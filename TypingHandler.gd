extends Control

onready var tbox = $TextBox
signal text_confirmed(text)
# For keyboards with a "123" shift state (which ends up being just DaisyWheel)
var num: bool = false
var character_limit: int = 0
var can_type: bool = false

# For actual keyboard on computer.
onready var text_filter = RegEx.new()
# For traditional grid keyboard.
var kb_page: int = 0
var kb_focus_x: int = 0
var kb_focus_y: int = 0
# For DaisyWheel keyboard.
onready var dw_pages = [
	$DW/KbPage0,
	$DW/KbPage1,
	$DW/KbPage2,
	$DW/KbPage3,
	$DW/KbPage4,
	$DW/KbPage5,
	$DW/KbPage6,
	$DW/KbPage7,
	$DW/KbPage8
]
onready var dw_tween = $DW/Tween
var dw_base_scale: float = 0.5
var dw_max_scale: float = 0.75
var dw_page: int = 0
# For Spiral keyboard.
onready var sp_pages = [
	$SP/Box1,
	$SP/Box2,
	$SP/Box3,
	$SP/Box4,
	$SP/Box5,
	$SP/Box6,
	$SP/Box7,
	$SP/Box8
]
onready var sp_tween = $SP/Tween
var sp_base_scale: float = 1.0
var sp_max_scale: float = 1.5
var sp_index: int = 0
var sp_page: int = 0
# For interpreting analog stick movement.
var stick_deadzone: float = 0.4
var stick_max: float = 0.6
var axis: Vector2 = Vector2.ZERO
# To tell which type of keyboard is active and by which player.
# 0: Grid, 1: DaisyWheel, 2: Spiral.
var which_keyboard: int = -1
# Player number (starts at 0).
var which_player: int = -1
# Input slot to expect.
var which_input: int = -1

var config = {
	dw_neutral = ["left", "delete", "right", "space"],
	dw_main = [
		["A", "B", "C", "D"],
		["E", "F", "G", "H"],
		["I", "J", "K", "L"],
		["M", "N", "O", "P"],
		["Q", "R", "S", "T"],
		["U", "V", "W", "X"],
		["Y", "Z", ".", ","],
		["?", "!", "'", "-"],
		["num", "submit"]
	],
	dw_num = [
		["0", "1", "2", "3"],
		["4", "5", "6", "7"],
		["8", "9", "-", "/"],
		["", "", "", ""],
		["", "", "", ""],
		["", "", "", ""],
		["", "", "", ""],
		["", "", "", ""],
		["num", "submit"]
	],
	KB_WIDTH = 10,
	KB_HEIGHT = 5,
	kb_main = [
		'1', '2', '3', '4', '5', '6', '7', '8', '9', '0',
		'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'delete',
		'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', "'",
		'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'left', 'right',
		'.', ',', '?', '!', '-', '/',
	],
	sp_main = [
		'space', 'A', 'B', 'C', 'D', 'E', 'F', 'G',
		'space', 'H', 'I', 'J', 'K', 'L', 'M', 'N',
		'space', 'O', 'P', 'Q', 'R', 'S', 'T', 'U',
		'space', 'V', 'W', 'X', 'Y', 'Z', '.', ',',
		'space', '?', '!', '-', "'", '1', '2', '3',
		'space', '4', '5', '6', '7', '8', '9', '0',
	],
	sp_shoulder = [
		'delete', 'submit'
	]
}

const keycap_text = {
	"space": "␣",
	"left": "⇽",
	"right": "⇾",
	"delete": "⌫",
	"submit": "✓",
	"num": "№"
}

func key_text(which: String):
	if which in keycap_text:
		return keycap_text[which]
	return which

func submit():
	can_type = false
	emit_signal("text_confirmed", tbox.get_text().strip_edges())
	$Anim.play("Hide")
#	print("Signal remote_typing was connected to ", len(Ws.get_signal_connection_list('remote_typing')), " nodes.")
	if which_keyboard == 3:
		Fb.disconnect('remote_typing', self, 'remote_typing')

func reset_state():
	which_player = -1
	which_input = -1
	which_keyboard = -1
	num = false
	tbox.set_text("")
	$KB.hide()
	$DW.hide()
	$SP.hide()
	$NA.hide()
	_sp_init()

