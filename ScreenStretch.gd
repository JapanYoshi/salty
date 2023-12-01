extends Control

const base_resolution = Vector2(1280, 720)

# Called when the node enters the scene tree for the first time.
func _ready():
	anchor_left = 0
	anchor_top = 0
	anchor_right = 0
	anchor_bottom = 0
	rect_size = base_resolution
	rect_pivot_offset = Vector2.ZERO
	rect_clip_content = true
	_on_size_changed() # initialize size
	get_viewport().connect("size_changed", self, "_on_size_changed")
	pass # Replace with function body.

func _on_size_changed():
	var resolution = get_viewport_rect().size
	rect_size = base_resolution
	rect_scale = Vector2.ONE * min(
		resolution.y / base_resolution.y,
		resolution.x / base_resolution.x
	)
	rect_position = (resolution - rect_scale * base_resolution) * 0.5
#	print("_on_size_changed():", resolution, "->", rect_scale)
