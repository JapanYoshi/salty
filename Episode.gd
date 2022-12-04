extends ColorRect

onready var q_box = $ScreenStretch/Standard
onready var c_box = $ScreenStretch/Cutscenes
onready var hud = $ScreenStretch/HUD
onready var skip_btn = $ScreenStretch/SkipButton
var episode_data = {}
var question_number = 0
var intermission_played = false
var skippable = false
var skipped = false
var DEBUG = false
# make a list of players using phones-as-controllers
var remote_players = []
var penalize_pausing = false

var scene_history = []

# Called when the node enters the scene tree for the first time.
func _ready():
	q_box.ep = self
	q_box.kb = $ScreenStretch/TypingHandler
	q_box.set_process(false)
	if R.cfg.cutscenes:
		c_box.show()
	else:
		c_box.hide()
	S.play_sfx("blank")
	$ScreenStretch/Shutter/AnimationPlayer.stop()
	skip_btn.hide()
	$ScreenStretch/BackButton.hide()
#	c_box.backdrop.modulate = Color.black
#	c_box.vignette.modulate = Color.white
	c_box.get_node("TechDiff").hide()
	c_box.get_node("Final").hide()
	q_box.connect("question_done", self, "load_next_question")
	q_box.hud = hud
	question_number = 0
	episode_data = R.pass_between.episode_data
#	if not R.pass_between.has("episode_name"):
##		# we're debugging
#		DEBUG = true
#		R.pass_between.episode_name = "demo"
#		question_number = 12
#		episode_data = Loader.load_episode(R.pass_between.episode_name)
#		load_next_question()
#		return
#	elif R.pass_between.episode_name == "demo":
#		# still debug for now
#		DEBUG = true
#		question_number = 12
#		load_next_question()
#		return
	c_box.get_node("Round2").scale = Vector2(0, 1)
	for i in range(len(R.players)):
		if R.players[i].device == C.DEVICES.TOUCHSCREEN:
			$PauseButton.show()
			break
	call_deferred("play_intro")

func enable_skip():
	C.connect("gp_button", self, "_gp_button")
	skip_btn.show()
	skippable = true
	skipped = false
#	Ws.scene("enableSkip")
	send_scene("enableSkip")

func disable_skip():
	skip_btn.hide()
	C.disconnect("gp_button", self, "_gp_button")
	skippable = false
	skipped = true
#	Ws.scene("disableSkip")
	revert_scene("enableSkip")
	send_scene("disableSkip")

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
	# Fade the music that has been playing since the signup screen.
	# (Takes 0.5 seconds.)
	S.play_track(0, 0)
	S.play_track(1, 0)
	S.play_track(2, 0)
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
	var special_guest: int = (
		# -1 is sentinel for "none yet",
		# -2 for "this episode can't do that"
		-2 if (
			!episode_data.has("no_special_guest")
			or episode_data.no_special_guest == false
		) else -1
	)
	var special_guest_id: String = ""
	for p in R.players:
		if p.name_type == 1: # default name
			default_players.append(p.player_number)
		elif p.name_type == 2: # censored name
			censored_players.append(p.player_number)
#			q_box.hud.set_player_name(p.player_number, "[CENSORED]")
		elif special_guest == -1:
			var guest_id_or_empty_string = Loader.guest_id_or_empty_string(p.name)
			if !guest_id_or_empty_string.empty():
				special_guest = p.player_number
				special_guest_id = guest_id_or_empty_string
		if p.device == C.DEVICES.REMOTE:
			remote_players.append(p.player_number)
	var names = Loader.random_dict.audio_episode["give_name"]
	chosen_names = _give_default_names(len(default_players) + len(censored_players), len(names))
	for i in default_players:
		R.players[i].name = names[chosen_names.pop_back()].name
		q_box.hud.set_player_name(i, R.players[i].name)
		if i in remote_players:
			Fb.change_nick(R.players[i].device_name, R.players[i].name)
