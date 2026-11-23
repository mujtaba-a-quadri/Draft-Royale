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
# --- pennygif: transparent-background frames of Penny vs a passive knight -----
const GIF_W := 480
const GIF_H := 360
const GIF_FPS := 20.0
const GIF_FRAMES := 72
var gif_a := "penny"
var gif_b := "hero"
var gif_started := false
var gif_done := false
var gif_taken := 0
var gif_t := 0.0
var gif_dir := ""
var gif_view: SubViewport = null
var gif_penny: Node = null
var gif_knight: Node = null
var gif_cam: Camera2D = null
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
		elif a.begins_with("--gif-a="):
			gif_a = a.substr(8)
		elif a.begins_with("--gif-b="):
			gif_b = a.substr(8)
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
	elif scenario == "snowblast":
		shot_times = []
		run_time = 6.0
	elif scenario == "shiesty":
		shot_times = []
		run_time = 6.0
	elif scenario == "boulder2":
		shot_times = []
		run_time = 4.0
	elif scenario == "fuair":
		shot_times = []
		run_time = 4.0
	elif scenario == "boomerang3":
		shot_times = []
		run_time = 7.0
	elif scenario == "burn":
		shot_times = []
		run_time = 9.5
	elif scenario == "chicken":
		shot_times = []
		run_time = 6.0
	elif scenario == "commanders":
		shot_times = []
		run_time = 47.0
	elif scenario == "scaling":
		shot_times = []
		run_time = 9.0
	elif scenario == "relics":
		# with --shots: the relic column mid-window (2 columns: 8 relics)
		shot_times = [4.6, 12.0]
		run_time = 30.0
	elif scenario == "pearl":
		# with --shots: floating down, in the purse, floating back up
		shot_times = [1.3, 1.9, 2.3]
		run_time = 5.0
	elif scenario == "lizard":
		shot_times = []
		run_time = 7.5
	elif scenario == "cross":
		shot_times = []
		run_time = 14.0
	elif scenario == "bld":
		shot_times = []
		run_time = 5.0
	elif scenario == "firebolt":
		shot_times = []
		run_time = 3.0
	elif scenario == "laniakea":
		shot_times = [7.1]
		run_time = 9.2
	elif scenario == "femme":
		shot_times = []
		run_time = 9.5
	elif scenario == "toss":
		shot_times = [0.95, 1.2, 1.45]
		run_time = 3.0
	elif scenario == "shiestylane":
		shot_times = []
		run_time = 7.5
	elif scenario == "whelp":
		shot_times = [1.2, 6.6]
		run_time = 8.6
	elif scenario == "coins":
		shot_times = [1.08]
		run_time = 1.4
	elif scenario == "towerpick":
		shot_times = [1.4]
		run_time = 6.2
	elif scenario == "wu":
		shot_times = [0.6, 2.0, 2.12, 3.42, 8.0]
		run_time = 10.5
	elif scenario == "wuart":
		shot_times = [0.8]
		run_time = 1.0
	elif scenario == "neko":
		shot_times = [1.6, 4.6, 5.45]
		run_time = 10.0
	elif scenario == "nekoart":
		shot_times = [0.8]
		run_time = 1.0
	elif scenario == "gil":
		shot_times = [1.12, 7.0]
		run_time = 9.0
	elif scenario == "gilart":
		shot_times = [0.8]
		run_time = 1.0
	elif scenario == "frog":
		shot_times = []
		run_time = 5.0
	elif scenario == "dupes":
		shot_times = [1.0, 2.2]
		run_time = 3.0
	elif scenario == "run":
		# each fight is its own scene, so the shot is retaken (and overwritten) per fight
		shot_times = [2.1]
		run_time = 2.6
	elif scenario == "frogart":
		shot_times = [0.8]
		run_time = 1.0
	elif scenario == "phalanx":
		shot_times = [7.2]
		run_time = 11.0
	elif scenario == "wolves":
		shot_times = [3.0]
		run_time = 13.0
	elif scenario == "anthill":
		shot_times = [6.0]
		run_time = 6.2
	elif scenario == "packart":
		shot_times = [0.8]
		run_time = 1.0
	elif scenario == "spidercycle":
		shot_times = [6.0, 12.0, 14.2, 16.1]
		run_time = 20.0
	elif scenario == "eggs":
		shot_times = []
		run_time = 33.0
	elif scenario == "boltlock":
		shot_times = []
		run_time = 9.0
	elif scenario == "goat":
		shot_times = []
		run_time = 12.0
	elif scenario == "pocket":
		shot_times = [1.0]
		run_time = 1.4
	elif scenario == "antaggro":
		shot_times = [2.0]
		run_time = 13.0
	elif scenario == "hovervol":
		shot_times = [1.65, 2.05]
		run_time = 3.0
	elif scenario == "cardcycle":
		shot_times = [1.2]
		run_time = 2.5
	elif scenario == "mantis":
		shot_times = [2.0, 2.78, 3.6]
		run_time = 7.2
	elif scenario == "tweaks":
		shot_times = []
		run_time = 13.5
	elif scenario == "elf":
		shot_times = [2.6]
		run_time = 4.3
	elif scenario == "drawfx":
		shot_times = [1.9, 2.2, 2.6, 3.45]
		run_time = 3.6
	elif scenario == "elitetime":
		shot_times = []
		run_time = 1.2
	elif scenario == "nopres":
		shot_times = []
		run_time = 2.0
	elif scenario == "ballista":
		shot_times = [3.0, 24.0]
		run_time = 31.0
	elif scenario == "phases" or scenario == "phaselead" or scenario == "phaseelite":
		shot_times = [0.45, 1.4]
		run_time = 2.3
	elif scenario == "lockbridge":
		shot_times = [1.6, 4.5]
		run_time = 4.8
	elif scenario == "shiestyweb":
		shot_times = []
		run_time = 1.0
	elif scenario == "snowroll":
		shot_times = []
		run_time = 4.7
	elif scenario == "pennyair":
		shot_times = []
		run_time = 7.2
	elif scenario == "towerstar":
		shot_times = [1.2]
		run_time = 1.3
	elif scenario == "boot":
		shot_times = [1.95, 2.15, 2.4, 2.75]
		run_time = 2.8
	elif scenario == "bridges3":
		shot_times = [5.5]
		run_time = 9.0
	elif scenario == "rewardui":
		# needs --run=7: the first fight is won at 0.6 and the reward screen is up
		# from 0.9; its cards are in by about 2.0
		shot_times = [3.3, 3.9]
		run_time = 4.2
	elif scenario == "goatart":
		shot_times = [0.8]
		run_time = 1.0
	elif scenario == "valkyrie":
		shot_times = [2.6]
		run_time = 10.0
	elif scenario == "valkart":
		shot_times = [0.8]
		run_time = 1.0
	elif scenario == "whelpart":
		shot_times = [0.8]
		run_time = 1.0
	elif scenario == "ovo":
		shot_times = []
		run_time = 64.0
	elif scenario == "deal":
		shot_times = [0.12, 0.7, 2.6]
		run_time = 3.2
	elif scenario == "spider":
		shot_times = [8.4, 12.3, 13.0]
		run_time = 16.5
	elif scenario == "kraken":
		shot_times = [2.9, 4.8, 11.6, 12.75]
		run_time = 18.0
	elif scenario == "pennygif" or scenario == "pairgif":
		shot_times = []
		run_time = 6.0
	else:
		shot_times = [2.0, 5.0, 8.0, 11.0]
		run_time = 13.5


## Penny, alone on a transparency-rendered stage with a knight that never swings
## back. Frames are dumped as raw RGBA (what the GIF encoder eats) plus PNG.
func _pennygif_steps() -> void:
	if not gif_started:
		_gif_setup()
		return
	if gif_done:
		return
	if gif_taken >= GIF_FRAMES:
		if not gif_done:
			gif_done = true
			var meta := FileAccess.open(gif_dir + "/meta.txt", FileAccess.WRITE)
			if meta != null:
				meta.store_line("%d %d %d %d" % [GIF_W, GIF_H, int(GIF_FPS), gif_taken])
				meta.close()
			print("PENNYGIF done frames=", gif_taken, " dir=", ProjectSettings.globalize_path(gif_dir))
		return
	gif_t += get_process_delta_time()
	if gif_t < 1.0 / GIF_FPS:
		return
	gif_t = 0.0
	# keep both dancers in frame while she spins and leaps around him
	if gif_cam != null and gif_penny != null and is_instance_valid(gif_penny) and gif_knight != null and is_instance_valid(gif_knight):
		gif_cam.position = (gif_penny.position + gif_knight.position) * 0.5
		# no health bar in the shot: the knight is a partner, not a target
		gif_knight.hp = gif_knight.max_hp
	var img: Image = gif_view.get_texture().get_image()
	if img == null:
		return
	img.convert(Image.FORMAT_RGBA8)
	var bytes := img.get_data()
	var fh := FileAccess.open(gif_dir + "/frame_%04d.bin" % gif_taken, FileAccess.WRITE)
	if fh == null:
		return
	fh.store_buffer(bytes)
	fh.close()
	img.save_png(gif_dir + "/frame_%04d.png" % gif_taken)
	gif_taken += 1


func _gif_setup() -> void:
	gif_started = true
	# inside the project (hidden from the importer) so the frame dump is writable
	gif_dir = "res://.godot/penny_frames"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(gif_dir))
	for u in arena.units.duplicate():
		if is_instance_valid(u):
			u.take_damage(999999.0, u.position)
	arena.bot_players = [false, false]
	gif_view = SubViewport.new()
	gif_view.size = Vector2i(GIF_W, GIF_H)
	gif_view.transparent_bg = true
	gif_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(gif_view)
	var cam := Camera2D.new()
	cam.zoom = Vector2(2.4, 2.4)
	gif_view.add_child(cam)
	gif_penny = arena.spawn_troop(gif_a, 0, Vector2(760.0, 506.0), true)
	gif_knight = arena.spawn_troop(gif_b, 1, Vector2(760.0, 466.0), true)
	if gif_penny != null and gif_penny.get("deploy_timer") != null:
		gif_penny.deploy_timer = 0.0
		gif_penny.hp = 99999.0
		gif_penny.max_hp = 99999.0
	if gif_knight != null:
		# a passive partner: never swings, never dies, never moves
		if gif_knight.get("deploy_timer") != null:
			gif_knight.deploy_timer = 0.0
		if gif_knight.get("hp") != null:
			gif_knight.hp = 999999.0
			gif_knight.max_hp = 999999.0
		if gif_knight.get("speed") != null:
			gif_knight.speed = 0.0
		if gif_knight.get("dmg") != null:
			gif_knight.dmg = 0.0
	for n in [gif_penny, gif_knight]:
		if n == null or not is_instance_valid(n):
			continue
		arena.remove_child(n)
		gif_view.add_child(n)
		n.queue_redraw()
	cam.position = Vector2(760.0, 486.0)
	cam.make_current()
	gif_cam = cam
	print("PENNYGIF setup at ", ProjectSettings.globalize_path(gif_dir))


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
	elif scenario == "snowblast":
		_snowblast_steps()
	elif scenario == "shiesty":
		_shiesty_steps()
	elif scenario == "boulder2":
		_boulder2_steps()
	elif scenario == "fuair":
		_fuair_steps()
	elif scenario == "boomerang3":
		_boomerang3_steps()
	elif scenario == "burn":
		_burn_steps()
	elif scenario == "chicken":
		_chicken_steps()
	elif scenario == "commanders":
		_commander_steps()
	elif scenario == "scaling":
		_scaling_steps()
	elif scenario == "relics":
		_relic_steps()
	elif scenario == "pearl":
		_pearl_steps()
	elif scenario == "lizard":
		_lizard_steps()
	elif scenario == "cross":
		_cross_steps()
	elif scenario == "bld":
		_bld_steps()
	elif scenario == "firebolt":
		_firebolt_steps()
	elif scenario == "laniakea":
		_laniakea_steps()
	elif scenario == "femme":
		_femme_steps()
	elif scenario == "toss":
		_toss_steps()
	elif scenario == "shiestylane":
		_shiesty_lane_steps()
	elif scenario == "whelp":
		_whelp_steps()
	elif scenario == "towerpick":
		_towerpick_steps()
	elif scenario == "wu":
		_wu_steps()
	elif scenario == "neko":
		_neko_steps()
	elif scenario == "gil":
		_gil_steps()
	elif scenario == "frog":
		_frog_steps()
	elif scenario == "phalanx":
		_phalanx_steps()
	elif scenario == "wolves":
		_wolves_steps()
	elif scenario == "anthill":
		_anthill_steps()
	elif scenario == "packart":
		_packart_steps()
	elif scenario == "spidercycle":
		_spidercycle_steps()
	elif scenario == "eggs":
		_eggs_steps()
	elif scenario == "boltlock":
		_boltlock_steps()
	elif scenario == "goat":
		_goat_steps()
	elif scenario == "pocket":
		_pocket_steps()
	elif scenario == "antaggro":
		_antaggro_steps()
	elif scenario == "hovervol":
		_hovervol_steps()
	elif scenario == "cardcycle":
		_cardcycle_steps()
	elif scenario == "mantis":
		_mantis_steps()
	elif scenario == "tweaks":
		_tweaks_steps()
	elif scenario == "elf":
		_elf_steps()
	elif scenario == "drawfx":
		_drawfx_steps()
	elif scenario == "elitetime":
		_elitetime_steps()
	elif scenario == "nopres":
		_nopres_steps()
	elif scenario == "ballista":
		_ballista_steps()
	elif scenario == "phases" or scenario == "phaselead" or scenario == "phaseelite":
		_phases_steps()
	elif scenario == "lockbridge":
		_lockbridge_steps()
	elif scenario == "shiestyweb":
		_shiestyweb_steps()
	elif scenario == "snowroll":
		_snowroll_steps()
	elif scenario == "pennyair":
		_pennyair_steps()
	elif scenario == "towerstar":
		_towerstar_steps()
	elif scenario == "boot":
		_boot_steps()
	elif scenario == "bridges3":
		_bridges3_steps()
	elif scenario == "rewardui":
		_rewardui_steps()
	elif scenario == "goatart":
		_goatart_steps()
	elif scenario == "valkyrie":
		_valkyrie_steps()
	elif scenario == "valkart":
		_valkart_steps()
	elif scenario == "shiestyfx":
		_shiesty_fx_steps()
	elif scenario == "dupes":
		_dupes_steps()
	elif scenario == "run":
		_run_steps()
	elif scenario == "timeout":
		# the clock running out: more towers lost loses; level on towers -> tower
		# HP; level on both -> draw. Each case re-runs the finish on a reset board.
		if _at(0.4):
			var cases := [
				["P1 lost none at 100 HP each, P2 lost one but 500 HP left", [100.0, 100.0, 100.0], [0.0, 250.0, 250.0], 0],
				["one down each, P2 has more HP left", [0.0, 100.0, 100.0], [0.0, 250.0, 250.0], 1],
				["one down each, level HP", [0.0, 120.0, 120.0], [0.0, 120.0, 120.0], -1],
			]
			for c in cases:
				var mine: Array = []
				var theirs: Array = []
				for tw in arena.towers:
					(mine if int(tw.team) == 0 else theirs).append(tw)
				for k in 3:
					for side in [[mine, c[1]], [theirs, c[2]]]:
						var tw: Node = (side[0] as Array)[k]
						tw.hp = float((side[1] as Array)[k])
						tw.dead = tw.hp <= 0.0
				arena.match_over = false
				arena._finish_on_towers()
				print("[timeout] %s -> winner %d (expect %d) | %s" % [c[0], arena.winner, c[3], arena.banner_text])
	elif scenario == "frogart":
		# 5x close-up: sitting, mid-hop, mid-leap
		if _at(0.3):
			for i in 3:
				var u = arena.spawn_troop("frog", 0, arena.tile_center(9.5, 21.5), true)
				u.deploy_timer = 0.0
				u.set_physics_process(false)
				u.position = arena.tile_center(9.5, 14.5 + 5.0 * float(i))
				u.scale = Vector2(5.0, 5.0)
				u.z_index = 30
				u.facing = 1.0
				if i == 1:
					u.frog_hop_t = float(u.frog_cfg["hop_time"]) * 0.5
				if i == 2:
					u.frog_leaping = true
					u.frog_leap_t = float(u.frog_cfg["leap_time"]) * 0.4
				u.queue_redraw()
	elif scenario == "deployclamp":
		# aiming a troop deep in enemy ground: the preview and the click both go to
		# the closest tile it may land on; aiming at an open tile is left alone
		if _at(0.3):
			arena.hands[0][0] = "slate"
			arena.gold[0] = 20.0
			arena.selected_player = 0
			arena.selected_index = 0
			var far: Vector2 = arena.tile_center(9.5, 5.5)
			var open: Vector2 = arena.deploy_point(0, "slate", far)
			print("[clamp] aimed at tile %s can_deploy=%s -> lands on tile %s (can_deploy=%s) aim_point tile %s" % [
				str(arena.tile_of(far)), str(arena.can_deploy(0, "slate", far)), str(arena.tile_of(open)),
				str(arena.can_deploy(0, "slate", open)), str(arena.tile_of(arena.aim_point(far)))])
			var own: Vector2 = arena.tile_center(9.5, 24.5)
			print("[clamp] own-side tile %s stays %s" % [str(arena.tile_of(own)), str(arena.tile_of(arena.deploy_point(0, "slate", own)))])
			arena.try_deploy_at(far)
			for u in arena.units:
				if is_instance_valid(u) and String(u.kind) == "slate" and int(u.team) == 0:
					print("[clamp] slate placed on tile %s gold left %.1f" % [str(arena.tile_of(u.position)), arena.gold[0]])
	elif scenario == "gilart":
		# 4x close-up: Gilgamesh at rest and mid-lash, Enkidu with spear and sword
		if _at(0.3):
			for i in 4:
				var k := "gilgamesh" if i < 2 else "enkidu"
				var u = arena.spawn_troop(k, 0, arena.tile_center(9.5, 21.5), true)
				u.deploy_timer = 0.0
				u.set_physics_process(false)
				u.position = arena.tile_center(9.5, 13.5 + 4.5 * float(i))
				u.scale = Vector2(4.0, 4.0)
				u.z_index = 30
				u.facing = 1.0
				if i == 1:
					u.whip_t = u.WHIP_SHOW * 0.6
					u.whip_to = u.position + Vector2(2.5 * float(arena.TILE), 0.0)
				if i == 3:
					u.spear_away = 2.0
				u.queue_redraw()
	elif scenario == "nekoart":
		# 4x close-up: idle, mid-gust, casting; a rat skeleton at 5x
		if _at(0.3):
			for i in 4:
				var k := "ratbones" if i == 3 else "neko"
				var u = arena.spawn_troop(k, 0, arena.tile_center(9.5, 21.5), true)
				u.deploy_timer = 0.0
				u.set_physics_process(false)
				u.position = arena.tile_center(9.5, 13.5 + 4.5 * float(i))
				u.scale = Vector2(5.0, 5.0) if i == 3 else Vector2(4.0, 4.0)
				u.z_index = 30
				u.facing = 1.0
				if i == 1:
					u.cloak_t = u.CLOAK_WIND * 0.5
				if i == 2:
					u.beam_t = u.BEAM_SHOW * 0.9
				u.queue_redraw()
	elif scenario == "wuart":
		# 4x close-up: knuckle-walking, staff half out, staff out, raging
		if _at(0.3):
			var outs := [0.0, 0.5, 1.0, 1.0]
			for i in 4:
				var u = arena.spawn_troop("wu", 0, arena.tile_center(9.5, 21.5), true)
				u.deploy_timer = 0.0
				u.set_physics_process(false)
				u.position = arena.tile_center(9.5, 13.0 + 4.5 * float(i))
				u.scale = Vector2(4.0, 4.0)
				u.z_index = 30
				u.facing = 1.0
				u.staff_out = outs[i]
				u.state = u.S.APPROACH if i == 0 else u.S.ATTACK
				if i == 3:
					u.rage_t = 3.0
					u.rage_hits = 9
					u.hp = 30.0
				u.queue_redraw()
	elif scenario == "whelpart":
		# close-up of the curled and open Obsidian Whelp, 5x
		if _at(0.3):
			for i in 2:
				var u = arena.spawn_troop("obsidian", 0, arena.tile_center(9.5, 21.5), true)
				u.deploy_timer = 0.0
				u.speed = 0.0
				u.position = arena.tile_center(9.0, 20.5 + 6.0 * float(i))
				u.scale = Vector2(5.0, 5.0)
				u.z_index = 30
				if i == 0:
					u.guard_calm = 99.0
					u.curled = true
	elif scenario == "coins":
		if _at(0.2):
			arena.gold[0] = 4.97
			arena.gold[1] = 10.0
		if _at(0.5):
			print("[coins] t0.5 blue coin 4 twinkle started=%.2f (expect ~0.2-0.3) red full, next rattle at %.2f" % [
				float(arena.coin_twinkle[0][4]), float(arena.full_twinkle_at[1])])
	elif scenario == "ovo":
		_ovo_steps()
	elif scenario == "deal":
		_deal_steps()
	elif scenario == "spider":
		_spider_steps()
	elif scenario == "kraken":
		_kraken_steps()
	elif scenario == "pennygif" or scenario == "pairgif":
		_pennygif_steps()
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


## Regression: a two-use card must fire once per click. The press that starts a
## gesture belongs to the hand panel, which drops the card on release; casting on
## the press as well spends both charges for a single click.
func _firebolt_steps() -> void:
	if _at(0.8):
		arena.bot_players = [false, false]
		arena.hands[0] = ["firebolt", "hero", "warren"]
		arena.charges = [{}, {}]
		arena.gold[0] = 20.0
		arena.panels[0].select_index(0)
		print("[firebolt] armed lifted=%s charges=%d" % [
			str(arena.panels[0].drag_card != null), arena.charges_of(0, "firebolt")])
	if _at(1.0):
		# pin the drag: with no real cursor the panel lets go of it between frames
		arena.panels[0].select_index(0)
		arena.panels[0]._begin_drag(0)
		print("[firebolt] state before press: lifted=%s sel=%d/%d" % [
			str(arena.panels[0].drag_card != null), arena.selected_player, arena.selected_index])
		# the Firebolt only casts locked on: an enemy to cast it on
		probe = _lani_dummy("hero", arena.tile_center(4.0, 20.0))
		probe.max_hp = 5000.0
		probe.hp = 5000.0
		var point: Vector2 = probe.position
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = point
		arena._unhandled_input(press)
		print("[firebolt] casts after press=%d (expect 0)" % _bolts())
		arena.try_deploy_at(point)
		print("[firebolt] casts after click 1=%d (expect 1) charges=%d in_hand=%s" % [
			_bolts(), arena.charges_of(0, "firebolt"), str(arena.hands[0].has("firebolt"))])
	if _at(1.6):
		arena.try_deploy_at(probe.position)
		# the counter sees bolts still in flight, not a total: the charge bookkeeping
		# is the proof here â€” 1 charge left after click 1, none after click 2
		print("[firebolt] after click 2: bolts_in_flight=%d in_hand=%s lifted=%s" % [
			_bolts(), str(arena.hands[0].has("firebolt")), str(arena.panels[0].drag_card != null)])


