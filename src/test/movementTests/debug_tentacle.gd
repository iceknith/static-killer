extends Node2D


#func _physics_process(delta: float) -> void:
#	
#	var movement = Vector2(Input.get_axis("left1", "right1"), Input.get_axis("up1", "down1"))
#	if movement == Vector2.ZERO: return
#	
#	var old_pos:Vector2 = $tentacle.points[-1]
#	#$tentacle.set_movement(movement, delta)
#	var i = 0
#	var effective_speed = $tentacle.max_speed * delta
#	while old_pos.distance_squared_to($tentacle.points[-1]) < effective_speed ** 2 * 0.7 && i < 7:
#		$tentacle.goal_point = movement.normalized() * effective_speed + $tentacle.points[-1]
#		$tentacle.distance_chain_forward_movement(delta)
#		$tentacle.distance_chain_anchor_movement(delta)
#		i += 1
#	
#	$Label.text = str(($tentacle.points[-1] - old_pos).length()) + "\n" + str(i)


func _on_tentacle_test_movement(movement: float, iterations: int) -> void:
	$Label.text = "Vitesse: " + str(movement) + "\n" + "Nombre d'itération: " + str(iterations)
