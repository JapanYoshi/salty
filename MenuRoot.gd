extends Control

onready var current_page = $Episodes
var first_page = preload("res://Episodes.tscn")
var signup = preload("res://signup.tscn")
onready var tween = $Tween
onready var click_mask = $ClickMask

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

func load_episode(episode_name):
	change_scene_to(signup.instance())

func start_game():
	S.play_track(0, false, false)
	S.play_track(1, false, false)
	S.play_track(2, false, false)
	self.rect_pivot_offset = Vector2(640,360)
	tween.interpolate_property(self, "modulate", Color.white, Color.black, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.interpolate_property(self, "rect_scale", Vector2.ONE, Vector2.ONE * 1.1, 0.5)
	tween.start()
	yield(tween, "tween_all_completed")
	get_tree().change_scene("res://Episode.tscn")
