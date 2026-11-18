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
		"obsidian":
			whelp(ci, r, facing, t, false, false, ink_col)
		"wu":
			bonobo(ci, r, facing, t, {"staff": 1.0}, ink_col)
		"magma":
			whelp(ci, r, facing, t, false, true, ink_col)
		"neko":
			nekomancer(ci, r, facing, t, {}, ink_col)
		"ratbones":
			ratbones(ci, r, facing, t, ink_col)
		"gilgamesh":
			gilgamesh(ci, r, facing, t, {}, ink_col)
		"enkidu":
			enkidu(ci, r, facing, t, {}, ink_col)
		"frog":
			dart_frog(ci, r, facing, t, 0.0, ink_col)
		"chicken":
			_chicken(ci, r, t, facing, fly)
		"penny":
			_penny(ci, r, t, facing)
		"pen":
			_pen(ci, r, t, facing)
		"troll":
			troll(ci, r, facing, t, 0.45, ink_col)
		"laniakea":
			laniakea(ci, r, facing, t, 0, ink_col)
		"femme":
			femme(ci, r, facing, t, 0, ink_col)
		"shiesty":
			shiesty(ci, r, facing, t, ink_col)
		"spiderling":
			_spiderling(ci, r, t, facing)
		"spideregg":
			_spideregg(ci, r, t)
		"spider":
			spider_boss(ci, r, t, {}, ink_col)
		"kraken":
			kraken_head(ci, r * 0.7, t, {"mouth": 0.4}, ink_col)
		"krakenarm":
			kraken_arm(ci, Vector2(-r * 0.3, r * 0.8), Vector2(r * 0.3, r * 0.6), r * 1.1, r * 0.7,
				Vector2(0.8, 0.6), r * 1.5, Color(0.2, 0.36, 0.78), t, 0.0, 1.0, ink_col)
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
## pose is cosmetic state from the tower, goblin only: "face" (+1 / -1, the side
## the enemy is on), "throw" (seconds since his spear left his hand) and "toss"
## (seconds since he scooped Shiesty up).
static func commander(ci: CanvasItem, kind: String, r: float, t: float, ready: bool, team_col: Color, flip: bool = false, pose: Dictionary = {}) -> void:
	if kind == "tentacle":
		_jelly(ci, r, t, ready, team_col, flip)
	else:
		_goblin_commander(ci, r, t, ready, team_col, pose)


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


## How long the goblin commander holds Shiesty before letting go, and how long
## the throwing arm takes to follow through. Shiesty's own draw uses the first.
const TOSS_SCOOP := 0.28
const TOSS_FOLLOW := 0.25
## After a spear leaves his hand: the follow-through, then the wait for the next.
const THROW_FOLLOW := 0.16
const THROW_REARM := 0.42


## Where the goblin commander's free hand is while he scoops Shiesty up, relative
## to the tower centre. p runs 0..1 over TOSS_SCOOP: down to the ground in front
## of him, then up and back over his head. Shiesty rides this point.
static func commander_toss_hand(r: float, face: float, p: float) -> Vector2:
	var rest := Vector2(r * 0.8 * face, r * 0.35)
	var ground := Vector2(r * 1.05 * face, r * 0.8)
	var over := Vector2(-r * 0.1 * face, -r * 1.25)
	if p < 0.4:
		return rest.lerp(ground, p / 0.4)
	var q := clampf((p - 0.4) / 0.6, 0.0, 1.0)
	return ground.lerp(over, q) + Vector2(face * r * 0.5 * sin(q * PI), 0.0)


## The banner's cloth: the team colour pushed to full brightness and kept
## saturated, so it reads as a brighter flag rather than a paler one.
static func banner_color(team_col: Color) -> Color:
	return Color.from_hsv(team_col.h, clampf(team_col.s + 0.15, 0.6, 1.0), 1.0)


## A halberd with a war banner tied under the head: shaft, spear point, axe blade
## and a rippling cloth. side picks which way the cloth hangs off the shaft and
## flutter (0..1+) how hard it is moving. Used in the commander's hand and for
## the spear in flight.
static func standard(ci: CanvasItem, butt: Vector2, tip: Vector2, cloth: Color, t: float, side: float = 1.0, flutter: float = 0.4) -> void:
	var d := tip - butt
	var length := d.length()
	if length < 1.0:
		return
	var n := d / length
	var o := n.orthogonal() * side
	var gold := Color(0.8, 0.68, 0.36)
	var wide := maxf(2.0, length * 0.035)
	# banner first, so the shaft sits on top of its hem
	var top := PackedVector2Array()
	var hem := PackedVector2Array()
	for i in 6:
		var u := 0.44 + 0.3 * float(i) / 5.0
		var on_shaft := butt + d * u
		var ripple := sin(t * 6.0 + u * 22.0) * flutter
		# the far corner is torn short
		var drop := length * (0.3 + 0.05 * ripple) * (0.7 if i == 5 else 1.0)
		top.append(on_shaft)
		hem.append(on_shaft + o * drop + n * length * 0.05 * ripple)
	var flag := top.duplicate()
	for i in range(hem.size() - 1, -1, -1):
		flag.append(hem[i])
	poly(ci, flag, cloth, 1.4)
	ci.draw_polyline(hem, Color(0.96, 0.84, 0.42), maxf(1.4, length * 0.02), true)
	# shaft and butt spike
	ci.draw_line(butt, butt + d * 0.86, gold.darkened(0.25), wide, true)
	ci.draw_line(butt, butt + d * 0.07, Color(0.82, 0.84, 0.88), wide * 0.8, true)
	# axe blade on the cloth side, hook on the other
	var neck := butt + d * 0.8
	poly(ci, PackedVector2Array([neck - n * length * 0.07, neck + o * length * 0.13 - n * length * 0.1,
		neck + o * length * 0.15 + n * length * 0.05, neck + n * length * 0.04]), gold, 1.4)
	poly(ci, PackedVector2Array([neck - n * length * 0.02, neck - o * length * 0.08 + n * length * 0.03,
		neck + n * length * 0.04]), gold, 1.2)
	# spear point
	poly(ci, PackedVector2Array([neck + n * length * 0.02 + o * wide * 1.1, tip, neck + n * length * 0.02 - o * wide * 1.1]),
		Color(0.88, 0.9, 0.94), 1.4)


## The goblin commander: a hunched slab of muscle with tusks and a mohawk, a
## halberd carrying his side's banner in one fist. Eyes light up in the team
## colour and the standard is waved when the ability is ready.
static func _goblin_commander(ci: CanvasItem, r: float, t: float, ready: bool, team_col: Color, pose: Dictionary = {}) -> void:
	var f: float = float(pose.get("face", 1.0))
	var throw_t: float = float(pose.get("throw", 9.0))
	var toss_t: float = float(pose.get("toss", 9.0))
	var skin := Color(0.42, 0.62, 0.24)
	var skin_dark := Color(0.3, 0.46, 0.17)
	var leather := Color(0.42, 0.28, 0.18)
	var cloth := banner_color(team_col)
	var breath := sin(t * 2.2) * r * 0.03
	var keep := ink
	ink = OUTLINE
	# --- the standard: in the back fist, planted, unless it has just been thrown
	var armed: bool = throw_t >= THROW_REARM
	var back_fist := Vector2(-r * 0.78 * f, r * 0.12 + breath)
	if armed:
		var lean := 0.12 + sin(t * 1.3) * 0.03
		var flutter := 0.35
		if ready:
			# waving it: the whole pole swings and the cloth snaps
			lean = sin(t * 4.6) * 0.42
			flutter = 1.0
			back_fist = Vector2(-r * 0.74 * f, -r * 0.1 + breath)
		var up := Vector2(-f * sin(lean), -cos(lean))
		standard(ci, back_fist - up * r * 0.75, back_fist + up * r * 1.75, cloth, t, f, flutter)
	# --- legs and loincloth
	for s in [-1.0, 1.0]:
		ellipse(ci, Vector2(s * r * 0.42, r * 0.72), r * 0.3, r * 0.22, skin_dark, 2.0)
		ellipse(ci, Vector2(s * r * 0.5 + f * r * 0.08, r * 0.88), r * 0.26, r * 0.11, skin, 1.6)
	poly(ci, PackedVector2Array([Vector2(-r * 0.3, r * 0.42), Vector2(r * 0.3, r * 0.42),
		Vector2(r * 0.14, r * 0.92), Vector2(0, r * 0.78), Vector2(-r * 0.16, r * 0.94)]), leather, 1.6)
	# --- torso: wide shoulders, a strap across the chest, a belt
	ellipse(ci, Vector2(0, r * 0.14 + breath), r * 0.8, r * 0.52, skin, 2.2)
	ci.draw_line(Vector2(-r * 0.5 * f, -r * 0.22 + breath), Vector2(r * 0.42 * f, r * 0.5), leather, r * 0.12, true)
	ci.draw_line(Vector2(-r * 0.56, r * 0.46), Vector2(r * 0.56, r * 0.46), leather.darkened(0.2), r * 0.13, true)
	circle(ci, Vector2(0, r * 0.46), r * 0.08, Color(0.8, 0.68, 0.36), 1.2)
	# --- back arm (the spear arm)
	var back_shoulder := Vector2(-r * 0.66 * f, -r * 0.08 + breath)
	if not armed:
		if throw_t < THROW_FOLLOW:
			# just let go: arm flung out toward the enemy
			back_fist = Vector2(r * 0.55 * f, -r * 0.85)
		else:
			# reaching back for the next one
			var q := clampf((throw_t - THROW_FOLLOW) / (THROW_REARM - THROW_FOLLOW), 0.0, 1.0)
			back_fist = Vector2(r * 0.55 * f, -r * 0.85).lerp(Vector2(-r * 1.0 * f, r * 0.3), q)
	circle(ci, back_shoulder, r * 0.3, skin, 2.0)
	ci.draw_line(back_shoulder, back_fist, skin_dark, r * 0.3, true)
	ci.draw_line(back_shoulder.lerp(back_fist, 0.55), back_fist, leather, r * 0.32, true)
	circle(ci, back_fist, r * 0.2, skin, 1.8)
	# --- head: ears, mohawk, heavy brow, tusks
	var head := Vector2(r * 0.14 * f, -r * 0.42 + breath)
	for s in [-1.0, 1.0]:
		poly(ci, PackedVector2Array([head + Vector2(s * r * 0.3, -r * 0.05), head + Vector2(s * r * 0.95, -r * 0.42),
			head + Vector2(s * r * 0.34, r * 0.16)]), skin_dark, 1.8)
	for i in 5:
		var mx := (-0.24 + 0.12 * float(i)) * r
		poly(ci, PackedVector2Array([head + Vector2(mx - r * 0.07, -r * 0.3), head + Vector2(mx - r * 0.06 * f, -r * (0.58 + 0.06 * sin(float(i) * 1.9))),
			head + Vector2(mx + r * 0.07, -r * 0.3)]), Color(0.1, 0.3, 0.32), 1.2)
	ellipse(ci, head, r * 0.42, r * 0.38, skin, 2.2)
	ellipse(ci, head + Vector2(r * 0.04 * f, r * 0.2), r * 0.3, r * 0.17, skin.lightened(0.08), 1.6)
	for s in [-1.0, 1.0]:
		poly(ci, PackedVector2Array([head + Vector2(s * r * 0.2 + r * 0.04 * f, r * 0.22), head + Vector2(s * r * 0.25 + r * 0.04 * f, -r * 0.02),
			head + Vector2(s * r * 0.12 + r * 0.04 * f, r * 0.2)]), Color(0.96, 0.92, 0.78), 1.2)
	ci.draw_line(head + Vector2(-r * 0.12 + r * 0.04 * f, r * 0.2), head + Vector2(r * 0.12 + r * 0.04 * f, r * 0.2), Color(0.15, 0.1, 0.1), 2.0, true)
	# eyes: dark until the ability is up, then lit in the team colour with flames
	var eye := Color(0.1, 0.1, 0.12) if not ready else team_col.lightened(0.15)
	if ready:
		ci.draw_circle(head + Vector2(0, -r * 0.06), r * 0.42, Color(team_col.r, team_col.g, team_col.b, 0.18))
	for s in [-1.0, 1.0]:
		var e := head + Vector2(s * r * 0.17 + r * 0.03 * f, -r * 0.08)
		ci.draw_circle(e, r * 0.085, eye)
		ci.draw_line(e + Vector2(-s * r * 0.14, -r * 0.05), e + Vector2(s * r * 0.12, -r * 0.16), skin_dark, r * 0.07, true)
		if ready:
			for k in 3:
				var fl := Vector2(e.x + sin(t * 9.0 + float(k)) * r * 0.05, e.y - r * (0.16 + 0.1 * float(k)))
				ci.draw_circle(fl, r * (0.07 - 0.018 * float(k)), Color(team_col.r, team_col.g, team_col.b, 0.8 - 0.2 * float(k)))
	# --- front arm: at his side, or scooping Shiesty up and hurling him
	var front_shoulder := Vector2(r * 0.66 * f, -r * 0.08 + breath)
	var front_fist := Vector2(r * 0.8 * f, r * 0.35 + breath)
	if toss_t < TOSS_SCOOP:
		front_fist = commander_toss_hand(r, f, toss_t / TOSS_SCOOP)
	elif toss_t < TOSS_SCOOP + TOSS_FOLLOW:
		var q2 := (toss_t - TOSS_SCOOP) / TOSS_FOLLOW
		front_fist = commander_toss_hand(r, f, 1.0).lerp(Vector2(r * 1.2 * f, -r * 0.55), ease(q2, 0.35))
	circle(ci, front_shoulder, r * 0.32, skin, 2.0)
	ci.draw_line(front_shoulder, front_fist, skin, r * 0.3, true)
	ci.draw_line(front_shoulder.lerp(front_fist, 0.55), front_fist, leather, r * 0.32, true)
	circle(ci, front_fist, r * 0.22, skin, 1.8)
	ink = keep


## The purple poison marker on a unit or tower: the counter, with a ring that
## empties as the next tick approaches (left is 1 just after a tick, 0 at it).
static func poison_badge(ci: CanvasItem, at: Vector2, amount: float, left: float) -> void:
	var purple := Color(0.62, 0.3, 0.85)
	ci.draw_circle(at, 8.0, Color(0.12, 0.08, 0.16, 0.9))
	ci.draw_arc(at, 8.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(1.0 - left, 0.0, 1.0), 20, purple, 2.2, true)
	ci.draw_string(ThemeDB.fallback_font, at + Vector2(-8.0, 4.0), "%d" % int(amount),
		HORIZONTAL_ALIGNMENT_CENTER, 16.0, 10, Color(0.86, 0.7, 1.0))


const KRAKEN_PURPLE := Color(0.72, 0.3, 0.95)
const KRAKEN_PINK := Color(1.0, 0.45, 0.85)


## One kraken tentacle, rising out of the ground and arching over to its head.
##   base    where it leaves the ground
##   ground  the point on the ground under its head
##   lift    how high the head is held, arch  how high the middle bows (px)
##   aim     unit vector the horn points along
##   sway    sideways wobble (px), out  0..1 how much of it is above ground
static func kraken_arm(ci: CanvasItem, base: Vector2, ground: Vector2, lift: float, arch: float, aim: Vector2,
		tile: float, col: Color, t: float, sway: float = 0.0, out: float = 1.0, ink_col: Color = OUTLINE) -> void:
	var keep := ink
	ink = ink_col
	# the hole it lives in (drawn as a shape, not through draw_set_transform,
	# which would throw away whatever transform the caller set)
	ellipse(ci, base, tile * 0.5, tile * 0.25, Color(0.05, 0.04, 0.1, 0.55), 0.0)
	if out <= 0.02:
		ink = keep
		return
	var g1 := base.lerp(ground, out)
	var along := g1 - base
	var side := Vector2(-along.y, along.x).normalized() if along.length() > 1.0 else Vector2.RIGHT
	var n := 12
	var pts := PackedVector2Array()
	var widths: Array = []
	for i in n + 1:
		var f := float(i) / float(n)
		var h: float = (sin(PI * pow(f, 0.85)) * arch + f * lift) * out
		var wob: float = sin(t * 2.2 + f * 3.0) * tile * 0.06 * f
		pts.append(base.lerp(g1, f * f * (3.0 - 2.0 * f)) + Vector2(wob, -h) + side * sway * sin(PI * f))
		widths.append(tile * (0.66 - 0.3 * f) * (0.55 + 0.45 * out))
	for i in n:
		ci.draw_line(pts[i], pts[i + 1], ink, float(widths[i]) + 5.0, true)
		ci.draw_circle(pts[i + 1], (float(widths[i + 1]) + 5.0) * 0.5, ink)
	for i in n:
		ci.draw_line(pts[i], pts[i + 1], col, float(widths[i]), true)
		ci.draw_circle(pts[i + 1], float(widths[i + 1]) * 0.5, col)
	# paler underside and a few suckers
	var pale := col.lightened(0.4)
	for i in n:
		var off := Vector2(0.0, float(widths[i]) * 0.2)
		ci.draw_line(pts[i] + off, pts[i + 1] + off, pale, float(widths[i]) * 0.34, true)
	for i in range(2, n - 1, 2):
		ci.draw_circle(pts[i] + Vector2(0.0, -float(widths[i]) * 0.2), tile * 0.045, col.darkened(0.3))
	# head, eye and horn
	var head: Vector2 = pts[n]
	var hr: float = tile * 0.3 * (0.55 + 0.45 * out)
	var hb := head + aim * hr * 0.6
	var tip := head + aim * (hr + tile * 0.8)
	var nrm := Vector2(-aim.y, aim.x) * tile * 0.15
	var mid := hb.lerp(tip, 0.38)
	poly(ci, PackedVector2Array([hb + nrm, tip, hb - nrm]), Color(0.97, 0.96, 0.92), 2.0)
	poly(ci, PackedVector2Array([hb + nrm, mid + nrm * 0.62, mid - nrm * 0.62, hb - nrm]), KRAKEN_PURPLE, 0.0)
	circle(ci, head, hr, col.lightened(0.12), 2.2)
	ci.draw_circle(head + Vector2(0.0, -hr * 0.25), hr * 0.34, Color(0.8, 0.92, 0.35))
	ci.draw_circle(head + Vector2(0.0, -hr * 0.25) + aim * hr * 0.1, hr * 0.16, Color(0.06, 0.05, 0.08))
	ink = keep


