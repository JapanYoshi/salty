extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready():
	var max_value = 10000.0
	var arr = []
	for count in range(90, 120):
		var value = 0.0
		if count <= 100:
			value = floor(max_value * pow(10, -count / 20.0) * 1000) / 1000
		elif count < 120:
			value = (120 - count) * 0.005
		elif count == 120:
			value = 0
		arr.push_back(
			R.format_currency(value, true, 4)
		)
	print(JSON.print(arr, ""))