## Live projectiles of the firebolt kind: one per cast.
func _bolts() -> int:
	var n := 0
	for c in arena.get_children():
		if not is_instance_valid(c):
			continue
		var k = c.get("kind")
		if k != null and String(k) == "firebolt":
			n += 1
	return n


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
	if _at(0.3):
		print("[control] no units â€” p1 rows 18/17/16/13: %s %s %s %s" % [
			str(arena.can_deploy(0, "slate", arena.tile_center(9.5, 18.5))),
			str(arena.can_deploy(0, "slate", arena.tile_center(9.5, 17.5))),
			str(arena.can_deploy(0, "slate", arena.tile_center(9.5, 16.5))),
			str(arena.can_deploy(0, "slate", arena.tile_center(9.5, 13.5)))])
		print("[control] no units â€” p2 rows 11/12/13/18: %s %s %s %s" % [
			str(arena.can_deploy(1, "slate", arena.tile_center(9.5, 11.5))),
			str(arena.can_deploy(1, "slate", arena.tile_center(9.5, 12.5))),
			str(arena.can_deploy(1, "slate", arena.tile_center(9.5, 13.5))),
			str(arena.can_deploy(1, "slate", arena.tile_center(9.5, 18.5)))])
	if _at(0.6):
		alch = arena.spawn_troop("slate", 0, arena.tile_center(9.5, 16.5))
		if is_instance_valid(alch):
			alch.deploy_timer = 0.0
	if _at(0.9):
		print("[control] p1 unit at row 16 â†’ p1 row16 col9=%s col2=%s row13=%s | p2 row16 col9=%s" % [
			str(arena.can_deploy(0, "slate", arena.tile_center(9.5, 16.5))),
			str(arena.can_deploy(0, "slate", arena.tile_center(2.5, 16.5))),
			str(arena.can_deploy(0, "slate", arena.tile_center(9.5, 13.5))),
			str(arena.can_deploy(1, "slate", arena.tile_center(9.5, 16.5)))])
	if _at(1.2):
		var h = arena.spawn_troop("hero", 1, arena.tile_center(9.5, 20.5))
		if is_instance_valid(h):
			h.deploy_timer = 0.0
	if _at(1.5):
		print("[control] p2 unit at row 20 â†’ p2 row18 col9=%s col2=%s" % [
			str(arena.can_deploy(1, "slate", arena.tile_center(9.5, 18.5))),
			str(arena.can_deploy(1, "slate", arena.tile_center(2.5, 18.5)))])
	if _at(1.9):
		var t := Vector2i(9, 18)
		print("[control] shared tile row18 col9: p1=%s p2=%s | counts=%s" % [
			str(arena.controlled(0, t)), str(arena.controlled(1, t)), str(arena.control_counts())])
	if _at(2.6):
		arena.set_view_mode(1)
		print("[control] dual view for the screenshot")


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
	if _at(4.0):
		print("[roll] t4.0 level=%d before a 0.5 s stun" % alch.roll_level)
		alch.stunned = 0.5
	if _at(4.6):
		print("[roll] t4.6 after the stun: level=%d speed=%.2f timer=%.2f (expect 0 / base / ~0)" % [
			alch.roll_level, alch.speed, alch.roll_timer])
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


func _bld_steps() -> void:
	if _at(0.3):
		arena.spawn_troop("snowman", 0, arena.tile_center(9.5, 20.5))
		arena.spawn_troop("warren", 0, arena.tile_center(6.5, 20.5))
		print("[bld] deploy on snowman tile=%s | on warren tile=%s" % [
			str(arena.can_deploy(0, "hero", arena.tile_center(9.5, 20.5))),
			str(arena.can_deploy(0, "hero", arena.tile_center(6.5, 20.5)))])
	if _at(0.9):
		var h = arena.spawn_troop("hero", 0, arena.tile_center(6.5, 20.5))
		var t2: Vector2i = arena.tile_of(h.position)
		print("[bld] hero dropped on the warren landed at tile=(%d,%d), warren anchor=(6,20)" % [t2.x, t2.y])
	if _at(1.3):
		alch = arena.spawn_troop("snowman", 1, arena.tile_center(9.5, 17.5))
		var snow: Node = arena.building_at(Vector2i(9, 20))
		if snow != null:
			snow.apply_impulse(Vector2(1, 0), 2.0, 0.3)
			probe = snow
			print("[bld] shoved the snowman 2 tiles")
	if _at(1.9):
		print("[bld] snowman moved %.2f tiles (buildings do not budge)" % (
			probe.position.distance_to(arena.tile_center(9.5, 20.5)) / arena.TILE))
	if _at(2.1):
		arena.spawn_troop("hero", 0, arena.tile_center(3.5, 22.5))
		arena.spawn_troop("hero", 0, arena.tile_center(3.5, 22.5))
	if _at(2.8):
		var list: Array = []
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "hero" and u.team == 0:
				list.append(u.position)
		if list.size() >= 2:
			print("[bld] two heroes on one tile are now %.2f tiles apart" % (list[0].distance_to(list[1]) / arena.TILE))


func _cross_steps() -> void:
	if _at(0.2):
		alch = arena.spawn_troop("hero", 0, arena.tile_center(9.5, 21.5))
		alch.deploy_timer = 0.0
		print("[cross] hero spawned on its own bank, walking to the enemy king tower")
	if _at(3.0) or _at(6.0) or _at(9.0) or _at(12.0):
		var t2: Vector2i = arena.tile_of(alch.position)
		print("[cross] t%.0f tile=(%d,%d) hp=%d" % [elapsed, t2.x, t2.y, int(alch.hp)])
	# burn on a tower: 40 burn = 20 % per tick for a tower
	if _at(1.0):
		arena.towers[1].apply_burn(40.0, 6)
	if _at(2.4) or _at(3.4) or _at(4.4):
		print("[cross] tower hp=%d burn=%.1f tick=%d" % [int(arena.towers[1].hp), arena.towers[1].burn_stack, arena.towers[1].burn_ticks])
	# lizard rifle
	if _at(2.5):
		var lz = arena.spawn_troop("lizard", 0, arena.tile_center(3.5, 20.5), true)
		lz.deploy_timer = 0.0
		probe = arena.spawn_troop("snowman", 1, arena.tile_center(3.5, 17.5))
		probe.deploy_timer = 0.0
		print("[cross] lizard at 3.0 tiles from a snowman")
	if _at(4.5):
		print("[cross] snowman hp=%d (rifle should have landed)" % int(probe.hp))


func _lizard_steps() -> void:
	if _at(0.3):
		alch = arena.spawn_troop("snowman", 0, arena.tile_center(9.5, 18.5))
		alch.deploy_timer = 0.0
	if _at(0.7):
		print("[lizard] plain cone rows 18-21 widths: %s" % _cone_widths(0, 18, 4))
	if _at(1.1):
		alch.take_damage(99999.0, alch.position)
		probe = arena.spawn_troop("lizard", 0, arena.tile_center(9.5, 18.5), true)
		probe.speed = 0.0
		probe.deploy_timer = 0.0
	if _at(1.5):
		print("[lizard] soldier cone rows 17-20 widths: %s (shifted one forward)" % _cone_widths(0, 17, 4))
	if _at(2.0):
		for u in arena.units.duplicate():
			if is_instance_valid(u):
				u.take_damage(99999.0, u.position)
		var tank = arena.spawn_troop("slate", 1, arena.tile_center(9.5, 15.5))
		var weak = arena.spawn_troop("snowman", 1, arena.tile_center(9.5, 14.5))
		tank.deploy_timer = 0.0
		weak.deploy_timer = 0.0
		weak.take_damage(60.0, weak.position)
		probe = arena.spawn_troop("lizard", 0, arena.tile_center(9.5, 18.5), true)
		probe.deploy_timer = 0.0
		alch = tank
		print("[lizard] slate 200hp at 3.0 tiles, snowman 30hp at 4.0 tiles")
	if _at(2.8):
		var tg = probe.target
		print("[lizard] soldier targets %s (nearest is the slate, weakest is the snowman)" % [
			String(tg.kind) if tg != null and is_instance_valid(tg) else "none"])
	if _at(3.4):
		for u in arena.units.duplicate():
			if is_instance_valid(u):
				u.take_damage(99999.0, u.position)
		var w = arena.spawn_troop("warren", 0, arena.tile_center(9.5, 18.5))
		w.deploy_timer = 0.0
		var h = arena.spawn_troop("hero", 1, arena.tile_center(9.5, 14.0))
		h.deploy_timer = 0.0
		print("[lizard] warren placed, enemy 4.5 tiles away (range 6)")
	if _at(5.2):
		var n := 0
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "lizard":
				n += 1
		print("[lizard] warren has summoned %d lizards" % n)


func _cone_widths(team: int, from_row: int, rows: int) -> String:
	var out := ""
	for row in range(from_row, from_row + rows):
		var n := 0
		for col in range(0, arena.GRID_W):
			if arena.controlled(team, Vector2i(col, row)):
				n += 1
		out += "r%d=%d " % [row, n]
	return out


func _chicken_steps() -> void:
	if _at(0.3):
		probe = arena.spawn_troop("chicken", 0, arena.tile_center(3.5, 20.5))
		probe.deploy_timer = 0.0
		alch = arena.spawn_troop("hero", 1, arena.tile_center(3.5, 17.8))
		alch.deploy_timer = 0.0
		print("[chicken] chicken vs hero, 2.7 tiles apart (hero hp %d)" % int(alch.hp))
	if _at(1.6) or _at(2.0) or _at(2.4) or _at(2.8) or _at(4.2) or _at(5.6):
		var alive: bool = is_instance_valid(probe) and not bool(probe.get("dead"))
		print("[chicken] t%.1f hero_hp=%d hero_status=%d | chicken alive=%s flying=%s takeoff=%.2f" % [
			elapsed, int(alch.hp) if is_instance_valid(alch) else -1, int(alch.status) if is_instance_valid(alch) else -1,
			str(alive), str(probe.flying) if alive else "-", float(probe.takeoff_t) if alive else 0.0])


## Flammenmeister and Man-Mantis: warmth on a friend, the weak firebolt on a
## foe, and drones planted in hosts of different sizes, each bursting into its
## tier of parasite. Bodies are frozen dummies so the numbers are the
## abilities' alone.
var cm_friend: Node = null
var cm_foe: Node = null
var cm_hosts: Array = []
var cm_seen := {}
var cm_dead := {}
var cm_last: Array = []


## A body on `team` that neither walks nor hits back.
func _cm_body(kind: String, team: int, at: Vector2) -> Node:
	var u = arena.spawn_troop(kind, team, at, true)
	u.position = at
	u.deploy_timer = 0.0
	u.speed = 0.0
	u.dmg = 0.0
	return u


func _commander_steps() -> void:
	if _at(0.3):
		arena.ability = ["flame", "drone"]
		arena.gold = [10.0, 10.0]
		for b in arena.bots:
			if b != null and is_instance_valid(b):
				b.enabled = false
		print("[cmd] tiers: 5->%s 20->%s 21->%s 60->%s 61->%s 150->%s 151->%s" % [arena.parasite_for(5.0),
			arena.parasite_for(20.0), arena.parasite_for(21.0), arena.parasite_for(60.0), arena.parasite_for(61.0),
			arena.parasite_for(150.0), arena.parasite_for(151.0)])
		cm_friend = _cm_body("troll", 0, arena.tile_center(4.5, 20.5))
		cm_friend.hp = cm_friend.max_hp - 40.0
		cm_foe = _cm_body("militia", 1, arena.tile_center(12.5, 20.5))
		arena.ability_cd = [0.0, 0.0]
		var before := float(arena.gold[0])
		var ok1: bool = arena.use_ability_on(0, cm_friend)
		print("[cmd] warmth on friend: ok %s, gold %.0f -> %.0f, cd %.1f, regen %.1f/s for %.1f s" % [
			str(ok1), before, float(arena.gold[0]), float(arena.ability_cd[0]), cm_friend.regen_rate, cm_friend.regen_t])
		print("[cmd] Man-Mantis may not target his own side: %s; may target foe: %s" % [
			str(arena.ability_can_target(1, cm_foe)),
			str(arena.ability_can_target(1, cm_friend))])
	if _at(0.8) or _at(1.6) or _at(4.4):
		print("[cmd] t%.1f friend hp %.0f, regen left %.1f" % [elapsed, cm_friend.hp, cm_friend.regen_t])
	if _at(2.5):
		print("[cmd] t2.5 friend hp %.0f / %.0f (expect +%.0f over the warmth)" % [cm_friend.hp, cm_friend.max_hp,
			arena.FLAME_REGEN * arena.FLAME_REGEN_TIME])
		arena.ability_cd[0] = 0.0
		var ok2: bool = arena.use_ability_on(0, cm_foe)
		print("[cmd] firebolt on foe: ok %s, gold now %.0f" % [str(ok2), float(arena.gold[0])])
	if _at(4.5):
		if is_instance_valid(cm_foe) and not cm_foe.dead:
			print("[cmd] t4.5 foe hp %.0f / %.0f, status %d (burn = 2)" % [cm_foe.hp, cm_foe.max_hp, int(cm_foe.status)])
		else:
			print("[cmd] t4.5 foe is dead (burnt, and in range of our towers)")
		# drones in hosts of four sizes: each one bites until its host is gone
		var hp_list := [15.0, 45.0, 120.0, 200.0]
		for i in hp_list.size():
			var h: Node = _cm_body("troll", 0, arena.tile_center(2.5 + 4.0 * float(i), 26.5))
			h.hp = float(hp_list[i])
			cm_last.append(0.0)
			arena.ability_cd[1] = 0.0
			arena.gold[1] = 10.0
			var ok3: bool = arena.use_ability_on(1, h)
			cm_hosts.append(h)
			print("[cmd] drone into a %.0f hp host: ok %s" % [float(hp_list[i]), str(ok3)])
	# every parasite as it appears: logged once, then frozen and made harmless
	# so it cannot bite the other hosts
	for u in arena.units:
		if is_instance_valid(u) and String(u.kind).begins_with("parasite") and not cm_seen.has(u.get_instance_id()):
			cm_seen[u.get_instance_id()] = true
			u.speed = 0.0
			u.dmg = 0.0
			print("[cmd] t%.1f %s burst out for team %d (hp %.0f)" % [elapsed, String(u.kind), int(u.team), u.hp])
	for i in cm_hosts.size():
		var h = cm_hosts[i]
		if cm_dead.has(i):
			continue
		if not is_instance_valid(h) or h.dead:
			cm_dead[i] = true
			print("[cmd] t%.1f host %d died; its drone had done %.0f+" % [elapsed, i, float(cm_last[i])])
		else:
			cm_last[i] = float(h.drone_dealt)


## Puissance and Armor: a real Militia jab on a dummy with neither, with
## Puissance, with Armor on top; a burn tick that ignores both; the floor of 1;
## a hit on a tower.
var sc_mil: Node = null
var sc_dummy: Node = null
var sc_hp := 0.0


func _sc_jab(label: String) -> void:
	sc_hp = float(sc_dummy.hp)
	sc_mil.atk_cd = 0.0
	sc_mil.target = sc_dummy
	sc_mil._attack()
	print("[scale] %s: P %d / A %d -> took %.0f" % [label, int(arena.puissance[0]), int(arena.armor[1]),
		sc_hp - float(sc_dummy.hp)])


func _scaling_steps() -> void:
	if _at(0.3):
		for b in arena.bots:
			if b != null and is_instance_valid(b):
				b.enabled = false
		sc_mil = _cm_body("militia", 0, arena.tile_center(9.5, 20.5))
		sc_mil.dmg = float(DDCard.get_card("militia")["dmg"])
		sc_dummy = _cm_body("troll", 1, arena.tile_center(9.5, 20.0))
		sc_mil.state = DDUnit.S.ATTACK
		print("[scale] militia hit is %.0f" % sc_mil.dmg)
		_sc_jab("plain")
		arena.add_puissance(0, 3.0)
		_sc_jab("Puissance 3")
		arena.add_armor(1, 5.0)
		_sc_jab("Puissance 3, Armor 5")
		arena.add_armor(1, 20.0)
		_sc_jab("Armor 25 (floor)")
		arena.armor[1] = 0.0
		# a burn tick ignores both
		sc_hp = float(sc_dummy.hp)
		arena.tick_damage(sc_dummy, 6.0)
		print("[scale] burn tick of 6 with P 3: took %.0f (expect 6); dot flag left %s" % [sc_hp - float(sc_dummy.hp),
			str(arena.dot_hit)])
		# a hit on a tower: the side's Puissance counts there too
		var tw: Node = arena.crown_tower(1)
		var thp: float = float(tw.hp)
		tw.take_damage(10.0, tw.position + Vector2(40, 0), sc_mil)
		print("[scale] tower hit of 10 with P 3: took %.0f (expect 13)" % (thp - float(tw.hp)))
		arena.add_armor(1, 2.0)
		thp = float(tw.hp)
		tw.take_damage(10.0, tw.position + Vector2(40, 0), sc_mil)
		print("[scale] same with tower side Armor 2: took %.0f (expect 11)" % (thp - float(tw.hp)))


## Relics and Dominion cards. Plain match, side 0 handed every in-fight relic;
## card plays are fed straight to the relic hook at set times so the windows
## are exact. Then the run side: starting relics, awards, Fuel for the Fire.
var rl_gold := 0.0


func _relic_line(label: String) -> void:
	print("[relic] t%.1f %s | fires %s | metronome %s sleight %s idle %.1f" % [arena.fight_t, label,
		str(arena.relic_fires), str(arena.relic_window(0, "metronome").size()),
		str(arena.relic_window(0, "sleight").size()), float(arena.relic_idle[0])])


## The Abyssal Pearl's cycle: spend to 0 -> the pearl drops in as the first gold
## (the gold that was filling carries on); spend it -> back to the bar, resting;
## a first gold of your own -> ready; spend to 0 again -> it drops again.
func _pearl_line(what: String) -> void:
	var names := ["READY", "BANKED", "RESTING"]
	print("[pearl] t%.1f %s: gold %.2f, pearl %s" % [elapsed, what, float(arena.gold[0]),
		names[int(arena.pearl_state[0])]])


func _pearl_steps() -> void:
	if _at(0.3):
		for b in arena.bots:
			if b != null and is_instance_valid(b):
				b.enabled = false
		arena.relics[0] = ["abyssal_pearl"]
		arena.gold[0] = 3.4
		_pearl_line("start (expect READY)")
	# each "spend" spends every whole gold, keeping the part still filling
	if _at(1.0):
		arena.gold[0] = fmod(float(arena.gold[0]), 1.0)
		_pearl_line("spent every whole gold")
	if _at(1.1):
		_pearl_line("next tick (expect BANKED, gold 1 + what was filling)")
	if _at(2.0):
		arena.gold[0] = fmod(float(arena.gold[0]), 1.0)
		_pearl_line("spent the pearl and the rest")
	if _at(2.1):
		_pearl_line("next tick (expect RESTING, gold under 1)")
	if _at(4.6):
		_pearl_line("a first gold of our own (expect READY)")
		arena.gold[0] = fmod(float(arena.gold[0]), 1.0)
	if _at(4.7):
		_pearl_line("spent to 0 again (expect BANKED)")
		print("[pearl] drops: %d (expect 2)" % int(arena.relic_fires.get("abyssal_pearl", 0)))


func _relic_steps() -> void:
	if _at(0.3):
		for b in arena.bots:
			if b != null and is_instance_valid(b):
				b.enabled = false
		arena.relics[0] = ["whetstone", "tortoise_shell", "metronome", "sleight", "hourglass", "ledger",
			"field_dressing", "warhorn"]
		arena.puissance = [0.0, 0.0]
		arena.armor = [0.0, 0.0]
		var king: Node = arena._king_of(0)
		king.hp = float(king.max_hp) - 25.0
		var before_hp: float = king.hp
		arena._apply_relics_start()
		print("[relic] start: Puissance %d Armor %d, commander %.0f -> %.0f (+10), king mult %.2f" % [
			int(arena.puissance[0]), int(arena.armor[0]), before_hp, float(king.hp), arena.king_mult(0)])
		arena.relic_idle[0] = 0.0
		arena.relic_income[0] = 0.0
		arena.relic_fires = {}
		# a Dominion card from the hand: Puissance up, the card gone for the fight
		arena.hands[0][0] = "dominion_puissance"
		arena.gold[0] = 10.0
		var p_before := float(arena.puissance[0])
		var q_before: int = arena.queues[0].count("dominion_puissance")
		arena.deploy(0, 0, arena.tile_center(9.0, 22.0))
		print("[relic] Dominion of Puissance: Puissance %d -> %d; copies in the queue %d -> %d (spent: no change)" % [
			int(p_before), int(arena.puissance[0]), q_before, arena.queues[0].count("dominion_puissance")])
		# that deploy was a card play too: start the windows clean
		arena.relic_plays = [{}, {}]
		arena.relic_fires = {}
		arena.relic_idle[0] = 0.0
		_relic_line("after setup")
	# Metronome: 3 within 9 s -> 1 gold; Sleight: 4 within 12 s -> a card
	if _at(1.0) or _at(2.0):
		arena._relics_card_played(0)
		_relic_line("card played")
	if _at(3.0):
		rl_gold = float(arena.gold[0])
		arena._relics_card_played(0)
		_relic_line("3rd card (metronome should fire: gold %.2f -> %.2f)" % [rl_gold, float(arena.gold[0])])
	if _at(4.0):
		arena._relics_card_played(0)
		_relic_line("4th card (sleight should fire)")
	# a lone play, then the window lets it go after 9 s
	if _at(5.0):
		arena._relics_card_played(0)
		_relic_line("lone card")
	if _at(13.5):
		_relic_line("8.5 s later: metronome still holds it")
	if _at(14.6):
		_relic_line("9.6 s later: metronome has let it go")
	# no card since t5.0: the Hourglass fires at t14.0 and again at t23.0
	if _at(24.0):
		_relic_line("idle since t5 (hourglass should have fired twice)")
		print("[relic] ledger: income %.2f gold over the fight -> %d doubled (every 4th)" % [float(arena.relic_income[0]),
			int(arena.relic_fires.get("ledger", 0))])
	# Lucky 7: income carrying gold from 7.95 past 8 gives one more
	if _at(24.3):
		arena.relics[0].append("lucky7")
		arena.gold[0] = 7.95
		arena.relic_fires.erase("lucky7")
	if _at(24.8):
		print("[relic] lucky7: gold from 7.95 -> %.2f half a second later (about 8.2 without it, 9.2 with), fired %d" % [
			float(arena.gold[0]), int(arena.relic_fires.get("lucky7", 0))])
	if _at(25.0):
		_run_relic_checks()


