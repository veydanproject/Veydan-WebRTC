# Changelog

## 1.0.8 (2026-10-08): the archives hold every object

- The archives of 1.0.7 (and of every release before it) lost about 500
  objects: `ar -r` replaces a member of the same name, and the tree holds
  many objects of one name in different folders (resampler.o, base64.o,
  entenc.o, bind.o…). A product linking them missed the symbols of Opus,
  BoringSSL and abseil (`undefined symbol: ec_enc_init`). The objects are
  appended with `ar -q` now; the script counts the members against the
  objects and looks for the symbols of Opus before it packs the archive.
  Windows takes the webrtc.lib of GN and was whole.

## 1.0.7 (2026-10-08): Windows leaves no empty folders of FFmpeg behind

- xcopy excluded the headers of FFmpeg and OpenH264 but made their folders
  all the same; the script removes them, and the check of the archive reads
  files only. The Windows build of 1.0.6 was otherwise complete, with no
  FFmpeg or OpenH264 among its licences.

## 1.0.6 (2026-10-08): the Windows script goes on past lastchange.py

- python3 of depot_tools is a batch file; run without `call`, it took the
  rest of the script with it: the build ended after the checkout with a
  green step and no archive.

## 1.0.5 (2026-10-08): LASTCHANGE by the hook itself; macOS on the newest Xcode

- LASTCHANGE is written by lastchange.py with an empty filter (the pinned
  commit, its real time) on every system: the batch of 1.0.4 lost its
  format string to cmd and wrote "ECHO is off" into the time.
- macOS builds on macos-15 with the newest Xcode of the image: the libc++
  of Xcode 15 refuses the constinit of protobuf in M150.

## 1.0.4 (2026-10-08): gn starts on Linux, macOS and Android; Windows links

- depot_tools is let update itself on every system: its first run of
  gclient bootstraps the python gn runs with; with DEPOT_TOOLS_UPDATE=0 gn
  stopped with "python3_bin_reldir.txt not found".
- LASTCHANGE and LASTCHANGE.committime are written from the pinned commit:
  the hook finds no Change-Id in a checkout without history, writes a time
  of 0, and lld-link refuses the negative timestamp made of it.

## 1.0.3 (2026-10-08): setuptools on every image

- The pip of Ubuntu 22.04 knows no --break-system-packages; the setting goes
  through PIP_BREAK_SYSTEM_PACKAGES, which an old pip ignores and the
  Homebrew one on macOS reads.

## 1.0.2 (2026-10-08): the first steps of the Windows and macOS builds

- Windows: depot_tools is let bootstrap its own git and python on the first
  run of gclient; with DEPOT_TOOLS_UPDATE=0 its git.bat found no git and
  gclient sync stopped before the checkout.
- macOS: setuptools is installed with --break-system-packages, as the
  python of the image is Homebrew's (PEP 668).

## 1.0.1 (2026-10-08): the check of the workflows reads no URLs

- The CI step that makes sure the workflows name files that exist took the
  path of the ninja download on GitHub for a file of ours and stopped the
  first release before a build began. URLs are left out of that check.

## 1.0.0 (2026-10-08): the first build, without the software H.264

- WebRTC M150: commit `89d790b40447c3c5c54c3edd58aa53d285e35fa7` of
  webrtc-sdk/webrtc (branch `m150_release`), the one the bridge
  `webrtc-sys` 0.3.48 is written against; the same commit livekit/rust-sdks
  builds its release `webrtc-89d790b` from, with the same patches.
- `rtc_use_h264=false`, `proprietary_codecs=false` on every system: neither
  FFmpeg (the H.264 decoder, LGPL) nor OpenH264 (the encoder) is built,
  linked or shipped as headers. The hardware H.264 of the systems stays:
  MediaCodec in the Java side of the Android archive, VideoToolbox in the
  Objective-C side of the macOS one. Video on the desktop otherwise: VP8,
  VP9, AV1.
- Archives for linux-x64, linux-arm64, win-x64, win-arm64, mac-x64,
  mac-arm64, android-arm64, named and laid out as the ones of
  livekit/rust-sdks (`webrtc-<target>-release.zip`), so that the bridge and
  the scripts of the apps take them unchanged.
