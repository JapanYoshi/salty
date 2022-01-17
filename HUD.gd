extends Control

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
	rect_position.y = 240
	pass # Replace with function body.

func slide_playerbar(slide_in: bool):
	$Tween.interpolate_property(
		self, "rect_position:y",
		240 if slide_in else 0,
		0 if slide_in else 240,
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
		player_boxes[i].incorrect(point_value)
		R.players[i].score -= point_value

func reward_players(players: Array, point_value):
	for i in players:
		player_boxes[i].correct(point_value)
		R.players[i].score += point_value

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

func show_accuracy(data: Array):
	for i in range(len(data)):
		player_boxes[i].show_accuracy(data[i][0], data[i][1])

func hide_accuracy():
	for i in range(8):
		player_boxes[i].set_score()

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
