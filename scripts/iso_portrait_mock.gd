extends Node2D

## Throwaway mockups of a portrait board, your towers and hand at the bottom,
## the opponent at the top. Two renders from the same scene graph:
##   mockups/iso_portrait.png  tilted 3/4 view (axis-aligned board, far end
##                             recedes; what Clash Royale does)
##   mockups/iso_true.png      true 2:1 isometric: diamond tiles, and the arena
##                             is the set of iso cells inside a tall screen
##                             rectangle, so it still runs bottom to top; its
##                             side edges and the river banks come out jagged
##                             and the towers are diamond footprints
## Uses the live palette, card faces and creature art.
## Run: godot --path . res://scenes/iso_portrait_mock.tscn

const W := 1080.0
const H := 1920.0
const COLS := 18
const ROWS := 30
const TW := 56.0          # tilted view: tile width at the near edge, px
const TH := 43.0          # tilted view: row depth at the near edge, px
const FAR := 0.78         # tilted view: far edge width / near edge width
const BOARD_TOP := 190.0
const CX := W * 0.5

# true iso: a cell is a 2:1 diamond IW x IH; d = i - j is the screen column
# (IW/2 apart), s = i + j the screen row (IH/2 apart)
const IW := 84.0
const IH := 42.0
const IZ := 50.0          # px per tile of height
const ID := 11            # |d| <= ID
const IS := 51            # 0 <= s <= IS
const ITOP := 196.0
const RIVER_S := [24, 25, 26]
const BRIDGE_D := [-5, 5]

const GRASS_A := Color(0.149, 0.42, 0.58)
const GRASS_B := Color(0.33, 0.46, 0.24)
const RIVER := Color(0.678, 0.332, 0.139)
const RIVER_HI := Color(1.0, 0.62, 0.3)
const WOOD := Color(0.62, 0.45, 0.3)
const SLAB := Color(0.2, 0.16, 0.14)
const BG := Color(0.07, 0.07, 0.11)
const TEAM := [Color(0.306, 0.517, 0.151), Color(0.168, 0.578, 0.523)]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://mockups"))
	for true_iso in [false, true]:
		var vp := SubViewport.new()
		vp.size = Vector2i(int(W), int(H))
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var face := Face.new()
		face.true_iso = true_iso
		vp.add_child(face)
		for i in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var out := "res://mockups/iso_true.png" if true_iso else "res://mockups/iso_portrait.png"
		vp.get_texture().get_image().save_png(out)
		print("[iso] saved " + out)
		vp.queue_free()
	get_tree().quit()


