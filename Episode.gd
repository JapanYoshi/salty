extends ColorRect

onready var q_box = $Standard
onready var c_box = $Cutscenes
onready var hud = $HUD
var episode_data = {}
var question_number = 0
var intermission_played = false
var skippable = false
var skipped = false
var DEBUG = false
# make a list of players using phones-as-controllers
var remote_players = []
var penalize_pausing = false

# Called when the node enters the scene tree for the first time.
func _ready():
	q_box.ep = self
	q_box.kb = get_node("TypingHandler")
	q_box.set_process(false)
	c_box.set_process(true)
	S.play_sfx("blank")
	$Shutter/AnimationPlayer.stop()
	$SkipButton.hide()
	$BackButton.hide()
	$Cutscenes/Circle.color = Color.black
	$Cutscenes/Circle.modulate = Color.white
	$Cutscenes/TechDiff.hide()
	$Cutscenes/Final.hide()
	q_box.connect("question_done", self, "load_next_question")
	q_box.hud = hud
	question_number = 0
#	if not R.pass_between.has("episode_name"):
#		# we're debugging
#		R.pass_between.episode_name = "demo"
#		question_number = 0
#		load_next_question()
#		return
#	elif R.pass_between.episode_name == "demo":
#		# still debug for now
#		DEBUG = true
#		question_number = 6
#		episode_data = Loader.load_episode(R.pass_between.episode_name)
#		load_next_question()
#		return
	episode_data = R.pass_between.episode_data
	$Cutscenes/Round2.scale = Vector2(0, 1)
	call_deferred("play_intro")

func enable_skip():
	C.connect("gp_button", self, "_gp_button")
	$SkipButton.show()
	skippable = true
	skipped = false
	Ws.scene("enableSkip")

func disable_skip():
	$SkipButton.hide()
	C.disconnect("gp_button", self, "_gp_button")
	skippable = false
	skipped = true
	Ws.scene("disableSkip")

func _gp_button(player, button, pressed):
	print(R.players)
	# example
	# [{device:0, device_index:3, keyboard:0, name:Numpad, player_number:0, score:0, side:0}]
	print(player, " ", button, " ", pressed)
	if skippable:
		for p in R.players:
			if p.device_index == player:
				if button == 5 and pressed == true:
					disable_skip()
					S.stop_voice()
					S.play_sfx("skip")
					yield(get_tree().create_timer(0.5), "timeout")
					S.play_voice("skip")
					yield(S, "voice_end")
					end_intro()

func _back_button(player, button, pressed):
	if player != -1 and (button == 4 or button == 6) and pressed and question_number == 13 and intermission_played:
		_on_BackButton_back_pressed()

func _give_default_names(count, size):
	var chosen_names = []
	# now actually give names
	for i in range(count):
		var choice = R.rng.randi_range(0, size - 1)
		while choice in chosen_names:
			choice = R.rng.randi_range(0, size - 1)
		chosen_names.append(choice)
	return chosen_names

