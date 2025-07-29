shader_type canvas_item;

uniform sampler2D curve_texture : repeat_disable, filter_linear;
uniform bool inverted = false;

uniform float outline_size : hint_range(0, 1) = .1;
uniform vec4 outline_color : source_color = vec4(1.);

uniform float speed = 5.0;
uniform sampler2D amplitude_curve_texture : repeat_disable, filter_linear;
uniform float amplitude : hint_range(0.0, 10.0) = 2;
uniform float period : hint_range(0.0, 20.0) = .1;

void vertex() {
	float y = abs(1.0 - 2.0*UV.y);
	float amplitude_curve = texture(amplitude_curve_texture, vec2(UV.x,y)).r;
	float amplitude_mult = amplitude_curve - (y - 1.0);

	vec2 normal = COLOR.xy*2.0 - vec2(1.0);
	VERTEX += sin(UV.x * period + TIME * speed) * amplitude * amplitude_mult * normal;
}

void fragment() {
	float y = abs(1.0 - 2.0*UV.y);
	float curve = texture(curve_texture, vec2(UV.x,0)).r;
	float line_outline = outline_size/curve - (1.0 - y);

	if (line_outline > 0.0){
		// If we are inside the outline
		COLOR = outline_color;
	}
	else {
		COLOR = vec4(0,0,0,1);
	}
}
