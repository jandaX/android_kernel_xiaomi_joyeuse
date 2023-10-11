export PATH="$HOME/clang-GengKapak/bin:$PATH"
SECONDS=0
KERNEL_DEFCONFIG=joyeuse_defconfig
ZIPNAME="DeathRhythm-joyeuse-$(date '+%Y%m%d-%H%M').zip"

if ! [ -d "$HOME/clang-GengKapak" ]; then
echo "GengKapak clang not found! Cloning..."
if ! git clone https://scm.osdn.net/gitroot/gengkapak/clang-GengKapak.git -b main --depth=1 --single-branch ~/clang-GengKapak; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

mkdir -p out
make O=out clean

if [[ $1 == "-r" || $1 == "--regen" ]]; then
cp out/.config arch/arm64/configs/joyeuse_defconfig
echo -e "\nRegened defconfig succesfully!"
exit 0
else
echo -e "\nStarting compilation...\n"
# export ld=ld.lld
make $KERNEL_DEFCONFIG O=out
make -j$(nproc --all) O=out \
                      ARCH=arm64 \
                      CC=clang \
                      LD=ld.lld \
                      AR=llvm-ar \
                      NM=llvm-nm \
                      OBJCOPY=llvm-objcopy \
                      OBJDUMP=llvm-objdump \
                      STRIP=llvm-strip \
                      CROSS_COMPILE=aarch64-linux-gnu- \
                      CROSS_COMPILE_ARM32=arm-linux-gnueabi-
fi

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
echo -e "\nKernel compiled succesfully! Zipping up...\n"
git clone -q https://github.com/AnggaR96s/AnyKernel3 -b 14
git log --oneline -n10 > AnyKernel3/changelog
cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
cp out/arch/arm64/boot/dtbo.img AnyKernel3
cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x '*.git*' README.md LICENSE *placeholder
cd ..
rm -rf AnyKernel3
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
if command -v curl &> /dev/null; then
curl -X POST -H "content-type: multipart/form-data" -F document=@"$ZIPNAME" -F chat_id=$CID https://api.telegram.org/bot$TOKEN/sendDocument
else
echo "Zip: $ZIPNAME"
fi
rm -rf out/arch/arm64/boot
else
echo -e "\nCompilation failed!"
fi