func play_intro():
	# in case I let players turn off Lifesavers in the future
	var lifesaver_left = false
	for p in R.players:
		if p.has_lifesaver:
			lifesaver_left = true
			break
	skipped = false
	# If anyone's name_type is 2, their name was censored.
	var names_used = []
	var default_players = []
	var censored_players = []
	var chosen_names = []
	for p in R.players:
		if p.name_type == 1: # default name
			default_players.append(p.player_number)
		if p.name_type == 2: # censored name
			censored_players.append(p.player_number)
			q_box.hud.set_player_name(p.player_number, "[CENSORED]")
		if p.device == C.DEVICES.REMOTE:
			remote_players.append(p.player_number)
	var names = Loader.random_dict.audio_episode["give_name"]
	chosen_names = _give_default_names(len(default_players) + len(censored_players), len(names))
	for i in default_players:
		R.players[i].name = names[chosen_names.pop_back()].name
		q_box.hud.set_player_name(i, R.players[i].name)
		if i in remote_players:
			Ws.send('message', {
				'to': R.players[i].device_name,
				'action': 'changeNick',
				'nick': R.players[i].name,
				'playerIndex': R.players[i].player_number,
				'isVip': false
			});
	# censored names will be given later
	# will be used later if cutscenes are on.
	var show_tech_diff: bool = false
	var voice_lines = [
		"welcome"
	]
	if episode_data.has("welcome_before") and episode_data.welcome_before != "default":
		show_tech_diff = true
		voice_lines.append_array(
			[
				"welcome_before",
				"welcome_standby"
			]
		)
	var player_voice
	var global_voice_lines = []
	if R.cfg.cutscenes:
		Ws.scene("intro")
		# preload the voice lines we need
		if lifesaver_left:
			voice_lines.append_array([
				"lifesaver",
				"lifesaver_tute0",
				"lifesaver_tute1",
				"lifesaver_tute2",
				"lifesaver_tute3"
			])
		match len(censored_players):
			0:
				match len(R.players):
					1:
						player_voice = "player_1"
						voice_lines.append("player_1")
					2:
						player_voice = "player_2"
						voice_lines.append("player_2")
					3:
						player_voice = "player_3"
						voice_lines.append("player_3")
					_:
						player_voice = "player_4"
						voice_lines.append("player_4")
			1:
				player_voice = "player_callout_%d" % censored_players[0]
				global_voice_lines.append(player_voice)
				global_voice_lines.append("name_censored")
				S.preload_ep_voice("give_name", names[chosen_names[0]].v, false, names[chosen_names[0]].s)
			2, 3:
				player_voice = "%d_player_callout" % len(censored_players)
				global_voice_lines.append(player_voice)
				global_voice_lines.append("multiple_names_censored")
				global_voice_lines.append("give_multiple_names")
			_:
				player_voice = "all_names_censored"
				global_voice_lines.append(player_voice)
				global_voice_lines.append("give_multiple_names")
	
		if episode_data.has("audio") == false:
			R.crash("Episode data is missing audio data.")
			return
		for key in voice_lines:
			# func preload_voice(key, filename, question_specific: bool = false, subtitle_string=""):
			#if episode_data.audio.has(key) == false:
			#	R.crash("Episode data is missing audio key: " + key + ".")
			#	return
			#if episode_data.audio[key].v == "default":
			if episode_data.audio.has(key) == false or episode_data.audio[key].v == "default":
				if episode_data.audio.has(key) == false:
					print("WARNING: Episode data has no key for audio: " + key + ". Treating as default.")
				var candidates = Loader.random_dict.audio_episode[key]
				var index = 0
				if len(candidates) == 0:
					printerr("No candidate lines for key: ", key)
					breakpoint
					# fallback
					S.preload_ep_voice(key, "wrong_00", false, "LINE ID %s NOT FOUND" % key)
				elif len(candidates) > 1:
					index = R.rng.randi_range(0, len(candidates) - 1)
				S.preload_ep_voice(key, candidates[index].v, false, candidates[index].s)
			else:
				S.preload_ep_voice(key, episode_data.audio[key].v, R.pass_between.episode_name, episode_data.audio[key].s)
		for key in global_voice_lines:
			# not episode specific, assume you meant to do it
			var candidates = Loader.random_dict.audio_episode[key]
			var index = 0
			if len(candidates) == 0:
				printerr("No candidate lines for key: ", key)
				breakpoint
				# fallback
				S.preload_ep_voice(key, "wrong_00", false, "LINE ID %s NOT FOUND" % key)
			elif len(candidates) > 1:
				index = R.rng.randi_range(0, len(candidates) - 1)
			S.preload_ep_voice(key, candidates[index].v, false, candidates[index].s)
		# non-random skip voice?
		if episode_data.audio.has("skip") == false or episode_data.audio["skip"].v == "default":
			var skip_index = R.rng.randi_range(0, len(Loader.random_dict.audio_question.skip) - 1)
			S.preload_voice(
				"skip",
				Loader.random_dict.audio_question.skip[skip_index].v,
				false,
				Loader.random_dict.audio_question.skip[skip_index].s
			)
		else:
			S.preload_ep_voice(
				"skip",
				episode_data.audio["skip"].v,
				R.pass_between.episode_name,
				episode_data.audio["skip"].s
			)
		yield(get_tree().create_timer(0.5), "timeout")
		# fake intro
		if show_tech_diff:
			S.play_music("new_theme", 1.0)
			c_box.play_intro(); yield(c_box, "animation_finished")
			S.play_track(0, 0.4)
			S.play_voice("welcome_before"); yield(S, "voice_end")
			# tech diff
			S.play_music("", 0.4) # stop music without tweening
			c_box.show_techdiff()
			S.play_voice("welcome_standby"); yield(S, "voice_end")
			c_box.hide_techdiff()
		
		# real intro
		S.play_music("new_theme", 1.0)
		c_box.play_intro(); yield(c_box, "animation_finished")
		S.play_track(0, 0.4)
		S.play_voice("welcome"); yield(S, "voice_end")
		
		c_box.lose_logo(); yield(c_box, "animation_finished")
	
		hud.slide_playerbar(true); yield(hud.get_node("Tween"), "tween_all_completed")
		yield(get_tree().create_timer(0.1), "timeout") # allow a bit of extra time for slide out
		
		S.play_voice(player_voice); yield(S, "voice_end")
	
	match len(censored_players):
		0:
			pass;
		1:
			if R.cfg.cutscenes:
				q_box.hud.highlight_players(censored_players)
				S.play_voice("name_censored"); yield(S, "voice_end")
			R.players[censored_players[0]].name = names[chosen_names[0]].name
			q_box.hud.set_player_name(censored_players[0], R.players[censored_players[0]].name, true)
			if censored_players[0] in remote_players:
				Ws.send('message', {
					'to': R.players[censored_players[0]].device_name,
					'action': 'changeNick',
					'nick': R.players[censored_players[0]].name,
					'playerIndex': R.players[censored_players[0]].player_number,
					'isVip': false
				});
			if R.cfg.cutscenes:
				S.play_voice("give_name"); yield(S, "voice_end")
				q_box.hud.reset_playerboxes(censored_players)
		2, 3:
			if R.cfg.cutscenes:
				q_box.hud.highlight_players(censored_players)
				S.play_voice("multiple_names_censored"); yield(S, "voice_end")
			# Generate sets of names
			var new_names = []
			if len(censored_players) == 2:
				new_names = [
					["Beavis", "Butthead"],
					["Chang", "Eng"],
					["Chip", "Dale"],
					["Dylan", "Cole"],
					["Left Brain", "Right Brain"],
					["Mary-Kate", "Ashley"],
					["Red Fish", "Blue Fish"],
					["Thing One", "Thing Two"],
					["Toby", "Lena"],
					["Tweedledum", "Tweedledee"],
					["Wario", "Waluigi"],
				]
			else:
				new_names = [
					["Alvin", "Simon", "Theodore"],
					["Billy", "Mandy", "Grim"],
					["Breakfast", "Lunch", "Dinner"],
					["Curly", "Larry", "Moe"],
					["Ed", "Edd", "Eddy"],
					["Jimmy", "Sheen", "Carl"],
					["Snap", "Crackle", "Pop"],
					["Timmy", "Cosmo", "Wanda"]
				]
			new_names = new_names[R.rng.randi_range(0, len(new_names) - 1)]
			for i in range(len(censored_players)):
				R.players[censored_players[i]].name = new_names[i]
				q_box.hud.set_player_name(censored_players[i], new_names[i], true)
				if censored_players[i] in remote_players:
					Ws.send('message', {
						'to': R.players[censored_players[i]].device_name,
						'action': 'changeNick',
						'nick': R.players[censored_players[i]].name,
						'playerIndex': R.players[censored_players[i]].player_number,
						'isVip': false
					});
			if R.cfg.cutscenes:
				S.play_voice("give_multiple_names"); yield(S, "voice_end")
				q_box.hud.reset_playerboxes(censored_players)
		_:
			for i in range(len(R.players)):
				R.players[i].name = "Number %d" % (i + 1)
				q_box.hud.set_player_name(i, R.players[i].name)
				if i in remote_players:
					Ws.send('message', {
						'to': R.players[i].device_name,
						'action': 'changeNick',
						'nick': R.players[i].name,
						'playerIndex': R.players[i].player_number,
						'isVip': false
					});
			q_box.hud.punish_players(range(len(R.players)), 500.01)
			if R.cfg.cutscenes:
				S.play_voice("give_multiple_names"); yield(S, "voice_end")
			q_box.hud.reset_all_playerboxes()
	
	if R.cfg.cutscenes:
		if lifesaver_left:
			enable_skip()
			c_box.show_lifesaver_logo()
			Ws.scene("lifesaver")
			S.play_voice("lifesaver"); yield(S, "voice_end")
			if skipped: return
			hud.give_lifesaver()
			c_box.lifesaver_tutorial(0)
			S.play_voice("lifesaver_tute0"); yield(S, "voice_end")
			if skipped: return
			c_box.lifesaver_tutorial(1)
			S.play_voice("lifesaver_tute1"); yield(S, "voice_end")
			if skipped: return
			c_box.lifesaver_tutorial(2)
			S.play_voice("lifesaver_tute2"); yield(S, "voice_end")
			if skipped: return
			S.play_voice("lifesaver_tute3"); yield(S, "voice_end")
			if skipped: return
			disable_skip()
		for k in voice_lines:
			S.unload_voice(k)
		for k in global_voice_lines:
			S.unload_voice(k)
		end_intro()
	else:
		load_next_question()

