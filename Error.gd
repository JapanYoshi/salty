extends ColorRect

func set_reason(text):
	$ColorRect/Reason.set_text(text)

func _on_Button_pressed():
	get_tree().change_scene("res://Title.tscn")
