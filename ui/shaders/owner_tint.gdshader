shader_type canvas_item;

uniform vec4 owner_color : source_color = vec4(1.0);
uniform float owner_grey = 0.70980392;
uniform float owner_spread = 0.02352941;
uniform float owner_tolerance = 0.06274510;
uniform vec4 tint_region = vec4(0.0, 0.0, 1.0, 1.0);
varying vec4 unit_modulate;

void vertex() {
	unit_modulate = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float light = dot(pixel.rgb, vec3(0.2126, 0.7152, 0.0722));
	float chroma = max(pixel.r, max(pixel.g, pixel.b)) - min(pixel.r, min(pixel.g, pixel.b));
	float value = max(pixel.r, max(pixel.g, pixel.b));
	float mask = step(chroma, owner_spread + 0.00001)
		* step(abs(value - owner_grey), owner_tolerance + 0.00001)
		* step(tint_region.x, UV.x) * step(tint_region.y, UV.y)
		* step(UV.x, tint_region.z) * step(UV.y, tint_region.w);
	pixel.rgb = mix(pixel.rgb, owner_color.rgb * light / max(owner_grey, 0.001), mask);
	COLOR = pixel * unit_modulate;
}
