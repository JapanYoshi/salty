extends ColorRect
var ready_to_play_intro: bool = false
var total_size: int = -1

# Called when the node enters the scene tree for the first time.
func _ready():
	if R.html:
		print("HTML build; check whether the asset pack is downloaded.")
		update_download_progress(-1)
		Loader.head_request_assets(self, "update_download_progress")
#	elif OS.has_feature("Android"):
#		_request_internet_permissions()
	else:
		print("Not an HTML build; all assets are already here. Load sounds.")
		_load_sounds()
		return

#func _request_internet_permissions():
#	var perms = OS.get_granted_permissions()
#	print(perms)
#	if "android.permission.INTERNET" in perms:
#		# Already granted
#		_load_sounds()
#		return
#	$ColorRect.show()
#	$ColorRect/Label.text = "In order to download question data from the Internet, the Android app needs your permission to access the Internet.\nPlease confirm that you want to grant this permission through the system dialog you are about to see."
#	$ColorRect/Button.show()
#	$ColorRect/Button.grab_focus()

func update_download_progress(result: int, param: int = -1):
	match result:
		-1: # Initialization
			$ColorRect.show()
			$ColorRect/Label.text = "Checking for updates; please wait..."
		8: # connection failed
			$ColorRect/Label.text = "Failed to connect to the server that has the asset files.\n" +\
			"Please make sure you’re on the latest version of the game, and the network isn’t blocking connections to " + Loader.asset_cache_url + "."
		9: # connection success, same file
			$ColorRect/Label.text = "No updates to asset files. Please wait while we extract and load the resources..."
			_load_assets()
		10: #connection success, but file not found
			$ColorRect/Label.text = "The asset file could not be found.\nMaybe this version of the game is outdated, and the server no longer has the correct version of the asset files.\n" +\
			"Please make sure you’re on the latest version of the game, and the network isn’t blocking connections to " + Loader.asset_cache_url + "."
			
		0: # connection success, different file
			# the number reported in the header was inaccurate in testing
			var filesize_estimate: String
			if param != 0:
				var total_float = param * (155229333.0 / 118225409.0)
				total_size = int(total_float)
				filesize_estimate = "estimated %.1f MiB" % (float(total_size) / 1048576)
			else:
				filesize_estimate = "file size unknown"
			$ColorRect/Label.text = "Before starting the game, it needs to download the asset files (" + filesize_estimate + ").\nPlease confirm that you want to start this download by pressing the button below."
			$ColorRect/Button.show()
			$ColorRect/Button.grab_focus()
		1: # loading
			if param == 0:
				$ColorRect/Label.text = "Waiting for download to start; please wait...\nestimated file size %.1f MiB" % [
					float(total_size) / 1048576
				]
			elif param < total_size:
				$ColorRect/Label.text = "Downloading asset files; please wait...\n%.1f MiB of estimated %.1f MiB (%.1f%%) downloaded" % [
					float(param) / 1048576, float(total_size) / 1048576, float(param * 100) / float(total_size)
				]
			else:
				$ColorRect/Label.text = "Hold on... (%.1f MiB downloaded)" % [
					float(param) / 1048576
				]
		2: # loaded
			$ColorRect/Label.text = "Downloaded the asset files. Please wait while we extract and load the assets..."
			_load_assets()


func _on_Button_pressed():
	$ColorRect/Button.hide() # also loses focus
	if R.html:
		Loader.download_assets_confirm(self, "update_download_progress")
#	else:
#		OS.request_permissions()
#		yield(get_tree(), "idle_frame")
#		_request_internet_permissions()


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
	var title_filename = "res://disclaimer/Disclaimers.tscn" if R.get_save_data_item("misc", "never_seen_disclaimer", true) else "res://logo/SplashScreen.tscn"
	get_tree().change_scene(title_filename)
