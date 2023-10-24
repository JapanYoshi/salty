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
const question_url = "https://haitouch.ga/me/salty/q/"
const q_cache_filename = "%s.zip"
var cached = {}

# update this when releasing new version
# must start with "_assets"
var asset_cache_filename = "_assets_3.pck"
var asset_cache_path = ProjectSettings.globalize_path("user://")
const asset_cache_url = "https://haitouch-9320f.web.app/salty_pck/"
onready var http_request = HTTPRequest.new()


export var random_dict = {}

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
	# preload question cache list
	var dir: Directory = Directory.new()
	var file: File = File.new()
	var exists: bool = dir.file_exists(q_cache_path + "_cached_questions.csv")
	if exists:
		file.open(q_cache_path + "_cached_questions.csv", File.READ)
		var text: String = file.get_as_text()
		for id in text.split(",", false):
			cached[id] = true
	else:
		file.open(q_cache_path + "_cached_questions.csv", File.WRITE)
		file.store_string("")
	file.close()
	# var dir: Directory = Directory.new()
	# if !(dir.dir_exists(q_cache_path)):
	# 	dir.make_dir_recursive(q_cache_path)
	### Testing
#	load_question("n001")
	### End testing


const MAGIC_NUMBER = PoolByteArray([0x47, 0x44, 0x50, 0x43])
func is_question_cached(id):
	if id in cached and cached[id] == true:
		var file: File = File.new()
		if !file.file_exists(q_cache_path + q_cache_filename % id):
			file.close()
			cached[id] = false
			return false
		return true
#	var error: int = file.open(q_cache_path + q_cache_filename % id, File.READ)
#	if error:
#		printerr("Loading ", q_cache_path, q_cache_filename % id, " resulted in error %d." % error)
#		file.close()
#		return false
	# code to validate .pck file, not used because it's a zip file
#	for i in range(4):
#		if file.get_8() != MAGIC_NUMBER[i]:
#			# Corrupted file.
#			printerr(q_cache_path + q_cache_filename % id, " exists, but does not start with GDPC. Removing.")
#			remove_from_question_cache(id)
#			return false
	return false


func append_question_cache(id):
	cached[id] = true
	
	var file: File = File.new()
	file.open(q_cache_path + "_cached_questions.csv", File.READ_WRITE)
	file.seek_end()
	file.store_string(",")
	file.store_string(id)
	file.close()


func remove_from_question_cache(id, save_text_file: bool = true):
	cached[id] = false
	var dir = Directory.new()
	dir.remove(q_cache_path + q_cache_filename % id)
	
	if !save_text_file: return
	var file: File = File.new()
	file.open(q_cache_path + "_cached_questions.csv", File.WRITE)
	var not_first: bool = false
	for id in cached.keys().sort():
		if cached[id]:
			if not_first:
				file.store_string(",")
			else:
				not_first = true
			file.store_string(id)
	file.close()


func clear_question_cache():
	var dir = Directory.new()
	for id in cached:
		remove_from_question_cache(id, false)
	
	var file: File = File.new()
	file.open(q_cache_path + "_cached_questions.csv", File.WRITE)
	file.store_string("")
	file.close()


func mount_cached_question(id):
	return ProjectSettings.load_resource_pack(
		q_cache_path + q_cache_filename % id
	)


#func are_assets_cached():
#	var file: File = File.new()
#	if !file.file_exists(asset_cache_path + asset_cache_filename):
#		print("Loader: Asset cache is not saved. Trying to delete any other versions of the assets to save space...")
#		clear_asset_cache()
#		return false
#	var error: int = file.open(asset_cache_path + asset_cache_filename, File.READ)
#	if error:
#		printerr("Loading ", asset_cache_path + asset_cache_filename, " resulted in error %d." % error)
#		var dir = Directory.new()
#		dir.remove(asset_cache_path + asset_cache_filename)
#		return false
#	for i in range(4):
#		if file.get_8() != MAGIC_NUMBER[i]:
#			# Corrupted file.
#			print("Loader: Asset cache is saved, but invalid.")
#			var dir = Directory.new()
#			dir.remove(asset_cache_path + asset_cache_filename)
#			return false
#	file.close()
#	return true


