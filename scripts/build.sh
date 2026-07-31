#!/usr/bin/env bash
# Build decode-only libwebpdecoder into out/<platform>/.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/src"
PLATFORM="${TARGET_PLATFORM:-linux}"
OUT="$ROOT/out/${PLATFORM}"
BUILD="$ROOT/build-${PLATFORM}"
JOBS="${JOBS:-$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

if [[ ! -f "$SRC/CMakeLists.txt" ]]; then
  echo "missing libwebp source at $SRC — run: make fetch" >&2
  exit 1
fi

CMAKE_ARGS=(
  -S "$SRC"
  -B "$BUILD"
  -DCMAKE_BUILD_TYPE=Release
  -DBUILD_SHARED_LIBS=OFF
  -DWEBP_LINK_STATIC=ON
  -DWEBP_BUILD_CWEBP=OFF
  -DWEBP_BUILD_DWEBP=OFF
  -DWEBP_BUILD_GIF2WEBP=OFF
  -DWEBP_BUILD_IMG2WEBP=OFF
  -DWEBP_BUILD_VWEBP=OFF
  -DWEBP_BUILD_WEBPINFO=OFF
  -DWEBP_BUILD_ANIM_UTILS=OFF
  -DWEBP_BUILD_LIBWEBPMUX=OFF
  -DWEBP_BUILD_WEBPMUX=OFF
  -DWEBP_BUILD_EXTRAS=OFF
  -DWEBP_ENABLE_SIMD=ON
  -DWEBP_USE_THREAD=ON
  -DCMAKE_INSTALL_PREFIX="$OUT"
)

case "$PLATFORM" in
  linux)
    ;;
  windows)
    CMAKE_ARGS+=(
      -DCMAKE_SYSTEM_NAME=Windows
      -DCMAKE_C_COMPILER=x86_64-w64-mingw32-gcc
      -DCMAKE_CXX_COMPILER=x86_64-w64-mingw32-g++
      -DCMAKE_RC_COMPILER=x86_64-w64-mingw32-windres
      -DCMAKE_FIND_ROOT_PATH=/usr/x86_64-w64-mingw32
      -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER
      -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY
      -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY
    )
    ;;
  macos)
    CMAKE_ARGS+=(
      -DCMAKE_OSX_ARCHITECTURES=arm64
      -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0
    )
    ;;
  ios)
    SDK_PATH="$(xcrun --sdk iphoneos --show-sdk-path)"
    CMAKE_ARGS+=(
      -DCMAKE_SYSTEM_NAME=iOS
      -DCMAKE_OSX_ARCHITECTURES=arm64
      -DCMAKE_OSX_SYSROOT="$SDK_PATH"
      -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0
      -DCMAKE_C_FLAGS="-fembed-bitcode-marker"
    )
    ;;
  ios-simulator)
    # arm64 iPhone Simulator (Apple Silicon). Device .a cannot link into sim.
    SDK_PATH="$(xcrun --sdk iphonesimulator --show-sdk-path)"
    CMAKE_ARGS+=(
      -DCMAKE_SYSTEM_NAME=iOS
      -DCMAKE_OSX_ARCHITECTURES=arm64
      -DCMAKE_OSX_SYSROOT="$SDK_PATH"
      -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0
    )
    ;;
  android)
    if [[ -z "${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}" ]]; then
      echo "ANDROID_NDK_HOME (or ANDROID_NDK_ROOT) required for android builds" >&2
      exit 1
    fi
    NDK="${ANDROID_NDK_HOME:-$ANDROID_NDK_ROOT}"
    CMAKE_ARGS+=(
      -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake"
      -DANDROID_ABI=arm64-v8a
      -DANDROID_PLATFORM=android-24
    )
    ;;
  *)
    echo "unknown TARGET_PLATFORM=$PLATFORM" >&2
    exit 1
    ;;
esac

echo "=== configuring libwebpdecoder ($PLATFORM) ==="
cmake "${CMAKE_ARGS[@]}"

echo "=== building webpdecoder ($JOBS jobs) ==="
cmake --build "$BUILD" --target webpdecoder -j"$JOBS"

# Prefer cmake --install of the decoder target; fall back to manual copy.
mkdir -p "$OUT/lib" "$OUT/include/webp"
if cmake --install "$BUILD" --component Unspecified >/dev/null 2>&1; then
  :
fi

# Always ensure the decoder archive + public headers land under out/<platform>/.
shopt -s nullglob
found=0
for cand in "$BUILD"/libwebpdecoder.a "$BUILD"/libwebpdecoder.lib \
            "$BUILD"/*/libwebpdecoder.a "$OUT"/lib/libwebpdecoder.a; do
  if [[ -f "$cand" ]]; then
    cp -f "$cand" "$OUT/lib/libwebpdecoder.a"
    found=1
    break
  fi
done
shopt -u nullglob

if [[ "$found" -ne 1 ]]; then
  # Some CMake generators nest under build tree oddly — search once.
  cand="$(find "$BUILD" -name 'libwebpdecoder.a' -o -name 'webpdecoder.lib' 2>/dev/null | head -1 || true)"
  if [[ -n "$cand" && -f "$cand" ]]; then
    cp -f "$cand" "$OUT/lib/libwebpdecoder.a"
    found=1
  fi
fi

if [[ "$found" -ne 1 ]]; then
  echo "failed to locate libwebpdecoder.a under $BUILD" >&2
  exit 1
fi

for h in decode.h types.h; do
  src_h="$SRC/src/webp/$h"
  if [[ ! -f "$src_h" ]]; then
    echo "missing header $src_h" >&2
    exit 1
  fi
  cp -f "$src_h" "$OUT/include/webp/$h"
done

# Also copy generated config header bits if present (types.h is usually enough).
if [[ -f "$BUILD/src/webp/config.h" ]]; then
  cp -f "$BUILD/src/webp/config.h" "$OUT/include/webp/config.h" 2>/dev/null || true
fi

ls -lh "$OUT/lib/libwebpdecoder.a"
echo "=== installed headers ==="
ls -lh "$OUT/include/webp/"
echo "done: $OUT"