func play_intro_2():
	q_box.show_loading_logo(15)
	yield(q_box.anim, "animation_finished")
	
	q_box.hud.reset_all_playerboxes()
	var lifesaver_left = false
	for p in R.players:
		if p.has_lifesaver:
			lifesaver_left = true
			break
	intermission_played = true
	skipped = false
	Ws.scene("round2")
	var voice_lines = [
		"round2",
		"round2_tute"
	]
	if lifesaver_left:
		voice_lines.append_array([
			"lifesaver2",
			"lifesaver2_tute0",
			"lifesaver2_tute1"
		])
	for key in voice_lines:
		if episode_data.audio.has(key) == false or episode_data.audio[key].v == "default":
			var candidates = Loader.random_dict.audio_episode[key]
			var index = 0
			if len(candidates) == 0:
				printerr("No candidate lines for key: ", key)
				breakpoint
				# fallback
				S.preload_ep_voice(key, "wrong_00", false, "LINE ID %s NOT FOUND" % key)
			elif len(candidates) > 1:
				index = R.rng.randi_range(0, len(candidates) - 1)
			S.preload_ep_voice(key, candidates[index].v, false, candidates[index].s)
		else:
			S.preload_ep_voice(key, episode_data.audio[key].v, R.pass_between.episode_name, episode_data.audio[key].s)
	# non-random skip voice?
	if episode_data.audio.has("skip_round2") == false or episode_data.audio["skip_round2"].v == "default":
		var skip_index = R.rng.randi_range(0, len(Loader.random_dict.audio_question.skip) - 1)
		S.preload_voice(
			"skip",
			Loader.random_dict.audio_question.skip[skip_index].v,
			false,
			Loader.random_dict.audio_question.skip[skip_index].s
		)
	else:
		S.preload_ep_voice(
			"skip",
			episode_data.audio["skip_round2"].v,
			R.pass_between.episode_name,
			episode_data.audio["skip_round2"].s
		)
	
	q_box.anim.play("touchprism_leave")
	yield(q_box.anim, "animation_finished")
	q_box.set_process(false)
	
	S.play_music("new_theme", true)
	c_box.play_intro(); yield(c_box, "animation_finished")
	S.play_track(0, 0.4)
	S.play_voice("round2"); yield(S, "voice_end")
	
	c_box.round2_logo(false); yield(c_box, "animation_finished")
	S.play_voice("round2_tute"); yield(S, "voice_end")
	
	c_box.round2_logo(true); yield(get_tree().create_timer(0.5), "timeout")
	if lifesaver_left:
		enable_skip()
		hud.slide_playerbar(true)
		c_box.show_lifesaver_logo()
		Ws.scene("lifesaver")
		S.play_voice("lifesaver2"); yield(S, "voice_end")
		if skipped: return
		hud.give_lifesaver()
		S.play_voice("lifesaver2_tute0");
		c_box.lifesaver_tutorial(0); yield(c_box.anim, "animation_finished")
		c_box.lifesaver_tutorial(1)
		yield(S, "voice_end")
		if skipped: return
		S.play_voice("lifesaver2_tute1"); yield(S, "voice_end")
		if skipped: return
		disable_skip()
	for k in voice_lines:
		S.unload_voice(k)
	end_intro()