## A sunk tentacle: only the horn is left sticking out of its hole.
static func kraken_stub(ci: CanvasItem, base: Vector2, tile: float) -> void:
	ellipse(ci, base, tile * 0.5, tile * 0.25, Color(0.05, 0.04, 0.1, 0.55), 0.0)
	var w: float = tile * 0.15
	var top := base + Vector2(tile * 0.08, -tile * 0.7)
	var a := base + Vector2(-w, 0.0)
	var b := base + Vector2(w, 0.0)
	poly(ci, PackedVector2Array([a, top, b]), Color(0.97, 0.96, 0.92), 2.0)
	poly(ci, PackedVector2Array([a, a.lerp(top, 0.38), b.lerp(top, 0.38), b]), KRAKEN_PURPLE, 0.0)


## The kraken's head, seen from above, drawn facing +x in a whirlpool (the caller
## rotates it to face the player's board). pose: "rise" 0..1 how far it is out
## of the water, "mouth" 0..1 how wide the jaws are.
static func kraken_head(ci: CanvasItem, r: float, t: float, pose: Dictionary = {}, ink_col: Color = OUTLINE,
		col: Color = Color(0.2, 0.36, 0.78)) -> void:
	var keep := ink
	ink = ink_col
	var rise: float = clampf(float(pose.get("rise", 1.0)), 0.0, 1.0)
	var mouth: float = clampf(float(pose.get("mouth", 0.0)), 0.0, 1.0)
	# the whirlpool
	ci.draw_circle(Vector2.ZERO, r * 1.55, Color(0.05, 0.08, 0.2, 0.45))
	for i in 4:
		var rr: float = r * (0.7 + 0.28 * float(i))
		var a0: float = t * (1.6 - 0.25 * float(i)) + float(i) * 1.9
		ci.draw_arc(Vector2.ZERO, rr, a0, a0 + 2.2, 20, Color(0.6, 0.75, 1.0, 0.4), 2.0, true)
		ci.draw_arc(Vector2.ZERO, rr, a0 + PI, a0 + PI + 1.6, 16, Color(0.6, 0.75, 1.0, 0.25), 2.0, true)
	if rise <= 0.02:
		ink = keep
		return
	var R: float = r * rise
	var dark := col.darkened(0.45)
	var magenta := Color(0.86, 0.16, 0.52)
	# the crown of spines, fanned out behind the head
	for i in 7:
		var a: float = deg_to_rad(105.0 + 25.0 * float(i)) + sin(t * 1.3 + float(i)) * 0.04
		var d := Vector2(cos(a), sin(a))
		var n := Vector2(-d.y, d.x) * R * 0.17
		var c := Vector2(-R * 0.1, 0.0)
		poly(ci, PackedVector2Array([c + d * R * 0.5 + n, c + d * R * (1.3 + 0.12 * float(i % 2)), c + d * R * 0.5 - n]), dark, 2.0)
	ellipse(ci, Vector2(-R * 0.15, 0.0), R * 0.82, R * 0.74, magenta, 2.4)
	ellipse(ci, Vector2(-R * 0.3, 0.0), R * 0.55, R * 0.5, col.darkened(0.2), 0.0)
	# the two long horns sweeping forward
	for s in [-1.0, 1.0]:
		poly(ci, PackedVector2Array([Vector2(R * 0.25, s * R * 0.32), Vector2(R * 0.3, s * R * 1.0),
			Vector2(R * 1.2, s * R * 1.15), Vector2(R * 0.55, s * R * 0.7), Vector2(R * 0.5, s * R * 0.3)]), dark, 2.0)
	ellipse(ci, Vector2(R * 0.3, 0.0), R * 0.52, R * 0.44, col, 2.4)
	# the mouth: magenta gums, a dark throat and a ring of fangs
	var mc := Vector2(R * 0.72, 0.0)
	var mx: float = R * (0.2 + 0.1 * mouth)
	var my: float = R * (0.24 + 0.1 * mouth)
	ellipse(ci, mc, mx + R * 0.06, my + R * 0.06, magenta, 2.2)
	ellipse(ci, mc, mx * 0.7, my * 0.7, Color(0.12, 0.03, 0.1), 0.0)
	for i in 8:
		var a: float = TAU * (float(i) + 0.5) / 8.0
		var rim := mc + Vector2(cos(a) * mx, sin(a) * my)
		var tn := Vector2(-sin(a), cos(a)) * R * 0.06
		poly(ci, PackedVector2Array([rim + tn, mc + (rim - mc) * 0.45, rim - tn]), Color(0.98, 0.97, 0.93), 1.0)
	for s in [-1.0, 1.0]:
		ci.draw_circle(Vector2(R * 0.36, s * R * 0.25), R * 0.09, Color(1.0, 0.2, 0.2, 0.35))
		ci.draw_circle(Vector2(R * 0.36, s * R * 0.25), R * 0.05, Color(1.0, 0.25, 0.2))
	ink = keep


## The ballista spider, seen from above and drawn facing +x (the caller rotates
## it to face the player's board). r is the body scale; the legs reach about 2r.
## pose: "move" 0..1 how hard the legs are working, "strike" 0..1 progress of a
## front-leg stab, "side" which front leg (+1 / -1), "reach" how far the stab
## goes (in r), "aim" its angle off straight ahead.
static func spider_boss(ci: CanvasItem, r: float, t: float, pose: Dictionary = {}, ink_col: Color = OUTLINE) -> void:
	var keep := ink
	ink = ink_col
	var move: float = float(pose.get("move", 0.0))
	var strike: float = float(pose.get("strike", 0.0))
	var strike_side: float = float(pose.get("side", 1.0))
	var strike_reach: float = float(pose.get("reach", 2.4))
	var strike_aim: float = float(pose.get("aim", 0.0))
	var leg := Color(0.92, 0.48, 0.16)
	var leg_dark := Color(0.62, 0.26, 0.1)
	var gait: float = 3.0 + 17.0 * move
	var swing: float = 0.05 + 0.2 * move
	# --- eight legs: hip on the thorax, knee out and up, foot far out
	var angles: Array = [32.0, 68.0, 108.0, 144.0]
	for s in [-1.0, 1.0]:
		for i in 4:
			var a: float = deg_to_rad(float(angles[i])) + sin(t * gait + float(i) * 1.7 + (0.0 if s > 0.0 else PI)) * swing
			var hip := Vector2(r * (0.28 - 0.14 * float(i)), s * r * 0.2)
			var out := Vector2(cos(a), s * sin(a))
			var knee := hip + out * r * 0.95
			var foot := hip + out * r * (2.05 - 0.12 * float(i))
			if i == 0 and strike > 0.0 and is_equal_approx(s, strike_side):
				# the stab: knee cocks back, then the foot snaps out along the aim
				var jab: float = sin(clampf(strike, 0.0, 1.0) * PI)
				var aim := Vector2(cos(strike_aim), sin(strike_aim))
				knee = knee.lerp(hip + Vector2(r * 0.5, s * r * 0.75), jab)
				foot = foot.lerp(aim * r * strike_reach, jab)
			ci.draw_line(hip, knee, ink, r * 0.17, true)
			ci.draw_line(hip, knee, leg, r * 0.11, true)
			ci.draw_line(knee, foot, ink, r * 0.12, true)
			ci.draw_line(knee, foot, leg.lightened(0.1), r * 0.07, true)
			ci.draw_circle(knee, r * 0.085, leg_dark)
			ci.draw_circle(foot, r * 0.05, leg_dark)
	# --- abdomen: pale yellow-green with a darker saddle and chevrons
	var belly := Vector2(-r * 0.82, 0)
	ellipse(ci, belly, r * 0.82, r * 0.64, Color(0.8, 0.8, 0.32), 2.6)
	ellipse(ci, belly + Vector2(-r * 0.08, 0), r * 0.5, r * 0.34, Color(0.62, 0.66, 0.22), 0.0)
	for i in 3:
		var cx: float = -r * (0.45 + 0.3 * float(i))
		ci.draw_polyline(PackedVector2Array([Vector2(cx, -r * 0.3), Vector2(cx - r * 0.12, 0), Vector2(cx, r * 0.3)]),
			Color(0.97, 0.96, 0.8), r * 0.05, true)
	circle(ci, Vector2(-r * 1.62, 0), r * 0.1, leg_dark, 1.4)
	# --- thorax and head
	ellipse(ci, Vector2(r * 0.08, 0), r * 0.46, r * 0.38, leg.darkened(0.12), 2.4)
	circle(ci, Vector2(r * 0.52, 0), r * 0.26, leg, 2.2)
	# fangs
	for s in [-1.0, 1.0]:
		poly(ci, PackedVector2Array([Vector2(r * 0.68, s * r * 0.08), Vector2(r * 0.98, s * r * 0.12),
			Vector2(r * 0.72, s * r * 0.2)]), Color(0.22, 0.12, 0.1), 1.2)
	# eyes: two big, two small, each with a glint
	for s in [-1.0, 1.0]:
		ci.draw_circle(Vector2(r * 0.6, s * r * 0.1), r * 0.065, Color(0.06, 0.05, 0.08))
		ci.draw_circle(Vector2(r * 0.62, s * r * 0.085), r * 0.02, Color(1, 1, 1))
		ci.draw_circle(Vector2(r * 0.48, s * r * 0.19), r * 0.04, Color(0.06, 0.05, 0.08))
	ink = keep


## A spiderling: the same animal at pocket size, legs going like mad.
static func _spiderling(ci: CanvasItem, r: float, t: float, facing: float) -> void:
	var f := facing if absf(facing) > 0.01 else 1.0
	var body := Color(0.9, 0.5, 0.18)
	for s in [-1.0, 1.0]:
		for i in 4:
			var a: float = deg_to_rad(35.0 + 36.0 * float(i)) + sin(t * 22.0 + float(i) * 1.6 + (0.0 if s > 0.0 else PI)) * 0.25
			var out := Vector2(cos(a) * f, s * sin(a))
			ci.draw_line(Vector2.ZERO, out * r * 0.9, ink, r * 0.16, true)
			ci.draw_line(out * r * 0.9, out * r * 1.5 + Vector2(0, r * 0.15), ink, r * 0.11, true)
	ellipse(ci, Vector2(-r * 0.45 * f, 0), r * 0.62, r * 0.5, Color(0.8, 0.8, 0.32), 1.8)
	circle(ci, Vector2(r * 0.25 * f, 0), r * 0.38, body, 1.8)
	ci.draw_circle(Vector2(r * 0.42 * f, -r * 0.13), r * 0.09, Color(0.06, 0.05, 0.08))
	ci.draw_circle(Vector2(r * 0.42 * f, r * 0.13), r * 0.09, Color(0.06, 0.05, 0.08))


## A spider egg: a pale silk sac that twitches now and then, anchored by threads.
static func _spideregg(ci: CanvasItem, r: float, t: float) -> void:
	var twitch := sin(t * 3.0) * r * 0.03 + (sin(t * 23.0) * r * 0.03 if fmod(t, 2.4) < 0.3 else 0.0)
	for i in 6:
		var a := TAU * float(i) / 6.0 + 0.3
		ci.draw_line(Vector2(cos(a), sin(a)) * r * 0.7, Vector2(cos(a), sin(a)) * r * 1.5, Color(1, 1, 1, 0.55), 1.4, true)
	ellipse(ci, Vector2(twitch, 0), r * 0.82, r * 1.0, Color(0.95, 0.94, 0.86), 2.2)
	ellipse(ci, Vector2(-r * 0.2 + twitch, -r * 0.3), r * 0.3, r * 0.4, Color(1, 1, 1, 0.7), 0.0)
	for i in 4:
		var p := Vector2(cos(float(i) * 2.3) * r * 0.4 + twitch, sin(float(i) * 1.9 + 0.6) * r * 0.55)
		ci.draw_circle(p, r * 0.09, Color(0.55, 0.42, 0.3, 0.55))


## One tile of webbing: spokes and two rings of silk across the tile's rect.
static func web_tile(ci: CanvasItem, rect: Rect2) -> void:
	var c := rect.get_center()
	var h := rect.size * 0.5
	var silk := Color(1.0, 1.0, 1.0, 0.62)
	ci.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.1), true)
	for i in 8:
		var a := TAU * float(i) / 8.0
		var d := Vector2(cos(a), sin(a))
		var edge: float = minf(h.x / maxf(absf(d.x), 0.001), h.y / maxf(absf(d.y), 0.001))
		ci.draw_line(c, c + d * edge, silk, 1.2, true)
	for ring in [0.42, 0.8]:
		var pts := PackedVector2Array()
		for i in 9:
			var a2 := TAU * float(i) / 8.0
			pts.append(c + Vector2(cos(a2), sin(a2)) * h.x * float(ring))
		ci.draw_polyline(pts, silk, 1.2, true)


## A ballista trap on a bridge: a silk sling drawn taut between four pegs, with
## a pulsing pad in the middle. Whatever steps on it leaves by air.
static func ballista_trap(ci: CanvasItem, at: Vector2, tile: float, t: float) -> void:
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	var peg := tile * 0.62
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var corner: Vector2 = at + Vector2(s.x, s.y) * peg
		ci.draw_line(corner, at, Color(1.0, 1.0, 1.0, 0.75), 2.0, true)
		ci.draw_circle(corner, tile * 0.09, Color(0.42, 0.28, 0.18))
	ci.draw_circle(at, tile * (0.3 + 0.04 * pulse), Color(0.62, 0.3, 0.85, 0.35 + 0.25 * pulse))
	ci.draw_arc(at, tile * (0.3 + 0.04 * pulse), 0.0, TAU, 20, Color(0.95, 0.9, 1.0, 0.9), 2.0, true)
	ci.draw_arc(at, tile * 0.55, 0.0, TAU, 24, Color(1.0, 1.0, 1.0, 0.35), 1.2, true)


