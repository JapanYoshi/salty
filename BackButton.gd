extends Panel

signal back_pressed

func _on_Panel_pressed():
	emit_signal("back_pressed")
