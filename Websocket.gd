extends Node

const LOCAL_MODE = false
signal connected()
signal disconnected()
# The URL we will connect to
var websocket_url = "localhost:3001" if LOCAL_MODE else "haitouch.herokuapp.com"
var client_name = ""
var connected = false

signal room_opened()
signal room_closed()
var room_code = ""

signal player_joined()
var players = []

signal server_reply()
var server_reply_content

signal remote_typing(text, from)
signal synced_button(player, button, aux)
signal player_requested_nick(from)

# Our WebSocketClient instance
var _client = WebSocketClient.new()

func _ready():
	# Don't pause the server connection when you pause the game
	pause_mode = PAUSE_MODE_PROCESS
	# Connect base signals to get notified of connection open, close, and errors.
	_client.connect("connection_closed", self, "_closed")
	_client.connect("connection_error", self, "_closed")
	_client.connect("connection_established", self, "_connected")
	# This signal is emitted when not using the Multiplayer API every time
	# a full packet is received.
	# Alternatively, you could check get_peer(1).get_available_packets() in a loop.
	_client.connect("data_received", self, "_on_data")

func _disconnect(code = 1000, reason = ""):
	print("WS: Disconnecting from host. code = %d, reason = " % code + reason)
	if not(code == 1000 or (code >= 3000 and code < 5000)):
		code = 1000
	_client.disconnect_from_host(code, reason)

func _connect():
	print("WS: Connecting to host.")
	# Initiate connection to the given URL.
	set_process(true)
	if _client.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED:
		var err = _client.connect_to_url(("ws://" if LOCAL_MODE else "wss://") + websocket_url)
		#print(err, _client.get_connected_host())
		if err:
			print("WS: Unable to connect")
			set_process(false)
			emit_signal("disconnected")
		else:
			print("WS: Already connected")
			connected = true
			emit_signal("connected")
	else:
		print("WS: Already connected")
		connected = true
		emit_signal("connected")

func _closed(was_clean = false):
	# was_clean will tell you if the disconnection was correctly notified
	# by the remote peer before closing the socket.
	print("WS: Closed, clean: ", was_clean)
	if room_code != "":
		room_code = ""
		printerr("Room closed.")
		emit_signal("room_closed")
	connected = false
	emit_signal("disconnected")
	set_process(false)

func _connected(proto = ""):
	# This is called on connection, "proto" will be the selected WebSocket
	# sub-protocol (which is optional)
	print("WS: Connected with %s protocol" % (proto if proto else "the default"))
	_send_packet({
		type = 'hello',
		name = client_name
	})
	connected = true
	$Timer.start()

func _on_data():
	# Print the received packet, you MUST always use get_peer(1).get_packet
	# to receive data from server, and not get_packet directly when not
	# using the MultiplayerAPI.
	var data_str = _client.get_peer(1).get_packet().get_string_from_utf8()
	print("Got data from server: ", data_str)
	var result = JSON.parse(data_str)
	if result.error != OK:
		printerr("WS: Invalid JSON received from server.")
		return
	var data = result.result
	match data.type:
		'onGetMyName':
			client_name = data.name
			print('WS: This client has the name ' + data.name)
			server_reply_content = 'name given'; emit_signal('server_reply');
		'onBroadcast':
			print("WS: Client {from} broadcast this message: {message}".format(data))
		'onMessage':
			print("WS: Client {from} sent this message to you: {message}".format(data))
		'onError':
			print("WS: Error received from server: {message}".format(data))
			if data.message.begins_with("You are already hosting"):
				close_room()
			server_reply_content = 'error'; emit_signal('server_reply')
		'sendToHost':
			if !data.has("action"):
				print("WS: Client {from} in your room broadcast this action: {action} / {which} / {reason}".format(data))
				return
			match data.action:
				'buttonPress':
					print("WS: Player {from} pressed button {which} with this intent: {reason}".format(data))
					var lookup = C.lookup_button(C.DEVICES.REMOTE, data.from, data.which)
					# player: int, button: int, pressed: bool
					# if the aux is there, fire the signal for that purpose
					if false == data.has("aux"):
						C.inject_button(lookup.player, data.which, true)
					else:
						emit_signal("synced_button", lookup.player, data.which, data.aux)
				'updateText':
					emit_signal("remote_typing", data.message, data.from, bool(data.finalize))
				'requestNick':
					emit_signal("player_requested_nick", data.from)
		'roomFound':
			server_reply_content = 'occupied'; emit_signal('server_reply')
		'roomNotFound':
			server_reply_content = 'free'; emit_signal('server_reply')
		'onRoomMade':
			server_reply_content = 'room made'; emit_signal('server_reply')
		'onPlayerJoin':
			if players.has(data.name):
				print("WS: Player {name} rejoined after disconnecting.".format(data))
			else:
				print("WS: Player {name} joined the room with nickname {nick}".format(data))
				players.push_back(data.name)
				emit_signal('player_joined', data)
		'onRoomLeave':
			print("WS: Player {name} disconnected.".format(data))

func _process(delta):
	# Call this in _process or _physics_process. Data transfer, and signals
	# emission will only happen when calling this function.
	_client.poll()

func _send_packet(data):
	# You MUST always use get_peer(1).put_packet to send data to server,
	# and not put_packet directly when not using the MultiplayerAPI.
	_client.get_peer(1).put_packet(JSON.print(data).to_utf8())

func send(type, data = {}, to = ""):
	data.type = type
	data.from = client_name
	if to:
		data.to = to
	_send_packet(data)

func send_to_room(type, data = {}):
	data.roomCode = room_code
	send(type, data)

func scene(scene_name, extra_data = {}):
	extra_data.action = "changeScene"
	extra_data.sceneName = scene_name
	send_to_room('sendToRoom', extra_data)

func open_room():
	# check until we find a room code that is available
	server_reply_content = 'occupied'
	# test server-side banned room codes
	while server_reply_content != 'free':
		# generate a room code
		generate_room_code()
		print("WS: Trying room code %s..." % room_code)
		# is this room code taken?
		send('queryRoom', {
			'roomCode': room_code
		})
		yield(self, 'server_reply')
	print("WS: Room code %s is available." % room_code)
	while server_reply_content == 'free':
		send('hostRoom', {
			'roomCode': room_code,
			'gameName': "Salty Trivia with Candy Barre",
			'controller': 'controller_salty.html',
			'maxPlayers': 8,
			'maxAudience': 100
		})
		yield(self, 'server_reply')
		if server_reply_content == 'room made':
			print("WS: Room made, sending signal")
		elif server_reply_content == 'room exists':
			send('closeRoom', {})
			yield(self, 'server_reply')
			server_reply_content = 'free'
		else:
			room_code = ""
			print("WS: Room not made, but sending signal")
		emit_signal("room_opened")

func close_room():
	send('closeRoom', {roomCode = room_code})
	room_code = ""
	players = []

func kick_player(player_id):
	send('kickFromRoom', {
		'roomCode': room_code,
		'name': player_id, # ID
		'message': "The host did not let you in."
	});
	players.erase(player_id)

func generate_room_code():
	var buf: PoolByteArray = [0, 0, 0, 0]
	var code: String = ""
	while true:
		var rng = RandomNumberGenerator.new()
		rng.randomize()
		for i in range(4):
			buf[i] = rng.randi_range(65, 90)
		code = buf.get_string_from_ascii()
		room_code = code
		return code

func _on_Timer_timeout():
	if connected:
		print("WS: Heartbeat")
		send('heartbeat')
		$Timer.start()
