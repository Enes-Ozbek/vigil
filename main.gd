extends Node2D

# ---------------------------------------------------------------------------
# A dark fantasy arena roguelite. See PLAN.md.
#
# You hold a ruined chapel against the things in the dark. Survive the vigil,
# and something offers you power. You must take one of its offers -- there is
# no walking away -- and every one of them costs you.
#
# Pacts apply once, immediately, and never cost anything (_apply_boon). All
# difficulty comes from the per-vigil enemy curve in enemy_kinds.gd.
#
# DISPLAY: the window is 1920x1080, but gameplay runs in a 960x540 WORLD drawn
# through a child node scaled by WORLD_SCALE. That keeps every gameplay number
# small and readable while sprites get a clean 2x blow-up. The HUD is drawn on
# THIS node, unscaled, so text stays crisp at native resolution instead of
# being magnified into mush.
# ---------------------------------------------------------------------------

const WORLD_SCALE := 2.0

# How many screens across the arena is. At 1.0 the whole map fits on screen and
# nothing scrolls, which is exactly how this game used to work -- turn it back
# down and everything still runs.
#
# The view follows the player by MOVING THE WORLD NODE rather than with a
# Camera2D. A camera would drag the HUD along with it, since the HUD is drawn
# on this node; scrolling the world instead leaves the HUD exactly where it is.
const MAP_SCREENS := Vector2(2.0, 2.0)

# BALANCE.md section 4. A flat 20s vigil made late waves a density spike
# instead of a climb: vigil 15 threw 567 HP/sec at you, which no pact pool can
# answer. Brotato's ramp -- 20s, +5s a wave, capped at 60 -- moves the pressure
# into duration, so late vigils are an endurance test rather than a wall.
const VIGIL_BASE := 20.0
const VIGIL_STEP := 5.0
const VIGIL_MAX := 60.0

# The spawn floor is the other half. 0.12 meant 8 enemies a second by vigil 15.
#
# These came down ~3x when enemy health went up ~5x (see enemy_kinds.gd). The
# two are one change: tougher enemies at the old spawn rate would have thrown
# 122 health per second at a character who deals 19.5, and the arena would have
# filled with things that could not be killed. Fewer, tougher, and each worth
# three times as much when it falls.
const SPAWN_INTERVAL := 2.40
const SPAWN_FLOOR := 0.60
const SPAWN_RAMP := 0.12       # how much faster spawning gets per vigil

# The most things that may be alive at once. Brotato caps at 100 and culls one
# at random when a spawn would exceed it; this is the same idea at a number the
# perf probe supports. Measured, a late vigil reached 197 enemies, which cost
# more frame time than everything else on screen put together and was unreadable
# to play against regardless of what it cost.
const MAX_ENEMIES := 90

# NOT EVERY VIGIL IS THE SAME VIGIL.
#
# Until now the only thing separating vigil 12 from vigil 3 was bigger numbers,
# which is the main reason a run stopped surprising anyone halfway through.
# Brotato breaks its twenty waves with two special kinds at fixed waves; scaled
# to fifteen vigils that lands here, with Brotato's own 40/60 split between them.
#
# They are not "harder vigils" -- they are DIFFERENT ONES, and each rewards the
# opposite build. A Horde punishes single-target damage and pays off area,
# pierce and knockback. An Elite does the reverse.
const SPECIAL_VIGILS := [8, 11, 14]
const HORDE_CHANCE := 0.40

enum VigilKind { NORMAL, HORDE, ELITE }

var vigil_kind: VigilKind = VigilKind.NORMAL
# Kept apart from the enemy_*_mult fields below, which belong to the pact
# system: a vigil kind must not silently overwrite something a pact set.
var vigil_hp_mult := 1.0
var vigil_spawn_mult := 1.0
var vigil_mote_mult := 1

# REROLLING A PACT SCREEN.
#
# "None of these four help me" had no answer, which made a bad screen a thing
# that happened TO you rather than a thing you could act on. Brotato's cost
# curve, escalating within a screen so a reroll is a decision and not a habit.
#
# Paid out of Profile.gold -- the Chapel purse. That is deliberate: in Brotato
# materials are simultaneously experience and shop currency, so every spend is a
# trade against something else you wanted. Here the trade is this run against
# every run after it.
var _rerolls := 0
# Three offers, not four. Cards take room, and a hand of three is a decision
# you can hold in your head -- four upright cards is a spreadsheet again.
const OFFER_COUNT := 3

# Each pact can be sworn at most this many times. Without a cap, stacking one
# pact fifteen times is always the strongest play and the run stops being a
# series of decisions.
const MAX_STACKS := 3

# Tuning knob: health granted for surviving a vigil. Set to 0 to make healing
# available ONLY through pacts, which is considerably harsher.
const VIGIL_SURVIVAL_HEAL := 10

# How far a bouncing projectile will look for its next victim.
const BOUNCE_RANGE := 220.0

# Soul motes left where something died.
const ORB_VALUE := 1
const ORB_SCATTER := 90.0
const ORB_MAX_DROP := 4

# Treasure. Enough to be worth crossing the arena for, few enough that finding
# one is an event.
const CHESTS_PER_VIGIL := 1

# How many cards a Cursed Chest lays out. Three, and you take one.
const CHEST_CARDS := 3

# An upright card, and the gap between them. See card_face.gd.
const CARD_W := 320.0
const CARD_H := 456.0
const CARD_GAP := 68.0
# How long the ink is allowed to boil after a hand is dealt, before the screen
# goes still and stops asking for frames.
const CARD_SETTLE := 1.1

# How a bolt chooses what to shoot. Declared per bolt in characters.gd, the way
# `kind`, `sprite` and `art_forward` already are; anything without the key gets
# TARGET_NEAREST and behaves as it always did.
const TARGET_NEAREST := "nearest"
const TARGET_SCATTER := "random3"      # random among the SCATTER_POOL nearest
const TARGET_FARTHEST := "farthest"    # for bolts that pierce a whole lane
const SCATTER_POOL := 3
const CHEST_MIN_DISTANCE := 260.0

# The minimap, top right. Its height comes from the arena's aspect rather than
# being written down, so changing MAP_SCREENS cannot leave it the wrong shape.
const MINIMAP_W := 180.0
const MINIMAP_PAD := 32.0

# How hard Luck leans on gold. See META.md section 2.
const LUCK_GOLD := 0.14

enum State { CHARACTER, PLAYING, TALLY, SHOP, DEAD }

# The beat between surviving a vigil and being offered a pact.
#
# The two used to be the same instant: the timer hit zero and four cards were
# already on screen. Nothing marked the thing you had just done, so a vigil
# ended the way a loading screen ends. This is a held moment that names the
# vigil and counts what it cost, drawn on rather than faded in -- see
# CardFace.stroke_drawn.
# How long the writing takes. It is NOT a timeout: once it is written the
# screen stays until you dismiss it. A vigil is worth a moment of your own
# choosing rather than one the game takes back after two and a half seconds --
# and a screen that leaves on its own trains you to ignore it.
const TALLY_DRAW_TIME := 2.6
const TALLY_SKIP_AFTER := 0.55    # before this a keypress is a leftover, not intent
var _tally_t := 0.0
var _tally_kills := 0
var _tally_gold := 0
var _tally_hurt := 0
var _kills_at_vigil := 0
var _gold_at_vigil := 0
var _hp_at_vigil := 0

var state: State = State.CHARACTER
var wave := 1
var wave_time_left := VIGIL_BASE
var spawn_timer := 0.0
var kills := 0

var screen: Vector2                     # 1920x1080, HUD space
var arena: Rect2                        # 960x540, world space
var world: Node2D                       # everything gameplay lives under here
var dungeon: Dungeon
var player: Player
var enemies: Array[Enemy] = []
var bullets: Array[Bullet] = []
var foe_bullets: Array[Bullet] = []
var orbs: Array[Orb] = []
var coins: Array[Coin] = []
var chests: Array[Chest] = []
var run_gold := 0
var offers: Array = []

# --- run state written by pacts --------------------------------------------
var held_pacts: Array[String] = []
var pact_counts := {}
var enemy_hp_mult := 1.0
var enemy_speed_mult := 1.0
var spawn_rate_mult := 1.0
var corruption := 0                     # HOOK for Milestone 3. Nothing reads this yet.

# A pact screen can be reached two ways, and they resume differently: a
# level-up drops you back into the vigil you were in, the end of a vigil starts
# the next one.
# Three ways to arrive at a choice screen, and they resume differently: a
# level-up and a chest both drop you back into the vigil you were in, the end
# of a vigil starts the next one.
enum PactReason { VIGIL, LEVEL, CHEST }
var _pact_reason: PactReason = PactReason.VIGIL
var _pending_levels := 0

var boss: Enemy = null
var _run_started := false
# Time since the current choice screen opened. Drives the entrance, the pulse
# and the shimmer, so every card animates off one clock.
var _choice_t := 0.0
var _notice := ""
var _notice_time := 0.0
var _hover := -1
# Where the mouse was last frame. The highlight is shared between mouse and
# keyboard, and re-reading the mouse every frame would wipe an arrow-key
# selection before it could ever be seen.
var _mouse_last := Vector2(-9999.0, -9999.0)
# What _hover was when the screen was last painted. -2 means "not holding a
# still screen", so the next still frame always repaints once.
var _drawn_hover := -2
var _portraits: Array = []
var _embers: Array = []
# Impact blasts, drawn for a moment after they land. The game had no hit
# feedback beyond a flash, and an area effect nobody can see is an area effect
# nobody believes in.
var _bursts: Array = []
const BURST_LIFE := 0.26
# Bursts happen in WORLD space, but main._draw is the HUD and draws unscaled.
# Rather than convert coordinates by hand -- which would then have to be redone
# every time the view or the scale changed -- they get their own node under the
# world and inherit its transform for free.
var _burst_layer: Node2D
var _font: Font


