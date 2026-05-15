extends Node

var tower_data = {
	"GunT1": {
		"damage": 50,
		"rof": 1,
		"range": 350,
		"cost": 100,
		"category": "Projectile"},
	"GunT2":{
		"damage": 30,
		"rof": 1,
		"range": 350,
		"cost": 150,
		"category": "Projectile"},
	"MissileT1": {
		"damage": 100,
		"rof": 3,
		"range": 550,
		"cost": 200,
		"category": "Missile"},
	"BlockadeT1": {
		"cost": 50,
		"range": 0,
		"category": "placement"},}


signal money_changed(new_money)

var money = 200

func add_money(amount):
	money += amount
	emit_signal("money_changed", money)

func subtract_money(amount):
	if money >= amount:
		money -= amount
		emit_signal("money_changed", money)

#-------ข้อมูลสำหรับ Wave ในแต่ละแมพ--------

var enemywaveLV1 = 7
var enemywaveLV2 = 14
var enemywaveLV3 = 28

#map 1
var enemywaveALV1 = 7
var enemywaveDLV1 = 7

var enemy_required_wave1 = 14
var enemy_required_wave2 = 28
var enemy_required_wave3 = 42
var enemy_check_completion = 42


var base_enemies_in_waveA = 5
var base_enemies_in_waveD = 3
var base_enemy_required = 8
var enemy_required_increment = 14

func get_enemy_required_for_wave(wave: int) -> int:
	var total = 0
	for w in range(wave):
		var enemiesA = base_enemies_in_waveA + w * 2
		var enemiesD = base_enemies_in_waveD + w * 2
		total += enemiesA + enemiesD
	return total

func get_enemy_check_completion(max_waves: int, base_A: int, base_D: int, inc_A: int, inc_D: int) -> int:
	var total = 0
	for w in range(max_waves):
		var enemiesA = base_A + w * inc_A
		var enemiesD = base_D + w * inc_D
		total += enemiesA + enemiesD
	return total

signal enemy_changed(new_enemy)
var enemies_destroy = 0

func enemy_changed(amount) :
	enemies_destroy += amount
	emit_signal("enemy_changed", enemies_destroy)

var path_locked = false