#			Ws.send('message', {
#				'to': R.players[i].device_name,
#				'action': 'changeNick',
#				'nick': R.players[i].name,
#				'playerIndex': R.players[i].player_number,
#				'isVip': false
#			});
	# censored names will be given later
	# will be used later if cutscenes are on.
	var show_tech_diff: bool = false
	var voice_lines = [
		"welcome"
	]
	if R.cfg.cutscenes and episode_data.audio.has("welcome_before") and episode_data.audio.welcome_before.v != "default":
		show_tech_diff = true
		voice_lines.append_array(
			[
				"welcome_before",
				"welcome_standby"
			]
		)
	var player_voice
	var global_voice_lines = []
	# Wait for the volume to fade to -80.0 (zero)
	while S.music_dict[S.tracks[0]].get_volume_db() > -80.0:
#		print("Episode.gd waiting for the volume to fade: ", S.music_dict[S.tracks[0]].get_volume_db())
		yield(get_tree(), "idle_frame")
	if R.cfg.cutscenes:
#		Ws.scene("intro")
		send_scene("intro")
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
				if special_guest >= 0:
					# special guest easter egg lines
					player_voice = "special_guest"
					yield(
						S.preload_guest_voice(special_guest_id),
						"completed"
					)
				else:
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
				yield(
					S.preload_ep_voice(
						"give_name", names[chosen_names[0]].v, false, names[chosen_names[0]].s
					), "completed"
				)
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
			R.crash("Episode data is missing the section `audio`. Malformed episode data?")
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
					yield(
						S.preload_ep_voice(
							key, "wrong_00", false, "LINE ID %s NOT FOUND" % key
						), "completed"
					)
				elif len(candidates) > 1:
					index = R.rng.randi_range(0, len(candidates) - 1)
				yield(
					S.preload_ep_voice(
						key, candidates[index].v, false, candidates[index].s
					), "completed"
				)
			else:
				yield(
					S.preload_ep_voice(
						key, episode_data.audio[key].v, R.pass_between.episode_name, episode_data.audio[key].s
					), "completed"
				)
		for key in global_voice_lines:
			# not episode specific, assume you meant to do it
			var candidates = Loader.random_dict.audio_episode[key]
			var index = 0
			if len(candidates) == 0:
				printerr("No candidate lines for key: ", key)
				breakpoint
				# fallback
				yield(
					S.preload_ep_voice(
						key, "wrong_00", false, "LINE ID %s NOT FOUND" % key
					), "completed"
				)
			elif len(candidates) > 1:
				index = R.rng.randi_range(0, len(candidates) - 1)
			yield(
				S.preload_ep_voice(
					key, candidates[index].v, false, candidates[index].s
				), "completed"
			)
		# non-random skip voice?
		if episode_data.audio.has("skip") == false or episode_data.audio["skip"].v == "default":
			var skip_index = R.rng.randi_range(0, len(Loader.random_dict.audio_question.skip) - 1)
			yield(S.preload_voice(
				"skip",
				Loader.random_dict.audio_question.skip[skip_index].v,
				false,
				Loader.random_dict.audio_question.skip[skip_index].s
			), "completed")
		else:
			yield(S.preload_ep_voice(
				"skip",
				episode_data.audio["skip"].v,
				R.pass_between.episode_name,
				episode_data.audio["skip"].s
			), "completed")
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
		
		# If there are censored players, it calls out the player(s) who got censored
		# If there are special guests, this does not play
		# Otherwise, it plays a player count quip
		if special_guest < 0:
			S.play_voice(player_voice); yield(S, "voice_end")
		else:
			if R.cfg.cutscenes:
				q_box.hub.highlight_players(special_guest)
				S.play_sfx("option_highlight")
				yield(get_tree().create_timer(0.5), "timeout")
				S.play_voice("special_guest"); yield(S, "voice_end")
				q_box.hud.reset_playerboxes(special_guest)
				S.unload_voice("special_guest")
	match len(censored_players):
		0: # we deal with "more than 3" later
			pass;
		1:
			if R.cfg.cutscenes:
				q_box.hud.highlight_players(censored_players)
				S.play_sfx("option_highlight")
				yield(get_tree().create_timer(0.5), "timeout")
				S.play_voice("name_censored"); yield(S, "voice_end")
			R.players[censored_players[0]].name = names[chosen_names[0]].name
			q_box.hud.set_player_name(censored_players[0], R.players[censored_players[0]].name, true)
