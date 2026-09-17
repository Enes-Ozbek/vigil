extends SceneTree

# Drives the real game through every state, as every character, with enemies on
# the field -- and lets _draw actually run for each one.
#
#     godot --headless --path . -s tools/smoke_test.gd
#
# This exists because a HUD-only crash shipped once: main.gd read a property
# that had been deleted from Weapon, and every headless check until then had
# sat on the character-select screen and never entered play, so nothing ever
# executed the line. Checking that a project "runs" is worthless if it only
# ever runs the first screen.
#
# Exits non-zero on any engine error, so it is usable as a gate.

const FRAMES_PER_PHASE := 130   # long enough for a ranged enemy to actually throw

var _ci := 0
var _phase := 0
var _f := 0
var _main = null
var _errors := 0
var _checked := []
var _menus_done := false
var _drain := 0

# The test plays the game for real, so it writes run saves the whole way
# through -- ending a vigil calls _begin_vigil, which saves. Left alone it would
# hand the player a CONTINUE button pointing at a run this test invented, or
# overwrite a real one they were in the middle of. The bytes are taken before
# anything runs and put back after everything has.
var _run_backup := ""
var _had_run := false


func _process(_delta: float) -> bool:
	if _ci >= Characters.ALL.size():
		if not _menus_done:
			_menus_done = true
			print("--- menus ---")
			_check_menus()
			# Let the frees queued by the menu and audio checks actually happen
			# before quitting, or the engine reports them as leaks on the way
			# out and that noise sits where a real error should stand out.
			# Audio goes down FIRST: a sample still ringing when its stream is
			# dropped is held by the audio server until it finishes playing.
			Audio.silence()
			_drain = 30
			return false
		_drain -= 1
		if _drain > 0:
			return false
		return _finish()

	if not _menus_done and _main == null and _ci == 0 and _phase == 0 and _run_backup == "":
		_had_run = FileAccess.file_exists(RunSave.PATH)
		_run_backup = FileAccess.get_file_as_string(RunSave.PATH) if _had_run else " "

	if _main == null:
		_begin_character()

	_f += 1
	if _f < FRAMES_PER_PHASE:
		return false

	_f = 0
	_phase += 1
	match _phase:
		1:
			_note("playing")
			_main.state = _main.State.SHOP
			var pool := Pacts.ALL.duplicate()
			pool.shuffle()
			_main.offers = pool.slice(0, 4)
			_main.pact_counts[_main.offers[0]["id"]] = 2
			_main.held_pacts.append(String(_main.offers[0]["id"]))
			_main._hover = 1
		2:
			_note("pact screen")
			# take a pact, which also frees a bolt, then play on
			_main._choose(0)
		3:
			_note("pact taken + bolt freed")
			_main.state = _main.State.DEAD
		4:
			_note("death screen")
			_end_character()
	return false


func _begin_character() -> void:
	var c: Dictionary = Characters.ALL[_ci]
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	_main.player.apply_character(c)
	_main.player.visible = true
	_main._run_started = true
	_main.state = _main.State.PLAYING
	# enemies all round, so melee, ranged and multi-target all have work to do
	# One of EVERY archetype, so ranged behaviour, tanks and elites all draw and
	# tick. A roster only exercised through random spawns is a roster where the
	# rare entry is never tested.
	var spots := [Vector2(70, 0), Vector2(-60, 20), Vector2(30, -90),
		Vector2(140, 40), Vector2(-120, -60), Vector2(0, 130)]
	for ki in EnemyKinds.ALL.size():
		var e := Enemy.new()
		e.setup(8, String(EnemyKinds.ALL[ki]["id"]))
		e.speed = 0.0
		e.max_hp = 9999
		e.hp = 9999
		e.position = _main.player.position + spots[ki % spots.size()]
		_main.world.add_child(e)
		_main.enemies.append(e)

	# A handful that die immediately, so death animations, soul motes, the
	# pickup pull and the level-up pact screen all get exercised too.
	for i in 14:
		var d := Enemy.new()
		d.setup(1)
		d.speed = 0.0
		d.position = _main.player.position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
		d.hp = 0
		_main.world.add_child(d)
		_main.enemies.append(d)
	# The vigil-5 boss, so its swing, its rooting and its health bar all draw.
	_main.wave = 5
	_main._summon_boss()
	_main._scatter_chests()

	_main.player.extra_shots = 2          # exercise the multi-target path
	print("--- %s ---" % c["name"])


