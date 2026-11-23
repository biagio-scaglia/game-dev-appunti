shader_type canvas_item;
// Dietro il menu: il gioco fermo, quasi grigio e più buio ai bordi, con le righe di
// scansione e i colori un po' sdoppiati. Ogni tanto lo sdoppiamento salta.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// 0 = il gioco com'è, 1 = l'effetto pieno (la si porta su all'apertura).
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float aberration = 1.5;
uniform vec3 tint = vec3(0.7, 0.66, 0.95);

float hash(float n) {
	return fract(sin(n * 91.7) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float tick = floor(TIME * 14.0);
	float jump = step(0.94, hash(tick)) * 4.0;
	// Una banda orizzontale che si sposta di lato, di rado.
	float band = step(0.97, hash(tick + 3.0)) * step(abs(uv.y - hash(tick + 7.0)), 0.03);
	uv.x += band * 0.01;
	vec2 off = vec2(SCREEN_PIXEL_SIZE.x * (aberration + jump), 0.0);
	vec3 shifted = vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g,
		texture(screen_tex, uv - off).b);
	float grey = dot(shifted, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(shifted, grey * tint, 0.8);
	col *= 1.0 - smoothstep(0.3, 0.8, distance(SCREEN_UV, vec2(0.5))) * 0.85;
	col *= 0.5 + 0.08 * step(0.5, fract(FRAGCOORD.y * 0.5));
	vec3 plain = texture(screen_tex, SCREEN_UV).rgb;
	COLOR = vec4(mix(plain, col, strength), 1.0);
}
