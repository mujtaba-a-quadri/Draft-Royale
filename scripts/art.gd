class_name DDArt
extends RefCounted

## Flat, cartoonish, outlined art. Every creature/tower is drawn procedurally so
## the project stays asset-free while keeping a consistent Adventure Time /
## Hollow Knight silhouette language.

const OUTLINE := Color(0.11, 0.09, 0.14)
const OUTLINE_W := 2.4

const INK := Color(0.16, 0.13, 0.2)

## Outline ink is draw state: the creature and tower entry points set it to the
## drawing team's colour for the length of one draw and restore it, so chrome
## (coins, card faces, UI) keeps the neutral outline.
static var ink := OUTLINE


static func circle(ci: CanvasItem, c: Vector2, r: float, fill: Color, w: float = OUTLINE_W) -> void:
	ci.draw_circle(c, r, fill)
	if w > 0.0:
		ci.draw_arc(c, r, 0.0, TAU, 48, ink, w, true)


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color, w: float = OUTLINE_W) -> void:
	var pts := PackedVector2Array()
	for i in 32:
		var a := TAU * float(i) / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	poly(ci, pts, fill, w)


static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, w: float = OUTLINE_W) -> void:
	ci.draw_colored_polygon(pts, fill)
	if w > 0.0:
		var loop := pts.duplicate()
		loop.append(pts[0])
		ci.draw_polyline(loop, ink, w, true)


static func rect_outlined(ci: CanvasItem, r: Rect2, fill: Color, w: float = OUTLINE_W) -> void:
	ci.draw_rect(r, fill, true)
	if w > 0.0:
		ci.draw_rect(r, ink, false, w)


static func coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	circle(ci, c, r, Color(0.98, 0.79, 0.26))
	ci.draw_arc(c, r * 0.55, 0.0, TAU, 24, Color(0.85, 0.6, 0.15), 1.6, true)


## r is the drawing radius in pixels; t is a shared animation clock.
static func creature(ci: CanvasItem, kind: String, r: float, facing: float, t: float, hurt: float = 0.0, phase2: bool = false, ink_col: Color = OUTLINE, fly: bool = false) -> void:
	ink = ink_col
	match kind:
		"snowman":
			_snowman(ci, r, t)
		"ovomachine":
			_ovomachine(ci, r, t)
		"snowball":
			_snowball(ci, r, t)
		"slate":
			_slate(ci, r, t, facing)
		"alchemist":
			_alchemist(ci, r, t, facing, phase2)
		"idol":
			_idol(ci, r, t)
		"hero":
			_hero(ci, r, t, facing)
		"fu":
			_fu(ci, r, t, facing)
		"zombie":
			_zombie(ci, r, t, facing)
		"hedgehog":
			hedgehog(ci, r, facing, t, false, ink_col)
		"chicken":
			_chicken(ci, r, t, facing, fly)
		"penny":
			_penny(ci, r, t, facing)
		"pen":
			_pen(ci, r, t, facing)
		"aphid":
			_aphid(ci, r, t, facing)
		"lizard":
			_lizard(ci, r, t, facing)
		"warren":
			_warren(ci, r, t)
		"boulder":
			_boulder(ci, r, t)
		"fireball":
			_fireball(ci, r, t)
		"firebolt":
			_firebolt(ci, r, t)
		_:
			circle(ci, Vector2.ZERO, r, Color.MAGENTA)
	if hurt > 0.0:
		ci.draw_circle(Vector2.ZERO, r * 1.15, Color(1, 1, 1, clampf(hurt, 0.0, 0.55)))
	ink = OUTLINE


## In-Ovo Machine: a squat industrial hatchery. Steel body, riveted plates, a
## chimney leaking smoke and an egg glowing in the inspection window.
## Snowball: a packed ball of snow for the card and the deploy ghost.
static func _snowball(ci: CanvasItem, r: float, t: float) -> void:
	var spin := t * 1.6
	ci.draw_circle(Vector2.ZERO, r, Color(0.9, 0.95, 1.0))
	ci.draw_circle(Vector2(-r * 0.26, -r * 0.28), r * 0.5, Color(1.0, 1.0, 1.0, 0.9))
	ci.draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, ink, r * 0.09, true)
	for i in 5:
		var a := spin + float(i) * TAU / 5.0
		ci.draw_circle(Vector2(cos(a), sin(a)) * r * 0.58, r * 0.12, Color(0.66, 0.82, 1.0, 0.9))
	for i in 3:
		var b := -spin + float(i) * 2.1
		ci.draw_line(Vector2(cos(b) * r * 0.72, sin(b) * r * 0.72),
			Vector2(cos(b + 0.5) * r * 0.94, sin(b + 0.5) * r * 0.94), Color(0.55, 0.72, 0.95, 0.6), r * 0.07, true)


static func _ovomachine(ci: CanvasItem, r: float, t: float) -> void:
	var steel := Color(0.53, 0.57, 0.62)
	var steel_dark := Color(0.33, 0.36, 0.42)
	var rust := Color(0.64, 0.44, 0.3)
	var glow := Color(0.99, 0.74, 0.28)
	var pulse := 0.5 + 0.5 * sin(t * 2.4)
	for i in 4:
		var f := fmod(t * 0.32 + float(i) * 0.25, 1.0)
		var sx := -r * 0.6 - f * r * 0.55 + sin(t * 1.7 + float(i) * 1.1) * r * 0.12
		var sy := -r * 1.25 - f * r * 1.15
		ci.draw_circle(Vector2(sx, sy), r * (0.16 + f * 0.36), Color(0.84, 0.86, 0.9, 0.48 * (1.0 - f)))
	ci.draw_rect(Rect2(-r * 1.0, r * 0.62, r * 2.0, r * 0.24), steel_dark)
	ci.draw_rect(Rect2(-r * 1.0, r * 0.62, r * 2.0, r * 0.24), ink, false, 1.8)
	ci.draw_rect(Rect2(-r * 0.94, -r * 0.82, r * 1.88, r * 1.46), steel)
	ci.draw_rect(Rect2(-r * 0.94, -r * 0.82, r * 1.88, r * 1.46), ink, false, 2.4)
	ci.draw_rect(Rect2(-r * 1.04, -r * 1.02, r * 2.08, r * 0.26), steel_dark)
	ci.draw_rect(Rect2(-r * 1.04, -r * 1.02, r * 2.08, r * 0.26), ink, false, 2.0)
	ci.draw_rect(Rect2(-r * 0.82, -r * 1.36, r * 0.36, r * 0.4), rust)
	ci.draw_rect(Rect2(-r * 0.82, -r * 1.36, r * 0.36, r * 0.4), ink, false, 2.0)
	ci.draw_rect(Rect2(-r * 0.88, -r * 1.42, r * 0.48, r * 0.12), steel_dark)
	ci.draw_circle(Vector2(r * 0.16, -r * 0.16), r * 0.44, Color(0.13, 0.14, 0.17))
	ellipse(ci, Vector2(r * 0.16, -r * 0.12), r * 0.21, r * 0.27,
		Color(0.99, 0.87, 0.55).lerp(glow, pulse), 0.0)
	ci.draw_arc(Vector2(r * 0.16, -r * 0.16), r * 0.44, 0.0, TAU, 24, ink, 2.2, true)
	ci.draw_arc(Vector2(r * 0.16, -r * 0.16), r * 0.44, -0.7, 0.9, 12,
		Color(glow.r, glow.g, glow.b, 0.35), 2.0, true)
	ci.draw_rect(Rect2(r * 0.5, r * 0.12, r * 0.42, r * 0.48), Color(0.16, 0.15, 0.19))
	ci.draw_rect(Rect2(-r * 0.92, r * 0.12, r * 0.42, r * 0.48), Color(0.16, 0.15, 0.19))
	for i in 4:
		var y := r * 0.16 + float(i) * r * 0.11
		ci.draw_line(Vector2(-r * 0.9, y), Vector2(-r * 0.52, y), Color(0.4, 0.42, 0.46), 1.4, true)
		ci.draw_line(Vector2(r * 0.52, y), Vector2(r * 0.9, y), Color(0.4, 0.42, 0.46), 1.4, true)
	for i in 6:
		var x := -r * 0.95 + float(i) * r * 0.32
		ci.draw_line(Vector2(x, r * 0.64), Vector2(x + r * 0.15, r * 0.86), Color(0.96, 0.79, 0.26), r * 0.11, true)
	for i in 4:
		var rx := -r * 0.8 + float(i) * r * 0.52
		ci.draw_circle(Vector2(rx, -r * 0.68), r * 0.06, steel_dark)
		ci.draw_circle(Vector2(rx, r * 0.5), r * 0.06, steel_dark)


