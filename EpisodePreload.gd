extends Control

var menu_root: Control
onready var status_label: Label = $Label
var q_index_now: int = 0
var waiting_to_start: bool = false
var questions: PoolStringArray = PoolStringArray()
var start_time: int = 0
onready var LoadingIndicator: Control = $LoadingIndicator

func _ready():
	$Confirm.hide()
	LoadingIndicator.get_node("LoadingProgress").hide()
	status_label.set_text("Preparing to download questions for " + R.pass_between.episode_data.episode_name + "...")
	
	var question_types = {
		"n": 0, "s": 0, "c": 0, "t": 0, "g": 0, "o": 0, "l": 0, "r": 0
	}
	var qid = R.pass_between.episode_data.question_id
	# get named questions, store random question presence for later
	if qid[12].empty():
		qid[12] = "RNG_rl"
	for i in range(len(qid)):
		if qid[i].begins_with(menu_root.RAND_PREFIX):
			for c in qid[i].right(len(menu_root.RAND_PREFIX)):
				question_types[c] = 1
		else:
			questions.push_back(qid[i])
	# get random questions
	for k in question_types.keys():
		if question_types[k] == 0: continue
		var q: PoolStringArray = Loader.random_questions_of_type(k, 0)
		questions.append_array(q)
	# exclude already downloaded questions
	for i in range(len(questions) - 1, -1, -1):
		yield(get_tree(), "idle_frame")
		if Loader.is_question_cached(questions[i]):
			questions.remove(i)
	# check if any questions need downloading
	if questions.empty():
		status_label.set_text(
			"All questions are already downloaded and cached. This episode can be played offline!\nPress Esc/㍜ to return to the list of episodes."
		)
		S.play_sfx("menu_signin")
		S.play_track(0, 1)
		S.play_track(1, 0)
		S.play_track(2, 1)
	else:
		waiting_to_start = true
		status_label.set_text(
			"Do you want to pre-download the {0} questions that are not locally cached yet?"\
			.format([len(questions)])
		)
		$Confirm.show()
		S.play_track(0, 0)
		S.play_track(1, 1)
		S.play_track(2, 0)

# Check for controllers that haven't signed up yet.
func _input(e: InputEvent):
	if e.is_action_pressed("ui_accept") and waiting_to_start:
		start_downloading()
		return
	if e.is_action_pressed("ui_cancel"):
		menu_root.back()
		return

func start_downloading():
	$Confirm.hide()
	waiting_to_start = false
	status_label.set_text("Preloading {0} questions. This can be canceled at any time.".format([len(questions)]))
	update_loading_progress()
	LoadingIndicator.get_node("LoadingPanel").show()
	q_index_now = 0
	start_time = OS.get_system_time_msecs()
	load_next_question()

func load_next_question():
	if q_index_now >= len(questions):
		S.play_track(0, 1)
		S.play_track(1, 0)
		S.play_track(2, 1)
		LoadingIndicator.hide()
		S.play_sfx("menu_signin")
		status_label.set_text("All questions downloaded! You may now exit this page.")
		return
	if q_index_now >= len(questions):
		S.play_track(0, 1)
		S.play_track(1, 0)
		S.play_track(2, 0)
	else:
		S.play_track(0, 0)
		S.play_track(1, 1)
		S.play_track(2, 0)
	menu_root.download_question(questions[q_index_now], self, "_load_question")

func _ordinal(number: int) -> String:
	var num_string: String = "{0:03d}".format(number % 1000)
	if num_string[1] == "1":
		return str(number) + "th"
	if num_string[2] == "1":
		return str(number) + "st"
	if num_string[2] == "2":
		return str(number) + "nd"
	if num_string[2] == "3":
		return str(number) + "rd"
	return str(number) + "th"

func _load_question(q):
	if Loader.is_question_cached(q):
		q_index_now += 1
		status_label.set_text("{0} downloaded of {1}. You can cancel this at any time.".format([
			str(q_index_now) + " question" + ("" if q_index_now == 1 else "s"),
			len(questions)
		]))
		update_loading_progress()
		load_next_question()
	else:
		status_label.set_text("Having trouble downloading the {0} question. Trying again... (Timestamp {1})".format([
			_ordinal(q_index_now),
			OS.get_system_time_msecs() % 100000
		]))
		load_next_question()

func update_loading_progress():
	var now_time = OS.get_system_time_msecs()
	# Linearly interpolate time remaining
	var eta = -1
	if q_index_now != 0:
		eta = (
			float(now_time - start_time) * # partial time
			len(questions) / # total size
			q_index_now # partial size
		) - (now_time - start_time)  # subtract elapsed time from total
	LoadingIndicator.update_loading_progress(q_index_now, len(questions), int(eta))

func _on_leave_page():
	# probably don't need to abort the connection so eagerly
	pass


func _on_Confirm_pressed():
	start_downloading()
