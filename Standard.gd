extends Control

signal question_done

# Standard question
# Flow:
# init - load assets and set up question
# pretitle
# title
# intro (if applicable)
# question
# options (buzz in stage, while reading options)
# countdown (buzz in stage)
# reveal (may be normal, crickets, jinx, split, or correct)
# option
# outro
# end
var stage: String = ""

var point_value: int = 0
var no_wrong_penalty_cheat: bool = "no_wrong_penalty" in R.get_settings_value("cheat_codes_active")

var question_number: int = 0
var question_type: String = "N"
var question_section_number: int = 0

var theme_normal: Theme = preload("res://ThemeOption.theme")
var theme_candy: Theme = preload("res://ThemeCandyOption.tres")
const musics: Dictionary = {
	"N": [],
	"O": ["rage_intro", "rage_loop", "rage_answer_now", "rage_outro"],
	"C": ["candy_intro", "candy_base", "candy_extra", "candy_extra2"],
	"S": ["sort_intro", "sort_base", "sort_extra", "sort_outro"],
	"G": ["gibberish_intro", "gibberish_base", "gibberish_extra", "gibberish_end"],
	"T": ["thousand_intro", "thousand_loop", "tick_loop"],
	"B": ["brain_intro", "brain_base", "brain_extra", "brain_outro"],
	"L": ["like_loop_base", "like_loop_ingame", "like_outro"],
	"R": [
		"rush_intro",
		"rush_phase_1", "rush_phase_2", "rush_phase_3",
		"rush_phase_4", "rush_phase_5", "rush_phase_6"
	]
}

var ep: Node
var hud: Node
var kb: Node

onready var anim = $AnimationPlayer
onready var loadanim = $Loading/LoadingLoopAnim
onready var title = $Title
onready var question = $Qbox/Question
onready var candy_setup = $Qbox/Candy/Bg/setup
onready var candy_punchline = $Qbox/Candy/Bg/punchline
onready var question_tween = $Qbox/QuestionRevealTween
onready var question_timer = $Qbox/QuestionRevealTimer
onready var option_boxes = [
	$Options/Option, $Options/Option2, $Options/Option3, $Options/Option4
]
onready var timer = $Qbox/Timer


onready var bgs = {}

var data = {}
# For gradually showing long question text
var question_queue = []

# 255 for wrong (generic response),
# 0 for wrong (specific response), and 1 for correct
var responses = PoolByteArray([
	0, 0, 0, 0
])
const RESPONSE_USED: int = 241
# a total of 6 buckets, the last two reserved for Sugar Rush.
# stores the integer IDs of players who chose the answer.
var answers = [
	PoolByteArray(), PoolByteArray(), PoolByteArray(), PoolByteArray(), PoolByteArray(), PoolByteArray()
]
var answers_audience = [
	PoolByteArray(), PoolByteArray(), PoolByteArray(), PoolByteArray(), PoolByteArray(), PoolByteArray()
]
# players who have not answered this question (yet).
# audience players won't be put in here.
var no_answer: PoolByteArray = PoolByteArray()
var no_answer_audience: PoolByteArray = PoolByteArray()
# players who used a lifesaver this question.
# audience members won't get one.
var used_lifesaver: PoolByteArray = PoolByteArray()
var lifesaver_is_activated: bool = false
# players who answered wrong.
# player IDs are moved from answers to answered_wrong as the correct answer gets revealed.
var answered_wrong: PoolByteArray = PoolByteArray()
# Can't be PoolByteArray because All Outta Salt pushes [index, value]
var answered_wrong_audience: Array = []
# the index of the correct answer (0 - 3 for normal questions).
var correct_answer = 0
var last_revealed_answer = 0
var revealed_count = 0
# used to track Sorta Kinda, Sugar Rush, and Like/Leave performance.
# could have more elements if audience members participate.
var accuracy: PoolByteArray = PoolByteArray()
var accuracy_audience: PoolByteArray = PoolByteArray()

var can_buzz_in = false
var audience_can_buzz_in: bool = false
# how many seconds to wait before closing the question for the audience
const remote_buzzin_latency: float = 1.25
var can_skip = false
var waiting_for_timer = false

var ans_regex = RegEx.new()
var cuss_level = 0
var gib_clues = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	S.connect("voice_end", self, "_on_voice_end")
	timer.connect("time_up", self, "_on_question_time_up")
#	Ws.connect('server_reply', self, "_on_server_reply")
#	Ws.connect('player_requested_nick', self, "_on_player_requested_nick")
#	Ws.connect('synced_button', self, "_on_synced_button")

# process waiting for the sugar rush phase to start at a measure boundary
var last_pos
var measure = (4.0) / (15.0)
func _R_wait_to_start():
	var pos = S.music_dict[S.tracks[0]].get_playback_position()
	print("music position ", pos * measure)
	if floor(last_pos * measure + 0.02) != floor(pos * measure + 0.02):
		stage = "rush_question"
		R_show_question()
		get_tree().disconnect("idle_frame", self, "_R_wait_to_start")
	else:
		last_pos = pos

func set_buzz_in(enabled):
	if enabled == can_buzz_in: return
	can_buzz_in = enabled
	if enabled:
		audience_can_buzz_in = true
		ep.send_scene('enableBuzzIn')
		var result = C.connect("gp_button", self, "_gp_button")
		print("Result of Standard connecting to C.gp_button is: ", result)
		# buzz in button
		if question_type in ["G"]:
			$TouchButton.show()
#			if len(R.audience_keys):
#				Ws.connect("remote_typing", self, "_on_gib_audience_submit")
		# lifesaver button
		elif question_type in ["N", "C", "O", "B"]:
			if R.get_lifesaver_count() > 0:
				$LSButton.show()
	else:
		#ep.revert_scene('enableBuzzIn')
		ep.send_scene('disableBuzzIn')
		C.disconnect("gp_button", self, "_gp_button")
		# buzz in button
		if question_type in ["G"]:
			$TouchButton.hide()
		# lifesaver button
		elif question_type in ["N", "C", "O", "B"]:
			$LSButton.hide()

func stop_remote_buzz_in():
	audience_can_buzz_in = false

func enable_skip():
	if can_skip == true:
		printerr("Double call enable_skip()")
		return
	ep.send_scene('enableSkip')
	can_skip = true
	ep.skip_btn.show()
	var result = C.connect("gp_button", self, "_gp_button")
	print("Result of Standard connecting to C.gp_button is: ", result)

func disable_skip():
	if can_skip == false:
		printerr("Double call disable_skip()")
		return
	ep.revert_scene('enableSkip')
	ep.send_scene('disableSkip')
	can_skip = false
	ep.skip_btn.hide()
	C.disconnect("gp_button", self, "_gp_button")

func skip():
	disable_skip()
	S.stop_voice()
	S.play_sfx("skip")
	yield(get_tree().create_timer(0.5), "timeout")
	S.play_voice("skip")
	yield(S, "voice_end")
	match question_type:
		"S":
			change_stage("sorta_questions")
		"G":
			change_stage("gib_genre")
		"T":
			change_stage("thou_intro")
		"R":
			change_stage("rush_clue")
		"L":
			change_stage("like_clue")

func _gp_button(input_player, button, pressed):
	# Is this an audience member or an actual player?
	var is_audience: bool = false
	var player: int = -1
	for i in len(R.players):
		if R.players[i].device_index == input_player:
			player = i; break
	if player == -1:
		is_audience = true
		for i in len(R.audience):
			if R.audience[i].device_index == input_player:
				player = i; break # is this true?
	if player == -1: return;
	if (
		is_audience and audience_can_buzz_in
	) or (
		!is_audience and can_buzz_in
	):
		match question_type:
			"N", "C", "O", "B":
				if not pressed: return
				if (
					no_answer_audience.find(player)
					if is_audience else
					no_answer.find(player)
				) != -1:
					var option = [-2, 0, -2, 1, 3, 2, -1][button]
					if option & 128 == 0 and responses[option] != RESPONSE_USED:
						print("Player %d chose option %d" % [player, option])
						if is_audience:
							no_answer_audience.remove(no_answer_audience.find(player))
							answers_audience[option].append(player)
							print("AUDI:",answers_audience,"/",no_answer_audience)
							# R.audience[player].accuracy[1] += 1
						else:
							answers[option].append(player)
							no_answer.remove(no_answer.find(player))
							print("PLYR:",answers_audience,"/",no_answer_audience)
							player_buzz_in(player)
							R.players[player].accuracy[1] += 1
					elif option == -2 and R.players[player].has_lifesaver:
						print("Player %d used the Lifesaver!")
						R.players[player].has_lifesaver = false
						used_lifesaver.append(player)
						no_answer.remove(no_answer.find(player))
						player_buzz_in(player)
					else:
						pass
					print("Players who haven't answered: ", no_answer)
					if len(no_answer) == 0:
						change_stage("reveal")
				return
			"S":
				if not pressed: return
				if (
					no_answer_audience.find(player)
					if is_audience else
					no_answer.find(player)
				) != -1:
					var option = [-1, (2 if data.has_both else -1), -1, 0, -1, 1, -1][button]
					if option != -1:
						answers[option].append(player)
						print("Player %d chose option %d" % [player, option])
						if is_audience:
							no_answer_audience.remove(no_answer_audience.find(player))
							#R.audience[player].accuracy[1] += 1
						else:
							player_buzz_in(player)
							no_answer.remove(no_answer.find(player))
							print("Players who haven't answered: ", no_answer)
							R.players[player].accuracy[1] += 1
							if len(no_answer) == 0:
								change_stage("reveal")
				return
			"G":
				# audience will not be able to buzz in
				# but instead have to respond directly
				if not pressed: return
				if len(answers[0]): return # use this for "currently answering"
				if no_answer.find(player) != -1:
					if button in [1, 3, 4, 5]:
						set_buzz_in(false)
						no_answer.remove(no_answer.find(player))
						print("Player %d buzzed in" % player)
						hud.highlight_players([player])
						S.play_sfx("buzz_in")
						S.stop_voice()
						bgs.G.countdown_pause(true)
						bgs.G.gib_typing(true)
						S.play_track(1, 0)
						activate_keyboard(player)
						R.players[player].accuracy[1] += 1
						yield(get_tree().create_timer(0.75), "timeout")
						if R.players[player].device == C.DEVICES.REMOTE:
							Fb.send_to_player(
								R.players[player].device_name,
								{action = 'gibYourTurn'}
							)
