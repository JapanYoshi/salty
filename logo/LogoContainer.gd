extends Control
onready var anim: AnimationPlayer = $AnimationPlayer
var ready_to_play_intro: bool = false
# Animated logo for hai!touch Studios.

# Called when the node enters the scene tree for the first time.
func _ready():
	print("LogoContainer._ready()")
	_on_size_changed()
	get_viewport().connect("size_changed", self, "_on_size_changed")
	anim.play("rating_fadein")


func _on_size_changed():
	var resolution = get_viewport_rect().size
	var scale = min(
		resolution.x / 1280,
		resolution.y / 720
	)
	rect_scale = Vector2.ONE * scale / 1.5 # 1080p logo in 720p screen
	
# Called when the logo is finished animating.
# Also called when the user skips the logo.
func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "rating_fadein":
		ready_to_play_intro = true
	elif anim_name == "fadeout":
		anim.play("haitouch")
	elif anim_name == "haitouch":
		anim.play("godot")
	elif anim_name == "godot":
		get_tree().change_scene(
			"res://Title.tscn"
		)

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
	if ready_to_play_intro and "pressed" in event and event.pressed:
		if Input.is_action_pressed("ui_accept"):
			skip()
		elif event is InputEventMouseButton:
			if event.button_index == BUTTON_LEFT:
				skip()
