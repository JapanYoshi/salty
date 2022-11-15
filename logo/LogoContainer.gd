extends Control
var title: PackedScene = preload("res://Title.tscn")
# Animated logo for hai!touch Studios.

# Called when the node enters the scene tree for the first time.
func _ready():
	print("SplashScreen ready")

# Called when the logo is finished animating.
# Also called when the user skips the logo.
func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "haitouch":
		$AnimationPlayer.play("jackbox")
	else:
# warning-ignore:return_value_discarded
		get_tree().change_scene_to(title)

# Called when the user skips the logo.
func skip():
	var anim_name = $AnimationPlayer.current_animation
	if anim_name == "":
		S.play_sfx("key_press")
		$AnimationPlayer.play("haitouch")
	else:
		$AnimationPlayer.seek(100,true)
		_on_AnimationPlayer_animation_finished(anim_name)

func _input(event):
	if "pressed" in event and event.pressed:
		if Input.is_action_pressed("ui_accept"):
			skip()
		elif event is InputEventMouseButton:
			if event.button_index == BUTTON_LEFT:
				skip()