#			if censored_players[0] in remote_players:
#				Ws.send('message', {
#					'to': R.players[censored_players[0]].device_name,
#					'action': 'changeNick',
#					'nick': R.players[censored_players[0]].name,
#					'playerIndex': R.players[censored_players[0]].player_number,
#					'isVip': false
#				});
			if R.cfg.cutscenes:
				S.play_sfx("name_change")
				yield(get_tree().create_timer(0.5), "timeout")
				q_box.hud.reset_playerboxes(censored_players)
				S.play_voice("give_name"); yield(S, "voice_end")
		2, 3:
			if R.cfg.cutscenes:
				q_box.hud.highlight_players(censored_players)
				S.play_sfx("option_highlight")
				yield(get_tree().create_timer(0.5), "timeout")
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
#				if censored_players[i] in remote_players:
#					Ws.send('message', {
#						'to': R.players[censored_players[i]].device_name,
#						'action': 'changeNick',
#						'nick': R.players[censored_players[i]].name,
#						'playerIndex': R.players[censored_players[i]].player_number,
#						'isVip': false
#					});
			if R.cfg.cutscenes:
				S.play_sfx("name_change")
				yield(get_tree().create_timer(0.5), "timeout")
				S.play_voice("give_multiple_names"); yield(S, "voice_end")
				q_box.hud.reset_playerboxes(censored_players)
		_:
			for i in range(len(R.players)):
				R.players[i].name = "Number %d" % (i + 1)
				q_box.hud.set_player_name(i, R.players[i].name)
#				if i in remote_players:
#					Ws.send('message', {
#						'to': R.players[i].device_name,
#						'action': 'changeNick',
#						'nick': R.players[i].name,
#						'playerIndex': R.players[i].player_number,
#						'isVip': false
#					});
			q_box.hud.punish_players(range(len(R.players)), 50001)
			if R.cfg.cutscenes:
				S.play_sfx("naughty")
				yield(get_tree().create_timer(1.0), "timeout")
				S.play_voice("give_multiple_names"); yield(S, "voice_end")
			q_box.hud.reset_all_playerboxes()
	
	if R.cfg.cutscenes:
		if lifesaver_left:
			send_scene("lifesaver")
			enable_skip()
			c_box.show_lifesaver_logo()
#			Ws.scene("lifesaver")
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
	c_box.hide()
	q_box.show_loading_logo(15)
	
	q_box.hud.reset_all_playerboxes()
	var lifesaver_left = false
	for p in R.players:
		if p.has_lifesaver:
			lifesaver_left = true
			break
	intermission_played = true
	skipped = false
#	Ws.scene("round2")
	send_scene("round2")
	var voice_lines = [
		"round2",
		"round2_tute"
	]
	if lifesaver_left:
		voice_lines.append_array([
			"lifesaver2",
			"lifesaver2_tute0",
			"lifesaver2_tute1",
			"lifesaver2_tute2"
		])
	for key in voice_lines:
		if episode_data.audio.has(key) == false or episode_data.audio[key].v == "default":
			var candidates = Loader.random_dict.audio_episode[key]
			var index = 0
			if len(candidates) == 0:
				printerr("No candidate lines for key: ", key)
				breakpoint
				# fallback
				S.call_deferred("preload_ep_voice",
					key, "wrong_00", false, "LINE ID %s NOT FOUND" % key
				)
				yield(S, "voice_preloaded")
			elif len(candidates) > 1:
				index = R.rng.randi_range(0, len(candidates) - 1)
			S.call_deferred("preload_ep_voice",
				key, candidates[index].v, false, candidates[index].s
			)
			yield(S, "voice_preloaded")
		else:
			S.call_deferred("preload_ep_voice",
				key, episode_data.audio[key].v, R.pass_between.episode_name, episode_data.audio[key].s
			)
			yield(S, "voice_preloaded")
	# non-random skip voice?
	if episode_data.audio.has("skip_round2") == false or episode_data.audio["skip_round2"].v == "default":
		var skip_index = R.rng.randi_range(0, len(Loader.random_dict.audio_question.skip) - 1)
		S.call_deferred("preload_ep_voice",
			"skip",
			Loader.random_dict.audio_question.skip[skip_index].v,
			false,
			Loader.random_dict.audio_question.skip[skip_index].s
		)
		yield(S, "voice_preloaded")
	else:
		S.call_deferred("preload_ep_voice",
			"skip",
			episode_data.audio["skip_round2"].v,
			R.pass_between.episode_name,
			episode_data.audio["skip_round2"].s
		)
		yield(S, "voice_preloaded")
	
	if q_box.anim.is_playing():
		yield(q_box.anim, "animation_finished")
	q_box.finish_loading_screen()
	yield(q_box.anim, "animation_finished")
	q_box.set_process(false)
	
	c_box.show()
	S.play_music("new_theme", true)
	c_box.play_intro(); yield(c_box, "animation_finished")
	S.play_track(0, 0.4)
	S.play_voice("round2"); yield(S, "voice_end")
	
	c_box.round2_logo(false); yield(c_box, "animation_finished")
	S.play_voice("round2_tute"); yield(S, "voice_end")
	
	c_box.round2_logo(true); yield(get_tree().create_timer(0.5), "timeout")
	if lifesaver_left:
#		Ws.scene("lifesaver")
		send_scene("lifesaver2")
		enable_skip()
		hud.slide_playerbar(true)
		c_box.show_lifesaver_logo()
		S.play_voice("lifesaver2"); yield(S, "voice_end")
		if skipped: return
		hud.give_lifesaver()
		c_box.lifesaver_tutorial(3)
		#yield(c_box.anim, "animation_finished")
		S.play_voice("lifesaver2_tute0");
		yield(S, "voice_end")
		if skipped: return
		c_box.lifesaver_tutorial(4)
		S.play_voice("lifesaver2_tute1"); yield(S, "voice_end")
		if skipped: return
		c_box.lifesaver_tutorial(5)
		S.play_voice("lifesaver2_tute2"); yield(S, "voice_end")
		if skipped: return
		disable_skip()
	for k in voice_lines:
		S.unload_voice(k)
	end_intro()

func end_intro():
	S.play_track(0, 0.0, false)
	S.play_sfx("question_leave")
#	disable_skip()
	hud.slide_playerbar(false)
#	c_box.tween.connect("tween_all_completed", q_box, "show_loading_logo", [], CONNECT_ONESHOT)
	c_box.close_bg()
	if c_box.anim.current_animation != "end_intro":
		c_box.anim.play("end_intro"); yield(c_box, "animation_finished")
	#q_box.set_process(true)
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
			S.call_deferred("preload_ep_voice",
				"intermission", "wrong_00", false, "LINE ID intermission NOT FOUND"
			)
			yield(S, "voice_preloaded")
		elif len(candidates) > 1:
			index = R.rng.randi_range(0, len(candidates) - 1)
		S.call_deferred("preload_ep_voice",
			"intermission", candidates[index].v, false, candidates[index].s
		)
		yield(S, "voice_preloaded")
	else:
		S.call_deferred("preload_ep_voice",
			"intermission", episode_data.audio["intermission"].v, R.pass_between.episode_name, episode_data.audio["intermission"].s
		)
		yield(S, "voice_preloaded")
	
	c_box.set_process(true)
	q_box.finish_loading_screen()
	yield(q_box.anim, "animation_finished")
	q_box.set_process(false)
	c_box.show()
	
	S.play_sfx("leaderboard_show")
	c_box.show_leaderboard()
	S.play_music("house", 1)
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
	revert_scene("")
	send_scene()
	print("Loading next question. Question number is ", str(question_number), " and intermission played is ", str(intermission_played))
	if question_number == 6 and R.cfg.cutscenes and intermission_played == false:
		intermission_played = true
		play_intermission()
		#load_question(episode_data.question_id[question_number])
	elif question_number == 13:
		q_box.set_process(false)
		c_box.show()
		c_box.set_process(true)
		play_outro()
	else:
		intermission_played = false
		load_question(episode_data.question_id[question_number])

func load_question(q_name):
	c_box.set_process(false)
	c_box.hide()
	
	q_box.question_number = question_number
	q_box.show_loading_logo(question_number + 1)
	yield(q_box.anim, "animation_finished")
	S.unload_all_voices()
	Loader.call_deferred("load_question",
		q_name, question_number == 0, q_box
	)
	yield(Loader, "loaded")