## Shiesty: a small goblin swallowed by a ragged hood, ears out the sides, eyes
## glinting in the shadow, the loot sack over his shoulder.
static func shiesty(ci: CanvasItem, r: float, facing: float, t: float, ink_col: Color = OUTLINE) -> void:
	var keep := ink
	ink = ink_col
	var f := facing if absf(facing) > 0.01 else 1.0
	var bob := sin(t * 12.0) * r * 0.1
	var skin := Color(0.45, 0.7, 0.32)
	var hood := Color(0.72, 0.58, 0.36)
	var cloak := Color(0.38, 0.28, 0.2)
	# sack, slung behind
	circle(ci, Vector2(-r * 0.85 * f, r * 0.15 + bob), r * 0.42, Color(0.82, 0.7, 0.4), 1.6)
	ci.draw_line(Vector2(-r * 0.6 * f, -r * 0.15 + bob), Vector2(-r * 0.1 * f, -r * 0.2 + bob), cloak.darkened(0.2), r * 0.1, true)
	# feet
	ellipse(ci, Vector2(-r * 0.25 * f, r * 0.95), r * 0.24, r * 0.1, skin.darkened(0.25), 1.2)
	ellipse(ci, Vector2(r * 0.3 * f, r * 0.95), r * 0.24, r * 0.1, skin.darkened(0.25), 1.2)
	# cloak with a ragged hem
	poly(ci, PackedVector2Array([Vector2(-r * 0.4, -r * 0.25 + bob), Vector2(r * 0.4, -r * 0.25 + bob),
		Vector2(r * 0.8, r * 0.7), Vector2(r * 0.5, r * 0.6), Vector2(r * 0.3, r * 0.88), Vector2(r * 0.05, r * 0.66),
		Vector2(-r * 0.2, r * 0.9), Vector2(-r * 0.45, r * 0.62), Vector2(-r * 0.8, r * 0.74)]), cloak, 1.8)
	# a clawed hand creeping out in front
	ci.draw_line(Vector2(r * 0.35 * f, r * 0.1 + bob), Vector2(r * 0.85 * f, r * 0.3 + bob), skin, r * 0.16, true)
	# ears out through the hood
	var head := Vector2(r * 0.1 * f, -r * 0.5 + bob)
	for s in [-1.0, 1.0]:
		poly(ci, PackedVector2Array([head + Vector2(s * r * 0.4, r * 0.05), head + Vector2(s * r * 1.25, -r * 0.5),
			head + Vector2(s * r * 0.45, -r * 0.3)]), skin, 1.6)
		poly(ci, PackedVector2Array([head + Vector2(s * r * 0.52, -r * 0.05), head + Vector2(s * r * 1.0, -r * 0.4),
			head + Vector2(s * r * 0.55, -r * 0.22)]), Color(0.8, 0.45, 0.28), 0.0)
	# hood: a low wide peak pulled down over the face
	poly(ci, PackedVector2Array([head + Vector2(-r * 0.62, r * 0.28), head + Vector2(-r * 0.5, -r * 0.3),
		head + Vector2(r * 0.05 * f, -r * 0.72), head + Vector2(r * 0.5, -r * 0.3), head + Vector2(r * 0.62, r * 0.28),
		head + Vector2(0, r * 0.48)]), hood, 1.8)
	# the face in its shadow: two slit eyes and a smirk
	ellipse(ci, head + Vector2(r * 0.06 * f, r * 0.08), r * 0.36, r * 0.27, Color(0.16, 0.12, 0.1), 0.0)
	for s in [-1.0, 1.0]:
		var e := head + Vector2(s * r * 0.15 + r * 0.06 * f, r * 0.03)
		ci.draw_line(e + Vector2(-r * 0.08, s * r * 0.03 * f), e + Vector2(r * 0.08, -s * r * 0.03 * f), Color(1.0, 0.86, 0.3), r * 0.09, true)
	ci.draw_arc(head + Vector2(r * 0.08 * f, r * 0.12), r * 0.16, 0.25, PI - 0.6, 8, Color(0.85, 0.75, 0.55), 1.2, true)
	ink = keep


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

## Penny for the card and the deploy ghost: the plain trot.
static func _penny(ci: CanvasItem, r: float, t: float, facing: float) -> void:
	penny(ci, r, facing, t, 0, 0.0, ink)


## Penny: a scrappy calico cat on all fours. White fur with orange and charcoal
## patches, gold eyes under a wicked brow, a fanged grin, a ringed ear, a red
## collar and a band on her foreleg in her team's colour (band_col).
## pose: 0 trot, 1 the startled hop back, 2 the arched, stiff-legged sideways run
## (the quarter circle; the tail swaps between a puffed brush held up and a hook
## hanging down), 3 the leap with both forepaws reaching out. pf is the 0..1
## progress through poses 1-3. Everything is laid out facing right, then mirrored
## by facing and tilted about the body centre (_pp).
static func penny(ci: CanvasItem, r: float, facing: float, t: float, pose: int = 0, pf: float = 0.0, ink_col: Color = OUTLINE, band_col: Color = Color(0.8, 0.14, 0.13)) -> void:
	ink = ink_col
	var f := facing if absf(facing) > 0.01 else 1.0
	var white := Color(0.97, 0.94, 0.88)
	var orange := Color(0.93, 0.5, 0.18)
	var coal := Color(0.27, 0.23, 0.28)
	var far_fur := Color(0.78, 0.72, 0.68)
	var red := Color(0.8, 0.14, 0.13)
	var g := t * 9.0
	var arch := 0.0      # how far the spine humps up, in r
	var tilt := 0.0      # nose up (+) / down (-), radians
	var stretch := 1.0   # body length in the leap
	var raise := 0.0     # stiff legs lift the body, in r
	var scare := 0.0     # ears back, fur up, hissing
	var wide := 0.0      # round pupils
	var bob := 0.0
	# foot positions: far hind, far front, near hind, near front
	var feet: Array[Vector2] = []
	match pose:
		1:
			# straight up and back off the ground: legs stiff, spine humping
			arch = 0.2 + 0.2 * pf
			raise = 0.08 + 0.08 * pf
			scare = 0.6 + 0.4 * pf
			wide = 1.0
			tilt = 0.2 * sin(pf * PI)
			feet = [Vector2(-0.62, 1.0), Vector2(0.4, 1.0), Vector2(-0.72, 1.02), Vector2(0.52, 1.02)]
		2:
			# the Halloween crab run: full arch, stiff legs stepping on tiptoe in
			# diagonal pairs, the body rocking a little over each step
			arch = 0.42
			raise = 0.1
			scare = 1.0
			wide = 1.0
			var gs := pf * TAU * 2.5
			tilt = sin(gs) * 0.04
			bob = -absf(sin(gs)) * 0.03
			for leg in 4:
				var sx: float = [-0.68, 0.44, -0.8, 0.6][leg]
				var sp: float = [0.0, PI, PI, 0.0][leg]
				feet.append(Vector2(sx + sin(gs + sp) * 0.16, 1.04 - maxf(0.0, cos(gs + sp)) * 0.12))
		3:
			# the leap: long body, forepaws reaching out together, hind legs trailing
			stretch = 1.18
			tilt = lerpf(0.24, -0.2, pf)
			wide = 1.0
			feet = [Vector2(-1.18, 0.66), Vector2(1.22, 0.46), Vector2(-1.3, 0.54), Vector2(1.38, 0.36)]
		_:
			bob = -absf(sin(g)) * 0.05
			for leg in 4:
				var hx: float = [-0.55, 0.4, -0.55, 0.4][leg]
				# diagonal pairs move together: near front with far hind
				var ph: float = [0.0, PI, PI, 0.0][leg]
				feet.append(Vector2(hx + sin(g + ph) * 0.22, 1.02 - maxf(0.0, cos(g + ph)) * 0.14))
	var bc := Vector2(-0.12, 0.28 - raise + bob) * r
	var brx := 0.8 * stretch * r
	var bry := 0.42 * r
	var piv := bc
	# the spine bends up in the middle; anything sitting on the body bends with it
	var bend := func(p: Vector2) -> Vector2:
		var u := clampf((p.x - bc.x) / brx, -1.0, 1.0)
		return Vector2(p.x, p.y - arch * r * (1.0 - u * u))
	var P := func(p: Vector2) -> Vector2:
		return _pp(p, f, piv, tilt)
	var hind_hip: Vector2 = bend.call(bc + Vector2(-0.5 * stretch * r, 0.16 * r))
	var front_hip: Vector2 = bend.call(bc + Vector2(0.46 * stretch * r, 0.16 * r))
	var leg_w := r * 0.24
	# far legs, behind everything
	_penny_leg(ci, P.call(hind_hip + Vector2(0.06 * r, 0.0)), P.call(feet[0] * r), leg_w, coal.darkened(0.25), coal.darkened(0.25), false)
	_penny_leg(ci, P.call(front_hip + Vector2(-0.06 * r, 0.0)), P.call(feet[1] * r), leg_w, far_fur, far_fur, pose >= 2)
	# tail: confident curl when trotting, a bottle brush when scared, a rudder in the leap
	var tb: Vector2 = bend.call(bc + Vector2(-0.7 * stretch * r, -0.06 * r))
	var sway := sin(t * 3.0) * 0.12
	var tail_raw: Array[Vector2] = []
	# 0 = brush held straight up, 1 = hanging hook; the crab run swaps between them
	var droop := 0.0
	if pose == 2:
		droop = 0.5 - 0.5 * cos(pf * TAU * 1.5)
	if pose == 3:
		tail_raw = [Vector2(0, 0), Vector2(-0.24, -0.02), Vector2(-0.48, -0.06), Vector2(-0.72, -0.1),
			Vector2(-0.96, -0.1), Vector2(-1.2, -0.06)]
	elif scare > 0.0:
		var wob := sin(t * 14.0) * 0.04 * (1.0 - droop)
		var up: Array[Vector2] = [Vector2(0, 0), Vector2(-0.12, -0.22), Vector2(-0.16, -0.46), Vector2(-0.12 + wob, -0.7),
			Vector2(-0.06 + wob, -0.96), Vector2(0.04 + wob * 1.5, -1.2)]
		var down: Array[Vector2] = [Vector2(0, 0), Vector2(-0.2, -0.26), Vector2(-0.42, -0.34), Vector2(-0.58, -0.16),
			Vector2(-0.64, 0.14), Vector2(-0.58, 0.44)]
		for i in up.size():
			tail_raw.append(up[i].lerp(down[i], droop))
	else:
		tail_raw = [Vector2(0, 0), Vector2(-0.28, -0.04), Vector2(-0.48, -0.22), Vector2(-0.56 + sway, -0.48),
			Vector2(-0.48 + sway * 1.3, -0.74), Vector2(-0.3 + sway * 1.6, -0.9)]
	var tail := PackedVector2Array()
	for p in tail_raw:
		tail.append(P.call(tb + p * r))
	# the fur only stands up while the tail does
	var poof := scare * (1.0 - 0.75 * droop)
	var tw := r * (0.24 + 0.16 * poof)
	ci.draw_polyline(tail, ink, tw + OUTLINE_W * 2.0, true)
	for i in tail.size():
		ci.draw_circle(tail[i], (tw + OUTLINE_W * 2.0) * 0.5, ink)
	# orange root, white middle, charcoal tip
	for i in tail.size() - 1:
		var tf := float(i + 1) / float(tail.size() - 1)
		var tc := orange if tf < 0.5 else (white if tf < 0.85 else coal)
		ci.draw_line(tail[i], tail[i + 1], tc, tw, true)
		ci.draw_circle(tail[i + 1], tw * 0.5, tc)
	if poof > 0.3:
		# bristles all down the brush
		for i in range(1, tail.size()):
			var d: Vector2 = (tail[i] - tail[i - 1]).normalized()
			var n := Vector2(-d.y, d.x)
			for s in [-1.0, 1.0]:
				var root: Vector2 = tail[i] - d * tw * 0.4
				ci.draw_line(root + n * s * tw * 0.4, root + n * s * tw * (0.5 + 0.35 * poof) - d * tw * 0.3, ink, 1.4, true)
	# hackles: a ridge of spikes along the arched spine, under the body fill
	if scare > 0.0:
		for i in 7:
			var x := lerpf(-0.62, 0.38, float(i) / 6.0) * brx
			var u := x / brx
			var top: Vector2 = bend.call(bc + Vector2(x, -bry * sqrt(maxf(0.0, 1.0 - u * u))))
			var hgt := r * 0.2 * scare
			poly(ci, PackedVector2Array([P.call(top + Vector2(-0.09 * r, 0.06 * r)),
				P.call(top + Vector2(-0.03 * r, -hgt)), P.call(top + Vector2(0.07 * r, 0.06 * r))]),
				orange if i < 4 else white, 1.6)
	# body with its patches, outlined last so the patches sit inside it
	var body := _penny_blob(bc, brx, bry, bend, P)
	ci.draw_colored_polygon(body, white)
	ci.draw_colored_polygon(_penny_blob(bc + Vector2(-0.3 * brx, -0.1 * r), 0.42 * r * stretch, 0.24 * r, bend, P), orange)
	ci.draw_colored_polygon(_penny_blob(bc + Vector2(0.14 * brx, -0.16 * r), 0.24 * r * stretch, 0.15 * r, bend, P), coal)
	ci.draw_colored_polygon(_penny_blob(bc + Vector2(-0.72 * brx, 0.08 * r), 0.2 * r, 0.2 * r, bend, P), coal)
	var loop := body.duplicate()
	loop.append(body[0])
	ci.draw_polyline(loop, ink, OUTLINE_W, true)
	# near legs
	_penny_leg(ci, P.call(hind_hip), P.call(feet[2] * r), leg_w * 1.08, coal, white, false)
	var nf_hip: Vector2 = P.call(front_hip)
	var nf_paw: Vector2 = P.call(feet[3] * r)
	_penny_leg(ci, nf_hip, nf_paw, leg_w * 1.08, white, white, pose >= 2)
	# team-coloured band above the paw
	ci.draw_line(nf_hip.lerp(nf_paw, 0.6), nf_hip.lerp(nf_paw, 0.8), ink, leg_w * 1.08 + OUTLINE_W * 2.0, true)
	ci.draw_line(nf_hip.lerp(nf_paw, 0.6), nf_hip.lerp(nf_paw, 0.8), band_col, leg_w * 1.08, true)
	# head
	var hc := Vector2((-0.12 + 0.88 * stretch) * r, (-0.25 - raise + 0.12 * scare) * r) + Vector2(0.0, bob * r)
	if pose == 3:
		hc += Vector2(0.06, 0.04) * r
	# collar
	var neck_a: Vector2 = hc + Vector2(-0.3, -0.12) * r
	var neck_b: Vector2 = hc + Vector2(-0.14, 0.4) * r
	ci.draw_line(P.call(neck_a), P.call(neck_b), ink, r * 0.12 + OUTLINE_W * 2.0, true)
	ci.draw_line(P.call(neck_a), P.call(neck_b), red, r * 0.12, true)
	# far ear
	var far_tip: Vector2 = Vector2(0.3, -0.86).lerp(Vector2(-0.3, -0.6), scare)
	poly(ci, PackedVector2Array([P.call(hc + Vector2(0.06, -0.34) * r), P.call(hc + far_tip * r),
		P.call(hc + Vector2(0.34, -0.24) * r)]), coal, 1.8)
	# cheek ruff
	for i in 3:
		var y := (-0.02 + 0.16 * float(i)) * r
		poly(ci, PackedVector2Array([P.call(hc + Vector2(-0.36 * r, y - 0.08 * r)),
			P.call(hc + Vector2(-0.62 * r, y + 0.02 * r + 0.06 * r * scare)), P.call(hc + Vector2(-0.34 * r, y + 0.08 * r))]), white, 1.6)
	# head: white, orange cap, a charcoal patch around the eye
	var no_bend := func(p: Vector2) -> Vector2:
		return p
	var head := _penny_blob(hc, 0.48 * r, 0.42 * r, no_bend, P)
	ci.draw_colored_polygon(head, white)
	ci.draw_colored_polygon(_penny_blob(hc + Vector2(-0.12, -0.16) * r, 0.32 * r, 0.21 * r, no_bend, P), orange)
	ci.draw_colored_polygon(_penny_blob(hc + Vector2(0.14, -0.1) * r, 0.17 * r, 0.15 * r, no_bend, P), coal)
	ci.draw_colored_polygon(_penny_blob(hc + Vector2(0.33, 0.12) * r, 0.17 * r, 0.12 * r, no_bend, P), white)
	var hloop := head.duplicate()
	hloop.append(head[0])
	ci.draw_polyline(hloop, ink, OUTLINE_W, true)
	# near ear: orange with a pink inside and a gold ring through it
	var near_tip: Vector2 = Vector2(-0.2, -0.92).lerp(Vector2(-0.74, -0.42), scare)
	var ea := hc + Vector2(-0.34, -0.2) * r
	var eb := hc + Vector2(0.02, -0.36) * r
	var et := hc + near_tip * r
	poly(ci, PackedVector2Array([P.call(ea), P.call(et), P.call(eb)]), orange, 1.8)
	ci.draw_colored_polygon(PackedVector2Array([P.call(ea.lerp(eb, 0.3).lerp(et, 0.15)),
		P.call(et.lerp(ea.lerp(eb, 0.5), 0.25)), P.call(ea.lerp(eb, 0.75).lerp(et, 0.1))]), Color(0.93, 0.62, 0.62))
	ci.draw_arc(P.call(eb.lerp(et, 0.22)), r * 0.08, 0.0, TAU, 12, Color(0.96, 0.78, 0.28), 1.6, true)
	# eye: gold almond, slit pupil (round and huge when startled or pouncing)
	var eye := hc + Vector2(0.18, -0.1) * r
	ci.draw_colored_polygon(_penny_blob(eye, 0.13 * r, (0.08 + 0.04 * wide) * r, no_bend, P), Color(0.98, 0.84, 0.18))
	var pupil: Vector2 = P.call(eye + Vector2(0.03, 0.0) * r)
	ellipse(ci, pupil, r * lerpf(0.025, 0.07, wide), r * lerpf(0.08, 0.075, wide), Color(0.1, 0.08, 0.1), 0.0)
	ci.draw_circle(pupil + Vector2(-0.03 * f, -0.03) * r, r * 0.025, Color(1, 1, 1))
	# the wicked brow (raised in surprise when scared)
	ci.draw_line(P.call(hc + Vector2(0.02, -0.24 - 0.08 * scare) * r), P.call(hc + Vector2(0.32, -0.16 - 0.1 * scare) * r), ink, r * 0.06, true)
	# nose
	poly(ci, PackedVector2Array([P.call(hc + Vector2(0.42, -0.02) * r), P.call(hc + Vector2(0.52, -0.02) * r),
		P.call(hc + Vector2(0.48, 0.05) * r)]), Color(0.55, 0.25, 0.3), 1.0)
	if scare > 0.3:
		# hissing: mouth open, both fangs out
		var m0: Vector2 = P.call(hc + Vector2(0.46, 0.08) * r)
		var m1: Vector2 = P.call(hc + Vector2(0.16, 0.14) * r)
		var m2: Vector2 = P.call(hc + Vector2(0.36, 0.34) * r)
		poly(ci, PackedVector2Array([m0, m1, m2]), Color(0.5, 0.1, 0.14), 1.6)
		for fx in [0.24, 0.4]:
			poly(ci, PackedVector2Array([P.call(hc + Vector2(fx - 0.03, 0.12) * r), P.call(hc + Vector2(fx + 0.03, 0.1) * r),
				P.call(hc + Vector2(fx, 0.2) * r)]), white, 1.0)
	else:
		# the grin, one fang hanging over the lip
		ci.draw_polyline(PackedVector2Array([P.call(hc + Vector2(0.47, 0.05) * r), P.call(hc + Vector2(0.42, 0.16) * r),
			P.call(hc + Vector2(0.26, 0.2) * r), P.call(hc + Vector2(0.12, 0.12) * r)]), ink, r * 0.05, true)
		poly(ci, PackedVector2Array([P.call(hc + Vector2(0.33, 0.18) * r), P.call(hc + Vector2(0.39, 0.18) * r),
			P.call(hc + Vector2(0.36, 0.29) * r)]), white, 1.0)
	# whiskers, swept back when scared
	for wy in [-0.04, 0.12]:
		ci.draw_line(P.call(hc + Vector2(0.38, 0.06) * r), P.call(hc + Vector2(0.86 - 0.3 * scare, wy - 0.1 * scare) * r), ink, 1.1, true)


