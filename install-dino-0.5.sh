#!/bin/bash

# this script will download (clone git repo), compile and install dino 
# on the following (tested distributions), the distribution is detected automatically
# - ubuntu
# - linuxmint
# - fedora
# - endeavouros
# - it will integrate in kde, gnome and cinnamon desktop environments automatically

# set the script to case insensitive string comparison, to avoid
# incompatibilities 
shopt -s nocasematch
###############################################################################
# output colors
GREEN="\033[1;32m" # green bold
RED="\033[1;31m" # red bold
NC="\033[0m"   # no color / reset

# printing to console helper functions
# prints normal output
printf_info()  { printf '%s%b\n' "$*" "$NC"; }
# prints red, bold output
printf_error() { printf '%b%s%b\n' "$RED" "$*" "$NC" >&2; }
# prints green, bold output
printf_success() { printf '%b%s%b\n' "$GREEN" "$*" "$NC" >&2; }

# Configuration section - set your preferred plugin options here
###############################################################################
# meson build options for dino, taken from the project
# valid values have been added as comment
declare -A MESON_PROJECT_OPTIONS=(
    # ["crypto-backend"]=auto # [auto, openssl, gnu] - prefered crypto backend
    # ["omemo"]=enabled # [enabled, disabled, auto] - end-to-end encryption using OMEMO
    # [openpgp]=auto # [enabled, disabled, auto] - end-to-end encyption using PGP
    # ["plugin-notification-sound"]=disabled # [enabled, disabled, auto] - sound for chat notification
    # ["plugindir"]=dino/plugin # dino plugin directory, relative to libdir
    ["rtp-h264"]=true # [true, false] - voice/video calls
    ["rtp-vaapi"]=true # [true, false] - video accelaeration api
    ["rtp-msdk"]=true # [true, false] - intel mediaSDK
    # ["rtp-v4l2"]=false # [true, false] - V4L2 API (stateful)
    # ["rtp-v4l2-sl"]=false # [true, false] - V4L2 API (stateless)
    ["rtp-vp9"]=false # [true, false] - vp 9 codec
    # ["set-install-rpath"]=false # [true, false] - set rpath of installed binaries to the configured libdir
    ["voice-processing"]=enabled # [auto, enabled, disabled] voice processing
)
# dino download, cloned, build directory
DINO_BUILD_DIR_NAME="dino"

###############################################################################

# check the distro by reading the  
DISTRO=$(source /etc/os-release && echo "$ID")

################################################################################
# set distro specific settings for the installations
# mostly different package names and packagers

PACKAGE_UPDATE_COMMAND=()
PACKAGE_INSTALL_COMMAND=()

case "$DISTRO" in
    "ubuntu"|"linuxmint")
        DYNAMIC_LIB_PATH="/usr/local/lib"
        PACKAGE_UPDATE_COMMAND=("apt update" "apt upgrade -y")
        PACKAGE_INSTALL_COMMAND=(apt install -y)
        PACKAGE_QUERY_COMMAND() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"; }
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
        PACKAGE_UPDATE_COMMAND=("dnf upgrade --refresh")
        PACKAGE_INSTALL_COMMAND=(dnf install -y --refresh --skip-unavailable)
        PACKAGE_QUERY_COMMAND() { rpm -q --whatprovides "$1" >/dev/null 2>&1; }
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
        'pkgconfig(webrtc-audio-processing)'
        )
    ;;

    "endeavouros")
        DYNAMIC_LIB_PATH="/usr/local/lib"
        PACKAGE_UPDATE_COMMAND=("pacman -Syu")
        PACKAGE_INSTALL_COMMAND=(pacman -Sy --noconfirm --needed)
        PACKAGE_QUERY_COMMAND() { pacman -Q "$1" >/dev/null 2>&1; }
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
    exit 1
;;

esac

# Refresh current package repositories and install missing packages 

