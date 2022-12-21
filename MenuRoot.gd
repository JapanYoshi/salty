extends Control

onready var current_page
var first_page = preload("res://Episodes.tscn")
var signup = preload("res://signup.tscn")
onready var tween = $Tween
onready var click_mask = $ClickMask
var question_pack_is_downloaded = false
var waiting_for_game_start = false
var cancel_loading = false

signal next_question_please

# Called when the node enters the scene tree for the first time.
func _ready():
	current_page = first_page.instance()
	$ScreenStretch.add_child(current_page, true)
	$ScreenStretch.move_child(current_page, 1)
	current_page.menu_root = self
	print("MenuRoot readying...")
	S.play_multitrack("signup_base", 1, "signup_extra", 0, "signup_extra2", 0)
	click_mask.hide()
	R.pass_between.clear()
	print("MenuRoot readied.")
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
#		Ws._disconnect()
		yield(get_tree().create_timer(0.5), "timeout")
		get_tree().change_scene("res://Title.tscn")
	else:
		cancel_loading = true
		# free the added controller slots, so that we can reuse them next time
		C.remove_all_gamepads()
		R.players = []
		R.audience_keys = []
		R.audience = []
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
	current_page.menu_root = self
	$ScreenStretch.add_child(current_page, true)
	$ScreenStretch.move_child(current_page, 1)
	click_mask.hide()

func choose_episode(id):
	change_scene_to(signup.instance())
	while !("p_count" in current_page):
		yield(get_tree().create_timer(0.125), "timeout")
	pass
	load_episode(id)

const QUESTION_COUNT = 13
var time_start = -1
var load_start = -1
const RAND_PREFIX = "RNG_"
var load_order = []

func load_episode(ep):
	Loader.reset_question_text()
