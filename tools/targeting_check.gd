extends SceneTree

# Proves that bolts spread across the crowd instead of piling onto one enemy,
# and that nothing is shot at after enough damage to kill it is already flying.
#
#     godot --headless --path . -s tools/targeting_check.gd
#
# This exists because the convergence bug was invisible to every check we had.
# The smoke test ran the firing code happily -- it just never asked WHERE the
# bullets went, and "all of them went to the same place" is not an error, it is
# a design failure that looks exactly like working code.

var _done := false
var _fails := 0
var _drain := 0


# This is measurement, not play -- it instantiates and runs main, and main cannot tell
# the difference. Without this the run left on disk is the simulation's,
# and the menu offers it back to the player as their own.
func _initialize() -> void:
	RunSave.suspended = true


func _process(_delta: float) -> bool:
	# The checks queue_free() corpses and spent bullets, and queue_free is
	# deferred to the end of the frame. Quitting in the same frame leaves them
	# alive and the engine reports leaked objects on the way out -- noise that
	# would then sit permanently where a real error is supposed to stand out.
	if _done:
		_drain -= 1
		if _drain > 0:
			return false
		Audio.release()
		SpriteAnim.clear_cache()
		if _fails == 0:
			print("\ntargeting: all checks held")
		else:
			print("\ntargeting: %d CHECK(S) BROKE" % _fails)
		quit(1 if _fails > 0 else 0)
		return true

	_done = true
	_drain = 30
	_check_spread()
	_check_no_overkill()
	_check_release()
	_check_splash()
	# Audio goes down as the drain STARTS, not at the end: a sample still
	# ringing when its stream is dropped is held by the audio server until it
	# finishes, and quitting in that frame reports it as a leaked resource.
	Audio.silence()
	return false


func _fail(what: String) -> void:
	_fails += 1
	print("    BROKE: %s" % what)


# A line of enemies, all in reach, all identical. Two bolts should choose two
# different ones.
func _check_spread() -> void:
	print("--- two bolts, six identical targets ---")
	var main = _arena(6, 40)
	var w = main.player.weapons[0]
	w.unlock_bolt()                      # the Necromancer's second bolt
	print("    bolts: %s" % str(w.unlocked_bolt_names()))

	# Force every bolt off cooldown so one _fire() fires all of them.
	for i in w.live_bolt_count():
		w.note_bolt_fired(i, 0.0)
	main._fire()

	var targets := {}
	for b in main.bullets:
		if b.reserved != null:
			targets[b.reserved.get_instance_id()] = true
	print("    %d bullets, %d distinct targets" % [main.bullets.size(), targets.size()])
	if main.bullets.size() < 2:
		_fail("expected both bolts to fire, got %d bullets" % main.bullets.size())
	elif targets.size() < 2:
		_fail("every bullet went to the same enemy -- the original bug")
	_free(main)


# One enemy, weak enough that a single bolt covers it, and plenty of others
# further out. Nothing should keep shooting the one already marked for death.
func _check_no_overkill() -> void:
	print("--- overkill: a target already covered is skipped ---")
	var main = _arena(6, 40)
	var w = main.player.weapons[0]
	var near: Enemy = main.enemies[0]
	near.position = main.player.position + Vector2(30.0, 0.0)
	near.hp = 1
	near.max_hp = 1

	for shot in 4:
		for i in w.live_bolt_count():
			w.note_bolt_fired(i, 0.0)
		main._fire()

	var over := 0
	for e in main.enemies:
		if e.incoming > e.hp + 60:      # one bolt's worth of slack is expected
			over += 1
			print("    %s: %d incoming vs %d hp" % [e.kind["name"], e.incoming, e.hp])
	print("    %d bullets in flight, %d enemies over-committed" % [main.bullets.size(), over])
	if over > 0:
		_fail("%d enemies had far more damage committed than they have health" % over)
	_free(main)


