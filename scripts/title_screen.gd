extends Control

## The title screen (scenes/title.tscn, the main scene): a coordinate plane on
## graph paper. Each quadrant is a menu option and lifts away from the axes,
## growing a little, while it is hovered or picked with the keys:
##   2nd (top left)      PLAY A MATCH    a plain match, the whole collection
##   1st (top right)     START A RUN     a fresh run
##   3rd (bottom left)   COLLECTION      every card, large (a DDCardGrid)
##   4th (bottom right)  EXIT            quit to the desktop
## The game's name sits in a circle on the origin.
##
## Launched with a match / dev flag (--match, --run, --botsim=, --scenario=,
## --shots=, --demo) it goes straight to the arena, so the bot sim and the dev
## scenarios start exactly as before.

const ARENA_SCENE := "res://scenes/arena.tscn"
const SKIP_FLAGS := ["--match", "--run", "--botsim=", "--scenario=", "--shots=", "--demo"]

## Graph paper: a minor line every CELL px, a major one every MAJOR cells.
const CELL := 25.0
const MAJOR := 5
## Where the quadrants' outer edges sit. Negative: past the screen edge, so the
## plane trails off in every direction (the axes run off screen too, with no
## arrowheads). A positive margin with ARROWS on draws the bounded plane.
const MARGIN := -90.0
const ARROWS := false
## gap between a resting quadrant and the axes, and how far a hovered one lifts
const AXIS_GAP := 9.0
const LIFT_PX := 22.0
const GROW := 0.04
const LIFT_RATE := 12.0
const CIRCLE_R := 150.0

const PAPER := Color(0.965, 0.958, 0.94)
const INK := Color(0.16, 0.13, 0.2)
## the reference plane's colours: axes, then per quadrant [fill, border/ink]
const AXIS_X := Color(0.78, 0.13, 0.86)
const AXIS_Y := Color(0.93, 0.25, 0.47)

## index: 0 top left, 1 top right, 2 bottom left, 3 bottom right
const OPTIONS := [
	{"title": "PLAY A MATCH", "sub": "one match with the whole collection", "quad": "2nd",
		"fill": Color(0.995, 0.925, 0.86), "ink": Color(0.94, 0.47, 0.1)},
	{"title": "START A RUN", "sub": "a fresh run: draft as you go", "quad": "1st",
		"fill": Color(0.91, 0.88, 0.99), "ink": Color(0.36, 0.25, 0.65)},
	{"title": "COLLECTION", "sub": "every card in the game", "quad": "3rd",
		"fill": Color(0.85, 0.93, 0.9), "ink": Color(0.17, 0.6, 0.47)},
	{"title": "EXIT", "sub": "back to the desktop", "quad": "4th",
		"fill": Color(0.82, 0.89, 0.97), "ink": Color(0.12, 0.47, 0.86)},
]

var hover := -1
var lift := [0.0, 0.0, 0.0, 0.0]
var clock := 0.0
var collection: DDCardGrid = null
var preview: Control = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	for a in OS.get_cmdline_user_args():
		for f in SKIP_FLAGS:
			if a == String(f) or (String(f).ends_with("=") and a.begins_with(String(f))) \
					or (f == "--run" and a.begins_with("--run=")):
				get_tree().change_scene_to_file.call_deferred(ARENA_SCENE)
				return


func _process(delta: float) -> void:
	clock += delta
	var k: float = clampf(delta * LIFT_RATE, 0.0, 1.0)
	for i in 4:
		lift[i] = lerpf(float(lift[i]), 1.0 if (i == hover and collection == null) else 0.0, k)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if (hover >= 0 and collection == null) \
		else Control.CURSOR_ARROW
	queue_redraw()


# --------------------------------------------------------------------- layout

func origin() -> Vector2:
	return size * 0.5


