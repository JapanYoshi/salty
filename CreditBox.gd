extends Panel

onready var scroller = $CreditScroller
onready var scrollerV = scroller.get_child(0)

func _ready():
	scroller.hide()

const credits_speed = 48
var credits_scroll = 0.0

func _process(delta):
	if scroller.visible:
		credits_scroll += delta * credits_speed
		if credits_scroll > scrollerV.rect_size.y - scroller.rect_size.y:
			credits_scroll = 0
		scroller.scroll_vertical = credits_scroll

func load_credits():
	var credits = ConfigFile.new()
	var err = credits.load("res://credits.gdcfg")
	if err != OK:
		printerr("Could not load credits.")
	else:
		var spacer = scrollerV.get_child(0)
		spacer.set_custom_minimum_size(
			Vector2(1, scroller.rect_size.y)
		)
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
