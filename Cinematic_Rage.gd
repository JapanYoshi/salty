extends Control

signal intro_ended

onready var bg = $ColorRect

var shader_time: float = 0.0
var shader_fps: int = 15
var shader_last_time: int = 0
var shader_looplen: float = 15.0

func _ready():
	bg.material.set_shader_param(
		"p_time", shader_time
	)
#	init()

func _process(delta):
	if R.cfg.graphics_quality <= 1: return
	shader_time += delta
	var shader_frame: int = int(shader_time * shader_fps)
	if shader_last_time != shader_frame:
		bg.material.set_shader_param(
			"p_time", float(shader_frame) / shader_fps / shader_looplen
		)
		if shader_time >= shader_looplen:
			shader_time -= shader_looplen
			shader_frame = 0
		shader_last_time = shader_frame

#func init():
#	$AnimationPlayer.play("intro")
#	$AnimationPlayer.stop()
#	if R.cfg.cutscenes:
#		$AnimationPlayer.seek(0, true)
#		hide()

func intro():
	if R.cfg.cutscenes:
		$AnimationPlayer.play("intro")
		S.play_music("rage_intro", 1.0)
	else:
		# shortened animation so that the logo still appears at the right time
		$AnimationPlayer.play("intro_skip")

# warning-ignore:unused_argument
func _on_AnimationPlayer_animation_finished(anim_name):
	emit_signal("intro_ended")