## A quadrant's resting rect: from the screen margin to just short of the axes.
func quad_rect(i: int) -> Rect2:
	var c := origin()
	var left := i % 2 == 0
	var top := i < 2
	var x0: float = MARGIN if left else c.x + AXIS_GAP
	var x1: float = c.x - AXIS_GAP if left else size.x - MARGIN
	var y0: float = MARGIN if top else c.y + AXIS_GAP
	var y1: float = c.y - AXIS_GAP if top else size.y - MARGIN
	return Rect2(x0, y0, x1 - x0, y1 - y0)


## Away from the origin, through the quadrant's middle.
func quad_dir(i: int) -> Vector2:
	return (quad_rect(i).get_center() - origin()).normalized()


func quad_at(p: Vector2) -> int:
	if p.distance_to(origin()) <= CIRCLE_R:
		return -1
	for i in 4:
		if quad_rect(i).grow(AXIS_GAP).has_point(p):
			return i
	return -1


# ---------------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if collection != null:
		return
	if event is InputEventMouseMotion:
		hover = quad_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := quad_at(event.position)
		if i >= 0:
			_choose(i)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if collection != null:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE:
			if preview != null:
				_close_preview()
			else:
				_close_collection()
			get_viewport().set_input_as_handled()
		return
	var cur: int = maxi(hover, 0)
	match event.keycode:
		KEY_LEFT, KEY_A:
			hover = cur - 1 if cur % 2 == 1 else cur
		KEY_RIGHT, KEY_D:
			hover = cur + 1 if cur % 2 == 0 else cur
		KEY_UP, KEY_W:
			hover = cur - 2 if cur >= 2 else cur
		KEY_DOWN, KEY_S:
			hover = cur + 2 if cur < 2 else cur
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if hover >= 0:
				_choose(hover)
		_:
			return
	get_viewport().set_input_as_handled()


func _choose(i: int) -> void:
	match i:
		0:
			if Run.active:
				Run.stop()
			Run.menu_choice = "match"
			get_tree().change_scene_to_file(ARENA_SCENE)
		1:
			if Run.active:
				Run.stop()
			Run.menu_choice = "run"
			get_tree().change_scene_to_file(ARENA_SCENE)
		2:
			_open_collection()
		3:
			get_tree().quit()


# ----------------------------------------------------------------- collection

## The debug all-cards view, enlarged: fewer columns, full-height cards.
func _open_collection() -> void:
	hover = -1
	collection = DDCardGrid.new()
	collection.name = "Collection"
	collection.cols = 6
	collection.aspect = 1.4
	collection.position = Vector2(40.0, 92.0)
	collection.size = Vector2(size.x - 80.0, size.y - 120.0)
	collection.set_kinds(DDCard.all_kinds())
	collection.card_pressed.connect(_open_preview)
	add_child(collection)


func _close_collection() -> void:
	_close_preview()
	if collection != null and is_instance_valid(collection):
		collection.queue_free()
	collection = null


func _back_rect() -> Rect2:
	return Rect2(40.0, 30.0, 150.0, 46.0)


## Click anywhere on the header strip's BACK chip (the grid eats clicks below).
func _input(event: InputEvent) -> void:
	if collection == null or preview != null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _back_rect().has_point(event.position):
			_close_collection()
			get_viewport().set_input_as_handled()


func _open_preview(kind: String) -> void:
	_close_preview()
	preview = CardPreview.new()
	preview.kind = kind
	preview.closed.connect(_close_preview)
	add_child(preview)


func _close_preview() -> void:
	if preview != null and is_instance_valid(preview):
		preview.queue_free()
	preview = null


## One card shown large with its description; any click closes it.
class CardPreview extends Control:
	signal closed
	var kind := ""

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			closed.emit()
			accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.08, 0.72), true)
		var h: float = minf(size.y - 120.0, 660.0)
		var w: float = h / 1.4
		DDCardFace.draw_full(self, kind, Rect2(size * 0.5 - Vector2(w, h) * 0.5, Vector2(w, h)))
		draw_string(ThemeDB.fallback_font, Vector2(0.0, size.y - 28.0), "click anywhere to close",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(0.85, 0.85, 0.92))


