class_name DDBoard

## Board geometry and the pure layout rules, lifted out of arena.gd.
##
## Everything here is a static function of the constants below — no arena state —
## so the arena, units, bots, panels and the dev harness all ask the same
## questions and get the same answers. Rules that need live state (what is
## standing where, who controls which tile) stay on the arena and call in here.

## Board shape: 30 rows tall. Rows 1..10 (top) and 19..28 (bottom) are 16 tiles
## wide; the middle band of 8 rows (11..18) bulges out to 18 tiles. The band is
## neutral no-man's land: you may only deploy inside it on tiles your ground
## troops have claimed recently.
const TILE := 38.0
const ORIGIN := Vector2(230.0, 56.0)
const GRID_W := 18
const GRID_H := 30
const OUTER_COL_MIN := 1
const OUTER_COL_MAX := 16
const BAND_TOP := 11
const BAND_BOTTOM := 18

## Orientation. true  -> your half on the LEFT, the enemy on the RIGHT, hands
##                       along the bottom of the screen (the current layout).
##        false -> the original portrait board, your half at the BOTTOM.
const LANDSCAPE := true


static func row_is_band(row: int) -> bool:
	return row >= BAND_TOP and row <= BAND_BOTTOM


static func col_min(row: int) -> int:
	return 0 if row_is_band(row) else OUTER_COL_MIN


static func col_max(row: int) -> int:
	return 17 if row_is_band(row) else OUTER_COL_MAX


static func valid_tile(t: Vector2i) -> bool:
	if t.y < 0 or t.y >= GRID_H:
		return false
	return t.x >= col_min(t.y) and t.x <= col_max(t.y)


static func tile_of(world: Vector2) -> Vector2i:
	var gx := int(floorf((world.x - ORIGIN.x) / TILE))
	var gy := int(floorf((world.y - ORIGIN.y) / TILE))
	if LANDSCAPE:
		return Vector2i(gy, GRID_H - 1 - gx)
	return Vector2i(gx, gy)


## tx/ty are tile coordinates where the centre of tile (col,row) is (col+0.5, row+0.5).
static func tile_center(tx: float, ty: float) -> Vector2:
	if LANDSCAPE:
		return ORIGIN + Vector2(float(GRID_H) - ty, tx) * TILE
	return ORIGIN + Vector2(tx, ty) * TILE


static func tile_rect(col: int, row: int) -> Rect2:
	if LANDSCAPE:
		return Rect2(ORIGIN + Vector2(float(GRID_H - 1 - row), float(col)) * TILE, Vector2(TILE, TILE))
	return Rect2(ORIGIN + Vector2(float(col), float(row)) * TILE, Vector2(TILE, TILE))


## Screen rect covering cols c0..c1 of a single row (orientation agnostic).
static func row_span(c0: int, c1: int, row: int) -> Rect2:
	return tile_rect(c0, row).merge(tile_rect(c1, row))


static func band_index(t: Vector2i) -> int:
	return t.y * GRID_W + t.x


static func board_rect() -> Rect2:
	if LANDSCAPE:
		return Rect2(ORIGIN, Vector2(GRID_H, GRID_W) * TILE)
	return Rect2(ORIGIN, Vector2(GRID_W, GRID_H) * TILE)


## Tiles a building of this footprint covers, anchored at the clicked tile, plus
## the screen position its art should sit at (corner-centred for 2x2).
static func footprint_layout(t: Vector2i, fp: Array) -> Dictionary:
	var fw := int(fp[0])
	var fh := int(fp[1])
	var tiles: Array = []
	if fw <= 1 and fh <= 1:
		tiles.append(t)
		return {"tiles": tiles, "center": tile_center(float(t.x) + 0.5, float(t.y) + 0.5)}
	for dy in range(-(fh - 1), 1):
		for dx in range(-(fw - 1), 1):
			var nt := Vector2i(t.x + dx, t.y + dy)
			if valid_tile(nt):
				tiles.append(nt)
	var center := tile_center(float(t.x) + 0.5 - float(fw - 1) * 0.5, float(t.y) + 0.5 - float(fh - 1) * 0.5)
	return {"tiles": tiles, "center": center}
