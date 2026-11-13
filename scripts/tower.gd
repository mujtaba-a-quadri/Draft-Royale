class_name DDTower
extends Node2D

var team: int = 0
var area: Node2D = null
var max_hp := 250.0
var hp := 250.0
var dmg := 12.0
var reach := 6.0
var interval := 1.0
var radius_t := 0.9
var crown := false
var dead := false
var atk_cd := 0.0
var flash := 0.0
var clock := 0.0
var target: Node = null
var w := 0.0
var h := 0.0


func setup(tm: int, ar: Node2D, is_crown: bool) -> void:
	team = tm
	area = ar
	crown = is_crown
	max_hp = 250.0
	hp = max_hp
	w = area.TILE * 1.75
	h = area.TILE * 1.75
	z_index = 3


func is_building() -> bool:
	return true


func is_tower() -> bool:
	return true


func get_radius_t() -> float:
	return radius_t


func _physics_process(delta: float) -> void:
	if dead:
		return
	clock += delta
	flash = maxf(0.0, flash - delta * 5.0)
	if area.match_over:
		queue_redraw()
		return
	atk_cd = maxf(0.0, atk_cd - delta)
	if target == null or not _target_valid(target) or area.tiles_between(position, target.position) > reach + 1.5:
		target = _acquire()
	if target == null:
		queue_redraw()
		return
	if atk_cd <= 0.0 and area.tiles_between(position, target.position) <= reach:
		atk_cd = interval
		area.spawn_projectile(position, target.position, team, dmg, 0.0, "tower")
	queue_redraw()


func _target_valid(t: Node) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	return t.get("dead") != true and int(t.get("team")) != team


func _acquire() -> Node:
	var best: Node = null
	var best_d := INF
	for u in area.enemy_units(team):
		if not is_instance_valid(u) or u.dead:
			continue
		var d: float = area.tiles_between(position, u.position)
		if d > reach:
			continue
		if d < best_d - 0.0001:
			best = u
			best_d = d
		elif absf(d - best_d) <= 0.0001 and best != null and u.get_instance_id() < best.get_instance_id():
			best = u
	return best


func take_damage(amount: float, _from: Vector2, _attacker: Node = null) -> void:
	if dead or amount <= 0.0:
		return
	hp -= amount
	flash = 0.5
	if hp <= 0.0:
		hp = 0.0
		dead = true
		area.on_tower_destroyed(self)
		queue_redraw()


func _draw() -> void:
	var col := Color(0.36, 0.62, 0.95) if team == 0 else Color(0.92, 0.4, 0.42)
	if dead:
		var wall := Color(0.5, 0.48, 0.46)
		draw_rect(Rect2(-w * 0.5, h * 0.12, w, h * 0.38), wall, true)
		draw_rect(Rect2(-w * 0.5, h * 0.12, w, h * 0.38), DDArt.OUTLINE, false, 2.5)
		for i in 3:
			var rr := Rect2(-w * 0.48 + float(i) * w * 0.3, -h * 0.1 + float(i) * 5.0, w * 0.2, h * 0.16)
			draw_rect(rr, wall.darkened(0.15), true)
			draw_rect(rr, DDArt.OUTLINE, false, 2.0)
		return
	DDArt.tower(self, w, h, col, flash, crown)
	if hp <= 0.0:
		return
	var bw := w * 1.05
	var by := -h * 0.5 - 22.0
	draw_rect(Rect2(-bw * 0.5, by, bw, 7.0), Color(0.08, 0.07, 0.1, 0.85), true)
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	var hc := Color(0.45, 0.9, 0.55) if team == 0 else Color(0.95, 0.45, 0.45)
	draw_rect(Rect2(-bw * 0.5 + 1.5, by + 1.5, (bw - 3.0) * frac, 4.0), hc, true)
	draw_string(ThemeDB.fallback_font, Vector2(bw * 0.5 + 6.0, by + 9.0), "%d" % int(ceil(hp)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.95, 0.9))