func _ready() -> void:
	Settings.load_all()
	Profile.load_all()
	_font = ThemeDB.fallback_font
	_resize()
	get_viewport().size_changed.connect(_resize)

	world = Node2D.new()
	world.scale = Vector2(WORLD_SCALE, WORLD_SCALE)
	add_child(world)

	dungeon = Dungeon.new()
	world.add_child(dungeon)
	dungeon.setup(arena.size)

	_burst_layer = Node2D.new()
	_burst_layer.z_index = 5          # over the floor and the dead, under the HUD
	world.add_child(_burst_layer)
	_burst_layer.draw.connect(_draw_bursts)

	player = Player.new()
	player.position = arena.size * 0.5
	world.add_child(player)
	player.visible = false        # nothing on the field until a character is chosen

	offers = Characters.ALL.duplicate()
	_build_portraits()
	_seed_embers()

	# The menu asks for a resume by setting this before changing scene, rather
	# than by passing an argument -- there is nowhere to pass one to.
	if RunSave.pending:
		RunSave.pending = false
		if RunSave.restore(self):
			player.visible = true
			_run_started = true
			state = State.PLAYING
			wave_time_left = vigil_length(wave)
			spawn_timer = 0.0
			_set_vigil_kind()
			_kills_at_vigil = kills
			_gold_at_vigil = run_gold
			_hp_at_vigil = player.hp
			_scatter_chests()
			_summon_boss()


# How long vigil v lasts.
func vigil_length(v: int) -> float:
	return minf(VIGIL_BASE + float(v - 1) * VIGIL_STEP, VIGIL_MAX)


func _resize() -> void:
	var had := arena.size
	# Take the DESIGN resolution, not the live viewport. With stretch aspect
	# "keep" they are the same in a real window, but reading the design size
	# means the arena can never change shape because someone resized the
	# window, went fullscreen, or ran on a monitor that is not 16:9.
	screen = Vector2(get_window().content_scale_size)
	if screen.x <= 0.0 or screen.y <= 0.0:
		screen = get_viewport_rect().size
	arena = Rect2(Vector2.ZERO, (screen / WORLD_SCALE) * MAP_SCREENS)
	if dungeon != null and arena.size != had:
		dungeon.setup(arena.size)


# What the player can see, in world units.
func view_size() -> Vector2:
	return screen / WORLD_SCALE


# Where the view is centred: on the player, but never past the map edges.
func view_centre() -> Vector2:
	var half := view_size() * 0.5
	return Vector2(
		clampf(player.position.x, half.x, maxf(half.x, arena.size.x - half.x)),
		clampf(player.position.y, half.y, maxf(half.y, arena.size.y - half.y)))


func view_rect() -> Rect2:
	return Rect2(view_centre() - view_size() * 0.5, view_size())


func _update_view() -> void:
	world.position = screen * 0.5 - view_centre() * WORLD_SCALE
	if dungeon != null:
		dungeon.view = view_rect()


func _process(delta: float) -> void:
	# Only a mouse that actually MOVED gets to take the highlight back.
	var m := get_local_mouse_position()
	if m.distance_to(_mouse_last) > 2.0:
		_mouse_last = m
		_hover = _card_at(m)

	match state:
		State.CHARACTER:
			_tick_embers(delta)
			_tick_portraits(delta)
		State.SHOP:
			_choice_t += delta
		State.PLAYING:
			_tick_playing(delta)
		State.TALLY:
			_tick_tally(delta)
		State.DEAD:
			if Input.is_key_pressed(KEY_R):
				get_tree().reload_current_scene()
			elif Input.is_key_pressed(KEY_C):
				get_tree().change_scene_to_file("res://chapel.tscn")

	# The chest cards are hand-inked -- a few thousand wobbly strokes between
	# the three of them -- and nothing on that screen moves. Redrawing them
	# every frame measured at 12.6ms, ten times what the whole arena costs at
	# vigil 15. A CanvasItem keeps its command list until something asks for a
	# new one, so the card screen only needs a redraw when the selection moves.
	# Every other screen animates and still redraws on the frame.
	# Inked cards are a few hundred strokes each and nothing on these screens
	# moves once they have arrived, so they repaint when the selection changes
	# rather than sixty times a second. Redrawing them every frame measured at
	# ten times what the whole arena costs at vigil 15.
	#
	# The first moment is the exception: the ink boils as the cards land, so the
	# frames are paid for while that is happening and not afterwards.
	if state == State.SHOP:
		if _hover != _drawn_hover or _choice_t < CARD_SETTLE:
			_drawn_hover = _hover
			queue_redraw()
		return
	_drawn_hover = -2
	queue_redraw()


# --- input -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_open_pause_menu()
		get_viewport().set_input_as_handled()
		return
	if state == State.CHARACTER or state == State.SHOP:
		var k := event as InputEventKey
		if k != null and k.pressed and not k.echo and _key_to_choice(k):
			get_viewport().set_input_as_handled()
			return

	if state == State.TALLY:
		var by_key: bool = event is InputEventKey and event.pressed and not event.is_echo()
		var by_click: bool = event is InputEventMouseButton and event.pressed
		if by_key or by_click:
			_skip_tally()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == State.DEAD:
			get_tree().reload_current_scene()
			return
		var i := _card_at(event.position)
		if i >= 0:
			_choose(i)


