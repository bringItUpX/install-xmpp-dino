#!/bin/bash

# this script will install dino

# dino build directory
DINO_BUILD_DIR_NAME="dino"

# dependencies for dino
DEPS="webrtc-audio-processing libomemo-c"
# dependencies for building dino from source
BUILD_ENV="base-devel gcc meson gettext glib2 gtk4 icu libgee qrencode ninja sqlite vala gpgme libgcrypt libsrtp glib-networking libnice libsoup gst-plugins-good gst-plugins-bad gst-plugins-ugly"

printf "Install arch-based dependencies to install dino \n"

# install packages (only needed ones to avoid reinstalling)
sudo pacman -Sy --noconfirm --needed $DEPS $BUILD_ENV > compile-dino.log 2>&1

# clone the dino github repository
printf "Clone the latest dino version from github repo into the working directoy $DINO_BUILD_DIR_NAME\n"
git clone https://github.com/dino/dino.git $DINO_BUILD_DIR_NAME >> compile-dino.log 2>&1
cd $DINO_BUILD_DIR_NAME
# prepare the build process
printf "Prepapre the build\n"
meson setup --reconfigure build \
 -Dplugin-rtp-h264=enabled -Dplugin-rtp-vaapi=enabled -Dplugin-rtp-vp9=enabled -Dplugin-rtp-msdk=enabled -Dplugin-rtp-webrtc-audio-processing=enabled \
 --wipe >> compile-dino.log 2>&1
# actual build dino
printf "build dino from source\n"
meson compile -C build >> compile-dino.log 2>&1

# copy desktop file and icon to the system cache
printf "install dino \n"

sudo meson install -C build --no-rebuild >> compile-dino.log 2>&1
echo '/usr/local/lib' | sudo tee -a /etc/ld.so.conf.d/local.conf >> compile-dino.log 2>&1
sudo ldconfig

printf "Finished installing dino\n"