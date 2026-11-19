extends Node2D

## Mockup: side towers as diamonds, against the hitbox they really have (a
## circle of 0.9 tiles) and Heroes standing where a melee troop stops to hit
## (centre 0.9 + 0.45 + 0.4 tiles out), coming in along the lane, on the
## diagonal and from the side. Each Hero is labelled with the gap between it and
## the drawn wall: 0 reads as "touching", more reads as "hitting thin air".
## Writes mockups/towers/diamond_towers.png.
## Run:  godot --path . res://scenes/tower_mock.tscn

const OUT_PATH := "res://mockups/towers/diamond_towers.png"
const SHEET := Vector2i(1600, 760)
const TILE := 64.0
const TOWER_R := 0.9
const HERO_R := 0.45
const HERO_REACH := 0.4
const TEAM := Color(0.168, 0.578, 0.523)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://mockups/towers"))
	var vp := SubViewport.new()
	vp.size = SHEET
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var s := Sheet.new()
	vp.add_child(s)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png(OUT_PATH)
	print("[towermock] -> ", OUT_PATH)
	get_tree().quit()


class Sheet extends Node2D:
	var font: Font = ThemeDB.fallback_font

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(SHEET)), Color(0.13, 0.14, 0.18))
		draw_string(font, Vector2(24, 38), "Side towers: square (now) and two diamonds.  Dashed ring = the real hitbox (0.9 tiles).  Heroes stand where melee stops to hit.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.95, 1.0))
		var panels := [
			["Square (today), 1.75 tiles", "square", 1.75],
			["Diamond, same keep turned 45 deg", "diamond", 1.75],
			["Diamond, smaller (tips at 1.06)", "diamond", 1.5],
		]
		for i in panels.size():
			var p: Array = panels[i]
			_panel(Rect2(24.0 + 524.0 * float(i), 64.0, 504.0, 672.0), String(p[0]), String(p[1]), float(p[2]))

	func _panel(r: Rect2, title: String, shape: String, side_t: float) -> void:
		draw_rect(r, Color(0.2, 0.21, 0.26))
		draw_string(font, r.position + Vector2(14, 28), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.88, 0.55))
		# a 7 x 7 patch of board, the tower on the centre corner as in the game
		var board := Rect2(r.position + Vector2((r.size.x - 7.0 * TILE) * 0.5, 48.0), Vector2(7.0, 7.0) * TILE)
		for gy in 7:
			for gx in 7:
				var c := Color(0.36, 0.5, 0.24) if (gx + gy) % 2 == 0 else Color(0.2, 0.42, 0.62)
				draw_rect(Rect2(board.position + Vector2(gx, gy) * TILE, Vector2(TILE, TILE)), c)
		var centre := board.get_center()
		var ink := TEAM.darkened(0.45)
		var side := side_t * TILE
		if shape == "square":
			draw_set_transform(centre, 0.0, Vector2.ONE)
			DDArt.tower(self, side, side, TEAM, 0.0, false, ink)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			DDArt.diamond_tower(self, centre, side, TEAM, 0.0, ink)
		# the hitbox
		_dashed_circle(centre, TOWER_R * TILE, Color(1.0, 0.35, 0.35, 0.95))
		# Heroes at contact: along the lane (from the left), the diagonal, the side
		var stop := TOWER_R + HERO_R + HERO_REACH - 0.03
		var lines: Array = []
		for ang_deg in [180.0, 225.0, 270.0]:
			var ang := deg_to_rad(ang_deg)
			var dir := Vector2.from_angle(ang)
			var at: Vector2 = centre + dir * stop * TILE
			draw_set_transform(at, 0.0, Vector2.ONE)
			DDArt.creature(self, "hero", HERO_R * TILE, 1.0 if dir.x <= 0.01 else -1.0, 0.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_arc(at, HERO_R * TILE, 0.0, TAU, 24, Color(1, 1, 1, 0.5), 1.5, true)
			var gap := stop - HERO_R - _wall(shape, side_t * 0.5, ang)
			lines.append([ang_deg, gap])
			draw_string(font, at + Vector2(-34, HERO_R * TILE + 18.0), "gap %.2f" % gap, HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
				Color(1, 1, 1))
		var y := board.end.y + 30.0
		var names := {180.0: "along the lane", 225.0: "diagonal", 270.0: "from the side"}
		for l in lines:
			var g: float = float(l[1])
			var verdict := "touching" if absf(g) < 0.08 else ("overlaps the wall" if g < 0.0 else "%.0f%% of a tile short" % (g * 100.0))
			draw_string(font, Vector2(r.position.x + 16, y), "%s: %s" % [String(names[l[0]]), verdict], HORIZONTAL_ALIGNMENT_LEFT,
				-1, 15, Color(0.85, 0.86, 0.9))
			y += 22.0

	## How far the drawn wall is from the centre in direction `ang`, in tiles.
	func _wall(shape: String, half: float, ang: float) -> float:
		var a := ang if shape == "square" else ang - PI * 0.25
		return half / maxf(absf(cos(a)), absf(sin(a)))

	func _dashed_circle(c: Vector2, rad: float, col: Color) -> void:
		var n := 36
		for i in n:
			if i % 2 == 1:
				continue
			draw_arc(c, rad, TAU * float(i) / float(n), TAU * float(i + 1) / float(n), 4, col, 2.5, true)
