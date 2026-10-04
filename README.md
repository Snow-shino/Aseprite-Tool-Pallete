# Arete Palette Limiter

An Aseprite extension for constraining existing pixel art to a chosen palette. It remaps color values only: canvas dimensions, cel positions, and pixel coordinates stay unchanged.

## Current release

Version `0.1.0`. Tested with Aseprite `1.3.18.6`.

## Quick start

1. Install `AretePaletteLimiter.aseprite-extension` from **Edit > Preferences > Extensions > Add Extension**, then restart or rescan extensions.
2. Open an RGB sprite and run **Arete Palette Limiter** from the Scripts menu.
3. Choose **Current Sprite Palette** or **Generate From Artwork**. For generated palettes, choose 2–256 colors; the default is 16.
4. Choose a scope, matching method, and optional dither. Press **Preview** to inspect the active cel sample and palette swatches.
5. Press **Apply**. **Modify Existing** is grouped as one labeled undo step. Use Aseprite Undo to restore the source.

## Features

- Current sprite palette or generated palette from the selected scope
- Deterministic median cut and optional median cut plus bounded K-Means refinement
- RGB Euclidean, weighted RGB, CIE76 Lab, and CIEDE2000 nearest-color matching
- None, Bayer 2x2/4x4/8x8, Floyd–Steinberg, and Atkinson dithering, with 0–100% amount
- Alpha threshold and preserve-transparency controls; error diffusion skips transparent and below-threshold pixels
- Current Cel, Selection, Current Frame, Current Layer, All Frames, and Whole Sprite scopes
- Named persistent presets; generated palettes are stored in a preset for reuse
- Detached preview image and visual palette swatches
- Linked cels are detached only when needed; a one-step Undo restores both pixels and linked state

Weighted RGB uses squared channel error `0.299·ΔR² + 0.587·ΔG² + 0.114·ΔB²`. Lab conversion uses sRGB → linear RGB → D65 XYZ → CIE Lab. Destination Lab values are prepared once per processing pass; repeated-color nearest matches are cached only when dithering is off.

## Scopes and layer behavior

- **Current Cel** and **Selection** use the active cel. Selection checks each canvas coordinate, including irregular masks.
- **Current Frame** visits editable, visible image layers in the current frame.
- **Current Layer** visits the selected image layer across its cels; selecting a group visits its image-layer children.
- **All Frames** visits editable, visible image layers across the animation.
- **Whole Sprite** includes hidden image layers as well as visible ones.
- Locked, reference, background, and tilemap layers are skipped in multi-layer scopes. The active unsupported layer produces an error. Empty cels are ignored.
- RGB is supported. Indexed and Grayscale sprites are rejected without modification.

### Duplicate Layer status

Duplicate Layer is temporarily unavailable. In Aseprite 1.3.18.6, its native duplication command creates a separate undo action that cannot be grouped with pixel changes through the scripting transaction API. A batch acceptance check confirmed that one Undo would leave the duplicate layer behind. **Modify Existing** remains the default because it preserves the required one-step Undo behavior. See `tests/ACCEPTANCE.md` for this verified limitation.

## Presets

Presets are stored under Aseprite's user configuration directory in `AretePaletteLimiter/presets.json`. They include source, generated palette when applicable, target count, quantizer, matching, dithering, alpha settings, scope, and output preference. Preset data is versioned and invalid entries are ignored.

## Install from source

For development, run `src/main.lua` from Aseprite's Scripts menu or package the project as described below.

## Package

The release archive is `AretePaletteLimiter.aseprite-extension`. It is a ZIP archive with `package.json` at its root and the `src/` folder alongside it.

## Acceptance tests

The Aseprite batch tests cover color math, deterministic palette generation, dithering, scopes, selection bounds, transparency, linked-cel safety, presets, and Undo. From the repository root, run:

```powershell
& 'C:\path\to\Aseprite.exe' --batch tests/fixture.aseprite --script tests/runner.lua
```

The visual dialog and canvas appearance still need a manual GUI review. The test matrix and remaining limitations are in `tests/ACCEPTANCE.md`.

## Development layout

- `src/main.lua` — script entrypoint
- `src/ui.lua` — dialog, preview, and preset controls
- `src/lib/color.lua` — RGB/Lab conversion and distance functions
- `src/lib/palette.lua` — palette extraction, sanitizing, and generation
- `src/lib/quantize.lua` — median cut and K-Means refinement
- `src/lib/dither.lua` — ordered and error-diffusion dithering
- `src/lib/apply.lua` — scope traversal, linked-cel handling, and transactional edits
- `src/lib/presets.lua` — persistent versioned preset storage
- `tests/ACCEPTANCE.md` — acceptance status
- `tests/run.lua` — Aseprite batch acceptance cases

## Reference

Workflow inspiration: [SLK_img2pixel by Captain4LK](https://captain4lk.itch.io/slk-img2pixel). This extension implements palette reduction and matching for existing Aseprite artwork; it does not recreate the standalone app.