func _note(what: String) -> void:
	var w = _main.player.weapons[0]
	_checked.append("%s / %s" % [_main.player.character["name"], what])
	print("    %-24s weapon=%s bolts=%s bullets=%d foe_shots=%d enemies=%d motes=%d lvl=%d xp=%d" % [
		what, w.data["name"], str(w.unlocked_bolt_names()),
		_main.bullets.size(), _main.foe_bullets.size(), _main.enemies.size(), _main.orbs.size(),
		_main.player.level, _main.player.xp])
	print("        map %s, view %s, %d chests, %d coins" % [
		_main.arena.size, _main.view_size(), _main.chests.size(), _main.coins.size()])
	if _main.boss != null and is_instance_valid(_main.boss):
		print("        boss %s at %d/%d hp" % [_main.boss.kind["name"], _main.boss.hp, _main.boss.max_hp])


func _end_character() -> void:
	root.remove_child(_main)
	_main.free()
	_main = null
	_phase = 0
	_ci += 1


# A real save on disk, so the menu has something to offer and the loader has
# something to chew on. pact_ids overrides what was taken, for feeding it names
# that no longer resolve.
func _fabricate_save(wave: int, pact_ids: PackedStringArray) -> void:
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.player.apply_character(Characters.ALL[0])
	m._run_started = true
	m.wave = wave
	RunSave.save(m)
	root.remove_child(m)
	m.queue_free()
	if not pact_ids.is_empty():
		var cfg := ConfigFile.new()
		cfg.load(RunSave.PATH)
		cfg.set_value("pacts", "taken", pact_ids)
		cfg.save(RunSave.PATH)


func _check_menus() -> void:
	# WHAT ENTER DOES ON THE MENU. With a run on disk the menu shows CONTINUE
	# above BEGIN, so "focus the first visible button" meant pressing Enter
	# silently resumed an old run -- the one choice that should be deliberate.
	# Checking that a button IS focused would have passed the whole time.
	_fabricate_save(16, PackedStringArray())
	var mm: Control = (load("res://menu.tscn") as PackedScene).instantiate()
	root.add_child(mm)
	var owner_node := mm.get_viewport().gui_get_focus_owner()
	var focused: String = owner_node.name if owner_node != null else "<nothing>"
	print("    menu with a saved run: continue offered=%s, focus starts on %s" % [
		mm.get_node("Buttons/Continue").visible, focused])
	if focused == "Continue":
		print("    menu: FOCUS IS WRONG -- enter resumes the old run")
	if not mm.get_node("Buttons/Continue").visible:
		print("    menu: CONTINUE MISSING FOR A VALID SAVE")
	root.remove_child(mm)
	mm.free()
	RunSave.clear()

	for m in [0, 1]:                       # Menu.Mode.MAIN, Menu.Mode.PAUSE
		var menu: Control = (load("res://menu.tscn") as PackedScene).instantiate()
		menu.mode = m
		root.add_child(menu)
		var shown := []
		for b in menu.get_node("Buttons").get_children():
			if b.visible:
				shown.append(b.name)
		print("    menu mode %d: buttons %s" % [m, str(shown)])
		print("      settings panel hidden=%s, toggles=%d, theme=%s" % [
			not menu.get_node("SettingsPanel").visible,
			menu.get_node("SettingsPanel").get_child_count() - 1,
			menu.theme != null])
		# open settings, move a slider, close again
		menu._show_settings(true)
		var sfx: HSlider = menu.get_node("SettingsPanel/Sfx")
		var before := Settings.sfx_volume
		sfx.value = 0.35
		print("      sfx volume %.2f -> %.2f (applied=%s)" % [
			before, Settings.sfx_volume, not is_equal_approx(Settings.sfx_volume, before)])
		sfx.value = before
		menu._show_settings(false)
		root.remove_child(menu)
		menu.free()
	_check_chapel()


