extends ColorRect
var ready_to_play_intro: bool = false
var total_size: int = -1

# Called when the node enters the scene tree for the first time.
func _ready():
	if !R.html:
		print("Not an HTML build; all assets are already here. Load sounds.")
		_load_sounds()
		return
	print("HTML build; check whether the asset pack is downloaded.")
	update_download_progress(-1)
	Loader.head_request_assets(self, "update_download_progress")


func update_download_progress(result: int, param: int = -1):
	match result:
		-1: # Initialization
			$ColorRect.show()
			$ColorRect/Label.text = "Checking for updates; please wait..."
		8: # connection failed
			$ColorRect/Label.text = "Failed to connect to the server that has the asset files."
		9: # connection success, same file
			$ColorRect/Label.text = "No updates to asset files. Please wait while we extract and load the resources..."
			_load_assets()
		0: # connection success, different file
			# the number reported in the header was inaccurate in testing
			var total_float = param * (155229333.0 / 118225409.0)
			total_size = int(total_float)
			$ColorRect/Label.text = "Before starting the game, it needs to download the asset files (estimated %.1f MB).\nPlease confirm that you want to start this download by pressing the button below." % (float(total_size) / 1048576)
			$ColorRect/Button.show()
			$ColorRect/Button.grab_focus()
		1: # loading
			if param < total_size:
				$ColorRect/Label.text = "Downloading asset files; please wait...\n%.1f MB of estimated %.1f MB (%.1f%%) downloaded" % [
					float(param) / 1048576, float(total_size) / 1048576, float(param * 100) / float(total_size)
				]
			else:
				$ColorRect/Label.text = "Finishing downloading the asset files..."
		2: # loaded
			$ColorRect/Label.text = "Downloaded the asset files. Please wait while we extract and load the assets..."
			_load_assets()


func _on_Button_pressed():
	$ColorRect/Button.hide() # also loses focus
	Loader.download_assets_confirm(self, "update_download_progress")


func _load_assets():
	print("Init._load_assets()")
	Loader.connect("loaded", self, "_load_sounds", [], CONNECT_ONESHOT)
	Loader.load_assets()
	return


## Also loads other stuff
func _load_sounds():
	Loader.load_random_voice_lines()
	Loader.load_random_questions()
	Loader.load_episodes_list()
	print("Init._load_sounds()")
	S.preload_sounds()
	_assets_loaded()
	return


func _assets_loaded():
	get_tree().change_scene("res://logo/SplashScreen.tscn")
