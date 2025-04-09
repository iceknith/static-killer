shader_type canvas_item;

uniform vec4 line_color : source_color = vec4(1.0);
uniform float line_thickness : hint_range(0, 1) = 0.1;
uniform float x_cap : hint_range(0.0, 1.0) = 0.25;
uniform float x_acceleration : hint_range(0.0, 1.0) = 0.55;
uniform bool reversed = false;

void fragment() {
	float x_offset;
	if (reversed) {
		x_offset = (x_cap - UV.x) / x_cap * x_acceleration;
	}
	else {
		x_offset = (UV.x - 1.0 + x_cap) / x_cap * x_acceleration;
	}
	if (x_offset > .0 && (UV.y <= line_thickness + x_offset || UV.y >= 1.0 - line_thickness - x_offset)){
		COLOR = line_color;
	}
	else if (UV.y <= line_thickness  || UV.y >= 1.0 - line_thickness){
		COLOR = line_color;
	}
	/*
	else{
		COLOR = vec4(UV, 1, 1);
	}
	*/
}