static func _snowman(ci: CanvasItem, r: float, t: float) -> void:
	var bob := sin(t * 2.0) * r * 0.05
	var body := Color(0.93, 0.97, 1.0)
	var shade := Color(0.72, 0.84, 0.95)
	# arms — unit detail, drawn in the neutral ink so only outlines take the team colour
	ci.draw_line(Vector2(-r * 0.55, -r * 0.1), Vector2(-r * 1.35, -r * 0.65), OUTLINE, 2.0, true)
	ci.draw_line(Vector2(r * 0.55, -r * 0.1), Vector2(r * 1.35, -r * 0.5), OUTLINE, 2.0, true)
	ellipse(ci, Vector2(0, r * 0.45 + bob), r * 0.78, r * 0.72, body)
	circle(ci, Vector2(0, -r * 0.55 + bob), r * 0.52, body)
	# coal buttons
	for i in 3:
		ci.draw_circle(Vector2(0, r * (0.15 + float(i) * 0.28) + bob), r * 0.07, INK)
	# face
	ci.draw_circle(Vector2(-r * 0.18, -r * 0.62 + bob), r * 0.07, INK)
	ci.draw_circle(Vector2(r * 0.18, -r * 0.62 + bob), r * 0.07, INK)
	poly(ci, PackedVector2Array([
		Vector2(0, -r * 0.45 + bob),
		Vector2(r * 0.62, -r * 0.38 + bob),
		Vector2(0, -r * 0.3 + bob)]), Color(0.98, 0.55, 0.18), 1.6)
	ci.draw_circle(Vector2(-r * 0.35, -r * 0.25 + bob), r * 0.16, Color(shade, 0.6))


static func _slate(ci: CanvasItem, r: float, t: float, facing: float) -> void:
	var wob := sin(t * 3.0) * r * 0.03
	var base := Color(0.62, 0.44, 0.86)
	var ring1 := Color(0.85, 0.68, 0.98)
	var ring2 := Color(0.52, 0.3, 0.74)
	ellipse(ci, Vector2(0, wob), r * 0.98, r * 0.9, base)
	ci.draw_arc(Vector2(0, wob), r * 0.74, 0.0, TAU, 40, ring1, r * 0.16, true)
	ci.draw_arc(Vector2(0, wob), r * 0.52, 0.0, TAU, 36, ring2, r * 0.14, true)
	ci.draw_arc(Vector2(0, wob), r * 0.3, 0.0, TAU, 28, ring1, r * 0.1, true)
	# sleepy candy face
	ci.draw_circle(Vector2(-r * 0.26 * facing, -r * 0.12 + wob), r * 0.09, INK)
	ci.draw_circle(Vector2(r * 0.1 * facing, -r * 0.12 + wob), r * 0.09, INK)
	ci.draw_arc(Vector2(r * 0.02 * facing, r * 0.12 + wob), r * 0.18, 0.2, PI - 0.2, 16, INK, 1.8, true)
	ci.draw_circle(Vector2(-r * 0.5, -r * 0.45 + wob), r * 0.14, Color(1, 1, 1, 0.55))


static func _alchemist(ci: CanvasItem, r: float, t: float, facing: float, phase2: bool) -> void:
	var bob := sin(t * 5.0) * r * 0.06
	var skin := Color(0.45, 0.78, 0.36) if not phase2 else Color(0.62, 0.86, 0.34)
	var dark := Color(0.24, 0.52, 0.24) if not phase2 else Color(0.3, 0.62, 0.2)
	# ears
	poly(ci, PackedVector2Array([
		Vector2(-r * 0.8, -r * 0.45 + bob), Vector2(-r * 1.5, -r * 0.85 + bob), Vector2(-r * 0.75, -r * 0.9 + bob)]), skin, 1.8)
	poly(ci, PackedVector2Array([
		Vector2(r * 0.8, -r * 0.5 + bob), Vector2(r * 1.5, -r * 0.95 + bob), Vector2(r * 0.72, -r * 0.95 + bob)]), skin, 1.8)
	# body
	ellipse(ci, Vector2(0, r * 0.3 + bob), r * 0.62, r * 0.72, dark)
	# head
	circle(ci, Vector2(0, -r * 0.35 + bob), r * 0.55, skin)
	# long nose
	poly(ci, PackedVector2Array([
		Vector2(r * 0.1 * facing, -r * 0.4 + bob),
		Vector2(r * 1.05 * facing, -r * 0.22 + bob),
		Vector2(r * 0.12 * facing, -r * 0.12 + bob)]), Color(0.3, 0.62, 0.26), 1.6)
	# eyes
	var eye := Color(0.9, 0.15, 0.15) if phase2 else INK
	ci.draw_circle(Vector2(-r * 0.22, -r * 0.5 + bob), r * 0.1, eye)
	ci.draw_circle(Vector2(r * 0.18, -r * 0.52 + bob), r * 0.1, eye)
	# potion flask in hand
	var fx := r * 0.72 * facing
	circle(ci, Vector2(fx, r * 0.18 + bob), r * 0.22, Color(0.35, 0.85, 0.75), 1.8)
	ci.draw_line(Vector2(fx, -r * 0.02 + bob), Vector2(fx, -r * 0.16 + bob), OUTLINE, 2.0, true)


static func _idol(ci: CanvasItem, r: float, t: float) -> void:
	var glow := 0.55 + sin(t * 3.4) * 0.12
	var gold := Color(0.98, 0.78, 0.3)
	var dark := Color(0.72, 0.52, 0.12)
	ci.draw_circle(Vector2(0, 0), r * 1.45, Color(0.98, 0.85, 0.4, 0.12 * glow))
	poly(ci, PackedVector2Array([
		Vector2(-r * 0.55, r * 0.95), Vector2(r * 0.55, r * 0.95),
		Vector2(r * 0.85, -r * 0.25), Vector2(-r * 0.85, -r * 0.25)]), gold)
	poly(ci, PackedVector2Array([
		Vector2(-r * 0.55, r * 0.95), Vector2(r * 0.55, r * 0.95),
		Vector2(r * 0.42, r * 0.4), Vector2(-r * 0.42, r * 0.4)]), dark, 1.6)
	circle(ci, Vector2(0, -r * 0.65), r * 0.5, gold)
	ci.draw_circle(Vector2(-r * 0.18, -r * 0.7), r * 0.1, Color(0.2, 0.55, 0.9))
	ci.draw_circle(Vector2(r * 0.18, -r * 0.7), r * 0.1, Color(0.2, 0.55, 0.9))
	ci.draw_arc(Vector2(0, -r * 0.62), r * 0.3, PI, TAU, 16, Color(0.14, 0.4, 0.7), 1.8, true)
	# halo crown
	ci.draw_arc(Vector2(0, -r * 1.05), r * 0.45, 0.0, TAU, 24, Color(1, 0.92, 0.55), r * 0.09, true)


