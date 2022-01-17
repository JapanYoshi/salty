extends Control


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func setup(name, number, type):
	$Bg/Name.set_text(name)
	$Bg/Number.set_text("%d" % (number + 1))
	$Bg/Type.animation = type
	$AnimationPlayer.play("appear")