func end_intro():
	S.play_track(0, 0.0, false)
	S.play_sfx("question_leave")
	disable_skip()
	hud.slide_playerbar(false)
	c_box.tween.connect("tween_all_completed", q_box, "show_loading_logo", [], CONNECT_ONESHOT)
	c_box.close_bg()
	c_box.anim.play("end_intro"); yield(c_box, "animation_finished")
#	q_box.show_loading_logo()
	q_box.set_process(true)
	load_next_question()

func play_intermission():
	q_box.show_loading_logo(14)
	yield(q_box.anim, "animation_finished")
	# make this optional
#	if episode_data.audio.has("intermission") == false:
#		R.crash("Episode data is missing audio key: intermission.")
#		return
#	if episode_data.audio["intermission"].v == "default":

	if episode_data.audio.has("intermission") == false or episode_data.audio["intermission"].v == "default":
		var candidates = Loader.random_dict.audio_episode["intermission"]
		var index = 0
		if len(candidates) == 0:
			printerr("No candidate lines for key: intermission")
			breakpoint
			# fallback
			S.preload_ep_voice("intermission", "wrong_00", false, "LINE ID intermission NOT FOUND")
		elif len(candidates) > 1:
			index = R.rng.randi_range(0, len(candidates) - 1)
		S.preload_ep_voice("intermission", candidates[index].v, false, candidates[index].s)
	else:
		S.preload_ep_voice("intermission", episode_data.audio["intermission"].v, R.pass_between.episode_name, episode_data.audio["intermission"].s)
	
	c_box.set_process(true)
	q_box.anim.play("touchprism_leave")
	yield(q_box.anim, "animation_finished")
	q_box.set_process(false)
	
	S.play_sfx("leaderboard_show")
	c_box.show_leaderboard()
	S.play_music("main_theme", 1)
	yield(get_tree().create_timer(1.5), "timeout")
	S.play_track(0, 0.5)
	S.play_voice("intermission"); yield(S, "voice_end")
	S.play_sfx("question_leave")
	c_box.hide_leaderboard()
	c_box.close_bg()
	S.play_track(0, 0)
	yield(get_tree().create_timer(0.5), "timeout")
	intermission_played = true
	play_intro_2()