# Arrows or A/D to move, Enter or Space to take it, 1-4 to jump straight there.
#
# Edge-triggered from _input rather than polled from _process: Input.is_key_pressed
# is true on every frame the key is held, so holding Right would skim through
# every card in three frames and land somewhere arbitrary.
func _key_to_choice(k: InputEventKey) -> bool:
	for i in offers.size():
		if k.keycode == KEY_1 + i:
			_choose(i)
			return true
	# Both axes move the selection, because the screens do not agree on one.
	#
	# Pact cards and the character list are stacked VERTICALLY, so up/down and
	# W/S are what a hand reaches for -- that was the bug: only left/right was
	# bound, on a screen where left and right mean nothing. The cursed chest
	# lays its three cards out SIDE BY SIDE, where left/right is the natural
	# axis instead. Accepting all four everywhere means the key you reach for is
	# always the right one, whichever screen you are on.
	match k.keycode:
		KEY_UP, KEY_W, KEY_LEFT, KEY_A:
			_move_hover(-1)
		KEY_DOWN, KEY_S, KEY_RIGHT, KEY_D:
			_move_hover(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _hover >= 0:
				_choose(_hover)
		KEY_R:
			_do_reroll()
		_:
			return false
	return true


func _move_hover(step: int) -> void:
	var n := offers.size()
	if n == 0:
		return
	# Nothing highlighted yet: step in from whichever end you came from.
	if _hover < 0:
		_hover = 0 if step > 0 else n - 1
	else:
		_hover = wrapi(_hover + step, 0, n)
	# Hand the highlight to the keyboard until the mouse is genuinely moved,
	# rather than until the next frame reads its unchanged position.
	_mouse_last = get_local_mouse_position()


# Card geometry lives in ONE place, so the click target can never drift away
# from what is drawn. Both _draw and the mouse hit-test call this.
func _card_rect(i: int) -> Rect2:
	var cx := screen.x * 0.5
	if state == State.CHARACTER:
		return Rect2(cx - 590.0, 296.0 + float(i) * 224.0, 1180.0, 200.0)
	# Everything you are offered is dealt as a hand, upright and side by side --
	# pacts and chest cards alike. Pacts used to be a stack of wide bars, which
	# read as a settings list rather than as something being handed to you.
	var n := maxi(offers.size(), 1)
	var span := float(n) * CARD_W + float(n - 1) * CARD_GAP
	return Rect2(cx - span * 0.5 + float(i) * (CARD_W + CARD_GAP), 300.0,
		CARD_W, CARD_H)


func _card_at(pos: Vector2) -> int:
	if state != State.CHARACTER and state != State.SHOP:
		return -1
	for i in offers.size():
		if _card_rect(i).has_point(pos):
			return i
	return -1


func _choose(i: int) -> void:
	if i < 0 or i >= offers.size():
		return
	match state:
		State.CHARACTER:
			player.apply_character(offers[i])
			player.visible = true
			_run_started = true
			state = State.PLAYING
			_kills_at_vigil = kills
			_gold_at_vigil = run_gold
			_hp_at_vigil = player.hp
			RunSave.save(self)     # vigil 1 never passes through _begin_vigil
		State.SHOP:
			Audio.play("pact_pick", 0.04)
			if _pact_reason == PactReason.CHEST:
				_take_card(offers[i])
				state = State.PLAYING      # straight back into the vigil
			else:
				_swear_pact(offers[i])
				if _pact_reason == PactReason.LEVEL:
					_pending_levels -= 1
					_advance_intermission()
				else:
					_begin_vigil()
	_hover = -1


# The pause menu is menu.tscn in its PAUSE mode -- same scene, same settings
# panel, same styling as the main menu. It sits on a CanvasLayer so it is not
# affected by the world scaling, and runs while the tree is frozen.
func _open_pause_menu() -> void:
	if get_tree().paused:
		return
	var layer := CanvasLayer.new()
	layer.layer = 10
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var menu: Control = (load("res://menu.tscn") as PackedScene).instantiate()
	menu.mode = 1                          # Menu.Mode.PAUSE
	menu.player = player                   # so it can show what the run has made you
	layer.add_child(menu)
	add_child(layer)
	get_tree().paused = true


# --- the vigil -------------------------------------------------------------

func _tick_playing(delta: float) -> void:
	player.tick(delta, arena)

	spawn_timer -= delta
	if spawn_timer <= 0.0:
		var base := maxf(SPAWN_FLOOR, SPAWN_INTERVAL - float(wave) * SPAWN_RAMP)
		spawn_timer = maxf(0.06, base / (spawn_rate_mult * vigil_spawn_mult))
		_spawn_enemy()

	_fire()
	_move_enemies(delta)
	_move_bullets(delta)
	_move_foe_bullets(delta)
	_reap_enemies()
	_tick_bursts(delta)
	_move_orbs(delta)
	_move_coins(delta)
	_move_chests(delta)
	_update_view()

	if player.hp <= 0:
		if player.try_revive():
			_clear_field()        # the dark recoils, briefly
		else:
			player.play_death()
			Audio.play("death", 0.0)
			state = State.DEAD
			RunSave.clear()        # you do not get to reload out of dying
			Profile.record_run(wave, kills)
			return

	_notice_time = maxf(0.0, _notice_time - delta)

	wave_time_left -= delta
	if wave_time_left <= 0.0:
		_end_vigil()


# Bosses are not in the spawn table. One arrives at the start of its vigil, on
# top of the normal wave, and announces itself.
func _summon_boss() -> void:
	boss = null
	var id := EnemyKinds.boss_for(wave)
	if id == "":
		return
	var e := Enemy.new()
	e.setup(wave, id)
	e.position = _spawn_point()
	world.add_child(e)
	enemies.append(e)
	boss = e
	Audio.play("boss_spawn", 0.0)
	_notice = String(e.kind.get("name", "SOMETHING")).to_upper()
	_notice_time = 4.0


# Make room for one more, by removing the OLDEST living non-boss.
#
# Culling rather than refusing the spawn is deliberate: refusing would freeze
# the field around whatever happened to arrive first, so a late vigil would end
# up fought entirely against vigil-1 spawns. This keeps the mix current.
#
# A cull is not a kill -- no motes, no coin, no kill count. Paying out for
# something the game removed for its own convenience would turn the cap into a
# free income source.
func _make_room() -> void:
	if enemies.size() < MAX_ENEMIES:
		return
	for e in enemies:
		if e.is_boss or e.is_dying:
			continue
		enemies.erase(e)
		e.queue_free()
		return


func _spawn_enemy() -> void:
	_make_room()
	var e := Enemy.new()
	e.setup(wave, EnemyKinds.roll(wave))
	e.max_hp = maxi(1, roundi(float(e.max_hp) * enemy_hp_mult * vigil_hp_mult))
	e.hp = e.max_hp
	e.speed *= enemy_speed_mult

	e.position = _spawn_point()
	world.add_child(e)
	enemies.append(e)


# Just outside what you can see, then kept on the map. Spawning at the map edge
# on a large arena would mean enemies walking in from off in the dark for
# several seconds before they ever became your problem.
# Chests are placed away from you and away from the walls, so every one is a
# walk rather than a freebie.
func _scatter_chests() -> void:
	for i in CHESTS_PER_VIGIL:
		var p := Vector2.ZERO
		for attempt in 24:
			p = Vector2(
				randf_range(70.0, maxf(80.0, arena.size.x - 70.0)),
				randf_range(70.0, maxf(80.0, arena.size.y - 70.0)))
			if p.distance_to(player.position) >= CHEST_MIN_DISTANCE:
				break
		var c := Chest.new()
		c.position = p
		# ONE chest, worth what three used to be.
		#
		# Three a vigil is forty-five across a run: there was always one nearby,
		# so the decision the chest exists to create -- it is over there, the
		# wave is thickening here -- never actually came up. You just collected
		# them on the way past.
		#
		# The value triples to match, so a run pays the same gold as before and
		# the Chapel keeps its pacing. What changes is that finding one is now an
		# event worth crossing the map for. Still scaled against what killing
		# things pays: a vigil-5 wave is worth about 11 gold, and the original
		# 90-per-chest made treasure 25x the entire kill economy.
		c.value = 12 + 6 * wave
		world.add_child(c)
		chests.append(c)


func _move_chests(delta: float) -> void:
	var opened: Array[Chest] = []
	for c in chests:
		c.tick(delta)

		# A cursed chest is a two-step: the lid animates, and the cards arrive
		# when it finishes. Handing them over on contact would throw the
		# animation away, since the choice screen covers the arena.
		if c.cursed:
			if c.phase == Chest.Phase.SHUT 					and c.position.distance_to(player.position) < Player.RADIUS + Chest.RADIUS:
				c.begin_open()
				Audio.play("chest_open")
			elif c.finished_opening():
				c.phase = Chest.Phase.DONE
				opened.append(c)
			continue

		if c.position.distance_to(player.position) < Player.RADIUS + Chest.RADIUS:
			opened.append(c)

	for c in opened:
		chests.erase(c)
		var was_cursed := c.cursed
		var where := c.position
		c.queue_free()
		if was_cursed:
			_open_chest_cards()
			return                     # the screen is up; the rest can wait
		Audio.play("chest_open")
		_burst_coins(where, c.value)
		_notice = "%d GOLD" % c.value
		_notice_time = 1.8


# The chest's worth, thrown outward as real coins -- so opening one still ends
# with you chasing the money rather than just watching a number rise.
func _burst_coins(at: Vector2, total: int) -> void:
	var n := 6
	var each := int(ceil(float(total) / float(n)))
	var left := total
	for i in n:
		var v := mini(each, left)
		if v <= 0:
			break
		left -= v
		var c := Coin.new()
		c.value = v
		c.position = at
		c.velocity = Vector2.RIGHT.rotated(TAU * float(i) / float(n)) * randf_range(90.0, 150.0)
		world.add_child(c)
		coins.append(c)


func _spawn_point() -> Vector2:
	var v := view_rect().grow(40.0)
	var p := Vector2.ZERO
	match randi() % 4:
		0: p = Vector2(randf_range(v.position.x, v.end.x), v.position.y)
		1: p = Vector2(randf_range(v.position.x, v.end.x), v.end.y)
		2: p = Vector2(v.position.x, randf_range(v.position.y, v.end.y))
		_: p = Vector2(v.end.x, randf_range(v.position.y, v.end.y))
	return Vector2(
		clampf(p.x, -30.0, arena.size.x + 30.0),
		clampf(p.y, -30.0, arena.size.y + 30.0))


func _fire() -> void:
	for w in player.weapons:
		var reach := player.effective_range(w)

		# Melee and ranged both run every unlocked bolt on its own cooldown.
		for bi in w.ready_bolts():
			var bolt := w.bolt_at(bi)
			# Per BOLT, not per weapon: the Vessel's blade cuts with two of its
			# attacks and throws with the third.
			if w.bolt_is_melee(bolt):
				_fire_melee(w, bi, bolt, reach)
			else:
				_fire_ranged(w, bi, bolt, reach)


func _fire_melee(w: Weapon, bi: int, bolt: Dictionary, reach: float) -> void:
	var reach_b := reach * float(bolt.get("reach_mult", 1.0))
	var half_h := _melee_half_height(w) * float(bolt.get("height_mult", 1.0))
	var target := _melee_target(w, reach_b, half_h)
	if target == null:
		return
	# A melee weapon only ever swings left or right, because that is what its
	# animation does.
	w.aim = Vector2(1.0 if target.position.x >= player.position.x else -1.0, 0.0)
	w.note_bolt_fired(bi, 1.0 / player.effective_rate_of(w, bolt))
	player.note_cast()
	Audio.play(String(bolt.get("sfx", "swing")))
	_swing(w, reach_b, half_h, bolt)


func _fire_ranged(w: Weapon, bi: int, bolt: Dictionary, reach: float) -> void:
	# Extra projectiles pick their OWN targets rather than piling onto the same
	# one -- and so does every other bolt, because _pick_targets can see what
	# they have already committed to.
	var shots := player.effective_shots(w)
	reach *= float(bolt.get("range_mult", 1.0))
	var targets := _pick_targets(player.position, reach, shots,
		String(bolt.get("target", TARGET_NEAREST)))
	if targets.is_empty():
		return

	# Aim from the MUZZLE, not the character's position: the staff head is
	# offset from his feet, so aiming from the feet sends every shot along a
	# line parallel to the one that would have hit.
	var first: Enemy = targets[0]
	var facing_left: bool = first.position.x < player.position.x
	w.muzzle = player.muzzle_for(facing_left)
	w.aim = w.muzzle.direction_to(first.position)

	w.note_bolt_fired(bi, 1.0 / player.effective_rate_of(w, bolt))
	player.note_cast()
	Audio.play(String(bolt.get("sfx", "shoot_cinder")))
	_shoot(w, bolt, targets)


# Melee damages everything inside its box the instant it swings. The box is
# HORIZONTAL, matching the swing animation -- reach to one side, half_h above
# and below -- and is centred on the player's POSITION, not the drawn torso.
# The sprites are side-on but the gameplay is top-down: enemies home in on the
# position, so anchoring to the artwork would let a swing hit things above the
# player rather than beside them.
func _melee_half_height(w: Weapon) -> float:
	return float(w.data.get("melee_height", 26.0)) * (1.0 + player.area_pct)


func _melee_hits(w: Weapon, reach: float, half_h: float, e: Enemy) -> bool:
	var d := e.position - player.position
	var along := d.x * (-1.0 if w.aim.x < 0.0 else 1.0)
	if along < 0.0 or along > reach + e.radius:
		return false                      # behind you, or out of reach
	return absf(d.y) <= half_h + e.radius


# Nearest enemy a horizontal swing could actually reach, on either side.
func _melee_target(w: Weapon, reach: float, half_h: float) -> Enemy:
	var best: Enemy = null
	var best_d := INF
	for e in enemies:
		if e.hp <= 0 or e.is_dying:
			continue
		# A swing lands instantly so it reserves nothing, but it should still
		# not be spent on something a bolt has already killed in flight.
		if e.incoming >= e.hp:
			continue
		var d := e.position - player.position
		if absf(d.y) > half_h + e.radius:
			continue
		var along := absf(d.x)
		if along > reach + e.radius or along >= best_d:
			continue
		best_d = along
		best = e
	return best


func _swing(w: Weapon, reach: float, half_h: float, bolt: Dictionary) -> void:
	var dmg := player.effective_damage(w)
	if bolt.has("damage_mult"):
		dmg = maxi(1, roundi(float(dmg) * float(bolt["damage_mult"])))
	# One roll for the whole swing: a cut either lands well or it does not.
	var crit := player.roll_crit()
	if crit:
		dmg = player.crit_damage(dmg)
	var push := Vector2(w.aim.x, 0.0) * player.knockback
	for e in enemies:
		if e.hp <= 0 or e.is_dying:
			continue
		if _melee_hits(w, reach, half_h, e):
			e.take_damage(dmg, crit, push)


func _shoot(w: Weapon, bolt: Dictionary, targets: Array) -> void:
	var shots := player.effective_shots(w)
	var dmg := player.effective_damage(w)
	var spd := player.effective_bullet_speed(w, bolt)
	var life := player.effective_bullet_life(w, bolt)
	var pierce := player.effective_pierce(bolt, w)
	var bounces := player.effective_bounces(bolt)
	var sprite := String(bolt.get("sprite", ""))
	if bolt.has("damage_mult"):
		dmg = maxi(1, roundi(float(dmg) * float(bolt["damage_mult"])))
	dmg = maxi(1, roundi(float(dmg) * player.shot_damage_factor(w)))

	for i in shots:
		var t: Enemy = targets[i % targets.size()]
		var dir := w.muzzle.direction_to(t.position)

		# More shots than there are enemies: fan the surplus so the extras do
		# not sit exactly on top of each other.
		if i >= targets.size():
			var lap := i / targets.size()
			dir = dir.rotated(0.16 * float(lap) * (1.0 if i % 2 == 0 else -1.0))

		var b := Bullet.new()
		b.position = w.muzzle
		b.velocity = dir * spd
		b.damage = dmg
		b.life = life
		b.pierce = pierce
		b.bounces = bounces
		b.crit = player.roll_crit()
		if b.crit:
			b.damage = player.crit_damage(b.damage)
		b.size = player.effective_bullet_size(w, bolt)
		# Area widens the blast the same way it widens a swing.
		b.splash = float(bolt.get("splash", 0.0)) * (1.0 + player.area_pct)
		b.splash_mult = float(bolt.get("splash_mult", 0.5))

		# Committed the instant the bullet exists, so the next bolt fired this
		# frame -- and every frame until it lands -- can see this one is taken.
		b.reserved = t
		t.incoming += b.damage

		if sprite != "":
			b.texture = SpriteAnim.texture_for(sprite)
			b.align_to_velocity = bool(bolt.get("align", false))
			b.art_forward = float(bolt.get("art_forward", -PI * 0.5))
			b.frames = int(bolt.get("frames", 1))
			b.frame_size = bolt.get("frame", Vector2i.ZERO)
			b.fps = float(bolt.get("fps", 12.0))
			b.anim_t = randf() * 2.0
			b.angle = randf() * TAU
			b.spin = randf_range(5.0, 9.0) * (1.0 if randf() < 0.5 else -1.0)
		world.add_child(b)
		bullets.append(b)


# Nearest enemy this bullet has NOT already hit -- what a bounce leaps to.
func _nearest_unhit(from: Vector2, max_dist: float, hit_ids: Array[int]) -> Enemy:
	var best: Enemy = null
	var best_d := max_dist
	for e in enemies:
		if e.hp <= 0 or e.is_dying or hit_ids.has(e.get_instance_id()):
			continue
		var d := from.distance_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


# The N nearest live enemies within reach, closest first.
# Who this bolt should shoot at.
#
# Two things were wrong before. Every bolt independently asked for "the nearest
# enemy" and every bolt got the SAME one, so a Necromancer holding two bolts
# fired both at one target -- and unlocking a third made it worse. And nothing
# tracked damage already on its way, so three bolts would each spend a shot
# finishing a creature the first one had already killed.
#
# Both are fixed by the same idea, the one Vampire Survivors and Brotato lean
# on: an enemy with enough damage already flying at it is not a target. Enemy
# holds that as `incoming`; _shoot commits to it and _release gives it back.
# The bolts then naturally spread across the crowd without ever needing to
# coordinate with each other.
# Three levels of pickiness, tried in order. Skipping only what is ALREADY DEAD
# is not enough on its own: once enemies take three hits to kill, a single
# bolt's damage no longer covers one, so nothing is ever "already dead" and
# every bolt converges on the nearest body again -- the original complaint,
# reappearing the moment enemy health went up. Preferring a target nobody has
# shot at yet is what actually spreads them.
const CLAIM_UNTOUCHED := 0     # nothing committed to it at all
const CLAIM_SURVIVABLE := 1    # committed to, but not enough to kill it
const CLAIM_ANY := 2           # last resort: shoot something


func _pick_targets(from: Vector2, max_dist: float, count: int, mode: String) -> Array:
	var out := _top_targets(from, max_dist, count, mode, CLAIM_UNTOUCHED)
	if out.size() >= count:
		return out
	out = _top_targets(from, max_dist, count, mode, CLAIM_SURVIVABLE)
	if not out.is_empty():
		return out
	# Everything in reach is already marked for death. Shoot anyway rather than
	# stand still holding a loaded weapon -- wasted damage beats no damage, and
	# a player watching their character not fire reads it as a bug.
	return _top_targets(from, max_dist, count, mode, CLAIM_ANY)


# One pass, keeping the best `want` as it goes.
#
# The old form built a Dictionary per enemy and sorted the whole list to pick
# one target, once per bolt per shot. A late vigil puts ~200 enemies on the
# field and this runs several times a second, so that was a few hundred heap
# allocations and a sort_custom to answer a question about the top 1 to 4.
func _top_targets(from: Vector2, max_dist: float, count: int, mode: String,
		claim_level: int) -> Array:
	var want := count
	if mode == TARGET_SCATTER:
		want = maxi(count, SCATTER_POOL)      # gather a few, then choose among them
	var flip := 1.0 if mode != TARGET_FARTHEST else -1.0

	var best: Array[Enemy] = []
	var keys: Array[float] = []
	for e in enemies:
		if e.hp <= 0 or e.is_dying:
			continue
		if claim_level == CLAIM_UNTOUCHED and e.incoming > 0:
			continue
		if claim_level == CLAIM_SURVIVABLE and e.incoming >= e.hp:
			continue
		var d := from.distance_to(e.position)
		if d > max_dist:
			continue
		var key := d * flip
		var at := best.size()
		while at > 0 and key < keys[at - 1]:
			at -= 1
		if at >= want:
			continue
		best.insert(at, e)
		keys.insert(at, key)
		if best.size() > want:
			best.resize(want)
			keys.resize(want)

	if mode == TARGET_SCATTER and best.size() > count:
		best.shuffle()
		best.resize(count)
	var out := []
	for e in best:
		out.append(e)
	return out


func _nearest_enemy(from: Vector2, max_dist: float) -> Enemy:
	var best: Enemy = null
	var best_dist := max_dist
	for e in enemies:
		if e.is_dying:
			continue
		var d := from.distance_to(e.position)
		if d < best_dist:
			best_dist = d
			best = e
	return best


func _move_enemies(delta: float) -> void:
	for e in enemies:
		if e.is_dying:
			e.tick(delta, false)      # corpses still animate, but do nothing else
			continue
		var to_player := player.position - e.position
		var dist := to_player.length()

		# A ranged archetype closes only to its standoff range and throws; a
		# swinger closes to just inside its reach and plants itself. Everything
		# else walks straight at you.
		var stop_at := 0.0
		if e.is_ranged():
			stop_at = e.standoff()
		elif e.has_swing():
			stop_at = e.swing_reach() * 0.75
		# Rooted mid-swing, so stepping out of the arc always works.
		if not e.is_rooted() and dist > stop_at + 4.0 and dist > 0.001:
			e.position += (to_player / dist) * e.speed * delta

		e.position += e.knock * delta
		e.tick(delta, player.position.x < e.position.x)
		if e.wants_to_attack(dist):
			e.begin_attack()
		if e.consume_attack():
			if e.is_ranged():
				_foe_throw(e)
			else:
				_foe_swing(e)
		if dist < e.radius + Player.RADIUS and e.can_touch():
			e.note_touched()
			player.take_damage(e.damage)   # returns false on a dodge; nothing else to undo


func _move_bullets(delta: float) -> void:
	var spent: Array[Bullet] = []
	var bounds := arena.grow(40.0)
	for b in bullets:
		b.position += b.velocity * delta
		b.advance(delta)
		b.life -= delta
		if b.life <= 0.0 or not bounds.has_point(b.position):
			spent.append(b)
			continue
		for e in enemies:
			if e.hp <= 0 or e.is_dying or b.hit_ids.has(e.get_instance_id()):
				continue
			if b.position.distance_to(e.position) < e.radius + b.size:
				# The damage is real now rather than pending, so the claim ends
				# here whether or not this was the enemy it was aimed at.
				_release(b)
				Audio.play("enemy_hit", 0.13)
				e.take_damage(b.damage, b.crit, b.velocity.normalized() * player.knockback)
				b.hit_ids.append(e.get_instance_id())
				if b.splash > 0.0:
					_splash(b, e)

				if b.bounces > 0:
					var next := _nearest_unhit(b.position, BOUNCE_RANGE, b.hit_ids)
					if next != null:
						b.bounces -= 1
						b.velocity = b.position.direction_to(next.position) * b.velocity.length()
						b.life = maxf(b.life, BOUNCE_RANGE / maxf(b.velocity.length(), 1.0) * 1.3)
						break                 # it has changed course; done this frame
					spent.append(b)
					break

				if b.pierce <= 0:
					spent.append(b)
					break
				b.pierce -= 1
	for b in spent:
		_release(b)
		bullets.erase(b)
		b.queue_free()


# The blast around a hit. Everything inside the radius except the thing that was
# actually struck takes a share of the damage.
#
# Splash reserves nothing (see _release): it lands in the same instant it is
# dealt, so there is no in-flight window for another bolt to see. It also does
# not add to hit_ids -- a bystander burned by one flame is still a legitimate
# target for the next.
func _splash(b: Bullet, hit: Enemy) -> void:
	var share := maxi(1, roundi(float(b.damage) * b.splash_mult))
	for e in enemies:
		if e == hit or e.hp <= 0 or e.is_dying:
			continue
		var d := e.position.distance_to(b.position)
		if d > b.splash + e.radius:
			continue
		e.take_damage(share, false, (e.position - b.position).normalized() * player.knockback * 0.5)
	_bursts.append({"pos": b.position, "r": b.splash, "t": 0.0})


# A claim has to be given back exactly once, on every path that ends it: the
# bullet landing, expiring, or leaving the arena. Miss one and that enemy stays
# permanently invisible to targeting -- alive, walking at you, and never shot
# at again.
func _release(b: Bullet) -> void:
	if b.reserved == null:
		return
	if is_instance_valid(b.reserved):
		b.reserved.incoming = maxi(0, b.reserved.incoming - b.damage)
	b.reserved = null


# Death is a state, not an instant free: a corpse plays its death animation
# while being ignored by targeting, collision and movement.
func _reap_enemies() -> void:
	var gone: Array[Enemy] = []
	for e in enemies:
		if e.hp <= 0 and not e.is_dying:
			e.begin_death()
			Audio.play("enemy_die", 0.11)
			if e.is_boss:
				_drop_cursed_chest(e.position)
			kills += 1
			_drop_orbs(e.position, (e.motes + player.mote_bonus) * vigil_mote_mult)
			_drop_coin(e)
			if player.heal_on_kill > 0:
				player.heal(player.heal_on_kill)
		if e.is_dying and e.death_finished():
			gone.append(e)
			if e == boss:
				boss = null
	for e in gone:
		enemies.erase(e)
		e.queue_free()


# A boss leaves a Cursed Chest where it fell. Dropped on DEATH rather than on
# despawn, so it lands under the corpse while the death animation is still
# playing and reads as something the boss was carrying.
func _drop_cursed_chest(at: Vector2) -> void:
	var c := Chest.new()
	c.make_cursed()
	c.value = 0                        # it pays in cards, not coin
	c.position = Vector2(
		clampf(at.x, 40.0, arena.size.x - 40.0),
		clampf(at.y, 40.0, arena.size.y - 40.0))
	world.add_child(c)
	chests.append(c)
	_notice = "IT LEFT SOMETHING"
	_notice_time = 2.4


# Tougher archetypes leave more behind, so clearing an Abomination is worth the
# trouble it took. The value is split across at most ORB_MAX_DROP motes rather
# than one per point: a late vigil kills ~270 things worth ~570 motes between
# them, and that many nodes on the floor is clutter as much as it is cost.
# Bigger motes are drawn bigger, so a fat one still reads as a fat reward.
func _drop_orbs(at: Vector2, total: int) -> void:
	var want := maxi(1, total)
	var n := mini(want, ORB_MAX_DROP)
	var each := int(ceil(float(want) / float(n)))
	var left := want
	for i in n:
		var v := mini(each, left)
		if v <= 0:
			break
		left -= v
		var o := Orb.new()
		o.value = v
		o.position = at
		o.velocity = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(20.0, ORB_SCATTER)
		world.add_child(o)
		orbs.append(o)


func _foe_throw(e: Enemy) -> void:
	var spec: Dictionary = e.ranged
	var b := Bullet.new()
	b.position = e.position + Vector2(0.0, -8.0)
	b.velocity = b.position.direction_to(player.position) * float(spec.get("bolt_speed", 200.0))
	b.damage = e.damage
	b.size = float(spec.get("bolt_size", 6.0))
	b.life = (e.standoff() * 1.6) / maxf(b.velocity.length(), 1.0)
	b.tint = Palette.BLOOD_BRIGHT
	world.add_child(b)
	foe_bullets.append(b)


# The blow lands when the wind-up ends, and only if you are still inside the
# arc -- which is what makes the telegraph mean something.
func _foe_swing(e: Enemy) -> void:
	if player.position.distance_to(e.position) > e.swing_reach() + Player.RADIUS:
		return
	player.take_damage(maxi(1, roundi(float(e.damage) * float(e.melee_attack.get("damage_mult", 1.0)))))


func _move_foe_bullets(delta: float) -> void:
	var spent: Array[Bullet] = []
	var bounds := arena.grow(60.0)
	for b in foe_bullets:
		b.position += b.velocity * delta
		b.life -= delta
		if b.life <= 0.0 or not bounds.has_point(b.position):
			spent.append(b)
			continue
		if b.position.distance_to(player.position) < Player.RADIUS + b.size:
			player.take_damage(b.damage)
			spent.append(b)
	for b in spent:
		foe_bullets.erase(b)
		b.queue_free()


# Gold drops on a roll, not on a rule. Luck raises the chance; once the chance
# would pass 100% the overflow raises the VALUE instead, so Luck never stops
# doing anything for an enemy that already always drops. META.md section 2.
func _drop_coin(e: Enemy) -> void:
	if e.gold <= 0 or e.gold_chance <= 0.0:
		return
	var raw := e.gold_chance * (1.0 + LUCK_GOLD * player.luck)
	if randf() > minf(raw, 1.0):
		return
	var c := Coin.new()
	c.value = maxi(1, roundi(float(e.gold) * maxf(raw, 1.0)))
	c.position = e.position
	c.velocity = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(25.0, ORB_SCATTER)
	world.add_child(c)
	coins.append(c)


# Coins are pulled like motes, but they BANK the instant they are touched --
# die a second later and the gold is still yours.
func _move_coins(delta: float) -> void:
	var taken: Array[Coin] = []
	var vis := view_rect().grow(40.0)
	for c in coins:
		c.tick(delta, vis)
		var to_player := player.position - c.position
		var dist := to_player.length()
		if dist <= player.pickup_range():
			c.pulled = true
		if c.pulled:
			c.velocity = c.velocity.move_toward(to_player.normalized() * 340.0, Coin.PULL * delta)
		else:
			c.velocity = c.velocity.move_toward(Vector2.ZERO, Coin.DRAG * 60.0 * delta)
		c.position += c.velocity * delta
		if dist < Player.RADIUS + Coin.RADIUS + 2.0:
			taken.append(c)
	for c in taken:
		coins.erase(c)
		Audio.play("coin_pickup", 0.09)
		run_gold += c.value
		Profile.bank(c.value)
		c.queue_free()


# A flame going out: a ring that opens and fades, with a hot centre that does
# not. Drawn rather than particled, like everything else here.
func _draw_bursts() -> void:
	for b in _bursts:
		var k: float = float(b["t"]) / BURST_LIFE
		var fade := 1.0 - k
		var r: float = float(b["r"]) * (0.40 + 0.75 * k)
		var at: Vector2 = b["pos"]
		_burst_layer.draw_circle(at, r * 0.92, Color(Palette.BLOOD, 0.16 * fade))
		_burst_layer.draw_arc(at, r, 0.0, TAU, 18, Color(Palette.BLOOD_BRIGHT, 0.65 * fade), 2.0)
		_burst_layer.draw_circle(at, r * 0.28 * fade, Color(1.0, 0.86, 0.62, 0.75 * fade))


func _tick_bursts(delta: float) -> void:
	var i := _bursts.size() - 1
	while i >= 0:
		_bursts[i]["t"] = float(_bursts[i]["t"]) + delta
		if float(_bursts[i]["t"]) >= BURST_LIFE:
			_bursts.remove_at(i)
		i -= 1
	# Only ask for a frame while there is something to show -- an empty layer
	# redrawing sixty times a second is the cost this project keeps paying for.
	if _burst_layer != null and not _bursts.is_empty():
		_burst_layer.queue_redraw()


func _move_orbs(delta: float) -> void:
	var taken: Array[Orb] = []
	var vis := view_rect().grow(40.0)
	for o in orbs:
		o.tick(delta, vis)
		var to_player := player.position - o.position
		var dist := to_player.length()

		# Once a mote has been caught it stays caught, so it cannot be shaken
		# off by running past it.
		if dist <= player.pickup_range():
			o.pulled = true

		if o.pulled:
			o.velocity = o.velocity.move_toward(
				to_player.normalized() * 340.0, Orb.PULL * delta)
		else:
			o.velocity = o.velocity.move_toward(Vector2.ZERO, Orb.DRAG * 60.0 * delta)

		o.position += o.velocity * delta
		if dist < Player.RADIUS + o.radius() + 2.0:
			taken.append(o)

	for o in taken:
		orbs.erase(o)
		o.queue_free()
		Audio.play("mote_pickup", 0.12)
		_pending_levels += player.gain_xp(o.value)


func _collect_all_orbs() -> void:
	for o in orbs:
		_pending_levels += player.gain_xp(o.value)
		o.queue_free()
	orbs.clear()


func _end_vigil() -> void:
	Audio.play("vigil_end", 0.0)
	_collect_all_orbs()        # nothing left on the floor goes to waste
	_clear_field()
	# What this vigil actually cost, measured against the snapshot taken when it
	# began. kills and run_gold are cumulative, so the per-vigil figure is a
	# difference rather than a counter -- one less thing to remember to reset.
	_tally_kills = kills - _kills_at_vigil
	_tally_gold = run_gold - _gold_at_vigil
	_tally_hurt = maxi(0, _hp_at_vigil - player.hp)
	_tally_t = 0.0
	state = State.TALLY


func _tick_tally(delta: float) -> void:
	_tally_t += delta      # the writing advances; the screen does not


# Any key, any click, once the moment has had a chance to land. Without the
# delay the keypress that was still down from choosing a direction would skip
# the screen before it drew a single stroke.
func _skip_tally() -> void:
	if state == State.TALLY and _tally_t >= TALLY_SKIP_AFTER:
		_advance_intermission()


# Levels earned during a vigil are spent at the END of it, Brotato-style, one
# pact screen each, and the vigil's own pact comes last. Interrupting a fight
# to shop is Vampire Survivors' model, and it lands while you are surrounded.
func _advance_intermission() -> void:
	if _pending_levels > 0:
		_open_pact_screen(PactReason.LEVEL)
	else:
		_open_pact_screen(PactReason.VIGIL)


# Reuses the pact screen wholesale -- same cards, same rarity colours, same
# mouse and keyboard selection -- because a chest card and a pact are the same
# shape and there is no reason for the player to learn a second screen.
func _open_chest_cards() -> void:
	_pact_reason = PactReason.CHEST
	offers = ChestCards.roll(CHEST_CARDS)
	_choice_t = 0.0
	state = State.SHOP


# What the next reroll costs. Escalates within one screen, so the fourth is a
# real decision even when the first was cheap.
func reroll_cost() -> int:
	var first := maxi(1, int(floor(float(wave) * 0.75)))
	var step := maxi(1, int(floor(float(wave) * 0.40)))
	return first + _rerolls * step


# A chest's three cards are a boss reward and cannot be rerolled -- letting you
# spin them would make the thing you killed a slot machine.
func can_reroll() -> bool:
	return state == State.SHOP and _pact_reason != PactReason.CHEST 		and Profile.gold >= reroll_cost()


func _do_reroll() -> void:
	if not can_reroll():
		return
	var cost := reroll_cost()
	Profile.gold -= cost
	run_gold = maxi(0, run_gold - cost)      # so the HUD does not claim gold you spent
	_rerolls += 1
	offers = _roll_offers()
	_hover = -1
	_choice_t = 0.0                          # the cards arrive again, not blink
	Audio.play("chest_open", 0.10)


func _open_pact_screen(reason: PactReason) -> void:
	_pact_reason = reason
	_rerolls = 0
	offers = _roll_offers()
	_choice_t = 0.0
	state = State.SHOP


# Each slot rolls a TIER first, then a pact within it. Rolling from the flat
# pool instead would make a Damned pact no rarer than a Common one -- rarity
# has to live in the roll, not in how many of each exist.
func _roll_offers() -> Array:
	var picked := []
	var used := {}
	for slot in OFFER_COUNT:
		var p := _roll_one(Pacts.roll_tier(wave, player.luck), used)
		if p.is_empty():
			break
		used[p["id"]] = true
		picked.append(p)
	return picked


# The rolled tier if it still has anything to give, then the others as
# fallbacks -- so a screen fills up even when a tier is exhausted or every pact
# in it is already at MAX_STACKS. Falling DOWN before falling up: running out of
# Damned should hand you a Grim, not silently upgrade you.
func _roll_one(tier: int, used: Dictionary) -> Dictionary:
	var order := [tier]
	for t in [2, 1, 3]:
		if t != tier:
			order.append(t)
	for t in order:
		var pool := []
		for p in Pacts.of_tier(t):
			if used.has(p["id"]):
				continue
			if int(pact_counts.get(p["id"], 0)) >= MAX_STACKS:
				continue
			pool.append(p)
		if not pool.is_empty():
			return pool[randi() % pool.size()]
	return {}


func _clear_field() -> void:
	for e in enemies:
		e.queue_free()
	enemies.clear()
	for o in orbs:
		o.queue_free()
	orbs.clear()
	# Coins are NOT swept up the way motes are. One you did not reach is one
	# you did not earn -- that is what makes going after them a decision.
	for c in coins:
		c.queue_free()
	coins.clear()
	# An unopened chest is lost with everything else on the floor.
	for c in chests:
		c.queue_free()
	chests.clear()
	for b in bullets:
		b.queue_free()
	bullets.clear()
	_bursts.clear()
	for b in foe_bullets:
		b.queue_free()
	foe_bullets.clear()


func _swear_pact(pact: Dictionary) -> void:
	var id: String = pact["id"]
	held_pacts.append(id)
	pact_counts[id] = int(pact_counts.get(id, 0)) + 1
	corruption += int(pact.get("corruption", 0))
	_apply_boon(id)


# Which kind of vigil this is, and what that does to the field. Rolled fresh
# each run rather than fixed, so knowing vigil 11 is special does not tell you
# which special it is.
func _set_vigil_kind() -> void:
	vigil_kind = VigilKind.NORMAL
	vigil_hp_mult = 1.0
	vigil_spawn_mult = 1.0
	vigil_mote_mult = 1
	if not SPECIAL_VIGILS.has(wave):
		return
	if randf() < HORDE_CHANCE:
		vigil_kind = VigilKind.HORDE
		vigil_spawn_mult = 3.0
		vigil_hp_mult = 0.40
		_notice = "THE HORDE"
	else:
		vigil_kind = VigilKind.ELITE
		vigil_spawn_mult = 0.35
		vigil_hp_mult = 2.60
		vigil_mote_mult = 2
		_notice = "THEY COME ALONE"
	_notice_time = 3.0


func _begin_vigil() -> void:
	Audio.play("vigil_start", 0.0)
	wave += 1
	wave_time_left = vigil_length(wave)
	spawn_timer = 0.0
	_set_vigil_kind()          # before the boss and the chests, so the notice lands first
	player.heal(VIGIL_SURVIVAL_HEAL)
	# Snapshotted after the heal, so the health you were given for surviving is
	# not counted back as harm you avoided.
	_kills_at_vigil = kills
	_gold_at_vigil = run_gold
	_hp_at_vigil = player.hp

	Profile.save_all()      # a crash costs at most one vigil of gold
	RunSave.save(self)      # ...and at most one vigil of the run itself

	_summon_boss()
	_scatter_chests()

	# Surviving a vigil frees another of your projectiles.
	var freed := player.unlock_next_bolt()
	if freed != "":
		_notice = "%s ANSWERS YOU" % freed.to_upper()
		_notice_time = 3.5

	state = State.PLAYING


# --- pacts -----------------------------------------------------------------

# Applied ONCE, the moment the pact is sworn, and never revisited. These write
# MODIFIERS, never absolute weapon stats -- see player.gd.
# Taking a card out of a Cursed Chest.
#
# Deliberately separate from _apply_boon rather than folded into it: chest
# cards are a different pool with a different source and a different power
# budget, and when the real cards replace the placeholders they will want to do
# things a pact cannot. Keeping the two apart means that day is an edit here
# rather than an untangling.
#
# PLACEHOLDER EFFECTS -- see chest_cards.gd. Anything unrecognised is a loud
# no-op rather than a silent one, because a card that does nothing is worse
# than a card that is missing.
func _take_card(card: Dictionary) -> void:
	var id := String(card.get("id", ""))
	held_pacts.append(id)          # so it shows in SWORN and on the death screen
	match id:
		"cc_gilded_ruin":
			player.damage_bonus += 28
		"cc_split_coin":
			player.extra_shots += 1
		"cc_kingsblood":
			player.max_hp += 55
			player.heal(player.max_hp)
		"cc_hoarders_eye":
			player.mote_bonus += 2
		"cc_unquiet_blade":
			player.rate_pct += 0.55
		"cc_sepulchre_iron":
			player.armor += 5
			player.damage_taken_pct += 0.15
		"cc_long_count":
			player.pierce_bonus += 1
			player.bounce_bonus += 1
		"cc_dead_kings_favour":
			player.luck += 2.0
		"cc_reliquary":
			player.revives += 1
		"cc_wolfs_hour":
			player.crit_chance = minf(player.crit_chance + 0.20, 1.0)
			player.crit_mult += 0.40
		_:
			push_error("chest card '%s' has no effect" % id)
	_notice = String(card.get("name", "")).to_upper()
	_notice_time = 2.0


func _apply_boon(id: String) -> void:
	match id:
		"blood_price":
			player.damage_bonus += 9
		"fevered_hands":
			player.rate_pct += 0.42
		"fleet_dread":
			player.speed_pct += 0.26
		"grave_vigour":
			player.max_hp += 30
			player.heal(30)
		"long_stare":
			player.range_bonus += 70.0
		"gluttony":
			player.heal_on_kill += 4
		"swift_judgment":
			player.bullet_speed_pct += 0.50
			player.damage_bonus += 2
		"iron_bargain":
			player.max_hp += 45
		"hungering_dark":
			player.damage_pct += 0.30
		"ashen_skin":
			player.damage_taken_pct += 0.30
		"widows_gift":
			player.damage_bonus += 16
		"candleflame":
			player.heal(player.max_hp)
		"thousand_cuts":
			player.rate_pct += 0.50
		"watchers_eye":
			player.range_bonus += 90.0
			player.bullet_speed_pct += 0.18
		"whetstone":
			player.damage_pct += 0.32
		"grave_plate":
			player.armor += 3
		"swollen_heart":
			var before := player.max_hp
			player.grow_max_hp_pct(0.25)
			player.heal(player.max_hp - before)
		"rotwort":
			player.regen += 1.5
		"empty_psalter":
			player.rate_pct += 0.46
		"wide_censer":
			player.area_pct += 0.40
		"dried_sinew":
			player.bullet_speed_pct += 0.55
		"lingering_word":
			player.bullet_life_pct += 0.70
		"split_tongue":
			player.extra_shots += 1
		"carrion_wings":
			player.speed_pct += 0.32
		"second_breath":
			player.revives += 1
		"sure_cut":
			player.crit_chance = minf(player.crit_chance + 0.12, 1.0)
		"executioners_eye":
			player.crit_mult += 0.35
		"smoke_and_ash":
			player.dodge = minf(player.dodge + 0.09, Player.DODGE_CAP)
		"long_shadow":
			player.dodge = minf(player.dodge + 0.05, Player.DODGE_CAP)
		"boneshear":
			player.pierce_bonus += 1
		"ricochet_psalm":
			player.bounce_bonus += 1
		"black_fortune":
			player.luck += 1.0
		"iron_wind":
			player.knockback += 130.0
		"lodestone":
			player.pickup_pct += 0.80
		"grave_wisdom":
			player.xp_pct += 0.45


# --- atmosphere ------------------------------------------------------------

# Drifting embers. Cheap, and motion sells a mood better than detail does.
func _seed_embers() -> void:
	_embers.clear()
	for i in 90:
		_embers.append({
			"pos": Vector2(randf() * 1920.0, randf() * 1080.0),
			"vel": Vector2(randf_range(-8.0, 8.0), randf_range(-26.0, -9.0)),
			"size": randf_range(1.0, 2.6),
			"a": randf_range(0.10, 0.5),
			"phase": randf() * TAU,
		})


func _tick_embers(delta: float) -> void:
	for e in _embers:
		e["phase"] += delta
		e["pos"] += e["vel"] * delta + Vector2(sin(e["phase"]) * 7.0 * delta, 0.0)
		if e["pos"].y < -10.0:
			e["pos"] = Vector2(randf() * screen.x, screen.y + 10.0)


# --- character portraits ---------------------------------------------------

func _build_portraits() -> void:
	_portraits.clear()
	for c in Characters.ALL:
		var anims: Dictionary = c.get("anims", {})
		if anims.has("idle"):
			var a := SpriteAnim.new()
			a.frame_size = c.get("frame", Vector2i(64, 64))
			a.pivot = c.get("pivot", Vector2(32.0, 32.0))
			a.scale = float(c.get("scale", 1.0)) * 2.4
			a.play("idle", anims["idle"])
			_portraits.append(a)
		else:
			_portraits.append(null)


func _tick_portraits(delta: float) -> void:
	for a in _portraits:
		if a != null:
			a.advance(delta)


# --- HUD -------------------------------------------------------------------

func _draw() -> void:
	if player == null:
		return

	if state == State.CHARACTER:
		_draw_character_screen()
		return

	_draw_chest_markers()
	_draw_vignette()
	_draw_status()
	match state:
		State.PLAYING:
			_draw_vigil_clock()
			if _notice_time > 0.0:
				var a := clampf(_notice_time / 1.2, 0.0, 1.0)
				_text_center(screen.x * 0.5, 176.0, _notice, 42, Color(Palette.BLOOD_BRIGHT, a))
		State.SHOP:
			if _pact_reason == PactReason.CHEST:
				_draw_choice_screen("THE CURSED CHEST",
					"it was carrying this. take one, and leave the rest.")
			elif _pact_reason == PactReason.LEVEL:
				var sub := "level %d. it has been watching you kill. take one." % player.level
				if _pending_levels > 1:
					sub = "level %d, and %d more to answer for." % [player.level, _pending_levels - 1]
				_draw_choice_screen("THE DARK TAKES NOTICE", sub)
			else:
				_draw_choice_screen("THE VIGIL HOLDS",
					"something in the dark offers you power. take one.")
		State.TALLY:
			_draw_tally()
		State.DEAD:
			_draw_death()


# The vigil you just held, written down.
#
# Everything arrives in sequence rather than together: the ground darkens, the
# frame is drawn edge by edge, the number lands, the rule is struck under it,
# then the tally counts itself out. A screen where everything appears at once is
# a screen with no rhythm, and rhythm is most of what makes a beat feel earned.
func _draw_tally() -> void:
	var t := _tally_t
	var cx := screen.x * 0.5
	var cy := screen.y * 0.45

	draw_rect(Rect2(0, 0, screen.x, screen.y),
		Color(0.0, 0.0, 0.0, 0.78 * clampf(t / 0.22, 0.0, 1.0)))

	var boil := CardFace.boil_frame(t)
	var panel := Rect2(cx - 330.0, cy - 150.0, 660.0, 320.0)
	CardFace.set_hand("tally%d" % wave, boil)
	CardFace.box_drawn(self, panel, clampf((t - 0.08) / 0.42, 0.0, 1.0),
		Color(Palette.BONE_DIM, 0.55), 2.2, 2.4)

	# The number, struck in. It overshoots its size and settles, the way a
	# stamp bounces.
	var pop := clampf((t - 0.30) / 0.26, 0.0, 1.0)
	if pop > 0.0:
		var swell := 1.0 + 0.35 * (1.0 - pop) - 0.12 * sin(pop * PI)
		var size := int(96.0 * swell)
		var label := "VIGIL %d" % wave
		# a soft shadow first, so it reads over the dungeon behind
		_text_center(cx + 3.0, cy - 44.0 + 3.0, label, size, Color(0.0, 0.0, 0.0, 0.5 * pop))
		_text_center(cx, cy - 44.0, label, size, Color(Palette.BONE, pop))

	# struck through, left to right
	CardFace.set_hand("tallyrule%d" % wave, boil)
	CardFace.stroke_drawn(self, Vector2(cx - 250.0, cy - 14.0), Vector2(cx + 250.0, cy - 14.0),
		clampf((t - 0.52) / 0.30, 0.0, 1.0), Color(Palette.BLOOD_BRIGHT, 0.9), 3.0, 2, 2.0)

	var held := "HELD"
	if _tally_hurt > 0 and player.hp <= player.max_hp / 4:
		held = "HELD, BARELY"
	var sub_a := clampf((t - 0.62) / 0.24, 0.0, 1.0)
	_text_center(cx, cy + 26.0, held, 34, Color(Palette.BLOOD_BRIGHT, sub_a))

	# the tally, counting itself out one line at a time
	var rows := [
		["%d slain" % _tally_kills, Palette.BONE_DIM],
		["%d gold taken" % _tally_gold, Palette.COIN],
		["%d harm suffered" % _tally_hurt if _tally_hurt > 0 else "untouched",
			Palette.BLOOD_BRIGHT if _tally_hurt > 0 else Palette.XP_MID],
	]
	for i in rows.size():
		var ra := clampf((t - 0.86 - float(i) * 0.16) / 0.22, 0.0, 1.0)
		if ra <= 0.0:
			continue
		# slides up the last few pixels as it lands
		_text_center(cx, cy + 74.0 + float(i) * 34.0 + (1.0 - ra) * 8.0,
			rows[i][0], 27, Color(rows[i][1], ra))

	# Now that nothing advances on its own, this is an instruction rather than a
	# footnote -- so it breathes, to read as the screen waiting on you.
	var hint := clampf((t - TALLY_DRAW_TIME * 0.62) / 0.4, 0.0, 1.0)
	if hint > 0.0:
		var breath := 0.62 + 0.38 * (0.5 + 0.5 * sin(t * 2.6))
		_text_center(cx, panel.end.y + 46.0, "click, or press anything, to go on", 22,
			Color(Palette.BONE_DIM, breath * hint))


# Frames what you can see, not the map. Nested unfilled rects darkening
# outward -- cheap, and it pulls the eye to the middle of the screen where the
# fight is.
# A chest you cannot see is a chest you will never walk to. Anything off-screen
# gets a marker pinned at the screen edge, pointing the way.
func _draw_chest_markers() -> void:
	if state != State.PLAYING:
		return
	var v := view_rect()
	var centre := view_centre()
	for c in chests:
		if v.grow(-20.0).has_point(c.position):
			continue
		var dir := (c.position - centre)
		if dir.length() < 1.0:
			continue
		dir = dir.normalized()
		var edge := screen * 0.5 + dir * (minf(screen.x, screen.y) * 0.40)
		var pulse := 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.004)
		draw_circle(edge, 13.0, Color(Palette.COIN, 0.16 * pulse))
		var tip := edge + dir * 13.0
		var a := edge + dir.rotated(2.5) * 10.0
		var b := edge + dir.rotated(-2.5) * 10.0
		draw_colored_polygon(PackedVector2Array([tip, a, b]), Color(Palette.COIN, 0.9))