var assets_done: bool = false
func head_request_assets(callback_node: Node, callback_function_name: String):
	print("Loader.download_assets(): Getting ready to contact this url: ", asset_cache_url + asset_cache_filename)
	http_request.connect("request_completed", self, "_head_request_completed", [callback_node, callback_function_name], CONNECT_ONESHOT)
	var result = http_request.request(
		asset_cache_url + asset_cache_filename,
		["Accept-Encoding: identity"], true, HTTPClient.METHOD_HEAD
	)
	if result:
		printerr("http_request() HEAD did not succeed: ", result)
		if is_instance_valid(callback_node):
			callback_node.call(callback_function_name, 8)
		return


func _head_request_completed(\
	result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray,\
	callback_node: Node, callback_function_name: String):
	print("_head_request_completed ", result, " ", response_code, " ", headers, " ", body)
	# get last modified date
	var file: File = File.new()
	var last_mod_saved: String = ""
	if file.file_exists(asset_cache_path + "last-modified.txt"):
		file.open(asset_cache_path + "last-modified.txt", File.READ)
		last_mod_saved = file.get_as_text()
		file.close()
	# find out the size
	var size: int = 0
	var last_mod: String = ""
	for h in headers:
		var h_split = h.split(":", true, 1)
		if h_split[0] == "content-length":
			size = int(h_split[1])
		elif h_split[0] == "last-modified":
			last_mod = h_split[1]
	if is_instance_valid(callback_node):
		if last_mod == last_mod_saved:
			print("New last-modified header value ", last_mod, " == cached last-modified header value", last_mod_saved)
			callback_node.call(callback_function_name, 9, size)
		else:
			print("New last-modified header value ", last_mod, " != cached last-modified header value", last_mod_saved)
			callback_node.call(callback_function_name, 0, size)


func download_assets_confirm(callback_node: Node, callback_function_name: String):
	http_request.set_download_file(asset_cache_path + asset_cache_filename)
	http_request.download_chunk_size = 262144
	http_request.connect("request_completed", self, "_download_assets_request_completed", [], CONNECT_ONESHOT)
	# Perform the HTTP request.
	print("Loader.download_assets(): About to send the request to download the file as: ", asset_cache_path + asset_cache_filename)
	var error = http_request.request(asset_cache_url + asset_cache_filename)
	if error != OK:
		push_error("Loader.download_assets(): An error occurred while making the HTTP request: %d." % error)
		return
	print("Loader.download_assets(): Successfully sent HTTP request. ", http_request.get_downloaded_bytes());
	assets_done = false
	while !assets_done:
		if is_instance_valid(callback_node):
			print("Loader.download_assets(): ", http_request.get_downloaded_bytes())
			callback_node.call(callback_function_name, 1, http_request.get_downloaded_bytes())
			yield(get_tree().create_timer(1.0), "timeout")
		else:
			print("Loader.download_assets(): Callback node is invalid.", http_request.get_downloaded_bytes())
	if is_instance_valid(callback_node):
		callback_node.call(callback_function_name, 2, -1)
	else:
		printerr("Loader.download_assets_confirm: Callback node is not valid")


func _download_assets_request_completed(\
	result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray):
	print("Loader._download_assets_request_completed(",result,",",response_code,",",headers,",",body,")")
	assets_done = true
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
	# save last modified date
	var last_mod: String = ""
	for h in headers:
		var h_split = h.split(":", 1)
		if h_split[0] == "last-modified":
			last_mod = h_split[1]
			break
	var file = File.new()
	file.open(asset_cache_path + "last-modified.txt", File.WRITE)
	file.store_string(last_mod)
	file.close()
	return


func load_assets():
	var result = ProjectSettings.load_resource_pack(asset_cache_path + asset_cache_filename)
	print("Resource pack load result is ", result)
	yield(get_tree().create_timer(0.5), "timeout")
	emit_signal("loaded")
	return


func clear_asset_cache():
	var dir = Directory.new()
	if dir.open(asset_cache_path) == OK:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if !dir.current_is_dir():
				print("Found file: " + asset_cache_path + file_name)
				if file_name.begins_with("_assets") and file_name.ends_with(".pck"):
					dir.remove(file_name)
			file_name = dir.get_next()

## Old version that didn't allow "//" inside text
# func remove_jsonc_comments(text: String) -> String:
# 	# remove block comments
# 	# as a side effect of me not bothering to parse the entire thing, strings cannot contain /* or */
# 	var start: int = text.find("/*"); var end: int = text.find("*/", start)
# 	while start != -1:
# 		if end == -1:
# 			return "// Parse error in remove_jsonc_comments: Unterminated block comment."
# 		text.erase(start, end - start + 2)
# 		start = text.find("/*"); end = text.find("*/", start)
# 	# remove line comments
# 	start = text.find("//"); end = text.find("\n", start)
# 	while start != -1:
# 		if end == -1:
# 			# delete until EOF
# 			text = text.left(start)
# 		else:
# 			text.erase(start, end - start + 1)
# 		start = text.find("//"); end = text.find("\n", start)
# 	return text

