shader_type canvas_item;
// Your own eyes, through a cheap pair of safety glasses at 3 a.m.:
// fine grain, a little color fringing toward the edges, dark corners.
// `strength` fades it out while the camcorder (which has its own look) is up.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 1.0;
uniform float grain = 0.035;
uniform float fringe = 0.0022;
uniform float vignette = 0.38;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - vec2(0.5);
	float d = length(c);
	// Fringing grows toward the edges, like real glass.
	vec2 off = c * fringe * strength * d * 2.0;
	vec3 col;
	col.r = texture(screen_tex, uv + off).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - off).b;
	// Grain is stronger in the dark, where eyes and sensors both get noisy.
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	float n = rand(uv * vec2(1920.0, 1080.0) + fract(TIME * 7.13) * 100.0) - 0.5;
	col += n * grain * strength * mix(1.6, 0.5, clamp(lum * 2.0, 0.0, 1.0));
	col *= 1.0 - vignette * strength * smoothstep(0.3, 0.85, d);
	COLOR = vec4(col, 1.0);
}