func _draw_vignette() -> void:
	for i in 14:
		var inset := float(i) * 11.0
		var a := 0.06 * (1.0 - float(i) / 14.0)
		draw_rect(Rect2(inset, inset, screen.x - inset * 2.0, screen.y - inset * 2.0),
			Color(0.0, 0.0, 0.0, a), false, 11.0)


func _draw_status() -> void:
	draw_rect(Rect2(32, 32, 440, 34), Palette.ASH_DIM)
	var frac := clampf(float(player.hp) / float(maxi(player.max_hp, 1)), 0.0, 1.0)
	draw_rect(Rect2(32, 32, 440.0 * frac, 34), Palette.BLOOD)
	_text(Vector2(42, 58), "%d / %d" % [maxi(player.hp, 0), player.max_hp], 24)

	# Soul motes collected toward the next level.
	draw_rect(Rect2(32, 76, 440, 14), Palette.ASH_DIM)
	var xf := clampf(float(player.xp) / float(maxi(player.xp_to_next(), 1)), 0.0, 1.0)
	draw_rect(Rect2(32, 76, 440.0 * xf, 14), Palette.BONE_DIM)
	_text_right(472.0, 74.0, "LEVEL %d   %d/%d" % [player.level, player.xp, player.xp_to_next()],
		20, Palette.ASH)

	_text(Vector2(32, 130), "VIGIL %d" % wave, 34)
	_text(Vector2(32, 164), "%d slain" % kills, 24, Palette.BONE_DIM)
	_text(Vector2(32, 194), "%d gold" % run_gold, 24, Palette.COIN)
	if player.revives > 0:
		_text(Vector2(32, 222), "%d breath left" % player.revives, 22, Palette.BLOOD_BRIGHT)

	_draw_minimap()
	_draw_carried()
	_draw_held_pacts()
	_draw_boss_bar()


