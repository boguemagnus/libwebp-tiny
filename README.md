# libwebp-tiny

Minimal, self-compiled [libwebp](https://chromium.googlesource.com/webm/libwebp) builds tailored to my needs.

Produces static **`libwebpdecoder.a`** (no encoder, demux, mux, or CLI tools) for
scaled WebP thumbnails via the advanced decode API (`use_scaling`).

## Why

FFmpeg’s built-in WebP decoder full-decodes then swscales. libwebp can decode
directly to thumbnail size (~200–300 KB of text vs multi‑MiB FFmpeg).

## Layout

```
src/              libwebp source (shallow clone; not committed)
scripts/          Build helpers
out/<platform>/   Install prefix (lib/libwebpdecoder.a, include/webp/)
.github/workflows GH Actions matrix (linux / windows / macos / ios / android)
```

## Quick start (Linux host)

```bash
# First time
git clone --depth 1 --branch v1.5.0 https://github.com/webmproject/libwebp.git src

make build                    # → out/linux/
```

## CMake flags

Upstream has no `WEBP_BUILD_ENCODER=OFF`. Encoder objects live in `libwebp`; we
**ship only the `webpdecoder` target**. Tools/mux/anim are disabled so CI does
not waste time on them:

```
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
```

## Pin

Default source pin: libwebp **v1.5.0**.

## License

libwebp is **BSD-3-Clause**. See upstream `COPYING`.
