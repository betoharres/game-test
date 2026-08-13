# VHS Screen Shader Tuning

This guide covers the exposed controls in [`shaders/vhs_screen.gdshader`](../shaders/vhs_screen.gdshader) and provides starting points for several visual styles.

The shader material in [`scenes/effects/vhs_screen_effect.tscn`](../scenes/effects/vhs_screen_effect.tscn) does not currently override these uniforms. Changing a default in the shader therefore changes the effect in game. If a value is later overridden on the `ShaderMaterial`, the material value takes precedence over the shader default.

## Quick Clarity Fix

For a sharper image that retains the VHS character, start with these changes:

```text
luma_lines = 360.0
chroma_samples = 160.0
chroma_lines = 180.0
source_softness_lod = 0.35
horizontal_softness = 0.40
vertical_softness = 0.15
chroma_bleed = 0.45
highlight_bleed = 0.08
```

If motion and color instability also make the image difficult to read, use:

```text
chroma_alignment_pixels = 0.15
chroma_drift_pixels = 0.25
line_jitter_pixels = 0.10
band_jitter_pixels = 0.15
horizontal_drift_pixels = 0.20
```

`source_softness_lod` has the greatest immediate effect on sharpness. Adjust it first, then increase the luma and chroma resolutions, and finally reduce directional softness and color bleed.

## Resolution And Softness

These variables have the greatest effect on whether scene details and text remain readable.

| Variable | Default | What it controls | Tuning guidance |
| --- | ---: | --- | --- |
| `luma_lines` | `360.0` | The vertical resolution of the brightness signal. Horizontal resolution is derived from it using the viewport aspect ratio. | Increase for sharper silhouettes, textures, and text. Decrease for a lower-resolution tape image. Try `300-420` for gameplay clarity. |
| `chroma_samples` | `96.0` | The horizontal resolution of the color signal. It is intentionally independent from luma resolution. | Increase to sharpen horizontal color boundaries and reduce broad color smearing. Try `128-200` for a clearer image. |
| `chroma_lines` | `120.0` | The vertical resolution of the color signal. | Increase to reduce vertical color softness. Values around `150-210` retain some VHS color loss without obscuring details. |
| `source_softness_lod` | `0.50` | The mipmap level used for most screen samples. Higher levels sample blurrier mipmaps. | This is the main global blur control. Try `0.25-0.65` for a readable VHS effect. At `0.0`, color remains softer than luma because chroma sampling adds another `1.0-1.15` LOD in the shader. |
| `horizontal_softness` | `0.60` | How far the two horizontal luma blur samples are offset, measured in luma texels. | Lower it to preserve vertical edges and fine horizontal detail. Try `0.25-0.60`. Setting it to `0.0` removes the offset but not the mipmap blur. |
| `vertical_softness` | `0.25` | How far the upper and lower luma blur samples are offset, measured in luma texels. | Lower it to preserve horizontal edges and small text. Try `0.10-0.25`. |

`luma_lines`, `chroma_samples`, and `chroma_lines` control the virtual signal resolution, not the viewport resolution. The shader interpolates between sparse samples, so low values appear soft rather than pixelated.

## Color Signal

These controls determine how much the color signal separates, smears, and changes over time.

| Variable | Default | What it controls | Tuning guidance |
| --- | ---: | --- | --- |
| `chroma_bleed` | `0.78` | Blends each pixel's color signal with neighboring horizontal chroma samples. Warm colors receive slightly stronger bleed. | Lower it for clean color boundaries. Use `0.30-0.55` for clarity or `0.70-0.90` for an aged tape. |
| `saturation` | `1.35` | Scales chroma after the shadow desaturation step. | Reduce it if bright colors make bleed or noise distracting. Try `1.05-1.25` for a restrained image. Values above `1.35` create a more exaggerated analog look. |
| `chroma_alignment_pixels` | `0.35` | The maximum animated color-channel misalignment, measured in screen pixels. | Lower it when colored fringes make thin geometry or text difficult to read. Try `0.05-0.20` for subtle fringing. |
| `chroma_drift_pixels` | `0.55` | A slower horizontal drift of the entire chroma signal, measured in screen pixels. | Lower it for stable color. Raise it for visible color separation that wanders over time. |
| `highlight_bleed` | `0.16` | Adds warm light from neighboring bright samples into the current pixel. | Lower it if lamps and bright surfaces lose detail or appear hazy. Try `0.04-0.10` for normal gameplay. |

High `saturation` makes `chroma_bleed`, `chroma_noise_strength`, and alignment errors more noticeable. Tune saturation after the chroma resolution and bleed controls.

## Noise And Instability

