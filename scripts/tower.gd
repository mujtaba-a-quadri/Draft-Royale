class_name DDTower
extends Node2D

var team: int = 0
var area: Node2D = null
var max_hp := 250.0
var hp := 250.0
var dmg := 12.0
## side towers: 7 tiles; the crown tower keeps 8 (setup)
var reach := 7.0
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
const BURN_RATE := 0.2
var burn_stack := 0.0
var burn_ticks := 0
var burn_max_ticks := 4
var burn_timer := 0.0
var burn_pulse := 0.0
## Poison (spiderling bites): a counter that never wears off, ticking for twice
## its value every five seconds. Same rule as DDUnit.
var poison := 0.0
var poison_timer := 0.0
## Cosmetic clocks for the goblin commander: seconds since his spear left his
## hand and since he scooped Shiesty up. Nothing in the simulation reads them.
var throw_t := 9.0
var toss_t := 9.0


## The goblin commander is the crown tower of whoever holds the Shiesty ability.
func is_goblin() -> bool:
	if not crown or area == null or area.ability.size() <= int(team):
		return false
	return String(area.ability[int(team)]) != "tentacle"


## +1 when the enemy is to the right of this tower, -1 when to the left.
func face_dir() -> float:
	var dx: float = area.board_rect().get_center().x - position.x
	return 1.0 if dx >= 0.0 else -1.0


## Called by the arena when Shiesty is sent: the commander scoops and throws him.
func play_toss() -> void:
	toss_t = 0.0


func setup(tm: int, ar: Node2D, is_crown: bool) -> void:
	team = tm
	area = ar
	crown = is_crown
	if is_crown:
		reach += 1.0
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
	throw_t += delta
	toss_t += delta
	flash = maxf(0.0, flash - delta * 5.0)
	if area.match_over:
		queue_redraw()
		return
	atk_cd = maxf(0.0, atk_cd - delta)
	if poison > 0.0:
		poison_timer -= delta
		if poison_timer <= 0.0:
			poison_timer += DDUnit.POISON_PERIOD
			take_damage(poison * DDUnit.POISON_MULT * DDUnit.POISON_BUILDING, position)
			if dead:
				return
	# burn: towers take 20 % of the stack per tick instead of a troop's 40 %
	if burn_pulse > 0.0:
		burn_pulse = maxf(0.0, burn_pulse - delta * 1.7)
	if burn_timer > 0.0:
		burn_timer -= delta
		if burn_timer <= 0.0:
			var tick_dmg := floorf(burn_stack * BURN_RATE)
			burn_ticks += 1
			burn_pulse = 1.0
			if tick_dmg <= 0.0 or burn_ticks >= burn_max_ticks:
				burn_stack = 0.0
				burn_ticks = 0
				burn_timer = 0.0
			else:
				burn_stack = maxf(0.0, burn_stack - tick_dmg)
				burn_timer = 1.0
				take_damage(tick_dmg, position)
	# a curled whelp or hedgehog is the last thing worth a shot: while the
	# current target is curled, look again every tick for anything better
	if target == null or not _target_valid(target) or area.tiles_between(position, target.position) > reach + 1.5 \
			or target.get("curled") == true:
		target = _acquire()
	if target == null:
		queue_redraw()
		return
	if atk_cd <= 0.0 and area.tiles_between(position, target.position) <= reach:
		atk_cd = interval
		# aimed shot: the bolt hits only the unit it was fired at, never splash
		# the goblin commander throws his standard; same shot, different picture
		var shot := "tower"
		if is_goblin():
			shot = "spear"
			throw_t = 0.0
		area.spawn_projectile(position, target.position, team, dmg, 0.0, shot,
			0, "bolt", false, null, 0.0, target)
	queue_redraw()


func _target_valid(t: Node) -> bool:
	if t == null or not is_instance_valid(t):
		return false
	return t.get("dead") != true and int(t.get("team")) != team


