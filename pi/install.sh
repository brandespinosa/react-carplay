#!/bin/bash
# One-step Raspberry Pi setup for the car:
#   1. packages   2. I2C   3. X728 UPS power manager
#   4. CarPlay app (dongle permissions + black-screen AppImage)
#   5. black boot: no splash, no boot text, no desktop, app in the cage kiosk
#   6. X728 clock (keeps the time for night dimming), only if the chip answers
# Run once on the Pi:  bash pi/install.sh   (then: sudo reboot)
set -euo pipefail

APP_URL="${APP_URL:-https://github.com/brandespinosa/react-carplay/releases/latest/download/Carplay-arm64.AppImage}"
USER_NAME="${SUDO_USER:-$USER}"
HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
HERE="$(cd "$(dirname "$0")" && pwd)"
BOOT=/boot/firmware
[ -f "$BOOT/cmdline.txt" ] || BOOT=/boot

# Copies a service file into systemd, swapping the "pi" user and /home/pi/ for yours
install_service() {
  sed -e "s#/home/pi/#$HOME_DIR/#" -e "s/^User=pi/User=$USER_NAME/" "$HERE/$1" \
    | sudo tee "/etc/systemd/system/$1" >/dev/null
}

echo "== 1/6 Installing packages"
sudo apt-get update
sudo apt-get install -y python3-smbus python3-rpi.gpio gpiod i2c-tools cage xwayland fuse libfuse2

echo "== 2/6 Enabling I2C (the X728 board talks over I2C)"
sudo raspi-config nonint do_i2c 0

echo "== 3/6 Installing the X728 power manager"
sudo -u "$USER_NAME" mkdir -p "$HOME_DIR/x728_power_monitor"
sudo -u "$USER_NAME" cp "$HERE/x728_auto_shutdown.py" "$HOME_DIR/x728_power_monitor/"
install_service x728-power-monitor.service

echo "== 4/6 Installing the CarPlay app"
# Lets the app open the Carlinkit dongle (USB vendor 1314) without root
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="1314", ATTR{idProduct}=="152*", MODE="0660", GROUP="plugdev"' \
  | sudo tee /etc/udev/rules.d/52-nodecarplay.rules >/dev/null
sudo -u "$USER_NAME" mkdir -p "$HOME_DIR/carplay"
sudo -u "$USER_NAME" curl -fL "$APP_URL" -o "$HOME_DIR/carplay/Carplay.AppImage"
chmod +x "$HOME_DIR/carplay/Carplay.AppImage"

echo "== 5/6 Black screen from power-on until CarPlay opens"
sudo cp -n "$BOOT/config.txt" "$BOOT/config.txt.bak"
sudo cp -n "$BOOT/cmdline.txt" "$BOOT/cmdline.txt.bak"
grep -q '^disable_splash=1' "$BOOT/config.txt" || echo 'disable_splash=1' | sudo tee -a "$BOOT/config.txt" >/dev/null
# cmdline.txt must stay one line: send boot text to tty3, drop the splash, hide logo and cursor
sudo sed -i -e 's/console=tty1/console=tty3/' -e 's/ splash//' "$BOOT/cmdline.txt"
for opt in quiet loglevel=3 logo.nologo vt.global_cursor_default=0; do
  grep -qw "$opt" "$BOOT/cmdline.txt" || sudo sed -i "1 s/\$/ $opt/" "$BOOT/cmdline.txt"
done
sudo raspi-config nonint do_boot_behaviour B1
sudo systemctl disable getty@tty1.service
install_service carplay-kiosk.service

echo "== 6/6 X728 clock (keeps the right time for night dimming)"
# The X728's clock is a DS1307 at I2C address 0x68 ("UU" = already in use by the driver)
if [ ! -e /dev/i2c-1 ]; then
  echo "I2C turns on after the reboot. Reboot, then run this installer again to set up the clock."
elif sudo i2cdetect -y 1 0x68 0x68 | grep -qE ' (68|UU)'; then
  grep -q '^dtoverlay=i2c-rtc,ds1307' "$BOOT/config.txt" || echo 'dtoverlay=i2c-rtc,ds1307' | sudo tee -a "$BOOT/config.txt" >/dev/null
  sudo apt-get remove -y fake-hwclock
  # Let udev set the time from the clock chip at boot (Debian skips it when systemd runs)
  if [ -f /lib/udev/hwclock-set ]; then
    sudo cp -n /lib/udev/hwclock-set /lib/udev/hwclock-set.bak
    sudo sed -i '/^if \[ -e \/run\/systemd\/system \] ; then$/,/^fi$/ s/^/#/' /lib/udev/hwclock-set
  fi
  if [ -e /dev/rtc0 ] && [ "$(timedatectl show -p NTPSynchronized --value)" = yes ]; then
    sudo hwclock -w
    echo "Clock set: $(sudo hwclock -r)"
  else
    echo "Clock turned on. Reboot with internet connected, then run:  sudo hwclock -w"
  fi
else
  echo "WARNING: the X728 clock was not found, so night dimming may use the wrong time without internet."
  echo "         Run  bash pi/check_x728_clock.sh  to see why."
fi

sudo systemctl daemon-reload
sudo systemctl enable x728-power-monitor.service carplay-kiosk.service

echo "Done. Reboot to start everything:  sudo reboot"
