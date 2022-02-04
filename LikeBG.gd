extends Control

var tutorial = true
var abort = false
onready var screen = $ViewportContainer/Viewport/LikePhone/LikeScreen
onready var phone = $PhoneTxr
onready var anim = $Anim
onready var lb = $LB
onready var tween = $Tween

var options = []
var answers = []

func _ready():
	screen.bg_elem = self
	anim.play("logo"); anim.stop()
	if !R.cfg.cutscenes:
		tutorial = false

var t = 0
var shader_speed = 1/16.0

func _process(delta):
	if R.cfg.graphics_quality > 0:
		t = fmod(t + delta * shader_speed, 1)
		$Rings.material.set_shader_param("offset", t)

func set_shader_center(center):
	$Rings.material.set_shader_param("center", center)

func play_intro():
	screen.play_intro()
	tween.interpolate_method(
		self, "set_shader_center", Vector2(0.5, 0.5), Vector2(0.625, 0.5),
		0.7, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT, 1.3
	)
	tween.start()
	anim.play("logo")

# DEBUG INPUTS
#func _input(event):
#	if event.is_action_pressed("signup2"):
#		play_intro()
#	elif event.is_action_pressed("signup0"):
#		screen.enter_question("ahcru.,ksrc ch uah sr hr hrac. rs")
#		screen.enter_options(["aaeat hua ,.n", "scra u,chru.chs", "cua,hr rah,u crur ssar ", "sah, cru.hcsrua .ksarcha rca, "])
#	elif event.is_action_pressed("signup0b"):
#		screen.ready_reveal()
#	elif event.is_action_pressed("signup1"):
#		var bit = R.rng.randi_range(0, 15)
#		reveal([bool(bit & 8), bool(bit & 4), bool(bit & 2), bool(bit & 1)])
#	elif event.is_action_pressed("signup1b"):
#		var q_text = "%d" % R.rng.randi_range(0, 99999)
#		while R.rng.randi() & 255 < 192:
#			q_text += " %d" % R.rng.randi_range(0, 99999)
#		show_question(
#			q_text,
#			["%4d" % R.rng.randi_range(0, 9999),"%4d" % R.rng.randi_range(0, 9999),"%4d" % R.rng.randi_range(0, 9999),"%4d" % R.rng.randi_range(0, 9999)],
#			1
#		)
#	elif event.is_action_pressed("signup2b"):
#		end_question()

func show_question(question: String, options: Array, q_num):
	abort = false
	if q_num == 0:
		screen.enter_question(question, 0)
		screen.enter_options(options)
	else:
		anim.play("swipe")
		screen.next_question(question, q_num)
		screen.next_options(options)

func end_question():
	#S.play_music("like_outro", 1)
	screen.end_question()
	anim.stop()
	tween.interpolate_method(
		self, "set_shader_center", Vector2(0.625, 0.5), Vector2(0.5, 0.5),
		1, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.start()
	anim.play("outro")

func reveal(answers):
	anim.stop()
	self.answers = answers
	screen.ready_reveal()
	anim.play("reveal")

func _reveal_index(i):
	if abort: return
	S.play_sfx(("like_%d_" % (i + 1)) + ("yes" if answers[i] else "no"))
	if !tutorial:
		lb.reveal(i, answers[i])
	screen.reveal(i, answers[i])

func tute(stage: int):
	match stage:
		-1:
			anim.stop(false)
			screen.leave_question()
			screen.leave_options()
			abort = true
			tutorial = false
		0:
			screen.enter_question("ESRB game ratings", -1)
			screen.enter_tutorial_options(["S", "M", "L", "AO"])
			yield(get_tree().create_timer(1.0), "timeout")
			if abort: return
			reveal([false, true, false, true])
		1:
			show_question("Tokyo subway line abbreviations", ["S", "M", "L", "Q"], -1)
			yield(get_tree().create_timer(1.0), "timeout")
			if abort: return
			reveal([true, true, false, false])

func show_title(title):
	screen.show_title(title)

func show_initial_options(options):
	options.push_back("?")
	abort = false
	screen.show_init_options(options)

func reset_all_answers():
	lb.reset_all_answers()

func toggle_player_input(index: int, button_index: int, new_value: bool):
	lb.toggle_player_input(index, button_index, new_value)

func _on_Button_pressed(extra_arg_0):
	if !tutorial:
		# 4 = touchscreen, true = pressed
		C.inject_button(4, extra_arg_0, true)
