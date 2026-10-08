# Veydan WebRTC

**Коротко.** Сборка libwebrtc для приложений Veydan (движок звонков)
без программного H.264: ни FFmpeg (LGPL), ни OpenH264. Аппаратный H.264
остаётся — MediaCodec на Android, VideoToolbox на macOS; на десктопе видео
идёт VP8/VP9/AV1. Архивы — `webrtc-<цель>-release.zip` в релизе тега, той
же раскладки, что у livekit/rust-sdks, так что мост `webrtc-sys` и
`scripts/webrtc-toolchain.sh` приложений берут их без изменений. Версия
WebRTC — M150, коммит `89d790b…` webrtc-sdk/webrtc; патчи — LiveKit'овы.
Собирает CI по тегу `vX.Y.Z` (`.github/workflows/release.yml`); скрипты
в `build/` запускаются и руками.

---

Prebuilt **libwebrtc** for the Veydan apps (Space, Chat): the engine of
their calls, one static archive per system, built by the release workflow
of this repository from a pinned commit of WebRTC.

## Why a build of our own

The apps link libwebrtc through the crate `webrtc-sys` of
[livekit/rust-sdks](https://github.com/livekit/rust-sdks), and LiveKit
publishes archives of its own. Those carry the software H.264 of the
tree: the decoder of **FFmpeg** (LGPL-2.1-or-later, linked statically)
and the encoder of **OpenH264** (Cisco's terms on the H.264 patents).
Both are obligations that come with distributing the binary, not with
using it. These builds leave the software H.264 out and change nothing
else:

| | livekit/rust-sdks | Veydan WebRTC |
|---|---|---|
| `rtc_use_h264` | `true` on the desktop (`false` on Android) | `false` everywhere |
| `proprietary_codecs` | default | `false` |
| `ffmpeg_branding` | `"Chrome"` | not set (FFmpeg is not built) |
| headers in `include/` | the whole tree | the tree without `third_party/ffmpeg` and `third_party/openh264` |

What stays: the hardware H.264 of the systems, which is not in the tree —
**MediaCodec** through the Java side of the Android archive
(`libwebrtc.jar`), **VideoToolbox** through the Objective-C side of the
macOS one. On Linux and Windows video is VP8, VP9 and AV1 (libvpx, libaom,
dav1d). The codec of a call is chosen by what both sides offer in the
SDP, so an app with these archives talks to any other.

Everything else is as LiveKit builds it: the same commit of WebRTC, the
same patches (`build/patches/`, the folder `webrtc-sys/libwebrtc` of
rust-sdks), the same GN arguments, the same layout of the archive, the
same names — so the bridge `webrtc-sys`, `webrtc-sys-build` and the
scripts of the apps take an archive of ours where they took one of
LiveKit's.

## What a release holds

A tag `vX.Y.Z` (the number of this repository; `CHANGELOG.md` says which
commit of WebRTC is inside) builds and publishes:

```
webrtc-linux-x64-release.zip      webrtc-mac-x64-release.zip
webrtc-linux-arm64-release.zip    webrtc-mac-arm64-release.zip
webrtc-win-x64-release.zip        webrtc-android-arm64-release.zip
webrtc-win-arm64-release.zip      SHA256SUMS
```

Each archive is one folder, `<target>-release/`:

```
include/                 every .h and .inc of the tree (Linux: the hermetic libc++ too)
lib/libwebrtc.a          the static library (lib/webrtc.lib on Windows)
webrtc.ninja             the -D flags the bridge is compiled with (read by webrtc-sys-build)
desktop_capture.ninja    the flags of the desktop capture (desktop only)
args.gn                  the GN arguments of the build
LICENSE.md               the notices of what is inside
libwebrtc.jar            Android: the Java side, packages under livekit.org.webrtc
lib/libjingle_peerconnection_so.so   Android: the shared library
```

## Build it yourself

Each system builds on itself; Linux also cross-builds arm64 and the
Android archive. A build is a checkout of about 15 GB and an hour or more.

```
build/linux.sh   --arch x64|arm64     [--work <dir>]
build/android.sh --arch arm64|arm|x64 [--work <dir>]
build/macos.sh   --arch x64|arm64     [--work <dir>]
build\windows.cmd --arch x64|arm64    [--work <dir>]
```

The archive lands in `<work>/webrtc-<target>-release.zip` with its sha256
beside it; `<work>` is `work/` beside `build/` unless named. Needed: git,
python3, ninja, cpio, zip (Linux: pkg-config; Android: a JDK 17 and
gradle; Windows: Visual Studio 2022 with C++, 7-Zip). The compiler, the
sysroot and the NDK come with the checkout. The scripts can be run again
on the same work directory: a patch already in is skipped, a checkout that
is there is kept.

## Update the version of WebRTC

1. Move `WEBRTC_COMMIT` in `build/common.sh` and `build/windows.cmd` to
   the commit the new `webrtc-sys` is written against (its folder
   `webrtc-sys/libwebrtc/.gclient` in rust-sdks names the branch).
2. Take the patches of that folder into `build/patches/` and apply them in
   the order of its scripts, in `build/*.sh` and `build/windows.cmd`;
   compare its GN arguments with ours (the table above is the whole
   difference), and `boringssl_prefix_symbols.txt`.
3. Say in `CHANGELOG.md` which commit is inside, raise `VERSION`, tag
   `v<VERSION>`.
4. In the apps: the new tag and the hashes of `SHA256SUMS` in
   `scripts/webrtc-toolchain.sh`, together with the new `webrtc-sys`.

## Check the hashes

`SHA256SUMS` of a release is what the workflow computed over the archives
it just built; `scripts/webrtc-toolchain.sh` of the apps pins the same
numbers and refuses an archive that differs. To check an archive by hand:

```
sha256sum -c --ignore-missing SHA256SUMS
```

## Licence

The scripts are under the PolyForm Perimeter License 1.0.1, the licence
of every part of Veydan: [LICENSE](LICENSE) is the text that counts,
[LICENSE-SUMMARY.md](LICENSE-SUMMARY.md) says it in short. WebRTC and what
goes into an archive are the work of others, under their own licences:
[THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md) lists them, and the
`LICENSE.md` inside each archive carries their full text — ship it with
any binary built on the archive.

Developed by Rookbeam Technologies LLC, USA
