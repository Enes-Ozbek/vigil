class_name RunSave

# A run in progress, written to disk at the start of every vigil.
#
# Same ConfigFile pattern as settings.gd and profile.gd, in its own file for the
# same reason those are separate: abandoning a run should not touch your wallet,
# and wiping your wallet should not touch your key bindings.
#
# ---------------------------------------------------------------------------
# IT SAVES THE DECISIONS, NOT THE CONSEQUENCES.
#
# The player carries twenty-eight modifier fields. Mirroring them into a config
# file would work exactly once: the next pact that writes a new field would be
# silently dropped from every save, and the bug would look like "that pact
# sometimes doesn't do anything after you reload" -- which is close to
# undiagnosable.
#
# So what gets written is the LIST OF PACTS TAKEN, in order, and restoring
# replays them through the very same _swear_pact and _take_card the game uses
# while you play. There is one source of truth for what a pact does, the save
# format cannot drift from it, and adding a pact tomorrow needs no change here.
#
# Only what is genuinely not derivable is stored alongside: health, because you
# were hurt; level and experience, because those come from kills; and the
# counters the HUD shows.
# ---------------------------------------------------------------------------
#
# The save point is the START of a vigil, which is the only moment the run is in
# a clean state -- field empty, no pact screen open, nothing mid-animation. A
# resumed run therefore always begins a vigil rather than resuming the middle of
# one, and the most a crash can cost is the vigil you were in.

const PATH := "user://run.cfg"

# Set by the menu to ask main.tscn to restore rather than open character select.
static var pending := false

# WRITES OFF. For the analysis tools, which instantiate main.tscn and drive it
# through a whole run to measure it.
#
# They are not playing, but main cannot tell the difference, so every simulated
# vigil wrote a real save over the player's actual run -- balance_sim finishing
# its sweep left "necromancer, vigil 16" on disk, the menu offered it, and it
# was the focused button. Every rebuild silently replaced the player's run with
# the simulation's. The flag lives here rather than being a backup-and-restore
# dance repeated in each tool, so a tool written next month is safe by default
# the moment it sets it.
static var suspended := false


# CAN THIS SAVE STILL BE REPLAYED?
#
# A run is stored as the list of pacts taken and rebuilt by replaying them, so
# the one thing that can actually break it is a pact id that no longer resolves
# -- renamed, removed, retyped. The loop below used to skip those silently,
# which does not fail: it loads a run missing some of its power and looks like
# the pacts "stopped working after a reload".
#
# So ask the exact question rather than approximating it. A hash of all content
# would also catch this, but it would throw away a perfectly good run every time
# a pact was ADDED, which breaks nothing.
static func _replayable(cfg: ConfigFile) -> bool:
	for id in cfg.get_value("pacts", "taken", PackedStringArray()):
		var key := String(id)
		var known: bool = (ChestCards.by_id(key) if key.begins_with("cc_")
			else Pacts.by_id(key)).is_empty() == false
		if not known:
			return false
	return not Characters.by_id(String(cfg.get_value("run", "character", ""))).is_empty()


static func has_run() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return false
	return bool(cfg.get_value("run", "active", false))


# Who and how far, for the menu to show without loading the whole thing.
static func summary() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK or not bool(cfg.get_value("run", "active", false)):
		return {}
	# Not offered at all, rather than offered and then refused on the click.
	if not _replayable(cfg):
		return {}
	var cid := String(cfg.get_value("run", "character", ""))
	var c := Characters.by_id(cid)
	return {
		"character": String(c.get("name", cid)),
		"wave": int(cfg.get_value("run", "wave", 1)),
	}


static func save(main) -> void:
	if suspended:
		return
	var cfg := ConfigFile.new()
	var p = main.player
	cfg.set_value("run", "active", true)
	cfg.set_value("run", "character", String(p.character.get("id", "")))
	cfg.set_value("run", "wave", int(main.wave))
	cfg.set_value("run", "hp", int(p.hp))
	cfg.set_value("run", "level", int(p.level))
	cfg.set_value("run", "xp", int(p.xp))
	cfg.set_value("run", "kills", int(main.kills))
	cfg.set_value("run", "gold", int(main.run_gold))
	cfg.set_value("run", "corruption", int(main.corruption))
	# Bolts unlock one per vigil survived, so this is nearly derivable from the
	# wave -- but not quite, because a Chapel upgrade can start you with two.
	# Storing it is cheaper than reasoning about it.
	var bolts := 1
	if not p.weapons.is_empty():
		bolts = int(p.weapons[0].unlocked_bolts)
	cfg.set_value("run", "bolts", bolts)
	cfg.set_value("pacts", "taken", PackedStringArray(main.held_pacts))
	cfg.save(PATH)


# Rebuild the run onto a fresh main. Returns false if there was nothing to load,
# so the caller can fall through to character select.
static func restore(main) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK or not bool(cfg.get_value("run", "active", false)):
		return false
	if not _replayable(cfg):
		# Names something this build no longer has. Loading it would quietly
		# hand back a weaker run than the one that was saved.
		print("run save: names content this build no longer has, discarded")
		clear()
		return false
	var c := Characters.by_id(String(cfg.get_value("run", "character", "")))

	var p = main.player
	p.apply_character(c)            # brings current Chapel upgrades with it

	# Replay. These functions append to held_pacts and pact_counts themselves,
	# so both rebuild as a side effect of applying the effects -- which is the
	# point: there is no second code path that could disagree with the first.
	main.held_pacts.clear()
	main.pact_counts.clear()
	main.corruption = 0
	for id in cfg.get_value("pacts", "taken", PackedStringArray()):
		var key := String(id)
		if key.begins_with("cc_"):
			var card := ChestCards.by_id(key)
			if not card.is_empty():
				main._take_card(card)
		else:
			var pact := Pacts.by_id(key)
			if not pact.is_empty():
				main._swear_pact(pact)

	# Now the things no amount of replaying can produce.
	p.level = int(cfg.get_value("run", "level", 1))
	p.xp = int(cfg.get_value("run", "xp", 0))
	p.hp = clampi(int(cfg.get_value("run", "hp", p.max_hp)), 1, p.max_hp)
	main.kills = int(cfg.get_value("run", "kills", 0))
	main.run_gold = int(cfg.get_value("run", "gold", 0))
	main.corruption = int(cfg.get_value("run", "corruption", main.corruption))
	main.wave = int(cfg.get_value("run", "wave", 1))
	if not p.weapons.is_empty():
		p.weapons[0].unlocked_bolts = clampi(int(cfg.get_value("run", "bolts", 1)),
			1, maxi(1, p.weapons[0].bolts().size()))
	# _take_card leaves a banner behind; a resumed run should open quietly.
	main._notice = ""
	main._notice_time = 0.0
	return true


static func clear() -> void:
	pending = false
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