#	var LOG_FILE = File.new()
#	LOG_FILE.open("user://LOG.txt", File.WRITE)
#	LOG_FILE.close()
	cancel_loading = false
	# Get question list.
	R.pass_between.episode_data = Loader.episodes[ep].duplicate(true)
	# The question IDs are an array of 13 strings.
	# The first character of each question stands for its quesiton type.
	# (lowercase: nsctgolr)
	# To choose a random question from the pile, start the question ID with "RNG_"
	# then list all the question types it could be.
	# (e.g. RNG_ncot for any 4-choice question)
	var q_id = R.pass_between.episode_data.question_id
	if len(q_id) < QUESTION_COUNT:
		R.crash("Episode ID %s has only %d questions, where %d is required." % [
			ep, len(q_id), QUESTION_COUNT
		])
		return
	var question_types = {
		"n": 0, "s": 0, "c": 0, "t": 0, "g": 0, "o": 0, "l": 0, "r": 0
	}
	R.rng.randomize()
	# If the last question ID is blank or begins with "RNG_",
	# choose 1 random question that is either Like/Leave ("l") or Sugar Rush ("r").
	if q_id[QUESTION_COUNT-1] == "" or\
	   q_id[QUESTION_COUNT-1].begins_with(RAND_PREFIX):
		var which_finale = "lr"[R.rng.randi_range(0, 1)]
		question_types[which_finale] += 1
		q_id[QUESTION_COUNT-1] = Loader.random_questions_of_type(which_finale, 1)[0]
	# If the other question IDs begin with "RNG_",
	# mark it for a random choice later.
	# Otherwise, tally up the number of questions by question type.
	# Save the indices of the random questions for later.
	var search_order = []
	for i in range(QUESTION_COUNT - 1):
		if q_id[i].begins_with(RAND_PREFIX):
			search_order.push_back(i)
			q_id[i] = q_id[i].trim_prefix(RAND_PREFIX)
		else:
			question_types[q_id[i][0]] += 1
	# If any of the non-final questions are random, choose them here:
	if len(search_order) > 0:
		print(len(search_order), " random question(s) required.")
		search_order.shuffle()
		# * Exactly 1 big-bucks round:
		# Thousand-Question Question ("t"), All Outta Salt ("g")
		if question_types["t"] == 0 and question_types["g"] == 0:
			var which_special = "t" if (R.rng.randi_range(0, 7) == 0) else "g"
			for i in range(len(search_order)):
				var q = search_order[i]
				if which_special in q_id[q]:
					q_id[q] = Loader.random_questions_of_type(which_special, 1)[0]
					question_types[which_special] += 1
					search_order.remove(i)
					break
		print("Add random big-buck rounds:\n", q_id)
	if len(search_order) > 0:
		# * Exactly 1 Sorta Kinda ("s") per game
		if question_types["s"] == 0:
			for i in range(len(search_order)):
				var q = search_order[i]
				if "s" in q_id[q]:
					q_id[q] = Loader.random_questions_of_type("s", 1)[0]
					search_order.remove(i)
					break
		print("Add random Sorta Kinda:\n", q_id)
	if len(search_order) > 0:
		# * Exactly 1 Candy Trivia with Salty Barre ("c") per game
		if question_types["c"] == 0:
			for i in range(len(search_order)):
				var q = search_order[i]
				if "c" in q_id[q]:
					q_id[q] = Loader.random_questions_of_type("c", 1)[0]
					search_order.remove(i)
					break
		print("Add random Candy Trivia:\n", q_id)
	if len(search_order) > 0:
		# * A 12/128 chance for Rage Against the Times with Ozzy ("o")
		if question_types["o"] == 0 and randi() % 128 < 12:
			for i in range(len(search_order)):
				var q = search_order[i]
				if "o" in q_id[q]:
					q_id[q] = Loader.random_questions_of_type("o", 1)[0]
					search_order.remove(i)
					print("Add random Rage Question:\n", q_id)
					break
	if len(search_order) > 0:
		# * Rest are all normal 4-choicers / Shorties ("n")
		var shorties = Loader.random_questions_of_type("n", len(search_order))
		for i in range(len(search_order)):
			var q = search_order[i]
			q_id[q] = shorties[i]
		print("Fill rest with shorties:\n", q_id)
	for i in range(len(q_id)):
		R.pass_between.episode_data.question_id[i] = q_id[i]
	print("MenuRoot: Question IDs for episode ", ep, " are ", R.pass_between.episode_data.question_id, ".")
	# Load the questions.
	# If local copies exist, load them immediately.
	load_order = []
	for q in range(QUESTION_COUNT):
		if Loader.is_question_cached(q_id[q]):
			print("MenuRoot: Question already cached: ", q_id[q])
			_load_question(q_id[q])
		else:
			print("MenuRoot: Question must be downloaded: ", q_id[q])
			load_order.push_back(q_id[q])

	assert(len(Loader.question_texts.keys()) == 13 - len(load_order), "Only %d question texts are preemptively loaded." % len(Loader.question_texts.keys()))
	print("MenuRoot: List of questions that must be downloaded: ", load_order)
	# These questions do not exist locally.
	# Start downloading and importing the question files.
	time_start = OS.get_ticks_msec()
	load_start = 0
	question_pack_is_downloaded = false
	_update_loading_progress(0, len(load_order))
	for q in range(len(load_order)):
		yield(get_tree(), "idle_frame")
		print("MenuRoot: DOWNLOAD_QUESTION")
		download_question(load_order[q]) # this was the issue
		print("MenuRoot: YIELD START")
		yield(self, "next_question_please")
		assert(len(Loader.question_texts.keys()) == 14 - len(load_order) + q, "Only %d question texts are preemptively loaded." % len(Loader.question_texts.keys()))
		print("MenuRoot: YIELD END")
		if cancel_loading:
			return
		_update_loading_progress(q + 1, len(load_order))
	# All done! If we pressed Start meanwhile, we will start it up now.
	question_pack_is_downloaded = true
	if waiting_for_game_start:
		start_game()


onready var http_request = $HTTPRequest

func download_question(q):
	print("download_question(%s)" % q)
	var url = Loader.question_url + Loader.q_cache_filename % q
	# Create an HTTP request node and connect its completion signal.
	var download_file = Loader.q_cache_path + Loader.q_cache_filename % q
	while http_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		# wait while the HTTP client is still downloading
		yield(get_tree().create_timer(1.0), "timeout")
		print("download_question(%s): " % q, "Waiting for previous request to finish")
	print("download_question(%s): " % q, "Previous request has finished")
	http_request.set_download_file(download_file)
	http_request.download_chunk_size = 262144
	http_request.disconnect("request_completed", self, "_http_request_completed")
	http_request.connect("request_completed", self, "_http_request_completed", [q])

	var error = http_request.request(url)
	if error != OK:
		push_error("An error occurred while making the HTTP request.")
	print("Request sent to download (%s)" % q)
	return


