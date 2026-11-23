extends Control

## The title screen (scenes/title.tscn, the main scene): a coordinate plane on
## graph paper. Each quadrant is a menu option and lifts away from the axes,
## growing a little, while it is hovered or picked with the keys:
##   2nd (top left)      PLAY A MATCH    a plain match, the whole collection
##   1st (top right)     START A RUN     a fresh run
##   3rd (bottom left)   COLLECTION      every card, large (a DDCardGrid)
##   4th (bottom right)  OPTIONS         sound levels and the sides' colours
## The game's name sits in a circle on the origin. A small EXIT chip in the
## bottom right corner, over the OPTIONS quadrant, quits to the desktop.
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
const LIFT_PX := 30.0
const GROW := 0.06
const LIFT_RATE := 12.0
const CIRCLE_R := 180.0

const PAPER := Color(0.965, 0.958, 0.94)
const INK := Color(0.16, 0.13, 0.2)
const Settings := preload("res://scripts/settings.gd")
## the axes wear the players' colours (the options page's fixed picks): x the
## right player's, y the left's
var axis_x: Color = Arena.Right_Color
var axis_y: Color = Arena.Left_Color

## index: 0 top left, 1 top right, 2 bottom left, 3 bottom right
const OPTIONS := [
	{"title": "PLAY A MATCH", "sub": "one match with the whole collection", "quad": "2nd",
		"fill": Color(0.995, 0.925, 0.86), "ink": Color(0.94, 0.47, 0.1)},
	{"title": "START A RUN", "sub": "a fresh run: draft as you go", "quad": "1st",
		"fill": Color(0.91, 0.88, 0.99), "ink": Color(0.36, 0.25, 0.65)},
	{"title": "COLLECTION", "sub": "every card in the game", "quad": "3rd",
		"fill": Color(0.85, 0.93, 0.9), "ink": Color(0.17, 0.6, 0.47)},
	{"title": "OPTIONS", "sub": "sound and colors", "quad": "4th",
		"fill": Color(0.82, 0.89, 0.97), "ink": Color(0.12, 0.47, 0.86)},
]

var hover := -1
var lift := [0.0, 0.0, 0.0, 0.0]
var clock := 0.0
var collection: DDCardGrid = null
var preview: Control = null
## the options page is open (drawn in place of the plane, like the collection)
var options_open := false
var exit_hover := false
## the volume slider being dragged: 0 sound effects, 1 music, -1 none
var drag_slider := -1
var opt_hover := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	_refresh_axes()
	for a in OS.get_cmdline_user_args():
		for f in SKIP_FLAGS:
			if a == String(f) or (String(f).ends_with("=") and a.begins_with(String(f))) \
					or (f == "--run" and a.begins_with("--run=")):
				get_tree().change_scene_to_file.call_deferred(ARENA_SCENE)
				return


func _process(delta: float) -> void:
	clock += delta
	var k: float = clampf(delta * LIFT_RATE, 0.0, 1.0)
	var plane := collection == null and not options_open
	for i in 4:
		lift[i] = lerpf(float(lift[i]), 1.0 if (i == hover and plane and not exit_hover) else 0.0, k)
	var pointing: bool = (plane and (hover >= 0 or exit_hover)) or (options_open and opt_hover != "")
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if pointing else Control.CURSOR_ARROW
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
	if options_open:
		_options_input(event)
		return
	if event is InputEventMouseMotion:
		exit_hover = exit_rect().has_point(event.position)
		hover = -1 if exit_hover else quad_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if exit_rect().has_point(event.position):
			get_tree().quit()
		else:
			var i := quad_at(event.position)
			if i >= 0:
				_choose(i)
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if options_open:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACKSPACE:
			_close_options()
			get_viewport().set_input_as_handled()
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
			_open_options()


## The small exit sign, bottom right, over the OPTIONS quadrant.
func exit_rect() -> Rect2:
	return Rect2(size.x - 192.0, size.y - 108.0, 168.0, 84.0)