func _sp_init():
	# reset Spiral keyboard
	sp_set_page(0)
	sp_index = 0
	dw_page = 1
	sp_set_page(7)
	sp_set_page(1)
	sp_set_page(3)
	sp_set_page(5)
	sp_set_page(0)

func _key_pressed(which: String):
	if !can_type: return
	match which:
		"left", "right":
			tbox.set_cursor_position(
				tbox.get_cursor_position() + (
					1 if which == "right" else -1
				)
			)
			sfx_press()
		"delete":
			tbox.delete_char_at_cursor()
			sfx_delete()
		"space":
			tbox.append_at_cursor(" ")
			sfx_press()
		"num":
			_toggle_num()
			sfx_press()
		"submit":
			submit()
		_:
			tbox.append_at_cursor(which)
			sfx_press()

func _kb_focused():
	if kb_focus_y == config.KB_HEIGHT - 1:
		if kb_focus_x >= 8:
			return "submit"
		if kb_focus_x >= 6:
			return "space"
	return config.kb_main[kb_focus_y * config.KB_WIDTH + kb_focus_x]

func kb_set_page(new_page):
	if new_page == kb_page:
		return
	match new_page:
		0:
			pass
		1:
			if !kb_page in [2, 8]:
				kb_move(MARGIN_TOP)
		2:
			if !kb_page in [1, 8]:
				kb_move(MARGIN_TOP)
			if !kb_page in [3, 4]:
				kb_move(MARGIN_RIGHT)
		3:
			if !kb_page in [2, 4]:
				kb_move(MARGIN_RIGHT)
		4:
			if !kb_page in [2, 3]:
				kb_move(MARGIN_RIGHT)
			if !kb_page in [5, 6]:
				kb_move(MARGIN_BOTTOM)
		5:
			if !kb_page in [4, 6]:
				kb_move(MARGIN_BOTTOM)
		6:
			if !kb_page in [4, 5]:
				kb_move(MARGIN_BOTTOM)
			if !kb_page in [7, 8]:
				kb_move(MARGIN_LEFT)
		7:
			if !kb_page in [6, 8]:
				kb_move(MARGIN_LEFT)
		8:
			if !kb_page in [6, 7]:
				kb_move(MARGIN_LEFT)
			if !kb_page in [1, 2]:
				kb_move(MARGIN_TOP)
	kb_page = new_page

func kb_move(margin: int):
	# is the text box selected by default?
	if $TextBox.has_focus():
		kb_focus_x = 0
		kb_focus_y = 0
	# no, move between the keys
	else:
		match margin:
			MARGIN_RIGHT:
				if kb_focus_y == 4 and kb_focus_x >= 6:
					kb_focus_x = (kb_focus_x + 2) % config.KB_WIDTH
				else:
					kb_focus_x = (kb_focus_x + 1) % config.KB_WIDTH
			MARGIN_LEFT:
				if kb_focus_y == 4 and (kb_focus_x >= 8 or kb_focus_x == 0):
					kb_focus_x = posmod(kb_focus_x - 2, config.KB_WIDTH)
				else:
					kb_focus_x = posmod(kb_focus_x - 1, config.KB_WIDTH)
			MARGIN_BOTTOM:
				kb_focus_y = (kb_focus_y + 1) % config.KB_HEIGHT
			MARGIN_TOP:
				kb_focus_y = posmod(kb_focus_y - 1, config.KB_HEIGHT)
		if kb_focus_y == 4:
			if kb_focus_x == 7:
				kb_focus_x = 6
			elif kb_focus_x == 9:
				kb_focus_x = 8
	#print("Keyboard focus: %d, %d" % [kb_focus_x, kb_focus_y])
	
	if kb_focus_y == 4:
		if kb_focus_x >= 8:
			$KB/KeySubmit.grab_focus()
		elif kb_focus_x >= 6:
			$KB/KeySpace.grab_focus()
		else:
			$KB/Grid.get_child(kb_focus_y * config.KB_WIDTH + kb_focus_x).grab_focus()
	else:
		$KB/Grid.get_child(kb_focus_y * config.KB_WIDTH + kb_focus_x).grab_focus()
	sfx_move()

