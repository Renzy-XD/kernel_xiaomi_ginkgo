#!/usr/bin/env bash
# Edit by Renzy

SECONDS=0 # builtin bash timer
kernel_dir="${PWD}"
objdir="${kernel_dir}/out"
builddir="${kernel_dir}/build"
CCACHE=$(command -v ccache)
LOCAL_DIR="/workspace/renzy"
TC_DIR="${LOCAL_DIR}/toolchain"
CLANG_DIR="${TC_DIR}/clang"
GCC_64_DIR="${TC_DIR}/aarch64-linux-android-4.9"
GCC_32_DIR="${TC_DIR}/arm-linux-androideabi-4.9"
export DEFCONFIG="ginkgo_defconfig"
export ARCH="arm64"
export PATH="$CLANG_DIR/bin:$GCC_64_DIR/bin:$GCC_32_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$CLANG_DIR/lib:$LD_LIBRARY_PATH"
export KBUILD_BUILD_VERSION="1"

setup() {
  if ! [ -d "${CLANG_DIR}" ]; then
      echo "Clang not found! Cloning to ${TC_DIR}..."
      if ! git clone --depth=1 -b main https://gitlab.com/aosp-clang/r563880b "${CLANG_DIR}"; then
          echo "Cloning failed! Aborting..."
          exit 1
      fi
  fi

  if ! [ -d "${GCC_64_DIR}" ]; then
      echo "gcc not found! Cloning to ${GCC_64_DIR}..."
      if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git ${GCC_64_DIR}; then
          echo "Cloning failed! Aborting..."
          exit 1
      fi
  fi

  if ! [ -d "${GCC_32_DIR}" ]; then
      echo "gcc_32 not found! Cloning to ${GCC_32_DIR}..."
      if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git ${GCC_32_DIR}; then
          echo "Cloning failed! Aborting..."
          exit 1
      fi
  fi

  if [[ $1 = "-k" || $1 = "--ksu" ]]; then
      echo -e "\nCleanup KernelSU first on local build\n"
      rm -rf KernelSU drivers/kernelsu

      echo -e "\nKSU Support, let's Make it On\n"
      curl -kLSs "https://raw.githubusercontent.com/renzyprjkt/KernelSU-Next/next-susfs/kernel/setup.sh" | bash -s next-susfs

      sed -i 's/CONFIG_KSU=n/CONFIG_KSU=y/g' arch/arm64/configs/ginkgo_defconfig
  else
      echo -e "\nKSU not Support, let's Skip\n"
  fi
}

clean_build() {
    echo -e "\n########### Starting build clean-up ###########"

    if [ -d "${objdir}" ]; then
        echo "Clean up old build output..."
        rm -rf "${objdir}" || { echo "Failed to clean up old build output!"; exit 1; }
    else
        echo "No previous build output found."
    fi

    if [ -f "${kernel_dir}/.config" ]; then
        echo "Clean up kernel configuration files..."
        make mrproper -C "${kernel_dir}" || { echo "make mrproper failed!"; exit 1; }
    else
        echo "No existing .config file found, skipping make mrproper."
    fi

    echo -e "########### Build clean-up completed ###########"
}

make_defconfig() {
    echo -e "\n########### Generating Defconfig ###########"
    mkdir -p "${objdir}"
    if ! make -s ARCH="${ARCH}" O="${objdir}" "${DEFCONFIG}" -j$(nproc --all); then
        echo -e "Failed to generate defconfig"
        exit 1
    fi
    echo -e "Defconfig generation completed"
}

compile() {
cd "${kernel_dir}" || { echo "Kernel directory not found!"; exit 1; }
echo -e "\n######### Starting compilation #########"
make -j$(nproc --all) \
       O="${objdir}" \
       ARCH="arm64" \
       CC="clang" \
       LD="ld.lld" \
       AR="llvm-ar" \
       AS="llvm-as" \
       NM="llvm-nm" \
       OBJCOPY="llvm-objcopy" \
       OBJDUMP="llvm-objdump" \
       STRIP="llvm-strip" \
       CLANG_TRIPLE="aarch64-linux-gnu-" \
       CROSS_COMPILE="$GCC_64_DIR/bin/aarch64-linux-android-" \
       CROSS_COMPILE_ARM32="$GCC_32_DIR/bin/arm-linux-androideabi-" \
       Image.gz-dtb \
       dtbo.img \
       CC="${CCACHE} clang" \
       ${1:-}
   if [ $? -ne 0 ]; then
        echo -e "Compilation failed!"
        exit 1
    fi
}

completion() {
  local image="${objdir}/arch/arm64/boot/Image.gz-dtb"
  local dtbo="${objdir}/arch/arm64/boot/dtbo.img"

  if [[ -f "${image}" && -f "${dtbo}" ]]; then
     echo -e "\n#########################################"
     echo -e "############# OkThisIsEpic! #############"
     echo -e "#########################################"
  else
     echo -e "\n#########################################"
     echo -e "##         This Is Not Epic :'(        ##"
     echo -e "#########################################"
     exit 1
  fi
}

setup "$@"
clean_build
make_defconfig
compile
completion