## Penny's layout point → screen: mirror by facing, then tilt about the body centre.
static func _pp(p: Vector2, f: float, piv: Vector2, tilt: float) -> Vector2:
	var q := Vector2(p.x * f, p.y)
	var c := Vector2(piv.x * f, piv.y)
	return c + (q - c).rotated(-tilt * f)


## An ellipse in Penny's layout space, bent with her spine and mapped to screen.
static func _penny_blob(c: Vector2, rx: float, ry: float, bend: Callable, to_screen: Callable) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		pts.append(to_screen.call(bend.call(c + Vector2(cos(a) * rx, sin(a) * ry))))
	return pts


## One of Penny's legs, hip to paw (screen space). Claws out when she means it.
static func _penny_leg(ci: CanvasItem, hip: Vector2, paw: Vector2, w: float, col: Color, paw_col: Color, claws: bool) -> void:
	ci.draw_line(hip, paw, ink, w + OUTLINE_W * 2.0, true)
	ci.draw_line(hip, paw, col, w, true)
	if claws:
		var d := (paw - hip).normalized()
		for s in [-0.6, 0.0, 0.6]:
			var c := d.rotated(s)
			ci.draw_line(paw + c * w * 0.45, paw + c * w * 0.95, Color(0.12, 0.1, 0.12), 1.4, true)
	circle(ci, paw, w * 0.62, paw_col, 1.6)


## Troll: a hunched, pot-bellied swamp troll. Khaki warty skin, moss hanging off
## his head, shoulders and hips, twigs in his hair, huge red-rimmed yellow eyes, a
## long drooping nose, an underbite, and a tufted tail. He holds a whole tree
## near the middle of the trunk, roots behind his hands and the crown in front.
## club: 0 = just struck (crown down in front), 1 = raised over his head; ~0.45 is
## the walking carry.
static func troll(ci: CanvasItem, r: float, facing: float, t: float, club: float = 0.45, ink_col: Color = OUTLINE) -> void:
	ink = ink_col
	var f := facing if absf(facing) > 0.01 else 1.0
	var skin := Color(0.74, 0.68, 0.47)
	var skin_dark := Color(0.6, 0.54, 0.36)
	var belly := Color(0.82, 0.77, 0.58)
	var moss := Color(0.45, 0.53, 0.2)
	var moss_dark := Color(0.32, 0.4, 0.14)
	var bark := Color(0.42, 0.29, 0.18)
	var bark_dark := Color(0.3, 0.2, 0.12)
	var leaf := Color(0.36, 0.56, 0.22)
	var sway := sin(t * 2.2) * r * 0.03
	var X := func(x: float, y: float) -> Vector2:
		return Vector2(x * f * r, y * r + sway)
	# tail, curling down behind him with a grassy tuft
	var tw := sin(t * 2.6) * 0.08
	var tail := PackedVector2Array([X.call(-0.5, 0.5), X.call(-0.95, 0.85), X.call(-1.3, 0.78 + tw), X.call(-1.45, 0.45 + tw)])
	ci.draw_polyline(tail, ink, r * 0.12 + OUTLINE_W * 2.0, true)
	ci.draw_polyline(tail, skin_dark, r * 0.12, true)
	for k in 4:
		var a := -PI * 0.5 + (float(k) - 1.5) * 0.35
		ci.draw_line(tail[3], tail[3] + Vector2(cos(a) * 0.9 * f, sin(a)) * r * 0.32, moss_dark, r * 0.08, true)
	# back leg and foot
	ci.draw_line(X.call(-0.28, 0.5), X.call(-0.32, 0.98), ink, r * 0.36 + OUTLINE_W * 2.0, true)
	ci.draw_line(X.call(-0.28, 0.5), X.call(-0.32, 0.98), skin_dark, r * 0.36, true)
	ellipse(ci, X.call(-0.2, 1.04), r * 0.32, r * 0.13, skin_dark)
	# the tree: grip near the middle of the trunk, swung from in front up over his head
	var ang := lerpf(0.35, -2.3, clampf(club, 0.0, 1.0))
	var d := Vector2(cos(ang) * f, sin(ang))
	var grip: Vector2 = X.call(0.45, 0.12).lerp(X.call(0.05, -0.75), clampf(club, 0.0, 1.0))
	var root_end := grip - d * r * 1.15
	var top := grip + d * r * 2.7
	var n := Vector2(-d.y, d.x)
	# far arm, behind the body, to the back hand on the trunk
	var back_hand := grip - d * r * 0.3
	ci.draw_line(X.call(-0.32, -0.32), back_hand, ink, r * 0.26 + OUTLINE_W * 2.0, true)
	ci.draw_line(X.call(-0.32, -0.32), back_hand, skin_dark, r * 0.26, true)
	# body: a pear with a pot belly
	ellipse(ci, X.call(0.0, 0.12), r * 0.74, r * 0.72, skin)
	ellipse(ci, X.call(0.2, 0.3), r * 0.46, r * 0.44, belly, 0.0)
	for w in [[0.3, 0.18, 0.05], [0.1, 0.42, 0.04], [-0.35, 0.0, 0.05], [0.42, 0.45, 0.035]]:
		ci.draw_circle(X.call(float(w[0]), float(w[1])), r * float(w[2]), skin_dark)
	# moss skirt
	var skirt := PackedVector2Array()
	for i in 11:
		var x := lerpf(-0.72, 0.68, float(i) / 10.0)
		skirt.append(X.call(x, 0.42 + (0.28 if i % 2 == 0 else 0.16) + 0.05 * sin(float(i) * 1.7)))
	skirt.append(X.call(0.62, 0.36))
	skirt.append(X.call(-0.66, 0.34))
	poly(ci, skirt, moss, 1.8)
	# front leg and the big flat foot
	ci.draw_line(X.call(0.22, 0.55), X.call(0.28, 0.98), ink, r * 0.4 + OUTLINE_W * 2.0, true)
	ci.draw_line(X.call(0.22, 0.55), X.call(0.28, 0.98), skin, r * 0.4, true)
	ellipse(ci, X.call(0.42, 1.05), r * 0.38, r * 0.15, skin)
	for k in 3:
		ci.draw_circle(X.call(0.58 + 0.1 * float(k), 1.02), r * 0.045, Color(0.88, 0.78, 0.66))
	# moss cloak over the shoulders and back, ragged at the hem
	var cloak := PackedVector2Array([X.call(-0.78, -0.3), X.call(-0.5, -0.64), X.call(-0.05, -0.76), X.call(0.34, -0.62)])
	for i in 9:
		var x := lerpf(0.34, -0.8, float(i) / 8.0)
		cloak.append(X.call(x, -0.22 + (0.22 if i % 2 == 0 else 0.06) + 0.14 * absf(x)))
	poly(ci, cloak, moss, 1.8)
	for k in 4:
		var x := -0.6 + 0.22 * float(k)
		ci.draw_line(X.call(x, -0.5), X.call(x - 0.04, -0.12 + 0.1 * absf(x)), moss_dark, 1.6, true)
	# the tree trunk, tapering toward the crown
	var trunk := PackedVector2Array([root_end + n * r * 0.17, top + n * r * 0.1, top - n * r * 0.1, root_end - n * r * 0.17])
	poly(ci, trunk, bark, 2.0)
	ci.draw_line(root_end.lerp(top, 0.15) + n * r * 0.04, root_end.lerp(top, 0.7) + n * r * 0.03, bark_dark, 1.6, true)
	# roots splaying out of the back end
	for s in [-1.0, 0.0, 1.0]:
		var rd: Vector2 = (-d).rotated(float(s) * 0.6)
		ci.draw_line(root_end, root_end + rd * r * 0.32, ink, r * 0.07 + OUTLINE_W * 1.6, true)
		ci.draw_line(root_end, root_end + rd * r * 0.32, bark, r * 0.07, true)
	# crown: snapped branches with clumps of leaves
	for s in [-1.0, 1.0]:
		var bfrom := root_end.lerp(top, 0.82)
		var bto: Vector2 = bfrom + d.rotated(float(s) * 0.7) * r * 0.65
		ci.draw_line(bfrom, bto, ink, r * 0.08 + OUTLINE_W * 1.6, true)
		ci.draw_line(bfrom, bto, bark, r * 0.08, true)
		circle(ci, bto, r * 0.2, leaf, 1.8)
	circle(ci, top + d * r * 0.12, r * 0.28, leaf, 2.0)
	circle(ci, top + d * r * 0.05 + n * r * 0.2, r * 0.17, leaf.lightened(0.12), 1.6)
	# hands: back one first, front one over the trunk
	circle(ci, back_hand, r * 0.17, skin_dark, 1.8)
	var front_hand := grip + d * r * 0.12
	ci.draw_line(X.call(0.3, -0.3), front_hand, ink, r * 0.28 + OUTLINE_W * 2.0, true)
	ci.draw_line(X.call(0.3, -0.3), front_hand, skin, r * 0.28, true)
	circle(ci, front_hand, r * 0.19, skin, 1.8)
	for k in 3:
		var nail := front_hand + n * r * (0.1 * (float(k) - 1.0)) + d * r * 0.16
		ci.draw_circle(nail, r * 0.04, Color(0.9, 0.8, 0.66))
	# head, hunched forward and low
	var hc: Vector2 = X.call(0.42, -0.62)
	# droopy ear at the back of the head
	poly(ci, PackedVector2Array([hc + Vector2(-0.12 * f, -0.12) * r, hc + Vector2(-0.6 * f, -0.3) * r,
		hc + Vector2(-0.18 * f, 0.08) * r]), skin, 1.8)
	ellipse(ci, hc, r * 0.46, r * 0.42, skin)
	# mossy hair with twigs poking out
	var hair := PackedVector2Array([hc + Vector2(-0.44 * f, 0.02) * r])
	for i in 7:
		var a := lerpf(PI, PI * 1.85, float(i) / 6.0)
		var rad := 0.46 if i % 2 == 0 else 0.6
		hair.append(hc + Vector2(cos(a) * 0.45 * f * (1.0 if i % 2 == 0 else 1.15), sin(a) * rad) * r + Vector2(-0.04 * f, -0.06) * r)
	hair.append(hc + Vector2(0.22 * f, -0.26) * r)
	poly(ci, hair, moss, 1.8)
	for tw2 in [[-0.2, -0.5, -0.4, -0.92], [0.05, -0.55, 0.12, -0.98]]:
		var ta: Vector2 = hc + Vector2(float(tw2[0]) * f, float(tw2[1])) * r
		var tb: Vector2 = hc + Vector2(float(tw2[2]) * f, float(tw2[3])) * r
		ci.draw_line(ta, tb, bark, r * 0.05, true)
		ci.draw_line(ta.lerp(tb, 0.55), ta.lerp(tb, 0.55) + Vector2(0.14 * f, -0.08) * r, bark, r * 0.04, true)
	# eyes: huge, yellow, red-rimmed and bloodshot
	for e in [[0.08, -0.08, 0.15], [0.32, -0.1, 0.12]]:
		var ec: Vector2 = hc + Vector2(float(e[0]) * f, float(e[1])) * r
		circle(ci, ec, r * (float(e[2]) + 0.03), Color(0.85, 0.5, 0.45), 1.6)
		ci.draw_circle(ec, r * float(e[2]), Color(0.98, 0.84, 0.3))
		ci.draw_circle(ec + Vector2(0.03 * f, 0.0) * r, r * float(e[2]) * 0.45, Color(0.12, 0.08, 0.06))
		ci.draw_circle(ec + Vector2(-0.02 * f, -0.04) * r, r * 0.03, Color(1, 1, 1))
	# long drooping nose
	var nose_a: Vector2 = hc + Vector2(0.22 * f, -0.02) * r
	var nose_b: Vector2 = hc + Vector2(0.5 * f, 0.24) * r
	ci.draw_line(nose_a, nose_b, ink, r * 0.2 + OUTLINE_W * 2.0, true)
	ci.draw_circle(nose_b, r * 0.15 + OUTLINE_W, ink)
	ci.draw_line(nose_a, nose_b, skin, r * 0.2, true)
	ci.draw_circle(nose_b, r * 0.15, skin)
	ci.draw_circle(nose_b + Vector2(-0.04 * f, 0.03) * r, r * 0.035, skin_dark)
	# lip and underbite teeth
	ellipse(ci, hc + Vector2(0.18 * f, 0.3) * r, r * 0.2, r * 0.07, Color(0.72, 0.45, 0.42), 1.6)
	for tx in [0.08, 0.24]:
		poly(ci, PackedVector2Array([hc + Vector2((float(tx) - 0.04) * f, 0.26) * r, hc + Vector2((float(tx) + 0.04) * f, 0.26) * r,
			hc + Vector2(float(tx) * f, 0.16) * r]), Color(0.96, 0.93, 0.8), 1.2)


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


## A slab of a sword from hilt to tip, w wide: one straight edge, one slanted
## point, a dark grip behind the guard. Used on Laniakea's back and, by the
## unit itself, for the blade in mid-swing.
static func greatsword(ci: CanvasItem, hilt: Vector2, tip: Vector2, w: float, ink_col: Color = OUTLINE) -> void:
	var keep := ink
	ink = ink_col
	var d := tip - hilt
	if d.length() < 0.01:
		ink = keep
		return
	var n := d.normalized()
	var s := n.orthogonal() * w * 0.5
	ci.draw_line(hilt - n * w * 0.9, hilt, Color(0.2, 0.19, 0.24), w * 0.3, true)
	poly(ci, PackedVector2Array([hilt + s, hilt + d * 0.8 + s, hilt + d - s, hilt - s]),
		Color(0.72, 0.74, 0.79), 1.8)
	ci.draw_line(hilt + d * 0.08, hilt + d * 0.74 + s * 0.15, Color(0.52, 0.54, 0.6), w * 0.16, true)
	ci.draw_line(hilt + s * 1.5, hilt - s * 1.5, Color(0.3, 0.3, 0.37), w * 0.26, true)
	ink = keep


