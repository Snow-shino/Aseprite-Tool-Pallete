# Arete Palette Limiter

Aseprite extension for reducing artwork to a constrained palette and remapping pixels to the nearest available color.

## Planned v1 features

- Use current sprite palette
- Use selected/current palette colors
- Generate a reduced palette from artwork
- Target color count
- Exact nearest-color remapping
- RGB and perceptual color-distance modes
- Optional dithering
- Alpha preservation / alpha threshold
- Apply to current cel, selection, frame, layer, all frames, or whole sprite
- Non-destructive duplicate-layer option
- Single-step undo
- Presets

## Reference

Behavior is inspired by SLK_img2pixel by Captain4LK, especially its palette limiting, quantization,
color-distance, and dithering workflow. Reimplement the needed behavior cleanly for Aseprite/Lua.

## Install during development

1. Open Aseprite.
2. File > Scripts > Open Scripts Folder.
3. Put/symlink `src/` there for script iteration, OR package the project as a `.zip` / `.aseprite-extension`.
4. Rescan scripts or restart Aseprite.

## Packaging

Zip the extension contents so `package.json` is at the root of the archive, then rename the archive to:

`AretePaletteLimiter.aseprite-extension`

## Development rule

Do not destructively rewrite the original artwork during preview. Apply final changes only inside one
`app.transaction("Arete Palette Limiter", function() ... end)`.
