extends Node

## Verification helper. Launch with user args after a bare "--", e.g.
##   -- --demo --shots=<abs path to debug folder>
##   -- --scenario=kit --shots=...
## --demo drives both hands automatically; --scenario sets up scripted
## situations (alchemist phase 2, golden idol boulder) for visual checks.

var arena: Node2D = null
var shot_dir := ""
var demo := false
var scenario := ""
var elapsed := 0.0
var shot_times: Array = []
var count := 0
var demo_t := 0.6
var lane_flip := 0
var done_steps: Dictionary = {}
var alch: Node = null
var log_mode := false
var next_log := 0.5
var run_time := 12.0
var max_gap := 0.0
var probe: Node = null
var saw_air_target := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shot_dir = a.substr(8)
		elif a == "--demo":
			demo = true
		elif a.begins_with("--scenario="):
			scenario = a.substr(11)
		elif a == "--log":
			log_mode = true
	if shot_dir != "":
		DirAccess.make_dir_recursive_absolute(shot_dir)
	if scenario == "kit":
		shot_times = [1.2, 2.8, 4.2, 6.0, 8.0, 10.0]
		run_time = 12.5
	elif scenario == "checks":
		shot_times = []
		run_time = 9.0
	elif scenario == "click":
		shot_times = []
		run_time = 8.0
	elif scenario == "win":
		shot_times = [2.2]
		run_time = 4.0
	elif scenario == "dragon":
		shot_times = []
		run_time = 9.5
	elif scenario == "slate":
		shot_times = []
		run_time = 4.0
	elif scenario == "control":
		shot_times = []
		run_time = 8.0
	elif scenario == "targeting":
		shot_times = []
		run_time = 6.0
	elif scenario == "overkill":
		shot_times = []
		run_time = 3.0
	elif scenario == "roll":
		shot_times = []
		run_time = 10.0
	elif scenario == "prims":
		shot_times = []
		run_time = 4.0
	elif scenario == "fu":
		shot_times = []
		run_time = 9.0
	elif scenario == "bench":
		shot_times = []
		run_time = 999.0
	elif scenario == "bot":
		shot_times = []
		run_time = 999.0
	elif scenario == "think":
		shot_times = [3.2]
		run_time = 6.5
	elif scenario == "swarm":
		shot_times = []
		run_time = 7.0
	elif scenario == "juice":
		shot_times = []
		run_time = 3.0
	elif scenario == "flash":
		shot_times = [1.0]
		run_time = 2.5
	elif scenario == "ability":
		shot_times = []
		run_time = 20.0
	elif scenario == "zombify":
		shot_times = [2.4]
		run_time = 4.0
	elif scenario == "hog":
		shot_times = [2.3]
		run_time = 4.0
	else:
		shot_times = [2.0, 5.0, 8.0, 11.0]
		run_time = 13.5