## Laniakea: a small armoured bug under a pale mask with a crown of jagged
## horns, hauling a sword bigger than he is.
## pose 0 = sword slung on his back, 1 = raised overhead (the leap),
## 2 = no sword drawn (the unit paints the swing itself).
static func laniakea(ci: CanvasItem, r: float, facing: float, t: float, pose: int = 0, ink_col: Color = OUTLINE) -> void:
	ink = ink_col
	var f := facing if absf(facing) > 0.01 else 1.0
	var bob := sin(t * 4.0) * r * 0.05
	var mask := Color(0.96, 0.95, 0.9)
	var plate := Color(0.37, 0.38, 0.45)
	var plate_dark := Color(0.22, 0.22, 0.28)
	if pose == 0:
		# slung across the back: grip over the shoulder, blade trailing behind
		greatsword(ci, Vector2(-r * 0.05 * f, -r * 0.5 + bob), Vector2(-r * 1.9 * f, r * 0.95 + bob), r * 0.52, ink_col)
	# legs
	ci.draw_line(Vector2(-r * 0.2 * f, r * 0.5), Vector2(-r * 0.36 * f, r * 1.08), plate_dark, r * 0.15, true)
	ci.draw_line(Vector2(r * 0.2 * f, r * 0.5), Vector2(r * 0.34 * f, r * 1.08), plate_dark, r * 0.15, true)
	# armoured body, banded, with a short skirt of plates
	poly(ci, PackedVector2Array([Vector2(-r * 0.5, r * 0.4 + bob), Vector2(-r * 0.62, r * 0.78 + bob),
		Vector2(0, r * 0.62 + bob), Vector2(r * 0.62, r * 0.78 + bob), Vector2(r * 0.5, r * 0.4 + bob)]), plate_dark, 1.6)
	ellipse(ci, Vector2(0, r * 0.2 + bob), r * 0.46, r * 0.5, plate)
	ci.draw_arc(Vector2(0, r * 0.02 + bob), r * 0.4, 0.5, PI - 0.5, 12, plate_dark, r * 0.08, true)
	ci.draw_arc(Vector2(0, r * 0.22 + bob), r * 0.4, 0.5, PI - 0.5, 12, plate_dark, r * 0.08, true)
	# sword arm
	var hand := Vector2(r * 0.5 * f, r * 0.3 + bob)
	if pose == 0:
		hand = Vector2(-r * 0.12 * f, -r * 0.42 + bob)
	elif pose == 1:
		hand = Vector2(r * 0.1 * f, -r * 1.25 + bob)
	ci.draw_line(Vector2(r * 0.3 * f, -r * 0.05 + bob), hand, plate_dark, r * 0.16, true)
	# the crown: jagged horns swept up and back to one side like windblown
	# hair, the biggest one leaning well past the back of the mask
	var head := Vector2(r * 0.08 * f, -r * 0.62 + bob)
	var tall: Array = [0.85, 1.2, 1.6, 1.4, 1.05, 0.75]
	var lean: Array = [-205.0, -178.0, -150.0, -124.0, -98.0, -66.0]
	for i in 6:
		var a := deg_to_rad(float(lean[i]))
		var out := Vector2(cos(a) * f, sin(a))
		var side := out.orthogonal() * r * 0.16
		poly(ci, PackedVector2Array([head + out * r * 0.3 + side, head + out * r * float(tall[i]),
			head + out * r * 0.3 - side]), mask, 1.6)
	ellipse(ci, head, r * 0.52, r * 0.45, mask)
	# two hollow eyes
	ellipse(ci, head + Vector2(-r * 0.2 + r * 0.06 * f, r * 0.06), r * 0.11, r * 0.16, Color(0.08, 0.07, 0.1), 0.0)
	ellipse(ci, head + Vector2(r * 0.2 + r * 0.06 * f, r * 0.06), r * 0.11, r * 0.16, Color(0.08, 0.07, 0.1), 0.0)
	if pose == 1:
		# both hands up, blade straight overhead and a little behind
		greatsword(ci, Vector2(r * 0.1 * f, -r * 1.3 + bob), Vector2(-r * 0.7 * f, -r * 3.6 + bob), r * 0.52, ink_col)
	ink = OUTLINE


## A needle from hilt to tip: a blade that is all taper, a short dark grip and a
## small guard. w is the width at the hilt.
static func needle(ci: CanvasItem, hilt: Vector2, tip: Vector2, w: float, ink_col: Color = OUTLINE) -> void:
	var keep := ink
	ink = ink_col
	var d := tip - hilt
	if d.length() < 0.01:
		ink = keep
		return
	var n := d.normalized()
	var s := n.orthogonal() * w * 0.5
	ci.draw_line(hilt - n * w * 2.4, hilt, Color(0.2, 0.17, 0.2), w * 0.7, true)
	poly(ci, PackedVector2Array([hilt + s, tip, hilt - s]), Color(0.87, 0.89, 0.94), 1.2)
	ci.draw_line(hilt + s * 2.2, hilt - s * 2.2, Color(0.62, 0.52, 0.3), w * 0.6, true)
	ink = keep


## Femme Fatale: a slight figure lost in a hood and a heavy cloak, carrying a
## needle longer than she is tall.
## pose 0 = needle trailing at her side, 1 = raised straight up (the wind-up),
## 2 = no needle drawn (the unit paints the lunge and the combo itself).
static func femme(ci: CanvasItem, r: float, facing: float, t: float, pose: int = 0, ink_col: Color = OUTLINE) -> void:
	ink = ink_col
	var f := facing if absf(facing) > 0.01 else 1.0
	var bob := sin(t * 3.4) * r * 0.04
	var sway := sin(t * 2.6) * r * 0.06
	var hood := Color(0.29, 0.2, 0.2)
	var cloak := Color(0.43, 0.26, 0.27)
	var robe := Color(0.5, 0.45, 0.33)
	var skin := Color(0.96, 0.86, 0.79)
	var hair := Color(0.46, 0.2, 0.17)
	if pose == 0:
		# trailing behind her, point down
		needle(ci, Vector2(r * 0.5 * f, r * 0.2 + bob), Vector2(-r * 2.7 * f, r * 1.0), r * 0.2, ink_col)
	# legs
	ci.draw_line(Vector2(-r * 0.16 * f, r * 0.6), Vector2(-r * 0.24 * f, r * 1.08), INK, r * 0.13, true)
	ci.draw_line(Vector2(r * 0.16 * f, r * 0.6), Vector2(r * 0.22 * f, r * 1.08), INK, r * 0.13, true)
	# cloak, open down the front over a paler robe
	poly(ci, PackedVector2Array([Vector2(-r * 0.34, -r * 0.4 + bob), Vector2(r * 0.34, -r * 0.4 + bob),
		Vector2(r * 0.74 + sway, r * 0.84), Vector2(-r * 0.74 + sway, r * 0.84)]), cloak)
	poly(ci, PackedVector2Array([Vector2(-r * 0.08 * f, -r * 0.3 + bob), Vector2(r * 0.2 * f, -r * 0.3 + bob),
		Vector2(r * 0.38 * f + sway, r * 0.84), Vector2(-r * 0.12 * f + sway, r * 0.84)]), robe, 0.0)
	# sword arm
	var hand := Vector2(r * 0.5 * f, r * 0.2 + bob)
	if pose == 1:
		hand = Vector2(r * 0.42 * f, -r * 0.9 + bob)
	elif pose == 2:
		hand = Vector2(r * 0.62 * f, -r * 0.05 + bob)
	ci.draw_line(Vector2(r * 0.26 * f, -r * 0.22 + bob), hand, hood, r * 0.17, true)
	# hood: a deep cowl with a soft point at the back, mantle over the shoulders
	poly(ci, PackedVector2Array([Vector2(-r * 0.3 * f, -r * 1.25 + bob), Vector2(-r * 0.86 * f, -r * 0.82 + bob),
		Vector2(-r * 0.3 * f, -r * 0.5 + bob)]), hood, 1.6)
	ellipse(ci, Vector2(r * 0.04 * f, -r * 0.8 + bob), r * 0.56, r * 0.58, hood)
	ellipse(ci, Vector2(0, -r * 0.3 + bob), r * 0.58, r * 0.2, hood)
	# the face in the shadow of it, a fringe of dark red hair
	ellipse(ci, Vector2(r * 0.16 * f, -r * 0.72 + bob), r * 0.33, r * 0.37, skin, 1.2)
	ci.draw_arc(Vector2(r * 0.16 * f, -r * 0.72 + bob), r * 0.3, PI + 0.25, TAU - 0.25, 12, hair, r * 0.13, true)
	ci.draw_circle(Vector2(r * 0.07 * f, -r * 0.7 + bob), r * 0.05, INK)
	ci.draw_circle(Vector2(r * 0.29 * f, -r * 0.7 + bob), r * 0.05, INK)
	# brooch
	ci.draw_circle(Vector2(r * 0.06 * f, -r * 0.28 + bob), r * 0.09, Color(0.9, 0.72, 0.3))
	if pose == 1:
		needle(ci, hand, Vector2(hand.x, -r * 4.2), r * 0.2, ink_col)
	ink = OUTLINE


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


## The two whelps share one body. molten = false: the Obsidian Whelp, near-black
## with rows of bone-coloured scale plates down its back and tail; curled, it
## rolls into a ring biting its own tail, plates out, eye shut. molten = true:
## the Magma Whelp, smooth and glowing with cracks of light, flapping in the air.
static func whelp(ci: CanvasItem, r: float, facing: float, t: float, curled: bool, molten: bool,
		ink_col: Color = OUTLINE) -> void:
	var keep := ink
	ink = ink_col
	var f := facing if absf(facing) > 0.01 else 1.0
	var body := Color(0.16, 0.14, 0.2) if not molten else Color(0.95, 0.32, 0.08)
	var belly := Color(0.3, 0.27, 0.36) if not molten else Color(1.0, 0.72, 0.22)
	var plate := Color(0.78, 0.7, 0.52)
	var plate_dark := Color(0.52, 0.46, 0.34)
	if curled and not molten:
		_whelp_curled(ci, r, f, body, plate, plate_dark)
		ink = keep
		return
	var bob: float = sin(t * (11.0 if molten else 5.0)) * r * (0.12 if molten else 0.04)
	var o := Vector2(0.0, bob)
	if molten:
		# a wake of embers below and behind
		for i in 4:
			var p: float = fmod(t * 1.6 + float(i) * 0.25, 1.0)
			ci.draw_circle(o + Vector2(-f * r * (0.5 + 0.9 * p), r * (0.3 + 0.5 * p)), r * 0.12 * (1.0 - p),
				Color(1.0, 0.6, 0.15, 0.7 * (1.0 - p)))
	# tail: tapering, curling up at the tip
	var tail := PackedVector2Array()
	for i in 7:
		var k: float = float(i) / 6.0
		tail.append(o + Vector2(-f * r * (0.4 + 0.9 * k), r * (0.25 - 0.55 * k * k) + sin(t * 4.0 + k * 3.0) * r * 0.06 * k))
	for i in 6:
		var w: float = r * (0.3 - 0.04 * float(i))
		ci.draw_line(tail[i], tail[i + 1], ink, w + 4.0, true)
	for i in 6:
		var w2: float = r * (0.3 - 0.04 * float(i))
		ci.draw_line(tail[i], tail[i + 1], body, w2, true)
	# wing: a bat wing behind the body, flapping hard when airborne
	var flap: float = sin(t * 14.0) if molten else 0.15
	var root := o + Vector2(-f * r * 0.05, -r * 0.2)
	var tip := root + Vector2(-f * r * 0.55, -r * (0.55 + 0.45 * flap))
	var mid := root + Vector2(-f * r * 0.15, -r * (0.75 + 0.35 * flap))
	var trail := root + Vector2(-f * r * 0.6, -r * 0.05 * flap)
	poly(ci, PackedVector2Array([root, mid, tip, trail]),
		Color(0.28, 0.22, 0.34) if not molten else Color(1.0, 0.55, 0.15), 1.6)
	# body and belly
	ellipse(ci, o + Vector2(0.0, r * 0.1), r * 0.52, r * 0.4, body, 2.2)
	ellipse(ci, o + Vector2(f * r * 0.06, r * 0.24), r * 0.34, r * 0.18, belly, 0.0)
	# legs
	if not molten:
		for lx in [-0.25, 0.22]:
			ci.draw_line(o + Vector2(f * r * lx, r * 0.36), Vector2(f * r * (lx + 0.04), r * 0.62), body.lightened(0.05), r * 0.14, true)
	else:
		for lx in [-0.15, 0.2]:
			ci.draw_line(o + Vector2(f * r * lx, r * 0.4), o + Vector2(f * r * (lx - 0.1), r * 0.58), body, r * 0.1, true)
	# neck and head
	var head_at := o + Vector2(f * r * 0.55, -r * 0.3)
	ci.draw_line(o + Vector2(f * r * 0.25, -r * 0.02), head_at, ink, r * 0.3 + 4.0, true)
	ci.draw_line(o + Vector2(f * r * 0.25, -r * 0.02), head_at, body, r * 0.3, true)
	ellipse(ci, head_at, r * 0.3, r * 0.22, body, 2.0)
	poly(ci, PackedVector2Array([head_at + Vector2(f * r * 0.12, -r * 0.12), head_at + Vector2(f * r * 0.48, -r * 0.02),
		head_at + Vector2(f * r * 0.44, r * 0.08), head_at + Vector2(f * r * 0.1, r * 0.14)]), body, 1.8)
	# two swept-back horns
	for hy in [-0.16, -0.08]:
		var hb := head_at + Vector2(-f * r * 0.05, r * hy)
		poly(ci, PackedVector2Array([hb, hb + Vector2(-f * r * 0.4, -r * 0.18 + r * hy), hb + Vector2(f * r * 0.06, -r * 0.08)]),
			plate if not molten else Color(1.0, 0.85, 0.4), 1.4)
	# the eye, open
	var eye := head_at + Vector2(f * r * 0.12, -r * 0.05)
	ci.draw_circle(eye, r * 0.07, Color(1.0, 0.35, 0.15) if not molten else Color(1.0, 0.95, 0.6))
	ci.draw_circle(eye + Vector2(f * r * 0.015, 0.0), r * 0.03, Color(0.05, 0.04, 0.06))
	if not molten:
		# rows of scale plates down the back and along the tail
		for i in 5:
			var a: float = deg_to_rad(200.0 + 32.0 * float(i))
			var base := o + Vector2(0.0, r * 0.1) + Vector2(cos(a) * f * r * 0.5, sin(a) * r * 0.38)
			var out := (base - o - Vector2(0.0, r * 0.1)).normalized()
			var s := out.orthogonal() * r * 0.13
			poly(ci, PackedVector2Array([base + s, base + out * r * 0.3, base - s]), plate, 1.3)
		for i in range(1, 6):
			var tp: Vector2 = tail[i]
			var up := Vector2(0.0, -1.0)
			var s2 := Vector2(f * r * 0.07, 0.0)
			poly(ci, PackedVector2Array([tp - s2, tp + up * r * (0.22 - 0.03 * float(i)), tp + s2]), plate_dark, 1.1)
	else:
		# cracks of light across the molten hide
		var glow := Color(1.0, 0.92, 0.5)
		ci.draw_polyline(PackedVector2Array([o + Vector2(-f * r * 0.3, -r * 0.05), o + Vector2(-f * r * 0.05, r * 0.08),
			o + Vector2(f * r * 0.1, -r * 0.08), o + Vector2(f * r * 0.3, r * 0.04)]), glow, 1.6, true)
		ci.draw_polyline(PackedVector2Array([o + Vector2(-f * r * 0.2, r * 0.25), o + Vector2(0.0, r * 0.18),
			o + Vector2(f * r * 0.18, r * 0.28)]), glow, 1.3, true)
		ci.draw_circle(o + Vector2(0.0, r * 0.1), r * 0.7, Color(1.0, 0.5, 0.1, 0.12))
	ink = keep


const STAFF_WOOD := Color(0.56, 0.35, 0.17)
const STAFF_GOLD := Color(0.97, 0.78, 0.25)


## A wooden staff with gold caps from a to b; w is its thickness.
static func gold_staff(ci: CanvasItem, a: Vector2, b: Vector2, w: float) -> void:
	var d := b - a
	if d.length() < 0.5:
		return
	var n := d.normalized()
	var cap: float = minf(d.length() * 0.14, w * 2.2)
	ci.draw_line(a, b, ink, w + 3.0, true)
	ci.draw_line(a, b, STAFF_WOOD, w, true)
	ci.draw_line(a + n.orthogonal() * w * 0.2, b + n.orthogonal() * w * 0.2, STAFF_WOOD.lightened(0.25), w * 0.25, true)
	ci.draw_line(a, a + n * cap, STAFF_GOLD, w * 1.25, true)
	ci.draw_line(b, b - n * cap, STAFF_GOLD, w * 1.25, true)


