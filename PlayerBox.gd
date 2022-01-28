extends Panel

var nickname = "Player Name"
# 0-indexed because programming
export var number = 0
var score = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	show_finale_box(0)
	$Number.set_text("%d" % (number + 1))
	#var result = C.connect("gp_button", self, "_test_functions")
	#print("PlayerBox connection result is ", result)

func initialize(player_data):
	nickname = player_data.name
	$Name.set_text(nickname)
	score = player_data.score
	set_score()
	number = player_data.player_number
	$Number.set_text("%d" % (1 + number))
	$Lifesaver.modulate.a = 0.0
	$Lifesaver.visible = player_data.has_lifesaver

func _set_name(name, animate):
	nickname = name
	$Name.set_text(nickname)
	if animate:
		$Anim.play("set_name")

func _test_functions(who, which, pressed):
	if who != number or !pressed:
		return
	match which:
		0:
			pass#use_lifesaver(true)
		1:
			correct()
		2:
			pass#activate_lifesaver(false)
		4:
			incorrect()

func _process(delta):
	if $Tween.is_active():
		set_score()

func reset_anim(no_tweening: bool = false):
	var DUR = 0.25; var TRANS = Tween.TRANS_QUAD; var EASE = Tween.EASE_IN_OUT
	if no_tweening:
		$Anim.play("Reset")
	else:
		$Tween.stop_all()
		$Tween.interpolate_property(self, "rect_rotation", self.rect_rotation, 0, DUR, TRANS, EASE)
		$Tween.interpolate_property(self, "rect_pivot_offset", self.rect_pivot_offset, Vector2(192, 32), DUR, TRANS, EASE)
		$Tween.interpolate_property(self, "self_modulate", self.self_modulate, Color.white, DUR, TRANS, EASE)
		$Tween.interpolate_property(self, "rect_position:y", self.rect_position.y, 32, DUR, TRANS, EASE)
		$Tween.interpolate_property(self, "rect_scale", self.rect_scale, Vector2.ONE, DUR, TRANS, EASE)
		$Tween.interpolate_property($Number, "rect_rotation", $Number.rect_rotation, 0, DUR, TRANS, EASE)
		$Tween.interpolate_property($Number, "rect_pivot_offset", $Number.rect_pivot_offset, Vector2(26, 64), DUR, TRANS, EASE)
		$Tween.start()
	set_score()

func buzz_in():
	$Anim.play("BuzzIn")

func highlight():
	$Anim.play("Highlight")

func incorrect(loss = 5):
	$Anim.stop(false)
	$Tween.interpolate_property(
		self, "score", score, score - loss, 0.7, Tween.TRANS_QUAD
	)
	$Tween.start()
	$Anim.play("Wrong", 0.05)

func correct(gain = 5):
	$Anim.stop(false)
	$Tween.interpolate_property(
		self, "score", score, score + gain, 0.7, Tween.TRANS_QUAD
	)
	$Tween.start()
	$Anim.play("Right", 0.05)

func set_score():
	$Score.set_text(R.format_currency(score))

func show_accuracy(numerator = 0, denominator = -1):
	if denominator == -1:
		$Score.set_text("%d" % numerator)
	else:
		$Score.set_text(("%d of " % numerator) + ("%d" % denominator))

# used in the intro animation
func give_lifesaver():
	$Lifesaver/Anim.play("get")
	yield($Lifesaver/Anim, "animation_finished")
	$Lifesaver/Anim.play("default")

func enable_lifesaver(active = true):
	if active:
		$Lifesaver/Anim.play("default")
	else:
		$Lifesaver/Anim.stop()
		$Lifesaver.modulate.a = 0

func use_lifesaver():
	$Lifesaver/Anim.play("use")
	$Anim.play("BuzzOut")

func show_finale_box(which):
	match which:
		0:
			$GridContainer.hide()
		1:
			$GridContainer.get_child(0).show()
			$GridContainer.get_child(2).show()
			$GridContainer.get_child(3).get_child(0).position.y = 0
			$GridContainer.get_child(5).get_child(0).position.y = 0
			$GridContainer.show()
		2:
			$GridContainer.get_child(0).hide()
			$GridContainer.get_child(2).hide()
			$GridContainer.get_child(3).get_child(0).position.y = -8
			$GridContainer.get_child(5).get_child(0).position.y = -8
			$GridContainer.show()

func reset_finale_box():
	for i in range(6):
		$GridContainer.get_child(i).get_child(0).set_animation("no")

func set_finale_answer(option, truthy: bool):
	$GridContainer.get_child(option).get_child(0).set_animation(
		"yes" if truthy else "no"
	)
	assert($GridContainer.get_child(option).get_child(0).get_animation() == ("yes" if truthy else "no"))

func confirm_finale_answer(option, truthy):
	var anim = $GridContainer.get_child(option).get_child(0).animation
	if anim == "yes":
		if truthy:
			anim = "truepos"
		else:
			anim = "falsepos"
	else:
		if truthy:
			anim = "falseneg"
		else:
			anim = "trueneg"
	$GridContainer.get_child(option).get_child(0).set_animation(anim)

func _on_Tween_tween_all_completed():
	$Tween.remove_all()
