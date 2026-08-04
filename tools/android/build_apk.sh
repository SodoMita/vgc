#!/usr/bin/env bash
# Build the VGC Illustration APK on a normal Linux machine.
#
# Requires: cmake >= 3.19, ninja, python3 (with dev files), curl, git, JDK 17
#           (sets up the rest itself: Android SDK, NDK, Qt 6.7.3 for Android,
#           FreeType, HarfBuzz).
#
# Usage:  bash tools/android/build_apk.sh   [out dir, default: build-android]
set -euo pipefail

OUT_DIR="${1:-build-android}"
QT_VERSION="${QT_VERSION:-6.7.3}"
ANDROID_PLATFORM="${ANDROID_PLATFORM:-android-34}"
ANDROID_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-34.0.0}"
NDK_VERSION="${NDK_VERSION:-26.1.10909125}"
ABI="${ABI:-arm64-v8a}"

export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$HOME/Android/Sdk}"
NDK_HOME="$ANDROID_SDK_ROOT/ndk/$NDK_VERSION"
SYSROOT="$NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/sysroot"

echo "==> [1/8] Java"
JAVA_VERSION_OUTPUT="$(java -version 2>&1 | head -n1)"
JAVA_MAJOR="$(printf '%s\n' "$JAVA_VERSION_OUTPUT" | sed -E 's/.*version "([0-9]+).*/\1/')"
if ! printf '%s' "$JAVA_MAJOR" | grep -Eq '^[0-9]+$' || [ "$JAVA_MAJOR" -lt 17 ]; then
    echo "Please install a JDK 17 or newer (found: $JAVA_VERSION_OUTPUT)" >&2; exit 1
fi
command -v javac >/dev/null || { echo "javac not found; install a full JDK" >&2; exit 1; }

echo "==> [2/8] Android SDK + NDK ($NDK_VERSION)"
if [ ! -x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" ]; then
    mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
    curl -L -o /tmp/cmdtools.zip \
        "https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip"
    unzip -q /tmp/cmdtools.zip -d "$ANDROID_SDK_ROOT/cmdline-tools"
    mv "$ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
fi
yes | "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
"$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager" --install \
    "platforms;$ANDROID_PLATFORM" "build-tools;$ANDROID_BUILD_TOOLS" "ndk;$NDK_VERSION"

echo "==> [3/8] Qt $QT_VERSION (host + android)"
python3 -m pip install --user aqtinstall || true
export PATH="$HOME/.local/bin:$PATH"
QT_HOST_PATH="$HOME/Qt/$QT_VERSION/gcc_64"
export QT_ROOT_DIR="$HOME/Qt/$QT_VERSION/android_arm64_v8a"
if [ ! -d "$QT_HOST_PATH" ]; then
    aqt install-qt linux desktop "$QT_VERSION" linux_gcc_64 -O "$HOME/Qt"
fi
if [ ! -d "$QT_ROOT_DIR" ]; then
    aqt install-qt linux android "$QT_VERSION" android_arm64_v8a -O "$HOME/Qt"
fi
export PATH="$QT_HOST_PATH/bin:$QT_ROOT_DIR/bin:$PATH"
# Keep Gradle within small CI/container memory budgets and avoid persistent daemons.
export GRADLE_OPTS="${GRADLE_OPTS:--Dorg.gradle.daemon=false -Dorg.gradle.jvmargs=-Xmx768m -Dfile.encoding=UTF-8}"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Dfile.encoding=UTF-8}"

echo "==> [4/8] Cross-build FreeType + HarfBuzz (static, into NDK sysroot)"
curl -sL -o /tmp/freetype.tar.gz https://codeload.github.com/freetype/freetype/tar.gz/refs/tags/VER-2-13-2
tar xzf /tmp/freetype.tar.gz -C /tmp
cmake -S /tmp/freetype-VER-2-13-2 -B /tmp/ft-build -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$ANDROID_PLATFORM" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$SYSROOT/usr/local" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DBUILD_SHARED_LIBS=OFF \
    -DFT_DISABLE_BZIP2=ON -DFT_DISABLE_PNG=ON -DFT_DISABLE_BROTLI=ON \
    -DFT_DISABLE_HARFBUZZ=ON -DFT_DISABLE_ZLIB=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build /tmp/ft-build --parallel && cmake --install /tmp/ft-build

curl -sL -o /tmp/harfbuzz.tar.gz https://codeload.github.com/harfbuzz/harfbuzz/tar.gz/refs/tags/8.3.0
tar xzf /tmp/harfbuzz.tar.gz -C /tmp
cmake -S /tmp/harfbuzz-8.3.0 -B /tmp/hb-build -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$ABI" -DANDROID_PLATFORM="$ANDROID_PLATFORM" \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$SYSROOT/usr/local" \
    -DCMAKE_PREFIX_PATH="$SYSROOT/usr/local" \
    -DCMAKE_POSITION_INDEPENDENT_CODE=ON -DBUILD_SHARED_LIBS=OFF \
    -DHB_HAVE_FREETYPE=ON -DHB_BUILD_UTILS=OFF -DHB_BUILD_TESTS=OFF \
    -DHB_BUILD_BENCHMARKS=OFF -DHB_BUILD_SUBSET=OFF -DHB_HAVE_GLIB=OFF \
    -DHB_HAVE_GRAPHITE2=OFF -DHB_HAVE_ICU=OFF -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build /tmp/hb-build --parallel && cmake --install /tmp/hb-build
# HarfBuzz's own cmake config requires a Threads::Threads target that VGC's
# configure doesn't provide; remove it so VGC uses its Findharfbuzz.cmake.
rm -rf "$SYSROOT/usr/local/lib/cmake/harfbuzz"

echo "==> [5/8] Python (dev files)"
if ! python3 -c 'import sysconfig; sysconfig.get_paths()["include"]' >/dev/null 2>&1 \
   || [ ! -f "$(python3 -c 'import sysconfig; print(sysconfig.get_paths()["include"])')/Python.h" ]; then
    echo "python3 dev files missing: sudo apt install python3-dev" >&2; exit 1
fi
PYBIN="$(command -v python3)"

echo "==> [6/8] Configure (NDK toolchain wrapper: allow host Python discovery)"
cat > /tmp/vgc-android.toolchain.cmake <<EOF
include("$NDK_HOME/build/cmake/android.toolchain.cmake")
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
EOF
cmake -S . -B "$OUT_DIR" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DVGC_QT_VERSION=6 \
    -DQt6_DIR="$QT_ROOT_DIR/lib/cmake/Qt6" \
    -DQT_HOST_PATH="$QT_HOST_PATH" \
    -DPython_EXECUTABLE="$PYBIN" \
    -DCMAKE_TOOLCHAIN_FILE=/tmp/vgc-android.toolchain.cmake \
    -DANDROID_ABI="$ABI" \
    -DANDROID_PLATFORM="$ANDROID_PLATFORM" \
    -DANDROID_STL=c++_shared \
    -DANDROID_NDK="$NDK_HOME" \
    -DANDROID_SDK_ROOT="$ANDROID_SDK_ROOT" \
    -DHARFBUZZ_DIR="$SYSROOT/usr/local" \
    -DCMAKE_PREFIX_PATH="$SYSROOT/usr/local"

echo "==> [7/8] Build"
cmake --build "$OUT_DIR" --parallel "$(nproc)"

echo "==> [8/8] Locate APK"
APK=$(find "$OUT_DIR" -name '*.apk' -type f | head -n1)
[ -n "$APK" ] || { echo "No APK found under $OUT_DIR after build!" >&2; exit 1; }

echo ""
echo "APK: $APK"
