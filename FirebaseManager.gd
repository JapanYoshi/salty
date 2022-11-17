extends Node
signal finished
var just_finished: String = ""

var connected_to_room: bool = false

onready var PingTimer: Timer = $PingTimer

signal player_joined(data)

signal remote_typing(uuid, text)
signal remote_finale(uuid, text)

var room_code: String = ""
const firebase_config = {
	apiKey="AIzaSyCCQlFqG66ls0jNEeZDqv0F5V4d2l3mIPw",
	authDomain="haitouch-9320f.firebaseapp.com",
	databaseURL="https://haitouch-9320f-default-rtdb.firebaseio.com",
	projectId="haitouch-9320f",
	storageBucket="haitouch-9320f.appspot.com",
	messagingSenderId="850603279750",
	appId="1:850603279750:web:a92cc85981305fe85e5807"
}
var default_room = {
	gameName = "Salty Trivia with Candy Barre",
	controllerName = "controller_salty",
	playerCount = 0,
	maxPlayers = 8, # can be changed in config
	audienceCount = 0,
	maxAudience = 100, # can be changed in config
	connections = {
	# From earliest join to latest. In format:
	# uUiDh3rE = {
	#     nickname = "ABCDEFGH",
	#     score = 0,
	#     inputState = 0,
	#     inputText = "",
	# }
	# Each person's inputState should be listened to.
	},
	scene = [
	# From old to new. In format:
	# {
	#     name = "question",
	#     question = "What color is a firetruck?",
	#     options = ["red", "blue", "yellow", "green"],
	# }
	],
	lastUpdate = 0, # unix timestamp
}
var db: FirebaseDatabase
var db_ready: bool = false
var db_user: FirebaseUser
var room_codes = []
var scene_history = []
var scene_ref
var players_list = [] # just in case we might use this
var player_snapshot
var all_players_ref

var audience_list = []
var audience_snapshot
var all_audience_ref
var join_request_ref
var player_refs = {}
# Initialize the Firebase plugin.
func _init_firebase():
	db_ready = false
	firebase.initialize_app(firebase_config)
	db = firebase.database()
	print("Firebase initialized.")
	
	var auth: FirebaseAuth = firebase.auth()
	var result = yield(auth.sign_in_anonymously(), "completed")
	if result is FirebaseError:
		printerr("Could not authenticate Firebase: ", result.code)
	else:
		db_user = result as FirebaseUser
		db_ready = true
	just_finished = "_init_firebase"; emit_signal("finished")

func check_if_connected(call_node: Node, call_function: String):
	var dummy_ref = db.get_reference_lite("lastUpdate")
	var result = yield(dummy_ref.put(Time.get_unix_time_from_system()), "completed")
	if result is FirebaseError:
		if is_instance_valid(call_node):
			call_node.call(call_function, false)
	else:
		if is_instance_valid(call_node):
			call_node.call(call_function, true)

func timestamp_room(call_node: Node, call_function: String):
	var ref = db.get_reference_lite("rooms/" + room_code + "/lastUpdate")
	var result = yield(ref.put(Time.get_unix_time_from_system()), "completed")
	if result is FirebaseError:
		pass
#		if is_instance_valid(call_node):
#			call_node.call(call_function, false)
	else:
		if is_instance_valid(call_node):
			call_node.call(call_function, true)

func _timestamp_room_result(success: bool):
	if !success:
		connected_to_room = false
		pass

func try_room(call_node: Node, call_function: String):
	room_code = R.generate_room_code()
	var room_free = is_room_free()
	while just_finished != "is_room_free":
		yield(self, "finished")
	if !room_free:
		if is_instance_valid(call_node):
			call_node.call(call_function, false)
		return true
	var room_made = yield(establish_room(), "completed")
	while just_finished != "establish_room":
		yield(self, "finished")
	if !room_made:
		if is_instance_valid(call_node):
			call_node.call(call_function, false)
		return true
	print(room_code + "Room established.")
	just_finished = "try_room"; emit_signal("finished")
	if is_instance_valid(call_node):
		call_node.call(call_function, true)
	return false

#func _ready():
	#_init_firebase()
	#update_room_list()
	#while just_finished != "update_room_list":
	#	yield(self, "finished")
	#_DEBUG_try_room()
	#while just_finished != "_DEBUG_try_room":
	#	yield(self, "finished")
	# Testing room host functionality
	#print("Adding scene 1")
	#add_scene("question", {
	#	question = "What color is a firetruck?",
	#	options = ["red", "blue", "yellow", "green"],
	#})
	#while just_finished != "add_scene":
	#	yield(self, "finished")
	#just_finished = ""
	#print("Adding scene 2")
	#add_scene("showOptions")
	#while just_finished != "add_scene":
	#	yield(self, "finished")
	#just_finished = ""