func _check_chapel() -> void:
	var before_gold := Profile.gold
	var before_owned := Profile.owned.duplicate(true)
	Profile.gold = 5000
	var ch: Control = (load("res://chapel.tscn") as PackedScene).instantiate()
	root.add_child(ch)
	print("    chapel: opens on the picker (view %d), %d characters shown" % [
		ch._view, Characters.ALL.size()])
	for ci in Characters.ALL.size():
		# Drive it by CLICKING, not by calling _open directly. Calling the
		# method straight is how a dead click path shipped once already: the
		# test passed while the screen was unusable.
		ch._go(0)
		ch._last_click_frame = -1
		ch._gui_input(_click_at(ch._pick_rect(ci).get_center()))
		if ch._view != 1:
			print("    chapel: CLICK ON CHARACTER %d DID NOTHING" % ci)
		var cid: String = ch._character_id()
		var nodes: Array = ch._nodes()
		ch._hover = 0
		ch._last_click_frame = -1
		ch._gui_input(_click_at(ch._card_rect(0).get_center()))
		print("    chapel: %-16s view=%d %d nodes, tree %4d gold, owns %d, flash \"%s\"" % [
			cid, ch._view, nodes.size(), Upgrades.tree_cost(cid),
			Profile.owned_for(cid).size(), ch._flash])

	root.remove_child(ch)
	ch.free()
	_check_audio()
	_check_keyboard()
	_check_tally()
	_check_run_save()
	_check_reroll()
	_check_cursed_chest()
	Profile.gold = before_gold
	Profile.owned = before_owned
	Profile.save_all()


# Sound is the one system where the failure mode is not a crash. A missing file
# plays nothing; a missing THROTTLE plays thirty copies of one sample on one
# frame, which is a clipped click rather than an error. Both are checked here.
func _check_audio() -> void:
	var have: Array = Audio.known()
	have.sort()
	print("    audio: %d sounds loaded" % have.size())
	var want := ["mote_pickup", "coin_pickup", "shoot_cinder", "shoot_skull",
		"shoot_arrow", "swing", "enemy_hit", "enemy_die", "player_hurt",
		"level_up", "chest_open", "vigil_start", "vigil_end", "boss_spawn",
		"pact_pick", "death"]
	for id in want:
		if not have.has(id):
			print("    audio: MISSING SOUND %s -- run tools/build_sfx.py" % id)

	# Thirty motes landing on one frame, which is an ordinary end to a vigil.
	for i in 30:
		Audio.play("mote_pickup")
	var live := 0
	for p in Audio._players:
		if p.playing:
			live += 1
	var cap: int = int(Audio.CAP.get("mote_pickup", Audio.DEFAULT_CAP))
	print("    audio: 30 motes in one frame -> %d voices live (cap %d)" % [live, cap])
	if live > cap:
		print("    audio: THROTTLE FAILED -- %d voices for a cap of %d" % [live, cap])


