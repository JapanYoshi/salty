extends Control
var menu_root: Control
var ep_scroller: VBoxContainer
var eps = {}
#var eps = {"RQ": {
#	id = "RQ",
#	filename = "random",
#	name = "choose random questions",
#	desc = "Randomly choose 13 questions to create your very own special episode of Salty Trivia. Let’s hope there are no repeats.",
#	hs = {...},
#}}
var selected_now = ""
var first = ""
var last = ""
var disable_controls = false

onready var el_name = $Details/V/Name
onready var el_locked = $Details/V/Stats/V0/Locked
onready var el_last_played = $Details/V/Stats/V1/LastPlayed
onready var el_high_score = $Details/V/Stats/V0/HiScore
onready var el_best_acc = $Details/V/Stats/V1/BestAcc
onready var el_desc = $Details/V/Desc

# Called when the node enters the scene tree for the first time.
func _ready():
	ep_scroller = get_node_or_null("ScrollContainer/VBoxContainer")
	ep_scroller.get_parent().get_v_scrollbar().rect_min_size.x = 32
	var ep_box = ep_scroller.get_node("Option")
	ep_box.name = "Template"
	for e in Loader.episodes.keys():
		var ep = {
			id = Loader.episodes[e].episode_id if "episode_id" in Loader.episodes[e] else "i%d" % len(eps),
			filename = e,
			name = Loader.episodes[e].episode_name,
			desc = Loader.episodes[e].episode_desc,
			hs = R.get_high_score(e),
		}
		eps[ep.id] = ep
		if first == "":
			first = ep.id
		last = ep.id
		var new_box = ep_box.duplicate()
		new_box.name = ep.id
		new_box.get_node("VBox/Split/Num/Text").set_text(ep.id)
		new_box.get_node("VBox/Split/Title").set_text(ep.name)
		if ep.hs.locked:
			new_box.self_modulate = Color(0.5, 0.5, 0.5, 1.0)
			new_box.get_node("VBox/Split/Num/Text").modulate = Color(1.0, 1.0, 1.0, 0.25)
			new_box.get_node("VBox/Split/Title").modulate = Color(1.0, 1.0, 1.0, 0.25)
		ep_scroller.add_child(new_box)
		ep_scroller.move_child(
			$ScrollContainer/VBoxContainer/BottomSpacer,
			ep_scroller.get_child_count() - 1
		)
	ep_scroller.get_node(first).grab_focus()
	ep_box.queue_free()
	focus_shifted(first)


func focus_shifted(which):
	print("focus_shifted to ", which)
	if selected_now != which:
		selected_now = which
		S.play_sfx("menu_move")
		print("Shifted focus")
		# update info panel
		el_name.set_text(eps[selected_now].name)
		
		var hs = eps[selected_now].hs
		if hs.last_played == 0:
			el_last_played.bbcode_text = "Never played"
		else:
			el_last_played.bbcode_text = "Last play: %s" % R.format_date(hs.last_played)
			
		if hs.high_score_time == 0:
			el_high_score.bbcode_text = "High score: %s (never)" % R.format_currency(0)
		else:
			el_high_score.bbcode_text = "High score: %s (%s)" % [
				R.format_currency(hs.high_score),
				R.format_date(hs.high_score_time),
			]
		
		if hs.best_accuracy_time == 0:
			el_best_acc.bbcode_text = "Best accuracy: 0.0% (never)"
		else:
			el_best_acc.bbcode_text = "Best accuracy: %.1f%% (%s)" % [
				hs.best_accuracy * 100.0,
				R.format_date(hs.best_accuracy_time)
			]
		
		el_desc.clear()
		if hs.locked:
			el_locked.bbcode_text = "Locked"
			el_desc.append_bbcode("This episode is locked. Play the other episodes to unlock it.")
		else:
			el_locked.bbcode_text = "Playable"
			el_desc.append_bbcode(eps[selected_now].desc)
		
		R.pass_between.episode_name = eps[selected_now].filename
		if which == first:
			ep_scroller.get_parent().set_v_scroll(0)
		elif which == last:
			ep_scroller.get_parent().set_v_scroll(1 << 15)

func _input(event):
	var focus_index = ep_scroller.get_focus_owner().get_index()
	if event.is_action_pressed("ui_down"):
		accept_event()
		var child = ep_scroller.get_child(focus_index+1)
		if child is Button:
			child.grab_focus()
			focus_shifted(child.name)
		else:
			S.play_sfx("menu_stuck")
	elif event.is_action_pressed("ui_up"):
		accept_event()
		var child = ep_scroller.get_child(focus_index-1)
		if child is Button:
			child.grab_focus()
			focus_shifted(child.name)
		else:
			S.play_sfx("menu_stuck")
	elif event.is_action_pressed("ui_accept"):
		_on_Option_pressed()
		accept_event()
		pass
	elif event.is_action_pressed("ui_cancel"):
		accept_event()
		menu_root.back()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		accept_event()

func _on_Option_pressed():
	if disable_controls: return
	var this_box = get_focus_owner()
	if selected_now == this_box.name:
		if eps[selected_now].hs.locked:
			S.play_sfx("menu_fail")
			var ease_time = 1.0 / 30.0
			var ease_size = 32.0
			var ease_shake = 6.0
			var ease_fade = 0.8
			var tween = $Tween
			tween.stop_all()
			tween.interpolate_property(
				this_box, "rect_position:x",
				0.0, ease_size, ease_time,
				Tween.TRANS_SINE, Tween.EASE_OUT
			)
			var from = pow(ease_size, 1)
			for i in range(ease_shake):
				var to1 = -pow(ease_fade, i * 4 + 1) * ease_size
				var to2 = pow(ease_fade, i * 4 + 3) * ease_size
				tween.interpolate_property(
					this_box, "rect_position:x",
					from, to1, ease_time * 2.0,
					Tween.TRANS_SINE, Tween.EASE_IN_OUT, ease_time * (1.0 + i * 4.0)
				)
				tween.interpolate_property(
					this_box, "rect_position:x",
					to1, to2, ease_time * 2.0,
					Tween.TRANS_SINE, Tween.EASE_IN_OUT, ease_time * (3.0 + i * 4.0)
				)
				from = to2
			tween.interpolate_property(
				this_box, "rect_position:x",
				from, 0.0, ease_time,
				Tween.TRANS_SINE, Tween.EASE_IN, ease_time * (1.0 + ease_shake * 4.0)
			)
			tween.start()
		else:
			disable_controls = true
			S.play_sfx("menu_confirm")
			release_focus()
			menu_root.choose_episode(eps[selected_now].filename)
	else:
		focus_shifted(get_focus_owner().name)

func _on_BackButton_back_pressed():
	S.play_sfx("menu_back")
	menu_root.back()
