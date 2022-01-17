extends Panel

var index = 0
onready var child = $bg
onready var child_size = child.rect_size

onready var positions = [
	Vector2(child_size.x * -1.5, child_size.y *  0.0 + rect_size.y * 0.0),
	Vector2(child_size.x * -0.5, child_size.y * -0.5 + rect_size.y * 0.5),
	Vector2(child_size.x *  0.5, child_size.y * -1.0 + rect_size.y * 1.0),
	Vector2(child_size.x * -1.0, child_size.y * -0.5 + rect_size.y * 0.75),
	Vector2(child_size.x *  0.0, child_size.y * -0.5 + rect_size.y * 0.25),
]
func set_index(index: int):
	self.index = index;
	child.rect_position = Vector2(rect_size.x * 0.5, 0) + positions[index % 5]

func init_values(player: Dictionary):
	$bg/number.set_text("%d" % (player.player_number + 1))
	$bg/score.set_text(R.format_currency(player.score))
	if player.score < 0:
		$bg/score.add_color_override("font_color", Color.red)
	$bg/name.set_text(player.name)
