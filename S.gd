extends Node
# Handles sound.

signal voice_preloaded(result)

signal voice_end

onready var tweens = [Tween.new(), Tween.new(), Tween.new()]
# path of music files in storage
const music_path = "res://audio/music/"
# path of SFX files in storage
const sfx_path = "res://audio/sfx/"
# name to filename for SFX
var sfx_list = {}
# path of generic voice files in storage
const voice_path = "res://audio/voice/"
# path of questions in storage, for question-specific voice lines
const questions_path = "res://q/"
const episode_path = "res://ep/"

const max_music_db = -3;

var sub_node: Node

var music_dict = {}
var sfx_dict = {}
var voice_list = {}

var tracks = ["", "", ""]
var last_voice = ""

func _ready():
	for t in tweens:
		add_child(t)

	var f = File.new()
	var r = f.open(sfx_path + "_.json", File.READ)
	if r != OK:
		printerr("Could not load list of sound effects.")
	sfx_list = JSON.parse(f.get_as_text()).result
	for k in sfx_list.keys():
		preload_sfx(k)
	for k in [
		"answer_now", "answer_now_2", "answer_now_3", "answer_now_4", "answer_now_5",
		"hiphop", "house",
		"load_loop", "main_theme", "new_theme",
		"organ", "outro",
		"placeholder",
		"reading_question_base", "reading_question_extra",
		"signup_base", "signup_extra", "signup_extra2",
	]:
		preload_music(k)
	### Testing
#	preload_music("signup_base")
#	preload_music("signup_extra")
#	preload_music("signup_extra2")
#	play_multitrack(
#		"signup_base", true,
#		"signup_extra", false,
#		"signup_extra2", false
#	)
	### End testing

func preload_music(name):
	if music_dict.has(name): return
	var music = load(music_path + name + ".ogg")
	var player = AudioStreamPlayer.new()
	player.set_stream(music)
	player.bus = "BGM"
	add_child(player)
	music_dict[name] = player

func unload_music(name):
	if R.cfg.music_volume > 0 or music_dict.has(name):
		music_dict[name].queue_free()
	music_dict.erase(name)

func preload_sfx(name):
	var sfx = load(sfx_path + sfx_list[name])
	var player = AudioStreamPlayer.new()
	player.set_stream(sfx)
	player.bus = "SFX"
	add_child(player)
	sfx_dict[name] = player

func preload_voice(key, filename, question_specific: bool = false, subtitle_string=""):
	# we have to use a yield in this function for using yield() to wait for it
	var file = File.new()
	var filepath = (questions_path if question_specific else voice_path) + filename + ".wav"
	var loader: ResourceInteractiveLoader = ResourceLoader.load_interactive(filepath)
	if loader == null: # Check for errors.
		printerr("S.preload_voice - ResourceInteractiveLoader failed to preload %s!" % filename)
		yield(get_tree().create_timer(0), "timeout")
		emit_signal("voice_preloaded", ERR_PARSE_ERROR)
		return
	while loader.poll() == OK:
		# stall for time
		yield(get_tree(), "idle_frame")
	if loader.poll() != ERR_FILE_EOF:
		printerr("S.preload_voice - ResourceInteractiveLoader got error # %d while preloading %s!" % [loader.poll(), filename])
		yield(get_tree().create_timer(0), "timeout")
		emit_signal("voice_preloaded", ERR_PARSE_ERROR)
		return
	var voice = loader.get_resource() # try loading, and if it doesn't load, fallback
	if voice == null and file.file_exists(filepath + ".import"):
		print(filepath + ".import exists. Loading.")
		# find out what the actual data is called.
		# WARNING: Very hacky maneuver because automatically redirecting WAV
		# files breaks when loading from pck file apparently.
		file.open(filepath + ".import", File.READ)
		var text = file.get_as_text()
		file.close()
		var start = text.find('path="res://.import/') + 6
		var end = text.find('.sample"', start) + 7
		var redir_path = text.substr(start, end - start)
		print("Redirect to: ", redir_path)
		voice = load(redir_path)
	if voice == null:
		printerr("Voice line could not load! File path: " + filepath)
		voice = load("res://audio/_.wav")
		yield(get_tree().create_timer(0), "timeout")
		emit_signal("voice_preloaded", ERR_DOES_NOT_EXIST)
		return
	print("Voice preloaded: " + filename)
	# avoid duplicate keys
	if voice_list.has(key):
		voice_list[key].player.set_stream(voice)
		voice_list[key].subtitle = subtitle_string
		yield(get_tree().create_timer(0), "timeout")
		emit_signal("voice_preloaded", OK)
		return
	var player = AudioStreamPlayer.new()
	player.set_stream(voice)
	player.bus = "VOX"
	add_child(player)
	voice_list[key] = {
		player = player,
		subtitle = subtitle_string
	}
	yield(get_tree().create_timer(0), "timeout")
	emit_signal("voice_preloaded", OK)
	return

