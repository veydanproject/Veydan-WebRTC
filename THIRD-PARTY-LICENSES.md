# Third-Party Licenses

The scripts of this repository are the Veydan Project's, under the PolyForm
Perimeter License 1.0.1 ([LICENSE](LICENSE)). What they build and what the
archives of a release hold is the work of others, each part under its own
licence. The full text of every notice is `LICENSE.md` inside each archive,
written by `tools_webrtc/libs/generate_licenses.py` of the tree from the
dependencies of the built target; what follows is the list, so that the
licences can be read before an archive is fetched. The BSD licences ask
that the notice goes with every binary: an application that ships an
archive ships its `LICENSE.md` too.

## What is built

- **WebRTC** — the WebRTC project authors (Google), BSD-3-Clause. The
  tree is the fork [webrtc-sdk/webrtc](https://github.com/webrtc-sdk/webrtc)
  (BSD-3-Clause), branch `m150_release`, at the commit `build/common.sh`
  pins.
- **Patches of livekit/rust-sdks** — `build/patches/`, from the folder
  `webrtc-sys/libwebrtc` of [livekit/rust-sdks](https://github.com/livekit/rust-sdks),
  Apache-2.0: the notices of the licence tool, the dependencies cut down,
  the TLS verify callback with its native handle, the external audio
  source, the desktop capture and PipeWire fixes, the compact relocations
  off, the GNU_SOURCE macro of dav1d, SME off in libyuv, libunwind and the
  JNI prefix on Android. The build arguments and the layout of the
  archives follow the build scripts of the same folder. The list of
  BoringSSL symbols that get a prefix (`build/boringssl_prefix_symbols.txt`)
  is from the same place.
- **depot_tools** — the Chromium Authors, BSD-3-Clause: `gclient`, `gn`
  and `ninja` wrappers, fetched by the scripts, not shipped.

## What is in every archive

Each under its own licence, as `LICENSE.md` of the archive lists them:

- abseil-cpp — Apache-2.0
- BoringSSL — Apache-2.0 and ISC (the symbols carry the prefix of
  `build/boringssl_prefix_symbols.txt`)
- dav1d — BSD-2-Clause
- libaom — BSD-2-Clause
- libvpx — BSD-3-Clause
- libyuv — BSD-3-Clause
- libjpeg-turbo — IJG and BSD-3-Clause
- libsrtp — BSD-3-Clause
- Opus — BSD-3-Clause
- RNNoise — BSD-3-Clause
- protobuf — BSD-3-Clause
- Perfetto — Apache-2.0
- PFFFT, Ooura FFT, the FFT of Mark Olesen (fft), spl_sqrt_floor — their
  own permissive notices
- the G.711 and G.722 code of SpanDSP — their own notices
- fiat-crypto — Apache-2.0 (and MIT)
- zlib — Zlib
- libc++, libc++abi, llvm-libc — Apache-2.0 WITH LLVM-exception (Linux:
  the hermetic libc++ is in the archive and its headers under `include/`)
- NASM — BSD-2-Clause (desktop; its objects are not in the archive)

On Android also: the Android SDK parts, compiler-rt, libunwind,
cpu_features, jni_zero, ijar and the Kotlin standard library — Apache-2.0.

**Not in any archive:** FFmpeg (LGPL-2.1-or-later) and OpenH264
(BSD-2-Clause, with Cisco's terms on the H.264 patents) — the software
H.264 that the archives of livekit/rust-sdks carry. These builds set
`rtc_use_h264=false` and `proprietary_codecs=false`, and the release
workflow refuses an archive whose notices or headers name either.
