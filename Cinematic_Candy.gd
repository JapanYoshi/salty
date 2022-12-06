extends Control

signal intro_ended

func _ready():
	init()

func init():
	$AnimationPlayer.play("intro")
	$AnimationPlayer.stop()
	if R.get_settings_value("cutscenes"):
		$AnimationPlayer.seek(0, true)
		hide()
	if R.get_settings_value("graphics_quality") < 1:
		$Particles.hide()
	else:
		$Particles.show()

func intro():
	if R.get_settings_value("cutscenes"):
		$AnimationPlayer.play("intro")
		S.play_music("candy_intro", true)
	else:
		emit_signal("intro_ended")

func _on_AnimationPlayer_animation_finished(anim_name):
	emit_signal("intro_ended")
