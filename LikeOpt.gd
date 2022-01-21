extends Control

var displayed: bool = false
export var is_last: bool = false
var content: String = "Lorem ipsum"
onready var anim = $Anim
onready var text0 = $P0/HSplitContainer/CenterContainer/RichTextLabel
onready var text1 = $P1/HSplitContainer/CenterContainer/RichTextLabel

func _ready():
	reset()

#func _process(delta):
#	if anim.is_playing():
#		prints(self.get_index(), anim.current_animation, anim.current_animation_position)
#	else:
#		prints(self.get_index(), "N/A")

func reset():
	anim.play("enter")
	anim.stop(true)

func enter(new_content: String):
	content = new_content
	if is_last:
		text1.clear()
		text1.append_bbcode(new_content)
	else:
		text0.clear()
		text0.append_bbcode(new_content)
	anim.advance(10)
	anim.stop(false)
	anim.play("enter", -1, 1)
	print(self.get_index(), "ENTER")

func next(new_content: String):
	content = new_content
	if is_last:
		text1.clear()
		text1.append_bbcode(new_content)
	else:
		text0.clear()
		text0.append_bbcode(new_content)
	anim.play("next", -1, 1)
	print(self.get_index(), "NEXT")

func leave():
	anim.advance(10)
	anim.stop(false)
	anim.play("leave", -1, 1)
	print(self.get_index(), "LEAVE")

func ready_reveal():
	anim.advance(10)
	anim.stop(false)
	if is_last:
		text0.clear()
		text0.append_bbcode(content)
	anim.play("reveal", -1, 1)
	print(self.get_index(), "READY_REVEAL")

func reveal(truthy: bool):
	anim.advance(10)
	anim.play("yes" if truthy else "no")
	print(self.get_index(), "REVEAL")

func _on_Anim_animation_finished(anim_name):
	anim.stop(false)
