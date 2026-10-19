# RiAct CarPlay

**A Raspberry Pi car head unit: wireless Apple CarPlay with safe, automatic power on and off.**

Everything for the project lives in this one repository:

- **The CarPlay app.** A copy of [react-carplay](https://github.com/rhysmorgan134/react-carplay) changed so the screen stays black until CarPlay opens.
- **The power manager.** A small Python program for the Geekworm X728 UPS (battery backup board). It shuts the Pi down safely when the car is turned off.
- **One install script** that sets up the whole Pi.
- **The guides:** how to install it, and how all the code works.

> I am not a coder. This project was built with the help of Claude (claude.ai). It is shared so other hobbyists can use and change it. It is not maintained. Good luck! — B.

## What it does

| When | What happens |
|------|--------------|
| Car turned on | The X728 powers the Pi on. The screen stays **black** (no logos, no boot text, no desktop, no white "Searching…" screens) until the app starts. Then a little dancing car shows while it waits for your phone, and **CarPlay** appears when the phone connects. |
| Engine starting (short power dip) | Ignored. If power is back within 5 seconds, nothing happens. |
| Car turned off | After 5 seconds the Pi shuts down cleanly, then the X728 turns itself off to save the battery. |
| After sunset | The screen dims by 50% until sunrise (once you pick your city in the app's settings). |
| Car turned off while the Pi is still booting | The Pi shuts down 5 seconds after the power manager starts, instead of draining the battery. |
| `sudo reboot` with power on | A normal reboot. The UPS stays on. |

## What you need

- Raspberry Pi 4 Model B with **Raspberry Pi OS (64-bit, Bookworm)**
- Geekworm **X728** UPS board (V2.5 tested), with 18650 batteries, the **AUTO ON** and **CHG EN** jumpers fitted
- Carlinkit **CPC200-CCPA** (wireless and wired) or **CPC200-CCPW** (wired only) CarPlay dongle
- A screen (touch screen recommended)
- An iPhone

## Quick start

On the Pi, with internet:

```bash
git clone https://github.com/brandespinosa/react-carplay.git
cd react-carplay
bash pi/install.sh
sudo reboot
```

That's it. For step-by-step instructions with checks after each step, see the **[Installation Guide](docs/INSTALL_GUIDE.md)** (also as a [PDF](docs/Installation%20Guide.pdf)).

**Using it:**

- **Tap the black screen** to show the app menu (settings, info, quit) for 10 seconds.
- Power manager log: `tail -f ~/x728_power_monitor/x728_shutdown.log`
- CarPlay app log: `journalctl -u carplay-kiosk -f`

## Documentation

| Document | What's in it |
|----------|--------------|
| [Installation Guide](docs/INSTALL_GUIDE.md) | Hardware setup, install, tests, troubleshooting, useful commands, how to get the desktop back |
| [How It Works](docs/HOW_IT_WORKS.md) | Plain-English walkthrough of all the code: boot, power manager, services, the CarPlay app, the build |
| [Original react-carplay README](docs/UPSTREAM_README.md) | App features: CAN bus reverse camera, MOST bus audio, key bindings |

## What's in this repository

```
pi/                          Raspberry Pi setup (this project)
  install.sh                 One-step setup script
  x728_auto_shutdown.py      Power manager for the X728 UPS
  x728-power-monitor.service Runs the power manager; powers off the UPS on shutdown
  carplay-kiosk.service      Runs the CarPlay app full screen on a black screen
  LICENSE                    MIT licence for the files in pi/
src/                         The CarPlay app (Electron + React), from react-carplay
  main/                      Background part: window, settings file, CAN bus
  preload/                   Bridge between the background part and the screen
  renderer/                  What you see: React screens, video and audio workers
docs/                        Guides
.github/workflows/           Automatic build of the Pi app (Carplay-arm64.AppImage)
.claude/skills/              Claude Code helper skills (ponytail)
```

## Building the app

You don't need to build anything: `pi/install.sh` downloads the ready-made app from this repository's [latest release](https://github.com/brandespinosa/react-carplay/releases/latest).

Every change pushed to `main` is built automatically by GitHub Actions (`.github/workflows/build-pi.yml`) and published as a new release. To build it yourself on an arm64 Linux machine (such as a Pi 4): `npm ci`, then `npx electron-vite build && npx electron-builder --linux AppImage --arm64`.

## Credits and licences

- The CarPlay app is [react-carplay](https://github.com/rhysmorgan134/react-carplay) by Rhys Morgan. It uses [node-carplay](https://github.com/rhysmorgan134/node-CarPlay) to talk to the dongle. The original project has no licence file, so its code remains © its authors.
- The files in `pi/` are © brandespinosa, under the MIT licence (`pi/LICENSE`).
- The UPS power-off method follows Geekworm's official X728 scripts.