# Called when the HTTP request is completed.
func _http_request_completed(result, response_code, headers, body, q):
	prints("MenuRoot._http_request_completed(", response_code, ", ", q, ")")
	http_request.disconnect("request_completed", self, "_http_request_completed")
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_message = "The HTTP request for question ID %s did not succeed. Error code: %d — " % [q, result]
		match result:
			HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH:
				error_message += "Chunked body size mismatch."
			HTTPRequest.RESULT_CANT_CONNECT:
				error_message += "Request failed while connecting."
			HTTPRequest.RESULT_CANT_RESOLVE:
				error_message += "Request failed while resolving."
			HTTPRequest.RESULT_CONNECTION_ERROR:
				error_message += "Request failed due to connection (read/write) error."
			HTTPRequest.RESULT_SSL_HANDSHAKE_ERROR:
				error_message += "Request failed on SSL handshake."
			HTTPRequest.RESULT_NO_RESPONSE:
				error_message += "No response."
			HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
				error_message += "Request exceeded its maximum body size limit."
			HTTPRequest.RESULT_REQUEST_FAILED:
				error_message += "Request failed."
			HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
				error_message += "HTTPRequest couldn't open the download file."
			HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
				error_message += "HTTPRequest couldn't write to the download file."
			HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
				error_message += "Request reached its maximum redirect limit."
			HTTPRequest.RESULT_TIMEOUT:
				error_message += "Request timed out."
		R.crash(error_message)
		return
	elif response_code >= 400:
		R.crash("Tried to load question ID %s, but the Web request did not succeed. The HTTP response code was %d." % [q, response_code])
		return
	Loader.append_question_cache(q)
	_load_question(q)


## Called after HTTP request is completed or local file is confirmed to exist.
func _load_question(q):
	print("_load_question(%s)" % q)
	# check file existence
	if Loader.is_question_cached(q):
		var success: bool = Loader.mount_cached_question(q)
		if !success:
			Loader.remove_from_question_cache(q)
			R.crash("Could not load resource pack for question ID %s. The file appears to be corrupted, so it has been removed from the cache." % q)
		# check required files
		var file = File.new()
		if !file.file_exists("res://q/%s/title.wav.import" % q):
			R.crash("Loaded resource pack for question ID %s, but it has not been correctly extracted.\n" % q + "Cause of failure: res://q/%s/title.wav.import does not exist." % q)
			return
		if !file.file_exists("res://q/%s/_question.gdcfg" % q):
			R.crash("Loaded resource pack for question ID %s, but it seems to be incomplete.\n" % q + "Cause of failure: res://q/%s/_question.gdcfg does not exist." % q)
			return
		print("_load_question(%s): " % q, "Loading question text preemptively...")
		var result = Loader.load_question_text(q)
		if result:
			R.crash(("Loading question text for %s" % q) + " failed with error code %d." % result)
			return
#		# check last file
#		q = R.pass_between.episode_data.question_id[0]
#		if !file.file_exists("res://q/%s/title.wav.import" % q):
#			R.crash("Loaded resource pack for question ID %s, but it has not been correctly extracted." % q + "Cause of failure: res://q/%s/title.wav.import does not exist." % q)
#		if !file.file_exists("res://q/%s/_question.gdcfg" % q):
#			R.crash("Loaded resource pack for question ID %s, but it has not been correctly extracted." % q + "Cause of failure: res://q/%s/_question.gdcfg does not exist." % q)
#		else:
#			file.open("res://q/%s/_question.gdcfg" % q, File.READ)
#			LOG_FILE.store_line("# First question content is now:\n" + file.get_as_text())
#			file.close()
		print("_load_question(%s): " % q, "Question text loaded preemptively. ", len(Loader.question_texts[q].keys()), " keys in total")
		print("Emitting signal next_question_please")
		call_deferred("emit_signal", "next_question_please")
	else:
		R.crash("Tried to load the assets for question ID " + q + ", but the asset pack does not exist. Please try clearing your question cache and try again.")
		return


# Request the game to start.
func start_game():
	if !question_pack_is_downloaded:
		# Wait until the question files are loaded.
		# This function will be called again once it's done.
		waiting_for_game_start = true
		current_page.get_node("MouseMask").color = Color(0, 0, 0, 0.5)
		current_page.get_node("LoadingPanel").show()
		return
	# Fade the music. (Takes 0.5 seconds.)
	S.play_track(0, 0.1)
	S.play_track(1, 0.1)
	S.play_track(2, 0.1)
	# Transition effect.
	#self.rect_pivot_offset = Vector2(640,360)
	tween.interpolate_property(self, "modulate", Color.white, Color.black, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.interpolate_property(self, "rect_scale", Vector2.ONE, Vector2.ONE * 1.1, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.interpolate_property(current_page.get_node("LoadingPanel"), "rect_scale", Vector2.ONE, Vector2.ONE * 1.25, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	get_tree().call_deferred("change_scene", "res://Episode.tscn")

# show player how much data is loaded
func _update_loading_progress(partial, load_count):
	var time = OS.get_ticks_msec()
	# total time / total size == partial time / partial size.
	# move total size to right hand side and get
	# total time == partial time * total size / partial size..
	var eta = -1
	if partial != 0:
		eta = (
			1.0 * (time - time_start) * # partial time
			(load_count - load_start) / # total size
			(partial - load_start) # partial size
		) - (time - time_start)  # subtract elapsed time from total
	current_page.update_loading_progress(
		partial + QUESTION_COUNT - load_count,
		QUESTION_COUNT,
		int(eta)
	)