func _run_relic_checks() -> void:
	Run.start(77)
	Run.ability = "flame"
	Run.relics = [Run.RELIC_DB.starter_for("flame")]
	print("[run] starters: flame %s, shiesty %s, tentacle %s, drone %s" % [Run.RELIC_DB.starter_for("flame"),
		Run.RELIC_DB.starter_for("shiesty"), Run.RELIC_DB.starter_for("tentacle"), Run.RELIC_DB.starter_for("drone")])
	# fight 1 (regular) won: no relic yet; skip the card -> fueled
	Run.report(0, 200.0)
	print("[run] fight 1 won: relic %s, %d choices" % [str(Run.last.get("relic", "-")), Run.reward_choices().size()])
	Run.skip_reward()
	print("[run] skipped: fueled %s" % str(Run.fueled_now()))
	Run.advance()
	# fight 2 (regular) won: 2nd regular -> a relic; this reward is the fueled kind
	Run.report(0, 180.0)
	var ch: Array = Run.reward_choices()
	print("[run] fight 2 won: relic %s, %d choices %s" % [str(Run.last.get("relic", "-")), ch.size(), str(ch)])
	Run.take_reward(String(ch[0]))
	print("[run] take one on a fueled reward refused: rewarded %s" % str(Run.rewarded))
	var deck_before: int = Run.deck.size()
	var gone := String(Run.deck[0])
	var ok: bool = Run.take_two(String(ch[0]), String(ch[1]), gone)
	print("[run] take two, remove %s: ok %s, deck %d -> %d, fueled now %s" % [gone, str(ok), deck_before, Run.deck.size(),
		str(Run.fueled_now())])
	Run.advance()
	# fight 3 (the elite) won -> a relic
	Run.report(0, 150.0)
	print("[run] elite won: relic %s; relics %s" % [str(Run.last.get("relic", "-")), str(Run.relics)])
	Run.stop()


## A body for Laniakea to hit that neither walks nor hits back.
func _lani_dummy(kind: String, at: Vector2) -> Node:
	var u = arena.spawn_troop(kind, 1, at, true)
	# spawn_troop snaps to the tile; the checks need the exact offset
	u.position = at
	u.deploy_timer = 0.0
	u.speed = 0.0
	u.dmg = 0.0
	return u


func _lani_clear() -> void:
	for u in arena.units.duplicate():
		if is_instance_valid(u):
			u.take_damage(99999.0, u.position)


## Laniakea's three cases: the cleave (arc + shove, nothing behind him), the leap
## (flyer + the strip behind it, stun) and the dead zone (flyer inside 2.5 tiles).
var lani_marks: Array = []
func _laniakea_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.3):
		probe = arena.spawn_troop("laniakea", 0, arena.tile_center(9.5, 20.5), true)
		probe.deploy_timer = 0.0
		probe.speed = 0.0
		var p: Vector2 = probe.position
		var fwd: Vector2 = (arena.tile_center(9.5, 19.5) - p).normalized()
		lani_marks = [
			_lani_dummy("hero", p + fwd * 1.3 * t),
			_lani_dummy("hero", p + fwd.rotated(deg_to_rad(60.0)) * 2.0 * t),
			_lani_dummy("hero", p + fwd.rotated(deg_to_rad(100.0)) * 1.8 * t),
			_lani_dummy("hero", p - fwd * 1.8 * t),
			_lani_dummy("aphid", p + fwd * 1.6 * t),
		]
		print("[laniakea] cleave: target 1.3 ahead, 60deg flank at 2.0, 100deg flank at 1.8, one behind, a flyer in the arc")
	if _at(0.9):
		print("[laniakea] hp target/flank60/flank100/behind/flyer = %s (expect 125,125,150,150,110; multiples of 12 off are tower shots)" % [
			str(lani_marks.map(func(u): return int(u.hp)))])
		print("[laniakea] dist target/flank60 = %.2f / %.2f (expect ~1.80 / ~2.50, the shared impulse runs one tick long), atk_cd=%.2f" % [
			arena.tiles_between(probe.position, lani_marks[0].position),
			arena.tiles_between(probe.position, lani_marks[1].position), probe.atk_cd])
	if _at(2.0):
		_lani_clear()
		probe = arena.spawn_troop("laniakea", 0, arena.tile_center(9.5, 20.5), true)
		probe.deploy_timer = 0.0
		var p2: Vector2 = probe.position
		var fwd2: Vector2 = (arena.tile_center(9.5, 19.5) - p2).normalized()
		lani_marks = [
			_lani_dummy("aphid", p2 + fwd2 * 3.0 * t),
			_lani_dummy("hero", p2 + fwd2 * 5.0 * t),
			_lani_dummy("hero", p2 + fwd2 * 5.0 * t + fwd2.orthogonal() * 2.0 * t),
		]
		print("[laniakea] leap: flyer at 3.0, hero 2.0 behind it, hero 2.0 off to the side")
	if _at(2.2):
		print("[laniakea] leaping=%s" % str(probe.leaping))
	if _at(2.7):
		print("[laniakea] hp flyer/behind/side = %s (expect 60,100,150) stunned flyer/behind = %s/%s gap to flyer=%.2f" % [
			str(lani_marks.map(func(u): return int(u.hp))),
			str(lani_marks[0].stunned > 0.0), str(lani_marks[1].stunned > 0.0),
			arena.gap_between(probe.position, lani_marks[0].position, probe.radius_t, lani_marks[0].radius_t)])
	if _at(4.0):
		_lani_clear()
		probe = arena.spawn_troop("laniakea", 0, arena.tile_center(9.5, 20.5), true)
		probe.deploy_timer = 0.0
		var p3: Vector2 = probe.position
		var fwd3: Vector2 = (arena.tile_center(9.5, 19.5) - p3).normalized()
		lani_marks = [_lani_dummy("aphid", p3 + fwd3 * 2.0 * t)]
		print("[laniakea] dead zone: flyer at 2.0")
	if _at(6.5):
		var tg = probe.target
		print("[laniakea] flyer hp=%d (expect 110) leaping=%s target_is_tower=%s" % [
			int(lani_marks[0].hp), str(probe.leaping),
			str(tg != null and is_instance_valid(tg) and tg.is_tower())])
	if _at(7.0):
		_lani_clear()
		probe = arena.spawn_troop("laniakea", 0, arena.tile_center(9.5, 20.5), true)
		probe.deploy_timer = 0.0
		var p4: Vector2 = probe.position
		var fwd4: Vector2 = (arena.tile_center(9.5, 19.5) - p4).normalized()
		lani_marks = [_lani_dummy("hero", p4 + fwd4 * 3.0 * t)]
		print("[laniakea] ground leap: hero at 3.0")
	if _at(7.2):
		print("[laniakea] leaping=%s (expect true)" % str(probe.leaping))
	if _at(7.8):
		print("[laniakea] hero hp=%d (expect 100: 150 - 50) stunned=%s" % [
			int(lani_marks[0].hp), str(lani_marks[0].stunned > 0.0)])
	if _at(8.2):
		_lani_clear()
		probe = arena.spawn_troop("laniakea", 0, arena.tile_center(9.5, 20.5), true)
		probe.deploy_timer = 0.0
		var p5: Vector2 = probe.position
		var fwd5: Vector2 = (arena.tile_center(9.5, 19.5) - p5).normalized()
		lani_marks = [_lani_dummy("warren", p5 + fwd5 * 3.3 * t)]
		print("[laniakea] building leap: warren (radius 0.75) at 3.3, 3.0 measured from its edge")
	if _at(8.4):
		print("[laniakea] leaping=%s (expect true)" % str(probe.leaping))
	if _at(9.0):
		print("[laniakea] warren hp=%d (expect 80: 130 - 50)" % int(lani_marks[0].hp))


## Femme Fatale: the dash (4.0 tiles: wind-up, lunge to 1.5, 25 on the tip), then
## the combo from a 3.0 tile walk-up (12, 12, 12 + half a tile of recoil).
## Towers are silenced so every point of damage in the log is hers.
func _femme_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.2):
		for tw in arena.towers:
			tw.dmg = 0.0
	if _at(0.3):
		probe = arena.spawn_troop("femme", 0, arena.tile_center(9.5, 21.5), true)
		probe.deploy_timer = 0.0
		var fwd: Vector2 = (arena.tile_center(9.5, 20.5) - probe.position).normalized()
		lani_marks = [_lani_dummy("hero", probe.position + fwd * 4.0 * t)]
		print("[femme] dash: hero 4.0 tiles ahead")
	if _at(0.5):
		print("[femme] t0.5 dash_phase=%d (expect 1, winding up) dist=%.2f" % [
			probe.dash_phase, arena.tiles_between(probe.position, lani_marks[0].position)])
	if _at(1.3):
		print("[femme] t1.3 dash_phase=%d dist=%.2f (expect 0 / 1.50) hero hp=%d (expect 125)" % [
			probe.dash_phase, arena.tiles_between(probe.position, lani_marks[0].position), int(lani_marks[0].hp)])
	if _at(3.0):
		_lani_clear()
		probe = arena.spawn_troop("femme", 0, arena.tile_center(9.5, 21.5), true)
		probe.deploy_timer = 0.0
		var fwd2: Vector2 = (arena.tile_center(9.5, 20.5) - probe.position).normalized()
		lani_marks = [_lani_dummy("hero", probe.position + fwd2 * 3.0 * t)]
		print("[femme] combo: hero 3.0 tiles ahead (inside the dash window's near edge)")
	if _at(3.3):
		print("[femme] t3.3 dash_phase=%d (expect 0, walking)" % probe.dash_phase)
	if _at(4.6) or _at(5.8) or _at(6.6) or _at(7.4) or _at(9.0):
		print("[femme] t%.1f hero hp=%d step=%d dist=%.2f" % [elapsed, int(lani_marks[0].hp),
			probe.needle_step, arena.tiles_between(probe.position, lani_marks[0].position)])


## The goblin commander: spear throws at a dummy, then the Shiesty scoop and
## throw. Shots (with --shots=<dir>) catch the ready wave, the scoop and the flight;
## the log proves the toss is picture only (his real position stays on the old arc).
## Shiesty's way home: two enemy troops guard bridge A's half and one guards
## bridge B's, so he must take B. Then three more are dropped on B's half while
## he runs: he must not turn back. Guards are frozen and toothless (speed 0,
## dmg kept so they count) far from his path so the run is not interrupted.
var lane_shiesty: Node = null
func _shiesty_lane_steps() -> void:
	if _at(0.2):
		arena.ability[0] = "shiesty"
		arena.gold[0] = 10.0
		arena.gold[1] = 5.0
		arena.ability_cd[0] = 0.0
		for spot in [Vector2(2.5, 6.5), Vector2(3.5, 8.5), Vector2(15.5, 8.5)]:
			var g = arena.spawn_troop("hero", 1, arena.tile_center(spot.x, spot.y), true)
			g.deploy_timer = 0.0
			g.speed = 0.0
			g.aggro = 0.0
		print("[shiestylane] guards: 2 on bridge A's half, 1 on bridge B's (expect B)")
		print("[shiestylane] ability used=%s" % str(arena.use_ability(0)))
	if lane_shiesty == null:
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "shiesty":
				lane_shiesty = u
	if _at(1.5) and lane_shiesty != null:
		print("[shiestylane] t1.5 landed, threat A/B=%s bridge col=%.0f (expect 13)" % [
			str(lane_shiesty.lane_threat), lane_shiesty.bridge_col])
		for spot in [Vector2(12.5, 5.5), Vector2(14.5, 5.5), Vector2(15.5, 6.5)]:
			var g2 = arena.spawn_troop("hero", 1, arena.tile_center(spot.x, spot.y), true)
			g2.deploy_timer = 0.0
			g2.speed = 0.0
			g2.aggro = 0.0
		print("[shiestylane] 3 more guards dropped on B's half")
	for tt in [3.0, 5.0, 7.0]:
		if _at(tt):
			if is_instance_valid(lane_shiesty) and not lane_shiesty.dead:
				var t: Vector2i = arena.tile_of(lane_shiesty.position)
				print("[shiestylane] t%.1f tile=(%d,%d) bridge col=%.0f" % [tt, t.x, t.y, lane_shiesty.bridge_col])
			else:
				print("[shiestylane] t%.1f shiesty gone (home or caught) escaped=%d caught=%d" % [
					tt, arena.stat_shiesty_escaped, arena.stat_shiesty_caught])


## The two whelps (run with --bots=off). Obsidian: open with nobody near, curls
## when a unit comes within 3 tiles, opens the moment it leaves; a hit curls it
## (that hit in full, the next at 20 %) and it stays shut 2 s; a melee blow
## nudges it 0.25 tiles. The hand swap. Magma: feathers burn at 2 tiles.
var whelp_o: Node = null
var whelp_m: Node = null
var whelp_foe: Node = null
var whelp_at := Vector2.ZERO
func _whelp_freeze(kind: String, at: Vector2) -> Node:
	var u = arena.spawn_troop(kind, 1, at, true)
	u.deploy_timer = 0.0
	u.position = at
	u.speed = 0.0
	u.dmg = 0.0
	return u
func _whelp_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.3):
		whelp_o = arena.spawn_troop("obsidian", 0, arena.tile_center(9.5, 22.5), true)
		whelp_o.deploy_timer = 0.0
		whelp_o.speed = 0.0
	if _at(0.8):
		print("[whelp] t0.8 nobody near: curled=%s (expect false)" % str(whelp_o.curled))
		whelp_foe = _whelp_freeze("hero", whelp_o.position + Vector2(3.2 * t, 0.0))
		print("[whelp] hero placed, gap=%.2f tiles" % arena.gap_between(whelp_o.position, whelp_foe.position,
			whelp_o.radius_t, whelp_foe.radius_t))
	if _at(1.0):
		print("[whelp] t1.0 curled=%s (expect true)" % str(whelp_o.curled))
		whelp_foe.take_damage(9999.0, whelp_foe.position)
	if _at(1.3):
		print("[whelp] t1.3 hero gone, never hit: curled=%s (expect false)" % str(whelp_o.curled))
		whelp_o.take_damage(20.0, whelp_o.position + Vector2(200, 0))
		print("[whelp] hit for 20 while open: hp=%d (expect 40) curled=%s" % [int(whelp_o.hp), str(whelp_o.curled)])
		whelp_o.take_damage(20.0, whelp_o.position + Vector2(200, 0))
		print("[whelp] hit for 20 while curled: hp=%d (expect 36)" % int(whelp_o.hp))
	if _at(3.0):
		print("[whelp] t3.0 1.7 s after the hit: curled=%s (expect true)" % str(whelp_o.curled))
	if _at(3.5):
		print("[whelp] t3.5 2.2 s after the hit: curled=%s (expect false)" % str(whelp_o.curled))
		whelp_foe = _whelp_freeze("hero", whelp_o.position + Vector2(0.9 * t, 0.0))
		whelp_at = whelp_o.position
		whelp_o.take_damage(10.0, whelp_foe.position, whelp_foe)
	if _at(3.9):
		print("[whelp] t3.9 melee blow: pushed %.2f tiles away from the hero (expect 0.25) curled=%s" % [
			arena.tiles_between(whelp_at, whelp_o.position), str(whelp_o.curled)])
		whelp_foe.take_damage(9999.0, whelp_foe.position)
		whelp_o.take_damage(9999.0, whelp_o.position)
		arena.gold[0] = 10.0
		arena.hands[0][0] = "obsidian"
		arena.deploy(0, 0, arena.tile_center(9.5, 24.5))
		print("[whelp] played obsidian from slot 0: slot 0 is now %s (expect magma) obsidian back in deck=%s" % [
			arena.hands[0][0], str(arena.queues[0].has("obsidian"))])
	if _at(4.5):
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "obsidian":
				u.take_damage(9999.0, u.position)
		whelp_m = arena.spawn_troop("magma", 0, arena.tile_center(9.5, 22.5), true)
		whelp_m.deploy_timer = 0.0
		whelp_m.speed = 0.0
		whelp_foe = _whelp_freeze("hero", whelp_m.position + Vector2(2.4 * t, 0.0))
		print("[whelp] magma flying=%s, hero %.2f tiles away edge to edge, hp=%d" % [str(whelp_m.flying),
			arena.gap_between(whelp_m.position, whelp_foe.position, whelp_m.radius_t, whelp_foe.radius_t), int(whelp_foe.hp)])
	for tt in [5.0, 6.5, 8.5]:
		if _at(tt) and is_instance_valid(whelp_foe):
			print("[whelp] t%.1f hero hp=%d status=%d burn_stack=%.1f" % [tt, int(whelp_foe.hp), int(whelp_foe.status), whelp_foe.burn_stack])


## A tower and a lone enemy Obsidian Whelp: the first shot lands in full and only
## then curls it. A hero walks into range further away: the tower switches to
## it. The hero dies: the tower goes back to the curled whelp (20 % damage).
var pick_tower: Node = null
var pick_whelp: Node = null
var pick_hero: Node = null
func _towerpick_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.3):
		for tw in arena.towers:
			if int(tw.team) == 0 and not bool(tw.get("crown")):
				pick_tower = tw
				break
		pick_whelp = _whelp_freeze("obsidian", pick_tower.position + Vector2(5.0 * t, 0.0))
		print("[towerpick] whelp %.1f tiles from the tower, hp=%d curled=%s" % [
			arena.tiles_between(pick_tower.position, pick_whelp.position), int(pick_whelp.hp), str(pick_whelp.curled)])
	if _at(1.4):
		print("[towerpick] t1.4 whelp hp=%d (expect 48: first shot in full) curled=%s" % [int(pick_whelp.hp), str(pick_whelp.curled)])
		pick_hero = _whelp_freeze("hero", pick_tower.position + Vector2(5.5 * t, 1.5 * t))
		# a hero beside a curled whelp would keep it shut anyway; keep the whelp blind
		pick_whelp.guard_cfg = pick_whelp.guard_cfg.duplicate()
		pick_whelp.guard_cfg["sense"] = -1.0
	if _at(1.6):
		print("[towerpick] t1.6 tower target is the hero=%s (expect true: the whelp is curled)" % str(pick_tower.target == pick_hero))
	if _at(4.0):
		print("[towerpick] t4.0 whelp hp=%d (expect 48: untouched) hero hp=%d" % [int(pick_whelp.hp), int(pick_hero.hp)])
		pick_hero.take_damage(9999.0, pick_hero.position)
	if _at(6.0):
		print("[towerpick] t6.0 back on the whelp: target=%s whelp hp=%.1f (expect under 48, by 2.4 a shot) curled=%s" % [
			str(pick_tower.target == pick_whelp), pick_whelp.hp, str(pick_whelp.curled)])


## Wu Cheng'en against a row of frozen dummies, away from every tower: the
## staff comes out first, the poke goes through the target and 2 tiles on
## (pushing), the sweep takes the cone, and hits bank rage. Then he is cut
## under 25 %: rage, faster swings and regen by banked hits.
var wu: Node = null
var wu_dummies: Array = []
func _wu_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.3):
		wu = arena.spawn_troop("wu", 0, arena.tile_center(9.5, 20.5), true)
		wu.deploy_timer = 0.0
		var p: Vector2 = wu.position
		var fwd: Vector2 = (arena.tile_center(9.5, 19.5) - p).normalized()
		# target 2.0 ahead, one 1.5 behind it on the line, one 3.0 behind it (out
		# of the pierce), one 50 degrees off at 1.6 tiles (in the sweep only)
		wu_dummies = [
			_lani_dummy("hero", p + fwd * 2.0 * t),
			_lani_dummy("hero", p + fwd * 3.5 * t),
			_lani_dummy("hero", p + fwd * 5.0 * t),
			_lani_dummy("hero", p + fwd.rotated(deg_to_rad(50.0)) * 2.15 * t),
		]
		for d in wu_dummies:
			d.speed = 0.0
			d.dmg = 0.0
		print("[wu] dummies: target 2.0 ahead, on the line at 3.5 and 5.0, 50 deg off at 2.15 (ignore drops of 12: tower shots)")
	if _at(0.5):
		print("[wu] t0.5 staff_out=%.2f state=%d" % [wu.staff_out, wu.state])
	for tt in [1.0, 1.6, 2.4, 3.0, 4.4]:
		if _at(tt):
			print("[wu] t%.1f staff_out=%.2f combo next=%d hp=%s rage_hits=%d level=%d" % [tt, wu.staff_out, wu.staff_combo,
				str(wu_dummies.map(func(u): return int(u.hp) if is_instance_valid(u) else -1)), wu.rage_hits, wu.rage_level()])
	if _at(4.5):
		for d in wu_dummies:
			if is_instance_valid(d):
				d.hp = 9999.0
				d.max_hp = 9999.0
		wu.rage_hits = 8
		wu.take_damage(wu.max_hp * 0.8, wu.position)
		print("[wu] cut to %d/%d with 8 banked: rage_t=%.1f regen=%.0f/s (expect 25) speed=%.2f (base %.2f)" % [
			int(wu.hp), int(wu.max_hp), wu.rage_t, wu.rage_regen, wu.speed, wu.ground_speed])
	if _at(6.5):
		print("[wu] t6.5 hp=%.1f (2 s of 25/s on top of %d)" % [wu.hp, int(wu.max_hp * 0.2)])
	if _at(9.6):
		print("[wu] t9.6 rage over: rage_t=%.1f speed=%.2f hp=%.1f" % [wu.rage_t, wu.speed, wu.hp])


## The Nekomancer, held in place, beaming a frozen dummy 3.5 tiles ahead: the
## beam hits for 14 every 1.2 s, the ritual opens two pentagrams 1.2 tiles out
## on the forward diagonals every 4 s with the cloak gust, a rat skeleton climbs
## out of each a second later, and the second ritual's rats still come after
## she is killed mid-glow.
var neko: Node = null
var neko_dummy: Node = null
func _neko_count(k: String) -> int:
	var n := 0
	for u in arena.units:
		if is_instance_valid(u) and not u.dead and String(u.kind) == k:
			n += 1
	return n


