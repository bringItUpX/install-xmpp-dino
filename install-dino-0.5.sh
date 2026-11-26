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
PACKAGE_QUERY_COMMAND=()
PACKAGE_INSTALL_COMMAND=()

case "$DISTRO" in
    "ubuntu"|"linuxmint")
        DYNAMIC_LIB_PATH="/usr/local/lib"
        PACKAGE_UPDATE_COMMAND=("apt update" "apt upgrade -y")
        PACKAGE_INSTALL_COMMAND=(apt install -y)
        PACKAGE_QUERY_COMMAND=(dpkg -l)
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
        PACKAGE_QUERY_COMMAND=(rpm -q)
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
        PACKAGE_UPDATE_COMMAND=("pacman -Syu")
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
    exit 1
;;

esac

###############################################################################
# Function to check if package is installed 
check_package_installed() {
    local pkg=$1
    if [[ "$PACKAGE_QUERY_COMMAND" == *"rpm -q"* ]]; then
        # For rpm-based systems, use rpm -q
        if ! rpm -q "$pkg" >/dev/null 2>&1; then
            return 1
        fi
    elif [[ "$PACKAGE_QUERY_COMMAND" == *"dpkg -l"* ]]; then
        # For deb-based systems, check if package is installed
        if ! dpkg -l | grep -q "^ii.*$pkg"; then
            return 1
        fi
    else
        # For pacman, use pacman -Q
        if ! pacman -Q "$pkg" >/dev/null 2>&1; then
            return 1
        fi
    fi
    return 0
}

# Refresh current package repositories and install missing packages 

read -r -p "Update system packages before building and installing Dino (recommended)? [y/N] " answer
case "$answer" in
    [yY]|[yY][eE][sS])
    echo "Updating system packages."
    for upCmd in "${PACKAGE_UPDATE_COMMAND[@]}"; do
        if ! sudo bash -c "$upCmd"; then
            echo "Failed: $upCmd. Exiting" >&2
            exit 1
        fi
    done
    ;;
    *)
    echo "Package update skipped."
    ;;
esac


# Check for missing packages
echo "Checking required packages for building dino..."
missing=()

for requirement in "${DEPS[@]}"; do
    if ! check_package_installed "$requirement"; then
        missing+=("$requirement")
    fi
done

# install missing required packages 
if [[ ${#missing[@]} -eq 0 ]]; then
    echo "All required packages are installed."
else
    echo "Missing requirements:"
    printf '  - %s\n' "${missing[@]}"
    
    read -r -p "Install them now? [y/N] " answer
    case "$answer" in
      [yY]|[yY][eE][sS])
        ;;
      *)
        echo "Installation cancelled."
        exit 1
        ;;
    esac

    # Install packages (only needed ones to avoid reinstalling) 
    if ! sudo "${PACKAGE_INSTALL_COMMAND[@]}" "${missing[@]}"; then
        echo "Failed to install packages. Exiting."
        exit 1
    fi
fi

# remove previous build files by deleting the build dir to get a 'fresh' version
echo "Removing dino build files from previous run"
rm -rf "$DINO_BUILD_DIR_NAME" 2>/dev/null || true

# Clone the Dino GitHub repository
echo "Clone the latest Dino version from GitHub repo into the working directory $DINO_BUILD_DIR_NAME"
if ! git clone https://github.com/dino/dino.git "$DINO_BUILD_DIR_NAME"; then
    echo "Failed to clone repository. Exiting."
    exit 1
fi

cd "$DINO_BUILD_DIR_NAME" || exit 1

# Prepare the build process
echo "Prepare the build"

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
    echo "Meson setup failed. Exiting."
    exit 1
fi

# wait for user input before proceeding with the build
read -r -p "Proceed with building dino from source? [y/N] " answer
case "$answer" in
    [yY]|[yY][eE][sS])
        echo "Starting build process..."
        ;;
    *)
        echo "Dino installation cancelled."
        exit 1
        ;;
esac

# Build Dino
echo "Build Dino from source"
if ! meson compile -C build; then
    echo "Build failed. Exiting."
    exit 1
fi

# wait for user input before proceeding with the build
read -r -p "Install dino to the system? [y/N] " answer
case "$answer" in
    [yY]|[yY][eE][sS])
        echo "Start installing..."
        ;;
    *)
        echo "Dino installation cancelled."
        exit 1
        ;;
esac

# Install Dino to the system
if ! sudo meson install -C build --no-rebuild; then
    echo "Installation failed. Exiting."
    exit 1
fi

echo "Adding dino libs to the dynamic linker library"
echo "$DYNAMIC_LIB_PATH" | sudo tee -a /etc/ld.so.conf.d/local.conf > /dev/null
sudo ldconfig

echo "Finished installing Dino"
echo "You can type 'dino' in the terminal or find dino in your distribution's application list"