#							Ws.send('message', {'action': 'gibYourTurn'}, R.players[player].device_name)
						S.play_voice("buzz_in")
			"T":
				# If audience buzzes in, they will be added to evaluation queue
				if not pressed: return
				if (
					no_answer_audience.find(player)
					if is_audience else
					no_answer.find(player)
				) != -1:
					var option = [-1, 0, -1, 1, 3, 2, -1][button]
					if option & 128 == 0 and responses[option] != RESPONSE_USED:
						if is_audience:
							answers_audience[option].append([player, bgs.G.value])
							no_answer_audience.remove(no_answer_audience.find(player))
							print("Audience member %d chose option %d for %f points" % [player, option, bgs.G.value])
							#R.players[audience].accuracy[1] += 1
							# Don't reveal the option until a player gets it right
						else:
							# player
							set_buzz_in(false)
							player_buzz_in(player)
							answers[option].append(player)
							no_answer.remove(no_answer.find(player))
							print("Player %d chose option %d" % [player, option])
							S.stop_voice()
							bgs.G.countdown_pause(true)
							S.play_track(0, 0); S.play_track(1, 0)
							R.players[player].accuracy[1] += 1
							yield(get_tree().create_timer(0.5), "timeout")
							reveal_option(option)
					else:
						pass
			"R":
				if not pressed: return
				R_button(player, button)
			"L":
				if not pressed: return
				L_button(player, button)
			_:
				printerr("Unimplemented input.")
	elif can_skip:
		if button == 5 and !is_audience:
			match question_type:
				"S":
					bgs.S.skip_intro(data.has_both)
					skip()
				"G":
					bgs.G.skip_gib_intro()
					skip()
				"T":
					bgs.G.skip_thou_intro()
					skip()
				"R":
					bgs.R.tute(3)
					bgs.R.abort = true
					skip()
				"L":
					bgs.L.tute(-1)
					bgs.L.abort = true
					skip()

# Firebase stores the current seletion state as a STRING of '0' and '1'.
# Correct the selection state locally to match the state on Firebase.
func _on_remote_finale(value: String, slot: int):
	var player: int = R.slot2player(slot)
	if player == -1:
		printerr("_on_remote_finale called for a slot number that does not correspond to a player (%d)" % slot)
		return
	var is_audience = player >= 1 + R.get_settings_value("room_size")
	if (
		is_audience and !audience_can_buzz_in
	) or (
		!is_audience and !can_buzz_in
	): return
	if is_audience:
		player -= 1 + R.get_settings_value("room_size")
	var rush: bool = question_type == "R"
	for i in range(6 if rush else 4):
		var bucket = (
			answers_audience[i] if is_audience else answers[i]
		)
		var new_state: bool = (value[i] == "1")
		var old_state: bool = bucket.has(player)
		if new_state == old_state: continue
		if new_state:
			bucket.push_back(player)
			if !is_audience:
				S.play_sfx("rush_on")
		else:
			bucket.erase(player)
			if !is_audience:
				S.play_sfx("rush_off")
		if is_audience: return
		if rush:
			hud.set_finale_answer(player, i, new_state)
		else:
			bgs.L.toggle_player_input(player, i, new_state)

func R_button(player, button):
	if player == -1 or button == -1 or button == 6: # shouldn't be pause button!
		return
	var old_state = answers[button].has(player)
	if old_state:
		answers[button].erase(player)
		S.play_sfx("rush_off")
		hud.set_finale_answer(player, button, false)
	else:
		answers[button].push_back(player)
		S.play_sfx("rush_on")
		hud.set_finale_answer(player, button, true)

func L_button(player, button):
	if player == -1 or button in [-1, 0, 2]:
		return
	var option = [-1, 0, -1, 1, 3, 2, -1][button]
	var old_state = answers[option].has(player)
	if old_state:
		answers[option].erase(player)
		S.play_sfx("rush_off")
		bgs.L.toggle_player_input(player, option, false)
	else:
		answers[option].push_back(player)
		S.play_sfx("rush_on")
		bgs.L.toggle_player_input(player, option, true)

func activate_keyboard(player):
	S.stop_voice()
	timer.initialize(30 if R.players[player].device == C.DEVICES.KEYBOARD else 60)
	timer.show_timer()
	timer.start_timer()
	kb.connect("text_confirmed", self, "answer_submitted")
#func start_keyboard(
#	which_keyboard: int = 0, which_player: int = 0, which_input: int = 0,
#	character_limit: int = 0
#):
	kb.start_keyboard(
		R.players[player].keyboard,
		player,
		R.players[player].device_index,
		64
	)
	answers[0].append(player)

func answer_submitted(text):
	print("answer_submitted: " + text)
	kb.disconnect("text_confirmed", self, "answer_submitted")
	bgs.G.gib_typing(false)
	timer.stop_timer()
	timer.hide_timer()
	# In case buzz in voice hasn't stopped yet, stop it before unloading
	# and loading a different one
	S.stop_voice("buzz_in")

	# blank?
	if len(text) == 0:
		Loader.call_deferred("load_random_voice_line", "gib_wrong", "gib_blank")
		yield(Loader, "voice_line_loaded")
		S.play_voice("gib_wrong")
		Loader.call_deferred("load_random_voice_line", "buzz_in", "buzz_in")
#		yield(Loader, "voice_line_loaded")
		return
	# correct?
	var matched = ans_regex.search(text)
	if null != matched: # matched
#		print("correct")
		ep.achieve.increment_progress("gib_correct", 1)
		if bgs.G.value == bgs.G.max_value:
			ep.achieve.increment_progress("gib_correct_fast", 1)
		# Move the person correctly answering to bucket 1
		answers[1].push_back(answers[0].pop_back())
		R.players[answers[1][0]].accuracy[0] += 1
		get_tree().create_timer(remote_buzzin_latency).connect("timeout", self, "stop_remote_buzz_in", [], CONNECT_ONESHOT)
		change_stage("gib_answer")
		return
	matched = R.cuss_regex.search(text)
	# cuss word?
	if null != matched:
		S.play_track(0, 0.0)
		print("fuck you right back, player")
		if cuss_level == 0:
			ep.achieve.increment_progress("cuss_gib", 1)
			# Host-specific cuss lines. Choose between the 4 sets.
			# Total number of points to deduct. Make it a multiple of 10.
			var total_money_deduction: int = 100000
			# Name to rename the player as. If it's blank, deduct scores in 2 stages instead.
			var cuss_names = {
				"legacy": "",
				"daisy": "Dig Dunny",
				"miles": "Limp Prick",
				"ozzy": ""
			}
			var cuss_categories = cuss_names.keys()
			# Don't choose the same co-host as before,
			# until the player has seen all of them.
			var used_cuss_lines = R.save_data.misc.cuss_history
			if len(used_cuss_lines) < len(cuss_categories):
				for k in used_cuss_lines:
					cuss_categories.erase(k)
			else:
				used_cuss_lines = []
			var cuss_category = cuss_categories[
				R.rng.randi_range(0, len(cuss_categories) - 1)
			]
			# save it back
			used_cuss_lines.push_back(cuss_category)
			R.set_save_data_item("misc", "cuss_history", used_cuss_lines)
			R.save_save_data()
			# Alright, it's screw-back time
			cuss_level = 1
			# preload lines
			for key in ["cuss_a0", "cuss_a1", "cuss_a2", "cuss_b0", "cuss_c0"]:
				var value = Loader.random_dict.audio_episode[key + "_" + cuss_category][0]
				S.call_deferred("preload_ep_voice", key, value.v, "", value.s)
				yield(S, "voice_preloaded")
				
			# "come on why do people do this"
			S.play_voice("cuss_a0")
			yield(S, "voice_end")
			# deduct score
			S.play_sfx("naughty")
			if cuss_names[cuss_category] == "":
				hud.punish_players(answers[0], total_money_deduction / 10)
			else:
				hud.punish_players(answers[0], total_money_deduction)
			yield(get_tree().create_timer(1.25), "timeout")
			# "why don't we take away some more points"
			S.play_voice("cuss_a1")
			yield(S, "voice_end")
			# deduct score again
			if cuss_names[cuss_category] == "":
				S.play_sfx("naughty")
				hud.punish_players(answers[0], total_money_deduction * 9 / 10)
				yield(get_tree().create_timer(1.25), "timeout")
			else:
				hud.set_player_name(answers[0][0], cuss_names[cuss_category])
				S.play_sfx("name_change")
				yield(get_tree().create_timer(0.5), "timeout")
			# let's get back to the game
			S.play_voice("cuss_a2")
			return
		elif cuss_level == 1:
			cuss_level = 2
			# "take a look at your score"
			# DON'T deduct score
			# let's get back to the game
			S.play_voice("cuss_b0")
			return
		else:
			ep.achieve.increment_progress("cuss_gib_3", 1)
			ep.achieve.increment_progress("ragequit", 1)
			# "you know what we quit"
			S.play_voice("cuss_c0")
			yield(S, "voice_end")
			ep.disqualified()
			return
	else:
		print("incorrect")
		Loader.call_deferred("load_random_voice_line",
			"gib_wrong",
			"gib_early" if gib_clues == 0 else
			"gib_wrong" if gib_clues < 3 else
			"gib_late"
		)
		yield(Loader, "voice_line_loaded")
		S.play_voice("gib_wrong")
		return

