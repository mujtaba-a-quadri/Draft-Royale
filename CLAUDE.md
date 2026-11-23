# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Deep Draft is a Godot 4.7.2 project (GL Compatibility renderer, GDScript only): a Clash-Royale-style arena RTS with two hands, progressed toward a Slay-the-Spire-style run layer that does not exist yet. `README.md` is the product reference (rules, card table, numbers). `NOTES.md` is the working reference (file ownership, card checklist, bot measurement, design intent). Read `NOTES.md` before changing anything; this file does not repeat it.

## Commands

No build step, no linter, no unit test runner. Godot is invoked as `godot` on PATH.

```
godot --path . --editor                         # open in the editor
godot --path .                                  # play: the title screen (main scene: scenes/title.tscn)
godot --path . -- --match                       # one plain match, straight past the title
godot --path . -- --colors=#ff8800,#22ccaa      # recolour teams
godot --path . -- --trim=#9aa6b8 --line=#3b4a66 # card face trim and middle line
godot --path . -- --towers=diamond              # trial art: diamond princess towers
godot --path . -- --match --bridges=2|3         # force the two-bridge or three-bridge layout
godot --path . -- --bots=both|off               # bot on both hands / off
godot --path . -- --ability=tentacle|shiesty|flame|drone    # force hero ability assignment
godot --path . -- --run=<seed>                  # a run with a fixed seed
godot --path . -- --match --relics=metronome,hourglass   # give yourself relics in a plain match
```

Bot A/B harness (headless, one match per run, byte-identical for a given seed):

```
godot --headless --path . --fixed-fps 60 -- --botsim=<seed>       # v2 vs v1, sides alternate by seed parity
godot --headless --path . --fixed-fps 60 -- --botsim=<100+seed>   # control: v1 vs v1
```

Each run prints one `BOTSIM result seed=... v2=... winner=... hp0=... hp1=...` line. Compare those lines before and after every bot or balance change; do not judge by feel.

Dev scenarios (`scripts/dev_capture.gd`, loaded only when a `--shots=`, `--demo` or `--scenario=` argument is present):

```
godot --headless --path . -- --scenario=checks --log
godot --path . -- --scenario=click --log
godot --path . -- --scenario=kit|win|pennygif --shots=<abs dir>
```

Verification is cheapest first: an eval assertion for behaviour (state, numbers, timings), a seeded sim line for refactors (compare bytes before and after), and at most one full-resolution screenshot for rendering-only questions. Art and feel go to the human.

Live evals run through the `addons/godot_ai` editor plugin (enabled in `project.godot`, with the `_mcp_game_helper` autoload), not through repo scripts. Its bodies must be one line, and the editor must rescan the filesystem before a new `class_name` file resolves in a headless run. `NOTES.md` §5 lists the other traps.

## Architecture

**Title screen.** The game is now called Draft Quadrint (`project.godot` `config/name`; folder, `DD` class prefixes and docs elsewhere keep "Deep Draft"). The main scene is `scenes/title.tscn` (`title_screen.gd`): a graph-paper coordinate plane whose four quadrants are Play a match / Start a run / Collection / Exit. It sets `Run.menu_choice` ("match" or "run") and changes to `arena.tscn`; `arena._apply_run()` reads that choice. Any of `--match`, `--run`, `--botsim=`, `--scenario=`, `--shots=`, `--demo` on the command line skips the title, so the bot sim and dev scenarios start as before. The pause menu's Title screen button goes back (abandoning a run).

**Scene hub.** `scripts/arena.gd` is the root of `scenes/arena.tscn` and owns all match state: towers, gold, hands and queues, deploy and staging rules, the match clock and win conditions, hero abilities, effect spawners, and input. It delegates geometry to `board.gd` (`DDBoard`, pure statics: grid and tile/screen maths) and painting to `arena_draw.gd` (`DDArenaDraw`). Every drawing primitive goes through `tile_rect()` / `tile_center()` / `tile_of()`; keep it that way.

**Balance surface.** `scripts/card_db.gd` holds every card's data and the deck `ORDER`. Behaviour flags live here too (`roll`, `boomerang`, `chicken`, `kamikaze`, `spread`, `dodge`, `summon`, `death_aoe`, `troops_only`, `flying_unit`, `hits_air`, `stationary`, `lifetime`, `shoots`, `payload`, `cooldown_per_tile`, `greatsword`, `needle`, `guard`, `becomes`, `gives`, `spent`, `draws`, `devour`, `no_presence`, `staff`, `beam`, `ritual`, `partner`, `whip`, `spear`, `frog`, `shield`, `dagger`, `pack`, `trail`, `ram`, `wool`). `unit.gd` reads these in `setup()` and branches in `_attack()` / `_physics_process()`. So a card is mostly data, and code is added only for a genuinely new mechanic. Decks may hold duplicates: every card copy has an id (`arena.hand_ids` / `queue_ids`, parallel to `hands` / `queues`), and hand slots, the selection and charges bind by id; move the id along with the kind (`NOTES.md` §2).

