extends Line2D

@export var max_distance:float = 6
@export var number_of_points:int = 50
var anchor_position:Vector2

@export var max_speed:float = 200.0
@export var acceleration:float = 30.0

@export var inverted:bool = false
@export var debug_display:bool = false

@export var collision_circle_resolution:int = 10

@export var max_angle:float = 0.2

var goal_point:Vector2 = Vector2.ZERO
var last_point_with_collisions:int = 0
var space_state:PhysicsDirectSpaceState2D

var debug_indx:int
var debug_vect:Vector2

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
		for i in range(number_of_points):
			var point = points[i]
			draw_circle(point, max_distance/7, Color.REBECCA_PURPLE)
			draw_circle(point, max_distance, Color.AZURE, false)
			
		
		draw_circle(goal_point, 3, Color.RED)
		draw_circle(points[last_point_with_collisions], max_distance * (number_of_points - last_point_with_collisions - 1), Color.DARK_GRAY, false)

func set_movement(movement:Vector2, dt:float) -> void:
	last_point_with_collisions = 0
	
	for i in range(points.size() - 3, 0, -1):
		var angle = (points[i+1] - points[i]).angle_to(points[i] - points[i-1])
		if abs(angle) >= max_angle:
			last_point_with_collisions = i
			break
	
	
	movement = movement.normalized() * dt * max_speed
	var next_goal_point:Vector2 = points[-1] + movement
	
	var movCirc_radius:float = max_distance * (number_of_points - last_point_with_collisions - 1)
	var movCirc_radius_sqr:float = movCirc_radius**2
	var movCirc_center:Vector2 = points[last_point_with_collisions]
	
	
	# Checking if there is no intersection with the circle
	if movCirc_center.distance_squared_to(next_goal_point) <= movCirc_radius_sqr:
		goal_point = next_goal_point
		return
	
	# If there is intersection, get the intersection point
	var pt1:Vector2 = points[-1] - movCirc_center
	var pt2:Vector2 = next_goal_point - movCirc_center
	var x_near_0:bool = abs(pt1.x - pt2.x) <= abs(pt1.y - pt2.y)
	
	var alpha:float; var beta:float; 
	var a:float; var b:float; var c:float; 
	var delta:float; var pt3_direction:float
	
	if x_near_0:
		alpha = (pt2.x - pt1.x)/(pt2.y - pt1.y)
		beta = (pt1.x*pt2.y - pt2.x*pt1.y)/(pt2.y - pt1.y)
		pt3_direction = sign(pt2.y - pt1.y)
	else:
		alpha = (pt2.y - pt1.y)/(pt2.x - pt1.x)
		beta = (pt2.x*pt1.y - pt1.x*pt2.y)/(pt2.x - pt1.x)
		pt3_direction = sign(pt2.x - pt1.x)
	
	a = 1 + alpha**2
	b = 2*alpha*beta
	c = beta**2 - movCirc_radius_sqr
	delta = b**2 - 4*a*c
	
	var v1:float = (-b + pt3_direction * sqrt(delta))/(2*a)
	var v2:float = alpha*v1 + beta
	var pt3:Vector2
	
	if x_near_0: pt3 = Vector2(v2, v1)
	else: pt3 = Vector2(v1, v2)
	
	# Get the amount by which we have to move
	var active_movement:Vector2 = pt3 - pt1
	var v:float = min(dt * max_speed - active_movement.length(), 2*movCirc_radius)
	var m1:Vector2; var m2:Vector2
	
	if x_near_0:
		var mX1 = v*(-v*pt3.x + pt3.y*sqrt(4*movCirc_radius_sqr - v**2))/(2*movCirc_radius_sqr)
		var mY1 = -mX1*pt3.x/pt3.y - v**2/(2*pt3.y)
		m1 = Vector2(mX1, mY1)
		
		var mX2 = v*(-v*pt3.x - pt3.y*sqrt(4*movCirc_radius_sqr - v**2))/(2*movCirc_radius_sqr)
		var mY2 = -mX2*pt3.x/pt3.y - v**2/(2*pt3.y)
		m2 = Vector2(mX2, mY2)
	
	else:
		var mY1 = v*(-v*pt3.y - pt3.x*sqrt(4*movCirc_radius_sqr - v**2))/(2*movCirc_radius_sqr)
		var mX1 = -mY1*pt3.y/pt3.x - v**2/(2*pt3.x)
		m1 = Vector2(mX1, mY1)
		
		var mY2 = v*(-v*pt3.y + pt3.x*sqrt(4*movCirc_radius_sqr - v**2))/(2*movCirc_radius_sqr)
		var mX2 = -mY2*pt3.y/pt3.x - v**2/(2*pt3.x)
		m2 = Vector2(mX2, mY2)
		
	if pt2.distance_squared_to(m1) < pt2.distance_squared_to(m2):
		active_movement += m1
	else:
		active_movement += m2
	
	goal_point = points[-1] + active_movement

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

func distance_chain_forward_movement(delta:float) -> void:
	#Initialize variables
	space_state = get_world_2d().direct_space_state
	
	# Move first point
	#var temp_goal_point:Vector2 = points[-1] + (goal_point - points[-1]).normalized() * min(max_speed * delta, points[-1].distance_to(goal_point))
	points[-1] = movement_with_collisions(points[-1], goal_point)
	
	# Move other points
	for i in range(points.size()-2, -1, -1):
		var point_new_position:Vector2 = constraint_distance(points[i], points[i+1], max_distance)
		points[i] = chain_movement_with_collisions(points[i], point_new_position, points[i+1], max_distance)

func distance_chain_anchor_movement(delta:float) -> void:
	points[0] = anchor_position
	for i in range(1, points.size()):
		var point_new_position:Vector2 = constraint_distance(points[i], points[i-1], max_distance)
		points[i] = chain_movement_with_collisions(points[i], point_new_position, points[i-1], max_distance)

func constraint_distance(point:Vector2, anchor:Vector2, distance:float) -> Vector2:
	return anchor + (point - anchor).normalized() * min(point.distance_to(anchor),distance)

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
		
		if collision_normal == Vector2.ZERO: 
			return goal_position
		
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
		#ray_querry.exclude = [self]
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
