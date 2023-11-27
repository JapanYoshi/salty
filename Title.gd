extends Control

var now_focused = -1
var active = true
const desc = [
	"Play the game, alone or with friends. Play the latest episode to unlock the next one in line.",
	"What the heck is [i]Salty Trivia,[/i] anyway? Read the virtual manual to find out.",
	"Tweak settings, such as volume, phones-as-controllers capabilities, and cutscenes. (Press F11 to toggle fullscreen, by the way.)",
	"View your past progress, such as high scores and when you got them.",
	"Close the game. Bye!",
]
const desc_webpage = "Take a look at our webpage, haitouch.ga."
onready var tween = Tween.new()

const CHEAT_MENU_CODE = PoolStringArray(["ui_up", "ui_left", "ui_right", "ui_down", "ui_select", "ui_accept"])
var cheat_menu_code_index: int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	$ScreenStretch/VersionCode.text = "Version code: " + R.VERSION_CODE
	R._set_visual_quality(-1)
	add_child(tween)
	$ScreenStretch/Logo.play_intro()
	S.play_music("hiphop", 1.0)
	now_focused = -1
	change_focus_to(0)
	$ScreenStretch/About.hide()
	if R.html:
		$ScreenStretch/VBoxContainer/Button5.text = "Open webpage"

func _on_Button_mouse_entered(i):
	change_focus_to(i)

func change_focus_to(i):
	$ScreenStretch/VBoxContainer.get_child(i).grab_focus()
	if now_focused != i: # changing focus
		if now_focused != -1: # not first time
			S.play_sfx("menu_move")
		if R.html and i == len(desc) - 1:
			$ScreenStretch/Panel/RichTextLabel.bbcode_text = desc_webpage
		else:
			$ScreenStretch/Panel/RichTextLabel.bbcode_text = desc[i]
		now_focused = i

const SCROLL_SPEED: float = 1000.0
var current_scroll_speed: float = 0.0

func _process(delta):
	$ScreenStretch/About/PanelContainer/ScrollContainer.scroll_vertical += delta * current_scroll_speed


func _input(e: InputEvent):
	# cheat code
	if e.is_pressed():
		if e.is_action_pressed(CHEAT_MENU_CODE[cheat_menu_code_index]):
			cheat_menu_code_index += 1
			if cheat_menu_code_index >= len(CHEAT_MENU_CODE):
				get_tree().change_scene("res://CheatCodes.tscn")
		else:
			cheat_menu_code_index = 0
	# scrolling
	if $ScreenStretch/About.visible:
		if e is InputEventKey and e.is_echo():
			accept_event(); return
		if e.is_action_pressed("ui_down"):
			accept_event()
			$ScreenStretch/About/Close.grab_focus()
			current_scroll_speed = SCROLL_SPEED
		elif e.is_action_pressed("ui_up"):
			accept_event()
			$ScreenStretch/About/Close.grab_focus()
			current_scroll_speed = -SCROLL_SPEED
		elif (
			e.is_action_released("ui_down") or e.is_action_released("ui_up")
		):
			accept_event()
			$ScreenStretch/About/Close.grab_focus()
			current_scroll_speed = 0
		elif e.is_action_pressed("ui_cancel"):
			accept_event()
			$ScreenStretch/About/Close.grab_focus()
			_on_Close_pressed()
	else:
		if e.is_action_pressed("ui_down"):
			change_focus_to((now_focused + 1) % len(desc))
			accept_event()
		elif e.is_action_pressed("ui_up"):
			change_focus_to(posmod(now_focused - 1, len(desc)))
			accept_event()
			current_scroll_speed = 0
			accept_event()

func _scene_transition(path: String):
	release_focus()
	S.play_sfx("menu_confirm")
	tween.interpolate_property(
		self, "modulate", Color.white, Color.black, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT, 0
	)
	tween.interpolate_property(
		self, "rect_scale", Vector2.ONE, Vector2.ONE * 1.1, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT, 0
	)
	tween.start()
	yield(tween, "tween_all_completed")
# warning-ignore:return_value_discarded
	get_tree().change_scene(path)


func _on_Play_pressed():
	if not active: return
	active = false
	var timestamp = Time.get_unix_time_from_system()
	var cuss_timestamp = R.get_save_data_item("misc", "cuss_timestamp", 0)
	if cuss_timestamp > timestamp:
		S.preload_music("trolled")
		_scene_transition("res://Timeout.tscn")
	else:
		_scene_transition("res://MenuRoot.tscn")


func _on_About_pressed():
	S.play_sfx("menu_confirm")
	$ScreenStretch/About.show()
	$ScreenStretch/About/Close.grab_focus()
	pass # Replace with function body.


func _on_Options_pressed():
	S.play_sfx("menu_confirm")
	_scene_transition("res://Settings.tscn")


func _on_Save_Data_pressed():
	_scene_transition("res://SaveData.tscn")


func _on_Exit_pressed():
	# "quit" just freezes the game on html5, open the webpage instead
	if R.html:
		OS.shell_open("https://haitouch.ga")
	else:
		get_tree().notification(MainLoop.NOTIFICATION_WM_QUIT_REQUEST)


func _on_Close_pressed():
	$ScreenStretch/About.hide()
	$ScreenStretch/VBoxContainer.get_child(1).grab_focus()