static func _boulder(ci: CanvasItem, r: float, t: float) -> void:
	var rock := Color(0.55, 0.55, 0.6)
	circle(ci, Vector2.ZERO, r, rock)
	for i in 4:
		var a := t * 6.0 + float(i) * 1.9
		ci.draw_circle(Vector2(cos(a), sin(a)) * r * 0.45, r * 0.13, Color(0.42, 0.42, 0.48))
	ci.draw_arc(Vector2.ZERO, r * 0.78, -2.2, -0.6, 18, Color(0.72, 0.72, 0.78), r * 0.12, true)


static func _fireball(ci: CanvasItem, r: float, t: float) -> void:
	var pulse := 1.0 + sin(t * 18.0) * 0.08
	ci.draw_circle(Vector2.ZERO, r * 1.5 * pulse, Color(1.0, 0.45, 0.1, 0.22))
	circle(ci, Vector2.ZERO, r * pulse, Color(1.0, 0.55, 0.12))
	ci.draw_circle(Vector2.ZERO, r * 0.6 * pulse, Color(1.0, 0.85, 0.35))
	ci.draw_circle(Vector2(-r * 0.25, -r * 0.25), r * 0.16, Color(1, 1, 0.9))


static func _firebolt(ci: CanvasItem, r: float, t: float) -> void:
	var pulse := 1.0 + sin(t * 26.0) * 0.12
	ci.draw_circle(Vector2.ZERO, r * 1.3 * pulse, Color(1.0, 0.7, 0.2, 0.2))
	var pts := PackedVector2Array([
		Vector2(-r * 0.9, 0), Vector2(0, -r * 0.55), Vector2(r * 0.9, 0), Vector2(0, r * 0.55)])
	poly(ci, pts, Color(1.0, 0.78, 0.28), 1.8)
	ci.draw_circle(Vector2.ZERO, r * 0.28, Color(1, 1, 0.92))


static func _hero(ci: CanvasItem, r: float, t: float, facing: float) -> void:
	var bob := sin(t * 4.0) * r * 0.05
	var steel := Color(0.74, 0.77, 0.86)
	var dark := Color(0.3, 0.32, 0.44)
	var cape := Color(0.85, 0.3, 0.32)
	poly(ci, PackedVector2Array([
		Vector2(-r * 0.45 * facing, -r * 0.35 + bob), Vector2(-r * 1.2 * facing, r * 0.75 + bob),
		Vector2(-r * 0.15 * facing, r * 0.5 + bob)]), cape, 1.8)
	ellipse(ci, Vector2(0, r * 0.2 + bob), r * 0.5, r * 0.6, steel)
	circle(ci, Vector2(-r * 0.62 * facing, r * 0.16 + bob), r * 0.3, Color(0.88, 0.72, 0.34))
	ci.draw_line(Vector2(r * 0.45 * facing, r * 0.5 + bob), Vector2(r * 0.82 * facing, -r * 0.6 + bob), Color(0.93, 0.95, 1.0), 3.0, true)
	circle(ci, Vector2(0, -r * 0.45 + bob), r * 0.42, steel)
	ci.draw_rect(Rect2(-r * 0.28, -r * 0.5 + bob, r * 0.56, r * 0.13), dark, true)
	poly(ci, PackedVector2Array([
		Vector2(0, -r * 0.85 + bob), Vector2(r * 0.28 * facing, -r * 1.2 + bob),
		Vector2(-r * 0.06, -r * 1.02 + bob)]), cape, 1.4)


