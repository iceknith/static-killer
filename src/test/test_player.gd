extends Node2D

@export var max_distance:float = 6

@export var initial_pos_tentacle1:Vector2 = Vector2(-11, -1)
@export var initial_pos_tentacle2:Vector2 = Vector2(11, -1)

@export var anchor_position = Vector2(250, 125)

func _ready() -> void:
	$tentacle1.anchor_position = anchor_position
	$head.position = anchor_position

func _physics_process(delta: float) -> void:
	if ($tentacle1.points.is_empty() || $tentacle2.points.is_empty()): return
	
	# Forward
	var movement = Vector2(Input.get_axis("left1", "right1"), Input.get_axis("up1", "down1")).normalized()
	$tentacle2.goal_point = movement * $tentacle2.max_speed * delta + $tentacle2.points[-1]
	$tentacle2.distance_chain_forward_movement(delta)
	
	$head.rotation = $tentacle1.points[-1].angle_to_point($tentacle2.points[0])
	var rotated_pos_tentacle1 = initial_pos_tentacle1.rotated($head.rotation)
	var rotated_pos_tentacle2 = initial_pos_tentacle2.rotated($head.rotation)
	
	
	var new_pos = $tentacle2.points[0] - rotated_pos_tentacle2
	
	$tentacle1.goal_point = new_pos + rotated_pos_tentacle1
	$tentacle1.distance_chain_forward_movement(delta)
	
	# Backwards
	$tentacle1.distance_chain_anchor_movement(delta)
	
	new_pos = $tentacle1.points[-1] - rotated_pos_tentacle1
	
	$tentacle2.anchor_position = new_pos + rotated_pos_tentacle2
	$tentacle2.distance_chain_anchor_movement(delta)
	
	$head.position = new_pos

func constraint_distance(point:Vector2, anchor:Vector2, distance) -> Vector2:
	return point + (anchor - point).normalized() * max(0, anchor.distance_to(point) - distance)
