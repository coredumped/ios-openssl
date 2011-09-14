#!/bin/bash

# Yay shell scripting! This script builds a static version of
# OpenSSL 1.0.0x for every installed iOS sdk installed, builds targets for armv6, armv7 and i386.


OPENSSL_CONFIGURE_OPTIONS=

detectedSSLVersion=""
# Verify that OpenSSL has been downloaded
if [ -f openssl*z ]; then
	for ssltgz in openssl*z
	do
		detectedSSLVersion=`echo $ssltgz | sed 's/openssl-\(.*\).tar.gz/\1/'`
	done
else
	echo "OpenSSL has not been downloaded, get it from http://openssl.org/source/"
	exit 1
fi
echo "Compiling OpenSSL ${detectedSSLVersion}..."

rm -rf include lib *.log

rm -rf /tmp/openssl-${detectedSSLVersion}-*
rm -rf /tmp/openssl-${detectedSSLVersion}-*.log

for iossdkpath in `xcode-select -print-path`/Platforms/iPhoneOS.platform/Developer/SDKs/* `xcode-select -print-path`/Platforms/iPhoneSimulator.platform/Developer/SDKs/*

do
	echo "=== Building targets for "`basename $iossdkpath`" ==="
	echo $iossdkpath | grep iPhoneOS > /dev/null
	if [ $? -eq 0 ]; then
		allarchs="armv6 armv7"
	else
		allarchs=i386
	fi
	for iosarch in $allarchs
	do
		echo -ne " * $iosarch... "
		if [ "$iosarch" = i386 ]; then
			GCC=`xcode-select -print-path`/Platforms/iPhoneSimulator.platform/Developer/usr/bin/gcc
		else
			GCC=`xcode-select -print-path`/Platforms/iPhoneOS.platform/Developer/usr/bin/gcc
		fi
		rm -rf openssl-${detectedSSLVersion}
		tar xfz openssl-${detectedSSLVersion}.tar.gz
		pushd . > /dev/null 2>&1
		cd openssl-${detectedSSLVersion}
		echo -ne "compiling..."
		./configure BSD-generic32 --openssldir=/tmp/openssl-${detectedSSLVersion}-${iosarch} $OPENSSL_CONFIGURE_OPTIONS &> /tmp/openssl-${detectedSSLVersion}-${iosarch}.log
		perl -i -pe 's|static volatile sig_atomic_t intr_signal|static volatile int intr_signal|' crypto/ui/ui_openssl.c
		perl -i -pe "s|^CC= gcc|CC=${GCC} -arch ${iosarch}|g" Makefile
		perl -i -pe "s|^CFLAG= (.*)|CFLAG= -isysroot ${iossdkpath} \$1|g" Makefile
		make &> /tmp/openssl-${detectedSSLVersion}-${iosarch}.log
		if [ $? -ne 0 ]; then
			cat /tmp/openssl-${detectedSSLVersion}-${iosarch}.log
			exit 1;
		fi
		make install &> /tmp/openssl-${detectedSSLVersion}-${iosarch}.log
		popd > /dev/null 2>&1
		echo done
	done
done

mkdir include
cp -r /tmp/openssl-${detectedSSLVersion}-i386/include/openssl include/

mkdir lib
mkdir lib/device
mkdir lib/simulator
lipo \
	/tmp/openssl-${detectedSSLVersion}-armv6/lib/libcrypto.a \
	/tmp/openssl-${detectedSSLVersion}-armv7/lib/libcrypto.a \
	/tmp/openssl-${detectedSSLVersion}-i386/lib/libcrypto.a \
	-create -output lib/device/libcrypto.a
lipo \
	/tmp/openssl-${detectedSSLVersion}-armv6/lib/libssl.a \
	/tmp/openssl-${detectedSSLVersion}-armv7/lib/libssl.a \
	-create -output lib/device/libssl.a

cp -f /tmp/openssl-${detectedSSLVersion}-i386/lib/libcrypto.a lib/simulator/
cp -f /tmp/openssl-${detectedSSLVersion}-i386/lib/libssl.a lib/simulator/

rm -rf /tmp/openssl-${detectedSSLVersion}-*
rm -rf /tmp/openssl-${detectedSSLVersion}-*.log