func _on_gib_audience_answer(message, from, finalize: bool):
	if !finalize: return;
	var player: int = R.audience_keys.find(from)
	var matched = ans_regex.search(message)
	if null != matched: # matched
		print("audience incorrect")
		answered_wrong_audience.push_back([player, bgs.G.value])
	else:
		print("audience correct")
		answers_audience[0].push([player, bgs.G.value])
		return

# for cosmetic animation/sfx.
func player_buzz_in(player):
	hud.player_buzzed_in(player)
	S.play_sfx("lock_in", [1.0/1.0, 9.0/8.0, 5.0/4.0, 3.0/2.0][randi() % 4])

func reset_answers():
	answers = [[], [], [], [], [], []]
	answers_audience = [[], [], [], [], [], []]
	no_answer = []
	no_answer_audience = []
	used_lifesaver = []
	for i in range(len(R.players)):
		no_answer.append(i)
	for i in range(len(R.audience)):
		no_answer_audience.append(i + len(R.players))

func reset_accuracy():
	accuracy = R.blank_bytes(len(R.players) * 2)
	if len(R.audience) > 0:
		accuracy_audience = R.blank_bytes(len(R.audience) * 2)

# Called during the unloading of the previous question (unloading used backgrounds)
# and during the ending of the round intro
func show_loading_logo(thumb_id: int):
	print("show loading logo")

	$Loading/Thumbnails/Thumbnails.frame = thumb_id
	loadanim.play("idle", 0, 1.0)
	anim.play("touchprism_enter", -1, 1.0)
	$Loading.show()
	S.play_music("load_loop", 0)
	S.play_track(0, 0.6)
	show()

# Advance to the next stage of the question!
func change_stage(next_stage):
	if next_stage == "init":
		stage = "init"
		print("CHANGE STAGE TO INIT")
		can_buzz_in = false
		question_type = data.type
		title.bbcode_text = data.title.t
		question.set_text("")
		hud.reset_all_playerboxes()
		#hud.slide_playerbar(false)
		reset_answers()
		$BG/QNum.hide()
		# Which mode next?
		for k in musics[question_type]:
			S.preload_music(k)
		$Qbox/Candy.hide()
		lifesaver_is_activated = false
		match question_type:
			"N":
				$BG/Noise.set_process(true)
				$BG/Noise.show()
				$BG/Color.modulate = [
					Color("#ffffff"),
					Color("#ff9514"),
					Color("#306f18"),
					Color("#fffdc0"),
					Color("#363430"),
					Color("#6ca780"),
					
					Color("#d01d27"),
					Color("#010a31"),
					Color("#efefee"),
					Color("#3d4247"),
					Color("#4d0708"),
					Color("#f9f3f3"),
				][question_number]
				hud.enable_lifesaver(true)
				$BG/QNum.frame = question_number + 1
				$BG/QNum.show()
				$Options.set_theme(theme_normal)
				point_value = 1000 * (1 if question_number < 6 else 2)
				$Value.set_text(R.format_currency(point_value, true))
				$Value.show()
			"S":
				$BG/Noise.set_process(false)
				$BG/Noise.hide()
				bgs.S = load("res://Cinematic_SortaKinda.tscn").instance()
				$BG.add_child(bgs.S)
				reset_accuracy()
				question.bbcode_text = ""
				bgs.S.set_process(true)
				bgs.S.init()
				bgs.S.set_options(
					data.sort_a.t,
					data.sort_b.t,
					data.sort_a_short.t,
					data.sort_b_short.t
				)
				bgs.S.connect("intro_ended", self, "intro_S_ended")
				bgs.S.connect("answer_done", self, "S_answer_shown")
				bgs.S.connect("outro_ended", self, "outro_S_ended")
				bgs.S.show()
				hud.enable_lifesaver(false)
				question_section_number = 0
				ep.send_scene("sort", {
					'hasBoth': data.has_both,
					'a': data.sort_a_short.t,
					'b': data.sort_b_short.t
				})
				point_value = 300 * (1 if question_number < 6 else 2)
				$Value.set_text(R.format_currency(point_value, true) + "×7")
				$Value.show()
			"B":
				$BG/Noise.set_process(true)
				$BG/Noise.show()
				$BG/Color.modulate = Color("#a4576d")
				bgs.B = load("res://Cinematic_Brain.tscn").instance()
				$BG.add_child(bgs.B)
				bgs.B.init()
				bgs.B.show()
				$Options.set_theme(theme_normal)
				hud.enable_lifesaver(true)
				point_value = 1500 * (1 if question_number < 6 else 2)
				$Value.set_text(R.format_currency(point_value, true))
				$Value.show()
			"C":
				$BG/Noise.set_process(true)
				$BG/Noise.show()
				$BG/Color.modulate = Color("#a4576d")
				bgs.C = load("res://Cinematic_Candy.tscn").instance()
				$BG.add_child(bgs.C)
				bgs.C.init()
				bgs.C.show()
				if data.has("setup"):
					$Qbox/Candy.show()
					candy_setup.set_text(data.setup.t)
					candy_punchline.set_text(data.punchline.t)
				$Options.set_theme(theme_candy)
				hud.enable_lifesaver(true)
				point_value = 1500 * (1 if question_number < 6 else 2)
				$Value.set_text(R.format_currency(point_value, true))
				$Value.show()
			"O":
				$BG/Noise.set_process(true)
				$BG/Noise.show()
				$BG/Color.modulate = Color("#365c45")
				bgs.O = load("res://Cinematic_Rage.tscn").instance()
				$BG.add_child(bgs.O)
				#bgs.O.init() # no init function here
				bgs.O.show()
				hud.enable_lifesaver(true)
				point_value = 1500 * (1 if question_number < 6 else 2)
				$Value.set_text(R.format_currency(point_value, true))
				$Value.show()
			"G":
				$BG/Noise.set_process(true)
				$BG/Noise.show()
				$BG/Color.modulate = Color("#196892")
				bgs.G = load("res://TextTick.tscn").instance()
				$BG.add_child(bgs.G)
				bgs.G.set_process(true)
				bgs.G.connect("checkpoint", self, "_on_TextTick_checkpoint")
				bgs.G.init_gibberish(
					data.gib_genre.t if data.gib_genre.t else "phrase",
					data.question.t,
					data.clue0.t,
					data.clue1.t,
					data.clue2.t,
					data.answer.t,
					question_number >= 6
				)
				bgs.G.show()
				hud.enable_lifesaver(false)
				gib_clues = 0
				var result = ans_regex.compile(data.answer.r)
				if result != OK:
					print("Could not compile RegEx %s: error code %d" % [data.answer.r, result])
				ep.send_scene("gib", {
					"question": data.question.t
				})
				$Value.hide()
			"T":
				$BG/Noise.set_process(true)
				$BG/Noise.show()
				$BG/Color.modulate = Color("#675c49")
				bgs.G = load("res://TextTick.tscn").instance()
				$BG.add_child(bgs.G)
				bgs.G.set_process(true)
				bgs.G.init_thousand()
				bgs.G.connect('checkpoint', self, "T_checkpoint")
				bgs.G.show()
				$Options.set_theme(theme_normal)
				hud.enable_lifesaver(false)
				$Value.hide()
			"R":
				$BG/Noise.set_process(false)
				$BG/Noise.hide()
				$BG/Color.modulate = Color.black
				hud.enable_lifesaver(false)
				reset_accuracy()
				question_section_number = 0
				bgs.R = load("res://RushBG.tscn").instance()
				$BG.add_child(bgs.R)
				
				hud.show_finale_box(1)
				hud.show_accuracy(accuracy)
				ep.send_scene("rush", {
					'title': data.title.t
				})
				point_value = 36000 / (6 * 6)
				Fb.connect("remote_finale", self, "_on_remote_finale")
			"L":
				$BG/Noise.set_process(false)
				$BG/Noise.hide()
				$BG/Color.modulate = Color.black
				hud.enable_lifesaver(false)
				reset_accuracy()
				question_section_number = 0
				bgs.L = load("res://LikeBG.tscn").instance()
				$BG.add_child(bgs.L)
				hud.show_finale_box(2)
				hud.show_accuracy(accuracy)
				ep.send_scene("like", {
					'title': data.title.t,
				})
				point_value = 36000 / (4 * 5)
				Fb.connect("remote_finale", self, "_on_remote_finale")
		if question_type in ["N", "C", "O", "T", "B"]:
			if question_type == "B":
				bgs.B.set_fields(data.cards.t, data.question.t.strip_edges())
			else:
				question_queue = Loader.parse_time_markers(data.question.t.strip_edges(), true)
				question.bbcode_text = ""
				question.visible_characters = 0
				for el in question_queue:
					question.bbcode_text += el.text
			
			for i in range(0, 4):
				option_boxes[i].set_content(
					data.options.t[i]
				)
				if data.options.i == i:
					responses[i] = 1
					correct_answer = i
				elif data["option%d" % i].v == "random":
					responses[i] = 255
				else:
					responses[i] = 0
			revealed_count = 0
			timer.initialize(15)
			ep.send_scene(
				"thousand" if question_type == "T" else
				"candy" if question_type == "C" else
				"brain" if question_type == "B" else
				"rage" if question_type == "O" else
				"normal", {
				"question": question.bbcode_text,
				"options": data.options.t
			})
		if anim.is_playing():
			yield(anim, "animation_finished")
		finish_loading_screen()
		yield(anim, "animation_finished")
		$Loading.hide()
		if question_type in ["R", "L"]:
			$Vignette.color = Color.black
			anim.play("finale_enter")
			if question_type == "R":
				S.play_music("rush_intro", 1)
			else:
				S.play_music("like_loop_base", 1)
		else:
			call_deferred("change_stage", "pretitle")
	elif stage == "init" and next_stage == "pretitle":
		stage = "pretitle"
		S.play_voice("pretitle")
	elif stage == "pretitle" and next_stage == "title":
		stage = "title"
		S.play_sfx("title_show")
		S.play_voice("title")
		anim.play("title_enter")
	# normal intro
	elif stage == "title" and next_stage == "intro":
		stage = "intro"
		if data.has("intro") and data.intro.v != "":
			S.play_voice("intro")
		else:
			change_stage("question")
	# candy intro
	elif stage == "title" and next_stage == "intro_C":
		stage = "intro"
		bgs.C.connect("intro_ended", self, "intro_C_ended", [], CONNECT_ONESHOT)
		bgs.C.intro()
	# rage intro
	elif stage == "title" and next_stage == "preintro_O":
		stage = "preintro_O"
		S.play_voice("preintro")
	elif stage == "preintro_O" and next_stage == "intro_O":
		stage = "intro"
		bgs.O.connect("intro_ended", self, "intro_O_ended", [], CONNECT_ONESHOT)
		bgs.O.intro()
	# brain intro
	elif stage == "title" and next_stage == "preintro_B":
		stage = "preintro_B"
		S.play_voice("preintro")
	elif stage == "preintro_B" and next_stage == "intro_B":
		stage = "intro"
		bgs.B.connect("intro_ended", self, "intro_B_ended", [], CONNECT_ONESHOT)
		bgs.B.intro()
	# sorta kinda intro
	elif stage == "title" and next_stage == "intro_S":
		stage = "intro"
		bgs.S.intro()
	# gibberish intro
	elif stage == "title" and next_stage == "intro_G":
		stage = "intro"
		bgs.G.connect("intro_ended", self, "intro_G_ended", [], CONNECT_ONESHOT)
		bgs.G.intro_gibberish()
	# thousand intro
	elif stage == "title" and next_stage == "intro_T":
		stage = "intro"
		bgs.G.connect("intro_ended", self, "intro_T_ended", [], CONNECT_ONESHOT)
		bgs.G.intro_thou()
	elif stage == "init" and next_stage == "intro_R":
		stage = "intro_R"
		anim.play("finale_out")
		if R.get_settings_value("cutscenes"):
			enable_skip()
			S.play_voice("rush_intro")
			yield(S, "voice_end"); if !can_skip: return
			bgs.R.tute(0)
			S.play_voice("rush_tute0")
			yield(S, "voice_end"); if !can_skip: return
			bgs.R.tute(1)
			S.play_voice("rush_tute1")
			yield(S, "voice_end"); if !can_skip: return
			bgs.R.tute(2)
			S.play_voice("rush_tute2")
			yield(S, "voice_end"); if !can_skip: return
			bgs.R.tute(3)
			S.play_voice("rush_tute3")
			yield(S, "voice_end"); if !can_skip: return
			disable_skip()
		else:
			S.play_voice("rush_tute3")
			yield(S, "voice_end")
		change_stage("rush_clue")
	elif stage == "init" and next_stage == "intro_L":
		stage = "intro_L"
		bgs.L.play_intro()
		anim.play("finale_out")
		yield(get_tree().create_timer(0.7), "timeout")
		S.play_track(0, 0.75)
		S.play_voice("like_intro")
		yield(S, "voice_end")
		if R.get_settings_value("cutscenes"):
			enable_skip()
			bgs.L.tute(0)
			S.play_voice("like_tute0")
			yield(S, "voice_end"); if !can_skip: return
			bgs.L.tute(1)
			S.play_voice("like_tute1")
			yield(S, "voice_end"); if !can_skip: return
