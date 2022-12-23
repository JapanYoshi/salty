extends PanelContainer


func set_fields(ep_data, hs):
	$v/Split/Num/Text.text = ep_data.episode_id
	if hs.locked:
		$v/Split/name.text = "Locked episode"
	else:
		$v/Split/name.text = ep_data.episode_name
	if hs.high_score_time == 0:
		$v/h/value/hs.text = "---"
		$v/h/date/hs.text = "Never played"
	else:
		$v/h/value/hs.text = R.format_currency(hs.high_score)
		$v/h/date/hs.text = R.format_date(hs.high_score_time)
	if hs.best_accuracy_time == 0:
		$v/h/value/acc.text = "---%"
		$v/h/date/acc.text = "Never played"
	else:
		$v/h/value/acc.text = "%.1f%%" % (hs.best_accuracy * 100.0)
		$v/h/date/acc.text = R.format_date(hs.best_accuracy_time)
