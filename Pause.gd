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
	C.connect("gp_button_paused", self, "_gp_button_paused")

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
	if get_parent().penalize_pausing:
		paused_times += 1
		if paused_times >= 3:
			var rand = R.rng.randi() # max: 4294967295
			var thres = (1 << 28) * (2 + paused_times)
			if rand < thres:
				print("too many pauses")
				get_parent().too_many_pauses()
				C.disconnect("gp_button", self, "_gp_button")
				return
	device = device_index
	if player_number == -1:
		$NinePatchRect/Sprite.hide()
	else:
		$NinePatchRect/Sprite.show()
		number_label.set_text("%d" % (player_number + 1))
	match paused_times:
		0:
			count_label.set_text("What now, contestant?")
		1:
			count_label.set_text("Don’t pause too much during a question.")
		2:
			count_label.set_text("Busy? Come back soon.")
		3:
			count_label.set_text("You’re being a bit suspicious right now.")
		4:
			count_label.set_text("The host is getting upset.")
		5:
			count_label.set_text("You’re on thin ice.")
		_:
			count_label.set_text("Dude, why are you doing this?")
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

func _gp_button_paused(index, button, pressed):
	# other buttons?
	if !self.visible: return
	if index != device: return
	if button == 5 or button == 6:
		accept_event()
		resume()
		return;
	elif button == 3:
		accept_event()
		quit()
		return;

func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "hide":
		hide()
		get_tree().paused = false