#			bgs.L.tute(2)
#			S.play_voice("like_tute2")
#			yield(S, "voice_end"); if !can_skip: return
#			bgs.L.tute(3)
#			S.play_voice("like_tute3")
#			yield(S, "voice_end"); if !can_skip: return
			bgs.L.tute(-1)
			disable_skip()
		change_stage("like_clue")
	
	elif stage == "intro" and next_stage == "question":
		stage = "question"
		hud.slide_playerbar(true)
		if question_type == "N":
			S.play_multitrack("reading_question_base", 1.0, "reading_question_extra", 1.0)
		elif question_type == "C":
			S.play_track(0, 1.0)
			S.play_track(1, 1.0)
		elif question_type == "O":
			S.play_multitrack("rage_loop", 0.5)
		elif question_type == "B":
			S.play_multitrack("brain_base", 0.5, "brain_extra", 0.0)
			bgs.B.tween_boxes(data.cards.delay)
			S.play_voice("cards")
			ep.send_scene('showQuestion')
			ep.set_pause_penalty(true)
			return
		else:
			# Implementing a new question type, are we?
			breakpoint
		S.play_sfx("question_show")
		S.play_voice("question")
		anim.play("question_enter")
		ep.send_scene('showQuestion')
		ep.set_pause_penalty(true)
		reveal_question_text()
	elif stage == "question" and next_stage == "options":
		stage = "options"
		S.play_sfx("option_show")
		S.play_voice("options")
		if question_type == "B":
			bgs.B.question_shrink()
		else:
			anim.play("question_shrink")
		for i in range(4):
			option_boxes[i].enter(i)
		set_buzz_in(true)
		timer.show_timer()
	elif next_stage == "countdown":
		stage = "countdown"
		if question_type == "N":
			play_answer_music()
		elif question_type == "C":
			S.play_track(0, true)
			S.play_track(1, true)
			S.play_track(2, true)
		elif question_type == "O":
			S.play_multitrack("rage_answer_now", 1.0)
		elif question_type == "B":
			S.play_track(0, 0.8)
			S.play_track(1, 0.8)
		else:
			# Implementing a new question type, are we?
			breakpoint
		timer.start_timer(true)
	elif stage == "options" or stage == "countdown" and next_stage == "reveal":
		stage = "reveal"
		if !len(used_lifesaver) or lifesaver_is_activated:
			ep.set_pause_penalty(false)
		set_buzz_in(false)
		get_tree().create_timer(remote_buzzin_latency).connect("timeout", self, "stop_remote_buzz_in", [], CONNECT_ONESHOT)
		S.stop_voice("options")
		S.play_track(0, false); S.play_track(1, false); S.play_track(2, false)
		timer.stop_timer()
		timer.hide_timer()
		yield(get_tree().create_timer(0.25), "timeout")
		stop_remote_buzz_in()
		# which version of the line will Candy say?
		if lifesaver_is_activated: # TODO
			# lifesaver already used, don't play a voice line. immediately go to option
			reveal_next_option()
		elif not(len(answers[0]) or len(answers[1]) or len(answers[2]) or len(answers[3]) or len(used_lifesaver)):
			# crickets: nobody answered
			S.play_voice("reveal_crickets")
		elif (
			#len(used_lifesaver) == 0 and
			len(answers[0]) and len(answers[1]) and len(answers[2]) and len(answers[3])
		):
			# split: at least 1 person chose each of the 4 options
			S.play_voice("reveal_split")
		elif 0 == len(no_answer) and 0 == len(answered_wrong) and len(used_lifesaver) == 0 and ( # if everyone chose the same option, exactly 3 options will be not true
			int(not(len(answers[0]))) +
			int(not(len(answers[1]))) +
			int(not(len(answers[2]))) +
			int(not(len(answers[3])))
		) == 3 and (
			len(answers[0]) +
			len(answers[1]) +
			len(answers[2]) +
			len(answers[3])
		) >= 3:
			# jinx: at least 3 people answered the same
			S.play_voice("reveal_jinx")
		else:
			S.play_voice("reveal")
	elif stage == "rush_question" and next_stage == "reveal":
		R_show_answers()
	elif stage == "like_question" and next_stage == "reveal":
		L_show_answers()
	
	elif stage == "sorta_setup" and next_stage == "sorta_questions":
		stage = "sorta_questions"
		hud.slide_playerbar(true)
		disable_skip()
		S_show_question()
	elif stage == "sorta_questions" and next_stage == "reveal":
		S_show_answer()
	
	elif stage == "intro" and next_stage == "gib_setup":
		stage = "gib_setup"
		enable_skip()
		S.play_multitrack("gibberish_base", 0.6, "gibberish_extra", 0.0)
		S.play_voice("gib_tute0")
		bgs.G.gib_tute(0)
	elif stage == "gib_setup" and next_stage == "gib_genre":
		stage = "gib_genre"
		if can_skip:
			disable_skip()
		S.play_voice("gib_genre")
		hud.slide_playerbar(true)
		bgs.G.show_price()
		bgs.G.gib_category()
	elif stage == "gib_genre" and next_stage == "gib_question":
		stage = "gib_question"
		ep.set_pause_penalty(true)
		set_buzz_in(true)
		if R.get_settings_value("cutscenes"):
			#S.seek_multitrack(0)
			S.play_track(0, 0.5)
			S.play_track(1, 0.5)
		else:
			S.play_multitrack("gibberish_base", 0.5, "gibberish_extra", 0.5)
		S.play_sfx("question_show")
		S.play_voice("question")
		bgs.G.gib_question()
		bgs.G.connect("checkpoint", self, "G_checkpoint")
	elif stage == "gib_question" and next_stage == "gib_answer":
		stage = "gib_answer"
		ep.set_pause_penalty(false)
		# animation lags so wait
		yield(get_tree(), "idle_frame")
		bgs.G.gib_reveal()
		yield(get_tree().create_timer(0.05), "timeout")
		S.play_music("gibberish_end", 1)
		ep.send_scene('gibReveal', {
			answer = data.answer.t
		})
		hud.reward_players(answers[1], bgs.G.value)
		if len(R.audience_keys):
