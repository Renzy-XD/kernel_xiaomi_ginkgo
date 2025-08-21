#!/bin/bash

case "$1" in
    -k) VARIANT="KSU" ;;
    -v) VARIANT="Vanilla" ;;
    *) VARIANT="Vanilla" ;;
esac

KERNEL_NAME="Kazuya Kernel"
NAME_KERNEL="Kazuya"
BASE="pelt/main"
ANDROID="12-15"
KERNEL_DIR="$PWD"
IMG="$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb"
DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"
KBUILD_COMPILER_STRING=$(/workspace/renzy/toolchain/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
AK3_DIR="/workspace/renzy/AnyKernel3"
PHONE="Redmi Note 8"
DEVICE="Ginkgo"
CHAT_ID="5479672033"
TOKEN="8485647929:AAEJ9daOIX1UZdecHhy9OXf8KOz_Z-zqpSg"
TG_URL="https://api.telegram.org/bot$TOKEN"
ZIP_NAME="${NAME_KERNEL}-${DEVICE}-${VARIANT}-$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M").zip"

cleaned() {
    if [ -d "$AK3_DIR" ]; then
        rm -f "$AK3_DIR"/Image* "$AK3_DIR"/dtbo*.img
        rm -f "$AK3_DIR"/*.zip
        echo "Cleaned old kernel files (Image, dtbo, zip)"
    else
        echo "Error: AnyKernel3 directory not found!"
        exit 1
    fi
}

copy() {
    for file in "$IMG" "$DTBO"; do
        if [ -f "$file" ]; then
            echo "Copy [$file] to AnyKernel3..."
            cp "$file" "$AK3_DIR"
        else
            echo "Error: $file not found"
            exit 1
        fi
    done
}

main() {
    echo -e "\nCreate ZIP file for variant: $VARIANT..."
    cd "$AK3_DIR" || exit
    zip -r9 "$ZIP_NAME" ./*
    echo -e "\nSuccessfully created $ZIP_NAME"
}

push() {
    curl -s -F document=@"$AK3_DIR/$ZIP_NAME" "$TG_URL/sendDocument" \
        -F chat_id="$CHAT_ID" \
        -F caption="Designed For Performance\nDevice: $DEVICE" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=HTML" >/dev/null
    echo "ZIP $ZIP_NAME sent successfully"
}

sendInfo() {
    curl -s -X POST "$TG_URL/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d parse_mode=HTML \
        -d text="$(cat <<EOF
<b>------ ${KERNEL_NAME} ------</b>
<b>Device:</b> $PHONE
<b>Name:</b> $NAME_KERNEL
<b>Base:</b> $BASE
<b>Variant:</b> $VARIANT
<b>Android:</b> $ANDROID
<b>Commit:</b> $(git log -1 --pretty=format:'%h : %s')
<b>Compiler:</b> $KBUILD_COMPILER_STRING
EOF
)" >/dev/null
    echo "Build info sent successfully"
}

end() {
    echo "All Done."
    exit 0
}

sendInfo
cleaned
copy
main
push
end
