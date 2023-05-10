extends Node2D

var state: int = 0

func _ready():
	if R.get_settings_value("cheat_codes_active").empty():
		hide()
		queue_free()
		return
	_on_Timer_timeout()

func _on_Timer_timeout():
	match state:
		0:
			$Cheat20.play("2")
			$Label.set_text("Cheat enabled!")
		1:
			$Cheat20.play("0")
			$Label.set_text("Achievements & save data")
		2:
			$Cheat20.play("3")
			$Label.set_text("cannot be saved until")
		3:
			$Cheat20.play("1")
			$Label.set_text("they are all turned off.")
	state = (state + 1) % 4
