extends PanelContainer


func set_fields(
	image_path: String,
	achievement_name: String,
	description: String,
	progress: float,
	date: int
):
	if progress < 1.0:
		$h/TextureRect.texture = load("res://achievements/locked.png")
		$h/v/h.value = progress
		$h/v/h/progress.text = "%.1f%%" % (progress * 100.0)
	else:
		$h/TextureRect.texture = load(image_path)
		$h/v/h.value = 1
		$h/v/h/progress.text = "Unlocked via cheat code" if date == 0 else R.format_date(date)
	$h/v/name.text = achievement_name
	$h/v/desc.text = description
