# RiAct CarPlay Installation Guide

## What This Guide Will Help You Do

This guide turns a Raspberry Pi 4 into a car head unit:

- ✅ **CarPlay** on the screen as soon as your phone connects.
- ✅ **Black screen** from power-on: no logos, boot text, desktop or white "Searching…" screens. While the app waits for your phone, a little dancing car shows on the black screen.
- ✅ **Safe shutdown:** 5 seconds after the car is turned off, the Pi shuts down cleanly, then the X728 UPS turns itself off to save its battery.
- ✅ **Short dips are ignored:** if power comes back within 5 seconds (for example while the engine starts), nothing happens.
- ✅ **Auto power-on:** when the car is turned on, the Pi starts again.

**What you'll need:**

- Raspberry Pi 4 Model B with the Geekworm X728 UPS board attached, and 18650 batteries
- Carlinkit CPC200-CCPA (wireless) or CPC200-CCPW (wired) CarPlay dongle
- A screen (touch screen recommended), plus a keyboard and mouse for the setup
- A microSD card with **Raspberry Pi OS (64-bit)**, Bookworm or Trixie
- Internet connection
- About 30 minutes

---

## 📋 Step 1: Check Your Hardware Setup

### 1.1 Physical Connections

1. Turn off your Pi and unplug the power.
2. Check the X728 board is properly connected to your Pi's GPIO pins.
3. Check the jumpers on the X728:
   - The **AUTO ON** jumper is connected (the Pi starts when power arrives).
   - The **CHG EN** jumper is connected (the batteries charge).
4. Connect your power supply to the X728 board (**not** directly to the Pi).
5. Insert the 18650 batteries into the X728 if you haven't already.
6. Plug the CarPlay dongle into a USB port on the Pi.

### 1.2 Power On Test

1. Plug in the power to the X728 board.
2. If the Pi doesn't start by itself, press the power button on the X728.
3. Wait for the Pi to boot to the desktop.

✅ **Success check:** your Pi boots normally and you see the desktop.

---

## 💾 Step 2: Download the Project

Open a terminal (the black square icon on the desktop) and run:

```bash
cd ~
git clone https://github.com/brandespinosa/react-carplay.git
cd react-carplay
```

✅ **Success check:** `ls` shows folders called `pi`, `src` and `docs`.

---

## 🚀 Step 3: Run the Installer

> **Used an older version before?** If this Pi ever had the original react-carplay app, an earlier RiAct-Carplay version, or Geekworm's own X728 scripts, do the **🧹 Removing Old Versions** section (near the end of this guide) first.

```bash
bash pi/install.sh
```

Enter your password if asked. It takes a few minutes and prints six steps:

1. **Installing packages:** the tools for the X728 board, the GPIO pins and the kiosk.
2. **Enabling I2C:** the X728 board talks to the Pi over I2C.
3. **Installing the X728 power manager:** copies `x728_auto_shutdown.py` to `~/x728_power_monitor/` and sets it to start at boot.
4. **Installing the CarPlay app:** gives the app permission to use the dongle, and downloads `Carplay.AppImage` to `~/carplay/`.
5. **Black screen:** hides the boot logo and text, turns off the desktop, and sets the CarPlay app to start full screen at boot.
6. **X728 clock:** if the X728's clock chip answers, it turns the clock on so the Pi keeps the right time without internet (needed for night dimming). If it says the clock wasn't found, see **The X728 clock isn't found** in Troubleshooting.

> **First install:** I2C only switches on after a reboot, so step 6 asks you to reboot and run `bash pi/install.sh` once more. That's normal.

✅ **Success check:** the last line says `Done. Reboot to start everything`.

> The installer uses your username automatically. The service files in `pi/` say `pi`, but the installer swaps in your name when it copies them.

---

## 🔄 Step 4: Reboot

```bash
sudo reboot
```

**What you should see:**

1. The screen stays black while the Pi starts.
2. When the CarPlay app is ready, a little dancing car appears while it waits for your phone.
3. When your iPhone connects to the dongle, CarPlay appears.

