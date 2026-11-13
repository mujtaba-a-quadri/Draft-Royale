class_name DDSpell
extends Node2D

var kind := "fireball"
var team := 0
var area: Node2D = null
var clock := 0.0
var fall := 0.32
var burst := 0.45
var applied := false
var radius_t := 2.0
var dmg := 100.0


func setup(a: Node2D, k: String, tm: int) -> void:
	area = a
	kind = k
	team = tm
	var d: Dictionary = DDCard.get_card(k)
	radius_t = float(d["splash"])
	dmg = float(d["dmg"])
	z_index = 20


func _physics_process(delta: float) -> void:
	clock += delta
	if not applied and clock >= fall:
		applied = true
		var col := Color(1.0, 0.55, 0.15) if kind == "fireball" else Color(1.0, 0.8, 0.3)
		area.spawn_splash_burst(position, radius_t, dmg, team, col)
		area.shake(7.0 if kind == "fireball" else 3.0)
	if clock >= fall + burst:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var r: float = radius_t * area.TILE
	if clock < fall:
		var f := clock / fall
		var y := lerpf(-260.0, 0.0, f * f)
		draw_set_transform(Vector2(0, y), 0.0, Vector2.ONE)
		DDArt.creature(self, kind, area.TILE * 0.42, 1.0, clock * 6.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 2.0, true)
	else:
		var f := clampf((clock - fall) / burst, 0.0, 1.0)
		var col := Color(1.0, 0.55, 0.15, (1.0 - f) * 0.55) if kind == "fireball" else Color(1.0, 0.8, 0.3, (1.0 - f) * 0.5)
		draw_circle(Vector2.ZERO, r * (0.55 + f * 0.55), col)
		draw_arc(Vector2.ZERO, r * (0.55 + f * 0.55), 0.0, TAU, 40, Color(1, 1, 1, (1.0 - f) * 0.7), 3.0, true)
