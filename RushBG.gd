extends Control
var abort = false
export var ring_speed = 1.0
var ready_to_start = false

func _ready():
	$Rings.show()
	$Cover.hide()
	$Options.show()
	show_topic(false)
	$Panel2.modulate = Color.transparent
	$Panel3.modulate = Color.transparent
	$Panel4.modulate = Color.transparent
	$Label.modulate = Color.transparent
	$Label2.modulate = Color.transparent
	$Label3.modulate = Color.transparent

func set_topic(bbcode):
	$Topic.clear()
	$Topic.append_bbcode("[center]%s[/center]" % bbcode)

func show_topic(truthy):
	$Topic.visible = truthy
	if truthy:
		$AnimationPlayer.play("show_topic")

func set_options(options):
	for i in range(6):
		$Options.get_child(i).set_option(options[i])

func show_option(index):
	$Options.get_child(index).enter()

func show_option_delayed(index, time_sec):
	$Options.get_child(index).enter_delayed(time_sec)

func time_up(truthy):
	$Tween.remove_all()
	if truthy:
		$Cover.color = Color.white
		$Cover.show()
		for i in range(6):
			$Options.get_child(i).time_up()
	else:
		$AnimationPlayer.play_backwards("show_topic")
		for i in range(6):
			$Options.get_child(i).exit()

func reveal_option(index, truthy):
	$Options.get_child(index).reveal_option(truthy)

func tute(stage):
	var answers = [true, false, true, true, false, true]
	match stage:
		0:
			set_topic("smartphones")
			$AnimationPlayer.play("show_topic")
			set_options(["iPhone", "iPad", "Google Pixel", "Windows Phone", "Commodore 64", "Samsung Galaxy"])
			show_topic(true)
			for i in range(6):
				yield(get_tree().create_timer(0.125), "timeout")
				if abort: return;
				show_option(i)
			$AnimationPlayer.play("selection_example")
		1:
			for i in range(3):
				yield(get_tree().create_timer(0.125), "timeout")
				if abort: return;
				reveal_option(i, answers[i])
				$Label. set_text("+1 POINT")
				$Label2.set_text("+1 POINT")
				$Label3.set_text("+1 POINT")
			$AnimationPlayer.play("correct_example")
		2:
			for i in range(3):
				yield(get_tree().create_timer(0.125), "timeout")
				if abort: return;
				reveal_option(i+3, answers[i+3])
				$Label. set_text("−1 POINT")
				$Label2.set_text("−1 POINT")
				$Label3.set_text("−1 POINT")
			$AnimationPlayer.play("incorrect_example")
		3:
			$AnimationPlayer.stop(false)
			time_up(false)
			show_topic(false)
			if abort: return;
			$Panel2.modulate = Color.transparent
			$Panel3.modulate = Color.transparent
			$Panel4.modulate = Color.transparent
			$Label.modulate = Color.transparent
			$Label2.modulate = Color.transparent
			$Label3.modulate = Color.transparent
			$AnimationPlayer.play("tutorial_over")

func show_title(bbcode):
	$CenterContainer/RichTextLabel.clear()
	$CenterContainer/RichTextLabel.append_bbcode(
		"[center]%s[/center]" % bbcode
	)
	$AnimationPlayer.play("show_title")

func tween_background_intensity(duration: float, backwards: bool, delay: float = 0.0):
	var ring_speed_min = 1.0
	var ring_speed_max = 16.0
	var color_min = Color.transparent
	var color_max = Color(1, 1, 1, 0.5)
	var scale_min = 1.0
	var scale_max = 1.25
	var ring_speed_from; var ring_speed_to
	var color_from; var color_to
	var scale_from; var scale_to
	var easing
	if backwards:
		ring_speed_from = ring_speed_max
		ring_speed_to   = ring_speed_min
		color_from = color_max
		color_to   = color_min
		scale_from = scale_max
		scale_to   = scale_min
		easing = Tween.EASE_OUT
	else:
		ring_speed_from = ring_speed_min
		ring_speed_to   = ring_speed_max
		color_from = color_min
		color_to   = color_max
		scale_from = scale_min
		scale_to   = scale_max
		easing = Tween.EASE_IN
	$Tween.remove_all()
	$Tween.interpolate_property(
		self, "ring_speed",
		ring_speed_from, ring_speed_to,
		duration, Tween.TRANS_QUAD, easing, delay
	)
	$Tween.interpolate_property(
		$Cover, "color",
		color_from, color_to,
		duration, Tween.TRANS_QUAD, easing, delay
	)
	$Tween.interpolate_method(
		self, "_set_ring_scale",
		scale_from, scale_to,
		duration, Tween.TRANS_QUAD, easing, delay
	)
	$Tween.start()

func start_question():
	$Cover.color = Color.transparent
	tween_background_intensity(5.00, false)
	$Cover.show()

func start_round(topic, options):
	set_topic(topic)
	show_topic(true)
	set_options(options)
	tween_background_intensity(1.5, true)
	show_option(0)
	show_option_delayed(1, 0.9375)
	show_option_delayed(2, 3.75)
	show_option_delayed(3, 4.6875)
	show_option_delayed(4, 7.5)
	show_option_delayed(5, 8.4375)
	tween_background_intensity(3.75, 11.25)

func _set_ring_scale(scale):
	if R.get_settings_value("graphics_quality") >= 1:
		$Rings.material.set_shader_param(
			"scale", scale
		)
