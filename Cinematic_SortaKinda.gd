extends Control

signal intro_ended
signal answer_done
signal outro_ended
onready var a_long = $ViewportContainer/Viewport/OptionsVP/PanelA/Center/RTL
onready var b_long = $ViewportContainer/Viewport/OptionsVP/PanelB/Center/RTL
onready var a_short = $ViewportContainer/Viewport/OptionsVP/PanelA/Center/Short
onready var b_short = $ViewportContainer/Viewport/OptionsVP/PanelB/Center/Short
var has_both = false

func _ready():
	get_tree().get_root().connect("size_changed", self, "_on_resized")
	hide()
	init()

func init():
	$AnimationPlayer.play("initialize")
	$Screen3D/jiggle.stop()
	if !R.cfg.cutscenes:
		$AnimationPlayer.set_current_animation("intro")
		$AnimationPlayer.seek(100, true)

func intro():
	show()
	if R.cfg.cutscenes:
		$AnimationPlayer.play("intro")
		S.play_music("sort_intro", true)
	else:
		emit_signal("intro_ended"); return

func set_options(long_a, long_b, short_a, short_b):
	a_long.bbcode_text =  ("[center]" + long_a  + "[/center]")
	b_long.bbcode_text =  ("[center]" + long_b  + "[/center]")
	a_short.bbcode_text = ("[center]" + short_a + "[/center]")
	b_short.bbcode_text = ("[center]" + short_b + "[/center]")
	$Option/AbTurn1.animation = "default"
	$Option/AbTurn2.animation = "default"

func show_option(which: int):
	match which:
		0:
			$AnimationPlayer.play("opt_a")
		1:
			$AnimationPlayer.play("opt_b")
		2:
			$AnimationPlayer.play("opt_ab")
			has_both = true

func short_option(which: int):
	match which:
		0:
			$AnimationPlayer.play("short_a")
		1:
			$AnimationPlayer.play("short_b")

func show_button(which: int):
	match which:
		0:
			$AnimationPlayer.play("press_a")
		1:
			$AnimationPlayer.play("press_b")
		2:
			$AnimationPlayer.play("press_ab")

func show_question(text: String):
	$Screen3D/jiggle.play("vibrate")
	$Option/Cent/Quest.clear()
	$Option/Cent/Quest.append_bbcode("[center]" + text + "[/center]")
	if has_both:
		$Option/AbTurn1.animation = "both"
		$Option/AbTurn2.animation = "both"
	else:
		$Option/AbTurn1.animation = "default"
		$Option/AbTurn2.animation = "default"
	$AnimationPlayer.play("enter_question")

func skip_intro(has_both: bool):
	$AnimationPlayer.play("skip_intro")
	if has_both:
		$Viewport/OptionsVP/PanelAB.rect_scale = Vector2.ONE

func answer(which: int):
	match which:
		0:
			$AnimationPlayer.play("answer_a")
			$Option/AbTurn1.animation = "default"
			$Option/AbTurn2.animation = "none"
		1:
			$AnimationPlayer.play("answer_b")
			$Option/AbTurn1.animation = "none"
			$Option/AbTurn2.animation = "default"
		2:
			$AnimationPlayer.play("answer_ab")
			$Option/AbTurn1.animation = "straight"
			$Option/AbTurn2.animation = "straight"
	

func outro(best_accuracy, best_names):
	$Ranking/Acc.text = "%d" % best_accuracy
	var leaderboard = ""
	match len(best_names):
		1: leaderboard = best_names[0]
		2: leaderboard = best_names[0] + "\n" + best_names[1]
		3: leaderboard = best_names[0] + "\n" + best_names[1] + "\nand " + best_names[2]
		_: leaderboard = "%d players" % len(best_names)
	$Ranking/Names.text = leaderboard
	$Screen3D/jiggle.stop()
	$AnimationPlayer.play("ending")
	#S.play_music("sort_end", true)

func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "intro":
		emit_signal("intro_ended"); return
	if anim_name in ["answer_a", "answer_b", "answer_ab"]:
		emit_signal("answer_done"); return
	if anim_name == "ending":
		emit_signal("outro_ended"); return	

func _on_TouchA_pressed():
	# 4 = touchscreen, 3 = left face button, true = pressed
	C.inject_button(4, 3, true)

func _on_TouchB_pressed():
	# 4 = touchscreen, 5 = right face button, true = pressed
	C.inject_button(4, 5, true)

func _on_TouchAB_pressed():
	# 4 = touchscreen, 1 = up face button, true = pressed
	C.inject_button(4, 1, true)

func _on_resized():
	var size = get_tree().get_root().size # already in the correct aspect ratio
	$ViewportContainer.rect_size = size
	# i want to scale the meta viewport but it doesn't affect the text size
	#$ViewportContainer/Viewport/OptionsVP.size = size
	pass # Replace with function body.
