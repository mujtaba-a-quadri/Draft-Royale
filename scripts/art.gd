class_name DDArt
extends RefCounted

## Flat, cartoonish, outlined art. Every creature/tower is drawn procedurally so
## the project stays asset-free while keeping a consistent Adventure Time /
## Hollow Knight silhouette language.

const OUTLINE := Color(0.11, 0.09, 0.14)
const OUTLINE_W := 2.4

const INK := Color(0.16, 0.13, 0.2)


static func circle(ci: CanvasItem, c: Vector2, r: float, fill: Color, w: float = OUTLINE_W) -> void:
	ci.draw_circle(c, r, fill)
	if w > 0.0:
		ci.draw_arc(c, r, 0.0, TAU, 48, OUTLINE, w, true)


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
		ci.draw_polyline(loop, OUTLINE, w, true)


static func rect_outlined(ci: CanvasItem, r: Rect2, fill: Color, w: float = OUTLINE_W) -> void:
	ci.draw_rect(r, fill, true)
	if w > 0.0:
		ci.draw_rect(r, OUTLINE, false, w)


static func coin(ci: CanvasItem, c: Vector2, r: float) -> void:
	circle(ci, c, r, Color(0.98, 0.79, 0.26))
	ci.draw_arc(c, r * 0.55, 0.0, TAU, 24, Color(0.85, 0.6, 0.15), 1.6, true)


## r is the drawing radius in pixels; t is a shared animation clock.
static func creature(ci: CanvasItem, kind: String, r: float, facing: float, t: float, hurt: float = 0.0, phase2: bool = false) -> void:
	match kind:
		"snowman":
			_snowman(ci, r, t)
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
			hedgehog(ci, r, facing, t, false)
		"chicken":
			_chicken(ci, r, t, facing, false)
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


static func _snowman(ci: CanvasItem, r: float, t: float) -> void:
	var bob := sin(t * 2.0) * r * 0.05
	var body := Color(0.93, 0.97, 1.0)
	var shade := Color(0.72, 0.84, 0.95)
	# arms
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