func _button_pressed(device, which_button, pressed):
	if ( # wrong player
		which_input != device
	) or ( # if expecting input from physical keyboard, don't do this part
		which_input < 4
	) or ( # invalid button
		which_button == -1
	) or ( # only process button presses, not releases
		!pressed
	) or ( # don't process if the transitions are playing
		$Anim.is_playing()
	):
		return
#	if C.ctrl[device].device_type == C.DEVICES.KEYBOARD:
#		return
	if which_keyboard == 0:
		if which_button == 0:
			_key_pressed("space")
		elif which_button == 1:
			_key_pressed("submit")
		elif which_button == 2:
			_key_pressed("delete")
		else:
			_key_pressed(
				_kb_focused()
			)
	elif which_keyboard == 1:
		which_button = {
			-1: -1,
			0: 4,
			1: 1,
			2: 5,
			3: 0,
			4: 3,
			5: 2,
			6: 6,
		}[which_button]
		if which_button < 4:
			# Face buttons 0~3 in order of L U R D
			if dw_page > 0:
				_key_pressed(
					config.dw_num[dw_page - 1][which_button]
				if num else
					config.dw_main[dw_page - 1][which_button]
				)
			else:
				_key_pressed(
					config.dw_neutral[which_button]
				)
		else:
			# Shoulder buttons 4 if L, 5 if R
			_key_pressed(
				config.dw_num[8][which_button - 4]
			if num else
				config.dw_main[8][which_button - 4]
			)
	elif which_keyboard == 2:
		match which_button:
			0:
				_key_pressed(config.sp_shoulder[0])
			2:
				_key_pressed(config.sp_shoulder[1])
			_:
				_key_pressed(config.sp_main[sp_index])
	elif which_keyboard == 3:
		submit()

func _axis_tilted(which_input, which_axis, axis_value):
	if self.which_input != which_input:
		return
	if which_axis == 1:
		axis.y = axis_value
	else:
		axis.x = axis_value
	if which_keyboard == 1:
		$DW/KbBase/KbStick.position = (Vector2.ONE + axis.limit_length(1.0)) * 128.0
	else:
		$SP/KbBase/KbStick.position = (Vector2.ONE + axis.limit_length(1.0)) * 128.0
	var axis_magn = axis.length()
	if axis_magn < stick_deadzone:
#		print("Center")
		if which_keyboard == 0:
			kb_set_page(0)
		elif which_keyboard == 1:
			dw_set_page(0)
		elif which_keyboard == 2:
			sp_set_page(0)
	elif axis_magn < stick_max:
#		print("Transitioning")
		pass
	else:
#		print("Outer")
		var new_page = 5 + int(round(axis.angle_to(Vector2.DOWN) * -4.0 / PI))
		if new_page == 9:
			new_page = 1
		if which_keyboard == 0:
			kb_set_page(new_page)
		if which_keyboard == 1:
			dw_set_page(new_page)
		elif which_keyboard == 2:
			sp_set_page(new_page)

# Use dw_page as the last page EXCLUDING the center.
func sp_set_page(new_page: int):
	if new_page == sp_page:
		return
	# find if the index will change
	if new_page != 0:
		# positive if clockwise, negative if counterclockwise
		var diff: int = posmod(4 + new_page - dw_page, 8)
		if diff < 0:
			diff = -diff
		diff -= 4
		sp_index = posmod(sp_index + diff, len(config.sp_main))
		#print("Letter index ", sp_index)
		for i in range(5):
			var index_to_change = posmod(sp_index + i * (1 if diff >= 0 else -1), 8)
			sp_relabel(i, index_to_change, diff > 0)
	# set size of each letter
	sp_tween.seek(9999.0)
	sp_tween.remove_all()
	if new_page == 0:
		for e in sp_pages:
			sp_tween.interpolate_property(
				e,
				"rect_scale",
				e.rect_scale,
				Vector2.ONE * sp_base_scale,
				0.1,
				Tween.TRANS_CUBIC,
				Tween.EASE_OUT
			)
			for c in [e.get_node("Last"), e.get_node("Next")]:
				sp_tween.interpolate_property(
					c,
					"scale",
					c.scale,
					Vector2.ONE * 0.375,
					0.1,
					Tween.TRANS_CUBIC,
					Tween.EASE_OUT
				)
	else:
		if $SP.visible:
			sfx_move()
		for i in range(8):
			var difmod = abs(posmod(i - (new_page - 1), 8) - 4)
			#print(difmod)
			var new_scale = (difmod - 3) * (sp_max_scale - sp_base_scale) * 0.5 + sp_base_scale
			if difmod < 3.0:
				new_scale = (difmod / 3.0) * sp_base_scale
			sp_tween.interpolate_property(
				sp_pages[i],
				"rect_scale",
				sp_pages[i].rect_scale,
				Vector2.ONE * new_scale,
				0.1,
				Tween.TRANS_CUBIC,
				Tween.EASE_OUT
			)
			if sp_page == 0:
				for c in [sp_pages[i].get_node("Last"), sp_pages[i].get_node("Next")]:
					sp_tween.interpolate_property(
						c,
						"scale",
						c.scale,
						Vector2.ZERO,
						0.1,
						Tween.TRANS_CUBIC,
						Tween.EASE_OUT
					)
	sp_tween.start()
	sp_page = new_page
	if sp_page != 0:
		dw_page = sp_page

