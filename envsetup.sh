#!/bin/bash
# SPDX-License-Identifier: GPL-2.0

### Customisable variables
export AK3_URL=https://github.com/dereference23/AnyKernel3
export AK3_BRANCH=positron
export DEFCONFIG_NAME=vendor/xiaomi/miatoll
export TC_DIR="$HOME/prebuilts"
export ZIPNAME="positron-miatoll-$(date +%Y%m%d).zip"

export KBUILD_OUTPUT=out
export KBUILD_BUILD_USER=dereference23
export KBUILD_BUILD_HOST=github.com
### End

# Set up environment
function envsetup() {
    export ARCH=arm64
    export PATH="$TC_DIR/clang-r450784d/bin:$PATH"

    export CROSS_COMPILE=aarch64-linux-gnu-
    export CROSS_COMPILE_ARM32=arm-none-eabi-
    export CROSS_COMPILE_COMPAT=arm-none-eabi-
}

# Clone the toolchain(s)
function clonetc() {
    TC_REMOTE=https://github.com/Positron-V

    if [ "$HOSTARCH" != aarch64 ]; then
        [ -d "$TC_DIR/gcc-arm64" ] || git clone --depth 1 $TC_REMOTE/android_prebuilts_gcc_linux-x86_aarch64_aarch64-none-linux-gnu "$TC_DIR/gcc-arm64" || return
	[ -d "$TC_DIR/gcc-arm" ] || git clone --depth 1 $TC_REMOTE/android_prebuilts_gcc_linux-x86_arm_arm-none-eabi "$TC_DIR/gcc-arm"
    else
	[ -d "$TC_DIR/gcc-arm" ] || git clone --depth 1 $TC_REMOTE/android_prebuilts_gcc_linux-aarch64_arm_arm-none-eabi "$TC_DIR/gcc-arm"
    fi

    # Save some space
    rm -rf "$TC_DIR/gcc-arm64/.git" 2> /dev/null
    rm -rf "$TC_DIR/gcc-arm/.git" 2> /dev/null
}


# Wrapper to utilise all available cores
function m() {
	make -j$(nproc --all) HOSTAR=llvm-ar HOSTCC=clang HOSTCXX=clang++ HOSTLD=ld.lld CC="ccache clang" LD=ld.lld LD_ARM32=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip "$@"
}

# Build kernel
function mka() {
    rd || return
    m
}

# Pack kernel and upload it
function pack() {
    AK3=AnyKernel3
    if [ ! -d $AK3 ]; then
        git clone $AK3_URL $AK3 -b $AK3_BRANCH --depth 1 -q || return
    fi

    OUT=arch/arm64/boot
    cp "$KBUILD_OUTPUT"/$OUT/Image $AK3 || return
    cp "$KBUILD_OUTPUT"/$OUT/dtbo.img $AK3 2> /dev/null
    find "$KBUILD_OUTPUT"/$OUT/dts -name *.dtb -exec cat {} + > $AK3/dtb
    rm $AK3/*.zip 2> /dev/null
    ( cd $AK3 && zip -r9 "$ZIPNAME" * -x .git README.md *placeholder ) || return
    transfer wet "$AK3/$ZIPNAME"
}

function prepare_bsp() {
   git rm -rf .
   git checkout $@ .
   rm -rf AnyKernel3
   rm -rf out
   rm -f envsetup.sh
   rm -f scripts/execprog
   git add .
   git config user.name "bsp-open"
   git config user.email "bsp-open@positron.foundation"
   git config commit.gpgsign false
}

function gen_contrib_list() {
    [ ! -z "$2" ] || { echo "Usage: gen_contrib_list sha1 sha2"; return; }
    git log --format='%an <%ae>' "$1"^.."$2" | sort | uniq > contributors.txt
}

# Regenerate defconfig
function rd() {
   m ${DEFCONFIG_NAME}_defconfig savedefconfig || return
   cp "$KBUILD_OUTPUT"/defconfig arch/arm64/configs/${DEFCONFIG_NAME}_defconfig
}

envsetup
