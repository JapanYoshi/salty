extends Node2D

signal time_up

const INACTIVE_COLOR = Color(0.7, 0.7, 0.7, 1)
onready var tens = $tens
onready var ones = $ones
onready var anim = $AnimationPlayer
onready var timer = $Timer
var shown = false
var time_left = 15

func initialize(duration: int = 15):
	anim.play("hide", -1, 10000)
	self.time_left = duration
	set_text(duration)

func set_text(time):
	tens.set_text("%d" % (time / 10))
	ones.set_text("%d" % (time % 10))

func tick_time(change_value: bool = true):
	if change_value:
		time_left -= 1
	set_text(time_left)
	anim.play("tick_tens" if (time_left % 10) == 9 else "tick")
	if time_left == 0:
		emit_signal("time_up")
	elif time_left <= 5:
		timer.start(1)
		if shown:
			S.play_sfx("time_close")
		return
	else:
		timer.start(1)
		return

func start_timer(tick_immediately: bool = false):
	print("TIMER START")
	self.modulate = Color.white
	if tick_immediately:
		timer.stop()
		tick_time(false)
	else:
		timer.start(1)

func stop_timer():
	self.modulate = INACTIVE_COLOR
	timer.stop()
	time_left = 0

func show_timer():
	self.modulate = INACTIVE_COLOR
	anim.play("show")
	shown = true

func hide_timer():
	if shown:
		anim.play("hide")
		shown = false

func _on_Timer_timeout():
	tick_time()
