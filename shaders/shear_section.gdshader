shader_type spatial;
// Beam segment seen end-on: colored by the shear stress tau(y) sampled by the CPU from the
// shear formula (PROFILE_SAMPLES values from y = -c to +c, normalized), with the area
// beyond the cut level hatched (the area A' whose first moment is Q).

const int PROFILE_SAMPLES = 33;
uniform float tau_profile[PROFILE_SAMPLES];
uniform float half_depth = 0.3;   // drawn c [m]
uniform float y_cut = 0.0;        // drawn cut height [m]
uniform vec3 low_color : source_color = vec3(0.86, 0.86, 0.84);
uniform vec3 high_color : source_color = vec3(0.1, 0.65, 0.95);

varying vec3 rest;

void vertex() {
	rest = VERTEX;
}

void fragment() {
	float s = clamp((rest.y + half_depth) / (2.0 * half_depth), 0.0, 1.0) * float(PROFILE_SAMPLES - 1);
	int i = int(floor(s));
	int j = min(i + 1, PROFILE_SAMPLES - 1);
	float tau = mix(tau_profile[i], tau_profile[j], s - float(i));
	vec3 col = mix(low_color, high_color, clamp(tau, 0.0, 1.0));
	bool beyond = y_cut >= 0.0 ? rest.y > y_cut : rest.y < y_cut;
	if (beyond && fract((rest.y + rest.z) * 25.0) < 0.35) {
		col = mix(col, vec3(1.0, 0.75, 0.2), 0.8);
	}
	ALBEDO = col;
	ROUGHNESS = 0.6;
}
