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
	for i in range(9):
		_tween_nth_box(i, delays[i] / 1000.0)
	tween.start()

func _tween_nth_box(n: int, delay_sec: float):
	# animate the "?" card appearing
	if n == 0:
		if delay_sec == 0:
			anim.play("question_enter")
		else:
			var t = self.get_tree().create_timer(delay_sec)
			t.connect("timeout", anim, "play", ['question_enter'], CONNECT_ONESHOT)
	# bounce the "?" card on subsequent times Candy says "blank"
	elif n % 3 == 0:
		var c: Sprite = $Qbox/BrainBlank
		tween.interpolate_property(
			c, "scale",
			Vector2.ONE, Vector2.ONE * 1.1,
			0.0625, Tween.TRANS_QUAD, Tween.EASE_IN_OUT,
			delay_sec
		)
		tween.interpolate_property(
			c, "scale",
			Vector2.ONE * 1.1, Vector2.ONE,
			0.25, Tween.TRANS_CUBIC, Tween.EASE_OUT,
			delay_sec + 0.0625
		)
	# show the other note cards as Candy says their contents
	else:
		# warning-ignore:integer_division
		var c: TextureRect = $Qbox/box.get_child(n % 3 - 1 + 2 * (n / 3))
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
		# animate the red strings
		if n % 3 == 1:
			# warning-ignore:integer_division
			var s = $Qbox.get_node("BrainString%d" % (n / 3))
			tween.interpolate_property(
				s, "scale",
				Vector2.ZERO, Vector2.ONE,
				0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT,
				delay_sec
			)
			tween.interpolate_property(
				s, "rotation",
				-0.3 if n > 3 else 0.3, 0,
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
