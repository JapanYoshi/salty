extends Control
var title: PackedScene = preload("res://Title.tscn")
# Animated logo for hai!touch Studios.

# Called when the node enters the scene tree for the first time.
func _ready():
	print("SplashScreen ready")
#	resize()
#
## Called when the window is initialized.
## It overrides the default scaling behavior based on 360x640px.
#func resize():
#	var viewport = self.get_tree().get_root().get_visible_rect().size
#	var scale = min(viewport.x, viewport.y) / 1080.0
#	set_scale(Vector2(scale, scale))

# Called when the logo is finished animating.
# Also called when the user skips the logo.
func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "haitouch":
		$AnimationPlayer.play("jackbox")
	else:
		get_tree().change_scene_to(title)

# Called when the user skips the logo.
func skip():
	var anim_name = $AnimationPlayer.current_animation
	if anim_name == "":
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