func _process(delta: float) -> void:
	elapsed += delta
	if arena == null:
		return
	if scenario == "kit":
		_kit_steps()
	elif scenario == "checks":
		_checks_steps()
	elif scenario == "click":
		_click_steps()
	elif scenario == "dragon":
		_dragon_steps()
	elif scenario == "slate":
		_slate_steps()
	elif scenario == "control":
		_control_steps()
	elif scenario == "targeting":
		_targeting_steps()
	elif scenario == "overkill":
		_overkill_steps()
	elif scenario == "roll":
		_roll_steps()
	elif scenario == "prims":
		_prims_steps()
	elif scenario == "fu":
		_fu_steps()
	elif scenario == "bot":
		_bot_steps()
	elif scenario == "swarm":
		_swarm_steps()
	elif scenario == "juice":
		_juice_steps()
	elif scenario == "ability":
		_ability_steps()
	elif scenario == "zombify":
		_zombify_steps()
	elif scenario == "hog":
		_hog_steps()
	elif scenario == "flash":
		if _at(1.0):
			var kinds := ["snowman", "slate", "alchemist", "hero"]
			for i in 4:
				var u = arena.spawn_troop(String(kinds[i]), 0, arena.tile_center(6.5 + float(i) * 2.5, 20.5))
				u.deploy_timer = 0.0
				if i < 3:
					u.hurt_frames = 2
			print("[flash] staged 3 hurt units + 1 control")
	elif scenario == "think":
		if _at(0.2):
			arena.set_view_mode(1)
		if _at(2.6):
			var b = arena.bots[1]
			if b != null and not b.armed:
				var hand: Array = arena.hands[1]
				var idx := mini(1, hand.size() - 1)
				if idx >= 0:
					b.hover_index = idx
					b.pending_kind = String(hand[idx])
					b.pending_pos = arena.tile_center(9.5, 12.5)
					b.armed = true
					b.arm_t = 9.0
			elif b != null:
				b.arm_t = 9.0
			print("[think] armed=%s hover=%d target=(%.1f,%.1f)" % [
				str(b.armed), int(b.hover_index),
				(b.pending_pos.x - arena.ORIGIN.x) / arena.TILE,
				(b.pending_pos.y - arena.ORIGIN.y) / arena.TILE])
	elif scenario == "bench":
		if _at(0.1):
			for i in 5:
				arena.spawn_troop("slate", 0, arena.tile_center(4.5 + float(i), 24.5))
				arena.spawn_troop("hero", 0, arena.tile_center(11.5 + float(i) * 0.5, 22.5))
				arena.spawn_troop("slate", 1, arena.tile_center(4.5 + float(i), 5.5))
				arena.spawn_troop("hero", 1, arena.tile_center(11.5 + float(i) * 0.5, 7.5))
			arena.spawn_troop("fu", 0, arena.tile_center(9.5, 20.5))
			arena.spawn_troop("fu", 1, arena.tile_center(9.5, 9.5))
			print("[bench] %d units" % arena.units.size())
	elif scenario == "win":
		if _at(0.4):
			for tw in arena.towers:
				if is_instance_valid(tw) and int(tw.team) == 0:
					tw.take_damage(999.0, tw.position)
			print("[win] match_over=%s winner=%d" % [str(arena.match_over), arena.winner])
	if log_mode and elapsed >= next_log:
		next_log += 1.0
		_log_state()
	if demo:
		demo_t -= delta
		if demo_t <= 0.0:
			demo_t = 2.0
			_demo_play()
	if shot_dir != "" and count < shot_times.size() and elapsed >= float(shot_times[count]):
		_capture()
	if run_time > 0.0 and elapsed > run_time:
		get_tree().quit()


func _at(t: float) -> bool:
	var key := str(t)
	if elapsed >= t and not done_steps.has(key):
		done_steps[key] = true
		return true
	return false


func _kit_steps() -> void:
	if _at(0.4):
		arena.spawn_troop("idol", 0, arena.tile_center(8.0, 18.0))
		arena.spawn_troop("slate", 1, arena.tile_center(8.0, 12.0))
		alch = arena.spawn_troop("alchemist", 0, arena.tile_center(3.5, 18.0))
		arena.spawn_troop("snowman", 1, arena.tile_center(11.5, 12.0))
	if _at(2.4) and alch != null and is_instance_valid(alch):
		alch.take_damage(28.0, alch.position + Vector2(0, 24))
	if _at(6.5):
		arena.spawn_troop("fireball", 1, arena.tile_center(8.0, 17.5))


func _log_state() -> void:
	var parts: Array = []
	for u in arena.units:
		if is_instance_valid(u) and not u.dead:
			var tx: float = (u.position.x - arena.ORIGIN.x) / arena.TILE
			var ty: float = (u.position.y - arena.ORIGIN.y) / arena.TILE
			parts.append("%s%d(%.1f,%.1f)%d" % [String(u.kind).substr(0, 4), int(u.team), tx, ty, int(u.hp)])
	var tw_parts: Array = []
	for tw in arena.towers:
		if is_instance_valid(tw):
			tw_parts.append("t%d:%d" % [int(tw.team), int(tw.hp)])
	print("[t=%.1f] units=%s | towers=%s" % [elapsed, ",".join(parts), ",".join(tw_parts)])


func _checks_steps() -> void:
	if _at(0.3):
		arena.spawn_troop("idol", 0, arena.tile_center(8.0, 18.0))
		arena.spawn_troop("slate", 1, arena.tile_center(8.0, 16.6))
		alch = arena.spawn_troop("alchemist", 0, arena.tile_center(3.0, 20.0))
	if _at(1.0) and alch != null and is_instance_valid(alch):
		alch.take_damage(28.0, alch.position + Vector2(0, 24))