static func dragon(ci: CanvasItem, r: float, facing: float, t: float, flying: bool, hurt: float = 0.0, ink_col: Color = OUTLINE) -> void:
	ink = ink_col
	var f := facing if absf(facing) > 0.01 else 1.0
	var skin := Color(0.3, 0.66, 0.38)
	var skin_dark := Color(0.16, 0.42, 0.24)
	var belly := Color(0.74, 0.54, 0.4)
	var horn := Color(0.88, 0.8, 0.56)
	var wing := Color(0.64, 0.17, 0.28)
	var wing_dark := Color(0.4, 0.09, 0.18)
	var glow := Color(0.66, 1.0, 0.3)
	var flap := sin(t * 5.0) * 0.18
	# --- wings: strapped down when chained, thrown wide in the air -----------
	if flying:
		for s in [-1.0, 1.0]:
			var root := Vector2(s * r * 0.35, -r * 0.5)
			var tip := Vector2(s * r * (1.8 + 0.25 * flap), -r * (1.15 + flap))
			poly(ci, PackedVector2Array([root, tip, Vector2(s * r * 1.25, -r * 0.1), Vector2(s * r * 0.6, -r * 0.2)]),
				wing, 2.0)
			ci.draw_line(root, tip, wing_dark, 2.5, true)
			ci.draw_line(tip, Vector2(s * r * 1.25, -r * 0.1), wing_dark, 2.0, true)
	else:
		for s in [-1.0, 1.0]:
			# a folded wing standing off the shoulder: tall, narrow, scalloped edge
			poly(ci, PackedVector2Array([
				Vector2(s * r * 0.28, -r * 0.78), Vector2(s * r * 1.05, -r * 0.62),
				Vector2(s * r * 1.32, -r * 0.05), Vector2(s * r * 1.02, r * 0.28),
				Vector2(s * r * 0.62, r * 0.05), Vector2(s * r * 0.42, -r * 0.3)]), wing, 2.0)
			ci.draw_line(Vector2(s * r * 0.28, -r * 0.78), Vector2(s * r * 1.32, -r * 0.05), wing_dark, 2.2)
	# --- tail and legs ------------------------------------------------------
	var tail := PackedVector2Array()
	for i in 6:
		var q := float(i) / 5.0
		tail.append(Vector2(-r * (0.55 + q * 1.35) * f,
			r * (0.55 - 0.28 * sin(q * PI)) + r * 0.12 * sin(t * 3.0 + q * 2.2)))
	ci.draw_polyline(tail, skin_dark, r * 0.42, true)
	ci.draw_circle(tail[tail.size() - 1], r * 0.2, skin_dark)
	ci.draw_line(Vector2(-r * 0.34, r * 0.65), Vector2(-r * 0.46, r * 1.2), skin_dark, r * 0.36, true)
	ci.draw_line(Vector2(r * 0.3, r * 0.65), Vector2(r * 0.42, r * 1.2), skin_dark, r * 0.36, true)
	# --- torso, belly plates, back ridge ------------------------------------
	ellipse(ci, Vector2(0, r * 0.05), r * 1.02, r * 0.86, skin)
	ellipse(ci, Vector2(r * 0.14 * f, r * 0.34), r * 0.6, r * 0.48, belly, 0.0)
	for i in 3:
		ci.draw_line(Vector2(r * (-0.32 + 0.04 * float(i)) * f, r * (0.16 + float(i) * 0.2)),
			Vector2(r * (0.42 - 0.02 * float(i)) * f, r * (0.2 + float(i) * 0.2)),
			Color(0.5, 0.34, 0.24, 0.75), 1.6, true)
	for i in 4:
		var sx := -r * (0.12 + float(i) * 0.22) * f
		var sy := -r * (0.72 - float(i) * 0.13)
		poly(ci, PackedVector2Array([Vector2(sx, sy), Vector2(sx - r * 0.08 * f, sy - r * 0.32),
			Vector2(sx + r * 0.17 * f, sy - r * 0.02)]), horn, 1.3)
	# --- arms: shoulders and fists. never chained ---------------------------
	for s in [1.0, -1.0]:
		var shoulder := Vector2(s * r * 0.74 * f, -r * 0.28)
		ci.draw_line(shoulder, shoulder + Vector2(s * r * 0.26 * f, r * 0.6), skin, r * 0.46, true)
		var fist := shoulder + Vector2(s * r * 0.3 * f, r * 0.74)
		ci.draw_circle(fist, r * 0.36, skin)
		ci.draw_arc(fist, r * 0.36, 0.0, TAU, 18, ink, 2.0, true)
		for k in 3:
			ci.draw_line(fist + Vector2(s * r * 0.12 * f, r * 0.16), fist + Vector2(s * r * (0.26 + 0.09 * float(k)) * f, r * 0.46),
				horn, 2.2, true)
	# --- head: horns, glowing eyes, burning maw -----------------------------
	var head := Vector2(r * 0.34 * f, -r * 0.82)
	ellipse(ci, head, r * 0.62, r * 0.54, skin)
	ci.draw_line(head + Vector2(-r * 0.4 * f, -r * 0.18), head + Vector2(r * 0.44 * f, -r * 0.24), skin_dark, r * 0.15, true)
	ci.draw_circle(head + Vector2(r * 0.02 * f, -r * 0.02), r * 0.11, Color(0.1, 0.26, 0.08))
	ci.draw_circle(head + Vector2(r * 0.02 * f, -r * 0.02), r * 0.075, glow)
	ci.draw_circle(head + Vector2(r * 0.32 * f, -r * 0.02), r * 0.085, glow)
	for s in [-1.0, 1.0]:
		var base_pt := head + Vector2(s * r * 0.32, -r * 0.28)
		var curve := PackedVector2Array()
		for i in 5:
			var q := float(i) / 4.0
			curve.append(base_pt + Vector2(s * r * (0.06 + 0.72 * q * q), -r * (0.5 * q + 0.55 * q * q)))
		ci.draw_polyline(curve, horn, r * 0.24, true)
		ci.draw_polyline(curve, Color(1, 1, 1, 0.3), r * 0.09, true)
	var maw := head + Vector2(r * 0.44 * f, r * 0.28)
	ellipse(ci, maw, r * 0.26, r * 0.16, Color(0.09, 0.2, 0.07), 0.0)
	ci.draw_circle(maw + Vector2(r * 0.05 * f, 0.0), r * 0.11, glow)
	for k in 3:
		ci.draw_line(maw + Vector2(r * (-0.15 + 0.13 * float(k)) * f, -r * 0.1),
			maw + Vector2(r * (-0.15 + 0.13 * float(k)) * f, r * 0.05), Color(0.95, 0.95, 0.85), 1.8, true)
	# --- chains: the wings only --------------------------------------------
	var steel := Color(0.66, 0.68, 0.74)
	var steel_hi := Color(0.86, 0.88, 0.93)
	if flying:
		# broken stubs swinging from each wing joint
		for s in [-1.0, 1.0]:
			var joint := Vector2(s * r * 0.45, -r * 0.5)
			var sway := sin(t * 4.0 + s) * r * 0.08
			ci.draw_line(joint, joint + Vector2(s * r * 0.22 + sway, r * 0.52), steel, 3.0, true)
			for k in 2:
				ci.draw_arc(joint + Vector2(s * r * (0.14 + 0.09 * float(k)) + sway, r * (0.3 + 0.12 * float(k))),
					r * 0.1, 0.0, TAU, 10, steel_hi, 1.8, true)
	else:
		# chains strapped across both folded wings
		for s in [-1.0, 1.0]:
			for k in 2:
				var y := -r * 0.5 + float(k) * r * 0.34
				ci.draw_line(Vector2(s * r * 0.3, y), Vector2(s * r * 1.24, y + r * 0.28), steel, 3.0, true)
				for j in 3:
					var q := float(j) / 2.0
					ci.draw_arc(Vector2(s * r * (0.45 + 0.5 * q), y + r * (0.06 + 0.14 * q)), r * 0.11,
						0.0, TAU, 12, steel_hi, 1.8, true)
	if hurt > 0.0:
		ci.draw_circle(Vector2.ZERO, r * 1.15, Color(1, 1, 1, clampf(hurt, 0.0, 0.5)))
	ink = OUTLINE


static func _fu(ci: CanvasItem, r: float, t: float, facing: float) -> void:
	var bob := sin(t * 5.0) * r * 0.06
	var cloth := Color(0.36, 0.55, 0.86)
	var skin := Color(0.87, 0.72, 0.52)
	var straw := Color(0.93, 0.81, 0.5)
	# legs — unit detail, not an outline
	ci.draw_line(Vector2(-r * 0.28, r * 0.6 + bob), Vector2(-r * 0.42, r * 1.05 + bob), OUTLINE, 3.0, true)
	ci.draw_line(Vector2(r * 0.26, r * 0.6 + bob), Vector2(r * 0.4, r * 1.05 + bob), OUTLINE, 3.0, true)
	# poncho
	poly(ci, PackedVector2Array([
		Vector2(-r * 0.72, r * 0.75 + bob), Vector2(r * 0.72, r * 0.75 + bob),
		Vector2(r * 0.42, -r * 0.25 + bob), Vector2(-r * 0.42, -r * 0.25 + bob)]), cloth)
	# head
	circle(ci, Vector2(0, -r * 0.5 + bob), r * 0.38, skin)
	# eyes
	ci.draw_circle(Vector2(-r * 0.14, -r * 0.55 + bob), r * 0.06, INK)
	ci.draw_circle(Vector2(r * 0.14, -r * 0.55 + bob), r * 0.06, INK)
	# conical hat
	poly(ci, PackedVector2Array([
		Vector2(-r * 0.62, -r * 0.72 + bob), Vector2(r * 0.62, -r * 0.72 + bob),
		Vector2(0, -r * 1.35 + bob)]), straw)
	ci.draw_line(Vector2(-r * 0.62, -r * 0.72 + bob), Vector2(r * 0.62, -r * 0.72 + bob), DDArt.ink, 2.0, true)
	# boomerang in hand
	var bx := r * 0.85 * facing
	ci.draw_line(Vector2(bx, r * 0.15 + bob), Vector2(bx + r * 0.42 * facing, -r * 0.12 + bob), Color(0.75, 0.55, 0.28), 3.5, true)
	ci.draw_line(Vector2(bx + r * 0.42 * facing, -r * 0.12 + bob), Vector2(bx + r * 0.3 * facing, -r * 0.5 + bob), Color(0.75, 0.55, 0.28), 3.5, true)


## Commander towers: the furthest-back tower wears a face of its own.
## Blue side reads as a celestial jelly, red side as a spear goblin. Both light
## up when that player's ability is ready.
static func commander(ci: CanvasItem, kind: String, r: float, t: float, ready: bool, team_col: Color, flip: bool = false) -> void:
	if kind == "tentacle":
		_jelly(ci, r, t, ready, team_col, flip)
	else:
		_goblin_commander(ci, r, t, ready, team_col)


