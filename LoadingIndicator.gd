extends Control

func update_loading_progress(partial: int, total: int, eta: int):
	var time_text = "Time estimate unknown..."
	if eta >= 60*1000:
# warning-ignore:integer_division
		time_text = "Please wait ≈%dʹ' %0.1f\"..." % [eta / (60*1000), (eta % (60*1000)) / 1000.0]
	elif eta >= 1000:
		time_text = "Please wait ≈%0.1f\"..." % (eta / 1000.0)
	elif eta > 0:
		time_text = "Almost there..."
	elif eta == 0:
		time_text = "Finished!"
	# if the ETA is null or undefined, time_text stays as default
	$LoadingPanel/Label.set_text(
		"Downloading question pack. %s" % time_text
	)
	$LoadingPanel/ProgressBar.max_value = total
	$LoadingPanel/ProgressBar.value = partial
	$LoadingPanel/Progress.set_text(
		"%d of %d questions (%05.1f%%)" % [partial, total, 100.0 * partial / total]
	)
	$LoadingProgress.set_text(
		"Downloaded %d of %d questions" % [partial, total]
	)
