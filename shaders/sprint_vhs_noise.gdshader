shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float grain_strength : hint_range(0.0, 0.3, 0.005) = 0.1;
uniform float chroma_noise_strength : hint_range(0.0, 0.2, 0.005) = 0.035;
uniform float horizontal_jitter_pixels : hint_range(0.0, 4.0, 0.05) = 0.35;
uniform float static_band_strength : hint_range(0.0, 0.5, 0.01) = 0.14;
uniform float speck_strength : hint_range(0.0, 0.5, 0.01) = 0.001;

float hash_2d(vec2 value) {
	vec3 p = fract(vec3(value.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	float frame = floor(TIME * 59.94);
	float row = floor(SCREEN_UV.y * 240.0);
	float row_noise = hash_2d(vec2(row * 0.731, frame)) * 2.0 - 1.0;
	float row_jitter = sign(row_noise) * pow(abs(row_noise), 9.0) * horizontal_jitter_pixels;
	vec2 signal_uv = clamp(
		SCREEN_UV + vec2(row_jitter * SCREEN_PIXEL_SIZE.x, 0.0),
		vec2(0.0),
		vec2(1.0)
	);
	vec3 screen_color = texture(screen_texture, signal_uv).rgb;

	float fine_noise = hash_2d(floor(FRAGCOORD.xy) + vec2(frame * 17.0, -frame * 11.0)) - 0.5;
	float line_noise = hash_2d(vec2(row, floor(frame * 0.5))) - 0.5;
	float band_center = fract(TIME * 0.37 + hash_2d(vec2(floor(TIME * 0.37), 31.7)));
	float static_band = 1.0 - smoothstep(0.015, 0.09, abs(SCREEN_UV.y - band_center));
	float speck_seed = hash_2d(floor(FRAGCOORD.xy / vec2(2.0, 1.0)) + vec2(frame * 23.0, frame * 7.0));
	float speck = smoothstep(0.975, 1.0, speck_seed);
	float luma_noise = fine_noise * grain_strength
		+ line_noise * grain_strength * 0.45
		+ fine_noise * static_band * static_band_strength
		+ speck * speck_strength;
	screen_color += vec3(luma_noise);

	float red_noise = hash_2d(floor(FRAGCOORD.xy * 0.25) + vec2(frame * 5.0, frame * 3.0)) - 0.5;
	float blue_noise = hash_2d(floor(FRAGCOORD.xy * 0.2) + vec2(-frame * 3.0, frame * 7.0)) - 0.5;
	screen_color.r += red_noise * chroma_noise_strength;
	screen_color.b += blue_noise * chroma_noise_strength;

	COLOR = vec4(clamp(screen_color, vec3(0.0), vec3(1.0)), 1.0);
}
