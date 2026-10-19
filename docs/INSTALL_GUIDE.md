# RiAct CarPlay Installation Guide

## What This Guide Will Help You Do

This guide turns a Raspberry Pi 4 into a car head unit:

- ✅ **CarPlay** on the screen as soon as your phone connects.
- ✅ **Black screen** from power-on until CarPlay opens: no logos, boot text, desktop or white "Searching…" screens.
- ✅ **Safe shutdown:** 5 seconds after the car is turned off, the Pi shuts down cleanly, then the X728 UPS turns itself off to save its battery.
- ✅ **Short dips are ignored:** if power comes back within 5 seconds (for example while the engine starts), nothing happens.
- ✅ **Auto power-on:** when the car is turned on, the Pi starts again.

**What you'll need:**

- Raspberry Pi 4 Model B with the Geekworm X728 UPS board attached, and 18650 batteries
- Carlinkit CPC200-CCPA (wireless) or CPC200-CCPW (wired) CarPlay dongle
- A screen (touch screen recommended), plus a keyboard and mouse for the setup
- A microSD card with **Raspberry Pi OS (64-bit, Bookworm)**
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

```bash
bash pi/install.sh
```

Enter your password if asked. It takes a few minutes and prints five steps:

1. **Installing packages:** the tools for the X728 board, the GPIO pins and the kiosk.
2. **Enabling I2C:** the X728 board talks to the Pi over I2C.
3. **Installing the X728 power manager:** copies `x728_auto_shutdown.py` to `~/x728_power_monitor/` and sets it to start at boot.
4. **Installing the CarPlay app:** gives the app permission to use the dongle, and downloads `Carplay.AppImage` to `~/carplay/`.
5. **Black screen:** hides the boot logo and text, turns off the desktop, and sets the CarPlay app to start full screen at boot.

✅ **Success check:** the last line says `Done. Reboot to start everything`.

> The installer uses your username automatically. The service files in `pi/` say `pi`, but the installer swaps in your name when it copies them.

---

## 🔄 Step 4: Reboot

```bash
sudo reboot
```

**What you should see:**

1. The screen stays black while the Pi starts.
2. When your iPhone connects to the dongle, CarPlay appears.

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

Tap the black screen, then tap ⚙️. Here you can set the resolution, frame rate, microphone, camera, key bindings, and the CAN bus and MOST bus options. Saving restarts the app. The [original react-carplay README](UPSTREAM_README.md) explains the CAN bus, MOST bus and key bindings.

### Dim the Screen at Night

The screen can dim by 50% from sunset to sunrise. To turn it on:

1. Look up your location's latitude and longitude, for example by long-pressing your home on Google Maps. Los Angeles is about `34.05` and `-118.24`.
2. Tap the black screen, then tap ⚙️.
3. Enter the numbers in **LATITUDE (NIGHT DIM)** and **LONGITUDE (NIGHT DIM)**. Use a minus sign for south and west.
4. Tap **SAVE**. The app restarts.

The sunset time is worked out on the Pi from your location and the date, so it needs no internet. It is checked once a minute. To turn dimming off, clear both fields and tap **SAVE**.

> **The Pi's clock must be right.** A Raspberry Pi 4 has no clock battery. It gets the time from the internet, and without internet it starts from the time it was last switched off. So after a night parked, it may think it's still evening and dim during the day. Check the time with `date`.
>
> The X728 seems to have its own clock chip, kept running by its batteries. **This hasn't been tested with this project.** To try it:
>
> 1. Check the chip is there: `sudo i2cdetect -y 1` should show **68**.
> 2. Add this line to the end of `/boot/firmware/config.txt`:
>
>    ```
>    dtoverlay=i2c-rtc,ds1307
>    ```
>
> 3. Run `sudo apt remove -y fake-hwclock`, then reboot with internet.
> 4. Save the correct time to the chip: `sudo hwclock -w`.
> 5. Check it: `sudo hwclock -r` should show the right time.

---

## 🔧 Troubleshooting

**The screen stays black and CarPlay never appears**

1. Tap the screen. If the menu appears, the app is running but no phone is connected. Check the dongle is plugged in and your phone is paired.
2. If nothing appears, check the app's log:

   ```bash
   journalctl -u carplay-kiosk -n 50
   ```

3. Check the dongle is seen by the Pi. You should see a line with `1314`:

   ```bash
   lsusb
   ```

**No sound from CarPlay**

Check the Pi's audio output. Open the settings with `sudo raspi-config` → **System Options** → **Audio**, and pick the right output.

**The Pi shuts down, but the X728 stays on**

1. Check the power manager service has the power-off step:

   ```bash
   sudo systemctl show x728-power-monitor.service -p ExecStop
   ```

   It should mention `gpioset 0 26=1`.

2. Test the power-off signal by hand. **Warning: this turns the whole system off.**

   ```bash
   gpioset 0 26=1
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

You should see **36** in the grid. If not, check the board is seated properly on the GPIO pins.

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

## 🔁 Updating

```bash
cd ~/react-carplay
git pull
bash pi/install.sh
sudo reboot
```

This downloads the newest app and reinstalls the power manager and services.

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
gpioget 0 6          # 0 = power OK, 1 = power lost
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
