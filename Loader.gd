extends Node

# Loads episode data.
# Also parses question structure and timing markers in text.
const episode_path = "res://ep"
var episodes = {}

const question_path = "res://q"
var random_questions = {}

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

# Called when the node enters the scene tree for the first time.
func _ready():
	r_separator.compile("\\[#\\d+#\\]")
	rng.randomize()
	load_random_voice_lines()
	load_random_questions()
	load_episodes_list()
	load_high_scores()
	### Testing
#	load_question("n001")
	### End testing

func load_random_voice_lines():
	var file = File.new()
	if file.open("res://random_voicelines.json", File.READ) == OK:
		var json = JSON.parse(file.get_as_text())
		if json.error == OK:
			random_dict = json.result

func load_random_questions():
	var file = File.new()
	if file.open("res://random_questions.json", File.READ) == OK:
		var json = JSON.parse(file.get_as_text())
		if json.error == OK:
			random_questions = json.result

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
	var err = file.open(episode_path + "/list.txt", File.READ)
	if err == OK:
		episodes = {}
		var names = file.get_as_text().split(",")
		for file_name in names:
			var ep_file = File.new()
			ep_file.open(episode_path + "/" + file_name + "/" + file_name + ".json", File.READ)
			var result = JSON.parse(ep_file.get_as_text())
			if result.error == OK:
				episodes[file_name] = result.result
			else:
				print("Couldn't load episode: " + file_name)
	# old directory-based option
#	var dir = Directory.new()
#	if dir.open(episode_path) == OK:
#		episodes = {}
#		dir.list_dir_begin(true, true)
#		var file_name = dir.get_next()
#		while file_name != "":
#			if dir.current_is_dir():
#				print("Found directory: " + file_name)
#				var file = File.new()
#				file.open(dir.get_current_dir() + "/" + file_name + "/" + file_name + ".json", File.READ)
#				var result = JSON.parse(file.get_as_text())
#				if result.error == OK:
#					episodes[file_name] = result.result
#				else:
#					print("Couldn't load file: " + dir.get_current_dir() + "/" + file_name)
#			else:
#				print("Found file: " + file_name)
#			file_name = dir.get_next()
#	else:
#		printerr("Could not open episodes folder.")
	### TEST: Simulate lots more episodes
#	for i in range(2, 12):
#		episodes["%03d.json" % i] = {
#			episode_name = "Episode %d" % i,
#			episode_desc = "Episode %d is unavailable. Stay tuned!" % i
#		}
	### END TEST
	print(episodes)
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func load_high_scores():
	pass

func load_episode(id):
	var file = File.new()
	var err = file.open(episode_path + "/" + id + "/" + id + ".json", File.READ)
	var data = {}
	var result = JSON.parse(file.get_as_text())
	if err == OK and result.error == OK:
		data = result.result
	else:
		printerr("Couldn't load episode ID: " + id)
		R.crash("Episode data for ID '" + id + "' is missing.")
	return data

func load_question(id, first_question: bool):
	var file = ConfigFile.new()
	var names = ["_question.gdcfg", "_question.tscn", "data.gdcfg"]
	var err = ERR_FILE_NOT_FOUND
	for n in names:
		print("Trying to load the following file... " + question_path + "/" + id + "/" + n)
		err = file.load(question_path + "/" + id + "/" + n)
		if err == ERR_FILE_NOT_FOUND:
			print("Didn't find " + n)
			continue
		elif err == ERR_PARSE_ERROR:
			print("Found it, but it could not be parsed")
			var textfile = File.new()
			textfile.open(question_path + "/" + id + "/" + n, File.READ)
			print(textfile.get_as_text())
		else:
			print("OK")
			break
	if err != OK:
		printerr("Couldn't load question ID: " + id)
		R.crash("Question data for ID '" + id + "' is missing.")
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
		R.crash("Question data is missing the key 'type'.")
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
		"S":
			keys = [
				"pretitle", "title", "sort_segue",
				"sort_category", "sort_explain",
				"sort_a", "sort_b", "sort_both", "sort_a_short", "sort_press_left",
				"sort_b_short", "sort_press_right", "sort_press_up",
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
	for key in keys:
		# Sorta Kinda option voice lines.
		if key == "sort_options":
			for i in range(0, 7):
				S.preload_voice("sort_option%d" % i, id + ("/sort_option%d" % i), true, data[key].s[i])
		elif data.has(key) and data[key]["v"] != "":
			if data[key]["v"] != "random":
				# not random
				if not data[key]["v"].begins_with("_"):
					# question-specific voice line
					S.preload_voice(key, id + "/" + data[key].v, true, data[key].s)
				else:
#					# common voice line
#					var possible_lines = random_dict.audio_question[data[key].v.substr(1)]
#					if len(possible_lines) == 1:
#						S.preload_voice(key, possible_lines[0].v, false, possible_lines[0].s)
#					else:
#						var index = R.rng.randi_range(0, len(possible_lines) - 1)
#						S.preload_voice(key, possible_lines[index].v, false, possible_lines[index].s)
					load_random_voice_line(key, data[key].v.substr(1))
			# is random?
			elif key in [
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
				"sort_press_up",
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
			]:
				# some logic depending on the situation
				var pool =\
					"option" if key.begins_with("option") else\
					"pretitle_q1" if first_question == true and key == "pretitle" else\
					key
				load_random_voice_line(key, pool)
		else:
			# is optional?
			if key in ["intro"] or (
				data.type == "S" and data.has_both == false and key in ["sort_both", "sort_if_both", "sort_press_up"]
			):
				# in case this key was previously loaded, unload it
				S.unload_voice(key)
				pass
			else:
				printerr("Missing voice for " + key)
				breakpoint
	return data

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
					"duration": timings[i+1] - timings[i]
				})
			elif texts[i] == "":
				# final one can be empty
				pass
			else:
				# after final timing marker
				queue.append({
					"text": texts[i],
					"chars": indices[i*2+1] - indices[i*2] - skipped_chars,
					"duration": -1
				})
	else:
		# no timing markers
		print("Subtitle has no timing markers")
		queue.append({
			"text": contents,
			"chars": len(contents),
			"duration": -1.0
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
	S.preload_voice(
		key, selection.v, false, selection.s
	)
