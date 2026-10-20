#!/bin/bash
# Checks why the X728 clock (I2C 0x68) or battery chip (0x36) can't be seen. Changes nothing.
# Run on the Pi:  bash pi/check_x728_clock.sh   and read the "What to do" line at the end.

BOOT=/boot/firmware
[ -f "$BOOT/config.txt" ] || BOOT=/boot

echo "== 1. Is I2C turned on?"
if [ -e /dev/i2c-1 ]; then echo "yes: /dev/i2c-1 exists"; else echo "NO: /dev/i2c-1 is missing"; fi
grep -n 'i2c_arm' "$BOOT/config.txt" || echo "(no i2c_arm line in $BOOT/config.txt)"

echo
echo "== 2. Are pins 3 and 5 (GPIO 2 and 3) free for I2C? Both should say a0 / SDA1 / SCL1"
if command -v pinctrl >/dev/null; then pinctrl get 2-3; else raspi-gpio get 2-3 2>/dev/null || echo "(no pinctrl tool)"; fi
echo "Overlays that can take over those pins (should be none):"
grep -nE '^dtoverlay=(gpio-shutdown|i2c-gpio)' "$BOOT/config.txt" || echo "none"

echo
echo "== 3. Which chips answer on bus 1? (36 = X728 battery chip, 68 or UU = X728 clock)"
found36=no; found68=no
# The X728 is on bus 1 (pins 3 and 5). Other buses, like the HDMI ones (20, 21), can show false hits.
scan="$(sudo i2cdetect -y 1 2>/dev/null)"
echo "$scan"
echo "$scan" | grep -qE '^30:.* 36( |$)' && found36=yes
echo "$scan" | grep -qE '^60:.* (68|UU)( |$)' && found68=yes
echo "battery chip (36): $found36   clock (68): $found68"

echo
echo "== 4. Is the clock already in use?"
if [ -e /dev/rtc0 ]; then echo "yes: /dev/rtc0 exists, clock reads: $(sudo hwclock -r 2>&1)"; else echo "no /dev/rtc0"; fi
echo "Pi time now: $(date)"

echo
echo "== What to do"
if [ -e /dev/rtc0 ] && [ "$found68" = yes ]; then
  echo "The clock is working. Nothing to do. (If the time above is wrong, connect to the internet, then run: sudo hwclock -w)"
elif [ ! -e /dev/i2c-1 ]; then
  echo "Turn I2C on:  sudo raspi-config nonint do_i2c 0   then reboot and run this check again."
elif [ "$found68" = yes ]; then
  echo "The clock answers. Run  bash pi/install.sh  to turn it on, then reboot with internet connected."
elif [ "$found36" = yes ]; then
  echo "The X728 answers, but its clock chip doesn't. Reseat the board; if 68 still doesn't show, contact Geekworm support."
else
  echo "The Pi can't reach the X728 over I2C at all:"
  echo "  1. Power off, unplug, and reseat the X728 firmly on all 40 pins."
  echo "  2. Make sure the 18650 batteries are in and charged."
  echo "  3. Remove any overlay listed in step 2 above from $BOOT/config.txt (sudo nano $BOOT/config.txt)."
  echo "  4. If pins 2/3 above don't say a0, run: sudo raspi-config nonint do_i2c 0"
  echo "  5. Reboot and run this check again."
fi
