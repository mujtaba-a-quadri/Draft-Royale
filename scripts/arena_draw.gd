class_name DDArenaDraw

## Everything the arena paints: the board and its terrain, the deploy hint, the
## hover inspection, the match HUD and the end-of-match overlay.
##
## Pure drawing — every piece of state is read through the arena handed in, the
## same way art.gd draws units and DDCardFace draws cards. Keeps arena.gd focused
## on the rules rather than on where the river goes.

static func draw_all(ci: CanvasItem, a) -> void:
	ci.draw_set_transform(a.shake_offset, 0.0, Vector2.ONE)
	_board(ci, a)
	_deploy_hint(ci, a)
	_bot_intent(ci, a)
	a._draw_ability_button(0)
	if a.selection_kind() == "" and not a.match_over:
		_hover(ci, a, a.get_global_mouse_position())
	_hud(ci, a)
	_result(ci, a)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------------- board

static func _board(ci: CanvasItem, a) -> void:
	# tiles
	for row in a.GRID_H:
		var c0: int = a.col_min(row)
		var c1: int = a.col_max(row)
		for col in range(c0, c1 + 1):
			var rect: Rect2 = a.tile_rect(col, row)
			var base: Color = a.GRASS_A if (row + col) % 2 == 0 else a.GRASS_B
			if a.row_is_band(row):
				base = a.BAND_A if (row + col) % 2 == 0 else a.BAND_B
			ci.draw_rect(rect, base)
	# halves tint (orientation agnostic: one row at a time)
	for row in a.GRID_H:
		var c0: int = a.col_min(row)
		var span: Rect2 = a.row_span(c0, a.col_max(row), row)
		if row < a.BAND_TOP:
			ci.draw_rect(span, Color(0.92, 0.35, 0.35, 0.07))
		elif row > a.BAND_BOTTOM:
			ci.draw_rect(span, Color(0.35, 0.55, 1.0, 0.07))
	# river
	var river_span: Rect2 = a.tile_rect(a.col_min(a.RIVER_TOP), a.RIVER_TOP).merge(
		a.tile_rect(a.col_max(a.RIVER_BOTTOM), a.RIVER_BOTTOM))
	ci.draw_rect(river_span, a.WATER)
	for i in 6:
		var phase: float = a.clock * 0.8 + float(i)
		if a.LANDSCAPE:
			var x: float = river_span.position.x + 10.0 + float(i) * 9.0
			var y: float = river_span.position.y + fmod(phase * 26.0, river_span.size.y)
			ci.draw_line(Vector2(x, y), Vector2(x, y + 34.0), a.WATER_HI, 2.0, true)
		else:
			var y2: float = river_span.position.y + 10.0 + float(i) * 9.0
			var x2: float = river_span.position.x + fmod(phase * 26.0, river_span.size.x)
			ci.draw_line(Vector2(x2, y2), Vector2(x2 + 34.0, y2), a.WATER_HI, 2.0, true)
	# bridges
	for bx in [int(a.BRIDGE_COL_A), int(a.BRIDGE_COL_B)]:
		var br: Rect2 = a.tile_rect(bx - 1, a.RIVER_TOP).merge(a.tile_rect(bx, a.RIVER_BOTTOM))
		ci.draw_rect(br, a.WOOD)
		for k in 5:
			if a.LANDSCAPE:
				var x3: float = br.position.x + 6.0 + float(k) * 16.0
				ci.draw_line(Vector2(x3, br.position.y + 2.0), Vector2(x3, br.end.y - 2.0), Color(0.45, 0.31, 0.2), 1.5, true)
			else:
				var y3: float = br.position.y + 6.0 + float(k) * 16.0
				ci.draw_line(Vector2(br.position.x + 2.0, y3), Vector2(br.end.x - 2.0, y3), Color(0.45, 0.31, 0.2), 1.5, true)
		ci.draw_rect(br, DDArt.OUTLINE, false, 2.5)
	# (control tint lives in DDControlLayer so it only repaints on change)
	# dashed no-man's-land edges
	for edge_row in [a.BAND_TOP, a.BAND_BOTTOM + 1]:
		var er: Rect2 = a.tile_rect(a.col_min(edge_row), edge_row)
		var across: float = a.board_rect().size.y if a.LANDSCAPE else a.board_rect().size.x
		var start: float = a.board_rect().position.y if a.LANDSCAPE else a.board_rect().position.x
		var at: float = er.position.x if a.LANDSCAPE else er.position.y
		var k2 := 0.0
		while k2 < across:
			if a.LANDSCAPE:
				ci.draw_line(Vector2(at, start + k2), Vector2(at, start + k2 + 9.0), Color(1.0, 0.9, 0.55, 0.55), 2.0)
			else:
				ci.draw_line(Vector2(start + k2, at), Vector2(start + k2 + 9.0, at), Color(1.0, 0.9, 0.55, 0.55), 2.0)
			k2 += 18.0
	# board silhouette: three slabs make the plus shape
	ci.draw_rect(a.tile_rect(a.col_min(0), 0).merge(a.tile_rect(a.col_max(a.GRID_H - 1), a.BAND_TOP - 1)), DDArt.OUTLINE, false, 4.0)
	ci.draw_rect(a.tile_rect(a.col_min(a.BAND_TOP), a.BAND_TOP).merge(a.tile_rect(a.col_max(a.BAND_BOTTOM), a.BAND_BOTTOM)), DDArt.OUTLINE, false, 4.0)
	ci.draw_rect(a.tile_rect(a.col_min(a.GRID_H - 1), a.BAND_BOTTOM + 1).merge(a.tile_rect(a.col_max(a.GRID_H - 1), a.GRID_H - 1)), DDArt.OUTLINE, false, 4.0)