# --------------------------------------------------------------------- render

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER, true)
	_draw_grid(Rect2(Vector2.ZERO, size), INK, 0.05, 0.1)
	if collection != null:
		_draw_collection_header()
		return
	# resting quadrants first, the lifted one over the axes
	var order: Array = [0, 1, 2, 3]
	order.sort_custom(func(a, b): return float(lift[a]) < float(lift[b]))
	for i in order:
		if float(lift[i]) < 0.02:
			_draw_quadrant(i)
	_draw_axes()
	for i in order:
		if float(lift[i]) >= 0.02:
			_draw_quadrant(i)
	_draw_title_circle()


## Graph paper over `r`, lines anchored on the origin so every panel lines up.
func _draw_grid(r: Rect2, col: Color, minor_a: float, major_a: float) -> void:
	var c := origin()
	var x: float = c.x - ceilf((c.x - r.position.x) / CELL) * CELL
	while x <= r.end.x:
		var n: int = int(roundf((x - c.x) / CELL))
		var major := n % MAJOR == 0
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(col.r, col.g, col.b, major_a if major else minor_a),
			1.6 if major else 1.0)
		x += CELL
	var y: float = c.y - ceilf((c.y - r.position.y) / CELL) * CELL
	while y <= r.end.y:
		var m: int = int(roundf((y - c.y) / CELL))
		var major2 := m % MAJOR == 0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), Color(col.r, col.g, col.b, major_a if major2 else minor_a),
			1.6 if major2 else 1.0)
		y += CELL


