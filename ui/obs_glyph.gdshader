shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.957, 0.937, 0.894, 1.0);
void fragment() {
	float a = texture(TEXTURE, UV).a;
	COLOR = vec4(tint.rgb, a * tint.a);
}
