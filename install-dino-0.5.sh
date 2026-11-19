#!/bin/bash

# this script will download (clone git repo), compile and install dino 
# on the following (tested distributions), the distribution is detected automatically
# - ubuntu
# - linuxmint
# - fedora
# - endeavouros
# - it will integrate in kde, gnome and cinnamon desktop environments automatically

# dino donwload, cloned, build directory
DINO_BUILD_DIR_NAME="dino"

# check the distro by reading the  
DISTRO=$(source /etc/os-release && echo "$ID")

# set the script to case insensitive string comparison, to avoid
# incompatibilities 
shopt -s nocasematch

################################################################################
# set distro specific settings for the installations
# mostly different package names and packagers

case "$DISTRO" in
    "ubuntu"|"linuxmint")
        DYNAMIC_LIB_PATH="/usr/local/lib"
        PACKAGE_INSTALL_COMMAND=(apt install -y)
        PACKAGE_QUERY_COMMAND=()
        DEPS=(ninja-build
            valac 
            gettext
            libgee-0.8-dev
            libsqlite3-dev
            libgtk-4-dev
            libadwaita-1-0
            libgpgme-dev
            libsoup2.4-dev
            libgcrypt20-dev
            libqrencode-dev
            libgstreamer1.0-dev
            libgstreamer-plugins-base1.0-dev
            libwebrtc-audio-processing-dev
            libsrtp2-dev
            libnice-dev
            glib-networking
            gstreamer1.0-plugins-good
            libadwaita-1-dev
            meson
            libomemo-c-dev
            git
        )
    ;;

    "fedora") 
        DYNAMIC_LIB_PATH="/usr/local/lib64"
        PACKAGE_INSTALL_COMMAND=(dnf install -y --refresh --skip-unavailable)
        PACKAGE_QUERY_COMMAND=(rpm -q --whatprovides)
        DEPS=(meson
        gcc-c++ 
        cmake 
        gpgme-devel 
        gtk4-devel 
        libadwaita-devel
        libnotify-devel
        libgcrypt-devel
        pkgconfig
        vala
        git
        openssl-devel
        gnutls-devel
        libomemo-c-devel
        protobuf-c-devel
        'pkgconfig(gee-0.8)'
        'pkgconfig(gio-2.0)'
        'pkgconfig(glib-2.0)'
        'pkgconfig(gthread-2.0)'
        'pkgconfig(gtk+-3.0)'
        'pkgconfig(libsoup-2.4)'
        'pkgconfig(sqlite3)'
        'pkgconfig(libqrencode)'
        'pkgconfig(gstreamer-1.0)'
        'pkgconfig(gstreamer-app-1.0)'
        'pkgconfig(gstreamer-audio-1.0)'
        'pkgconfig(gstreamer-rtp-1.0)'
        'pkgconfig(gstreamer-video-1.0)'
        'pkgconfig(nice)'
        'pkgconfig(libsrtp2)'
        'pkgconfig(webrtc-audio-processing'
        )
    ;;

    "endeavouros")
        DYNAMIC_LIB_PATH="/usr/local/lib"
        PACKAGE_INSTALL_COMMAND=(pacman -Sy --noconfirm --needed)
        PACKAGE_QUERY_COMMAND=(pacman -Q)
        DEPS=(base-devel
            gcc
            git
            meson
            gettext
            glib2
            gtk4
            icu
            'libgee>=0.10'
            qrencode
            ninja
            sqlite
            vala
            gpgme
            libgcrypt
            libsrtp
            glib-networking
            libnice
            gst-plugins-good
            gst-plugins-bad
            gst-plugins-ugly
            libadwaita
            gstreamer
            gst-plugins-base
            libomemo-c
        )
            
    ;;

    *)
    echo "Distro $DISTRO not supported. Stopping."
    exit
;;

esac

###############################################################################

printf "Comparing installed / required packages"
missing=()

for requirement in "${DEPS[@]}"; do
  if ! "$PACKAGE_QUERY_COMMAND" "$requirement" >/dev/null 2>&1; then
    missing+=("$requirement")
  fi
done

if ((${#missing[@]} == 0)); then
  echo "All required pkgconfig dependencies are installed."
  exit 0
fi

printf 'Missing requirements:\n'
printf '  - %s\n' "${missing[@]}"

read -r -p "Install them now? [y/N] " answer
case "$answer" in
  [yY]|[yY][eE][sS])
    ;;
  *)
    echo "Installation cancelled."
    exit
    ;;
esac

# Install packages (only needed ones to avoid reinstalling) 
sudo "${PACKAGE_INSTALL_COMMAND[@]}" "${missing[@]}"

printf "Removing dino build files from previous run\n"
rm -rf "$DINO_BUILD_DIR_NAME" 2>/dev/null

# Clone the Dino GitHub repository
printf "Clone the latest Dino version from GitHub repo into the working directory $DINO_BUILD_DIR_NAME\n"
git clone https://github.com/dino/dino.git $DINO_BUILD_DIR_NAME 
cd $DINO_BUILD_DIR_NAME

# Prepare the build process
printf "Prepare the build\n"
meson setup \
  --reconfigure \
   build \
  -Drtp-h264=true \
  -Drtp-vaapi=true \
  -Drtp-msdk=true \
  --wipe 

# Build Dino
printf "Build Dino from source\n"
meson compile -C build 

# Install Dino
printf "Install Dino\n"
sudo meson install -C build --no-rebuild 
printf "adding dino libs to the dynamic linker library\n"
echo "$DYNAMIC_LIB_PATH" | sudo tee -a /etc/ld.so.conf.d/local.conf > /dev/null
sudo ldconfig

printf "Finished installing Dino\n"
printf "You can type 'dino' in the terminal or find dino the distributions
application list\n"