# The pact screen must be usable without a mouse.
#
# Driven through the viewport's real input pipeline rather than by calling
# _key_to_choice directly -- a dead input path that the test reaches around is
# exactly how the Chapel once shipped with unclickable buttons while its check
# passed.
func _check_keyboard() -> void:
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.player.apply_character(Characters.ALL[0])
	m._run_started = true
	m.state = m.State.SHOP
	var pool := Pacts.ALL.duplicate()
	pool.shuffle()
	m.offers = pool.slice(0, m.OFFER_COUNT)
	m._hover = -1

	# Every key that should move the selection, tested by name. The pact cards
	# are a VERTICAL list, and for a while only left/right was bound -- so the
	# obvious key did nothing and the test, which only pressed RIGHT, passed.
	# A check that exercises one direction proves one direction.
	var moves := {"DOWN": KEY_DOWN, "S": KEY_S, "RIGHT": KEY_RIGHT, "D": KEY_D}
	var backs := {"UP": KEY_UP, "W": KEY_W, "LEFT": KEY_LEFT, "A": KEY_A}
	var dead := []
	for nm in moves:
		m._hover = 0
		m.get_viewport().push_input(_key(moves[nm]))
		if m._hover != 1:
			dead.append(nm)
	for nm in backs:
		m._hover = 1
		m.get_viewport().push_input(_key(backs[nm]))
		if m._hover != 0:
			dead.append(nm)
	print("    keyboard: %d of 8 movement keys work on a %d-card screen" % [
		8 - dead.size(), m.offers.size()])
	if not dead.is_empty():
		print("    keyboard: THESE KEYS DID NOTHING: %s" % str(dead))
	m._hover = 1

	var held: int = m.held_pacts.size()
	m.get_viewport().push_input(_key(KEY_ENTER))
	print("    keyboard: ENTER -> %d pacts held (was %d), state %d" % [
		m.held_pacts.size(), held, m.state])
	if m.held_pacts.size() == held:
		print("    keyboard: ENTER DID NOTHING on the pact screen")

	# and the number keys, which are the path that already existed
	m.state = m.State.SHOP
	m.offers = pool.slice(m.OFFER_COUNT, m.OFFER_COUNT * 2)
	var held2: int = m.held_pacts.size()
	m.get_viewport().push_input(_key(KEY_3))
	if m.held_pacts.size() == held2:
		print("    keyboard: NUMBER KEYS DID NOTHING on the pact screen")

	root.remove_child(m)
	m.queue_free()


# Killing a boss must leave a Cursed Chest, walking into it must lay out three
# cards, and taking one must actually change the player.
#
# Every link in that chain is somewhere a silent failure fits: a chest that
# never spawns, an opening animation that never reports finished so the screen
# never arrives, or a card whose effect has no matching arm and quietly does
# nothing. None of those raise an error on their own.
func _check_cursed_chest() -> void:
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.player.apply_character(Characters.ALL[0])
	m.player.visible = true
	m._run_started = true
	m.state = m.State.PLAYING
	m.wave = 5
	m.chests.clear()
	m._summon_boss()
	if m.boss == null:
		print("    chest: NO BOSS AT VIGIL 5 -- nothing to drop a chest")
		root.remove_child(m); m.queue_free(); return

	m.boss.position = m.player.position + Vector2(30.0, 0.0)
	m.boss.hp = 0
	m._reap_enemies()
	var cursed := 0
	for c in m.chests:
		if c.cursed:
			cursed += 1
	print("    chest: boss died -> %d cursed chest(s)" % cursed)
	if cursed == 0:
		print("    chest: BOSS DROPPED NOTHING")
		root.remove_child(m); m.queue_free(); return

	# Walk into it. The lid animates first, so the screen must NOT be up yet.
	for c in m.chests:
		if c.cursed:
			c.position = m.player.position
	m._move_chests(0.016)
	var early: bool = m.state == m.State.SHOP
	# Then run past the length of the opening animation.
	for i in 60:
		m._move_chests(0.016)
	print("    chest: screen on contact=%s, after the lid opens=%s, %d cards" % [
		early, m.state == m.State.SHOP, m.offers.size()])
	if early:
		print("    chest: OPENED INSTANTLY -- the animation is being thrown away")
	if m.state != m.State.SHOP:
		print("    chest: THE CARD SCREEN NEVER ARRIVED")
	elif m.offers.size() != m.CHEST_CARDS:
		print("    chest: EXPECTED %d CARDS, GOT %d" % [m.CHEST_CARDS, m.offers.size()])

	# Every placeholder card must actually do something.
	var before := [m.player.damage_bonus, m.player.max_hp, m.player.extra_shots,
		m.player.armor, m.player.revives, m.player.luck, m.player.mote_bonus,
		m.player.pierce_bonus, m.player.crit_chance, m.player.rate_pct]
	for card in ChestCards.ALL:
		var p2 = load("res://main.tscn").instantiate()
		root.add_child(p2)
		p2.player.apply_character(Characters.ALL[0])
		var a := _fingerprint(p2.player)
		p2._take_card(card)
		if _fingerprint(p2.player) == a:
			print("    chest: CARD '%s' CHANGED NOTHING" % card["id"])
		root.remove_child(p2)
		p2.queue_free()
	print("    chest: all %d placeholder cards change the player" % ChestCards.ALL.size())

	root.remove_child(m)
	m.queue_free()


