extends ColorRect

onready var tween = $Tween
const MONTH_NAMES: PoolStringArray = PoolStringArray(["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"])
# actual timeout lengths are in Standard.gd -> answer_submitted()
const TIMEOUT_LENGTHS: PoolStringArray = PoolStringArray(["five-minute", "ten-minute", "quarter-hour", "twenty-minute", "half-hour", "hour-long", "two-hour", "three-hour", "six-hour", "one-day", "two-day", "week-long"])

func _ready():
	# length of timeout
	var cuss_counter = R.get_save_data_item("misc", "cuss_counter", 1) - 1
	var timeout_length = TIMEOUT_LENGTHS[cuss_counter] if cuss_counter < len(TIMEOUT_LENGTHS) else TIMEOUT_LENGTHS[-1]
	$ScreenStretch/ColorRect/Label4.set_text($ScreenStretch/ColorRect/Label4.text.replace("{}", timeout_length))
	# timestamp
	var timestamp = R.get_save_data_item("misc", "cuss_timestamp", int(Time.get_unix_time_from_system()))
	var timezone = Time.get_time_zone_from_system()
	timestamp += timezone.bias * 60
	var date_dict = Time.get_datetime_dict_from_unix_time(timestamp)
	print(timestamp, timezone, date_dict)
	date_dict.month_name = MONTH_NAMES[date_dict.month - 1]
	date_dict.hour_str = "%02d" % (posmod(date_dict.hour - 1, 12) + 1)
	date_dict.minute_str = "%02d" % date_dict.minute
	date_dict.second_str = "%02d" % date_dict.second
	date_dict.ampm = "PM" if date_dict.hour >= 12 else "AM"
	var time = "{year} {month_name} {day} {hour_str}:{minute_str}:{second_str} {ampm}".format(date_dict)
	$ScreenStretch/ColorRect/Label5.set_text(time)
	S.play_music("trolled", 0.8)


func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		_on_back_pressed()

func _on_back_pressed():
	if tween.is_active():
		print("Tween is still active, can't go back")
		return
	S.play_sfx("menu_back")
	S.play_track(0, 0)
	tween.interpolate_property($ScreenStretch/ColorRect, "rect_scale", Vector2.ONE, Vector2.ONE * 1.2, 0.5)
	tween.interpolate_property(self, "modulate", Color.white, Color.black, 0.5, Tween.TRANS_CUBIC, Tween.EASE_OUT)
	tween.start()
	yield(tween, "tween_all_completed")
	S.unload_music("trolled")
	get_tree().change_scene("res://Title.tscn")
