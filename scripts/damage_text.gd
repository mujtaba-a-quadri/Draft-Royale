class_name DDDamageText
extends Node2D

## Floating damage number, only spawned while the debug/dual view is on.

var amount := 0.0
var tint := Color(1.0, 0.92, 0.75)
var life := 0.8
var clock := 0.0
var start := Vector2.ZERO
var drift := 0.0
var rise := 36.0
var area: Node2D = null


func setup(a: Node2D, at: Vector2, dmg: float, col: Color) -> void:
	area = a
	amount = dmg
	tint = col
	start = at
	position = at
	drift = randf_range(-10.0, 10.0)
	z_index = 18


func _physics_process(delta: float) -> void:
	clock += delta
	if clock >= life:
		queue_free()
		return
	var f := clock / life
	position = start + Vector2(drift * f, -rise * f)
	queue_redraw()


func _draw() -> void:
	var f := clampf(clock / life, 0.0, 1.0)
	var a := 1.0 - f * f
	var font := ThemeDB.fallback_font
	var text := str(int(round(amount)))
	var w := 40.0
	var col := Color(tint.r, tint.g, tint.b, a)
	var shadow := Color(0.05, 0.04, 0.07, a * 0.9)
	draw_string(font, Vector2(-w * 0.5 + 1.5, 1.5), text, HORIZONTAL_ALIGNMENT_CENTER, w, 15, shadow)
	draw_string(font, Vector2(-w * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, 15, col)