#	pass # Replace with function body.

# Update the settings for the default room. Fired after changing the settings or booting up the game.
func update_default_room_settings():
	default_room.maxPlayers = R.cfg.room_size + 1
	default_room.maxAudience = 100 if R.cfg.audience else 0

# Checks the Realtime Database to see which room codes are currently in use.
func update_room_list():
	var ref: FirebaseReference = db.get_reference_lite("roomCodes")
	var result = yield(ref.fetch(), "completed")
	if result is FirebaseError:
		printerr("Error on fetching room list")
		just_finished = "update_room_list"; emit_signal("finished")
		return result
	room_codes = []
	var kv = result.value()
	if !(kv == null):
		for k in kv.keys(): # Ignore room codes with a "false" value
			if kv[k]:
				room_codes.push_back(k)
	print("Room list fetched. ", room_codes)
	just_finished = "update_room_list"; emit_signal("finished")
	return result

# Checks if a room is free. DOES NOT check the Realtime Database!
# Set the variable `room_code` beforehand
func is_room_free() -> bool:
	if not(room_code in room_codes):
		print("Room code is free.")
		just_finished = "is_room_free"; emit_signal("finished")
		return true
	# Room code is in the list.
	var result
	var ref: FirebaseReference = db.get_reference_lite(
		"rooms/" + room_code
	)
	result = yield(ref.fetch(), "completed")
	if result is FirebaseError:
		printerr("Error on checking rooms/" + room_code + ".")
		just_finished = "is_room_free"; emit_signal("finished")
		return false
	# Is this an old room?
	if Time.get_unix_time_from_system() - 5 * 60 < result.value["lastUpdate"]:
		print("Room has been updated in the last 5 minutes. Game is probably in progress.")
		just_finished = "is_room_free"; emit_signal("finished")
		return false
	print("Room has not been updated in 5 minutes. Can safely delete, but don't use just in case.")
	ref = db.get_reference_lite("roomCodes/" + room_code)
	result = yield(ref.update(false), "completed")
	if result is FirebaseError:
		printerr("Could not update roomCodes/" + room_code + " to True. Aborted.")
	just_finished = "is_room_free"; emit_signal("finished")
	return false

# Establishes a room in the database.
# Hopefully another client won't try to host another room by the same room code at the same time.
func establish_room() -> bool:
	var ref = db.get_reference_lite("roomCodes/" + room_code)
	var result = yield(ref.fetch(), "completed")
	if result is FirebaseError:
		printerr("Error on checking roomsCodes/" + room_code + ".")
		just_finished = "establish_room"; emit_signal("finished")
		return false
	if ( # Since I have to account for the value being null, this condition is long
		result.value() is Dictionary
	) and (
		room_code in result.value()
	) and (
		result.value()[room_code] == true
	):
		printerr(room_code + " Room code is now used!")
		just_finished = "establish_room"; emit_signal("finished")
		return false
	result = yield(ref.put(true), "completed")
	if result is FirebaseError:
		printerr("Could not update roomCodes/" + room_code + " to True. Aborted.")
		just_finished = "establish_room"; emit_signal("finished")
		return false
	ref = db.get_reference_lite("rooms/" + room_code)
	var room = default_room.duplicate(true)
	room.lastUpdate = Time.get_unix_time_from_system()
	result = yield(ref.update(room), "completed")
	if result is FirebaseError:
		printerr("Could not establish rooms/" + room_code + ". Aborted.")
		just_finished = "establish_room"; emit_signal("finished")
		return false
	print(room_code + "Room established!")
	scene_ref = db.get_reference_lite("rooms/" + room_code + "/scene")
	# Store reference for the currently joined players list
	all_players_ref = db.get_reference_lite("rooms/" + room_code + "/players")
#	# TODO: receive input from players
	all_audience_ref = db.get_reference_lite("rooms/" + room_code + "/audience")
	# Store reference for the join waitlist
	join_request_ref = db.get_reference_lite("rooms/" + room_code + "/pending")
	join_request_ref.connect("child_added", self, "_new_player_entry")
	join_request_ref.connect("child_changed", self, "_player_rejoin")
	join_request_ref.enable_listener()
	# And we're done.
	just_finished = "establish_room"; emit_signal("finished")
	
	connected_to_room = true
	PingTimer.start()
	return true

