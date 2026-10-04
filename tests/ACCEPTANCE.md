# Manual Acceptance Tests

## Mapping
- [ ] Exact palette colors remain unchanged.
- [ ] Every opaque output pixel belongs to the chosen destination palette.
- [ ] Pixel coordinates/dimensions are unchanged.
- [ ] Transparent pixels stay transparent.

## Scope
- [ ] Current Cel changes only active cel.
- [ ] Selection never modifies outside selection.
- [ ] Current Layer processes all intended cels only.
- [ ] All Frames processes all intended frames.
- [ ] Whole Sprite processes visible/defined layers according to documented rules.

## Undo
- [ ] Apply appears as one Undo History item.
- [ ] Undo fully restores source state.

## Generated palettes
- [ ] Requested palette count is respected when enough unique colors exist.
- [ ] Fewer unique source colors does not invent needless colors.
- [ ] Same source/settings produce same palette.

## Dithering
- [ ] None performs strict nearest-color mapping.
- [ ] Ordered dither is deterministic.
- [ ] Error diffusion does not leak through transparency.
- [ ] 0% dither behaves like None.

## Animation
- [ ] Linked cels are handled safely.
- [ ] Empty cels do not cause errors.