# The bookkeeping half: every claim must come back. A leak here would make an
# enemy permanently invisible to targeting -- alive, walking at you, never shot.
func _check_release() -> void:
	print("--- every reservation is given back ---")
	var main = _arena(4, 60)
	var w = main.player.weapons[0]
	w.unlock_bolt()
	for shot in 30:
		for i in w.live_bolt_count():
			w.note_bolt_fired(i, 0.0)
		main._fire()
		main._move_bullets(0.25)         # coarse steps, so bullets land and expire
		main._reap_enemies()

	var stuck := 0
	for e in main.enemies:
		if e.incoming > 0 and not _claimed_by_live_bullet(main, e):
			stuck += 1
			print("    %s holds %d incoming with no bullet to match" % [e.kind["name"], e.incoming])
	print("    %d enemies left, %d bullets live, %d leaked claims" % [
		main.enemies.size(), main.bullets.size(), stuck])
	if stuck > 0:
		_fail("%d enemies leaked a reservation and can never be targeted again" % stuck)
	_free(main)


# The Cinder stops where it lands and burns what is beside it -- and no amount
# of stacked pierce turns it back into a lance.
func _check_splash() -> void:
	print("--- the Cinder: no pierce, small blast ---")
	var main = _arena(0, 0)
	var w = main.player.weapons[0]
	var bolt: Dictionary = w.bolt_at(0)

	# even with pierce stacked to the ceiling
	main.player.pierce_bonus = 9
	var p: int = main.player.effective_pierce(bolt, w)
	print("    pierce with +9 pierce_bonus: %d" % p)
	if p != 0:
		_fail("the Cinder pierces %d despite no_pierce" % p)

	# three enemies in a tight clump: one is hit, two should still be burned
	var clump: Vector2 = main.player.position + Vector2(120.0, 0.0)
	for off in [Vector2.ZERO, Vector2(16.0, 6.0), Vector2(-14.0, 10.0)]:
		var e := Enemy.new()
		e.setup(1, "bat")
		e.speed = 0.0
		e.position = clump + off
		main.world.add_child(e)
		main.enemies.append(e)
	var far := Enemy.new()
	far.setup(1, "bat")
	far.speed = 0.0
	far.position = clump + Vector2(260.0, 0.0)      # well outside the blast
	main.world.add_child(far)
	main.enemies.append(far)

	var full: Array[int] = []
	for e in main.enemies:
		full.append(e.hp)
	for i in w.live_bolt_count():
		w.note_bolt_fired(i, 0.0)
	main._fire()
	for step in 40:
		main._move_bullets(0.02)

	var hurt := 0
	for i in main.enemies.size():
		if main.enemies[i].hp < full[i]:
			hurt += 1
	print("    %d of 4 enemies damaged by one flame (%d bursts drawn)" % [hurt, main._bursts.size()])
	if hurt < 2:
		_fail("the blast caught only %d -- splash is not landing" % hurt)
	if main.enemies[3].hp < full[3]:
		_fail("the blast reached an enemy 260 units away")
	_free(main)


func _claimed_by_live_bullet(main, e: Enemy) -> bool:
	for b in main.bullets:
		if b.reserved == e:
			return true
	return false


# A player at the centre with `n` identical enemies in a line to the right, all
# inside reach.
func _arena(n: int, spacing: float):
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	main.player.apply_character(Characters.ALL[0])   # the Necromancer
	main.player.visible = true
	main._run_started = true
	main.state = main.State.PLAYING
	main.wave = 1
	for i in n:
		var e := Enemy.new()
		e.setup(1, "bat")
		e.speed = 0.0
		e.position = main.player.position + Vector2(60.0 + float(i) * spacing, 0.0)
		main.world.add_child(e)
		main.enemies.append(e)
	return main


# queue_free rather than free: the checks leave live bullets and corpses behind,
# and tearing their parent out from under them mid-frame is what left the engine
# reporting leaked objects at exit. The drain frames in _process let these
# actually complete.
#
# Processing is DISABLED first, though. queue_free is deferred, so the node gets
# one more _process before it goes -- and a main still in State.PLAYING spends
# that frame spawning, firing and playing sounds. Since Audio.silence() runs in
# the same pass, that last frame was booting the audio system back up after it
# had been shut down, and leaving a playback alive at exit.
func _free(main) -> void:
	main.process_mode = Node.PROCESS_MODE_DISABLED
	main.queue_free()