func sp_relabel(i, index_to_change, clockwise):
	var index = sp_index + i * (1 if clockwise else -1)
	#print(
	#	"Change label ", index_to_change, " to letter ", index,
	#	", which is ", config.sp_main[posmod(index, len(config.sp_main))]
	#)
	sp_pages[index_to_change].get_node("L1").text = key_text(
		config.sp_main[
			posmod(
				index
			, len(config.sp_main))
		]
	);
	sp_pages[index_to_change].get_node("Last/L2").text = key_text(
		config.sp_main[
			posmod(
				index - 8
			, len(config.sp_main))
		]
	);
	sp_pages[index_to_change].get_node("Next/L3").text = key_text(
		config.sp_main[
			posmod(
				index + 8
			, len(config.sp_main))
		]
	)

func dw_set_page(new_page: int):
	if new_page == dw_page:
		return
	dw_tween.seek(9999.0)
	dw_tween.remove_all()
	dw_tween.interpolate_property(
		dw_pages[dw_page],
		"rect_scale",
		dw_pages[dw_page].rect_scale,
		Vector2.ONE * dw_base_scale,
		0.2,
		Tween.TRANS_BACK,
		Tween.EASE_OUT)
	dw_tween.interpolate_property(
		dw_pages[new_page],
		"rect_scale",
		dw_pages[new_page].rect_scale,
		Vector2.ONE * dw_max_scale,
		0.2,
		Tween.TRANS_BACK,
		Tween.EASE_OUT)
	dw_tween.start()
	dw_page = new_page
	sfx_move()

func _toggle_num():
	num = !num
	if which_keyboard == 1:
		var i = -1
		for e in $DW.get_children():
			if e.name == "KbBase":
				e.get_node("L").get_child(0).set_text(
					key_text(
						config.dw_num[8][0]
					if num else
						config.dw_main[8][0]
					)
				)
				e.get_node("R").get_child(0).set_text(
					key_text(
						config.dw_num[8][1]
					if num else
						config.dw_main[8][1]
					)
				)
			else:
				var j = 0
				for c in e.get_children():
					if c is Label:
						if i == -1:
							pass
						else:
							c.text = key_text(
								config.dw_num[i][j] if num else
								config.dw_main[i][j]
							)
						#print(c.text)
						j += 1
				i += 1

func _ready():
	hide()
	reset_state()
	# filtering text
	text_filter.compile(
		"[^ 0-9A-Z.,'!?\\-/]+"
	)
	# touch keyboard
	var i = 0
	for e in $KB/Grid.get_children():
		e.set_text(key_text(config.kb_main[i]))
		e.connect("pressed", self, "_key_pressed", [config.kb_main[i]])
		i += 1
	$KB/KeySpace.connect("pressed", self, "_key_pressed", ["space"])
	$KB/KeySubmit.connect("pressed", self, "_key_pressed", ["submit"])
	# DaisyWheel
	i = -1
	for e in $DW.get_children():
		if e.name == "KbBase":
			e.get_node("L").get_child(0).set_text(
				key_text(
					config.dw_main[8][0]
				)
			)
			e.get_node("R").get_child(0).set_text(
				key_text(
					config.dw_main[8][1]
				)
			)
		else:
			var j = 0
			for c in e.get_children():
				if c is Label:
					if i == -1:
						c.text = key_text(config.dw_neutral[j])
					else:
						c.text = key_text(config.dw_main[i][j])
					j += 1
			i += 1
	#for j in range(8):
	#	sp_relabel(j, j, 1)
	$SP/KbBase/L/L1.set_text(key_text(
		config.sp_shoulder[0]
	))
	$SP/KbBase/R/L1.set_text(key_text(
		config.sp_shoulder[1]
	))
	# get ready to receive input
	C.connect("gp_button", self, "_button_pressed")
	C.connect("gp_axis", self, "_axis_tilted")
	# TEST: Start keyboard
	#start_keyboard(1, 0)

