# How It Works

This guide explains every part of the project in plain English. No coding experience is needed. Code names are shown `like this`, so you can find them in the files.

## The Big Picture

The system has four main parts, plus one boot-up stage:

```
 Car power ──► X728 UPS board ──► Raspberry Pi 4 ──► Screen
                   │                  │
                   │ GPIO 6: "power   ├─ x728-power-monitor.service
                   │   lost?"         │    runs x728_auto_shutdown.py
                   │ GPIO 26: "turn   │
                   │   yourself off"  └─ carplay-kiosk.service
                   │                       runs cage ──► Carplay.AppImage
                   │                                        │ USB
                   └── batteries keep the Pi alive          ▼
                       while it shuts down           Carlinkit dongle ◄─ Wi-Fi ─► iPhone
```

| Part | Where | Job |
|------|-------|-----|
| **Boot settings** | `/boot/firmware/config.txt` and `cmdline.txt` (set by `pi/install.sh`) | Keep the screen black while the Pi starts |
| **Power manager** | `pi/x728_auto_shutdown.py` | Watch the car's power, shut the Pi down safely when it goes away |
| **Power service** | `pi/x728-power-monitor.service` | Start the power manager at boot, and switch the UPS off at the very end of shutdown |
| **Kiosk service** | `pi/carplay-kiosk.service` | Start the CarPlay app full screen instead of the desktop |
| **CarPlay app** | `src/` | Talk to the dongle and show CarPlay's picture, sound and touch |

---

## 1. Power-On: From Black Screen to CarPlay

What happens, in order, when the car is turned on:

1. **The X728 turns the Pi on.** The AUTO ON jumper makes the X728 power the Pi as soon as outside power arrives.
2. **No rainbow square.** `disable_splash=1` in `config.txt` hides the Pi's colourful start-up square.
3. **No boot text or logo.** In `cmdline.txt` (the Linux start-up options):
   - `console=tty3`: boot messages go to a hidden screen (tty3) instead of the visible one (tty1).
   - `quiet loglevel=3`: only serious errors are printed.
   - `logo.nologo`: no Raspberry Pi logos.
   - `vt.global_cursor_default=0`: no blinking cursor.
   - `systemd.show_status=false`: no "[  OK  ] Started …" lines from the start-up manager (systemd).
   - `udev.log_level=3`: no hardware-detection messages.
   - `plymouth.enable=0`: turns off Plymouth, the boot-screen program. With no splash, it prints the "[  OK  ]" lines on screen itself.
   - `fbcon=map:2`: the Pi never draws text on the screen, so no messages show at start-up or shut-down, even ones that get past the settings above. (A terminal is still available over SSH.)
   - `splash` removed: no boot animation.
