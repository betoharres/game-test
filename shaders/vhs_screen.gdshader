shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;

uniform float luma_lines : hint_range(180.0, 480.0, 1.0) = 360.0;
uniform float chroma_samples : hint_range(48.0, 240.0, 1.0) = 96.0;
uniform float chroma_lines : hint_range(60.0, 240.0, 1.0) = 120.0;
uniform float source_softness_lod : hint_range(0.0, 3.0, 0.05) = 0.5;
uniform float horizontal_softness : hint_range(0.0, 1.5, 0.05) = 0.6;
uniform float vertical_softness : hint_range(0.0, 1.0, 0.05) = 0.25;

uniform float chroma_bleed : hint_range(0.0, 1.0, 0.01) = 0.78;
uniform float saturation : hint_range(0.5, 2.0, 0.01) = 1.35;
uniform float chroma_alignment_pixels : hint_range(0.0, 1.0, 0.01) = 0.35;
uniform float chroma_drift_pixels : hint_range(0.0, 2.0, 0.05) = 0.55;
uniform float highlight_bleed : hint_range(0.0, 0.5, 0.01) = 0.16;

uniform float grain_strength : hint_range(0.0, 0.12, 0.001) = 0.025;
uniform float chroma_noise_strength : hint_range(0.0, 0.08, 0.001) = 0.012;
uniform float line_jitter_pixels : hint_range(0.0, 1.5, 0.05) = 0.25;
uniform float band_jitter_pixels : hint_range(0.0, 2.0, 0.05) = 0.35;
uniform float horizontal_drift_pixels : hint_range(0.0, 2.0, 0.05) = 0.45;

uniform float tracking_interval : hint_range(2.0, 20.0, 0.5) = 5.0;
uniform float tracking_chance : hint_range(0.0, 0.5, 0.01) = 0.12;
uniform float tracking_shift_pixels : hint_range(0.0, 12.0, 0.25) = 4.0;

uniform float exposure : hint_range(0.8, 1.5, 0.01) = 1.08;
uniform float exposure_pump : hint_range(0.0, 0.15, 0.005) = 0.035;
uniform float vignette_strength : hint_range(0.0, 0.5, 0.01) = 0.12;
uniform float exhaustion_vignette_strength : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float fish_eye_strength : hint_range(0.0, 0.35, 0.005) = 0.18;

float hash_1d(float value) {
	return fract(sin(value * 127.1) * 43758.5453123);
}

