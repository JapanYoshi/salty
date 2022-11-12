extends Control

onready var anim = $AnimationPlayer
onready var logo = $Logo
onready var tween = $Tween
onready var backdrop = $Circle
var ranking

signal animation_finished(name)

func _ready():
	set_radius(0)
	var pb = $Leaderboard/PC
	for i in range(1, 8):
		$Leaderboard.add_child(pb.duplicate())
	$CreditBox/CreditScroller.hide()

const credits_speed = 48
var credits_scroll = 0.0

func _process(delta):
	if $CreditBox/CreditScroller.visible:
		credits_scroll += delta * credits_speed
		if credits_scroll > $CreditBox/CreditScroller/V.rect_size.y - $CreditBox/CreditScroller.rect_size.y:
			credits_scroll = 0
		$CreditBox/CreditScroller.scroll_vertical = credits_scroll

func play_intro():
	backdrop.color = Color("#365c45");
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
	tween.interpolate_method(
		self, "set_radius", 0.0, 0.75, 0.25, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.start()

func close_bg():
	tween.interpolate_method(
		self, "set_radius", 0.75, 0.0, 0.25, Tween.TRANS_CUBIC, Tween.EASE_OUT
	)
	tween.start()

func show_lifesaver_logo():
	$Lifesavers.show()
	anim.play("lifesavers_logo")

# 0, 1, 2: first round
# 3, 4, 5: second round
func lifesaver_tutorial(stage: int):
	var lbl: RichTextLabel = get_node("Label%d" % (stage % 3))
	var text = [
		# round 1
		"Press ㍘ or ㍚ to activate",
		"From 4 options to 2 options",
		"12 questions, 1 Lifesaver",
		# round 2
		"From 4 options to 2 options",
		"6 more questions!",
		"Press ㍘ or ㍚ to activate",
	][stage]
	lbl.bbcode_text = text
	anim.play("lifesavers_tute%d" % (stage % 3))

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
	backdrop.color = Color("#0b3601")
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

# depending on the number of players, the "indices" of the leaderboard boxes will be:
const leaderboard_positions = [
	[], [1], [3, 4], [0, 1, 2], [3, 2, 0, 4], [4, 0, 1, 2, 3], [1, 2, 3, 4, 0, 1], [3, 4, 0, 1, 2, 3, 4], [0, 1, 2, 3, 4, 0, 1, 2]
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
#		Ws.send('message', {
#			'action': 'changeScene',
#			'sceneName': 'finalResult',
#			'result': a.score,
#			'resultAsText': R.format_currency(a.score),
#			'comment': comment
#		}, a.device_name);
	# actually, load the credits too while we're at it.
	var credits = ConfigFile.new()
	var err = credits.load("res://credits.gdcfg")
	if err != OK:
		printerr("Could not load credits.")
	else:
		$CreditBox/CreditScroller/V/Spacer.rect_min_size.y = $CreditBox/CreditScroller.rect_size.y
		var rtl = $CreditBox/CreditScroller/V/RichTextLabel
		for sect in credits.get_sections():
			var new_rtl = rtl.duplicate(7) # don't use instancing so we can edit the text
			new_rtl.set_bbcode(
				"[b]" +
				credits.get_value(sect, "h") +
				"[/b]"
			)
			new_rtl.name = sect
			$CreditBox/CreditScroller/V.add_child(new_rtl)
			var items = credits.get_value(sect, "b")
			for i in len(items):
				new_rtl = rtl.duplicate(7)
				new_rtl.set_bbcode(items[i])
				new_rtl.name = sect + "_%02d" % i
				$CreditBox/CreditScroller/V.add_child(new_rtl)
		$CreditBox/CreditScroller/V.add_child($CreditBox/CreditScroller/V/Spacer.duplicate())
		rtl.free()
	anim.play("final_standings")
	logo.show_logo()

func hide_final_leaderboard():
	set_radius(1.5)
	$Final.hide()

func roll_credits():
	anim.play("credits_roll")
	S.play_music("organ", 1.0)

func set_radius(value):
	backdrop.set_param("radius", value)

func _on_AnimationPlayer_animation_finished(anim_name):
	emit_signal("animation_finished")

func show_techdiff():
	$TechDiff.show()
	$TechDiff.set_process(true)
	logo.hide_logo()
	set_radius(0.0)
	anim.play("intro", 0.0, 0.01, false)
	anim.stop() # resets playback position to 0

func hide_techdiff():
	$TechDiff.hide()
