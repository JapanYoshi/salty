extends Node
### Controls.
enum DEVICES {
	KEYBOARD,
	GAMEPAD,
	TOUCHSCREEN,
	REMOTE
}
signal gp_button(index, button, pressed)
signal gp_axis(index, axis, value)
# prevent inputs from leaking out to the game when paused
signal gp_button_paused(index, button, pressed)
signal gp_axis_paused(index, axis, value)
signal gp_connect
signal gp_disconnect

# List of registered controllers.
# By default, indices 0-3 will be occupied by the keyboard,
# and index 4 will be occupied by the "touchscreen" player.
var ctrl = []

# Called when the node enters the scene tree for the first time.
func _ready():
	pause_mode = PAUSE_MODE_PROCESS
	Input.connect("joy_connection_changed", self, "_on_input_changed")
	add_controller(DEVICES.KEYBOARD, 0, 0)
	add_controller(DEVICES.KEYBOARD, 1, 0)
	add_controller(DEVICES.KEYBOARD, 2, 0)
	add_controller(DEVICES.KEYBOARD, 3, 0)
	add_controller(DEVICES.TOUCHSCREEN, 0, 0)
	# TEST
	#print(lookup_axis(0, 0))
	#print(lookup_axis(0, 1))
	#print(lookup_axis(0, 2))
	#print(lookup_axis(0, 3))
	# END TEST

func _input(event):
	if event is InputEventJoypadButton or event is InputEventKey:
		var device = DEVICES.KEYBOARD if event is InputEventKey else DEVICES.GAMEPAD
		var which = lookup_button(
			device, event.device,
			event.physical_scancode if event is InputEventKey else event.button_index
		)
		if which.player != -1:
			print("Player %d, button %d, pressed %s" % [which.player, which.button, str(event.pressed)])
			if get_tree().paused:
				emit_signal("gp_button_paused", which.player, which.button, event.pressed)
			else:
				emit_signal("gp_button", which.player, which.button, event.pressed)
	elif event is InputEventJoypadMotion:
		var which = lookup_axis(event.device, event.axis)
		if which.player != -1:
			#print("Player %d, axis %d, value %f" % [which.player, which.axis, event.axis_value])
			if get_tree().paused:
				emit_signal("gp_axis_paused", which.player, which.button, event.axis_value)
			else:
				emit_signal("gp_axis", which.player, which.axis, event.axis_value)

func inject_button(player: int, button: int, pressed: bool):
	print("Player %d, button %d, pressed %s" % [player, button, str(pressed)])
	# remote or touchscreen can't leave pause menu
	emit_signal("gp_button", player, button, pressed)

func _on_input_changed(device: int, connected: bool):
	if connected:
#		add_controller(DEVICES.GAMEPAD, device)
		pass
	else:
		remove_controller(DEVICES.GAMEPAD, device)

func remove_controller(device_type, device):
	for i in range(len(ctrl) - 1, -1, -1):
		var c = ctrl[i]
		if c.device_type == device_type and c.device == device:
			ctrl.remove(i)

# return the new player number.
func add_controller(device_type, device, side = 0):
	for c in ctrl:
		if c.device_type == device_type and c.device == device and c.side == side:
			print("controller already registered")
			return
	var c = {
		device_type = device_type,
		device = device,
		device_name = "",
		side = side,
		map = [],
		axes = [0, 1]
	}
	if device_type == DEVICES.KEYBOARD:
		match device:
			0:
				c.map = [KEY_Q, KEY_W, KEY_E, KEY_A, KEY_S, KEY_D, KEY_ESCAPE]
			1:
				c.map = [KEY_F, KEY_G, KEY_H, KEY_V, KEY_B, KEY_N, null]
			2:
				c.map = [KEY_U, KEY_I, KEY_O, KEY_J, KEY_K, KEY_L, null]
			3:
				c.map = [KEY_KP_7, KEY_KP_8, KEY_KP_9, KEY_KP_4, KEY_KP_5, KEY_KP_6, KEY_KP_SUBTRACT]
		device = 0 # change this to ease lookup
	elif device_type == DEVICES.GAMEPAD:
		match side:
			0:
				c.map = [JOY_L, JOY_DS_X, JOY_R, JOY_DS_Y, JOY_DS_B, JOY_DS_A, JOY_START]
				c.axes = [JOY_AXIS_0, JOY_AXIS_1]
			1:
				c.map = [JOY_L2, JOY_DPAD_UP, JOY_L, JOY_DPAD_LEFT, JOY_DPAD_DOWN, JOY_DPAD_RIGHT, JOY_SELECT]
				c.axes = [JOY_AXIS_0, JOY_AXIS_1]
			2:
				c.map = [JOY_R, JOY_DS_X, JOY_R2, JOY_DS_Y, JOY_DS_B, JOY_DS_A, JOY_START]
				c.axes = [JOY_AXIS_2, JOY_AXIS_3]
	elif device_type == DEVICES.REMOTE:
		c.map = [0, 1, 2, 3, 4, 5, 6]
		c.axes = []
		c.device_name = device # contains the network ID
	ctrl.append(c)
	return len(ctrl) - 1

# Use for system keys as well.
# If a non-shared controller gets D-pad input, it returns the enums
# (standing for the integers 12 to 15 inclusive)
func lookup_button(device_type, device, index):
	var map = {
		"player": -1,
		"button": -1,
		"side": -1
	}
	for i in range(len(ctrl)):
		var c = ctrl[i]
		if c.device_type == device_type:
			if c.device_type == DEVICES.KEYBOARD or\
			(c.device_type == DEVICES.REMOTE and c.device_name == device) or\
			c.device == device:
				var matched = false
				if c.side == 0:
					matched = true
				elif c.side == 1 and index in [
					JOY_L, JOY_L2, JOY_DPAD_UP, JOY_DPAD_DOWN, JOY_DPAD_LEFT, JOY_DPAD_RIGHT, JOY_SELECT
				]:
					matched = true
				elif c.side == 2 and index in [
					0, 1, 2, 3, JOY_R, JOY_R2, JOY_START
				]:
					matched = true
				if matched and map.button == -1:
					map.player = i
					map.button = c.map.find(index)
					map.side = c.side
					# allow non-shared controller to use the D-pad as the analog stick
					if map.button == -1 and c.side == 0 and index in [
						JOY_DPAD_UP, JOY_DPAD_DOWN, JOY_DPAD_LEFT, JOY_DPAD_RIGHT
					]:
						map.button = index
	return map

# Use for joystick axes
func lookup_axis(device, axis):
	var map = {
		"player": -1,
		"axis": -1
	}
	for i in range(len(ctrl)):
		var c = ctrl[i]
		if c.device_type == DEVICES.GAMEPAD and c.device == device and axis in c.axes:
			map.player = i; map.axis = c.axes.find(axis)
	return map
