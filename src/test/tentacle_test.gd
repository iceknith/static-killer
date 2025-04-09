extends Line2D

@export var max_distance:float = 6
@export var number_of_points:int = 50
var anchor_position:Vector2

@export var max_speed:float = 200.0
@export var acceleration:float = 30.0

@export var inverted:bool = false
@export var debug_display:bool = false

@export var collision_circle_resolution:int = 10

var tentacle_wave_offset:float = 0

var goal_point:Vector2 = Vector2.ZERO
var space_state:PhysicsDirectSpaceState2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var temp_points:PackedVector2Array = []
	anchor_position = Vector2(400, 300)
	for i in range(number_of_points):
		temp_points.append(anchor_position)
	
	points = temp_points
	
	if inverted:
		invert()
		inverted = true
	else:
		send_width_curve_to_shader()

func _draw() -> void:
	if debug_display:
		for point in points:
			draw_circle(point, max_distance/5, Color.REBECCA_PURPLE)
			draw_circle(point, max_distance, Color.AZURE, false)

func distance_chain_forward_movement(delta:float) -> void:
	space_state = get_world_2d().direct_space_state
	# Move first point
	#var temp_goal_point:Vector2 = points[-1] + (goal_point - points[-1]).normalized() * min(max_speed, points[-1].distance_to(goal_point))
	points[-1] = movement_with_collisions(points[-1], goal_point)
	
	# Move other points
	for i in range(points.size()-2, -1, -1):
		var point_new_position:Vector2 = constraint_distance(points[i], points[i+1], max_distance)
		points[i] = chain_movement_with_collisions(points[i], point_new_position, points[i+1], max_distance)

func distance_chain_anchor_movement(delta:float) -> void:
	points[0] = anchor_position
	for i in range(1, points.size()):
		var point_new_position:Vector2 = constraint_distance(points[i], points[i-1], max_distance)
		if i != points.size()-1:
			points[i] = chain_movement_with_collisions(points[i], point_new_position, points[i-1], max_distance)
		else:
			points[i] = movement_with_collisions(points[i], point_new_position)
	
	calculate_and_store_normals()

func calculate_and_store_normals() -> void:
	gradient = Gradient.new()
	
	for i in range(points.size()):
		var tangent:Vector2
		if i == 0:
			tangent = (points[i+1] - points[i]).normalized()
		elif i == points.size() - 1:
			tangent = (points[i] - points[i-1]).normalized()
		else:
			tangent = (points[i+1] - points[i-1]).normalized()
		
		var normal = Vector2(-tangent.y, tangent.x)
		var color = Color((normal.x + 1.0)/2, (normal.y + 1.0)/2, 0.0, 1.0)
		gradient.add_point(float(i)/(points.size()-1), color)

func constraint_distance(point:Vector2, anchor:Vector2, distance:float) -> Vector2:
	return point + (anchor - point).normalized() * max(0, anchor.distance_to(point) - distance)

func movement_with_collisions(initial_position:Vector2, goal_position:Vector2) -> Vector2:
	var initial_global_position = initial_position + global_position
	var query = PhysicsRayQueryParameters2D.create(initial_global_position, goal_position + global_position)
	query.exclude = [self] 
	
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return goal_position
	
	else:
		 # Collision détectée, ajuster le déplacement
		var collision_point = result.position
		var collision_normal = result.normal
		
		# Trouver le mouvement projeté pour glisser le long de l'obstacle
		var slide_movement = (goal_position - initial_position).slide(collision_normal)
		
		# Vérifier si on peut se déplacer après avoir ajusté la trajectoire
		query = PhysicsRayQueryParameters2D.create(initial_global_position, initial_global_position + slide_movement)
		result = space_state.intersect_ray(query)
		if result.is_empty():
			return initial_position + slide_movement
	
	return initial_position

func chain_movement_with_collisions(initial_position:Vector2, goal_position:Vector2, anchor_position:Vector2, distance:float) -> Vector2:
	var initial_global_position = initial_position + global_position
	var point_querry = PhysicsPointQueryParameters2D.new()
	point_querry.position = goal_position
	point_querry.exclude = [self] 
	
	var result = space_state.intersect_point(point_querry)
	if result.is_empty():
		return goal_position
	
	else:
		# Collision détectée, trouver l'intersection entre le cercle et le bord
		
		# Définition du raycast
		var ray_querry = PhysicsRayQueryParameters2D.new()
		ray_querry.exclude = [self]
		ray_querry.hit_from_inside = false
		
		# Définition des positions
		var anchor_global_position:Vector2 = anchor_position + global_position
		var offset = PI/float(collision_circle_resolution)
		var pos1:Vector2
		var pos2:Vector2
		
		# Définition de l'angle initial
		var init_angle = (anchor_position - goal_position).angle()
		
		# Itération dans le sens positif
		var angle = init_angle
		while angle <= init_angle+PI:
			ray_querry.from = anchor_global_position + Vector2.from_angle(angle) * distance
			ray_querry.to = anchor_global_position + Vector2.from_angle(angle + offset) * distance
			
			result = space_state.intersect_ray(ray_querry)
			if !result.is_empty():
				pos1 = result.position
			
			angle += offset
			
		# Itération dans le sens négatif
		angle = init_angle
		while angle >= init_angle-PI:
			ray_querry.from = anchor_global_position + Vector2.from_angle(angle) * distance
			ray_querry.to = anchor_global_position + Vector2.from_angle(angle - offset) * distance
			
			result = space_state.intersect_ray(ray_querry)
			if !result.is_empty():
				pos2 = result.position
			
			angle -= offset
		
		if pos2 && initial_position.distance_squared_to(pos1) >= initial_position.distance_squared_to(pos2):
			return pos2
		elif pos1:
			return pos1
		
		# Ancienne méthode
		"
		# On prends le premier point d'intersection entre le raycast entre l'anchre et notre point
		var anchor_global_position:Vector2 = anchor_position + global_position
		var ray_querry = PhysicsRayQueryParameters2D.create(anchor_global_position, initial_global_position)
		ray_querry.exclude = [self]
		
		result = space_state.intersect_ray(ray_querry)
		if result.is_empty():
			return goal_position
		
		
		# On récupère la normale à la surface d'itersection et on calcule la tangente
		var normal_angle:float = result.normal.angle_to(anchor_global_position - result.position)
		var normal:Vector2 = result.normal * - anchor_global_position.distance_to(result.position) * cos(normal_angle)
		var tangent:Vector2 = Vector2(result.normal.y, -result.normal.x) * sqrt(abs(normal.length_squared() - distance**2))
		
		# On compare les 2 positions possibles
		var pos1:Vector2 = anchor_position + normal + tangent
		var pos2:Vector2 = anchor_position + normal - tangent
		
		if initial_position.distance_squared_to(pos1) >= initial_position.distance_squared_to(pos2):
			return pos2
		else:
			return pos1
		"
	
	return initial_position

func invert() -> void:
	inverted = !inverted
	var new_points = []
	for i in width_curve.point_count:
		var new_pos = width_curve.get_point_position(i)
		new_pos.x = width_curve.max_domain - new_pos.x
		new_points.append(new_pos)
	
	width_curve.clear_points()
	
	for point in new_points:
		width_curve.add_point(point)
	
	send_width_curve_to_shader()

func send_width_curve_to_shader() -> void:
	var width_curve_texture:CurveTexture = CurveTexture.new()
	width_curve_texture.set_curve(width_curve)
	material.set_shader_parameter("curve_texture", width_curve_texture)
