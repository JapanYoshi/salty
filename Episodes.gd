extends Control
onready var ep_scroller = $ScrollContainer/VBoxContainer
var eps = {}
#var eps = {"RQ": {
#	id = "RQ",
#	filename = "random",
#	name = "choose random questions",
#	desc = "Randomly choose 13 questions to create your very own special episode of Salty Trivia. Let’s hope there are no repeats.",
#	locked = false
#}}
var selected_now = ""
var first = ""
var last = ""
var disable_controls = false

# Called when the node enters the scene tree for the first time.
func _ready():
	print("Episodes readying...")
	ep_scroller.get_parent().get_v_scrollbar().rect_min_size.x = 32
	var ep_box = ep_scroller.get_node("Option")
	ep_box.name = "Template"
	for e in Loader.episodes.keys():
		var ep = {
			id = Loader.episodes[e].episode_id if "episode_id" in Loader.episodes[e] else "i%d" % len(eps),
			filename = e,
			name = Loader.episodes[e].episode_name,
			desc = Loader.episodes[e].episode_desc,
			locked = false
		}
		eps[ep.id] = ep
		if first == "":
			first = ep.id
		last = ep.id
		var new_box = ep_box.duplicate()
		new_box.name = ep.id
		new_box.get_node("VBox/Split/Num/Text").set_text(ep.id)
		new_box.get_node("VBox/Split/Title").set_text(ep.name)
		ep_scroller.add_child(new_box)
		ep_scroller.move_child($ScrollContainer/VBoxContainer/BottomSpacer, ep_scroller.get_child_count()-1)
#	if eps.has("RQ"):
#		first = "RQ"
#		ep_box.grab_focus()
#	else:
	ep_scroller.get_node(first).grab_focus()
	ep_box.queue_free()
	focus_shifted(first)
	print("Episodes readied.")

func focus_shifted(which):
	print("focus_shifted to ", which)
	if selected_now != which:
		selected_now = which
		S.play_sfx("menu_move")
		print("Shifted focus")
		$Details/Name.set_text(eps[selected_now].name)
		$Details/Desc.clear()
		if eps[selected_now].has("locked") and eps[selected_now].locked == true:
			$Details/Desc.append_bbcode("This episode is locked.")
		else:
			$Details/Desc.append_bbcode(eps[selected_now].desc)
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
		get_parent().back()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		accept_event()

func _on_Option_pressed():
	if disable_controls: return
	if selected_now == get_focus_owner().name:
		if eps[selected_now].has('locked') and eps[selected_now].locked:
			S.play_sfx("menu_fail")
		else:
			disable_controls = true
			S.play_sfx("menu_confirm")
			release_focus()
			get_parent().choose_episode(eps[selected_now].filename)
	else:
		focus_shifted(get_focus_owner().name)

func _on_BackButton_back_pressed():
	S.play_sfx("menu_back")
	get_parent().back()