class Face extends Node2D:
	var true_iso := false

	# ---------------------------------------------------------------- projection
	## tilted view: width scale at a row (0 = far / enemy end)
	func s(row: float) -> float:
		if true_iso:
			return 1.0
		return lerpf(FAR, 1.0, clampf(row / float(ROWS), 0.0, 1.0))

	func ry(row: float) -> float:
		return BOARD_TOP + TH * (FAR * row + (1.0 - FAR) * row * row / (2.0 * float(ROWS)))

	## Board point from the game's own coordinates (col 0..18 across, row 0..30
	## from the enemy end), h tiles up. Both views place pieces through this.
	func p(col: float, row: float, h: float = 0.0) -> Vector2:
		if true_iso:
			var d: float = (col - float(COLS) * 0.5) * 1.2
			var sc: float = row * float(IS + 1) / float(ROWS)
			return Vector2(CX + d * IW * 0.5, ITOP + sc * IH * 0.5 - h * IZ)
		return Vector2(CX + (col - float(COLS) * 0.5) * TW * s(row), ry(row) - h * TW * s(row) * 0.9)

	## true iso: grid point (u, v), h tiles up
	func q(u: float, v: float, h: float = 0.0) -> Vector2:
		return Vector2(CX + (u - v) * IW * 0.5, ITOP + (u + v) * IH * 0.5 - h * IZ)

	func inside(i: int, j: int) -> bool:
		return absi(i - j) <= ID and i + j >= 0 and i + j <= IS

	func is_river(i: int, j: int) -> bool:
		return RIVER_S.has(i + j) and not is_bridge(i, j)

	func is_bridge(i: int, j: int) -> bool:
		if not RIVER_S.has(i + j) and i + j != RIVER_S[0] - 1 and i + j != RIVER_S[-1] + 1:
			return false
		# a solid zigzag strip: rows alternate 3 and 2 cells wide (cells in a row
		# sit two columns apart), which reads as one vertical deck
		for bd in BRIDGE_D:
			if absi((i - j) - bd) <= 2:
				return true
		return false

	func quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, fill: Color, line: Color = Color(0, 0, 0, 0), w: float = 1.5) -> void:
		draw_colored_polygon(PackedVector2Array([a, b, c, d]), fill)
		if line.a > 0.0:
			draw_polyline(PackedVector2Array([a, b, c, d, a]), line, w, true)

	## tilted view box: front face, the side facing the centre line, top
	func box(x0: float, x1: float, r0: float, r1: float, h0: float, h1: float, col: Color, ink: Color) -> void:
		var mid := (x0 + x1) * 0.5
		if mid < float(COLS) * 0.5 - 0.3:
			quad(p(x1, r0, h0), p(x1, r1, h0), p(x1, r1, h1), p(x1, r0, h1), col.darkened(0.3), ink)
		elif mid > float(COLS) * 0.5 + 0.3:
			quad(p(x0, r0, h0), p(x0, r1, h0), p(x0, r1, h1), p(x0, r0, h1), col.darkened(0.3), ink)
		quad(p(x0, r1, h0), p(x1, r1, h0), p(x1, r1, h1), p(x0, r1, h1), col.darkened(0.12), ink)
		quad(p(x0, r0, h1), p(x1, r0, h1), p(x1, r1, h1), p(x0, r1, h1), col.lightened(0.12), ink)

	## true iso box over grid u0..u1, v0..v1: the two near faces and the top
	func ibox(u0: float, u1: float, v0: float, v1: float, h0: float, h1: float, col: Color, ink: Color) -> void:
		quad(q(u0, v1, h0), q(u1, v1, h0), q(u1, v1, h1), q(u0, v1, h1), col.darkened(0.3), ink)
		quad(q(u1, v1, h0), q(u1, v0, h0), q(u1, v0, h1), q(u1, v1, h1), col.darkened(0.12), ink)
		quad(q(u0, v0, h1), q(u1, v0, h1), q(u1, v1, h1), q(u0, v1, h1), col.lightened(0.12), ink)

	# --------------------------------------------------------------------- scene
	func _draw() -> void:
		draw_rect(Rect2(0, 0, W, H), BG)
		for i in 12:
			var f := float(i) / 11.0
			draw_rect(Rect2(0, BOARD_TOP - 160.0 + f * 160.0, W, 14.0), Color(0.14, 0.12, 0.22, 0.08 * (1.0 - f)))
		if true_iso:
			_board_iso()
		else:
			_board()
		_objects()
		_hud_top()
		_hud_bottom()

	func _board() -> void:
		var dep := 0.55
		quad(p(0, ROWS), p(COLS, ROWS), p(COLS, ROWS, -dep), p(0, ROWS, -dep), SLAB.lightened(0.08))
		quad(p(0, 0), p(0, ROWS), p(0, ROWS, -dep), p(0, 0, -dep), SLAB)
		quad(p(COLS, 0), p(COLS, ROWS), p(COLS, ROWS, -dep), p(COLS, 0, -dep), SLAB)
		for row in ROWS:
			for col in COLS:
				var r := float(row)
				var c := float(col)
				var base := GRASS_A if (row + col) % 2 == 0 else GRASS_B
				if row >= 11 and row <= 18:
					base = base.darkened(0.25)
				if row >= 14 and row <= 15:
					continue
				quad(p(c, r), p(c + 1, r), p(c + 1, r + 1), p(c, r + 1), base)
		for row in range(16, 30):
			for col in COLS:
				var r := float(row)
				var c := float(col)
				quad(p(c, r), p(c + 1, r), p(c + 1, r + 1), p(c, r + 1), Color(TEAM[0].r, TEAM[0].g, TEAM[0].b, 0.08))
		var sink := 0.22
		quad(p(0, 14, -sink), p(COLS, 14, -sink), p(COLS, 16, -sink), p(0, 16, -sink), RIVER)
		quad(p(0, 14), p(COLS, 14), p(COLS, 14, -sink), p(0, 14, -sink), SLAB.lightened(0.15))
		for i in 26:
			var c := 0.4 + float(i) * 0.68
			var r := 14.35 + 0.9 * fmod(float(i) * 0.37, 1.0)
			draw_line(p(c, r, -sink), p(c + 0.35, r, -sink), Color(RIVER_HI.r, RIVER_HI.g, RIVER_HI.b, 0.55), 2.0, true)
		for bc in [5.0, 13.0]:
			var x0: float = bc - 0.15
			var x1: float = bc + 1.15
			quad(p(x0, 13.8, 0.05), p(x1, 13.8, 0.05), p(x1, 16.2, 0.05), p(x0, 16.2, 0.05), WOOD, WOOD.darkened(0.5), 2.0)
			quad(p(x0, 16.2, 0.05), p(x1, 16.2, 0.05), p(x1, 16.2, -0.15), p(x0, 16.2, -0.15), WOOD.darkened(0.35))
			for k in 9:
				var r: float = 13.95 + float(k) * 0.27
				draw_line(p(x0, r, 0.05), p(x1, r, 0.05), WOOD.darkened(0.3), 1.5, true)
			for xr in [x0, x1]:
				draw_line(p(xr, 13.8, 0.35), p(xr, 16.2, 0.35), WOOD.darkened(0.45), 3.0, true)
				for k in 4:
					var r2: float = 13.85 + float(k) * 0.77
					draw_line(p(xr, r2, 0.05), p(xr, r2, 0.35), WOOD.darkened(0.45), 2.5, true)
		var gc := 3.0
		var gr := 18.5
		quad(p(gc, gr), p(gc + 2, gr), p(gc + 2, gr + 2), p(gc, gr + 2), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.75), 2.0)

	## The iso arena: every cell inside the screen rectangle, a checker of
	## diamonds, earth faces under the jagged near edges, the river as a sunk
	## band of diamonds with its far banks showing, and two zigzag bridges.
	func _board_iso() -> void:
		var cells: Array = []
		for sv in IS + 1:
			for d in range(-ID, ID + 1):
				if (sv + d) % 2 != 0:
					continue
				cells.append(Vector2i((sv + d) / 2, (sv - d) / 2))
		var dep := 0.5
		var sink := 0.22
		for c in cells:
			var i: int = c.x
			var j: int = c.y
			var fi := float(i)
			var fj := float(j)
			if is_river(i, j):
				quad(q(fi, fj, -sink), q(fi + 1, fj, -sink), q(fi + 1, fj + 1, -sink), q(fi, fj + 1, -sink), RIVER)
				# far banks: the walls behind the water, where land is higher
				if inside(i - 1, j) and not is_river(i - 1, j):
					quad(q(fi, fj), q(fi, fj + 1), q(fi, fj + 1, -sink), q(fi, fj, -sink), SLAB.lightened(0.15))
				if inside(i, j - 1) and not is_river(i, j - 1):
					quad(q(fi, fj), q(fi + 1, fj), q(fi + 1, fj, -sink), q(fi, fj, -sink), SLAB.lightened(0.05))
				if (i * 7 + j * 3) % 4 == 0:
					var m: Vector2 = q(fi + 0.5, fj + 0.5, -sink)
					draw_line(m - Vector2(10, 0), m + Vector2(10, 0), Color(RIVER_HI.r, RIVER_HI.g, RIVER_HI.b, 0.6), 2.0, true)
			else:
				var sv: int = i + j
				var base := GRASS_A if sv % 2 == 0 else GRASS_B
				if sv >= 19 and sv <= 31:
					base = base.darkened(0.25)
				var h := 0.0
				if is_bridge(i, j) and RIVER_S.has(sv):
					base = WOOD
					h = 0.05
				quad(q(fi, fj, h), q(fi + 1, fj, h), q(fi + 1, fj + 1, h), q(fi, fj + 1, h), base)
				if is_bridge(i, j) and RIVER_S.has(sv):
					draw_line(q(fi + 0.25, fj, h), q(fi + 0.25, fj + 1, h), WOOD.darkened(0.3), 1.5, true)
					draw_line(q(fi + 0.5, fj, h), q(fi + 0.5, fj + 1, h), WOOD.darkened(0.3), 1.5, true)
					draw_line(q(fi + 0.75, fj, h), q(fi + 0.75, fj + 1, h), WOOD.darkened(0.3), 1.5, true)
					# the deck's edge over the water
					if is_river(i, j + 1) or not inside(i, j + 1):
						quad(q(fi, fj + 1, h), q(fi + 1, fj + 1, h), q(fi + 1, fj + 1, -0.15), q(fi, fj + 1, -0.15), WOOD.darkened(0.4))
					if is_river(i + 1, j) or not inside(i + 1, j):
						quad(q(fi + 1, fj + 1, h), q(fi + 1, fj, h), q(fi + 1, fj, -0.15), q(fi + 1, fj + 1, -0.15), WOOD.darkened(0.25))
				if sv >= 29:
					quad(q(fi, fj), q(fi + 1, fj), q(fi + 1, fj + 1), q(fi, fj + 1), Color(TEAM[0].r, TEAM[0].g, TEAM[0].b, 0.08))
			# the jagged near edges of the board: earth faces under the cell's
			# two front edges wherever the board stops
			if not inside(i, j + 1):
				quad(q(fi, fj + 1), q(fi + 1, fj + 1), q(fi + 1, fj + 1, -dep), q(fi, fj + 1, -dep), SLAB)
			if not inside(i + 1, j):
				quad(q(fi + 1, fj + 1), q(fi + 1, fj), q(fi + 1, fj, -dep), q(fi + 1, fj + 1, -dep), SLAB.lightened(0.08))
		# deploy ghost: a 2x2 diamond of cells
		var g0 := Vector2(21.0, 12.0)
		quad(q(g0.x, g0.y), q(g0.x + 2, g0.y), q(g0.x + 2, g0.y + 2), q(g0.x, g0.y + 2), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.75), 2.0)

	# ------------------------------------------------------------------- objects
	func _objects() -> void:
		var items: Array = []
		for t in [[9.0, 2.8, 3.0, 1.6, 1, true, 1.0], [4.0, 6.8, 2.0, 1.25, 1, false, 0.62],
				[14.0, 6.8, 2.0, 1.25, 1, false, 1.0],
				[9.0, 27.2, 3.0, 1.6, 0, true, 1.0], [4.0, 23.2, 2.0, 1.25, 0, false, 0.86],
				[14.0, 23.2, 2.0, 1.25, 0, false, 1.0]]:
			items.append({"tower": t, "row": float(t[1]) + float(t[2]) * 0.5})
		var u: Array = [
			["troll", 5.6, 10.2, 1, 1.0, {}],
			["hedgehog", 4.2, 10.9, 1, 1.0, {"curled": true}],
			["hedgehog", 3.4, 9.8, 1, 1.0, {}],
			["gilgamesh", 5.2, 12.6, 0, -1.0, {}],
			["enkidu", 6.6, 12.9, 0, -1.0, {"spear": false}],
			["laniakea", 12.6, 11.4, 1, -1.0, {}],
			["penny", 14.0, 12.1, 1, -1.0, {}],
			["aphid", 13.2, 15.0, 1, -1.0, {"fly": true}],
			["neko", 12.8, 19.6, 0, 1.0, {}],
			["ratbones", 12.0, 18.6, 0, -1.0, {}],
			["ratbones", 13.7, 18.7, 0, 1.0, {}],
			["wu", 9.9, 21.4, 0, -1.0, {}],
			["obsidian", 7.4, 24.9, 0, 1.0, {"curled": true}],
			["hawk", 8.3, 7.8, 1, 1.0, {"fly": true, "lead": true}],
			["hawk", 7.5, 7.0, 1, 1.0, {"fly": true}],
			["hawk", 9.1, 7.0, 1, 1.0, {"fly": true}],
		]
		for e in u:
			items.append({"unit": e, "row": float(e[2])})
		items.sort_custom(func(a, b): return float(a["row"]) < float(b["row"]))
		for pc in [[12.0, 18.6], [13.7, 18.7]]:
			_pentagram(float(pc[0]), float(pc[1]))
		for it in items:
			if it.has("tower"):
				if true_iso:
					_tower_iso(it["tower"])
				else:
					_tower(it["tower"])
			else:
				_unit(it["unit"])
		_effects()

	func _tower(t: Array) -> void:
		var c: float = t[0]
		var r: float = t[1]
		var half: float = float(t[2]) * 0.5
		var hgt: float = t[3]
		var team: int = t[4]
		var crown: bool = t[5]
		var col: Color = TEAM[team]
		var ink: Color = col.darkened(0.45)
		quad(p(c - half - 0.15, r - half + 0.2), p(c + half + 0.35, r - half + 0.2),
			p(c + half + 0.35, r + half + 0.25), p(c - half - 0.15, r + half + 0.25), Color(0, 0, 0, 0.3))
		box(c - half - 0.1, c + half + 0.1, r - half - 0.1, r + half + 0.1, 0.0, 0.18, Color(0.5, 0.48, 0.46), Color(0.2, 0.18, 0.18))
		box(c - half, c + half, r - half, r + half, 0.18, hgt, col, ink)
		var n := 4 if crown else 3
		for edge in [r - half, r + half - 0.32]:
			for i in n:
				var x0: float = c - half + (float(i) + 0.15) * (half * 2.0 / float(n))
				box(x0, x0 + half * 2.0 / float(n) * 0.6, edge, edge + 0.32, hgt, hgt + 0.28, col.lightened(0.06), ink)
		var wc: Vector2 = p(c, r + half, hgt * 0.55)
		var ww: float = TW * s(r + half) * 0.22
		draw_rect(Rect2(wc - Vector2(ww * 0.5, ww * 0.7), Vector2(ww, ww * 1.3)), Color(0.12, 0.1, 0.16), true)
		draw_rect(Rect2(wc - Vector2(ww * 0.5, ww * 0.7), Vector2(ww, ww * 0.4)), Color(1.0, 0.85, 0.45, 0.35), true)
		_tower_crown_bar(p(c, r, hgt + 0.28), TW * s(r), float(t[2]), team, crown, float(t[6]))

	## true iso tower: a diamond footprint snapped to the cells under it, two
	## lit faces, merlons round the rim, a window on each face
	func _tower_iso(t: Array) -> void:
		var n: int = int(t[2])
		var hgt: float = t[3]
		var team: int = t[4]
		var crown: bool = t[5]
		var col: Color = TEAM[team]
		var ink: Color = col.darkened(0.45)
		var d: float = (float(t[0]) - float(COLS) * 0.5) * 1.2
		var sc: float = float(t[1]) * float(IS + 1) / float(ROWS)
		var u0: float = roundf((sc + d) * 0.5 - float(n) * 0.5)
		var v0: float = roundf((sc - d) * 0.5 - float(n) * 0.5)
		var u1: float = u0 + float(n)
		var v1: float = v0 + float(n)
		# shadow falls toward the near-right
		quad(q(u0 + 0.3, v0, 0), q(u1 + 0.5, v0, 0), q(u1 + 0.5, v1 + 0.2, 0), q(u0 + 0.3, v1 + 0.2, 0), Color(0, 0, 0, 0.3))
		ibox(u0 - 0.1, u1 + 0.1, v0 - 0.1, v1 + 0.1, 0.0, 0.18, Color(0.5, 0.48, 0.46), Color(0.2, 0.18, 0.18))
		ibox(u0, u1, v0, v1, 0.18, hgt, col, ink)
		# windows, one per near face
		var wl: Vector2 = q(u0 + float(n) * 0.5, v1, hgt * 0.55)
		var wr: Vector2 = q(u1, v0 + float(n) * 0.5, hgt * 0.55)
		for wc in [wl, wr]:
			var sk: float = -1.0 if wc == wl else 1.0
			var a: Vector2 = wc + Vector2(-7, 4.0 * sk * -1.0) + Vector2(0, -12)
			quad(a, a + Vector2(14, -7.0 * sk), a + Vector2(14, -7.0 * sk + 22), a + Vector2(0, 22), Color(0.12, 0.1, 0.16))
			quad(a, a + Vector2(14, -7.0 * sk), a + Vector2(14, -7.0 * sk + 7), a + Vector2(0, 7), Color(1.0, 0.85, 0.45, 0.35))
		# merlons round the rim, far ones first
		var m: float = 0.34
		var spots: Array = []
		var k := n + 1
		for i in k:
			var f: float = float(i) / float(k - 1) * (float(n) - m)
			spots.append(Vector2(u0 + f, v0))
			spots.append(Vector2(u0 + f, v1 - m))
			spots.append(Vector2(u0, v0 + f))
			spots.append(Vector2(u1 - m, v0 + f))
		spots.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
		for sp in spots:
			ibox(sp.x, sp.x + m, sp.y, sp.y + m, hgt, hgt + 0.28, col.lightened(0.06), ink)
		var top: Vector2 = q((u0 + u1) * 0.5, (v0 + v1) * 0.5, hgt + 0.28)
		_tower_crown_bar(top, IW * 0.66, float(n), team, crown, float(t[6]))

	func _tower_crown_bar(top: Vector2, tile_px: float, size: float, team: int, crown: bool, frac: float) -> void:
		if crown:
			var cr: float = tile_px * 0.42
			var pts := PackedVector2Array([top + Vector2(-cr, 0), top + Vector2(-cr * 0.55, -cr * 0.9),
				top + Vector2(0, -cr * 0.25), top + Vector2(cr * 0.55, -cr * 0.9), top + Vector2(cr, 0)])
			draw_colored_polygon(pts, Color(0.98, 0.82, 0.3))
			pts.append(pts[0])
			draw_polyline(pts, Color(0.45, 0.32, 0.05), 2.0, true)
		var bw: float = tile_px * size * 0.9
		var by: float = top.y - (tile_px * 0.75 if crown else 18.0)
		draw_rect(Rect2(top.x - bw * 0.5, by, bw, 8), Color(0.05, 0.05, 0.08, 0.9), true)
		var hc := Color(0.45, 0.9, 0.55) if team == 0 else Color(0.95, 0.45, 0.45)
		draw_rect(Rect2(top.x - bw * 0.5 + 1, by + 1, (bw - 2) * frac, 6), hc, true)
		draw_string(ThemeDB.fallback_font, Vector2(top.x + bw * 0.5 + 6, by + 9), str(int(250.0 * frac)),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))

	func _unit(e: Array) -> void:
		var kind: String = e[0]
		var c: float = e[1]
		var r: float = e[2]
		var team: int = e[3]
		var f: float = e[4]
		var ex: Dictionary = e[5]
		var sc: float = s(r)
		var rad: float = float(DDCard.get_card(kind).get("radius", 0.4)) * TW
		var fly: bool = bool(ex.get("fly", false))
		var ground: Vector2 = p(c, r)
		draw_set_transform(ground, 0.0, Vector2(sc, sc * 0.5))
		draw_circle(Vector2.ZERO, rad * 0.95, Color(0, 0, 0, 0.3 if not fly else 0.18))
		var lift: float = (0.85 * TW if fly else 0.0) + rad * 0.55
		draw_set_transform(ground - Vector2(0, lift * sc), 0.0, Vector2(sc, sc))
		var ink: Color = TEAM[team].darkened(0.45)
		var tc: Color = TEAM[team]
		match kind:
			"gilgamesh":
				DDArt.gilgamesh(self, rad, f, 0.4, {"lashing": true}, ink, tc)
			"enkidu":
				DDArt.enkidu(self, rad, f, 0.4, {"spear": bool(ex.get("spear", true))}, ink)
			"neko":
				DDArt.nekomancer(self, rad, f, 0.4, {"wind": 0.5, "cast": 0.8}, ink, tc)
			"wu":
				DDArt.bonobo(self, rad, f, 0.4, {"walk": true}, ink)
			"obsidian":
				DDArt.whelp(self, rad, f, 0.4, bool(ex.get("curled", false)), false, ink)
			"hedgehog":
				DDArt.hedgehog(self, rad, f, 0.4, bool(ex.get("curled", false)), ink)
			"troll":
				DDArt.troll(self, rad, f, 0.4, 0.7, ink)
			"laniakea":
				DDArt.laniakea(self, rad, f, 0.4, 0, ink)
			"hawk":
				DDArt.bird(self, rad * (1.3 if bool(ex.get("lead", false)) else 1.0), f, 0.4, bool(ex.get("lead", false)), ink)
			_:
				DDArt.creature(self, kind, rad, f, 0.4, 0.0, false, ink, fly)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var pip: Vector2 = ground - Vector2(0, (lift + rad * 1.9) * sc)
		draw_circle(pip, 5.0, tc.lightened(0.25))
		draw_arc(pip, 5.0, 0.0, TAU, 12, ink, 1.5, true)

	func _pentagram(c: float, r: float) -> void:
		var tc: Color = TEAM[0]
		var at := p(c, r)
		var rr: float = TW * s(r) * 0.42
		draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, rr * 1.15, Color(tc.r, tc.g, tc.b, 0.35))
		var lc := tc.lightened(0.65)
		draw_arc(Vector2.ZERO, rr, 0.0, TAU, 32, lc, 2.2, true)
		var pts: Array = []
		for i in 5:
			var a: float = -PI * 0.5 + TAU * float(i) / 5.0
			pts.append(Vector2(cos(a), sin(a)) * rr * 0.82)
		for i in 5:
			draw_line(pts[i], pts[(i + 2) % 5], lc, 1.8, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _effects() -> void:
		var tc: Color = TEAM[0]
		var nr := 19.6
		var nrad: float = float(DDCard.get_card("neko")["radius"]) * TW
		var nek: Vector2 = p(12.8, nr) - Vector2(0, nrad * 0.55 * s(nr))
		var from: Vector2 = nek + DDArt.neko_staff_tip(nrad, 1.0) * s(nr)
		var to: Vector2 = p(13.2, 15.0) - Vector2(0, (0.85 * TW + 12.0) * s(15.0))
		draw_line(from, to, Color(tc.r, tc.g, tc.b, 0.35), 12.0, true)
		draw_line(from, to, tc.lightened(0.35), 5.0, true)
		draw_line(from, to, Color(1, 1, 1, 0.9), 1.6, true)
		draw_circle(to, 10.0, Color(tc.r, tc.g, tc.b, 0.5))
		var gr := 12.6
		var grad: float = float(DDCard.get_card("gilgamesh")["radius"]) * TW
		var gil: Vector2 = p(5.2, gr) - Vector2(0, grad * 0.55 * s(gr))
		var hed: Vector2 = p(4.2, 10.9) - Vector2(0, 10.0)
		draw_set_transform(gil, 0.0, Vector2(s(gr), s(gr)))
		DDArt.snake_lash(self, DDArt.gilgamesh_hand(grad, -1.0), (hed - gil) / s(gr), 1.0, 0.3, grad * 0.2,
			tc, tc.darkened(0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var sp_at: Vector2 = p(6.2, 11.4) - Vector2(0, 34)
		var sp_to: Vector2 = p(5.6, 10.2) - Vector2(0, 40)
		draw_set_transform(sp_at, (sp_to - sp_at).angle(), Vector2(1.1, 1.1))
		DDArt.enkidu_spear(self, Vector2(-26, 0), Vector2(12, 0), 2.6)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# ----------------------------------------------------------------------- HUD
	func _panel(r: Rect2, col: Color) -> void:
		draw_rect(r, col, true)
		draw_rect(r, Color(1, 1, 1, 0.08), false, 2.0)

	func _hud_top() -> void:
		var font := ThemeDB.fallback_font
		_panel(Rect2(0, 0, W, 112), Color(0.1, 0.1, 0.15, 0.96))
		draw_rect(Rect2(0, 110, W, 4), TEAM[1], true)
		draw_string(font, Vector2(28, 46), "OPPONENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, TEAM[1].lightened(0.4))
		draw_string(font, Vector2(28, 80), "Ability: Shiesty", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.55))
		for i in 4:
			var cr := Rect2(W - 300 + float(i) * 66, 18, 56, 76)
			draw_rect(cr, TEAM[1].darkened(0.35), true)
			draw_rect(cr, TEAM[1].lightened(0.2), false, 2.0)
			draw_circle(cr.get_center(), 14.0, TEAM[1].darkened(0.1))
			draw_arc(cr.get_center(), 14.0, 0.0, TAU, 20, TEAM[1].lightened(0.3), 2.0, true)
		for i in 10:
			var cc := Vector2(250 + float(i) * 22, 88)
			if i < 6:
				DDArt.coin(self, cc, 8.0)
			else:
				draw_circle(cc, 8.0, Color(1, 1, 1, 0.12))
		var chip := Rect2(CX - 70, 122, 140, 46)
		_panel(chip, Color(0.12, 0.11, 0.18, 0.95))
		draw_string(font, chip.position + Vector2(0, 33), "1:42", HORIZONTAL_ALIGNMENT_CENTER, 140, 30, Color(1, 1, 1))

	func _hud_bottom() -> void:
		var font := ThemeDB.fallback_font
		var y0 := 1440.0
		_panel(Rect2(0, y0, W, H - y0), Color(0.1, 0.1, 0.15, 0.97))
		draw_rect(Rect2(0, y0, W, 4), TEAM[0], true)
		for i in 10:
			var cc := Vector2(190 + float(i) * 62, y0 + 48)
			if i < 7:
				DDArt.coin(self, cc, 22.0)
			elif i == 7:
				draw_circle(cc, 22.0, Color(1, 1, 1, 0.1))
				draw_arc(cc, 22.0, -PI * 0.5, -PI * 0.5 + TAU * 0.6, 24, Color(0.98, 0.79, 0.26), 4.0, true)
			else:
				draw_circle(cc, 22.0, Color(1, 1, 1, 0.1))
		draw_string(font, Vector2(36, y0 + 60), "7", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.98, 0.82, 0.3))
		draw_string(font, Vector2(80, y0 + 58), "/ 10", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))
		var cy := y0 + 108.0
		draw_string(font, Vector2(22, cy + 4), "NEXT", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))
		DDCardFace.draw(self, "fireball", Rect2(18, cy + 14, 128, 178))
		var hand := ["gilgamesh", "neko", "wu", "obsidian"]
		for i in 4:
			var x := 168.0 + float(i) * 224.0
			var lifted := i == 2
			var rect := Rect2(x, cy + (-26.0 if lifted else 0.0), 212, 300)
			if lifted:
				draw_rect(rect.grow(6.0), Color(1, 1, 1, 0.55), false, 4.0)
			DDCardFace.draw(self, hand[i], rect)
		var ab := Vector2(W - 70, y0 - 70)
		draw_circle(ab, 48.0, Color(0.08, 0.07, 0.12, 0.92))
		draw_arc(ab, 48.0, -PI * 0.5, -PI * 0.5 + TAU * 0.7, 40, Color(0.55, 0.85, 1.0), 5.0, true)
		draw_circle(ab + Vector2(0, -6), 22.0, Color(0.88, 0.62, 0.95))
		draw_string(font, ab + Vector2(-60, 70), "TENTACLE", HORIZONTAL_ALIGNMENT_CENTER, 120, 16, Color(1, 1, 1, 0.75))
		draw_string(font, Vector2(0, H - 22), "YOU", HORIZONTAL_ALIGNMENT_CENTER, W, 20, TEAM[0].lightened(0.4))
