shader_type spatial;
render_mode cull_disabled;
// Tension-test specimen along local +X (gauge length 0..L): stretched by `stretch`,
// slimmed by `diameter_ratio`, with a local neck at mid-length. Values come from
// StressStrainCurve; the shader only applies them. Broken specimens open at the neck.

uniform float gauge_length = 0.6;
uniform float stretch = 1.0;           // (1 + eps), drawn
uniform float diameter_ratio = 1.0;    // d/d0 away from the neck
uniform float neck = 0.0;              // extra fractional reduction at the neck
uniform float stress_ratio = 0.0;      // sigma / sigma_U
uniform bool broken = false;
uniform vec3 low_color : source_color = vec3(0.8, 0.82, 0.85);
uniform vec3 high_color : source_color = vec3(0.95, 0.3, 0.15);

varying float u;

void vertex() {
	u = VERTEX.x / gauge_length;
	float profile = diameter_ratio * (1.0 - neck * exp(-pow((u - 0.5) / 0.07, 2.0)));
	VERTEX.yz *= profile;
	VERTEX.x *= stretch;
	if (broken) {
		VERTEX.x += (u > 0.5 ? 0.04 : -0.04);
	}
}

void fragment() {
	if (broken && u > 0.5 && u < 0.5 + 1.0 / 32.0) {  // the mesh segment just above mid-length
		discard;
	}
	vec3 col = mix(low_color, high_color, clamp(stress_ratio, 0.0, 1.0));
	// Gauge marks at 10% and 90% of the original gauge length.
	if (abs(u - 0.1) < 0.006 || abs(u - 0.9) < 0.006) {
		col = vec3(0.1, 0.1, 0.12);
	}
	ALBEDO = col;
	METALLIC = 0.4;
	ROUGHNESS = 0.4;
}