> **First connection:** pair your iPhone with the dongle the first time. Wireless dongles show up in the iPhone's CarPlay settings (Settings → General → CarPlay). For a wired dongle, plug the phone into the dongle with a cable.

✅ **Success check:** the screen is black until CarPlay appears.

**Tap the black screen** to show the app menu for 10 seconds: 📞 CarPlay, ⚙️ Settings, ℹ️ Info, and ⏏️ Quit.

---

## 🧪 Step 5: Test the Power Manager

Do these tests with the Pi running.

### 5.1 Short Power Dip

1. Unplug the power to the X728 for about 2 seconds, then plug it back in.
2. The Pi keeps running.

### 5.2 Real Power Loss

1. Unplug the power to the X728 and leave it unplugged.
2. After 5 seconds the Pi shuts down.
3. A few seconds later the X728 turns off (all its LEDs go out).
4. Plug the power back in. The Pi starts again by itself.

### 5.3 Normal Reboot

1. Run `sudo reboot` with the power plugged in.
2. The Pi restarts. The X728 stays on.

### 5.4 Check the Log

```bash
tail -n 20 ~/x728_power_monitor/x728_shutdown.log
```

You should see lines like `AC Power Loss detected` and `AC Power restored`.

✅ **Success check:** all four tests behave as described.

---

## ⚙️ Settings You Can Change

### Shutdown Delay and Debounce

Edit `~/x728_power_monitor/x728_auto_shutdown.py`. The settings are near the top:

```python
SHUTDOWN_DELAY = 5           # Seconds to wait before shutdown after power loss
DEBOUNCE_TIME = 0.5          # Seconds to wait to avoid false triggers
```

Then restart the power manager:

```bash
sudo systemctl restart x728-power-monitor.service
```

### CarPlay App Settings

