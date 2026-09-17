extends SceneTree

# Measures where the frame goes, at whichever vigils you name.
#
#     godot --headless --path . --fixed-fps 60 -s tools/perf_probe.gd
#
# This exists because "it feels like it drops frames around vigil 12" is a real
# report but not a measurement, and every other change in this pass moves entity
# counts. Without a baseline there is no way to tell a fix from a placebo.
#
# WHAT THIS DOES AND DOES NOT MEASURE. Headless Godot uses the dummy rasterizer,
# so there is no GPU work in these numbers. What survives is the part we actually
# suspect: script time in _process, and the cost of every _draw that a
# queue_redraw forced the engine to re-run. A node that redraws 60 times a second
# to animate a twinkle shows up here at full price. A shader that is expensive to
# rasterise does not show up at all.
#
# Each vigil is run as a real vigil: the game spawns on its own timer, things die
# on their own, motes pile up on the floor on their own. Pre-seeding the field
# with a guessed population would measure the guess.

const VIGILS := [1, 6, 12, 15]
const SETTLE_FRAMES := 20         # let the first frame's allocations stop skewing
const KITE_RADIUS := 350.0        # how wide a circuit the probe player walks

var _vi := 0
var _main = null
var _frames := 0
var _budget := 0
var _last_usec := 0
var _times: Array[float] = []
var _peak := {}
var _rows := []
var _elapsed := 0.0
var _centre := Vector2.ZERO


# This is measurement, not play -- it drives real vigils, and main cannot tell
# the difference. Without this the run left on disk is the simulation's,
# and the menu offers it back to the player as their own.
func _initialize() -> void:
	RunSave.suspended = true


func _process(_delta: float) -> bool:
	if _vi >= VIGILS.size():
		return _finish()

	if _main == null:
		_begin_vigil()
		return false

	_sample()

	_frames += 1
	if _frames >= _budget:
		_end_vigil()
	return false


# A vigil, set up the way the game sets one up -- then left alone to run.
func _begin_vigil() -> void:
	var v: int = VIGILS[_vi]
	_main = load("res://main.tscn").instantiate()
	root.add_child(_main)
	_main.player.apply_character(Characters.ALL[0])   # the Necromancer
	_main.player.visible = true
	_main._run_started = true
	_main.state = _main.State.PLAYING
	_main.wave = v

	# Bolts unlock one per vigil survived, so a vigil-12 field has to be fought
	# with a vigil-12 loadout or the kill rate -- and therefore the mote count --
	# is wrong.
	var w = _main.player.weapons[0]
	for i in mini(v - 1, 8):
		w.unlock_bolt()

	# A vigil-12 field fought with vigil-1 power is not a vigil-12 frame. Swear
	# one pact per vigil survived, the way a real run would have, or the probe
	# measures a player who cannot kill anything and reports the resulting
	# pile-up as the normal population.
	for i in v - 1:
		var pool := []
		for pact in Pacts.ALL:
			if int(_main.pact_counts.get(pact["id"], 0)) < _main.MAX_STACKS:
				pool.append(pact)
		if pool.is_empty():
			break
		_main._swear_pact(pool[randi() % pool.size()])

	_main._scatter_chests()

	# A probe player that stands still gets swarmed, dies, and spends the rest of
	# the run measuring the death screen -- which is exactly what the first
	# version of this file did, and why it reported the late game as CHEAPER than
	# the early game. Make it unkillable and keep it kiting.
	_main.player.max_hp = 99999999
	_main.player.hp = 99999999
	_centre = _main.arena.get_center()
	_elapsed = 0.0

	# One full vigil, at 60fps, plus a moment to settle.
	# Stop a beat short of the timer, so the vigil-end transition never lands
	# inside the sample window and pollutes the worst-frame number.
	var secs: float = _main.vigil_length(v)
	_main.wave_time_left = secs
	_budget = int((secs - 0.5) * 60.0) + SETTLE_FRAMES
	_frames = 0
	_times = []
	_peak = {"enemies": 0, "orbs": 0, "coins": 0, "bullets": 0, "foe": 0, "chests": 0}
	_last_usec = Time.get_ticks_usec()
	print("--- vigil %d: %d frames (%.0fs of play), %d bolts ---" % [
		v, _budget, secs, w.unlocked_bolt_names().size()])


