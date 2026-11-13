class_name DDBurst
extends Node2D

var color := Color(1, 0.6, 0.2)
var radius_t := 1.0
var life := 0.32
var clock := 0.0
var area: Node2D = null


func setup(a: Node2D, r: float, c: Color) -> void:
	area = a
	radius_t = r
	color = c
	z_index = 18


func _physics_process(delta: float) -> void:
	clock += delta
	if clock >= life:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var f := clampf(clock / life, 0.0, 1.0)
	var r: float = radius_t * area.TILE * (0.35 + f * 0.75)
	draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, (1.0 - f) * 0.35))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(color.r, color.g, color.b, 1.0 - f), 3.0, true)
