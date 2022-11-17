extends Control
var title: PackedScene = preload("res://Title.tscn")
onready var anim: AnimationPlayer = $AnimationPlayer
# Animated logo for hai!touch Studios.

# Called when the node enters the scene tree for the first time.
func _ready():
	print("SplashScreen ready")

# Called when the logo is finished animating.
# Also called when the user skips the logo.
func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "fadeout":
		anim.play("haitouch")
	elif anim_name == "haitouch":
		anim.play("ydkj")
	elif anim_name == "ydkj":
		get_tree().change_scene_to(title)

# Called when the user skips the logo.
func skip():
	var anim_name = anim.current_animation
	if anim_name == "":
		S.play_sfx("key_press")
		anim.play("fadeout")
	elif anim_name == "fadeout":
		pass
	else:
		if anim.get_current_animation_position() > 0.25:
			anim.seek(100,true)
			_on_AnimationPlayer_animation_finished(anim_name)

func _input(event):
	if "pressed" in event and event.pressed:
		if Input.is_action_pressed("ui_accept"):
			skip()
		elif event is InputEventMouseButton:
			if event.button_index == BUTTON_LEFT:
				skip()
