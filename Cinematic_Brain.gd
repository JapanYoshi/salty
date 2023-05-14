extends Control

signal intro_ended

onready var tween = $Qbox/Tween
onready var anim = $AnimationPlayer2

func _ready():
	init()

func init():
	anim.play("intro")
	anim.stop()
	if R.get_settings_value("cutscenes"):
		anim.seek(0, true)
		hide()
	if R.get_settings_value("graphics_quality") < 1:
		$Particles.hide()
	else:
		$Particles.show()

func set_fields(items: PoolStringArray, question: String):
	for i in range(6):
		$Qbox.get_child(i).bbcode_text = "[center]%s[/center]" % items[i]
	$Qbox/Question.bbcode_text = question
	$Qbox/Question.visible_characters = 0

func intro():
	if R.get_settings_value("cutscenes"):
		anim.play("intro")
		S.play_music("brain_intro", true)
	else:
		emit_signal("intro_ended")

func _on_AnimationPlayer2_animation_finished(anim_name):
	if anim_name == "intro":
		emit_signal("intro_ended")

func show_question():
	anim.play("question_enter")

func tween_nth_box(n: int):
	var c = $Qbox.get_child(n)
	tween.interpolate_property(
		c, "rect_scale",
		Vector2.ZERO, Vector2.ONE,
		0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.interpolate_property(
		c, "rect_position",
		c.rect_position + Vector2.RIGHT * 128, c.rect_position,
		0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.start()

func show_question_text():
	tween.interpolate_property(
		$Qbox/Question, "visible_characters",
		0, $Qbox/Question.get_total_character_count(),
		0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.start()

func question_shrink():
	anim.play("question_shrink")

func question_exit():
	anim.play("question_exit")
