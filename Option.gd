extends Node2D

export var index = 0

onready var anim = $Option/AnimationPlayer
onready var button = $Option/HSplitContainer/Button
onready var textbox = $Option/HSplitContainer/Content

# Called when the node enters the scene tree for the first time.
func _ready():
	button.set_text(["↑", "←", "→", "↓"][index])
	anim.play("wrong_silent", -1, 1000)
	pass # Replace with function body.

func reset():
	anim.play("wrong_silent", -1, 10000, false)

func set_content(content: String):
	textbox.bbcode_text = content

func enter(i):
	yield(get_tree().create_timer(i * 0.1), "timeout")
	anim.play("show")

func leave():
	anim.play("wrong_silent")

func highlight():
	anim.play("highlight")

func wrong():
	anim.play("wrong")

func right():
	anim.play("right")

func _on_Option_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.pressed:
			print("Clicked option %d" % index + " (reaction not implemented)")
			C.emit_signal("gp_button", 4, [1, 3, 5, 4][index], true)
