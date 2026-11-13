class_name DDTrail
extends Node2D

## Ground scar left by a max-level Slate roll: cracked earth that fades out.

var life := 2.6
var clock := 0.0
var facing := 1.0
var team := 0
var area: Node2D = null


func setup(a: Node2D, f: float, tm: int) -> void:
	area = a
	facing = f
	team = tm
	z_index = 1


func _physics_process(delta: float) -> void:
	clock += delta
	if clock >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var f := clampf(clock / life, 0.0, 1.0)
	var a := (1.0 - f) * 0.55
	var w: float = area.TILE * 0.9
	var h: float = area.TILE * 0.8
	var tint := Color(0.36, 0.24, 0.16, a)
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), tint, true)
	var crack := Color(0.12, 0.08, 0.06, a * 1.4)
	draw_line(Vector2(-w * 0.4 * facing, -h * 0.25), Vector2(w * 0.35 * facing, h * 0.2), crack, 2.0, true)
	draw_line(Vector2(-w * 0.2 * facing, h * 0.3), Vector2(w * 0.1 * facing, -h * 0.35), crack, 1.5, true)
	draw_line(Vector2(w * 0.2 * facing, -h * 0.2), Vector2(w * 0.45 * facing, h * 0.35), crack, 1.2, true)
