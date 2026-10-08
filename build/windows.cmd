@echo off
rem SPDX-FileCopyrightText: 2026 Veydan Project
rem SPDX-License-Identifier: LicenseRef-PolyForm-Perimeter-1.0.1
rem
rem libwebrtc for Windows, x64 or arm64, without the software H.264:
rem
rem   build\windows.cmd --arch x64 [--work <dir>]
rem
rem Gives <work>\webrtc-win-<arch>-release.zip with lib\webrtc.lib. Needs
rem Visual Studio 2022 with the C++ workload and the Windows SDK, git,
rem python3, ninja and 7-Zip on PATH. The same steps as common.sh and
rem linux.sh, in batch: the pinned WebRTC, depot_tools, the patches, the
rem archive. The compiler is clang of the checkout (is_clang=true), the
rem C runtime the static one (static_link_crt), as the archives of
rem livekit/rust-sdks the bridge links.
setlocal enabledelayedexpansion

set WEBRTC_REPO=https://github.com/webrtc-sdk/webrtc.git
set WEBRTC_COMMIT=89d790b40447c3c5c54c3edd58aa53d285e35fa7
set DEPOT_TOOLS_REPO=https://chromium.googlesource.com/chromium/tools/depot_tools.git

set BUILD_DIR=%~dp0
set BUILD_DIR=%BUILD_DIR:~0,-1%
set arch=
if defined WEBRTC_WORK (set "work=%WEBRTC_WORK%") else (set "work=%BUILD_DIR%\..\work")

:args
if "%~1" == "" goto args_done
if "%~1" == "--arch" (
  set "arch=%~2"
  shift & shift & goto args
)
if "%~1" == "--work" (
  set "work=%~2"
  shift & shift & goto args
)
echo unknown argument '%~1'; usage: build\windows.cmd --arch ^<x64^|arm64^> [--work ^<dir^>]
exit /b 1
:args_done
if not "!arch!" == "x64" if not "!arch!" == "arm64" (
  echo --arch must be one of: x64 arm64
  exit /b 1
)
if not exist "!work!" mkdir "!work!"
pushd "!work!" || exit /b 1
set "work=%CD%"
popd

set target=win-!arch!
echo ^>^> libwebrtc %WEBRTC_COMMIT% for !target! in !work!

rem The checkout: depot_tools, then src at WEBRTC_COMMIT with its
rem dependencies for Windows, without history. depot_tools must not look
rem for the toolchain of Google's own builds. On Windows depot_tools brings its
rem own git and python on the first run of gclient (bootstrap); with
rem DEPOT_TOOLS_UPDATE=0 that never happens and its git.bat finds nothing.
cd /d "!work!"
if not exist depot_tools (
  git clone --depth 1 %DEPOT_TOOLS_REPO% depot_tools || exit /b 1
)
set "PATH=!work!\depot_tools;%PATH%"
set DEPOT_TOOLS_WIN_TOOLCHAIN=0
set GYP_MSVS_VERSION=2022
if not defined vs2022_install set "vs2022_install=C:\Program Files\Microsoft Visual Studio\2022\Enterprise"
(
  echo solutions = [
  echo   {
  echo     "name": "src",
  echo     "url": "%WEBRTC_REPO%@%WEBRTC_COMMIT%",
  echo     "deps_file": "DEPS",
  echo     "managed": False,
  echo     "custom_deps": {},
  echo   },
  echo ]
  echo target_os = ["win"]
) > .gclient
if not exist src (
  call gclient.bat sync -D --no-history || exit /b 1
)
rem lastchange.py finds no commit with a Change-Id in a checkout without
rem history and writes a time of 0; lld then refuses the negative link
rem timestamp made of it. Run again with an empty filter, it takes the
rem pinned commit itself and writes its real time.
call python3 src\build\util\lastchange.py -o src\build\util\LASTCHANGE --filter= || exit /b 1

