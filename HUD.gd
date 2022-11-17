extends Control

onready var player_bar = $PlayerBar
onready var player_bar_default_y: float = 624.0
var player_bar_slide_distance: float = 116.0
onready var player_boxes = [
	$PlayerBar/PlayerHBox/PlayerBox,
	$PlayerBar/PlayerHBox/PlayerBox2,
	$PlayerBar/PlayerHBox/PlayerBox3,
	$PlayerBar/PlayerHBox/PlayerBox4,
	$PlayerBar/PlayerHBox/PlayerBox5,
	$PlayerBar/PlayerHBox/PlayerBox6,
	$PlayerBar/PlayerHBox/PlayerBox7,
	$PlayerBar/PlayerHBox/PlayerBox8,
]
onready var rc_box = $RoomCode

# Called when the node enters the scene tree for the first time.
func _ready():
	# if we're debugging, add a default player
	if len(R.players) == 0:
		R.players = [
			{
				player_number=0,
				name="FOO",
				name_type=1,
				score=0,
				device=0,
				device_index=0,
				side=0,
				keyboard=0,
				has_lifesaver=true
			},
			{
				player_number=1,
				name="BAR",
				name_type=1,
				score=0,
				device=0,
				device_index=1,
				side=0,
				keyboard=0,
				has_lifesaver=true
			},
			{
				player_number=2,
				name="BAZ",
				name_type=1,
				score=0,
				device=0,
				device_index=2,
				side=0,
				keyboard=0,
				has_lifesaver=true
			},
			{
				player_number=3,
				name="QUX",
				name_type=1,
				score=0,
				device=0,
				device_index=3,
				side=0,
				keyboard=0,
				has_lifesaver=true
			},
			{
				player_number=4,
				name="Touchscreen",
				name_type=1,
				score=0,
				device=2,
				device_index=4,
				side=0,
				keyboard=0,
				has_lifesaver=true
			}
		]
	for i in range(8):
		if i < len(R.players):
			print(R.players[i])
			player_boxes[i].initialize(R.players[i])
		else:
			player_boxes[i].hide()
	player_bar.rect_position.y = player_bar_default_y + player_bar_slide_distance
	# If we (potentially) have an audience, connect the signal from Root.
	if R.cfg.audience:
		rc_box.show_room_code(Fb.room_code)
		R.connect("change_audience_count", rc_box, "show_count")
		rc_box.show_count(len(R.audience_keys))

func slide_playerbar(slide_in: bool):
	$Tween.interpolate_property(
		player_bar, "rect_position:y",
		player_bar_default_y + player_bar_slide_distance if slide_in else player_bar_default_y,
		player_bar_default_y if slide_in else player_bar_default_y + player_bar_slide_distance,
		0.2, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT
	)
	$Tween.start()

func reset_playerboxes(players: Array, no_tweening: bool = false):
	for i in players:
		player_boxes[i].reset_anim(no_tweening)

func reset_all_playerboxes(no_tweening: bool = false):
	#breakpoint
	reset_playerboxes(range(8), no_tweening)

func highlight_players(players: Array):
	for i in players:
		player_boxes[i].highlight()

func punish_players(players: Array, point_value):
	for i in players:
		if i < len(R.players):
			player_boxes[i].incorrect(point_value)
			R.players[i].score -= point_value
			if R.players[i].device == C.DEVICES.REMOTE:
				refresh_remote_score(R.players[i].device_name, R.players[i].score)
		else:
			R.audience[i - len(R.players)].score -= point_value
			refresh_remote_score(R.audience[i - len(R.players)].device_name, R.audience[i - len(R.players)].score)

func reward_players(players: Array, point_value):
	for i in players:
		if i < len(R.players):
			player_boxes[i].correct(point_value)
			R.players[i].score += point_value
			if R.players[i].device == C.DEVICES.REMOTE:
				refresh_remote_score(R.players[i].device_name, R.players[i].score)
		else:
			R.audience[i - len(R.players)].score += point_value
			refresh_remote_score(R.audience[i - len(R.players)].device_name, R.audience[i - len(R.players)].score)

func refresh_remote_score(device_name, score):
	Fb.update_score(device_name, score, R.format_currency(score, true))
#	Ws.send(
#		"message", {
#			"action": "score",
#			"value": score,
#			"formatted": R.format_currency(score, true)
#		}, device_name
#	)

func give_lifesaver():
	for i in range(8):
		player_boxes[i].give_lifesaver()

func enable_lifesaver(active = true):
	for i in range(8):
		player_boxes[i].enable_lifesaver(active)

func player_buzzed_in(player):
	player_boxes[player].buzz_in()

func players_used_lifesaver(players):
	for i in players:
		player_boxes[i].use_lifesaver()

func show_accuracy(data: PoolByteArray):
	for i in range(len(data) / 2):
		player_boxes[i].show_accuracy(data[i * 2], data[i * 2 + 1])

func hide_accuracy():
	for i in range(8):
		player_boxes[i].set_score()

func show_accuracy_audience(percentage: float):
	rc_box.show_accuracy(percentage)

func hide_accuracy_audience():
	rc_box.hide_accuracy()

func show_finale_box(type):
	for i in range(8):
		player_boxes[i].show_finale_box(type)

func reset_finale_box():
	for i in range(8):
		player_boxes[i].reset_finale_box()

func set_finale_answer(player, option, truthy):
	player_boxes[player].set_finale_answer(option, truthy)

func confirm_finale_answer(option, truthy):
	for i in range(8):
		player_boxes[i].confirm_finale_answer(option, truthy)

func set_player_name(player, text, animate: bool = false):
	player_boxes[player]._set_name(text, animate)
