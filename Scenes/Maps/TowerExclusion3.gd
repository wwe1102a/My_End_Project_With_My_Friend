extends TileMap

onready var walkable_tile_id = 0

onready var path2d_astar = $Path2DAstar
onready var line2d_astar = $PathLineAstar
onready var path2d_dijkstra = $Path2DDijk
onready var line2d_dijkstra = $PathLineDijkstra
onready var marker_astar = $MarkerAstar
onready var marker_dijk = $MarkerDijk

signal astar_path_ready(path)
signal dijkstra_path_ready(path)

signal path_blocked

var astar_ready_flag = false
var dijkstra_ready_flag = false

var inf = 1000000

var point_ids = {} 
var g_score = {}
var f_score = {}

var astar_explored_points = []
var dijkstra_explored_points = []

var path_astar = []
var path_dijkstra = []

onready var timer = Timer.new()
var change_interval = 6.0
var alternate_tile_id = 6
var changing_cells = []

var tank_destroyed_count = GameData.enemies_destroy

var blocked_points = []  # สำหรับบล็อคเซลล์ของทั้งสองอัลกอริทึม

var astar_start_time = 0
var astar_end_time = 0

var dijkstra_start_time = 0
var dijkstra_end_time = 0

var block_round = 0
var blocked_3 = false
var blocked_6 = false
var has_triggered_block = false

var block_wave_indices = [1, 2]  # Length should match cells_to_block_rounds
var block_flags = [false, false] # Same length as above

var cells_to_block_rounds = [
	[Vector2(17,5)],      
	[Vector2(11,5)] 
]

func _ready():
	build_point_map()
	start_astar_visual(Vector2(-1, 9), Vector2(21, 1))
	start_dijkstra_step_search(Vector2(-1, 9), Vector2(21, 1))

func _process(delta):
	var destroyed = GameData.enemies_destroy
	for i in range(block_wave_indices.size()):
		var wave_index = block_wave_indices[i]
		var required_destroyed = GameData.get_enemy_required_for_wave(wave_index)
		if destroyed >= required_destroyed and not block_flags[i]:
			block_flags[i] = true
			print("Wave block event for wave", wave_index, "triggered")
			print("Destroy count: ", destroyed)
			print("Required for block: ", required_destroyed)
			
			var cells_to_block = cells_to_block_rounds[i]
			for cell in cells_to_block:
				if get_cellv(cell) == walkable_tile_id:
					set_cellv(cell, alternate_tile_id)
					block_cell(cell)
				else:
					print("Cell", cell, " already blocked or not walkable")
			GameData.path_locked = true
			#Reset the pathfind
			initialize_astar()
			start_astar_visual(Vector2(-1, 9), Vector2(21, 1))
			initialize_dijkstra()
			start_dijkstra_step_search(Vector2(-1, 9), Vector2(21, 1))
			emit_signal("path_blocked")


func _on_wave_requested():
	get_node("res://Scenes/MainScenes/GameScene.gd").start_next_wave()

func build_point_map():
	point_ids.clear()
	for cell in get_used_cells():
		if get_cellv(cell) == walkable_tile_id:
			point_ids[cell] = true

func heuristic(a, b):
	return abs(a.x - b.x) + abs(a.y - b.y)

func compare_f_score(a, b):
	var fa = f_score.get(a, inf)
	var fb = f_score.get(b, inf)
	return fa < fb

# --- A* ---

func initialize_astar():
	build_point_map()
	for cell in blocked_points:
		if point_ids.has(cell):
			point_ids.erase(cell)
	astar_explored_points.clear()
	path_astar.clear()
	line2d_astar.clear_points()
	path2d_astar.curve.clear_points()
	update()

func start_astar_visual(start_cell, end_cell):
	astar_start_time = OS.get_ticks_msec()
	
	var open_set = []
	var came_from = {}
	g_score.clear()
	f_score.clear()
	open_set.append(start_cell)
	g_score[start_cell] = 0
	f_score[start_cell] = heuristic(start_cell, end_cell)
	_astar_step(open_set, came_from, start_cell, end_cell)

func _astar_step(open_set, came_from, start_cell, end_cell):
	while open_set.size() > 0:
		open_set.sort_custom(self, "compare_f_score")
		var current = open_set[0]

		if current == end_cell:
			break

		open_set.erase(current)

		if current != start_cell and current != end_cell:
			astar_explored_points.append(current)
			# ขยับ marker ทีละจุด
			marker_astar.position = map_to_world(current) + cell_size / 2
			marker_astar.visible = true
			update()
			yield(get_tree().create_timer(0.2), "timeout") # เพิ่ม delay 

		for offset in [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]:
			var neighbor = current + offset
			if not point_ids.has(neighbor):
				continue

			var tentative_g = inf
			if g_score.has(current):
				tentative_g = g_score[current] + 1

			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + heuristic(neighbor, end_cell)
				if not open_set.has(neighbor):
					open_set.append(neighbor)

	# อัพเดต marker หลังคำนวณเสร็จ
	if astar_explored_points.size() > 0:
		var last_point = astar_explored_points[-1]
		marker_astar.position = map_to_world(last_point) + cell_size / 2
		marker_astar.visible = true

	update()

	# สร้าง path
	var cell_path = []
	var cur = end_cell
	while came_from.has(cur):
		cell_path.insert(0, cur)
		cur = came_from[cur]
	if cur == start_cell:
		cell_path.insert(0, start_cell)

	draw_astar_path(cell_path)
	astar_end_time = OS.get_ticks_msec()
	var elapsed_ms = astar_end_time - astar_start_time
	var elapsed_sec = float(elapsed_ms) / 1000.0 # แปลงเป็นวินาที 
	print("A*ใช้เวลา: %d ms (%.3f วินาที)" % [elapsed_ms, elapsed_sec])
	print("A* tiles explored: ", astar_explored_points.size())

