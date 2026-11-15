extends Node2D

## Layout mockups: hand of 8 under the gold line, opponent in two columns, and
## the debug shelf overlapping the arena bulge. godot --path . res://scenes/layout_mock.tscn

const W := 1600.0
const H := 1000.0
const BOARD := Rect2(230.0, 56.0, 1140.0, 684.0)
const GOLD_X := 249.0
const GOLD_Y := 720.0




func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://mockups"))
	await get_tree().process_frame
	for mode in ["regular", "debug"]:
		var vp := SubViewport.new()
		vp.size = Vector2i(int(W), int(H))
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var f := MockFace.new()
		f.mode = String(mode)
		vp.add_child(f)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("res://mockups/hand_layout_%s.png" % mode)
		print("[layout] ", mode)
		vp.queue_free()
	get_tree().quit()


class MockFace extends Node2D:
	const KINDS := ["hero", "slate", "hawk", "hedgehog", "fireball"]
	const OPPS := ["dragon", "fu", "alchemist", "zombie", "warren", "idol", "firebolt", "hedgehog"]
	var mode := "regular"

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.1, 0.15))
		# --- arena placeholder
		draw_rect(BOARD, Color(0.4, 0.62, 0.33))
		for i in 30:
			if i % 2 == 0:
				draw_rect(Rect2(BOARD.position.x + float(i) * 38.0, BOARD.position.y, 38.0, BOARD.size.y),
					Color(0.36, 0.57, 0.3))
		# river (rows 14-15 -> a vertical band) and its one-tile bulge
		var river := Rect2(BOARD.position.x + float(30 - 16) * 38.0, BOARD.position.y - 38.0, 76.0, BOARD.size.y + 76.0)
		draw_rect(river, Color(0.22, 0.45, 0.72))
		draw_rect(Rect2(BOARD.position.x + float(30 - 19) * 38.0, BOARD.position.y - 38.0, 3.0 * 38.0, BOARD.size.y + 76.0),
			Color(0.36, 0.5, 0.26))
		draw_rect(Rect2(BOARD.position.x, BOARD.position.y, BOARD.size.x, BOARD.size.y), Color(0.13, 0.12, 0.16), false, 3.0)
		# --- gold line (blue left, red mirrored right)
		if mode == "regular":
			_gold(0, 6.0, GOLD_X, GOLD_Y, false)
			_gold(1, 3.4, W - GOLD_X - 9.0 * 30.0, GOLD_Y, true)
		# --- hand of 8: spans from my leftmost coin to just left of NEXT, which
		# is lined up with the enemy's rightmost coin
		var next_cx := W - GOLD_X - 9.0 * 30.0 + 9.0 * 30.0
		var right := next_cx - 56.0
		var gap := 5.0
		var n_hand := KINDS.size()
		var size2: Vector2 = DDCard.hand_size(right - GOLD_X, n_hand)
		var card_w := size2.x
		var card_h := size2.y
		for i in KINDS.size():
			var r := Rect2(GOLD_X + float(i) * (card_w + gap), H - card_h - 8.0, card_w, card_h)
			DDCardFace.draw(self, String(KINDS[i]), r, 1.0)
		# next, right-aligned with the enemy's rightmost coin
		draw_string(font, Vector2(next_cx - 100.0, H - card_h - 24.0), "NEXT", HORIZONTAL_ALIGNMENT_RIGHT, 100, 11, Color(0.7, 0.72, 0.82))
		DDCardFace.draw(self, "idol", Rect2(next_cx - 52.0, H - card_h + 22.0, 100.0, 96.0), 0.9)
		# --- opponent: two columns of four, taller cards
		var ow := 100.0
		var oh := 156.0
		for i in OPPS.size():
			var col: int = i / 4
			var row: int = i % 4
			var x := 1382.0 + float(col) * (ow + 8.0)
			var y := 56.0 + float(row) * (oh + 8.0)
			DDCardFace.draw(self, String(OPPS[i]), Rect2(x, y, ow, oh), 0.92)
		# --- debug shelf overlapping the bulge
		if mode == "debug":
			var shelf := Rect2(150.0, 640.0, 1300.0, 350.0)
			draw_rect(shelf, Color(0.1, 0.1, 0.14, 0.97), true)
			draw_rect(shelf, Color(0.5, 0.5, 0.62), false, 2.0)
			draw_string(font, shelf.position + Vector2(16, 24), "DEBUG — ALL CARDS  (overrides gold + next)", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.92, 1.0))
			var all := ["hero", "snowman", "slate", "alchemist", "idol", "fireball", "firebolt", "dragon",
				"chicken", "fu", "hawk", "zombie", "hedgehog", "lizard", "warren"]
			var cw := 150.0
			var ch := 132.0
			for i in all.size():
				var cc2: int = i % 8
				var rr: int = i / 8
				var at := shelf.position + Vector2(16.0 + float(cc2) * (cw + 8.0), 40.0 + float(rr) * (ch + 8.0))
				DDCardFace.draw(self, String(all[i]), Rect2(at, Vector2(cw, ch)), 1.0)

	func _gold(team: int, amount: float, x0: float, y: float, reverse: bool) -> void:
		var r := 11.0
		for i in 10:
			var idx := 9 - i if reverse else i
			var c := Vector2(x0 + float(idx) * 30.0, y)
			var filled: float = clampf(amount - float(i), 0.0, 1.0)
			if filled >= 1.0:
				draw_circle(c, r, Color(0.98, 0.78, 0.22))
				draw_circle(c + Vector2(-3, -3), r * 0.4, Color(1.0, 0.94, 0.62, 0.9))
				draw_arc(c, r, 0.0, TAU, 18, Color(0.55, 0.38, 0.05), 1.6, true)
			elif filled > 0.0:
				draw_circle(c, r * 1.35, Color(0.3, 0.3, 0.34, 0.95))
				draw_arc(c, r * 1.35, -PI * 0.5, -PI * 0.5 + TAU * filled, 22, Color(1.0, 1.0, 0.84), 3.0, true)
			else:
				draw_circle(c, r, Color(0.28, 0.28, 0.32))
				draw_arc(c, r, 0.0, TAU, 16, Color(0.45, 0.45, 0.5), 1.2, true)
