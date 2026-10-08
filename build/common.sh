#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Veydan Project
# SPDX-License-Identifier: LicenseRef-PolyForm-Perimeter-1.0.1
#
# What the builds of every system share: the pinned WebRTC, the checkout
# with depot_tools, the patches, the archive. Sourced by linux.sh,
# android.sh and macos.sh; windows.cmd repeats the same steps in batch.
# Not run by itself.
#
# The archive of a target is <work>/<target>-release/ zipped as
# <work>/webrtc-<target>-release.zip, the layout webrtc-sys-build expects:
#
#   <target>-release/include/            every .h and .inc of the tree
#   <target>-release/lib/libwebrtc.a     (lib/webrtc.lib on Windows)
#   <target>-release/webrtc.ninja        the -D flags the bridge is compiled with
#   <target>-release/desktop_capture.ninja   (desktop only)
#   <target>-release/args.gn             the GN arguments of the build
#   <target>-release/LICENSE.md          the notices of what is in the archive
#   <target>-release/libwebrtc.jar       (Android only) the Java side
#   <target>-release/lib/libjingle_peerconnection_so.so   (Android only)

# The WebRTC these archives are built from: one commit of the fork
# webrtc-sdk/webrtc, the one the crate webrtc-sys 0.3.48 was written
# against (branch m150_release, milestone M150; livekit/rust-sdks builds its
# release webrtc-89d790b from the same commit).
WEBRTC_REPO="https://github.com/webrtc-sdk/webrtc.git"
WEBRTC_COMMIT="89d790b40447c3c5c54c3edd58aa53d285e35fa7"
DEPOT_TOOLS_REPO="https://chromium.googlesource.com/chromium/tools/depot_tools.git"

WEBRTC_BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Where the checkout, the build and the archive go: --work, WEBRTC_WORK,
# or work/ beside build/ (ignored by git). Tens of gigabytes.
WEBRTC_WORK="${WEBRTC_WORK:-$(dirname "$WEBRTC_BUILD_DIR")/work}"
WEBRTC_ARCH=""

# The arguments every script takes: --arch <x64|arm64|arm> --work <dir>.
# $1 is the list of architectures the system builds for.
webrtc_args() {
  local allowed="$1"
  shift
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --arch)
        [ "$#" -ge 2 ] || { echo "--arch needs a value" >&2; exit 1; }
        WEBRTC_ARCH="$2"
        shift 2
        ;;
      --work)
        [ "$#" -ge 2 ] || { echo "--work needs a value" >&2; exit 1; }
        WEBRTC_WORK="$2"
        shift 2
        ;;
      *)
        echo "unknown argument '$1'; usage: $0 --arch <$allowed> [--work <dir>]" >&2
        exit 1
        ;;
    esac
  done
  case " $allowed " in
    *" $WEBRTC_ARCH "*) ;;
    *) echo "--arch must be one of: $allowed" >&2; exit 1 ;;
  esac
  mkdir -p "$WEBRTC_WORK"
  WEBRTC_WORK="$(cd "$WEBRTC_WORK" && pwd)"
}

# The checkout, in $WEBRTC_WORK: depot_tools, then src/ at WEBRTC_COMMIT
# with its dependencies for the target OS ($1), without history. A checkout
# that is there is kept: the scripts can be run again on it, and the patches
# know when they are already in.
webrtc_checkout() {
  local target_os="$1"
  cd "$WEBRTC_WORK" || exit 1
  if [ ! -d depot_tools ]; then
    git clone --depth 1 "$DEPOT_TOOLS_REPO" depot_tools
  fi
  export PATH="$WEBRTC_WORK/depot_tools:$PATH"
  # depot_tools would otherwise look for a Chromium-internal toolchain.
  export DEPOT_TOOLS_UPDATE=0
  export DEPOT_TOOLS_WIN_TOOLCHAIN=0
  cat > .gclient <<EOF
solutions = [
  {
    "name": "src",
    "url": "$WEBRTC_REPO@$WEBRTC_COMMIT",
    "deps_file": "DEPS",
    "managed": False,
    "custom_deps": {},
  },
]
target_os = ["$target_os"]
EOF
  if [ ! -d src ]; then
    gclient sync -D --no-history
  fi
}

