extends PanelContainer


func set_fields(
	image_path: String,
	achievement_name: String,
	description: String,
	progress: float,
	date: int
):
	$h/TextureRect.texture = load(image_path)
	$h/v/name.text = achievement_name
	$h/v/desc.text = description
	if date == -1:
		$h/v/h.value = progress
		$h/v/h/progress.text = "%.1f%%" % (progress * 100.0)
	else:
		$h/v/h.value = 1
		$h/v/h/prgoress.text = R.format_date(date)