## Wu Cheng'en, a bonobo, side view facing `facing`.
## pose: "staff" 0..1 how far the staff is out (0 = on all fours, knuckle
## walking; while it comes out he rises onto his legs and the staff grows from
## behind his ear into both hands), "walk" true when moving, "swing" true while
## the unit draws a staff hit itself (the staff is left out of his hands),
## "rage" true while raging (hair up, red eyes).
static func bonobo(ci: CanvasItem, r: float, facing: float, t: float, pose: Dictionary = {}, ink_col: Color = OUTLINE) -> void:
	var keep := ink
	ink = ink_col
	var f := facing if absf(facing) > 0.01 else 1.0
	var s: float = clampf(float(pose.get("staff", 0.0)), 0.0, 1.0)
	var walk: bool = bool(pose.get("walk", false))
	var swing: bool = bool(pose.get("swing", false))
	var rage: bool = bool(pose.get("rage", false))
	# rising onto the legs happens over the first half of the draw
	var up: float = clampf(s * 2.0, 0.0, 1.0)
	var fur := Color(0.17, 0.16, 0.19)
	var fur_hi := Color(0.3, 0.29, 0.33)
	var skin := Color(0.24, 0.2, 0.22)
	var gait: float = sin(t * 9.0) if walk and up < 0.5 else 0.0
	var P := func(x: float, y: float) -> Vector2: return Vector2(x * f * r, y * r)
	# torso: long and sloping on all fours, upright-ish once he stands
	var hip: Vector2 = P.call(lerpf(-0.42, -0.12, up), lerpf(0.05, 0.05, up))
	var shoulder: Vector2 = P.call(lerpf(0.32, 0.08, up), lerpf(-0.28, -0.62, up))
	# back leg (far) and front arm (far) first, darker
	var knee_far: Vector2 = hip + P.call(0.22 - 0.1 * gait, 0.35)
	var foot_far: Vector2 = knee_far + P.call(-0.12 - 0.12 * gait, 0.4)
	ci.draw_line(hip, knee_far, fur.darkened(0.25), r * 0.24, true)
	ci.draw_line(knee_far, foot_far, fur.darkened(0.25), r * 0.2, true)
	if up < 0.5:
		var knuck_far: Vector2 = shoulder + P.call(0.12 + 0.12 * gait, 1.08)
		ci.draw_line(shoulder, knuck_far, fur.darkened(0.25), r * 0.2, true)
	# torso
	var mid := hip.lerp(shoulder, 0.5)
	var ang: float = (shoulder - hip).angle()
	# a rotated ellipse built point by point: draw_set_transform here would throw
	# away the caller's transform (card faces, previews, the unit's squash)
	var tp := PackedVector2Array()
	var trx: float = hip.distance_to(shoulder) * 0.72
	for i in 32:
		var a := TAU * float(i) / 32.0
		tp.append(mid + Vector2(cos(a) * trx, sin(a) * r * 0.36).rotated(ang))
	poly(ci, tp, fur, 2.2)
	# near back leg
	var knee: Vector2 = hip + P.call(0.26 + 0.1 * gait, 0.32)
	var foot: Vector2 = knee + P.call(-0.1 + 0.12 * gait, 0.42)
	ci.draw_line(hip, knee, ink, r * 0.3, true)
	ci.draw_line(hip, knee, fur, r * 0.24, true)
	ci.draw_line(knee, foot, ink, r * 0.25, true)
	ci.draw_line(knee, foot, fur, r * 0.19, true)
	ci.draw_line(foot, foot + P.call(0.18, 0.0), skin, r * 0.12, true)
	# head: forward of the shoulders, a dark face with pale lips
	var head: Vector2 = shoulder + P.call(lerpf(0.3, 0.16, up), lerpf(-0.22, -0.3, up))
	var ear: Vector2 = head + P.call(-0.2, -0.04)
	# hair standing up in a rage
	if rage:
		for i in 5:
			var a: float = deg_to_rad(-150.0 + 25.0 * float(i))
			var hd := Vector2(cos(a) * f, sin(a))
			ci.draw_line(head + hd * r * 0.28, head + hd * r * 0.5, fur_hi, 2.0, true)
	circle(ci, head, r * 0.3, fur, 2.0)
	circle(ci, ear, r * 0.09, skin, 1.4)
	# the centre-parted hair of a bonobo
	ci.draw_line(head + P.call(0.0, -0.3), head + P.call(-0.05, -0.12), fur_hi, 1.6, true)
	ellipse(ci, head + P.call(0.12, 0.05), r * 0.19, r * 0.17, skin, 1.6)
	ci.draw_line(head + P.call(0.18, 0.14), head + P.call(0.3, 0.12), Color(0.86, 0.62, 0.62), r * 0.07, true)
	var eye: Vector2 = head + P.call(0.14, -0.04)
	ci.draw_circle(eye, r * 0.055, Color(1.0, 0.25, 0.2) if rage else Color(0.62, 0.45, 0.3))
	ci.draw_circle(eye + P.call(0.012, 0.0), r * 0.025, Color(0.04, 0.03, 0.04))
	ci.draw_line(eye + P.call(-0.07, -0.08), eye + P.call(0.07, -0.07), fur_hi, 1.6, true)
	# near arm and the staff
	if up < 0.5 and s <= 0.0:
		var knuck: Vector2 = shoulder + P.call(0.18 - 0.14 * gait, 1.08)
		ci.draw_line(shoulder, knuck, ink, r * 0.26, true)
		ci.draw_line(shoulder, knuck, fur, r * 0.2, true)
		ci.draw_circle(knuck, r * 0.1, skin)
	else:
		# the staff: a twig behind the ear that grows as it comes out until it
		# lies across both hands at chest height
		var hands: Vector2 = shoulder + P.call(0.28, 0.26)
		var hold := hands
		if not swing:
			var len_px: float = lerpf(r * 0.2, r * 2.4, ease(s, 0.6))
			var c: Vector2 = ear.lerp(hands, ease(s, 0.5))
			var dir_s: Vector2 = Vector2(f * cos(lerpf(-1.4, -0.35, s)), sin(lerpf(-1.4, -0.35, s)))
			gold_staff(ci, c - dir_s * len_px * 0.45, c + dir_s * len_px * 0.55, lerpf(r * 0.06, r * 0.13, s))
			hold = c
		ci.draw_line(shoulder, hold, ink, r * 0.26, true)
		ci.draw_line(shoulder, hold, fur, r * 0.2, true)
		ci.draw_circle(hold, r * 0.1, skin)
	ink = keep


const NEKO_CLOAK := Color(0.6, 0.82, 0.4)
const NEKO_CLOAK_DARK := Color(0.44, 0.64, 0.29)
const NEKO_TUNIC := Color(0.36, 0.43, 0.3)
const NEKO_HAT := Color(0.15, 0.24, 0.15)
const NEKO_FUR := Color(0.13, 0.12, 0.15)


## Where the gem on the Nekomancer's staff sits (her beam starts there).
static func neko_staff_tip(r: float, facing: float) -> Vector2:
	var f := facing if absf(facing) > 0.01 else 1.0
	return Vector2(0.56 * f * r, -1.52 * r)


## The Nekomancer: a black cat in a ragged green hooded cloak and a pointed
## wizard's hat, a crescent-headed staff in her front paw.
## pose: "wind" 1..0 what is left of a gust (the cloak streams back and
## flutters while it lasts), "cast" 1..0 the gem's flash after a beam, "walk".
## gem is the colour of her beam (her team).
static func nekomancer(ci: CanvasItem, r: float, facing: float, t: float, pose: Dictionary = {},
		ink_col: Color = OUTLINE, gem: Color = Color(0.6, 1.0, 0.5)) -> void:
	var keep := ink
	ink = ink_col
	var f := facing if absf(facing) > 0.01 else 1.0
	var wind: float = clampf(float(pose.get("wind", 0.0)), 0.0, 1.0)
	var gust: float = sin((1.0 - wind) * PI) if wind > 0.0 else 0.0
	var cast: float = clampf(float(pose.get("cast", 0.0)), 0.0, 1.0)
	var walk: bool = bool(pose.get("walk", false))
	var step: float = sin(t * 8.0) if walk else 0.0
	var P := func(x: float, y: float) -> Vector2: return Vector2(x * f * r, y * r)
	# tail: curls up behind her
	var sway: float = sin(t * 2.4) * 0.08
	var tail := PackedVector2Array([P.call(-0.3, 0.55), P.call(-0.7, 0.45), P.call(-0.95, 0.1),
		P.call(-0.9 + sway, -0.3), P.call(-0.72 + sway, -0.42)])
	ci.draw_polyline(tail, ink, r * 0.22, true)
	ci.draw_polyline(tail, NEKO_FUR, r * 0.15, true)
	# the cloak behind her: hangs from the shoulders, hem ragged; a gust streams
	# the back of it out and sets the hem flapping
	var back := PackedVector2Array()
	back.append(P.call(0.28, -0.5))
	back.append(P.call(-0.3, -0.52))
	var hem_n := 7
	for i in hem_n + 1:
		var k: float = float(i) / float(hem_n)
		# k 0 = back corner, 1 = front corner
		var x: float = lerpf(-0.6, 0.42, k)
		var y: float = 0.82 + (0.1 if i % 2 == 1 else 0.0)
		var flap: float = sin(t * 14.0 + float(i) * 1.3) * 0.07 * gust + sin(t * 3.0 + float(i)) * 0.02
		x -= gust * (0.55 - 0.45 * k)
		y += flap - gust * (0.3 - 0.25 * k)
		if i == 0:
			# the back edge, out behind her
			back.append(P.call(x - 0.1 * gust, y - 0.5 - 0.2 * gust))
		back.append(P.call(x, y))
	poly(ci, back, NEKO_CLOAK_DARK, 2.0)
	# feet
	ellipse(ci, P.call(-0.14 - 0.08 * step, 0.86), r * 0.15, r * 0.09, NEKO_FUR, 1.6)
	ellipse(ci, P.call(0.2 + 0.08 * step, 0.86), r * 0.15, r * 0.09, NEKO_FUR, 1.6)
	# tunic and belt, between the cloak's edges
	ellipse(ci, P.call(0.04, 0.28), r * 0.33, r * 0.5, NEKO_TUNIC, 2.0)
	ci.draw_line(P.call(-0.27, 0.3), P.call(0.35, 0.22), Color(0.45, 0.28, 0.14), r * 0.12, true)
	ci.draw_rect(Rect2(P.call(0.06, 0.2) - Vector2(r * 0.07, r * 0.06), Vector2(r * 0.14, r * 0.13)), Color(0.95, 0.76, 0.25), true)
	# the near half of the cloak, falling over her back shoulder
	var front := PackedVector2Array([P.call(-0.3, -0.52), P.call(-0.05, -0.48), P.call(-0.12, 0.2),
		P.call(-0.3 - 0.3 * gust, 0.86 - 0.15 * gust), P.call(-0.5 - 0.45 * gust, 0.78 - 0.25 * gust)])
	poly(ci, front, NEKO_CLOAK, 2.0)
	# the paw and sleeve on the staff, then the staff itself
	var tip: Vector2 = neko_staff_tip(r, f)
	var foot_s: Vector2 = P.call(0.6, 0.86)
	var crook: Vector2 = tip + P.call(0.0, 0.2)
	ci.draw_line(foot_s, crook, ink, r * 0.15 + 2.0, true)
	ci.draw_line(foot_s, crook, STAFF_WOOD.darkened(0.15), r * 0.15, true)
	# the crescent cupping the gem
	ci.draw_arc(tip, r * 0.2, PI * 0.15, PI * 0.85, 10, ink, r * 0.12 + 2.0, true)
	ci.draw_arc(tip, r * 0.2, PI * 0.15, PI * 0.85, 10, STAFF_WOOD.darkened(0.15), r * 0.12, true)
	ci.draw_line(tip + Vector2(r * 0.18, -r * 0.02), tip + Vector2(r * 0.24, -r * 0.2), ink, r * 0.08, true)
	ci.draw_line(tip + Vector2(-r * 0.18, -r * 0.02), tip + Vector2(-r * 0.24, -r * 0.2), ink, r * 0.08, true)
	var glow: float = 0.3 + 0.12 * sin(t * 5.0) + 0.5 * cast
	ci.draw_circle(tip, r * (0.22 + 0.2 * cast), Color(gem.r, gem.g, gem.b, glow * 0.5))
	circle(ci, tip, r * 0.11, gem.lightened(0.25 + 0.4 * cast), 1.4)
	var paw: Vector2 = P.call(0.56, -0.08)
	ci.draw_line(P.call(0.2, -0.38), paw, ink, r * 0.24, true)
	ci.draw_line(P.call(0.2, -0.38), paw, NEKO_CLOAK, r * 0.18, true)
	circle(ci, paw, r * 0.11, NEKO_FUR, 1.4)
	# head, collar gem, face
	var head: Vector2 = P.call(0.06, -0.74)
	circle(ci, head, r * 0.36, NEKO_FUR, 2.0)
	circle(ci, P.call(0.06, -0.4), r * 0.085, Color(0.85, 0.15, 0.12), 1.4)
	for side in [-1.0, 1.0]:
		var eye: Vector2 = head + P.call(0.07 + 0.16 * side, 0.03)
		ellipse(ci, eye, r * 0.12, r * 0.1, Color(0.9, 0.97, 0.25), 0.0)
		ci.draw_line(eye + Vector2(0, -r * 0.08), eye + Vector2(0, r * 0.08), Color(0.04, 0.03, 0.04), maxf(1.0, r * 0.05), true)
		# heavy lids slanting in: she is not pleased
		# (the inner corner, toward the nose, droops lowest)
		var y_in: float = -0.01
		var y_out: float = -0.1
		poly(ci, PackedVector2Array([eye + P.call(-0.14, -0.12), eye + P.call(0.14, -0.12),
			eye + P.call(0.14, y_in if side < 0.0 else y_out), eye + P.call(-0.14, y_out if side < 0.0 else y_in)]), NEKO_FUR, 0.0)
	# the hat: wide brim, ears through it, a cone that bends back at the tip
	ellipse(ci, head + P.call(0.0, -0.24), r * 0.6, r * 0.13, NEKO_HAT, 2.0)
	for side in [-1.0, 1.0]:
		var base: Vector2 = head + P.call(0.33 * side, -0.27)
		poly(ci, PackedVector2Array([base + P.call(-0.1, 0.0), base + P.call(0.1, 0.0),
			base + P.call(0.12 * side, -0.24)]), NEKO_FUR, 1.6)
	var droop: float = sin(t * 2.0) * 0.04 - 0.15 * gust
	var cone := PackedVector2Array([head + P.call(-0.26, -0.28), head + P.call(0.24, -0.28),
		head + P.call(0.06, -0.85), head + P.call(-0.3 + droop, -1.12), head + P.call(-0.14, -0.78)])
	poly(ci, cone, NEKO_HAT, 2.0)
	ci.draw_line(head + P.call(-0.24, -0.38), head + P.call(0.21, -0.38), NEKO_CLOAK, r * 0.1, true)
	ci.draw_rect(Rect2(head + P.call(-0.02, -0.38) - Vector2(r * 0.05, r * 0.05), Vector2(r * 0.1, r * 0.1)), Color(0.95, 0.76, 0.25), true)
	ink = keep


const GIL_PLATE := Color(0.16, 0.42, 0.5)
const GIL_PLATE_DARK := Color(0.1, 0.27, 0.34)
const GIL_GOLD := Color(0.95, 0.75, 0.28)
const GIL_SKIN := Color(0.82, 0.6, 0.44)
const GIL_HAIR := Color(0.2, 0.13, 0.1)
const LION := Color(0.9, 0.66, 0.28)
const LION_MANE := Color(0.68, 0.38, 0.14)


