extends Control
onready var anim = $AnimationPlayer
onready var text_box = $Bg/CenterContainer/RichTextLabel
var idx

func _ready():
	anim.play("hide", -1, 10000)
	idx = get_index()
	$Btn/Label.set_text(
		"↖↑↗←↓→"[idx]
	)

func set_option(bbcode):
	text_box.clear()
	text_box.append_bbcode(
		"[center]%s[/center]" % bbcode
	)

func enter():
	anim.play("show")

func time_up():
	anim.play("reveal")

func reveal_option(truthy):
	anim.play("yes" if truthy else "no")

func exit():
	anim.stop()
	if modulate.a > 0.0:
		anim.play("hide")

func _on_TouchBtn_pressed():
	C.inject_button(4, idx, true)
