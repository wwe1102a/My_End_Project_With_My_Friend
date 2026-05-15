extends Node2D

var map_node
var build_mode = false
var build_valid = false
var build_tile
var build_location 
var build_type


var max_base_health = 100
var base_health = max_base_health setget set_base_health

var max_waves = 3
var current_wave = 0
var base_enemies_in_waveA = 5
var base_enemies_in_waveD = 3
var increment_A = 2
var increment_D = 2
var enemies_in_waveA = base_enemies_in_waveA
var enemies_in_waveD = base_enemies_in_waveD
var enemies_check_victory = 0
var active_enemies = 0

var popup_scene = preload("res://Scenes/UIScenes/Pop_up_Menu.tscn")  # เปลี่ยนเส้นทางให้ถูกต้อง
var popup_instance  # ตัวแปรสำหรับเก็บอินสแตนซ์ของ Popup
var popup_vic = preload("res://Scenes/UIScenes/pop_up_victory.tscn")
var popup_vicinstance
var popup_def = preload("res://Scenes/UIScenes/Pop_up_lose.tscn")
var popup_definstance

onready var money_label = get_node("UI/HBoxContainer/Money")
onready var play_pause = get_node("UI/HUD/HBoxContainer/play_paused")
onready var x2_button = get_node("UI/HUD/HBoxContainer/X2")

signal base_health_changed(new_health)
signal base_destroyed

signal astar_path_ready
signal dijkstra_path_ready

var astar_ready_flag = false
var dijkstra_ready_flag = false
signal both_path_ready

func _ready():
	add_to_group("base")
	base_health = max_base_health
	update_health_ui()
	
	enemies_check_victory = calculate_total_enemies_for_victory(
		max_waves, base_enemies_in_waveA, base_enemies_in_waveD, increment_A, increment_D
	)
	
	$Map2/TowerExclusion2.connect("path_blocked", self, "_on_path_blocked")
	GameData.connect("money_changed", self, "_on_money_changed")
	_update_money_display()  # แสดงเงินเริ่มต้น
	GameData.connect("enemy_changed", self, "_on_enemy_changed")
	check_victory()
	
	popup_instance = popup_scene.instance()  # สร้างอินสแตนซ์ของ Popup
	popup_instance.visible = false  # ซ่อน Popup ตั้งแต่เริ่ม
	add_child(popup_instance)  # เพิ่ม Popup ไปยัง Scene
	
	popup_instance.get_node("TextureRect/continue").connect("pressed", self, "_on_continue_pressed")
	popup_instance.get_node("TextureRect/restart").connect("pressed", self, "_on_restart_pressed")
	popup_instance.get_node("TextureRect/quit").connect("pressed", self, "_on_quit_pressed")
	
	
	
	map_node = get_node("Map2/TowerExclusion2")
	map_node.connect("astar_path_ready", self, "_on_astar_path_ready")
	map_node.connect("dijkstra_path_ready", self, "_on_dijkstra_path_ready")
	yield(get_tree().create_timer(0.1), "timeout")
	start_next_wave()
	
	connect("base_health_changed", self, "_on_base_health_changed")

	# เชื่อมต่อปุ่มสำหรับการสร้างตึก
	for i in get_tree().get_nodes_in_group("build_buttons"):
		i.connect("pressed", self, "initiate_build_mode", [i.get_name()])
	
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.connect("died", self, "_on_enemy_died")
	emit_signal("request_next_wave")


func set_base_health(value):
	base_health = clamp(value, 0, max_base_health)
	emit_signal("base_health_changed", base_health)
	update_health_ui()
	
	if base_health <= 0:
		emit_signal("base_destroyed")
		game_over()

func take_damage(amount):
	print("Base took damage", amount)
	base_health -= amount
	$UI/HBoxContainer/Heart.text = str(base_health)
	if base_health <= 0:
		game_over()

func show_defeat_popup():
	yield(get_tree().create_timer(0.2), "timeout")
	Engine.time_scale = 0
	if popup_definstance == null:
		popup_definstance = popup_def.instance()
		add_child(popup_definstance)
		popup_definstance.get_node("Restart").connect("pressed", self, "_on_restart_pressed")
		popup_definstance.get_node("MainMenu").connect("pressed", self, "_on_quit_pressed")
	else:
		popup_definstance.visible = true


func _on_base_health_changed(new_health):
	# This will automatically update through the setter
	pass


func update_health_ui():
	$UI/HBoxContainer/Heart.text = str(base_health)

func game_over():
	show_defeat_popup()

func _process(delta):
	if build_mode:
		update_tower_preview()