# The vigil clock. Top centre, because it is the one number you end up watching
# without deciding to, and the corner of the screen is where numbers go to be
# ignored.
#
# It reddens and swells over the last ten seconds, one pulse a second, so "very
# nearly through" arrives in peripheral vision rather than needing to be read.
func _draw_vigil_clock() -> void:
	var left := maxf(wave_time_left, 0.0)
	var cx := screen.x * 0.5
	var size := 52
	var col := Palette.BONE_DIM
	if left <= 10.0:
		var beat := 0.5 + 0.5 * cos(left * TAU)
		col = Palette.BONE_DIM.lerp(Palette.BLOOD_BRIGHT, 0.35 + 0.65 * beat)
		size += int(6.0 * beat)
	# A little ground behind it, so it stays legible when a brazier lights the
	# floor underneath.
	draw_rect(Rect2(cx - 92.0, 10.0, 184.0, 66.0), Color(0.0, 0.0, 0.0, 0.38))
	_text_center(cx, 62.0, "%0.1f" % left, size, col)


# Where the rest of the arena is.
#
# The map is 2x2 screens and the view only ever shows a quarter of it, so the
# chest that expires when the vigil does, and the horde massing on a side you
# are not looking at, are both permanently out of sight. The off-screen chest
# markers pinned to the screen edge say which DIRECTION; this says how far, and
# what else is over there.
#
# Deliberately sparse. No motes, no coins, no floor, and no rectangle marking
# what is already on screen -- you can see what is on screen by looking at it.
# Everything drawn here is something you cannot otherwise know.
#
# The frame is chapel masonry rather than UI chrome: PIT for the dark inside,
# WALL_CAP for the edge, the same two values the dungeon walls are built from.
func _draw_minimap() -> void:
	# At 1x1 the whole arena is already in front of you and this would be a
	# smaller, worse copy of the screen.
	if MAP_SCREENS.x <= 1.0 and MAP_SCREENS.y <= 1.0:
		return

	var r := _minimap_rect()
	var k := r.size / arena.size            # world units -> minimap units

	draw_rect(r.grow(2.0), Color(0.0, 0.0, 0.0, 0.45))
	draw_rect(r, Color(Palette.PIT, 0.88))
	draw_rect(r, Palette.WALL_CAP, false, 1.0)

	# Corner ticks. A plain outline this small reads as an unfinished box; four
	# brighter corners give it an edge to end at without drawing a heavy frame
	# around information that is mostly empty space.
	var t := 9.0
	for c in [[r.position, 1.0, 1.0], [Vector2(r.end.x, r.position.y), -1.0, 1.0],
			[Vector2(r.position.x, r.end.y), 1.0, -1.0], [r.end, -1.0, -1.0]]:
		var p: Vector2 = c[0]
		var sx: float = c[1]
		var sy: float = c[2]
		draw_line(p, p + Vector2(t * sx, 0.0), Palette.BONE_DIM, 1.0)
		draw_line(p, p + Vector2(0.0, t * sy), Palette.BONE_DIM, 1.0)

	# Chests are SQUARES, everything alive is a circle. At three pixels a shape
	# difference carries further than a hue difference does -- the same reason
	# a coin is a flat disc and a mote is a haloed orb.
	for c in chests:
		var cp := r.position + c.position * k
		draw_rect(Rect2(cp - Vector2(3.4, 3.4), Vector2(6.8, 6.8)), Palette.VOID)
		draw_rect(Rect2(cp - Vector2(2.2, 2.2), Vector2(4.4, 4.4)), Palette.COIN)
	for e in enemies:
		if e.is_dying:
			continue
		var ep := r.position + e.position * k
		if e.is_boss:
			draw_circle(ep, 4.6, Palette.VOID)
			draw_circle(ep, 3.2, Palette.BLOOD_BRIGHT)
		else:
			draw_circle(ep, 1.7, Palette.BLOOD_BRIGHT)

	# Drawn last, so it is never buried under the horde standing on top of you.
	var at := r.position + player.position * k
	draw_circle(at, 4.2, Palette.VOID)
	draw_circle(at, 2.8, Palette.BONE)