## New version with a primitive check to see if we're inside a string
func remove_jsonc_comments(text: String) -> String:
	var inside_a_string: bool = false
	var closing_tag: String
	var i: int = -1
	while i < len(text) - 1:
		i += 1
		# JSON only allows double quotes to start and end a string.
		if text[i] == '"':
			if inside_a_string:
				if text[i - 1] == "\\":
					# Literal quotation mark inside a string. Ignore.
					continue
				inside_a_string = !inside_a_string
			continue
		if text[i] == "/":
			# Slashes are used in all comment tags.
			if inside_a_string:
				# Literal slash inside a string. Ignore.
				continue
			if text[i + 1] == "/":
				# Single line comment.
				closing_tag = "\n"
			elif text[i + 1] == "*":
				# Multiline comment.
				closing_tag = "*/"
			else:
				# Not a comment, but a misplaced slash. Leave it for the JSON parser to find.
				continue
			# Find the end of the comment.
			var end = text.find(closing_tag, i)
			if end == -1:
				# delete until EOF
				text = text.left(i)
				break
			else:
				text.erase(i, end - i + len(closing_tag))
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

# Pass 0 to return all questions
func random_questions_of_type(type, count) -> PoolStringArray:
	var pool: PoolStringArray = PoolStringArray(random_questions[type])
	if count == 0:
		return pool
	if count == 1:
		return PoolStringArray([pool[R.rng.randi_range(0, len(pool) - 1)]])
	var questions: PoolStringArray = PoolStringArray()
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
			var result = JSON.parse(
				remove_jsonc_comments(ep_file.get_as_text())
			)
			if result.error == OK:
				episodes[ep_name] = result.result
				episodes[ep_name].filename = ep_name
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
export var question_texts: Dictionary = {};


func reset_question_text():
	question_texts.clear()


func load_question_text(id):
	var file = ConfigFile.new()
	# I changed the name of the file during Alpha development.
	var err: int = ERR_FILE_NOT_FOUND
	var path = question_path + id + "/_question.gdcfg"
	print("Trying to load the following file... " + path)
	err = file.load(path)
	if err == ERR_FILE_NOT_FOUND:
		R.crash("Question data `_question.gdcfg` for ID '" + id + "' is missing.")
		printerr("question id ", id, " has missing GDCFG")
		yield(get_tree(), "idle_frame")
		return #err
	elif err == ERR_PARSE_ERROR:
		var textfile = File.new()
		textfile.open(path, File.READ)
		printerr("question id ", id, " has bad GDCFG:\n", textfile.get_as_text())
		textfile.close()
		R.crash("Question data for ID '" + id + "' cannot be parsed. Please look at the console for output.")
		yield(get_tree(), "idle_frame")
		return #err
	elif err != OK:
		R.crash("Loading question data `_question.gdcfg` for ID '" + id + "' resulted in error code %d." % err)
		yield(get_tree(), "idle_frame")
		return #err
	if len(file.get_sections()) == 0:
		var textfile = File.new()
		textfile.open(path, File.READ)
		textfile.close()
		R.crash("Question data for ID '" + id + "' turned out empty. Text content:\n" + textfile.get_as_text())
		yield(get_tree(), "idle_frame")
		return #ERR_FILE_EOF
	question_texts[id] = {}
	for section in file.get_sections():
		if section == "root":
			for section_key in file.get_section_keys(section):
				question_texts[id][section_key] = file.get_value(section, section_key)
		else:
			question_texts[id][section] = {}
			for section_key in file.get_section_keys(section):
				question_texts[id][section][section_key] = file.get_value(section, section_key)
#	if question_texts.has(id):
#		return OK
#	return ERR_SCRIPT_FAILED


func load_question(id, first_question: bool, q_box: Node):
	if not(id in question_texts.keys()):
		printerr("Question ID passed is ", id, ", which is not one of the questions in the episode data: ", R.pass_between.episode_data.question_id)
		R.crash("Question data for ID '" + id + "' has not been preloaded. Question asset data cannot be loaded.\nCurrently loaded question list: " + String(R.pass_between.episode_data.question_id))
		return
	var data: Dictionary = question_texts[id]
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
		"B":
			keys = [
				"pretitle", "title", "preintro", "intro",
				"cards", "question",
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