static func _jelly(ci: CanvasItem, r: float, t: float, ready: bool, team_col: Color, flip: bool = false) -> void:
	var core := Color(0.55, 0.35, 0.95).lerp(team_col, 0.45 if not ready else 0.75)
	var rim := Color(0.8, 0.55, 1.0) if not ready else Color(0.7, 0.9, 1.0)
	for i in 4:
		ci.draw_circle(Vector2(0, -r * 0.5), r * (0.95 - float(i) * 0.16), Color(core.r, core.g, core.b, 0.13 + float(i) * 0.05))
	ci.draw_circle(Vector2(0, -r * 0.5), r * 0.38, Color(1, 1, 1, 0.85))
	ci.draw_arc(Vector2(0, -r * 0.5), r * 0.7, 0.0, TAU, 28, rim, 2.0, true)
	# crown tendrils
	for i in 7:
		var a := -PI * 0.85 + PI * 0.7 * float(i) / 6.0
		var p := Vector2(cos(a), sin(a)) * r * 0.34 + Vector2(0, -r * 0.72)
		ci.draw_line(Vector2(0, -r * 0.5), p, Color(0.85, 0.6, 1.0, 0.9), 2.0, true)
	# chained tail sweeping behind toward the back of the arena
	var speed := 4.2 if ready else 1.6
	var chain := Color(0.85, 0.45, 1.0) if not ready else Color(0.6, 0.85, 1.0)
	var prev := Vector2(0, r * 0.05)
	for k in 9:
		var f := float(k) / 8.0
		var px := r * 2.6 * f * (-1.0 if flip else 1.0)
		var py := r * 0.35 + sin(t * speed - f * 2.2) * r * 0.55 * f
		var p2 := Vector2(px, py)
		ci.draw_line(prev, p2, Color(chain.r, chain.g, chain.b, 0.55), 3.0, true)
		ci.draw_circle(p2, r * (0.20 - 0.1 * f), Color(chain.r, chain.g, chain.b, 0.85))
		ci.draw_arc(p2, r * (0.20 - 0.1 * f), 0.0, TAU, 12, Color(1, 1, 1, 0.35), 1.2, true)
		prev = p2


static func _goblin_commander(ci: CanvasItem, r: float, t: float, ready: bool, team_col: Color) -> void:
	var skin := Color(0.52, 0.82, 0.34)
	var dark := Color(0.33, 0.58, 0.2)
	# ears
	for s in [-1.0, 1.0]:
		ci.draw_colored_polygon(PackedVector2Array([
			Vector2(s * r * 0.45, -r * 0.1), Vector2(s * r * 1.15, -r * 0.55), Vector2(s * r * 0.5, r * 0.25),
		]), skin.darkened(0.1))
	# head
	ci.draw_circle(Vector2(0, -r * 0.15), r * 0.62, skin)
	ci.draw_arc(Vector2(0, -r * 0.15), r * 0.62, 0.0, TAU, 22, Color(0.13, 0.12, 0.16), 2.2, true)
	# grin
	ci.draw_arc(Vector2(0, r * 0.05), r * 0.34, 0.15 * PI, 0.85 * PI, 14, Color(0.15, 0.1, 0.1), 3.0, true)
	# eyes: red with flames when the ability is up
	var eye := Color(0.1, 0.1, 0.12) if not ready else team_col.lightened(0.15)
	if ready:
		ci.draw_circle(Vector2(0, -r * 0.3), r * 0.5, Color(team_col.r, team_col.g, team_col.b, 0.18))
	for s in [-1.0, 1.0]:
		var e := Vector2(s * r * 0.26, -r * 0.3)
		ci.draw_circle(e, r * 0.13, eye)
		if ready:
			for k in 3:
				var fl := Vector2(e.x + sin(t * 9.0 + float(k)) * r * 0.06, e.y - r * (0.22 + 0.12 * float(k)))
				ci.draw_circle(fl, r * (0.08 - 0.02 * float(k)), Color(team_col.r, team_col.g, team_col.b, 0.8 - 0.2 * float(k)))
	# spear, thrown rather than held as a staff
	var tip := Vector2(r * 0.95, -r * 0.95)
	ci.draw_line(Vector2(-r * 0.15, r * 0.35), tip, Color(0.62, 0.45, 0.28), 3.0, true)
	ci.draw_colored_polygon(PackedVector2Array([
		tip + Vector2(r * 0.26, -r * 0.1), tip + Vector2(-r * 0.02, -r * 0.2), tip + Vector2(-r * 0.02, r * 0.16),
	]), Color(0.85, 0.88, 0.92))
	ci.draw_polyline(PackedVector2Array([
		tip + Vector2(r * 0.26, -r * 0.1), tip + Vector2(-r * 0.02, -r * 0.2),
		tip + Vector2(-r * 0.02, r * 0.16), tip + Vector2(r * 0.26, -r * 0.1),
	]), Color(0.13, 0.12, 0.16), 1.4, true)


## Lizard soldier: small green spear-carrier, crest up, spear levelled.
static func _lizard(ci: CanvasItem, r: float, t: float, facing: float) -> void:
	var dir: float = 1.0 if facing >= 0.0 else -1.0
	var bob := sin(t * 11.0) * r * 0.06
	var skin := Color(0.52, 0.82, 0.42)
	var belly := Color(0.78, 0.92, 0.6)
	# tail
	ci.draw_line(Vector2(-dir * r * 0.6, r * 0.25 + bob), Vector2(-dir * r * 1.25, r * 0.05 + bob), skin.darkened(0.15), r * 0.24, true)
	# body
	ci.draw_circle(Vector2(0, bob), r * 0.62, skin)
	ci.draw_arc(Vector2(0, bob), r * 0.62, 0.0, TAU, 18, ink, 1.8, true)
	ci.draw_circle(Vector2(dir * r * 0.1, r * 0.18 + bob), r * 0.34, belly)
	# head
	var head := Vector2(dir * r * 0.55, -r * 0.35 + bob)
	ci.draw_circle(head, r * 0.34, skin)
	ci.draw_arc(head, r * 0.34, 0.0, TAU, 16, ink, 1.8, true)
	# crest
	ci.draw_colored_polygon(PackedVector2Array([
		head + Vector2(-dir * r * 0.1, -r * 0.3),
		head + Vector2(dir * r * 0.05, -r * 0.75),
		head + Vector2(dir * r * 0.26, -r * 0.22),
	]), Color(0.95, 0.62, 0.3))
	ci.draw_circle(head + Vector2(dir * r * 0.12, -r * 0.05), r * 0.09, Color(0.1, 0.09, 0.12))
	# snout
	ci.draw_colored_polygon(PackedVector2Array([
		head + Vector2(dir * r * 0.28, r * 0.02),
		head + Vector2(dir * r * 0.7, r * 0.14),
		head + Vector2(dir * r * 0.28, r * 0.26),
	]), skin.lightened(0.1))
	# spear
	var tip := Vector2(dir * r * 1.5, -r * 0.45 + bob)
	ci.draw_line(Vector2(-dir * r * 0.1, r * 0.1 + bob), tip, Color(0.63, 0.45, 0.26), 2.4, true)
	ci.draw_colored_polygon(PackedVector2Array([
		tip + Vector2(dir * r * 0.22, 0.0),
		tip + Vector2(-dir * r * 0.06, -r * 0.16),
		tip + Vector2(-dir * r * 0.06, r * 0.16),
	]), Color(0.85, 0.87, 0.9))
	ci.draw_polyline(PackedVector2Array([
		tip + Vector2(dir * r * 0.22, 0.0),
		tip + Vector2(-dir * r * 0.06, -r * 0.16),
		tip + Vector2(-dir * r * 0.06, r * 0.16),
		tip + Vector2(dir * r * 0.22, 0.0),
	]), ink, 1.4, true)


