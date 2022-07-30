extends Control
var title: PackedScene = preload("res://Title.tscn")
onready var ratingImage = $"../Rating/RatingPic"
# Animated logo for hai!touch Studios.

# Called when the node enters the scene tree for the first time.
func _ready():
	print("SplashScreen ready")
	_set_rating_image()

func _set_rating_image():
	var locale = OS.get_locale()
	locale = locale.replace("-", "_") # my browser said en-US instead of en_US so here we are
	locale = locale.split("_")
	print(locale)
	match locale[1]:
		"US", "CA":
			ratingImage.texture = load("res://logo/rating_us.png")
			return
		"AU":
			ratingImage.texture = load("res://logo/rating_au.png")
			return
		"DE":
			ratingImage.texture = load("res://logo/rating_de.png")
			return
		"AL","AT","BE","BE","BE","BA","BG","HR","CY","CZ",\
		"DK","EE","FI","FR","GR","HU","IE","IS","IL","IT",\
		"KV","LV","LT","LU","ME","MT","RO","ES","SE","CH",\
		"UA","GB":
			ratingImage.texture = load("res://logo/rating_eu.png")
			return
		_:
			match locale[0]:
				"bg", "cs", "cy",\
				"da", "el", "et", "eu", "fi", "fr",\
				"ga", "gd", "gv", "he", "hr", "hu", "is", "it",\
				"kw", "lt", "lb", "lv",\
				"mt",\
				"ro", "sgs", "sq", "sr", "sv",\
				"uk":
					ratingImage.texture = load("res://logo/rating_eu.png")
					return
				_:
					ratingImage.texture = load("res://logo/rating_us.png")
					return
#	resize()
#
## Called when the window is initialized.
## It overrides the default scaling behavior based on 360x640px.
#func resize():
#	var viewport = self.get_tree().get_root().get_visible_rect().size
#	var scale = min(viewport.x, viewport.y) / 1080.0
#	set_scale(Vector2(scale, scale))

# Called when the logo is finished animating.
# Also called when the user skips the logo.
func _on_AnimationPlayer_animation_finished(anim_name):
	if anim_name == "haitouch":
		$AnimationPlayer.play("jackbox")
	else:
		get_tree().change_scene_to(title)

# Called when the user skips the logo.
func skip():
	var anim_name = $AnimationPlayer.current_animation
	if anim_name == "":
		S.play_sfx("key_press")
		$AnimationPlayer.play("haitouch")
	else:
		$AnimationPlayer.seek(100,true)
		_on_AnimationPlayer_animation_finished(anim_name)

func _input(event):
	if "pressed" in event and event.pressed:
		if Input.is_action_pressed("ui_accept"):
			skip()
		elif event is InputEventMouseButton:
			if event.button_index == BUTTON_LEFT:
				skip()
