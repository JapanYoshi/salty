extends Node

# Used to communicate to Episode.gd
signal loaded
# Used to communicate to itself that a random voice line has loaded in S.gd
signal voice_line_loaded(result)

# Loads episode data.
# Also parses question structure and timing markers in text.
const episode_path = "res://ep/"
var episodes = {}

const question_path = "res://q/"
var random_questions = {}

# ProjectSettings.globalize_path forbids this from being a const
var q_cache_path = ProjectSettings.globalize_path("user://")
var cached = {}

var asset_cache_path = ProjectSettings.globalize_path("user://")
var asset_cache_url = "https://haitouch-9320f.web.app/salty/"
var asset_cache_filename = "_assets.pck"
onready var http_request = HTTPRequest.new()


var random_dict = {}

var rng = RandomNumberGenerator.new()

# Regex for the timing markers in the subtitle files,
# e.g.
### One Mississippi, [#1000#] Two Mississippi, [#2000#] Three Mississippi, [#3000#]
# where "One Mississippi," is shown from 0ms to 1000ms, "Two Mississippi," from 1000ms to 2000ms,
# and so on. The numbers are in milliseconds.
# The last timing marker may not be present, in which case it will persist
# until interrupted by another subtitle command.
var r_separator = RegEx.new()

var special_guest_names = []
var special_guest_ids = []

# Called when the node enters the scene tree for the first time.
func _ready():
	add_child(http_request)
	r_separator.compile("\\[#\\d+#\\]")
	rng.randomize()
	load_random_voice_lines()
	load_random_questions()
	load_episodes_list()
	# var dir: Directory = Directory.new()
	# if !(dir.dir_exists(q_cache_path)):
	# 	dir.make_dir_recursive(q_cache_path)
	### Testing
#	load_question("n001")
	### End testing


const MAGIC_NUMBER = PoolByteArray([0x47, 0x44, 0x50, 0x43])
func is_question_cached(id):
	var file: File = File.new()
	if !file.file_exists(q_cache_path + "%s.pck" % id):
		return false
	var error: int = file.open(q_cache_path + "%s.pck" % id, File.READ)
	if error:
		printerr("Loading ", q_cache_path, "%s.pck" % id, " resulted in error %d." % error)
		return false
	for i in range(4):
		if file.get_8() != MAGIC_NUMBER[i]:
			# Corrupted file.
			printerr(q_cache_path + "%s.pck" % id, " exists, but does not start with GDPC. Removing.")
			remove_from_question_cache(id)
			return false
	file.close()
	return true


func append_question_cache(id):
	cached[id] = true


func remove_from_question_cache(id):
	cached[id] = false
	var dir = Directory.new()
	dir.remove(q_cache_path + "%s.pck" % id)


func clear_question_cache():
	for id in cached:
		var dir = Directory.new()
		dir.remove(q_cache_path + "%s.pck" % id)


func load_cached_question(id):
	return ProjectSettings.load_resource_pack(
		q_cache_path + "%s.pck" % id
	)


func are_assets_cached():
	var file: File = File.new()
	if !file.file_exists(asset_cache_path + asset_cache_filename):
		print("Loader: Asset cache is not saved.")
		return false
	var error: int = file.open(asset_cache_path + asset_cache_filename, File.READ)
	if error:
		printerr("Loading ", asset_cache_path + asset_cache_filename, " resulted in error %d." % error)
		return false
	for i in range(4):
		if file.get_8() != MAGIC_NUMBER[i]:
			# Corrupted file.
			print("Loader: Asset cache is saved, but invalid.")
			return false
	file.close()
	return true


func download_assets(callback_node: Node, callback_function_name: String):
	var url = asset_cache_url + asset_cache_filename
	print("Loader.download_assets(): Getting ready to contact this url: ", asset_cache_url + asset_cache_filename)
	# Create an HTTP request node and connect its completion signal.
	http_request.set_download_file(asset_cache_path + asset_cache_filename)
	http_request.download_chunk_size = 262144
	http_request.connect("request_completed", self, "_download_assets_request_completed")
	# Perform the HTTP request.
	print("Loader.download_assets(): About to send the request to download the file as: ", asset_cache_path + asset_cache_filename)
	var error = http_request.request(url)
	if error != OK:
		push_error("Loader.download_assets(): An error occurred while making the HTTP request: %d." % error)
		return
	print("Loader.download_assets(): Successfully sent HTTP request.\n", http_request.get_downloaded_bytes(), "/", http_request.get_body_size());
	while http_request.get_downloaded_bytes() < http_request.get_body_size():
		callback_node.call(callback_function_name, http_request.get_downloaded_bytes(), http_request.get_body_size())
		yield(get_tree().create_timer(1.0), "timeout")


