extends ColorRect

func _ready():
	$ScreenStretch/ColorRect/VBoxContainer/Button.grab_focus()

func set_reason(text):
	$ScreenStretch/ColorRect/VBoxContainer/Reason.set_text(text)


func _on_Button_pressed():
	get_tree().change_scene("res://Title.tscn")


func _on_Footer_meta_clicked(meta):
	OS.shell_open(meta)
