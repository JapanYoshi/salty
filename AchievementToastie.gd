extends Node2D

signal toastie_hidden(index)

export var index: int = -1
onready var title = $bg/title
onready var icon = $bg/icon
onready var anim = $anim
onready var timer = $timer


func _on_hide_timer():
	anim.play("hide")


func show_toastie(name: String, texture: Texture):
	icon.texture = texture

	title.text = name
	anim.play("show")
	S.play_sfx("achievement")
	timer.start()


func _on_animation_finished(anim_name):
	if anim_name == "hide":
		emit_signal("toastie_hidden", index)