func _fingerprint(p) -> String:
	return "%d|%d|%d|%d|%d|%.2f|%d|%d|%.2f|%.3f|%.2f|%.2f" % [
		p.damage_bonus, p.max_hp, p.extra_shots, p.armor, p.revives, p.luck,
		p.mote_bonus, p.pierce_bonus, p.crit_chance, p.rate_pct,
		p.crit_mult, p.damage_taken_pct]


# Rerolling has to spend real gold, escalate within a screen, refuse when you
# cannot pay, and leave a boss chest alone. Four separate ways to get it wrong.
# A vigil must END on the tally, hold there, count the right numbers, and then
# hand over to the pact screen -- on its own if left alone, or early on a press.
#
# Three ways this fails silently: the state is skipped entirely and the cards
# appear as before; it opens but never advances, freezing the run; or the
# leftover keypress from moving skips it before a stroke is drawn.
# A run must survive being written to disk and read back IDENTICALLY.
#
# This is the check the feature lives or dies by. A save that drops one modifier
# does not crash, does not warn, and does not look wrong -- it just makes a pact
# you took stop working after a reload, which is close to undiagnosable from the
# outside. So: build a run, swear a pile of pacts, take a chest card, save,
# rebuild from nothing, and compare every field the player has.
# THE INVARIANT THE ANALYSIS TOOLS HAVE TO HOLD.
#
# A tool that instantiates main.tscn is driving the real game, and the real game
# saves. balance_sim did this for months: it swept a full run as the necromancer
# and left "vigil 16" on disk, so every rebuild handed the player the
# simulation's run instead of their own, wearing a CONTINUE button.
#
# This reads the sources rather than running them, because a SceneTree tool
# cannot be launched from inside another one. Crude, and it still catches the
# next tool written -- which is the point.
func _check_tools_leave_saves_alone() -> void:
	var bad := PackedStringArray()
	var checked := 0
	for f in DirAccess.get_files_at("res://tools"):
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://tools/" + f)
		if not src.contains("main.tscn"):
			continue                    # not driving the game, cannot save
		checked += 1
		# smoke_test is the exception: it tests saving, so it saves for real and
		# backs the player's file up around the whole run instead.
		if f == "smoke_test.gd":
			continue
		if not src.contains("RunSave.suspended = true"):
			bad.append(f)
	print("    tools: %d drive main.tscn, %d would write over a real save" % [
		checked, bad.size()])
	if not bad.is_empty():
		print("    tools: %s WILL NOT LEAVE THE PLAYER SAVE ALONE" % str(bad))