# ---------------------------------------------------------------- deploy hint

static func _deploy_hint(ci: CanvasItem, a) -> void:
	var armed: String = a.selection_kind()
	if armed != "" and not a.match_over:
		var kind: String = armed
		var sel_player: int = a.selection_owner()
		if not DDCard.is_spell(kind):
			for row in a.GRID_H:
				for col in range(a.col_min(row), a.col_max(row) + 1):
					var t := Vector2i(col, row)
					if not a.can_deploy(sel_player, kind, a.tile_center(float(col) + 0.5, float(row) + 0.5)):
						continue
					ci.draw_rect(a.tile_rect(col, row), Color(0.9, 0.95, 0.6, 0.13))
		var m: Vector2 = a.get_global_mouse_position()
		if a.board_rect().has_point(m):
			var tt: Vector2i = a.tile_of(m)
			var lock = a.aim_lock(m)
			var at: Vector2 = a.aim_point(m)
			var ok: bool = a.can_deploy(sel_player, kind, m)
			var col2: Color = Color(0.5, 1.0, 0.6, 0.85) if ok else Color(1.0, 0.35, 0.35, 0.85)
			var pfp: Array = DDCard.get_card(kind).get("footprint", [1, 1])
			if lock != null:
				# locked on a troop: ring the troop itself, no tile outline
				ci.draw_arc(lock.position, float(lock.get_radius_t()) * a.TILE + 6.0, 0.0, TAU, 32, col2, 2.5, true)
			elif int(pfp[0]) > 1 or int(pfp[1]) > 1:
				var lay: Dictionary = a.footprint_layout(tt, pfp)
				at = lay["center"]
				for ot in (lay["tiles"] as Array):
					ci.draw_rect(a.tile_rect((ot as Vector2i).x, (ot as Vector2i).y), col2, false, 2.5)
			else:
				ci.draw_rect(Rect2(at - Vector2(a.TILE, a.TILE) * 0.5, Vector2(a.TILE, a.TILE)), col2, false, 2.5)
			if DDCard.is_spell(kind):
				var rad: float = maxf(float(DDCard.get_card(kind)["splash"]), 0.5) * a.TILE
				ci.draw_circle(at, rad, Color(1.0, 0.6, 0.2, 0.16 if ok else 0.1))
				ci.draw_arc(at, rad, 0.0, TAU, 48, col2, 2.5, true)
			if a.preview != null:
				a.preview.show_for(kind, sel_player, at)
		elif a.preview != null:
			a.preview.hide_preview()
	else:
		if a.preview != null:
			a.preview.hide_preview()


# ----------------------------------------------------------------- bot intent

static func _bot_intent(ci: CanvasItem, a) -> void:
	for p in 2:
		var tp: Vector2 = a.bot_target(p)
		if tp == Vector2.INF:
			continue
		var pulse: float = 0.5 + 0.5 * absf(sin(a.clock * 6.0))
		ci.draw_arc(tp, a.TILE * 1.15, 0.0, TAU, 32, Color(0.55, 0.85, 1.0, 0.5 + 0.4 * pulse), 2.5, true)
		ci.draw_arc(tp, a.TILE * 0.55, 0.0, TAU, 24, Color(1.0, 0.95, 0.75, 0.7), 2.0, true)


