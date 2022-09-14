extends Container

onready var timer = $Timer
onready var tbox = $SubText
var queue = []
var last_duration: int = 0

func _ready():
	clear_contents()
	S.sub_node = self
	### Testing
	#queue_subtitles("Welcome to Salty Trivia with Candy Barre,[#3000#]and I woke up like this.[#5500#]Disheveled.")
	### End testing

func clear_contents():
	print("SUB CLEAR_CONTENTS")
	timer.stop()
	queue.clear()
	tbox.bbcode_text = ""

# Queues timed subtitles.
func queue_subtitles(contents = ""):
	print("SUB QUEUE_SUBTITLES ", contents)
	if !R.cfg.subtitles: return
	queue = Loader.parse_time_markers(contents)
	show_queued()

# Shows subtitles from the queue. Clears the subtitle if the queue is empty.
func show_queued():
	print("SUB SHOW_QUEUED ", queue)
	if len(queue) == 0:
		clear_contents()
		return
	var next = queue.pop_front()
	show_subtitle(next.text, next.time)

# Time of 0 clears the contents.
# Negative time disables the timer,
# displaying the subtitle until interrupted by a different subtitle.
func show_subtitle(contents = "", time = 0):
	print("SUB SHOW_SUBTITLE ", contents, " ", time)
	if !R.cfg.subtitles: return
	if time == 0:
		clear_contents()
	else:
		last_duration = time
		tbox.clear()
		tbox.append_bbcode("[center]" + contents.strip_edges() + "[/center]")
		if time >= 0:
			var duration: float = (time / 1000.0) - S.get_voice_time()
#			print("SUBTITLE Duration:", duration)
			if duration > 0.0:
				timer.start(duration)

# Only clear the subtitles if current length is -1
func signal_end_subtitle():
	if last_duration == -1:
		tbox.clear()
		last_duration = 0

func _on_Timer_timeout():
	print("SUB TIMER_TIMEOUT")
	show_queued()
