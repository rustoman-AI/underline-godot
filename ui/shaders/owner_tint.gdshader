shader_type canvas_item;

uniform vec4 owner_color : source_color = vec4(1.0);
varying vec4 unit_modulate;

void vertex() {
	unit_modulate = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float light = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
	float chroma = max(pixel.r, max(pixel.g, pixel.b)) - min(pixel.r, min(pixel.g, pixel.b));
	float value = max(pixel.r, max(pixel.g, pixel.b));
	float mask = step(chroma, 6.0 / 255.0 + 0.00001)
		* step(abs(value - 181.0 / 255.0), 16.0 / 255.0 + 0.00001);
	pixel.rgb = mix(pixel.rgb, owner_color.rgb * light / (181.0 / 255.0), mask);
	COLOR = pixel * unit_modulate;
}
