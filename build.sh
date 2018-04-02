#!/bin/bash
export CROSS_COMPILE=arm-linux-gnueabihf-
export ARCH=arm
LANG=C
CFLAGS=-j$(grep ^processor /proc/cpuinfo  | wc -l)
export INSTALL_MOD_PATH=$(pwd)/mod/
mkdir -p $INSTALL_MOD_PATH

kernver=$(make kernelversion)
gitbranch=$(git rev-parse --abbrev-ref HEAD)
d=$(date +%Y%m%d)
gitrev=$(git rev-parse --short --verify $gitbranch)
export LOCALVERSION="-${gitbranch}"

export KDIR=$(pwd)

case $1 in
"defconfig")
  nano arch/arm/configs/mt7623n_evb_fwu_defconfig
;;
"importconfig")
  echo "importconfig"
  #cp arch/arm/configs/mt7623n_evb_fwu_defconfig .config
  make mt7623n_evb_fwu_defconfig
  ;;
"config")
  make menuconfig
  ;;
"clean")
  make clean
  cd cryptodev-linux-1.9
  make clean && cd -
  cd DX910-SW-99002-r8p1-00rel0/driver/src/devicedrv/mali/
  make clean && cd -
  ;;
"dts")
  nano arch/arm/boot/dts/mt7623n-bananapi-bpi-r2.dts
;;
"dtsi")
  nano arch/arm/boot/dts/mt7623.dtsi
;;
"cryptodev")
  echo "cryptodev"
  cd cryptodev-linux-1.9
  make KERNEL_DIR=${KDIR}
  cd tests
  export CFLAGS=-I$(pwd)/openssl-1.1.0f/include/
  export LDLIBS=-L$(pwd)/openssl-cryptodev/lib/
  make CC=arm-linux-gnueabihf-gcc
  ;;
"openssl")
  echo openssl
  apt-get source openssl
  cd openssl-1.1.0f
  sed -i 's/\tdh_shlibdeps/dh_shlibdeps -l\/usr\/arm-linux-gnueabihf\/lib:$(pwd)\/debian\/libssl1.1\/usr\/lib\/arm-linux-gnueabihf/' debian/rules
  LANG=C ARCH=arm DEB_BUILD_OPTIONS=nocheck CROSS_COMPILE=arm-linux-gnueabihf- \
	DEB_CFLAGS_APPEND='-DHAVE_CRYPTODEV -DUSE_CRYPTODEV_DIGESTS' \
	DEB_CPPFLAGS_APPEND="-I$(pwd)/../cryptodev-linux-1.9" \
	dpkg-buildpackage -us -uc -aarmhf
  ;;
"mali")
  echo "mali"
  cd DX910-SW-99002-r8p1-00rel0/driver/src/devicedrv/mali/
  KDIR=${KDIR} USING_UMP=0 BUILD=release make
  cd - && cd DX910-SW-99002-r8p1-00rel0/driver/src/egl/x11/drm_module/mali_drm/
  KDIR=${KDIR} make
  ;;
"install")
  echo "install"
  cp uImage /media/$USER/BPI-BOOT/bananapi/bpi-r2/linux/
  sudo cp -r mod/lib/modules/4.9.44-bpi-r2+ /media/$USER/BPI-ROOT/lib/modules/
  sync
;;
"pack")
  echo "pack"
  mkdir -p SD
  mkdir -p SD/BPI-BOOT/bananapi/bpi-r2/linux/
  cp uImage SD/BPI-BOOT/bananapi/bpi-r2/linux/
  mkdir -p SD/BPI-ROOT/lib/modules/
  rm -r SD/BPI-ROOT/lib/modules/*
  #set -x
  SRC=$(ls -1t mod/lib/modules/ | head -1)
  cp -r mod/lib/modules/$SRC SD/BPI-ROOT/lib/modules/$SRC
  #set +x
  #ls SD/BPI-ROOT/lib/modules/
  filename=bpi-r2-$kernver.tar.gz
  (cd SD; tar -czf $filename BPI-BOOT BPI-ROOT;md5sum $filename > $filename.md5; ls -lh $filename)
;;
"kernel")
  make ${CFLAGS}
  if [[ $? -eq 0 ]];then
    cat arch/arm/boot/zImage arch/arm/boot/dts/mt7623n-bananapi-bpi-r2.dtb > arch/arm/boot/zImage-dtb
    mkimage -A arm -O linux -T kernel -C none -a 80008000 -e 80008000 -n "Linux Kernel $kernver" -d arch/arm/boot/zImage-dtb ./uImage
    make modules_install
  fi
  ;;
*)
echo "This tool support following building command:"
echo "--------------------------------------------------------------------------------"
echo "  importconfig, import default config."
echo "  config, kernel configure."
echo "  clean, clean all build."
echo "  cryptodev, build cryptodev kernel module."
echo "  openssl, build openssl with cryptodev kernel engine."
echo "  mali, build mali kernel module."
echo "  install, copy kernel image and module into a mount SD"
echo "  pack, create tar-archive with kernel-image and modules"
echo "  kernel, build kernel image and module, cryptodev, mali"
echo "--------------------------------------------------------------------------------"
  ;;
esac
