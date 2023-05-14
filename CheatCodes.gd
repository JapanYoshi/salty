extends ColorRect

class CheatCode:
	var sequence: PoolByteArray
	var cheat_code: String
	var run_once: bool
	var cheat_name: String
	var description: String
	var on_string: String
	var off_string: String
	func _init(sequence: PoolByteArray, cheat_code: String = "new_cheat", run_once: bool = false, cheat_name: String = "New Cheat Code", description: String = "No description", on_string: String = "on", off_string: String = "off"):
		self.sequence = sequence
		self.cheat_code = cheat_code
		self.run_once = run_once
		self.cheat_name = cheat_name
		self.description = description
		self.on_string = on_string
		self.off_string = off_string

const CHEAT_CODE_LENGTH = 8
onready var CHEAT_CODE_INPUTS = [ # classes may not be const
	CheatCode.new(
		PoolByteArray([0, 1, 3, 3, 1, 2, 2, 0]),
		"no_pause_penalty",
		false,
		"No Pause Penalty",
		"Normally, you can only pause up to a certain number of times per game before you get kicked out. This cheat code disables this feature, so that you can play with time to your heart’s content."
	),
	CheatCode.new(
		PoolByteArray([1, 0, 0, 2, 1, 3, 3, 0]),
		"no_wrong_penalty",
		false,
		"No Wrong Penalty",
		"Normally, you lose money when you answer wrong. Enabling this cheat code will prevent you from these penalties."
	),
	CheatCode.new(
		PoolByteArray([1, 0, 2, 0, 3, 1, 2, 3]),
		"unlock_episode_004",
		true,
		"Unlock Episode 4",
		"You unlocked Episode 4 without playing Episodes 1 through 3!"
	),
	CheatCode.new(
		PoolByteArray([2, 1, 3, 0, 0, 1, 2, 2]),
		"unlock_all_episodes",
		true,
		"Unlock All Episodes",
		"You unlocked all episodes unlocked without playing the game!"
	),
	CheatCode.new(
		PoolByteArray([3, 1, 3, 0, 2, 2, 2, 0]),
		"unlock_all_achievements",
		true,
		"Unlock All Achievements",
		"You got all achievements unlocked instantly!"
	),
]
var CHEAT_CODE_BUTTONS = []
const CHEAT_CODE_INDEX = {
	"ui_select": 0,
	"ui_action": 1,
	"ui_accept": 2,
	"ui_cancel": 3,
}
var enabled_cheat_codes: PoolByteArray = []
var input_values: PoolByteArray = PoolByteArray()
var input_mode: int = 0

var unlocked_temp: Array = R.get_save_data_item("misc", "cheat_codes_unlocked", [])
var active_temp: Array = R.get_settings_value("cheat_codes_active")

var savedata_changed: bool = false
var settings_changed: bool = false

var focus_index: int = -1

onready var vbox = $ScreenStretch/CheatCodeList/Scroll/VBoxContainer
onready var vbox_children = {}
onready var title = $ScreenStretch/CheatCodeList/Details/V/Name
onready var desc = $ScreenStretch/CheatCodeList/Details/V/Desc
onready var tween = $ScreenStretch/Tween
onready var pg_list = $ScreenStretch/CheatCodeList
onready var pg_pad = $ScreenStretch/CheatCodePad
onready var arcade = $ScreenStretch/CheatCodePad/CheatArcade
onready var code_bg = $ScreenStretch/CheatCodePad/CheatArcade/Screen/TextBox
onready var code_box = $ScreenStretch/CheatCodePad/CheatArcade/Screen/TextBox/Code
onready var retry_timer = $ScreenStretch/CheatCodePad/RetryTimer
onready var bg = $ScreenStretch/CheatCodePad/Bg

func _get_unlock_state(cheat_code: String) -> bool:
	return cheat_code in unlocked_temp

func _get_active_state(cheat_code: String) -> bool:
	return cheat_code in active_temp

func _set_active_state(cheat_code: String, activated: bool):
	if activated:
		if active_temp.has(cheat_code): return
		active_temp.push_back(cheat_code)
		settings_changed = true
	else:
		var i = active_temp.find(cheat_code)
		if i == -1: return
		active_temp.remove(i)
		settings_changed = true

func _unlock_cheat(cc: CheatCode):
	_cheat_get_dialog(cc)
	if cc.run_once:
		match cc.cheat_code:
			"unlock_episode_004":
				savedata_changed = savedata_changed or R.unlock_episode("ep_004")
			"unlock_all_episodes":
				savedata_changed = savedata_changed or R.unlock_all_episodes()
			"unlock_all_achievements":
				var achievement_list = Loader.get_achievement_list()
				for k in achievement_list.keys():
					var existing_save = R.get_save_data_item("achievements", k, {progress=0, achieved=false, date=0})
					if existing_save.achieved: continue
					savedata_changed = true
					R.set_save_data_item("achievements", k, {
						"progress": achievement_list[k].steps,
						"achieved": true,
						"date": 0,
					})
			_:
				printerr("Unimplemented run_once cheat!")
		return
	unlocked_temp.push_back(cc.cheat_code)
	var element = vbox_children[cc.cheat_code]
	element.get_node("VBox/HSplit/Label").set_text(cc.cheat_name)
	element.get_node("VBox/HSplit/value").text = cc.off_string
	element.get_node("VBox/HSplit/SBox").disabled = false

