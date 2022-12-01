extends Control

onready var anim = $AnimationPlayer
onready var logo = $Logo
onready var tween = $Tween
onready var backdrop = $Color
onready var vignette = $Circle
onready var scroller = $CreditBox/CreditScroller
onready var scrollerV = scroller.get_child(0)

var ranking

signal animation_finished(name)

func _ready():
	set_radius(0)
	var pb = $Leaderboard/PC
	for i in range(1, 8):
		$Leaderboard.add_child(pb.duplicate())
	scroller.hide()

const credits_speed = 48
var credits_scroll = 0.0

func _process(delta):
	if scroller.visible:
		credits_scroll += delta * credits_speed
		if credits_scroll > scrollerV.rect_size.y - scroller.rect_size.y:
			credits_scroll = 0
		scroller.scroll_vertical = credits_scroll

func play_intro():
	anim.play("intro")
	logo.play_intro()

func lose_logo():
	S.play_sfx("logo_leave")
	anim.play("logo_leave")

func round2_logo(backwards):
	if backwards:
		anim.play("round2_reverse")
	else:
		S.play_sfx("logo_flip")
		anim.play("round2")

func open_bg():
	vignette.open()

func close_bg():
	vignette.close()

func show_lifesaver_logo():
	$Lifesavers.show()
	anim.play("lifesavers_logo")

func lifesaver_tutorial(stage: int):
	var real_stage = stage % 3
	get_node("Label%d" % real_stage).bbcode_text = (
		[
			"Press ㍘ or ㍚ to activate",
			"From 4 options to 2 options",
			"12 questions, 1 Lifesaver",
			"From 4 options to 2 options",
			"6 questions left to use!",
			"Press ㍘ or ㍚ to activate",
		][stage]
	)
	anim.play("lifesavers_tute%d" % real_stage)

# A class just to pass a function to ranking.sort_custom(..) below
class LBSorter:
	static func _sort_players(a, b):
		if a.score == b.score:
			return (a.player_number < b.player_number)
		return (a.score > b.score)

func rank_players():
	ranking = R.players.duplicate()
	ranking.sort_custom(LBSorter, "_sort_players")
	for p in ranking:
		p.tied = false
	for i in range(len(ranking)):
		if 0 < i and ranking[i-1].score == ranking[i].score:
			ranking[i-1].tied = true
			ranking[i].tied = true

func show_leaderboard(hidden: bool = false):
	rank_players()
	backdrop.modulate = Color("#0b3601")
	var lb = $Leaderboard
	for i in range(8):
		var box = lb.get_child(i + 1);
		if i >= len(ranking):
			box.hide()
		else:
			box.get_node("Number").set_text("%d" % (ranking[i].player_number + 1))
			box.get_node("HBox/Name").set_text(ranking[i].name)
			box.get_node("HBox/Score").set_text(R.format_currency(ranking[i].score))
			box.show()
	if !hidden:
		anim.play("leaderboard")
		set_radius(1.5)
		$Logo.show_logo()

func hide_leaderboard():
	anim.play("leaderboard_end")
	close_bg()

# 0, 1, 2: 3 items in a row
# 3, 4: 2 items in a row
# depending on the number of players, the "indices" of the leaderboard boxes will be:
const leaderboard_positions = [
	[], [1], [3, 4], [0, 1, 2], [3, 2, 0, 4], [4, 0, 1, 2, 3],
	[1, 2, 3, 4, 0, 1], [3, 4, 0, 1, 2, 3, 4], [0, 1, 2, 3, 4, 0, 1, 2]
]
func show_final_leaderboard():
	var flb = $Final/FinalLeaderboard
	var pb = $Final/FinalLeaderboard/FinalPBox
	show_leaderboard(true)
	var lb_pos = leaderboard_positions[len(ranking)]
	for i in range(len(ranking)):
		if i != 0:
			flb.add_child(pb.duplicate())
		flb.get_child(i).set_index(lb_pos[i])
		flb.get_child(i).init_values(ranking[i])
	$Final.show()
	$Leaderboard/Panel/Label.set_text("Final standings")
	backdrop.modulate = Color("#365c45")
	vignette.modulate = Color.black
	# calculate the placement of each player, taking ties into account.
	for i in range(len(ranking)):
		var placement = i
		while placement > 0 and ranking[placement - 1].score == ranking[i].score:
			ranking[i].tied = true
			ranking[placement - 1].tied = true
			placement -= 1
		ranking[i].placement = placement
	# send remote controllers their results
	for p in ranking:
		if p.device == C.DEVICES.REMOTE:
			var comment = ""
			if len(R.players) == 1: # Singleplayer comments.
				if   p.score >= 50000:   # $50000 ~
					comment = "Well, that’s respectable."
				elif p.score >= 20000: # $20000 ~ $50000
					comment = "That’s a lotta cash!";
				elif p.score >= 10000: # $10000 ~ $19999
					comment = "That’s nothing to sneeze at!";
				elif p.score >=  5000: #  $5000 -  $9999
					comment = "Not bad, but not great either.";
				elif p.score >      0: #     $1 -  $4999
					comment = "Well, better than losing money.";
				elif p.score ==     0: # $0
					comment = "Bruh.";
				elif p.score >  -5000: # -$4999 -     -$1
					comment = "So close to breaking even.";
				elif p.score > -10000: # -$9999 -  -$5000
					comment = "That was pretty pathetic.";
				elif p.score > -20000: #-$19999 - -$10000
					comment = "Tough break.";
				elif p.score > -50000: #-$49999 - -$20000
					comment = "You’re definitely doing that on purpose.";
				else: # ~ -$20000
					comment = "Let me guess, you swore at Candy?"
			else:
				var _ord = (
					"1st" if p.placement == 0 else
					"2nd" if p.placement == 1 else
					"3rd" if p.placement == 2 else
					"%dth" % (p.placement + 1)
				)
				comment = ("You tied for %s!" if p.tied else "You placed %s!") % _ord
			Fb.send_to_player(
				p.device_name, {
					action = "finalResult",
					result = p.score,
					resultAsText = R.format_currency(p.score),
					comment = comment,
				}
			)