#			Ws.disconnect("remote_typing", self, "_on_gib_audience_submit")
			for kv_pair in answers_audience[0]:
				hud.reward_players([kv_pair[0]], kv_pair[1])
			
			for kv_pair in answered_wrong_audience:
				hud.punish_players([kv_pair[0]], 0 if no_wrong_penalty_cheat else kv_pair[1])
		yield(get_tree().create_timer(6.0), "timeout")
		
		stage = "outro"
		S.play_music("gibberish_base", 0.0)
		S.play_track(0, 0.6) # prevent sudden start
		S.play_voice("outro")
	
	elif stage == "intro" and next_stage == "thou_setup":
		stage = "thou_setup"
		S.play_multitrack("thousand_loop", 0, "tick_loop", 0)
		S.play_track(0, 0.5)
		if R.get_settings_value("cutscenes"):
			enable_skip()
			S.play_voice("thou_tute0")
			bgs.G.thou_tute(0)
		else:
			change_stage("thou_intro")
	elif stage == "thou_setup" and next_stage == "thou_intro":
		stage = "thou_intro"
		S.play_voice("thou_intro")
		bgs.G.show_price()
	elif stage == "thou_intro" and next_stage == "thou_question":
		stage = "thou_question"
		ep.set_pause_penalty(true)
		hud.slide_playerbar(true)
		bgs.G.countdown(true)
		S.play_track(1, 1)
		S.play_sfx("question_show")
		S.play_voice("question")
		anim.play("question_enter")
		ep.send_scene('showQuestion')
		reveal_question_text()
	elif stage == "thou_question" and next_stage == "thou_options":
		stage = "thou_options"
		S.play_sfx("option_show")
		S.play_voice("options")
		anim.play("question_shrink")
		for i in range(4):
			option_boxes[i].enter(i)
		set_buzz_in(true)
	
	elif stage == "intro_R" and next_stage == "rush_clue":
		bgs.R.show_title(data.title.t)
		ep.send_scene("rushClue")
		hud.slide_playerbar(true)
		S.play_voice("title")
		yield(S, "voice_end")
		S.play_voice("explanation")
		bgs.R.start_question()
#		yield(S, "voice_end")
#		S.play_voice("rush_ready")
		# find out how long the voice line "explanation" is. then subtract 2 seconds from it
		yield(get_tree().create_timer(S.get_voice_length("explanation") - 2.0), "timeout")
		last_pos = S.music_dict[S.tracks[0]].get_playback_position()
		stage = "rush_wait"
		get_tree().connect("idle_frame", self, "_R_wait_to_start")
	
	elif stage == "intro_L" and next_stage == "like_clue":
		stage = "intro_L"
		S.play_voice("like_title")
		yield(S, "voice_end")
		bgs.L.show_title(data.title.t)
		S.play_voice("title")
		ep.send_scene("likeClue")
		yield(S, "voice_end")
		S.play_voice("like_options")
		yield(S, "voice_end")
		var options = data.options.o
		assert(typeof(options) == TYPE_ARRAY)
		bgs.L.show_initial_options(options)
		S.play_voice("options")
		yield(S, "voice_end")
		S.play_voice("like_ready")
		timer.initialize(10)
		yield(S, "voice_end")
		S.play_music("like_loop_ingame", 0.75)
		L_show_question()

	elif next_stage == "outro":
		stage = "outro"
		if question_type == "N" or question_type == "T":
			var which_outro: int = R.rng.randi_range(1, 3)
			S.play_music("outro_%d" % which_outro, 1.0)
		elif question_type == "C":
			S.play_music("candy_base", 1.0)
		elif question_type == "O":
			S.play_music("rage_outro", 1.0)
		elif question_type == "B":
			S.play_music("brain_outro", 1.0)
		else:
			# Implementing a new question type, are we?
			breakpoint
		yield(get_tree().create_timer(1.5), "timeout")
		S.play_track(0, 0.5)
		yield(get_tree().create_timer(0.5), "timeout")
		hud.hide_accuracy_audience()
		S.play_voice("outro")
	elif stage == "outro" and next_stage == "end":
		stage = "end"
		print("Change stage to end")
		S.play_track(0, false)
		ep.revert_scene('')
		ep.send_scene('endQuestion')
		S.play_sfx("question_leave")
		# all the question types with question text, title, or point value
		#if question_type in ["N", "C", "O", "T", "G", "S", "B"]:
		anim.play("question_exit")
		#endif (should be inaccessible from finale anyway)
		$Vignette.close()
#		if question_number != 5:
#			$Vignette.connect("tween_finished", self, "show_loading_logo", [], CONNECT_ONESHOT)
		hud.slide_playerbar(false)
		print("DEBUG PRINT UNLOAD MUSIC")
		for k in musics[question_type]:
			S.unload_music(k)
		for b in option_boxes:
			b.reset()
		print("Question is successfully finished!")
		while $Vignette.tween.is_active():
			print("DEBUG PRINT WAIT FOR VIGNETTE")
			yield(get_tree(), "idle_frame")
		print("DEBUG PRINT UNLOAD BG")
		# TQQ reuses Gibberish background
		var q_to_unload = "G" if question_type == "T" else question_type
		if q_to_unload != "N":
			if is_instance_valid(bgs[q_to_unload]):
				bgs[q_to_unload].queue_free()
		emit_signal("question_done")
	elif next_stage == "before_countdown":
		# just finished revealing lifesaver decoys
		stage = "before_countdown"
		timer.initialize(15)
		timer.show_timer()
		hud.players_used_lifesaver(used_lifesaver)
		S.play_voice("used_lifesaver")
	else:
		printerr("Unrecognized stage: ", next_stage)
		#	breakpoint

func _on_voice_end(voice_id):
	match stage:
		"pretitle":
			change_stage("title")
		"title":
			# Some question types have an extra line
			if voice_id == "title":
				if question_type == "S":
					S.play_voice("sort_segue")
				elif question_type == "T":
					S.play_voice("thou_segue")
				else:
					S.play_sfx("title_leave")
					$Vignette.open()
					anim.play("title_exit")
			else:
				S.play_sfx("title_leave")
				$Vignette.open()
				anim.play("title_exit")
				#stage("intro") # This happens when the animation stops playing
		"preintro_O":
			change_stage("intro_O")
		"preintro_B":
			change_stage("intro_B")
		"intro":
			# is this a Candy Trivia, and if so, is there a candy joke?
			if question_type == "C" and data.has("setup"):
				stage = "candy_setup"
				anim.play("candy_enter")
				S.play_voice("setup")
			else:
				change_stage("question")
		"candy_setup":
			stage = "candy_punchline"
			anim.play("candy_punchline")
			S.play_voice("punchline")
		"candy_punchline":
			stage = "candy_post_punchline"
			S.play_track(0, false)
			anim.play("candy_bruh")
			S.play_sfx("rimshot")
			yield(get_tree().create_timer(1.2), "timeout")
			S.play_track(0, true)
			S.play_voice("post_punchline")
		"candy_post_punchline":
			stage = "intro"
			change_stage("question")
		"sorta_setup":
			#var last_line_name: String = "sort_lifesaver" if R.get_lifesaver_count() == 0 else "sort_no_lifesaver"