float hash_2d(vec2 value) {
	vec3 p = fract(vec3(value.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float noise_1d(float value) {
	float cell = floor(value);
	float blend = fract(value);
	blend = blend * blend * (3.0 - 2.0 * blend);
	return mix(hash_1d(cell), hash_1d(cell + 1.0), blend);
}

float noise_2d(vec2 value) {
	vec2 cell = floor(value);
	vec2 blend = fract(value);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float top = mix(hash_2d(cell), hash_2d(cell + vec2(1.0, 0.0)), blend.x);
	float bottom = mix(hash_2d(cell + vec2(0.0, 1.0)), hash_2d(cell + vec2(1.0)), blend.x);
	return mix(top, bottom, blend.y);
}

vec2 safe_uv(vec2 uv) {
	return clamp(uv, vec2(0.0), vec2(1.0));
}

vec2 fish_eye_uv(vec2 uv) {
	vec2 centered_uv = uv * 2.0 - 1.0;
	float radius_squared = dot(centered_uv, centered_uv);
	// Normalize against the corners so distortion never exposes areas outside the scene.
	float edge_scale = 1.0 / (1.0 + fish_eye_strength * 2.0);
	return centered_uv * (1.0 + fish_eye_strength * radius_squared) * edge_scale * 0.5 + 0.5;
}

vec3 sample_screen(vec2 uv, float lod) {
	return textureLod(screen_texture, safe_uv(uv), lod).rgb;
}

// Reconstructing between sparse samples keeps the image soft without visible pixel-art blocks.
vec3 sample_low_resolution(vec2 uv, vec2 resolution, float lod) {
	vec2 grid = uv * resolution - 0.5;
	vec2 cell = floor(grid);
	vec2 blend = fract(grid);
	vec2 inverse_resolution = 1.0 / resolution;
	vec2 top_left = (cell + 0.5) * inverse_resolution;

	vec3 top = mix(
		sample_screen(top_left, lod),
		sample_screen(top_left + vec2(inverse_resolution.x, 0.0), lod),
		blend.x
	);
	vec3 bottom = mix(
		sample_screen(top_left + vec2(0.0, inverse_resolution.y), lod),
		sample_screen(top_left + inverse_resolution, lod),
		blend.x
	);
	return mix(top, bottom, blend.y);
}

vec3 rgb_to_yiq(vec3 color) {
	return vec3(
		dot(color, vec3(0.299, 0.587, 0.114)),
		dot(color, vec3(0.596, -0.274, -0.322)),
		dot(color, vec3(0.211, -0.523, 0.312))
	);
}

vec3 yiq_to_rgb(vec3 color) {
	return vec3(
		color.x + 0.956 * color.y + 0.621 * color.z,
		color.x - 0.272 * color.y - 0.647 * color.z,
		color.x - 1.106 * color.y + 1.703 * color.z
	);
}

void fragment() {
	float frame = floor(TIME * 59.94);
	float aspect_ratio = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 luma_resolution = vec2(luma_lines * aspect_ratio, luma_lines);
	vec2 chroma_resolution = vec2(chroma_samples, chroma_lines);

	vec2 centered_uv = SCREEN_UV * 2.0 - 1.0;
	float radius_squared = dot(centered_uv, centered_uv);
	vec2 signal_uv = fish_eye_uv(SCREEN_UV);

	float global_drift = (noise_1d(TIME * 1.71 + 4.2) - 0.5) * 2.0 * horizontal_drift_pixels;
	float row = floor(SCREEN_UV.y * luma_lines);
	float row_noise = hash_2d(vec2(row * 0.713, frame));
	float signed_row_noise = row_noise * 2.0 - 1.0;
	float row_jitter = sign(signed_row_noise) * pow(abs(signed_row_noise), 8.0) * line_jitter_pixels;
	float band = floor(SCREEN_UV.y * 32.0);
	float signed_band_noise = hash_2d(vec2(band, floor(TIME * 18.0))) * 2.0 - 1.0;
	float band_jitter = sign(signed_band_noise) * pow(abs(signed_band_noise), 10.0) * band_jitter_pixels;

	float cycle_length = max(tracking_interval, 0.1);
	float tracking_cycle = floor(TIME / cycle_length);
	float tracking_phase = fract(TIME / cycle_length);
	float tracking_event = step(1.0 - tracking_chance, hash_1d(tracking_cycle + 71.3));
	float tracking_envelope = smoothstep(0.01, 0.04, tracking_phase)
		* (1.0 - smoothstep(0.10, 0.18, tracking_phase)) * tracking_event;
	float tracking_center = mix(0.12, 0.92, hash_1d(tracking_cycle + 19.7));
	float tracking_height = mix(0.018, 0.065, hash_1d(tracking_cycle + 43.1));
	float ragged_edge = (noise_2d(vec2(FRAGCOORD.x * 0.025, frame * 0.31)) - 0.5) * 0.018;
	float tracking_band = 1.0 - smoothstep(
		tracking_height * 0.45,
		tracking_height * 0.55,
		abs(SCREEN_UV.y - tracking_center + ragged_edge)
	);
	float tracking_direction = hash_1d(tracking_cycle + 5.9) < 0.5 ? -1.0 : 1.0;
	float tracking_amount = tracking_envelope * tracking_band;
	float horizontal_offset = global_drift + row_jitter + band_jitter
		+ tracking_amount * tracking_direction * tracking_shift_pixels;
	signal_uv.x += horizontal_offset * SCREEN_PIXEL_SIZE.x;

	vec2 luma_texel = 1.0 / luma_resolution;
	vec3 low_color = sample_low_resolution(signal_uv, luma_resolution, source_softness_lod);
	vec3 left_color = sample_screen(
		signal_uv - vec2(luma_texel.x * horizontal_softness, 0.0),
		source_softness_lod + 0.35
	);
	vec3 right_color = sample_screen(
		signal_uv + vec2(luma_texel.x * horizontal_softness, 0.0),
		source_softness_lod + 0.35
	);
	vec3 upper_color = sample_screen(
		signal_uv - vec2(0.0, luma_texel.y * vertical_softness),
		source_softness_lod + 0.15
	);
	vec3 lower_color = sample_screen(
		signal_uv + vec2(0.0, luma_texel.y * vertical_softness),
		source_softness_lod + 0.15
	);
	float luminance = rgb_to_yiq(low_color).x * 0.50
		+ rgb_to_yiq(left_color).x * 0.19
		+ rgb_to_yiq(right_color).x * 0.19
		+ rgb_to_yiq(upper_color).x * 0.06
		+ rgb_to_yiq(lower_color).x * 0.06;

	float chroma_drift = (noise_1d(TIME * 1.13 + 28.4) - 0.5) * 2.0 * chroma_drift_pixels;
	float alignment = (noise_1d(TIME * 2.37 + 11.8) - 0.5) * 2.0 * chroma_alignment_pixels;
	vec2 chroma_uv = signal_uv + vec2((chroma_drift + alignment) * SCREEN_PIXEL_SIZE.x, 0.0);
	chroma_uv += centered_uv * radius_squared * SCREEN_PIXEL_SIZE * 0.3;
	vec2 chroma_texel = 1.0 / chroma_resolution;
	vec3 center_yiq = rgb_to_yiq(sample_low_resolution(
		chroma_uv,
		chroma_resolution,
		source_softness_lod + 1.0
	));
	vec3 left_yiq = rgb_to_yiq(sample_low_resolution(
		chroma_uv - vec2(chroma_texel.x, 0.0),
		chroma_resolution,
		source_softness_lod + 1.15
	));
	vec3 right_yiq = rgb_to_yiq(sample_low_resolution(
		chroma_uv + vec2(chroma_texel.x, 0.0),
		chroma_resolution,
		source_softness_lod + 1.15
	));

	vec2 blurred_chroma = (left_yiq.yz + right_yiq.yz) * 0.5;
	float warm_amount = smoothstep(0.0, 0.28, center_yiq.y);
	float warm_bleed = min(chroma_bleed * 1.18, 1.0);
	float effective_bleed = mix(chroma_bleed, warm_bleed, warm_amount);
	vec2 chroma = mix(center_yiq.yz, blurred_chroma, effective_bleed);
	float alignment_ratio = alignment * SCREEN_PIXEL_SIZE.x / max(2.0 * chroma_texel.x, 0.00001);
	chroma.x += (right_yiq.y - left_yiq.y) * alignment_ratio;
	chroma.y -= (right_yiq.z - left_yiq.z) * alignment_ratio * 0.7;

	float fine_noise = noise_2d(FRAGCOORD.xy * 0.47 + vec2(frame * 7.1, -frame * 3.7)) - 0.5;
	float soft_noise = noise_2d(FRAGCOORD.xy * 0.16 + vec2(-frame * 2.3, frame * 1.9)) - 0.5;
	float cloudy_noise = noise_2d(SCREEN_UV * vec2(7.0, 4.0) + vec2(TIME * 0.13, -TIME * 0.09)) - 0.5;
	float speck_seed = hash_2d(floor(FRAGCOORD.xy / vec2(2.0, 1.0)) + vec2(frame * 13.0, frame * 5.0));
	float speck = smoothstep(0.986, 1.0, speck_seed);
	speck *= hash_2d(vec2(speck_seed * 97.0, frame)) < 0.5 ? -1.0 : 1.0;
	float tape_noise = fine_noise * 0.55 + soft_noise * 0.30 + cloudy_noise * 0.15 + speck * 0.45;
	luminance += tape_noise * grain_strength;

	float color_noise_a = noise_2d(FRAGCOORD.xy * 0.10 + vec2(frame * 1.7, -frame * 2.1)) - 0.5;
	float color_noise_b = noise_2d(FRAGCOORD.xy * 0.13 + vec2(-frame * 2.9, frame * 1.3)) - 0.5;
	chroma += vec2(color_noise_a, color_noise_b) * chroma_noise_strength;

	float shadow_saturation = mix(0.72, 1.0, smoothstep(0.08, 0.42, luminance));
	chroma *= saturation * shadow_saturation;
	chroma.x *= 1.0 + 0.14 * smoothstep(0.0, 0.3, chroma.x);
	vec3 screen_color = yiq_to_rgb(vec3(luminance, chroma));

	vec3 neighboring_highlights = max((left_color + right_color) * 0.5 - vec3(0.62), vec3(0.0));
	screen_color += neighboring_highlights * vec3(1.18, 0.92, 0.68) * highlight_bleed;
	screen_color *= vec3(1.045, 1.015, 0.93);
	float brightness_drift = (noise_1d(TIME * 0.29 + 52.6) - 0.5) * 0.035;
	float exposure_drift = (noise_1d(TIME * 0.17 + 8.4) - 0.5) * 2.0 * exposure_pump;
	screen_color *= exposure + exposure_drift + brightness_drift;
	// This shoulder overexposes detail before white while retaining old-video limited range.
	screen_color = (1.0 - exp(-max(screen_color, vec3(0.0)) * 1.35)) * 1.18;
	screen_color = min(screen_color, vec3(0.965));
	screen_color = screen_color * 0.975 + vec3(0.018, 0.020, 0.015);

	float bottom_static = tracking_envelope * smoothstep(0.76, 1.0, SCREEN_UV.y);
	screen_color += vec3(tape_noise * 0.18 + color_noise_a * 0.04) * (tracking_amount + bottom_static);
	float line_structure = (mod(floor(FRAGCOORD.y), 2.0) - 0.5) * 0.006;
	screen_color *= 1.0 + line_structure;
	float vignette = 1.0 - smoothstep(0.48, 1.42, length(centered_uv));
	float exhaustion_vignette = 1.0 - smoothstep(0.25, 1.0, length(centered_uv));
	screen_color *= mix(1.0, vignette, vignette_strength)
		* mix(1.0, exhaustion_vignette, exhaustion_vignette_strength);

	COLOR = vec4(clamp(screen_color, vec3(0.0), vec3(1.0)), 1.0);
}