## An emergency-exit sign: arrow and EXIT on the left, a running figure leaving
## through an open door on the right. Drawn on a 168 x 84 grid in a pale tint
## of the right side's colour on white; hovering swaps the two.
func _draw_exit_sign(r: Rect2, hot: bool) -> void:
	var s: float = r.size.x / 168.0
	var o := r.position
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var tint: Color = axis_x.lerp(Color(1, 1, 1), 0.3)
	var paper := tint if hot else Color(1, 1, 1)
	var ink := Color(1, 1, 1) if hot else tint
	var sb := StyleBoxFlat.new()
	sb.bg_color = paper
	sb.border_color = tint
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	sb.shadow_color = Color(0.1, 0.06, 0.16, 0.18)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(3, 4)
	draw_style_box(sb, r)
	# arrow
	var arrow := PackedVector2Array()
	for q in [[10, 23], [42, 23], [31, 10], [46, 10], [64, 28], [46, 46], [31, 46], [42, 33], [10, 33]]:
		arrow.append(p.call(q[0], q[1]))
	draw_colored_polygon(arrow, ink)
	draw_string(ThemeDB.fallback_font, p.call(6, 75), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, 62.0 * s, int(25 * s), ink)
	# door frame, and the door swung open on the right
	draw_rect(Rect2(p.call(112, 12), Vector2(36, 66) * s), ink, false, 3.0 * s)
	draw_colored_polygon(PackedVector2Array([p.call(150, 6), p.call(162, 12), p.call(162, 72), p.call(150, 80)]), ink)
	# the runner, limbs as round-capped strokes
	var lw: float = 8.5 * s
	var limbs := [
		[[122, 30], [106, 27], [98, 36]],   # back arm
		[[113, 50], [100, 59], [88, 52]],   # back leg
		[[122, 30], [113, 50]],             # body
		[[113, 50], [126, 59], [127, 74]],  # front leg
		[[122, 30], [131, 42], [142, 36]],  # front arm
	]
	for limb in limbs:
		for j in limb.size():
			var a: Vector2 = p.call(limb[j][0], limb[j][1])
			draw_circle(a, lw * 0.5, ink)
			if j > 0:
				var b: Vector2 = p.call(limb[j - 1][0], limb[j - 1][1])
				draw_line(b, a, ink, lw, true)
	draw_circle(p.call(128, 17), 7.5 * s, ink)


# -------------------------------------------------------------------- options

## The options page: a sheet on the graph paper with two volume sliders and,
## for each side, a row of swatches and a "commander's colour" chip. Every
## change is saved at once (Settings, user://settings.cfg); the sliders are
## heard live if a match's sounds exist, and the axes repaint in the new picks.
const OPT_INK := Color(0.12, 0.47, 0.86)
const SWATCH := 34.0
const SWATCH_GAP := 9.0
const SLIDER_W := 480.0


func _open_options() -> void:
	Settings.ensure()
	hover = -1
	exit_hover = false
	options_open = true


func _close_options() -> void:
	if drag_slider >= 0:
		Settings.save()
	drag_slider = -1
	options_open = false
	opt_hover = ""
	_refresh_axes()


func _refresh_axes() -> void:
	axis_x = Settings.side_color(1)
	axis_y = Settings.side_color(0)


func _sheet_rect() -> Rect2:
	var w: float = minf(size.x - 80.0, 1060.0)
	return Rect2((size.x - w) * 0.5, 120.0, w, minf(size.y - 160.0, 640.0))


## Every hot spot on the page: name -> Rect2. "back", "track0" / "track1" (the
## slider tracks), "sw<side>_<i>" (swatch i), "cmd<side>" (commander chip).
func _opt_spots() -> Dictionary:
	var s := _sheet_rect()
	var x0: float = s.position.x + 250.0
	var out := {"back": _back_rect()}
	for k in 2:
		out["track%d" % k] = Rect2(x0, s.position.y + 78.0 + 70.0 * float(k), SLIDER_W, 14.0)
	for side in 2:
		var y: float = s.position.y + 278.0 + 150.0 * float(side)
		for i in Settings.PALETTE.size():
			out["sw%d_%d" % [side, i]] = Rect2(x0 + (SWATCH + SWATCH_GAP) * float(i), y, SWATCH, SWATCH)
		out["cmd%d" % side] = Rect2(x0, y + SWATCH + 22.0, 240.0, 40.0)
	return out


