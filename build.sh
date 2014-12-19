#!/bin/bash

# directory where the source files are located
SRCDIR=src

# directory to create (any previous will be removed) for staging source
# files generated by J2ObjC
STGDIR=stg

# headerdir is the final location of the headers needed with the lib
HEADERDIR=headers

# the extra arguments to pass to J2ObjC. -d is already defined.
# please set the -d in bindir
J2OBJCARGS=

# the name of the library without the .a at the end. Can also include a path at the beginning
LIBNAME=mylib

# the iOS SDK being used to compile
IOS_BASE_SDK=8.1

# the lowest iOS version to target with the SDK
IOS_DEPLOY_TGT=7.0

# the location of XCode on the system
XCODEROOT=/Applications/Xcode.app/Contents/Developer/Platforms

# no need to change the rest
SIMDEVELROOT=$XCODEROOT/iPhoneSimulator.platform/Developer
DEVDEVELROOT=$XCODEROOT/iPhoneOS.platform/Developer

rm -rf ${STGDIR}
mkdir ${STGDIR}

# find all java files
jfiles=`find ${SRCDIR} -name "*.java"`

# transpile using defaults
j2objc ${J2OBJCARGS} -d ${STGDIR} $jfiles

# use some string replace to determine the m files and eventually the o files
# also to prevent collisions with pkg1/file.java and pkg2/file.java, including pkg name in the o file
mfiles=${jfiles//.java/.m}
ofiles=${jfiles//.\//}
ofiles=${ofiles//.java/.o}
ofiles=${ofiles//\//_}

# first compiling the simulator versions
DEVROOT=$SIMDEVELROOT
SDKROOT=${DEVROOT}/SDKs/iPhoneSimulator${IOS_BASE_SDK}.sdk

cd ${STGDIR}

lipoargs=""
for outarch in x86_64 i386 armv7 armv7s arm64
do
  CFLAGS="-arch $outarch -pipe -no-cpp-precomp -isysroot $SDKROOT -miphoneos-version-min=$IOS_DEPLOY_TGT -ObjC -I./"

  echo "Compiling for architecture: $outarch"
  for jfile in $jfiles
  do
    mfile=${jfile//.java/.m}
    ofile=${jfile//.java/.o}
    ofile=${ofile/.\//}
    ofile=${ofile//\//_}
    echo "Compiling $mfile"
    j2objcc $CFLAGS -c -o ${ofile/.\//} $mfile
  done

  echo "Building ${LIBNAME}_${outarch}.a"
  libtool -static -o ${LIBNAME}_${outarch}.a $ofiles
  lipoargs="$lipoargs -arch $outarch ${LIBNAME}_${outarch}.a"

  # after all the simulator ones, switch to the device SDK
  if [ "$outarch" = "i386" ]
  then
	DEVROOT=$DEVDEVELROOT
  	SDKROOT=${DEVROOT}/SDKs/iPhoneOS${IOS_BASE_SDK}.sdk
  fi
done

echo "combining all into single ${LIBNAME}.a"
lipo $lipoargs -create -output ../${LIBNAME}.a

# clean up
rm *.o
rm *.a
rm $mfiles

cd ..
rm -rf ${HEADERDIR}

# moving to final destination
mv ${STGDIR} ${HEADERDIR}

echo "Complete."
