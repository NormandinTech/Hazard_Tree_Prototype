shader_type canvas_item;
// Camcorder look: color bleed, tracking wobble, scan lines, grain, vignette.
// `glitch` (0..1) is raised by the game when something is in frame.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float noise_amount = 0.08;
uniform float scanline_strength = 0.14;
uniform float color_bleed = 0.0025;
uniform float vignette = 0.45;
uniform float glitch = 0.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Tracking wobble, plus horizontal tearing when glitch is up.
	float line = floor(uv.y * 240.0);
	uv.x += (rand(vec2(line, floor(TIME * 12.0))) - 0.5) * 0.002;
	uv.x += glitch * (rand(vec2(floor(uv.y * 30.0), floor(TIME * 20.0))) - 0.5) * 0.06;

	float bleed = color_bleed * (1.0 + glitch * 3.0);
	float r = texture(screen_tex, uv + vec2(bleed, 0.0)).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - vec2(bleed, 0.0)).b;
	vec3 col = vec3(r, g, b);

	// Washed-out, slightly warm tape color.
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, 0.6) * vec3(1.05, 1.0, 0.92);

	col *= 1.0 - scanline_strength * (0.5 + 0.5 * sin(SCREEN_UV.y * 900.0));
	col += (rand(SCREEN_UV * (TIME + 1.0)) - 0.5) * (noise_amount + glitch * 0.15);

	float d = distance(SCREEN_UV, vec2(0.5));
	col *= 1.0 - vignette * smoothstep(0.35, 0.8, d);

	COLOR = vec4(col, 1.0);
}