4. **No desktop.** `raspi-config nonint do_boot_behaviour B1` makes the Pi start to a text console instead of the desktop. The usual login prompt on screen 1 is turned off (`getty@tty1` disabled), so the console stays black.
5. **The kiosk starts.** systemd (Linux's service manager) starts `carplay-kiosk.service`:
   - It logs in as you on screen 1 (`TTYPath=/dev/tty1`, `PAMName=login`), so sound and USB permissions work like a normal login.
   - It runs **cage**, a "kiosk" display program that shows exactly one app, full screen, on a black background. There are no windows, taskbar or desktop.
   - cage runs `~/carplay/Carplay.AppImage --ozone-platform=wayland`. The AppImage is the CarPlay app packed into a single file. The flag tells it to draw directly through cage.
   - `Restart=always`: if the app ever crashes, it starts again 2 seconds later.
6. **The app stays black** until the phone connects (see section 4), then shows CarPlay.

---

## 2. The Power Manager (`pi/x728_auto_shutdown.py`)

A small Python program that runs all the time in the background.

### How it knows the power is gone

The X728 board connects to the Pi's GPIO pins (general-purpose input/output pins):

- **GPIO 6 (input):** the X728 holds it **low (0)** while outside power is present, and makes it **high (1)** when it's lost.
- **GPIO 26 (output):** setting it **high** tells the X728 to turn itself off.

`check_power_status()` reads GPIO 6 and returns `True` when power is OK.

### Watching for changes

`start_monitoring()`:

1. Sets up the pins (`setup_gpio()`): GPIO 6 as an input, GPIO 26 as an output starting low.
2. Checks the power once at start. **If power is already lost** (for example, the car was turned off during boot), it starts the shutdown right away. Otherwise it would wait for a change that never comes.
3. Asks the Pi to call `power_loss_callback()` whenever GPIO 6 changes (an "interrupt": the Pi tells the program instead of the program checking over and over). `bouncetime` ignores electrical jitter shorter than `DEBOUNCE_TIME`.
4. If interrupts don't work, it falls back to `start_polling_mode()`, which checks the pin once a second.

### The shutdown countdown

`handle_power_loss()`:

1. Logs "AC Power Loss detected".
2. Counts down `SHUTDOWN_DELAY` (5) seconds. **Every second it checks the power again.** If power is back (for example, the engine was starting), it calls `handle_power_restored()` and stops. No shutdown happens.
3. If power is still gone after 5 seconds, it calls `perform_system_shutdown()`, which runs `sudo shutdown -h now`. The installer's rule in `/etc/sudoers.d/010_x728-shutdown` lets it run that one command without a password.

### The log file

Messages go to `~/x728_power_monitor/x728_shutdown.log` and to the system journal. Python's `RotatingFileHandler` keeps the file under about 100KB: when it's full, it's renamed to `x728_shutdown.log.1` and a new one starts.

---

## 3. Power-Off: Turning the UPS Off (`pi/x728-power-monitor.service`)

The Pi can't turn the X728 off while the Pi is still running its programs. The X728 must be told **at the very end** of the shutdown. systemd does this:

- `ExecStart` starts the power manager at boot.
- `ExecStop` runs when the service is stopped, which happens during shutdown:

  ```sh
  pinctrl get 6 | grep -q "| hi" && pinctrl set 26 op dh || true
  ```

  This means: "if GPIO 6 is high (power lost), drive GPIO 26 high (turn the UPS off); otherwise do nothing". `pinctrl` is the Raspberry Pi's own pin tool and works the same on Bookworm and Trixie (the older `gpioget` / `gpioset` commands changed between those versions). This check is why a normal `sudo reboot` with power connected does **not** turn the UPS off.
- `ExecStopPost=/bin/sleep 4` gives the X728 time to notice the signal.
- `Restart=always` restarts the power manager if it ever crashes.

The X728 then waits for the Pi to finish shutting down, and switches everything off. When the car is turned on again, AUTO ON starts the cycle over.

---

## 4. The CarPlay App (`src/`)

The app is built with **Electron**: a web page (made with **React**) running in its own window, plus a background program that can use the Pi's hardware. It's the [react-carplay](https://github.com/rhysmorgan134/react-carplay) project, with the black-screen changes in this repo.

### The three parts of an Electron app

| Part | Folder | Job |
|------|--------|-----|
| **Main process** (background) | `src/main/` | Opens the window, loads and saves settings, reads the CAN bus |
| **Preload** (bridge) | `src/preload/index.ts` | Gives the screen a small, safe set of functions: `getSettings`, `saveSettings`, `quit` |
| **Renderer** (what you see) | `src/renderer/` | The React screens, plus "workers" that handle the dongle, video and sound |

### Main process: `src/main/index.ts`

- **Settings:** stored in `~/.config/react-carplay/config.json`. On first run it's created from the defaults (`EXTRA_CONFIG`). If an update adds new settings, they're merged in.
- **Settings server:** `Socket.ts` runs a small local server on port 4000. The screen uses it to read and save settings. Saving restarts the app (`saveSettings` → `app.relaunch()`).
- **CAN bus (optional):** if enabled, `Canbus.ts` listens to the car's CAN bus (its internal network) and tells the screen when reverse is selected, to show a camera.
- **The window:** `createWindow()` opens a full-screen, frameless window (`kiosk: true`) with a **black background** (`backgroundColor: '#000000'`), so nothing white shows while it loads.
- **Always dark:** `nativeTheme.themeSource = 'dark'` makes the whole app use its dark look: the menu, the "Searching" screen and the settings pages. `App.css` makes the dark background pure black.
- **No pointer, no scroll bars:** `App.css` hides the mouse pointer (`cursor: none`) and all scroll bars (`::-webkit-scrollbar`), since it's a touch screen. Swiping still scrolls pages like Settings.

### Renderer: the screens

- `src/renderer/index.html`: the page. It starts with a **black cover** inside `#root`, so the screen is black even before React has drawn anything.
- `App.tsx`: the top level. It shows the menu (`Nav`), the CarPlay view (`Carplay`) and the pages (Settings, Info, Camera).
- `components/Nav.tsx`: the menu bar. **Black-screen change:** while you're on the CarPlay page and no phone is connected (`!isPlugged`), it covers the whole screen in black. Tapping it calls `revealMenu()`, which shows the menu for 10 seconds.
- `components/LoadingCar.tsx`: the **dancing car** shown in the middle of that black cover.
  - A drawn (SVG) car on a green tile that bobs and sways, with spinning wheels and floating music notes.
  - It uses only CSS animations of movement and fading, which the Pi's graphics chip handles easily.
  - Touches pass through it to the black cover.
- `components/Carplay.tsx`: the CarPlay view.
  - Starts the two workers below.
  - Watches for the dongle being plugged or unplugged (`navigator.usb.onconnect` / `ondisconnect`).
  - Listens for `plugged` / `unplugged` messages (phone connected or not) and stores them in `isPlugged`.
  - Sends your touches to the phone (`useCarplayTouch.ts`).
  - The video area has a black background, so it's black until the first video frame arrives.
- `components/Settings.tsx`, `KeyBindings.tsx`, `Canbus.tsx`, `Camera.tsx`: the settings pages.
- `components/NightDim.tsx`: **night dimming.**
  - If a city is picked in the settings, it checks once a minute whether it's between sunset and sunrise (`isNight()`).
  - The **suncalc** library works out the sunset and sunrise times from the location and date, with no internet needed.
  - At night it lays a see-through black layer over everything, including CarPlay. Touches pass straight through it (`pointerEvents: 'none'`).
  - How dark the layer is comes from the **NIGHT BRIGHTNESS** setting (`nightBrightness`: 5 to 100 in steps of 5, default 50). The layer's opacity is `1 − nightBrightness / 100`, so 50% brightness = half-dark, 5% = almost black, and 100% = no layer at all.
  - The **NIGHT DIM CITY** list is in `components/usCities.ts` (name, latitude, longitude). Picking a city saves its `latitude` / `longitude` in the settings file. **Off** saves `null`, which means dimming is off.
- `store/store.ts`: shared memory for the screens. `useStatusStore` holds `isPlugged` and `reverse`. `useCarplayStore` holds the settings.

### Workers: the heavy lifting

Workers are background helpers in the renderer, so video and sound don't slow down the screen.

- **`worker/CarPlay.worker.ts` (talks to the dongle).**
  - Uses **node-carplay** (`CarplayWeb`) to find the dongle over USB (`findDevice()`) and start a session.
  - Sends video data on to the render worker.
  - Puts sound data into shared "ring buffers" for the audio player.
  - Passes on messages like `plugged`, `unplugged` and commands from the phone.
  - Sends your touches, key presses and microphone sound to the dongle.
- **`worker/render/Render.worker.ts` (draws the picture).** Decodes the phone's H.264 video with the browser's `VideoDecoder`, then draws each frame with WebGL (WebGL2 and WebGPU drawing code is also included, but WebGL is the one used).
- **`useCarplayAudio.ts` + `public/audio.worklet.js` (sound).** Plays CarPlay's music, navigation and phone audio. Records the microphone for Siri and calls.

### From phone to screen, step by step

1. The iPhone connects to the dongle over Wi-Fi (or a cable).
2. The dongle sends `plugged` over USB → `CarPlay.worker.ts` → `Carplay.tsx` sets `isPlugged = true`.
3. `Nav.tsx` removes the black cover, and the video area becomes visible.
4. Video frames flow: dongle → `CarPlay.worker.ts` → `Render.worker.ts` → screen.
5. When the phone disconnects, `unplugged` → `isPlugged = false` → the black cover returns.

---

## 5. Building the App (`.github/workflows/build-pi.yml`)

You never need to build the app yourself. GitHub does it:

1. Every push to `main` starts the **Build Pi AppImage** workflow on an arm64 (Pi-compatible) GitHub computer.
2. It installs the code's dependencies (`npm ci`), builds the web code (`electron-vite build`), then packs everything into one file (`electron-builder --linux AppImage --arm64`).
3. It publishes the file as `Carplay-arm64.AppImage` in a new release, marked "latest".
4. `pi/install.sh` downloads it from `releases/latest`.

**Two dependency fixes** were needed for the build to work again. The original project pointed `node-carplay` at a version on GitHub that no longer exists. `package.json` now uses the same versions published on npm: `node-carplay@4.0.0` and `pcm-ringbuf-player@0.0.5`.

---

## 6. The Installer (`pi/install.sh`)

The installer runs six steps, and is safe to run more than once:

1. **Packages:** Python GPIO and I2C tools for the X728, `raspi-utils` (the `pinctrl` pin tool), `cage` and `xwayland` (the kiosk), and `fuse` / `libfuse2` (to run AppImages).
2. **I2C on:** `raspi-config nonint do_i2c 0`.
3. **Power manager:**
   - Copies the script to `~/x728_power_monitor/`.
   - Installs the service with your username and home folder swapped in (`install_service`).
   - Adds `/etc/sudoers.d/010_x728-shutdown` so the power manager can run `sudo shutdown` without a password. Newer Pi images ask for one, and the shutdown would fail.
4. **CarPlay app:**
   - Adds a udev rule (`/etc/udev/rules.d/52-nodecarplay.rules`) so the app can use the dongle (USB vendor ID `1314`) without being root.
   - Downloads the app to `~/carplay/Carplay.AppImage`.
5. **Black boot:**
   - Backs up `config.txt` and `cmdline.txt` (`.bak`), then makes the boot changes from section 1.
   - Turns off the desktop and the screen-1 login, and installs the kiosk service.
6. **X728 clock** (so night dimming knows the time without internet):
   - It first checks whether the X728's clock chip answers at I2C address 0x68 (`i2cdetect -y 1 0x68 0x68`, showing `68` or `UU`).
   - If it does, it adds `dtoverlay=i2c-rtc,ds1307` to `config.txt` so Linux uses the chip, and removes `fake-hwclock` (which would otherwise restore the last shutdown time).
   - It also comments out the "skip when systemd runs" lines in `/lib/udev/hwclock-set`, keeping a `.bak` copy, so the time is read from the chip at boot.
   - When the clock is active and the time is synced from the internet, it saves that time to the chip (`hwclock -w`).
   - If the chip doesn't answer, it changes nothing and points to `pi/check_x728_clock.sh`. That script only reads: it checks that I2C is on, that pins GPIO 2/3 are free, scans every I2C bus for 0x36/0x68, and prints what to do.

Finally, it enables both services so they start at every boot.

---

## 7. Files at a Glance

| File | What it is |
|------|-----------|
| `pi/install.sh` | One-step Pi setup |
| `pi/check_x728_clock.sh` | Read-only check for the X728 clock: I2C on, pins free, chips found, what to do |
| `pi/x728_auto_shutdown.py` | Power manager |
| `pi/x728-power-monitor.service` | Starts the power manager; turns the UPS off at shutdown |
| `pi/carplay-kiosk.service` | Starts the CarPlay app full screen with cage |
| `src/main/index.ts` | App background: window, settings |
| `src/main/Socket.ts` | Local settings server (port 4000) |
| `src/main/Canbus.ts` | Car CAN bus reader (reverse camera trigger) |
| `src/main/Globals.ts` | The list of settings and their types |
| `src/preload/index.ts` | Safe bridge between the background and the screen |
| `src/renderer/index.html` | The page, with the black cover |
| `src/renderer/src/App.tsx` | Top-level screen layout |
| `src/renderer/src/components/Nav.tsx` | Menu bar and black cover with tap-to-show |
| `src/renderer/src/components/NightDim.tsx` | Dims the screen to the chosen night brightness from sunset to sunrise |
| `src/renderer/src/components/usCities.ts` | The list of US cities for night dimming |
| `src/renderer/src/components/LoadingCar.tsx` | Dancing car shown while waiting for the phone |
| `src/renderer/src/components/Carplay.tsx` | CarPlay view: workers, plugged/unplugged, touch |
| `src/renderer/src/components/worker/CarPlay.worker.ts` | Talks to the dongle |
| `src/renderer/src/components/worker/render/Render.worker.ts` | Decodes and draws the video |
| `src/renderer/src/components/useCarplayAudio.ts` | Sound and microphone |
| `src/renderer/src/store/store.ts` | Shared state: settings, plugged, reverse |
| `.github/workflows/build-pi.yml` | Automatic build and release of the app |
| `electron-builder.yml` | How the AppImage is packed |
