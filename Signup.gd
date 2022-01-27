extends Control

var p_count = 0 # number of players
var players_list = []
var signup_now = []
var signup_queue = []
onready var signup_modal = $SignupModal
var signup_box = preload("res://SignupBox.tscn")
enum SIGNUP {
	DEVICE_TYPE,
	DEVICE_INDEX,
	PLAYER_NUMBER,
	SIDE
}

func _ready():
	R.rng.randomize()
	C.connect("gp_button", self, "_gp_button")
	$LoadingPanel.hide()
	$MouseMask.hide()
	players_list = []; signup_now = []; signup_queue = []
	p_count = 0
	$Instructions/SignupOnline.self_modulate = Color(1, 1, 1, 0.3)
	$Instructions/SignupOnline/RoomCode2.set_text("")
	$Instructions/SignupOnline/RoomCode.set_text("")
	if R.cfg.room_openness != 0:
		$Instructions/SignupOnline/host.set_text("Connecting to server...")
		Ws.connect('connected', self, "server_connected", [], CONNECT_ONESHOT)
		Ws.connect('disconnected', self, "server_failed", [], CONNECT_ONESHOT)
		Ws.connect('player_requested_nick', self, "give_player_nick")
		Ws._connect()
	else:
		$Instructions/SignupOnline/host.set_text("Online controllers are turned off because\n“Room openness” is set to “no room”.")

func server_failed():
	Ws.disconnect('connected', self, "server_connected")
	$Instructions/SignupOnline.self_modulate = Color(0.5, 0.5, 0.5, 0.5)
	$Instructions/SignupOnline/host.set_text("Could not connect to server.")
	$Instructions/SignupOnline/RoomCode2.set_text("Local play still works, though!")

func server_connected():
	Ws.disconnect('disconnected', self, "server_failed")
	$Instructions/SignupOnline.self_modulate = Color(1, 1, 1, 0.3)
	$Instructions/SignupOnline/host.set_text("Visit " + Ws.websocket_url)
	$Instructions/SignupOnline/RoomCode2.set_text("Opening room...")
	$Instructions/SignupOnline/RoomCode.set_text("")
	Ws.connect("room_opened", self, "room_opened", [], CONNECT_ONESHOT)
	Ws.open_room()

func room_opened():
	if Ws.room_code != "":
		self.connect("tree_exited", Ws, "close_room")
		$Instructions/SignupOnline.self_modulate = Color(1, 1, 1, 1.0)
		$Instructions/SignupOnline/RoomCode2.set_text("and enter the room code:")
		$Instructions/SignupOnline/RoomCode.set_text(Ws.room_code)
		Ws.connect("player_joined", self, 'remote_queue')
	else:
		$Instructions/SignupOnline.self_modulate = Color(0.5, 0.2, 0.2, 0.5)
		$Instructions/SignupOnline/RoomCode2.set_text("Could not open room.")
	pass

# Just the remote game start thing.
func _gp_button(player: int, button: int, pressed: bool):
	if len(players_list) > 0\
	and players_list[0].device == C.DEVICES.REMOTE\
	and players_list[0].device_index == player\
	and button == 5:
		start_game()

# Check for controllers that haven't signed up yet.
func _input(e):
	if $MouseMask.visible: return
	if len(signup_now): return
	if e is InputEventJoypadButton:
		var lookup = C.lookup_button(C.DEVICES.GAMEPAD, e.device, e.button_index)
		#print(lookup)
		if e.button_index in [JOY_L, JOY_R, JOY_L2, JOY_R2]:
			if lookup.player == -1:
				# no match
				match e.button_index:
					JOY_L:
						if Input.is_joy_button_pressed(e.device, JOY_R):
							print("SIGNUP QUEUED")
							var p = C.add_controller(C.DEVICES.GAMEPAD, e.device, 0)
							gp_queue(e.device, p, 0)
							p_count += 1
						elif Input.is_joy_button_pressed(e.device, JOY_L2):
							print("SIGNUP QUEUED")
							var p = C.add_controller(C.DEVICES.GAMEPAD, e.device, 1)
							gp_queue(e.device, p, 1)
							p_count += 1
					JOY_R:
						if Input.is_joy_button_pressed(e.device, JOY_L):
							print("SIGNUP QUEUED")
							var p = C.add_controller(C.DEVICES.GAMEPAD, e.device, 0)
							gp_queue(e.device, p, 0)
							p_count += 1
						elif Input.is_joy_button_pressed(e.device, JOY_R2):
							print("SIGNUP QUEUED")
							var p = C.add_controller(C.DEVICES.GAMEPAD, e.device, 2)
							gp_queue(e.device, p, 2)
							p_count += 1
					JOY_L2:
						if Input.is_joy_button_pressed(e.device, JOY_L):
							print("SIGNUP QUEUED")
							var p = C.add_controller(C.DEVICES.GAMEPAD, e.device, 1)
							gp_queue(e.device, p, 1)
							p_count += 1
					JOY_R2:
						if Input.is_joy_button_pressed(e.device, JOY_R):
							print("SIGNUP QUEUED")
							var p = C.add_controller(C.DEVICES.GAMEPAD, e.device, 2)
							gp_queue(e.device, p, 2)
							p_count += 1
			
		else:
			# check if anyone's signing up
			if e.pressed and lookup.button == 5 and (
				len(players_list) > 0 and len(signup_now) == 0 and len(signup_queue) == 0
			):
				if (
					players_list[0].device == C.DEVICES.GAMEPAD and players_list[0].device_index == lookup.player
				):
					start_game()
			elif e.button_index == JOY_DS_B and (
				e.device == 0
			):
				get_parent().back()
	elif e is InputEventKey:
		var sc = e.physical_scancode
		if e.pressed:
			if sc == KEY_ESCAPE:
				get_parent().back()
			# this is a hacky workaround caused by "physical scancode" being backported from Godot 4
			# but not "is physical key pressed". the workaround involves creating 8 input actions.
			if sc == KEY_Q and Input.is_action_pressed("signup0b")\
			or sc == KEY_E and Input.is_action_pressed("signup0"):
				kb_queue(0)
			elif sc == KEY_F and Input.is_action_pressed("signup1b")\
			or sc == KEY_H and Input.is_action_pressed("signup1"):
				kb_queue(1)
			elif sc == KEY_U and Input.is_action_pressed("signup2b")\
			or sc == KEY_O and Input.is_action_pressed("signup2"):
				kb_queue(2)
			elif sc == KEY_KP_7 and Input.is_action_pressed("signup3b")\
			or sc == KEY_KP_9 and Input.is_action_pressed("signup3"):
				kb_queue(3)
			elif sc == KEY_ENTER or sc == KEY_KP_ENTER:
				# check if anyone's signing up
				if len(players_list) > 0 and len(signup_now) == 0 and len(signup_queue) == 0:
					start_game()

