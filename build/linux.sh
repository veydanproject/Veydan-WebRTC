#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Veydan Project
# SPDX-License-Identifier: LicenseRef-PolyForm-Perimeter-1.0.1
#
# libwebrtc for Linux, x64 or arm64, without the software H.264:
#
#   build/linux.sh --arch x64 [--work <dir>]
#
# Gives <work>/webrtc-linux-<arch>-release.zip. Needs git, python3, ninja,
# pkg-config, cpio, zip and a few gigabytes of patience: the checkout is
# about 15 GB, the build an hour or more on a hosted runner. The compiler,
# the sysroot and libc++ come with the checkout (hermetic), so the
# distribution hardly matters.
set -euo pipefail
# shellcheck source=common.sh
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
webrtc_args "x64 arm64" "$@"
arch="$WEBRTC_ARCH"
target="linux-$arch"
echo ">> libwebrtc $WEBRTC_COMMIT for $target in $WEBRTC_WORK"

webrtc_checkout linux
out="$WEBRTC_WORK/src/out-$arch-release"
artifacts="$WEBRTC_WORK/$target-release"

cd "$WEBRTC_WORK/src" || exit 1
webrtc_patch add_licenses
webrtc_patch fix_license_json_parsing
webrtc_patch ssl_verify_callback_with_native_handle
webrtc_patch add_deps
webrtc_patch fix_desktop_capture_compile
webrtc_patch external_audio_source
webrtc_patch fix_pipewire_utils_compile
# Compact relocations (-Wa,--crel) of Chromium's build crash on aarch64.
webrtc_patch disable_crel build
webrtc_patch david_disable_gun_source_macro third_party
webrtc_patch disable_sme_for_libyuv third_party/libyuv

python3 ./build/linux/sysroot_scripts/install-sysroot.py --arch="$arch"

# The arguments are those of the archives of livekit/rust-sdks, which the
# bridge webrtc-sys is written against, but for the codecs: no software
# H.264 (rtc_use_h264=false: neither FFmpeg nor OpenH264 is built or
# linked; proprietary_codecs=false says the same to Chromium's build). The
# hermetic libc++ (use_custom_libcxx=true) is an ABI contract with the
# bridge, which is compiled against the headers the archive ships.
# use_clang_modules=false: the C++ modules of the toolchain fail halfway.
args="is_debug=false
  target_os=\"linux\"
  target_cpu=\"$arch\"
  rtc_enable_protobuf=false
  treat_warnings_as_errors=false
  use_llvm_libatomic=false
  use_custom_libcxx=true
  use_custom_libcxx_for_host=true
  use_clang_modules=false
  rtc_include_tests=false
  rtc_build_tools=false
  rtc_build_examples=false
  rtc_libvpx_build_vp9=true
  enable_libaom=true
  is_component_build=false
  enable_stripping=true
  proprietary_codecs=false
  rtc_use_h264=false
  rtc_use_h265=true
  rtc_use_pipewire=true
  symbol_level=0
  enable_iterator_debugging=false
  use_rtti=true
  rtc_use_x11=true"

gn gen "$out" --root=. --args="$args"
ninja -C "$out" :default

# The hermetic libc++ and libc++abi for the target, built on purpose:
# nothing of :default links a binary, so their objects would not be
# compiled, and the bridge, which takes the archive as its whole standard
# library, would miss every out-of-line symbol of std. The host copy of a
# native x64 build lands in obj/ by chance; a cross build for arm64 puts it
# under clang_x64/ instead, which the pattern below leaves out.
libcxx_archives=$(ninja -C "$out" -t targets all | grep -oE '^obj/[^:]*/libc\+\+(abi)?\.a' | sort -u)
if [ -z "$libcxx_archives" ]; then
  echo ">> no hermetic libc++ in the ninja graph of $out; use_custom_libcxx=true is an ABI contract with the bridge" >&2
  exit 1
fi
# shellcheck disable=SC2086
ninja -C "$out" $libcxx_archives

webrtc_no_h264 "$out"

# One static archive of every object (webrtc_pack_objects of common.sh).
# BoringSSL's symbols get a prefix, so that a process which also loads
# OpenSSL does not mix the two.
rm -rf "$artifacts"
mkdir -p "$artifacts/lib"
webrtc_pack_objects "$out" "$artifacts/lib/libwebrtc.a"
llvm=./third_party/llvm-build/Release+Asserts/bin
"$llvm/llvm-objcopy" --redefine-syms="$WEBRTC_BUILD_DIR/boringssl_prefix_symbols.txt" "$artifacts/lib/libwebrtc.a"

# The out-of-line half of libc++ is really in there.
markers=$("$llvm/llvm-nm" --defined-only "$artifacts/lib/libwebrtc.a" 2>/dev/null | grep -oE '__libcpp_verbose_abort|__cxa_throw' | sort -u | tr '\n' ' ')
for sym in __libcpp_verbose_abort __cxa_throw; do
  case " $markers " in
    *" $sym "*) ;;
    *) echo ">> libwebrtc.a defines no $sym: the objects of libc++/libc++abi are missing" >&2; exit 1 ;;
  esac
done

webrtc_common_files "$out" "$artifacts"
webrtc_headers "$artifacts"

# The headers of the hermetic libc++ (no extension, so the find above does
# not see them) and its configuration, where build/config/c++/BUILD.gn
# points -isystem and -I at, so the bridge can do the same.
for inc in third_party/libc++/src/include third_party/libc++abi/src/include; do
  mkdir -p "$artifacts/include/$inc"
  cp -R "$inc/." "$artifacts/include/$inc/"
done
mkdir -p "$artifacts/include/buildtools/third_party/libc++"
cp buildtools/third_party/libc++/__config_site buildtools/third_party/libc++/__assertion_handler "$artifacts/include/buildtools/third_party/libc++/"

webrtc_zip "$target"
echo ">> $WEBRTC_WORK/webrtc-$target-release.zip"
