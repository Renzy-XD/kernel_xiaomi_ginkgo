#!/usr/bin/env bash
#
# Use this script on root of kernel directory

SECONDS=0 # builtin bash timer
ZIPNAME="Neophyte-Reborn-A10-Ginkgo-$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M").zip"
TC_DIR="$(pwd)/../tc/"
CLANG_DIR="${TC_DIR}clang"
AK3_DIR="$HOME/AnyKernel3"
DEFCONFIG="vendor/ginkgo_defconfig"

export PATH="$CLANG_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$CLANG_DIR/lib:$LD_LIBRARY_PATH"
export KBUILD_BUILD_VERSION="1"
export LOCALVERSION

if ! [ -d "${CLANG_DIR}" ]; then
echo "Clang not found! Cloning to ${TC_DIR}..."
if ! git clone --depth=1 -b main https://gitlab.com/Panchajanya1999/azure-clang ${CLANG_DIR}; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out \
					  ARCH=arm64 \
					  CC=clang \
					  LD=ld.lld \
					  AR=llvm-ar \
					  AS=llvm-as \
					  NM=llvm-nm \
					  OBJCOPY=llvm-objcopy \
					  OBJDUMP=llvm-objdump \
					  STRIP=llvm-strip \
					  CROSS_COMPILE=aarch64-linux-gnu- \
					  CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
					  Image.gz-dtb \
					  dtbo.img

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
echo -e "\nKernel compiled succesfully! Zipping up...\n"
if [ -d "$AK3_DIR" ]; then
cp -r $AK3_DIR AnyKernel3
elif ! git clone -q https://github.com/k4ngcaribug/AnyKernel3; then
echo -e "\nAnyKernel3 repo not found locally and cloning failed! Aborting..."
exit 1
fi
cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
cp out/arch/arm64/boot/dtbo.img AnyKernel3
rm -f *zip
cd AnyKernel3
git checkout main &> /dev/null
zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
cd ..
rm -rf AnyKernel3
rm -rf out/arch/arm64/boot
echo -e "Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
echo "Zip: $ZIPNAME"
else
echo -e "\nCompilation failed!"
fi
echo -e "======================================="
