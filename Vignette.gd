extends ColorRect

onready var tween = Tween.new()
const MAX_RADIUS = 1.25;

# Called when the node enters the scene tree for the first time.
func _ready():
	add_child(tween)
#	set_radius(0)
	pass

func open():
	tween.stop_all()
	tween.interpolate_method(
		self, "set_radius",
		0.0, MAX_RADIUS,
		0.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT
	)
	tween.start()

func close():
	tween.stop_all()
	tween.interpolate_method(
		self, "set_radius",
		MAX_RADIUS, 0.0,
		0.5, Tween.TRANS_SINE, Tween.EASE_IN_OUT
	)
	tween.start()

func set_radius(radius):
	#print("vignette radius set to ", radius)
	material.set_shader_param("radius", radius)