read -r -p "Update system packages before building and installing Dino (recommended)? [y/N] " answer
case "$answer" in
    [yY]|[yY][eE][sS])
    echo "Updating system packages."
    for upCmd in "${PACKAGE_UPDATE_COMMAND[@]}"; do
        if ! sudo bash -c "$upCmd"; then
            printf_error "Failed: $upCmd. Exiting" >&2
            exit 1
        fi
    done
    ;;
    *)
    printf_error "Package update skipped."
    ;;
esac


# Check for missing packages
printf_info "Checking required packages for building dino..."
missing=()

for requirement in "${DEPS[@]}"; do
    if ! PACKAGE_QUERY_COMMAND "$requirement"; then
        missing+=("$requirement")
    fi
done

# install missing required packages 
if [[ ${#missing[@]} -eq 0 ]]; then
    printf_success "All required packages are installed."
else
    printf_info "Missing requirements:"
    printf '  - %s\n' "${missing[@]}"
    
    read -r -p "Install them now? [y/N] " answer
    case "$answer" in
      [yY]|[yY][eE][sS])
        ;;
      *)
        printf_error "Installation cancelled."
        exit 1
        ;;
    esac

    # Install packages (only needed ones to avoid reinstalling) 
    if ! sudo "${PACKAGE_INSTALL_COMMAND[@]}" "${missing[@]}"; then
        printf_error "Failed to install packages. Exiting."
        exit 1
    fi
fi

# remove previous build files by deleting the build dir to get a 'fresh' version
printf_info "Removing dino build files from previous run"
rm -rf "$DINO_BUILD_DIR_NAME" 2>/dev/null || true

# Clone the Dino GitHub repository
printf_info "Clone the latest Dino version from GitHub repo into the working directory $DINO_BUILD_DIR_NAME"
if ! git clone https://github.com/dino/dino.git "$DINO_BUILD_DIR_NAME"; then
    printf_error "Failed to clone repository. Exiting."
    exit 1
fi

printf_success "Successfully cloned repository"

if ! cd "$DINO_BUILD_DIR_NAME"; then
    FP=$(realpath -m "$DINO_BUILD_DIR_NAME")
    printf_error "Failed to enter cloned repository ("$DINO_BUILD_DIR_NAME"). Exiting."; exit 1
fi

# Prepare the build process
printf_info "Prepare the build"

# Build command with configurable RTP options
MESON_ARGS=(
    "--reconfigure"
    "build"
)

# Add plugin options based on configuration
for option in "${!MESON_PROJECT_OPTIONS[@]}"; do
    MESON_ARGS+=("-D$option=${MESON_PROJECT_OPTIONS[$option]}")
done

MESON_ARGS+=("--wipe")

# run meson set up with the provided arguments, exit when failed
if ! meson setup "${MESON_ARGS[@]}"; then
    printf_error "Meson setup failed. Exiting."
    exit 1
fi

# wait for user input before proceeding with the build
read -r -p "Proceed with building dino from source? [y/N] " answer
case "$answer" in
    [yY]|[yY][eE][sS])
        printf_info "Starting build process..."
        ;;
    *)
        printf_error "Dino installation cancelled."
        exit 1
        ;;
esac

# Build Dino
printf_info "Build Dino from source"
if ! meson compile -C build; then
    printf_error "Build failed. Exiting."
    exit 1
fi

# wait for user input before proceeding with the build
read -r -p "Install dino to the system? [y/N] " answer
case "$answer" in
    [yY]|[yY][eE][sS])
        printf_info "Start installing..."
        ;;
    *)
        printf_error "Dino installation cancelled."
        exit 1
        ;;
esac

# Install Dino to the system
if ! sudo meson install -C build --no-rebuild; then
    printf_error "Installation failed. Exiting."
    exit 1
fi

printf_info "Adding dino libs to the dynamic linker library"
echo "$DYNAMIC_LIB_PATH" | sudo tee -a /etc/ld.so.conf.d/local.conf > /dev/null
sudo ldconfig

printf_success "Finished installing Dino"
printf_success "You can type 'dino' in the terminal or find dino in your distribution's application list"