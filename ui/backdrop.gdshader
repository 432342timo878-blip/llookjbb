shader_type canvas_item;
// App background: a soft dark gradient with two faint glows. When a photo is set it is
// cover-fitted, blurred (mip level), tinted very dark and faded towards the bottom,
// so the panels on top stay perfectly readable.

uniform vec4 base : source_color = vec4(0.07, 0.078, 0.102, 1.0);
uniform vec4 glow : source_color = vec4(1.0, 0.353, 0.212, 1.0);
uniform sampler2D photo : source_color, filter_linear_mipmap, repeat_disable;
uniform bool has_photo = false;
uniform vec2 photo_size = vec2(1.0, 1.0);
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform float photo_strength : hint_range(0.0, 1.0) = 0.30;
uniform float blur_lod : hint_range(0.0, 6.0) = 3.5;

void fragment() {
	vec2 uv = UV;
	vec3 col = base.rgb;
	col += glow.rgb * smoothstep(0.95, 0.0, distance(uv * vec2(rect_size.x / rect_size.y, 1.0), vec2(rect_size.x / rect_size.y, 0.0))) * 0.07;
	col += vec3(0.10, 0.17, 0.33) * smoothstep(0.9, 0.0, distance(uv * vec2(rect_size.x / rect_size.y, 1.0), vec2(0.0, 1.0))) * 0.10;
	if (has_photo) {
		float s = max(rect_size.x / photo_size.x, rect_size.y / photo_size.y);
		vec2 puv = (uv - 0.5) * rect_size / (photo_size * s) + 0.5;
		vec3 p = textureLod(photo, puv, blur_lod).rgb;
		float lum = dot(p, vec3(0.299, 0.587, 0.114));
		p = mix(vec3(lum), p, 0.8) * vec3(1.0, 0.96, 0.92);   // slightly desaturated, warm
		float fade = smoothstep(0.0, 1.0, uv.y);               // strongest at the top, gone at the bottom
		col = mix(col, p * 0.75, photo_strength * mix(1.0, 0.25, fade));
	}
	// Vignette
	float v = smoothstep(1.15, 0.35, distance(uv, vec2(0.5)));
	col *= mix(0.72, 1.0, v);
	COLOR = vec4(col, 1.0);
}