func _neko_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.3):
		neko = arena.spawn_troop("neko", 0, arena.tile_center(9.5, 20.5), true)
		neko.deploy_timer = 0.0
		neko.speed = 0.0
		neko.ground_speed = 0.0
		var fwd: Vector2 = (arena.tile_center(9.5, 19.5) - neko.position).normalized()
		neko_dummy = _lani_dummy("hero", neko.position + fwd * 3.5 * t)
		neko_dummy.speed = 0.0
		neko_dummy.dmg = 0.0
		neko_dummy.hp = 9999.0
		neko_dummy.max_hp = 9999.0
		print("[neko] fwd=%s (ignore drops of 12 on her: tower shots)" % str(fwd))
	for tt in [0.4, 1.6, 2.8]:
		if _at(tt):
			print("[neko] t%.1f dummy lost %d beam_t=%.2f" % [tt, int(9999.0 - neko_dummy.hp), neko.beam_t])
	if _at(4.35):
		var spots: Array = []
		for c in arena.get_children():
			if c.get("unit_kind") != null and String(c.get("unit_kind")) == "ratbones":
				var off: Vector2 = (c.position - neko.position) / t
				spots.append("(%.2f, %.2f) |%.2f|" % [off.x, off.y, off.length()])
		print("[neko] t4.35 cloak_t=%.2f pentagrams=%s rats=%d" % [neko.cloak_t, str(spots), _neko_count("ratbones")])
	if _at(5.4):
		var offs: Array = []
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "ratbones":
				offs.append(str(((u.position - neko.position) / t).snapped(Vector2(0.01, 0.01))))
		print("[neko] t5.4 rats=%d at %s" % [_neko_count("ratbones"), str(offs)])
	if _at(8.5):
		print("[neko] t8.5 rats=%d, killing her mid-glow" % _neko_count("ratbones"))
		neko.take_damage(9999.0, neko.position)
	if _at(9.6):
		print("[neko] t9.6 she is gone=%s rats=%d (expect 4)" % [str(not is_instance_valid(neko) or neko.dead), _neko_count("ratbones")])


## Gilgamesh & Enkidu, both held in place: the pair lands a tile apart; Enkidu
## ignores a hovering flyer in his throw band, throws at a ground dummy that
## appears there (45, then sword: reach 0.5, no air) and has the spear back
## 3.5 s later; a dummy dropped inside 3 tiles is fought, not thrown at. Then
## Enkidu is removed and Gilgamesh lashes a dummy 2.25 tiles off his edge.
var gil: Node = null
var enk: Node = null
var gil_dummy: Node = null
func _gil_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.3):
		gil = arena.spawn_troop("gilgamesh", 0, arena.tile_center(9.5, 20.5))
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "enkidu":
				enk = u
		for u in [gil, enk]:
			u.deploy_timer = 0.0
			u.speed = 0.0
			u.ground_speed = 0.0
		print("[gil] pair: gil=%s enk=%s gap=%.2f tiles" % [str(gil != null), str(enk != null),
			arena.tiles_between(gil.position, enk.position)])
		var hawk: Node = _lani_dummy("hawk", enk.position + Vector2(4.0 * t, 0.0))
		hawk.hp = 999.0
		hawk.max_hp = 999.0
	if _at(0.9):
		print("[gil] t0.9 flyer at 4.0: spear_away=%.2f (expect 0, no throw)" % enk.spear_away)
		gil_dummy = _lani_dummy("hero", enk.position + Vector2(3.8 * t, 0.6 * t))
		gil_dummy.hp = 9999.0
		gil_dummy.max_hp = 9999.0
	if _at(1.4):
		print("[gil] t1.4 ground dummy at 3.85: dummy lost %d (expect 45) spear_away=%.2f reach=%.2f dmg=%.0f hits_air=%s" % [
			int(9999.0 - gil_dummy.hp), enk.spear_away, enk.reach, enk.dmg, str(enk.hits_air)])
	if _at(4.0):
		# out of the way before the spear comes back, or he throws it again
		_lani_clear_except([gil, enk])
	if _at(4.7):
		print("[gil] t4.7 spear_away=%.2f reach=%.2f dmg=%.0f hits_air=%s (expect 0 1.10 24 true)" % [
			enk.spear_away, enk.reach, enk.dmg, str(enk.hits_air)])
		gil_dummy = _lani_dummy("hero", enk.position + Vector2(2.0 * t, 0.4 * t))
		gil_dummy.hp = 9999.0
		gil_dummy.max_hp = 9999.0
	if _at(5.6):
		print("[gil] t5.6 dummy dropped at 2.0: spear_away=%.2f (expect 0) target=%s" % [
			enk.spear_away, str(enk.target == gil_dummy)])
		enk.take_damage(99999.0, enk.position)
		_lani_clear_except([gil])
		gil_dummy = _lani_dummy("hero", gil.position + Vector2((2.25 + 0.5 + 0.45) * t, 0.0))
		gil_dummy.hp = 9999.0
		gil_dummy.max_hp = 9999.0
	if _at(8.8):
		print("[gil] t8.8 Gilgamesh lashed 2.25 off his edge: dummy lost %d (22 a lash, every 1.3 s)" % int(9999.0 - gil_dummy.hp))


## The dart frog: hops toward the enemy in 0.7 tile steps with rests between;
## when a dummy's edge comes within 2 tiles it leaps on it and bursts, putting
## 10 poison on the dummy and on one standing beside it (within 0.5), none on
## one 1.5 tiles off, and the frog is gone.
var frog: Node = null
var frog_dummies: Array = []
var frog_last := Vector2.ZERO
var frog_burst_gaps: Array = []
func _frog_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.3):
		frog = arena.spawn_troop("frog", 0, arena.tile_center(9.5, 24.5), true)
		frog.deploy_timer = 0.0
		frog_last = frog.position
		print("[frog] hop=%.2f over %.2f s, rest %.2f s" % [float(frog.frog_cfg["hop"]),
			float(frog.frog_cfg["hop_time"]), float(frog.frog_cfg["rest"])])
	# every hop's landing: how far it went
	if is_instance_valid(frog) and not frog.dead and elapsed > 0.3 and elapsed < 2.4:
		if frog.frog_hop_t <= 0.0 and not frog.frog_leaping and frog.position.distance_to(frog_last) > 1.0:
			print("[frog] t%.2f hopped %.2f tiles" % [elapsed, frog.position.distance_to(frog_last) / t])
			frog_last = frog.position
	if _at(2.4):
		var fwd: Vector2 = (arena.tile_center(9.5, 19.5) - arena.tile_center(9.5, 20.5)).normalized()
		var a: Node = _lani_dummy("hero", frog.position + fwd * 3.0 * t)
		# 0.92 apart: just clear of body overlap (0.9), so nothing shoves them
		var b: Node = _lani_dummy("hero", a.position + fwd.orthogonal() * 0.92 * t)
		var c: Node = _lani_dummy("hero", a.position + fwd.orthogonal() * -1.5 * t)
		frog_dummies = [a, b, c]
		for d in frog_dummies:
			d.hp = 999.0
			d.max_hp = 999.0
			# frozen, so body collision cannot push the pair apart before the burst
			d.set_physics_process(false)
		print("[frog] dummies 3.0 ahead: one, one touching it (0.92 beside), one 1.5 off the other way")
	if is_instance_valid(frog) and not frog.dead and frog.frog_leaping and frog.frog_leap_t <= 0.02 and not frog_dummies.is_empty():
		print("[frog] t%.2f leaps at dummy %d; centre distances to dummies %s" % [elapsed,
			frog_dummies.find(frog.frog_victim),
			str(frog_dummies.map(func(u): return snappedf(arena.tiles_between(frog.position, u.position), 0.01)))])
	# the burst point and where each dummy stood, on the frame it went off
	if arena.has_meta("frog_burst") and frog_burst_gaps.is_empty() and not frog_dummies.is_empty():
		var at: Vector2 = arena.get_meta("frog_burst")
		for d in frog_dummies:
			frog_burst_gaps.append(arena.tiles_between(at, d.position) - float(d.get_radius_t()))
	if _at(3.6):
		print("[frog] t3.6 frog gone=%s" % str(not is_instance_valid(frog) or frog.dead))
		for i in frog_dummies.size():
			var d: Node = frog_dummies[i]
			var gap: float = frog_burst_gaps[i] if i < frog_burst_gaps.size() else -99.0
			print("[frog]   dummy edge %.2f tiles from the landing -> poison %.0f (expect %s)" % [
				gap, d.poison, "10" if gap <= 0.5 else "0"])


## Shiesty on his run home takes what a troop takes, through the same arena
## paths the cards use: a burn splash, a slow blast, poison, a knockback blast.
## Towers still ignore him. Run with --bots=off.
var fx_sh: Node = null
var fx_mark := Vector2.ZERO
func _shiesty_fx_steps() -> void:
	if _at(0.2):
		arena.ability[0] = "shiesty"
		arena.gold[0] = 10.0
		arena.ability_cd[0] = 0.0
		print("[sfx] ability used=%s" % str(arena.use_ability(0)))
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "shiesty":
				fx_sh = u
	if fx_sh == null or not is_instance_valid(fx_sh):
		return
	if _at(1.2):
		fx_sh.hp = 400.0
		fx_sh.max_hp = 400.0
		print("[sfx] t1.2 landed=%s; burn splash 20 from the enemy side" % str(not fx_sh.untargetable))
		arena.apply_burn_at(fx_sh.position, 0.5, 20.0, 1)
		print("[sfx]   burn_stack=%.0f status=%d" % [fx_sh.burn_stack, fx_sh.status])
	if _at(3.3):
		print("[sfx] t3.3 hp=%.0f (burn ticks 8 + 4 -> expect 388)" % fx_sh.hp)
		fx_mark = fx_sh.position
	if _at(3.8):
		var free_run: float = fx_sh.position.distance_to(fx_mark)
		fx_mark = fx_sh.position
		arena.death_aoe(fx_sh.position, 1.0, 0.0, 0.3, 2.0, 1)
		print("[sfx] t3.8 ran %.1f px in 0.5 s; slow blast -> status=%d slow=%.2f" % [free_run, fx_sh.status, fx_sh.slow_amount])
	if _at(4.3):
		print("[sfx] t4.3 slowed: ran %.1f px in 0.5 s (expect 70 %%)" % fx_sh.position.distance_to(fx_mark))
		fx_sh.add_poison(5.0)
		var before: Vector2 = fx_sh.position
		arena.spell_blast(fx_sh.position + Vector2(-20, 0), 1.5, 0.0, 1, 1.0, 0.0, 1.0, "fireball")
		fx_mark = before
		print("[sfx]   poison=%.0f knock_time=%.2f" % [fx_sh.poison, fx_sh.knock_time])
	if _at(4.7):
		print("[sfx] t4.7 shoved %.2f tiles; towers ignore him: tower_ignore=%s" % [
			fx_sh.position.distance_to(fx_mark) / float(arena.TILE), str(fx_sh.tower_ignore)])


## Card-draw signalling and the Nekomancer's pentagrams: playing the Hero sends
## the drawn card in face down from where he landed, and it flashes as it turns
## over; the "+1" badge sits under the cost. Then the pentagrams open ahead of
## her. Run with --bots=off.
var dfx_card: Node = null
var dfx_neko: Node = null
func _dfx_card_of(id: int) -> Node:
	for c in arena.panels[0].cards:
		if is_instance_valid(c) and int(c.card_id) == id:
			return c
	return null


func _drawfx_steps() -> void:
	if _at(1.6):
		arena.hands[0] = ["hero", "frog", "aphid"]
		arena.queues[0] = ["chicken", "wu", "slate"]
		arena.hand_ids[0] = []
		arena.queue_ids[0] = []
		arena.gold[0] = 10.0
	if _at(2.0):
		arena.deploy(0, 0, arena.tile_center(9.5, 20.5))
		print("[drawfx] played the Hero: hand %s" % str(arena.hands[0]))
	if _at(2.08):
		dfx_card = _dfx_card_of(int(arena.hand_ids[0].back()))
		print("[drawfx] drawn card in flight: face down %s, state %d" % [str(dfx_card.arrive_back), int(dfx_card.state)])
	if dfx_card != null and is_instance_valid(dfx_card) and dfx_card.land_flash > 0.0 and dfx_card.land_flash > DDHandCard.LAND_FLASH - 0.02:
		print("[drawfx] t%.2f landed: face up %s, flash %.2f" % [elapsed, str(not dfx_card.arrive_back), dfx_card.land_flash])
	if _at(3.2):
		dfx_neko = arena.spawn_troop("neko", 0, arena.tile_center(9.5, 24.5))
		dfx_neko.deploy_timer = 0.0
		dfx_neko.speed = 0.0
		dfx_neko.ritual_cd = 0.0
	if _at(3.4):
		for n in arena.get_children():
			if n.get_script() == load("res://scripts/pentagram.gd"):
				print("[drawfx] pentagram %.2f tiles ahead of her, %.2f across" % [
					(n.position.x - dfx_neko.position.x) / float(arena.TILE), (n.position.y - dfx_neko.position.y) / float(arena.TILE)])


## The star side towers, one burning, each with its hitbox (radius_t) drawn as
## a ring over it: the ring should come close to the tips without reaching.
func _towerstar_steps() -> void:
	if _at(0.3):
		for tw in arena.towers:
			if not tw.crown:
				var ring := HitRing.new()
				ring.r = float(tw.radius_t) * float(arena.TILE)
				ring.position = tw.position
				ring.z_index = 20
				arena.add_child(ring)
				print("[towerstar] hitbox %.2f tiles, tips %.2f tiles" % [float(tw.radius_t), DDTower.STAR_TIP_T])
		arena.towers[1].apply_burn(40.0)


class HitRing extends Node2D:
	var r := 0.0
	func _draw() -> void:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1, 1, 0.2, 0.9), 1.5, true)


## A full hand draws: the leftmost card is kicked off over the DISCARD arrow and
## falls away. Also shows the tall grey NEXT card and the small faces' attack
## names (two-attack cards in two columns).
func _boot_steps() -> void:
	if _at(1.6):
		arena.hands[0] = ["fu", "chicken", "mantis", "phalanx", "neko", "gilgamesh"]
		arena.queues[0] = ["frog", "aphid", "slate"]
		arena.hand_ids[0] = []
		arena.queue_ids[0] = []
		arena.draw_timer[0] = 99.0
	if _at(2.0):
		arena.draw_card(0)
		var boots := 0
		for n in arena.panels[0].get_children():
			if n is HandPanel.Boot:
				boots += 1
		print("[boot] drew: hand %s, cards in flight %d" % [str(arena.hands[0]), boots])


## Three bridges (run with --bridges=3): which tiles are water, which bridge each
## column crosses by, and a troop from each lane walking over.
var b3_units: Array = []
func _bridges3_steps() -> void:
	if _at(0.3):
		var row := ""
		for x in arena.GRID_W:
			row += "~" if arena.is_water(Vector2i(x, 14)) else "#"
		var near := []
		for x in arena.GRID_W:
			near.append(arena.nearest_bridge_col(x))
		print("[bridges3] bridges %s  row 14: %s" % [str(arena.bridges), row])
		print("[bridges3] nearest by column: %s" % str(near))
		for x in [1.5, 5.5, 9.5, 12.5, 16.5]:
			var u: Node = arena.spawn_troop("militia", 0, arena.tile_center(x, 20.5))
			u.deploy_timer = 0.0
			b3_units.append(u)
	if _at(8.5):
		for u in b3_units:
			if is_instance_valid(u):
				var t: Vector2i = arena.tile_of(u.position)
				print("[bridges3] militia now at col %.2f row %d (crossed %s)" % [arena.col_f(u.position), t.y, str(t.y < arena.RIVER_TOP)])


## Penny: a flyer outranks a nearer ground troop, she reaches it only by
## leaping (from 2.5 tiles, never a swipe), with a cooldown between leaps; and
## with only an enemy building near she attacks it. Run with --bots=off.
var pa_penny: Node = null
var pa_bird: Node = null
var pa_ground: Node = null
var pa_leaps := 0
var pa_was_jumping := false
var pa_snow: Node = null
func _pennyair_steps() -> void:
	if _at(0.3):
		pa_penny = arena.spawn_troop("penny", 0, arena.tile_center(9.5, 19.5))
		pa_penny.deploy_timer = 0.0
		pa_ground = _aa_dummy(arena.tile_center(9.5, 17.8))
		pa_bird = _aa_dummy(arena.tile_center(6.5, 16.5))
		pa_bird.flying = true
		print("[pennyair] ground dummy %.1f tiles away, flyer %.1f tiles away" % [
			arena.tiles_between(pa_penny.position, pa_ground.position), arena.tiles_between(pa_penny.position, pa_bird.position)])
	if pa_penny != null and is_instance_valid(pa_penny):
		if pa_penny.jumping and not pa_was_jumping:
			pa_leaps += 1
			var victim: Node = pa_penny.jump_victim
			print("[pennyair] t%.2f leap %d at the %s, from %.2f tiles" % [elapsed, pa_leaps,
				"flyer" if victim == pa_bird else ("ground dummy" if victim == pa_ground else "something else"),
				arena.tiles_between(pa_penny.position, victim.position) if victim != null else -1.0])
		pa_was_jumping = pa_penny.jumping
	if _at(4.0):
		print("[pennyair] t4: flyer took %.0f, ground dummy took %.0f, swipes on flyer none (all damage in leaps of 20)" % [
			99999.0 - pa_bird.hp, 99999.0 - pa_ground.hp])
		pa_bird.take_damage(999999.0, pa_bird.position)
		pa_ground.take_damage(999999.0, pa_ground.position)
		pa_snow = arena.spawn_troop("snowman", 1, pa_penny.position + Vector2(2.0 * float(arena.TILE), 0.0), true)
		pa_snow.deploy_timer = 0.0
		pa_snow.max_hp = 9999.0
		pa_snow.hp = 9999.0
		pa_snow.lifetime = 0.0
	if _at(7.0):
		print("[pennyair] t7: enemy building took %.0f (Penny targets buildings now: %s)" % [
			9999.0 - pa_snow.hp, str(pa_penny.target == pa_snow)])


## The Snowball: cast mid-board it rolls 8 tiles, straight over the river, and
## bursts; the roll hits each enemy once (a dummy it shoves ahead is not rolled
## over twice), and the burst still reaches what the roll shoved. Also the
## starter deck and the draft pool. Run with --bots=off.
var sn_ball: Node = null
var sn_land := Vector2.ZERO
var sn_last := Vector2.ZERO
var sn_dummies: Array = []
var sn_log: Array = []
func _snowroll_steps() -> void:
	if _at(0.3):
		print("[snowroll] starter %s" % str(Run.STARTER_DECK))
		print("[snowroll] draft pool %d cards: %s" % [Run.draft_pool().size(), str(Run.draft_pool())])
		sn_land = arena.tile_center(9.5, 19.5)
		sn_ball = arena.spawn_troop("snowball", 0, sn_land)
		for row in [17.5, 14.5]:
			var d: Node = _aa_dummy(arena.tile_center(9.5, row))
			d.max_hp = 9999.0
			d.hp = 9999.0
			sn_dummies.append(d)
			sn_log.append([])
	if sn_ball != null and is_instance_valid(sn_ball) and not sn_ball.done:
		sn_last = sn_ball.position
	if _at(3.5):
		print("[snowroll] gone %s; last seen %.2f tiles from where it landed, at row %.1f (river rows 14-15)" % [
			str(not is_instance_valid(sn_ball)), absf(sn_last.x - sn_land.x) / float(arena.TILE),
			float(arena.GRID_H) - (sn_last.x - arena.ORIGIN.x) / float(arena.TILE)])
	# every change in a dummy's HP is one hit
	for i in sn_dummies.size():
		var d: Node = sn_dummies[i]
		if is_instance_valid(d) and d.hp < 9999.0 - _sn_sum(sn_log[i]) - 0.01:
			var amount: float = 9999.0 - _sn_sum(sn_log[i]) - d.hp
			sn_log[i].append(snappedf(amount, 0.1))
	if _at(4.5):
		for i in sn_dummies.size():
			print("[snowroll] dummy %d (started on row %s): hits %s" % [i, ["17.5", "14.5"][i], str(sn_log[i])])


