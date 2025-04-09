extends Node2D

func _physics_process(delta: float) -> void:
	var movement = Vector2(Input.get_axis("left1", "right1"), Input.get_axis("up1", "down1")).normalized()
	$tentacle.goal_point = movement * $tentacle.max_speed * delta + $tentacle.points[-1]
	$tentacle.distance_chain_forward_movement(delta)
	$tentacle.distance_chain_anchor_movement(delta)