func _draw_quadrant(i: int) -> void:
	var o: Dictionary = OPTIONS[i]
	var fill: Color = o["fill"]
	var ink: Color = o["ink"]
	var l: float = float(lift[i])
	var r := quad_rect(i)
	# lifted: pushed away from the origin and grown about its own middle
	var at: Vector2 = r.get_center() + quad_dir(i) * LIFT_PX * l
	var s: float = 1.0 + GROW * l
	var drawn := Rect2(at - r.size * s * 0.5, r.size * s)
	if l > 0.02:
		var shadow := drawn
		shadow.position += Vector2(8.0, 10.0) * l
		draw_rect(shadow, Color(0.1, 0.06, 0.16, 0.22 * l), true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill.lerp(Color(1, 1, 1), 0.25 * l)
	sb.border_color = ink
	sb.set_border_width_all(int(2.0 + 3.0 * l))
	sb.set_corner_radius_all(int(6.0 + 6.0 * l))
	draw_style_box(sb, drawn)
	_draw_grid(drawn.grow(-3.0), ink, 0.1, 0.2)
	# the option: an icon, then a label box like the plane's quadrant tags, centred
	# on the part of the quadrant that is on screen
	var seen := drawn.intersection(Rect2(Vector2.ZERO, size))
	var mid := seen.get_center() + Vector2(0.0, -seen.size.y * 0.08)
	_draw_icon(i, mid + Vector2(0.0, -62.0 * s), 92.0 * s, ink)
	var font := ThemeDB.fallback_font
	var tsize := int(40.0 * s)
	var tw: float = font.get_string_size(String(o["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, tsize).x
	var box := Rect2(mid.x - tw * 0.5 - 22.0, mid.y + 32.0 * s, tw + 44.0, 64.0 * s)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(1, 1, 1, 0.96)
	bsb.border_color = ink
	bsb.set_border_width_all(3)
	bsb.set_corner_radius_all(6)
	draw_style_box(bsb, box)
	draw_string(font, Vector2(box.position.x, box.position.y + box.size.y * 0.5 + tsize * 0.36), String(o["title"]),
		HORIZONTAL_ALIGNMENT_CENTER, box.size.x, tsize, ink)
	draw_string(font, Vector2(seen.position.x, box.end.y + 30.0), String(o["sub"]), HORIZONTAL_ALIGNMENT_CENTER,
		seen.size.x, int(18.0 * s), Color(ink.r, ink.g, ink.b, 0.8))


## The two axes through the origin, arrows at both ends, a tick across each
## axis every cell and a longer one every MAJOR cells.
func _draw_axes() -> void:
	var c := origin()
	# bounded: they stop short of the edge with arrowheads; otherwise they run
	# straight off the screen
	var inset: float = MARGIN * 0.4 if ARROWS else -40.0
	var left := Vector2(inset, c.y)
	var right := Vector2(size.x - inset, c.y)
	var top := Vector2(c.x, inset)
	var bottom := Vector2(c.x, size.y - inset)
	for t in [[left, right, AXIS_X, Vector2(0, 1)], [top, bottom, AXIS_Y, Vector2(1, 0)]]:
		var a: Vector2 = t[0]
		var b: Vector2 = t[1]
		var col: Color = t[2]
		var across: Vector2 = t[3]
		var along := (b - a).normalized()
		var length := a.distance_to(b)
		# ticks first, so the axis line sits over their middles
		var d := fmod(c.distance_to(a), CELL)
		while d < length:
			var p: Vector2 = a + along * d
			var n: int = int(roundf(p.distance_to(c) / CELL))
			var clear_of_arrows: bool = not ARROWS or (d > 18.0 and d < length - 18.0)
			if p.distance_to(c) > CIRCLE_R + 4.0 and clear_of_arrows:
				var big := n % MAJOR == 0
				var half: float = 13.0 if big else 6.0
				draw_line(p - across * half, p + across * half, col, 3.0 if big else 2.0, true)
			d += CELL
		draw_line(a, b, col, 5.0, true)
		if not ARROWS:
			continue
		for end in [[a, -along], [b, along]]:
			var tip: Vector2 = end[0]
			var dir: Vector2 = end[1]
			draw_colored_polygon(PackedVector2Array([tip, tip - dir * 22.0 + across * 11.0, tip - dir * 22.0 - across * 11.0]), col)


func _draw_title_circle() -> void:
	var c := origin()
	draw_circle(c + Vector2(6.0, 8.0), CIRCLE_R + 6.0, Color(0.1, 0.06, 0.16, 0.18))
	draw_circle(c, CIRCLE_R + 6.0, INK)
	draw_circle(c, CIRCLE_R, Color(1, 1, 1))
	# the four quadrant colours as a thin inner ring, in their own corners
	for i in 4:
		var start: float = [PI, PI * 1.5, PI * 0.5, 0.0][i]
		draw_arc(c, CIRCLE_R - 9.0, start, start + PI * 0.5, 16, OPTIONS[i]["ink"], 6.0, true)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(c.x - CIRCLE_R, c.y - 6.0), "DRAFT", HORIZONTAL_ALIGNMENT_CENTER, CIRCLE_R * 2.0, 52, INK)
	draw_string(font, Vector2(c.x - CIRCLE_R, c.y + 46.0), "QUADRINT", HORIZONTAL_ALIGNMENT_CENTER, CIRCLE_R * 2.0, 40,
		AXIS_X.darkened(0.15))
	draw_line(c + Vector2(-82.0, 10.0), c + Vector2(82.0, 10.0), AXIS_Y, 3.0, true)


func _draw_collection_header() -> void:
	var font := ThemeDB.fallback_font
	var b := _back_rect()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.95)
	sb.border_color = OPTIONS[2]["ink"]
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	draw_style_box(sb, b)
	draw_string(font, Vector2(b.position.x, b.position.y + 31.0), "< BACK", HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 22,
		OPTIONS[2]["ink"])
	draw_string(font, Vector2(0.0, 66.0), "COLLECTION", HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, INK)
	draw_string(font, Vector2(size.x - 440.0, 64.0), "%d cards  ·  click one to see it large" % DDCard.all_kinds().size(),
		HORIZONTAL_ALIGNMENT_RIGHT, 400.0, 16, Color(INK.r, INK.g, INK.b, 0.7))


## Each option's picture, in its quadrant's ink, centred on c, about `r` across.
func _draw_icon(i: int, c: Vector2, r: float, ink: Color) -> void:
	var paper := Color(1, 1, 1, 0.95)
	match i:
		0:
			# two cards squaring up, a spark between them
			for side in [-1.0, 1.0]:
				var cc: Vector2 = c + Vector2(side * r * 0.55, 0.0)
				_card_shape(cc, Vector2(r * 0.62, r * 0.86), side * 0.22, paper, ink)
			var spark := PackedVector2Array()
			for k in 8:
				var rad: float = r * (0.3 if k % 2 == 0 else 0.12)
				spark.append(c + Vector2.from_angle(TAU * float(k) / 8.0 + clock * 0.6) * rad)
			draw_colored_polygon(spark, ink)
		1:
			# a winding path of fights up to a flag
			var pts := [c + Vector2(-r * 0.9, r * 0.5), c + Vector2(-r * 0.35, r * 0.15), c + Vector2(0.05 * r, r * 0.45),
				c + Vector2(r * 0.45, 0.0), c + Vector2(r * 0.15, -r * 0.4)]
			for k in pts.size() - 1:
				var a: Vector2 = pts[k]
				var b: Vector2 = pts[k + 1]
				var steps := 5
				for s2 in steps:
					draw_circle(a.lerp(b, (float(s2) + 0.5) / float(steps)), 2.4, ink)
			for k in pts.size() - 1:
				draw_circle(pts[k], 8.0, paper)
				draw_arc(pts[k], 8.0, 0.0, TAU, 16, ink, 3.0, true)
			var pole: Vector2 = pts[pts.size() - 1]
			draw_line(pole + Vector2(0.0, 8.0), pole + Vector2(0.0, -r * 0.55), ink, 3.0, true)
			draw_colored_polygon(PackedVector2Array([pole + Vector2(0.0, -r * 0.55), pole + Vector2(r * 0.42, -r * 0.43),
				pole + Vector2(0.0, -r * 0.3)]), ink)
		2:
			# a fan of five cards
			for k in 5:
				var ang: float = (float(k) - 2.0) * 0.22
				var cc2: Vector2 = c + Vector2(0.0, r * 0.35) + Vector2.from_angle(ang - PI * 0.5) * r * 0.45
				_card_shape(cc2, Vector2(r * 0.5, r * 0.72), ang, paper if k != 2 else Color(ink.r, ink.g, ink.b, 0.25), ink)
		3:
			# a door left open, an arrow on its way out
			var door := Rect2(c + Vector2(-r * 0.75, -r * 0.6), Vector2(r * 0.65, r * 1.2))
			draw_rect(door, paper, true)
			draw_rect(door, ink, false, 3.0)
			draw_colored_polygon(PackedVector2Array([door.position, door.position + Vector2(r * 0.38, r * 0.14),
				door.position + Vector2(r * 0.38, door.size.y + r * 0.1), door.position + Vector2(0.0, door.size.y)]), ink)
			var y: float = c.y
			draw_line(Vector2(c.x - r * 0.05, y), Vector2(c.x + r * 0.8, y), ink, 6.0, true)
			draw_colored_polygon(PackedVector2Array([Vector2(c.x + r * 0.98, y), Vector2(c.x + r * 0.7, y - r * 0.2),
				Vector2(c.x + r * 0.7, y + r * 0.2)]), ink)


func _card_shape(c: Vector2, sz: Vector2, ang: float, fill: Color, ink: Color) -> void:
	var hx := Vector2(sz.x * 0.5, 0.0).rotated(ang)
	var hy := Vector2(0.0, sz.y * 0.5).rotated(ang)
	var pts := PackedVector2Array([c - hx - hy, c + hx - hy, c + hx + hy, c - hx + hy])
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, ink, 3.0, true)
	draw_line(c - hx * 0.6 - hy * 0.55, c + hx * 0.6 - hy * 0.55, Color(ink.r, ink.g, ink.b, 0.6), 2.0, true)
