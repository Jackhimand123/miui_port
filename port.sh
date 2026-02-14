#!/bin/bash

# miui_port project for Raphael (K20 Pro)
# Target: HyperOS 3.0 (Android 16)
# Optimization: Extreme Gaming Performance

BASEROM="$1"
PORTROM="$2"

export PATH=$(pwd)/bin/$(uname)/$(uname -m)/:$PATH

# Colors
Error() { echo -e \[$(date +%m%d-%T)\] "\e[1;31m"$@"\e[0m"; }
Yellow() { echo -e \[$(date +%m%d-%T)\] "\e[1;33m"$@"\e[0m"; }
Green() { echo -e \[$(date +%m%d-%T)\] "\e[1;32m"$@"\e[0m"; }

# --- DOWNLOAD LOGIC ---
if [ ! -f "${BASEROM}" ] && [ "$(echo $BASEROM |grep http)" != "" ];then
    Yellow "Downloading Base ROM..."
    aria2c --max-download-limit=1024M -s10 -x10 -j10 ${BASEROM}
    BASEROM=$(basename ${BASEROM})
fi

if [ ! -f "${PORTROM}" ] && [ "$(echo ${PORTROM} |grep http)" != "" ];then
    Yellow "Downloading Port ROM..."
    aria2c --max-download-limit=1024M -s10 -x10 -j10 ${PORTROM}
    PORTROM=$(basename ${PORTROM})
fi

# --- EXTRACTION ---
Yellow "Cleaning up workspace..."
rm -rf BASEROM/ PORTROM/ images/ 
mkdir -p BASEROM/images/ PORTROM/images/ images/

Yellow "Extracting Payload..."
unzip ${BASEROM} payload.bin -d BASEROM/
payload-dumper-go -o BASEROM/images/ BASEROM/payload.bin
unzip ${PORTROM} payload.bin -d PORTROM/
payload-dumper-go -o PORTROM/images/ PORTROM/payload.bin

# --- RAPHAEL GAMING & HYPEROS MODS ---
Yellow "Applying Raphael Gaming & A16 Tweaks..."

# 1. Thermal Mod (No FPS Throttling)
for thermal in $(find BASEROM/images/vendor/etc/ -type f -name "thermal-engine.conf"); do
    sed -i 's/sampling 5000/sampling 10000/g' $thermal
    sed -i 's/thresholds 45000/thresholds 58000/g' $thermal 
done

# 2. Performance & UI Smoothness (build.prop)
target_prop="BASEROM/images/system/system/build.prop"
{
    echo "# Raphael Gaming Edition Tweaks"
    echo "persist.vendor.qti.games.gt.prof=1"
    echo "touch.pressure.scale=0.001"
    echo "ro.config.low_ram=false"
    echo "persist.sys.composition.type=gpu"
    echo "debug.cpurendering=true"
    echo "ro.surface_flinger.max_frame_buffer_acquired_stores=4"
    echo "persist.sys.performance_level=3"
} >> "$target_prop"

# 3. Extreme Debloating for Android 16 Space
Yellow "Extreme Debloating for Space..."
rm -rf PORTROM/images/product/app/Joyose
rm -rf PORTROM/images/product/priv-app/Joyose
rm -rf PORTROM/images/product/app/MiuiVideo
rm -rf PORTROM/images/product/app/MiBrowserGlobal
rm -rf PORTROM/images/product/app/XiaomiTrends
rm -rf PORTROM/images/system/system/app/Keep
rm -rf PORTROM/images/product/priv-app/Mipay
rm -rf PORTROM/images/product/app/MSA
rm -rf PORTROM/images/product/priv-app/AnalyticsCore

# 4. Android 16 Compatibility Patch (Vendor fstab)
for fstab in $(find BASEROM/images/vendor/etc/ -name "fstab.qcom"); do
    sed -i 's/fileencryption=ice/encryptable=footer/g' $fstab
done

# --- REPACKING FOR RAPHAEL (SUPER.IMG) ---
Yellow "Generating Super.img for Raphael..."

# Get image sizes
system_size=$(stat -c%s PORTROM/images/system.img)
product_size=$(stat -c%s PORTROM/images/product.img)
system_ext_size=$(stat -c%s PORTROM/images/system_ext.img)
vendor_size=$(stat -c%s BASEROM/images/vendor.img)
odm_size=$(stat -c%s BASEROM/images/odm.img)

# Sum total size with a buffer (100MB)
group_size=$((system_size + product_size + system_ext_size + vendor_size + odm_size + 104857600))

# Execute lpmake (Ensuring images are in the right folder for the flashable zip)
lpmake --metadata-size 65536 \
       --super-name super \
       --metadata-slots 2 \
       --device super:9126805504 \
       --group raphael_dynamic_partitions:$group_size \
       --partition system:readonly:$system_size:raphael_dynamic_partitions --image system=PORTROM/images/system.img \
       --partition product:readonly:$product_size:raphael_dynamic_partitions --image product=PORTROM/images/product.img \
       --partition system_ext:readonly:$system_ext_size:raphael_dynamic_partitions --image system_ext=PORTROM/images/system_ext.img \
       --partition vendor:readonly:$vendor_size:raphael_dynamic_partitions --image vendor=BASEROM/images/vendor.img \
       --partition odm:readonly:$odm_size:raphael_dynamic_partitions --image odm=BASEROM/images/odm.img \
       --sparse \
       --output images/super.img

# Move individual firmware images needed for flash
cp BASEROM/images/boot.img images/
cp BASEROM/images/dtbo.img images/
cp BASEROM/images/vbmeta*.img images/

# --- FINAL ZIP PACKAGE ---
Yellow "Zipping flashable ROM..."
cd images/
zip -r ../Raphael_HyperOS3_A16_Gaming.zip ./*
cd ..

Green "Build Successful! ROM: Raphael_HyperOS3_A16_Gaming.zip"
