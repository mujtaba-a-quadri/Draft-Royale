extends Node2D

## Throwaway mockup: what the current board and art look like projected into a
## 2:1 isometric view. Run: godot --path . res://scenes/iso_mock.tscn

const W := 1700.0
const H := 950.0
const TW := 60.0
const TH := 30.0
const ORIGIN := Vector2(W * 0.5, 120.0)

const GRASS_A := Color(0.42, 0.62, 0.3)
const GRASS_B := Color(0.38, 0.57, 0.27)
const BAND_A := Color(0.36, 0.5, 0.26)
const BAND_B := Color(0.31, 0.44, 0.22)
const WATER := Color(0.2, 0.47, 0.72)
const WOOD := Color(0.62, 0.45, 0.3)

var units: Array = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://mockups"))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var vp := SubViewport.new()
	vp.size = Vector2i(int(W), int(H))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var face := IsoFace.new()
	vp.add_child(face)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("res://mockups/iso_preview.png")
	print("[iso] saved")
	get_tree().quit()


class IsoFace extends Node2D:
	func p(col: float, row: float) -> Vector2:
		return ORIGIN + Vector2((col - row) * TW * 0.5, (col + row) * TH * 0.5)

	func diamond(col: float, row: float) -> PackedVector2Array:
		return PackedVector2Array([
			p(col - 0.5, row - 0.5), p(col + 0.5, row - 0.5),
			p(col + 0.5, row + 0.5), p(col - 0.5, row + 0.5),
		])

	func _draw() -> void:
		var d: Dictionary = DDCard.get_card("slate")
		# backdrop
		draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.1, 0.15))
		# board tiles
		for row in 30:
			var lo := 0 if (row >= 11 and row <= 18) else 1
			var hi := 17 if (row >= 11 and row <= 18) else 16
			for col in range(lo, hi + 1):
				var poly := diamond(float(col), float(row))
				var base := GRASS_A if (row + col) % 2 == 0 else GRASS_B
				if row >= 11 and row <= 18:
					base = BAND_A if (row + col) % 2 == 0 else BAND_B
				if row >= 14 and row <= 15:
					base = WATER
				draw_colored_polygon(poly, base)
				draw_polyline(PackedVector2Array([poly[0], poly[1], poly[2], poly[3], poly[0]]),
					Color(0, 0, 0, 0.05), 1.0)
		# bridges
		for bc in [5, 13]:
			for row in [14, 15]:
				draw_colored_polygon(diamond(float(bc), float(row)), WOOD)
				var p0 := diamond(float(bc), float(row))
				draw_polyline(PackedVector2Array([p0[0], p0[1], p0[2], p0[3], p0[0]]), Color(0.2, 0.14, 0.1), 1.5)
		# control tint
		for row in range(16, 20):
			for col in range(6, 11):
				draw_colored_polygon(diamond(float(col), float(row)), Color(0.36, 0.62, 0.95, 0.3))
		# towers + units, depth sorted
		var items: Array = []
		for t in [[9, 3, true, 1], [4, 7, false, 1], [14, 7, false, 1],
				[9, 27, true, 0], [4, 23, false, 0], [14, 23, false, 0]]:
			items.append({"col": float(t[0]), "row": float(t[1]), "kind": "tower", "team": int(t[3])})
		for e in [["slate", 8.5, 20.5, 0], ["hedgehog", 6.5, 18.6, 0], ["hedgehog", 7.2, 18.2, 0],
				["hedgehog", 6.9, 19.3, 0], ["chicken", 11.5, 21.0, 0], ["lizard", 9.5, 17.6, 0],
				["lizard", 8.8, 18.3, 0], ["lizard", 10.2, 18.3, 0],
				["hero", 9.0, 7.5, 1], ["dragon", 12.0, 10.0, 1], ["fu", 4.0, 12.0, 1]]:
			items.append({"col": float(e[1]), "row": float(e[2]), "kind": String(e[0]), "team": int(e[3])})
		items.sort_custom(func(a, b): return a["col"] + a["row"] < b["col"] + b["row"])
		for it in items:
			var at := p(it["col"], it["row"])
			if it["kind"] == "tower":
				_draw_tower(at, it["team"])
			else:
				_draw_unit(at, it["kind"], it["team"])

	func _shadow(at: Vector2, r: float) -> void:
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-r, 0), at + Vector2(0, -r * 0.5), at + Vector2(r, 0), at + Vector2(0, r * 0.5),
		]), Color(0, 0, 0, 0.25))

	func _draw_tower(at: Vector2, team: int) -> void:
		var col := Color(0.4, 0.66, 0.98) if team == 0 else Color(0.95, 0.44, 0.46)
		var h := 96.0
		_shadow(at, 40.0)
		# left face
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-30, 0), at + Vector2(0, 15), at + Vector2(0, 15 - h), at + Vector2(-30, -h),
		]), col.darkened(0.28))
		# right face
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(30, 0), at + Vector2(0, 15), at + Vector2(0, 15 - h), at + Vector2(30, -h),
		]), col.darkened(0.12))
		# top
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(0, -h - 15), at + Vector2(30, -h), at + Vector2(0, -h + 15), at + Vector2(-30, -h),
		]), col.lightened(0.18))
		draw_polyline(PackedVector2Array([
			at + Vector2(-30, 0), at + Vector2(0, 15), at + Vector2(30, 0),
			at + Vector2(30, -h), at + Vector2(0, -h + 15), at + Vector2(-30, -h), at + Vector2(-30, 0),
		]), Color(0.1, 0.09, 0.12), 2.0)

	func _draw_unit(at: Vector2, kind: String, team: int) -> void:
		_shadow(at, 21.0)
		var lift := -24.0
		draw_set_transform(at + Vector2(0, lift), 0.0, Vector2.ONE)
		if kind == "dragon":
			DDArt.dragon(self, 44.0, 1.0, 0.0, false)
		elif kind == "tower":
			pass
		else:
			DDArt.creature(self, kind, 20.0, 1.0, 0.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# team pip
		var tc := Color(0.45, 0.7, 1.0) if team == 0 else Color(1.0, 0.5, 0.5)
		draw_circle(at + Vector2(0, -58), 6.0, tc)
		draw_arc(at + Vector2(0, -58), 6.0, 0.0, TAU, 12, Color(0.1, 0.09, 0.12), 1.5, true)