func _spot_at(p: Vector2) -> String:
	var spots := _opt_spots()
	for key in spots:
		var r: Rect2 = spots[key]
		var hit: Rect2 = r.grow_individual(0.0, 12.0, 0.0, 12.0) if String(key).begins_with("track") else r
		if hit.has_point(p):
			return String(key)
	return ""


func _options_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if drag_slider >= 0:
			_slide(drag_slider, event.position.x)
		opt_hover = _spot_at(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			if drag_slider >= 0:
				Settings.save()
			drag_slider = -1
			return
		var key := _spot_at(event.position)
		if key == "back":
			_close_options()
		elif key.begins_with("track"):
			drag_slider = int(key.substr(5))
			_slide(drag_slider, event.position.x)
		elif key.begins_with("sw"):
			var parts := key.substr(2).split("_")
			_pick_color(int(parts[0]), Settings.PALETTE[int(parts[1])])
		elif key.begins_with("cmd"):
			var side := int(key.substr(3))
			Settings.commander[side] = not bool(Settings.commander[side])
			Settings.save()
		accept_event()


func _slide(k: int, x: float) -> void:
	var r: Rect2 = _opt_spots()["track%d" % k]
	var v: float = clampf((x - r.position.x) / r.size.x, 0.0, 1.0)
	if k == 0:
		Settings.sfx = v
	else:
		Settings.music = v
	DDSfx.apply_levels()


## A swatch pick also turns that side's commander colour off. Picking the other
## side's colour swaps the two, so the sides never match.
func _pick_color(side: int, c: Color) -> void:
	var other := 1 - side
	if Settings.colors[other].is_equal_approx(c):
		Settings.colors[other] = Settings.colors[side]
	Settings.colors[side] = c
	Settings.commander[side] = false
	Settings.save()
	_refresh_axes()


func _draw_options() -> void:
	var font := ThemeDB.fallback_font
	var spots := _opt_spots()
	_draw_chip(_back_rect(), "< BACK", OPT_INK, opt_hover == "back")
	draw_string(font, Vector2(0.0, 66.0), "OPTIONS", HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, INK)
	var s := _sheet_rect()
	draw_rect(Rect2(s.position + Vector2(7.0, 9.0), s.size), Color(0.1, 0.06, 0.16, 0.18), true)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.97)
	sb.border_color = OPT_INK
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	draw_style_box(sb, s)
	var lx: float = s.position.x + 40.0
	draw_string(font, Vector2(lx, s.position.y + 46.0), "SOUND", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, OPT_INK)
	var levels := [Settings.sfx, Settings.music]
	var names := ["Sound effects", "Music"]
	for k in 2:
		var tr: Rect2 = spots["track%d" % k]
		var v: float = float(levels[k])
		draw_string(font, Vector2(lx, tr.get_center().y + 7.0), names[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
		var bar := StyleBoxFlat.new()
		bar.bg_color = Color(OPT_INK.r, OPT_INK.g, OPT_INK.b, 0.14)
		bar.set_corner_radius_all(7)
		draw_style_box(bar, tr)
		var full := StyleBoxFlat.new()
		full.bg_color = OPT_INK
		full.set_corner_radius_all(7)
		if v > 0.01:
			draw_style_box(full, Rect2(tr.position, Vector2(maxf(14.0, tr.size.x * v), tr.size.y)))
		var knob := Vector2(tr.position.x + tr.size.x * v, tr.get_center().y)
		var big: bool = drag_slider == k or opt_hover == "track%d" % k
		draw_circle(knob, 15.0 if big else 13.0, Color(1, 1, 1))
		draw_arc(knob, 15.0 if big else 13.0, 0.0, TAU, 24, OPT_INK, 3.0, true)
		draw_string(font, Vector2(tr.end.x + 26.0, tr.get_center().y + 7.0), "%d %%" % int(roundf(v * 100.0)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, INK)
	draw_line(Vector2(lx, s.position.y + 205.0), Vector2(s.end.x - 40.0, s.position.y + 205.0),
		Color(INK.r, INK.g, INK.b, 0.15), 2.0)
	draw_string(font, Vector2(lx, s.position.y + 246.0), "COLORS", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, OPT_INK)
	var sides := [["Left side", "you"], ["Right side", "your opponent"]]
	for side in 2:
		var first: Rect2 = spots["sw%d_0" % side]
		var use_cmd: bool = bool(Settings.commander[side])
		var shown: Color = Settings.side_color(side)
		draw_string(font, Vector2(lx, first.get_center().y + 2.0), String(sides[side][0]), HORIZONTAL_ALIGNMENT_LEFT, -1,
			20, INK)
		draw_string(font, Vector2(lx, first.get_center().y + 24.0), String(sides[side][1]), HORIZONTAL_ALIGNMENT_LEFT, -1,
			15, Color(INK.r, INK.g, INK.b, 0.6))
		# a little flag of the side's colour by its name
		var flag := Rect2(lx + 140.0, first.position.y, 40.0, SWATCH)
		if use_cmd:
			var ks: Array = Arena.ABILITIES
			for j in ks.size():
				draw_rect(Rect2(flag.position + Vector2(flag.size.x * float(j) / float(ks.size()), 0.0),
					Vector2(flag.size.x / float(ks.size()), flag.size.y)), Arena.commander_color(String(ks[j])), true)
		else:
			draw_rect(flag, shown, true)
		draw_rect(flag, INK, false, 2.0)
		for i in Settings.PALETTE.size():
			var r: Rect2 = spots["sw%d_%d" % [side, i]]
			var c: Color = Settings.PALETTE[i]
			var picked: bool = not use_cmd and shown.is_equal_approx(c)
			var taken: bool = Settings.side_color(1 - side).is_equal_approx(c) and not bool(Settings.commander[1 - side])
			var rr: Rect2 = r.grow(2.0) if opt_hover == "sw%d_%d" % [side, i] else r
			draw_rect(rr, c if not use_cmd else c.lerp(Color(1, 1, 1), 0.55), true)
			draw_rect(rr, Color(INK.r, INK.g, INK.b, 0.5), false, 1.5)
			if picked:
				draw_rect(r.grow(5.0), INK, false, 3.0)
			elif taken:
				# the other side's: a small dot (picking it swaps the two)
				draw_circle(r.get_center(), 4.0, Color(1, 1, 1, 0.9))
		var chip: Rect2 = spots["cmd%d" % side]
		var csb := StyleBoxFlat.new()
		csb.bg_color = OPT_INK if use_cmd else Color(1, 1, 1)
		csb.border_color = OPT_INK
		csb.set_border_width_all(3 if opt_hover == "cmd%d" % side else 2)
		csb.set_corner_radius_all(20)
		draw_style_box(csb, chip)
		var box := Rect2(chip.position + Vector2(14.0, 11.0), Vector2(18.0, 18.0))
		draw_rect(box, Color(1, 1, 1), true)
		draw_rect(box, INK, false, 2.0)
		if use_cmd:
			draw_polyline(PackedVector2Array([box.position + Vector2(3.0, 9.0), box.position + Vector2(8.0, 14.0),
				box.position + Vector2(16.0, 3.0)]), OPT_INK, 3.0, true)
		draw_string(font, Vector2(chip.position.x + 42.0, chip.get_center().y + 7.0), "Commander's color",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1) if use_cmd else INK)
		# the four commanders' colours, so the choice is not a surprise
		var ks2: Array = Arena.ABILITIES
		var dx: float = chip.end.x + 24.0
		for j in ks2.size():
			var dc := Vector2(dx + 26.0 * float(j), chip.get_center().y)
			draw_circle(dc, 9.0, Arena.commander_color(String(ks2[j])))
			draw_arc(dc, 9.0, 0.0, TAU, 16, INK, 1.5, true)
		draw_string(font, Vector2(dx + 26.0 * float(ks2.size()) + 4.0, chip.get_center().y + 6.0),
			"(whichever commander the side draws)", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(INK.r, INK.g, INK.b, 0.6))
	draw_string(font, Vector2(0.0, s.end.y - 22.0), "changes are saved straight away  ·  Esc to go back",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(INK.r, INK.g, INK.b, 0.55))


func _draw_chip(r: Rect2, label: String, ink: Color, hot: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.95) if not hot else ink.lerp(Color(1, 1, 1), 0.82)
	sb.border_color = ink
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(6)
	draw_style_box(sb, r)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(r.position.x, r.get_center().y + 8.0), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, ink)


# ----------------------------------------------------------------- collection

## Every card's full face, description included, straight on the graph paper
## (no backing). A face only carries its description at COLLECTION_CARD_W px
## or wider, so the columns are as many as fit at that width (5 at 1600 px).
const COLLECTION_CARD_W := 270.0


func _open_collection() -> void:
	hover = -1
	collection = DDCardGrid.new()
	collection.name = "Collection"
	collection.full = true
	collection.backing = false
	collection.aspect = 1.4
	collection.position = Vector2(40.0, 92.0)
	collection.size = Vector2(size.x - 80.0, size.y - 92.0)
	var room: float = collection.size.x - DDCardGrid.PAD * 2.0 + DDCardGrid.GAP
	collection.cols = maxi(1, int(floorf(room / (COLLECTION_CARD_W + DDCardGrid.GAP))))
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
	if options_open:
		_draw_options()
		return
	# quadrants, resting ones first, then the axes: the thick axis lines always sit
	# over the quadrant edges, even while a button is lifting or settling
	var order: Array = [0, 1, 2, 3]
	order.sort_custom(func(a, b): return float(lift[a]) < float(lift[b]))
	for i in order:
		_draw_quadrant(i)
	_draw_axes()
	_draw_title_circle()
	_draw_exit_sign(exit_rect(), exit_hover)


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
	# lifted: up off the paper and away from both axes. The inner corner (the one
	# at the origin) moves out diagonally and the quadrant grows outward from it,
	# so its two inner edges both pull clear of the axes; growing about its middle
	# would push them back in, since most of a quadrant is off screen.
	var away := Vector2(-1.0 if i % 2 == 0 else 1.0, -1.0 if i < 2 else 1.0)
	var s: float = 1.0 + GROW * l
	var inner := Vector2(r.end.x if i % 2 == 0 else r.position.x, r.end.y if i < 2 else r.position.y)
	inner += away * LIFT_PX * l
	var far: Vector2 = inner + away * r.size * s
	var drawn := Rect2(Vector2(minf(inner.x, far.x), minf(inner.y, far.y)), r.size * s)
	if l > 0.02:
		# its shadow stays down on the paper, showing in the gap it left
		var shadow := drawn
		shadow.position += -away * LIFT_PX * 0.55 * l + Vector2(6.0, 9.0) * l
		draw_rect(shadow, Color(0.1, 0.06, 0.16, 0.26 * l), true)
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
	for t in [[left, right, axis_x, Vector2(0, 1)], [top, bottom, axis_y, Vector2(1, 0)]]:
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
	var word := axis_x.darkened(0.15)
	draw_string(font, Vector2(c.x - CIRCLE_R, c.y - 7.0), "DRAFT", HORIZONTAL_ALIGNMENT_CENTER, CIRCLE_R * 2.0, 62, word)
	_draw_quadrint(font, Vector2(c.x, c.y + 55.0), word)
	draw_line(c + Vector2(-98.0, 4.0), c + Vector2(98.0, 4.0), axis_y, 3.5, true)


## QUADRINT centred on `at` (x centre, text baseline), its I a narrow warning
## sign (DDArt.warning_glyph) set as a letter: apex level with the cap tops,
## crossbar resting on the baseline, legs running on below it as far as the
## Q's tail. Lines in the word's colour, filled with the y axis colour.
## CAP / DESC are the fallback font's cap height and Q tail, as fractions of
## the font size (measured: 29 px and 7 px at size 40).
const CAP := 0.725
const DESC := 0.175


func _draw_quadrint(font: Font, at: Vector2, col: Color) -> void:
	const SIZE := 48
	var k: float = SIZE / 40.0  # the pixel nudges below were measured at 40
	var spread := 0.46
	var stroke := 0.11
	var mark := 0.85
	var cap: float = CAP * SIZE
	# apex top edge to crossbar bottom edge is the cap height: 0.8 h between the
	# two line centres, plus half a stroke at each end
	var h: float = cap / (0.8 + stroke)
	var t: float = stroke * h
	var cy: float = at.y - cap + t * 0.5 + 0.5 * h
	var foot: float = (at.y + DESC * SIZE - t * 0.5 - cy) / h
	# laid out by its width on the baseline; the feet splay under the neighbours
	var half: float = 0.8 * spread * h + t * 0.5
	var gap := 2.0 * k
	var w0: float = font.get_string_size("QUADR", HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	var w1: float = font.get_string_size("NT", HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	# R ends 1 px short of its advance and N starts 4 px into its own: take those
	# side bearings back so the gaps either side look like the word's own
	var tuck_r := 1.0 * k
	var tuck_n := 3.0 * k
	var total: float = w0 - tuck_r + gap + half * 2.0 + gap + w1 - tuck_n
	var x: float = at.x - total * 0.5
	draw_string(font, Vector2(x, at.y), "QUADR", HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, col)
	x += w0 - tuck_r + gap + half
	DDArt.warning_glyph(self, Vector2(x, cy), h, axis_y, col, 0.0, spread, stroke, mark, foot)
	x += half + gap - tuck_n
	draw_string(font, Vector2(x, at.y), "NT", HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, col)


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
			# a slider over a slowly turning gear
			var gc: Vector2 = c + Vector2(-r * 0.2, r * 0.05)
			var teeth := 8
			var gear := PackedVector2Array()
			var spin: float = clock * 0.4
			for k in teeth * 4:
				var a: float = spin + TAU * float(k) / float(teeth * 4)
				var outer: bool = (k % 4) == 1 or (k % 4) == 2
				gear.append(gc + Vector2.from_angle(a) * r * (0.5 if outer else 0.38))
			draw_colored_polygon(gear, paper)
			var ring := gear.duplicate()
			ring.append(gear[0])
			draw_polyline(ring, ink, 3.0, true)
			draw_circle(gc, r * 0.15, ink)
			var sy: float = c.y + r * 0.5
			draw_line(Vector2(c.x - r * 0.1, sy), Vector2(c.x + r * 0.85, sy), ink, 5.0, true)
			draw_circle(Vector2(c.x + r * 0.5, sy), r * 0.12, paper)
			draw_arc(Vector2(c.x + r * 0.5, sy), r * 0.12, 0.0, TAU, 16, ink, 3.0, true)


func _card_shape(c: Vector2, sz: Vector2, ang: float, fill: Color, ink: Color) -> void:
	var hx := Vector2(sz.x * 0.5, 0.0).rotated(ang)
	var hy := Vector2(0.0, sz.y * 0.5).rotated(ang)
	var pts := PackedVector2Array([c - hx - hy, c + hx - hy, c + hx + hy, c - hx + hy])
	draw_colored_polygon(pts, fill)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, ink, 3.0, true)
	draw_line(c - hx * 0.6 - hy * 0.55, c + hx * 0.6 - hy * 0.55, Color(ink.r, ink.g, ink.b, 0.6), 2.0, true)
