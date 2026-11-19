class_name DDCardGrid
extends Control

## A scrolling grid of card faces with a type filter bar above it.
##
## The debug all-cards shelf uses it today; the collection screen and the mid-run
## deck view are meant to reuse it with their own card list, their own filters and
## their own columns.

signal card_pressed(kind: String)

const COLS := 8
const PAD := 12.0
const GAP := 9.0
const HEADER_H := 30.0
const FONT_SIZE := 15

## Card types the filter buttons toggle, in bar order. "BUILDING" "TROOPS"
## "SPELLS" are drawn from these.
const FILTERS := ["building", "troop", "spell"]

var kinds: Array = []
var active := {}
## columns and card height / width: the debug shelf keeps COLS and 0.82; the
## collection screen uses fewer, taller cards
var cols := COLS
var aspect := 0.82
var selected_kind := "":
	set(value):
		if value == selected_kind:
			return
		selected_kind = value
		queue_redraw()

var scroll := 0.0
var hover_index := -1
var hover_filter := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true


func set_kinds(list: Array) -> void:
	kinds = list.duplicate()
	scroll = 0.0
	queue_redraw()


# ------------------------------------------------------------------ filtering

## The cards currently shown, in list order.
func filtered() -> Array:
	var out: Array = []
	for k in kinds:
		var t := String(DDCard.get_card(String(k))["type"])
		if not active.is_empty() and not active.has(t):
			continue
		out.append(k)
	return out


## "CARDS", "TROOPS", "TROOPS + SPELLS" — what the header claims to be showing.
func shown_label() -> String:
	var parts: Array = []
	for f in FILTERS:
		if active.has(f):
			parts.append(String(f).to_upper() + "S")
	if parts.is_empty():
		return "CARDS"
	return " + ".join(parts)


func header_text() -> String:
	return "SHOWING ALL %s -- FILTERS: " % shown_label()


func toggle_filter(f: String) -> void:
	if active.has(f):
		active.erase(f)
	else:
		active[f] = true
	scroll = 0.0
	queue_redraw()


# ------------------------------------------------------------------- geometry

func cell_width() -> float:
	return (size.x - PAD * 2.0 - float(cols - 1) * GAP) / float(cols)


func cell_height() -> float:
	return cell_width() * aspect


func list_top() -> float:
	return HEADER_H + 4.0


func list_height() -> float:
	return maxf(0.0, size.y - list_top() - PAD * 0.5)


func rows() -> int:
	return int(ceil(float(filtered().size()) / float(cols)))


func content_height() -> float:
	var n := filtered().size()
	if n == 0:
		return 0.0
	return float(rows()) * cell_height() + float(rows() - 1) * GAP


func max_scroll() -> float:
	return maxf(0.0, content_height() - list_height())


func cell_rect(i: int) -> Rect2:
	var cw := cell_width()
	var ch := cell_height()
	var col := i % cols
	var row: int = int(float(i) / float(cols))
	return Rect2(PAD + float(col) * (cw + GAP), list_top() + float(row) * (ch + GAP) - scroll, cw, ch)


func _clamp_scroll() -> void:
	scroll = clampf(scroll, 0.0, max_scroll())


# ---------------------------------------------------------------------- input

func _filter_buttons() -> Dictionary:
	var font := ThemeDB.fallback_font
	var out := {}
	var x: float = PAD + font.get_string_size(header_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 8.0
	for f in FILTERS:
		var w: float = font.get_string_size(_filter_label(f), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 18.0
		out[f] = Rect2(x, 6.0, w, 20.0)
		x += w + 7.0
	return out


func _filter_label(f: String) -> String:
	return String(f).to_upper() + "S"


func _filter_at(p: Vector2) -> String:
	var btns := _filter_buttons()
	for f in FILTERS:
		if (btns[f] as Rect2).has_point(p):
			return String(f)
	return ""


func _card_at(p: Vector2) -> int:
	if p.y < list_top() or p.y > size.y:
		return -1
	var list: Array = filtered()
	for i in list.size():
		if cell_rect(i).has_point(p):
			return i
	return -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			scroll -= cell_height() * 0.6
			_clamp_scroll()
			queue_redraw()
			accept_event()
			return
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			scroll += cell_height() * 0.6
			_clamp_scroll()
			queue_redraw()
			accept_event()
			return
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			var f := _filter_at(event.position)
			if f != "":
				toggle_filter(f)
			else:
				var i := _card_at(event.position)
				if i >= 0:
					card_pressed.emit(String(filtered()[i]))
		accept_event()
	elif event is InputEventMouseMotion:
		hover_filter = _filter_at(event.position)
		hover_index = _card_at(event.position)
		queue_redraw()


# --------------------------------------------------------------------- render

func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.08, 0.13, 0.97), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.34, 0.34, 0.44, 0.95), false, 2.0)
	draw_string(font, Vector2(PAD, 22.0), header_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE,
		Color(0.9, 0.92, 1.0))
	var btns := _filter_buttons()
	for f in FILTERS:
		var r: Rect2 = btns[f]
		var on: bool = active.has(f)
		var hot := String(hover_filter) == String(f)
		draw_rect(r, Color(0.42, 0.62, 0.95, 0.92) if on else Color(0.16, 0.17, 0.23, 1.0), true)
		draw_rect(r, Color(0.74, 0.88, 1.0, 0.9) if (on or hot) else Color(0.4, 0.42, 0.5), false, 1.5)
		draw_string(font, r.position + Vector2(9.0, 14.5), _filter_label(f),
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 18.0, 13,
			Color(0.06, 0.07, 0.1) if on else Color(0.82, 0.85, 0.95))
	var list: Array = filtered()
	draw_rect(Rect2(PAD * 0.5, list_top() - 3.0, size.x - PAD, 1.0), Color(1, 1, 1, 0.07), true)
	for i in list.size():
		var cr := cell_rect(i)
		if cr.end.y < list_top() or cr.position.y > size.y:
			continue
		DDCardFace.draw(self, String(list[i]), cr, 1.0)
		if String(list[i]) == String(selected_kind):
			draw_rect(cr, Color(1, 1, 1, 0.85), false, 3.0)
		elif i == hover_index:
			draw_rect(cr, Color(0.92, 0.95, 1.0, 0.5), false, 2.0)
	if max_scroll() > 0.0:
		var track := Rect2(size.x - 8.0, list_top(), 4.0, list_height())
		draw_rect(track, Color(1, 1, 1, 0.08), true)
		var frac: float = clampf(list_height() / content_height(), 0.08, 1.0)
		var h: float = track.size.y * frac
		var y: float = track.position.y + (track.size.y - h) * clampf(scroll / max_scroll(), 0.0, 1.0)
		draw_rect(Rect2(track.position.x, y, track.size.x, h), Color(0.72, 0.82, 1.0, 0.55), true)
	if list.is_empty():
		draw_string(font, Vector2(PAD, list_top() + 30.0), "no cards match those filters",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.72, 0.8))