func preload_ep_voice(key, filename, episode_name, subtitle_string=""):
	var final_filename = filename + ".wav"
	if !episode_name:
		final_filename = voice_path + final_filename
	else:
		final_filename = (episode_path + episode_name + "/") + final_filename
	var loader: ResourceInteractiveLoader = ResourceLoader.load_interactive(final_filename)
	if loader == null: # Check for errors.
		printerr("S.preload_voice - ResourceInteractiveLoader failed to preload %s!" % filename)
		yield(get_tree().create_timer(0), "timeout")
		emit_signal("voice_preloaded", ERR_PARSE_ERROR)
		return
	while loader.poll() == OK:
		yield(get_tree(), "idle_frame")
	if loader.poll() != ERR_FILE_EOF:
		printerr("S.preload_ep_voice - ResourceInteractiveLoader got error # %d while preloading %s!" % [loader.poll(), filename])
		yield(get_tree().create_timer(0), "timeout")
		emit_signal("voice_preloaded", ERR_PARSE_ERROR)
		return
	var voice = loader.get_resource() # try loading, and if it doesn't load, fallback
	if voice == null:
		printerr("Voice line could not load! File path: " + final_filename)
		yield(get_tree().create_timer(0), "timeout")
		emit_signal("voice_preloaded", OK)
		return
	print("Voice preloaded: " + filename)
	var player = AudioStreamPlayer.new()
	player.set_stream(voice)
	player.bus = "VOX"
	# we'll connect when we play it
#	player.connect("finished", self, "_on_voice_end", [key])
	add_child(player)
	voice_list[key] = {
		player = player,
		subtitle = subtitle_string
	}
	yield(get_tree().create_timer(0), "timeout")
	emit_signal("voice_preloaded", OK)
	return

func preload_guest_voice(key):
	var obj = Loader.random_dict.special_guest.id_to_voice[key]
	var final_filename = voice_path +\
		obj.v + ".wav"
	var loader: ResourceInteractiveLoader = ResourceLoader.load_interactive(final_filename)
	if loader == null: # Check for errors.
		printerr("S.preload_voice - ResourceInteractiveLoader failed to preload %s!" % filename)
		yield(get_tree().create_timer(0), "timeout")
		emit_signal("voice_preloaded", ERR_PARSE_ERROR)
		return
	while loader.poll() == OK:
		yield(get_tree(), "idle_frame")
	if loader.poll() != ERR_FILE_EOF:
		printerr("S.preload_ep_voice - ResourceInteractiveLoader got error # %d while preloading %s!" % [loader.poll(), filename])
		yield(get_tree().create_timer(0), "timeout")
		emit_signal("voice_preloaded", ERR_PARSE_ERROR)
		return
	var voice = loader.get_resource() # try loading, and if it doesn't load, fallback
	if voice == null:
		printerr("Voice line could not load! File path: " + final_filename)
		yield(get_tree().create_timer(0), "timeout")
		emit_signal("voice_preloaded", OK)
		return
	print("Voice preloaded: " + filename)
	var player = AudioStreamPlayer.new()
	player.set_stream(voice)
	player.bus = "VOX"
	# we'll connect when we play it