static func dragon(ci: CanvasItem, r: float, facing: float, t: float, flying: bool, hurt: float = 0.0) -> void:
	var skin := Color(0.72, 0.2, 0.22)
	var dark := Color(0.48, 0.12, 0.16)
	var belly := Color(0.93, 0.6, 0.35)
	var flap := sin(t * 7.0) * 0.14
	poly(ci, PackedVector2Array([
		Vector2(-r * 0.9, r * 0.25), Vector2(-r * 1.95, r * 0.02), Vector2(-r * 1.15, r * 0.6)]), dark, 2.0)
	if flying:
		poly(ci, PackedVector2Array([
			Vector2(-r * 0.35, -r * 0.5), Vector2(-r * 1.95, -r * 1.25 - flap * r),
			Vector2(-r * 1.1, -r * 0.1)]), dark, 2.2)
		poly(ci, PackedVector2Array([
			Vector2(r * 0.35, -r * 0.5), Vector2(r * 1.95, -r * 1.25 - flap * r),
			Vector2(r * 1.1, -r * 0.1)]), dark, 2.2)
	else:
		poly(ci, PackedVector2Array([
			Vector2(-r * 0.45, -r * 0.35), Vector2(-r * 1.35, -r * 0.8),
			Vector2(-r * 0.95, r * 0.15)]), dark, 2.0)
		poly(ci, PackedVector2Array([
			Vector2(r * 0.45, -r * 0.35), Vector2(r * 1.35, -r * 0.8),
			Vector2(r * 0.95, r * 0.15)]), dark, 2.0)
	ellipse(ci, Vector2(0, 0), r * 1.0, r * 0.72, skin)
	ellipse(ci, Vector2(r * 0.05 * facing, r * 0.24), r * 0.62, r * 0.36, belly, 0.0)
	# legs
	ci.draw_line(Vector2(-r * 0.45, r * 0.55), Vector2(-r * 0.55, r * 0.95), dark, 4.0, true)
	ci.draw_line(Vector2(r * 0.4, r * 0.55), Vector2(r * 0.5, r * 0.95), dark, 4.0, true)
	# neck + head
	var hx := r * 0.95 * facing
	poly(ci, PackedVector2Array([
		Vector2(r * 0.3 * facing, -r * 0.2), Vector2(hx, -r * 0.85),
		Vector2(hx * 0.45, r * 0.05)]), skin, 0.0)
	circle(ci, Vector2(hx, -r * 0.85), r * 0.44, skin)
	poly(ci, PackedVector2Array([
		Vector2(hx + r * 0.28 * facing, -r * 0.95), Vector2(hx + r * 0.8 * facing, -r * 0.78),
		Vector2(hx + r * 0.28 * facing, -r * 0.62)]), skin, 1.8)
	poly(ci, PackedVector2Array([
		Vector2(hx - r * 0.1, -r * 1.18), Vector2(hx - r * 0.32, -r * 1.6),
		Vector2(hx + r * 0.22, -r * 1.16)]), Color(0.93, 0.89, 0.8), 1.6)
	ci.draw_circle(Vector2(hx + r * 0.1 * facing, -r * 0.92), r * 0.1, Color(1.0, 0.85, 0.2))
	if not flying:
		for i in 3:
			var cy := -r * 0.4 + float(i) * r * 0.34
			ci.draw_line(Vector2(-r * 1.05, cy), Vector2(r * 0.75, cy + r * 0.14), Color(0.6, 0.61, 0.68), 3.0, true)
			for k in 3:
				var cx := -r * 0.95 + float(k) * r * 0.62
				ci.draw_arc(Vector2(cx, cy + r * 0.1), r * 0.11, 0.0, TAU, 12, Color(0.78, 0.79, 0.86), 2.0, true)
	if hurt > 0.0:
		ci.draw_circle(Vector2.ZERO, r * 1.1, Color(1, 1, 1, clampf(hurt, 0.0, 0.5)))


static func _fu(ci: CanvasItem, r: float, t: float, facing: float) -> void:
	var bob := sin(t * 5.0) * r * 0.06
	var cloth := Color(0.36, 0.55, 0.86)
	var skin := Color(0.87, 0.72, 0.52)
	var straw := Color(0.93, 0.81, 0.5)
	# legs
	ci.draw_line(Vector2(-r * 0.28, r * 0.6 + bob), Vector2(-r * 0.42, r * 1.05 + bob), DDArt.OUTLINE, 3.0, true)
	ci.draw_line(Vector2(r * 0.26, r * 0.6 + bob), Vector2(r * 0.4, r * 1.05 + bob), DDArt.OUTLINE, 3.0, true)
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
	ci.draw_line(Vector2(-r * 0.62, -r * 0.72 + bob), Vector2(r * 0.62, -r * 0.72 + bob), DDArt.OUTLINE, 2.0, true)
	# boomerang in hand
	var bx := r * 0.85 * facing
	ci.draw_line(Vector2(bx, r * 0.15 + bob), Vector2(bx + r * 0.42 * facing, -r * 0.12 + bob), Color(0.75, 0.55, 0.28), 3.5, true)
	ci.draw_line(Vector2(bx + r * 0.42 * facing, -r * 0.12 + bob), Vector2(bx + r * 0.3 * facing, -r * 0.5 + bob), Color(0.75, 0.55, 0.28), 3.5, true)


## Commander towers: the furthest-back tower wears a face of its own.
## Blue side reads as a celestial jelly, red side as a spear goblin. Both light
## up when that player's ability is ready.
static func commander(ci: CanvasItem, kind: String, r: float, t: float, ready: bool, team_col: Color) -> void:
	if kind == "tentacle":
		_jelly(ci, r, t, ready, team_col)
	else:
		_goblin_commander(ci, r, t, ready, team_col)