func _unhandled_input(event):
	if event.is_action_released("ui_cancel") and build_mode == true:
		cancel_build_mode()
	if event.is_action_released("ui_accept") and build_mode == true:
		verify_and_build()
		cancel_build_mode()


##Buildings placements
func initiate_build_mode(tower_type):
	if build_mode:
		cancel_build_mode()
	build_type = tower_type + "T1"
	build_mode = true
	get_node("UI").set_tower_preview(build_type, get_global_mouse_position())


func update_tower_preview():
	var mouse_position = get_global_mouse_position()
	var current_tile = map_node.world_to_map(mouse_position)
	var tile_position = map_node.map_to_world(current_tile)
	
	# ตรวจสอบว่าตำแหน่งกริดที่เลือกเป็นที่ว่างหรือไม่
	if map_node.get_cellv(current_tile) == -1:
		get_node("UI").update_tower_preview(tile_position, "ad54ff3c")
		build_valid = true
		build_location = tile_position
		build_tile = current_tile
	else:
		get_node("UI").update_tower_preview(tile_position, "adff4545")
		build_valid = false


func cancel_build_mode():
	build_mode = false
	build_valid = false
	get_node("UI/TowerPreview").free()
	


func verify_and_build():
	if build_valid:
		var tower_cost = GameData.tower_data[build_type]["cost"]
		if GameData.money >= tower_cost:
			var new_tower = load("res://Scenes/Turrets/" + build_type + ".tscn").instance()
			new_tower.position = build_location
			new_tower.built = true
			new_tower.type = build_type
			new_tower.category = GameData.tower_data[build_type]["category"]
			get_node("Map2/Turrets").add_child(new_tower, true)
			map_node.set_cellv(build_tile, 5)
			GameData.subtract_money(tower_cost)
		else:
			print("not enough money")
	else:
		return


##Wave Functions
func _on_path_blocked():
	start_next_wave()

func start_next_wave():
	if current_wave >= max_waves:
		print("All waves completed!")
		return
	
	enemies_in_waveA = base_enemies_in_waveA + current_wave * 2 # 5, 9, 11
	enemies_in_waveD = base_enemies_in_waveD + current_wave * 2 # 3, 7, 9
	
	current_wave += 1
	print("Starting wave: ", current_wave)
	
	var wave_dataA = retrieve_wave_dataA()
	var wave_dataD = retrieve_wave_dataD()
	print("GameScene: wait both_path_ready")
	yield(self, "both_path_ready")
	spawn_enemiesA(wave_dataA)
	spawn_enemiesD(wave_dataD)


func retrieve_wave_dataA():
	var wave_data = []
	var delay = 0.0

	for i in range(enemies_in_waveA):
		var enemy_type = "RedTank"      # กำหนดประเภทของศัตรู
		delay += rand_range(0.1, 0.3)    # สุ่มเวลาสำหรับการสปอนศัตรู
		wave_data.append([enemy_type, delay])
	enemies_in_waveA = wave_data.size()
	return wave_data

func retrieve_wave_dataD():
	var wave_data = []
	var delay = 0.0

	for i in range(enemies_in_waveD):
		var enemy_type = "BlueTank"      # กำหนดประเภทของศัตรู
		delay += rand_range(0.2, 0.4)    # สุ่มเวลาสำหรับการสปอนศัตรู
		wave_data.append([enemy_type, delay])
	enemies_in_waveD = wave_data.size()
	return wave_data


func spawn_enemiesA(wave_data):
	
	for i in wave_data:
		var new_enemy = load("res://Scenes/Enemies/" + i[0] + ".tscn").instance()
		map_node.get_node("Path2DAstar").add_child(new_enemy, true)
		active_enemies += 1  # Increment counter
		new_enemy.connect("died", self, "_on_enemy_died")  # Connect signal
		yield(get_tree().create_timer(i[1]), "timeout")
		
func spawn_enemiesD(wave_data):
	
	for i in wave_data:
		var new_enemy = load("res://Scenes/Enemies/" + i[0] + ".tscn").instance()
		map_node.get_node("Path2DDijk").add_child(new_enemy, true)
		active_enemies += 1
		new_enemy.connect("died", self, "_on_enemy_died")
		yield(get_tree().create_timer(i[1]),"timeout")

func _on_enemy_died():
	active_enemies -= 1
	GameData.enemies_destroy += 1  # Your existing counter
	if active_enemies == 0:
		start_next_wave()  # Start next wave when all are dead
		

# ฟังก์ชันที่เกี่ยวข้องกับการหยุดและเร่งความเร็วเกม
func _paused():  
	if Engine.time_scale > 0:
		Engine.time_scale = 0
		x2_button.disabled = true 
	else:
		Engine.time_scale = 1  
		x2_button.disabled = false


func _on_play_paused_button_down():  
	_paused() 


