extends Control

onready var question = $Content/Body/VBox/Question
var q_text = ""
var q_num = 0
var bg_elem
onready var q_num_text = $Notch/TextureRect2/Label
onready var options = [
	$Content/Body/VBox/Opt0,
	$Content/Body/VBox/Opt1,
	$Content/Body/VBox/Opt2,
	$Content/Body/VBox/Opt3
]
onready var anim = $AnimationPlayer

var options_text = []

func _ready():
	anim.play("intro")
	anim.stop(true)
	question.get_node("Ani0").play("enter")
	question.get_node("Ani0").stop(true)
	$Notch/TextureRect3/Label2.set_text(
		"Room %s" % Fb.room_code if Fb.room_code != "" else "Local Mode"
	)
	leave_question()
	leave_options()

func play_intro():
	anim.play("intro")
	
func show_title(title):
	question.get_node("Ttl/PanelContainer/RichTextLabel").clear()
	question.get_node("Ttl/PanelContainer/RichTextLabel").append_bbcode(
		"[center]%s[/center]" % title
	)
	question.get_node("Ttl").show()
	question.get_node("Ani0").play("enter")
	question.get_node("Ani0").stop(true)
	question.get_node("Ani0").play("title")
	pass

func show_init_options(options: Array):
	options_text = options
	if bg_elem.abort: return
	anim.play("enter_initial")

#func _input(event):
#	if event.is_action_pressed("signup0"):
#		enter_options(["aaeat hua ,.n", "scra u,chru.chs", "cua,hr rah,u crur ssar ", "sah, cru.hcsrua .ksarcha rca, "])
#	elif event.is_action_pressed("signup0b"):
#		ready_reveal()
#	elif event.is_action_pressed("signup1"):
#		var bit = R.rng.randi_range(0, 15)
#		reveal([bool(bit & 8), bool(bit & 4), bool(bit & 2), bool(bit & 1)])
#	elif event.is_action_pressed("signup1b"):
#		next_options(["%4d" % R.rng.randi_range(0, 9999),"%4d" % R.rng.randi_range(0, 9999),"%4d" % R.rng.randi_range(0, 9999),"%4d" % R.rng.randi_range(0, 9999)])

func _set_question(text):
	q_text = text
	S.play_sfx("like_whoosh", 12/16.0)
	question.get_node("CenterContainer2/Bg/RichTextLabel").clear()
	question.get_node("CenterContainer2/Bg/RichTextLabel").append_bbcode("[center]%s[/center]" % text)
	if q_num >= 0:
		q_num_text.set_text("Article %d/5" % (q_num + 1))

func enter_question(text: String, q_num: int):
	self.q_num = q_num
	_set_question(text)
	question.get_node("Ani0").stop(false)
	question.get_node("Ani0").play("enter")

func next_question(text: String, q_num: int):
	self.q_num = q_num
	_set_question(text)
	question.get_node("Ani0").stop(false)
	question.get_node("Ani0").play("change")

func leave_question():
	question.get_node("Ani0").stop(false)
	question.get_node("Ani0").play("leave")

func enter_options(text_array: Array):
	print(text_array, "ENTER_OPTIONS")
	if bg_elem.abort: return
	options_text = text_array
	anim.play("enter")

func enter_tutorial_options(text_array: Array):
	options_text = text_array
	anim.play("enter_tutorial")

func _enter_option(i: int):
	print(i, "ENTER_OPTION")
	if bg_elem.abort:
		print("ENTER_OPTION ABORTED")
		return
	S.play_sfx("like_whoosh", (16 + i) / 16.0)
	options[i].enter(options_text[i])

func next_options(text_array: Array):
	print(text_array, "NEXT_OPTIONS")
	if bg_elem.abort: return
	options_text = text_array
	anim.stop(false)
	anim.play("next")
	
func _next_option(i: int):
	print(i, "NEXT_OPTION")
	if bg_elem.abort: return
	options[i].next(options_text[i])
	S.play_sfx("like_whoosh", (16 + i) / 16.0)

func ready_reveal():
	print("READY_REVEAL")
	anim.stop(true)
	if bg_elem.abort: return
	for i in range(4):
		options[i].ready_reveal()

func reveal(index: int, answer: bool):
	if bg_elem.abort: return
	options[index].reveal(answer)

func leave_options():
	anim.stop()
	anim.play("leave")

func _leave_option(i: int):
	#if bg_elem.abort: return
	options[i].leave()

func end_question():
	anim.play("outro")

func _on_Ani0_animation_finished(anim_name):
	if anim_name in ["enter", "change"]:
		question.get_node("CenterContainer/Bg/RichTextLabel").clear()
		question.get_node("CenterContainer/Bg/RichTextLabel").append_bbcode("[center]%s[/center]" % q_text)
		question.get_node("Ttl").hide()
		question.get_node("Ani0").play("enter_end")

func _on_AnimationPlayer_animation_finished(anim_name):
	print("ANIMATION FINISHED, ", anim_name)