**Card presentation is split across two dispatch tables.** `art.gd` draws each card twice: `creature()` for board and card art, and `icon()` for the deploy preview. Missing `icon` renders as a magenta circle. `card_face.gd` (`DDCardFace`) is the trading-card face: attack rows (`ATTACK_NAMES`, multi-hit `ATTACKS`), attribute icons derived from card data (`traits_of()`), the summon coin, and a trim / middle-line colour pair (`trim` / `line`, set from the arena's `card_trim` / `card_line` exports). Colours in it go through `_c()` so the face fades.

**Projectiles and statuses.** `projectile.gd` covers bolts, darts and pellets, with modes `bolt`, `splash` and `return` (boomerang), and a payload dictionary (`burn`, `stun`, `knock`, `first_hit`) applied on impact. Burn and slow are the only statuses; a unit holds one, and the newest application replaces it.

**Determinism is load-bearing.** Combat runs in `_physics_process` on fixed ticks with no randomness; only cosmetics (confetti, sound pick) roll dice. Decks are shuffled from a seed. Anything that adds randomness to combat, or reads wall-clock time, breaks the A/B harness and the byte-identical refactor check.

**Bot.** `bot.gd` (v1, flat utility scorer) is kept deliberately as the baseline. `bot2.gd` (v2) runs perception → state (DEFEND / COUNTER / ATTACK / HOLD) → scored (card × anchor) play → softmax pick → 0.55 s telegraph. Card roles are derived from card data by `bot_matrix.gd` (`roles_of()`), and only `bot_matrix.ANSWER` is hand-tuned. `bot_sim.gd` (`DDBotSim`) is the headless harness and is wired in `arena.gd` via `--botsim=`.

**Hero abilities.** Four commanders, one per side per match, from `arena.ABILITIES`: `tentacle` (`tentacle.gd`), `shiesty` (`shiesty.gd`), and two aimed ones (`AIMED_ABILITIES`: the button arms `ability_aim`, a click on a unit calls `use_ability_on`): `flame` (Flammenmeister: regen on a friend or a 30-burn firebolt) and `drone` (Man-Mantis: `unit.infect_drone`, a parasite token `parasite1-4` bursts out on death, sized by `arena.parasite_for`). Each player gets one per match, and neither draws a card unless the player has the draw (`arena.ability_draws`, meant to come from a relic), and then only when the payload lands. The bot's trigger for them is the known weak spot in `NOTES.md` §3.

**Per-fight scaling.** `arena.puissance` / `arena.armor` (Strength / Dexterity): every direct hit passes `arena.scale_hit` inside the victim's `take_damage`; damage over time must go through `arena.tick_damage` so it is left alone. `NOTES.md` §13.

**Relics and Dominion cards.** `relic_db.gd` (no class_name) defines relics; `Run.relics` carries them, `arena.relics` runs them (`_relics_card_played` from `deploy`, `_tick_relics` on `fight_t`). Dominion cards are spells with a `dominion` flag that raise Puissance / Armor for the fight. Fuel for the Fire lives in `Run` and `reward_screen.gd`. `NOTES.md` §14.

**Elite encounter.** `spider.gd` (no `class_name`, preloaded by `arena.gd`) is a boss that duck-types a crown tower and replaces the whole enemy side; start it with Tab then S. Poison (a counter on units and towers, never cleared) came in with it. Details: `NOTES.md` §9. `kraken.gd` + `kraken_arm.gd` (same pattern, Tab then K) are the second: five tentacle "towers", then the body surfaces as the crown. Details: `NOTES.md` §10.

**Run layer.** `run_state.gd` is the autoload `Run` (no `class_name`): deck, commander HP (carried between fights; side towers reset), position in a placeholder `ACT`. It survives `reload_current_scene()`, which is how a run moves to its next fight. `arena._apply_run()` sets a match up from it and `_match_ended()` reports back once, then shows `reward_screen.gd` (pick 1 of 3 cards or skip) after a won fight. Pressing play starts a run; `--match`, `--botsim=` and dev scenarios do not (unless `--run` is passed), so the bot sim and scenarios are unaffected. Details: `NOTES.md` §11.

**Dev-only code.** `dev_capture.gd` is about 1150 lines of scenarios and GIF capture. It is never instantiated in normal play. `*_mock.gd` / `layout_mock.gd` / `card_mock.gd` / `iso_mock.gd` / `landscape_mock.gd` are preview scenes, not game code (`title_mock.tscn` renders the title screen's states into `mockups/title/`).

**Rules that look like bugs but are not.** `NOTES.md` §6 lists design intent that must not be "fixed" (hedgehog has no jab, Penny only reaches flyers by leaping, the dragon's breath burns friendly troops, Pen is used up when played, the commander tower is the only win besides the clock). Check there before changing a card's behaviour.

## Conventions

- Balance numbers belong in `card_db.gd`, not in `unit.gd`. New cards also need an `art.gd` pen in both dispatch tables, an `ATTACK_NAMES` entry, a `README.md` card row and the deck-count line. Full checklist: `NOTES.md` §2.
- Team colours are data (`arena.team_colors`); nothing else hard-codes blue or red.
- The user edits `.gd` and `.tscn` files in the editor between sessions. Re-read a file before editing it; never rewrite a whole file from memory.
- Bot changes: one change at a time, same seeds before and after, and report the `BOTSIM result` lines.
