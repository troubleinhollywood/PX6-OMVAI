#/bin/sh

# This script is used in px4px6 platforms to show the DEEP 
# imaging status using the status LED.

if [ $1 == "blink" ]
then
	echo 0 > /sys/class/hwmon/hwmon1/device/system_red_led
	echo 1 > /sys/class/hwmon/hwmon1/device/led_blinkrate
	echo 2 > /sys/class/hwmon/hwmon1/device/system_white_led
elif [ $1 == "ok" ]
then
	echo 0 > /sys/class/hwmon/hwmon1/device/system_red_led
	echo 1 > /sys/class/hwmon/hwmon1/device/system_white_led
else
	echo 0 > /sys/class/hwmon/hwmon1/device/system_white_led
	echo 1 > /sys/class/hwmon/hwmon1/device/led_blinkrate
	echo 2 > /sys/class/hwmon/hwmon1/device/system_red_led
fi
echo 2 > /sys/class/hwmon/hwmon1/device/led_brightness