# possible scenarios:
# if no "Both":
# sort_category -> sort_explain ->
# sort_a -> sort_b ->
# sort_a_short -> sort_press_left ->
# sort_b_short -> sort_press_right ->
# sort—lifesaver -> (start question)
# if with "Both":
# sort_category -> sort_explain ->
# sort_a -> sort_b -> sort_both ->
# sort_a_short -> sort_press_left ->
# sort_b_short -> sort_press_right ->
# sort_press_up ->
# sort_lifesaver -> (start question)
			match voice_id:
				"sort_category":
					S.play_voice("sort_explain")
				"sort_explain":
					bgs.S.show_option(0)
					S.play_sfx("sort_a")
					yield(get_tree().create_timer(0.2), "timeout")
					S.play_voice("sort_a")
				"sort_a":
					if not data.has_both:
						enable_skip()
					bgs.S.show_option(1)
					S.play_sfx("sort_b")
					yield(get_tree().create_timer(0.2), "timeout")
					S.play_voice("sort_b")
				"sort_b":
					if true == data.has_both:
						enable_skip()
						bgs.S.show_option(2)
						S.play_sfx("sort_both")
						yield(get_tree().create_timer(0.2), "timeout")
						S.play_voice("sort_both")
					else:
						bgs.S.short_option(0)
						S.play_sfx("sort_a")
						yield(get_tree().create_timer(0.2), "timeout")
						S.play_voice("sort_a_short")
				"sort_both":
					enable_skip()
					bgs.S.short_option(0)
					S.play_sfx("sort_a")
					yield(get_tree().create_timer(0.2), "timeout")
					S.play_voice("sort_a_short")
				"sort_a_short":
					bgs.S.show_button(0)
					S.play_sfx("sort_button", 1.0)
					S.play_voice("sort_press_left")
				"sort_press_left":
					bgs.S.short_option(1)
					S.play_sfx("sort_b")
					yield(get_tree().create_timer(0.2), "timeout")
					S.play_voice("sort_b_short")
				"sort_b_short":
					bgs.S.show_button(1)
					S.play_sfx("sort_button", 1.25)
					S.play_voice("sort_press_right")
				"sort_press_right":
					if true == data.has_both:
						bgs.S.show_button(2)
						S.play_voice("sort_press_up")
						S.play_sfx("sort_button", 1.5)
					else:
						disable_skip()
						S.play_voice("sort_lifesaver")
				"sort_press_up":
					disable_skip()
					S.play_voice("sort_lifesaver")
				"sort_lifesaver":
					change_stage("sorta_questions")
		"sorta_questions":
			if waiting_for_timer:
				timer.start_timer(true)
			waiting_for_timer = false
			S._set_music_vol(0, 1.0, false)
		"sorta_answers":
			waiting_for_timer = false
		"gib_setup":
			match voice_id:
				"gib_tute0":
					S.play_voice("gib_tute1")
					bgs.G.gib_tute(1)
				"gib_tute1":
					S.play_voice("gib_tute2")
					bgs.G.gib_tute(2)
				"gib_tute2":
					S.play_voice("gib_tute3")
					bgs.G.gib_tute(3)
				"gib_tute3":
					disable_skip()
					S.play_voice("gib_tute4")
					bgs.G.gib_tute(4)
				"gib_tute4":
					change_stage("gib_genre")
		"gib_genre":
			change_stage("gib_question")
		"gib_question":
			match voice_id:
				"question":
					bgs.G.countdown(true)
					return
				"reveal":
					change_stage("gib_answer")
					return
				"gib_wrong":
					# penalize
					S.play_sfx("option_wrong")
					hud.punish_players(answers[0], 0 if no_wrong_penalty_cheat else bgs.G.value)
					# Move the person incorrectly answering to bucket 1
					answered_wrong.push_back(answers[0].pop_back())
					# no people left to buzz in?
					yield(get_tree().create_timer(1.5), "timeout")
					# pass through to "prepare for next player"
					G_prepare_next_player()
				"cuss_a2":
					# pass through to "prepare for next player"
					G_prepare_next_player()
				"cuss_b0":
					hud.punish_players(answers[0], 0)
					# pass through to "prepare for next player"
					G_prepare_next_player()
				_:
					pass
		
		"thou_setup":
			match voice_id:
				"thou_tute0":
					S.play_voice("thou_tute1")
					bgs.G.thou_tute(1)
				"thou_tute1":
					S.play_voice("thou_tute2")
					bgs.G.thou_tute(2)
				"thou_tute2":
					bgs.G.thou_tute(3)
					disable_skip()
					change_stage("thou_intro")
		"thou_intro":
			change_stage("thou_question")
		
		"thou_question":
			change_stage("thou_options")
		
		"rush_clue":
			change_stage("rush_stage")
		
		"question":
			if question_type == "B" and voice_id == "cards":
				S.play_voice("question")
				bgs.B.show_question_text()
			change_stage("options")
		"options":
			change_stage("countdown")
		"reveal":
			print("voice line reveal end")
			reveal_next_option()
		"option":
			# finished reading out option reveal voice line
			if question_type == "T":
				point_value = bgs.G.value
			if responses[correct_answer] == RESPONSE_USED:
				# just revealed the right answer
				ep.send_scene('correctReveal', {index = correct_answer})
				# check if anyone who answered right used a lifesaver
				var lifesaver_correct = 0
				for p in used_lifesaver:
					if p in answers[correct_answer]:
						lifesaver_correct += 1
				# check if anyone in the audience answered it right
				# (and remove the audience from the correct answer count calculations)
				var audience_correct: int = 0
				var audience_answered: int = 0
				if !R.audience.empty():
					audience_correct = len(answers_audience[correct_answer])
					audience_answered = len(R.audience) - len(no_answer_audience)
					if audience_answered > 0:
						hud.show_accuracy_audience(
							float(100 * audience_correct) / float(audience_answered)
						)
					else:
						hud.show_accuracy_audience(NAN)
				if 0 < len(answers[correct_answer]):
					S.play_sfx("point_gain")
					if question_type == "T" and point_value >= 1000:
						ep.achieve.increment_progress("tqq_x1", 1)
					if lifesaver_is_activated and lifesaver_correct:
						ep.achieve.increment_progress("correct_with_lifesaver", 1)
				else:
					S.play_sfx("option_correct")
				for i in range(4):
					if i == correct_answer:
						option_boxes[i].right()
						hud.reward_players(answers[i], point_value)
						for p in answers[i]:
							R.players[p].accuracy[0] += 1
						# keep score of audience
						if audience_answered > 0:
							if question_type == "T":
								# [[index, point value], [index, point value], ...]
								for kv_pair in answers_audience[i]:
									hud.reward_players([kv_pair[0]], kv_pair[1])
									#R.audience[kv_pair[0]].accuracy[0] += 1
							else:
								# [indices]
								hud.reward_players(answers_audience[i], point_value)
								#for p in answers_audience[i]:
									#R.audience[p].accuracy[0] += 1
					elif responses[i] != RESPONSE_USED:
						# evacuate all unannounced wrong answers
						option_boxes[i].leave()
						hud.punish_players(answers[i], 0 if no_wrong_penalty_cheat else point_value)
						# keep score of audience
						if audience_answered > 0:
							if question_type == "T":
								# [[index, point value], [index, point value], ...]
								for kv_pair in answers_audience[i]:
									hud.punish_players([kv_pair[0]], 0 if no_wrong_penalty_cheat else kv_pair[1])
							else:
								# [indices]
								hud.punish_players(answers_audience[i], 0 if no_wrong_penalty_cheat else point_value)
				change_stage("outro")
			else:
				ep.send_scene('wrongReveal', {index = last_revealed_answer})
				#ep.revert_scene('wrongReveal')
				option_boxes[last_revealed_answer].wrong()
				S.play_sfx("option_wrong")
				hud.punish_players(answers[last_revealed_answer], 0 if no_wrong_penalty_cheat else point_value)
				yield(get_tree().create_timer(1.0), "timeout")
				answered_wrong.append_array(answers[last_revealed_answer])
				answers[last_revealed_answer] = []
				if !R.audience.empty():
					answered_wrong_audience.append_array(answers_audience[last_revealed_answer])
					# keep score of audience
					if len(answers_audience[last_revealed_answer]) > 0:
						if question_type == "T":
							# [[index, point value], [index, point value], ...]
							for kv_pair in answers_audience[last_revealed_answer]:
								hud.punish_players([kv_pair[0]], 0 if no_wrong_penalty_cheat else kv_pair[1])
						else:
							# [indices]
							hud.punish_players(answers_audience[last_revealed_answer], 0 if no_wrong_penalty_cheat else point_value)
						answers_audience[last_revealed_answer] = []
				reveal_next_option()
		"reveal_correct":
			reveal_option(correct_answer)
		"before_countdown":
			set_buzz_in(true)
			lifesaver_is_activated = true
			no_answer = used_lifesaver # no need for .duplicate() because it's PoolByteArray
			# used_lifesaver = []
			change_stage("countdown")
		"outro":
			change_stage("end")
		_:
			print("unhandled voice line ended: stage %s voice %s" % [stage, voice_id])

# keep removing options
func reveal_next_option():
	# are we in a thousand question question?
	if question_type == "T":
		if ( # all the wrong answers were revealed
			int(responses[0] == RESPONSE_USED) +
			int(responses[1] == RESPONSE_USED) +
			int(responses[2] == RESPONSE_USED) +
			int(responses[3] == RESPONSE_USED)
		) == 3 or ( # nobody else is left to answer
			len(no_answer) == 0
		):
			stage = "reveal_correct"
			get_tree().create_timer(remote_buzzin_latency).connect("timeout", self, "stop_remote_buzz_in", [], CONNECT_ONESHOT)
			S.play_voice("reveal_correct")
		else:
			S.play_track(0, 0.5); S.play_track(1, 1)
			bgs.G.countdown_pause(false)
			set_buzz_in(true)
		return
	# did somebody use a lifesaver?
	if !lifesaver_is_activated and len(used_lifesaver) > 0:
		# find out if there are exactly 2 options left
		if revealed_count == 2:
			# buzz in again
			change_stage("before_countdown")
			return
		else:
			# is there a wrong choice that someone chose?
			var options = [0, 1, 2, 3]
			var wrong = -1
			while len(options):
				var choice = options.pop_at(R.rng.randi_range(0, len(options) - 1))
				if choice == correct_answer or responses[choice] == RESPONSE_USED:
					continue
				# if somebody chose it, and it is a specific line,
				# reveal it
				if responses[choice] == 0:
					if len(answers[choice]) > 0:
						reveal_option(choice)
						return
					# otherwise, if it is a specific line, save it for later
					wrong = choice
				# generic wrong answer line.
				# save it for later if there are no other wrong answer lines.
				elif wrong == -1:
					# if no wrong answer yet, choose it
					wrong = choice
			# no? pick the first wrong answer we found
			reveal_option(wrong)
			return
	# see if we have an unrevealed option with a specific voice line
	var options = [0, 1, 2, 3]
	var generic = -1
	while len(options):
		var choice = options.pop_at(R.rng.randi_range(0, len(options) - 1))
		if len(answers[choice]) > 0:
			if responses[choice] == 0:
				# Found one!
				reveal_option(choice)
				return
			elif responses[choice] == 255:
				generic = choice
	# okay, the rest are all generic answers
	# see if nobody answered
	if revealed_count == 0 and len(answers[0])+len(answers[1])+len(answers[2])+len(answers[3]) == 0:
		reveal_option(correct_answer)
		return
	# see if everybody chose the right answer (option 1)
	if revealed_count == 0 and len(answers[0])+len(answers[1])+len(answers[2])+len(answers[3])-len(answers[correct_answer])==0:
		reveal_option(correct_answer)
		return
	# see if nobody chose the right answer (option 2 and later)
	if revealed_count > 0 and len(answers[correct_answer]) == 0:
		# show the correct answer
		stage = "reveal_correct"
		S.play_voice("reveal_correct")
		return
	# see if someone chose the right answer (option 2 and later)
	if revealed_count > 0 and len(answers[correct_answer]) > 0:
		# no more incorrect answers
		reveal_option(correct_answer)
		return
	reveal_option(generic)