func load_next_question():
	print("Loading next question. Question number is ", str(question_number), " and intermission played is ", str(intermission_played))
	if question_number == 6 and R.cfg.cutscenes and intermission_played == false:
		play_intermission()
		#load_question(episode_data.question_id[question_number])
	elif question_number == 13:
		q_box.set_process(false)
		c_box.set_process(true)
		play_outro()
	else:
		intermission_played = false
		load_question(episode_data.question_id[question_number])

func load_question(q_name):
	c_box.set_process(false)
	q_box.question_number = question_number
	q_box.data = Loader.load_question(q_name, question_number == 0)
	question_number += 1
	q_box.call_deferred("show_loading_logo")
	yield(get_tree().create_timer(0.1), "timeout")
	q_box.call_deferred("change_stage", "init")

func too_many_pauses():
	# freeze frame effect
	var txr: ImageTexture = ImageTexture.new()
	# Let frames pass to make sure the screen was captured.
#	yield(get_tree(), "idle_frame")
	# Retrieve the captured image.
	var screenshot: Image = get_viewport().get_texture().get_data()
	txr.create_from_image(screenshot, 0)
	$Screen.set_texture(txr)
#	$Screen.show()
	
	S.play_music("", 0)
	S.stop_voice()
	q_box.queue_free()
	yield(get_tree().create_timer(0.5), "timeout")
	#S.play_voice("")
	disqualified()