# The gap between two consecutive _process calls is the whole frame: main's
# logic, plus every _draw the engine re-ran because something queued a redraw.
func _sample() -> void:
	# Walk a lap at the character's own speed. A stationary player vacuums every
	# mote the instant it drops, so the floor never fills -- and the floor
	# filling is half of what is being measured.
	_elapsed += 1.0 / 60.0
	var lap: float = _main.player.speed() * _elapsed / KITE_RADIUS
	_main.player.position = _centre + Vector2(KITE_RADIUS, 0.0).rotated(lap)

	var now := Time.get_ticks_usec()
	var ms := float(now - _last_usec) / 1000.0
	_last_usec = now
	if _frames >= SETTLE_FRAMES:
		_times.append(ms)

	_peak["enemies"] = maxi(_peak["enemies"], _main.enemies.size())
	_peak["orbs"] = maxi(_peak["orbs"], _main.orbs.size())
	_peak["coins"] = maxi(_peak["coins"], _main.coins.size())
	_peak["bullets"] = maxi(_peak["bullets"], _main.bullets.size())
	_peak["foe"] = maxi(_peak["foe"], _main.foe_bullets.size())
	_peak["chests"] = maxi(_peak["chests"], _main.chests.size())


func _end_vigil() -> void:
	_times.sort()
	var n := _times.size()
	var total := 0.0
	for t in _times:
		total += t
	var mean := total / maxf(float(n), 1.0)
	var p95: float = _times[mini(n - 1, int(float(n) * 0.95))] if n > 0 else 0.0
	var worst: float = _times[n - 1] if n > 0 else 0.0

	_rows.append({
		"v": VIGILS[_vi], "mean": mean, "p95": p95, "worst": worst,
		"peak": _peak.duplicate(),
	})
	print("    mean %6.3f ms   p95 %6.3f ms   worst %6.3f ms" % [mean, p95, worst])
	print("    peak on field: %d enemies, %d motes, %d coins, %d bullets, %d foe bolts" % [
		_peak["enemies"], _peak["orbs"], _peak["coins"], _peak["bullets"], _peak["foe"]])
	print("    %d kills, player ended on %d hp, state=%d" % [
		_main.kills, _main.player.hp, _main.state])

	root.remove_child(_main)
	_main.free()
	_main = null
	_vi += 1


func _finish() -> bool:
	Audio.silence()
	Audio.release()
	SpriteAnim.clear_cache()
	print("\n%-7s %9s %9s %9s   %8s %8s %8s %8s" % [
		"vigil", "mean ms", "p95 ms", "worst ms", "enemies", "motes", "coins", "bullets"])
	for r in _rows:
		print("%-7d %9.3f %9.3f %9.3f   %8d %8d %8d %8d" % [
			r["v"], r["mean"], r["p95"], r["worst"],
			r["peak"]["enemies"], r["peak"]["orbs"], r["peak"]["coins"], r["peak"]["bullets"]])

	# The whole question is whether the late game costs more per frame than the
	# early game, and by how much.
	if _rows.size() >= 2:
		var first: Dictionary = _rows[0]
		var last: Dictionary = _rows[_rows.size() - 1]
		print("\nvigil %d costs %.2fx a vigil-%d frame (mean), %.2fx (p95)" % [
			last["v"], last["mean"] / maxf(first["mean"], 0.0001), first["v"],
			last["p95"] / maxf(first["p95"], 0.0001)])
	print("no GPU in these numbers -- headless. script time and _draw only.")
	quit()
	return true