func _download_assets_request_completed(result, response_code, headers, body):
	http_request.disconnect("request_completed", self, "_download_assets_request_completed")
	if result != HTTPRequest.RESULT_SUCCESS:
		var error_message = "The HTTP request for the asset pack did not succeed. Error code: %d — " % [result]
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
		R.crash(error_message + "\nPressing the “Return to title” button below will not work correctly.")
		return
	elif response_code >= 400:
		R.crash("Tried to download the asset pack, but the Web request did not succeed. The HTTP response code was %d." % [response_code] + "\nPressing the “Return to title” button below will not work correctly.")
		return
	emit_signal("loaded")
	return


func load_assets():
	ProjectSettings.load_resource_pack(asset_cache_path + asset_cache_filename)
	emit_signal("loaded")


func remove_jsonc_comments(text: String) -> String:
	# remove block comments
	var start: int = text.find("/*"); var end: int = text.find("*/", start)
	while start != -1:
		if end == -1:
			return "// Parse error in remove_jsonc_comments: Unterminated block comment."
		text.erase(start, end - start + 2)
		start = text.find("/*"); end = text.find("*/", start)
	# remove line comments
	start = text.find("//"); end = text.find("\n", start)
	while start != -1:
		if end == -1:
			# delete until EOF
			text = text.left(start)
		else:
			text.erase(start, end - start + 1)
		start = text.find("//"); end = text.find("\n", start)
	return text


func load_random_voice_lines():
	var file = File.new()
	if file.open("res://random_voicelines.jsonc", File.READ) == OK:
		var json_text = remove_jsonc_comments(file.get_as_text())
		var json = JSON.parse(json_text)
		if json.error == OK:
			random_dict = json.result
			load_special_guests()
		else:
			R.crash("random_voicelines.jsonc could not be parsed. Error code: %d" % json.error)

func load_random_questions():
	var file = File.new()
	if file.open("res://random_questions.jsonc", File.READ) == OK:
		var json_text = remove_jsonc_comments(file.get_as_text())
		var json = JSON.parse(json_text)
		if json.error == OK:
			random_questions = json.result
		else:
			R.crash("random_questions.jsonc could not be parsed. Error code: %d" % json.error)

func random_questions_of_type(type, count):
	var questions = []
	var pool = random_questions[type]
	if count == 1:
		return [pool[R.rng.randi_range(0, len(pool) - 1)]]
	else:
		var indices = range(len(pool) - 1)
		for i in range(count):
			var index = R.rng.randi_range(0, len(indices) - 1)
			questions.push_back(pool[indices[index]])
			indices.remove(index)
		return questions

func load_episodes_list():
	# new option with list file
	var file = File.new()
	var err = file.open(episode_path + "list.txt", File.READ)
	if err == OK:
		episodes = {}
		var names = file.get_as_text().split(",")
		for ep_name in names:
			ep_name = ep_name.strip_edges()
			var ep_file = File.new()
			ep_file.open(episode_path + ep_name + "/ep.json", File.READ)
			var result = JSON.parse(ep_file.get_as_text())
			if result.error == OK:
				episodes[ep_name] = result.result
			else:
				print("Couldn't load episode: " + ep_name)
	print("Loader: Episode data loaded.")

func load_episode(id):
	var file = File.new()
	var err = file.open(episode_path + id + "/ep.json", File.READ)
	var data = {}
	var result = JSON.parse(file.get_as_text())
	if err == OK and result.error == OK:
		data = result.result
	else:
		R.crash("Episode data for ID '" + id + "' is missing. Please make sure that the following file exists:\n" + episode_path + id + "/ep.json")
	return data

const random_voice_line_keys = [
	# Normal / Candy Trivia
	"pretitle",
	"option0", "option1", "option2", "option3",
	"used_lifesaver",
	"reveal", "reveal_crickets", "reveal_jinx",
	"reveal_split", "reveal_correct",
	# multiple special question types
	"skip", "buzz_in",
	# Sorta Kinda
	"sort_segue", "sort_both", "sort_press_left", "sort_press_right",
	"sort_press_up", "sort_lifesaver",
	# All Outta Salt
	#"gib_segue",
	"gib_tute0", "gib_tute1", "gib_tute2", "gib_tute3", "gib_tute4",
	"gib_early", "gib_wrong", "gib_late", "gib_blank",
	# Thousand-Question Question
	"thou_segue", "thou_tute0", "thou_tute1", "thou_tute2", "thou_intro",
	# Sugar Rush
	"rush_intro", "rush_tute0", "rush_tute1", "rush_tute2", "rush_tute3",
	"rush_ready",
	# Like/Leave
	"like_intro",
	"like_tute0", "like_tute1", "like_tute2", "like_tute3",
	"like_title", "like_options", "like_ready",
	"like_outro"
];

