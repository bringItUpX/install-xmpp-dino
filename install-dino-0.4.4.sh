#!/bin/bash

sudo apt install make cmake valac gettext libgtk-4-1 libadwaita-1-dev  libglib2.0-dev libgee-0.8-dev ninja-build libsqlite3-dev libgcrypt20-dev  libsrtp2-dev  libsignal-protocol-c-dev  glib-networking libnice-dev  libsoup-3.0-dev  gstreamer1.0-x libwebrtc-audio-processing-dev libqrencode4 git libqrencode4 qrencode  libqrencode-dev  libgpgme-dev libsrtp2-dev glib-networking libgcrypt20-dev libsignal-protocol-c-dev  libnice-dev libsoup-2.4-1  libsoup2.4-dev libsoup-3.0-dev  libwebrtc-audio-processing-dev gstreamer1.0-rtsp  gstreamer1.0-plugins-base  gstreamer1.0-plugins-bad gstreamer1.0-libav libgstreamer1.0-dev  libgstreamer-plugins-base1.0-dev
echo
echo "You need a configured git, in order to clone the following dino repo: https://github.com/dino/dino.git"
echo
git clone https://github.com/dino/dino.git -b v0.4.4
cd dino
./configure
make
echo
echo "if the above compiling was successful you will find the dino binary ander the ./dino/build directory"
