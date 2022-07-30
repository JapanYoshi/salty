extends Node
### "Root", for data that every page should have.

# Declare member variables here. Examples:
# var a = 2
# var b = "text"
onready var rng = RandomNumberGenerator.new()
var pass_between = {}
var players = []
var cuss_regex = RegEx.new()
# 0: Render at 1280x720. Disable most shader animations.
# 1: Stretch to window size. Disable most shader animations.
# 2: Stretch to window size. Enable all shader animations.
var cfg = {
	graphics_quality = 2,
	room_openness = 2,
	subtitles = true,
	music = true,
	cutscenes = true,
	awesomeness = true
}

# Called when the node enters the scene tree for the first time.
func _ready():
	rng.randomize()
	set_currency("fmt_dollars")
	var result = cuss_regex.compile("F+U+C+K+[^A-Z]*(Y+O+U|O+F)")
	if result != OK:
		print("Could not compile cuss RegEx: error code %d" % result)
	load_settings()
	_set_visual_quality(cfg.graphics_quality)

### Configuration

func save_settings():
	# Create new ConfigFile object.
	var config = ConfigFile.new()
	# Store some values.
	for k in cfg.keys():
		config.set_value("config", k, cfg[k])
	# Save it to a file (overwrite if already exists).
	config.save("user://config.cfg")

func load_settings():
	var config = ConfigFile.new()
	# Load data from a file.
	var err = config.load("user://config.cfg")
	# If the file didn't load, ignore it.
	if err != OK:
		return
	cfg = {}
	# Iterate over all sections.
	for k in config.get_section_keys("config"):
		# Fetch the data for each section.
		cfg[k] = config.get_value("config", k)

### currency formatting
var currency_data = {
  "name": "dollars"
, "multiplier": 100
, "decimalDigits": 0
, "decimalSymbol": "."
, "separatorDigits": [3]
, "separatorSymbol": ","
, "nega":   ["-$", ""]
, "zero":   ["±$", ""]
, "posi":   ["+$", ""]
, "noSign": [ "$", ""]
}

func set_currency(curr_name="fmt_dollars"):
	var fmt_file = File.new()
	var result = fmt_file.open("res://strings/%s.json" % curr_name, File.READ)
	if result == OK:
		result = JSON.parse(fmt_file.get_as_text())
		if result.error == OK:
			currency_data = result.result
		else:
			breakpoint
	fmt_file.close()

func format_currency(score = 0.0, no_sign = false, min_digits = 0):
	score *= currency_data.multiplier
	var numText = str(int(floor(abs(score))))
	var digits = len(numText)
	var numText_ = ""
	var i = 0
	while true:
		if currency_data.separatorDigits[i] < len(numText):
			numText_ = currency_data.separatorSymbol + numText.right(
				len(numText) - currency_data.separatorDigits[i]
			) + numText_
			numText = numText.left(len(numText) - currency_data.separatorDigits[i])
			i = (i + 1) % len(currency_data.separatorDigits)
		else:
			break
	numText = numText + numText_
	var decimal_digits = max(currency_data.decimalDigits, min_digits - digits)
	if decimal_digits > 0:
		numText += currency_data.decimalSymbol + ("%*.*f" % [
			decimal_digits,
			decimal_digits,
			abs(score) - floor(abs(score))
		]).right(2)
	var sign_arr = currency_data.nega
	if score >= 0.0:
		if no_sign:
			sign_arr = currency_data.noSign
		elif score > 0.0:
			sign_arr = currency_data.posi
		else:
			sign_arr = currency_data.zero
	return sign_arr[0] + numText + sign_arr[1]

func _set_visual_quality(quality):
	cfg.graphics_quality = quality
	if cfg.graphics_quality == 0:
		get_tree().set_screen_stretch(
			SceneTree.STRETCH_MODE_VIEWPORT,
			SceneTree.STRETCH_ASPECT_KEEP,
			Vector2(1280, 720),
			1
		)
		get_tree().use_font_oversampling = false
	elif cfg.graphics_quality == 1:
		get_tree().set_screen_stretch(
			SceneTree.STRETCH_MODE_2D,
			SceneTree.STRETCH_ASPECT_KEEP,
			Vector2(1280, 720),
			1
		)
		get_tree().use_font_oversampling = false
	else:
		get_tree().set_screen_stretch(
			SceneTree.STRETCH_MODE_2D,
			SceneTree.STRETCH_ASPECT_KEEP,
			Vector2(1280, 720),
			1
		)
		get_tree().use_font_oversampling = true

### Crash handling

func crash(reason):
	Ws.close_room()
	S.stop_voice()
	S.play_music("", 0)
	get_tree().change_scene('res://Error.tscn')
	call_deferred(
		"_deferred_crash", reason
	)

func _deferred_crash(reason):
	get_tree().get_root().get_node('Error').set_reason(reason)
	S.play_sfx("naughty")

### Player stats

func get_lifesaver_count() -> int:
	var ans: int = 0
	for p in players:
		if p.has_lifesaver:
			ans += 1
	return ans
