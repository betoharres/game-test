shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float pixel_size : hint_range(1.0, 8.0, 1.0) = 2.0;
uniform float color_levels : hint_range(2.0, 32.0, 1.0) = 16.0;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.65;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.08;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;

float bayer_2x2(vec2 position) {
	vec2 cell = mod(floor(position), 2.0);
	float top_row = cell.x * 2.0;
	float bottom_row = 3.0 - cell.x * 2.0;
	return (mix(top_row, bottom_row, cell.y) + 0.5) / 4.0 - 0.5;
}

void fragment() {
	vec2 texel_size = SCREEN_PIXEL_SIZE * pixel_size;
	vec2 pixel_uv = (floor(SCREEN_UV / texel_size) + 0.5) * texel_size;
	vec3 screen_color = texture(screen_texture, pixel_uv).rgb;

	float level_count = color_levels - 1.0;
	float dither = bayer_2x2(FRAGCOORD.xy / pixel_size) * dither_strength;
	screen_color = floor(clamp(screen_color * level_count + dither + 0.5, 0.0, level_count)) / level_count;

	float scanline = mix(1.0 - scanline_strength, 1.0, mod(floor(FRAGCOORD.y), 2.0));
	vec2 centered_uv = SCREEN_UV * 2.0 - 1.0;
	float vignette = 1.0 - smoothstep(0.45, 1.35, length(centered_uv));
	screen_color *= scanline * mix(1.0, vignette, vignette_strength);

	COLOR = vec4(screen_color, 1.0);
}
