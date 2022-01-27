extends Node2D
var eta_f = 0.0

# Called when the node enters the scene tree for the first time.
func _ready():
	eta_f = 70.0

func _process(delta):
	eta_f -= delta
	var eta = int(eta_f * 1000.0)
	var time_text = "Almost there..."
	if eta >= 60*1000:
		time_text = "Please wait ≈%dm %0.1fs..." % [eta / (60*1000), (eta % (60*1000)) / 1000.0]
	elif eta >= 3000:
		time_text = "Please wait ≈%0.1fs..." % (eta / 1000.0)
	$Label.set_text(time_text)
