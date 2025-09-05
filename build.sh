#!/usr/bin/env bash
#
# Copyright (C) 2023 Edwiin Kusuma Jaya (ryuzenn)
#
# Simple Local Kernel Build Script
#
# Configured for Redmi Note 8 / ginkgo custom kernel source
#
# Setup build env with akhilnarang/scripts repo
#
# Use this script on root of kernel directory

SECONDS=0 # builtin bash timer
kernel_dir="${PWD}"
CCACHE=$(command -v ccache)
objdir="${kernel_dir}/out"
LOCAL_DIR="/workspace/renzy"
TC_DIR="${LOCAL_DIR}/toolchain"
CLANG_DIR="${TC_DIR}/aosp-clang"
ARCH_DIR="${TC_DIR}/aarch64-linux-android-4.9"
ARM_DIR="${TC_DIR}/arm-linux-androideabi-4.9"
export DEFCONFIG="vendor/ginkgo_defconfig"
export ARCH="arm64"
export PATH="$CLANG_DIR/bin:$ARCH_DIR/bin:$ARM_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$CLANG_DIR/lib:$LD_LIBRARY_PATH"
export KBUILD_BUILD_VERSION="1"

setup() {
  if ! [ -d "${CLANG_DIR}" ]; then
      echo "Clang not found! Cloning to ${TC_DIR}..."
      if ! git clone --depth=1 -b master https://gitlab.com/aosp-clang/r498229b "${CLANG_DIR}"; then
          echo "Cloning failed! Aborting..."
          exit 1
      fi
  fi

  if ! [ -d "${ARCH_DIR}" ]; then
      echo "gcc not found! Cloning to ${ARCH_DIR}..."
      if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git ${ARCH_DIR}; then
          echo "Cloning failed! Aborting..."
          exit 1
      fi
  fi

  if ! [ -d "${ARM_DIR}" ]; then
      echo "gcc_32 not found! Cloning to ${ARM_DIR}..."
      if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git ${ARM_DIR}; then
          echo "Cloning failed! Aborting..."
          exit 1
      fi
  fi

  if [[ $1 = "-k" || $1 = "--ksu" ]]; then
      echo -e "\nCleanup KernelSU first on local build\n"
      rm -rf KernelSU drivers/kernelsu

      echo -e "\nKSU Support, let's Make it On\n"
      curl -kLSs "https://raw.githubusercontent.com/SukiSU-Ultra/SukiSU-Ultra/main/kernel/setup.sh" | bash -s susfs-main

      sed -i 's/CONFIG_KSU=n/CONFIG_KSU=y/g' arch/arm64/configs/vendor/ginkgo_defconfig
    sed -i 's/CONFIG_KSU_MANUAL_HOOK=n/CONFIG_KSU_MANUAL_HOOK=y/g' arch/arm64/configs/vendor/ginkgo_defconfig
  else
      echo -e "\nKSU not Support, let's Skip\n"
  fi
}

clean_build() {
    echo -e "\nStarting build clean-up..."

    if [ -d "${objdir}" ]; then
        echo "Clean up old build output..."
        rm -rf "${objdir}" || { echo "Failed to remove old build output!"; exit 1; }
    else
        echo "No previous build output found."
    fi

  if [ -f "${kernel_dir}/.config" ]; then
      echo "Clean up kernel configuration files..."
      make mrproper -C "${kernel_dir}" || { echo "make mrproper failed!"; exit 1; }
  else
      echo "No existing .config file found, skipping make mrproper."
  fi

    echo "Build clean-up completed!"
}

make_defconfig() {
    echo -e "\nGenerating defconfig..."
    make -s ARCH=${ARCH} O=${objdir} ${DEFCONFIG} -j$(nproc --all)
    if [ $? -ne 0 ]; then
        echo -e "Failed to generate defconfig"
        exit 1
    fi
}

compile() {
cd ${kernel_dir}
echo -e "Starting compilation...\n"
make -j$(nproc --all) \
       O=${objdir} \
       ARCH=arm64 \
       CC=clang \
       LD=ld.lld \
       AR=llvm-ar \
       AS=llvm-as \
       NM=llvm-nm \
       OBJCOPY=llvm-objcopy \
       OBJDUMP=llvm-objdump \
       STRIP=llvm-strip \
       CROSS_COMPILE=$ARCH_DIR/bin/aarch64-linux-android- \
       CROSS_COMPILE_ARM32=$ARM_DIR/bin/arm-linux-androideabi- \
       CLANG_TRIPLE=aarch64-linux-gnu- \
       Image.gz-dtb \
       dtbo.img \
       CC="${CCACHE} clang" \
       $1
}

completion() {
  local image="${objdir}/arch/arm64/boot/Image.gz-dtb"
  local dtbo="${objdir}/arch/arm64/boot/dtbo.img"

  if [[ -f ${image} && -f ${dtbo} ]]; then
  echo -e "\nKernel compiled succesfully!"
  echo -e "Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
  else
  echo -e "\nCompilation failed!"
  exit 1
  fi
}

setup "$@"
clean_build
make_defconfig
compile
completion
