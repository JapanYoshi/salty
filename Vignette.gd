extends ColorRect

onready var tween = Tween.new()
const MAX_RADIUS = 1.01;
const EASE_TIME = 0.5;
const EASE_X = 0.23;
const EASE_Y = 0.18;
signal tween_finished

# Called when the node enters the scene tree for the first time.
func _ready():
	color = Color.black
	add_child(tween)
	tween.connect("tween_all_completed", self, "emit_signal", ["tween_finished"])
#	set_radius(0)
	pass

func open():
	tween.stop_all()
	tween.interpolate_method(
		self, "set_radius",
		0.0, MAX_RADIUS * EASE_Y,
		EASE_TIME * EASE_X, Tween.TRANS_QUAD, Tween.EASE_IN
	)
	tween.interpolate_method(
		self, "set_radius",
		MAX_RADIUS * EASE_Y, MAX_RADIUS,
		(1.0 - EASE_TIME) * EASE_X, Tween.TRANS_QUAD, Tween.EASE_IN,
		EASE_TIME * EASE_X
	)
	tween.start()

func close():
	tween.stop_all()
	tween.interpolate_method(
		self, "set_radius",
		MAX_RADIUS, MAX_RADIUS * (1.0 - EASE_Y),
		EASE_TIME * EASE_X, Tween.TRANS_QUAD, Tween.EASE_IN
	)
	tween.interpolate_method(
		self, "set_radius",
		MAX_RADIUS * (1.0 - EASE_Y), 0.0,
		(1.0 - EASE_TIME) * EASE_X, Tween.TRANS_QUAD, Tween.EASE_IN,
		EASE_TIME * EASE_X
	)
	tween.start()

func set_radius(radius):
	#print("vignette radius set to ", radius)
	material.set_shader_param("radius", radius)
