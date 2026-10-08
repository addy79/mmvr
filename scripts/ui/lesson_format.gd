class_name LessonFormat
extends RefCounted
## BBCode building blocks shared by every station's lesson text.

const EQ_COLOR: String = "#9fd3ff"
const VALUE_COLOR: String = "#ffd479"
const TRY_COLOR: String = "#a6f0a6"
const NOTE_COLOR: String = "#c8c8d0"
const DERIVATION_COLOR: String = "#d8c8ff"


## A displayed equation: symbolic form, then the numbers, then the result.
static func equation(symbolic: String, substituted: String = "", result: String = "") -> String:
	var s: String = "[indent][color=%s]%s[/color]" % [EQ_COLOR, symbolic]
	if not substituted.is_empty():
		s += "  =  " + substituted
	if not result.is_empty():
		s += "  =  [color=%s][b]%s[/b][/color]" % [VALUE_COLOR, result]
	return s + "[/indent]\n"


## Short derivation, set apart from the main text.
static func derivation(text: String) -> String:
	return "[indent][color=%s][b]Derivation:[/b] %s[/color][/indent]\n" % [DERIVATION_COLOR, text]


static func value(text: String) -> String:
	return "[color=%s][b]%s[/b][/color]" % [VALUE_COLOR, text]


static func try_this(text: String) -> String:
	return "\n[color=%s][b]Try this:[/b] %s[/color]\n" % [TRY_COLOR, text]


static func note(text: String) -> String:
	return "[color=%s][i]%s[/i][/color]\n" % [NOTE_COLOR, text]


static func ok_or_fail(ok: bool, text: String) -> String:
	return "[color=%s][b]%s[/b][/color]" % ["#7ee787" if ok else "#ff7b72", text]


## A data table like the handout's: header row, then rows of already formatted cells.
static func table(headers: PackedStringArray, rows: Array[PackedStringArray]) -> String:
	var s: String = "[table=%d]" % headers.size()
	for h: String in headers:
		s += "[cell bg=#1d2633 border=#3a4658 padding=6,3,6,3][b]%s[/b][/cell]" % h
	for row: PackedStringArray in rows:
		for c: String in row:
			s += "[cell border=#3a4658 padding=6,2,6,2]%s[/cell]" % c
	return s + "[/table]\n"


## Heading inside a lesson step.
static func section(text: String) -> String:
	return "\n[color=#9fd3ff][b]%s[/b][/color]\n" % text


## A report question from the handout, followed by guidance on how to think about it.
static func question(text: String, guidance: String) -> String:
	return "[color=#ffd479][b]Q.[/b] %s[/color]\n[indent]%s[/indent]\n" % [text, guidance]