These variables do not directly blur the source, but strong movement and noise can make a reasonably sharp image feel unreadable.

| Variable | Default | What it controls | Tuning guidance |
| --- | ---: | --- | --- |
| `grain_strength` | `0.025` | Adds animated luminance noise, cloudy variation, and occasional specks. | Use `0.008-0.018` for clean gameplay. Raise it for dirty tape, but values above `0.04` can hide dark details. |
| `chroma_noise_strength` | `0.012` | Adds independent animated noise to the two chroma channels. | Lower it if surfaces shimmer with colored noise. Try `0.003-0.008` for subtle color noise. |
| `line_jitter_pixels` | `0.25` | Horizontally shifts individual luma rows. Most rows move little, while a few receive stronger offsets. | Use `0.05-0.15` for readable motion. Raise it for unstable scan lines. |
| `band_jitter_pixels` | `0.35` | Horizontally shifts groups of rows in 32 screen-height bands. | Lower it if straight edges appear segmented. Use `0.10-0.25` for subtle tape instability. |
| `horizontal_drift_pixels` | `0.45` | Slowly moves the entire signal left and right. | Use `0.10-0.30` for a stable image. Set it to `0.0` for no global drift. |

All three jitter and drift values are expressed in output screen pixels. Their visual prominence therefore remains more consistent across changes to the virtual luma resolution.

## Tracking Errors

Tracking errors are intermittent horizontal displacement bands. They are useful as rare accents but can be disruptive during first-person movement.

| Variable | Default | What it controls | Tuning guidance |
| --- | ---: | --- | --- |
| `tracking_interval` | `5.0` | Length in seconds of each opportunity cycle for a tracking event. | Increase it for less frequent opportunities. Event duration is a fraction of this interval, so larger values also make a triggered event last longer. |
| `tracking_chance` | `0.12` | Approximate probability that an interval contains a tracking event. | Use `0.02-0.08` for rare glitches, `0.15-0.30` for damaged tape, or `0.0` to disable tracking events. |
| `tracking_shift_pixels` | `4.0` | Maximum horizontal displacement inside the active tracking band. | Use `1.0-3.0` for a restrained effect. Values from `6.0-10.0` create obvious tracking failures. |

`tracking_interval` and `tracking_chance` work together. For example, halving the interval while leaving the chance unchanged produces roughly twice as many opportunities per minute.

## Exposure And Lens

These controls shape the final image after the signal simulation.

| Variable | Default | What it controls | Tuning guidance |
| --- | ---: | --- | --- |
| `exposure` | `1.08` | Base multiplier applied before the final shoulder curve and white clamp. | Lower it if bright areas lose detail. Try `1.00-1.08`; raise it carefully for an overexposed camcorder look. |
| `exposure_pump` | `0.035` | Amplitude of slow animated exposure fluctuation. | Use `0.005-0.020` for subtle variation or `0.0` for stable brightness. Higher values can interfere with visibility in dark scenes. |
| `vignette_strength` | `0.12` | Blends the image toward the shader's static edge vignette. | Use `0.04-0.10` when peripheral visibility matters. Raise it for a stronger CRT or horror framing effect. |
| `exhaustion_vignette_strength` | `0.0` | Blends in a tighter vignette intended to communicate player exhaustion. | The local player controller sets this to `0.0` at startup and animates it during exhaustion. Tune the controller's exported `exhaustion_vignette_strength` for the gameplay maximum rather than relying on this shader default. |
| `fish_eye_strength` | `0.18` | Warps screen coordinates radially while scaling them to avoid exposing pixels outside the scene. | Use `0.04-0.12` for a subtle lens. Lower it if edge distortion affects aiming or spatial awareness. Use `0.0` for no lens distortion. |

Exposure is followed by a nonlinear shoulder and a white clamp, so increasing `exposure` can remove highlight detail faster than a simple linear brightness adjustment would suggest.

## Scenario Presets

These are starting points, not strict profiles. Values not shown can remain at their defaults.

### Gameplay-First Clarity

Use this when the VHS identity should remain visible without compromising navigation, aiming, or environmental detail.

```text
luma_lines = 360.0
chroma_samples = 160.0
chroma_lines = 180.0
source_softness_lod = 0.35
horizontal_softness = 0.40
vertical_softness = 0.15

chroma_bleed = 0.45
saturation = 1.15
chroma_alignment_pixels = 0.15
chroma_drift_pixels = 0.25
highlight_bleed = 0.08

grain_strength = 0.015
chroma_noise_strength = 0.006
line_jitter_pixels = 0.10
band_jitter_pixels = 0.15
horizontal_drift_pixels = 0.20

tracking_chance = 0.06
tracking_shift_pixels = 2.0
exposure_pump = 0.015
vignette_strength = 0.08
fish_eye_strength = 0.10
```

