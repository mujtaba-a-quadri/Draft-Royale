extends Node2D

## Throwaway mockup: the same board rotated 90° into a landscape layout, with
## your side on the left and the hand along the bottom. godot --path . res://scenes/landscape_mock.tscn

const W := 1400.0
const H := 900.0
const TILE := 40.0
const ORIGIN := Vector2(100.0, 58.0)

const GRASS_A := Color(0.42, 0.62, 0.3)
const GRASS_B := Color(0.38, 0.57, 0.27)
const BAND_A := Color(0.36, 0.5, 0.26)
const BAND_B := Color(0.31, 0.44, 0.22)
const WATER := Color(0.2, 0.47, 0.72)
const WOOD := Color(0.62, 0.45, 0.3)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://mockups"))
	await get_tree().process_frame
	var vp := SubViewport.new()
	vp.size = Vector2i(int(W), int(H))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	vp.add_child(LandFace.new())
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("res://mockups/landscape_preview.png")
	print("[land] saved")
	get_tree().quit()


class LandFace extends Node2D:
	func p(col: float, row: float) -> Vector2:
		return ORIGIN + Vector2((29.0 - row + 0.5) * TILE, (col + 0.5) * TILE)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.1, 0.15))
		# board
		for row in 30:
			var lo := 0 if (row >= 11 and row <= 18) else 1
			var hi := 17 if (row >= 11 and row <= 18) else 16
			for col in range(lo, hi + 1):
				var at := ORIGIN + Vector2((29.0 - row) * TILE, float(col) * TILE)
				var base := GRASS_A if (row + col) % 2 == 0 else GRASS_B
				if row >= 11 and row <= 18:
					base = BAND_A if (row + col) % 2 == 0 else BAND_B
				if row >= 14 and row <= 15:
					base = WATER
				draw_rect(Rect2(at, Vector2(TILE, TILE)), base)
		# bridges (vertical now)
		for bc in [5, 13]:
			for row in [14, 15]:
				var at := ORIGIN + Vector2((29.0 - row) * TILE, float(bc) * TILE)
				draw_rect(Rect2(at, Vector2(TILE, TILE)), WOOD)
		# deployment zone tint: your half (rows 19-29 -> left)
		for row in range(19, 30):
			draw_rect(Rect2(ORIGIN + Vector2((29.0 - row) * TILE, TILE), Vector2(TILE, 16.0 * TILE)),
				Color(0.36, 0.62, 0.95, 0.1))
		# towers
		for t in [[9, 3, 1], [4, 7, 1], [14, 7, 1], [9, 27, 0], [4, 23, 0], [14, 23, 0]]:
			var at := p(float(t[0]), float(t[1]))
			var col := Color(0.4, 0.66, 0.98) if int(t[2]) == 0 else Color(0.95, 0.44, 0.46)
			draw_rect(Rect2(at - Vector2(26, 30), Vector2(52, 60)), col.darkened(0.2))
			draw_rect(Rect2(at - Vector2(26, 30), Vector2(52, 60)), Color(0.1, 0.09, 0.12), false, 2.0)
		# units
		for e in [["slate", 8.5, 20.5, 0], ["hedgehog", 6.5, 18.6, 0], ["hedgehog", 7.2, 18.2, 0],
				["hedgehog", 6.9, 19.3, 0], ["chicken", 11.5, 21.0, 0], ["lizard", 9.5, 17.6, 0],
				["lizard", 8.8, 18.3, 0], ["lizard", 10.2, 18.3, 0],
				["hero", 9.0, 7.5, 1], ["dragon", 12.0, 10.0, 1], ["fu", 4.0, 12.0, 1]]:
			var at := p(float(e[1]), float(e[2]))
			draw_set_transform(at, 0.0, Vector2.ONE)
			if String(e[0]) == "dragon":
				DDArt.dragon(self, 30.0, 1.0, 0.0, false)
			else:
				DDArt.creature(self, String(e[0]), 17.0, 1.0, 0.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# HUD strip
		draw_rect(Rect2(0, 0, W, 50), Color(0.1, 0.1, 0.15))
		draw_string(ThemeDB.fallback_font, Vector2(24, 33), "YOU 6  ·  THEM 2", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.9, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(W - 200, 33), "5 / 10 GOLD", HORIZONTAL_ALIGNMENT_RIGHT, 176, 20, Color(1.0, 0.86, 0.4))
		# hand along the bottom
		var kinds := ["hero", "slate", "fireball", "hedgehog", "warren"]
		for i in kinds.size():
			var x := 120.0 + float(i) * 250.0
			var box := Rect2(x, 782.0, 230.0, 108.0)
			var d: Dictionary = DDCard.get_card(String(kinds[i]))
			draw_rect(box, Color(0.14, 0.14, 0.2))
			draw_rect(box, d["accent"], false, 2.0)
			draw_circle(box.position + Vector2(30, 34), 16.0, d["accent"])
			draw_string(ThemeDB.fallback_font, box.position + Vector2(18, 42), str(int(d["cost"])),
				HORIZONTAL_ALIGNMENT_CENTER, 24, 18, Color(0.15, 0.1, 0.06))
			draw_string(ThemeDB.fallback_font, box.position + Vector2(52, 30), String(d["name"]),
				HORIZONTAL_ALIGNMENT_LEFT, 170, 16, Color(0.92, 0.93, 1.0))
			draw_multiline_string(ThemeDB.fallback_font, box.position + Vector2(52, 52), String(d["blurb"]),
				HORIZONTAL_ALIGNMENT_LEFT, 166, 11, 2, Color(0.65, 0.67, 0.78))
			draw_set_transform(box.position + Vector2(190, 80), 0.0, Vector2.ONE)
			DDArt.icon(self, String(kinds[i]), Vector2.ZERO, 20.0, 0.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