## A snake as a tapering body along pts (tail first, head last), in col with a
## pale belly line, head at the end with an eye and a flick of tongue.
static func snake_body(ci: CanvasItem, pts: PackedVector2Array, w: float, col: Color, t: float) -> void:
	var n := pts.size()
	if n < 2:
		return
	for i in n - 1:
		var k: float = float(i) / float(n - 1)
		var ww: float = w * lerpf(0.35, 1.0, k)
		ci.draw_line(pts[i], pts[i + 1], ink, ww + 2.2, true)
	for i in n - 1:
		var k: float = float(i) / float(n - 1)
		var ww: float = w * lerpf(0.35, 1.0, k)
		ci.draw_line(pts[i], pts[i + 1], col, ww, true)
		if i % 2 == 0:
			ci.draw_line(pts[i], pts[i + 1], col.lightened(0.45), ww * 0.3, true)
	var head: Vector2 = pts[n - 1]
	var dir: Vector2 = (pts[n - 1] - pts[n - 2]).normalized()
	var side := dir.orthogonal()
	var tip: Vector2 = head + dir * w * 1.3
	poly(ci, PackedVector2Array([head - dir * w * 0.3 + side * w * 0.75, tip + side * w * 0.3,
		tip - side * w * 0.3, head - dir * w * 0.3 - side * w * 0.75]), col, 1.6)
	ci.draw_circle(head + dir * w * 0.35 + side * w * 0.38, maxf(1.0, w * 0.2), Color(1.0, 0.9, 0.3))
	if sin(t * 9.0) > 0.0:
		ci.draw_line(tip, tip + dir * w * 0.9, Color(0.85, 0.15, 0.2), maxf(1.0, w * 0.15), true)


## Gilgamesh's lash from `from` toward `to` (local), `ext` 0..1 of the way out:
## a wave travels down the body so it whips rather than pokes.
static func snake_lash(ci: CanvasItem, from: Vector2, to: Vector2, ext: float, t: float, w: float,
		col: Color, ink_col: Color = OUTLINE) -> void:
	if ext <= 0.01:
		return
	var keep := ink
	ink = ink_col
	var d: Vector2 = (to - from) * ext
	var side: Vector2 = d.normalized().orthogonal()
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var k: float = float(i) / float(n)
		var amp: float = w * 1.8 * sin(k * PI) * (1.2 - ext * 0.5)
		pts.append(from + d * k + side * amp * sin(k * TAU * 1.5 - t * 24.0))
	snake_body(ci, pts, w, col, t)
	ink = keep


## Where Gilgamesh's whip hand is, for the lash.
static func gilgamesh_hand(r: float, facing: float) -> Vector2:
	var f := facing if absf(facing) > 0.01 else 1.0
	return Vector2(0.62 * f * r, -0.05 * r)


## Gilgamesh, from the palace relief: square-cut beard in rows of ringlets,
## curled hair under a gold circlet, in teal plate trimmed in gold with a fur
## collar and a lion's head for the near pauldron. A snake in his team's
## colour is his whip: coiled on his arm at rest, gone from it mid-lash.
## pose: "lashing", "walk".
static func gilgamesh(ci: CanvasItem, r: float, facing: float, t: float, pose: Dictionary = {},
		ink_col: Color = OUTLINE, snake: Color = Color(0.3, 0.6, 0.9)) -> void:
	var keep := ink
	ink = ink_col
	var f := facing if absf(facing) > 0.01 else 1.0
	var walk: bool = bool(pose.get("walk", false))
	var lashing: bool = bool(pose.get("lashing", false))
	var g: float = sin(t * 8.0) if walk else 0.0
	var P := func(x: float, y: float) -> Vector2: return Vector2(x * f * r, y * r)
	# cape
	poly(ci, PackedVector2Array([P.call(0.2, -0.55), P.call(-0.42, -0.55), P.call(-0.72 - 0.05 * g, 0.78),
		P.call(-0.2, 0.86), P.call(0.1, 0.5)]), Color(0.42, 0.12, 0.14), 2.0)
	# legs: plated greaves
	for s in [-1.0, 1.0]:
		var hip: Vector2 = P.call(0.08 * s - 0.02, 0.35)
		var foot: Vector2 = P.call(0.1 * s + 0.12 * g * s, 0.9)
		ci.draw_line(hip, foot, ink, r * 0.26, true)
		ci.draw_line(hip, foot, GIL_PLATE_DARK if s < 0.0 else GIL_PLATE, r * 0.2, true)
		ellipse(ci, foot + P.call(0.06, 0.02), r * 0.15, r * 0.08, Color(0.3, 0.2, 0.14), 1.4)
	# plated skirt with a gold hem
	poly(ci, PackedVector2Array([P.call(-0.36, 0.0), P.call(0.36, 0.0), P.call(0.42, 0.5), P.call(-0.42, 0.5)]),
		GIL_PLATE_DARK, 2.0)
	ci.draw_line(P.call(-0.42, 0.48), P.call(0.42, 0.48), GIL_GOLD, r * 0.07, true)
	ci.draw_line(P.call(0.0, 0.02), P.call(0.0, 0.48), GIL_PLATE, r * 0.05, true)
	# far pauldron
	circle(ci, P.call(-0.36, -0.42), r * 0.2, GIL_PLATE_DARK, 1.8)
	# breastplate: gold trim, red gem, a chain across
	poly(ci, PackedVector2Array([P.call(-0.38, -0.5), P.call(0.38, -0.5), P.call(0.32, 0.04), P.call(-0.32, 0.04)]),
		GIL_PLATE, 2.0)
	ci.draw_line(P.call(-0.3, -0.18), P.call(0.3, -0.18), GIL_GOLD, r * 0.05, true)
	circle(ci, P.call(0.0, -0.28), r * 0.08, Color(0.85, 0.12, 0.12), 1.2)
	ci.draw_line(P.call(-0.3, -0.48), P.call(0.25, -0.05), GIL_GOLD.darkened(0.2), r * 0.04, true)
	# fur collar
	ellipse(ci, P.call(0.0, -0.52), r * 0.36, r * 0.11, Color(0.86, 0.8, 0.68), 1.6)
	# the lion's head pauldron on the near shoulder, looking forward; drawn
	# before the head so the beard falls over its mane
	var lion: Vector2 = P.call(0.44, -0.34)
	for i in 10:
		var a: float = TAU * float(i) / 10.0
		ci.draw_circle(lion + Vector2(cos(a), sin(a)) * r * 0.17, r * 0.09, LION_MANE)
	circle(ci, lion, r * 0.17, LION_MANE, 1.6)
	circle(ci, lion + P.call(0.03, 0.01), r * 0.12, LION, 1.4)
	ci.draw_circle(lion + P.call(0.07, 0.05), r * 0.05, Color(0.98, 0.84, 0.6))
	ci.draw_circle(lion + P.call(0.1, 0.02), maxf(1.0, r * 0.028), Color(0.15, 0.08, 0.05))
	ci.draw_circle(lion + P.call(0.04, -0.04), maxf(1.0, r * 0.026), Color(0.15, 0.08, 0.05))
	ci.draw_line(lion + P.call(0.05, 0.1), lion + P.call(0.12, 0.09), Color(0.5, 0.12, 0.1), maxf(1.0, r * 0.035), true)
	# head: curled hair, then the face, then the square beard in ringlet rows
	var head: Vector2 = P.call(0.02, -0.86)
	circle(ci, head + P.call(-0.06, -0.02), r * 0.3, GIL_HAIR, 1.8)
	ellipse(ci, head + P.call(0.04, 0.0), r * 0.2, r * 0.23, GIL_SKIN, 1.6)
	var beard := PackedVector2Array([head + P.call(-0.14, 0.06), head + P.call(0.22, 0.06),
		head + P.call(0.2, 0.42), head + P.call(-0.12, 0.42)])
	poly(ci, beard, GIL_HAIR, 1.6)
	for row in 4:
		var y: float = 0.13 + 0.08 * float(row)
		ci.draw_line(head + P.call(-0.11, y), head + P.call(0.19, y), GIL_HAIR.lightened(0.25), maxf(1.0, r * 0.03), true)
	for s in [-1.0, 1.0]:
		ci.draw_circle(head + P.call(0.04 + 0.27 * s, 0.1), r * 0.08, GIL_HAIR.lightened(0.12))
	ci.draw_circle(head + P.call(0.1, -0.03), maxf(1.0, r * 0.035), Color(0.08, 0.05, 0.04))
	ci.draw_line(head + P.call(0.03, -0.09), head + P.call(0.16, -0.09), GIL_HAIR, maxf(1.0, r * 0.04), true)
	ci.draw_line(head + P.call(-0.2, -0.17), head + P.call(0.22, -0.17), GIL_GOLD, r * 0.07, true)
	# near arm and whip hand
	var hand: Vector2 = gilgamesh_hand(r, f)
	# the arm comes out from under the lion
	var elbow: Vector2 = lion + P.call(0.04, 0.14)
	ci.draw_line(elbow, hand, ink, r * 0.24, true)
	ci.draw_line(elbow, hand, GIL_PLATE, r * 0.18, true)
	ci.draw_line(hand + P.call(-0.12, -0.1), hand + P.call(-0.03, -0.02), GIL_GOLD, r * 0.18, true)
	circle(ci, hand, r * 0.09, GIL_SKIN, 1.4)
	if not lashing:
		# the snake at rest: hangs from his fist, loops, and lifts its head
		var sw: float = sin(t * 2.5) * 0.06
		var pts := PackedVector2Array([hand + P.call(-0.05, -0.05), hand + P.call(0.05, 0.2),
			hand + P.call(0.2, 0.45), hand + P.call(0.08, 0.68), hand + P.call(0.28, 0.8),
			hand + P.call(0.42 + sw, 0.6), hand + P.call(0.46 + sw, 0.38)])
		snake_body(ci, pts, r * 0.15, snake, t)
	ink = keep


## The card / deploy-preview picture of the pair, centred on c: Gilgamesh on
## the left facing in, Enkidu on the right facing him. Sets the transform itself
## (absolute), so pass the centre in canvas coordinates.
static func gil_pair(ci: CanvasItem, c: Vector2, r: float, t: float = 0.0) -> void:
	ci.draw_set_transform(c + Vector2(-r * 0.6, 0.0), 0.0, Vector2.ONE)
	gilgamesh(ci, r, 1.0, t)
	ci.draw_set_transform(c + Vector2(r * 0.65, r * 0.05), 0.0, Vector2.ONE)
	enkidu(ci, r * 0.95, -1.0, t)
	ci.draw_set_transform(c, 0.0, Vector2.ONE)


const ENK_SKIN := Color(0.76, 0.55, 0.38)
const ENK_FUR := Color(0.45, 0.3, 0.18)
const ENK_HORN := Color(0.93, 0.88, 0.74)
const BRONZE := Color(0.82, 0.55, 0.25)


## Enkidu's spear from a (butt) to b (point).
static func enkidu_spear(ci: CanvasItem, a: Vector2, b: Vector2, w: float) -> void:
	var d := b - a
	if d.length() < 0.5:
		return
	var n := d.normalized()
	var s := n.orthogonal()
	ci.draw_line(a, b - n * w * 2.5, ink, w + 2.2, true)
	ci.draw_line(a, b - n * w * 2.5, STAFF_WOOD, w, true)
	poly(ci, PackedVector2Array([b, b - n * w * 3.2 + s * w * 1.1, b - n * w * 2.4, b - n * w * 3.2 - s * w * 1.1]),
		BRONZE, 1.2)


## Enkidu, from the cylinder seal: a bull-man with a human chest and bearded
## face, curved horns and bull's ears, shaggy bull legs on hooves and a tufted
## tail. pose: "spear" (in hand; otherwise a short bronze sword), "walk",
## "strike" 1..0 the thrust after a hit.
static func enkidu(ci: CanvasItem, r: float, facing: float, t: float, pose: Dictionary = {},
		ink_col: Color = OUTLINE) -> void:
	var keep := ink
	ink = ink_col
	var f := facing if absf(facing) > 0.01 else 1.0
	var walk: bool = bool(pose.get("walk", false))
	var has_spear: bool = bool(pose.get("spear", true))
	var strike: float = clampf(float(pose.get("strike", 0.0)), 0.0, 1.0)
	var g: float = sin(t * 9.0) if walk else 0.0
	var P := func(x: float, y: float) -> Vector2: return Vector2(x * f * r, y * r)
	# tail with a tuft
	var tw: float = sin(t * 3.0) * 0.08
	var tail := PackedVector2Array([P.call(-0.25, 0.25), P.call(-0.6, 0.35), P.call(-0.72 + tw, 0.65)])
	ci.draw_polyline(tail, ink, r * 0.09 + 2.0, true)
	ci.draw_polyline(tail, ENK_FUR, r * 0.09, true)
	circle(ci, P.call(-0.74 + tw, 0.72), r * 0.09, ENK_FUR.darkened(0.3), 1.2)
	# bull legs: thigh back, hock, cannon down to a hoof
	for s in [-1.0, 1.0]:
		var hip: Vector2 = P.call(-0.04 + 0.1 * s, 0.25)
		var hock: Vector2 = P.call(-0.14 + 0.1 * s - 0.1 * g * s, 0.6)
		var hoof: Vector2 = P.call(0.0 + 0.1 * s + 0.12 * g * s, 0.88)
		var c: Color = ENK_FUR.darkened(0.2) if s < 0.0 else ENK_FUR
		ci.draw_line(hip, hock, ink, r * 0.3, true)
		ci.draw_line(hip, hock, c, r * 0.24, true)
		ci.draw_line(hock, hoof, ink, r * 0.18, true)
		ci.draw_line(hock, hoof, c, r * 0.13, true)
		poly(ci, PackedVector2Array([hoof + P.call(-0.08, -0.03), hoof + P.call(0.1, -0.03),
			hoof + P.call(0.12, 0.06), hoof + P.call(-0.08, 0.06)]), Color(0.18, 0.13, 0.1), 1.2)
	# shaggy haunches and a loincloth
	ellipse(ci, P.call(-0.02, 0.22), r * 0.32, r * 0.2, ENK_FUR, 2.0)
	poly(ci, PackedVector2Array([P.call(-0.2, 0.08), P.call(0.24, 0.08), P.call(0.16, 0.38), P.call(-0.1, 0.38)]),
		Color(0.86, 0.8, 0.6), 1.4)
	# far arm
	ci.draw_line(P.call(-0.2, -0.45), P.call(-0.3, -0.05), ink, r * 0.2, true)
	ci.draw_line(P.call(-0.2, -0.45), P.call(-0.3, -0.05), ENK_SKIN.darkened(0.2), r * 0.15, true)
	# bare torso
	ellipse(ci, P.call(0.02, -0.25), r * 0.3, r * 0.34, ENK_SKIN, 2.0)
	ci.draw_line(P.call(0.0, -0.4), P.call(0.04, -0.1), ENK_SKIN.darkened(0.18), maxf(1.0, r * 0.03), true)
	# head: wild hair, horns, bull ears, face, long beard
	var head: Vector2 = P.call(0.08, -0.72)
	circle(ci, head + P.call(-0.05, -0.03), r * 0.25, GIL_HAIR.lightened(0.08), 1.8)
	for s in [-1.0, 1.0]:
		var base: Vector2 = head + P.call(0.02 + 0.17 * s, -0.17)
		var horn := PackedVector2Array([base, base + P.call(0.16 * s, -0.12), base + P.call(0.2 * s, -0.3)])
		ci.draw_polyline(horn, ink, r * 0.11 + 2.0, true)
		ci.draw_polyline(horn, ENK_HORN, r * 0.11, true)
		ellipse(ci, head + P.call(0.04 + 0.25 * s, -0.04), r * 0.1, r * 0.05, ENK_SKIN.darkened(0.1), 1.2)
	ellipse(ci, head + P.call(0.05, 0.0), r * 0.17, r * 0.2, ENK_SKIN, 1.6)
	poly(ci, PackedVector2Array([head + P.call(-0.1, 0.08), head + P.call(0.2, 0.08), head + P.call(0.12, 0.42),
		head + P.call(0.02, 0.46), head + P.call(-0.06, 0.4)]), GIL_HAIR.lightened(0.08), 1.6)
	ci.draw_circle(head + P.call(0.1, -0.03), maxf(1.0, r * 0.035), Color(0.08, 0.05, 0.04))
	ci.draw_line(head + P.call(0.02, -0.1), head + P.call(0.16, -0.08), GIL_HAIR, maxf(1.0, r * 0.04), true)
	# near arm and weapon, thrusting forward on a strike
	var push: float = strike * 0.25
	var shoulder: Vector2 = P.call(0.2, -0.42)
	var hand: Vector2 = P.call(0.5 + push, -0.12)
	ci.draw_line(shoulder, hand, ink, r * 0.22, true)
	ci.draw_line(shoulder, hand, ENK_SKIN, r * 0.17, true)
	if has_spear:
		var along := Vector2(f * 0.94, -0.34).normalized()
		enkidu_spear(ci, hand - along * r * 1.1, hand + along * r * 1.3, maxf(1.6, r * 0.09))
	else:
		# the short sword: a bronze leaf blade, point forward
		var sd := Vector2(f * 0.9, -0.44).normalized()
		ci.draw_line(hand - sd * r * 0.12, hand + sd * r * 0.08, Color(0.3, 0.2, 0.12), r * 0.1, true)
		poly(ci, PackedVector2Array([hand + sd * r * 0.08 + sd.orthogonal() * r * 0.08, hand + sd * r * 0.62,
			hand + sd * r * 0.08 - sd.orthogonal() * r * 0.08]), BRONZE.lightened(0.15), 1.2)
	circle(ci, hand, r * 0.09, ENK_SKIN, 1.3)
	ink = keep