func load_question(id, first_question: bool, q_box: Node):
	var failed_count: int = 5
	var file = ConfigFile.new()
	# I changed the name of the file during Alpha development.
	var err = ERR_FILE_NOT_FOUND
	var path = question_path + id + "/_question.gdcfg"
	print("Trying to load the following file... " + path)
	while failed_count:
		err = file.load(path)
		if !err:
			break
		failed_count -= 1
		printerr("Load failed: ", err)
		yield(get_tree().create_timer(0.2), "timeout")
	if err == ERR_FILE_NOT_FOUND:
		R.crash("Question data `_question.gdcfg` for ID '" + id + "' is missing.")
		return
	elif err == ERR_PARSE_ERROR:
		print("Found it, but it could not be parsed")
		var textfile = File.new()
		textfile.open(path, File.READ)
		print(textfile.get_as_text())
		textfile.close()
		R.crash("Question data for ID '" + id + "' cannot be parsed. Please look at the console for output.")
		return
	elif err != OK:
		R.crash("Loading question data `_question.gdcfg` for ID '" + id + "' resulted in error code %d." % err)
		return
	if len(file.get_sections()) == 0:
		var textfile = File.new()
		textfile.open(path, File.READ)
		R.crash("Question data for ID '" + id + "' turned out empty. Text content:\n" + textfile.get_as_text())
		textfile.close()
		return
	var data = {}
	for section in file.get_sections():
		if section == "root":
			for section_key in file.get_section_keys(section):
				data[section_key] = file.get_value(section, section_key)
		else:
			data[section] = {}
			for section_key in file.get_section_keys(section):
				data[section][section_key] = file.get_value(section, section_key)
	pass
	### Expected structure:
	# "v" is voice file name,
	# "t" is text (for title, question, and options),
	# "s" is subtitle data.
	# "v" can be "random", then "s" is taken from the randomly selected line.
	### Normal questions
	# "pretitle": {"v", "s"} (random?)
	# "title": {"t", "v", "s"}
	# "intro": {"v", "s"} (optional)
	# "question": {"t", "v", "s"}
	# "options": {"t"[4], "v", "s", "i"}
	# -- "i" is index of correct answer
	# "used_lifesaver": {"v", "s"} (random)?
	# "reveal": {"v", "s"} (random?)
	# "reveal_crickets": {"v", "s"} (random?)
	# "reveal_jinx": {"v", "s"} (random?)
	# "reveal_split": {"v", "s"} (random?)
	# "reveal_correct": {"v", "s"} (random?)
	# "option0"-"option3": {"v", "s"} (random?)
	# "outro": {"v", "s"}
	var keys = [];
	if not(data.has("type")):
		R.crash("Question data for ID " + id + " is missing the question type. Please make sure it has the key `type` inside the section `[root]`.\nlen(data.keys()) = " + str(len(data.keys())))
		return
	match data.type:
		"N":
			keys = [
				"pretitle", "title", "intro",
				"question",
				"options", "option0", "option1", "option2", "option3",
				"used_lifesaver",
				"reveal", "reveal_crickets", "reveal_jinx",
				"reveal_split", "reveal_correct", "outro"
			]
		"C":
			keys = [
				"pretitle", "title", "intro",
				"setup", "punchline", "post_punchline",
				"question",
				"options", "option0", "option1", "option2", "option3",
				"used_lifesaver",
				"reveal", "reveal_crickets", "reveal_jinx",
				"reveal_split", "reveal_correct", "outro"
			]
		"O":
			keys = [
				"pretitle", "title", "preintro", "intro",
				"question",
				"options", "option0", "option1", "option2", "option3",
				"used_lifesaver",
				"reveal", "reveal_crickets", "reveal_jinx",
				"reveal_split", "reveal_correct", "outro"
			]
		"S":
			keys = [
				"pretitle", "title", "sort_segue",
				"sort_category", "sort_explain",
				"sort_a", "sort_b", "sort_both", "sort_a_short", "sort_press_left",
				"sort_b_short", "sort_press_right", "sort_press_up", "sort_lifesaver",
				"sort_options", "sort_perfect", "sort_good", "sort_ok", "sort_bad",
				"outro", "skip"
			]
		"G":
			keys = [
				"pretitle", "title",
				#"gib_segue", # i dont think we need one for every question type
				"gib_tute0", "gib_tute1", "gib_tute2", "gib_tute3", "gib_tute4",
				"gib_genre", "question", "clue0", "clue1", "clue2",
				"buzz_in", "reveal",
				"outro", "skip"
			]
		"T":
			keys = [
				"pretitle", "title", "thou_segue",
				"thou_tute0", "thou_tute1", "thou_tute2",
				"thou_intro", "question",
				"options", "option0", "option1", "option2", "option3",
				"reveal_correct",
				"outro", "skip"
			]
		"R":
			keys = [
				"rush_intro",
				"rush_tute0", "rush_tute1", "rush_tute2", "rush_tute3",
				"title", "explanation", "rush_ready", "skip"
			]
		"L":
			keys = [
				"like_intro",
				"like_tute0", "like_tute1", #"like_tute2", "like_tute3",
				"like_title", "title", "like_options", "options", "like_ready",
				"section0", "answer0",
				"section1", "answer1",
				"section2", "answer2",
				"section3", "answer3",
				"section4", "answer4",
				"like_outro", "skip"
			]
		_:
			printerr("Question type can't be parsed yet: " + data.type)
			R.crash("Question data for ID " + id + " has an invalid or unsupported question type code `" + data.type + "`.")
	var failed: Array = []
	for key in keys:
		# Sorta Kinda option voice lines.
		if key == "sort_options":
			for i in range(0, 7):
				S.call_deferred("preload_voice",
					"sort_option%d" % i, id + ("/sort_option%d" % i), true, data[key].s[i]
				)
				var result = yield(S, "voice_preloaded")
				if result != OK:
					failed.push_back(key)
		elif data.has(key) and data[key]["v"] != "":
			if data[key]["v"] != "random":
				# not random
				if not data[key]["v"].begins_with("_"):
					# question-specific voice line
					S.call_deferred("preload_voice",key, id + "/" + data[key].v, true, data[key].s)
					var result = yield(S, "voice_preloaded")
					if result != OK:
						failed.push_back(key)
				else:
