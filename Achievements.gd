extends Control

enum PLATFORM {
	CUSTOM, # no achievements system, show them as custom elements
	# add additional platforms here
}
var current_platform: int = PLATFORM.CUSTOM

var achievement_list: Dictionary
var achievement_progress: Dictionary = {}
var achievement_type_key: Dictionary = {}


onready var toasties = [
	$YSort/AchievementToastie1,
	$YSort/AchievementToastie2,
	$YSort/AchievementToastie3,
]
var toastie_positions = []

var toastie_queue = []

const TOASTIE_DISTANCE: float = 64.0
onready var toastie_tween: Tween = $Tween
var waiting_for_resize: bool = true

# Called when the node enters the scene tree for the first time.
func _ready():
	get_tree().connect("screen_resized", self, "_on_screen_resized")
	_initialize_achievements()
	for i in len(toasties):
		toasties[i].position.y = -TOASTIE_DISTANCE
		toasties[i].index = i
		toastie_positions.push_back(-1)
		toasties[i].connect("toastie_hidden", self, "_on_toastie_hidden")
	
	# TESTING
#	yield(get_tree(), "idle_frame")
#	_queue_toastie("episode_01")
#	_queue_toastie("episode_02")
#	_queue_toastie("episode_03")
#	_queue_toastie("special_guest")
#	_queue_toastie("cuss_1")


const COOLDOWN: float = 0.25
var cooldown: float = 0.0
func _process(delta):
	if toastie_queue.empty():
		cooldown = 0.0
		return
	cooldown -= delta
	if cooldown <= 0.0:
		_show_toastie(toastie_queue.pop_front())
		return
	if waiting_for_resize:
		_resize_element()
		waiting_for_resize = false


func _on_screen_resized():
	waiting_for_resize = true


func _resize_element():
	var resolution = get_viewport_rect().size
	rect_pivot_offset = Vector2(640, 360)
	rect_scale = Vector2.ONE * min(
		resolution.y / 720.0,
		resolution.x / 1080.0
	)


func _initialize_achievements():
	achievement_list = Loader.get_achievement_list()
	for k in achievement_list.keys():
		achievement_progress[k] = R.get_save_data_item("achievements", k, {progress = 0}).progress
		var ach_type = achievement_list[k].type
		if ach_type in achievement_type_key:
			achievement_type_key[ach_type].push_back(k)
		else:
			achievement_type_key[ach_type] = [k]
	# check what platform it is
	pass # Replace with function body.


## Sets the progress of the achievement with the given key. Does not update if the achievement is already progressed past it.
## Checks whether the achievement is gotten afterward.
func set_progress(type: String, to: int):
	if not (R.get_settings_value("cheat_codes_active").empty()):
		print("Cannot progress achievements while cheat codes are active."); return
	if !achievement_type_key.has(type):
		printerr("Achievement type ", type, " is not used in any achievement!"); return
	for ach in achievement_type_key[type]:
		# Incease progress only if we haven't progressed past it yet.
		if achievement_progress[ach] < to and achievement_progress[ach] < achievement_list[ach].steps:
			achievement_progress[ach] = to
			_check_progress(ach)


## Increments the progress of the achievement with the given key.
## Checks whether the achievement is gotten afterward.
func increment_progress(type: String, by: int):
	if not (R.get_settings_value("cheat_codes_active").empty()):
		print("Cannot progress achievements while cheat codes are active."); return
	if !achievement_type_key.has(type):
		printerr("Achievement type ", type, " is not used in any achievement!"); return
	for ach in achievement_type_key[type]:
		if achievement_progress[ach] < achievement_list[ach].steps:
			achievement_progress[ach] += by
			_check_progress(ach)


## Checks whether the achievement is gotten.
## If it is, sets the progress to the provided value and shows the toast.
## Either way, it also commits the change to the save data.
func _check_progress(key):
	if achievement_progress[key] >= achievement_list[key].steps:
		achievement_progress[key] = achievement_list[key].steps
		if current_platform == PLATFORM.CUSTOM:
			_show_toastie(key)
	R.set_save_data_item("achievements", key, {
		progress = achievement_progress[key],
		achieved = achievement_progress[key] == achievement_list[key].steps,
		date = OS.get_unix_time(),
	})
	R.save_save_data()


## Shows the toastie for the achievement. Called automatically after _check_progress(key).
func _show_toastie(key):
	var new_index: int = -1
	var shift_down: PoolByteArray = PoolByteArray()
	for i in len(toasties):
		if toastie_positions[i] == -1:
			if new_index == -1:
				new_index = i
				shift_down.push_back(i)
		else:
			shift_down.push_back(i)
	if new_index == -1:
		_queue_toastie(key)
		return
	cooldown = COOLDOWN
	for i in shift_down:
		_tween_downward(i)
		toastie_positions[i] += 1
	toastie_tween.start()
	var texture = load("res://achievements/%s.png" % key)
	toasties[new_index].show_toastie(achievement_list[key].title, texture)
	toastie_positions[new_index] = 0


func _queue_toastie(key):
	toastie_queue.push_back(key)


func _on_toastie_hidden(i: int):
	toastie_positions[i] = -1
	toasties[i].position.y = -TOASTIE_DISTANCE
	if toastie_queue.empty(): return
	_show_toastie(toastie_queue.pop_front())


func _tween_downward(i: int):
	toastie_tween.interpolate_property(
		toasties[i], "position:y",
		toasties[i].position.y,
		(toastie_positions[i] + 1) * TOASTIE_DISTANCE,
		0.3, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
