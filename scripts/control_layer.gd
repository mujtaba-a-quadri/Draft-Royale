class_name DDControlLayer
extends Node2D

## Draws the no-man's-land control tint. It is a separate canvas item so the
## arena can redraw every frame (water, shakes) without paying for the band,
## and it only repaints when the control grid actually changes.

var arena = null


func _draw() -> void:
	if arena == null:
		return
	var c0: Color = arena.team_color(0)
	var c1: Color = arena.team_color(1)
	# a lane opened by a fallen tower reads like held ground; the rows of it past
	# the band (in the enemy's half) are drawn here, the band rows below
	for team in 2:
		var col_t: Color = c0 if team == 0 else c1
		for t in (arena.pocket_tiles[team] as Dictionary).keys():
			if arena.row_is_band(t.y):
				continue
			var pr: Rect2 = arena.tile_rect(t.x, t.y)
			draw_rect(pr, _tint(col_t, 0.34))
			draw_rect(pr, _tint(col_t.lightened(0.4), 0.45), false, 1.0)
	for row in range(arena.BAND_TOP, arena.BAND_BOTTOM + 1):
		for col in range(arena.col_min(row), arena.col_max(row) + 1):
			var t := Vector2i(col, row)
			var a0: bool = arena.controlled(0, t) or arena.in_pocket(0, t)
			var a1: bool = arena.controlled(1, t) or arena.in_pocket(1, t)
			if not a0 and not a1:
				continue
			var rect: Rect2 = arena.tile_rect(col, row)
			if a0 and a1:
				draw_rect(rect, Color(0.72, 0.45, 0.95, 0.4))
				draw_rect(rect, Color(0.85, 0.6, 1.0, 0.8), false, 1.5)
			elif a0:
				draw_rect(rect, _tint(c0, 0.34))
				draw_rect(rect, _tint(c0.lightened(0.4), 0.45), false, 1.0)
			else:
				draw_rect(rect, _tint(c1, 0.34))
				draw_rect(rect, _tint(c1.lightened(0.4), 0.45), false, 1.0)


func _tint(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)
