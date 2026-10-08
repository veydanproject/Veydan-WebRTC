#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Veydan Project
# SPDX-License-Identifier: LicenseRef-PolyForm-Perimeter-1.0.1
#
# libwebrtc for macOS, x64 or arm64, without the software H.264:
#
#   build/macos.sh --arch arm64 [--work <dir>]
#
# Gives <work>/webrtc-mac-<arch>-release.zip. Needs Xcode, git, python3,
# ninja (brew), cpio and zip. The H.264 of VideoToolbox (Apple's, in the
# system) stays in the Objective-C part of the archive, as MediaCodec's on
# Android; what is left out is the software codec of FFmpeg and OpenH264.
set -euo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
webrtc_args "x64 arm64" "$@"
arch="$WEBRTC_ARCH"
target="mac-$arch"
echo ">> libwebrtc $WEBRTC_COMMIT for $target in $WEBRTC_WORK"

webrtc_checkout mac
out="$WEBRTC_WORK/src/out-$arch-release"
artifacts="$WEBRTC_WORK/$target-release"

cd "$WEBRTC_WORK/src" || exit 1
webrtc_patch add_licenses
webrtc_patch fix_license_json_parsing
webrtc_patch ssl_verify_callback_with_native_handle
webrtc_patch add_deps
webrtc_patch external_audio_source

# As the archives of livekit/rust-sdks but for the codecs (rtc_use_h264,
# proprietary_codecs). use_clang_modules=false: with the headers of a
# recent SDK the C++ modules fail on size_t.
args="is_debug=false
  enable_dsyms=false
  target_os=\"mac\"
  target_cpu=\"$arch\"
  mac_deployment_target=\"10.15\"
  mac_min_system_version=\"10.15\"
  treat_warnings_as_errors=false
  rtc_enable_protobuf=false
  rtc_include_tests=false
  rtc_build_examples=false
  rtc_build_tools=false
  rtc_libvpx_build_vp9=true
  enable_libaom=true
  is_component_build=false
  enable_stripping=true
  rtc_enable_symbol_export=true
  rtc_enable_objc_symbol_export=false
  rtc_include_dav1d_in_internal_decoder_factory=true
  proprietary_codecs=false
  rtc_use_h264=false
  rtc_use_h265=true
  use_custom_libcxx=false
  use_clang_modules=false
  clang_use_chrome_plugins=false
  use_rtti=true
  use_lld=false
  rtc_include_internal_audio_device=true"

gn gen "$out" --root=. --args="$args"
ninja -C "$out" :default \
  api/audio_codecs:builtin_audio_decoder_factory \
  api/task_queue:default_task_queue_factory \
  sdk:native_api \
  sdk:default_codec_factory_objc \
  pc:peer_connection \
  sdk:videocapture_objc \
  sdk:mac_framework_objc \
  desktop_capture_objc \
  modules/audio_device:audio_device

webrtc_no_h264 "$out"

rm -rf "$artifacts"
mkdir -p "$artifacts/lib"
find "$out/obj" -name '*.o' -not -path '*/third_party/nasm/*' -print0 | xargs -0 ar -rc "$artifacts/lib/libwebrtc.a"

webrtc_common_files "$out" "$artifacts"
webrtc_headers "$artifacts"

webrtc_zip "$target"
echo ">> $WEBRTC_WORK/webrtc-$target-release.zip"