### Scenes
# Scenes control the events that happen on the players' controllers.
# A list of currently active scenes is stored in an array,
# with larger numbers happening more recently.

func add_scene(name: String, data: Dictionary = {}) -> bool:
	#scene_ref = db.get_reference_lite("rooms/" + room_code + "/scene")
	var result
#	if len(scene_history):
	# Hacky workaround: Keep track of the index of the latest scene, then use it as an index
	# into a Firebase RTDB "array" which is just an object with contiguous integer indices.
	result = yield(scene_ref.update({
		len(scene_history): {
			name=name, data=data
		}
	}), "completed")
#	else:
#		# Push the first scene.
#		result = yield(scene_ref.put([{name=name, data=data}]), "completed")
	if result is FirebaseError:
		printerr("Could not add scene.")
		just_finished = "add_scene"; emit_signal("finished")
		return false
	else:
		print("Scene added ", name, ", ", result)
	scene_history.push_back(name)
	just_finished = "add_scene"; emit_signal("finished")
	return true

func clear_scenes() -> bool:
	#scene_ref = db.get_reference_lite("rooms/" + room_code + "/scene")
	var result = yield(scene_ref.remove(), "completed")
	if result is FirebaseError:
		printerr("Could not delete scene.")
		just_finished = "clear_scenes"; emit_signal("finished")
		return false
	scene_history.clear()
	just_finished = "clear_scenes"; emit_signal("finished")
	return true

### Players
# Each player has their own entry on rooms/RMCD/players.
# When a new player wants to join, they create a new entry with their UUID.
# The structure should be {nick: "ABCDEF", status: 1, uuid: "ABCDEFGH"}.
# When the player is admitted, the following Object is written:
# {
#   playerNumber: -1 # -1 if audience, 0-7 if player.
#   nick: "ABCDEF",  # used to display the nickname in the webapp
#   score: 0,        # so far only used to track if the score is negative
#   scoreText: "$0", # used to display the score in the webapp
#   input: 0,                  # used for button inputs
#   inputText: "",             # used for All Outta Salt
#   inputFinale: "000000",     # used for Rush and Like
#   messages: {action: "none"} # used to communicate to the webapp
#                              # e.g. "You buzzed in"
# }

func _new_player_entry(data: FirebaseDataSnapshot):
	print("DATA.VALUE = ", data.value())
	var v = data.value()
	# check if rejoin
	for p in R.players:
		if p.device_name == v.uuid:
			init_controller(v.uuid, p.name)
			return
	# not a rejoin, sign up
	emit_signal("player_joined", {name = v.uuid, nick = v.nick})

# When an existing user disconnects and tries to join again, just the "status" var changes.
func _player_rejoin(data: FirebaseDataSnapshot):
	var v = data.value()
	print("DATA.VALUE = ", v)
	if v.status != 1:
		return # not a rejoin
	# check if this is an audience member or not
	for p in R.players:
		if p.device_name == v.uuid:
			init_controller(v.uuid, false) # player
			return
	init_controller(v.uuid, true) # audience, may change this later

func _add_remote(uuid, nick, as_audience: bool, player_number: int):
	C.add_controller(C.DEVICES.REMOTE, uuid, 0) # let the controller handler handle it
	if as_audience:
		var audience_count_ref = db.get_reference_lite("rooms/" + room_code + "/audienceCount")
		audience_count_ref.put(player_number + 1)
		all_audience_ref.update({
			uuid: { # we want the variable uuid, not the text "uuid"
				nick = nick,
				score = 0,
				scoreText = R.format_currency(0),
				input = 0,
				inputText = "",
				inputFinale = "000000",
				messages = {
					action = "none"
				},
				playerNumber = -1
			}
		})
		all_audience_ref.enable_listener() # only needs to be enabled once per game
	else:
		var player_count_ref = db.get_reference_lite("rooms/" + room_code + "/playerCount")
		player_count_ref.put(player_number + 1)
		all_players_ref.update({
			uuid: { # we want the variable uuid, not the text "uuid"
				nick = nick,
				score = 0,
				scoreText = R.format_currency(0, true),
				input = 0,
				inputText = "",
				inputFinale = "000000",
				messages = {
					action = "none"
				},
				playerNumber = player_number
			}
		})
		# only needs to be enabled once per game
		if all_players_ref._listener == null:
			var result = yield(all_players_ref.fetch(), "completed")
			player_snapshot = result.value()
			all_players_ref.enable_listener()
			all_players_ref.connect("value_changed", self, "_all_players_ref_changed")
		# inform the player that they're connected
	# i should yield but i won't unless I have to
	init_controller(uuid, as_audience)