func draw_astar_path(cell_path):
	path_astar.clear()
	line2d_astar.clear_points()
	path2d_astar.curve.clear_points()

	if cell_path.size() == 0:
		return

	var start_pos = map_to_world(cell_path[0]) + cell_size / 2
	path_astar.append(start_pos)
	line2d_astar.add_point(start_pos)
	path2d_astar.curve.add_point(start_pos)

	for i in range(1, cell_path.size()):
		var world_pos = map_to_world(cell_path[i]) + cell_size / 2
		path_astar.append(world_pos)
		line2d_astar.add_point(world_pos)
		path2d_astar.curve.add_point(world_pos)

	line2d_astar.width = 2
	line2d_astar.default_color = Color(1, 0, 0, 0.8)
	path2d_astar.update()
	print("A* path length (tiles walked):", path2d_astar.curve.get_point_count())
	emit_signal("astar_path_ready", cell_path)

# --- Dijkstra ---

func initialize_dijkstra():
	build_point_map()
	for cell in blocked_points:
		if point_ids.has(cell):
			point_ids.erase(cell)
	dijkstra_explored_points.clear()
	path_dijkstra.clear()
	line2d_dijkstra.clear_points()
	update()

class PriorityQueue:
	var elements = []

	func empty():
		return elements.empty()

	func push(item, priority):
		elements.append({'item': item, 'priority': priority})
		elements.sort_custom(self, "_compare_priority")

	func pop():
		return elements.pop_front()['item']

	func _compare_priority(a, b):
		return a['priority'] < b['priority']

func start_dijkstra_step_search(start_cell, end_cell):
	dijkstra_start_time = OS.get_ticks_msec()
	dijkstra_explored_points.clear()
	path_dijkstra.clear()

	var came_from = {}
	var cost_so_far = {}
	var frontier = PriorityQueue.new()

	frontier.push(start_cell, 0)
	came_from[start_cell] = null
	cost_so_far[start_cell] = 0

	_dijkstra_step_search(start_cell, end_cell, came_from, cost_so_far, frontier)

func _dijkstra_step_search(start_cell, end_cell, came_from, cost_so_far, frontier):
	while not frontier.empty():
		var current = frontier.pop()

		if current != start_cell and current != end_cell:
			dijkstra_explored_points.append(current)
			marker_dijk.position = map_to_world(current) + cell_size / 2
			marker_dijk.visible = true
			update()
			yield(get_tree().create_timer(0.2), "timeout") # เพิ่ม delay

		if current == end_cell:
			break

		for offset in [Vector2(1,0), Vector2(-1,0), Vector2(0,1), Vector2(0,-1)]:
			var neighbor = current + offset
			if not point_ids.has(neighbor):
				continue

			var new_cost = cost_so_far[current] + 1
			if not cost_so_far.has(neighbor) or new_cost < cost_so_far[neighbor]:
				cost_so_far[neighbor] = new_cost
				frontier.push(neighbor, new_cost)
				came_from[neighbor] = current

	# อัพเดต marker หลังคำนวณเสร็จ
	if dijkstra_explored_points.size() > 0:
		var last_point = dijkstra_explored_points[-1]
		marker_dijk.position = map_to_world(last_point) + cell_size / 2
		marker_dijk.visible = true

	update()

	draw_dijkstra_path(came_from, end_cell)
	dijkstra_end_time = OS.get_ticks_msec()
	print("Dijkstra tiles explored: ", dijkstra_explored_points.size())

func draw_dijkstra_path(came_from, end_cell):
	path_dijkstra.clear()
	line2d_dijkstra.clear_points()

	var current = end_cell
	var path = []
	while current != null:
		path.insert(0, current)
		current = came_from.get(current, null)

	for cell in path:
		var world_pos = map_to_world(cell) + cell_size / 2
		var local_pos = to_local(world_pos)
		path_dijkstra.append(world_pos)
		line2d_dijkstra.add_point(local_pos)

	line2d_dijkstra.width = 1
	line2d_dijkstra.default_color = Color.blue
	dijkstra_end_time = OS.get_ticks_msec()
	var elapsed_ms = dijkstra_end_time - dijkstra_start_time
	var elapsed_sec = float(elapsed_ms) / 1000.0 # แปลงเป็นวินาที 
	print("Dijkstraใช้เวลา: %d ms (%.3f วินาที)" % [elapsed_ms, elapsed_sec])
	print("Dijkstra path length (tiles walked): %d" % path.size())
	emit_signal("dijkstra_path_ready", path)

#  วาดวงกลมจุดที่สำรวจ 

func _draw():
	var radius = cell_size.x * 0.1
	for cell in astar_explored_points:
		var pos = map_to_world(cell) + cell_size / 2
		draw_circle(to_local(pos), radius, Color(1, 0, 0, 0.6))
	for cell in dijkstra_explored_points:
		var pos = map_to_world(cell) + cell_size / 2
		draw_circle(to_local(pos), radius, Color(0, 0, 1, 0.6))

# --- ฟังก์ชันบล็อคเซลล์และอัปเดต path ---

func block_cell(cell):
	if not blocked_points.has(cell):
		blocked_points.append(cell)

func animate_marker(marker, path):
	for cell in path:
		marker.position = map_to_world(cell) + cell_size / 2
		marker.visible = true
		update()
		yield(get_tree().create_timer(0.1), "timeout")


