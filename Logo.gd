extends Node2D

func play_intro():
	$AnimationPlayer.play("show")
func show_logo():
	$AnimationPlayer.play("static")
func hide_logo():
	$AnimationPlayer.play("hide")