#	player.connect("finished", self, "_on_voice_end", [key])
	add_child(player)
	voice_list.special_guest = {
		player = player,
		subtitle = obj.s
	}
	yield(get_tree().create_timer(0), "timeout")
	emit_signal("voice_preloaded", OK)
	return

func unload_all_voices():
	for k in voice_list.keys():
		unload_voice(k)

func unload_voice(key):
	if voice_list.has(key):
		voice_list[key].player.queue_free()
		voice_list.erase(key)
		return

func cycle_voices(keys):
	var items = []
	for key in keys:
		if voice_list.has(key):
			items.push_back(voice_list[key])
			break
	var temp_stream = items[0].player.stream
	var temp_subtitle = items[0].subtitle
	for i in range(len(items)):
		# exchange streams
		items[i].player.stream = items[(i + 1) % len(items)].player.stream
		# exchange subtitles
		items[i].subtitle = items[(i + 1) % len(items)].subtitle
	# exchange streams
	items[-1].player.stream = temp_stream
	# exchange subtitles
	items[-1].subtitle = temp_subtitle

func _stop_music(name):
#	print("_stop_music(%s)" % name)
#	print("check 1: ", name in music_dict.keys())
#	print("check 2: ", is_instance_valid(music_dict[name]))
	if name in music_dict.keys() and is_instance_valid(music_dict[name]):
		music_dict[name].stop()
		_log("Stopped music ", name, music_dict[name].get_playback_position())

func _set_music_vol(track: int, vol: float, dont_tween = true):
	print("S: _set_music_vol(%d, %f, %s)" % [track, vol, str(dont_tween)])
	if is_instance_valid(music_dict[tracks[track]]):
		var voldb = max(-80, linear2db(vol) + max_music_db)
		if dont_tween:
			music_dict[tracks[track]].set_volume_db(voldb)
		else:
			var vol_old = music_dict[tracks[track]].volume_db
			tweens[track].stop_all()
			if vol_old != voldb:
				print("Interpolating track " + str(track) + " from " + str(music_dict[tracks[track]].volume_db) + " to " + str(voldb))
				tweens[track].interpolate_property(
					music_dict[tracks[track]],
					"volume_db",
					-80 if vol_old <= -80 else vol_old,
					voldb,
					0.5,
					Tween.TRANS_QUART,
					Tween.EASE_IN if voldb < vol_old else Tween.EASE_OUT
				)
				tweens[track].start()

func _play_music(name):
	if name in music_dict.keys():
		music_dict[name].play()
		_log("Played music ", name, music_dict[name].get_playback_position())
	else:
		printerr("Music ", name, " not found")

func play_music(name, volume):
	play_multitrack(name, volume)

func play_multitrack(
	name0: String, volume_0: float,
	name1: String = "", volume_1: float = 0.0,
	name2: String = "", volume_2: float = 0.0
):
#	print("play_multitrack(%s, %f, %s, %f, %s, %f)" % [
#		name0, volume_0, name1, volume_1, name2, volume_2
#	])
	_stop_music(tracks[0])
	_stop_music(tracks[1])
	_stop_music(tracks[2])
	if R.cfg.music_volume == 0: return
	tracks[0] = name0
	tracks[1] = name1
	tracks[2] = name2
	if name0 != "":
		_set_music_vol(0, volume_0)
		_play_music(name0)
	if name1 != "":
		_set_music_vol(1, volume_1)
		_play_music(name1)
	if name2 != "":
		_set_music_vol(2, volume_2)
		_play_music(name2)
#	print("play_multitrack finished")

