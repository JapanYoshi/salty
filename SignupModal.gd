extends ColorRect

var current_device_type: int = -1
var current_device_index: int = -1
var current_keyboard: int = 0
var player_number: int = -1
var remote_nickname = ""
enum PHASE {
	NONE,
	CHOOSE_KB,
	NAME_ENTRY
}
var current_phase = ""

var stick_deadzone: float = 0.4
var stick_max: float = 0.6
var axis: Vector2 = Vector2.ZERO

# Called when the node enters the scene tree for the first time.
func _ready():
	current_device_type = -1
	current_device_index = -1
	current_phase = PHASE.NONE
	player_number = -1
	C.connect("gp_button", self, "gp_button")
	C.connect("gp_axis", self, "gp_axis")
	get_parent().get_node("KeyboardBox").connect("text_confirmed", self, "text_confirmed")
	pass # Replace with function body.

func start_setup_gp(device_number: int, input_slot_number: int, player_number: int, side: int):
	print("start_setup_gp(device_number = ", device_number, ", input_slot_number = ", input_slot_number, ", player_number = ", player_number, ", side = ", side, ")")
	self.player_number = player_number
	current_device_type = C.DEVICES.GAMEPAD
	current_device_index = input_slot_number # [input overhaul]
	current_phase = PHASE.CHOOSE_KB
	axis = Vector2.ZERO
	$Panel/Name.hide()
	$Panel/Type.set_animation("gp" if side == 0 else "gp_left" if side == 1 else "gp_right")
	$Panel/Confirm.show()
	$Panel/Instructions2.hide()
	$Panel/Number.set_text("Gamepad %d" % (player_number + 1) + (" (Left)" if side == 1 else " (Right)" if side == 2 else " (Whole)"))
	$Panel/List.show()
	$Panel/List.modulate.a = 1.0
	$Panel/Instructions.set_text("Choose your keyboard.")
	$Panel/List/Button2.grab_focus()
	$AnimationPlayer.play("choose_keyboard")

func start_setup_kb(player_number: int, device_index: int):
	self.player_number = player_number
	current_device_type = C.DEVICES.KEYBOARD
	current_device_index = device_index
	current_phase = PHASE.NAME_ENTRY
	$Panel/Name.hide()
	$Panel/Type.set_animation("kb")
	$Panel/Confirm.hide()
	$Panel/Instructions2.show()
	$Panel/Number.set_text(["QWE/ASD", "FGH/VBN", "UIO/JKL", "789/456"][device_index])
	$Panel/List.modulate.a = 0.0
	$Panel/Instructions.set_text("Enter your name")
	$AnimationPlayer.play("choose_keyboard")
	name_entry(0)

# only one touchscreen player, device index is ignored
func start_setup_touch(player_number: int):
	self.player_number = player_number
	current_device_type = C.DEVICES.TOUCHSCREEN
	current_device_index = -1
	current_phase = PHASE.NAME_ENTRY
	$Panel/Name.hide()
	$Panel/Type.set_animation("touch")
	$Panel/Confirm.hide()
	$Panel/Instructions2.show()
	$Panel/Number.set_text("Touchscreen")
	$Panel/List.modulate.a = 0.0
	$Panel/Instructions.set_text("Enter your name")
	$AnimationPlayer.play("choose_keyboard")
	name_entry(0)

# remotes are identified by unique identifier; device index is ignored
func start_setup_remote(player_name: String):
	current_device_type = C.DEVICES.REMOTE
	current_phase = PHASE.NAME_ENTRY
	remote_nickname = player_name
	$Panel/Name.show()
	$Panel/Name/Name.set_text("[no nickname]" if player_name == "" else player_name)
	$Panel/Type.set_animation("remote")
	$Panel/Confirm.hide()
	$Panel/Instructions.set_text("Confirm join")
	$Panel/Instructions2.hide()
	$Panel/Number.set_text("Remote")
	$Panel/List.modulate.a = 0.0
	$AnimationPlayer.play("choose_keyboard")

func press_right():
	print("Press right")
	var focused = get_focus_owner()
	var neighbor = focused.get_node_or_null(focused.get_focus_neighbour(MARGIN_RIGHT))
	if null == neighbor:
		S.play_sfx("menu_stuck")
	else:
		S.play_sfx("menu_move")
		neighbor.grab_focus()

func press_left():
	print("Press left")
	var focused = get_focus_owner()
	var neighbor = focused.get_node_or_null(focused.get_focus_neighbour(MARGIN_LEFT))
	if null == neighbor:
		S.play_sfx("menu_stuck")
	else:
		S.play_sfx("menu_move")
		neighbor.grab_focus()

func done(text):
	player_number = -1
	current_device_type = -1
	current_device_index = -1
	current_phase = PHASE.NONE
	$AnimationPlayer.play("done")
	get_parent().signup_ended(text, current_keyboard)

func gp_button(who, what, pressed):
	if who != current_device_index: return
	#print(who, what, pressed)
	if current_phase == PHASE.CHOOSE_KB:
		if what == 5:
			S.play_sfx("menu_confirm")
			$AnimationPlayer.play("chosen_keyboard")
			current_keyboard = get_focus_owner().get_index()
			name_entry(current_keyboard)
		elif what == 4:
			S.play_sfx("menu_back")
			done("")

func name_entry(type):
	$Panel/Confirm.hide()
	$Panel/Instructions.set_text("Enter your name")
	get_parent().get_node("KeyboardBox").start_keyboard(
		type, player_number, current_device_index,
		12 # name length limit.
	)
	current_phase = PHASE.NAME_ENTRY

func gp_axis(who, what, value):
	if who != current_device_index: return
	prints(who, what, value)
	if current_phase == PHASE.CHOOSE_KB:
		if what == 0:
			#print(value)
			if axis.x < stick_max and stick_max < value:
				#print("right")
				press_right()
			elif -stick_max < axis.x and value < -stick_max:
				#print("left")
				press_left()
			axis.x = value
		else:
			axis.y = value

func text_confirmed(text):
	print("Player %d on Device %d has name %s!" % [player_number, current_device_index + 1, text])
	done(text)

func _input(event):
	if current_device_type != -1 and current_device_type != C.DEVICES.KEYBOARD and (
		event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or
		event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or
		event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")
	):
		accept_event() # prevent default UI actions
		C._input(event) # and let the control handler parse the event instead
		pass

func _on_Button_pressed():
	current_keyboard = 1
	done(remote_nickname)

func _on_Button2_pressed():
	current_keyboard = -1
	done(remote_nickname)