# webrtc_patch <patch> [dir]: applies build/patches/<patch>.patch to the git
# checkout at [dir] (default: the current directory). One already applied is
# skipped, so a build can be run again on the same checkout; one that neither
# applies nor is in stops the build, since going on would give a libwebrtc
# that silently lacks the change.
webrtc_patch() {
  local patch="$WEBRTC_BUILD_DIR/patches/$1.patch" dir="${2:-.}"
  local flags=(--ignore-space-change --ignore-whitespace --whitespace=nowarn)
  if git -C "$dir" apply --reverse --check "${flags[@]}" "$patch" 2>/dev/null; then
    echo ">> patch $1: already applied"
    return 0
  fi
  echo ">> patch $1"
  if ! git -C "$dir" apply -v "${flags[@]}" "$patch"; then
    echo ">> patch $1 does not apply to $(cd "$dir" && pwd): make it again against $WEBRTC_COMMIT, or reset the checkout (git checkout -- .) and run again" >&2
    exit 1
  fi
}

# The archive of the GN output must hold no code of the software H.264:
# with rtc_use_h264=false neither FFmpeg nor OpenH264 is built, and this
# makes sure of it before the objects are packed.
webrtc_no_h264() {
  local out="$1" found
  found=$(find "$out/obj" \( -path '*/third_party/ffmpeg/*' -o -path '*/third_party/openh264/*' \) -name '*.o' | head -1)
  if [ -n "$found" ]; then
    echo ">> $found: an object of FFmpeg or OpenH264 in the build; rtc_use_h264 is not off" >&2
    exit 1
  fi
  if grep -q -- '-DWEBRTC_USE_H264' "$out/obj/webrtc.ninja"; then
    echo ">> $out/obj/webrtc.ninja defines WEBRTC_USE_H264; rtc_use_h264 is not off" >&2
    exit 1
  fi
}

# The headers of the tree into <artifacts>/include: every .h and .inc, as
# webrtc-sys-build expects them, without the sources of FFmpeg and OpenH264,
# which this build does not use. Run from src/.
webrtc_headers() {
  local artifacts="$1"
  find . \( -path ./third_party/ffmpeg -o -path ./third_party/openh264 -o -path './out-*' \) -prune -o \
    \( -name '*.h' -o -name '*.inc' \) -type f -print | cpio -pdm --quiet "$artifacts/include"
}

# The files every archive carries, from the GN output: the ninja files the
# bridge reads its flags from, the arguments, the notices. Run from src/.
webrtc_common_files() {
  local out="$1" artifacts="$2"
  cp "$out/obj/webrtc.ninja" "$artifacts/"
  if [ -f "$out/obj/modules/desktop_capture/desktop_capture.ninja" ]; then
    cp "$out/obj/modules/desktop_capture/desktop_capture.ninja" "$artifacts/"
  fi
  cp "$out/args.gn" "$artifacts/"
  # The notices of what the archive holds, by the dependencies of the
  # built target. vpython3 of depot_tools has the Python the tool needs.
  vpython3 ./tools_webrtc/libs/generate_licenses.py --target :default "$out" "$out"
  cp "$out/LICENSE.md" "$artifacts/"
}

# The archive: <work>/webrtc-<target>-release.zip of <work>/<target>-release/,
# and its sha256 beside it, as the release prints it in SHA256SUMS.
webrtc_zip() {
  local target="$1"
  cd "$WEBRTC_WORK" || exit 1
  rm -f "webrtc-$target-release.zip"
  zip -qr "webrtc-$target-release.zip" "$target-release"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "webrtc-$target-release.zip" | tee "webrtc-$target-release.zip.sha256"
  else
    shasum -a 256 "webrtc-$target-release.zip" | tee "webrtc-$target-release.zip.sha256"
  fi
}
