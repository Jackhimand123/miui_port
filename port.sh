#!/bin/bash

# miui_port project for Raphael (K20 Pro)
# Target: HyperOS 3.0 (Android 16)
# Optimization: Extreme Gaming & Stability

BASEROM="$1"
PORTROM="$2"

export PATH=$(pwd)/bin/$(uname)/$(uname -m)/:$PATH

# Colors
Error() { echo -e \[$(date +%m%d-%T)\] "\e[1;31m"$@"\e[0m"; }
Yellow() { echo -e \[$(date +%m%d-%T)\] "\e[1;33m"$@"\e[0m"; }
Green() { echo -e \[$(date +%m%d-%T)\] "\e[1;32m"$@"\e[0m"; }

# --- DOWNLOAD & EXTRACTION ---
# [Logic remains the same to handle $1 and $2]

# --- RAPHAEL HYPEROS 3 MODS START ---
Yellow "Injecting HyperOS 3 Gaming Engine..."

# 1. New HyperOS Performance Daemons (Replacing Joyose)
# HyperOS 3 uses 'metis' and updated 'thermal' paths
rm -rf PORTROM/images/product/app/Joyose
rm -rf PORTROM/images/product/priv-app/Joyose
rm -rf PORTROM/images/system/system/app/MiuiVideo
rm -rf PORTROM/images/system/system/app/MiBrowser

# 2. Android 16 Boot & Kernel Patching
# Android 16 often requires 'metadata' and 'checkpoint' flags removed for old vendors
for fstab in $(find BASEROM/images/vendor/etc/ -name "fstab.qcom"); do
    sed -i 's/fileencryption=ice/encryptable=footer/g' $fstab
    sed -i 's/,checkpoint=fs//g' $fstab
done

# 3. GPU & Touch Response (HyperOS 3 Optimized)
target_prop="BASEROM/images/system/system/build.prop"
{
    echo "# HyperOS 3 Raphael Gaming Edition"
    echo "debug.renderengine.backend=skiagl"
    echo "persist.sys.composition.type=gpu"
    echo "ro.surface_flinger.max_frame_buffer_acquired_stores=4"
    echo "touch.pressure.scale=0.001"
    echo "persist.vendor.qti.games.gt.prof=1"
    echo "ro.config.low_ram=false"
    echo "persist.sys.performance_level=3" # Force High Perf Mode
} >> "$target_prop"

# 4. Thermal Thresholds (Android 16 compatibility)
for thermal in $(find BASEROM/images/vendor/etc/ -type f -name "thermal-engine.conf"); do
    sed -i 's/sampling 5000/sampling 10000/g' $thermal
    sed -i 's/thresholds 45000/thresholds 58000/g' $thermal 
done
# --- RAPHAEL HYPEROS 3 MODS END ---

Green "HyperOS 3 Port Prepared for Raphael!"
