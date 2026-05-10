#!/bin/bash

# this script will installdino in $DINO_TARGET_DIR

# dino build directory
DINO_TARGET_DIR="/opt/dino"
DINO_BUILD_DIR_NAME="dino"

# dependencies for dino
DEPS="webrtc-audio-processing libomemo-c"
# dependencies for building dino from source
BUILD_ENV="base-devel gcc meson gettext glib2 gtk4 icu libgee qrencode ninja sqlite vala gpgme libgcrypt libsrtp glib-networking libnice libsoup gst-plugins-good gst-plugins-bad gst-plugins-ugly"

## functions

## returns false (0) if anything other then gnome desktop env is used
## else true (1)
## thanks to: https://github.com/alexeevdv/dename
function isGnome()
{
    ps -e | grep -E '^.* gnome-session$' > /dev/null
    if [ $? -ne 0 ];
        then
        return 0
    fi
    return 1
}

printf "Install arch-based dependencies to install dino \n"

# install packages (only needed ones to avoid reinstalling)
sudo pacman -S --noconfirm --needed $DEPS $BUILD_ENV > compile-dino.log 2>&1

# clone the dino github repository
printf "Clone the latest dino version from github repo into the working directoy $DINO_BUILD_DIR_NAME\n"
git clone https://github.com/dino/dino.git $DINO_BUILD_DIR_NAME >> compile-dino.log 2>&1
cd $DINO_BUILD_DIR_NAME
# prepare the build process
printf "Prepapre the build\n"
meson setup build \
 -Dplugin-rtp-h264=enabled -Dplugin-rtp-vaapi=enabled -Dplugin-rtp-vp9=disabled -Dplugin-rtp-msdk=enabled -Dplugin-rtp-webrtc-audio-processing=enabled \
    --wipe >> compile-dino.log 2>&1
# actual build dino
printf "build dino from source\n"
meson compile -C build >> compile-dino.log 2>&1

# copy desktop file and icon to the system cache
printf "copy desktop file and icons to system, to make dino available in the desktop environment\n"
sudo cp main/data/im.dino.Dino.desktop /usr/share/applications/
sudo cp main/data/icons/scalable/apps/im.dino.Dino.svg /usr/share/icons/hicolor/scalable/apps/

# create install diectory
sudo mkdir -p $DINO_TARGET_DIR
# copy bin/run files into the target dir 
sudo cp -r build/* $DINO_TARGET_DIR/
# make it available in the path
sudo ln -sf $DINO_TARGET_DIR/main/dino /usr/bin/dino 

# for gnome desktop update the icon cache and desktop database
# to make dino available in the application overview and search
if isGnome; then
    sudo update-desktop-database /usr/share/applications/
    sudo gtk-update-icon-cache /usr/share/icons/hicolor/ >> compile-dino.log 2>&1
fi
printf "Finished installing dino\n"