func _minimap_rect() -> Rect2:
	var h := MINIMAP_W * (arena.size.y / maxf(arena.size.x, 1.0))
	return Rect2(screen.x - MINIMAP_W - MINIMAP_PAD, MINIMAP_PAD, MINIMAP_W, h)


# A wide bar across the top while a boss lives. A different shape from your own
# health, so the two are never confused at a glance.
#
# It sits BELOW the vigil clock, and carries its name inside itself rather than
# under it -- stacked under the clock there was no room left for a second line
# before it ran into the notice text.
func _draw_boss_bar() -> void:
	if boss == null or not is_instance_valid(boss) or boss.is_dying:
		return
	var w := 900.0
	var x := screen.x * 0.5 - w * 0.5
	var y := 86.0
	var h := 30.0
	draw_rect(Rect2(x - 3.0, y - 3.0, w + 6.0, h + 6.0), Color(Palette.BONE, 0.18))
	draw_rect(Rect2(x, y, w, h), Palette.VOID_LIT)
	var frac := clampf(float(boss.hp) / float(maxi(boss.max_hp, 1)), 0.0, 1.0)
	draw_rect(Rect2(x, y, w * frac, h), Palette.BLOOD)
	_text_center(screen.x * 0.5, y + 22.0, String(boss.kind.get("name", "")).to_upper(),
		22, Palette.BONE)


