class_name DDConfetti
extends Node2D

## A dying unit's pop: mini confetti in the card's accent colour and the owner's
## team colour, each with a lighter and a darker variation. Bigger bodies throw
## more flecks, faster, for longer — a hero bursts wider than one honeycreeper.

const GRAVITY := 640.0
const DRAG := 1.9

var flecks: Array = []
var t := 0.0
var life_max := 0.6


## colours is [accent, team]; radius_t is the body's size in tiles.
func setup(colours: Array, radius_t: float) -> void:
	var palette: Array = []
	for c in colours:
		var col: Color = c
		palette.append(col)
		palette.append(col.lightened(0.28))
		palette.append(col.darkened(0.28))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n: int = 8 + int(round(radius_t * 20.0))
	var speed: float = 70.0 + radius_t * 260.0
	life_max = 0.45 + radius_t * 0.35
	for i in n:
		var a := rng.randf() * TAU
		var sp := speed * rng.randf_range(0.45, 1.25)
		flecks.append({
			"pos": Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-3.0, 3.0)),
			"vel": Vector2(cos(a), sin(a)) * sp + Vector2(0.0, -speed * 0.55),
			"spin": rng.randf_range(-14.0, 14.0),
			"angle": rng.randf() * TAU,
			"col": palette[rng.randi() % palette.size()],
			"size": 2.6 + radius_t * 4.6 + rng.randf() * 2.2,
			"life": life_max * rng.randf_range(0.65, 1.0),
		})
	z_index = 8


func _process(delta: float) -> void:
	t += delta
	var alive := false
	for f in flecks:
		var life: float = float(f["life"])
		if t >= life:
			continue
		alive = true
		var vel: Vector2 = f["vel"]
		vel.y += GRAVITY * delta
		vel -= vel * minf(DRAG * delta, 1.0)
		f["vel"] = vel
		f["pos"] = (f["pos"] as Vector2) + vel * delta
		f["angle"] = float(f["angle"]) + float(f["spin"]) * delta
	if not alive:
		queue_free()
	queue_redraw()


func _draw() -> void:
	for f in flecks:
		var life: float = float(f["life"])
		if t >= life:
			continue
		var k: float = 1.0 - t / life
		var col: Color = f["col"]
		var at: Vector2 = f["pos"]
		var ang: float = float(f["angle"])
		var s: float = float(f["size"])
		# a spinning paper chip, dimming as it goes
		draw_set_transform(at, ang, Vector2.ONE)
		draw_rect(Rect2(-s * 0.5, -s * 0.5, s, s * 0.55), Color(col.r, col.g, col.b, col.a * k))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
