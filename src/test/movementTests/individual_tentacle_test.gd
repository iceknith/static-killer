extends Line2D

@export var max_distance:float = 60
@export var number_of_points:int = 5
@export var anchor_position:Vector2 = Vector2(250, 125)

@export var max_speed:float = .0
@export var acceleration:float = 30.0


@export var tentacle_wave_speed:float = 5
@export var tentacle_wave_amplitude:float = 1
@export var tentacle_wave_frequency:float = 30

var base_points:PackedVector2Array = []
var tentacle_wave_offset:float = 0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	for i in range(number_of_points):
		base_points.append(anchor_position)
	
	points = base_points

func _draw() -> void:
	for point in points:
		draw_circle(point, 10, Color.AQUA)

func _physics_process(delta: float) -> void:
	if points.is_empty(): return
	
	var goal_point = get_viewport().get_mouse_position()
	var temp_goal_point:Vector2 = base_points[-1] + (goal_point - base_points[-1]).normalized() * min(max_speed, base_points[-1].distance_to(goal_point))
	base_points[-1] = goal_point
	distance_chain_constraint(delta)
	tentacle_movements(delta)
	
	$Sprite2D.position = points[number_of_points/2]
	$Sprite2D.rotation = - points[number_of_points/2 - 1].angle_to(points[number_of_points/2 + 1]) * 180/PI

func distance_chain_constraint(delta:float) -> void:
	for i in range(base_points.size()-2, -1, -1):
		base_points[i] = constraint_distance(base_points[i], base_points[i+1], max_distance)
	
	# Anchor
	base_points[0] = anchor_position
	for i in range(1, base_points.size()):
		base_points[i] = constraint_distance(base_points[i], base_points[i-1], max_distance)

func tentacle_movements(delta:float) -> void:
	tentacle_wave_offset += delta * tentacle_wave_speed
	if tentacle_wave_offset > 2*PI: tentacle_wave_offset -= 2*PI
	
	var x:float = tentacle_wave_offset
	var distance_multiplier:float = 1/tentacle_wave_frequency
	
	for i in range(1, base_points.size()):
		# calculate sin offset
		x += distance_multiplier * base_points[i-1].distance_to(base_points[i])
		var offset = sin(x) * tentacle_wave_amplitude
		# calculate normal
		var movement = base_points[i] - base_points[i-1]
		var normal = Vector2(-movement.y, movement.x).normalized()
		# set point
		points[i] = base_points[i] + normal * offset

func constraint_distance(point:Vector2, anchor:Vector2, distance) -> Vector2:
	return point + (anchor - point).normalized() * (anchor.distance_to(point) - distance)
