#!/bin/bash
# Edit by Renzy

VARIANT="${1:-}"
[ "$VARIANT" = "-k" ] && VARIANT="KSUNext" || VARIANT=""
VARIANT_INFO=${VARIANT:-Vanilla}

KERNEL_DIR="$PWD"
KERNEL_NAME="Kazuya Kernel"
NAME_KERNEL="Kazuya"
BASE="Rebase×Pelt"
ANDROID="12-15"
VERSI="v1.2"
DEVICE="Redmi Note 8"
CODENAME="Ginkgo"
CHAT_ID="5479672033"
TOKEN="8485647929:AAEJ9daOIX1UZdecHhy9OXf8KOz_Z-zqpSg"
TG_URL="https://api.telegram.org/bot$TOKEN"
IMG="$KERNEL_DIR/out/arch/arm64/boot/Image.gz-dtb"
DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"
AK3_DIR="/workspace/renzy/AnyKernel3"
TOOLCHAIN="/workspace/renzy/toolchain/clang/bin"
COMPILER=$(${TOOLCHAIN}/clang --version | head -n1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')
LLD_VER=$(${TOOLCHAIN}/ld.lld --version 2>/dev/null | head -n1 | awk '{print $2}')
LINUX_VER=$(make kernelversion 2>/dev/null)
COMMIT=$(git log -1 --pretty=format:'%h : %s')
ZIP_NAME="${NAME_KERNEL}-${VERSI}-${CODENAME}"
[ -n "$VARIANT" ] && ZIP_NAME+="-${VARIANT}"
ZIP_NAME+="-$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M").zip"

cleaned() {
    if [ -d "$AK3_DIR" ]; then
        rm -f "$AK3_DIR"/Image* "$AK3_DIR"/dtbo*.img "$AK3_DIR"/*.zip
        echo "Cleaned old kernel files"
    else
        echo "Error: AnyKernel3 directory not found!"
        exit 1
    fi
}

copy() {
    for file in "$IMG" "$DTBO"; do
        [ -f "$file" ] || { echo "Error: $file not found!"; exit 1; }
        echo "Copy [$file] to AnyKernel3..."
        cp "$file" "$AK3_DIR"
    done
}

main() {
    echo -e "\nCreating ZIP file${VARIANT:+ for variant: $VARIANT}..."
    cd "$AK3_DIR" || { echo "AK3 directory not found!"; exit 1; }
    zip -r9 "./$ZIP_NAME" * -x "*.git*" "README.md" >/dev/null
    echo "Successfully created $ZIP_NAME"
}

push() {
    echo "Sending $ZIP_NAME to Telegram..."
    curl -s -F document=@"$AK3_DIR/$ZIP_NAME" "$TG_URL/sendDocument" \
        -F chat_id="$CHAT_ID" \
        -F caption="It's time to brick | $CODENAME" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=HTML" >/dev/null
    echo "$ZIP_NAME sent successfully"
}

sendInfo() {
    MESSAGE=""
    for POST in "$@"; do
        MESSAGE+="${POST}\n"
    done
    curl -s -X POST "$TG_URL/sendMessage" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"$CHAT_ID\",
            \"parse_mode\": \"HTML\",
            \"text\": \"$MESSAGE\"
        }" >/dev/null
}

sendInfo \
  "<b>------ ${KERNEL_NAME} ------</b>" \
  "<b>Device:</b> <code>${DEVICE}</code>" \
  "<b>Name:</b> <code>${NAME_KERNEL}</code>" \
  "<b>Versi:</b> <code>${VERSI}</code>" \
  "<b>Base:</b> <code>${BASE}</code>" \
  "<b>Variant:</b> <code>${VARIANT_INFO}</code>" \
  "<b>Android:</b> <code>${ANDROID}</code>" \
  "<b>Kernel Version:</b> <code>${LINUX_VER}</code>" \
  "<b>Commit:</b> <code>${COMMIT}</code>" \
  "<b>Compiler:</b> <code>${COMPILER}</code>" \
  "<b>Linker:</b> <code>LLD ${LLD_VER}</code>"

sendInfo
cleaned
copy
main
push

echo "All done."
exit 0
