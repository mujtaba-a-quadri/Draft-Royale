extends Node2D

## Mockups of a trading-card style card face, with an attribute icon bar and
## melee / ranged attack rows. The face itself is the game's (DDCardFace); these
## sheets show it at every size.
## Writes four sheets into mockups/tcg/:
##   full     big cards with the description
##   compact  the same face without the description, at in-hand sizes
##   hands    hands of 4 / 6 / 8 / 10 cards at the widths the game gives them
##   icons    the icon legend: what each one means and what card data sets it
## Run:  godot --path . res://scenes/tcg_mock.tscn

const OUT_DIR := "res://mockups/tcg"
const SHEET := Vector2i(1600, 1100)


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await get_tree().process_frame
	for sheet in ["full", "compact", "hands", "icons"]:
		await _shot(sheet)
	get_tree().quit()


func _shot(sheet: String) -> void:
	var vp := SubViewport.new()
	vp.size = SHEET
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	add_child(vp)
	var s := Sheet.new()
	s.sheet = sheet
	vp.add_child(s)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png("%s/tcg_%s.png" % [OUT_DIR, sheet])
	print("[tcg] ", sheet, " -> ", img.get_size())
	vp.queue_free()


class Sheet extends Node2D:
	var sheet := "full"
	var font: Font = ThemeDB.fallback_font

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(SHEET)), Color(0.15, 0.16, 0.2))
		match sheet:
			"full":
				_title("Full cards, with the description (about 300 px wide)")
				var kinds := ["fu", "neko", "ovomachine", "fireball", "gilgamesh"]
				for i in kinds.size():
					TCG.card(self, kinds[i], Rect2(24.0 + 314.0 * float(i), 70.0, 300.0, 419.0), true)
				var kinds2 := ["chicken", "militia", "ballista", "elf", "mantis"]
				for i in kinds2.size():
					TCG.card(self, kinds2[i], Rect2(24.0 + 314.0 * float(i), 580.0, 300.0, 419.0), true)
			"compact":
				_title("Without the description: 260 px, 216 px (a 4-card hand) and 179 px (6 cards)")
				var a := ["hero", "neko", "fu", "wolves"]
				for i in a.size():
					TCG.card(self, a[i], Rect2(24.0 + 274.0 * float(i), 70.0, 260.0, 364.0), false)
				var b := ["femme", "warren", "frog", "obsidian", "magma", "dragon"]
				for i in b.size():
					TCG.card(self, b[i], Rect2(24.0 + 228.0 * float(i), 470.0, 216.0, 302.0), false)
				var c := ["alchemist", "anthill", "meerkats", "penny", "idol", "aphid", "wu", "troll"]
				for i in c.size():
					TCG.card(self, c[i], Rect2(24.0 + 190.0 * float(i), 808.0, 179.0, 250.0), false)
			"hands":
				_title("Hands at the game's own widths (DDCard.hand_size over a 1100 px panel), 1.4 tall")
				var deck := ["neko", "hero", "fu", "chicken", "slate", "ovomachine", "fireball", "phalanx", "wolves", "hawk"]
				var y := 64.0
				for n in [4, 6, 8, 10]:
					var sz: Vector2 = DDCard.hand_size(1100.0, n)
					var w: float = sz.x
					var h: float = w * 1.4
					draw_string(font, Vector2(24.0, y + 14.0), "%d in hand: %d px wide" % [n, int(w)],
						HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.85, 0.85, 0.9))
					for i in n:
						TCG.card(self, deck[i % deck.size()], Rect2(24.0 + (w + 5.0) * float(i), y + 22.0, w, h), false)
					y += h + 34.0
			"icons":
				_legend()

	func _title(t: String) -> void:
		draw_string(font, Vector2(24.0, 40.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.95, 0.95, 1.0))

	func _legend() -> void:
		_title("Icons: attack kinds (left of each attack row) and attributes (the bar along the bottom)")
		var col := 0
		var row := 0
		var groups := [["Attack kinds", TCG.ATTACK_ICONS], ["Attributes", TCG.TRAIT_ORDER]]
		var y0 := 80.0
		for g in groups:
			draw_string(font, Vector2(24.0, y0), String(g[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color(1.0, 0.85, 0.45))
			var ids: Array = g[1]
			col = 0
			row = 0
			for id in ids:
				var at := Vector2(52.0 + 520.0 * float(col), y0 + 38.0 + 52.0 * float(row))
				TCG.badge(self, String(id), at, 19.0)
				var info: Array = TCG.ICON_INFO.get(String(id), [String(id), ""])
				draw_string(font, at + Vector2(30.0, -4.0), String(info[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.95, 0.95))
				draw_string(font, at + Vector2(30.0, 14.0), String(info[1]), HORIZONTAL_ALIGNMENT_LEFT, 470.0, 11, Color(0.68, 0.7, 0.78))
				col += 1
				if col >= 3:
					col = 0
					row += 1
			y0 += 38.0 + 52.0 * float(row + (1 if col > 0 else 0)) + 20.0


## The card face now lives in the game: card_face.gd (DDCardFace).
const TCG := preload("res://scripts/card_face.gd")
