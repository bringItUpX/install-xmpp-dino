#!/bin/bash
sudo apt install ninja-build valac gettext libgee-0.8-dev libsqlite3-dev libgtk-4-dev libadwaita-1-0 libgpgme-dev libsoup2.4-dev libgcrypt20-dev libqrencode-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libwebrtc-audio-processing-dev libsrtp2-dev libnice-dev glib-networking gstreamer1.0-plugins-good libadwaita-1-dev
sudo apt install meson libomemo-c-dev
git clone https://github.com/dino/dino.git
cd dino
meson setup build -Dplugin-rtp-h264=enabled -Dplugin-rtp-msdk=enabled  -Dplugin-rtp-vaapi=enabled -Dplugin-rtp-vp9=disabled -Dplugin-rtp-webrtc-audio-processing=enabled --wipe
meson compile -C build

echo "If the above ends with success, please start the following file: build/main/dino"
