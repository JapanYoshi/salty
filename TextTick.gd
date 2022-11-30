extends Control

var mode = "T"
var count = 0
var max_value = 1000 * 1000 # 1000 dollars per question
var value: int = 0

# used to move the nonsense phrase into view while typing
const outside_y: float = -48.0
const clue_y: float = 40.0
const question_up_y: float = 24.0
const question_y: float = 56.0

signal intro_ended
signal checkpoint(checkpoint)

onready var dollars = $PriceBox/Label
onready var anim = $AnimationPlayer
onready var gib_anim = $GibTute/AnimationPlayer
onready var thou_anim = $ThouTute/AnimationPlayer
onready var tween = $Tween

onready var gib_q_box = $GibQBox
onready var gib_q = $GibQBox/GibQ
onready var gib_category = $GibCategory
onready var gib_clues = [
	$GibClue1,
	$GibClue2,
	$GibClue3,
]
onready var gib_bars = [
	$GibBar1,
	$GibBar2,
	$GibBar3,
	$GibBar4,
]
const gib_bar_text = [
	" 1st clue in %s″...",
	" 2nd clue in %s″...",
	" 3rd clue in %s″...",
	" Time’s up in %s″...",
]
onready var gib_a_box = $GibABox
onready var gib_a = $GibABox/GibA

# Called when the node enters the scene tree for the first time.
func _ready():
	$GibBase.hide()
	$ThouBase.hide()
	$GibTute.modulate = Color.transparent
	gib_anim.play("reset")
	pass

func countdown(first_time: bool = false):
	if mode == "T":
		anim.play("countdown")
	else:
		if first_time:
			gib_bars[0].flip_in(tween, 0.0, 10.0)
			tween.start()
		anim.play("countdown_gib")

func countdown_pause(paused: bool = true):
	if paused:
		anim.stop(false) # stop without seeking back to 0s
	else:
		if anim.current_animation == "countdown":
			anim.play() # continue current animation
		elif anim.current_animation == "countdown_gib":
			anim.play() # continue current animation
		else:
			countdown()

func init_thousand():
	mode = "T"; count = 0; max_value = 1_000_000; value = max_value;
	$PriceBox.hide()
	dollars.set_text(R.format_currency(value, true))
	dollars.add_color_override("font_color", Color(64/255.0, 36/255.0, 4/255.0, 126/255.0))
	thou_anim.play("reset")
	gib_category.bbcode_text = ""
	gib_q.bbcode_text = ""
	for el in gib_clues:
		el.bbcode_text = ""
	gib_a.bbcode_text = ""
	$ColorRect.modulate = Color.white
	if !R.cfg.cutscenes:
		anim.play("thou_logo", -1, 10000)

func init_gibberish(category, question, clue1, clue2, clue3, answer, is_round2):
	mode = "G"; count = 0;
	# max_value = (2 if is_round2 else 1) * 50 # apply round 2 bonus
	max_value = 10_000 # ignore round 2 bonus
	value = max_value;
	$PriceBox.hide()
	dollars.set_text(R.format_currency(value, true))
	dollars.add_color_override("font_color", Color(4/255.0, 16/255.0, 64/255.0, 126/255.0))
	gib_category.bbcode_text = "[center]With what [b]" + category + "[/b] does this rhyme?[/center]"
	gib_category.rect_scale.y = 0
	gib_category.rect_position.y = clue_y
	gib_q.bbcode_text = "[center]" + question + "[/center]"
	gib_q_box.rect_scale.y = 0
	gib_q_box.rect_position.y = question_y
	
	gib_clues[0].bbcode_text = clue1
	gib_clues[0].rect_scale.y = 0
	gib_clues[1].bbcode_text = clue2
	gib_clues[1].rect_scale.y = 0
	gib_clues[2].bbcode_text = clue3
	gib_clues[2].rect_scale.y = 0
	
	for i in range(4):
		gib_bars[i].rect_scale.y = 0
		gib_bars[i].setup(
			anim, gib_bar_text[i]
		)
	
	gib_a.bbcode_text = "[center]" + answer + "[/center]"
	gib_a_box.rect_scale.y = 0
	gib_a_box.rect_position.y = question_y
	$ColorRect.modulate = Color.transparent
	if !R.cfg.cutscenes:
		anim.play("gib_logo", -1, 10000)

func intro_gibberish():
	if R.cfg.cutscenes:
		anim.play("gib_logo")
		S.play_music("gibberish_intro", 1)
	else:
		emit_signal("intro_ended")

func intro_thou():
	if R.cfg.cutscenes:
		anim.play("thou_logo")
		S.play_music("thousand_intro", 1)
	else:
		emit_signal("intro_ended")

func show_price():
	if !R.cfg.cutscenes:
		if mode == "T":
			thou_anim.play("3", -1, 8)
		else:
			gib_anim.play("4", -1, 8)
	anim.play("entry")

