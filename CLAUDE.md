# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Deep Draft is a Godot 4.7.2 project (GL Compatibility renderer, GDScript only): a Clash-Royale-style arena RTS with two hands, progressed toward a Slay-the-Spire-style run layer that does not exist yet. `README.md` is the product reference (rules, card table, numbers). `NOTES.md` is the working reference (file ownership, card checklist, bot measurement, design intent). Read `NOTES.md` before changing anything; this file does not repeat it.

## Commands

No build step, no linter, no unit test runner. Godot is invoked as `godot` on PATH.

```
godot --path . --editor                         # open in the editor
godot --path .                                  # play: starts a run (main scene: scenes/arena.tscn)
godot --path . -- --match                       # one plain match instead of a run
godot --path . -- --colors=#ff8800,#22ccaa      # recolour teams
godot --path . -- --bots=both|off               # bot on both hands / off
godot --path . -- --ability=tentacle|shiesty    # force hero ability assignment
godot --path . -- --run=<seed>                  # a run with a fixed seed
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

**Scene hub.** `scripts/arena.gd` is the root of `scenes/arena.tscn` and owns all match state: towers, gold, hands and queues, deploy and staging rules, the match clock and win conditions, hero abilities, effect spawners, and input. It delegates geometry to `board.gd` (`DDBoard`, pure statics: grid and tile/screen maths) and painting to `arena_draw.gd` (`DDArenaDraw`). Every drawing primitive goes through `tile_rect()` / `tile_center()` / `tile_of()`; keep it that way.

**Balance surface.** `scripts/card_db.gd` holds every card's data and the deck `ORDER`. Behaviour flags live here too (`roll`, `boomerang`, `chicken`, `kamikaze`, `spread`, `dodge`, `summon`, `death_aoe`, `troops_only`, `flying_unit`, `hits_air`, `stationary`, `lifetime`, `shoots`, `payload`, `cooldown_per_tile`, `greatsword`, `needle`, `guard`, `becomes`, `staff`, `beam`, `ritual`, `partner`, `whip`, `spear`, `frog`). `unit.gd` reads these in `setup()` and branches in `_attack()` / `_physics_process()`. So a card is mostly data, and code is added only for a genuinely new mechanic. Decks may hold duplicates: every card copy has an id (`arena.hand_ids` / `queue_ids`, parallel to `hands` / `queues`), and hand slots, the selection and charges bind by id; move the id along with the kind (`NOTES.md` §2).

**Card presentation is split across two dispatch tables.** `art.gd` draws each card twice: `creature()` for board and card art, and `icon()` for the deploy preview. Missing `icon` renders as a magenta circle. `card_face.gd` maps attack names (`ATTACK_NAMES`) and the type-aware ribbon (troop / building / spell).

**Projectiles and statuses.** `projectile.gd` covers bolts, darts and pellets, with modes `bolt`, `splash` and `return` (boomerang), and a payload dictionary (`burn`, `stun`, `knock`, `first_hit`) applied on impact. Burn and slow are the only statuses; a unit holds one, and the newest application replaces it.

**Determinism is load-bearing.** Combat runs in `_physics_process` on fixed ticks with no randomness; only cosmetics (confetti, sound pick) roll dice. Decks are shuffled from a seed. Anything that adds randomness to combat, or reads wall-clock time, breaks the A/B harness and the byte-identical refactor check.

**Bot.** `bot.gd` (v1, flat utility scorer) is kept deliberately as the baseline. `bot2.gd` (v2) runs perception → state (DEFEND / COUNTER / ATTACK / HOLD) → scored (card × anchor) play → softmax pick → 0.55 s telegraph. Card roles are derived from card data by `bot_matrix.gd` (`roles_of()`), and only `bot_matrix.ANSWER` is hand-tuned. `bot_sim.gd` (`DDBotSim`) is the headless harness and is wired in `arena.gd` via `--botsim=`.

**Hero abilities.** `tentacle.gd` and `shiesty.gd` are the two abilities, each player gets one per match, and both pay a card draw only when their payload lands. The bot's trigger for them is the known weak spot in `NOTES.md` §3.

**Elite encounter.** `spider.gd` (no `class_name`, preloaded by `arena.gd`) is a boss that duck-types a crown tower and replaces the whole enemy side; start it with Tab then S. Poison (a counter on units and towers, never cleared) came in with it. Details: `NOTES.md` §9. `kraken.gd` + `kraken_arm.gd` (same pattern, Tab then K) are the second: five tentacle "towers", then the body surfaces as the crown. Details: `NOTES.md` §10.

**Run layer.** `run_state.gd` is the autoload `Run` (no `class_name`): deck, commander HP (carried between fights; side towers reset), position in a placeholder `ACT`. It survives `reload_current_scene()`, which is how a run moves to its next fight. `arena._apply_run()` sets a match up from it and `_match_ended()` reports back once, then shows `reward_screen.gd` (pick 1 of 3 cards or skip) after a won fight. Pressing play starts a run; `--match`, `--botsim=` and dev scenarios do not (unless `--run` is passed), so the bot sim and scenarios are unaffected. Details: `NOTES.md` §11.

**Dev-only code.** `dev_capture.gd` is about 1150 lines of scenarios and GIF capture. It is never instantiated in normal play. `*_mock.gd` / `layout_mock.gd` / `card_mock.gd` / `iso_mock.gd` / `landscape_mock.gd` are preview scenes, not game code.

**Rules that look like bugs but are not.** `NOTES.md` §6 lists design intent that must not be "fixed" (hedgehog has no jab, Penny ignores buildings, the dragon's breath burns friendly troops, Pen never reverts to Penny, the commander tower is the only win besides the clock). Check there before changing a card's behaviour.

## Conventions

- Balance numbers belong in `card_db.gd`, not in `unit.gd`. New cards also need an `art.gd` pen in both dispatch tables, an `ATTACK_NAMES` entry, a `README.md` card row and the deck-count line. Full checklist: `NOTES.md` §2.
- Team colours are data (`arena.team_colors`); nothing else hard-codes blue or red.
- The user edits `.gd` and `.tscn` files in the editor between sessions. Re-read a file before editing it; never rewrite a whole file from memory.
- Bot changes: one change at a time, same seeds before and after, and report the `BOTSIM result` lines.
