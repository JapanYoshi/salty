## Thing that automatically scrolls horizontally to show different controls to play the game.

extends ScrollContainer

onready var timer: Timer = $Timer
onready var tween: Tween = $Tween
onready var c: HBoxContainer = $HBoxContainer

onready var item_width: float = rect_min_size.x
onready var sep: float = c.get_constant("separation")

onready var pages: int = $HBoxContainer.get_child_count()
var page: int = 0

func _on_Timer_timeout():
	var new_page: int = (page + 1) % pages
	tween.interpolate_property(
		self, "scroll_horizontal",
		page     * (item_width + sep),
		new_page * (item_width + sep),
		0.75, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT
	)
	tween.start()
	page = new_page
