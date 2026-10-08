#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Veydan Project
# SPDX-License-Identifier: LicenseRef-PolyForm-Perimeter-1.0.1
#
# libwebrtc for Android, arm64 (arm and x64 build the same way):
#
#   build/android.sh --arch arm64 [--work <dir>]
#
# Gives <work>/webrtc-android-<arch>-release.zip with libwebrtc.a, the
# shared library and libwebrtc.jar, the Java side (the hardware codecs of
# MediaCodec, H.264 among them, live there: the archive has no software
# H.264). Needs git, python3, ninja, cpio, zip, a JDK 17 and gradle on PATH
# (GRADLE names another); the NDK and the SDK come with the checkout.
set -euo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
webrtc_args "arm64 arm x64" "$@"
arch="$WEBRTC_ARCH"
target="android-$arch"
echo ">> libwebrtc $WEBRTC_COMMIT for $target in $WEBRTC_WORK"

webrtc_checkout android
out="$WEBRTC_WORK/src/out-$arch-release"
artifacts="$WEBRTC_WORK/$target-release"

cd "$WEBRTC_WORK/src" || exit 1
webrtc_patch add_licenses
webrtc_patch fix_license_json_parsing
webrtc_patch ssl_verify_callback_with_native_handle
webrtc_patch add_deps
webrtc_patch android_use_libunwind
webrtc_patch external_audio_source
# The Java package and the JNI symbols get the prefix "livekit": the bridge
# (webrtc-sys-build, configure_jni_symbols) keeps Java_livekit_org_webrtc_*
# and the application's Kotlin names livekit.org.webrtc.*.
webrtc_patch jni_prefix
webrtc_patch disable_sme_for_libyuv third_party/libyuv

# As the archives of livekit/rust-sdks (Android never had the software
# H.264 there either), proprietary_codecs=false said aloud.
args="is_debug=false
  is_java_debug=false
  target_os=\"android\"
  target_cpu=\"$arch\"
  rtc_enable_protobuf=false
  treat_warnings_as_errors=false
  rtc_include_tests=false
  rtc_build_tools=false
  rtc_build_examples=false
  rtc_libvpx_build_vp9=false
  is_component_build=false
  enable_stripping=true
  proprietary_codecs=false
  rtc_use_h264=false
  rtc_use_h265=true
  rtc_use_pipewire=false
  symbol_level=0
  enable_iterator_debugging=false
  android_package_prefix=\"livekit\"
  use_custom_libcxx=false
  use_clang_modules=false
  use_rtti=true"

gn gen "$out" --root=. --args="$args"
autoninja -C "$out" :default sdk/android:native_api sdk/android:libwebrtc sdk/android:libjingle_peerconnection_so

webrtc_no_h264 "$out"

rm -rf "$artifacts"
mkdir -p "$artifacts/lib"
find "$out/obj" -name '*.o' -not -path '*/third_party/nasm/*' -print0 | xargs -0 ar -rc "$artifacts/lib/libwebrtc.a"
cp "$out/libjingle_peerconnection_so.so" "$artifacts/lib/"

webrtc_common_files "$out" "$artifacts"

# libwebrtc.jar: the classes of sdk/android, every package moved under
# "livekit" (what the JNI prefix above expects), stamped as Java 17 class
# files first — the tree compiles them for Java 21, and older toolchains of
# the applications refuse the stamp alone. Built in a copy of the small
# gradle project of build/prefixed-jni, so the tree stays clean.
jni="$WEBRTC_WORK/prefixed-jni"
rm -rf "$jni"
mkdir -p "$jni/libs"
cp "$WEBRTC_BUILD_DIR/prefixed-jni/build.gradle" "$WEBRTC_BUILD_DIR/prefixed-jni/settings.gradle" "$jni/"
cp "$out/lib.java/sdk/android/libwebrtc.jar" "$jni/libs/classes.jar"
python3 "$WEBRTC_BUILD_DIR/jar-class-version.py" "$jni/libs/classes.jar"
"${GRADLE:-gradle}" --no-daemon -q -p "$jni" shadowJar
cp "$jni/build/libs/prefixed-jni-all.jar" "$artifacts/libwebrtc.jar"
cp sdk/android/AndroidManifest.xml "$artifacts/"

webrtc_headers "$artifacts"

webrtc_zip "$target"
echo ">> $WEBRTC_WORK/webrtc-$target-release.zip"
