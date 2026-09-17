class_name Profile

# What survives between runs: the wallet, and a little history worth showing.
# Same ConfigFile pattern as settings.gd, in a separate file so wiping your
# progress does not wipe your key bindings.
#
# Gold banks the instant you touch a coin, so dying a second later still leaves
# you with it. Writing to disk happens at the end of each vigil and on death --
# often enough that a crash costs at most one vigil, rare enough that it is not
# a disk write per coin.

const PATH := "user://profile.cfg"

static var gold := 0
static var runs := 0
static var best_vigil := 0
static var total_kills := 0

# character id -> Array of owned upgrade ids
static var owned := {}

static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return                    # first run: the defaults above stand
	gold = int(cfg.get_value("wallet", "gold", gold))
	runs = int(cfg.get_value("history", "runs", runs))
	best_vigil = int(cfg.get_value("history", "best_vigil", best_vigil))
	total_kills = int(cfg.get_value("history", "total_kills", total_kills))
	owned = {}
	for cid in cfg.get_section_keys("owned") if cfg.has_section("owned") else []:
		owned[cid] = Array(cfg.get_value("owned", cid, []))


static func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("wallet", "gold", gold)
	cfg.set_value("history", "runs", runs)
	cfg.set_value("history", "best_vigil", best_vigil)
	cfg.set_value("history", "total_kills", total_kills)
	for cid in owned:
		cfg.set_value("owned", cid, owned[cid])
	cfg.save(PATH)


static func bank(amount: int) -> void:
	gold += maxi(0, amount)


static func owns(char_id: String, node_id: String) -> bool:
	return Array(owned.get(char_id, [])).has(node_id)


static func owned_for(char_id: String) -> Array:
	return Array(owned.get(char_id, []))


# Returns true if the purchase happened. Refuses quietly when you cannot afford
# it or already have it, so callers do not each need to re-check.
static func buy(char_id: String, node_id: String, cost: int) -> bool:
	if owns(char_id, node_id) or gold < cost:
		return false
	gold -= cost
	var list := Array(owned.get(char_id, []))
	list.append(node_id)
	owned[char_id] = list
	save_all()
	return true


# Called once when a run ends, however it ended.
static func record_run(vigil: int, kills: int) -> void:
	runs += 1
	best_vigil = maxi(best_vigil, vigil)
	total_kills += kills
	save_all()
