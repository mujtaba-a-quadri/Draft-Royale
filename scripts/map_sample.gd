extends SceneTree

## Dev-only: prints sample act maps for the run layer (NOTES.md §8). Not game code.
##
##   godot --headless --path . -s res://scripts/map_sample.gd -- --seeds=1,2,3 --out=<abs file>
##
## The act runs left to right like the arena: COLS steps, ROWS lanes, boss after
## the last column. Paths are laid Slay-the-Spire style (a few passes, each step
## to the same lane or a neighbour, never crossing); tile types are then rolled
## from WEIGHTS and re-rolled until the placement rules hold. Same seed, same map.

const ROWS := 5
const COLS := 9
const PASSES := 4

## Tile types are the faces of a die.
const FACES := ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
const NAMES := ["1v1 fight", "2v2 fight", "modifier fight", "elite", "shop", "event"]
const WEIGHTS := [35, 20, 15, 10, 8, 12]
const T_DUEL := 0
const T_ELITE := 3
const T_SHOP := 4
## no elite before this column (0-based)
const ELITE_FROM := 3


func _init() -> void:
	var seeds: Array = [1, 2, 3]
	var out_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--out="):
			out_path = a.substr(6)
	var text := "Legend: "
	for i in FACES.size():
		text += "%s %s   " % [FACES[i], NAMES[i]]
	text += "\n"
	for s in seeds:
		text += "\nseed %d\n%s" % [int(s), render(generate(int(s)))]
	if out_path != "":
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(text)
		f.close()
	else:
		print(text)
	quit()


## -> {"edges": {Vector2i(col, row): [rows in col + 1]}, "types": {Vector2i(col, row): int}}
static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var edges := {}
	var nodes := {}
	var first := -1
	for p in PASSES:
		var r := rng.randi_range(0, ROWS - 1)
		# the first two passes start in different lanes: always two ways in
		while p == 1 and r == first:
			r = rng.randi_range(0, ROWS - 1)
		if p == 0:
			first = r
		nodes[Vector2i(0, r)] = true
		for c in COLS - 1:
			var opts: Array = []
			for dr in [-1, 0, 1]:
				var nr: int = r + dr
				if nr < 0 or nr >= ROWS:
					continue
				# a diagonal may not cross one already laid the other way
				if dr != 0 and (edges.get(Vector2i(c, nr), []) as Array).has(r):
					continue
				opts.append(nr)
			var to: int = opts[rng.randi_range(0, opts.size() - 1)]
			var key := Vector2i(c, r)
			if not edges.has(key):
				edges[key] = []
			if not (edges[key] as Array).has(to):
				(edges[key] as Array).append(to)
			r = to
			nodes[Vector2i(c + 1, r)] = true
	var types := {}
	for c in COLS:
		for r in ROWS:
			var at := Vector2i(c, r)
			if not nodes.has(at):
				continue
			if c == 0:
				types[at] = T_DUEL
				continue
			if c == COLS - 1:
				types[at] = T_SHOP
				continue
			var picked := -1
			for attempt in 60:
				var t := _roll(rng)
				if _allowed(t, at, edges, types):
					picked = t
					break
			if picked < 0:
				for t in [0, 1, 2, 5]:
					if _allowed(t, at, edges, types):
						picked = t
						break
			types[at] = picked if picked >= 0 else T_DUEL
	return {"edges": edges, "types": types}


static func _roll(rng: RandomNumberGenerator) -> int:
	var total := 0
	for w in WEIGHTS:
		total += int(w)
	var x := rng.randi_range(0, total - 1)
	for i in WEIGHTS.size():
		x -= int(WEIGHTS[i])
		if x < 0:
			return i
	return 0


static func _allowed(t: int, at: Vector2i, edges: Dictionary, types: Dictionary) -> bool:
	if t == T_ELITE and at.x < ELITE_FROM:
		return false
	# the last column is all shops, so none in the column before it
	if t == T_SHOP and at.x == COLS - 2:
		return false
	for pr in ROWS:
		var parent := Vector2i(at.x - 1, pr)
		var kids: Array = edges.get(parent, [])
		if not kids.has(at.y):
			continue
		# no elite or shop straight after an elite or shop
		if (t == T_ELITE or t == T_SHOP) and (int(types[parent]) == T_ELITE or int(types[parent]) == T_SHOP):
			return false
		# a fork must offer two different things
		for k in kids:
			if int(k) != at.y and types.has(Vector2i(at.x, int(k))) and int(types[Vector2i(at.x, int(k))]) == t:
				return false
	return true


static func render(m: Dictionary) -> String:
	var edges: Dictionary = m["edges"]
	var types: Dictionary = m["types"]
	var width := COLS * 4 + 8
	var lines: Array = []
	for i in ROWS * 2 - 1:
		var row: Array = []
		row.resize(width)
		row.fill(" ")
		lines.append(row)
	var top := ROWS
	var bottom := -1
	for at in types:
		lines[at.y * 2][at.x * 4] = FACES[int(types[at])]
		if at.x == COLS - 1:
			top = mini(top, at.y)
			bottom = maxi(bottom, at.y)
	for from in edges:
		for to in edges[from]:
			var x: int = from.x * 4
			if int(to) == from.y:
				lines[from.y * 2][x + 1] = "─"
				lines[from.y * 2][x + 2] = "─"
				lines[from.y * 2][x + 3] = "─"
			elif int(to) > from.y:
				lines[from.y * 2 + 1][x + 2] = "╲"
			else:
				lines[from.y * 2 - 1][x + 2] = "╱"
	# every node in the last column leads to the boss
	var bx := (COLS - 1) * 4 + 2
	for y in range(top * 2, bottom * 2 + 1):
		lines[y][bx] = "┤" if y % 2 == 0 and types.has(Vector2i(COLS - 1, y / 2)) else "│"
	var mid := top + bottom
	lines[mid][bx + 1] = "─"
	lines[mid][bx + 2] = " "
	lines[mid][bx + 3] = "BOSS"
	var out := ""
	for row in lines:
		out += "".join(row).rstrip(" ") + "\n"
	return out
