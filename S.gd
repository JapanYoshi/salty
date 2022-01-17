extends Node
# Handles sound.

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
var voice_list = []

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
		"main_theme", "new_theme",
		"options",
		"outro",
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
	if !R.cfg.music or music_dict.has(name): return
	var music = load(music_path + name + ".ogg")
	var player = AudioStreamPlayer.new()
	player.set_stream(music)
	player.bus = "BGM"
	add_child(player)
	music_dict[name] = player

func unload_music(name):
	if R.cfg.music or music_dict.has(name):
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
	var voice = load((questions_path if question_specific else voice_path) + filename + ".wav")
	if voice == null:
		printerr("Voice line could not load! File path: " + (questions_path if question_specific else voice_path) + filename + ".wav")
	# avoid duplicate keys
	for e in voice_list:
		if e[0] == key:
			e[1].set_stream(voice)
			e[2] = subtitle_string
			return
	var player = AudioStreamPlayer.new()
	player.set_stream(voice)
	player.bus = "VOX"
	player.connect("finished", self, "_on_voice_end", [key])
	add_child(player)
	voice_list.append([key, player, subtitle_string])
	return

func preload_ep_voice(key, filename, episode_name, subtitle_string=""):
	var final_filename = filename + ".wav"
	if !episode_name:
		final_filename = voice_path + final_filename
	else:
		final_filename = (episode_path + episode_name + "/") + final_filename
	var voice = load(final_filename)
	if voice == null:
		printerr("Voice line could not load! File path: " + final_filename)
	var player = AudioStreamPlayer.new()
	player.set_stream(voice)
	player.bus = "VOX"
	player.connect("finished", self, "_on_voice_end", [key])
	add_child(player)
	voice_list.append([key, player, subtitle_string])

func unload_voice(key):
	for i in len(voice_list):
		if voice_list[i][0] == key:
			voice_list[i][1].queue_free()
			voice_list.remove(i)
			return

func cycle_voices(keys):
	var items = []
	for key in keys:
		for v in voice_list:
			if v[0] == key:
				items.push_back(v)
				break
	var temp = items[0]
	for i in range(len(items)):
		# exchange streams
		items[i][1].stream = items[(i + 1) % len(items)][1].stream
		# exchange subtitles
		items[i][2]        = items[(i + 1) % len(items)][2]
	# exchange streams
	items[-1][1].stream = temp[1].stream
	# exchange subtitles
	items[-1][2] = temp[2]

func _stop_music(name):
	if name in music_dict.keys():
		music_dict[name].stop()
		_log("Stopped music ", name, music_dict[name].get_playback_position())

func _set_music_vol(track: int, vol: float, dont_tween = true):
	if tracks[track] in music_dict.keys():
		var voldb = max(-80, linear2db(vol) + max_music_db)
		if dont_tween:
			music_dict[tracks[track]].set_volume_db(voldb)
		else:
			var vol_old = music_dict[tracks[track]].volume_db
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

func play_music(name, active):
	play_multitrack(name, active)

func play_multitrack(name0, active_0, name1 = "", active_1 = false, name2 = "", active_2 = false):
	if tracks[0] in music_dict.keys():
		_stop_music(tracks[0])
	if tracks[1] in music_dict.keys():
		_stop_music(tracks[1])
	if tracks[2] in music_dict.keys():
		_stop_music(tracks[2])
	if !R.cfg.music: return
	tracks[0] = name0
	tracks[1] = name1
	tracks[2] = name2
	if name0 != "":
		_set_music_vol(0, float(active_0))
		_play_music(name0)
	if name1 != "":
		_set_music_vol(1, float(active_1))
		_play_music(name1)
	if name2 != "":
		_set_music_vol(2, float(active_2))
		_play_music(name2)

func seek_multitrack(time):
	if !R.cfg.music: return
	for i in range(3):
		if tracks[i] in music_dict.keys():
			music_dict[tracks[i]].seek(time)

func play_track(track = 0, active = true, dont_tween = false):
	if !R.cfg.music: return
	if tracks[track] != "":
		_set_music_vol(track, float(active), dont_tween)
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
		_log("Played SFX ", name, sfx.get_playback_position())

func play_voice(id):
	if last_voice != "":
		stop_voice(last_voice)
	var voice_line: Array = []
	for e in voice_list:
		if e[0] == id:
			voice_line = e
			#voice_list.erase(e)
			break
	if len(voice_line) == 0:
		printerr("Could not find voice line with ID: " + id)
		return
	if is_instance_valid(sub_node):
		sub_node.queue_subtitles(voice_line[2])
	last_voice = voice_line[0]
	voice_line[1].play()
	_log("Played voice ", voice_line[0], voice_line[1].get_playback_position())

func stop_voice(should_be_playing = ""):
	if should_be_playing == "":
		should_be_playing = last_voice
	for e in voice_list:
		if e[0] == should_be_playing:
			_log("Stopped voice ", e[0], e[1].get_playback_position())
			e[1].stop()
			last_voice = ""
			sub_node.clear()
			return
	printerr("Could not stop voice ", last_voice, " because I couldn't find it")

func _on_voice_end(voice_id):
	if is_instance_valid(sub_node):
		sub_node.show_subtitle("", 0)
	_log("Finished playing voice ", voice_id, 9999)
	if voice_id == last_voice:
		last_voice = ""
		emit_signal("voice_end", voice_id)

func _log(msg, id, seek):
	print(msg + id + " (%f)" % seek)
