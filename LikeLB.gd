extends Control

onready var player0 = $Player
onready var tween = $Tween
var offset_y = 90.0
var offset_x = -offset_y * tan(deg2rad(5.0)) # Phone is rotated 5 degrees to the right.
var players = []
var scores = []

# Called when the node enters the scene tree for the first time.
func _ready():
	players.push_back(player0)
	for i in range(1, len(R.players)):
		var new_player = player0.duplicate()
		self.add_child(new_player, true)
		players.push_back(new_player)
	for i in range(0, len(R.players)):
		scores.push_back({
			"index": i,
			"score": 0,
			"out_of": 0
		})
		set_player_name(i, R.players[i].name)
		set_player_number(i)
		set_player_score(i)
	position_players()

func set_player_name(index: int, new_name: String):
	players[index].get_node("Panel/Name").set_text(new_name)

func set_player_number(index: int):
	players[index].get_node("Number").set_text("%d" % (1 + index))

func reveal(index: int, truthy: bool):
	for s in range(len(scores)):
		var i = scores[s].index
		var selected = players[i].get_node("HeartPanel").get_child(index).rect_scale.x >= 1.0
		if truthy == selected:
			scores[s].score += 1
		scores[s].out_of += 1
		set_player_score(i)
	if index == 3:
		yield(get_tree().create_timer(0.25), "timeout")
		sort_scores()
		position_players()

func set_player_score(index: int):
	for s in scores:
		if s.index == index:
			players[index].get_node("Panel/Score").set_text("%d OF " % s.score + "%d" % s.out_of)
			return

func toggle_player_input(index: int, button_index: int, new_input: bool):
	players[index].get_node("AnimationPlayer").advance(1.0)
	players[index].get_node("AnimationPlayer").play(("on%d" if new_input else "off%d") % button_index)

func position_players():
	for i in len(scores):
		var pbox = players[scores[i].index]
		tween.interpolate_property(
			pbox, "rect_position:y", pbox.rect_position.y,
			offset_y * (i - 0.5 * len(scores)) + (rect_size.y / 2),
			0.4, Tween.TRANS_QUART, Tween.EASE_OUT, (i + 0.0) * 0.1
		)
		tween.interpolate_property(
			pbox, "rect_position:x", pbox.rect_position.x,
			offset_x * (i - 0.5 * len(scores)),
			0.4, Tween.TRANS_QUART, Tween.EASE_IN, (i + 0.0) * 0.1 + 0.15
		)
	tween.start()

func reset_all_answers():
	for i in range(len(players)):
		for j in range(4):
			toggle_player_input(i, j, false)

func sort_scores():
	# insertion sort
	for i in range(1, len(scores)):
		var j = i
		print("start")
		print(JSON.print(scores))
		while j > 0:
			if (
				scores[j-1].score < scores[j].score
			) or (
				scores[j-1].score == scores[j].score and scores[j-1].index > scores[j].index
			):
				scores.insert(
					j-1, scores.pop_at(j)
				)
				j -= 1
				print("swap")
				print(JSON.print(scores))
			else:
				print("done")
				break
