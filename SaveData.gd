extends ColorRect

onready var tween = $Tween

onready var tabber = $ScreenStretch/r/TabContainer
onready var header = $ScreenStretch/r/Header
onready var header_anim = $ScreenStretch/r/Header/AnimationPlayer
onready var header_left = $ScreenStretch/r/Header/Left
onready var header_center = $ScreenStretch/r/Header/Center
onready var header_right = $ScreenStretch/r/Header/Right
enum TABS {
	HIGHSCORES = 0,
	ACHIEVEMENTS = 1,
	TAB_COUNT = 2,
}
const tab_names = {
	TABS.HIGHSCORES: "High scores",
	TABS.ACHIEVEMENTS: "Achievements",
}

var high_score_item = preload("res://HighScoreItem.tscn")
onready var high_score_grid = $ScreenStretch/r/TabContainer/HighScore/Grid

var achievement_item = preload("res://achievements/AchievementItem.tscn")
onready var achievement_label = $ScreenStretch/r/TabContainer/Achievements/v/Label
onready var achievement_grid = $ScreenStretch/r/TabContainer/Achievements/v/Grid

onready var delete_modal = $ScreenStretch/r/DeleteModal
onready var delete_title = delete_modal.get_node("Panel/VBoxContainer/Label")
onready var delete_desc = delete_modal.get_node("Panel/VBoxContainer/Label2")
onready var delete_yes = delete_modal.get_node("Panel/VBoxContainer/yes")
onready var delete_no = delete_modal.get_node("Panel/VBoxContainer/no")
var delete_confirm_state: int = 0

# 1: down is pressed; 2: up is pressed; 3: both is pressed (cancel it out)
var scroll_button_state: int = 0
const SCROLL_SPEED: float = 512.0

func _ready():
	_load_high_scores()
	_load_achievements()
	delete_modal.hide()
	S.play_music("load_loop", 0.5)
	
	S.preload_voice("confirm_delete_00", "confirm_delete_00")
	S.preload_voice("confirm_delete_01", "confirm_delete_01")


func _process(delta):
	# Scrolling
	if scroll_button_state != 0:
		if scroll_button_state == 1:
			tabber.get_child(tabber.current_tab).scroll_vertical += SCROLL_SPEED * delta
		elif scroll_button_state == 2:
			tabber.get_child(tabber.current_tab).scroll_vertical -= SCROLL_SPEED * delta


func _input(event):
	if delete_confirm_state: return
	if event.is_action_pressed("ui_left"):
		_tabulate(false); return
	if event.is_action_pressed("ui_right"):
		_tabulate(true); return
	if event.is_action("ui_up"):
		if event.is_pressed():
			scroll_button_state |= 2
		else:
			scroll_button_state &= (~2)
		return
	if event.is_action("ui_down"):
		if event.is_pressed():
			scroll_button_state |= 1
		else:
			scroll_button_state &= (~1)
		return
	if event.is_action_pressed("ui_cancel"):
		_back(); return
	if event is InputEventJoypadButton and event.button_index == JOY_START:
		_confirm_delete(); return


func _tabulate(right: bool):
	header_anim.stop()
	var tab_now = tabber.current_tab
	if right:
		tab_now = (tab_now + 1) % TABS.TAB_COUNT
		header_anim.play("tab_right", 0.05)
	else:
		tab_now = posmod(tab_now - 1, TABS.TAB_COUNT)
		header_anim.play("tab_left", 0.05)
	tabber.current_tab = tab_now
	header_center.set_text(tab_names[tab_now])
	header_left.set_text("㍛ " + tab_names[posmod(tab_now - 1, TABS.TAB_COUNT)])
	header_right.set_text("㍝ " + tab_names[(tab_now + 1) % TABS.TAB_COUNT])
	S.play_sfx("menu_move")


func _load_high_scores():
	for e in Loader.episodes.keys():
		var new_item = high_score_item.instance()
		new_item.set_fields(
			Loader.episodes[e],
			R.get_high_score(e)
		)
		high_score_grid.add_child(new_item)


func _load_achievements():
	pass


func _back():
	if tween.is_active():
		print("Tween is still active, can't go back")
		return
	S.play_sfx("menu_back")
	S.play_track(0, 0)
	tween.interpolate_property($ScreenStretch/r, "rect_scale", Vector2.ONE, Vector2.ONE * 1.2, 0.5)
	tween.interpolate_property(self, "modulate", Color.white, Color.black, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.start()
	S.unload_voice("confirm_delete_00")
	S.unload_voice("confirm_delete_01")
	yield(tween, "tween_all_completed")
	get_tree().change_scene("res://Title.tscn")


func _confirm_delete():
	S.play_voice("confirm_delete_00")
	S.play_track(0, 0)
	delete_modal.show()
	delete_title.text = "Are you sure?"
	delete_desc.text = "You are about to delete your save data and achievement history. This is irreversible! Are you sure you want to set yourself back to square one?"
	delete_yes.text = "Yes, I know what I’m doing."
	delete_yes.disabled = true
	delete_no.text = "Heck no! Take me back!"
	delete_no.grab_focus()
	delete_confirm_state = 1
	yield(get_tree().create_timer(3), "timeout")
	delete_yes.disabled = false


func _confirm_delete_again():
	S.stop_voice("confirm_delete_00")
	S.play_voice("confirm_delete_01")
	delete_title.text = "Are you DAMN sure?"
	delete_desc.text = "Nobody, not even I, can restore your save data once it’s been deleted. Are you really, really sure you want to yeet your progress out of existence?!"
	delete_yes.text = "Yep. To heck with my save file."
	delete_yes.disabled = true
	delete_no.text = "NOOOO! I DIDN’T MEAN TO!!"
	delete_no.grab_focus()
	delete_confirm_state = 2
	yield(get_tree().create_timer(3), "timeout")
	delete_yes.disabled = false


func _on_delete_cancel():
	if delete_confirm_state == 1:
		S.stop_voice("confirm_delete_00")
	else:
		S.stop_voice("confirm_delete_01")
	delete_modal.hide()
	delete_confirm_state = 0
	S.play_track(0, 0.5)


func _on_delete_confirm():
	if delete_confirm_state == 1:
		_confirm_delete_again()
	else:
		R.delete_save_data()
		_back()


func _on_Left_gui_input(event):
	if event is InputEventMouseButton and event.pressed and (event.button_index == 1):
		_tabulate(false)


func _on_Right_gui_input(event):
	if event is InputEventMouseButton and event.pressed and (event.button_index == 1):
		_tabulate(true)
