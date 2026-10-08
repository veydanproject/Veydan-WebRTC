# Changelog

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
