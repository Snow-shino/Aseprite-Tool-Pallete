# Product Specification

## UX

Primary workflow:
1. Open artwork.
2. Open Arete Palette Limiter.
3. Pick existing palette or generate a new limited palette.
4. Pick target color count.
5. Choose matching and dithering.
6. Preview.
7. Apply.

The common workflow should take only a few clicks.

## Palette sources

### Current Sprite Palette
Use Aseprite's active sprite palette. Allow:
- all non-transparent palette entries
- future option: selected/locked subset

### Generate From Artwork
Analyze pixels in the chosen scope and derive a palette.
- Target count: 2-256
- Initial reducer: median cut
- Quality mode: median cut followed by k-means++ refinement
- Alpha below threshold excluded from clustering
- Do not let transparent pixels become opaque colors

## Nearest-color matching

Required:
- RGB Euclidean
- Weighted RGB
- CIE76 in Lab

Desired:
- CIEDE2000

Default should favor a perceptual mode.

## Dithering

Required:
- None
- Bayer 2x2
- Bayer 4x4
- Bayer 8x8
- Floyd-Steinberg
- Atkinson

Dither amount: 0-100%.

Do not diffuse error into transparent pixels.

## Scope

- Current cel
- Selection
- Current frame
- Current layer
- All frames
- Whole sprite

Selection should intersect the requested scope rather than alter pixels outside it.

## Output

Default: duplicate layer where applicable.
Optional destructive mode.
All final changes grouped into one undo transaction.

## Preview

Preview should:
- be reversible without polluting undo history where possible
- never corrupt the source
- debounce expensive recomputation
- show resulting palette swatches
- expose Before/After or preview toggle if practical

## Presets

Save:
- palette source
- target color count
- algorithm
- distance mode
- dither mode
- dither amount
- alpha threshold
- scope/output preferences

Include support for named presets such as `TRF Portrait 16`.

## Performance target

A 512x512 RGBA image with a <=32-color destination palette should remap interactively on a normal desktop.
Cache palette Lab conversion and nearest-color lookups when useful.

## Explicit non-goals for v1

Do not implement:
- image scaling
- resampling
- pixelation/downsampling
- blur/sharpen
- outlines/inlines
- image color grading
- general image-to-pixel-art conversion

This project borrows the palette workflow idea from SLK_img2pixel, not its entire feature set.

## 0.1.0 implementation notes

The RGB implementation includes current-palette mapping, generated median-cut palettes, optional bounded K-Means refinement, RGB/weighted RGB/CIE76/CIEDE2000 matching, all listed dither modes, alpha thresholding, all six scopes, detached preview image processing, and persistent presets. Current Cel/Selection and scope traversal are batch-tested on Aseprite 1.3.18.6.

Modify Existing is the available output mode. Duplicate Layer is deferred by user decision to preserve one-step Undo because Aseprite's native layer-duplication command cannot be grouped with the pixel edits into the same transaction. See `tests/ACCEPTANCE.md` for the checked suite and verified limitation.

Indexed and Grayscale are rejected with a clear error. Tilemap, background, reference, and locked layers are skipped in broad scopes; an unsupported active layer errors before mutation. Whole Sprite includes hidden image layers; other broad scopes process visible image layers.