# THE SCREEN HAS TO AGREE WITH THE GAME.
#
# A stat screen that quotes its own arithmetic is worse than no stat screen: it
# is confidently wrong, and the player has no way to tell. So this does not
# check StatSheet against a formula copied out of StatSheet -- it hits the
# player for real, repeatedly, and checks that what actually came off the health
# bar is what the screen promised would.
func _check_stat_sheet() -> void:
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	var p = m.player
	p.apply_character(Characters.ALL[0])
	p.armor = 15                        # exactly ARMOR_SCALE, so soak is exactly half
	p.dodge = 0.0
	p.damage_taken_pct = 0.0
	p.max_hp = 1000000
	p.hp = p.max_hp

	var hits := 400
	var before: int = p.hp
	for _i in hits:
		p.take_damage(100)
	var measured := float(before - p.hp) / float(hits)
	var promised := (1.0 - StatSheet.armour_soak(p.armor)) * 100.0
	print("    stats: armour 15 -> screen says %s absorbed; 100 damage actually took %.1f" % [
		"%d%%" % roundi(StatSheet.armour_soak(15) * 100.0), measured])
	if absf(measured - promised) > 1.0:
		print("    stats: THE SCREEN AND take_damage DISAGREE (%.1f vs %.1f)" % [
			measured, promised])

	# Dodge is survival the other three stats cannot express, so the summary line
	# has to move when it moves.
	var dry := StatSheet.survivability(p)
	p.dodge = 0.5
	var wet := StatSheet.survivability(p)
	print("    stats: 50%% dodge takes survivability %d -> %d" % [roundi(dry), roundi(wet)])
	if wet < dry * 1.9:
		print("    stats: DODGE IS MISSING FROM SURVIVABILITY")

	p.crit_chance = 0.5
	p.crit_mult = 1.8
	if absf(StatSheet.crit_gain(p) - 0.4) > 0.001:
		print("    stats: CRIT AVERAGE IS WRONG (%.3f, wanted 0.400)" % StatSheet.crit_gain(p))

	# And the panel itself builds, with every row reachable.
	var rows := 0
	for sec in StatSheet.sections(p):
		for r in sec["rows"]:
			rows += 1
			for k in ["k", "v"]:
				var text := String(r[k])
				if text.is_empty() or text.contains("nan") or text.contains("inf"):
					print("    stats: A ROW IS BROKEN (%s)" % str(r))
	print("    stats: %d rows across %d columns" % [rows, StatSheet.sections(p).size()])
	if rows < 12:
		print("    stats: TOO FEW ROWS -- something is being skipped")

	m._open_pause_menu()
	var menu: Control = null
	for c in m.get_children():
		if c is CanvasLayer and c.get_child_count() > 0:
			menu = c.get_child(0)
	var built := 0
	if menu != null:
		for col in menu.get_node("Stats").get_children():
			built += col.get_child_count()
	print("    stats: pause screen shows %s, built %d lines" % [
		menu != null and menu.get_node("Stats").visible, built])
	if built <= rows:
		print("    stats: THE PAUSE SCREEN DID NOT BUILD THE SHEET")
	paused = false                      # this script IS the tree
	root.remove_child(m)
	m.queue_free()


# IS ANYTHING THE PLAYER CARRIES INVISIBLE?
#
# Asking "did I list them all" by eye works exactly once. The next pact that
# needs a new field will add it to player.gd and not to StatSheet, and the only
# symptom is a stat that silently does nothing you can see.
#
# So this does not compare two lists. It walks every script variable on the
# player, nudges it, and re-renders the sheet: if the text is identical, that
# field is invisible to the player, whatever anyone intended.
func _check_every_stat_is_visible() -> void:
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	var p = m.player
	p.apply_character(Characters.ALL[0])

	# Shown somewhere other than this sheet, on purpose.
	var elsewhere := {
		"xp": "the HUD level bar",
		# An input, not a stat: it decides unlocked_bolts at run start, and the
		# sheet prints that instead. Nudging it mid-run correctly does nothing.
		"start_bolts": "the weapon's bolts row",
	}
	var invisible := PackedStringArray()
	var walked := 0
	for prop in p.get_property_list():
		var nm: String = prop["name"]
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		if nm.begins_with("_") or elsewhere.has(nm):
			continue
		var was = p.get(nm)
		var t := typeof(was)
		if t != TYPE_INT and t != TYPE_FLOAT:
			continue
		walked += 1
		var before := _sheet_text(p)
		p.set(nm, (float(was) + 7.0) if t == TYPE_FLOAT else int(was) + 7)
		var after := _sheet_text(p)
		p.set(nm, was)
		if before == after:
			invisible.append(nm)

	print("    stats: nudged %d player fields, %d of them changed nothing on screen" % [
		walked, invisible.size()])
	if not invisible.is_empty():
		print("    stats: %s NEVER APPEAR ANYWHERE" % str(invisible))
	root.remove_child(m)
	m.queue_free()


func _sheet_text(p) -> String:
	var out := ""
	for sec in StatSheet.sections(p):
		for r in sec["rows"]:
			out += "%s=%s/%s;" % [r["k"], r["v"], r["n"]]
	return out