## Lizard warren: a mound with a dark burrow mouth and eyes peeking out.
static func _warren(ci: CanvasItem, r: float, t: float) -> void:
	var dirt := Color(0.55, 0.44, 0.3)
	var dirt_lit := Color(0.66, 0.54, 0.38)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 1.1, r * 0.55),
		Vector2(-r * 0.75, -r * 0.35),
		Vector2(-r * 0.2, -r * 0.75),
		Vector2(r * 0.35, -r * 0.6),
		Vector2(r * 0.9, -r * 0.05),
		Vector2(r * 1.1, r * 0.55),
	]), dirt)
	ci.draw_polyline(PackedVector2Array([
		Vector2(-r * 1.1, r * 0.55),
		Vector2(-r * 0.75, -r * 0.35),
		Vector2(-r * 0.2, -r * 0.75),
		Vector2(r * 0.35, -r * 0.6),
		Vector2(r * 0.9, -r * 0.05),
		Vector2(r * 1.1, r * 0.55),
	]), ink, 2.0, true)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-r * 0.55, r * 0.55),
		Vector2(-r * 0.7, -r * 0.1),
		Vector2(-r * 0.1, -r * 0.5),
		Vector2(r * 0.5, -r * 0.05),
		Vector2(r * 0.55, r * 0.55),
	]), dirt_lit)
	# burrow mouth
	ci.draw_circle(Vector2(0, r * 0.2), r * 0.42, Color(0.14, 0.11, 0.1))
	# eyes in the dark
	var blink := 0.5 + 0.5 * sin(t * 2.2)
	ci.draw_circle(Vector2(-r * 0.16, r * 0.08), r * 0.09, Color(0.99, 0.85, 0.3, blink))
	ci.draw_circle(Vector2(r * 0.16, r * 0.08), r * 0.09, Color(0.99, 0.85, 0.3, blink))
	# rocks
	for p in [Vector2(-r * 0.85, r * 0.42), Vector2(r * 0.8, r * 0.38)]:
		ci.draw_circle(p, r * 0.13, Color(0.5, 0.48, 0.45))
		ci.draw_arc(p, r * 0.13, 0.0, TAU, 12, ink, 1.4, true)


## Hot Chicken: a round orange bird with a flame crest. Airborne it spreads its
## wings and shows its claws.
## Primal Aphid: a hovering masked bug. Pale mask with dark eye slots, banded
## brown body, fluttering wings and the little spit tube it fires its cone from.
static func _aphid(ci: CanvasItem, r: float, t: float, facing: float) -> void:
	var f := facing if absf(facing) > 0.01 else 1.0
	var beat := 0.5 + 0.5 * sin(t * 24.0)
	# wings
	for s in [-1.0, 1.0]:
		var tip := Vector2(-r * (0.35 + 0.45 * beat) * f, -r * (0.85 + 0.35 * beat) * f)
		ci.draw_line(Vector2(-r * 0.15 * f, -r * 0.3), tip, Color(0.85, 0.92, 1.0, 0.45), r * 0.26, true)
		ci.draw_line(Vector2(-r * 0.15 * f, -r * 0.3), tip + Vector2(s * r * 0.25 * f, r * 0.15),
			Color(0.85, 0.92, 1.0, 0.28), r * 0.16, true)
	# body
	ellipse(ci, Vector2(-r * 0.1 * f, r * 0.1), r * 0.82, r * 0.68, Color(0.42, 0.29, 0.19))
	ellipse(ci, Vector2(-r * 0.25 * f, r * 0.25), r * 0.4, r * 0.3, Color(0.66, 0.47, 0.28), 0.0)
	# legs
	for k in 3:
		var y := r * (0.35 + float(k) * 0.22)
		ci.draw_line(Vector2(-r * 0.35 * f, y), Vector2(-r * 0.75 * f, y + r * 0.16), ink, r * 0.09, true)
	# mask
	ellipse(ci, Vector2(r * 0.42 * f, -r * 0.05), r * 0.6, r * 0.58, Color(0.95, 0.93, 0.86))
	# eye slots
	ellipse(ci, Vector2(r * 0.24 * f, -r * 0.16), r * 0.16, r * 0.22, Color(0.15, 0.12, 0.14), 0.0)
	ellipse(ci, Vector2(r * 0.62 * f, -r * 0.12), r * 0.14, r * 0.2, Color(0.15, 0.12, 0.14), 0.0)
	# crest
	poly(ci, PackedVector2Array([Vector2(r * 0.2 * f, -r * 0.55), Vector2(r * 0.45 * f, -r * 1.0),
		Vector2(r * 0.62 * f, -r * 0.5)]), Color(0.72, 0.52, 0.32), r * 0.1)
	# spit tube
	ci.draw_line(Vector2(r * 0.82 * f, r * 0.12), Vector2(r * 1.34 * f, r * 0.18), Color(0.28, 0.2, 0.15), r * 0.18, true)
	ci.draw_circle(Vector2(r * 1.34 * f, r * 0.18), r * 0.1, Color(0.96, 0.86, 0.52))

## Penny: a small calico cat — white base, orange and black patches, green eyes.
static func _penny(ci: CanvasItem, r: float, t: float, facing: float) -> void:
	var f := facing if absf(facing) > 0.01 else 1.0
	var wag := sin(t * 7.0) * 0.35
	# tail
	ci.draw_line(Vector2(-r * 1.0 * f, r * 0.5), Vector2(-r * 1.7 * f, r * 0.1 + r * wag), ink, r * 0.26, true)
	ci.draw_circle(Vector2(-r * 1.7 * f, r * 0.1 + r * wag), r * 0.17, Color(0.94, 0.55, 0.22))
	# body and haunches
	ellipse(ci, Vector2(-r * 0.2 * f, r * 0.45), r * 0.95, r * 0.68, Color(0.97, 0.95, 0.9))
	ellipse(ci, Vector2(-r * 0.55 * f, r * 0.25), r * 0.42, r * 0.38, Color(0.94, 0.55, 0.22), 0.0)
	ellipse(ci, Vector2(r * 0.3 * f, r * 0.72), r * 0.4, r * 0.28, Color(0.28, 0.24, 0.26), 0.0)
	# head
	ellipse(ci, Vector2(r * 0.62 * f, -r * 0.3), r * 0.6, r * 0.52, Color(0.97, 0.95, 0.9))
	poly(ci, PackedVector2Array([Vector2(r * 0.25 * f, -r * 0.68), Vector2(r * 0.42 * f, -r * 1.28),
		Vector2(r * 0.78 * f, -r * 0.78)]), Color(0.97, 0.95, 0.9), r * 0.12)
	poly(ci, PackedVector2Array([Vector2(r * 0.82 * f, -r * 0.78), Vector2(r * 1.06 * f, -r * 1.24),
		Vector2(r * 1.18 * f, -r * 0.55)]), Color(0.28, 0.24, 0.26), r * 0.12)
	# eyes and nose
	ci.draw_circle(Vector2(r * 0.52 * f, -r * 0.34), r * 0.11, Color(0.3, 0.8, 0.45))
	ci.draw_circle(Vector2(r * 0.88 * f, -r * 0.3), r * 0.11, Color(0.3, 0.8, 0.45))
	ci.draw_circle(Vector2(r * 0.7 * f, -r * 0.06), r * 0.08, Color(0.95, 0.6, 0.65))
	# whiskers
	ci.draw_line(Vector2(r * 0.6 * f, -r * 0.1), Vector2(r * 1.25 * f, -r * 0.22), ink, 1.2, true)
	ci.draw_line(Vector2(r * 0.6 * f, -r * 0.04), Vector2(r * 1.25 * f, r * 0.1), ink, 1.2, true)