#	print("Q_BOX.DATA SHOULD NOW BE THE DICTIONARY ", q_box.data)
	question_number += 1
	q_box.call_deferred("change_stage", "init")

func too_many_pauses():
	# freeze frame effect
	var txr: ImageTexture = ImageTexture.new()
	# stop the music and voice to get rid of the subtitles if visible
	S.play_music("", 0)
	S.stop_voice()
	S.sub_node.clear_contents()
	
	yield(get_tree().create_timer(0.1), "timeout")
	# Retrieve the captured image.
	var screenshot: Image = get_viewport().get_texture().get_data()
	txr.create_from_image(screenshot, 0)
	$ScreenBehindShutter.set_texture(txr)
	$ScreenBehindShutter.show()
	q_box.free()
	c_box.hide()
	yield(get_tree().create_timer(0.1), "timeout")
	#S.play_voice("")
	disqualified()

func disqualified():
#	Ws.close_room()
	yield(
		Loader.load_random_voice_line("too_many_pauses", "", true),
		"completed"
	)
	S.play_voice("too_many_pauses")
	yield(S, "voice_end")
	shutter()

func shutter():
	$ScreenStretch/Shutter.set_texture(load("res://images/shutter.png"))
	$ScreenStretch/Shutter/AnimationPlayer.play("disqualified")
	S.play_sfx("dq")
	yield($ScreenStretch/Shutter/AnimationPlayer, "animation_finished")
#	Ws._disconnect()
	get_tree().change_scene("res://Title.tscn")

func play_outro():
	$Pause.set_process(false) 
	$PauseButton.hide()
	revert_scene("")
	send_scene("gameEnd")
	c_box.show()
	c_box.set_radius(0)
#	intermission_played = false
	S.preload_music("drum_roll")
	if R.cfg.cutscenes:
		_load_outro_cutscene()
	else:
		_outro_cutscene_0()

func _load_outro_cutscene():
	# use the same index for both lines
	var outro_game_v: String
	var outro_game_s: String
	var outro_slam_v: String
	var outro_slam_s: String
	var use_episode_voice: bool
	if episode_data.audio.has("outro_game") == false or episode_data.audio["outro_game"].v == "default":
		var candidates = Loader.random_dict.audio_episode["outro_game"]
		var candidates_slam = Loader.random_dict.audio_episode["outro_slam"]
		var index = 0
		if candidates.empty() == 0 or candidates_slam.empty() == 0:
			R.crash("There are no random game outro lines! Please check `random_voicelines.json` to see if `outro_game` and `outro_slam` are filled up correctly.")
		elif len(candidates) != len(candidates_slam):
			R.crash("The number of random `outro_game` and `outro_slam` lines in `random_voicelines.json` are different: " + str(len(candidates)) + " vs. " + str(len(candidates_slam)) + ".")
		elif len(candidates) > 1:
			index = R.rng.randi_range(0, len(candidates) - 1)\
		# complications arose from preloading too fast
		outro_game_v = candidates[index].v
		outro_game_s = candidates[index].s
		outro_slam_v = candidates_slam[index].v
		outro_slam_s = candidates_slam[index].s
		use_episode_voice = false
#		S.preload_ep_voice("outro_game", candidates[index].v, false, candidates[index].s)
#		yield(S, "voice_preloaded")
#		S.preload_ep_voice("outro_slam", candidates_slam[index].v, false, candidates_slam[index].s)
#		yield(S, "voice_preloaded")
	else:
		outro_game_v = episode_data.audio["outro_game"].v
		outro_game_s = episode_data.audio["outro_game"].s
		outro_slam_v = episode_data.audio["outro_slam"].v
		outro_slam_s = episode_data.audio["outro_slam"].s
		use_episode_voice = true
#		S.preload_ep_voice("outro_game", episode_data.audio["outro_game"].v, R.pass_between.episode_name, episode_data.audio["outro_game"].s)
#		yield(S, "voice_preloaded")
#		S.preload_ep_voice("outro_slam", episode_data.audio["outro_slam"].v, R.pass_between.episode_name, episode_data.audio["outro_slam"].s)
#		yield(S, "voice_preloaded")
	S.connect("voice_preloaded", self, "_on_outro_voice_load_1", [outro_slam_v, outro_slam_s, use_episode_voice], CONNECT_ONESHOT)
	S.preload_ep_voice(
		"outro_game", outro_game_v,
		R.pass_between.episode_name if use_episode_voice else false,
		outro_game_s
	)
	return