func start_keyboard(
	which_keyboard: int = 0, which_player: int = 0, which_input: int = 0,
	character_limit: int = 0
):
	self.which_keyboard = which_keyboard
	self.which_player = which_player
	self.which_input = which_input
	if which_player != -1:
		$PlayerNumber.set_text("%d" % (which_player + 1))
		$PlayerNumber.show()
	else:
		$PlayerNumber.hide()
	$TextBox.max_length = character_limit
	$TextBox/CensorRect.hide()
	match which_keyboard:
		0:
			$KB.show()
			# hide shortcut labels if not gamepad player
			if which_input <= 4:
				$KB/Label.hide(); $KB/Label2.hide(); $KB/Label3.hide()
			else:
				$KB/Label.show(); $KB/Label2.show(); $KB/Label3.show()
		1:
			$DW.show()
		2:
			_sp_init()
			$SP.show()
			pass
		3:
			$NA.show()
			Fb.connect('remote_typing', self, 'remote_typing')
	$Anim.play("Show")
	yield($Anim, "animation_finished")
	can_type = true
	if which_keyboard == 0:
		$TextBox.grab_focus()

func sfx_move():
	if which_keyboard != -1:
		S.play_sfx("key_move", (R.rng.randi_range(16, 19)) / 16.0)

func sfx_press():
	if which_keyboard != -1:
		S.play_sfx("key_press", (R.rng.randi_range(16, 19)) / 16.0)

func sfx_delete():
	if which_keyboard != -1:
		S.play_sfx("key_delete", (R.rng.randi_range(16, 19)) / 16.0)

func _on_Anim_animation_finished(anim_name):
	if anim_name == "Hide":
		reset_state()

func _on_physical_enter_key(new_text):
	_key_pressed("submit")
	$TextBox.release_focus() # lose focus from textbox

func _on_TextBox_text_changed(new_text):
	var p = tbox.caret_position
	tbox.text = tbox.text.to_upper()
	var result = text_filter.search(tbox.text)
	# this code assumes that, at most, one consecutive patch of invalid characters is added at once
	if result != null:
		# invalid character was added
		if result.get_start() < p:
			p -= 1
		tbox.text = tbox.text.left(result.get_start()) + tbox.text.substr(result.get_end())
		S.play_sfx("menu_stuck")
	else:
		sfx_press()
	tbox.caret_position = p

func remote_typing(new_text, from):
	if (from != which_player):
		return
	tbox.text = new_text.to_upper()
	var result = text_filter.search(tbox.text)
	if result != null:
		S.play_sfx("menu_stuck")
		while result != null:
			# invalid character was added
			tbox.text = tbox.text.left(result.get_start()) + tbox.text.substr(result.get_end())
			result = text_filter.search(tbox.text)
	else:
		sfx_press()
	_censor_box()

func _censor_box():
	var matched = R.censor_regex.search(tbox.text)
	if null != matched:
		$TextBox/CensorRect.show()
	else:
		$TextBox/CensorRect.hide()

func _input(event):
	if which_keyboard != -1 and (
		event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or
		event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or
		event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
	):
		if C.ctrl[which_input].device_type != C.DEVICES.KEYBOARD:
			accept_event()
			C._input(event) # let the controller handler parse it
		elif event is InputEventKey and (
			event.physical_scancode == KEY_ENTER or
			event.physical_scancode == KEY_KP_ENTER
		) and C.ctrl[which_input].device_type != C.DEVICES.KEYBOARD:
			accept_event()
			submit()
