class_name ScreenStretch
extends Control

const base_resolution = Vector2(1280, 720)

# Called when the node enters the scene tree for the first time.
func _ready():
	rect_size = base_resolution
	rect_pivot_offset = base_resolution * 0.5
	rect_clip_content = true
	_on_size_changed() # initialize size
	get_viewport().connect("size_changed", self, "_on_size_changed")
	pass # Replace with function body.

func _on_size_changed():
	var resolution = get_viewport_rect().size
	rect_scale = Vector2.ONE * min(
		resolution.y / base_resolution.y,
		resolution.x / base_resolution.x
	)
	var parent = get_parent()
	if parent is Control:
		parent.rect_pivot_offset = resolution * 0.5