func seek_multitrack(time):
	if !R.cfg.music_volume == 0: return
	for i in range(3):
		if is_instance_valid(music_dict[tracks[i]]):
			music_dict[tracks[i]].seek(time)

func play_track(track = 0, volume: float = 1.0, dont_tween = false):
	if R.cfg.music_volume == 0: return
	if tracks[track] != "":
		_set_music_vol(track, volume, dont_tween)
		if track != 0:
			music_dict[tracks[track]].seek(music_dict[tracks[0]].get_playback_position())
			print(" playback offsets: ",
			music_dict[tracks[0]].get_playback_position() if tracks[0] else "", " ",
			music_dict[tracks[1]].get_playback_position() if tracks[1] else "", " ",
			music_dict[tracks[2]].get_playback_position() if tracks[2] else "")

func play_sfx(name, speed = 1.0):
	var sfx = sfx_dict[name]
	if is_instance_valid(sfx):
		sfx.set_pitch_scale(speed)
		sfx.play()
#		_log("Played SFX ", name, sfx.get_playback_position())
	else:
		printerr("SFX not found: ", name)

func play_voice(id):
	if last_voice in voice_list and voice_list[last_voice].player.is_playing():
		stop_voice(last_voice)
	# retrieve the voice line "struct" and put it here.
	# we'll use the 'id', 'subtitle', and 'player' properties
	var voice_line: Dictionary = {}
	if voice_list.has(id):
		voice_line = voice_list[id]
		#voice_list.erase(e)
	if voice_line.empty():
		printerr("Could not find voice line with ID: " + id)
		return
	if is_instance_valid(sub_node):
		sub_node.queue_subtitles(voice_line.subtitle)
	last_voice = id
	# call_deferred causes a frame-perfect double audio glitch.
	# if you stop the audio on the exact frame you start playing a voice,
	# this tries to stop an audio player that's already stopped
#	voice_line.player.call_deferred("play")
	voice_line.player.connect("finished", self, "_on_voice_end", [id], CONNECT_ONESHOT)
	voice_line.player.play()
#	_log("Played voice ", id, voice_line.player.get_playback_position())

# Stop the currently playing voice.
# DEPRECATED: supply the voice line that should be playing right now.
func stop_voice(should_be_playing = ""):
	if should_be_playing != last_voice:
		if should_be_playing != "":
			printerr("Tried to stop ", should_be_playing, " which isn't the currently playing voice line.")
		should_be_playing = last_voice
	if (
		last_voice in voice_list
	) and voice_list[last_voice].player.is_playing():
		sub_node.clear_contents()
		voice_list[last_voice].player.disconnect("finished", self, "_on_voice_end")
		voice_list[last_voice].player.stop()
		_log("Manually stopped voice ", last_voice, voice_list[last_voice].player.get_playback_position())
		last_voice = ""
		return
	printerr("Could not stop voice ", last_voice, " because I couldn't find it")

func get_voice_time() -> float:
	if !voice_list.has(last_voice):
		print("Last_voice is ", last_voice, " which was not found.")
		# The ID of the last voice line is not found.
		# This shouldn't happen, but I'll account for this. 
		return 0.0
	print("Last_voice is ", last_voice, " whose progress is ", voice_list[last_voice].player.get_playback_position())
	return voice_list[last_voice].player.get_playback_position()

func _on_voice_end(voice_id):
	_log("Naturally finished playing voice ", voice_id, 9999)
	if is_instance_valid(sub_node):
		sub_node.signal_end_subtitle()
#	if voice_id == last_voice:
	last_voice = ""
	emit_signal("voice_end", voice_id)

onready var bgm_bus: int = AudioServer.get_bus_index("BGM")

func set_music_volume(percentage: float):
	AudioServer.set_bus_volume_db(bgm_bus, linear2db(percentage * percentage))

func set_overall_volume(percentage: float):
	AudioServer.set_bus_volume_db(0, linear2db(percentage * percentage))

func _log(msg, id, seek):
	print(msg + id + " (%f)" % seek)
