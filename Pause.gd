extends ColorRect

var frame = 0
var delta_cumul = 0.0
var paused_times = 0
var device = -1

onready var anim = $AnimationPlayer
onready var number_label = $NinePatchRect/Sprite/Label
onready var title_label = $NinePatchRect/Label
onready var count_label = $NinePatchRect/Label2

# Called when the node enters the scene tree for the first time.
func _ready():
	hide()
	C.connect("gp_button", self, "_gp_button")

func _process(delta):
	if !visible: return
	_update_shader(delta)

func _update_shader(delta):
	delta_cumul += delta * 30.0
	if delta_cumul >= 1.0:
		delta_cumul -= 1.0
		frame += 1
		self.material.set_shader_param(
			"p_time", fmod(frame * 92.4, 1.0)
		)
		self.material.set_shader_param(
			"offset", Vector2(fmod(frame * 355 / 113.0, 1.0), fmod(frame * 127 / 360.0, 1))
		)

func pause_modal(player_number, device_index):
	paused_times += 1
	device = device_index
	number_label.set_text("%d" % (player_number + 1))
	count_label.set_text("You have paused %s this game." % (
		"once" if paused_times == 1 else (
			"twice" if paused_times == 2 else (
				"%d times" % paused_times
			)
		)
	))
	show()
	anim.play("show")
	get_tree().paused = true

func resume():
	if anim.get_playing_speed() or !visible: return
	anim.play("hide")

func quit():
	if anim.get_playing_speed() or !visible: return
	get_tree().change_scene("res://Title.tscn")
	get_tree().paused = false

func _gp_button(index, button, pressed):
	# dont accept during an animation
	if anim.get_playing_speed(): return
	# pause button?
	if button == 6 and pressed:
		accept_event()
		if visible:
			if index == device:
				resume()
		else:
			var i = -1
			for p in R.players:
				if p.device_index == index:
					i = p.player_number
			pause_modal(i, index)
		return
	# other buttons?
	if !self.visible: return
	if index != device: return
	if button == 5:
		accept_event()
		resume()
	elif button == 3:
		accept_event()
		quit()

func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "hide":
		hide()
		get_tree().paused = false