func _on_X2_button_down():  
	if Engine.time_scale == 1:
		Engine.time_scale = 2  
	else:
		Engine.time_scale = 1  


# ฟังก์ชันที่เกี่ยวกับการเปิด Popup เมนู
func _input(event):
	if event.is_action_pressed("Escape"): 
		if Engine.time_scale == 0 and popup_instance.visible == false:
			return  
		popup_instance.visible = !popup_instance.visible
		if popup_instance.visible:
			play_pause.disabled = true
		else:
			play_pause.disabled = false
	
		if Engine.time_scale == 0:
			Engine.time_scale = 1
		else:
			_paused()


# ฟังก์ชันที่ทำงานเมื่อกดปุ่ม "Continue" ใน popup
func _on_continue_pressed():
	popup_instance.visible = false
	play_pause.disabled = false
	_paused() 


# ฟังก์ชันที่ทำงานเมื่อกดปุ่ม "Restart" ใน popup
func _on_restart_pressed():
	popup_instance.visible = false 
	_paused()
	get_tree().reload_current_scene()  
	GameData.money = 200
	GameData.enemies_destroy = 0
	get_tree().change_scene("res://Scenes/MainScenes/GameScene2.tscn")


# ฟังก์ชันที่ทำงานเมื่อกดปุ่ม "Quit" ใน popup
func _on_quit_pressed():
	_paused()
	get_tree().reload_current_scene()
	GameData.money = 200
	GameData.enemies_destroy = 0
	get_tree().change_scene("res://SceneHandler.tscn")


func _on_nextlevel_pressed():
	get_tree().reload_current_scene()
	GameData.money = 200
	GameData.enemies_destroy = 0
	Engine.time_scale = 1
	get_tree().change_scene("res://Scenes/MainScenes/GameScene3.tscn")



# ฟังก์ชันที่ใช้แสดงผลเงินใน Label
func _update_money_display():
	money_label.text = "" + str(GameData.money)


#ฟังชั่นใ้ชรับการเพิ่มลดเงินที่จะไปแสดงผลใน Label
func _on_money_changed(new_money):
	GameData.money = new_money
	_update_money_display()


#ฟังชั่นที่ใช้รับการเปลี่ยนจำนวนศัตรูที่ถูกทำลาย
func _on_enemy_changed(new_enemy):
	GameData.enemies_destroy = new_enemy
	check_victory()


#ฟังชั่นไว้สำหรับเรียกvoictorypopup.sct
func show_victory_popup():
	yield(get_tree().create_timer(0.2), "timeout")  
	if popup_vicinstance == null:
		popup_vicinstance = popup_vic.instance()
		add_child(popup_vicinstance)
		popup_vicinstance.get_node("NextLevel").connect("pressed", self, "_on_nextlevel_pressed")
		popup_vicinstance.get_node("MainMenu").connect("pressed", self, "_on_quit_pressed")

	else:
		popup_vicinstance.visible = true

	# หยุดเกมไว้ตอนแสดง popup
	Engine.time_scale = 0
	
	

func calculate_total_enemies_for_victory(max_waves: int, base_A: int, base_D: int, inc_A: int, inc_D: int) -> int:
	var total = 0
	for w in range(max_waves):
		var enemiesA = base_A + w * inc_A
		var enemiesD = base_D + w * inc_D
		total += enemiesA + enemiesD
	return total

#ฟังก์ชันสำหรับการเช็คเงื่อนไขการชนะ
func check_victory():
	if GameData.enemies_destroy == enemies_check_victory:
		yield(get_tree().create_timer(0.2), "timeout")  
		show_victory_popup()

func _on_astar_path_ready(cell_path):
	print("A* path ready")
	GameData.path_locked = false
	var enemy_container = get_node("Map2/TowerExclusion2/Path2DAstar")
	if enemy_container:
		for enemy in enemy_container.get_children():
			if enemy.has_method("refresh_path"):
				enemy.refresh_path(cell_path)
	else:
		print("Path2DAstar not found!")
	astar_ready_flag = true
	check_both_paths_ready()

func _on_dijkstra_path_ready(cell_path):
	GameData.path_locked = false
	var enemy_container = get_node("Map2/TowerExclusion2/Path2DDijk")
	if enemy_container:
		for enemy in enemy_container.get_children():
			if enemy.has_method("refresh_path"):
				enemy.refresh_path(cell_path)
	else:
		print("Path2DDijk not found!")
	dijkstra_ready_flag = true
	check_both_paths_ready()

func check_both_paths_ready():
	if astar_ready_flag and dijkstra_ready_flag:
		emit_signal("both_path_ready")
		astar_ready_flag = false
		dijkstra_ready_flag = false
