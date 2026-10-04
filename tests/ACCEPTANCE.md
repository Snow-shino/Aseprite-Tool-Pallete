# Acceptance Status

Automated against the installed Aseprite `1.3.18.6` runtime using:

```powershell
& 'C:\path\to\Aseprite.exe' --batch tests/fixture.aseprite --script tests/runner.lua
```

`tests/run.lua` is the acceptance suite; `tests/runner.lua` captures pass/fail output in the system temporary directory so batch failures remain visible when Aseprite suppresses standard output.

## Automated and passing

- [x] Exact RGB palette matches and nearest-color remapping
- [x] Pixel dimensions and coordinates remain unchanged
- [x] sRGB-to-Lab reference values; CIEDE2000 reference pair
- [x] Weighted RGB and RGB Euclidean distance functions load and map
- [x] Median cut respects target count, excludes below-threshold/transparent inputs, avoids extra colors, and is deterministic
- [x] K-Means refinement is deterministic and retains requested cluster count where unique colors permit
- [x] Dither amount 0 equals no dithering
- [x] Bayer 4x4 and 8x8 are deterministic
- [x] Floyd–Steinberg skips transparent pixels; error-diffusion edges stay in bounds
- [x] Transparent and below-threshold pixel bytes remain unchanged
- [x] Current Cel and Selection scopes
- [x] Current Frame, Current Layer, All Frames, and Whole Sprite scopes
- [x] Hidden layers are included only by Whole Sprite; locked layers are skipped
- [x] Empty cels do not enter the processing set
- [x] Linked cel processing detaches only targeted cels; one Undo restores pixels and links
- [x] Modify Existing commits in one undo step and Undo restores source pixels
- [x] Preset save, overwrite, load, palette persistence, and delete
- [x] Indexed images are rejected before mutation
- [x] Preview processing uses an isolated Image clone and does not edit the source

## Blocked or needs GUI review

- [x] Duplicate Layer intentionally deferred by user decision to preserve one-step Undo. The unsupported option is omitted from the dialog and guarded in the apply layer.
- [ ] Visually inspect dialog sizing, preview canvas rendering, palette swatches, and preset control interactions in Aseprite's GUI.
- [ ] Manually verify installation through the Extensions preferences UI.

The automated preview assertion verifies source immutability of the detached preview image calculation. It does not verify the dialog's rendered canvas appearance.
