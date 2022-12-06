extends Control

const joinat_template = "[right]join via [b]haitouch.ga/te#[/b][code]%s[/code][/right]"
const count_template = "[right][b]%d[/b] in audience[/right]"
const acc_template = "[right]Audience score: [b]%s[/b][/right]"

var current_count: int = 0
var showing_accuracy: bool = false

onready var n_joinat = $Upper
onready var n_count = $Count
onready var n_accuracy = $Accuracy
onready var anim = $AnimationPlayer

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func show_room_code(room_code: String):
	if room_code != "" and !R.get_settings_value("hide_room_code_ingame"):
		n_joinat.bbcode_text = joinat_template % room_code
	else:
		n_joinat.bbcode_text = ""

func show_count(count: int):
	n_count.bbcode_text = count_template % count
	if count > 0 and current_count == 0:
		anim.play("AudienceShow")
	current_count = count

func show_accuracy(acc: float):
	if current_count == 0: return
	if acc >= 0.0:
		n_accuracy.bbcode_text = (
			acc_template % (
				"100%" if acc == 100 else (
					"%4.1f%%" % acc
				)
			)
		)
	else:
		n_accuracy.bbcode_text = "[right]no audience answers[/right]"
	if !showing_accuracy:
		anim.play("AccuracyOn")
		showing_accuracy = true

func hide_accuracy():
	if current_count == 0: return
	if showing_accuracy:
		anim.play("AccuracyOff")
		showing_accuracy = false