func _check_run_save() -> void:
	_check_stat_sheet()
	_check_every_stat_is_visible()
	_check_tools_leave_saves_alone()
	if RunSave.suspended:
		print("    save: SUSPENSION LEAKED INTO A REAL SESSION")

	var a = load("res://main.tscn").instantiate()
	root.add_child(a)
	a.player.apply_character(Characters.ALL[0])
	a._run_started = true
	a.wave = 9
	a.kills = 173
	a.run_gold = 88
	# a spread of pacts, several stacked, plus a boss card
	var swore := 0
	for pact in Pacts.ALL:
		if swore >= 14:
			break
		a._swear_pact(pact)
		swore += 1
	a._swear_pact(Pacts.ALL[0])
	a._swear_pact(Pacts.ALL[0])          # stacking, so pact_counts matters
	a._take_card(ChestCards.ALL[1])
	a.player.hp = 37
	a.player.level = 11
	a.player.xp = 26
	a.player.weapons[0].unlocked_bolts = 2
	var before := _player_state(a.player)
	var held_before: int = a.held_pacts.size()
	RunSave.save(a)
	root.remove_child(a)
	a.queue_free()

	var b = load("res://main.tscn").instantiate()
	root.add_child(b)
	var ok: bool = RunSave.restore(b)
	var after := _player_state(b.player)
	print("    save: restored=%s, %d pacts -> %d, wave %d, %d kills, %d gold" % [
		ok, held_before, b.held_pacts.size(), b.wave, b.kills, b.run_gold])
	if not ok:
		print("    save: RESTORE FAILED")
	elif before != after:
		print("    save: PLAYER STATE CHANGED ACROSS A SAVE")
		for k in before:
			if before[k] != after[k]:
				print("        %s: %s -> %s" % [k, before[k], after[k]])
	else:
		print("    save: every one of %d player fields survived intact" % before.size())
	if b.held_pacts.size() != held_before:
		print("    save: PACT LIST LENGTH CHANGED (%d -> %d)" % [held_before, b.held_pacts.size()])
	if int(b.pact_counts.get(Pacts.ALL[0]["id"], 0)) != 3:
		print("    save: STACK COUNTS DID NOT REBUILD")
	if b.wave != 9 or b.kills != 173 or b.run_gold != 88:
		print("    save: RUN COUNTERS DID NOT SURVIVE")

	root.remove_child(b)
	b.queue_free()

	# A SAVE THAT NAMES SOMETHING GONE. Renaming or removing a pact used to
	# leave a dangling id that the replay loop skipped in silence -- the run
	# loaded, quietly missing whatever that pact had given it.
	_fabricate_save(12, PackedStringArray(["a_pact_that_no_longer_exists"]))
	var offered: Dictionary = RunSave.summary()
	var c = load("res://main.tscn").instantiate()
	root.add_child(c)
	var loaded: bool = RunSave.restore(c)
	print("    save naming a removed pact: offered=%s, restored=%s" % [
		not offered.is_empty(), loaded])
	if not offered.is_empty():
		print("    save: A BROKEN SAVE IS STILL OFFERED IN THE MENU")
	if loaded:
		print("    save: A BROKEN SAVE LOADED ANYWAY")
	root.remove_child(c)
	c.queue_free()
	RunSave.clear()


# Every field the player carries, so a dropped one cannot hide.
func _player_state(p) -> Dictionary:
	var out := {}
	for prop in p.get_property_list():
		var nm: String = prop["name"]
		if nm.begins_with("_") or nm in ["weapons", "character", "script", "Built-in script"]:
			continue
		var v = p.get(nm)
		if typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
			out[nm] = v
	return out