## Pen: Penny's other half. Tall, purple-eared, wrapped in a yellow toga, with a
## long blowgun held across him.
static func _pen(ci: CanvasItem, r: float, t: float, facing: float) -> void:
	var f := facing if absf(facing) > 0.01 else 1.0
	var toga := Color(0.93, 0.72, 0.16)
	var toga_dark := Color(0.72, 0.5, 0.11)
	var fur := Color(0.87, 0.79, 0.73)
	var ear := Color(0.74, 0.42, 0.74)
	# legs
	ci.draw_line(Vector2(-r * 0.22 * f, r * 1.05), Vector2(-r * 0.3 * f, r * 0.5), ink, r * 0.24, true)
	ci.draw_line(Vector2(r * 0.26 * f, r * 1.05), Vector2(r * 0.32 * f, r * 0.5), ink, r * 0.24, true)
	# toga
	poly(ci, PackedVector2Array([Vector2(-r * 0.78 * f, r * 0.7), Vector2(r * 0.78 * f, r * 0.7),
		Vector2(r * 0.5 * f, -r * 0.5), Vector2(-r * 0.55 * f, -r * 0.42)]), toga)
	ci.draw_line(Vector2(-r * 0.45 * f, -r * 0.35), Vector2(r * 0.32 * f, r * 0.65), toga_dark, r * 0.13, true)
	# bare shoulder and welcoming hand
	ci.draw_line(Vector2(-r * 0.62 * f, -r * 0.28), Vector2(-r * 1.2 * f, -r * 0.02), fur, r * 0.26, true)
	ci.draw_circle(Vector2(-r * 1.28 * f, -r * 0.02), r * 0.2, fur)
	# head
	ellipse(ci, Vector2(r * 0.12 * f, -r * 0.95), r * 0.52, r * 0.55, fur)
	# tall ears
	poly(ci, PackedVector2Array([Vector2(-r * 0.18 * f, -r * 1.32), Vector2(r * 0.02 * f, -r * 1.92),
		Vector2(r * 0.3 * f, -r * 1.28)]), ear)
	poly(ci, PackedVector2Array([Vector2(r * 0.4 * f, -r * 1.3), Vector2(r * 0.66 * f, -r * 1.86),
		Vector2(r * 0.74 * f, -r * 1.12)]), ear)
	# eyes and muzzle
	ci.draw_circle(Vector2(-r * 0.02 * f, -r * 0.98), r * 0.12, Color(0.97, 0.85, 0.28))
	ci.draw_circle(Vector2(r * 0.42 * f, -r * 0.98), r * 0.12, Color(0.97, 0.85, 0.28))
	ellipse(ci, Vector2(r * 0.18 * f, -r * 0.74), r * 0.2, r * 0.14, Color(0.98, 0.95, 0.92), 0.0)
	# blowgun
	ci.draw_line(Vector2(-r * 1.35 * f, r * 0.22), Vector2(r * 1.0 * f, -r * 0.18), Color(0.52, 0.35, 0.2), r * 0.15, true)
	ci.draw_line(Vector2(-r * 1.35 * f, r * 0.22), Vector2(-r * 1.05 * f, r * 0.13), Color(0.78, 0.62, 0.3), r * 0.18, true)


static func _chicken(ci: CanvasItem, r: float, t: float, facing: float, flying: bool) -> void:
	var bob := sin(t * 9.0) * r * 0.08
	var body := Color(1.0, 0.56, 0.22)
	var dark := Color(0.72, 0.3, 0.1)
	if flying:
		# wings out
		var flap := sin(t * 16.0) * 0.35
		for s in [-1.0, 1.0]:
			var wp: PackedVector2Array = PackedVector2Array([
				Vector2(s * r * 0.2, -r * 0.1 + bob),
				Vector2(s * r * 1.35, (-r * 0.55 - flap * r) + bob),
				Vector2(s * r * 1.1, r * 0.35 + bob),
			])
			ci.draw_colored_polygon(wp, Color(1.0, 0.72, 0.35))
			var outline: PackedVector2Array = wp.duplicate()
			outline.append(wp[0])
			ci.draw_polyline(outline, ink, 2.0, true)
	ci.draw_circle(Vector2(0, bob), r * 0.82, body)
	ci.draw_arc(Vector2(0, bob), r * 0.82, 0.0, TAU, 22, ink, 2.0, true)
	# flame crest
	var flame: PackedVector2Array = PackedVector2Array([
		Vector2(-r * 0.3, -r * 0.7 + bob),
		Vector2(0.0, -r * 1.5 + bob + sin(t * 14.0) * r * 0.16),
		Vector2(r * 0.3, -r * 0.7 + bob),
	])
	ci.draw_colored_polygon(flame, Color(1.0, 0.85, 0.25))
	ci.draw_polyline(PackedVector2Array([flame[0], flame[1], flame[2], flame[0]]), ink, 1.6, true)
	# beak + eye
	var dir: float = 1.0 if facing >= 0.0 else -1.0
	var beak: PackedVector2Array = PackedVector2Array([
		Vector2(dir * r * 0.75, -r * 0.05 + bob),
		Vector2(dir * r * 1.25, r * 0.1 + bob),
		Vector2(dir * r * 0.72, r * 0.3 + bob),
	])
	ci.draw_colored_polygon(beak, Color(1.0, 0.8, 0.3))
	ci.draw_polyline(PackedVector2Array([beak[0], beak[1], beak[2], beak[0]]), ink, 1.6, true)
	ci.draw_circle(Vector2(dir * r * 0.32, -r * 0.28 + bob), r * 0.13, Color(0.1, 0.08, 0.1))
	if flying:
		for s in [-1.0, 1.0]:
			ci.draw_line(Vector2(s * r * 0.35, r * 0.72 + bob), Vector2(s * r * 0.6, r * 1.05 + bob), dark, 2.0, true)


static func hedgehog(ci: CanvasItem, r: float, facing: float, t: float, curled: bool, ink_col: Color = OUTLINE) -> void:
	ink = ink_col
	var body := Color(0.66, 0.52, 0.38)
	var spike := Color(0.32, 0.26, 0.2)
	var belly := Color(0.82, 0.72, 0.58)
	if curled:
		for i in 12:
			var a := TAU * float(i) / 12.0
			var base := Vector2(cos(a), sin(a)) * r * 0.85
			var tip := Vector2(cos(a), sin(a)) * r * 1.55
			var side := Vector2(-sin(a), cos(a)) * r * 0.17
			poly(ci, PackedVector2Array([base + side, tip, base - side]), spike, 1.0)
		circle(ci, Vector2.ZERO, r * 0.85, body)
		ci.draw_circle(Vector2(r * 0.28 * facing, -r * 0.08), r * 0.13, Color(0.12, 0.1, 0.14))
	else:
		ellipse(ci, Vector2(0, 0), r * 1.05, r * 0.75, body)
		ellipse(ci, Vector2(r * 0.2 * facing, r * 0.22), r * 0.7, r * 0.42, belly, 0.0)
		for i in 5:
			var p := Vector2(-r * 0.6 + float(i) * r * 0.3, -r * 0.5)
			poly(ci, PackedVector2Array([
				p + Vector2(-r * 0.13, 0), p + Vector2(0, -r * 0.55), p + Vector2(r * 0.13, 0)]), spike, 1.0)
		poly(ci, PackedVector2Array([
			Vector2(r * 0.85 * facing, -r * 0.18), Vector2(r * 1.5 * facing, 0),
			Vector2(r * 0.85 * facing, r * 0.22)]), body, 1.4)
		ci.draw_circle(Vector2(r * 0.7 * facing, -r * 0.25), r * 0.12, Color(0.12, 0.1, 0.14))
	ink = OUTLINE