### Subtle Camcorder

Use this for a mostly clean image with only enough analog character to establish the presentation style.

```text
luma_lines = 420.0
chroma_samples = 200.0
chroma_lines = 210.0
source_softness_lod = 0.15
horizontal_softness = 0.25
vertical_softness = 0.10

chroma_bleed = 0.30
saturation = 1.10
chroma_alignment_pixels = 0.08
chroma_drift_pixels = 0.10
highlight_bleed = 0.05

grain_strength = 0.010
chroma_noise_strength = 0.004
line_jitter_pixels = 0.05
band_jitter_pixels = 0.05
horizontal_drift_pixels = 0.10

tracking_chance = 0.03
tracking_shift_pixels = 1.5
exposure_pump = 0.010
vignette_strength = 0.06
fish_eye_strength = 0.06
```

### Balanced VHS

Use this for stronger analog softness and color degradation while keeping important shapes legible.

```text
luma_lines = 300.0
chroma_samples = 128.0
chroma_lines = 150.0
source_softness_lod = 0.65
horizontal_softness = 0.60
vertical_softness = 0.20

chroma_bleed = 0.58
saturation = 1.25
chroma_alignment_pixels = 0.20
chroma_drift_pixels = 0.35
highlight_bleed = 0.10

grain_strength = 0.020
chroma_noise_strength = 0.009
line_jitter_pixels = 0.15
band_jitter_pixels = 0.25
horizontal_drift_pixels = 0.30

tracking_chance = 0.08
tracking_shift_pixels = 3.0
exposure_pump = 0.025
vignette_strength = 0.10
fish_eye_strength = 0.14
```

### Damaged Horror Tape

Use this when poor signal quality is intentional and temporary loss of detail supports the atmosphere.

```text
luma_lines = 240.0
chroma_samples = 72.0
chroma_lines = 100.0
source_softness_lod = 1.00
horizontal_softness = 0.85
vertical_softness = 0.30

chroma_bleed = 0.82
saturation = 1.40
chroma_alignment_pixels = 0.60
chroma_drift_pixels = 1.00
highlight_bleed = 0.20

grain_strength = 0.045
chroma_noise_strength = 0.025
line_jitter_pixels = 0.45
band_jitter_pixels = 0.75
horizontal_drift_pixels = 0.80

tracking_interval = 3.5
tracking_chance = 0.25
tracking_shift_pixels = 8.0
exposure_pump = 0.060
vignette_strength = 0.20
fish_eye_strength = 0.18
```

### Motion-Sensitive Accessibility

Use this when animated image displacement, brightness changes, or lens distortion may cause discomfort. This profile keeps static softness and restrained grain for style while removing most screen motion.

```text
luma_lines = 420.0
chroma_samples = 180.0
chroma_lines = 200.0
source_softness_lod = 0.25
horizontal_softness = 0.30
vertical_softness = 0.10

chroma_bleed = 0.35
saturation = 1.10
chroma_alignment_pixels = 0.0
chroma_drift_pixels = 0.0
highlight_bleed = 0.05

grain_strength = 0.008
chroma_noise_strength = 0.0
line_jitter_pixels = 0.0
band_jitter_pixels = 0.0
horizontal_drift_pixels = 0.0

tracking_chance = 0.0
exposure_pump = 0.0
vignette_strength = 0.04
fish_eye_strength = 0.0
```

## Recommended Tuning Order

1. Set `source_softness_lod` to `0.0` and decide how much mipmap softness the scene can tolerate.
2. Raise `luma_lines` until geometry, signs, and small props are readable.
3. Raise `chroma_samples` and `chroma_lines` until colored edges are clear enough.
4. Add `horizontal_softness` and `vertical_softness` without sacrificing important edges.
5. Increase `chroma_bleed`, alignment, and drift until the color degradation is visible but not distracting.
6. Add grain, chroma noise, line jitter, and band jitter while testing both stationary and moving views.
7. Tune tracking errors as rare accents rather than as part of the constant image treatment.
8. Finish with exposure, vignette, and fish-eye distortion in representative bright and dark areas.

Test each profile while walking, sprinting, turning quickly, looking at high-contrast edges, and reading the smallest important text. A still frame can look attractive even when the same settings become difficult to parse in motion.

## Performance Note

Most controls change sample positions or blend strengths but do not change how many texture samples the shader performs. Setting blur, bleed, or noise strengths to zero improves visual clarity but generally does not make this shader substantially cheaper. A lower-cost mode would require a separate shader path that skips sampling and signal reconstruction work.