func _sn_sum(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += float(v)
	return s


## Shiesty takes his numbers from card_db; the spider never webs water (the
## bridge decks' outer half tiles included). Run with --bots=off.
func _shiestyweb_steps() -> void:
	if _at(0.3):
		arena.ability[0] = "shiesty"
		arena.gold[0] = 10.0
		arena.ability_cd[0] = 0.0
		arena.use_ability(0)
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "shiesty":
				var d: Dictionary = DDCard.get_card("shiesty")
				print("[shiestyweb] Shiesty hp %.0f / %.0f (card %s), speed %.2f tiles/s (card %s), dmg %.0f (card %s)" % [
					u.hp, u.max_hp, str(d["hp"]), u.speed_px / float(arena.TILE), str(d["speed"]), u.dmg, str(d["dmg"])])
	if _at(0.6):
		arena.start_spider_encounter()
		var bx: float = float(arena.BRIDGE_COL_A)
		var water_webs := 0
		var deck_webs := 0
		for off in [1.3, -1.3, 0.0]:
			var h: Node = arena.spawn_troop("hero", 0, arena.tile_center(bx + off, 17.5), true)
			h.deploy_timer = 0.0
			h.position = arena.tile_center(bx + off, 17.5)
			arena.spider.webs.clear()
			arena.spider.lay_web_ahead_of(h)
			for t in arena.spider.webs.keys():
				if arena.is_water(t):
					water_webs += 1
				elif t.y >= arena.RIVER_TOP and t.y <= arena.RIVER_BOTTOM:
					deck_webs += 1
			print("[shiestyweb] web ahead of a troop at bridge %+.1f: tiles %s" % [off, str(arena.spider.webs.keys())])
			h.take_damage(99999.0, h.position)
		print("[shiestyweb] web tiles on water %d (expect 0), on the bridge's whole tiles %d" % [water_webs, deck_webs])


## The whelp lock and the wider bridges. Playing the Obsidian Whelp puts a
## Magma Whelp in the hand that cannot be played for 3 s (a try is refused),
## then can. The bridge deck is 3 tiles wide: its outer half tiles are walkable
## but cannot be played on, and a troop shoved out to the deck's edge keeps
## crossing instead of turning back. Run with --bots=off.
var lb_hero: Node = null
var lb_row0 := 0.0
func _lockbridge_steps() -> void:
	if _at(0.6):
		arena.hands[0] = ["obsidian", "frog", "fu"]
		arena.queues[0] = ["idol", "wu"]
		arena.hand_ids[0] = []
		arena.queue_ids[0] = []
		arena.gold[0] = 10.0
		arena.deploy(0, 0, arena.tile_center(9.5, 24.5))
		print("[lockbridge] played Obsidian: hand %s, slot 0 locked %s, %.2f s left" % [
			str(arena.hands[0]), str(arena.card_locked(0, 0)), arena.lock_left(arena.hand_id(0, 0))])
		arena.gold[0] = 10.0
		arena.deploy(0, 0, arena.tile_center(9.5, 24.5))
		print("[lockbridge] tried the Magma Whelp at once: hand %s (expect magma still there)" % str(arena.hands[0]))
	if _at(3.7):
		arena.gold[0] = 10.0
		arena.deploy(0, 0, arena.tile_center(9.5, 24.5))
		print("[lockbridge] t3.7 played it: hand %s, new obsidian locked %s" % [str(arena.hands[0]), str(arena.card_locked(0, 0))])
		var bx: float = float(arena.BRIDGE_COL_A)
		var row := 14.5
		var probes: Array = []
		for off in [-1.6, -1.4, -0.5, 0.5, 1.4, 1.6]:
			probes.append("%+.1f:%s" % [off, str(arena.on_bridge_deck(arena.tile_center(bx + off, row)))])
		print("[lockbridge] on the deck at bridge middle + (tiles): %s (expect only +-1.6 false)" % ", ".join(probes))
		print("[lockbridge] outer half tile (col %d) is water %s, can deploy %s; deck tile (col %d) can deploy %s" % [
			int(bx) - 2, str(arena.is_water(Vector2i(int(bx) - 2, 15))),
			str(arena.can_deploy(0, "hero", arena.tile_center(bx - 1.75, 15.5))),
			int(bx) - 1, str(arena.can_deploy(0, "hero", arena.tile_center(bx - 0.5, 15.5)))])
		lb_hero = arena.spawn_troop("hero", 0, arena.tile_center(bx + 1.3, 15.6), true)
		lb_hero.deploy_timer = 0.0
		lb_hero.position = arena.tile_center(bx + 1.3, 15.6)
		lb_row0 = 15.6
	if _at(4.6) and lb_hero != null and is_instance_valid(lb_hero):
		var row_now: float = float(arena.GRID_H) - (lb_hero.position.x - arena.ORIGIN.x) / arena.TILE
		print("[lockbridge] hero started at the deck edge (+1.3) on row %.1f; 0.9 s later row %.2f, col %.2f (expect the row to drop: still crossing)" % [
			lb_row0, row_now, arena.col_f(lb_hero.position)])


## The three-phase clock. "phases": single (90 s) -> double -> sudden death,
## gold x1 / x2 / x4, and the next tower to fall ends it. "phaselead": a tower
## lead at the end of double gold wins there. "phaseelite": the spider's clock
## (120 s single) goes to sudden death even with a side tower down, and running
## out is the boss's win. Troops and a Snowman sit mid-board so the shots show
## the letters over troops, under buildings. Run with --bots=off.
func _ph_state(label: String) -> void:
	print("[%s] %s: phase %d, %.1f s left, lengths %s, gold rate %.2f, over %s, winner %d" % [
		scenario, label, int(arena.phase), arena.match_time_left, str(arena.phase_lengths()),
		arena.gold_rate_now(), str(arena.match_over), int(arena.winner)])


func _ph_side_tower(team: int) -> Node:
	for t in arena.towers:
		if is_instance_valid(t) and int(t.team) == team and t is DDTower and not bool(t.crown) and not t.dead:
			return t
	return null


func _phases_steps() -> void:
	if _at(0.2):
		var lens: Array = []
		for f in Run.ACT.size():
			var e: Dictionary = Run.ACT[f]
			lens.append("%s %ds" % [String(e["name"]), int(arena.SINGLE_TIME + arena.SINGLE_STEP * Run.battles_before(f)) if String(e.get("type", "")) == "battle" else int(arena.ELITE_SINGLE)])
		print("[%s] single gold per run fight: %s" % [scenario, ", ".join(lens)])
		if scenario == "phaseelite":
			arena.start_spider_encounter()
		_ph_state("start")
		for i in 3:
			var u: Node = arena.spawn_troop("militia", 0, arena.board_rect().get_center() + Vector2(-60.0 + 60.0 * i, 30.0))
			u.deploy_timer = 0.0
			u.speed = 0.0
		var sm: Node = arena.spawn_troop("snowman", 0, arena.board_rect().get_center() + Vector2(-130.0, -10.0))
		sm.deploy_timer = 0.0
	if _at(0.6):
		if scenario == "phaselead":
			_ph_side_tower(1).take_damage(99999.0, Vector2.ZERO)
		if scenario == "phaseelite":
			_ph_side_tower(0).take_damage(99999.0, Vector2.ZERO)
		arena.match_time_left = 0.05
	if _at(0.8):
		_ph_state("after single")
		arena.match_time_left = 0.05
	if _at(1.0):
		_ph_state("after double")
	if _at(1.6) and scenario == "phases":
		_ph_side_tower(1).take_damage(99999.0, Vector2.ZERO)
	if _at(1.8):
		if scenario == "phaseelite":
			arena.match_time_left = 0.05
	if _at(2.1):
		_ph_state("end")
		print("[%s] banner: %s" % [scenario, arena.banner_text])


## The Ballista: wheeled up the left lane, it should set down on the bridge and
## shoot the enemy's side tower from out of that tower's reach. A Militia goes
## with it for the picture. Then the run timeout rule (level towers = a loss).
## Run with --bots=off.
var bl_unit: Node = null
var bl_tower: Node = null
var bl_hp := 0.0
var bl_stop_logged := false
func _ballista_steps() -> void:
	if _at(0.3):
		bl_unit = arena.spawn_troop("ballista", 0, arena.tile_center(4.5, 22.5))
		bl_unit.deploy_timer = 0.0
		var mil: Node = arena.spawn_troop("militia", 0, arena.tile_center(7.5, 22.5))
		mil.deploy_timer = 0.0
		for t in arena.towers:
			if is_instance_valid(t) and int(t.team) == 1 and not bool(t.crown) and arena.tile_of(t.position).x < 9:
				bl_tower = t
		bl_hp = bl_tower.hp
		print("[ballista] is_building %s, stationary %s, reach %.1f, enemy side tower reach %.0f" % [
			str(bl_unit.is_building()), str(bl_unit.stationary), bl_unit.reach, bl_tower.reach])
	if bl_unit != null and is_instance_valid(bl_unit) and not bl_stop_logged and bl_unit.state == DDUnit.S.ATTACK:
		bl_stop_logged = true
		print("[ballista] t%.1f set down at tile %s, %.2f tiles from the tower's centre; tower can reach %s" % [
			elapsed, str(arena.tile_of(bl_unit.position)), arena.tiles_between(bl_unit.position, bl_tower.position),
			str(arena.tiles_between(bl_unit.position, bl_tower.position) <= float(bl_tower.reach))])
	if _at(30.0):
		print("[ballista] t30: tower took %.0f, ballista hp %.0f / %.0f" % [bl_hp - bl_tower.hp, bl_unit.hp, bl_unit.max_hp])
	if _at(30.5):
		Run.active = true
		arena._finish_on_towers()
		print("[ballista] run timeout with towers level: winner %d, \"%s\"" % [arena.winner, arena.banner_text])


## Presence: Rat Skeletons, Meerkats and ants hold no ground; a Hero does.
## Each is spawned alone in the band and the team's held tiles are counted.
func _presence_count() -> int:
	return (arena.control[0] as Array).count(true)


func _nopres_steps() -> void:
	var kinds := ["ratbones", "meerkats", "ant", "hero"]
	for i in kinds.size():
		var t0: float = 0.3 + 0.4 * float(i)
		if _at(t0):
			for u in arena.units.duplicate():
				if is_instance_valid(u) and int(u.team) == 0:
					u.take_damage(99999.0, u.position)
		if _at(t0 + 0.05):
			var u: Node = arena.spawn_troop(String(kinds[i]), 0, arena.tile_center(9.5, 16.5))
			for v in arena.units:
				if is_instance_valid(v) and String(v.kind) == String(kinds[i]):
					v.deploy_timer = 0.0
					v.speed = 0.0
		if _at(t0 + 0.3):
			print("[nopres] %s on the board: team 0 holds %d tiles" % [kinds[i], _presence_count()])


## Tower reach (side 7, crown 8), the elite pick per run seed, and the elite
## clock: starting the spider sets 120 s single / 60 double / 30 sudden death.
func _elitetime_steps() -> void:
	if _at(0.3):
		var r: Array = []
		for t in arena.towers:
			if is_instance_valid(t) and int(t.team) == 0:
				r.append("%s %.0f" % ["crown" if bool(t.crown) else "side", float(t.reach)])
		print("[elitetime] team 0 tower reach: %s" % ", ".join(r))
		var keep_seed: int = Run.run_seed
		var picks: Array = []
		for sd in 10:
			Run.run_seed = sd
			var e: Dictionary = Run.encounter_at(2)
			picks.append("%d:%s" % [sd, String(e.get("name", ""))])
		var krakens := 0
		for sd in 200:
			Run.run_seed = sd
			if String(Run.encounter_at(2).get("elite", "")) == "kraken":
				krakens += 1
		Run.run_seed = keep_seed
		print("[elitetime] elite fight by run seed: %s" % ", ".join(picks))
		print("[elitetime] over 200 seeds: %d Kraken, %d Matriarch" % [krakens, 200 - krakens])
		arena.start_spider_encounter()
		print("[elitetime] spider started: phases %s (expect 120 / 60 / 30), elite %s; name %s, pool %s poison every %s s" % [
			str(arena.phase_lengths()), str(arena.elite_fight), DDCard.pretty("spider"),
			str(arena.spider.cfg["pool_poison"]), str(arena.spider.cfg["pool_every"])])


## The Elf Archer: shoots a ground dummy and a flyer from 5.5 tiles. Run with
## --bots=off.
var el_elf: Node = null
var el_dummy: Node = null
var el_bird: Node = null
func _elf_steps() -> void:
	if _at(0.3):
		el_elf = arena.spawn_troop("elf", 0, arena.tile_center(9.5, 24.5))
		el_dummy = _aa_dummy(arena.tile_center(9.5, 18.6))
		el_bird = _aa_dummy(arena.tile_center(6.5, 18.6))
		el_bird.flying = true
	if _at(4.0):
		print("[elf] starter deck has her: %s; elf at %.1f tiles from the dummy" % [
			str(Run.STARTER_DECK.has("elf")), arena.tiles_between(el_elf.position, el_dummy.position)])
		print("[elf] dummy took %d, flyer took %d (20 an arrow)" % [int(99999.0 - el_dummy.hp), int(99999.0 - el_bird.hp)])


## Small rule checks: Hero / Hot Chicken / Snowman draw a card when played and
## leave the draw clock alone (apart from the usual gold pull); the
## Nekomancer's first ritual 1.5 s after she is played; the Wolf Pack's bite
## rate does not drop as wolves die; the run's starter deck. Run with --bots=off.
var tw_neko: Node = null
var tw_neko_at := -1.0
var tw_wolves: Array = []
var tw_dummy: Node = null
var tw_hp := 0.0
func _tweaks_steps() -> void:
	if _at(0.3):
		print("[tweaks] opening hands %d and %d (expect %d), hand max %d" % [arena.hands[0].size(),
			arena.hands[1].size(), int(arena.OPENING_HAND), int(arena.HAND_MAX)])
		arena.hands[0] = ["frog", "fu", "aphid", "idol", "wu", "slate"]
		arena.queues[0] = ["troll", "hero"]
		arena.hand_ids[0] = []
		arena.queue_ids[0] = []
		arena.draw_card(0)
		print("[tweaks] a draw into a full hand of 6: hand %d cards %s" % [arena.hands[0].size(), str(arena.hands[0])])
		for kind in ["hero", "chicken", "snowman", "fu"]:
			arena.hands[0] = [kind, "frog", "aphid"]
			arena.queues[0] = ["idol", "wu", "slate"]
			arena.hand_ids[0] = []
			arena.queue_ids[0] = []
			arena.gold[0] = 10.0
			arena.draw_timer[0] = 7.0
			arena.deploy(0, 0, arena.tile_center(9.5 - float(["hero", "chicken", "snowman", "fu"].find(kind)) * 2.0, 24.5))
			print("[tweaks] played %s: hand %s, deck %s, draw clock %.2f (expect 7.00 for the drawing cards, 7 less %d for others)" % [
				kind, str(arena.hands[0]), str(arena.queues[0]), float(arena.draw_timer[0]), DDCard.cost(kind)])
		print("[tweaks] starter deck %s" % str(Run.STARTER_DECK))
		tw_neko = arena.spawn_troop("neko", 0, arena.tile_center(3.5, 26.5))
		tw_neko_at = elapsed
	if tw_neko != null and is_instance_valid(tw_neko) and tw_neko_at >= 0.0 and tw_neko.cloak_t > 0.0:
		print("[tweaks] Nekomancer's first ritual %.2f s after she was played (expect 1.50)" % (elapsed - tw_neko_at))
		tw_neko_at = -1.0
	for tt in [1.95, 3.0, 4.9, 8.9]:
		if _at(tt):
			# clear the troops played above (and the rats), so only wolves bite
			for u in arena.units.duplicate():
				if is_instance_valid(u) and not u.dead and int(u.team) == 0 and String(u.kind) != "wolves":
					u.take_damage(99999.0, u.position)
	if _at(2.0):
		# out of every tower's range, so only the wolves hurt it
		tw_dummy = _aa_dummy(arena.tile_center(9.5, 17.5))
		arena.spawn_troop("wolves", 0, arena.tile_center(9.5, 21.5))
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "wolves":
				u.deploy_timer = 0.0
				tw_wolves.append(u)
	if _at(5.0):
		tw_hp = tw_dummy.hp
	if _at(9.0):
		print("[tweaks] 4 wolves: %d bites in 4 s" % int((tw_hp - tw_dummy.hp) / 10.0))
		tw_wolves[0].take_damage(999.0, tw_wolves[0].position)
		tw_wolves[1].take_damage(999.0, tw_wolves[1].position)
		tw_hp = tw_dummy.hp
	if _at(13.0):
		print("[tweaks] 2 wolves: %d bites in 4 s (expect about the same)" % int((tw_hp - tw_dummy.hp) / 10.0))


## The Mated Mantises: he lands on the tile, she 3.5 tiles behind; he claws, she
## throws; at 25 % she leaps on him, he loses his head (out of `units`, a
## corpse for a while), she heals 50 % up to 125 % of her max, rages and claws
## up close. Then a second pair where she is shot down in mid-leap: he must be
## let go. Run with --bots=off.
var mt_m: Node = null
var mt_f: Node = null
var mt_dummy: Node = null
func _mt_pair(at: Vector2) -> void:
	mt_m = arena.spawn_troop("mantis", 0, at)
	for u in arena.units:
		if is_instance_valid(u) and String(u.kind) == "mantisf" and u.mate == mt_m:
			mt_f = u
	mt_m.deploy_timer = 0.0
	mt_f.deploy_timer = 0.0


func _mantis_steps() -> void:
	if _at(0.3):
		_mt_pair(arena.tile_center(9.5, 21.5))
		var tm: Vector2i = arena.tile_of(mt_m.position)
		print("[mantis] male tile %s, female tile %s, apart %.2f tiles (expect 3.5 behind)" % [
			str(tm), str(arena.tile_of(mt_f.position)), arena.tiles_between(mt_m.position, mt_f.position)])
		mt_dummy = _aa_dummy(arena.tile_center(9.5, 19.3))
	if _at(2.5):
		print("[mantis] t2.5 dummy took %d (male claws + female scythes); male state %d, female state %d" % [
			int(99999.0 - mt_dummy.hp), int(mt_m.state), int(mt_f.state)])
		mt_m.take_damage(mt_m.max_hp * 0.7, mt_m.position)
		print("[mantis] male at %.0f / %.0f: female devour phase %d (expect 0)" % [mt_m.hp, mt_m.max_hp, mt_f.devour_phase])
	if _at(2.7):
		mt_m.take_damage(mt_m.max_hp * 0.06, mt_m.position)
		print("[mantis] male at %.0f: female hp %.0f / %.0f" % [mt_m.hp, mt_f.hp, mt_f.max_hp])
	if _at(2.8):
		print("[mantis] t2.8 devour phase %d, male held %s invincible %s" % [mt_f.devour_phase, mt_m.held, mt_m.invincible])
		mt_m.take_damage(500.0, mt_m.position)
		print("[mantis]   a 500 hit on him mid-leap: male hp %.0f dead %s (expect untouched)" % [mt_m.hp, mt_m.dead])
	if _at(3.5):
		print("[mantis] t3.5 male dead %s headless %s in units %s; female hp %.0f / %.0f (expect 150), rage %.1f s, speed %.3f, devoured %s" % [
			mt_m.dead, mt_m.headless, arena.units.has(mt_m), mt_f.hp, mt_f.max_hp, mt_f.rage_t, mt_f.speed, mt_f.devoured])
		print("[mantis]   female to male distance %.2f tiles" % arena.tiles_between(mt_f.position, mt_m.position))
		mt_dummy.position = mt_f.position + Vector2(-1.2 * float(arena.TILE), 0.0)
		mt_dummy.hp = 99999.0
	if _at(4.6):
		print("[mantis] t4.6 dummy beside her took %d (claws 18 each, 0.8 s apart in rage); claw shown %s" % [
			int(99999.0 - mt_dummy.hp), str(mt_f.claw_t > 0.0 or mt_f.attack_stretch > 0.0)])
	if _at(6.2):
		print("[mantis] t6.2 corpse still drawn %s (expect gone after 3 s), rage %.1f, speed %.2f" % [
			str(is_instance_valid(mt_m)), mt_f.rage_t, mt_f.speed])
		mt_dummy.queue_free()
		_mt_pair(arena.tile_center(4.5, 22.5))
	if _at(6.6):
		mt_m.take_damage(mt_m.max_hp * 0.8, mt_m.position)
	if _at(6.7):
		print("[mantis] pair 2: devour phase %d; shooting her down mid-leap" % mt_f.devour_phase)
		mt_f.take_damage(9999.0, mt_f.position)
	if _at(6.8):
		print("[mantis] pair 2: female dead %s; male held %s invincible %s dead %s (expect false false false)" % [
			str(not is_instance_valid(mt_f) or mt_f.dead), mt_m.held, mt_m.invincible, mt_m.dead])


## Card cycling: Penny gives Pen and goes to the back of the deck; Pen played is
## gone; the whelps swap in the hand every play and never enter the deck. Then
## the draft pool, and Esc pause (this node keeps running while paused). Run
## with --bots=off.
var cc_clock := 0.0
func _cc_state(label: String) -> void:
	print("[cardcycle] %s: hand %s | deck %s" % [label, str(arena.hands[0]), str(arena.queues[0])])


func _cardcycle_steps() -> void:
	var at: Vector2 = arena.tile_center(9.5, 24.5)
	if _at(0.3):
		process_mode = Node.PROCESS_MODE_ALWAYS
		arena.hands[0] = ["penny", "obsidian", "frog", "troll"]
		arena.queues[0] = ["fu", "idol"]
		arena.hand_ids[0] = []
		arena.queue_ids[0] = []
		arena.gold[0] = 10.0
		_cc_state("start")
		arena.deploy(0, 0, at)
		_cc_state("played Penny (expect pen in slot 0, penny at the deck's end)")
		arena.gold[0] = 10.0
		arena.deploy(0, 0, at)
		_cc_state("played Pen (expect it gone from hand and deck)")
		arena.gold[0] = 10.0
		arena.deploy(0, 0, at)
		_cc_state("played Obsidian (expect magma in slot 0, deck unchanged)")
		arena.gold[0] = 10.0
		arena.deploy(0, 0, at)
		_cc_state("played Magma (expect obsidian back in slot 0, deck unchanged)")
		arena.gold[0] = 10.0
		arena.deploy(0, 0, at)
		_cc_state("played Obsidian again (expect magma)")
		var pool: Array = Run.draft_pool()
		var bad: Array = Run.STARTER_DECK.filter(func(k): return pool.has(k))
		var missing: Array = DDCard.ORDER.filter(func(k): return not pool.has(k) and not Run.STARTER_DECK.has(k))
		print("[cardcycle] draft pool %d of %d cards, starter cards in it: %s, non-starter cards missing: %s" % [
			pool.size(), DDCard.ORDER.size(), str(bad), str(missing)])
	if _at(0.6):
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		arena.get_viewport().push_input(esc, true)
	if _at(0.7):
		cc_clock = float(arena.match_time_left)
		print("[cardcycle] after Esc: paused=%s menu=%s" % [get_tree().paused, arena.pause_layer != null])
	if _at(1.7):
		print("[cardcycle] 1 s paused: clock moved %.3f s (expect 0)" % (cc_clock - float(arena.match_time_left)))
		var esc := InputEventKey.new()
		esc.keycode = KEY_ESCAPE
		esc.pressed = true
		arena.get_viewport().push_input(esc, true)
	if _at(1.8):
		cc_clock = float(arena.match_time_left)
		print("[cardcycle] after second Esc: paused=%s menu=%s" % [get_tree().paused, arena.pause_layer != null])
	if _at(2.3):
		print("[cardcycle] 0.5 s running: clock moved %.2f s" % (cc_clock - float(arena.match_time_left)))


## Duplicate cards: a deck of repeats deals a hand with two of a card; each copy
## has its own id, cycles back as itself, keeps its own Firebolt charges, and a
## Penny turning into Pen leaves the other Penny alone. Then the draw clock:
## spending gold pulls it forward a second per gold, a big spend carries over,
## and the debug key gives 2 gold and a card. Run with --bots=off.
func _dupes_ids() -> String:
	var out: Array = []
	for i in arena.hands[0].size():
		out.append("%s#%d" % [arena.hands[0][i], arena.hand_id(0, i)])
	return str(out)


func _dupes_steps() -> void:
	var pos: Vector2 = arena.tile_center(9.5, 24.5)
	if _at(0.3):
		arena.deck_lists[0] = ["firebolt", "firebolt", "penny", "penny", "frog", "frog", "hero", "hero"]
		arena._build_decks(11)
		# a fixed opening, so the checks below do not depend on the shuffle
		arena.hands[0] = ["firebolt", "firebolt", "penny", "penny"]
		arena.queues[0] = ["frog", "frog", "hero", "hero"]
		arena.hand_ids[0] = []
		arena.queue_ids[0] = []
		arena.gold[0] = 10.0
		print("[dupes] hand %s" % _dupes_ids())
	if _at(0.5):
		var a: int = arena.hand_id(0, 0)
		var b: int = arena.hand_id(0, 1)
		arena.deploy(0, 0, pos)
		print("[dupes] cast firebolt #%d once: charges #%d=%d #%d=%d (expect 1, 2)" % [a, a,
			arena.charges_of(0, "firebolt", a), b, arena.charges_of(0, "firebolt", b)])
		var p1: int = arena.hand_id(0, 2)
		arena.gold[0] = 10.0
		arena.deploy(0, 2, pos)
		print("[dupes] played penny #%d -> hand %s (the other penny stays; pen is new)" % [p1, _dupes_ids()])
		print("[dupes] deck back %s ids %s" % [str(arena.queues[0]), str(arena.queue_ids[0])])
	if _at(1.2):
		arena.draw_timer[0] = 16.0
		arena.gold[0] = 10.0
		var before: int = arena.hands[0].size()
		arena.deploy(0, 3, pos)
		print("[dupes] spent 3 (penny): draw_timer 16 -> %.1f (expect 13), hand %d -> %d" % [
			arena.draw_timer[0], before, arena.hands[0].size()])
		arena.draw_timer[0] = 4.0
		arena.spend_gold_draw(0, 10.0)
		fx_mark = Vector2(float(arena.hands[0].size()), 0)
	if _at(1.3):
		print("[dupes] spend 10 with 4 s left: one draw (hand %d -> %d), clock carried to %.1f (expect ~10)" % [
			int(fx_mark.x), arena.hands[0].size(), arena.draw_timer[0]])
		var g0: float = arena.gold[0]
		var h0: int = arena.hands[0].size()
		arena._debug_gold(0, "")
		print("[dupes] debug key: gold %.1f -> %.1f, hand %d -> %d" % [g0, arena.gold[0], h0, arena.hands[0].size()])
		print("[dupes] hand %s" % _dupes_ids())


## The run loop, driven by script across scene reloads (run with --run=7
## --bots=off): fight 1 is won with the commander cut to 180; fight 2 opens with
## the commander still at 180 and the side towers full, and is won; fight 3 is
## the spider elite, lost; the result screen then starts a fresh run.
func _run_steps() -> void:
	var run = arena.get_node_or_null("/root/Run")
	if run == null or not run.active:
		if _at(0.3):
			print("[run] no run active (pass --run)")
		return
	if _at(0.3):
		var kings := []
		var sides := []
		for t in arena.towers:
			if is_instance_valid(t) and int(t.team) == 0:
				if bool(t.get("crown")):
					kings.append(int(t.hp))
				else:
					sides.append(int(t.hp))
		print("[run] fight %d (%s): commander %s side towers %s | abilities %s | hand %s | enemy deck %d" % [
			run.floor_index + 1, String(run.encounter()["name"]), str(kings), str(sides), str(arena.ability),
			str(arena.hands[0]), arena.hands[1].size() + arena.queues[1].size()])
	if _at(0.6):
		var mine: Node = arena._king_of(0)
		if run.floor_index == 0:
			mine.take_damage(70.0, mine.position)
		var foe: Node = arena._king_of(1)
		if run.floor_index < 2:
			foe.take_damage(99999.0, foe.position)
		else:
			print("[run]   enemy side is the spider: %s" % str(arena.spider != null and is_instance_valid(arena.spider)))
			mine.take_damage(99999.0, mine.position)
		print("[run]   result: %s  run over=%s won_run=%s commander now %.0f" % [
			str(run.last), str(run.over), str(run.won_run), run.commander_hp])
	if _at(0.9):
		if run.run_seed != 7:
			# the fresh run the result screen started after the loss: stop here
			print("[run] new run after the loss: fight %d commander %.0f history %d seed changed=%s deck %d" % [
				run.floor_index + 1, run.commander_hp, run.history.size(), str(run.run_seed != 7), run.deck.size()])
			return
		if not run.reward_pending():
			arena.continue_run()
			return
		var before: int = run.floor_index
		arena.continue_run()
		print("[run]   reward pending: screen up=%s choices %s; Enter does not skip it (still fight %d: %s)" % [
			str(arena.reward_screen != null and is_instance_valid(arena.reward_screen)), str(run.reward_choices()),
			run.floor_index + 1, str(run.floor_index == before)])
	if _at(2.3) and run.run_seed == 7 and run.reward_pending():
		var rs: Node = arena.reward_screen
		var n0: int = run.deck.size()
		if run.floor_index == 0:
			var want: String = String(rs.choices[1])
			rs.pick(1)
			print("[run]   picked %s: deck %d -> %d, last card %s" % [want, n0, run.deck.size(), str(run.deck[-1])])
		else:
			rs.skip()
			print("[run]   skipped: deck %d -> %d" % [n0, run.deck.size()])


func _lani_clear_except(keep: Array) -> void:
	for u in arena.units.duplicate():
		if is_instance_valid(u) and not keep.has(u):
			u.take_damage(99999.0, u.position)


func _toss_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.2):
		arena.ability[0] = "shiesty"
		arena.ability[1] = "shiesty"
		arena.gold[0] = 10.0
		arena.ability_cd[0] = 0.0
		var king: Node = arena._king_of(0)
		var fwd := Vector2(king.face_dir(), 0.0)
		lani_marks = [_lani_dummy("hero", king.position + fwd * 4.0 * t)]
		for k in ["laniakea", "femme"]:
			var u = arena.spawn_troop(k, 0, king.position + fwd * 2.0 * t + Vector2(0, (1.5 if k == "femme" else -1.5) * t), true)
			u.deploy_timer = 0.0
			u.speed = 0.0
		print("[toss] goblin=%s face=%.0f" % [str(king.is_goblin()), king.face_dir()])
	if _at(0.9):
		var king2: Node = arena._king_of(0)
		print("[toss] t0.9 hero hp=%d (spears land for 12) throw_t=%.2f ready=%s" % [
			int(lani_marks[0].hp), king2.throw_t, str(arena.ability_ready(0))])
	if _at(1.0):
		print("[toss] ability used=%s" % str(arena.use_ability(0)))
	if _at(1.1) or _at(1.25) or _at(1.5):
		var king3: Node = arena._king_of(0)
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "shiesty":
				print("[toss] t%.2f toss_t=%.2f shiesty clock=%.2f real=%s drawn offset=%s" % [
					elapsed, king3.toss_t, u.clock, str((u.position - king3.position).round()), str(u._launch_offset().round())])