# ---------------------------------------------------------- hover inspection

## The unit or tower under the cursor, if any.
static func hovered(a, at: Vector2) -> Node:
	var best: Node = null
	var best_d := INF
	for e in a.units:
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = a.tiles_between(at, e.position)
		if d <= float(e.get_radius_t()) + 0.35 and d < best_d:
			best = e
			best_d = d
	for t in a.towers:
		if not is_instance_valid(t) or t.dead:
			continue
		var d2: float = a.tiles_between(at, t.position)
		if d2 <= 1.1 and d2 < best_d:
			best = t
			best_d = d2
	return best


static func _hover(ci: CanvasItem, a, m: Vector2) -> void:
	var e: Node = hovered(a, m)
	if e == null:
		return
	var px: float = float(e.get_radius_t()) * a.TILE
	var reach_var = e.get("reach")
	var reach_v := 0.0
	if reach_var != null:
		reach_v = float(reach_var)
	var aggro_var = e.get("aggro")
	var aggro_v := 0.0
	if aggro_var != null:
		aggro_v = float(aggro_var)
	var label := "TOWER"
	var kind_var = e.get("kind")
	if kind_var != null:
		label = DDCard.pretty(String(kind_var))
	var hp_txt := "%d / %d HP" % [int(ceil(float(e.get("hp")))), int(float(e.get("max_hp")))]
	if aggro_v > 0.0:
		ci.draw_circle(e.position, aggro_v * a.TILE, Color(1.0, 0.95, 0.5, 0.05))
		ci.draw_arc(e.position, aggro_v * a.TILE, 0.0, TAU, 56, Color(1.0, 0.95, 0.45, 0.55), 2.0, true)
	if reach_v > 0.0:
		ci.draw_circle(e.position, reach_v * a.TILE, Color(1.0, 0.42, 0.34, 0.06))
		ci.draw_arc(e.position, reach_v * a.TILE, 0.0, TAU, 56, Color(1.0, 0.45, 0.4, 0.65), 2.0, true)
	# summoners (the Lizard Warren) show the radius they empty out on
	var summon_v := 0.0
	var summon_n := 0
	var summon_var = e.get("summon_cfg")
	if summon_var != null and not (summon_var as Dictionary).is_empty():
		summon_v = float((summon_var as Dictionary).get("range", 0.0))
		summon_n = int((summon_var as Dictionary).get("count", 0))
	if summon_v > 0.0:
		ci.draw_circle(e.position, summon_v * a.TILE, Color(0.55, 0.9, 0.5, 0.05))
		ci.draw_arc(e.position, summon_v * a.TILE, 0.0, TAU, 72, Color(0.62, 1.0, 0.55, 0.6), 2.0, true)
	ci.draw_arc(e.position, px + 2.0, 0.0, TAU, 24, Color(1, 1, 1, 0.45), 1.5, true)
	var font := ThemeDB.fallback_font
	var w := 190.0
	var extra := 14.0 if summon_v > 0.0 else 0.0
	var box := Rect2(e.position.x - w * 0.5, e.position.y - px - 48.0 - extra, w, 34.0 + extra)
	ci.draw_rect(box, Color(0.09, 0.08, 0.13, 0.92), true)
	ci.draw_rect(box, DDArt.OUTLINE, false, 1.5)
	ci.draw_string(font, Vector2(box.position.x + 8.0, box.position.y + 15.0), label, HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, 13, Color(1.0, 0.95, 0.8))
	ci.draw_string(font, Vector2(box.position.x + 8.0, box.position.y + 29.0), hp_txt, HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, 11, Color(0.8, 0.85, 0.95))
	if summon_v > 0.0:
		ci.draw_string(font, Vector2(box.position.x + 8.0, box.position.y + 43.0),
			"SUMMON %d · r%.0f" % [summon_n, summon_v], HORIZONTAL_ALIGNMENT_LEFT, w - 16.0, 11,
			Color(0.72, 1.0, 0.68))


# ---------------------------------------------------------------------- HUD