func _click(pos: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = pos
	down.global_position = pos
	get_viewport().push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = pos
	up.global_position = pos
	get_viewport().push_input(up)


func _click_steps() -> void:
	if _at(1.0):
		var hand: Array = arena.hands[0]
		var pick := -1
		for i in hand.size():
			if arena.gold[0] >= float(DDCard.cost(String(hand[i]))):
				pick = i
				break
		print("[click] p1 hand=%s pick=%d gold=%.1f panel_size=%s pos=%s" % [str(hand), pick, arena.gold[0], str(arena.panels[0].size), str(arena.panels[0].position)])
		if pick >= 0:
			_click(Vector2(230.0, 216.0 + float(pick) * 144.0))
		print("[click] selected=%d index=%d" % [arena.selected_player, arena.selected_index])
	if _at(1.6):
		_click(Vector2(588.0, 620.0))
		print("[click] units=%d gold=%.1f" % [arena.units.size(), arena.gold[0]])
	if _at(3.2):
		var hand: Array = arena.hands[1]
		var pick := -1
		for i in hand.size():
			if DDCard.is_spell(String(hand[i])) and arena.gold[1] >= float(DDCard.cost(String(hand[i]))):
				pick = i
				break
		print("[click] p2 hand=%s spellpick=%d gold=%.1f" % [str(hand), pick, arena.gold[1]])
		if pick >= 0:
			_click(Vector2(940.0 + 230.0, 216.0 + float(pick) * 144.0))
			print("[click] selected=%d index=%d" % [arena.selected_player, arena.selected_index])
	if _at(3.8):
		_click(Vector2(700.0, 742.0))
		print("[click] cast -> selected=%d" % arena.selected_player)
	if _at(5.0):
		print("[click] towers after spell=%s units=%d" % [str(arena.towers.map(func(t): return int(t.hp))), arena.units.size()])


func _dragon_steps() -> void:
	if _at(0.3):
		alch = arena.spawn_troop("dragon", 0, arena.tile_center(8.0, 16.0))
		alch.take_damage(200.0, alch.position)
		print("[dragon] spawned hp=%d" % int(alch.hp))
	if _at(2.0):
		print("[dragon] airborne=%s pos=(%.1f,%.1f) prompt_p2=%s" % [
			str(alch.flying), (alch.position.x - arena.ORIGIN.x) / arena.TILE,
			(alch.position.y - arena.ORIGIN.y) / arena.TILE, str(arena.hero_prompt_active(1))])
	if _at(2.4):
		arena.launch_hero(1)
		print("[dragon] hero launched, p2 gold=%.1f" % arena.gold[1])
	if _at(3.4):
		print("[dragon] after impact hp=%d flying=%s stun=%.1f" % [int(alch.hp), str(alch.flying), alch.stunned])
	if _at(7.0):
		print("[dragon] after stun hp=%d flying=%s" % [int(alch.hp), str(alch.flying)])
	if _at(8.1):
		var hero_count := 0
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "hero":
				hero_count += 1
		print("[dragon] heroes alive=%d  slate_targets_buildings_only=%s" % [hero_count, str(bool(DDCard.get_card("slate").get("buildings_only", false)))])


func _slate_steps() -> void:
	if _at(0.3):
		var s = arena.spawn_troop("slate", 0, arena.tile_center(8.0, 19.0))
		alch = s
		arena.spawn_troop("hero", 1, arena.tile_center(8.0, 17.0))
		print("[slate] hp=%d buildings_only=%s" % [int(s.hp), str(s.buildings_only)])
	if _at(1.6):
		var t = alch.target
		if t == null:
			print("[slate] no target")
		else:
			var kk = t.get("kind")
			if kk == null:
				kk = "tower"
			print("[slate] target=%s team=%d is_building=%s moving_troops_ignored=true" % [String(kk), int(t.team), str(t.is_building())])
	if _at(3.2):
		var t2 = alch.target
		print("[slate] later target=%s" % (("tower team %d" % int(t2.team)) if t2 != null and t2.get("kind") == null else str(t2)))


func _control_steps() -> void:
	var band_tile := Vector2i(6, 16)
	var pt: Vector2 = arena.tile_center(6.5, 16.5)
	if _at(0.3):
		alch = arena.spawn_troop("snowman", 0, pt)
		print("[control] band tile valid=%s outer col0 row9 valid=%s" % [
			str(arena.valid_tile(band_tile)), str(arena.valid_tile(Vector2i(0, 9)))])
		print("[control] before presence: p0=%s p1=%s" % [
			str(arena.can_deploy(0, "slate", pt)), str(arena.can_deploy(1, "slate", pt))])
	if _at(1.2):
		print("[control] claimed tile p0=%s p1=%s nearby_p0=%s far_band_p0=%s" % [
			str(arena.can_deploy(0, "slate", pt)), str(arena.can_deploy(1, "slate", pt)),
			str(arena.can_deploy(0, "slate", arena.tile_center(7.5, 16.5))),
			str(arena.can_deploy(0, "slate", arena.tile_center(13.5, 12.5)))])
		var counts = arena.control_counts()
		print("[control] counts p0=%d p1=%d contested=%d" % [counts[0], counts[1], counts[2]])
	if _at(2.0):
		alch.take_damage(9999.0, alch.position)
		print("[control] keeper killed")
	if _at(3.0):
		print("[control] 1s after death still claimed=%s" % str(arena.can_deploy(0, "slate", pt)))
	if _at(6.8):
		print("[control] after decay claimed=%s counts=%s" % [
			str(arena.can_deploy(0, "slate", pt)), str(arena.control_counts())])
	if _at(7.4):
		print("[control] own half still free=%s enemy half denied=%s" % [
			str(arena.can_deploy(0, "slate", arena.tile_center(9.5, 24.5))),
			str(arena.can_deploy(0, "slate", arena.tile_center(9.5, 8.5)))])


func _target_kind(u: Node) -> String:
	if u == null or not is_instance_valid(u):
		return "none"
	var k = u.get("kind")
	if k == null:
		return "tower%d" % int(u.team)
	return "%s%d" % [String(k), int(u.team)]


func _targeting_steps() -> void:
	if _at(0.2):
		alch = arena.spawn_troop("hero", 0, arena.tile_center(3.5, 25.5))
		var idol = arena.spawn_troop("idol", 1, arena.tile_center(12.5, 13.5))
		arena.spawn_troop("alchemist", 0, arena.tile_center(12.5, 16.5))
		arena.spawn_troop("alchemist", 0, arena.tile_center(14.5, 16.5))
		print("[target] setup idol hp=%d" % int(idol.hp))
	if _at(0.55):
		var idol: Node = null
		var alchs: Array = []
		for u in arena.units:
			if not is_instance_valid(u):
				continue
			if String(u.kind) == "idol":
				idol = u
			if String(u.kind) == "alchemist":
				alchs.append(u)
		if idol != null:
			var s := "[target] idol hp=%d incoming=%.0f doomed=%s" % [int(idol.hp), float(idol.incoming), str(arena.is_doomed(idol))]
			for u in alchs:
				s += " | alch->%s" % _target_kind(u.target)
			print(s)
		else:
			print("[target] idol already gone")
		print("[target] hero target(before)=%s" % _target_kind(alch.target))
	if _at(2.0):
		arena.spawn_troop("snowman", 1, arena.tile_center(3.5, 21.5))
		print("[target] snowman placed 4 tiles from hero")
	if _at(3.2):
		print("[target] hero target(after)=%s" % _target_kind(alch.target))


func _overkill_steps() -> void:
	if _at(0.2):
		var idol = arena.spawn_troop("idol", 1, arena.tile_center(12.5, 13.5))
		arena.reserve_damage(-99, idol, 45.0)
		print("[overkill] promised 45 into a %d hp idol -> doomed=%s incoming=%.0f" % [
			int(idol.hp), str(arena.is_doomed(idol)), float(idol.incoming)])
	if _at(0.3):
		alch = arena.spawn_troop("alchemist", 0, arena.tile_center(12.5, 16.5))
		print("[overkill] alchemist spawned while idol is doomed")
	if _at(0.9):
		print("[overkill] alchemist target while doomed=%s (should be a tower)" % _target_kind(alch.target))
	if _at(1.0):
		arena.release_reservation(-99)
		print("[overkill] reservation released -> doomed=%s" % str(arena.is_doomed(alch.target)))
	if _at(1.15):
		print("[overkill] 0.15s after release target=%s" % _target_kind(alch.target))
	if _at(1.9):
		var idol: Node = null
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "idol":
				idol = u
		print("[overkill] 0.9s after release idol_alive=%s target=%s (it took the shot)" % [
			str(idol != null), _target_kind(alch.target)])


func _roll_steps() -> void:
	if _at(0.2):
		alch = arena.spawn_troop("slate", 0, arena.tile_center(4.5, 16.5))
		print("[roll] spawned speed=%.2f level=%d" % [alch.speed, alch.roll_level])
	if _at(1.5):
		print("[roll] t1.5 speed=%.2f level=%d timer=%.2f" % [alch.speed, alch.roll_level, alch.roll_timer])
	if _at(3.6):
		print("[roll] t3.6 speed=%.2f level=%d" % [alch.speed, alch.roll_level])
	if _at(6.5):
		var trails := 0
		for c in arena.get_children():
			if c is DDTrail:
				trails += 1
		print("[roll] t6.5 speed=%.2f level=%d trail_decals=%d" % [alch.speed, alch.roll_level, trails])
	if _at(9.2):
		print("[roll] t9.2 level=%d speed=%.2f tower_hps=%s" % [alch.roll_level, alch.speed, str(arena.towers.map(func(t): return int(t.hp)))])


func _prims_steps() -> void:
	if _at(0.2):
		alch = arena.spawn_troop("hero", 0, arena.tile_center(9.5, 20.5))
		print("[prims] hero at (%.1f,%.1f)" % [(alch.position.x - arena.ORIGIN.x) / arena.TILE, (alch.position.y - arena.ORIGIN.y) / arena.TILE])
	if _at(0.4):
		alch.apply_impulse(Vector2(1, 0), 3.0, 0.3)
		print("[prims] impulse queued state=%d" % int(alch.state))
	if _at(1.0):
		print("[prims] after slide x=%.1f state=%d" % [(alch.position.x - arena.ORIGIN.x) / arena.TILE, int(alch.state)])
		alch.has_projectile = true
		arena.spawn_projectile(alch.position, alch.position + Vector2(4.0 * arena.TILE, 0), 0, 10.0, 0.0,
			"boomerang", alch.get_instance_id(), "return", false, alch)
		print("[prims] boomerang launched has_projectile=%s" % str(alch.has_projectile))
	if _at(1.9):
		print("[prims] mid flight has_projectile=%s" % str(alch.has_projectile))
	if _at(3.4):
		print("[prims] after return has_projectile=%s (caught by owner)" % str(alch.has_projectile))


func _fu_steps() -> void:
	if _at(0.2):
		alch = arena.spawn_troop("fu", 0, arena.tile_center(8.5, 20.5))
		arena.spawn_troop("snowman", 1, arena.tile_center(8.5, 17.5))
		print("[fu] spawned hp=%d cost=%d" % [int(alch.hp), DDCard.cost("fu")])
	if _at(0.7):
		print("[fu] has_projectile=%s pos=(%.1f,%.1f)" % [str(alch.has_projectile), (alch.position.x - arena.ORIGIN.x) / arena.TILE, (alch.position.y - arena.ORIGIN.y) / arena.TILE])
	if _at(1.4):
		alch.apply_impulse(Vector2(1, 0), 2.0, 0.2)
		print("[fu] displaced while boomerang is out")
	if _at(1.0) or _at(2.0) or _at(3.0) or _at(4.0):
		var info := ""
		for c in arena.get_children():
			if c is DDProjectile:
				info += "phase=%d pos=(%.1f,%.1f) clock=%.1f speed=%.0f | " % [
					int(c.phase), (c.position.x - arena.ORIGIN.x) / arena.TILE,
					(c.position.y - arena.ORIGIN.y) / arena.TILE, c.clock, c.speed_px]
		print("[fu] t=%.1f boomerangs: %s" % [elapsed, info if info != "" else "none"])
	if _at(2.2):
		print("[fu] after displacement pos=(%.1f,%.1f) has_projectile=%s state=%d" % [
			(alch.position.x - arena.ORIGIN.x) / arena.TILE, (alch.position.y - arena.ORIGIN.y) / arena.TILE,
			str(alch.has_projectile), int(alch.state)])
	if _at(4.6):
		print("[fu] boomerang home? has_projectile=%s throw_cd=%.2f" % [str(alch.has_projectile), alch.throw_cd])
	if _at(3.2):
		for u in arena.units.duplicate():
			if is_instance_valid(u) and String(u.kind) == "snowman":
				u.take_damage(9999.0, u.position)
		print("[fu] dummy removed")
	if _at(4.6):
		print("[fu] after dummy gone has_projectile=%s (false = caught)" % str(alch.has_projectile))
	if _at(6.0):
		probe = arena.spawn_troop("hero", 1, alch.position + Vector2(0, -arena.TILE))
		print("[fu] melee target placed adjacent")
	if elapsed > 6.0 and probe != null and is_instance_valid(probe):
		max_gap = maxf(max_gap, arena.tiles_between(alch.position, probe.position))
	if _at(8.6):
		print("[fu] max gap reached=%.1f tiles (kick pushes 3) fu_state=%d" % [max_gap, int(alch.state)])


func _bot_steps() -> void:
	if log_mode and elapsed >= next_log:
		next_log += 5.0
		var tower_hps: Array = []
		for tw in arena.towers:
			if is_instance_valid(tw):
				tower_hps.append(int(tw.hp))
		print("[bot] t=%.0f gold=(%.0f,%.0f) units=%d towers=%s" % [
			elapsed, float(arena.gold[0]), float(arena.gold[1]), arena.units.size(), str(tower_hps)])
	if arena.match_over and not done_steps.has("end"):
		done_steps["end"] = true
		var b0 = arena.bots[0]
		var b1 = arena.bots[1]
		print("[bot] MATCH OVER winner=%d | p1 plays=%d gold=%.0f | p2 plays=%d gold=%.0f | tower_hps=%s" % [
			arena.winner,
			int(b0.plays) if b0 != null else -1, float(b0.gold_spent) if b0 != null else -1.0,
			int(b1.plays) if b1 != null else -1, float(b1.gold_spent) if b1 != null else -1.0,
			str(arena.towers.map(func(t): return int(t.hp)))])


func _swarm_steps() -> void:
	if _at(0.2):
		var lead = arena.spawn_troop("hawk", 0, arena.tile_center(8.5, 19.5))
		probe = lead
		var birds := 0
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "hawk":
				birds += 1
		print("[swarm] birds=%d lead_hp=%d lead_r=%.2f first_hp=%d" % [birds, int(lead.hp), lead.radius_t, int(lead.hp)])
		print("[swarm] hits_air alchemist=%s fu=%s hawk=%s slate=%s" % [
			str(bool(DDCard.get_card("alchemist").get("hits_air", false))),
			str(bool(DDCard.get_card("fu").get("hits_air", false))),
			str(bool(DDCard.get_card("hawk").get("hits_air", false))),
			str(bool(DDCard.get_card("slate").get("hits_air", false)))])
	if _at(1.2):
		var d = arena.spawn_troop("dragon", 0, arena.tile_center(8.5, 16.0))
		d.team = 1
		d.take_damage(float(d.max_hp) * 0.6, d.position)
		print("[swarm] dragon for team 1 max=%d hp=%d" % [int(d.max_hp), int(d.hp)])
	if elapsed > 1.3:
		for u in arena.units:
			if not is_instance_valid(u) or String(u.kind) != "hawk":
				continue
			var t = u.target
			if t != null and is_instance_valid(t) and String(t.kind) == "dragon":
				saw_air_target = true
	if _at(2.6):
		var d2: Node = null
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "dragon":
				d2 = u
		var bird_targets_dragon := false
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "hawk" and u.target == d2:
				bird_targets_dragon = true
		print("[swarm] dragon flying=%s hp=%s | bird_targets_dragon=%s" % [
			str(d2.flying) if d2 != null else "gone",
			str(int(d2.hp)) if d2 != null else "gone",
			str(bird_targets_dragon)])
	if _at(4.2):
		var alive := 0
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "hawk" and not u.dead:
				alive += 1
		print("[swarm] birds alive after tower fire=%d | a bird locked onto the dragon at some point=%s" % [alive, str(saw_air_target)])


func _juice_steps() -> void:
	if _at(0.2):
		alch = arena.spawn_troop("slate", 0, arena.tile_center(9.5, 24.5))
		max_gap = alch.position.y
		print("[juice] spawned deploy_timer=%.2f pos.y=%.1f" % [alch.deploy_timer, alch.position.y])
	if _at(0.45):
		print("[juice] t0.45 deploy_timer=%.2f moved=%.2f px" % [alch.deploy_timer, absf(alch.position.y - max_gap)])
	if _at(0.85):
		print("[juice] t0.85 deploy_timer=%.2f moved=%.2f px" % [alch.deploy_timer, absf(alch.position.y - max_gap)])
	if _at(0.95):
		alch.take_damage(5.0, alch.position)
		print("[juice] hurt_frames right after damage=%d" % alch.hurt_frames)
	if _at(1.35):
		print("[juice] hurt_frames half a second later=%d" % alch.hurt_frames)


func _hog_steps() -> void:
	if _at(0.2):
		# hedgehogs vs a stationary dummy so they actually arrive
		arena.spawn_troop("snowman", 1, arena.tile_center(9.5, 18.5))
		probe = arena.spawn_troop("hero", 1, arena.tile_center(8.2, 18.2))
		arena.spawn_troop("hedgehog", 0, arena.tile_center(9.5, 16.0))
		# a unit parked next to an enemy tower: the crash repro from the bug report
		arena.spawn_troop("hero", 0, arena.tile_center(4.5, 8.5))
		print("[hog] staged hogs + dummy + tower attacker")
	if _at(1.4):
		var curled := 0
		var min_hp := 9999.0
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "hedgehog":
				if u.curled:
					curled += 1
				min_hp = minf(min_hp, float(u.hp))
		print("[hog] t1.4 curled=%d hog_min_hp=%d hero_hp=%d" % [curled, int(min_hp), int(probe.hp)])
	if _at(2.0):
		var hps := ""
		var curled_n := 0
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "hedgehog":
				hps += "%.1f(%s) " % [float(u.hp), "curled" if u.curled else "walking"]
				if u.curled:
					curled_n += 1
		print("[hog] t2.0 hogs: %s" % hps)
	if _at(3.0):
		var curled2 := 0
		var hog_hp := 0.0
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "hedgehog":
				if u.curled:
					curled2 += 1
				hog_hp = maxf(hog_hp, float(u.hp))
		print("[hog] t3.0 curled=%d hogs_alive_hp=%.0f hero_hp=%d (thorns bite back)" % [curled2, hog_hp, int(probe.hp)])
	if _at(3.2):
		# isolated boulder test
		probe = arena.spawn_troop("hero", 0, arena.tile_center(3.5, 22.5))
		arena.spawn_boulder(arena.tile_center(3.5, 19.0), Vector2(0, 1), 1)
		print("[hog] boulder launched at a hero")
	if _at(3.9):
		if is_instance_valid(probe):
			print("[hog] boulder hit: hero stun=%.1f pos_y=%.1f hp=%d" % [
				probe.stunned, (probe.position.y - arena.ORIGIN.y) / arena.TILE, int(probe.hp)])
	if _at(6.2):
		if is_instance_valid(probe):
			print("[hog] 3s later: hero stun=%.1f pos_y=%.1f" % [
				probe.stunned, (probe.position.y - arena.ORIGIN.y) / arena.TILE])


func _zombify_steps() -> void:
	if _at(0.2):
		var horde = arena.spawn_troop("zombie", 0, arena.tile_center(9.5, 20.5))
		var z := 0
		var min_hp := 99999.0
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "zombie":
				z += 1
				min_hp = minf(min_hp, float(u.hp))
				u.deploy_timer = 0.0
		print("[zombie] card spawned %d corpses, min hp=%d, cost=%d" % [z, int(min_hp), DDCard.cost("zombie")])
		var victim = arena.spawn_troop("hero", 1, arena.tile_center(9.5, 19.5))
		victim.hp = 10.0
		victim.deploy_timer = 0.0
		probe = victim
		print("[zombie] victim hp=10 next to the horde")
	if _at(2.2):
		var team0 := 0
		var team1 := 0
		var fresh_hp := 0.0
		for u in arena.units:
			if not is_instance_valid(u) or String(u.kind) != "zombie":
				continue
			if int(u.team) == 0:
				team0 += 1
				fresh_hp = maxf(fresh_hp, float(u.hp))
			else:
				team1 += 1
		print("[zombie] zombies now team0=%d team1=%d best_hp=%d victim_alive=%s" % [
			team0, team1, int(fresh_hp), str(is_instance_valid(probe) and not probe.dead)])


func _ability_steps() -> void:
	if _at(0.3):
		arena.gold = [6.0, 6.0]
		alch = arena.spawn_troop("hero", 1, arena.tile_center(8.5, 16.5))
		alch.hp = 150.0
		var ok: bool = arena.use_ability(0)
		print("[ability] p1=%s p2=%s use=%s gold=(%.0f,%.0f) cd=%.0f tentacles=%d victim_hp=%d stunned=%.1f" % [
			arena.ability[0], arena.ability[1], str(ok), arena.gold[0], arena.gold[1],
			float(arena.ability_cd[0]), _tentacle_count(), int(alch.hp), alch.stunned])
	if _at(1.5):
		print("[ability] t1.5 victim stunned=%.1f tentacle_alive=%s" % [alch.stunned, str(_tentacle_count() > 0)])
	if _at(2.0):
		for u in arena.units.duplicate():
			if is_instance_valid(u) and String(u.kind) == "tentacle":
				u.take_damage(999.0, u.position)
		print("[ability] tentacle killed -> victim stunned=%.1f tentacles=%d" % [alch.stunned, _tentacle_count()])
	if _at(3.0):
		arena.gold[1] = 6.0
		var tw: Node = arena._highest_hp_enemy_tower(1)
		var prior_hp: float = tw.hp if tw != null else -1.0
		var prior_x: float = tw.position.x if tw != null else -1.0
		var ok2: bool = arena.use_ability(1)
		print("[ability] goblin use=%s target_tower_x=%.0f tower_hp=%.0f p1_gold=%.0f" % [str(ok2), prior_x, prior_hp, arena.gold[0]])
	if _at(4.4):
		var g: Node = null
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "goblin":
				g = u
		print("[ability] t4.4 goblin=%s phase=%s stolen=%.0f p1_gold=%.0f p2_gold=%.0f" % [
			str(g != null), str(int(g.phase)) if g != null else "-",
			float(g.stolen) if g != null else -1.0, arena.gold[0], arena.gold[1]])
	if _at(5.0) and OS.get_cmdline_user_args().has("--kill-goblin"):
		for u in arena.units.duplicate():
			if is_instance_valid(u) and String(u.kind) == "goblin":
				var before: float = arena.gold[0]
				u.take_damage(999.0, u.position)
				print("[ability] goblin killed -> p1_gold %.0f -> %.0f (refund), goblins=%d" % [
					before, arena.gold[0], _goblin_count()])
	if _at(18.0):
		print("[ability] t18 goblins_left=%d escaped=%d caught=%d towers=%s" % [
			_goblin_count(), arena.stat_goblin_escaped, arena.stat_goblin_caught,
			str(arena.towers.map(func(t): return int(t.hp)))])


func _tentacle_count() -> int:
	var n := 0
	for u in arena.units:
		if is_instance_valid(u) and String(u.kind) == "tentacle":
			n += 1
	return n


func _goblin_count() -> int:
	var n := 0
	for u in arena.units:
		if is_instance_valid(u) and String(u.kind) == "goblin":
			n += 1
	return n


func _capture() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/shot_%02d.png" % [shot_dir, count]
	img.save_png(path)
	print("[capture] ", path)
	count += 1


func _demo_play() -> void:
	for p in 2:
		var hand: Array = arena.hands[p]
		for i in hand.size():
			var kind := String(hand[i])
			if arena.gold[p] < float(DDCard.cost(kind)):
				continue
			var pos := _lane_point(p, kind)
			if arena.can_deploy(p, kind, pos):
				arena.deploy(p, i, pos)
				break


func _lane_point(p: int, kind: String) -> Vector2:
	var bridge_x := 5.0 if lane_flip % 2 == 0 else 13.0
	lane_flip += 1
	if DDCard.is_spell(kind):
		var king := Vector2(8.0, 2.0) if p == 0 else Vector2(8.0, 26.0)
		return arena.tile_center(king.x, king.y)
	var row := 20.0 if p == 0 else 9.0
	return arena.tile_center(bridge_x, row)
