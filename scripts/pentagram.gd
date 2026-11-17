extends Node2D

## One of the Nekomancer's summoning circles (NOTES §2, `ritual`): a pentagram
## on the ground that glows up over `delay` seconds and then raises one `unit`
## for `team`. It belongs to the arena, not to her, so the summon still lands
## if she dies while it is glowing. No class_name: preloaded by unit.gd.

const FADE := 0.3

var arena: Node
var team := 0
var unit_kind := ""
var delay := 1.0
var t := 0.0
var color := Color(0.6, 1.0, 0.5)
var raised := false


func setup(p_arena: Node, p_team: int, kind: String, at: Vector2, p_delay: float) -> void:
	arena = p_arena
	team = p_team
	unit_kind = kind
	delay = maxf(0.05, p_delay)
	position = at
	color = arena.team_color(team)
	# under the units (z 5), over the board
	z_index = 2


func _physics_process(delta: float) -> void:
	t += delta
	if not raised and t >= delay - 0.0001:
		raised = true
		if not arena.match_over:
			var u: Node = arena.spawn_troop(unit_kind, team, position, true)
			if u != null:
				# out of the circle, not dropped from the sky, and exactly on it
				u.position = position
				u.rises = true
	if t >= delay + FADE:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var r: float = float(arena.TILE) * 0.42
	var grow: float = clampf(t / 0.25, 0.0, 1.0)
	var a: float = clampf(t / delay, 0.0, 1.0)
	if t > delay:
		a = 1.0 - clampf((t - delay) / FADE, 0.0, 1.0)
	else:
		a = 0.45 + 0.55 * a
	# flattened onto the ground, slowly turning
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.55))
	var rr: float = r * ease(grow, 0.5)
	# dark under-glow first so the lines read on any tile, then the team glow
	draw_circle(Vector2.ZERO, rr * 1.12, Color(0.05, 0.04, 0.08, 0.35 * a))
	draw_circle(Vector2.ZERO, rr * 1.12, Color(color.r, color.g, color.b, 0.3 * a))
	var lc: Color = color.lightened(0.65)
	var line := Color(lc.r, lc.g, lc.b, a)
	draw_arc(Vector2.ZERO, rr, 0.0, TAU, 32, line, 2.2, true)
	draw_arc(Vector2.ZERO, rr * 0.82, 0.0, TAU, 32, Color(line.r, line.g, line.b, line.a * 0.7), 1.2, true)
	var spin: float = t * 1.2
	var pts: Array = []
	for i in 5:
		var ang: float = spin - PI * 0.5 + TAU * float(i) / 5.0
		pts.append(Vector2(cos(ang), sin(ang)) * rr * 0.82)
	for i in 5:
		draw_line(pts[i], pts[(i + 2) % 5], line, 1.8, true)
	# the flash as the summon comes through
	if t > delay - 0.1 and t < delay + FADE:
		var f: float = clampf((t - delay + 0.1) / (FADE + 0.1), 0.0, 1.0)
		draw_circle(Vector2.ZERO, rr * (0.6 + 0.8 * f), Color(1.0, 1.0, 1.0, 0.45 * (1.0 - f)))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
