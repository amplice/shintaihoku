shader_type spatial;

// Puddle shader: screen-space fake reflection with rain ripple distortion
render_mode blend_mix, depth_draw_opaque, cull_back, specular_disabled, unshaded;

uniform vec4 puddle_tint : source_color = vec4(0.05, 0.05, 0.1, 1.0);
uniform float reflection_strength : hint_range(0.0, 1.0) = 0.35;
uniform float ripple_speed : hint_range(0.5, 5.0) = 2.0;
uniform float ripple_scale : hint_range(1.0, 20.0) = 8.0;
uniform float ripple_strength : hint_range(0.0, 0.05) = 0.015;
uniform float edge_fade : hint_range(0.0, 1.0) = 0.3;
uniform vec4 neon_tint : source_color = vec4(0.0, 0.9, 1.0, 1.0);
uniform float neon_strength : hint_range(0.0, 3.0) = 0.8;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	// Rain ripple distortion using overlapping sine waves
	vec2 ripple_uv = UV * ripple_scale;
	float t = TIME * ripple_speed;

	// Multiple ripple layers for organic look
	float ripple = sin(ripple_uv.x * 3.0 + t) * sin(ripple_uv.y * 3.7 + t * 0.8) * 0.5;
	ripple += sin(ripple_uv.x * 7.0 - t * 1.3 + ripple_uv.y * 2.0) * 0.25;
	ripple += sin(length(ripple_uv - vec2(3.0, 4.0)) * 5.0 - t * 2.0) * 0.15;
	// Random raindrop impacts (sparse circular ripples)
	float drop1 = sin(length(ripple_uv - vec2(sin(t * 0.7) * 3.0, cos(t * 0.5) * 3.0)) * 12.0 - t * 4.0);
	float drop2 = sin(length(ripple_uv - vec2(cos(t * 0.3) * 2.0, sin(t * 0.9) * 4.0)) * 10.0 - t * 3.5);
	ripple += (max(drop1, 0.0) + max(drop2, 0.0)) * 0.2;

	vec2 distortion = vec2(ripple) * ripple_strength;

	// Sample screen with flipped Y for reflection + ripple distortion
	vec2 screen_uv = SCREEN_UV;
	screen_uv.y = 1.0 - screen_uv.y;  // flip for reflection
	screen_uv += distortion;

	vec3 reflected = texture(SCREEN_TEXTURE, screen_uv).rgb;

	// Edge fade based on UV distance from center
	float edge = smoothstep(0.0, edge_fade, UV.x) * smoothstep(0.0, edge_fade, 1.0 - UV.x)
			   * smoothstep(0.0, edge_fade, UV.y) * smoothstep(0.0, edge_fade, 1.0 - UV.y);

	// Mix: dark puddle base + reflected scene + neon color tint
	vec3 base = puddle_tint.rgb;
	vec3 color = mix(base, reflected, reflection_strength * edge);

	// Add neon color as subtle emission-like glow
	color += neon_tint.rgb * neon_strength * edge * (0.5 + ripple * 0.3);

	ALBEDO = color;

	// Slight emission to make puddles glow in dark scenes
	EMISSION = neon_tint.rgb * neon_strength * 0.3 * edge;
}
