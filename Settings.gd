extends Control

var settings_dict = [
	{
		k = "graphics_quality",
		t = "Graphics quality",
		r = [0, 2],
		o = [
			{
				v = 0,
				t = "potato",
				d = "Don’t animate any background shaders (except for animated textures). Do not scale from 720p."
			},
			{
				v = 1,
				t = "toaster",
				d = "Animate some background shaders. Scale smoothly, but sacrifice text clarity.\nAnimated shaders:\n• Sugar Rush rings"
			},
			{
				v = 2,
				t = "smart fridge",
				d = "Animate background shaders. Scale everything smoothly."
			}
		]
	},{
		k = "room_size",
		t = "Room size",
		r = [0, 7],
		o = [
			{
				v = 0,
				t = "1 player",
				d = "Who needs that pesky competition when you can play with yourself, amirite?"
			},
			{
				v = 1,
				t = "1 - 2 players",
				d = "A romantic round of Salty Trivia with your loved one. Or a balls-to-the-wall one-on-one duel."
			},
			{
				v = 2,
				t = "1 - 3 players",
				d = "A classic three-way. One player slot for each of your two friends!"
			},
			{
				v = 3,
				t = "1 - 4 players",
				d = "You think any more than 4 players is overkill, really."
			},
			{
				v = 4,
				t = "1 - 5 players",
				d = "Shake your body if you’re feeling like a fi-i-ive-player game."
			},
			{
				v = 5,
				t = "1 - 6 players",
				d = "A perfect number of players! (mathematically speaking, 6 is a “perfect number”)"
			},
			{
				v = 6,
				t = "1 - 7 players",
				d = "6 out of 7 people are satisfied with a 7-player game. Screw that other 1 person."
			},
			{
				v = 7,
				t = "1 - 8 players",
				d = "A standard 8-player game. If you can fill this room up, you’re probably a good streamer."
			}
		]
	},{
		k = "room_openness",
		t = "Room openness",
		r = [0, 2],
		o = [
			{
				v = 0,
				t = "no room",
				d = "Don’t use phones as controllers. In fact, don’t even bother opening a room or connecting to the game server. Recommended for Android."
			},
			{
				v = 1,
				t = "vetted",
				d = "Players on their phones must be allowed in one by one. (However, once the room is full, they can join the audience freely, assuming that you’ve left that feature on.) Not recommended for Android."
			},
			{
				v = 2,
				t = "open room",
				d = "Players on their phones are automatically let in. Not recommended for Android."
			}
		]
	},{
		k = "audience",
		t = "Audience",
		r = [0, 1],
		o = [
			{
				v = false,
				t = "closed",
				d = "If people want to play along, you want them to keep score on a piece of paper or something."
			},
			{
				v = true,
				t = "open",
				d = "Let people use their phones as controllers to play along, even without a proper spot as a contestant."
			}
		]
	},{
		k = "remote_start",
		t = "Start game from remote",
		r = [0, 1],
		o = [
			{
				v = false,
				t = "forbid",
				d = "Only start the game from the host’s PC, not from phones as controllers."
			},
			{
				v = true,
				t = "allow",
				d = "When using phones as controllers, allow the game to be started from it."
			}
		]
	},{
		k = "subtitles",
		t = "Subtitles",
		r = [0, 1],
		o = [
			{
				v = false,
				t = "hide",
				d = "Don’t show subtitles on screen."
			},
			{
				v = true,
				t = "show",
				d = "Show subtitles on screen, so that you can talk over the host without missing what she has to say."
			}
		]
	},{
		k = "overall_volume",
		t = "Volume",
		r = [0, 15],
		o = [
			{
				v = 0,
				t = "Mute",
				d = "why"
			},
			{v =  1,	t = "1/15",	d = ""},
			{v =  2,	t = "2/15",	d = ""},
			{v =  3,	t = "3/15",	d = ""},
			{v =  4,	t = "4/15",	d = ""},
			{
				v =  5,
				t = "5/15",
				d = "Recommended if you’re also, like, on a Zoom call at this very moment, and you don’t want the game being way louder than your participants."
			},
			{v =  6,	t = "6/15",	d = ""},
			{v =  7,	t = "7/15",	d = ""},
			{v =  8,	t = "8/15",	d = ""},
			{v =  9,	t = "9/15",	d = ""},
			{v = 10,	t = "10/15",	d = ""},
			{v = 11,	t = "11/15",	d = ""},
			{v = 12,	t = "12/15",	d = ""},
			{v = 13,	t = "13/15",	d = ""},
			{v = 14,	t = "14/15",	d = ""},
			{
				v = 15,
				t = "Full",
				d = "I paid for the whole speaker, I’m gonna use the whole speaker."
			}
		]},{
		k = "music_volume",
		t = "Music volume",
		r = [0, 15],
		o = [
			{
				v = 0,
				t = "Mute",
				d = "Recommended if music makes you lose control. (We would rather have you under control at all times.)"
			},
			{v =  1,	t = "1/15",	d = ""},
			{v =  2,	t = "2/15",	d = ""},
			{v =  3,	t = "3/15",	d = ""},
			{v =  4,	t = "4/15",	d = ""},
			{v =  5,	t = "5/15",	d = ""},
			{v =  6,	t = "6/15",	d = ""},
			{v =  7,	t = "7/15",	d = ""},
			{v =  8,	t = "8/15",	d = ""},
			{v =  9,	t = "9/15",	d = ""},
			{
				v = 10,
				t = "10/15",
				d = "Recommended for those who want to hear the dialogue more clearly."
			},
			{v = 11,	t = "11/15",	d = ""},
			{v = 12,	t = "12/15",	d = ""},
			{v = 13,	t = "13/15",	d = ""},
			{v = 14,	t = "14/15",	d = ""},
			{
				v = 15,
				t = "Full",
				d = "Play that funky music right into my ears!"
			}
		]
	},{
		k = "cutscenes",
		t = "Cutscenes/Tutorials",
		r = [0, 1],
		o = [
			{
				v = false,
				t = "skip",
				d = "Skip [i]most[/i] cutscenes and tutorials, and only play the questions.\nExceptions:\n• Candy Trivia joke\n• Sorta Kinda explanation (skippable)\n• Sorta Kinda outro (when it shows you the top accuracy)\n• Ending cutscene"
			},
			{
				v = true,
				t = "play",
				d = "Watch all the cutscenes and tutorials for a full experience."
			}
		]
	},{
		k = "hide_room_code",
		t = "Start with the room code...",
		r = [0, 1],
		o = [
			{
				v = false,
				t = "visible",
				d = "Let everyone see the Room Code. Come join in, everyone!"
			},
			{
				v = true,
				t = "hidden",
				d = "Hide the Room Code when you connect, and only show the Room Code when you’re ready for it. Ideal for Twitch streamers (if this game garners enough attention for Twitch streamers to stream this game in the first place)."
			}
		]
	},{
		k = "hide_room_code_ingame",
		t = "Hide room code in-game",
		r = [0, 1],
		o = [
			{
				v = false,
				t = "visible",
				d = "Let everyone see the Room Code. Come join in, everyone!"
			},
			{
				v = true,
				t = "hidden",
				d = "Don’t show the Room Code while you’re playing. If you disconnect, good luck with that."
			}
		]
	},{
		k = "awesomeness",
		t = "Detect awesomeness",
		r = [0, 1],
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
onready var temp_config = ConfigFile.new()
onready var vbox = $ScreenStretch/Scroll/VBoxContainer
onready var title = $ScreenStretch/Details/V/Name
onready var desc = $ScreenStretch/Details/V/Desc
var setting_elements = []
var setting_is_bool = []
var setup_done = false

func _set_temp_config(key: String, value):
	temp_config.set_value("config", key, value)

func _get_temp_config(key: String):
	return temp_config.get_value("config", key)

func _ready():
	if R.html:
		$ScreenStretch/ButtonAsset.show()
	else:
		$ScreenStretch/ButtonAsset.hide()
	S.play_music("house", 1)
	# Set up the options. Finally automate this sucker.
	var range_used: bool = false
	var bool_used: bool = false
	for i in range(len(settings_dict)):
		focus_index = i # prevent weirdness upon changing slider values
		var element: Node
		var s = settings_dict[i]
		var is_a_boolean = (s.r[0] == 0 and s.r[1] == 1)
		setting_is_bool.push_back(is_a_boolean)
		var headline_text = s.t
		_set_temp_config(s.k, R.get_settings_value(s.k))
		var cb_or_slider: Node
		if is_a_boolean:
			element = vbox.get_node("Bool")
			if bool_used:
				element = element.duplicate()
				vbox.add_child(element)
			else:
				bool_used = true
			cb_or_slider = element.get_node("VBox/HSplit/SBox") as CheckBox
			cb_or_slider.set_pressed_no_signal(_get_temp_config(s.k))
			cb_or_slider.connect("toggled", self, "_on_check_toggled")
		else:
			element = vbox.get_node("Range")
			if range_used:
				element = element.duplicate()
				vbox.add_child(element)
			else:
				range_used = true
			cb_or_slider = element.get_node("VBox/HBoxContainer/HSlider") as HSlider
			cb_or_slider.min_value = s.r[0]
			cb_or_slider.max_value = s.r[1]
			cb_or_slider.tick_count = s.r[1] - s.r[0]
			cb_or_slider.value = _get_temp_config(s.k)
			cb_or_slider.connect("value_changed", self, "_on_HSlider_value_changed")
		cb_or_slider.connect("focus_entered", self, "_change_focus", [i])

		vbox.move_child(element, i + 1)
		element.get_node("VBox/HSplit/Label").set_text(headline_text)
		element.get_node("VBox/HSplit/value").text = s.o[int(_get_temp_config(s.k))].t
		setting_elements.push_back(element)

	# set focus neighbors manually
	focus_index = 0
	for i in range(len(setting_elements)):
		var element = setting_elements[i]
		var cb_or_slider: Node
		if setting_is_bool[i]:
			cb_or_slider = element.get_node("VBox/HSplit/SBox") as CheckBox
		else:
			cb_or_slider = element.get_node("VBox/HBoxContainer/HSlider") as HSlider
		element.connect("mouse_entered", self, "_on_option_mouse_entered", [i])

		var i_before = posmod(i - 1, len(setting_elements))
		if setting_is_bool[i_before]:
			cb_or_slider.focus_neighbour_top = setting_elements[i_before].get_node("VBox/HSplit/SBox").get_path()
		else:
			cb_or_slider.focus_neighbour_top = setting_elements[i_before].get_node("VBox/HBoxContainer/HSlider").get_path()
		var i_after = posmod(i + 1, len(setting_elements))
		if setting_is_bool[i_after]:
			cb_or_slider.focus_neighbour_bottom = setting_elements[i_after].get_node("VBox/HSplit/SBox").get_path()
		else:
			cb_or_slider.focus_neighbour_bottom = setting_elements[i_after].get_node("VBox/HBoxContainer/HSlider").get_path()
	# finally focus on the first item
	if setting_is_bool[0]:
		vbox.get_child(1).get_node("VBox/HSplit/SBox").grab_focus()
	else:
		vbox.get_child(1).get_node("VBox/HBoxContainer/HSlider").grab_focus()
	change_title()
	change_desc()
	scroll_scroller()
	setup_done = true

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_BackButton_back_pressed()
	elif event.is_action_pressed("ui_select"):
		_on_SaveButton_pressed()

func change_title():
	title.text = settings_dict[focus_index].t

func change_desc(backwards: bool = true):
	var set = settings_dict[focus_index]
	var setting_name = set.k
	var options = set.o
	var val = int(_get_temp_config(set.k))
	desc.bbcode_text = "[i]" + options[val].t + "[/i]"
	if options[val].d != "":
		desc.append_bbcode(" - " + options[val].d)
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

# Scroll the currently selected element into view
onready var scroll: ScrollContainer = $ScreenStretch/Scroll
var scroll_margin: float = 16.0
func scroll_scroller():
	if scroll.scroll_vertical > setting_elements[focus_index].rect_position.y:
		print("focused element is too high")
		scroll.scroll_vertical = \
			setting_elements[focus_index].rect_position.y\
			- scroll_margin
	elif scroll.scroll_vertical + scroll.rect_size.y < setting_elements[focus_index].rect_position.y + setting_elements[focus_index].rect_size.y:
		print("focused element is too low")
		scroll.scroll_vertical = \
			setting_elements[focus_index].rect_position.y\
			+ setting_elements[focus_index].rect_size.y\
			- scroll.rect_size.y\
			+ scroll_margin

func _on_HSlider_value_changed(value):
	var setting_name = settings_dict[focus_index].k
	_set_temp_config(setting_name, value)
	if typeof(value) == TYPE_REAL and setup_done:
		var slider = vbox.get_child(1 + focus_index).get_node("VBox/HBoxContainer/HSlider")
		if is_instance_valid(slider):
			S.play_sfx(
				"key_move",
				range_lerp(
					# map this...
					value,
					# from this range...
					settings_dict[focus_index].r[0],
					settings_dict[focus_index].r[1],
					# to this range
					1.0,
					2.0
				)
			)
	match settings_dict[focus_index].k:
		"graphics_quality":
			R._set_visual_quality(value)
		"music_volume":
			S.set_music_volume(float(value) / settings_dict[focus_index].r[1])
		"overall_volume":
			S.set_overall_volume(float(value) / settings_dict[focus_index].r[1])
	change_desc()

func _change_focus(extra_arg_0):
	if focus_index == extra_arg_0: return
	focus_index = extra_arg_0
	change_title()
	change_desc()
	scroll_scroller()
	S.play_sfx("menu_move")

func _on_check_toggled(button_pressed):
	if setup_done:
		S.play_sfx("rush_o" + ("n" if button_pressed else "ff"))
	_on_HSlider_value_changed(button_pressed)

func _on_BackButton_back_pressed():
	R._set_visual_quality(-1)
	get_tree().change_scene("res://Title.tscn")

func _on_SaveButton_pressed():
	R.cfg = temp_config
	R.save_settings()
	R._set_visual_quality(-1)
	get_tree().change_scene("res://Title.tscn")

func _on_option_mouse_entered(extra_arg_0):
	var element = setting_elements[extra_arg_0]
	var cb_or_slider: Node
	if setting_is_bool[extra_arg_0]:
		cb_or_slider = element.get_node("VBox/HSplit/SBox") as CheckBox
	else:
		cb_or_slider = element.get_node("VBox/HBoxContainer/HSlider") as HSlider
	cb_or_slider.grab_focus()
	_change_focus(extra_arg_0)

func clear_question_cache():
	Loader.clear_question_cache()
	S.play_sfx("rush_yes")

func clear_asset_cache():
	S.play_music("", 0.0)
	Loader.clear_asset_cache()
	$ScreenStretch/AssetDeleted.show()
	get_tree().notification(MainLoop.NOTIFICATION_WM_QUIT_REQUEST)