func gp_queue(player_number, device_index, side):
	print("gp_queue(player_number = ", player_number, ", device_index = ", device_index, ", side = ", side, ")")
	signup_queue.append([C.DEVICES.GAMEPAD, device_index, player_number, side])
	check_full()

func kb_queue(player_number):
	# check if the player's currently signing up
	if len(signup_now) > 0 and\
	signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.KEYBOARD:
		return
	# check if the player's already signed up
	for p in players_list:
		if p.device == C.DEVICES.KEYBOARD and p.device_index == player_number:
			return
	signup_queue.append([C.DEVICES.KEYBOARD, player_number, p_count, 0])
	p_count += 1
	accept_event()
	check_full()

func remote_queue(data):
	signup_queue.append([C.DEVICES.REMOTE, data.name, data.nick, 0])
	check_full()

func check_full():
	if len(players_list) + len(signup_now) + len(signup_queue) == 8:
		Ws.send_to_room('editRoom', {
			"status": "FULL"
		});
		$TouchButton.hide()

func _process(delta):
	if signup_now == [] and len(signup_queue) > 0:
		start_signup()

func start_signup():
	if len(players_list) >= 8: return
	signup_now = signup_queue.pop_front()
	if signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.GAMEPAD:
		signup_modal.start_setup_gp(signup_now[SIGNUP.DEVICE_INDEX], signup_now[SIGNUP.PLAYER_NUMBER], signup_now[SIGNUP.SIDE])
		S.play_sfx("menu_signout")
		S.play_track(0, 0)
		S.play_track(1, 1)
		S.play_track(2, 0)
	elif signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.KEYBOARD:
		signup_modal.start_setup_kb(signup_now[SIGNUP.PLAYER_NUMBER], signup_now[SIGNUP.DEVICE_INDEX])
		S.play_sfx("menu_signout")
		S.play_track(0, 0)
		S.play_track(1, 1)
		S.play_track(2, 0)
	elif signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.TOUCHSCREEN:
		signup_modal.start_setup_touch(signup_now[SIGNUP.PLAYER_NUMBER])
		S.play_sfx("menu_signout")
		S.play_track(0, 0)
		S.play_track(1, 1)
		S.play_track(2, 0)
		$TouchButton.hide()
	else:
		# online
		if R.cfg.room_openness == 2:
			signup_ended(signup_now[2], 0)
		elif R.cfg.room_openness == 1:
			signup_modal.start_setup_remote(signup_now[SIGNUP.PLAYER_NUMBER])
			S.play_sfx("menu_signout")
			S.play_track(0, 0)
			S.play_track(1, 1)
			S.play_track(2, 0)
		else:
			printerr("Why are you here? Room is not open")

