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

func set_fields(items: PoolStringArray, question: String):
	for i in range(6):
		var note = $Qbox/box.get_child(i)
		note.rect_scale = Vector2.ZERO
		note.get_child(0).get_child(0).bbcode_text = "[center]%s[/center]" % items[i]
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

func tween_boxes(delays: PoolIntArray):
	anim.play("question_enter")
	for i in range(6):
		_tween_nth_box(i, delays[i] / 1000.0)
	tween.start()

func _tween_nth_box(n: int, delay_sec: float):
	var c = $Qbox/box.get_child(n)
	tween.interpolate_property(
		c, "rect_scale",
		Vector2.ZERO, Vector2.ONE,
		0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT,
		delay_sec
	)
	tween.interpolate_property(
		c, "rect_position",
		c.rect_position + Vector2.DOWN * 256, c.rect_position,
		0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT,
		delay_sec
	)
	if n % 2 == 0:
		var s = $Qbox/BrainBlank.get_child(n / 2)
		tween.interpolate_property(
			s, "scale",
			Vector2.ZERO, Vector2.ONE,
			0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT,
			delay_sec
		)
		tween.interpolate_property(
			s, "rotation",
			-0.3 if n else 0.3, 0,
			0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT,
			delay_sec
		)

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
