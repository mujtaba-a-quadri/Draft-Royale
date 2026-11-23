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
## full: each card's full face with its description (DDCardFace.draw_full; the
## text only shows on faces at least 260 px wide). backing: the dark panel
## behind the grid; off, whatever is behind shows through and the header
## switches to dark ink.
var full := false
var backing := true
var selected_kind := "":
	set(value):
		if value == selected_kind:
			return
		selected_kind = value
		queue_redraw()

## Smooth scrolling: the wheel moves scroll_target, and scroll eases toward it
## (SCROLL_EASE per second, framerate independent).
var scroll := 0.0
var scroll_target := 0.0
const SCROLL_EASE := 14.0
var hover_index := -1
var hover_filter := ""
var _mouse := Vector2(-1.0, -1.0)


## The cards are drawn on this child, clipped to the list area under the
## header, so a card scrolling up slides under the filter bar instead of over
## it (which shows when there is no backing). Redrawn with the grid.
var _list: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_list = Control.new()
	_list.name = "List"
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.clip_contents = true
	_list.draw.connect(_draw_list)
	add_child(_list)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAW and _list != null:
		_list.position = Vector2(0.0, list_top())
		_list.size = Vector2(size.x, maxf(0.0, size.y - list_top()))
		_list.queue_redraw()


func _process(delta: float) -> void:
	if absf(scroll - scroll_target) < 0.5:
		if scroll != scroll_target:
			scroll = scroll_target
			queue_redraw()
		return
	scroll = lerpf(scroll, scroll_target, 1.0 - exp(-SCROLL_EASE * delta))
	# the card under a still cursor changes as the list glides past it
	if _mouse.x >= 0.0:
		hover_index = _card_at(_mouse)
	queue_redraw()


func set_kinds(list: Array) -> void:
	kinds = list.duplicate()
	scroll = 0.0
	scroll_target = 0.0
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
	scroll_target = 0.0
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
	scroll_target = clampf(scroll_target, 0.0, max_scroll())


## Move the list by `px` (positive: down the list), eased.
func scroll_by(px: float) -> void:
	scroll_target += px
	_clamp_scroll()


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
		if event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			# a notch is a fixed distance, not a share of a card: tall full faces
			# would otherwise jump half a row at a time. Touchpads send a factor.
			var factor: float = float(event.factor) if float(event.factor) > 0.0 else 1.0
			var notch: float = minf(cell_height() * 0.6, 150.0) * factor
			scroll_by(-notch if event.button_index == MOUSE_BUTTON_WHEEL_UP else notch)
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
	elif event is InputEventPanGesture:
		scroll_by(event.delta.y * 40.0)
		accept_event()
	elif event is InputEventMouseMotion:
		_mouse = event.position
		hover_filter = _filter_at(event.position)
		hover_index = _card_at(event.position)
		queue_redraw()


# --------------------------------------------------------------------- render

func _draw() -> void:
	var font := ThemeDB.fallback_font
	# with no backing the header sits on light paper: dark ink
	var ink := Color(0.9, 0.92, 1.0) if backing else Color(0.16, 0.13, 0.2)
	if backing:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.08, 0.13, 0.97), true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.34, 0.34, 0.44, 0.95), false, 2.0)
	draw_string(font, Vector2(PAD, 22.0), header_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, ink)
	var btns := _filter_buttons()
	for f in FILTERS:
		var r: Rect2 = btns[f]
		var on: bool = active.has(f)
		var hot := String(hover_filter) == String(f)
		var off_fill := Color(0.16, 0.17, 0.23, 1.0) if backing else Color(1, 1, 1, 0.92)
		draw_rect(r, Color(0.42, 0.62, 0.95, 0.92) if on else off_fill, true)
		var edge := Color(0.74, 0.88, 1.0, 0.9) if (on or hot) else Color(0.4, 0.42, 0.5)
		if not backing and not on:
			edge = ink if hot else Color(ink.r, ink.g, ink.b, 0.55)
		draw_rect(r, edge, false, 1.5)
		var off_text := Color(0.82, 0.85, 0.95) if backing else ink
		draw_string(font, r.position + Vector2(9.0, 14.5), _filter_label(f),
			HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 18.0, 13,
			Color(0.06, 0.07, 0.1) if on else off_text)
	var list: Array = filtered()
	draw_rect(Rect2(PAD * 0.5, list_top() - 3.0, size.x - PAD, 1.0),
		Color(1, 1, 1, 0.07) if backing else Color(ink.r, ink.g, ink.b, 0.15), true)
	if max_scroll() > 0.0:
		var track := Rect2(size.x - 8.0, list_top(), 4.0, list_height())
		draw_rect(track, Color(1, 1, 1, 0.08) if backing else Color(ink.r, ink.g, ink.b, 0.1), true)
		var frac: float = clampf(list_height() / content_height(), 0.08, 1.0)
		var h: float = track.size.y * frac
		var y: float = track.position.y + (track.size.y - h) * clampf(scroll / max_scroll(), 0.0, 1.0)
		draw_rect(Rect2(track.position.x, y, track.size.x, h),
			Color(0.72, 0.82, 1.0, 0.55) if backing else Color(ink.r, ink.g, ink.b, 0.5), true)
	if list.is_empty():
		draw_string(font, Vector2(PAD, list_top() + 30.0), "no cards match those filters",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.72, 0.8) if backing else ink)


## The cards themselves, on the clipped list child (its origin is list_top()).
func _draw_list() -> void:
	var hilite := Color(0.92, 0.95, 1.0, 0.5) if backing else Color(0.16, 0.13, 0.2, 0.55)
	var list: Array = filtered()
	var shift := Vector2(0.0, -list_top())
	for i in list.size():
		var cr := cell_rect(i)
		if cr.end.y < list_top() or cr.position.y > size.y:
			continue
		cr.position += shift
		if full:
			DDCardFace.draw_full(_list, String(list[i]), cr, 1.0)
		else:
			DDCardFace.draw(_list, String(list[i]), cr, 1.0)
		if String(list[i]) == String(selected_kind):
			_list.draw_rect(cr, Color(1, 1, 1, 0.85), false, 3.0)
		elif i == hover_index:
			_list.draw_rect(cr, hilite, false, 2.0)
