extends Node2D

## Renders Trading-Card-Game style mockups of the cards into debug/cards/.
## Run:  godot --path . res://scenes/card_mock.tscn

var KINDS := ["lizard", "warren", "dragon", "chicken", "fireball", "hawk", "hedgehog", "fu"]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://debug/cards"))
	await get_tree().process_frame
	for k in KINDS:
		await _shot(k)
	get_tree().quit()


func _shot(kind: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(760, 1060)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	var face := CardFace.new()
	face.kind = kind
	vp.add_child(face)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png("res://debug/cards/card_%s.png" % kind)
	print("[card] ", kind, " -> ", img.get_size())
	vp.queue_free()


class CardFace extends Node2D:
	const W := 760.0
	const H := 1060.0
	const OUT := Color(0.13, 0.12, 0.16)
	const ATTACK_NAMES := {
		"dragon": "Claw", "chicken": "Pecking Fire", "fu": "Boomerang Throw",
		"slate": "Jawbreaker", "hawk": "Dive", "hedgehog": "Quills",
		"hero": "Sword", "alchemist": "Splash Potion", "zombie": "Claw",
		"snowman": "—", "idol": "Taunt",
		"fireball": "Fireball", "firebolt": "Firebolt",
		"lizard": "Spear", "warren": "Burrow",
	}
	var kind := "dragon"
	var font: Font = ThemeDB.fallback_font

	func _draw() -> void:
		var d: Dictionary = DDCard.get_card(kind)
		var accent: Color = d["accent"]
		var cream := Color(0.96, 0.93, 0.85)
		# card body + frame
		draw_rect(Rect2(0, 0, W, H), Color(0.99, 0.97, 0.92))
		draw_rect(Rect2(10, 10, W - 20, H - 20), cream)
		draw_rect(Rect2(10, 10, W - 20, H - 20), OUT, false, 5.0)
		# accent band across the top
		draw_rect(Rect2(12, 12, W - 24, 96), accent.darkened(0.35))
		draw_rect(Rect2(12, 12, W - 24, 96), OUT, false, 3.0)
		# cost medallion, top-left
		draw_circle(Vector2(68, 60), 33, Color(0.12, 0.1, 0.16))
		draw_circle(Vector2(68, 60), 33, accent.lightened(0.35), false, 3.0)
		draw_circle(Vector2(68, 60), 27, accent)
		var cost_txt := str(int(d["cost"]))
		draw_string(font, Vector2(41, 72), cost_txt, HORIZONTAL_ALIGNMENT_CENTER, 54, 30, Color(0.16, 0.1, 0.06))
		# name, top middle
		draw_string(font, Vector2(110, 74), String(d["name"]).to_upper(), HORIZONTAL_ALIGNMENT_CENTER,
			W - 300.0, 31, Color(1, 1, 1))
		# hp, top right
		var hp_txt := _hp_text(d)
		draw_string(font, Vector2(W - 190, 74), hp_txt, HORIZONTAL_ALIGNMENT_RIGHT, 170, 28, Color(1, 1, 1))
		_draw_art(d, accent)
		_draw_stats(d, accent, cream)
		_draw_attack(d, accent)
		_draw_flavor(d)
		# footer
		draw_string(font, Vector2(40, H - 34), "ILLUS. DEEP DRAFT", HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(0.42, 0.4, 0.36))
		draw_string(font, Vector2(W - 140, H - 34), "DD · ARENA", HORIZONTAL_ALIGNMENT_RIGHT, 100, 13,
			accent.darkened(0.1))

	func _hp_text(d: Dictionary) -> String:
		var hp := int(d["hp"])
		var n := int(d.get("count", 0))
		if d.has("swarm_offsets") and n <= 1:
			n = (d["swarm_offsets"] as Array).size()
		if n > 1:
			return "%d  ×%d" % [hp, n]
		if hp <= 0:
			return "—"
		return str(hp)

	func _draw_art(d: Dictionary, accent: Color) -> void:
		var box := Rect2(44, 122, W - 88, 452)
		# sky
		for i in 24:
			var f := float(i) / 23.0
			draw_rect(Rect2(box.position.x, box.position.y + f * box.size.y, box.size.x, box.size.y / 23.0 + 1.0),
				accent.lightened(0.72 - f * 0.34))
		# sun burst
		for i in 10:
			var a := TAU * float(i) / 10.0
			var p := box.get_center() + Vector2(cos(a), sin(a)) * 150.0
			draw_circle(p, 46.0 + 12.0 * sin(a * 3.0), Color(1, 1, 1, 0.16))
		# ground
		draw_colored_polygon(PackedVector2Array([
			Vector2(box.position.x, box.position.y + box.size.y),
			Vector2(box.position.x + box.size.x, box.position.y + box.size.y),
			Vector2(box.position.x + box.size.x, box.position.y + box.size.y - 110),
			Vector2(box.position.x, box.position.y + box.size.y - 80),
		]), accent.darkened(0.42))
		# creature
		draw_set_transform(Vector2(box.get_center().x, box.position.y + box.size.y - 150.0), 0.0, Vector2.ONE)
		if kind == "dragon":
			DDArt.dragon(self, 185.0, 1.0, 0.0, false)
		elif kind == "hawk":
			DDArt.bird(self, 150.0, 1.0, 0.0, true)
		elif kind == "fireball" or kind == "firebolt":
			DDArt.creature(self, kind, 118.0, 1.0, 0.0)
		else:
			DDArt.creature(self, kind, 165.0, 1.0, 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# frame
		draw_rect(box, Color(0.13, 0.12, 0.16, 0.9), false, 6.0)
		draw_rect(box.grow(-9), accent.lightened(0.45), false, 2.0)

	func _draw_stats(d: Dictionary, accent: Color, cream: Color) -> void:
		var y := 604.0
		var t := String(d["type"]).to_upper()
		draw_string(font, Vector2(46, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, accent.darkened(0.2))
		var spd := float(d.get("speed", 0.0))
		var right := "STATIONARY"
		if bool(d.get("stationary", false)):
			right = "STATIONARY"
		elif spd > 0.0:
			right = "SPEED %.2f" % spd
		draw_string(font, Vector2(W - 300, y), right, HORIZONTAL_ALIGNMENT_RIGHT, 254, 17,
			Color(0.35, 0.33, 0.3))

	func _draw_attack(d: Dictionary, accent: Color) -> void:
		var box := Rect2(44, 618, W - 88, 176)
		draw_rect(box, accent.lightened(0.6))
		draw_rect(box, OUT, false, 3.0)
		var name := String(ATTACK_NAMES.get(kind, "Attack"))
		var dmg := int(d.get("dmg", 0))
		draw_string(font, Vector2(66, 668), name, HORIZONTAL_ALIGNMENT_LEFT, 420, 26, Color(0.16, 0.12, 0.1))
		var dmg_txt := str(dmg) if dmg > 0 else "—"
		draw_string(font, Vector2(W - 190, 670), dmg_txt, HORIZONTAL_ALIGNMENT_RIGHT, 120, 32,
			accent.darkened(0.25))
		var line := _rate_line(d)
		draw_multiline_string(font, Vector2(66, 702), line, HORIZONTAL_ALIGNMENT_LEFT, W - 160, 16, 2,
			Color(0.3, 0.27, 0.24))
		var extra := _detail_line(d)
		draw_multiline_string(font, Vector2(66, 754), extra, HORIZONTAL_ALIGNMENT_LEFT, W - 160, 15, 2,
			Color(0.46, 0.42, 0.38))

	func _rate_line(d: Dictionary) -> String:
		var parts: Array = []
		var iv := float(d.get("interval", 0.0))
		if iv > 0.0:
			parts.append("every %.2f s" % iv)
		var n := int(d.get("count", 1))
		if d.has("swarm_offsets") and n <= 1:
			n = (d["swarm_offsets"] as Array).size()
		if n > 1:
			parts.append("%d bodies" % n)
		if d.has("lead_hp") and n > 1:
			parts.append("lead body %d hp" % int(d["lead_hp"]))
		if d.has("burn"):
			parts.append("applies %d burn" % int(d["burn"]))
		if d.has("knock"):
			parts.append("shoves %.1f tiles" % float(d["knock"]))
		if parts.is_empty():
			return "no attack"
		return "  ·  ".join(parts)

	func _detail_line(d: Dictionary) -> String:
		var bits: Array = []
		var reach := float(d.get("reach", 0.0))
		if reach > 0.0:
			bits.append("range %.1f tiles" % reach)
		if bool(d.get("hits_air", false)):
			bits.append("can hit air")
		if bool(d.get("giant", false)):
			bits.append("GIANT (immune to shove)")
		if bool(d.get("buildings_only", false)):
			bits.append("structures only")
		if bool(d.get("stationary", false)):
			bits.append("stationary")
		if String(d.get("launch", "")) != "":
			bits.append("fired from the %s tower" % ("king" if String(d["launch"]) == "king" else "nearest"))
		return " · ".join(bits) if bits.size() > 0 else ""


	func _draw_flavor(d: Dictionary) -> void:
		var box := Rect2(46, 806, W - 92, 176)
		draw_rect(box, Color(0.9, 0.87, 0.78), true)
		draw_rect(box, Color(0.7, 0.66, 0.56), false, 2.0)
		draw_multiline_string(font, Vector2(62, 840), String(d["blurb"]), HORIZONTAL_ALIGNMENT_LEFT,
			box.size.x - 34.0, 17, 5, Color(0.22, 0.2, 0.17))
