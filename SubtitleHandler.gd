extends Container

onready var timer = $Timer
onready var tbox = $SubText
var queue = []

func _ready():
	clear_contents()
	S.sub_node = self
	### Testing
	#queue_subtitles("Welcome to Salty Trivia with Candy Barre,[#3000#]and I woke up like this.[#5500#]Disheveled.")
	### End testing

func clear():
	queue = []
	clear_contents()

func clear_contents():
	timer.stop()
	tbox.text = ""

# Queues timed subtitles.
func queue_subtitles(contents = ""):
	if !R.cfg.subtitles: return
	queue = Loader.parse_time_markers(contents)
	show_queued()

# Shows subtitles from the queue. Clears the subtitle if the queue is empty.
func show_queued():
	if len(queue) == 0:
		clear_contents()
		return
	var next = queue.pop_front()
	show_subtitle(next.text, next.duration / 1000.0)

# Duration of 0 clears the contents.
# Negative duration disables the timer,
# displaying the subtitle until interrupted by a different subtitle.
func show_subtitle(contents = "", duration = 0.0):
	if !R.cfg.subtitles: return
	if duration == 0.0:
		clear_contents()
	else:
		tbox.clear()
		tbox.append_bbcode("[center]" + contents.strip_edges() + "[/center]")
		if duration > 0.0:
			timer.start(duration)

func _on_Timer_timeout():
	show_queued()
