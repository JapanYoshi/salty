extends Control
const radius: float = 540.0
var radius_scale: float = 0.0
var color: Color = Color("#56405c")
var maxerror = 0.25
var last_radius_scale: float = 0.0

func _process(delta):
	if radius_scale != last_radius_scale:
		update()

func _draw():
	_draw_circle_custom()

func _draw_circle_custom():
	last_radius_scale = radius_scale
	if radius_scale <= 0.0:
		return
	var maxpoints = 1024 # I think this is renderer limit
	var numpoints = ceil(PI / acos(1.0 - maxerror / (radius * radius_scale)))
	numpoints = clamp(numpoints, 3, maxpoints)
	var points = PoolVector2Array([])
	for i in numpoints:
		var phi = i * PI * 2.0 / numpoints
		var v = (Vector2.ONE + Vector2.RIGHT.rotated(phi) * radius_scale) * radius
		points.push_back(v)
	draw_colored_polygon(points, color)
