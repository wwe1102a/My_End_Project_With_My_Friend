extends ProgressBar

func set_hp_color(current_hp: int, max_hp: int):
	var percent = float(current_hp) / max_hp
	var style = StyleBoxFlat.new()

	if percent > 0.6:
		style.bg_color = Color(0, 1, 0)  # เขียว
	elif percent > 0.3:
		style.bg_color = Color(1, 1, 0)  # เหลือง
	else:
		style.bg_color = Color(1, 0, 0)  # แดง
	
	
	add_stylebox_override("fg", style)
