#!/bin/bash

export NCURSES_NO_UTF8_ACS=1

if ! [ $(id -u) = 0 ]; then
	echo "SADIE must be run as root. Try 'sudo ./sadie.sh'."
	exit 1
fi

echo "======================================================"
echo "================= Welcome to SADIE ==================="
echo "=== Simple Android Download and Install Executable ==="
echo "======================================================"
echo "============= Made for the Rock64 board  ============="
echo "============= by Matthew Petry (fire219) ============="
echo "== Additional scripting by Kamil Trzciński (ayufan) =="
echo "======================================================"
echo ""
echo "SADIE version 1.0 (20170407)"
echo ""
echo "This script will download and flash Android 7.1 to your Rock64 board."
echo ""
echo "IMPORTANT NOTES:"
echo "1. Before you continue, please locate a USB A-to-A cable."
echo "   It is critical to the installation process."
echo ""
echo "2. If you wish to install Android to onboard eMMC, you *MUST* remove"
echo "   your SD card if you have one."
echo ""
read -rsp $'Press any key to continue...\n' -n 1 key  

HEIGHT=30
WIDTH=80
CHOICE_HEIGHT=4
BACKTITLE="Simple Android Download and Install Executable (SADIE)"
MENU="Please select one of the following options:"



clear
echo "====Preparation===="
echo "Script will now check to make sure all required tools are available."
echo ""
echo "Stage 1: Detect host distribution"
PKGINSTALL=""
if [ -e /usr/bin/apt ] ; then
	PKGINSTALL="apt-get install -q -y "
    	echo "apt package manager detected."
fi
if [ -e /usr/bin/dnf ] ; then
        PKGINSTALL="dnf install -q -y "
        echo "dnf package manager detected."
fi

echo "Stage 2: Check for essential utilities"
echo ""
for i in dialog make gcc wget unzip; do
	if ! hash $i &> /dev/null ; then
		if [ "$PKGINSTALL" = "" ] ; then
			echo "You are missing the utility '$i' and SADIE is unable to install it"
			echo "on your distro. Please do this manually and then restart SADIE."
			exit 1
		fi
		echo "$i not found. Now installing; please wait a moment."
		$($PKGINSTALL $i)
	else
		echo "$i is installed."
	fi
done
echo ""
echo "Stage 3: Check for rkflashtool"
if ! hash rkflashtool &> /dev/null ; then
	echo "rkflashtool not found. Must be compiled and installed. Please wait..."
	git clone https://github.com/ayufan-rock64/rkflashtool
	make -C rkflashtool
 	make -C rkflashtool install
else
	echo "rkflashtool detected."
fi
OPTIONS=(1 "Android 'Desktop' (currently unstable)"
	 2 "Android TV (Recommended)")

CHOICE=$(dialog --clear \
		--backtitle "$BACKTITLE" \
                --title "Android Image Selection" \
                --menu "$MENU" \
                $HEIGHT $WIDTH $CHOICE_HEIGHT \
                "${OPTIONS[@]}" \
                2>&1 >/dev/tty)

case $CHOICE in
	1)
		IMAGETYPE="desktop"
		clear
		IMAGEURL=$(wget fire219.kotori.me/sadie/desktop-image.txt -q -O -)
		;;
	2)
		IMAGETYPE="box"
                clear
                IMAGEURL=$(wget fire219.kotori.me/sadie/box-image.txt -q -O -)
		;;
esac

IMAGEFILEREL="${IMAGEURL##*/}"
IMAGEFILE=$(pwd)"/${IMAGEURL##*/}"

if [ -e "$IMAGEFILE" ] ; then
	dialog --clear \
                --backtitle "$BACKTITLE" \
                --title "Image already downloaded." \
                --msgbox "SADIE has detected that the latest image zip was previously downloaded. Continuing with existing image." \
                10 60 \
                2>&1 >/dev/tty

else
	dialog --clear \
		--backtitle "$BACKTITLE" \
		--title "Download Confirmation" \
		--msgbox "SADIE will now download the selected image. This may take some time, depending on your connection speed." \
		10 60 \
		2>&1 >/dev/tty

	clear
	echo "Please wait while this download completes."
	wget -nv --show-progress "$IMAGEURL" 
fi
dialog --backtitle "$BACKTITLE" --title "Please Wait..." --infobox "Preparing Scripts..." 10 60
if [ ! -e /usr/local/bin/rkinstall ] ; then
	wget fire219.kotori.me/sadie/rkinstall -q
	mv rkinstall /usr/local/bin/rkinstall
	chmod +x /usr/local/bin/rkinstall
fi
dialog  --backtitle "$BACKTITLE" --title "Please Wait..." --infobox "Unzipping image..." 10 60
IMAGEDIR="${IMAGEFILE%.*}"
if [ -d $IMAGEDIR ] ; then
	rm -r $IMAGEDIR
fi
unzip -qq  $IMAGEFILEREL
 
clear
echo "===Loader Mode Instructions==="
echo ""
echo "To flash Android onto your Rock64, it must be put into Loader Mode."
echo ""
echo "This is accomplished by the following steps with power plugged in to the board:"
echo ""
echo "1. Remove the eMMC jumper near the Recovery button. Do not lose it."
echo "2. Plug in the USB A-A cable to the top USB2 port on the R64, and the other into the"
echo "   system running SADIE."
echo "3. Press and hold the Reset Button."
echo "4. While still holding Reset, press and hold the Recovery Button."
echo "5. Release the Reset Button, but keep holding Recovery for at least three seconds."
echo ""
echo "WARNING: IF YOU HAVE AN SD CARD PLUGGED IN, IT WILL BE OVERWRITTEN INSTEAD AND"
echo "ALL DATA ON THE CARD WILL BE LOST."
echo ""
read -rsp $'Press any key to continue...\n' -n 1 key

rkflashtool n &> temprk
if grep "interface claimed" temprk ; then
	echo "Rock64 confirmed to be in Loader Mode!"
else
	loadermode="unready"
	while [ "$loadermode" = "unready" ] ; do
		echo "Rock64 is not in Loader Mode. Please follow the steps and try again."
		read -rsp $'Press any key...\n' -n 1 key
		rkflashtool n &> temprk
		if grep "interface claimed" temprk > /dev/null ; then
		        echo "Rock64 confirmed to be in Loader Mode!"
			loadermode="ready"
		fi
	done
fi 

if (dialog --backtitle "$BACKTITLE" --title "Ready to Flash" --yesno "SADIE is ready to flash Android onto your Rock64. Continue?" 20 60) then
	cd $IMAGEDIR
	rkinstall
else
	echo "Exiting without flashing."
fi
echo ""
echo "Flash is complete! Your Rock64 now should be booting into Android! It will take some time for it to boot first time."
echo "Enjoy your system. :)"