func _cheat_get_dialog(cc: CheatCode):
	var box = $ScreenStretch/CheatCodePad/CheatGet
	box.get_node("name").set_text(cc.cheat_name)
	if cc.run_once:
		box.get_node("desc").set_text(cc.description)
	else:
		box.get_node("desc").set_text("Try enabling the cheat code you just got by selecting it in the cheat code list.")
	var btween = box.get_node("Tween")
	btween.stop_all()
	btween.interpolate_property(box, "rect_scale", Vector2.ZERO, Vector2.ONE, 0.5, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
	btween.interpolate_property(box, "rect_scale", Vector2.ONE, Vector2.ZERO, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT, 3)
	btween.start()

func _ready():
	S.play_music("main_theme", 1.0)
	# get list of seen and activated cheat codes (todo)
#	var _unlocked = R.get_save_data_item("cheat_codes_unlocked", [])
#	if _unlocked is Array:
#		unlocked_temp = _unlocked
#	else:
#		unlocked_temp = []
	# populate list of cheat codes
	for i in range(len(CHEAT_CODE_INPUTS)):
		if CHEAT_CODE_INPUTS[i].run_once: continue
		CHEAT_CODE_BUTTONS.push_back(i)
		var element: Control = vbox.get_node("Bool")
		if i > 0:
			element = element.duplicate()
			vbox.add_child(element)
		element.connect("mouse_entered", self, "_change_focus", [len(vbox_children)])
		var checkbox = element.get_node("VBox/HSplit/SBox") as CheckBox
		if _get_unlock_state(CHEAT_CODE_INPUTS[i].cheat_code):
			element.get_node("VBox/HSplit/Label").set_text(CHEAT_CODE_INPUTS[i].cheat_name)
			element.get_node("VBox/HSplit/value").text = CHEAT_CODE_INPUTS[i].on_string if _get_active_state(CHEAT_CODE_INPUTS[i].cheat_code) else CHEAT_CODE_INPUTS[i].off_string
			checkbox.disabled = false
			checkbox.set_pressed_no_signal(_get_active_state(CHEAT_CODE_INPUTS[i].cheat_code))
		else:
			element.get_node("VBox/HSplit/Label").set_text("Enter password to unlock this cheat code.")
			element.get_node("VBox/HSplit/value").text = "N/A"
			checkbox.disabled = true
			checkbox.set_pressed_no_signal(false)
		checkbox.connect("toggled", self, "_on_check_toggled", [i])
		checkbox.connect("focus_entered", self, "_change_focus", [i])
		vbox.move_child(element, i + 1)
		vbox_children[CHEAT_CODE_INPUTS[i].cheat_code] = element
	
	_change_focus(0, false)
	pass

func _change_focus(index: int, sound: bool = true):
	if focus_index == index: return
	focus_index = index
	if sound:
		S.play_sfx("menu_move")
	var cc = CHEAT_CODE_INPUTS[CHEAT_CODE_BUTTONS[index]]
	vbox_children[cc.cheat_code].get_node("VBox/HSplit/SBox").grab_focus()
	if _get_unlock_state(cc.cheat_code):
		$ScreenStretch/CheatCodeList/Details/V/Name.text = cc.cheat_name
		$ScreenStretch/CheatCodeList/Details/V/Desc.bbcode_text = (cc.description)
	else:
		$ScreenStretch/CheatCodeList/Details/V/Name.set_text("Enter password to unlock this cheat code.")
		$ScreenStretch/CheatCodeList/Details/V/Desc.bbcode_text = "Press the → key on your keyboard, or press right on your D-pad or analog stick, to begin entering the cheat code. Alternatively, you can click this description window."
		

func _on_check_toggled(button_pressed: bool, index: int):
	var cc = CHEAT_CODE_INPUTS[CHEAT_CODE_BUTTONS[index]]
	var element = vbox_children[cc.cheat_code]
	
	_set_active_state(cc.cheat_code, button_pressed)
	S.play_sfx("rush_o" + ("n" if button_pressed else "ff"))
	element.get_node("VBox/HSplit/value").text = cc.on_string if button_pressed else cc.off_string

func _on_option_mouse_entered(index):
	var element = vbox_children[CHEAT_CODE_INPUTS[CHEAT_CODE_BUTTONS[index]].cheat_code]
	var cb: Node = element.get_node("VBox/HSplit/SBox") as CheckBox
	cb.grab_focus()
	_change_focus(index)

func _input(event):
	if tween.is_active(): return
	if input_mode == 0:
		_input_menu_movement(event)
	elif input_mode == 1:
		_input_cheat_code(event)

func _paginate(to_pad: bool):
	if input_mode == int(to_pad): return
	if !retry_timer.is_stopped():
		retry_timer.stop()
	tween.stop_all()
	tween.interpolate_property(
		pg_list, "rect_position",
		Vector2(0 if to_pad else -1280, 0),
		Vector2(-1280 if to_pad else 0, 0),
		0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.interpolate_property(
		bg, "rect_position",
		Vector2(-7 if to_pad else -313, -129 if to_pad else -584),
		Vector2(-313 if to_pad else -7, -584 if to_pad else -129),
		0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.interpolate_property(
		bg, "rect_scale",
		Vector2.ONE * (0.75 if to_pad else 1),
		Vector2.ONE * (1 if to_pad else 0.75),
		0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.interpolate_property(
		arcade, "position",
		Vector2(800 if to_pad else 256, -128 if to_pad else -292),
		Vector2(256 if to_pad else 800, -292 if to_pad else -128),
		0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.start()
	input_mode = int(to_pad)
	if !to_pad:
		focus_index = -1
		_change_focus(0, false)

func _input_menu_movement(event):
	if event.is_action_pressed("ui_right"):
		_paginate(true); return
	if event.is_action_pressed("ui_cancel"):
		_back_to_title(); return
	pass

func _input_cheat_code(event):
	var consumed: bool = false
	for k in CHEAT_CODE_INDEX.keys():
		if event.is_action_pressed(k):
			consumed = true
			_on_cheat_button_pressed(CHEAT_CODE_INDEX[k])
			break
	if consumed:
		print("Cheat code queue size is ", len(input_values))
	else:
		if event.is_action_pressed("ui_left"):
			_paginate(false)

func _on_cheat_button_pressed(i: int):
	if len(input_values) >= CHEAT_CODE_LENGTH: return
	S.play_sfx("cheat_input", [1.125, 1.25, 1.40625, 1.5][i])
	code_box.get_child(len(input_values)).play(str(i))
	arcade.get_child(i).set_frame(i + 4)
	get_tree().create_timer(0.1).connect("timeout", self, "_on_cheat_button_timeout", [i])
	input_values.push_back(i)
	if len(input_values) == CHEAT_CODE_LENGTH:
		_evaluate_cheat_code()

func _on_cheat_button_timeout(i: int):
	arcade.get_child(i).set_frame(i)

func _evaluate_cheat_code():
	var matched: bool = false
	for e in CHEAT_CODE_INPUTS:
		if e.sequence == input_values:
			matched = true
			printt(e.cheat_name, e.description)
			_unlock_cheat(e)
			break
	input_mode = 2
	if matched:
		S.play_sfx("cheat_valid")
	else:
		S.play_sfx("cheat_invalid")
		tween.stop_all()
		var time_unit = 1.0 / 30.0
		var original_x = code_bg.position.x
		var shakes = 8
		for i in range(0, shakes):
			tween.interpolate_property(
				code_bg, "position:x",
				original_x - 1, original_x + 1,
				time_unit, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT,
				(i * 2) * time_unit
			)
			tween.interpolate_property(
				code_bg, "position:x",
				original_x + 1, original_x - 1,
				time_unit, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT,
				(i * 2 + 1) * time_unit
			)
		tween.interpolate_property(
			code_bg, "position:x",
			original_x - 1, original_x,
			time_unit, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT,
			shakes * 2 * time_unit
		)
		tween.start()
	retry_timer.start()


func _on_RetryTimer_timeout():
	input_values.resize(0)
	for i in range(CHEAT_CODE_LENGTH):
		code_box.get_child(i).play("default")
	input_mode = 1


func _on_Details_gui_input(event):
	if event is InputEventMouseButton and event.is_pressed() and event.button_index == BUTTON_LEFT:
		_paginate(true)


func _back_to_title():
	input_mode = -1
	S.play_track(0, 0)
	
	tween.interpolate_property(pg_pad, "rect_scale", Vector2.ONE, Vector2.ONE * 1.05, 0.5)
	tween.interpolate_property(pg_list, "rect_scale", Vector2.ONE, Vector2.ONE * 1.2, 0.5)
	tween.interpolate_property(self, "modulate", Color.white, Color.black, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.start()
	yield(get_tree().create_timer(0.5), "timeout")
	if savedata_changed:
		R.set_save_data_item("misc", "cheat_codes_unlocked", unlocked_temp)
		R.save_save_data()
	if settings_changed:
		R.set_settings_value("cheat_codes_active", active_temp)
		R.save_settings()
# warning-ignore:return_value_discarded
	get_tree().change_scene("res://Title.tscn")
