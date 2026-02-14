#!/bin/bash

# miui_port project for Raphael (K20 Pro)
# Optimized for SourceForge & Mirror redirects

BASEROM="$1"
PORTROM="$2"

export PATH=$(pwd)/bin/$(uname)/$(uname -m)/:$PATH

# Colors
Yellow() { echo -e \[$(date +%m%d-%T)\] "\e[1;33m"$@"\e[0m"; }
Green() { echo -e \[$(date +%m%d-%T)\] "\e[1;32m"$@"\e[0m"; }

# --- DOWNLOAD LOGIC ---
Yellow "Cleaning up workspace..."
rm -rf BASEROM/ PORTROM/ images/ *.zip
mkdir -p BASEROM/images/ PORTROM/images/ images/

# Use wget for Base ROM (Better at handling the redirect from xiaomistockrom)
if [ ! -f "base.zip" ]; then
    Yellow "Downloading Base ROM via wget..."
    wget -U "Mozilla/5.0" -O base.zip "${BASEROM}"
fi

# Use aria2c for Port ROM (SourceForge usually works with direct URL + user agent)
if [ ! -f "port.zip" ]; then
    Yellow "Downloading Port ROM via aria2c..."
    aria2c --user-agent="Mozilla/5.0" -s10 -x10 -o port.zip "${PORTROM}"
fi

# --- EXTRACTION ---
Yellow "Extracting ROMs..."
# Base
unzip -q base.zip payload.bin -d BASEROM/ || unzip -q base.zip "images/*" -d BASEROM/
if [ -f "BASEROM/payload.bin" ]; then
    payload-dumper-go -o BASEROM/images/ BASEROM/payload.bin
fi

# Port
unzip -q port.zip payload.bin -d PORTROM/ || unzip -q port.zip "images/*" -d PORTROM/
if [ -f "PORTROM/payload.bin" ]; then
    payload-dumper-go -o PORTROM/images/ PORTROM/payload.bin
fi

# --- VERIFY FILES ---
if [ ! -f "PORTROM/images/system.img" ]; then
    echo "ERROR: Extraction failed. Images not found."
    exit 1
fi

# --- MODS & REPACK ---
Yellow "Applying Raphael Gaming Mods..."
# (Keeping your existing performance tweaks here)
target_prop="BASEROM/images/system/system/build.prop"
echo "persist.vendor.qti.games.gt.prof=1" >> "$target_prop"
echo "persist.sys.performance_level=3" >> "$target_prop"

Yellow "Generating Super.img..."
system_size=$(stat -c%s PORTROM/images/system.img)
product_size=$(stat -c%s PORTROM/images/product.img)
system_ext_size=$(stat -c%s PORTROM/images/system_ext.img)
vendor_size=$(stat -c%s BASEROM/images/vendor.img)
odm_size=$(stat -c%s BASEROM/images/odm.img)

group_size=$((system_size + product_size + system_ext_size + vendor_size + odm_size + 104857600))

lpmake --metadata-size 65536 --super-name super --metadata-slots 2 --device super:9126805504 \
       --group raphael_dynamic_partitions:$group_size \
       --partition system:readonly:$system_size:raphael_dynamic_partitions --image system=PORTROM/images/system.img \
       --partition product:readonly:$product_size:raphael_dynamic_partitions --image product=PORTROM/images/product.img \
       --partition system_ext:readonly:$system_ext_size:raphael_dynamic_partitions --image system_ext=PORTROM/images/system_ext.img \
       --partition vendor:readonly:$vendor_size:raphael_dynamic_partitions --image vendor=BASEROM/images/vendor.img \
       --partition odm:readonly:$odm_size:raphael_dynamic_partitions --image odm=BASEROM/images/odm.img \
       --sparse --output images/super.img

cp BASEROM/images/boot.img images/
cp BASEROM/images/dtbo.img images/
cp BASEROM/images/vbmeta*.img images/

Yellow "Finalizing ZIP..."
cd images/
zip -r ../Raphael_HyperOS3_A16.zip ./*
cd ..

Green "Build Successful! File: Raphael_HyperOS3_A16.zip"
