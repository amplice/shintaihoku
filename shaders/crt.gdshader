shader_type canvas_item;

// CRT/PS1 post-processing: scanlines, vignette, chromatic aberration, noise grain, speed blur
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float scanline_frequency : hint_range(100.0, 800.0) = 300.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float aberration_amount : hint_range(0.0, 5.0) = 0.0;
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.02;
uniform float speed_blur : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Chromatic aberration - shift R and B channels slightly
	float ab = aberration_amount / 1000.0;
	float r = texture(SCREEN_TEXTURE, vec2(uv.x + ab, uv.y)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, vec2(uv.x - ab, uv.y)).b;
	vec3 color = vec3(r, g, b);

	// Speed-based radial blur (stronger at screen edges)
	if (speed_blur > 0.01) {
		vec2 center = vec2(0.5, 0.5);
		vec2 dir = uv - center;
		float dist_from_center = length(dir);
		float edge_factor = smoothstep(0.15, 0.5, dist_from_center);
		vec2 blur_dir = normalize(dir) * speed_blur * dist_from_center * 0.03;
		vec3 blur_col = color * 0.4;
		blur_col += texture(SCREEN_TEXTURE, uv - blur_dir).rgb * 0.25;
		blur_col += texture(SCREEN_TEXTURE, uv - blur_dir * 2.0).rgb * 0.2;
		blur_col += texture(SCREEN_TEXTURE, uv - blur_dir * 3.0).rgb * 0.15;
		color = mix(color, blur_col, edge_factor * speed_blur);
	}

	// Scanlines
	float scanline = sin(uv.y * scanline_frequency * PI) * 0.5 + 0.5;
	scanline = pow(scanline, 0.8);
	color *= 1.0 - scanline_intensity * (1.0 - scanline);

	// Vignette (darken edges)
	vec2 vig_uv = uv * (1.0 - uv);
	float vig = vig_uv.x * vig_uv.y * 15.0;
	vig = pow(vig, vignette_intensity);
	color *= vig;

	// Film grain noise
	float noise = rand(uv + vec2(TIME * 0.01, TIME * 0.02)) * noise_intensity;
	color += vec3(noise) - vec3(noise_intensity * 0.5);

	COLOR = vec4(color, 1.0);
}
