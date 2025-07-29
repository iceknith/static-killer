# https://stackoverflow.com/questions/67412060/godot-engine-merging-more-than-two-polygons-using-geometrys-merge-polygons-2d
# https://github.com/a327ex/a327ex-template/blob/dd0a63aefbc3cae268d165deef8fdf931f776f55/engine/map/tilemap.lua
# https://github.com/a327ex/blog/issues/5
# https://godotengine.org/qa/30006/build-a-collision-polygon-from-tilemap-outline
class_name TilemapBakeCollisions

var walls_layer := 2

func bakeCollisions(level: Node2D):
	for child in level.get_children():
		if child is TileMapLayer:
			print("hi")
			handle_walls(child as TileMapLayer)

# Ignore all tilemaps not named walls
func handle_walls(tile_map: TileMapLayer) -> void:
	if not "walls" in tile_map.name.to_lower():
		return

	# This static body will have all the polygons
	# genereted as childs
	var node := StaticBody2D.new()
	node.collision_layer = walls_layer
	node.collision_mask = 0
	tile_map.add_child(node)

	var polygons := []
	var used_cells := tile_map.get_used_cells()

	# Create edges
	for cell in used_cells:
		var polygon = get_tile_polygon(get_points(cell, Vector2(8, 8)))
		polygons.append(polygon)


	# Polygons to remove will hold the actual polygons
	var polygons_to_remove := []
	# Index to remove is a dictionary so that searching is faster
	var index_to_remove := {}

	while true:
		# Clear the polygons to remove
		polygons_to_remove = []
		index_to_remove = {}
		
		# Start looping
		for i in polygons.size():
			# Skip if the polygon is due to remove
			if index_to_remove.get(i, false) == true:
				continue

			var a = polygons[i]

			# Loop from the start of the array to
			# the current polygon
			for j in i:
				# Skip if the polygon is due to remove
				if index_to_remove.get(j, false) == true:
					continue

				var b = polygons[j]
				var merged_polygons = Geometry2D.merge_polygons(a, b)

				# The polygons dind't merge so skip to the next loop
				if merged_polygons.size() != 1:
					continue

				# Replace the polygon with the merged one
				polygons[j] = merged_polygons[0]
				
				# Mark to remove the already merged polygon
				polygons_to_remove.append(a)
				index_to_remove[i] = true
				break

		# There is no polygon to remove so we finished
		if polygons_to_remove.size() == 0:
			break

		# Remove the polygons marked to be removed
		for polygon in polygons_to_remove:
			var index = polygons.find(polygon)
			polygons.pop_at(index)

	# Create all the polygon shapes from the result
	# and add them to the static body
	for polygon in polygons:
		var polygon_shape = CollisionPolygon2D.new()
		polygon_shape.polygon = polygon
		node.add_child(polygon_shape)

# Generate all the points in a tile
func get_points(position: Vector2, cell_size: Vector2) -> Array:
	var x = position.x
	var y = position.y
	#1   2
	#
	#0   3
	return [
		Vector2(x * cell_size.x, y * cell_size.y + cell_size.y),  # 0
		Vector2(x * cell_size.x, y * cell_size.y),  # 1
		Vector2(x * cell_size.x + cell_size.x, y * cell_size.y),  # 2
		Vector2(x * cell_size.x + cell_size.x, y * cell_size.y + cell_size.y)  # 3
	]

# Generate the edges/polygon from a tile points
func get_tile_polygon(points) -> Array:
	return [points[0], points[1], points[1], points[2], points[2], points[3], points[3], points[0]]
