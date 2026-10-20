shader_type canvas_item;

uniform vec4 owner_color : source_color = vec4(1.0);
uniform float tolerance = 0.075;

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float light = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
	float chroma = max(pixel.r, max(pixel.g, pixel.b)) - min(pixel.r, min(pixel.g, pixel.b));
	float mask = (1.0 - smoothstep(tolerance * 0.5, tolerance, chroma))
		* (1.0 - smoothstep(tolerance, tolerance * 2.0, abs(light - 0.784314)));
	pixel.rgb = mix(pixel.rgb, owner_color.rgb * light / 0.784314, mask);
	COLOR = pixel * COLOR;
}
