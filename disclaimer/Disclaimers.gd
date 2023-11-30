extends ColorRect
onready var sub = $SubManager
onready var anim = $ScreenStretch/r/AnimationPlayer
onready var tween = $ScreenStretch/r/Tween
var playing_cutscene: bool = false

func _ready():
	S.sub_node = sub
	S.preload_disclaimer_voice("disclaimer0")
	S.preload_disclaimer_voice("disclaimer1")
	S.preload_music("signup_extra")
	S.preload_music("signup_extra2")
	S.play_multitrack("signup_extra", 0.5, "signup_extra2", 0.0)
	S.connect("voice_end", self, "_on_voice_end")
	
	tween.interpolate_property($ScreenStretch/r, "rect_scale", Vector2(1.5, 1.5), Vector2.ONE, 0.5, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween.interpolate_property($ScreenStretch/Cover, "color", Color.black, Color(0.0, 0.0, 0.0, 0.0), 0.5, Tween.TRANS_QUAD, Tween.EASE_IN)
	tween.connect("tween_all_completed", self, "_on_SoundPlay_pressed", [], CONNECT_ONESHOT)
	tween.start()


func _input(event):
	if playing_cutscene: return
	if event.is_action_pressed("ui_select"):
		_page0()
		accept_event()
		return
	if event.is_action_pressed("ui_cancel"):
		_on_SoundPlay_pressed()
		accept_event()
		return


func _on_voice_end(id):
	match id:
		"disclaimer0":
			anim.play("reset", 0.125)
		"disclaimer1":
			_page1()
		"disclaimer2":
			_page2()
		"disclaimer3":
			_page3()
		"disclaimer4":
			_page4()
		"disclaimer5":
			_fade_out()
		_:
			printerr("Unexpected voice end ID: " + id)


func _on_SoundPlay_pressed():
	S.stop_voice("disclaimer0")
	anim.stop(true)
	S.play_voice("disclaimer0")
	anim.play("play")


func _on_SoundOK_pressed():
	_page0()


func _on_SkipDisclaimer_pressed():
	_end_onboarding()


func _page0():
	S.play_track(0, 0.0)
	S.play_track(1, 0.5)
	anim.stop(true)
	anim.play("transition0")
	S.stop_voice("disclaimer0")
	S.unload_voice("disclaimer0")
	S.play_voice("disclaimer1")
	S.preload_disclaimer_voice("disclaimer2")


func _page1():
	anim.play("transition1")
	S.unload_voice("disclaimer1")
	S.play_voice("disclaimer2")
	S.preload_disclaimer_voice("disclaimer3")
	var timer = get_tree().create_timer(11.0)
	timer.connect("timeout", self, "_on_page1_timer_end")


func _on_page1_timer_end():
	anim.play("sticker")


func _page2():
	anim.play("transition2")
	S.unload_voice("disclaimer2")
	S.play_voice("disclaimer3")
	S.preload_disclaimer_voice("disclaimer4")


func _page3():
	anim.play("transition3")
	S.unload_voice("disclaimer3")
	S.play_voice("disclaimer4")
	S.preload_disclaimer_voice("disclaimer5")


func _page4():
	anim.play("transition4")
	$ScreenStretch/r/panel4/AnimationPlayer.play("wave")
	S.unload_voice("disclaimer4")
	S.play_voice("disclaimer5")


func _fade_out():
	S.unload_voice("disclaimer5")
	S.play_track(1, 0.0)
	tween.interpolate_property($ScreenStretch/r, "rect_scale", Vector2.ONE, Vector2(1.5, 1.5), 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.interpolate_property($ScreenStretch/Cover, "color", Color(0.0, 0.0, 0.0, 0.0), Color.black, 0.5, Tween.TRANS_QUAD, Tween.EASE_OUT)
	tween.connect("tween_all_completed", self, "_end_onboarding")
	tween.start()


func _end_onboarding():
	R.set_save_data_item("misc", "never_seen_disclaimer", false)
	R.save_save_data()
	get_tree().change_scene("res://Title.tscn")
