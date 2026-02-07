shader_type spatial;

// PS1-style shader: vertex jitter, color banding, fog
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_disabled;

uniform vec4 albedo_color : source_color = vec4(0.4, 0.4, 0.45, 1.0);
uniform float vertex_snap_intensity : hint_range(1.0, 10.0, 0.5) = 1.0;
uniform float color_depth : hint_range(2.0, 32.0, 1.0) = 15.0;
uniform vec4 fog_color : source_color = vec4(0.02, 0.02, 0.08, 1.0);
uniform float fog_distance : hint_range(10.0, 200.0, 1.0) = 60.0;
uniform float fog_density : hint_range(0.0, 5.0, 0.1) = 1.5;
uniform bool emissive = false;
uniform vec4 emission_color : source_color = vec4(1.0, 0.0, 0.5, 1.0);
uniform float emission_strength : hint_range(0.0, 10.0, 0.1) = 2.0;
uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_enable;
uniform bool use_texture = false;
uniform bool wet_surface = false;
uniform float wet_strength : hint_range(0.0, 1.0, 0.05) = 0.3;

varying float vertex_distance;
varying vec3 world_normal;

void vertex() {
	// Transform to clip space
	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// Vertex snapping - snap to lower resolution grid (PS1 vertex jitter)
	float snap = vertex_snap_intensity * 50.0;
	clip_pos.xyz = clip_pos.xyz / clip_pos.w;
	clip_pos.x = floor(clip_pos.x * snap + 0.5) / snap;
	clip_pos.y = floor(clip_pos.y * snap + 0.5) / snap;
	clip_pos.xyz *= clip_pos.w;

	POSITION = clip_pos;

	// Calculate distance for fog
	vec4 world_pos = MODEL_MATRIX * vec4(VERTEX, 1.0);
	vertex_distance = length((VIEW_MATRIX * world_pos).xyz);

	// Pass world normal for wet surface
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 color;
	if (use_texture) {
		color = texture(albedo_texture, UV).rgb * albedo_color.rgb;
	} else {
		color = albedo_color.rgb;
	}

	// Color banding - reduce color precision
	color = floor(color * color_depth) / color_depth;

	ALBEDO = color;

	// Distance-based emission fade for emissive surfaces
	float fog_factor = 1.0 - exp(-vertex_distance * fog_density / fog_distance);
	fog_factor = clamp(fog_factor, 0.0, 1.0);

	if (emissive) {
		EMISSION = emission_color.rgb * emission_strength;
		EMISSION = mix(EMISSION, vec3(0.0), fog_factor * 0.7);
	}

	// Wet surface: fake Fresnel specular shimmer
	if (wet_surface) {
		vec3 view_dir = normalize(VIEW);
		float fresnel = 1.0 - abs(dot(view_dir, NORMAL));
		fresnel = pow(fresnel, 3.0) * wet_strength;
		// Add subtle blue-white sheen
		EMISSION += vec3(0.4, 0.45, 0.6) * fresnel;
		// Darken albedo slightly to simulate wet darkening
		ALBEDO *= 0.85;
	}
}
