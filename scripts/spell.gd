class_name DDSpell
extends Node2D

## Spells are fired out of one of the caster's towers, not dropped from the sky.
##   launch "closest"  the friendly tower nearest the target point
##   launch "king"     the king tower
## The node exists for one frame: it picks the tower, spawns the bolt and dies.

var kind := "fireball"
var team := 0
var area: Node2D = null
var dmg := 0.0
var radius_t := 1.0
var tower_mult := 1.0
var burn := 0.0
var burn_ticks := 4
var knock := 0.0
var launch := "closest"
var fired := false


func setup(a: Node2D, k: String, tm: int) -> void:
	area = a
	kind = k
	team = tm
	var d: Dictionary = DDCard.get_card(k)
	dmg = float(d.get("dmg", 0.0))
	radius_t = float(d.get("splash", 0.0))
	tower_mult = float(d.get("tower_mult", 1.0))
	burn = float(d.get("burn", 0.0))
	burn_ticks = int(d.get("burn_ticks", 4))
	knock = float(d.get("knock", 0.0))
	launch = String(d.get("launch", "closest"))
	z_index = 20


func _physics_process(_delta: float) -> void:
	if fired:
		return
	fired = true
	var origin: Vector2 = position
	var tw: Node = null
	if launch == "king":
		tw = area.crown_tower(team)
	if tw == null:
		tw = area.nearest_own_tower(team, position)
	if tw != null:
		origin = tw.position + Vector2(0.0, -float(area.TILE) * 0.9)
	var payload := {"burn": burn, "burn_ticks": burn_ticks, "knock": knock, "tower_mult": tower_mult, "spell": true}
	# a unit-locking spell (the Firebolt) was cast on the troop under the cursor:
	# it homes on that body and lands on it wherever it has walked to
	var lock: Node = _locked_target() if bool(DDCard.get_card(kind).get("unit_lock", false)) else null
	var aim: Vector2 = position
	if lock != null:
		payload["seek"] = lock
		aim = lock.position
	area.spawn_projectile(origin, aim, team, dmg, radius_t, kind,
		0, "bolt", false, null, 0.0, null, payload)
	queue_free()


## The enemy body this was cast on: the one whose body the cast point is in
## (aim_point puts the cast exactly on the locked body's centre, a frame ago).
## Troops, buildings, towers and bosses alike.
func _locked_target() -> Node:
	var best: Node = null
	var best_d := INF
	for e in area.enemy_entities(team):
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = area.tiles_between(position, e.position)
		if d <= float(e.get_radius_t()) + 0.2 and d < best_d:
			best_d = d
			best = e
	return best