#					# common voice line
#					var possible_lines = random_dict.audio_question[data[key].v.substr(1)]
#					if len(possible_lines) == 1:
#						S.call_deferred("preload_voice",key, possible_lines[0].v, false, possible_lines[0].s)
#					else:
#						var index = R.rng.randi_range(0, len(possible_lines) - 1)
#						S.call_deferred("preload_voice",key, possible_lines[index].v, false, possible_lines[index].s)
					load_random_voice_line(key, data[key].v.substr(1))
					var result = yield(self, "voice_line_loaded")
					if result != OK:
						failed.push_back(key)
			# is random?
			elif key in random_voice_line_keys:
				# some logic depending on the situation
				var pool =\
					"option" if key.begins_with("option") else\
					"pretitle_q1" if first_question == true and key == "pretitle" else\
					key
				load_random_voice_line(key, pool)
				var result = yield(self, "voice_line_loaded")
				if result != OK:
					failed.push_back(key)
		else:
			# is optional?
			if key in [
				"intro",
				# used in Rage Against the Time with Ozzy
				"preintro"
			] or (
				data.type == "S" and data.has_both == false and key in ["sort_both", "sort_if_both", "sort_press_up"]
			) or (
				data.type == "C" and key in ["setup", "punchline", "post_punchline"]
			):
				# in case this key was previously loaded, unload it
				S.unload_voice(key)
				data.erase(key)
				pass
			# is random?
			elif key in random_voice_line_keys:
				# some logic depending on the situation
				var pool =\
					"option" if key.begins_with("option") else\
					"pretitle_q1" if first_question == true and key == "pretitle" else\
					key
				load_random_voice_line(key, pool)
				var result = yield(self, "voice_line_loaded")
				if result != OK:
					failed.push_back(key)
			else:
				printerr("Missing voice for " + key)
				breakpoint
	if failed.empty():
		print("Loader: Question loaded.")
		q_box.data = data
		emit_signal("loaded")
		return
	else:
		print("Loader: Question is missing voice lines. Crashing.")
		var error_message: String = "The following voice lines for question ID %s failed to load:" % id
		for s in failed:
			error_message += "\n" + s
		R.crash(error_message)

