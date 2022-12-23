extends Control

enum PLATFORM {
	CUSTOM, # no achievements system, show them as custom elements
	# add additional platforms here
}
var current_platform: int = PLATFORM.CUSTOM

var achievement_list: Dictionary

var achievement_progress: Dictionary = {}

onready var toasties = [
	$YSort/AchievementToastie1,
	$YSort/AchievementToastie2,
	$YSort/AchievementToastie3,
]
var toastie_positions = []

var toastie_queue = []

const TOASTIE_DISTANCE: float = 64.0
onready var toastie_tween: Tween = $Tween

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
	yield(get_tree(), "idle_frame")
	_queue_toastie("episode_01")
	_queue_toastie("episode_02")
	_queue_toastie("episode_03")
	_queue_toastie("special_guest")
	_queue_toastie("cuss_1")


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

func _on_screen_resized():
	var resolution = get_viewport_rect().size
	rect_scale = Vector2.ONE * min(
		resolution.y / 720.0,
		resolution.x / 1080.0
	)


func _initialize_achievements():
	achievement_list = Loader.get_achievement_list()
	for k in achievement_list.keys():
		achievement_progress[k] = R.get_save_data_item("achievements", k, 0)
	# check what platform it is
	pass # Replace with function body.


## Sets the progress of the achievement with the given key. Does not update if the achievement is already progressed past it.
## Checks whether the achievement is gotten afterward.
func set_progress(key: String, to: int):
	# Do not increase progress if we are already progressed past it.
	if achievement_progress[key] < to:
		achievement_progress[key] = to
		_check_progress(key)


## Increments the progress of the achievement with the given key.
## Checks whether the achievement is gotten afterward.
func increment_progress(key: String, by: int):
	achievement_progress[key] += by
	_check_progress(key)


## Checks whether the achievement is gotten.
## If it is, sets the progress to the provided value and shows the toast.
## Either way, it also commits the change to the save data.
func _check_progress(key):
	if achievement_progress[key] >= achievement_list[key].steps:
		achievement_progress[key] = achievement_list[key].steps
		if current_platform == PLATFORM.CUSTOM:
			_show_toastie(key)


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
