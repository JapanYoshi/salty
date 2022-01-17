extends Control

var settings_dict = [
	{
		k = "graphics_quality",
		t = "Graphics quality",
		o = [
			{
				v = 0,
				t = "potato",
				d = "Don’t animate background shaders. Render everything at 720p."
			},
			{
				v = 1,
				t = "toaster",
				d = """Don’t animate intensive background shaders like Perlin noise. Scale, but less smoothly.
Animated shaders:
• Sugar Rush rings"""
			},
			{
				v = 2,
				t = "smart fridge",
				d = "Animate background shaders. Scale everything smoothly."
			}
		]
	},{
		k = "room_openness",
		t = "Room openness",
		o = [
			{
				v = 0,
				t = "no room",
				d = "Don’t use phones as controllers. In fact, don’t even bother opening a room or connecting to the game server."
			},
			{
				v = 1,
				t = "vetted",
				d = "Players on their phones must be allowed in one by one."
			},
			{
				v = 2,
				t = "open room",
				d = "Players on their phones are automatically let in."
			}
		]
	},{
		k = "subtitles",
		t = "Subtitles",
		o = [
			{
				v = false,
				t = "off",
				d = "Don’t show subtitles on screen."
			},
			{
				v = true,
				t = "on",
				d = "Show subtitles on screen, so that you can talk over the host without missing what she has to say."
			}
		]
	},{
		k = "music",
		t = "Music",
		o = [
			{
				v = false,
				t = "off",
				d = "No background music, just the host’s voice and you."
			},
			{
				v = true,
				t = "on",
				d = "Play the bangin’ soundtrack in the background as you play."
			}
		]
	},{
		k = "cutscenes",
		t = "Cutscenes/Tutorials",
		o = [
			{
				v = false,
				t = "off",
				d = """Skip [i]most[/i] cutscenes and tutorials, and only play the questions.
Exceptions:
• Candy Trivia joke
• Sorta Kinda explanation
• Sorta Kinda outro (when it shows you the top accuracy)
"""
			},
			{
				v = true,
				t = "on",
				d = "Watch all the cutscenes and tutorials for a full experience."
			}
		]
	},{
		k = "awesomeness",
		t = "Detect awesomeness",
		o = [
			{
				v = false,
				t = "off",
				d = "Nah."
			},
			{
				v = true,
				t = "on",
				d = "Yeah!"
			}
		]
	}
]
var ring_speed = 1
var focus_index = 0
onready var temp_config = R.cfg.duplicate()
onready var vbox = $Scroll/VBoxContainer
onready var title = $Details/Name
onready var desc = $Details/Desc

func _ready():
	S.play_music("options", 1)
	for i in range(len(temp_config)):
		focus_index = i
		change_desc(true)
	focus_index = 0
	vbox.get_child(1 + focus_index).get_node("VBox/HBoxContainer/HSlider").grab_focus()

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_BackButton_back_pressed()
	elif event.is_action_pressed("ui_select"):
		_on_SaveButton_pressed()

func change_title():
	title.text = settings_dict[focus_index].t

func change_desc(backwards: bool = true):
	print (temp_config)
	var set = settings_dict[focus_index]
	var setting_name = set.k
	var options = set.o
	var val = int(temp_config[set.k])
	desc.bbcode_text = "[i]" + options[val].t + "[/i] - " + options[val].d
	var ind = vbox.get_child(1 + focus_index).get_node_or_null("VBox/HSplit/value")
	if ind:
		ind.text = options[val].t
	if backwards:
		var slider = vbox.get_child(1 + focus_index).get_node_or_null("VBox/HBoxContainer/HSlider")
		if slider:
			slider.set_value(options[val].v)
		else:
			var checkbox = vbox.get_child(1 + focus_index).get_node_or_null("VBox/HSplit/SBox")
			if checkbox:
				checkbox.set_pressed_no_signal(options[val].v)

func _on_HSlider_value_changed(value):
	var setting_name = settings_dict[focus_index].k
	temp_config[setting_name] = value
	if settings_dict[focus_index].k == "graphics_quality":
		R._set_visual_quality(value)
	elif settings_dict[focus_index].k == "music":
		if value == true:
			S._play_music("options")
		else:
			S._stop_music("options")
	change_desc()

func _change_focus(extra_arg_0):
	focus_index = extra_arg_0
	change_title()
	change_desc()

func _on_check_toggled(button_pressed):
	_on_HSlider_value_changed(button_pressed)

func _on_BackButton_back_pressed():
	R._set_visual_quality(R.cfg.graphics_quality)
	get_tree().change_scene("res://Title.tscn")

func _on_SaveButton_pressed():
	R.cfg = temp_config
	R.save_settings()
	R._set_visual_quality(R.cfg.graphics_quality)
	get_tree().change_scene("res://Title.tscn")