Tap the black screen, then tap ⚙️. The app always uses a dark look, with no mouse pointer or scroll bars (swipe to scroll). Here you can set the resolution, frame rate, microphone, camera, key bindings, and the CAN bus and MOST bus options. (**DARK MODE** there is CarPlay's own night look on the phone side; it's separate from the app's dark look.) Saving restarts the app. The [original react-carplay README](UPSTREAM_README.md) explains the CAN bus, MOST bus and key bindings.

### Dim the Screen at Night

The screen can dim from sunset to sunrise. To turn it on:

1. Tap the black screen, then tap ⚙️.
2. Tap **NIGHT DIM CITY** and pick the city nearest to you. The list has 73 major US cities, with at least one in every state and DC.
3. Tap **NIGHT BRIGHTNESS** and pick how bright the screen should be at night, in steps of 5%:
   - **100% (no dimming)**: same as daytime.
   - **50%**: the default.
   - **5%**: darkest.
4. Tap **SAVE**. The app restarts.

The sunset time is worked out on the Pi from the city's location and the date, so it needs no internet. It is checked once a minute. To turn dimming off, pick **Off** and tap **SAVE**.

> Sunset moves by about 4 minutes for every 50 miles east or west, so the nearest city in the list is close enough.

> **The Pi's clock must be right.** A Raspberry Pi 4 has no clock battery. Without internet it would start from the time it was last switched off, so after a night parked it might think it's still evening and dim during the day.
>
> The X728 has its own clock chip, kept running by its batteries. The installer turns it on when it finds it (step 6). To check it's working:
>
> ```bash
> sudo hwclock -r   # the clock chip's time
> date              # the Pi's time — both should be right
> ```
>
> If the installer said the clock wasn't found, see **The X728 clock isn't found** in Troubleshooting.

---

## 🔧 Troubleshooting

**CarPlay never appears (black screen, or the dancing car keeps dancing)**

1. Tap the screen. If the menu appears, the app is running but no phone is connected. Check the dongle is plugged in and your phone is paired.
2. If nothing appears, check the app's log:

   ```bash
   journalctl -u carplay-kiosk -n 50
   ```

3. Check the dongle is seen by the Pi. You should see a line with `1314`:

   ```bash
   lsusb
   ```

**Text like "[  OK  ] Started …" shows at start-up**

These are the Pi's start-up messages. The installer hides them. If you still see them, update and run the installer again:

```bash
cd ~/react-carplay && git pull && bash pi/install.sh && sudo reboot
```

To check, run `cat /boot/firmware/cmdline.txt`. The one line should include `console=tty3`, `quiet` and `systemd.show_status=false`.

**No sound from CarPlay**

Check the Pi's audio output. Open the settings with `sudo raspi-config` → **System Options** → **Audio**, and pick the right output.

**The Pi shuts down, but the X728 stays on**

1. Check the power manager service has the power-off step:

   ```bash
   sudo systemctl show x728-power-monitor.service -p ExecStop
   ```

   It should mention `pinctrl set 26 op dh`.

2. Test the power-off signal by hand. **Warning: this turns the whole system off.**

   ```bash
   pinctrl set 26 op dh
   ```

**The power manager isn't running**

```bash
sudo systemctl status x728-power-monitor.service
sudo journalctl -u x728-power-monitor.service -n 50
```

**False power-loss detections**

Raise `DEBOUNCE_TIME` to `1.0` (see Settings You Can Change above).

**The X728 board isn't found**

```bash
sudo i2cdetect -y 1
```

You should see **36** (battery chip) and **68** or **UU** (clock) in the grid. If not, see the next problem.

**The X728 clock isn't found (`i2cdetect` shows only dashes, or no 68)**

1. Run the check script. It changes nothing; it just looks and tells you what to do:

   ```bash
   cd ~/react-carplay
   bash pi/check_x728_clock.sh
   ```

   Read the **What to do** lines at the end.

2. **Only dashes, not even 36:** the Pi can't reach the X728 over I2C at all. The power manager still works, because it uses other pins.
   1. Power off, unplug, and reseat the X728 firmly on all 40 pins.
   2. Make sure the 18650 batteries are in and charged.
   3. If the check script lists a `gpio-shutdown` or `i2c-gpio` line, remove it from `/boot/firmware/config.txt` (`sudo nano /boot/firmware/config.txt`). Those take over the same pins.
   4. Make sure I2C is on: `sudo raspi-config nonint do_i2c 0`.
   5. Reboot and run the check script again.

3. **36 shows but 68 doesn't:** the board answers but its clock chip doesn't. Reseat the board; if 68 still doesn't show, contact Geekworm support.

4. **68 shows:** run `bash pi/install.sh` again, reboot with internet connected, then run `sudo hwclock -w` once to save the right time to the chip.

---

## 🧹 Removing Old Versions

Older CarPlay or X728 software left on the Pi can fight with this program. You might get two CarPlay apps grabbing the dongle, or two programs switching the UPS on and off. Do these checks once, before running the installer (or any time something behaves strangely).

### A. The original react-carplay app

If you ever installed Rhys Morgan's react-carplay with its `setup-pi.sh` script, it put the app on your Desktop and set it to start with the desktop. Remove both:

```bash
sudo rm -f /etc/xdg/autostart/carplay.desktop
rm -f ~/Desktop/Carplay.AppImage
rm -f ~/Downloads/react-carplay-*.AppImage
```

✅ **Check:** this should print nothing:

```bash
ls /etc/xdg/autostart | grep -i carplay
```

> The dongle permission file it created (`/etc/udev/rules.d/52-nodecarplay.rules`) is the same one this installer writes, so leave it.

### B. Earlier versions of this project (RiAct-Carplay)

Earlier versions used the same names as this one: `~/x728_power_monitor/`, `x728-power-monitor.service`, `carplay-kiosk.service` and `~/carplay/`. The installer replaces them all by itself. You only need to delete the old download:

```bash
rm -rf ~/RiAct-Carplay
```

✅ **Check:** after a reboot, exactly **one** line should show:

```bash
pgrep -af x728_auto_shutdown
```

### C. Geekworm's own X728 scripts

Geekworm's X728 software watches the same power pins (GPIO 6 and 26) as this program, so only one of them should run.

1. **Look for it.** If any of these finds something, it's installed. ("No such file or directory" and no output mean it isn't.)

   ```bash
   grep -n x728 /etc/rc.local
   ls /etc/x728pwr.sh /usr/local/bin/xSoft.sh
   systemctl list-unit-files | grep -i x728
   ```

