class_name Settings

# Player settings, persisted to user:// so they survive a restart.
#
# Deliberately small and honest: every entry here changes something that
# actually exists. A slider that moves and does nothing is worse than no
# slider -- which is why the volume entries below arrived with the audio and
# not before it.

const PATH := "user://settings.cfg"

static var fullscreen := false
static var vsync := true

# Linear 0..1, converted to decibels on the bus. Music has no track yet, but the
# bus and the setting exist so dropping one in is a file rather than a feature.
static var sfx_volume := 0.8
static var music_volume := 0.6

static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return                    # first run: defaults above stand
	fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
	vsync = bool(cfg.get_value("display", "vsync", vsync))
	sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
	music_volume = float(cfg.get_value("audio", "music", music_volume))


static func save_all() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "vsync", vsync)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.save(PATH)


static func apply() -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
	Audio.apply_volumes()


static func apply_and_save() -> void:
	apply()
	save_all()
