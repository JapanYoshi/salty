extends Control

onready var current_page = $Episodes
var first_page = preload("res://Episodes.tscn")
var signup = preload("res://signup.tscn")
onready var tween = $Tween
onready var click_mask = $ClickMask
var question_pack_is_downloaded = false
var waiting_for_game_start = false
var cancel_loading = false
const QPACK_NAME = "user://question_pack.pck"

signal next_question_please

# Called when the node enters the scene tree for the first time.
func _ready():
	click_mask.hide()
	S.play_multitrack("signup_base", 1, "signup_extra", 0, "signup_extra2", 0)
	S.seek_multitrack(S.music_dict.signup_base.get_playback_position())
	pass # Replace with function body.

func back():
	if tween.is_active():
		print("Tween is still active, can't go back")
		return
	S.play_sfx("menu_back")
	if current_page.name == "Episodes":
		S.play_track(0, 0)
		S.play_track(1, 0)
		S.play_track(2, 0)
		tween.interpolate_property(self, "modulate", Color.white, Color.black, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
		tween.start()
		Ws._disconnect()
		yield(get_tree().create_timer(0.5), "timeout")
		get_tree().change_scene("res://Title.tscn")
	else:
		cancel_loading = true
		change_scene_to(first_page.instance())

func change_scene_to(n):
	click_mask.show()
	S.seek_multitrack(S.music_dict.signup_base.get_playback_position())
	S.play_track(0, 1)
	S.play_track(1, 0)
	S.play_track(2, 0)
	current_page.rect_pivot_offset = Vector2(640,360)
	tween.interpolate_property(current_page, "modulate", Color.white, Color.transparent, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.interpolate_property(current_page, "rect_scale", Vector2.ONE, Vector2.ONE * 1.2, 0.5)
	tween.start()
	yield(get_tree().create_timer(0.5), "timeout")
	current_page.queue_free()
	current_page = n
	add_child(current_page, true)
	move_child(current_page, 1)
	click_mask.hide()

const QUESTION_COUNT = 13
var time_start = -1
var load_start = -1
const RAND_PREFIX = "RNG_"

func load_episode(ep):
	change_scene_to(signup.instance())
	cancel_loading = false
	# get question list
	R.pass_between.episode_data = Loader.episodes[ep].duplicate(true)
	var q_id = R.pass_between.episode_data.question_id
	var randoms = 0
	var question_types = {
		"n": 0, "s": 0, "c": 0, "t": 0, "g": 0, "l": 0, "r": 0
	}
	if q_id[QUESTION_COUNT-1] == "":
		# randomize final question
		var which_finale = "lr"[R.rng.randi_range(0, 1)]
		question_types[which_finale] += 1
		q_id[QUESTION_COUNT-1] = Loader.random_questions_of_type(which_finale, 1)[0]
	
	for i in range(QUESTION_COUNT - 1):
		if q_id[i].begins_with(RAND_PREFIX):
			randoms += 1
			q_id[i] = q_id[i].trim_prefix(RAND_PREFIX)
		else:
			question_types[q_id[i][0]] += 1
	
	if randoms > 0:
		var search_order = range(0, QUESTION_COUNT-1)
		search_order.shuffle()
		# * exactly 1 of the following: thousand question question, gibberish
		if question_types["t"] == 0 and question_types["g"] == 0:
			var which_special = "t" if (R.rng.randi_range(0, 7) == 0) else "g"
			for i in range(len(search_order)):
				var q = search_order[i]
				if which_special in q_id[q]:
					q_id[q] = Loader.random_questions_of_type(which_special, 1)[0]
					question_types[which_special] += 1
					search_order.remove(i)
					break
		# * exactly 1 sorta kinda question per game
		if question_types["s"] == 0:
			for i in range(len(search_order)):
				var q = search_order[i]
				if "s" in q_id[q]:
					q_id[q] = Loader.random_questions_of_type("s", 1)[0]
					search_order.remove(i)
					break
		# * exactly 1 candy trivia question per game
		if question_types["c"] == 0:
			for i in range(len(search_order)):
				var q = search_order[i]
				if "c" in q_id[q]:
					q_id[q] = Loader.random_questions_of_type("c", 1)[0]
					search_order.remove(i)
					break
		# * rest are all Shorties
		var shorties = Loader.random_questions_of_type("n", len(search_order))
		for i in range(len(search_order)):
			var q = search_order[i]
			q_id[q] = shorties[i]
		print(q_id)
		R.pass_between.episode_data.question_id = q_id
	time_start = OS.get_ticks_msec()
	load_start = 0
	question_pack_is_downloaded = false
	for q in range(QUESTION_COUNT):
		async_load_question(q_id[q])
		yield(self, "next_question_please")
		if cancel_loading:
			return
		_update_loading_progress(q+1)
	question_pack_is_downloaded = true
	if waiting_for_game_start:
		start_game()

func start_game():
	if !question_pack_is_downloaded:
		waiting_for_game_start = true
		current_page.get_node("MouseMask").color = Color(0, 0, 0, 0.5)
		current_page.get_node("LoadingPanel").show()
		return
	S.play_track(0, false, false)
	S.play_track(1, false, false)
	S.play_track(2, false, false)
	self.rect_pivot_offset = Vector2(640,360)
	tween.interpolate_property(self, "modulate", Color.white, Color.black, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.interpolate_property(self, "rect_scale", Vector2.ONE, Vector2.ONE * 1.1, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.interpolate_property(current_page.get_node("LoadingPanel"), "rect_scale", Vector2.ONE, Vector2.ONE * 1.25, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	get_tree().change_scene("res://Episode.tscn")

onready var http_request = $HTTPRequest

func async_load_question(q):
	print("async_load_question(%s)" % q)
	var url = "https://haitouch.ga/me/salty/%s.pck" % q
	# Create an HTTP request node and connect its completion signal.
	http_request.download_file = QPACK_NAME
	http_request.download_chunk_size = 262144
	http_request.connect("request_completed", self, "_http_request_completed", [q])
	# Perform the HTTP request. The URL below returns a PNG image as of writing.
	var error = http_request.request(url)
	if error != OK:
		push_error("An error occurred while making the HTTP request.")
		return

# show player how much data is loaded
func _update_loading_progress(partial):
	var time = OS.get_ticks_msec()
	# total time / total size == partial time / partial size.
	# move total size to right hand side and get
	# total time == partial time * total size / partial size..
	var eta = -1 if partial == 0 else (
		1.0 * (time - time_start) * # partial time
		(QUESTION_COUNT - load_start) / # total size
		(partial - load_start) # partial size
	) - (time - time_start)  # subtract elapsed time from total
	current_page.update_loading_progress(partial, QUESTION_COUNT, int(eta))

# Called when the HTTP request is completed.
func _http_request_completed(result, response_code, headers, body, q):
	prints("MenuRoot._http_request_completed(", result, response_code, headers, body, ")")
	http_request.disconnect("request_completed", self, "_http_request_completed")
	if result != HTTPRequest.RESULT_SUCCESS:
		R.crash("The HTTP request for question ID %s did not succeed. Error code: %d" % [q, result])
		return
	elif response_code >= 400:
		R.crash("Tried to load question ID %s, but response code was: %d" % [q, response_code])
		return
	# not sure what to do when loaded...
	# check file existence
	var file = File.new()
	if file.file_exists(QPACK_NAME):
		var success: bool = ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(QPACK_NAME), true)
		if !success:
			R.crash("Could not load resource pack for question ID %s. The file appears to not have been saved." % q)
		if !file.file_exists("res://q/%s/title.wav.import" % q):
			R.crash("Loaded resource pack for question ID %s, but it has not been correctly extracted. Cause of failure: title.wav.import is missing." % q)
		if !file.file_exists("res://q/%s/_question.gdcfg" % q):
			R.crash("Loaded resource pack for question ID %s, but it has not been correctly extracted. Cause of failure: _question.gdcfg is missing." % q)
		print("Debug output of question data:")
		file.open("res://q/%s/_question.gdcfg" % q, File.READ)
		print(file.get_as_text())
		emit_signal("next_question_please")
	else:
		R.crash("Resource pack is not downloaded.")
		return