cd src
rem A patch already applied is skipped, so the build can be run again on the
rem same checkout; one that neither applies nor is in stops the build.
for %%p in (add_licenses add_deps ssl_verify_callback_with_native_handle external_audio_source) do (
  call git apply --reverse --check --ignore-space-change --ignore-whitespace "%BUILD_DIR%\patches\%%p.patch" >nul 2>&1
  if errorlevel 1 (
    echo ^>^> patch %%p
    call git apply -v --ignore-space-change --ignore-whitespace --whitespace=nowarn "%BUILD_DIR%\patches\%%p.patch"
    if errorlevel 1 (
      echo ^>^> patch %%p does not apply: make it again against %WEBRTC_COMMIT%, or reset the checkout ^(git checkout -- .^) and run again
      exit /b 1
    )
  ) else (
    echo ^>^> patch %%p: already applied
  )
)
copy /y .vpython3 "!work!\" >nul

set "out=!work!\src\out-!arch!-release"
set "artifacts=!work!\!target!-release"

rem As the archives of livekit/rust-sdks but for the codecs: no software
rem H.264 (rtc_use_h264=false, proprietary_codecs=false: neither FFmpeg nor
rem OpenH264 is built or linked).
call gn.bat gen "!out!" --root=. --args="is_debug=false is_clang=true target_cpu=\"!arch!\" use_custom_libcxx=false rtc_libvpx_build_vp9=true enable_libaom=true rtc_include_tests=false rtc_build_examples=false rtc_build_tools=false is_component_build=false rtc_enable_protobuf=false proprietary_codecs=false rtc_use_h264=false symbol_level=0 enable_iterator_debugging=false" || exit /b 1
ninja.exe -C "!out!" :default || exit /b 1

rem No object of FFmpeg or OpenH264 in the build, no WEBRTC_USE_H264 in the flags.
dir /s /b "!out!\obj\third_party\ffmpeg\*.obj" >nul 2>&1 && (echo ^>^> objects of FFmpeg in the build; rtc_use_h264 is not off & exit /b 1)
dir /s /b "!out!\obj\third_party\openh264\*.obj" >nul 2>&1 && (echo ^>^> objects of OpenH264 in the build; rtc_use_h264 is not off & exit /b 1)
findstr /c:"-DWEBRTC_USE_H264" "!out!\obj\webrtc.ninja" >nul && (echo ^>^> webrtc.ninja defines WEBRTC_USE_H264; rtc_use_h264 is not off & exit /b 1)

if exist "!artifacts!" rmdir /s /q "!artifacts!"
mkdir "!artifacts!\lib"
copy "!out!\obj\webrtc.lib" "!artifacts!\lib\" || exit /b 1

rem The notices of what the archive holds, by the dependencies of the built target.
call python3 tools_webrtc\libs\generate_licenses.py --target :default "!out!" "!out!" || exit /b 1
copy "!out!\obj\webrtc.ninja" "!artifacts!\" || exit /b 1
copy "!out!\obj\modules\desktop_capture\desktop_capture.ninja" "!artifacts!\" || exit /b 1
copy "!out!\args.gn" "!artifacts!\" || exit /b 1
copy "!out!\LICENSE.md" "!artifacts!\" || exit /b 1

rem The headers: every .h and .inc of the tree, without the sources of
rem FFmpeg and OpenH264, which this build does not use, and the build output.
xcopy *.h "!artifacts!\include" /C /S /I /Q /H /EXCLUDE:%BUILD_DIR%\windows-headers-exclude.txt >nul || exit /b 1
xcopy *.inc "!artifacts!\include" /C /S /I /Q /H /EXCLUDE:%BUILD_DIR%\windows-headers-exclude.txt >nul || exit /b 1
rem xcopy makes the folders of the excluded files all the same, empty.
for %%d in (ffmpeg openh264) do if exist "!artifacts!\include\third_party\%%d" rmdir /s /q "!artifacts!\include\third_party\%%d"

rem The archive: 7-Zip writes the paths with forward slashes, which every
rem unzip reads; Compress-Archive of PowerShell 5 did not.
cd /d "!work!"
if exist "webrtc-!target!-release.zip" del "webrtc-!target!-release.zip"
7z a -tzip -bso0 -bsp0 "webrtc-!target!-release.zip" "!target!-release" || exit /b 1
echo ^>^> !work!\webrtc-!target!-release.zip
endlocal