func disqualified():
	Ws.close_room()
	Loader.load_random_voice_line("too_many_pauses", "", true)
	S.play_voice("too_many_pauses")
	yield(S, "voice_end")
	$Shutter.set_texture(load("res://images/shutter.png"))
	$Shutter/AnimationPlayer.play("disqualified")
	S.play_sfx("dq")
	yield($Shutter/AnimationPlayer, "animation_finished")
	get_tree().change_scene("res://Title.tscn")

func play_outro():
	$Pause.hide()
	c_box.set_radius(0)
	intermission_played = false
	S.preload_music("drum_roll")
	# use the same index for both lines
	if episode_data.audio.has("outro_game") == false or episode_data.audio["outro_game"].v == "default":
		var candidates = Loader.random_dict.audio_episode["outro_game"]
		var candidates_slam = Loader.random_dict.audio_episode["outro_slam"]
		var index = 0
		if len(candidates) == 0:
			R.crash("No candidate lines for key: " + "outro_game")
		elif len(candidates_slam) == 0:
			R.crash("No candidate lines for key: " + "outro_slam")
		elif len(candidates) > 1:
			index = R.rng.randi_range(0, len(candidates) - 1)
		S.preload_ep_voice("outro_game", candidates[index].v, false, candidates[index].s)
		S.preload_ep_voice("outro_slam", candidates_slam[index].v, false, candidates_slam[index].s)
	else:
		S.preload_ep_voice("outro_game", episode_data.audio["outro_game"].v, R.pass_between.episode_name, episode_data.audio["outro_game"].s)
		S.preload_ep_voice("outro_slam", episode_data.audio["outro_slam"].v, R.pass_between.episode_name, episode_data.audio["outro_slam"].s)
	
	c_box.show_final_leaderboard();
	S.play_music("drum_roll", true)
	q_box.hide()
	yield(c_box.anim, "animation_finished")
	S.play_music("new_theme", true)
	yield(get_tree().create_timer(3.5), "timeout")
	S.play_track(0, 0.4)
	yield(get_tree().create_timer(0.5), "timeout")
	S.play_voice("outro_game"); yield(S, "voice_end")
	S.play_music("", 0)
	c_box.hide_final_leaderboard()
	S.play_voice("outro_slam"); yield(S, "voice_end")
	yield(get_tree().create_timer(1.0), "timeout")
	c_box.roll_credits()
	C.connect("gp_button", self, "_back_button")
	intermission_played = true

func set_pause_penalty(truthy: bool):
	penalize_pausing = truthy

func _on_SkipButton_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.pressed:
			print("Skip button clicked")
			C.inject_button(4, 5, true)

func _on_BackButton_back_pressed():
	intermission_played = false
	S.play_track(0, 0)
	S.play_sfx("menu_back")
	c_box.tween.interpolate_property(
		c_box, "rect_scale", 1.0, 1.2, 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT
	)
	c_box.tween.interpolate_property(
		c_box, "modulate", Color.white, Color.black, 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT
	)
	c_box.tween.start()
	yield(c_box.tween, "tween_all_completed")
	Ws.close_room()
	Ws._disconnect()
	get_tree().change_scene("res://Title.tscn")

func _on_credits_link_clicked(meta):
	OS.shell_open(meta)
