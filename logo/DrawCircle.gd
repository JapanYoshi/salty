extends Control
export var radius = 540.0
export var color = Color(0x56405c)

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _draw():
	draw_circle(Vector2(540, 540), radius, color)
