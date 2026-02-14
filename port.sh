#!/bin/bash

# Configuration for Raphael (K20 Pro) - HyperOS 3.0 / A16
BASEROM="$1"
PORTROM="$2"

export PATH=$(pwd)/bin/$(uname)/$(uname -m)/:$PATH

# Colors
Yellow() { echo -e \[$(date +%m%d-%T)\] "\e[1;33m"$@"\e[0m"; }
Green() { echo -e \[$(date +%m%d-%T)\] "\e[1;32m"$@"\e[0m"; }

# --- CLEANUP & PREP ---
Yellow "Preparing Workspace..."
rm -rf BASEROM/ PORTROM/ images/ *.zip
mkdir -p BASEROM/images/ PORTROM/images/ images/

# --- DOWNLOAD ---
Yellow "Downloading ROMs..."
# Using -L for redirects and -A for browser impersonation
aria2c -s16 -x16 -L -A "Mozilla/5.0" -o base.zip "$BASEROM"
aria2c -s16 -x16 -L -A "Mozilla/5.0" -o port.zip "$PORTROM"

# --- EXTRACTION ---
Yellow "Extracting ROMs..."
unzip -q base.zip payload.bin -d BASEROM/
payload-dumper-go -o BASEROM/images/ BASEROM/payload.bin

unzip -q port.zip payload.bin -d PORTROM/
payload-dumper-go -o PORTROM/images/ PORTROM/payload.bin

# --- EXTREME DEBLOAT (Mandatory for K20 Pro Space) ---
Yellow "Debloating Rodin System for Space..."
# Product Partition Cleanup
rm -rf PORTROM/images/product/app/XiaomiVideo
rm -rf PORTROM/images/product/app/MiBrowserGlobal
rm -rf PORTROM/images/product/app/Mipay
rm -rf PORTROM/images/product/app/MSA
rm -rf PORTROM/images/product/priv-app/Joyose
# System Partition Cleanup
rm -rf PORTROM/images/system/system/app/Keep
rm -rf PORTROM/images/system/system/app/Editors

# --- ANDROID 16 PATCHES ---
Yellow "Applying Android 16 Mount & Encryption Patches..."
for fstab in $(find BASEROM/images/vendor/etc/ -name "fstab.qcom"); do
    sed -i 's/fileencryption=ice/encryptable=footer/g' $fstab
done

# --- PERFORMANCE TWEAKS ---
target_prop="BASEROM/images/system/system/build.prop"
{
    echo "persist.vendor.qti.games.gt.prof=1"
    echo "persist.sys.performance_level=3"
    echo "ro.config.low_ram=false"
} >> "$target_prop"

# --- REPACKING ---
Yellow "Repacking Super.img (9.1GB Limit)..."
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

# Copying critical boot files
cp BASEROM/images/boot.img images/
cp BASEROM/images/dtbo.img images/
cp BASEROM/images/vbmeta*.img images/

# --- FINAL ZIP ---
Yellow "Creating Flashable Zip..."
cd images/
zip -r ../Raphael_HOS3_A16_Final.zip ./*
cd ..

Green "Build Successful!"