## In-Ovo Machine timing: every hatch and the machine's own death, in seconds
## since it was deployed (expect 1, 13, 25, 37, 49, then death and a sixth at 60).
## Run with --bots=off or the bots kill the machine early.
var ovo_seen: Dictionary = {}
var ovo_t0 := 0.0
var ovo_dead := false
func _ovo_steps() -> void:
	if _at(0.3):
		probe = arena.spawn_troop("ovomachine", 0, arena.tile_center(9.5, 22.5))
		ovo_t0 = elapsed
		print("[ovo] deployed, lifetime=%.0f" % probe.lifetime)
	if ovo_t0 <= 0.0:
		return
	for u in arena.units:
		if is_instance_valid(u) and String(u.kind) == "chicken" and not ovo_seen.has(u.get_instance_id()):
			ovo_seen[u.get_instance_id()] = true
			print("[ovo] chicken %d at %.2f s" % [ovo_seen.size(), elapsed - ovo_t0])
	if not ovo_dead and (not is_instance_valid(probe) or probe.dead):
		ovo_dead = true
		print("[ovo] machine gone at %.2f s, %d chickens in all" % [elapsed - ovo_t0, ovo_seen.size()])


## The opening deal: how long one beat is, and how many cards each panel is still
## holding back as the deal runs (both should count down together to 0).
func _deal_steps() -> void:
	if _at(0.05):
		print("[deal] beat=%.3f s (sound slice %.3f)" % [arena.panels[0].deal_beat, arena.sfx.slice_seconds])
	for t in [0.1, 0.4, 0.7, 1.0, 1.3, 1.6, 2.0, 2.6]:
		if _at(t):
			print("[deal] t%.1f held back: own=%d opponent=%d | own next=%s" % [t,
				arena.panels[0].deal_hidden.size(), arena.panels[1].deal_hidden.size(),
				str(arena.panels[0].deal_hidden)])


## The spider encounter, driven by hand so it fits in 20 s (run with --bots=off):
## the swap, a bridge trap, a web, venom + poison ticks, a leg stab, a skitter
## with its egg, and the egg hatching.
var spider_slowed := false
var spider_walker: Node = null
func _spider_steps() -> void:
	var sp: Node = arena.spider
	if _at(0.3):
		arena.start_spider_encounter()
		sp = arena.spider
		var enemy_towers: int = arena.towers.filter(func(t): return int(t.team) == 1).size()
		print("[spider] enemy 'towers'=%d (expect 1, the spider) hp=%d crown=%s hand1=%d" % [
			enemy_towers, int(sp.hp), str(sp.crown), arena.hands[1].size()])
		sp.lay_trap()
		probe = arena.spawn_troop("hero", 0, arena.tile_center(5.5, 17.5), true)
		probe.deploy_timer = 0.0
		print("[spider] trap laid on bridge A (traps=%d); hero walking at it" % sp.traps.size())
	if _at(3.2):
		print("[spider] t3.2 hero on the board=%s traps=%d (expect false / 0: launched)" % [
			str(is_instance_valid(probe) and not probe.dead and arena.units.has(probe)), sp.traps.size()])
		spider_walker = arena.spawn_troop("hero", 0, arena.tile_center(9.5, 12.5), true)
		spider_walker.deploy_timer = 0.0
		sp.lay_web_ahead_of(spider_walker)
		print("[spider] web laid ahead of a hero: %d tiles" % sp.webs.size())
	if is_instance_valid(spider_walker) and not spider_walker.dead and int(spider_walker.status) == 1:
		spider_slowed = true
	if _at(6.0):
		print("[spider] t6.0 web tiles left=%d slowed at some point=%s | hero hp=%d poison=%d" % [
			sp.webs.size(), str(spider_slowed), int(spider_walker.hp), int(spider_walker.poison)])
		# cut the wait at the back short; a 4 s wait means a 6 s stay forward
		sp.back_wait = 4.0
		sp.skitter_clock = 4.0
	if _at(7.0):
		print("[spider] t7.0 skittered %.1f tiles forward (expect 3-6) state=%d stay=%.1f (expect 6.0 = 10 - 4)" % [
			arena.tiles_between(sp.position, sp.home), sp.state, sp.stay_time])
	for tt in [8.0, 9.0, 10.0, 11.0, 11.4, 12.0, 12.4]:
		if _at(tt):
			print("[spider] t%.1f state=%d glint=%s walker poison=%d" % [tt, sp.state, str(sp.glint),
				int(spider_walker.poison) if is_instance_valid(spider_walker) and not spider_walker.dead else -1])
	if _at(13.5):
		print("[spider] t13.5 home=%s next wait at the back=%.2f s (expect 3-7)" % [
			str(sp.position.is_equal_approx(sp.home)), sp.back_wait])
	if _at(14.5):
		var eggs: Array = arena.units.filter(func(u): return is_instance_valid(u) and String(u.kind) == "spideregg")
		print("[spider] t14.5 back home=%s eggs=%d webs=%d hero alive=%s hp=%d poison=%d" % [
			str(sp.position.is_equal_approx(sp.home)), eggs.size(), sp.webs.size(),
			str(is_instance_valid(spider_walker) and not spider_walker.dead),
			int(spider_walker.hp) if is_instance_valid(spider_walker) else -1,
			int(spider_walker.poison) if is_instance_valid(spider_walker) else -1])
		var tower_poison: Array = arena.towers.filter(func(t): return int(t.team) == 0).map(func(t): return int(t.poison))
		print("[spider] t14.5 poison on my towers=%s (the parting spit lands on the nearest one)" % str(tower_poison))
		for e in eggs:
			e.take_damage(9999.0, e.position)
	if _at(15.0):
		var lings: int = arena.units.filter(func(u): return is_instance_valid(u) and String(u.kind) == "spiderling").size()
		print("[spider] t15.0 spiderlings=%d (expect 1, hatched from the egg)" % lings)
		sp.take_damage(sp.hp - 1.0, sp.position)
	if _at(15.5):
		sp.take_damage(5.0, sp.position)
		print("[spider] killed: dead=%s match_over=%s winner=%d webs=%d" % [
			str(sp.dead), str(arena.match_over), arena.winner, sp.webs.size()])


## The kraken encounter by hand (run with --bots=off): arrows with nobody near,
## a slam, a low-health spin, the phase change, orbs splitting, a burrow, the win.
var kraken_spun := false
var kraken_small := 0
var kraken_big := 0
var kraken_away := false
var kraken_held := false
var kraken_hero: Node = null
func _kraken_steps() -> void:
	var kr: Node = arena.kraken
	if _at(0.3):
		arena.start_kraken_encounter()
		kr = arena.kraken
		var mine: Array = arena.towers.filter(func(t): return int(t.team) == 1)
		print("[kraken] enemy towers=%d (expect 5 tentacles) crown=%s arrow timers=%s (furthest first)" % [
			mine.size(), str(arena.crown_tower(1) != null), str(kr.arms.map(func(a): return a.arrow_cd))])
	if kr == null:
		return
	for a in kr.arms:
		if a.state == 3 or a.state == 4:
			kraken_spun = true
		if a.state == 10:
			kraken_away = true
	for o in kr.orbs:
		if bool(o["big"]):
			kraken_big = maxi(kraken_big, kr.orbs.filter(func(x): return bool(x["big"])).size())
		else:
			kraken_small = maxi(kraken_small, kr.orbs.filter(func(x): return not bool(x["big"])).size())
	if is_instance_valid(kraken_hero) and not kraken_hero.dead and float(kraken_hero.stunned) > 1.0:
		kraken_held = true
	if _at(3.0):
		print("[kraken] t3.0 arrows in flight=%d (expect 1: the furthest fired at 2.6) states=%s" % [
			kr.arrows.size(), str(kr.arms.map(func(a): return a.state))])
	if _at(4.0):
		probe = arena.spawn_troop("hero", 0, arena.tile_center(5.5, 14.5), true)
		probe.deploy_timer = 0.0
		probe.position = arena.tile_center(5.5, 14.5)
		print("[kraken] hero 3 tiles from tentacle 3, hp=%d" % int(probe.hp))
	if _at(5.2):
		print("[kraken] t5.2 hero hp=%d (expect 30 less: slammed) tentacle 3 state=%d lean=%.2f tiles" % [
			int(probe.hp) if is_instance_valid(probe) else -1, kr.arms[3].state,
			arena.tiles_between(kr.arms[3].position, kr.arms[3].base)])
	if _at(6.0):
		kr.arms[3].hp = kr.arms[3].max_hp * 0.25
		if is_instance_valid(probe) and not probe.dead:
			probe.hp = 300.0
			probe.position = kr.arms[3].position + Vector2(0.0, 40.0)
		print("[kraken] tentacle 3 cut to 25%% hp, hero put next to it")
	if _at(9.5):
		print("[kraken] t9.5 spin seen=%s tower hp=%s (arrows land on towers)" % [str(kraken_spun),
			str(arena.towers.filter(func(t): return int(t.team) == 0).map(func(t): return int(t.hp)))])
		if is_instance_valid(probe) and not probe.dead:
			probe.take_damage(9999.0, probe.position)
	if _at(10.0):
		for a in kr.arms:
			a.take_damage(9999.0, a.position)
		print("[kraken] all tentacles killed: phase=%d body in towers=%s crown=%s arm hp=%s slow=%s" % [
			kr.phase, str(arena.towers.has(kr)), str(arena.crown_tower(1) == kr),
			str(kr.arms.map(func(a): return int(a.hp))), str(kr.arms[0].slow)])
		kraken_hero = arena.spawn_troop("hero", 0, arena.tile_center(9.5, 20.5), true)
		kraken_hero.deploy_timer = 0.0
	if _at(12.0):
		print("[kraken] t12.0 big orbs seen=%d (expect 3) body hp=%d" % [kraken_big, int(kr.hp)])
		kr.burrow_clock = 0.0
	if _at(13.6):
		var grabs: int = arena.units.filter(func(u): return is_instance_valid(u) and String(u.kind) == "tentacle" and int(u.team) == 1).size()
		print("[kraken] t13.6 a tentacle went under=%s grabbing tentacles=%d hero held=%s hero hp=%d" % [
			str(kraken_away), grabs, str(kraken_held), int(kraken_hero.hp) if is_instance_valid(kraken_hero) else -1])
	if _at(17.0):
		print("[kraken] t17.0 small orbs seen at once=%d (expect 3-5 per big orb)" % kraken_small)
		kr.take_damage(kr.hp + 1.0, kr.position)
		print("[kraken] killed: dead=%s match_over=%s winner=%d tentacles down=%s" % [
			str(kr.dead), str(arena.match_over), arena.winner, str(kr.arms.map(func(a): return a.down))])


var burn_tower_hp := 0.0
func _burn_steps() -> void:
	if _at(0.3):
		alch = arena.spawn_troop("snowman", 1, arena.tile_center(9.5, 18.5))
		alch.deploy_timer = 0.0
		alch.apply_burn(40.0)
		print("[burn] 40 burn applied to a 90 hp dummy")
		burn_tower_hp = float(arena.towers[1].hp)
		arena.towers[1].apply_burn(40.0)
	if _at(5.3):
		# a tower takes 20 % a tick for all four ticks: 8+6+5+4 = 23
		print("[burn] tower took %d from 40 burn (expect 23)" % int(burn_tower_hp - float(arena.towers[1].hp)))
	if _at(1.2) or _at(2.2) or _at(3.2) or _at(4.2) or _at(5.4):
		if not is_instance_valid(alch):
			# the tower shoots the dummy too; a fresh one keeps the slow checks below alive
			print("[burn] t%.1f the dummy is dead" % elapsed)
			alch = arena.spawn_troop("snowman", 1, arena.tile_center(9.5, 18.5))
			alch.deploy_timer = 0.0
			return
		print("[burn] t%.1f hp=%d stack=%.1f ticks=%d status=%d" % [
			elapsed, int(alch.hp), alch.burn_stack, alch.burn_ticks, int(alch.status)])
	if _at(5.8):
		alch.slow(0.3, 3.0)
		print("[burn] after slow: status=%d (1=SLOW)" % int(alch.status))
		alch.apply_burn(20.0)
		print("[burn] burn applied on top: status=%d stack=%.0f (2=BURN)" % [int(alch.status), alch.burn_stack])
	if _at(6.2):
		alch.apply_burn(20.0)
		alch.slow(0.3, 3.0)
		print("[burn] slow applied on top of burn: status=%d stack=%.0f (1=SLOW, stack cleared)" % [
			int(alch.status), alch.burn_stack])
	if _at(6.6):
		var tgt = arena.spawn_troop("hero", 1, arena.tile_center(9.5, 15.5))
		tgt.deploy_timer = 0.0
		var ch = arena.spawn_troop("chicken", 0, arena.tile_center(9.5, 17.5))
		ch.deploy_timer = 0.0
		probe = ch
		alch = tgt
		print("[burn] chicken vs hero placed 2 tiles apart")
	if _at(8.6):
		print("[burn] chicken flying=%s reach=%.1f alive=%s | hero hp=%d burn=%.1f" % [
			str(probe.flying), probe.reach, str(is_instance_valid(probe) and not bool(probe.get("dead"))),
			int(alch.hp), alch.burn_stack if alch.has_method("apply_burn") else -1.0])


func _boomerang3_steps() -> void:
	if _at(0.2):
		alch = arena.spawn_troop("fu", 0, arena.tile_center(9.5, 20.0))
		alch.deploy_timer = 0.0
		probe = arena.spawn_troop("hero", 1, arena.tile_center(9.5, 17.0))
		probe.deploy_timer = 0.0
		print("[rang] fu + aimed target 3 tiles away (target hp %d)" % int(probe.hp))
	if _at(0.5) or _at(1.0) or _at(1.5) or _at(1.8) or _at(2.1) or _at(2.5) or _at(2.9) or _at(3.3):
		var bp: Node = null
		for c in arena.get_children():
			if c is DDProjectile:
				bp = c
		var bstate := "none"
		if bp != null:
			bstate = "%s d=%.2f" % ["BACK" if bp.phase == 1 else "OUT", arena.tiles_between(bp.position, probe.position)]
		print("[rang] t%.1f target_hp=%d has_proj=%s boom=%s" % [
			elapsed, int(probe.hp) if is_instance_valid(probe) else -1, str(alch.has_projectile), bstate])
	if _at(0.7):
		var blocker = arena.spawn_troop("slate", 1, arena.tile_center(9.5, 18.5))
		blocker.deploy_timer = 0.0
		alch.set_meta("blocker", blocker)
		print("[rang] blocker dropped in between while the boomerang is out")
	if _at(2.4):
		var b: Node = alch.get_meta("blocker")
		print("[rang] aimed target hp=%d (one 30 hit = 120) | blocker hp=%d" % [
			int(probe.hp) if is_instance_valid(probe) else -1,
			int(b.hp) if is_instance_valid(b) else -1])
	if _at(3.0):
		for u in arena.units.duplicate():
			if is_instance_valid(u):
				u.take_damage(99999.0, u.position)
		alch = arena.spawn_troop("fu", 0, arena.tile_center(4.5, 10.5))
		alch.deploy_timer = 0.0
		print("[rang] fu parked next to a tower, tower hp=%d" % int(arena.towers[1].hp))
	if _at(5.0):
		print("[rang] tower hp now=%d (30 boomerang = 220)" % int(arena.towers[1].hp))


func _fuair_steps() -> void:
	if _at(0.2):
		alch = arena.spawn_troop("fu", 0, arena.tile_center(6.5, 18.5))
		var flyer = arena.spawn_troop("hawk", 1, arena.tile_center(6.5, 18.0), true)
		probe = flyer
		alch.deploy_timer = 0.0
		flyer.deploy_timer = 0.0
		print("[fuair] fu + flyer spawned 0.5 tiles apart")
	if _at(0.7):
		print("[fuair] t0.7 has_projectile=%s combo_hits=%d flyer_hp=%d" % [
			str(alch.has_projectile), int(alch.combo_hits), int(probe.hp) if is_instance_valid(probe) else -1])
	if _at(1.6):
		print("[fuair] t1.6 has_projectile=%s combo_hits=%d flyer_hp=%d throw_cd=%.2f" % [
			str(alch.has_projectile), int(alch.combo_hits), int(probe.hp) if is_instance_valid(probe) else -1, alch.throw_cd])
	if _at(2.2):
		for u in arena.units.duplicate():
			if is_instance_valid(u):
				u.take_damage(99999.0, u.position)
		alch = arena.spawn_troop("fu", 0, arena.tile_center(6.5, 18.5))
		var ground = arena.spawn_troop("snowman", 1, arena.tile_center(6.5, 17.8))
		alch.deploy_timer = 0.0
		ground.deploy_timer = 0.0
		print("[fuair] reset: fu + ground dummy adjacent")
	if _at(3.6):
		print("[fuair] vs ground: combo_hits=%d has_projectile=%s (brawls, does not throw)" % [
			int(alch.combo_hits), str(alch.has_projectile)])


