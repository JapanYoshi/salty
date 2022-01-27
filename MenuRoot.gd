extends Control

onready var current_page = $Episodes
var first_page = preload("res://Episodes.tscn")
var signup = preload("res://signup.tscn")
onready var tween = $Tween
onready var click_mask = $ClickMask
var question_pack_is_downloaded = false
var waiting_for_game_start = false
const QPACK_NAME = "user://question_pack.pck"

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

func load_episode(ep):
	change_scene_to(signup.instance())
	async_load_question_pack(ep)

func start_game():
	if !question_pack_is_downloaded:
		waiting_for_game_start = true
		_update_loading_progress()
		current_page.get_node("MouseMask").color = Color(0, 0, 0, 0.5)
		current_page.get_node("LoadingPanel").show()
		return
	current_page.update_loading_progress(http_request.get_body_size(), http_request.get_body_size(), 0)
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

func async_load_question_pack(ep):
	print("async_load_question_pack()")
	var url = "http://haitouch.ga/me/salty/%s.pck" % Loader.episodes[ep].question_pack
	# Create an HTTP request node and connect its completion signal.
	http_request.download_file = QPACK_NAME
	http_request.download_chunk_size = 262144
	http_request.connect("request_completed", self, "_http_request_completed")
	# Perform the HTTP request. The URL below returns a PNG image as of writing.
	var error = http_request.request(url)
	if error != OK:
		push_error("An error occurred while making the HTTP request.")
		return
	else:
		_check_loading_started()

var time_start = -1
var load_start = -1
func _check_loading_started():
	if http_request.get_body_size() > 0:
		time_start = OS.get_ticks_msec()
		load_start = http_request.get_downloaded_bytes()
	else:
		yield(get_tree().create_timer(0.1), "timeout")
		call_deferred("_check_loading_started")

# show player how much data is loaded
func _update_loading_progress():
	while http_request.get_body_size() <= 0:
		print("Reported body size is %d. Querying again." % http_request.get_body_size())
		_check_loading_started()
		yield(get_tree().create_timer(0.1), "timeout")
	var partial = http_request.get_downloaded_bytes()
	var total = http_request.get_body_size()
	var time = OS.get_ticks_msec()
	# total time / total size == partial time / partial size.
	# move total size to right hand side and get
	# total time == partial time * total size / partial size..
	var eta = (
		1.0 * (time - time_start) * # partial time
		(total - load_start) / # total size
		(partial - load_start) # partial size
	) - (time - time_start)  # subtract elapsed time from total
	prints("ETA CALCULATION", "start bytes:", load_start, "loaded bytes:", partial, "total bytes:", total, "start time:", time_start, "time now:", time, "calculated eta:", eta)
	current_page.update_loading_progress(partial, total, int(eta))
	if !question_pack_is_downloaded:
		yield(get_tree().create_timer(0.25), "timeout")
		call_deferred("_update_loading_progress")

# Called when the HTTP request is completed.
func _http_request_completed(result, response_code, headers, body):
	prints("MenuRoot._http_request_completed(", result, response_code, headers, body, ")")
	if result != HTTPRequest.RESULT_SUCCESS:
		printerr("HTTP request did not succeed.")
		return
	elif response_code == 404:
		R.crash("Tried to load the resource pack, but response code was 404 Not Found.")
	# not sure what to do when loaded...
	# check file existence
	var file = File.new()
	if file.file_exists(QPACK_NAME):
		var success: bool = ProjectSettings.load_resource_pack(ProjectSettings.globalize_path(QPACK_NAME), true)
		if !success:
			R.crash("Could not load resource pack.")
		for i in range(13):
			var qid = Loader.episodes[R.pass_between.episode_name].question_id[i]
			print(qid)
#			if !file.file_exists("res://q/%s/data.gdcfg" % qid):
#				R.crash("Loaded resource pack, but question file is missing: question index %d, question ID %s." % [i, qid])
#				return
		question_pack_is_downloaded = true
		if waiting_for_game_start == true:
			start_game()
	else:
		R.crash("Resource pack is not downloaded.")
		return
