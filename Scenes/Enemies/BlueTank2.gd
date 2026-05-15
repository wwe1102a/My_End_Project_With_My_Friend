extends PathFollow2D

var speed = 100
var maxhp = 50
var hp = 50
var is_dead = false
var base_damage  = 25

onready var health_bar = $HealthBar
onready var impact_area = $Impact
var projectile_impact = preload("res://Scenes/SupportScenes/ProjectileImpact.tscn")

func _ready():
	health_bar.max_value = maxhp
	health_bar.value = hp
	update_health_bar_color()

func _physics_process(delta):
	if not is_dead:
		offset += speed * delta
	
	if unit_offset >= 0.9:
		print("enemy is escaped")
		reach_base()

func reach_base():
	if not is_dead:
		get_tree().call_group("base", "take_damage", base_damage)
		GameData.enemies_destroy += 1
		queue_free()


func on_hit(damage):
	if is_dead:
		return

	impact()
	hp -= damage
	health_bar.value = hp
	update_health_bar_color()

	if hp <= 0:
		is_dead = true
		on_destroy()

func update_health_bar_color():
	var percent = float(hp) / maxhp
	var style = StyleBoxFlat.new()

	if percent > 0.6:
		style.bg_color = Color.green  
	elif percent > 0.3:
		style.bg_color = Color.yellow  
	else:
		style.bg_color = Color.red  
	
	health_bar.add_stylebox_override("fg", style)

func impact():
	randomize()
	var x_pos = randi() % 31
	var y_pos = randi() % 31
	var impact_location = Vector2(x_pos, y_pos)
	var new_impact = projectile_impact.instance()
	new_impact.position = impact_location
	impact_area.add_child(new_impact)

func on_destroy():
	GameData.add_money(10)
	GameData.enemy_changed(1)

	var explosion = load("res://Scenes/Enemies/explode.tscn").instance()
	explosion.global_position = global_position
	get_tree().get_root().add_child(explosion)

	yield(get_tree().create_timer(0.2), "timeout")
	explosion.queue_free()
	queue_free()
