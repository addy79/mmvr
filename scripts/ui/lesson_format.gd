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