func _draw_carried() -> void:
	if player.weapons.is_empty():
		return
	_text(Vector2(screen.x - 400.0, 166.0), "CARRIED", 22, Palette.ASH)
	for i in player.weapons.size():
		var w: Weapon = player.weapons[i]
		_text(Vector2(screen.x - 400.0, 192.0 + float(i) * 52.0),
			"%s   %d dmg  x%0.1f/s" % [w.data.get("name", "?"),
				player.effective_damage(w), player.effective_rate(w)],
			22, Palette.BONE_DIM)
		if not w.bolts().is_empty():
			var parts := []
			for bi in w.live_bolt_count():
				var bd := w.bolt_at(bi)
				parts.append("%s x%0.1f/s" % [bd.get("name", "?"), player.effective_rate_of(w, bd)])
			if w.has_locked_bolts():
				parts.append("+%d sealed" % (w.bolts().size() - w.live_bolt_count()))
			_text(Vector2(screen.x - 384.0, 218.0 + float(i) * 52.0),
				"throws %s" % ", ".join(parts), 19, Palette.ASH)


# The player must be able to watch the debt pile up. This list is the game
# telling you, every second, exactly what you agreed to.
func _draw_held_pacts() -> void:
	if held_pacts.is_empty():
		return
	_text(Vector2(32, 264), "SWORN", 22, Palette.ASH)
	var shown := mini(held_pacts.size(), 14)
	for i in shown:
		_text(Vector2(32, 296.0 + float(i) * 27.0), Pacts.name_of(held_pacts[i]), 21, Palette.BLOOD_BRIGHT)
	if held_pacts.size() > shown:
		_text(Vector2(32, 296.0 + float(shown) * 27.0),
			"+%d more" % (held_pacts.size() - shown), 21, Palette.BONE_DIM)