static func _hud(ci: CanvasItem, a) -> void:
	# match clock (the old lane-control counter is gone; control_counts() stays
	# for the deploy rules and the bot)
	var chip_w := 330.0
	var chip := Rect2(a.ORIGIN.x + a.board_rect().size.x * 0.5 - chip_w * 0.5, 10.0, chip_w, 30.0)
	ci.draw_rect(chip, Color(0.09, 0.08, 0.13, 0.92), true)
	ci.draw_rect(chip, Color(1.0, 0.72, 0.3) if a.overtime else DDArt.OUTLINE, false, 2.0)
	var left: int = int(ceil(a.match_time_left))
	var mins: int = int(float(left) / 60.0)
	var label := "%d:%02d" % [mins, left % 60]
	var ink := Color(1.0, 0.93, 0.78)
	if a.overtime:
		label = "FINAL  %d:%02d   ·   DOUBLE GOLD" % [mins, left % 60]
		ink = Color(1.0, 0.76, 0.42)
	ci.draw_string(ThemeDB.fallback_font, Vector2(chip.position.x + 12.0, chip.position.y + 21.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, chip_w - 24.0, 15, ink)
	if a.view_mode == 1:
		ci.draw_string(ThemeDB.fallback_font, Vector2(a.ORIGIN.x, 30.0),
			"DEBUG  1 = +1 gold P1   2 = +1 both   3 = +1 P2   B = bot",
			HORIZONTAL_ALIGNMENT_LEFT, 620.0, 13, Color(0.75, 0.8, 0.95, 0.75))
	# opponent label only — their gold is drawn as coins on the board
	var strip := Rect2(1372.0, 8.0, 216.0, 34.0)
	ci.draw_rect(strip, Color(0.1, 0.1, 0.14, 0.96), true)
	ci.draw_rect(strip, DDArt.OUTLINE, false, 2.0)
	var theirs: Color = a.team_color(1)
	ci.draw_rect(Rect2(strip.position, Vector2(strip.size.x, 4.0)), theirs, true)
	ci.draw_string(ThemeDB.fallback_font, Vector2(strip.position.x + 14.0, strip.position.y + 23.0), "OPPONENT",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 14, theirs.lightened(0.3))
	if a.view_mode == 0:
		ci.draw_string(ThemeDB.fallback_font, Vector2(strip.position.x + 96.0, strip.position.y + 23.0), "TAB to reveal",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.72, 0.72, 0.82))
	a._draw_gold_pieces()
	# hero prompt
	for p in 2:
		if a.hero_prompt_active(p):
			var pr: Rect2 = a.hero_prompt_rect(p)
			var pulse: float = 0.55 + 0.45 * absf(sin(a.clock * 3.2))
			ci.draw_rect(pr, Color(0.1, 0.08, 0.12, 0.94), true)
			ci.draw_rect(pr, Color(1.0, 0.82, 0.32, pulse), false, 3.0)
			DDArt.coin(ci, Vector2(pr.position.x + 24.0, pr.position.y + 22.0), 11.0)
			ci.draw_string(ThemeDB.fallback_font, Vector2(pr.position.x + 44.0, pr.position.y + 28.0),
				"LAUNCH HERO · 3", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.93, 0.76))
	# banner
	if a.banner_timer > 0.0 and a.banner_text != "":
		var w := 620.0
		var box := Rect2(a.ORIGIN.x + a.board_rect().size.x * 0.5 - w * 0.5, a.ORIGIN.y - 34.0, w, 32.0)
		ci.draw_rect(box, Color(0.09, 0.08, 0.13, 0.9), true)
		ci.draw_rect(box, DDArt.OUTLINE, false, 2.0)
		ci.draw_string(ThemeDB.fallback_font, Vector2(box.position.x + 14.0, box.position.y + 22.0), a.banner_text,
			HORIZONTAL_ALIGNMENT_CENTER, w - 28.0, 18, Color(1.0, 0.95, 0.85))


static func _result(ci: CanvasItem, a) -> void:
	if not a.match_over:
		return
	var board: Rect2 = a.board_rect()
	ci.draw_rect(board, Color(0.05, 0.05, 0.08, 0.62), true)
	var verdict := "DRAW" if int(a.winner) < 0 else "PLAYER %d WINS" % (int(a.winner) + 1)
	ci.draw_string(ThemeDB.fallback_font, Vector2(board.position.x, board.position.y + 380.0), verdict,
		HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 44, Color(1.0, 0.95, 0.8))
	ci.draw_string(ThemeDB.fallback_font, Vector2(board.position.x, board.position.y + 424.0), "press R to play again",
		HORIZONTAL_ALIGNMENT_CENTER, board.size.x, 20, Color(0.85, 0.85, 0.9))