2. **Remove the start-up line.** If `/etc/rc.local` has a line with `x728` in it, open the file and delete that line:

   ```bash
   sudo nano /etc/rc.local
   ```

   Save with **Ctrl + X**, **Y**, **Enter**.

3. **Turn off its services.** For every x728 service in the list **except** `x728-power-monitor.service` (that one is ours), run:

   ```bash
   sudo systemctl disable --now NAME-OF-THE-SERVICE
   ```

4. **Don't use the `x728off` command.** It runs Geekworm's script, and on the X728 V2.5 it can stop the Pi from starting by itself when power returns. This program powers the UPS off for you.

### D. Start the app's settings fresh (optional)

If the CarPlay app acts oddly after switching from an older version, reset its settings:

```bash
rm ~/.config/react-carplay/config.json
```

The app creates a new one with the defaults. Pick your city and night brightness again in ⚙️ Settings.

### Final check

```bash
systemctl list-unit-files | grep -iE "x728|carplay"
```

✅ You should see **only** `x728-power-monitor.service` and `carplay-kiosk.service`. Then run the installer and reboot:

```bash
cd ~/react-carplay
bash pi/install.sh
sudo reboot
```

---

## 🖥️ Getting the Desktop Back

To use the Pi as a normal computer again:

```bash
sudo systemctl disable carplay-kiosk.service
sudo systemctl enable getty@tty1.service
sudo raspi-config nonint do_boot_behaviour B4
sudo cp /boot/firmware/cmdline.txt.bak /boot/firmware/cmdline.txt
sudo cp /boot/firmware/config.txt.bak /boot/firmware/config.txt
sudo reboot
```

The power manager keeps working. To go back to CarPlay mode, run `bash pi/install.sh` again and reboot.

> **Tip:** to reach a terminal without changing anything, plug in a keyboard and press **Ctrl + Alt + F2**. Log in with your username and password.

---

## 🔁 Updating Safely

### Update this program

```bash
cd ~/react-carplay
git pull
bash pi/install.sh
sudo reboot
```

This downloads the newest app and reinstalls the power manager and services. Your app settings (city, night brightness) are kept.

### Update Raspberry Pi OS

Normal updates are safe:

```bash
sudo apt update
sudo apt full-upgrade -y
sudo reboot
```

✅ **Check afterwards:** both lines should say `active`:

```bash
systemctl is-active x728-power-monitor carplay-kiosk
```

If the desktop or boot text came back, or either service isn't active, run `bash pi/install.sh` again and reboot.

### Things that can break this program

| Don't | Why |
|-------|-----|
| Run `sudo rpi-update` | It installs test firmware that isn't needed and can break things. |
| Run the original react-carplay `setup-pi.sh`, or download the app from Rhys Morgan's releases | It brings back the white "Searching" screens and starts a second app with the desktop. |
| Install Geekworm's X728 scripts | They fight with this power manager over the same pins (see **🧹 Removing Old Versions**). |
| Change **System Options → Boot / Auto Login** in `raspi-config` | It turns the desktop back on in place of the CarPlay screen. |

> **Something broke after an update?** Run `bash pi/install.sh` again and reboot. It puts every part of this program back in place.

---

## 📱 Useful Commands

```bash
# Power manager
sudo systemctl status x728-power-monitor.service
tail -f ~/x728_power_monitor/x728_shutdown.log

# CarPlay app
sudo systemctl status carplay-kiosk.service
sudo systemctl restart carplay-kiosk.service
journalctl -u carplay-kiosk -f

# Hardware checks
pinctrl get 6        # lo = power OK, hi = power lost
sudo i2cdetect -y 1  # X728 shows as 36
lsusb                # the dongle shows as 1314
```

---

## 🎉 Done!

**What happens now:**

- **Car on:** the Pi starts with a black screen, and CarPlay appears when your phone connects.
- **Engine starting:** short power dips are ignored.
- **Car off:** the Pi shuts down safely after 5 seconds, then the X728 turns off to save its battery.
- **Logs:** the power manager log manages its own size (about 100KB, with one old copy kept).

To learn how it all works, read [How It Works](HOW_IT_WORKS.md).
