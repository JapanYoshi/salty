extends Control

var now_focused = -1
var active = true
const desc = [
	"Play the game, alone or with friends.",
	"What the heck is [i]Salty Trivia,[/i] anyway?",
	"Tweak settings like volume and fullscreen.",
	"Bye!"
]
onready var tween = Tween.new()

# Called when the node enters the scene tree for the first time.
func _ready():
	R._set_visual_quality(R.cfg.graphics_quality)
	add_child(tween)
	$Logo.play_intro()
	S.play_music("hiphop", 1.0)
	now_focused = -1
	change_focus_to(0)

func _on_Button_mouse_entered(i):
	change_focus_to(i)

func change_focus_to(i):
	$VBoxContainer.get_child(i).grab_focus()
	if now_focused != i: # changing focus
		if now_focused != -1: # not first time
			S.play_sfx("menu_move")
		$Panel/RichTextLabel.bbcode_text = desc[i]
		now_focused = i

func _input(e):
	if e.is_action_pressed("ui_down"):
		if $About.visible:
			$About/PanelContainer/ScrollContainer.scroll_vertical += 32
		else:
			change_focus_to((now_focused + 1) % len(desc))
		accept_event()
	elif e.is_action_pressed("ui_up"):
		if $About.visible:
			$About/PanelContainer/ScrollContainer.scroll_vertical -= 32
		else:
			change_focus_to(posmod(now_focused - 1, len(desc)))
		accept_event()
	elif e.is_action_pressed("ui_cancel"):
		if $About.visible:
			_on_Close_pressed()
			accept_event()

func _on_Play_pressed():
	if not active: return
	active = false
	S.play_sfx("menu_confirm")
	release_focus()
	tween.interpolate_property(
		self, "modulate", Color.white, Color.black, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT, 0
	)
	tween.interpolate_property(
		self, "rect_scale", Vector2.ONE, Vector2.ONE * 1.1, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT, 0
	)
	tween.start()
	yield(tween, "tween_all_completed")
# warning-ignore:return_value_discarded
	get_tree().change_scene("res://MenuRoot.tscn")
	pass # Replace with function body.

func _on_About_pressed():
	S.play_sfx("menu_confirm")
	$About.show()
	$About/Close.grab_focus()
	pass # Replace with function body.

func _on_Options_pressed():
	S.play_sfx("menu_confirm")
	release_focus()
	tween.interpolate_property(
		self, "modulate", Color.white, Color.black, 0.5, Tween.TRANS_LINEAR, Tween.EASE_OUT, 0
	)
	tween.start()
	yield(tween, "tween_all_completed")
# warning-ignore:return_value_discarded
	get_tree().change_scene("res://Settings.tscn")
	pass # Replace with function body.

func _on_Exit_pressed():
	get_tree().quit()


func _on_Close_pressed():
	$About.hide()


