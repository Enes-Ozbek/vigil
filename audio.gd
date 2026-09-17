class_name Audio

# Every sound the game makes.
#
# Same static-singleton shape as settings.gd and profile.gd, so call sites read
# the same way: Audio.play("enemy_hit"). It owns a pool of AudioStreamPlayer
# nodes parented to the scene root, created the first time something asks for a
# sound rather than at load, because a static class has no _ready to hook.
#
# THE PART THAT MATTERS IS THE THROTTLING. A vigil ends with thirty soul motes
# arriving inside a couple of frames. Playing thirty copies of one sample at the
# same moment is not thirty times louder, it is a click and a clipped mix, and
# it is the single most common way placeholder audio ruins a game that was
# otherwise fine. Every sound therefore has a minimum gap between retriggers and
# a cap on how many copies may overlap. Dropping a sound is always better than
# smearing the mix.
#
# Files come from tools/make_sfx.py. Replacing one is a matter of dropping a
# WAV with the same name into assets/sfx/ -- nothing below knows or cares how
# a sound was made.

const DIR := "res://assets/sfx/"
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"

# How many sounds may overlap at all. Past this, new ones are dropped.
const VOICES := 24

const DEFAULT_CAP := 4              # copies of ONE sound allowed at once
const DEFAULT_GAP := 0.04           # seconds before the same sound may retrigger

# Sounds that need tighter rules than the default, and why.
const CAP := {
	"mote_pickup": 2,               # dozens land together at the end of a vigil
	"coin_pickup": 3,
	"enemy_hit": 5,                 # a pierce shot through a crowd is legitimate
	"enemy_die": 4,
}
const GAP := {
	"mote_pickup": 0.055,
	"coin_pickup": 0.05,
	"enemy_hit": 0.03,
	"player_hurt": 0.18,            # contact damage ticks fast; this must not machine-gun
	"swing": 0.05,
}

# Sounds that should sit below the rest of the mix, in decibels.
const TRIM := {
	"mote_pickup": -7.0,
	"coin_pickup": -4.0,
	"enemy_hit": -5.0,
	"shoot_cinder": -3.0,
	"shoot_skull": -3.0,
	"shoot_arrow": -3.0,
	"swing": -4.0,
}

static var _players: Array[AudioStreamPlayer] = []
static var _voice_id: Array[String] = []
static var _streams := {}
static var _last := {}
static var _booted := false
static var _failed := false


# Called lazily, because a static class has no _ready. Safe to call every time.
static func boot() -> void:
	if _booted or _failed:
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return                      # too early -- the next play() will try again
	_booted = true
	_make_buses()

	var holder := Node.new()
	holder.name = "AudioVoices"
	# Sound carries on through the pause menu; cutting it dead is jarring.
	holder.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(holder)

	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		holder.add_child(p)
		_players.append(p)
		_voice_id.append("")

	_load_streams()
	apply_volumes()


static func _load_streams() -> void:
	var dir := DirAccess.open(DIR)
	if dir == null:
		# No sound files is a perfectly playable state -- run tools/make_sfx.py.
		_failed = true
		return
	for f in dir.get_files():
		var name := String(f)
		# Godot hands back the import stub name in an exported build.
		if name.ends_with(".import"):
			name = name.substr(0, name.length() - 7)
		if not name.ends_with(".wav"):
			continue
		var id := name.substr(0, name.length() - 4)
		var stream := load(DIR + name)
		if stream != null:
			_streams[id] = stream


# Buses are made in code rather than shipped as a .tres, so there is no binary
# resource to keep in step with this file.
static func _make_buses() -> void:
	for bus in [BUS_SFX, BUS_MUSIC]:
		if AudioServer.get_bus_index(bus) != -1:
			continue
		var at := AudioServer.bus_count
		AudioServer.add_bus(at)
		AudioServer.set_bus_name(at, bus)
		AudioServer.set_bus_send(at, "Master")


static func apply_volumes() -> void:
	_set_bus(BUS_SFX, Settings.sfx_volume)
	_set_bus(BUS_MUSIC, Settings.music_volume)


static func _set_bus(bus: String, vol: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, vol <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(clampf(vol, 0.001, 1.0)))


# Play a sound by id. Unknown ids are ignored on purpose: a missing file should
# make the game quieter, never crash it.
#
# pitch_var is how far the pitch wanders each time. Without it, a sound heard
# forty times a minute reads as a machine rather than a world.
static func play(id: String, pitch_var := 0.07) -> void:
	boot()
	if not _booted or not _streams.has(id):
		return

	var now := Time.get_ticks_msec()
	var gap := int(float(GAP.get(id, DEFAULT_GAP)) * 1000.0)
	if now - int(_last.get(id, -99999)) < gap:
		return

	var free := -1
	var same := 0
	for i in _players.size():
		if not _players[i].playing:
			if free < 0:
				free = i
		elif _voice_id[i] == id:
			same += 1
	if same >= int(CAP.get(id, DEFAULT_CAP)):
		return
	if free < 0:
		return                      # every voice busy; drop rather than cut one off

	_last[id] = now
	_voice_id[free] = id
	var p := _players[free]
	p.stream = _streams[id]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.volume_db = float(TRIM.get(id, 0.0))
	p.play()


# Release the voices and the loaded samples.
#
# Only the headless tools need this. They quit() the SceneTree directly, and a
# static dictionary still holding sixteen AudioStreams at that moment makes the
# engine report leaked resources on exit -- which would then sit in the output
# of every future run, exactly where a real error is supposed to stand out.
static func shutdown() -> void:
	silence()
	release()


# Stop everything and take the voices out of the tree. Dropping the STREAMS
# here too is not enough on its own: the audio server holds a sample until the
# playback it started actually finishes, so a sound still ringing keeps its
# resource alive past the point the dictionary let go of it. Hence the split --
# tools silence() first, run a few frames, then release().
static func silence() -> void:
	# Walk the TREE, not the tracked list. shutdown() sets _booted false, so any
	# later play() boots a second time and adds another holder -- which Godot
	# renames to avoid the clash, leaving the first one unreachable by name and
	# _players pointing only at the newest batch. A player missed that way keeps
	# its playback alive and the engine reports a leaked stream at exit.
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		for child in tree.root.get_children():
			if not String(child.name).begins_with("AudioVoices"):
				continue
			for v in child.get_children():
				if v is AudioStreamPlayer:
					v.stop()
					v.stream = null
			child.free()
	_players.clear()
	_voice_id.clear()
	_last.clear()
	_booted = false


static func release() -> void:
	_streams.clear()


# What tools/make_sfx.py produced, for the smoke test to check against.
static func known() -> Array:
	boot()
	return _streams.keys()