# number of players currently joined
func add_remote_player(uuid, nick, number):
	print("add_remote_player")
	_add_remote(uuid, nick, false, number)

# number of audience members currently joined
func add_remote_audience(uuid, nick, number):
	print("add_remote_audience")
	_add_remote(uuid, nick, true, number)

# Reject the player from joining.
func reject_remote_player(uuid):
	print("reject_remote_player")
	var this_guy_in_particular = db.get_reference_lite(
		"rooms/" + room_code + "/pending/" + uuid
	)
	this_guy_in_particular.update({
		status = -1
	})

# Reset the status in the "sign up" queue.
func init_controller(uuid, as_audience):
	var this_guy_in_particular = db.get_reference_lite(
		"rooms/" + room_code + "/pending/" + uuid
	)
	this_guy_in_particular.update({
		status = (9 if as_audience else 8)
	})
	pass

# only applies to players, not audience
func change_nick(uuid, new_nick):
	var this_guy_in_particular = db.get_reference_lite(
		"rooms/" + room_code + "/players/" + uuid
	)
	this_guy_in_particular.update({
		nick = new_nick
	})

func update_score(uuid, score, score_text):
	var this_guy_in_particular = db.get_reference_lite(
		"rooms/" + room_code + "/players/" + uuid
	)
	this_guy_in_particular.update({
		score = score,
		scoreText = score_text
	})

func send_to_player(player, data):
	if !(player in player_refs.keys()):
		return
	var result = yield(player_refs[player].put({message = data}), "completed")
	if result is FirebaseError:
		printerr("Could not send message to Player " + player + ".")
		just_finished = "send_to_player"; emit_signal("finished")
		return false
	just_finished = "send_to_player"; emit_signal("finished")
	return true

# Resets the inputFinale variable to all 0's.
# Call with digits=6 for Rush, digits=4 for Like (although it will work for both with 6)
# Shouldn't take too long; it will only be called 6 times at most.
func reset_finale_input(digits: int = 6):
	var updates = {}
	for p in player_snapshot.keys():
		updates[p + "/inputFinale"] = "0".repeat(digits)
	all_players_ref.update(updates)

# Update the player count online.
func update_player_count(new_player_count: int):
	if connected_to_room and R.cfg.room_openness > 0:
		var player_count_ref = db.get_reference_lite("rooms/" + room_code + "/playerCount")
		player_count_ref.put(new_player_count)

func _on_PingTimer_timeout():
	check_if_connected(self, "_ping_timer_result")

func _ping_timer_result(success: bool):
	if !success:
		connected_to_room = false
	else:
		timestamp_room(self, "_timestamp_room_result")
		PingTimer.start()

# Listen for any changes in the reference holding the players' data.
# This will also include OUR changes!
func _all_players_ref_changed(snapshot: FirebaseDataSnapshot):
	#print(snapshot)
	var new_value = snapshot.value()
	var old_value = player_snapshot
	if old_value == null: return
	# HOO BOY we gotta check every input state?
	for p in new_value.keys():
		var slot = C.lookup_remote(p)
		if slot == -1:
			continue
		if !old_value.has(p):
			old_value[p] = {}
		if new_value[p] is Dictionary:
			for k in new_value[p].keys():
				if !old_value.has(k):
					print(p, " ", k, " (nothing) -> ", new_value[p][k])
					#old_value[p][k] = new_value[p][k] # not necessary
				elif old_value[p][k] != new_value[p][k]:
					# messages
					print(p, " ", k, " ", old_value[p][k], " -> ", new_value[p][k])
				# input
				# inputText
				match k:
					"input":
						var state: int = int(new_value[p].input) # json float fuckery
						for i in range(7):
							if (state >> i) & 1:
								C.inject_button(slot, i, true)
						# overwrite with 0 to reset button state
						if state != 0:
							all_players_ref.update({p + "/input": 0})
					"inputText":
						print("inputText ", p, " ", new_value[p].inputText)
						emit_signal("remote_typing", new_value[p].inputText, slot)
					"inputFinale":
						print("inputFinale ", p, " ", new_value[p].inputFinale)
						emit_signal("remote_finale", new_value[p].inputFinale, slot)
	var result = yield(all_players_ref.fetch(), "completed")
	player_snapshot = result.value()

# Update the per-room scenes remotely.
# The game keeps track of which scenes have been sent already.
func scene(scene_history):
	if connected_to_room:
		scene_ref.put(scene_history)
