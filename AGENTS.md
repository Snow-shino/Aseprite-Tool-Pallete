# AGENTS.md

## Goal

Build a polished Aseprite palette-limiting extension optimized for pixel art workflows.

## Non-negotiables

- Pure Lua/Aseprite scripting API where practical.
- Pixel positions must never move.
- No blur, scaling, interpolation, resampling, or anti-aliasing.
- Transparency must be preserved.
- Final Apply must be one undoable transaction.
- Preview must never permanently alter original artwork.
- Algorithms must be deterministic for identical settings/input.
- Keep UI responsive; avoid needless repeated recomputation.
- Favor readable modules over one giant Lua file.

## Core modules

- `src/main.lua` - entrypoint / command registration
- `src/ui.lua` - dialog and state
- `src/lib/color.lua` - RGB/Lab conversion and distance functions
- `src/lib/palette.lua` - palette extraction/loading/reduction
- `src/lib/quantize.lua` - quantization algorithms
- `src/lib/dither.lua` - dithering
- `src/lib/apply.lua` - Aseprite scope traversal and pixel mutation
- `src/lib/presets.lua` - persistence

## Initial algorithm requirements

Nearest-color:
- RGB Euclidean
- weighted RGB
- CIE76 Lab
- CIEDE2000 if performance is acceptable

Palette generation:
- Median cut first
- K-means++ refinement as optional/high-quality mode
- Preserve manually locked colors when supported

Dithering:
- None
- Bayer 2x2
- Bayer 4x4
- Bayer 8x8
- Floyd-Steinberg
- Atkinson

## Coding approach

Implement correctness first. Add caching after tests exist.