func update_price():
	count = round(anim.current_animation_position * 2)
	# TQQs tick twice every second. AOSs tick once every second, but goes in 2s.
	var dollar_tween = $PriceBox/Tween
	dollar_tween.stop_all()
	dollar_tween.interpolate_property(
		dollars, "rect_scale", Vector2(1.1, 0.8), Vector2.ONE,
		0.5, Tween.TRANS_ELASTIC, Tween.EASE_OUT
	)
	dollar_tween.interpolate_property(
		dollars, "modulate", Color(1, 1, 1, 1), Color(1, 1, 1, 0.6),
		0.25, Tween.TRANS_QUAD, Tween.EASE_OUT
	)
	dollar_tween.start()
	value = 0
	if mode == "T":
		if count <= 100.0: # For the first 50 seconds, exponential
			value = int(floor(max_value * pow(10, -count / 20.0)))
		elif count < 120.0: # For the last 10 seconds, linear
			value = int((120.0 - count) * 0.5)
			# Play countdown sfx for last 5 seconds
			if count >= 110.0 and int(count) & 1 == 0:
				S.play_sfx("time_close")
		elif count == 120.0: # Time's up
			value = 0
			anim.stop(false)
			emit_signal("checkpoint", 0)
		dollars.set_text(R.format_currency(value, true, 3))
		print(str(count) + ": The question is worth " + str(value) + " points.")
	elif mode == "G":
		value = int(max_value * (80.0 - count) / 80.0)
		match count:
			20.0:
				emit_signal("checkpoint", 0)
			40.0:
				emit_signal("checkpoint", 1)
			60.0:
				emit_signal("checkpoint", 2)
			70.0, 72.0, 74.0, 76.0, 78.0:
				S.play_sfx("time_close")
			80.0:
				emit_signal("checkpoint", 3) # signals to Standard.gd
				S.play_sfx("time_up")
				anim.stop(false)
#			_:
#				pass
		dollars.set_text(R.format_currency(value, true))
		print(str(count) + ": The question is worth " + str(value) + " points.")

func gib_tute(phase: int):
	$GibTute.show()
	gib_anim.play("%d" % phase)

func thou_tute(phase: int):
	$ThouTute.show()
	if phase == 0:
		thou_anim.play("reset"); thou_anim.stop()
	thou_anim.play("%d" % phase)
	if phase == 3:
		yield(thou_anim, "animation_finished");
		$ThouTute.hide()

func gib_category():
	tween.interpolate_property(
		gib_category, "rect_scale", gib_category.rect_scale, Vector2.ONE, 0.2, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.start()

func gib_question():
	tween.interpolate_property(
		gib_q_box, "rect_scale", gib_q_box.rect_scale, Vector2.ONE, 0.2, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.interpolate_property(
		gib_q_box, "modulate", gib_q_box.modulate, Color.white, 0.2, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.start()

func gib_typing(start: bool):
	tween.interpolate_property(
		gib_q_box, "rect_position", gib_q_box.rect_position, Vector2(
			gib_q_box.rect_position.x, question_up_y if start else question_y
		), 0.25, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.interpolate_property(
		gib_a_box, "rect_position", gib_a_box.rect_position, Vector2(
			gib_a_box.rect_position.x, question_up_y if start else question_y
		), 0.25, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.interpolate_property(
		gib_category, "rect_position", gib_category.rect_position, Vector2(
			gib_category.rect_position.x, outside_y if start else clue_y
		), 0.25, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.start()

func skip_gib_intro():
	gib_anim.play("4", -1, 5.0)

func skip_thou_intro():
	thou_anim.play("3", -1, 5.0)
	yield(thou_anim, "animation_finished");
	$ThouTute.hide()

# Show the index-th clue and flip in the next countdown bar.
# DOES NOT start the tween.
func gib_clue(index: int):
	var el = gib_clues[index]
	tween.interpolate_property(
		el, "rect_scale", el.rect_scale, Vector2.ONE, 0.2, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.interpolate_property(
		el, "modulate", el.modulate, Color.white, 0.01, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)

func gib_reveal():
#	print("gib_clue1.rect_scale has type %f and Vector2.ONE has type %f" % [typeof(gib_clue1.rect_scale), typeof(Vector2.ONE)])
#	print("gib_clue1.modulate has type %f and Color.white has type %f" % [typeof(gib_clue1.modulate), typeof(Color.white)])
	gib_clue(0)
	gib_clue(1)
	gib_clue(2)
	for el in gib_bars:
		if el.time_limit != 0.0:
			tween.interpolate_property(
				el, "rect_scale", el.rect_scale, Vector2.RIGHT, 0.2, Tween.TRANS_CUBIC, Tween.EASE_OUT
			)
			tween.interpolate_property(
				el, "modulate", el.modulate, Color.transparent, 0.01, Tween.TRANS_CUBIC, Tween.EASE_OUT, 0.19
			)
			break
	tween.interpolate_property(
		gib_q_box, "rect_scale", gib_q_box.rect_scale, Vector2.RIGHT, 0.2, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.interpolate_property(
		gib_q_box, "modulate", gib_q_box.modulate, Color.transparent, 0.01, Tween.TRANS_CUBIC, Tween.EASE_OUT, 0.19
	)
	tween.interpolate_property(
		gib_category, "rect_scale", gib_category.rect_scale, Vector2.RIGHT, 0.2, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.interpolate_property(
		gib_category, "modulate", gib_category.modulate, Color.transparent, 0.01, Tween.TRANS_CUBIC, Tween.EASE_OUT, 0.19
	)
	tween.interpolate_property(
		gib_a_box, "rect_scale", gib_a_box.rect_scale, Vector2.ONE, 0.2, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.interpolate_property(
		gib_a_box, "modulate", gib_a_box.modulate, Color.white, 0.01, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
#	print("Alright, should be fine to tween these. Play it")
	tween.start()

func thou_tute_set_value():
	var l = $ThouTute/Label;
	var a = l.get_color("font_color_shadow").a
	var v = 0.0 if a <= 0.01 else 1000.0 * pow(1000, (a * 1.5) - 0.5)
	l.set_text(R.format_currency(v, true))

func _on_TextTick_checkpoint(checkpoint):
	print("DEBUG: Checkpoint %d reached." % checkpoint)
	if mode == "G":
		if checkpoint >= 3: return
		gib_clue(checkpoint)
		gib_bars[checkpoint + 1].flip_in(
			tween, float(checkpoint + 1) * 10.0, float(checkpoint + 2) * 10.0
		)
		tween.start()

func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name in ["gib_logo", "thou_logo"]:
		emit_signal("intro_ended")
