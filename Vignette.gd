extends ColorRect

onready var tween = Tween.new()
const MAX_RADIUS = 1.25;
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
