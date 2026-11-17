extends Node2D

## A patch of burning ground left where a spell landed (the Fireball). Every
## `every` seconds it applies `burn` to each enemy body inside `radius_t` tiles,
## towers included, until `time` runs out. No class_name: arena.gd preloads it.
## Ticks on the physics clock, so it is deterministic like the rest of combat.

var arena: Node = null
var team := 0
var radius_t := 2.0
var burn := 10.0
var every := 1.0
var time := 4.2
var age := 0.0
var next_tick := 1.0
var clock := 0.0


func setup(a: Node, center: Vector2, tm: int, r_t: float, cfg: Dictionary) -> void:
	arena = a
	position = center
	team = tm
	radius_t = r_t
	burn = float(cfg.get("burn", 10.0))
	every = maxf(0.1, float(cfg.get("every", 1.0)))
	time = float(cfg.get("time", 4.2))
	next_tick = every


func _physics_process(delta: float) -> void:
	if arena == null or not is_instance_valid(arena):
		queue_free()
		return
	age += delta
	clock += delta
	# the blast itself already burned on impact; the ground adds one dose a second
	while age >= next_tick and next_tick <= time:
		arena.apply_burn_at(position, radius_t, burn, team)
		next_tick += every
	if age >= time:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var px: float = radius_t * float(arena.TILE)
	# fade in fast, fade out over the last second
	var a: float = clampf(age / 0.2, 0.0, 1.0) * clampf((time - age) / 1.0, 0.0, 1.0)
	draw_circle(Vector2.ZERO, px, Color(0.35, 0.08, 0.02, 0.28 * a))
	draw_arc(Vector2.ZERO, px, 0.0, TAU, 40, Color(1.0, 0.45, 0.12, 0.55 * a), 2.0, true)
	# licking flames scattered over the patch (fixed spots, flicker from the clock)
	for i in 14:
		var ang := float(i) * 2.399
		var dist := px * sqrt((float(i) + 0.5) / 14.0) * 0.9
		var at := Vector2(cos(ang), sin(ang)) * dist
		var fl := 0.65 + 0.35 * sin(clock * 9.0 + float(i) * 1.7)
		var h := px * 0.16 * fl
		var w := px * 0.06
		var outer := PackedVector2Array([at + Vector2(-w, 0.0), at + Vector2(0.0, -h), at + Vector2(w, 0.0)])
		draw_colored_polygon(outer, Color(1.0, 0.42, 0.1, 0.75 * a))
		var inner := PackedVector2Array([at + Vector2(-w * 0.5, 0.0), at + Vector2(0.0, -h * 0.55), at + Vector2(w * 0.5, 0.0)])
		draw_colored_polygon(inner, Color(1.0, 0.85, 0.35, 0.85 * a))