func _boulder2_steps() -> void:
	if _at(0.2):
		var idol = arena.spawn_troop("idol", 0, arena.tile_center(9.5, 18.5))
		var killer = arena.spawn_troop("hero", 1, arena.tile_center(11.0, 16.5))
		alch = arena.spawn_troop("snowman", 1, arena.tile_center(9.5, 16.5))
		probe = killer
		idol.take_damage(999.0, killer.position, killer)
		print("[boulder2] idol destroyed; a snowman sits 2 tiles away")
	if _at(0.3):
		print("[boulder2] t0.30 snowman y=%.2f (start)" % ((alch.position.y - arena.ORIGIN.y) / arena.TILE))
	if _at(0.9):
		print("[boulder2] t0.90 snowman y=%.2f (pulled toward the idol at 1 tile/s)" % ((alch.position.y - arena.ORIGIN.y) / arena.TILE))
	if _at(0.45):
		var b: Node = null
		for c in arena.get_children():
			if c is DDBoulder:
				b = c
		if b == null:
			print("[boulder2] no boulder yet?!")
		else:
			var back: Vector2 = (arena.tile_center(9.5, 18.5) - b.position)
			print("[boulder2] t0.45 armed=%s delay=%.1f origin=%.2f tiles behind, dir=(%.2f,%.2f)" % [
				str(b.armed), b.delay, back.length() / arena.TILE, b.dir.x, b.dir.y])
	if _at(1.6):
		var b2: Node = null
		for c in arena.get_children():
			if c is DDBoulder:
				b2 = c
		if b2 == null:
			print("[boulder2] boulder already gone")
		else:
			var step := TAU / 16.0
			print("[boulder2] t1.6 armed=%s dir=(%.2f,%.2f) angle=%.1fÂ° steps=%.2f (integer = snapped)" % [
				str(b2.armed), b2.dir.x, b2.dir.y, rad_to_deg(b2.dir.angle()), b2.dir.angle() / step])
			var ep: Vector2 = b2.epicenter
			var spawn_off: float = ep.distance_to(b2.position) / arena.TILE
			print("[boulder2] boulder origin %.2f tiles from the idol, aimed at the killer" % spawn_off)
	if _at(2.4):
		print("[boulder2] check-hit: killer hp=%d stunned=%.1f" % [
			int(probe.hp) if is_instance_valid(probe) else -1,
			probe.stunned if is_instance_valid(probe) else -1.0])


func _shiesty_steps() -> void:
	if _at(0.2):
		arena.gold = [8.0, 8.0]
		arena.spawn_troop("snowman", 0, arena.tile_center(9.5, 17.5))
		print("[shiesty] p2 ability=%s" % arena.ability[1])
	if _at(1.0):
		max_gap = float(arena.control_rebuilds)
		print("[shiesty] rebuilds after settle=%d counts=%s" % [int(max_gap), str(arena.control_counts())])
	if _at(1.8):
		print("[shiesty] rebuilds 0.8s later=%d (unchanged = cache holds) counts=%s" % [
			int(arena.control_rebuilds), str(arena.control_counts())])
	if _at(2.0):
		var used: bool = arena.use_ability(1)
		print("[shiesty] ability used=%s p2_gold=%.0f" % [str(used), arena.gold[1]])
	if _at(3.2):
		var g: Node = null
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "shiesty":
				g = u
		print("[shiesty] present=%s hp=%s phase=%s | counts now=%s (must not grow)" % [
			str(g != null),
			str(int(g.hp)) if g != null else "-",
			str(int(g.phase)) if g != null else "-",
			str(arena.control_counts())])
	if _at(3.4):
		max_gap = float(arena.control_rebuilds)
		arena.spawn_troop("hero", 0, arena.tile_center(3.5, 20.5))
		print("[shiesty] spawned a walking unit, rebuilds before=%d" % int(max_gap))
	if _at(4.8):
		print("[shiesty] rebuilds after it walks=%d (rises only as it changes tile)" % arena.control_rebuilds)
	if _at(5.2):
		var g2: Node = null
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "shiesty":
				g2 = u
		print("[shiesty] t5.2 alive=%s hp=%s (towers ignore it) stats escaped=%d caught=%d" % [
			str(g2 != null), str(int(g2.hp)) if g2 != null else "-",
			arena.stat_shiesty_escaped, arena.stat_shiesty_caught])


func _snowblast_steps() -> void:
	if _at(0.2):
		var snow = arena.spawn_troop("snowman", 0, arena.tile_center(9.5, 18.5))
		probe = arena.spawn_troop("hero", 1, arena.tile_center(9.0, 16.8))
		alch = arena.spawn_troop("hero", 1, arena.tile_center(9.5, 12.5))
		snow.take_damage(999.0, snow.position)
		print("[snow] detonated; near_hp=%d far_hp=%d near_slow=%.2f near_time=%.1f" % [
			int(probe.hp), int(alch.hp), probe.slow_amount, probe.slow_time])
	if _at(1.0):
		print("[snow] t1 near_slow=%.2f time=%.1f far_slow=%.2f far_hp=%d" % [
			probe.slow_amount, probe.slow_time, alch.slow_amount, int(alch.hp)])
	if _at(3.9):
		print("[snow] t3.9 near_slow=%.2f time=%.1f (should be expired)" % [probe.slow_amount, probe.slow_time])


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
			if is_instance_valid(u) and String(u.kind) == "shiesty":
				g = u
		print("[ability] t4.4 goblin=%s phase=%s stolen=%.0f p1_gold=%.0f p2_gold=%.0f" % [
			str(g != null), str(int(g.phase)) if g != null else "-",
			float(g.stolen) if g != null else -1.0, arena.gold[0], arena.gold[1]])
	if _at(5.0) and OS.get_cmdline_user_args().has("--kill-goblin"):
		for u in arena.units.duplicate():
			if is_instance_valid(u) and String(u.kind) == "shiesty":
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
		if is_instance_valid(u) and String(u.kind) == "shiesty":
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


## The Phalanx. First one spartan on its own: the shield raised by a hit (that
## hit lands), burn going past it, the shield soaking and breaking, then dagger
## stabs between spear pokes on a dummy inside a tile. Then the full formation
## walking at a dummy: the layout, the shields coming up at 3 tiles, the slower
## walk and the slower pokes from both ranks.
var ph_solo: Node = null
var ph_dummy: Node = null
var ph_last_hp := 0.0
var ph_hits: Array = []
var ph_units: Array = []
var ph_pokes: Dictionary = {}
var ph_raised: Dictionary = {}
var ph_x := 0.0
func _phalanx_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.2):
		var at: Vector2 = arena.tile_center(3.5, 21.5)
		ph_solo = arena.spawn_troop("phalanx", 0, at, true)
		ph_solo.deploy_timer = 0.0
		ph_solo.speed = 0.0
		var s: Node = ph_solo
		var side := at + Vector2(t * 2.0, 0.0)
		print("[phalanx] solo hp %.0f shield %.0f up=%s" % [s.hp, s.shield_hp, str(s.shield_up)])
		s.take_damage(10.0, side)
		print("[phalanx] hit 10 with shield down -> hp %.0f shield %.0f up=%s (expect 60 / 60 / true)" % [s.hp, s.shield_hp, str(s.shield_up)])
		s.take_damage(5.0, s.position)
		print("[phalanx] burn tick 5 -> hp %.0f shield %.0f (expect 55 / 60)" % [s.hp, s.shield_hp])
		s.take_damage(25.0, side)
		print("[phalanx] hit 25 raised -> hp %.0f shield %.0f (expect 55 / 35)" % [s.hp, s.shield_hp])
		s.take_damage(50.0, side)
		print("[phalanx] hit 50 raised -> hp %.0f shield %.0f up=%s (expect 40 / 0 / false)" % [s.hp, s.shield_hp, str(s.shield_up)])
		ph_dummy = _lani_dummy("hero", at + Vector2(t * (0.42 + 0.45 + 0.6), 0.0))
		ph_dummy.max_hp = 5000.0
		ph_dummy.hp = 5000.0
		ph_last_hp = ph_dummy.hp
	if elapsed > 0.2 and elapsed < 3.5 and is_instance_valid(ph_dummy):
		if ph_dummy.hp < ph_last_hp - 0.01:
			ph_hits.append([snappedf(elapsed, 0.01), int(roundf(ph_last_hp - ph_dummy.hp))])
			ph_last_hp = ph_dummy.hp
	if _at(3.5):
		print("[phalanx] broken shield, dummy 0.6 away: hits [time, dmg] %s (expect 14 / 8 alternating, 0.65 s apart)" % str(ph_hits))
		_lani_clear()
	if _at(3.7):
		var centre: Vector2 = arena.tile_center(9.5, 22.5)
		arena.spawn_troop("phalanx", 0, centre)
		for u in arena.units:
			if is_instance_valid(u) and not u.dead and String(u.kind) == "phalanx":
				ph_units.append(u)
		var offs: Array = []
		for u in ph_units:
			offs.append([snappedf((u.position.x - centre.x) / t, 0.01), snappedf((u.position.y - centre.y) / t, 0.01)])
		print("[phalanx] %d spartans at offsets [forward, across] %s" % [ph_units.size(), str(offs)])
		ph_dummy = _lani_dummy("hero", centre + Vector2(t * 4.5, 0.0))
		ph_dummy.max_hp = 5000.0
		ph_dummy.hp = 5000.0
	if elapsed > 3.7 and not ph_units.is_empty():
		for i in ph_units.size():
			var u: Node = ph_units[i]
			if not is_instance_valid(u) or u.dead:
				continue
			if u.shield_up and not ph_raised.has(i):
				ph_raised[i] = true
				print("[phalanx] t%.2f spartan %d raises its shield, edge gap to dummy %.2f" % [elapsed, i,
					arena.gap_between(u.position, ph_dummy.position, u.radius_t, ph_dummy.radius_t)])
			if u.poke_t == u.POKE_SHOW:
				if not ph_pokes.has(i):
					ph_pokes[i] = []
					print("[phalanx] t%.2f spartan %d first poke from edge gap %.2f" % [elapsed, i,
						arena.gap_between(u.position, ph_dummy.position, u.radius_t, ph_dummy.radius_t)])
				(ph_pokes[i] as Array).append(snappedf(elapsed, 0.01))
	if _at(4.6):
		ph_x = ph_units[1].position.x
	if _at(4.8):
		print("[phalanx] walking speed, shield down: %.2f tiles/s (expect 0.85)" % ((ph_units[1].position.x - ph_x) / t / 0.2))
	if _at(5.6):
		ph_x = ph_units[1].position.x
	if _at(5.8):
		print("[phalanx] walking speed, shield up=%s: %.2f tiles/s (expect 0.51)" % [str(ph_units[1].shield_up), (ph_units[1].position.x - ph_x) / t / 0.2])
	if _at(10.8):
		print("[phalanx] pokes per spartan %s (expect 1.69 s apart while raised)" % str(ph_pokes))


## The Wolf Pack: two dummies standing together and one on its own; the pack
## goes for the lonely one, travels in its diamond, rings it, and bites in turn
## (0.4 s apart with four, 0.8 s with two).
var wf_wolves: Array = []
var wf_dummies: Array = []
var wf_target: Node = null
var wf_last_hp := 0.0
var wf_bites: Array = []
var wf_engaged := false
func _wolves_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.2):
		arena.spawn_troop("wolves", 0, arena.tile_center(9.5, 22.5))
		for u in arena.units:
			if is_instance_valid(u) and not u.dead and String(u.kind) == "wolves":
				wf_wolves.append(u)
		for spot in [Vector2(6.5, 18.5), Vector2(7.5, 18.5), Vector2(13.5, 19.5)]:
			var d: Node = _lani_dummy("hero", arena.tile_center(spot.x, spot.y))
			d.max_hp = 1000.0
			d.hp = 1000.0
			wf_dummies.append(d)
		print("[wolves] %d wolves; dummies 0 and 1 side by side, dummy 2 alone" % wf_wolves.size())
	if wf_wolves.is_empty():
		return
	var pk: Dictionary = {}
	for w in wf_wolves:
		if is_instance_valid(w) and not w.dead:
			pk = w.pack
			if w.attack_stretch == w.ATTACK_STRETCH and wf_engaged:
				wf_bites.append([snappedf(elapsed, 0.01), wf_wolves.find(w)])
	if pk.is_empty():
		return
	if pk.get("target") != wf_target and pk.get("target") != null:
		wf_target = pk["target"]
		wf_last_hp = wf_target.hp
		print("[wolves] t%.2f pack target: dummy %d (expect 2)" % [elapsed, wf_dummies.find(wf_target)])
	if _at(1.2):
		var c: Vector2 = pk["center"]
		var offs: Array = []
		for w in wf_wolves:
			offs.append([snappedf((w.position.x - c.x) / t, 0.01), snappedf((w.position.y - c.y) / t, 0.01)])
		print("[wolves] travelling, offsets from the pack's middle %s" % str(offs))
	if bool(pk.get("engaged", false)) and not wf_engaged:
		wf_engaged = true
		print("[wolves] t%.2f engaged" % elapsed)
	if _at(4.0) or _at(5.0) or _at(6.0):
		var ds: Array = []
		for w in wf_wolves:
			if not w.wolf_lunge and w.attack_stretch <= 0.0:
				ds.append(snappedf(arena.tiles_between(w.position, wf_target.position), 0.01))
		print("[wolves] ring: centre distances of the wolves not biting %s (expect about %.2f)" % [str(ds), wf_target.radius_t + 2.0])
	if _at(7.0):
		print("[wolves] bites with four: %s" % str(wf_bites))
		wf_bites.clear()
		for k in 2:
			var w: Node = wf_wolves[k]
			w.take_damage(9999.0, w.position)
		print("[wolves] two wolves killed")
	if _at(12.9):
		print("[wolves] bites with two: %s" % str(wf_bites))


## The Ant Hill: an ant out of the front every 1.2 s (the first a second in),
## and a Meerkat swarm for the record.
var ah_count := 0
func _anthill_steps() -> void:
	if _at(0.2):
		arena.spawn_troop("anthill", 0, arena.tile_center(9.5, 24.5))
		arena.spawn_troop("meerkats", 0, arena.tile_center(4.5, 22.5))
		var n := 0
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "meerkats":
				n += 1
		print("[anthill] meerkats spawned: %d" % n)
	if elapsed > 0.2:
		var n2 := 0
		for u in arena.units:
			if is_instance_valid(u) and not u.dead and String(u.kind) == "ant":
				n2 += 1
		if n2 > ah_count:
			ah_count = n2
			print("[anthill] t%.2f ant %d out (expect 1.2, 2.4, 3.6 ...)" % [elapsed, ah_count])


## Close-ups of the new art and the four full cards, drawn on one overlay.
func _packart_steps() -> void:
	if not _at(0.3):
		return
	var layer := CanvasLayer.new()
	layer.layer = 60
	arena.add_child(layer)
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(c)
	var team_col: Color = arena.team_color(0)
	var ink: Color = arena.team_ink(0)
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.get_viewport_rect().size), Color(0.36, 0.52, 0.32))
		var s := 3.4
		var r := 0.42 * 38.0
		var y := 150.0
		var items := [
			func() -> void: DDArt.spartan(c, r, 1.0, 0.3, {"shield": 1, "walk": true}, ink, team_col),
			func() -> void: DDArt.spartan(c, r, 1.0, 0.3, {"shield": 2, "dent": 0.6, "poke": 0.5}, ink, team_col),
			func() -> void: DDArt.spartan(c, r, 1.0, 0.3, {"shield": 0, "stab": 0.5}, ink, team_col),
			func() -> void: DDArt.wolf(c, 0.4 * 38.0, 1.0, 0.1, {"run": true}, ink),
			func() -> void: DDArt.wolf(c, 0.4 * 38.0, 1.0, 0.0, {"bite": 1.0}, ink),
			func() -> void: DDArt.meerkat(c, 0.3 * 38.0, 1.0, 0.0, false, ink),
			func() -> void: DDArt.ant(c, 0.22 * 38.0 * 1.6, 1.0, 0.0, ink),
			func() -> void: DDArt.anthill(c, 0.55 * 38.0, 0.4, ink),
		]
		# Humbaba large, below the cards: walking carry, wind-up, just struck
		for k in 3:
			c.draw_set_transform(Vector2(1330.0 + 0.0 * float(k), 160.0 + 270.0 * float(k)), 0.0, Vector2(2.6, 2.6))
			DDArt.troll(c, 0.75 * 38.0, 1.0, 0.0, [0.45, 0.95, 0.0][k], ink)
		for i in items.size():
			c.draw_set_transform(Vector2(80.0 + 128.0 * float(i), y), 0.0, Vector2(s, s) * (0.8 if i >= 3 else 1.0))
			(items[i] as Callable).call()
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var kinds := ["phalanx", "wolves", "meerkats", "anthill"]
		for i in kinds.size():
			DDCardFace.draw_full(c, kinds[i], Rect2(70.0 + 300.0 * float(i), 290.0, 250.0, 390.0))
	)
	c.queue_redraw()


## One full spider cycle with timestamps: run forward, the pool forming before
## the first spit, the stream reaching the river and the river turning downstream,
## spits every 2 s, the egg, drying mouth first then the river from the top, the
## walk to a bridge, the 3 s build, the glint and the parting spit, home.
var sc_state := -1
var sc_venom: Dictionary = {}
var sc_dummies: Array = []
var sc_river := false
var sc_flags: Dictionary = {}
func _spidercycle_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.3):
		arena.start_spider_encounter()
	var sp: Node = arena.spider
	if sp == null or not is_instance_valid(sp):
		return
	if _at(0.4):
		sp.back_wait = 1.0
		sp.skitter_clock = 0.0
	if int(sp.state) != sc_state:
		sc_state = int(sp.state)
		print("[spidercycle] t%.2f state %s at tile %s | ooze wet %.2f dry %.2f len %.2f | river %s %.1f..%.1f" % [
			elapsed, ["HOME", "ADVANCE", "FORWARD", "TO_BRIDGE", "BUILD", "GLINT", "RETREAT"][sc_state],
			str(arena.tile_of(sp.position)), sp.ooze_wet, sp.ooze_dry, sp.ooze_len, str(sp.river_wet), sp.river_a, sp.river_b])
		if sc_state == 2 and sc_dummies.is_empty():
			# two dummies: one in the pool, one on the stream
			var side: Vector2 = sp.fwd.orthogonal()
			for s in [0.6, sp.ooze_len * 0.75]:
				var d: Node = arena.spawn_troop("hero", 0, sp.ooze_from + sp.fwd * float(s) * t, true)
				d.position = sp.ooze_from + sp.fwd * float(s) * t + side * 0.0
				d.deploy_timer = 0.0
				d.speed = 0.0
				d.dmg = 0.0
				d.max_hp = 9000.0
				d.hp = 9000.0
				sc_dummies.append(d)
	# every new venom glob: when, and at what
	for c in arena.get_children():
		if c is DDProjectile and String(c.kind) == "venom" and not sc_venom.has(c.get_instance_id()):
			sc_venom[c.get_instance_id()] = true
			var tgt = c.payload.get("seek") if c.get("payload") != null else null
			var what := "?"
			if tgt != null and is_instance_valid(tgt):
				what = "tower" if tgt.is_tower() else ("dummy %d" % sc_dummies.find(tgt))
			print("[spidercycle] t%.2f spit -> %s (pool wet %.2f / %.1f needed)" % [elapsed, what, sp.ooze_wet, float(sp.cfg["pool_len"])])
	if sp.ooze_wet >= sp.ooze_len - 0.001 and sp.ooze_len > 0.0 and not sc_flags.has("reach"):
		sc_flags["reach"] = true
		print("[spidercycle] t%.2f stream reaches the river (inflow col %.1f)" % [elapsed, sp.river_in])
	if sp.river_wet and sp.river_b >= sp._river_end() - 0.001 and not sc_flags.has("full"):
		sc_flags["full"] = true
		print("[spidercycle] t%.2f river poisoned from col %.1f to the bottom (%.1f)" % [elapsed, sp.river_a, sp.river_b])
	if sp.river_wet and sp.river_a > sp.river_in + 0.01 and not sc_flags.has("clear"):
		sc_flags["clear"] = true
		print("[spidercycle] t%.2f river starts clearing from the top; path wet %.2f dry %.2f" % [elapsed, sp.ooze_wet, sp.ooze_dry])
	if sc_flags.has("full") and not sp.river_wet and not sc_flags.has("clean"):
		sc_flags["clean"] = true
		print("[spidercycle] t%.2f river clear; ooze_len now %.1f" % [elapsed, sp.ooze_len])
	for tt in [3.0, 5.0, 7.0, 9.0]:
		if _at(tt):
			print("[spidercycle] t%.1f dummy poison: pool %d, stream %d" % [tt, int(sc_dummies[0].poison), int(sc_dummies[1].poison)])
	for tt2 in [13.0, 14.2, 15.5]:
		if _at(tt2):
			var tr: Array = sp.traps.map(func(x): return [int(x["bridge"]), snappedf(float(x["build"]), 0.01)])
			print("[spidercycle] t%.1f traps [bridge, built] %s" % [tt2, str(tr)])
	if _at(19.9):
		var eggs: Array = arena.units.filter(func(u): return is_instance_valid(u) and String(u.kind) == "spideregg")
		print("[spidercycle] t19.9 home=%s eggs=%d traps=%d tower poison %s" % [str(sp.position.is_equal_approx(sp.home)),
			eggs.size(), sp.traps.size(), str(arena.towers.filter(func(x): return int(x.team) == 0).map(func(x): return int(x.poison)))])


## Eggs: one broken at half its life (expect 4 spiderlings), one left to run
## its full 30 s (expect 8), and one broken at once (expect 1).
var eg_eggs: Array = []
var eg_lings := 0
func _eggs_steps() -> void:
	if _at(0.3):
		for spot in [Vector2(4.0, 5.0), Vector2(14.0, 5.0), Vector2(9.0, 8.0)]:
			var e: Node = arena.spawn_troop("spideregg", 1, arena.tile_center(spot.x, spot.y))
			e.deploy_timer = 0.0
			eg_eggs.append(e)
	var lings: int = arena.units.filter(func(u): return is_instance_valid(u) and not u.dead and String(u.kind) == "spiderling").size()
	if lings != eg_lings:
		print("[eggs] t%.2f spiderlings %d -> %d" % [elapsed, eg_lings, lings])
		eg_lings = lings
		# keep them still so the count stays readable
		for u in arena.units:
			if is_instance_valid(u) and String(u.kind) == "spiderling":
				u.speed = 0.0
	if _at(0.5):
		print("[eggs] breaking egg C at age %.2f (expect 1)" % eg_eggs[2].age)
		eg_eggs[2].take_damage(9999.0, eg_eggs[2].position)
	if _at(15.3):
		print("[eggs] breaking egg A at age %.2f of %.0f (expect 4)" % [eg_eggs[0].age, eg_eggs[0].lifetime])
		eg_eggs[0].take_damage(9999.0, eg_eggs[0].position)
	if _at(32.0):
		print("[eggs] egg B ran out on its own: gone=%s (expect 8 more)" % str(not is_instance_valid(eg_eggs[1])))