static func _jelly(ci: CanvasItem, r: float, t: float, ready: bool, team_col: Color) -> void:
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
		var px := r * 2.6 * f
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
	ci.draw_arc(Vector2(0, bob), r * 0.62, 0.0, TAU, 18, OUTLINE, 1.8, true)
	ci.draw_circle(Vector2(dir * r * 0.1, r * 0.18 + bob), r * 0.34, belly)
	# head
	var head := Vector2(dir * r * 0.55, -r * 0.35 + bob)
	ci.draw_circle(head, r * 0.34, skin)
	ci.draw_arc(head, r * 0.34, 0.0, TAU, 16, OUTLINE, 1.8, true)
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
	]), OUTLINE, 1.4, true)


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
	]), OUTLINE, 2.0, true)
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
		ci.draw_arc(p, r * 0.13, 0.0, TAU, 12, OUTLINE, 1.4, true)


## Hot Chicken: a round orange bird with a flame crest. Airborne it spreads its
## wings and shows its claws.
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
			ci.draw_polyline(outline, OUTLINE, 2.0, true)
	ci.draw_circle(Vector2(0, bob), r * 0.82, body)
	ci.draw_arc(Vector2(0, bob), r * 0.82, 0.0, TAU, 22, OUTLINE, 2.0, true)
	# flame crest
	var flame: PackedVector2Array = PackedVector2Array([
		Vector2(-r * 0.3, -r * 0.7 + bob),
		Vector2(0.0, -r * 1.5 + bob + sin(t * 14.0) * r * 0.16),
		Vector2(r * 0.3, -r * 0.7 + bob),
	])
	ci.draw_colored_polygon(flame, Color(1.0, 0.85, 0.25))
	ci.draw_polyline(PackedVector2Array([flame[0], flame[1], flame[2], flame[0]]), OUTLINE, 1.6, true)
	# beak + eye
	var dir: float = 1.0 if facing >= 0.0 else -1.0
	var beak: PackedVector2Array = PackedVector2Array([
		Vector2(dir * r * 0.75, -r * 0.05 + bob),
		Vector2(dir * r * 1.25, r * 0.1 + bob),
		Vector2(dir * r * 0.72, r * 0.3 + bob),
	])
	ci.draw_colored_polygon(beak, Color(1.0, 0.8, 0.3))
	ci.draw_polyline(PackedVector2Array([beak[0], beak[1], beak[2], beak[0]]), OUTLINE, 1.6, true)
	ci.draw_circle(Vector2(dir * r * 0.32, -r * 0.28 + bob), r * 0.13, Color(0.1, 0.08, 0.1))
	if flying:
		for s in [-1.0, 1.0]:
			ci.draw_line(Vector2(s * r * 0.35, r * 0.72 + bob), Vector2(s * r * 0.6, r * 1.05 + bob), dark, 2.0, true)


static func hedgehog(ci: CanvasItem, r: float, facing: float, t: float, curled: bool) -> void:
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


static func bird(ci: CanvasItem, r: float, facing: float, t: float, lead: bool) -> void:
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


static func tower(ci: CanvasItem, w: float, h: float, team_color: Color, hurt: float = 0.0, crown: bool = false) -> void:
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


## Small card-sheet icon, drawn inside a rounded card.
static func icon(ci: CanvasItem, kind: String, c: Vector2, r: float, t: float = 0.0) -> void:
	ci.draw_set_transform(c, 0.0, Vector2.ONE)
	match kind:
		"snowman":
			creature(ci, "snowman", r, 1.0, t)
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
			bird(ci, r, 1.0, t, false)
		"zombie":
			creature(ci, "zombie", r, 1.0, t)
		"hedgehog":
			creature(ci, "hedgehog", r, 1.0, t)
		"chicken":
			creature(ci, "chicken", r, 1.0, t)
		"lizard":
			creature(ci, "lizard", r, 1.0, t)
		"warren":
			creature(ci, "warren", r * 1.2, 1.0, t)
		"dragon":
			dragon(ci, r * 0.8, 1.0, t, false)
		_:
			circle(ci, Vector2.ZERO, r, Color.MAGENTA)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
