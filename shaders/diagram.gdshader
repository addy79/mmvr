shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;
// Filled V or M diagram. The ribbon's top edge (UV.y = 1) is raised to the sampled,
// normalized value; the bottom edge stays on the axis.

uniform sampler2D beam_data : filter_linear, repeat_disable;  // BeamDataTexture
uniform float samples = 128.0;
uniform int channel = 0;              // 0 = shear V, 1 = moment M (row 1)
uniform float height = 0.35;          // display height of |value| = max [m]
uniform vec4 positive_color : source_color = vec4(0.20, 0.70, 0.35, 0.75);
uniform vec4 negative_color : source_color = vec4(0.90, 0.55, 0.10, 0.75);

varying float value;

void vertex() {
	vec2 uv = vec2((UV.x * (samples - 1.0) + 0.5) / samples, 0.75);
	vec4 sample = textureLod(beam_data, uv, 0.0);
	value = channel == 0 ? sample.r : sample.g;
	VERTEX.y = UV.y * value * height;
}

void fragment() {
	vec4 c = value >= 0.0 ? positive_color : negative_color;
	ALBEDO = c.rgb;
	ALPHA = c.a;
}
