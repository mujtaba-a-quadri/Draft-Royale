class_name DDLeap
extends Node2D

## The defender's answer to an airborne dragon: a hero vaults off his own tower,
## lands on the dragon, knocks a quarter of its HP off and grounds it, then
## dismounts and fights on as a normal troop.

var area: Node2D = null
var target: Node = null
var team := 0
var from := Vector2.ZERO
var clock := 0.0
var dur := 0.6
var landed := false
var peak := 90.0


func setup(a: Node2D, f: Vector2, t: Node, tm: int) -> void:
	area = a
	from = f
	target = t
	team = tm
	position = from
	z_index = 22


func _physics_process(delta: float) -> void:
	clock += delta
	var to: Vector2 = from
	if is_instance_valid(target):
		to = target.position
	var f := clampf(clock / dur, 0.0, 1.0)
	position = from.lerp(to, f) - Vector2(0, sin(f * PI) * peak)
	queue_redraw()
	if f >= 1.0 and not landed:
		landed = true
		if is_instance_valid(target) and target.has_method("hit_by_hero"):
			target.hit_by_hero(float(target.max_hp) * 0.125, 3.0)
		area.spawn_troop("hero", team, position + Vector2(0, 16))
		area.banner_flash("The hero dismounts and holds the line!")
		queue_free()


func _draw() -> void:
	var r: float = area.TILE * 0.42
	# little cape trail
	draw_line(Vector2(-r * 1.4, -r * 1.6), Vector2(-r * 0.2, 0), Color(0.9, 0.8, 0.4, 0.5), 3.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	DDArt.creature(self, "hero", r, 1.0, clock * 4.0)
