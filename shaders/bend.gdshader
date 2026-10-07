shader_type spatial;
render_mode cull_disabled;
// Segment in pure bending: plane sections rotate about the neutral axis and the axis
// becomes a circular arc of curvature k (drawn, exaggerated). A grid of vertical lines
// (cross-sections) and horizontal lines (fibers) shows plane sections remaining plane.
// Color: stress -M*y/I normalized, passed as the sign of M and a ratio.

uniform float curvature = 0.0;        // drawn 1/rho [1/m], > 0 sags
uniform float segment_length = 1.6;   // [m], mesh spans x = 0..L
uniform float half_depth = 0.1;       // c [m]
uniform float stress_ratio = 1.0;     // sigma_max / color limit
uniform float moment_sign = 1.0;
uniform vec3 tension_color : source_color = vec3(0.85, 0.12, 0.10);
uniform vec3 compression_color : source_color = vec3(0.10, 0.30, 0.90);
uniform vec3 neutral_color : source_color = vec3(0.86, 0.86, 0.84);

varying vec3 rest;

void vertex() {
	rest = VERTEX;
	float x = VERTEX.x - segment_length / 2.0;
	if (abs(curvature) > 1e-6) {
		float r0 = 1.0 / curvature;
		float phi = x * curvature;
		float r = r0 - VERTEX.y;
		VERTEX.x = r * sin(phi) + segment_length / 2.0;
		VERTEX.y = r0 - r * cos(phi);
		float c = cos(phi);
		float s = sin(phi);
		NORMAL.xy = vec2(c * NORMAL.x - s * NORMAL.y, s * NORMAL.x + c * NORMAL.y);
	}
}

void fragment() {
	// sigma = -M*y/I: compression above the neutral axis when M > 0.
	float t = clamp(-moment_sign * rest.y / half_depth * stress_ratio, -1.0, 1.0);
	vec3 col = mix(neutral_color, t > 0.0 ? tension_color : compression_color, abs(t));
	float sections = rest.x / segment_length * 8.0;
	float fibers = rest.y / half_depth * 2.0;
	float line_s = smoothstep(0.04, 0.0, abs(fract(sections + 0.5) - 0.5));
	float line_f = smoothstep(0.04, 0.0, abs(fract(fibers + 0.5) - 0.5));
	col = mix(col, vec3(0.08, 0.1, 0.15), max(line_s, line_f) * 0.8);
	if (abs(rest.y) < half_depth * 0.03) {
		col = vec3(1.0, 0.9, 0.3);  // neutral axis
	}
	ALBEDO = col;
	ROUGHNESS = 0.6;
}