func signup_ended(name, keyboard_type):
	# check if player is remote and got rejected
	if keyboard_type == -1:
		S.play_sfx("menu_fail")
		Ws.kick_player(signup_now[SIGNUP.DEVICE_INDEX])
	# end check
	else:
		var box = signup_box.instance()
		S.play_sfx("menu_signin")
		$Players.add_child(box)
		var icon_name = ""
		var name_type = 0
		var default_name = ""
		# find icon to use
		if signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.GAMEPAD:
			match signup_now[SIGNUP.SIDE]:
				0:
					default_name = "Gamepad %d" % (signup_now[SIGNUP.DEVICE_INDEX] - 4)
					icon_name = "gp"
				1:
					default_name = "Shared L %d" % (signup_now[SIGNUP.DEVICE_INDEX] - 4)
					icon_name = "gp_left"
				2:
					default_name = "Shared R %d" % (signup_now[SIGNUP.DEVICE_INDEX] - 4)
					icon_name = "gp_right"
		elif signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.KEYBOARD:
			icon_name = "kb"
			match signup_now[SIGNUP.DEVICE_INDEX]:
				0:
					default_name = "Keeb WASD"
				1:
					default_name = "Keeb GVBN"
				2:
					default_name = "Keeb IJKL"
				3:
					default_name = "Numpad"
		elif signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.TOUCHSCREEN:
			icon_name = "touch"
			default_name = "Touchscreen"
		elif signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.REMOTE:
			icon_name = "online"
			default_name = "Remote %d" % (len(players_list) + 1)
			C.add_controller(C.DEVICES.REMOTE, signup_now[1])
		else:
			icon_name = "retro"
			default_name = "Player %d" % (len(players_list) + 1)
		# is name default?
		if name == "":
			name = default_name
			name_type = 1
		# is name "fuck you"?
		else:
			var matched = R.cuss_regex.search(name)
			if null != matched:
				name_type = 2
		box.setup(name, len(players_list), icon_name)
		var player_device_index = signup_now[SIGNUP.DEVICE_INDEX]
		if signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.REMOTE:
			player_device_index = C.lookup_button(C.DEVICES.REMOTE, signup_now[SIGNUP.DEVICE_INDEX], 0).player;
			keyboard_type = 3
		var player = {
			name = name,
			name_type = name_type,
			score = 0,
			device = signup_now[SIGNUP.DEVICE_TYPE],
			device_index = player_device_index,
			device_name = signup_now[SIGNUP.DEVICE_INDEX] if signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.REMOTE else "",
			has_lifesaver = true,
			player_number = len(players_list),
			side = signup_now[SIGNUP.SIDE],
			keyboard = keyboard_type
		}
		print("Appending new player: ", player)
		if len(players_list) == 0:
			$Ready/Label2.set_text("Or press Return on the keyboard")
			if signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.GAMEPAD:
				$Ready/Label.set_text("Press → to start!")
			elif signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.KEYBOARD:
				$Ready/Label.set_text("Press Return to start!")
				$Ready/Label2.set_text("")
			elif signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.TOUCHSCREEN:
				$Ready/Label.set_text("Tap here to start!")
			elif signup_now[SIGNUP.DEVICE_TYPE] == C.DEVICES.REMOTE:
				$Ready/Label.set_text("Tap “Start” to start!")
			$Ready/Anim.play("Enter")
		players_list.append(player)
		give_player_nick(player.device_name)
	S.play_track(0, 0.0 if len(players_list) else 1.0)
	S.play_track(1, 0.0)
	S.play_track(2, 1.0 if len(players_list) else 0.0)
	yield(get_tree().create_timer(1.0), "timeout")
	signup_now = []

func start_game():
	# disconnect this signal before exiting the RIGHT way
	self.disconnect("tree_exited", Ws, "close_room")
	print("Start the game!")
	$MouseMask.show()
	R.players = players_list
	get_parent().start_game()

func _on_TouchButton_pressed():
	signup_queue.append([C.DEVICES.TOUCHSCREEN, 4, len(signup_queue), 0])

func _on_Ready_gui_input(event):
	if players_list[0].device == C.DEVICES.TOUCHSCREEN:
		if event is InputEventMouseButton and event.pressed and event.button_index == 1:
			start_game()

# if the remote controller finishes signup before the html can load, their nickname will be "signing up..."
func give_player_nick(id):
	for p in players_list:
		if p.device == C.DEVICES.REMOTE and p.device_name == id:
			Ws.send('message', {
				'to': id,
				'action': 'changeNick',
				'nick': p.name,
				'playerIndex': p.player_number,
				'isVip': p.player_number == 0
			});

func update_loading_progress(partial, total, eta):
	var time_text = "Finished!"
	if eta >= 60*1000:
		time_text = "Please wait ≈%dʹ %0.1f″..." % [eta / (60*1000), (eta % (60*1000)) / 1000.0]
	elif eta >= 1000:
		time_text = "Please wait ≈%0.1f″..." % (eta / 1000.0)
	elif eta > 0:
		time_text = "Almost there..."
	$LoadingPanel/Label.set_text(
		"Downloading question pack. %s" % time_text
	)
	$LoadingPanel/ProgressBar.max_value = total
	$LoadingPanel/ProgressBar.value = partial
	$LoadingPanel/Progress.set_text(
		"Loaded %.1fKiB of %.1fKiB (%06.2f%%)" % [partial / 1024.0, total / 1024.0, 100.0 * partial / total]
	)