## Nearest enemy unit in range. Curled units (an Obsidian Whelp or a hedgehog
## balled up) only get picked when there is nothing else in range.
func _acquire() -> Node:
	var best: Node = null
	var best_d := INF
	var best_curled := true
	for u in area.enemy_units(team):
		if not is_instance_valid(u) or u.dead:
			continue
		if u.get("tower_ignore") == true:
			continue
		var d: float = area.tiles_between(position, u.position)
		if d > reach:
			continue
		var curled: bool = u.get("curled") == true
		if best != null and curled and not best_curled:
			continue
		if best == null or (best_curled and not curled) or d < best_d - 0.0001:
			best = u
			best_d = d
			best_curled = curled
		elif absf(d - best_d) <= 0.0001 and u.get_instance_id() < best.get_instance_id():
			best = u
	return best


func add_poison(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	if poison <= 0.0:
		poison_timer = DDUnit.POISON_PERIOD
	poison += amount


func apply_burn(amount: float, max_ticks: int = 4) -> void:
	if dead or amount <= 0.0:
		return
	burn_stack += amount
	burn_ticks = 0
	burn_max_ticks = maxi(max_ticks, 1)
	if burn_timer <= 0.0:
		burn_timer = 1.0


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
	var col: Color = area.team_color(int(team))
	if dead:
		var wall := Color(0.5, 0.48, 0.46)
		draw_rect(Rect2(-w * 0.5, h * 0.12, w, h * 0.38), wall, true)
		draw_rect(Rect2(-w * 0.5, h * 0.12, w, h * 0.38), DDArt.OUTLINE, false, 2.5)
		for i in 3:
			var rr := Rect2(-w * 0.48 + float(i) * w * 0.3, -h * 0.1 + float(i) * 5.0, w * 0.2, h * 0.16)
			draw_rect(rr, wall.darkened(0.15), true)
			draw_rect(rr, DDArt.OUTLINE, false, 2.0)
		return
	if crown:
		var ab := ""
		if area != null and area.ability.size() > int(team):
			ab = String(area.ability[int(team)])
		var ready := false
		if area != null and area.has_method("ability_ready"):
			ready = bool(area.ability_ready(int(team)))
		draw_circle(Vector2(0, h * 0.28), w * 0.62, Color(0, 0, 0, 0.18))
		var team_col: Color = col.lightened(0.18)
		# the tail sweeps away from the board: left side mirrors it outward
		DDArt.commander(self, ab, w * 0.62, clock, ready, team_col, int(team) == 0,
			{"face": face_dir(), "throw": throw_t, "toss": toss_t})
	elif area.get("diamond_towers") == true:
		DDArt.diamond_tower(self, Vector2.ZERO, w, col, flash, area.team_ink(int(team)))
	else:
		DDArt.tower(self, w, h, col, flash, crown, area.team_ink(int(team)))
	if hp <= 0.0:
		return
	if burn_timer > 0.0:
		var bc := DDUnit.burn_color(burn_ticks, burn_max_ticks)
		var a := 0.18 + 0.42 * burn_pulse
		draw_rect(Rect2(-w * 0.55, -h * 0.6, w * 1.1, h * 1.15), Color(bc.r, bc.g, bc.b, a), true)
		draw_rect(Rect2(-w * 0.55, -h * 0.6, w * 1.1, h * 1.15), Color(bc.r, bc.g, bc.b, 0.8), false, 2.0)
	if poison > 0.0:
		DDArt.poison_badge(self, Vector2(-w * 0.62, -h * 0.5 - 18.0), poison, poison_timer / DDUnit.POISON_PERIOD)
	var bw := w * 1.05
	var by := -h * 0.5 - 22.0
	draw_rect(Rect2(-bw * 0.5, by, bw, 7.0), Color(0.08, 0.07, 0.1, 0.85), true)
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	var hc := Color(0.45, 0.9, 0.55) if team == 0 else Color(0.95, 0.45, 0.45)
	draw_rect(Rect2(-bw * 0.5 + 1.5, by + 1.5, (bw - 3.0) * frac, 4.0), hc, true)
	draw_string(ThemeDB.fallback_font, Vector2(bw * 0.5 + 6.0, by + 9.0), "%d" % int(ceil(hp)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.95, 0.95, 0.9))