func _check_tally() -> void:
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.player.apply_character(Characters.ALL[0])
	m._run_started = true
	m.state = m.State.PLAYING
	m.wave = 3
	m._kills_at_vigil = 10
	m._gold_at_vigil = 5
	m._hp_at_vigil = m.player.max_hp
	m.kills = 41
	m.run_gold = 32
	m.player.hp = m.player.max_hp - 18

	m._end_vigil()
	print("    tally: state=%d (want %d), %d slain / %d gold / %d harm" % [
		m.state, m.State.TALLY, m._tally_kills, m._tally_gold, m._tally_hurt])
	if m.state != m.State.TALLY:
		print("    tally: VIGIL DID NOT END ON THE TALLY")
	if m._tally_kills != 31 or m._tally_gold != 27 or m._tally_hurt != 18:
		print("    tally: WRONG NUMBERS (want 31 / 27 / 18)")

	# a press too early must not skip it
	m.get_viewport().push_input(_key(KEY_SPACE))
	if m.state != m.State.TALLY:
		print("    tally: SKIPPED BY A LEFTOVER KEYPRESS before it could be read")

	# It must NOT move on by itself. Ten seconds is four times as long as the
	# writing takes, so anything still counting down would have fired.
	for i in 600:
		m._tick_tally(1.0 / 60.0)
	var waited: bool = m.state == m.State.TALLY
	print("    tally: still waiting after 10s = %s" % waited)
	if not waited:
		print("    tally: LEFT ON ITS OWN -- it is meant to hold until dismissed")

	# and it must move on when told to
	m.get_viewport().push_input(_key(KEY_SPACE))
	print("    tally: after a keypress -> state=%d (SHOP is %d)" % [m.state, m.State.SHOP])
	if m.state == m.State.TALLY:
		print("    tally: WILL NOT DISMISS -- the run would freeze here")

	root.remove_child(m)
	m.queue_free()


func _check_reroll() -> void:
	var m = load("res://main.tscn").instantiate()
	root.add_child(m)
	m.player.apply_character(Characters.ALL[0])
	m._run_started = true
	m.wave = 12
	var keep_gold: int = Profile.gold
	Profile.gold = 500
	m._open_pact_screen(0)                    # PactReason.VIGIL

	var first: int = m.reroll_cost()
	var before: Array = m.offers.duplicate()
	m.get_viewport().push_input(_key(KEY_R))
	var after_gold: int = Profile.gold
	var second: int = m.reroll_cost()
	m.get_viewport().push_input(_key(KEY_R))
	var third: int = m.reroll_cost()
	print("    reroll: cost %d then %d then %d, gold 500 -> %d, offers %d" % [
		first, second, third, Profile.gold, m.offers.size()])
	if after_gold != 500 - first:
		print("    reroll: R DID NOTHING (gold unchanged)")
	if second <= first or third <= second:
		print("    reroll: COST DOES NOT ESCALATE within a screen")
	if m.offers.size() != m.OFFER_COUNT:
		print("    reroll: SCREEN DID NOT REFILL (%d cards)" % m.offers.size())

	# broke: the button must do nothing at all
	Profile.gold = 0
	var poor: Array = m.offers.duplicate()
	m.get_viewport().push_input(_key(KEY_R))
	if m.offers != poor or Profile.gold != 0:
		print("    reroll: SPENT GOLD IT DID NOT HAVE")

	# a boss chest is not rerollable
	Profile.gold = 500
	m._open_chest_cards()
	var cards: Array = m.offers.duplicate()
	m.get_viewport().push_input(_key(KEY_R))
	if m.offers != cards:
		print("    reroll: A CURSED CHEST WAS REROLLED")
	print("    reroll: chest reroll refused=%s" % (m.offers == cards))

	Profile.gold = keep_gold
	root.remove_child(m)
	m.queue_free()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	return e


func _finish() -> bool:
	# Put the player's own save back exactly as it was found -- or remove the one
	# this test fabricated, if there was nothing there to begin with.
	RunSave.clear()
	if _had_run:
		var f := FileAccess.open(RunSave.PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(_run_backup)
			f.close()
	print("run save: %s" % ("the run in progress was put back" if _had_run
		else "none existed, and none was left behind"))
	if _had_run and not RunSave.has_run():
		print("run save: THE TEST ATE A REAL SAVE")
	if not _had_run and RunSave.has_run():
		print("run save: LEFT A FABRICATED RUN ON DISK")

	Audio.silence()
	Audio.release()
	SpriteAnim.clear_cache()
	print("\nsmoke test: %d state/character combinations exercised" % _checked.size())
	print("clean if nothing was logged above -- note this line deliberately")
	print("avoids the words a grep would look for, so it cannot match itself")
	quit()
	return true


func _click_at(pos: Vector2) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = pos
	return e