# ignore the result and assume it succeeded
func _on_outro_voice_load_1(_result: int, v2: String, s2: String, episode):
	print("_on_outro_voice_load_1")
	S.disconnect("voice_preloaded", self, "_on_outro_voice_load_1") # but, but it's fucking CONNECT_ONESHOT
	S.connect("voice_preloaded", self, "_on_outro_voice_load_2", [], CONNECT_ONESHOT)
	S.preload_ep_voice(
		"outro_slam", v2,
		R.pass_between.episode_name if episode else false,
		s2
	)
	return
	
# ignore the result and assume it succeeded
func _on_outro_voice_load_2(_result: int):
	print("_on_outro_voice_load_2")
	_outro_cutscene_0()

# called whether or not cutscenes are enabled
func _outro_cutscene_0():
	hud.rc_box.hide()
	c_box.show_final_leaderboard()
	S.play_music("drum_roll", true)
	q_box.hide()
	yield(get_tree().create_timer(5.0), "timeout")
	send_scene("showResult")
	yield(c_box.anim, "animation_finished")
	if R.cfg.cutscenes:
		_outro_cutscene_1()
	else:
		c_box.tween.interpolate_property(
			c_box.get_node("Final"),
			"modulate:a",
			1.0, 0.0, 0.5,
			Tween.TRANS_CUBIC, Tween.EASE_IN_OUT,
			2.5
		)
		c_box.tween.interpolate_property(
			c_box.get_node("Final"),
			"modulate:a",
			0.0, 0.0, 0.5,
			Tween.TRANS_CUBIC, Tween.EASE_IN_OUT,
			3.0
		)
		c_box.tween.start()
		yield(c_box.tween, "tween_all_completed")
		c_box.hide_final_leaderboard()
		_outro_cutscene_2()

func _outro_cutscene_1():
	S.play_music("new_theme", true)
	yield(get_tree().create_timer(3.5), "timeout")
	S.play_track(0, 0.4)
	yield(get_tree().create_timer(0.5), "timeout")
	S.play_voice("outro_game"); yield(S, "voice_end")
	S.play_music("", 0)
	c_box.hide_final_leaderboard()
	S.play_voice("outro_slam"); yield(S, "voice_end")
	yield(get_tree().create_timer(1.0), "timeout")
	_outro_cutscene_2()

func _outro_cutscene_2():
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
#	Ws.close_room()
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
#	Ws._disconnect()
	get_tree().change_scene("res://Title.tscn")

func _on_credits_link_clicked(meta):
	OS.shell_open(meta)

# Keeps a log of scenes sent, in case someone has to reconnect.
func send_scene(name: String = "", scene_data = {}):
	if name == "":
		# Just send the current backlog with no additions
		Fb.scene(scene_history)
#		print("resent scene history")
		return
#	Ws.scene(name, scene_data)
	#scene_data.action = "changeScene"
	scene_data.sceneName = name
	# The client can keep track of which events are new
	# Avoid timestamp collision
	var last_time = scene_history.back().time if len(scene_history) else 0
	var now_time = Time.get_ticks_usec()
	scene_data.time = now_time + (1 if last_time == now_time else 0)
	# Add the new scene to the backlog
	scene_history.push_back(scene_data)
	# Send the whole backlog to the room
	Fb.scene(scene_history)
#	print("sent scene history:", scene_history)
	return

# Pops the latest scene packets until the sceneName matches the `until` param.
# If it's '' or there's no match, the whole scene log is deleted.
func revert_scene(until: String):
	if until == "":
		# Just clear the whole backlog regardless
		scene_history.clear()
		return
	while len(scene_history):
		# Pop the backlog one scene at a time until we find the one
		# we should stop at (or we clear out the whole history)
		var back = scene_history.pop_back()
		if back.sceneName == until:
#			print("reverted scene history:", scene_history)
			return
#	print("Cleared all scene events")


func _on_PauseButton_pressed():
	C.inject_button(4, 6, true)