func reveal_option(choice):
	stage = "option"
	last_revealed_answer = choice
	# highlight the choice
	option_boxes[last_revealed_answer].highlight()
	# highlight any players who chose it
	hud.highlight_players(answers[last_revealed_answer])
	S.play_sfx("option_highlight")
	yield(get_tree().create_timer(0.4), "timeout")
	S.play_voice("option%d" % choice)
	revealed_count += 1
	# make sure we don't choose this response again.
	responses[choice] = RESPONSE_USED

# revealing the question text gradually
func reveal_question_text():
	print("Question queue: ", question_queue)
	if len(question_queue):
		var next = question_queue.pop_front()
		question_tween.interpolate_property(
			question, "visible_characters",
			question.visible_characters,
			question.visible_characters + next.chars,
			0.2, Tween.TRANS_CUBIC, Tween.EASE_OUT
		)
		question_tween.start()
		if next.time > 0:
			question_timer.start((next.time / 1000.0) - S.get_voice_time())

func _on_anim_finished(anim_name):
	if anim_name == "title_exit":
		anim.play("title_reenter")
		match question_type:
			"N", "S", "C", "O", "B":
				pass
				#anim.play("title_reenter")
			"G":
				change_stage("intro_G")
			"T":
				change_stage("intro_T")
			_:
				printerr("Unrecognized question type: " + question_type)
				change_stage("intro")
	elif anim_name == "title_reenter":
		match question_type:
			"N":
				change_stage("intro")
			"S":
				change_stage("intro_S")
			"C":
				change_stage("intro_C")
			"O":
				$Qbox/Candy.hide()
				change_stage("preintro_O")
			"B":
				$Qbox/Candy.hide()
				change_stage("preintro_B")
	elif anim_name == "finale_enter":
		if question_type == "R":
			change_stage("intro_R")
		else:
			change_stage("intro_L")

func _on_QuestionRevealTimer_timeout():
	reveal_question_text()

func _on_question_time_up():
	# If the typing timer expires, force submit the text
	if question_type in ["G"]:
		kb.submit()
		return
	# Some special question types should not play default "time up" sound effect.
	if question_type in ["N", "C", "L", "B"]:
		S.play_sfx("time_up")
	change_stage("reveal")

# Candy Trivia intro ended.
func intro_C_ended():
	# possible scenarios:
	# intro -> setup -> punchline -> post_punchline -> question
	# intro -> question
	# question
	S.play_multitrack("candy_base", true, "candy_extra", false, "candy_extra2", false)
	if data.has("intro"):
		if R.get_settings_value("cutscenes"):
			S.play_voice("intro")
		else:
			stage = "candy_setup"
			anim.play("candy_enter")
			S.play_voice("setup")
	else:
		change_stage("question")

func intro_O_ended():
	$BG/Noise.set_process(false)
	$BG/Noise.hide()
	# question
	S.play_multitrack("rage_loop", 0.5)
	S.play_voice("intro")

func intro_B_ended():
	# question
	S.play_multitrack("brain_base", 0.5)
	S.play_voice("intro")

# Sorta Kinda intro ended.
func intro_S_ended():
	stage = "sorta_setup"
	S.play_multitrack("sort_base", true, "sort_extra", false)
	S.seek_multitrack(0.168)
	S.play_voice("sort_category")
# Sorta Kinda outro ended.
func outro_S_ended():
	stage = "outro"
	S.play_music("sort_base", true)
	S.seek_multitrack(0.168)
	S.play_voice("outro")

func intro_G_ended():
	if R.get_settings_value("cutscenes"):
		change_stage("gib_setup")
	else:
		stage = "gib_setup"
		change_stage("gib_genre")

func intro_T_ended():
	change_stage("thou_setup")

func S_show_question():
	can_skip = false
	var i = question_section_number
	if i == 7:
		stage = "sort_end"
		hud.reset_all_playerboxes(true)
		#S._stop_music("sort_base"); S._stop_music("sort_extra")
		S.play_music("sort_outro", 0.65)
		hud.show_accuracy(accuracy)
#		ep.revert_scene('sortQuestion')
		# find best accuracy of players
		var winners = []
		var losers = []
		var breakevens = []
		var max_acc = 0
		var max_acc_index = []
		var max_acc_players = []
		for p in range(len(R.players)):
			# find player(s) with max accuracy
			if max_acc < accuracy[p * 2]:
				max_acc = accuracy[p * 2]
				max_acc_index = [p]
				max_acc_players = [R.players[p].name]
			elif max_acc == accuracy[p * 2]:
				max_acc_index.append(p)
				max_acc_players.append(R.players[p].name)
			# find out who gained money, lost money, and broke even
			if accuracy[p * 2] * 2 > accuracy[p * 2 + 1]:
				winners.append(p)
			elif accuracy[p * 2] * 2 < accuracy[p * 2 + 1]:
				losers.append(p)
			else:
				breakevens.append(p)
			# show remote players their own score
			if p in ep.remote_players:
				Fb.send_to_player(
					R.players[p].device_name,
					{
						action = 'sortAcc',
						numerator = accuracy[p * 2],
						denominator = accuracy [p * 2 + 1],
					}
				)
#				Ws.send('message', {
#					'action': 'changeScene',
#					'sceneName': 'sortAcc',
#					'numerator': accuracy[p * 2],
#					'denominator': accuracy[p * 2 + 1],
#				}, R.players[p].device_name)
		if max_acc == 7:
			ep.achieve.increment_progress("dod_perfect", 1)
	
		# find accuracy of audience
		var audience_correct: int = 0
		var audience_answered: int = 0
		for p in range(len(R.audience)):
			audience_correct += accuracy_audience[p * 2]
			audience_answered += accuracy_audience[p * 2 + 1]
			# show remote players their own score
			Fb.send_to_player(
				R.players[p].device_name,
				{
					action = 'sortAcc',
					numerator = accuracy_audience[p * 2],
					denominator = accuracy_audience[p * 2 + 1],
				}
			)
#			Ws.send('message', {
#				'action': 'changeScene',
#				'sceneName': 'sortAcc',
#				'numerator': accuracy_audience[p * 2],
#				'denominator': accuracy_audience[p * 2 + 1],
#			}, R.audience[p].device_name)
		var audience_accuracy_percentage: float = NAN
		if audience_answered > 0:
			audience_accuracy_percentage = (
				float(100 * audience_correct) / float(audience_answered)
			)
		hud.show_accuracy_audience(audience_accuracy_percentage)
		
		bgs.S.outro(max_acc, max_acc_players)
		if max_acc == 7:
			S.play_voice("sort_perfect")
		elif max_acc >= 5:
			S.play_voice("sort_good")
		elif max_acc >= 3:
			S.play_voice("sort_ok")
		else:
			S.play_voice("sort_bad")
		hud.highlight_players(max_acc_index)
		
		# the time it takes until the drop in the ending music
		yield(get_tree().create_timer(5.3), "timeout")
		hud.hide_accuracy()
		hud.hide_accuracy_audience()
		hud.reward_players(winners, 0)
		hud.punish_players(losers, 0) # purely visual
		hud.reset_playerboxes(breakevens)
	else:
		stage = "sorta_questions"
		reset_answers()
		ep.set_pause_penalty(true)
		# DEBUG: let players randomly answer
#		for p in range(0, 8):
#			var choice = R.rng.randi_range(0, 2 if data.has_both else 1)
#			if choice < 0:
#				# cheat
#				choice = data.sort_options.a[i]
#			answers[choice].push_back(p)
		# END DEBUG
		S.play_track(0, 0.8)
		S.play_track(1, 1)
		bgs.S.show_question(data.sort_options.t[i])
		timer.initialize(5)
		timer.show_timer()
		hud.reset_all_playerboxes()
		if i != 0:
			ep.revert_scene('sortQuestion')
			hud.hide_accuracy_audience()
		ep.send_scene('sortQuestion', {
			"question": data.sort_options.t[i]
		})
		set_buzz_in(true)
		waiting_for_timer = true
		S.play_voice("sort_option%d" % i)

func S_show_answer():
	stage = "sorta_answers"
	timer.stop_timer()
	timer.hide_timer()
	ep.set_pause_penalty(false)
	set_buzz_in(false)
# warning-ignore:return_value_discarded
	get_tree().create_timer(remote_buzzin_latency).connect("timeout", self, "stop_remote_buzz_in", [], CONNECT_ONESHOT)
	var i = question_section_number
	bgs.S.answer(data.sort_options.a[i])
	ep.send_scene('sortAnswer', {"index": data.sort_options.a[i]})
	if data.sort_options.a[i] == 0:
		S.play_sfx("sort_a_long")
	elif data.sort_options.a[i] == 1:
		S.play_sfx("sort_b_long")
	elif data.sort_options.a[i] == 2:
		S.play_sfx("sort_both_long")
	else:
		breakpoint
	# grade answers
	var audience_correct: int = 0; var audience_answered: int = 0
	for j in range(3 if data.has_both else 2):
		if data.sort_options.a[i] == j:
			hud.reward_players(answers[j], point_value)
			for p in answers[j]:
				R.players[p].accuracy[0] += 1
				if p < len(R.players):
					accuracy[p * 2] += 1
					accuracy[p * 2 + 1] += 1
				else:
					audience_correct += 1; audience_answered += 1
					accuracy_audience[(p - len(R.players)) * 2] += 1
					accuracy_audience[(p - len(R.players)) * 2 + 1] += 1
		else:
			hud.punish_players(answers[j], 0 if no_wrong_penalty_cheat else point_value)
			for p in answers[j]:
				if p < len(R.players):
					#accuracy[p][0] += 1 # Don't, they got it wrong.
					accuracy[p * 2 + 1] += 1
				else:
					audience_answered += 1
					accuracy_audience[(p - len(R.players)) * 2 + 1] += 1
	print("ply acc:", accuracy)
	print("aud acc:", accuracy_audience)
	if len(accuracy_audience):
		# gdscript errors on 0.0/0.0 so I manually produce NAN
		if audience_answered:
			hud.show_accuracy_audience(float(100 * audience_correct) / float(audience_answered))
		else:
			hud.show_accuracy_audience(NAN)
	question_section_number += 1