# Parses the time markers in the subtitle files.
# Timing is encoded in milliseconds since the start of the audio file, in this format: [#9999#]
# RETURNS:
# An Array of Dictionaries, structured as follows:
# {
#   "text": String
#     The text from the previous timing marker to this timing marker, excluding the timing markers.
#   "chars": int
#     The number of characters from the previous timing marker to this timing marker,
#     excluding the timing markers, and formatting tags if the argument
#     "exclude_formatting" is true.
#   "time": int
#     The time to switch to the next text at, in milliseconds from the start of the clip.
#     -1 means "show until the end of the audio file". 
# }
# ARGUMENTS:
# contents
# # The source string to decode.
# exclude_formatting
# # Whether or not to ignore BBcode tags in the character count.
# # Set to "true" if parsing time markers for question text
# # (revealing characters by visible character count),
# # and set to "false" if parsing time markers for subtitle text
# # (revealing characters by substringing).
func parse_time_markers(contents = "", exclude_formatting = false):
	var queue = []
	var texts = []
	var indices = [0]
	var timings = [0]
	var skipped_chars = 0
	for result in r_separator.search_all(contents):
		var timing = int(result.strings[0])
		indices.append(result.get_start())
		indices.append(result.get_end())
		timings.append(timing)
	indices.append(len(contents))
	timings.append(-1)
	if len(indices) > 1:
		for i in range(0, len(timings) - 1):
			texts.append(contents.substr(indices[i*2], indices[i*2+1] - indices[i*2]))
			if exclude_formatting:
				var copy = texts[i]
				copy = copy.replace("[b]", "")
				copy = copy.replace("[/b]", "")
				copy = copy.replace("[i]", "")
				copy = copy.replace("[/i]", "")
				copy = copy.replace("[code]", "")
				copy = copy.replace("[/code]", "")
				skipped_chars = len(texts[i]) - len(copy)
			if timings[i+1] > timings[i]:
				# normal one
				queue.append({
					"text": texts[i],
					"chars": indices[i*2+1] - indices[i*2] - skipped_chars,
#					"duration": timings[i+1] - timings[i]
					"time": timings[i+1]
				})
			elif texts[i] == "":
				# final one can be empty
				pass
			else:
				# after final timing marker
				queue.append({
					"text": texts[i],
					"chars": indices[i*2+1] - indices[i*2] - skipped_chars,
#					"duration": -1
					"time": -1
				})
	else:
		# no timing markers
		print("Subtitle has no timing markers")
		queue.append({
			"text": contents,
			"chars": len(contents),
#			"duration": -1
			"time": -1
		})
	return queue

func load_random_voice_line(key, pool = "", episode = false):
	if pool == "":
		pool = key
	var sel
	if episode:
		sel = random_dict.audio_episode[pool]
	else:
		sel = random_dict.audio_question[pool]
	var selection = sel[\
		rng.randi_range(0, len(sel) - 1)\
	]
	S.call_deferred("preload_voice",
		key, selection.v, false, selection.s
	)
	var result = yield(S, "voice_preloaded")
	emit_signal("voice_line_loaded", result)

func guest_id_or_empty_string(nick: String) -> String:
	if nick in special_guest_names:
		var guest_id = random_dict.special_guest.name_to_id[nick]
		if !(guest_id in special_guest_ids): return "" # we deleted seen guests beforehand
		
		return guest_id
	return ""


func load_special_guests():
	# Do not greet the same special guest twice.
	special_guest_names = random_dict.special_guest.name_to_id.keys()
	special_guest_ids = random_dict.special_guest.id_to_voice.keys()
	var already_seen = R.get_save_data_item("misc", "guests_seen", [])
	if !already_seen.empty():
		for v in already_seen:
			special_guest_ids.erase(v)
	# If you've seen all the special guests, reset progress.
	if special_guest_ids.empty():
		special_guest_ids = random_dict.special_guest.id_to_voice.keys()
		R.set_save_data_item("misc", "guests_seen", [])


func get_achievement_list() -> Dictionary:
	var file = File.new()
	if file.open("res://achievements/achievements.jsonc", File.READ) == OK:
		var json_text = remove_jsonc_comments(file.get_as_text())
		var json = JSON.parse(json_text)
		if json.error == OK:
			return json.result
		else:
			R.crash("achievements.jsonc could not be parsed. Error code: %d" % json.error)
			return {};
	else:
		R.crash("achievements.jsonc could not be opened. Please make sure that the file exists.")
		return {};