## The Firebolt locks on or does not cast. A click on bare ground does nothing;
## cast on a fast troop running away it follows it in and burns only it (its
## neighbour 0.9 tiles off is untouched); it locks on to a tower and to the
## spider too.
var bl_runner: Node = null
var bl_buddy: Node = null
func _bolt_arm() -> void:
	arena.hands[0][0] = "firebolt"
	arena._sync_ids(0)
	arena.charges = [{}, {}]
	arena.gold[0] = 20.0
	arena.selected_player = 0
	arena.selected_index = 0


func _boltlock_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.5):
		arena.bot_players = [false, false]
		_bolt_arm()
		var g0: float = arena.gold[0]
		arena.try_deploy_at(arena.tile_center(9.5, 19.5))
		print("[boltlock] click on bare ground: casts %d, gold spent %.1f (expect 0 / 0)" % [_bolts(), g0 - arena.gold[0]])
		# a tough runner going flat out (2.5 tiles/s), and a neighbour that stays put
		bl_runner = arena.spawn_troop("hero", 1, arena.tile_center(9.5, 16.5), true)
		bl_runner.deploy_timer = 0.0
		bl_runner.speed = 2.5
		bl_runner.ground_speed = 2.5
		bl_runner.max_hp = 5000.0
		bl_runner.hp = 5000.0
		bl_runner.dmg = 0.0
		bl_buddy = _lani_dummy("hero", bl_runner.position + Vector2(0.0, 0.9 * t))
	if _at(0.7):
		_bolt_arm()
		arena.try_deploy_at(bl_runner.position)
		bl_buddy.set_meta("cast_at", bl_runner.position)
		print("[boltlock] cast on a runner %.1f tiles from my nearest tower: casts %d" % [
			arena.tiles_between(bl_runner.position, arena.nearest_own_tower(0, bl_runner.position).position), _bolts()])
	if _at(2.5):
		print("[boltlock] runner burning=%s (moved %.1f tiles since the cast) (burn stack %.0f), neighbour burning=%s" % [
			str(int(bl_runner.status) == 2), arena.tiles_between(bl_buddy.get_meta("cast_at"), bl_runner.position),
			bl_runner.burn_stack, str(int(bl_buddy.status) == 2)])
		var tw: Node = null
		for x in arena.towers:
			if int(x.team) == 1 and not bool(x.crown):
				tw = x
				break
		_bolt_arm()
		arena.try_deploy_at(tw.position + Vector2(0.4 * t, 0.3 * t))
		probe = tw
		print("[boltlock] cast on an enemy side tower: casts %d" % _bolts())
	if _at(4.5):
		print("[boltlock] tower burn stack %.0f (expect 60)" % float(probe.get("burn_stack")))
		arena.start_spider_encounter()
	if _at(5.0):
		_bolt_arm()
		var sp: Node = arena.spider
		arena.try_deploy_at(sp.position + Vector2(-1.0 * t, 0.5 * t))
		print("[boltlock] cast on the spider: casts %d" % _bolts())
	if _at(8.5):
		print("[boltlock] spider burn stack %.0f or ticked (burn_timer %.2f)" % [float(arena.spider.burn_stack), float(arena.spider.burn_timer)])


## The Goat Rider: walks at a building (troops ignored), rams it once for 60,
## then chops for 18 a hit; a melee hero hitting the goat is shoved a tile
## back, a ranged shooter is not.
var gt_goat: Node = null
var gt_wall: Node = null
var gt_wall_hp := 0.0
var gt_hits: Array = []
var gt_hero: Node = null
var gt_pen: Node = null
var gt_hero_pushes := 0
var gt_pen_pushes := 0
func _goat_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.3):
		gt_wall = arena.spawn_troop("snowman", 1, arena.tile_center(9.5, 17.5), true)
		gt_wall.deploy_timer = 0.0
		gt_wall.lifetime = 0.0
		gt_wall.max_hp = 5000.0
		gt_wall.hp = 5000.0
		gt_wall_hp = gt_wall.hp
		gt_goat = arena.spawn_troop("goatrider", 0, arena.tile_center(9.5, 21.5), true)
		gt_goat.deploy_timer = 0.0
		gt_goat.max_hp = 5000.0
		gt_goat.hp = 5000.0
	if is_instance_valid(gt_wall) and gt_wall.hp < gt_wall_hp - 0.01:
		gt_hits.append([snappedf(elapsed, 0.01), int(roundf(gt_wall_hp - gt_wall.hp))])
		gt_wall_hp = gt_wall.hp
	if _at(5.0):
		print("[goat] hits on the building [time, dmg] %s (expect 60 first, then 18 every 1.1 s)" % str(gt_hits))
		# a melee hero and a ranged Pen on the goat
		gt_hero = arena.spawn_troop("hero", 1, gt_goat.position + Vector2(-1.2 * t, 0.0), true)
		gt_hero.deploy_timer = 0.0
		gt_pen = arena.spawn_troop("pen", 1, gt_goat.position + Vector2(-3.5 * t, 1.5 * t), true)
		gt_pen.deploy_timer = 0.0
		for u in [gt_hero, gt_pen]:
			u.max_hp = 5000.0
			u.hp = 5000.0
	if elapsed > 5.0 and is_instance_valid(gt_hero):
		if gt_hero.knock_time > 0.0 and not gt_hero.has_meta("pushed"):
			gt_hero.set_meta("pushed", gt_hero.position)
			gt_hero_pushes += 1
		elif gt_hero.knock_time <= 0.0 and gt_hero.has_meta("pushed"):
			var from_p: Vector2 = gt_hero.get_meta("pushed")
			if gt_hero_pushes == 1:
				print("[goat] t%.2f hero shoved %.2f tiles (expect about 1)" % [elapsed, from_p.distance_to(gt_hero.position) / t])
			gt_hero.remove_meta("pushed")
		if is_instance_valid(gt_pen) and gt_pen.knock_time > 0.0:
			gt_pen_pushes += 1
	if _at(11.5):
		print("[goat] hero shoves %d (expect several), pen shoves %d (expect 0), goat hp %d / 5000" % [
			gt_hero_pushes, gt_pen_pushes, int(gt_goat.hp)])


func _goatart_steps() -> void:
	if not _at(0.3):
		return
	var poses := [{}, {"walk": true}, {"ram": 0.5}, {"chop": 0.45}, {"puff": 1.0}]
	var layer := CanvasLayer.new()
	layer.layer = 60
	arena.add_child(layer)
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(c)
	var ink: Color = arena.team_ink(0)
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.get_viewport_rect().size), Color(0.36, 0.52, 0.32))
		for i in poses.size():
			c.draw_set_transform(Vector2(170.0 + 300.0 * float(i), 330.0), 0.0, Vector2(3.6, 3.6))
			DDArt.goat_rider(c, 0.7 * 38.0, 1.0, 0.4, poses[i], ink)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		DDCardFace.draw_full(c, "goatrider", Rect2(60.0, 560.0, 250.0, 390.0))
		DDCardFace.draw(c, "goatrider", Rect2(340.0, 640.0, 216.0, 264.0))
	)
	c.queue_redraw()


# ------------------------------------------------------------------- valkyrie

## The Valkyrie rides up the lane at a building: the charge starts 1.5 s in,
## doubles her speed, her lance kills a swarm in her path (ants, rat skeletons)
## but leaves a flyer over it alone, and the building takes 64 then 32s.
var vk: Node = null
var vk_wall: Node = null
var vk_wall_hp := 0.0
var vk_hits: Array = []
var vk_swarm: Array = []
var vk_hawk: Node = null
var vk_charge_at := -1.0
var vk_speed := 0.0
func _valkyrie_steps() -> void:
	var t: float = float(arena.TILE)
	if _at(0.3):
		vk_wall = arena.spawn_troop("snowman", 1, arena.tile_center(9.5, 16.5), true)
		vk_wall.deploy_timer = 0.0
		vk_wall.lifetime = 0.0
		vk_wall.max_hp = 5000.0
		vk_wall.hp = 5000.0
		vk_wall_hp = vk_wall.hp
		# the towers hold fire, so whatever kills the swarm is her lance
		for tw in arena.towers:
			if is_instance_valid(tw) and "dmg" in tw:
				tw.dmg = 0.0
		vk = arena.spawn_troop("valkyrie", 0, arena.tile_center(9.5, 27.5), true)
		vk.deploy_timer = 0.0
		vk.max_hp = 5000.0
		vk.hp = 5000.0
		for p in [Vector2(9.5, 22.0), Vector2(9.9, 22.6), Vector2(9.1, 22.4)]:
			var a: Node = arena.spawn_troop("ant", 1, arena.tile_center(p.x, p.y), true)
			a.deploy_timer = 0.0
			a.speed = 0.0
			vk_swarm.append(a)
		var rb: Node = arena.spawn_troop("ratbones", 1, arena.tile_center(9.5, 21.0), true)
		rb.deploy_timer = 0.0
		rb.speed = 0.0
		vk_swarm.append(rb)
		vk_hawk = arena.spawn_troop("hawk", 1, arena.tile_center(9.5, 21.5), true)
		vk_hawk.deploy_timer = 0.0
		vk_hawk.speed = 0.0
		vk_hawk.dmg = 0.0
		vk_hawk.max_hp = 5000.0
		vk_hawk.hp = 5000.0
	if not is_instance_valid(vk):
		return
	if vk_charge_at < 0.0 and vk.charging:
		vk_charge_at = elapsed
		vk_speed = vk.speed
	if is_instance_valid(vk_wall) and vk_wall.hp < vk_wall_hp - 0.01:
		vk_hits.append([snappedf(elapsed, 0.01), int(roundf(vk_wall_hp - vk_wall.hp))])
		vk_wall_hp = vk_wall.hp
	if _at(9.5):
		var alive := vk_swarm.filter(func(u): return is_instance_valid(u) and not u.dead)
		print("[valk] charge at %.2f (expect ~1.8: 0.3 + 1.5), speed %.2f -> %.2f (expect 0.9 -> 1.8)" % [vk_charge_at,
			vk.ground_speed, vk_speed])
		print("[valk] lanced %d (expect 4)" % vk.lanced.size())
		print("[valk] swarm left %d / %d (expect 0), hawk lanced %s (expect false: flyers are not in her path)" % [
			alive.size(), vk_swarm.size(), is_instance_valid(vk_hawk) and vk.lanced.has(vk_hawk.get_instance_id())])
		print("[valk] hits on the building [time, dmg] %s (expect 64 first, then 32 every 1.5 s)" % str(vk_hits))
		print("[valk] charging now %s (expect false)" % vk.charging)


func _valkart_steps() -> void:
	if not _at(0.3):
		return
	var poses := [{}, {"run": true}, {"run": true, "charge": 0.5}, {"run": true, "charge": 1.0},
		{"run": true, "charge": 1.0, "strike": 0.8}]
	var layer := CanvasLayer.new()
	layer.layer = 60
	arena.add_child(layer)
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(c)
	var ink: Color = arena.team_ink(0)
	var cols := [arena.team_color(0), arena.team_color(1), Color(0.72, 0.3, 0.85), Color(0.94, 0.47, 0.1), arena.team_color(0)]
	c.draw.connect(func() -> void:
		c.draw_rect(Rect2(Vector2.ZERO, c.get_viewport_rect().size), Color(0.36, 0.52, 0.32))
		for i in poses.size():
			c.draw_set_transform(Vector2(150.0 + 305.0 * float(i), 330.0), 0.0, Vector2(3.0, 3.0))
			DDArt.valkyrie(c, 0.65 * 38.0, 1.0, 0.4, poses[i], ink, cols[i])
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		DDCardFace.draw_full(c, "valkyrie", Rect2(60.0, 560.0, 250.0, 390.0))
		DDCardFace.draw(c, "valkyrie", Rect2(340.0, 640.0, 216.0, 264.0))
		DDArt.icon(c, "valkyrie", Vector2(700.0, 760.0), 40.0, 0.4)
	)
	c.queue_redraw()


# ---------------------------------------------------------------- lane pocket

func _side_tower(team: int, bottom: bool) -> Node:
	for tw in arena.towers:
		if is_instance_valid(tw) and tw is DDTower and int(tw.team) == team and not tw.crown:
			if (arena.tile_of(tw.position).x >= 9) == bottom:
				return tw
	return null


func _pocket_steps() -> void:
	if _at(0.2):
		var cases := [[0, Vector2i(3, 16)], [0, Vector2i(3, 12)], [0, Vector2i(5, 11)], [0, Vector2i(2, 9)], [0, Vector2i(1, 8)],
			[0, Vector2i(7, 12)], [0, Vector2i(3, 7)], [0, Vector2i(2, 14)], [1, Vector2i(15, 20)]]
		print("[pocket] before: %s" % str(cases.map(func(c): return arena.can_deploy(int(c[0]), "hero", arena.tile_center(float(c[1].x) + 0.5, float(c[1].y) + 0.5)))))
		_side_tower(1, false).take_damage(99999.0, Vector2.ZERO)
		_side_tower(0, true).take_damage(99999.0, Vector2.ZERO)
		# troops just past the river: their presence cones run back across it,
		# which must skip the water and keep the bridge decks
		for col in [2.5, 9.5, 15.5]:
			var u: Node = arena.spawn_troop("hero", 0, arena.tile_center(col, 12.5), true)
			u.speed = 0.0
			var v: Node = arena.spawn_troop("hero", 1, arena.tile_center(col, 17.5), true)
			v.speed = 0.0
	if _at(0.6):
		var cases := [[0, Vector2i(3, 16)], [0, Vector2i(3, 12)], [0, Vector2i(5, 11)], [0, Vector2i(2, 9)], [0, Vector2i(1, 8)],
			[0, Vector2i(7, 12)], [0, Vector2i(3, 7)], [0, Vector2i(2, 14)], [1, Vector2i(15, 20)]]
		for c in cases:
			var at: Vector2 = arena.tile_center(float(c[1].x) + 0.5, float(c[1].y) + 0.5)
			print("[pocket] team %d tile %s: can deploy %s (pocket %s, water %s)" % [int(c[0]), str(c[1]),
				str(arena.can_deploy(int(c[0]), "hero", at)), str(arena.in_pocket(int(c[0]), c[1])), str(arena.is_water(c[1]))])
		var wet := 0
		var bridge := 0
		for row in [14, 15]:
			for col in 18:
				var t := Vector2i(col, row)
				for team in 2:
					if arena.controlled(team, t):
						if arena.is_water(t):
							wet += 1
						else:
							bridge += 1
		print("[pocket] presence on river water tiles: %d, on bridge tiles: %d" % [wet, bridge])
		print("[pocket] pocket sizes: team 0 %d, team 1 %d" % [arena.pocket_tiles[0].size(), arena.pocket_tiles[1].size()])


# ---------------------------------------------------------------- reward screen UI

func _reward_move(rs: Node, p: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	rs.get_viewport().push_input(ev, true)


var rw_icon := ""


func _rewardui_steps() -> void:
	var run = arena.get_node_or_null("/root/Run")
	if run == null or not run.active:
		return
	if run.floor_index != 0:
		# the pick moved the run on: stop before this fight overwrites the shots
		if _at(0.05):
			get_tree().quit()
		return
	if _at(0.6):
		arena._king_of(1).take_damage(99999.0, Vector2.ZERO)
	var rs: Node = arena.reward_screen
	if rs == null or not is_instance_valid(rs):
		return
	if _at(2.2):
		print("[rewardui] choices %s, screen size %s" % [str(rs.choices), str(rs.size)])
		_reward_move(rs, rs.card_rect(1).get_center())
	if _at(2.6):
		print("[rewardui] over card 2: hover %d, grown %.2f, drawn %s vs %s" % [rs.hover, float(rs.lift[1]),
			str(rs.drawn_card_rect(1).size), str(rs.card_rect(1).size)])
		var icons: Array = rs.last_hits.filter(func(h): return not ["melee", "ranged", "special", "spell"].has(String(h["id"])))
		print("[rewardui] icons drawn: %s" % str(rs.last_hits.map(func(h): return String(h["id"]))))
		if not icons.is_empty():
			rw_icon = String(icons[0]["id"])
			_reward_move(rs, icons[0]["c"])
	if _at(2.85):
		# that card has grown under the mouse since: aim at the icon where it is now
		for h in rs.last_hits:
			if String(h["id"]) == rw_icon:
				_reward_move(rs, h["c"])
				break
	if _at(3.0):
		print("[rewardui] tooltip: %s -> %s" % [str(rs.tip_hit.get("id", "none")), str(DDCardFace.tip_for(rs.tip_hit)) if not rs.tip_hit.is_empty() else "-"])
	if _at(3.5):
		_reward_move(rs, rs.skip_rect().get_center())
	if _at(3.8):
		print("[rewardui] over Skip: hover %s, grown %.2f, drawn %s vs %s, card hover now %d" % [str(rs.skip_hover), rs.skip_lift,
			str(rs.drawn_skip_rect().size), str(rs.skip_rect().size), rs.hover])
	if _at(4.0):
		var p: Vector2 = rs.card_rect(0).get_center()
		_reward_move(rs, p)
		var want: String = String(rs.choices[0])
		var n0: int = run.deck.size()
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		ev.position = p
		ev.global_position = p
		rs.get_viewport().push_input(ev, true)
		print("[rewardui] clicked card 1 (%s): deck %d -> %d, last %s" % [want, n0, run.deck.size(), str(run.deck[-1])])

# ---------------------------------------------------------------- ant aggro

var aa_ants: Array = []
var aa_foes := {}


func _aa_dummy(at: Vector2) -> Node:
	var u: Node = arena.spawn_troop("hero", 1, at, true)
	u.deploy_timer = 0.0
	u.speed = 0.0
	u.dmg = 0.0
	u.max_hp = 99999.0
	u.hp = 99999.0
	return u


func _aa_report(label: String) -> void:
	var parts: Array = []
	for a in aa_ants:
		if not is_instance_valid(a) or a.dead:
			continue
		var who := "lane/other"
		for k in aa_foes.keys():
			if a.target == aa_foes[k]:
				who = k
		if a.target != null and is_instance_valid(a.target) and a.target.is_tower():
			who = "tower"
		var dists: Array = []
		for k in ["B", "C"]:
			dists.append("%s %.1f" % [k, arena.tiles_between(a.position, aa_foes[k].position)])
		parts.append("%s (%s)" % [who, ", ".join(dists)])
	print("[antaggro] %s: %s | marks %d" % [label, " ; ".join(parts), arena.ant_marks.size()])


## Hovered hand card (see-through, no art) and the volume slider: a real mouse
## press on the slider track must move the Master bus.
func _hovervol_steps() -> void:
	var c: Node = arena.panels[0].cards[2]
	var g := Rect2(c.global_position, c.size)
	var art: Rect2 = DDCardFace.art_rect(c.kind, g)
	if _at(1.0):
		# hand cards poll the viewport mouse, which pushed motion events do not move
		arena.get_viewport().warp_mouse(g.get_center())
	if _at(1.3):
		_hv_report("clear board")
		hv_dummy = _aa_dummy(Vector2(g.get_center().x, (g.position.y + art.position.y) * 0.5))
	if _at(1.45):
		_hv_report("troop behind the header")
		hv_dummy.position = art.get_center()
	if _at(1.6):
		_hv_report("troop behind the art")
	if _at(1.7):
		hv_dummy.queue_free()
		# the hovered card rises above the panel's own rect, so press it directly
		arena.panels[0]._press_card(2)
	if _at(1.8):
		var at: Vector2 = arena.tile_center(9.5, 22.5)
		arena.get_viewport().warp_mouse(at)
		var mv := InputEventMouseMotion.new()
		mv.position = at
		mv.global_position = at
		arena.get_viewport().push_input(mv, true)
	if _at(2.0):
		_hv_report("dragged over the board")
	if _at(2.4):
		var s: HSlider = arena.volume_slider
		var at := s.global_position + Vector2(s.size.x * 0.25, s.size.y * 0.5)
		for down in [true, false]:
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = down
			ev.position = at
			ev.global_position = at
			arena.get_viewport().push_input(ev, true)
	if _at(2.7):
		var cfg := ConfigFile.new()
		cfg.load(DDSfx.SETTINGS_FILE)
		print("[hovervol] slider=%.2f bus_db=%.1f muted=%s saved=%s" % [arena.volume_slider.value,
			AudioServer.get_bus_volume_db(0), AudioServer.is_bus_mute(0), cfg.get_value("audio", "volume", "none")])
		DDSfx.set_volume(DDSfx.VOLUME_DEFAULT)


var hv_dummy: Node = null


func _hv_report(label: String) -> void:
	var c: Node = arena.panels[0].cards[2]
	print("[hovervol] %s: state=%d alpha=%.2f art_hidden=%s" % [label, int(c.state), float(c.alpha), c.art_hidden])


func _antaggro_steps() -> void:
	if _at(0.2):
		for p in [Vector2(3.5, 19.5), Vector2(4.5, 19.5), Vector2(3.5, 20.5), Vector2(4.5, 20.5), Vector2(6.5, 21.5), Vector2(1.5, 21.5)]:
			var a: Node = arena.spawn_troop("ant", 0, arena.tile_center(p.x, p.y), true)
			a.deploy_timer = 0.0
			aa_ants.append(a)
		aa_foes["A"] = _aa_dummy(arena.tile_center(3.5, 17.5))
		aa_foes["B"] = _aa_dummy(arena.tile_center(7.5, 19.5))
		aa_foes["C"] = _aa_dummy(arena.tile_center(0.5, 20.5))
	if _at(0.45):
		_aa_report("idle enemies only (A in their path)")
	if _at(0.5):
		aa_ants[0].take_damage(999.0, aa_foes["B"].position, aa_foes["B"])
	if _at(0.7):
		_aa_report("B killed an ant")
	if _at(0.75):
		aa_ants[2].take_damage(999.0, aa_foes["C"].position, aa_foes["C"])
	if _at(0.95):
		_aa_report("C killed one too (each ant should take the closer)")
	if _at(6.0):
		_aa_report("t6")
	if _at(11.2):
		_aa_report("marks run out (10 s after each kill)")