#			Ws.send('message', {
#				'action': 'changeScene',
#				'sceneName': 'finalResult',
#				'result': p.score,
#				'resultAsText': R.format_currency(p.score),
#				'comment': comment
#			}, p.device_name);
	for a in R.audience:
		# Calculate how many players you beat.
#		ranking[i].score
#				  .placement
#				  .tied
		var comment: String
		if len(ranking) > 1:
			var players_beaten: int = 0
			var tied: bool = false
			for j in range(len(ranking)):
				match sign(a.score - ranking[len(ranking) - j - 1]):
					1.0:
						players_beaten += 1
					0.0:
						tied = true
						break
					-1.0:
						break
			if players_beaten == 1:
				comment = "You beat one single player... Better than losing to everyone."
			elif players_beaten > 1:
				if players_beaten == len(ranking):
					comment = "You beat all %d players! Great work, Galaxy Brain!" % players_beaten
				else:
					comment = "You beat %d players! Maybe next time you can beat all of them." % players_beaten
			else:
				comment = "You didn’t beat any players. See, this is why you can’t play."
		else:
			if a.score > ranking[0].score:
				comment = "You beat the Player! Go boast about it."
			elif a.score == ranking[0].score:
				comment = "Oh, come on! You tied with the Player?!"
			else:
				comment = "See, this is why you can’t play with the Player."
		Fb.send_to_player(
			a.device_name, {
				action = "finalResult",
				result = a.score,
				resultAsText = R.format_currency(a.score),
				comment = comment,
			}
		)
#		Ws.send('message', {
#			'action': 'changeScene',
#			'sceneName': 'finalResult',
#			'result': a.score,
#			'resultAsText': R.format_currency(a.score),
#			'comment': comment
#		}, a.device_name);
	# High score submission/checking
	# Find the best accuracy.
	var best_accuracy: float = NAN
	for i in range(len(R.players)):
		if R.players[i].accuracy[1] == 0: continue; # prevent division by zero
		var acc = float(R.players[i].accuracy[0]) / float(R.players[i].accuracy[1])
		if is_nan(best_accuracy) or acc > best_accuracy:
			best_accuracy = acc
	R.submit_high_score(ranking[0].score, best_accuracy)
	# actually, load the credits too while we're at it.
	var credits = ConfigFile.new()
	var err = credits.load("res://credits.gdcfg")
	if err != OK:
		printerr("Could not load credits.")
	else:
		var spacer = scrollerV.get_child(0)
		spacer.get_custom_minimum_size().y = scroller.rect_size.y
		var rtl_title: RichTextLabel = scrollerV.get_child(1)
		var rtl_body: RichTextLabel = scrollerV.get_child(2)
		for sect in credits.get_sections():
			var new_rtl = rtl_title.duplicate(7) # don't use instancing so we can edit the text
			new_rtl.set_bbcode(
				credits.get_value(sect, "h")
			)
			new_rtl.name = sect
			scrollerV.add_child(new_rtl)
			var items = credits.get_value(sect, "b")
			for i in len(items):
				new_rtl = rtl_body.duplicate(7)
				new_rtl.set_bbcode(items[i])
				new_rtl.name = sect + "_%02d" % i
				scrollerV.add_child(new_rtl)
		scrollerV.add_child(spacer.duplicate())
#		rtl_title.free(); rtl_body.free()
	anim.play("final_standings")
	set_radius(1.5)
	logo.show_logo()

func hide_final_leaderboard():
	backdrop.modulate = Color.black
	$Final.hide()
	$Leaderboard.show()
	logo.show_logo()

func roll_credits():
	anim.play("credits_roll")
	S.play_music("organ", 1.0)

func set_radius(value):
	vignette.set_radius(value)

func _on_AnimationPlayer_animation_finished(anim_name):
	emit_signal("animation_finished")

func show_techdiff():
	$TechDiff.set_process(true)
	$TechDiff.show()
	logo.hide_logo()
	anim.play("intro", 0.0, 0.01, false)
	anim.stop() # resets playback position to 0
	set_radius(0.0)

func hide_techdiff():
	$TechDiff.hide()