func _draw_death() -> void:
	var c := screen * 0.5
	_text(Vector2(c.x - 260.0, c.y - 60.0), "YOU HAVE FALLEN", 52, Palette.BLOOD_BRIGHT)
	_text(Vector2(c.x - 260.0, c.y - 16.0),
		"%d vigils held   %d slain   %d pacts sworn" % [wave, kills, held_pacts.size()],
		26, Palette.BONE_DIM)

	# What you are actually taking away from this.
	draw_rect(Rect2(c.x - 260.0, c.y + 10.0, 520.0, 2.0), Color(Palette.COIN, 0.5))
	_text(Vector2(c.x - 260.0, c.y + 52.0), "%d gold carried out" % run_gold, 34, Palette.COIN)
	_text(Vector2(c.x - 260.0, c.y + 86.0), "%d gold in the purse" % Profile.gold, 24, Palette.BONE_DIM)
	if player.luck > 0.0:
		_text(Vector2(c.x - 260.0, c.y + 116.0),
			"luck %d made the dark more generous" % int(player.luck), 21, Palette.ASH)

	_text(Vector2(c.x - 260.0, c.y + 156.0), "press R, or click, to rise again", 24, Palette.BONE_DIM)
	_text(Vector2(c.x - 260.0, c.y + 188.0), "press C to spend it in the Chapel", 24, Palette.COIN)


# --- the opening screen ----------------------------------------------------

func _draw_character_screen() -> void:
	for e in _embers:
		draw_circle(e["pos"], e["size"], Color(Palette.BLOOD_BRIGHT, e["a"]))

	var cx := screen.x * 0.5
	var left := cx - 590.0
	_text(Vector2(left, 150.0), "THE LONG VIGIL", 78, Palette.BONE)
	draw_rect(Rect2(left, 176.0, 300.0, 2.0), Palette.BLOOD)
	_text(Vector2(left, 226.0), "WHO HOLDS THE CHAPEL", 30, Palette.ASH)
	_text(Vector2(left, 262.0),
		"choose your damned. it is the last choice you make freely.", 24, Palette.BONE_DIM)

	for i in offers.size():
		_draw_character_card(i)

	_text(Vector2(left, screen.y - 110.0),
		"click a card, or W/S and ENTER, or press 1-3"
			+ "          WASD to move, everything else is automatic",
		21, Palette.ASH_DIM)


func _draw_character_card(i: int) -> void:
	var c: Dictionary = offers[i]
	var box := _card_rect(i)
	var hot := _hover == i

	draw_rect(box, Palette.VOID_LIT)
	draw_rect(box, Palette.BLOOD if hot else Palette.ASH_DIM, false, 3.0 if hot else 2.0)

	# The portrait well is deliberately LIGHTER than the card. These characters
	# are near-black silhouettes; on a dark panel they simply disappear.
	var well := Rect2(box.position + Vector2(16, 16), Vector2(200, 168))
	draw_rect(well, Color(0.175, 0.175, 0.205))
	draw_rect(well, Palette.ASH_DIM, false, 1.0)

	var a = _portraits[i] if i < _portraits.size() else null
	if a != null:
		a.draw_on(self, well.position + Vector2(100.0, 148.0), false,
			Color.WHITE if hot else Color(0.86, 0.86, 0.86))
	else:
		var mid := well.position + Vector2(100.0, 74.0)
		draw_circle(mid, 36.0, Palette.BONE if hot else Palette.BONE_DIM)
		draw_arc(mid, 36.0, 0.0, TAU, 28, Palette.ASH, 3.0)
		_text_center(well.position.x + 100.0, well.position.y + 148.0, "no art yet", 18, Palette.ASH_DIM)

	# Two columns with a hard 24px gutter between them. Text is fitted to the
	# left column width, stats are right-aligned to the card edge, so the two
	# can never meet in the middle.
	var stats_right := box.end.x - 24.0
	var stats_w := 280.0
	var tx := box.position.x + 236.0
	var tw := (stats_right - stats_w) - tx - 24.0
	var y := box.position.y

	_text_fit(Vector2(tx, y + 62.0), "%d)  %s" % [i + 1, c["name"]], 40,
		Palette.BONE if hot else Palette.BONE_DIM, tw)
	_text_fit(Vector2(tx, y + 108.0), c["blurb"], 24, Palette.BONE_DIM, tw)
	_text_fit(Vector2(tx, y + 148.0), c["note"], 23, Palette.BLOOD_BRIGHT, tw)

	_text_right(stats_right, y + 62.0, "%d health" % int(c["max_hp"]), 24, Palette.ASH, stats_w)
	_text_right(stats_right, y + 98.0, "%d speed" % int(c["speed"]), 24, Palette.ASH, stats_w)
	_text_right(stats_right, y + 148.0, String(c["weapon"]["name"]), 22, Palette.ASH, stats_w)


# One card renderer for both the pact screen and the armoury -- they differ
# only in which two lines of text they show.
func _draw_choice_screen(title: String, subtitle: String) -> void:
	var cx := screen.x * 0.5
	var left := cx - 500.0
	draw_rect(Rect2(0, 0, screen.x, screen.y), Color(0.0, 0.0, 0.0, 0.70))

	_text(Vector2(left, 226.0), title, 46, Palette.BONE)
	draw_rect(Rect2(left, 244.0, 220.0, 2.0), Palette.BLOOD)
	_text(Vector2(left, 286.0), subtitle, 24, Palette.BONE_DIM)

	for i in offers.size():
		CardFace.draw_card(self, _font, _card_rect(i), offers[i], _hover == i)

	var many := "1-%d" % maxi(offers.size(), 1)
	_text(Vector2(left, screen.y - 110.0),
		"click a card, or W/S and ENTER, or press " + many, 21, Palette.ASH_DIM)

	if _pact_reason != PactReason.CHEST:
		var cost := reroll_cost()
		var afford := Profile.gold >= cost
		_text(Vector2(left, screen.y - 74.0),
			"press R to refuse them all   -   %d gold   (you hold %d)" % [cost, Profile.gold],
			21, Palette.COIN if afford else Palette.ASH_DIM)


func _text(pos: Vector2, msg: String, size := 24, col := Palette.BONE) -> void:
	draw_string(_font, pos, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _width(msg: String, size: int) -> float:
	return _font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# Shrink the font until the string fits its column. In a hand-drawn HUD,
# overlapping columns are otherwise only a matter of time -- someone writes a
# longer pact name and it silently runs into whatever sits beside it. Every
# card label goes through here or through _text_right, so it cannot happen.
func _fitted(msg: String, size: int, max_w: float) -> int:
	var s := size
	while s > 12 and _width(msg, s) > max_w:
		s -= 1
	return s


func _text_fit(pos: Vector2, msg: String, size: int, col: Color, max_w: float) -> void:
	draw_string(_font, pos, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, _fitted(msg, size, max_w), col)


func _text_right(right_x: float, y: float, msg: String, size: int, col: Color, max_w := 4000.0) -> void:
	var s := _fitted(msg, size, max_w)
	draw_string(_font, Vector2(right_x - _width(msg, s), y), msg,
		HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)


func _text_center(cx: float, y: float, msg: String, size: int, col: Color) -> void:
	draw_string(_font, Vector2(cx - _width(msg, size) * 0.5, y), msg,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
