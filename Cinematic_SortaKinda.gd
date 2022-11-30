extends Control

signal intro_ended
signal answer_done
signal outro_ended
onready var a_long = $Viewport/OptionsVP/Scale/PanelA/Center/RTL
onready var b_long = $Viewport/OptionsVP/Scale/PanelB/Center/RTL
onready var a_short = $Viewport/OptionsVP/Scale/PanelA/Center/Short
onready var b_short = $Viewport/OptionsVP/Scale/PanelB/Center/Short
var has_both = false

func _ready():
	get_tree().get_root().connect("size_changed", self, "_on_resized")
#	hide()
	init()
	# debug
#	intro()
#	set_options("OPTION 1 long version", "OPTION 2 long version", "left", "right")
#	show_option(0); show_option(1);
	# end debug

func init():
	$AnimationPlayer.play("initialize")
	$Screen3D/jiggle.stop()
	if !R.cfg.cutscenes:
		$AnimationPlayer.set_current_animation("intro")
		$AnimationPlayer.seek(100, true)
	_on_size_changed()
	get_viewport().connect("size_changed", self, "_on_size_changed")

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
		$Viewport/OptionsVP/Scale/PanelAB.rect_scale = Vector2.ONE

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

const base_resolution = Vector2(1280, 720)
var scale: float = 1.0
func _on_size_changed():
	var resolution = get_viewport_rect().size
	if resolution.x / resolution.y > (16.0 / 9.0):
		# too wide
		scale = resolution.y / base_resolution.y
	else:
		# too narrow
		scale = resolution.x / base_resolution.x
	# todo: options viewport size is too big when started at 1080p
	$Viewport.size = base_resolution * scale # enlarge to native res
	
	$Viewport/OptionsVP.size = base_resolution * scale # enlarge to native res
	$Viewport/OptionsVP/Scale.rect_scale = Vector2.ONE * scale # enlarge to native res
	$Viewport/Options.scale = Vector3.ONE / scale # shrink sprite to "logical" 720p relative to camera
	
	$Screen3D.rect_size = base_resolution * scale # enlarge to native res
	$Screen3D.rect_scale = Vector2.ONE / scale # fit to "logical" 720p
