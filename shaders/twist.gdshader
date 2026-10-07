shader_type spatial;
// Shaft under torsion: each cross-section turns about the axis by phi(x), linear from
// twist_start at x = 0 to twist_end at x = L.
// Longitudinal lines and rings are painted in the undeformed (material) coordinates, so
// they turn into helices; color shows tau = tau_max * rho/c (computed on the CPU side as
// stress_ratio = tau_max / color limit). No mechanics here beyond interpolation.

uniform float twist_start = 0.0;    // drawn rotation of the section at x = 0 [rad]
uniform float twist_end = 0.0;      // drawn rotation at x = L [rad]
uniform float shaft_length = 1.5;   // L [m]
uniform float outer_radius = 0.03;  // c [m]
uniform float stress_ratio = 1.0;   // tau_max / color limit
uniform float line_count = 12.0;
uniform vec3 low_color : source_color = vec3(0.86, 0.86, 0.84);
uniform vec3 high_color : source_color = vec3(0.95, 0.45, 0.1);

varying vec3 rest;

void vertex() {
	rest = VERTEX;
	float phi = mix(twist_start, twist_end, clamp(VERTEX.x / shaft_length, 0.0, 1.0));
	float c = cos(phi);
	float s = sin(phi);
	VERTEX.yz = vec2(c * VERTEX.y - s * VERTEX.z, s * VERTEX.y + c * VERTEX.z);
	NORMAL.yz = vec2(c * NORMAL.y - s * NORMAL.z, s * NORMAL.y + c * NORMAL.z);
}

void fragment() {
	float rho = length(rest.yz) / outer_radius;
	float t = clamp(rho * stress_ratio, 0.0, 1.0);
	vec3 col = mix(low_color, high_color, t);
	float angle = atan(rest.z, rest.y) / (2.0 * PI) * line_count;
	float ring = rest.x / shaft_length * 10.0;
	float line_a = smoothstep(0.06, 0.0, abs(fract(angle + 0.5) - 0.5));
	float line_r = smoothstep(0.03, 0.0, abs(fract(ring + 0.5) - 0.5));
	col = mix(col, vec3(0.08, 0.1, 0.15), max(line_a, line_r) * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.5;
}
