extends Node2D

@export var origin:Vector2 = Vector2(500, 500)
@export var pos:Vector2 = Vector2(600, 400)
@export var goal:Vector2 = Vector2(700, 300)
@export var radius:float = 200
@export var speed:float = 50

var debug_display_pt1:Vector2 = Vector2.ZERO
var debug_display_pt2:Vector2 = Vector2.ZERO

func _draw() -> void:
	draw_circle(origin, radius, Color.WHITE_SMOKE, false)
	draw_circle(origin, 10, Color.WEB_GRAY)
	draw_circle(pos, 10, Color.AQUAMARINE)
	draw_circle(goal, 10, Color.CORAL)
	
	draw_circle(debug_display_pt1, 8, Color.YELLOW_GREEN)
	draw_circle(debug_display_pt2, 7, Color.GREEN_YELLOW)

func _process(delta: float) -> void:
	queue_redraw()

func _physics_process(delta: float) -> void:
	if Input.is_action_pressed("left_click"):
		goal = get_viewport().get_mouse_position()
	
	#debug_movement(goal - pos, delta)
	debug_movement_no_speed(goal - pos)

func debug_movement(movement:Vector2, dt:float) -> void:
	movement = movement.normalized() * dt * speed
	var next_goal_point:Vector2 = pos + movement
	
	var movCirc_radius:float = radius
	var movCirc_radius_sqr:float = movCirc_radius**2
	var movCirc_center:Vector2 = origin
	
	
	# Checking if there is no intersection with the circle
	if movCirc_center.distance_squared_to(next_goal_point) <= movCirc_radius_sqr:
		debug_display_pt2 = pos + movement
		pos = debug_display_pt2
		return
	
	# If there is intersection, get the intersection point
	var pt1:Vector2 = pos - movCirc_center
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
	
	debug_display_pt1 = pt3 + origin
	
	# Get the amount by which we have to move
	var active_movement:Vector2 = pt3 - pt1
	var v:float = min(dt * speed - active_movement.length(), 2*movCirc_radius)
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
	
	debug_display_pt2 = pos + active_movement
	pos = debug_display_pt2

func debug_movement_no_speed(movement:Vector2) -> void:
	var s = movement.length()
	var next_goal_point:Vector2 = pos + movement
	
	var movCirc_radius:float = radius
	var movCirc_radius_sqr:float = movCirc_radius**2
	var movCirc_center:Vector2 = origin
	
	
	# Checking if there is no intersection with the circle
	if movCirc_center.distance_squared_to(next_goal_point) <= movCirc_radius_sqr:
		debug_display_pt2 = pos + movement
		return
	
	# If there is intersection, get the intersection point
	var pt1:Vector2 = pos - movCirc_center
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
	
	debug_display_pt1 = pt3 + origin
	
	# Get the amount by which we have to move
	var active_movement:Vector2 = pt3 - pt1
	var v:float = min(s - active_movement.length(), 2*movCirc_radius)
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
	
	debug_display_pt2 = pos + active_movement
