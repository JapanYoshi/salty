extends ColorRect

onready var close_button = $ScreenStretch/ColorRect/Panel/ScrollContainer/VBoxContainer/Button
onready var scroller = $ScreenStretch/ColorRect/Panel/ScrollContainer
var max_scroll = 99999.9

const SCROLL_SPEED: float = 500.0
var current_scroll: float = 0.0
var current_scroll_speed: float = 0.0
var mouse_timeout: float = 0.0

func _ready():
	current_scroll = 0.0
	max_scroll = scroller.get_child(0).rect_size.y - scroller.rect_size.y + 16.0
	S.play_music("load_loop", 0.5)

func _process(delta):
	if mouse_timeout > 0.0:
		mouse_timeout -= delta
		current_scroll = scroller.get_v_scroll()
		return
	current_scroll += delta * current_scroll_speed
	current_scroll = max(0.0, current_scroll)
	if current_scroll >= max_scroll:
		current_scroll = max_scroll
		if close_button.disabled:
			close_button.disabled = false
			close_button.grab_focus()
			S.play_sfx("menu_move")
	else:
		if close_button.disabled == false:
			close_button.disabled = true
	scroller.set_v_scroll(current_scroll)

func _unhandled_input(e: InputEvent):
	if e is InputEventKey and e.is_echo():
		accept_event(); return
	if e.is_action_pressed("ui_down"):
		accept_event()
		current_scroll_speed = SCROLL_SPEED
	elif e.is_action_pressed("ui_up"):
		accept_event()
		current_scroll_speed = -SCROLL_SPEED
	elif (
		e.is_action_released("ui_down") or e.is_action_released("ui_up")
	):
		accept_event()
		current_scroll_speed = 0


func _on_ScrollContainer_gui_input(event):
	if event is InputEventMouseButton:
		mouse_timeout = 0.5
	print(event.as_text())


func _on_Button_pressed():
	R.set_save_data_item("misc", "never_seen_disclaimer", false)
	R.save_save_data()
# warning-ignore:return_value_discarded
	get_tree().change_scene("res://Title.tscn")
