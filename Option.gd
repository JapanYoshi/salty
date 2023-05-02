extends Node2D

export var index = 0

onready var anim = $Option/AnimationPlayer
onready var button = $Option/HSplitContainer/Button
onready var textbox = $Option/HSplitContainer/Content
onready var textbox_base_width = textbox.rect_size.x

# Called when the node enters the scene tree for the first time.
func _ready():
	button.set_text(char(0x3358 + 1 + 2 * index - 3 * int(index == 3)))
	anim.play("wrong_silent", -1, 1000)
	
	# TEST
#	set_content("line 1 [i]line 1[/i] [code]TRUE[/code] oeuoeuoeuoe uoe ou oe uoe uoeuoe uoe uoe uoe uoeu oe uoeu oeu oeu oeuoeu oeu oe uoe uoe uoe oeuu oeuoe uoe ueo ueou oe uoe uoe uoe")
#	enter(0);
	pass # Replace with function body.

func _calc_text_width_with_font(text: String, is_bold: bool, is_italic: bool, is_code: bool) -> float:
	var font: Font
	if is_code:
		font = textbox.get_font("mono_font")
	elif is_bold:
		if is_italic:
			font = textbox.get_font("bold_italics_font")
		else:
			font = textbox.get_font("bold_font")
	else:
		if is_italic:
			font = textbox.get_font("italics_font")
		else:
			font = textbox.get_font("normal_font")
	return font.get_string_size(text).x;

func _calc_rich_text_width(bbcode: String) -> float:
	if bbcode == "": return 1.0;
	var is_bold: bool = false; var is_italic: bool = false; var is_code: bool = false;
	var size: float = 0; var cursor: int = 0; var last_cursor: int = 0;
	while cursor < len(bbcode):
		if bbcode[cursor] != "[":
			cursor += 1; continue
		if is_bold and bbcode.substr(cursor, 4) == "[/b]":
			size += _calc_text_width_with_font(
				bbcode.substr(last_cursor, cursor - last_cursor),
				is_bold, is_italic, is_code
			)
			is_bold = false;
			cursor += 4;
			last_cursor = cursor;
		elif !is_bold and bbcode.substr(cursor, 3) == "[b]":
			size += _calc_text_width_with_font(
				bbcode.substr(last_cursor, cursor - last_cursor),
				is_bold, is_italic, is_code
			)
			is_bold = true;
			cursor += 3;
			last_cursor = cursor;
		elif is_italic and bbcode.substr(cursor, 4) == "[/i]":
			size += _calc_text_width_with_font(
				bbcode.substr(last_cursor, cursor - last_cursor),
				is_bold, is_italic, is_code
			)
			is_italic = false;
			cursor += 4;
			last_cursor = cursor;
		elif !is_italic and bbcode.substr(cursor, 3) == "[i]":
			size += _calc_text_width_with_font(
				bbcode.substr(last_cursor, cursor - last_cursor),
				is_bold, is_italic, is_code
			)
			is_italic = true;
			cursor += 3;
			last_cursor = cursor;
		elif is_code and bbcode.substr(cursor, 7) == "[/code]":
			size += _calc_text_width_with_font(
				bbcode.substr(last_cursor, cursor - last_cursor),
				is_bold, is_italic, is_code
			)
			is_code = false;
			cursor += 7;
			last_cursor = cursor;
		elif !is_code and bbcode.substr(cursor, 6) == "[code]":
			size += _calc_text_width_with_font(
				bbcode.substr(last_cursor, cursor - last_cursor),
				is_bold, is_italic, is_code
			)
			is_code = true;
			cursor += 6;
			last_cursor = cursor;
		else:
			cursor += 1;
	# In case we end with regular text:
	size += _calc_text_width_with_font(
		bbcode.substr(last_cursor, cursor - last_cursor),
		is_bold, is_italic, is_code
	)
	return size

func reset():
	anim.play("wrong_silent", -1, 10000, false)

func set_content(content: String):
	var text_width = _calc_rich_text_width(content)
	textbox.rect_scale.x = min(1.0, textbox_base_width / text_width)
	textbox.rect_size.x = max(textbox_base_width, text_width);
	textbox.bbcode_text = content

func enter(i):
	yield(get_tree().create_timer(i * 0.1), "timeout")
	anim.play("show")

func leave():
	anim.play("wrong_silent")

func highlight():
	anim.play("highlight")

func wrong():
	anim.play("wrong")

func right():
	anim.play("right")

func _on_Option_gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == 1 and event.pressed:
			print("Clicked option %d" % index + " (reaction not implemented)")
			C.emit_signal("gp_button", 4, [1, 3, 5, 4][index], true)