static func _zombie(ci: CanvasItem, r: float, t: float, facing: float) -> void:
	var sway := sin(t * 3.0) * r * 0.07
	var skin := Color(0.55, 0.72, 0.42)
	var dark := Color(0.34, 0.48, 0.3)
	var cloth := Color(0.45, 0.36, 0.5)
	ci.draw_line(Vector2(r * 0.15 * facing, -r * 0.05 + sway), Vector2(r * 1.15 * facing, -r * 0.22 + sway), dark, r * 0.26, true)
	ci.draw_line(Vector2(r * 0.15 * facing, r * 0.14 + sway), Vector2(r * 1.05 * facing, r * 0.06 + sway), dark, r * 0.24, true)
	ci.draw_line(Vector2(-r * 0.25, r * 0.75 + sway), Vector2(-r * 0.35, r * 1.15 + sway), dark, r * 0.24, true)
	ci.draw_line(Vector2(r * 0.25, r * 0.75 + sway), Vector2(r * 0.35, r * 1.15 + sway), dark, r * 0.24, true)
	ellipse(ci, Vector2(0, r * 0.3 + sway), r * 0.58, r * 0.62, cloth)
	circle(ci, Vector2(0, -r * 0.55 + sway), r * 0.48, skin)
	ci.draw_circle(Vector2(-r * 0.17, -r * 0.58 + sway), r * 0.12, Color(0.12, 0.1, 0.14))
	ci.draw_circle(Vector2(r * 0.17, -r * 0.58 + sway), r * 0.12, Color(0.12, 0.1, 0.14))
	ci.draw_line(Vector2(-r * 0.16, -r * 0.34 + sway), Vector2(r * 0.16, -r * 0.34 + sway), Color(0.25, 0.2, 0.24), 2.0, true)
	ci.draw_line(Vector2(-r * 0.3, -r * 0.78 + sway), Vector2(r * 0.32, -r * 0.7 + sway), Color(0.26, 0.32, 0.22), 1.6, true)


static func bird(ci: CanvasItem, r: float, facing: float, t: float, lead: bool, ink_col: Color = OUTLINE) -> void:
	ink = ink_col
	# super-auto-pets-ish: chunky simple shapes, thick outline, one big eye
	var frame := int(t * 9.0) % 3
	var lift: float = [-1.0, 0.0, 1.0][frame]
	var body := Color(0.92, 0.22, 0.2) if lead else Color(0.98, 0.8, 0.22)
	var wing := body.darkened(0.14)
	var belly := Color(0.99, 0.58, 0.24) if lead else Color(0.99, 0.93, 0.75)
	poly(ci, PackedVector2Array([
		Vector2(-r * 0.85 * facing, 0), Vector2(-r * 1.65 * facing, -r * 0.42),
		Vector2(-r * 1.65 * facing, r * 0.42)]), wing, 1.6)
	poly(ci, PackedVector2Array([
		Vector2(-r * 0.15 * facing, -r * 0.1), Vector2(-r * 0.9 * facing, -r * (0.75 + 0.45 * lift)),
		Vector2(-r * 0.45 * facing, r * 0.45)]), wing, 1.5)
	ellipse(ci, Vector2.ZERO, r * 1.0, r * 0.8, body)
	ellipse(ci, Vector2(r * 0.12 * facing, r * 0.22), r * 0.62, r * 0.4, belly, 0.0)
	circle(ci, Vector2(r * 0.8 * facing, -r * 0.45), r * 0.55, body)
	poly(ci, PackedVector2Array([
		Vector2(r * 1.2 * facing, -r * 0.55), Vector2(r * 1.95 * facing, -r * 0.38),
		Vector2(r * 1.2 * facing, -r * 0.2)]), Color(0.98, 0.62, 0.18) if lead else Color(0.36, 0.31, 0.27), 1.5)
	ci.draw_circle(Vector2(r * 0.9 * facing, -r * 0.55), r * 0.17, Color(0.1, 0.09, 0.12))
	ci.draw_circle(Vector2(r * 0.96 * facing, -r * 0.62), r * 0.06, Color(1, 1, 1))
	poly(ci, PackedVector2Array([
		Vector2(r * 0.1 * facing, -r * 0.15), Vector2(-r * 0.25 + r * 0.2 * facing, -r * (0.5 + 0.5 * lift)),
		Vector2(r * 0.35 * facing, r * 0.25)]), wing.lightened(0.12), 1.6)
	ink = OUTLINE


static func tower(ci: CanvasItem, w: float, h: float, team_color: Color, hurt: float = 0.0, crown: bool = false, ink_col: Color = OUTLINE) -> void:
	ink = ink_col
	var half := Vector2(w, h) * 0.5
	var body := Rect2(-half, Vector2(w, h))
	rect_outlined(ci, body, team_color)
	# crenellations
	var n := 4
	for i in n:
		var cw := w / float(n) * 0.55
		var x := -half.x + w / float(n) * (float(i) + 0.225)
		rect_outlined(ci, Rect2(x, -half.y - h * 0.16, cw, h * 0.18), team_color.lightened(0.08), 2.0)
	# stone band
	ci.draw_rect(Rect2(-half.x, half.y - h * 0.28, w, h * 0.16), Color(0, 0, 0, 0.18), true)
	# window
	ci.draw_rect(Rect2(-w * 0.12, -h * 0.15, w * 0.24, h * 0.26), Color(0.12, 0.1, 0.16), true)
	if crown:
		poly(ci, PackedVector2Array([
			Vector2(-w * 0.28, -half.y - h * 0.2), Vector2(-w * 0.14, -half.y - h * 0.42),
			Vector2(0, -half.y - h * 0.22), Vector2(w * 0.14, -half.y - h * 0.42),
			Vector2(w * 0.28, -half.y - h * 0.2)]), Color(0.98, 0.82, 0.3), 2.0)
	ci.draw_rect(Rect2(-half.x + 3, -half.y + 4, w * 0.18, h * 0.7), Color(1, 1, 1, 0.16), true)
	if hurt > 0.0:
		ci.draw_rect(body, Color(1, 1, 1, clampf(hurt, 0.0, 0.5)), true)
	ink = OUTLINE


## Small card-sheet icon, drawn inside a rounded card.
static func icon(ci: CanvasItem, kind: String, c: Vector2, r: float, t: float = 0.0, lead: bool = false) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE)
	match kind:
		"snowman":
			creature(ci, "snowman", r, 1.0, t)
		"ovomachine":
			creature(ci, "ovomachine", r, 1.0, t)
		"snowball":
			creature(ci, "snowball", r * 0.92, 1.0, t)
		"slate":
			creature(ci, "slate", r, 1.0, t)
		"alchemist":
			creature(ci, "alchemist", r, 1.0, t)
		"idol":
			creature(ci, "idol", r, 1.0, t)
		"fireball":
			creature(ci, "fireball", r * 0.85, 1.0, t)
		"firebolt":
			creature(ci, "firebolt", r * 0.85, 1.0, t)
		"hero":
			creature(ci, "hero", r, 1.0, t)
		"fu":
			creature(ci, "fu", r, 1.0, t)
		"hawk":
			bird(ci, r, 1.0, t, lead)
		"zombie":
			creature(ci, "zombie", r, 1.0, t)
		"hedgehog":
			creature(ci, "hedgehog", r, 1.0, t)
		"chicken":
			creature(ci, "chicken", r, 1.0, t)
		"penny":
			creature(ci, "penny", r, 1.0, t)
		"pen":
			creature(ci, "pen", r, 1.0, t)
		"aphid":
			creature(ci, "aphid", r, 1.0, t)
		"lizard":
			creature(ci, "lizard", r, 1.0, t)
		"warren":
			creature(ci, "warren", r * 1.2, 1.0, t)
		"dragon":
			dragon(ci, r * 0.8, 1.0, t, false)
		_:
			circle(ci, Vector2.ZERO, r, Color.MAGENTA)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
