shader_type spatial;
// Beam surface: displaced by the computed deflection curve and colored by the computed
// bending stress. No mechanics here: the shader only interpolates sampled results.

uniform sampler2D beam_data : filter_linear, repeat_disable;  // BeamDataTexture
uniform float samples = 128.0;          // texture width
uniform float deflection_scale = 0.0;   // v_max * exaggeration [m]
uniform float half_depth = 0.1;         // c [m]
uniform float beam_length = 4.0;        // L [m]
uniform float stress_ratio = 1.0;       // sigma_max / color-scale limit
uniform vec3 tension_color : source_color = vec3(0.85, 0.12, 0.10);
uniform vec3 compression_color : source_color = vec3(0.10, 0.30, 0.90);
uniform vec3 neutral_color : source_color = vec3(0.86, 0.86, 0.84);

varying float depth_t;   // 0 at bottom fiber, 1 at top fiber
varying float data_u;

// Texture coordinate of beam position u = x/L on row 0 (sample centers, not texel edges).
vec2 row0(float u) {
	return vec2((clamp(u, 0.0, 1.0) * (samples - 1.0) + 0.5) / samples, 0.25);
}

void vertex() {
	data_u = UV.x;
	depth_t = clamp((VERTEX.y + half_depth) / (2.0 * half_depth), 0.0, 1.0);
	float v = textureLod(beam_data, row0(UV.x), 0.0).r * deflection_scale;
	VERTEX.y -= v;
	// Tilt normals with the local slope of the displayed curve (finite difference).
	float du = 1.0 / (samples - 1.0);
	float dv = (textureLod(beam_data, row0(UV.x + du), 0.0).r
			- textureLod(beam_data, row0(UV.x - du), 0.0).r) * deflection_scale;
	float slope = dv / (2.0 * du * beam_length);
	NORMAL = normalize(vec3(NORMAL.x + NORMAL.y * slope, NORMAL.y - NORMAL.x * slope, NORMAL.z));
}

void fragment() {
	vec3 s = texture(beam_data, row0(data_u)).rgb;
	// Stress varies linearly through the depth between the two fiber values.
	float t = clamp(mix(s.b, s.g, depth_t) * stress_ratio, -1.0, 1.0);
	vec3 extreme = t > 0.0 ? tension_color : compression_color;
	ALBEDO = mix(neutral_color, extreme, abs(t));
	ROUGHNESS = 0.6;
}