func S_answer_shown():
	S.stop_voice()
	S_show_question()

func _on_TextTick_checkpoint():
	printerr("DEPRECATED")

func G_checkpoint(id: int):
	match id:
		0:
			S.play_voice("clue0")
			ep.send_scene('gibClue', {
				i = 0,
				t = data.clue0.t
			})
			gib_clues = 1
		1:
			S.play_voice("clue1")
			ep.send_scene('gibClue', {
				i = 1,
				t = data.clue1.t
			})
			gib_clues = 2
		2:
			S.play_voice("clue2")
			ep.send_scene('gibClue', {
				i = 2,
				t = data.clue2.t
			})
			gib_clues = 3
		3:
			set_buzz_in(false)
			get_tree().create_timer(remote_buzzin_latency).connect("timeout", self, "stop_remote_buzz_in", [], CONNECT_ONESHOT)
			ep.set_pause_penalty(false)
			S.play_track(0, 0); S.play_track(1, 0)
			S.play_sfx("time_up")
			yield(get_tree().create_timer(0.25), "timeout")
			S.play_voice("reveal")
			print("Gibberish gave up")
			bgs.G.disconnect("checkpoint", self, "G_checkpoint")

func G_prepare_next_player():
	# prepare for next player
	if len(no_answer) == 0:
		S.play_track(0, 0.0)
		S.play_track(1, 0.0)
		S.play_voice("reveal")
	else:
		# prepare buzz in
		answers[0] = []
		S.play_track(0, 0.5)
		S.play_track(1, 0.5)
		bgs.G.countdown_pause(false)
		stage = "gib_question"
		set_buzz_in(true)

func T_checkpoint(id: int):
	if id == 0:
		set_buzz_in(false)
		get_tree().create_timer(remote_buzzin_latency).connect("timeout", self, "stop_remote_buzz_in", [], CONNECT_ONESHOT)
		S.play_track(0, 0); S.play_track(1, 0)
		S.play_sfx("time_up")
		ep.set_pause_penalty(false)
		yield(get_tree().create_timer(0.25), "timeout")
		print("Gibberish gave up")
		bgs.G.disconnect("checkpoint", self, "T_checkpoint")
		S.play_voice("reveal_correct"); yield(S, "voice_end")
		reveal_option(correct_answer)
	else:
		breakpoint

func R_show_question():
	if question_section_number == 6:
		# Question is over!
		hud.slide_playerbar(false)
		# maximum 18000 dollars for final round
		for i in range(len(R.players)):
			var gain = point_value * (accuracy[i * 2] - accuracy[i * 2 + 1] / 2)
			R.players[i].score += gain
			R.players[i].accuracy[1] += accuracy[i * 2 + 1]
			R.players[i].accuracy[0] += accuracy[i * 2]
		for i in range(len(R.audience)):
			var gain = point_value * (accuracy_audience[i * 2] - accuracy_audience[i * 2 + 1] / 2)
			R.audience[i].score += gain
#			R.audience[i].accuracy[1] += accuracy[i * 2 + 1]
#			R.audience[i].accuracy[0] += accuracy[i * 2]
		bgs.R.queue_free()
		emit_signal("question_done")
	else:
		ep.set_pause_penalty(true)
		hud.reset_finale_box()
		reset_answers()
		S._stop_music(0)
		S.play_music("rush_phase_%d" % (question_section_number + 1), true)
		var section = data["section%d" % question_section_number]
		bgs.R.start_round(
			section.q, section.o
		)
		timer.initialize(15)
		timer.start_timer()
		if question_section_number > 0:
			ep.revert_scene("rushSection")
		ep.send_scene("rushSection", {
			'question': section.q,
			'options': section.o
		})
		set_buzz_in(true)

func R_show_answers():
	set_buzz_in(false)
	get_tree().create_timer(remote_buzzin_latency).connect("timeout", self, "stop_remote_buzz_in", [], CONNECT_ONESHOT)
	ep.set_pause_penalty(false)
	bgs.R.time_up(true)
	var solutions = data["section%d" % question_section_number].a
	ep.send_scene("rushReveal", {
		'answers': solutions
	})
	yield(get_tree().create_timer(0.7), "timeout")
	var audience_right: int = 0; var audience_total: int = 0
	for i in range(6):
		bgs.R.reveal_option(
			i, bool(solutions[i])
		)
		S.play_sfx(
			"rush_yes" if solutions[i] else "rush_no"
		)
		for j in range(len(R.players)):
			if answers[i].has(j) == bool(solutions[i]):
				accuracy[j * 2] += 1
			accuracy[j * 2 + 1] += 1
		hud.show_accuracy(accuracy)
		hud.confirm_finale_answer(i, bool(solutions[i]))
		for j in range(len(R.audience)):
			if answers_audience[i].has(j) == bool(solutions[i]):
				accuracy_audience[j * 2] += 1
				audience_right += 1
			accuracy_audience[j * 2 + 1] += 1
			audience_total += 1
		yield(get_tree().create_timer(0.35), "timeout")
	if audience_total > 0:
		hud.show_accuracy_audience(float(100 * audience_right) / float(audience_total))
	yield(get_tree().create_timer(0.75), "timeout")
	bgs.R.time_up(false)
	yield(get_tree().create_timer(0.5), "timeout")
	hud.hide_accuracy_audience()
	question_section_number += 1
	R_show_question()

func L_show_question():
	if question_section_number == 5:
		# Question end!
		# maximum 18000 dollars for final round
		for i in range(len(R.players)):
			var gain = point_value * (accuracy[i * 2] - (accuracy[i * 2 + 1] / 2))
			R.players[i].score += gain
			R.players[i].accuracy[1] += accuracy[i * 2 + 1]
			R.players[i].accuracy[0] += accuracy[i * 2]
		for i in range(len(R.audience)):
			if accuracy_audience[i * 2 + 1] == 0:
				continue # bail out before potential division by zero error on next line
			var gain = point_value * (accuracy_audience[i * 2] - (accuracy_audience[i * 2 + 1] / 2))
			R.audience[i].score += gain
#			R.audience[i].accuracy[1] += accuracy[i * 2 + 1]
#			R.audience[i].accuracy[0] += accuracy[i * 2]
		S.play_music("like_outro", 0.75)
		bgs.L.end_question()
		yield(get_tree().create_timer(1.0), "timeout")
		S.play_voice("like_outro")
		yield(get_tree().create_timer(6.0), "timeout") # wait for animation to end
		emit_signal("question_done")
		bgs.L.queue_free()
	else:
		stage = "like_question"
		timer.initialize(10)
		ep.set_pause_penalty(true)
		timer.show_timer()
		var section = data["section%d" % question_section_number]
		if question_section_number > 0:
			ep.revert_scene("likeSection")
		ep.send_scene("likeSection", {
			'question': section.t,
			'options': section.o
		})
		bgs.L.show_question(section.t, section.o, question_section_number)
		S.play_voice("section%d" % question_section_number)
		timer.start_timer()
		reset_answers()
		bgs.L.reset_all_answers()
		set_buzz_in(true)

func L_show_answers():
	set_buzz_in(false)
	get_tree().create_timer(remote_buzzin_latency).connect("timeout", self, "stop_remote_buzz_in", [], CONNECT_ONESHOT)
	ep.set_pause_penalty(false)
	stop_remote_buzz_in()
	timer.hide_timer()
	var section = data["answer%d" % question_section_number]
	bgs.L.reveal(section.a)
	yield(bgs.L.anim, "animation_finished")
	yield(get_tree().create_timer(1), "timeout")
	ep.send_scene("likeReveal", {
		'answers': section.a
	})
	for i in range(4):
		for j in range(len(R.players)):
			if answers[i].has(j) == bool(section.a[i]):
				accuracy[j * 2] += 1
			accuracy[j * 2 + 1] += 1
	S.play_voice("answer%d" % question_section_number)
	yield(S, "voice_end")
	question_section_number += 1
	L_show_question()

func play_answer_music():
	match R.rng.randi_range(1, 5):
		1:
			S.play_music("answer_now", true)
		2:
			S.play_music("answer_now_2", true)
		3:
			S.play_music("answer_now_3", true)
		4:
			S.play_music("answer_now_4", true)
		5:
			S.play_music("answer_now_5", true)

func _on_TouchButton_pressed():
	# 4 = touchscreen, 5 = right face button, true = pressed
	C.inject_button(4, 5, true)

func _on_LSButton_pressed():
	# 4 = touchscreen, 0 = left shoulder button, true = pressed
	C.inject_button(4, 0, true)

#func _on_server_reply(id):
#	# what the fuck does this do?
#	pass
##	if Ws.server_reply_content == "name given":
##		_send_scenes_to(Ws.client_name)
#
#func _on_player_requested_nick(id):
#	for i in ep.remote_players:
#		if R.players[i].device_name == id:
##			Ws.send('message', {
##				action = 'changeNick',
##				nick = R.players[i].name,
##				playerIndex = i
##			}, id)
#			_send_scenes_to(id)
#			break
#
#func _send_scenes_to(id):
#	for scene in scene_history:
#		print("Scene: ", scene)
##		Ws.send('message', scene, id)

func finish_loading_screen():
	S.play_track(0, 0.0)
	loadanim.play("straighten", 0.4, 1.0)
	anim.play("touchprism_leave")
