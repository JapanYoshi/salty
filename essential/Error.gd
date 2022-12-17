extends ColorRect

func _ready():
	if !R.html:
		$ScreenStretch/ColorRect/VBoxContainer/Button.text = "Quit game"
	$ScreenStretch/ColorRect/VBoxContainer/Button.grab_focus()

func set_reason(text):
	$ScreenStretch/ColorRect/VBoxContainer/Reason.set_text(text)


func _on_Button_pressed():
	if R.html:
		get_tree().change_scene("res://Title.tscn")
	else:
		get_tree().notification(MainLoop.NOTIFICATION_WM_QUIT_REQUEST)


func _on_Footer_meta_clicked(meta):
	OS.shell_open(meta)
