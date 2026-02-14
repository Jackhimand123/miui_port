#!/bin/bash

# miui_port project for Raphael (K20 Pro)
# Target: HyperOS 3.0 (Android 16)
# Optimization: Extreme Gaming Performance

BASEROM="$1"
PORTROM="$2"

export PATH=$(pwd)/bin/$(uname)/$(uname -m)/:$PATH

# Colors
Yellow() { echo -e \[$(date +%m%d-%T)\] "\e[1;33m"$@"\e[0m"; }
Green() { echo -e \[$(date +%m%d-%T)\] "\e[1;32m"$@"\e[0m"; }

# --- DOWNLOAD LOGIC (Updated for SourceForge) ---
if [ ! -f "${BASEROM}" ] && [[ "$BASEROM" == http* ]]; then
    Yellow "Downloading Base ROM..."
    aria2c --user-agent="Mozilla/5.0" -s16 -x16 -j16 "${BASEROM}"
    BASEROM=$(basename "${BASEROM}")
fi

if [ ! -f "${PORTROM}" ] && [[ "$PORTROM" == http* ]]; then
    Yellow "Downloading Port ROM..."
    # SourceForge requires -L to follow redirects
    aria2c -L --user-agent="Mozilla/5.0" -s16 -x16 -j16 "${PORTROM}"
    PORTROM=$(basename "${PORTROM%%/download}")
fi

# --- EXTRACTION ---
Yellow "Cleaning up workspace..."
rm -rf BASEROM/ PORTROM/ images/ 
mkdir -p BASEROM/images/ PORTROM/images/ images/

Yellow "Extracting Payload..."
unzip -q ${BASEROM} payload.bin -d BASEROM/
payload-dumper-go -o BASEROM/images/ BASEROM/payload.bin
unzip -q ${PORTROM} payload.bin -d PORTROM/
payload-dumper-go -o PORTROM/images/ PORTROM/payload.bin

# --- RAPHAEL GAMING & HYPEROS MODS ---
Yellow "Applying Raphael Gaming & A16 Tweaks..."

# 1. Thermal Mod
for thermal in $(find BASEROM/images/vendor/etc/ -type f -name "thermal-engine.conf"); do
    sed -i 's/sampling 5000/sampling 10000/g' $thermal
    sed -i 's/thresholds 45000/thresholds 58000/g' $thermal 
done

# 2. Performance & UI Smoothness
target_prop="BASEROM/images/system/system/build.prop"
{
    echo "persist.vendor.qti.games.gt.prof=1"
    echo "touch.pressure.scale=0.001"
    echo "persist.sys.composition.type=gpu"
    echo "persist.sys.performance_level=3"
} >> "$target_prop"

# 3. Extreme Debloating (Mandatory for A16 Space)
Yellow "Extreme Debloating for Space..."
rm -rf PORTROM/images/product/app/Joyose
rm -rf PORTROM/images/product/priv-app/Joyose
rm -rf PORTROM/images/product/app/MiuiVideo
rm -rf PORTROM/images/product/app/MiBrowserGlobal
rm -rf PORTROM/images/system/system/app/Keep
rm -rf PORTROM/images/product/priv-app/Mipay
rm -rf PORTROM/images/product/app/MSA

# 4. Android 16 Patch
for fstab in $(find BASEROM/images/vendor/etc/ -name "fstab.qcom"); do
    sed -i 's/fileencryption=ice/encryptable=footer/g' $fstab
done

# --- REPACKING FOR RAPHAEL ---
Yellow "Generating Super.img for Raphael..."

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

Yellow "Zipping flashable ROM..."
cd images/
zip -r ../Raphael_HyperOS3_A16_Gaming.zip ./*
cd ..

Green "Build Successful!"