## The dart frog's stripes: the owner's colour pushed brighter and a little
## more saturated, the way the real frog's gold glows against the black.
static func frog_stripe(team_col: Color) -> Color:
	return Color.from_hsv(team_col.h, clampf(team_col.s * 1.15, 0.0, 1.0), clampf(team_col.v * 1.5 + 0.18, 0.0, 1.0))


## A poison dart frog, side view: glossy black body, stripes in `stripe` from
## the snout over the eye and down the flank, blue legs netted with black.
## air 0..1: 0 sitting with the legs folded, 1 fully stretched out mid-leap.
static func dart_frog(ci: CanvasItem, r: float, facing: float, t: float, air: float = 0.0,
		ink_col: Color = OUTLINE, stripe: Color = Color(1.0, 0.75, 0.15)) -> void:
	var keep := ink
	ink = ink_col
	var f := facing if absf(facing) > 0.01 else 1.0
	var a: float = clampf(air, 0.0, 1.0)
	var P := func(x: float, y: float) -> Vector2: return Vector2(x * f * r, y * r)
	var black := Color(0.07, 0.07, 0.09)
	var leg := Color(0.36, 0.66, 0.96)
	var breathe: float = sin(t * 3.0) * 0.02 * (1.0 - a)
	# far legs (darker), then the body, then the near legs over it
	var hip_far: Vector2 = P.call(-0.38, 0.12)
	var foot_far: Vector2 = P.call(lerpf(-0.2, -1.05, a), lerpf(0.45, 0.28, a))
	ci.draw_line(hip_far, foot_far, ink, r * 0.22, true)
	ci.draw_line(hip_far, foot_far, leg.darkened(0.3), r * 0.16, true)
	ci.draw_line(P.call(0.3, 0.2), P.call(lerpf(0.38, 0.55, a), lerpf(0.47, 0.35, a)), leg.darkened(0.3), r * 0.12, true)
	var body := PackedVector2Array()
	var shape := [[0.68, -0.02], [0.58, -0.2], [0.32, -0.36], [-0.05, -0.42 - breathe], [-0.4, -0.32],
		[-0.62, -0.08], [-0.58, 0.18], [-0.25, 0.36], [0.2, 0.36], [0.55, 0.18]]
	for pt in shape:
		body.append(P.call(float(pt[0]), float(pt[1]) + a * 0.04))
	poly(ci, body, black, 2.0)
	# the stripes: one from the snout over the eye along the back, one down the flank
	var top := PackedVector2Array([P.call(0.64, -0.08), P.call(0.42, -0.27), P.call(0.05, -0.34),
		P.call(-0.3, -0.27), P.call(-0.52, -0.1)])
	ci.draw_polyline(top, stripe, r * 0.13, true)
	var flank := PackedVector2Array([P.call(0.5, 0.1), P.call(0.15, 0.06), P.call(-0.2, 0.1), P.call(-0.42, 0.04)])
	ci.draw_polyline(flank, stripe, r * 0.09, true)
	ci.draw_circle(P.call(-0.05, -0.2), r * 0.06, black)
	# gloss along the back
	ci.draw_line(P.call(-0.25, -0.36), P.call(0.1, -0.4), Color(1, 1, 1, 0.45), r * 0.05, true)
	# near hind leg: a folded thigh at rest, kicked straight back in the air
	var hip: Vector2 = P.call(-0.36, 0.18)
	var knee: Vector2 = P.call(lerpf(-0.05, -0.75, a), lerpf(0.3, 0.32, a))
	var foot: Vector2 = P.call(lerpf(-0.42, -1.2, a), lerpf(0.46, 0.4, a))
	for seg in [[hip, knee, 0.26], [knee, foot, 0.18]]:
		ci.draw_line(seg[0], seg[1], ink, r * float(seg[2]) + 2.0, true)
		ci.draw_line(seg[0], seg[1], leg, r * float(seg[2]), true)
		for k in 2:
			ci.draw_circle((seg[0] as Vector2).lerp(seg[1], 0.3 + 0.4 * float(k)), r * 0.05, black)
	for k in 3:
		ci.draw_circle(foot + P.call(0.1 * float(k) - 0.1, 0.03), r * 0.045, leg.lightened(0.3))
	# near front leg and its toe pads
	var sh: Vector2 = P.call(0.35, 0.22)
	var hand: Vector2 = P.call(lerpf(0.45, 0.7, a), lerpf(0.5, 0.36, a))
	ci.draw_line(sh, hand, ink, r * 0.15 + 2.0, true)
	ci.draw_line(sh, hand, leg, r * 0.15, true)
	ci.draw_circle(sh.lerp(hand, 0.5), r * 0.045, black)
	for k in 3:
		ci.draw_circle(hand + P.call(0.08 * float(k) - 0.04, 0.02), r * 0.045, leg.lightened(0.3))
	# the big wet eye
	var eye: Vector2 = P.call(0.4, -0.2)
	circle(ci, eye, r * 0.15, black, 1.4)
	ci.draw_circle(eye + P.call(0.05, -0.05), r * 0.045, Color(1, 1, 1, 0.85))
	ink = keep


## A raised rat skeleton, side view: skull with long incisors, a hunched spine
## with hanging ribs, thin legs and a long tail of vertebrae.
static func ratbones(ci: CanvasItem, r: float, facing: float, t: float, ink_col: Color = OUTLINE) -> void:
	var keep := ink
	ink = ink_col
	var f := facing if absf(facing) > 0.01 else 1.0
	var bone := Color(0.93, 0.9, 0.8)
	var P := func(x: float, y: float) -> Vector2: return Vector2(x * f * r, y * r)
	var g: float = sin(t * 14.0)
	var B := func(a: Vector2, b: Vector2, w: float) -> void:
		ci.draw_line(a, b, ink, w + 2.0, true)
		ci.draw_line(a, b, bone, w, true)
	# tail
	var tail := PackedVector2Array()
	for i in 7:
		var k: float = float(i) / 6.0
		tail.append(P.call(-0.5 - 0.9 * k, 0.1 + 0.12 * k + sin(t * 6.0 + k * 4.0) * 0.08 * k))
	ci.draw_polyline(tail, ink, r * 0.1 + 2.0, true)
	ci.draw_polyline(tail, bone, r * 0.1, true)
	# far legs
	B.call(P.call(-0.42, 0.02), P.call(-0.36 - 0.12 * g, 0.55), r * 0.08)
	B.call(P.call(0.25, -0.08), P.call(0.32 + 0.12 * g, 0.55), r * 0.08)
	# spine
	var spine := PackedVector2Array([P.call(-0.48, 0.02), P.call(-0.3, -0.25), P.call(0.0, -0.35),
		P.call(0.25, -0.25), P.call(0.42, -0.15)])
	ci.draw_polyline(spine, ink, r * 0.14 + 2.0, true)
	ci.draw_polyline(spine, bone, r * 0.14, true)
	# ribs hanging off it
	for i in 4:
		var k: float = float(i) / 3.0
		var top: Vector2 = P.call(lerpf(-0.22, 0.22, k), lerpf(-0.3, -0.3, k) - 0.04 * sin(k * PI))
		var bot: Vector2 = top + P.call(0.06, 0.32 - 0.06 * absf(k - 0.5))
		ci.draw_line(top, bot, ink, r * 0.07 + 1.6, true)
		ci.draw_line(top, bot, bone, r * 0.07, true)
	# pelvis
	ellipse(ci, P.call(-0.44, 0.0), r * 0.13, r * 0.1, bone, 1.4)
	# near legs
	B.call(P.call(-0.44, 0.04), P.call(-0.3 + 0.12 * g, 0.3), r * 0.09)
	B.call(P.call(-0.3 + 0.12 * g, 0.3), P.call(-0.4 + 0.12 * g, 0.56), r * 0.08)
	B.call(P.call(0.28, -0.1), P.call(0.36 - 0.12 * g, 0.56), r * 0.08)
	# skull: long snout, dark socket with a cold glint, incisors
	var skull := PackedVector2Array([P.call(0.32, -0.38), P.call(0.6, -0.42), P.call(0.95, -0.2),
		P.call(0.9, -0.08), P.call(0.55, -0.02), P.call(0.34, -0.1)])
	poly(ci, skull, bone, 1.6)
	ci.draw_circle(P.call(0.55, -0.24), r * 0.09, Color(0.08, 0.06, 0.1))
	ci.draw_circle(P.call(0.56, -0.25), r * 0.035, Color(0.6, 1.0, 0.55))
	ci.draw_line(P.call(0.88, -0.1), P.call(0.86, 0.04), ink, r * 0.09, true)
	ci.draw_line(P.call(0.32, -0.36), P.call(0.36, -0.52), bone.darkened(0.15), r * 0.1, true)
	ink = keep


## The Obsidian Whelp rolled up like an armadillo lizard, seen from the side:
## the body bends round in a near ring, banded plates along the outside of the
## curve, the head at the front biting the tail tip with its eye shut, the wings
## folded flat along the top of its back and the little legs tucked in the middle.
static func _whelp_curled(ci: CanvasItem, r: float, f: float, body: Color, plate: Color, plate_dark: Color) -> void:
	var c := Vector2(0.0, r * 0.08)
	var ring: float = r * 0.56
	var n := 18
	# the spine: from the neck (upper front) back over the top, down the back,
	# under the belly and up to the tail tip at the mouth
	var pts := PackedVector2Array()
	var dirs: Array = []
	var widths: Array = []
	for i in n + 1:
		var s: float = float(i) / float(n)
		var a: float = deg_to_rad(-35.0 - 305.0 * s)
		var d := Vector2(cos(a) * f, sin(a))
		dirs.append(d)
		pts.append(c + d * ring)
		widths.append(r * (0.44 - 0.3 * s))
	# the hollow of the curl
	ci.draw_circle(c, ring * 0.48, Color(0.06, 0.05, 0.08, 0.9))
	# tucked feet with pale claws, inside the curl
	for k in [-0.35, 0.15]:
		var foot := c + Vector2(f * r * k, r * 0.12)
		ci.draw_circle(foot, r * 0.1, body.lightened(0.08))
		for j in 3:
			ci.draw_line(foot, foot + Vector2(f * r * (0.06 + 0.05 * float(j)), -r * 0.12), plate, 1.4, true)
	# the body itself: outline pass, then fill
	for i in n:
		ci.draw_line(pts[i], pts[i + 1], ink, float(widths[i]) + 4.0, true)
		ci.draw_circle(pts[i + 1], (float(widths[i + 1]) + 4.0) * 0.5, ink)
	for i in n:
		ci.draw_line(pts[i], pts[i + 1], body, float(widths[i]), true)
		ci.draw_circle(pts[i + 1], float(widths[i + 1]) * 0.5, body)
	# a paler belly line on the inside of the curve
	for i in range(1, n):
		var inner: Vector2 = pts[i] - dirs[i] * float(widths[i]) * 0.3
		var inner2: Vector2 = pts[i + 1] - dirs[i + 1] * float(widths[i + 1]) * 0.3
		ci.draw_line(inner, inner2, Color(0.32, 0.29, 0.38), float(widths[i]) * 0.22, true)
	# banded plates: one ring of scale per segment, each a flat shield on the
	# outside of the curve with a short blunt point, not a spike
	for i in range(1, n + 1):
		var d: Vector2 = dirs[i]
		var w: float = float(widths[i])
		var side := d.orthogonal() * w * 0.42
		var base: Vector2 = pts[i] + d * w * 0.18
		poly(ci, PackedVector2Array([base + side, base + d * w * 0.42 + side * 0.7, base + d * w * 0.58,
			base + d * w * 0.42 - side * 0.7, base - side]), plate, 1.3)
		ci.draw_line(base + side * 0.8, base - side * 0.8, plate_dark, 1.4, true)
	# wings folded flat along the top of the back, membrane and a finger bone
	var w0: Vector2 = c + Vector2(cos(deg_to_rad(-60.0)) * f, sin(deg_to_rad(-60.0))) * ring * 1.15
	var w1: Vector2 = c + Vector2(cos(deg_to_rad(-150.0)) * f, sin(deg_to_rad(-150.0))) * ring * 1.25
	var wtip: Vector2 = c + Vector2(cos(deg_to_rad(-170.0)) * f, sin(deg_to_rad(-170.0))) * ring * 1.55
	var wtop: Vector2 = c + Vector2(cos(deg_to_rad(-100.0)) * f, sin(deg_to_rad(-100.0))) * ring * 1.55
	var membrane := Color(0.3, 0.22, 0.38)
	poly(ci, PackedVector2Array([w0, wtop, wtip, w1]), membrane, 1.8)
	ci.draw_line(w0, wtip, membrane.lightened(0.2), 1.6, true)
	ci.draw_line(w0.lerp(wtop, 0.5), w1.lerp(wtip, 0.6), membrane.darkened(0.3), 1.2, true)
	# the head at the front, bowed down over the tail tip, eye shut
	var head := c + Vector2(cos(deg_to_rad(-12.0)) * f, sin(deg_to_rad(-12.0))) * ring * 1.12
	var snout: Vector2 = pts[n] + Vector2(f * r * 0.08, -r * 0.04)
	var face := body.lightened(0.14)
	poly(ci, PackedVector2Array([head + Vector2(-f * r * 0.12, -r * 0.12), head + Vector2(f * r * 0.24, -r * 0.08),
		snout + Vector2(f * r * 0.1, 0.0), snout + Vector2(-f * r * 0.06, -r * 0.02)]), face, 1.8)
	ellipse(ci, head, r * 0.32, r * 0.26, face, 2.0)
	# scale tiles on the crown of the head
	for k in 3:
		ci.draw_arc(head + Vector2(f * r * (0.1 * float(k) - 0.1), -r * 0.04), r * 0.07, PI, TAU, 6, plate_dark, 1.2, true)
	# plated brow and two swept-back horns
	for k in 3:
		var hb := head + Vector2(-f * r * (0.08 * float(k) - 0.06), -r * 0.17)
		poly(ci, PackedVector2Array([hb + Vector2(-f * r * 0.06, 0.0), hb + Vector2(-f * r * 0.16, -r * (0.12 + 0.05 * float(k))),
			hb + Vector2(f * r * 0.05, 0.0)]), plate, 1.2)
	ci.draw_arc(head + Vector2(f * r * 0.04, -r * 0.02), r * 0.08, 0.25, PI - 0.25, 8, Color(0.05, 0.05, 0.07), 2.0, true)


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
		"obsidian":
			creature(ci, "obsidian", r, 1.0, t)
		"wu":
			creature(ci, "wu", r, 1.0, t)
		"magma":
			creature(ci, "magma", r, 1.0, t)
		"neko":
			# the hat and staff stand well above her: shrink to keep them on the card
			creature(ci, "neko", r * 0.75, 1.0, t)
		"ratbones":
			creature(ci, "ratbones", r, 1.0, t)
		"gilgamesh":
			gil_pair(ci, c, r * 0.8, t)
		"enkidu":
			creature(ci, "enkidu", r, 1.0, t)
		"frog":
			creature(ci, "frog", r, 1.0, t)
		"chicken":
			creature(ci, "chicken", r, 1.0, t)
		"penny":
			creature(ci, "penny", r, 1.0, t)
		"pen":
			creature(ci, "pen", r, 1.0, t)
		"troll":
			# the tree reaches well past him: shrink so the crown stays on the card
			creature(ci, "troll", r * 0.55, 1.0, t)
		"laniakea":
			creature(ci, "laniakea", r, 1.0, t)
		"femme":
			creature(ci, "femme", r, 1.0, t)
		"shiesty":
			creature(ci, "shiesty", r, 1.0, t)
		"spiderling":
			creature(ci, "spiderling", r, 1.0, t)
		"spideregg":
			creature(ci, "spideregg", r, 1.0, t)
		"spider":
			creature(ci, "spider", r * 0.45, 1.0, t)
		"kraken":
			creature(ci, "kraken", r * 0.8, 1.0, t)
		"krakenarm":
			creature(ci, "krakenarm", r * 0.7, 1.0, t)
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
