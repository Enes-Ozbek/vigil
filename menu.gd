extends Control

# The main menu AND the in-game pause menu -- same scene, two modes, so there
# is one settings panel and one visual style rather than two of each.
#
# This is the first part of the project built the way Godot intends: the layout
# lives in menu.tscn and can be dragged around in the editor, the buttons are
# real Control nodes with focus and keyboard navigation for free, and the
# styling comes from one Theme instead of being repeated at every draw call.

enum Mode { MAIN, PAUSE }

@export var mode: Mode = Mode.MAIN

@onready var _buttons: VBoxContainer = $Buttons
@onready var _settings_panel: VBoxContainer = $SettingsPanel
@onready var _backdrop: ColorRect = $Backdrop
@onready var _title: Label = $Title
@onready var _subtitle: Label = $Subtitle
@onready var _stats: HBoxContainer = $Stats

# The run being paused, handed over by main before this is added to the tree.
# Display only -- the pause screen never writes to it. Null on the main menu,
# where there is no run to describe.
var player = null

var _embers: Array = []
var _t := 0.0

# ---------------------------------------------------------------------------
# THE DARK BEHIND THE MENU
#
# The subtitle says something in the dark is still counting. It was the only
# thing on screen making that claim -- the rest was a title, three buttons and
# some drifting sparks, which is a menu, not a threat.
#
# So: braziers breathing on their own clocks (the same trick dungeon.gd uses, so
# the menu and the floor feel like the same place), blood finding its way down
# from the top, and EYES. The eyes do the most work by far. They open somewhere
# in the dark, hold on you, and close, and nothing else has to be said.
# ---------------------------------------------------------------------------
# Everything atmospheric draws HERE, not on the menu itself.
#
# A Control's own _draw runs beneath its children, and Backdrop is an opaque
# full-screen ColorRect -- so anything painted by this node was hidden behind
# it. The drifting embers had been invisible since the day they were written,
# which nobody noticed because the result looked like a deliberately plain
# menu. This layer sits directly above the backdrop and below the text.
var _dread_layer: Control
var _braziers: Array = []
var _eyes: Array = []
var _drips: Array = []


func _ready() -> void:
	# The pause menu has to keep running while the tree is frozen.
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.get_theme()

	Settings.load_all()
	Profile.load_all()
	if mode == Mode.MAIN:
		Settings.apply()

	_wire()
	_apply_mode()
	_seed_embers()
	_seed_dread()
	_make_dread_layer()
	_show_settings(false)


func _wire() -> void:
	$Buttons/Resume.pressed.connect(_on_resume)
	$Buttons/Continue.pressed.connect(_on_continue)
	$Buttons/NewVigil.pressed.connect(_on_new_vigil)
	$Buttons/Restart.pressed.connect(_on_restart)
	$Buttons/Chapel.pressed.connect(_on_chapel)
	$Buttons/SettingsBtn.pressed.connect(_show_settings.bind(true))
	$Buttons/MainMenu.pressed.connect(_on_main_menu)
	$Buttons/Quit.pressed.connect(_on_quit)
	$SettingsPanel/Back.pressed.connect(_show_settings.bind(false))

	var fs: CheckButton = $SettingsPanel/Fullscreen
	var vs: CheckButton = $SettingsPanel/VSync
	fs.button_pressed = Settings.fullscreen
	vs.button_pressed = Settings.vsync
	fs.toggled.connect(func(on): Settings.fullscreen = on; Settings.apply_and_save())
	vs.toggled.connect(func(on): Settings.vsync = on; Settings.apply_and_save())

	# Volume is applied live while dragging and only written to disk when the
	# handle is let go -- a config write per slider step would hammer the file.
	var sfx: HSlider = $SettingsPanel/Sfx
	var mus: HSlider = $SettingsPanel/Music
	sfx.value = Settings.sfx_volume
	mus.value = Settings.music_volume
	sfx.value_changed.connect(func(v): Settings.sfx_volume = v; Audio.apply_volumes())
	mus.value_changed.connect(func(v): Settings.music_volume = v; Audio.apply_volumes())
	sfx.drag_ended.connect(func(_c): Settings.save_all())
	mus.drag_ended.connect(func(_c): Settings.save_all())


func _apply_mode() -> void:
	var paused := mode == Mode.PAUSE
	$Buttons/Resume.visible = paused
	# Only offered when there is something to continue, and never mid-run --
	# the pause menu already has RESUME for that, and two buttons meaning almost
	# the same thing is how a player ends up abandoning a run by accident.
	var carry := RunSave.summary()
	$Buttons/Continue.visible = not paused and not carry.is_empty()
	if $Buttons/Continue.visible:
		$Buttons/Continue.text = "CONTINUE   (%s, vigil %d)" % [
			carry["character"], carry["wave"]]
	$Buttons/NewVigil.visible = not paused
	# A run in progress makes starting another an act of abandonment, so say so.
	$Buttons/NewVigil.text = "BEGIN ANEW" if $Buttons/Continue.visible else "BEGIN THE VIGIL"
	# The Chapel is a between-runs place; reaching it mid-run would mean
	# abandoning the vigil, which the pause menu already offers separately.
	$Buttons/Chapel.visible = not paused
	$Buttons/Chapel.text = "THE CHAPEL   (%d gold)" % Profile.gold
	$Buttons/Restart.visible = paused
	$Buttons/MainMenu.visible = paused
	$Buttons/Quit.visible = true

	# YOUR MEASURE. Every pact moves a number the player has never been shown --
	# which is how "5% chance to take nothing at all" ends up baffling the person
	# who chose it twice. Pausing is the moment they are already asking.
	_stats.visible = paused and player != null
	if _stats.visible:
		_build_stats()
		# Make room: the buttons sit dead centre by default, which is where the
		# middle column of numbers wants to be.
		_buttons.offset_top = 120.0
		_buttons.offset_bottom = 440.0

	if paused:
		_backdrop.color = Color(0.0, 0.0, 0.0, 0.88)
		_title.text = "THE VIGIL PAUSES"
		_title.add_theme_font_size_override("font_size", 56)
		_subtitle.text = "it is still out there, waiting"
		_title.offset_top = 74.0
		_title.offset_bottom = 174.0
		_subtitle.offset_top = 170.0
		_subtitle.offset_bottom = 210.0
		$Hint.text = "esc to resume"
	else:
		_backdrop.color = Palette.VOID


func _show_settings(on: bool) -> void:
	_settings_panel.visible = on
	_buttons.visible = not on
	if _stats != null:
		_stats.visible = not on and mode == Mode.PAUSE and player != null
	_title.visible = not on
	_subtitle.visible = not on
	# Give the keyboard something sensible to start on.
	if on:
		$SettingsPanel/Fullscreen.grab_focus()
	else:
		_first_visible_button()


# What the keyboard starts on.
#
# NOT simply the first visible button. CONTINUE sits above BEGIN in the scene,
# so "first visible" meant pressing Enter on the menu silently resumed an old
# run instead of starting a new one -- which is exactly the wrong default, since
# resuming is the choice you want to make deliberately and starting fresh is the
# one you want to fall into.
func _first_visible_button() -> void:
	for want in ["Resume", "NewVigil", "Chapel"]:
		var b := _buttons.get_node_or_null(want) as Button
		if b != null and b.visible:
			b.grab_focus()
			return
	for b in _buttons.get_children():
		if b is Button and b.visible:
			b.grab_focus()
			return


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if _settings_panel.visible:
		_show_settings(false)
	elif mode == Mode.PAUSE:
		_on_resume()
	get_viewport().set_input_as_handled()


# --- actions ---------------------------------------------------------------

func _on_resume() -> void:
	get_tree().paused = false
	queue_free()


func _on_chapel() -> void:
	get_tree().change_scene_to_file("res://chapel.tscn")


func _on_continue() -> void:
	RunSave.pending = true
	get_tree().change_scene_to_file("res://main.tscn")


func _on_new_vigil() -> void:
	# Beginning again throws the old run away. It is already lost the moment a
	# new one saves over it at vigil 1; clearing here just makes that honest.
	RunSave.clear()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://main.tscn")


func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://menu.tscn")


func _on_quit() -> void:
	get_tree().quit()


# --- atmosphere ------------------------------------------------------------

func _seed_embers() -> void:
	if mode == Mode.PAUSE:
		return                     # the arena is already behind us
	for i in 90:
		_embers.append({
			"pos": Vector2(randf() * 1920.0, randf() * 1080.0),
			"vel": Vector2(randf_range(-8.0, 8.0), randf_range(-26.0, -9.0)),
			"size": randf_range(1.0, 2.6),
			"a": randf_range(0.10, 0.5),
			"phase": randf() * TAU,
		})


# Everything here is MAIN-mode only. The pause menu has the arena behind it and
# does not need a second one painted over the top.
func _make_dread_layer() -> void:
	_dread_layer = Control.new()
	_dread_layer.name = "Dread"
	# It covers the screen, so it must never take a click meant for a button.
	_dread_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dread_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dread_layer)
	move_child(_dread_layer, 1)          # index 0 is Backdrop; the text follows
	_dread_layer.draw.connect(_draw_dread)
	# The frame is drawn around wherever the columns ended up, and a container
	# does not know its own size until it has sorted its children -- which
	# happens after _ready. Without this the box is drawn around a zero rect
	# once and never corrected, because a paused menu has no _process to
	# redraw it.
	if _stats != null:
		_stats.sort_children.connect(_dread_layer.queue_redraw)


func _seed_dread() -> void:
	if mode == Mode.PAUSE:
		return
	for i in 4:
		_braziers.append({
			"pos": Vector2(randf_range(120.0, 1800.0), randf_range(180.0, 940.0)),
			"phase": randf() * TAU,
			"rate": randf_range(3.4, 6.2),
			"reach": randf_range(150.0, 260.0),
		})
	# Kept out of the middle third, where the title and buttons live -- something
	# watching from behind the text is a readability problem, not atmosphere.
	for i in 11:
		var x := randf() * 1920.0
		if absf(x - 960.0) < 300.0:
			x += 460.0 * signf(x - 960.0)
		_eyes.append({
			"pos": Vector2(clampf(x, 40.0, 1880.0), randf_range(90.0, 1000.0)),
			"gap": randf_range(0.6, 5.0),      # how far apart the two eyes sit
			"wait": randf_range(1.0, 14.0),    # until it next opens
			"open": 0.0,                       # 0 shut, 1 wide
			"hold": 0.0,
			"size": randf_range(2.6, 5.2),
		})
	for i in 5:
		_drips.append(_new_drip())


func _new_drip() -> Dictionary:
	return {
		"x": randf() * 1920.0,
		"len": 0.0,
		"max": randf_range(60.0, 320.0),
		"speed": randf_range(14.0, 46.0),
		"wait": randf_range(0.0, 9.0),
		"fade": 1.0,
	}


func _tick_dread(delta: float) -> void:
	for e in _eyes:
		if e["hold"] > 0.0:
			e["hold"] = float(e["hold"]) - delta
			e["open"] = minf(float(e["open"]) + delta * 5.0, 1.0)
			continue
		if e["open"] > 0.0:
			e["open"] = maxf(float(e["open"]) - delta * 2.2, 0.0)
			continue
		e["wait"] = float(e["wait"]) - delta
		if e["wait"] <= 0.0:
			# It opens somewhere ELSE each time. An eye that always returns to
			# the same spot is a decoration; one that moves is something walking.
			var x := randf() * 1920.0
			if absf(x - 960.0) < 300.0:
				x += 460.0 * signf(x - 960.0)
			e["pos"] = Vector2(clampf(x, 40.0, 1880.0), randf_range(90.0, 1000.0))
			e["hold"] = randf_range(0.7, 2.6)
			e["wait"] = randf_range(3.0, 16.0)

	for d in _drips:
		if d["wait"] > 0.0:
			d["wait"] = float(d["wait"]) - delta
			continue
		d["len"] = float(d["len"]) + float(d["speed"]) * delta
		if d["len"] >= float(d["max"]):
			d["fade"] = float(d["fade"]) - delta * 0.7
			if d["fade"] <= 0.0:
				var fresh := _new_drip()
				for k in fresh:
					d[k] = fresh[k]


func _process(delta: float) -> void:
	if _embers.is_empty():
		return
	_t += delta
	_tick_dread(delta)
	if _dread_layer != null:
		_dread_layer.queue_redraw()
	var s := size
	for e in _embers:
		e["phase"] += delta
		e["pos"] += e["vel"] * delta + Vector2(sin(e["phase"]) * 7.0 * delta, 0.0)
		if e["pos"].y < -10.0:
			e["pos"] = Vector2(randf() * s.x, s.y + 10.0)
	queue_redraw()


func _draw_dread() -> void:
	var ci := _dread_layer
	# Order matters: light first, then what the light falls on, then the ash in
	# front of it, then the dark closing in around the whole thing.
	_draw_braziers(ci)
	_draw_drips(ci)
	_draw_eyes(ci)
	for e in _embers:
		ci.draw_circle(e["pos"], e["size"], Color(Palette.BLOOD_BRIGHT, e["a"]))
	_draw_creep(ci)

	if _stats != null and _stats.visible:
		# One inked box around the numbers, the same hand as the pact cards, so
		# the pause screen belongs to the same object as the rest of the game.
		CardFace.set_hand("stat_sheet")
		CardFace.sketch_box(ci, _stats.get_rect().grow(40.0),
			Color(0.78, 0.72, 0.60, 0.22), 1.5)

	if mode == Mode.MAIN:
		# The rule under the title is inked and boils, like the cards.
		#
		# It sits BELOW the subtitle. At its old y of 237 it ran through the
		# bottoms of THE LONG VIGIL like a strikethrough -- which nobody had seen,
		# because until this layer existed the backdrop covered it entirely.
		var cx := size.x * 0.5
		CardFace.set_hand("menurule", CardFace.boil_frame(_t))
		CardFace.stroke(ci, Vector2(cx - 150.0, 306.0), Vector2(cx + 150.0, 306.0),
			Palette.BLOOD, 2.6, 2, 2.0)


func _draw_braziers(ci: CanvasItem) -> void:
	for b in _braziers:
		var rate: float = b["rate"]
		var flick := 0.84 + 0.16 * sin(_t * rate + float(b["phase"]))
		flick += 0.06 * sin(_t * rate * 2.7)      # a second, faster tremor
		var reach: float = float(b["reach"]) * flick
		for i in 9:
			var k := 1.0 - float(i) / 9.0
			ci.draw_circle(b["pos"], reach * k, Color(Palette.BLOOD, 0.020 * (1.0 - k) + 0.008))


# Eyes. They open somewhere in the dark, hold, and close.
func _draw_eyes(ci: CanvasItem) -> void:
	for e in _eyes:
		var o: float = e["open"]
		if o <= 0.01:
			continue
		var s: float = e["size"]
		var gap: float = 9.0 + float(e["gap"]) * 3.0
		for d in [-1.0, 1.0]:
			var at: Vector2 = e["pos"] + Vector2(d * gap, 0.0)
			# a faint hint of the head around them, so they are not two dots
			ci.draw_circle(at, s * 5.0 * o, Color(Palette.BLOOD, 0.030 * o))
			# the lid closing squashes the eye rather than fading it
			ci.draw_circle(at, s * o, Color(Palette.BLOOD_BRIGHT, 0.85 * o))
			ci.draw_circle(at, s * 0.45 * o, Color(1.0, 0.80, 0.72, 0.9 * o))


# Blood, finding its way down from somewhere above the screen.
func _draw_drips(ci: CanvasItem) -> void:
	for d in _drips:
		var l: float = d["len"]
		if l <= 0.5:
			continue
		var a: float = clampf(d["fade"], 0.0, 1.0) * 0.55
		var x: float = d["x"]
		ci.draw_line(Vector2(x, 0.0), Vector2(x, l), Color(Palette.BLOOD, a * 0.7), 2.0)
		ci.draw_circle(Vector2(x, l), 2.6, Color(Palette.BLOOD_BRIGHT, a))


# The dark leaning in at the edges, breathing slowly. Nested unfilled rects
# rather than a texture -- cheap, and it pulls the eye to the middle.
func _draw_creep(ci: CanvasItem) -> void:
	var breath := 0.86 + 0.14 * sin(_t * 0.55)
	for i in 26:
		var k := float(i)
		ci.draw_rect(Rect2(k * 5.0, k * 5.0, size.x - k * 10.0, size.y - k * 10.0),
			Color(0.0, 0.0, 0.0, 0.055 * breath), false, 6.0)


# --- your measure ------------------------------------------------------------

# Built from Labels rather than a custom _draw, the same way the settings panel
# is: the theme supplies the font and the containers do the alignment, so this
# stays legible if either changes. The arithmetic is all in StatSheet.
func _build_stats() -> void:
	var cols := [$Stats/Col0, $Stats/Col1, $Stats/Col2]
	for c in cols:
		for old in c.get_children():
			c.remove_child(old)
			old.queue_free()
	var sections: Array = StatSheet.sections(player)
	for i in mini(sections.size(), cols.size()):
		cols[i].add_child(_stat_head(String(sections[i]["title"])))
		for row in sections[i]["rows"]:
			cols[i].add_child(_stat_row(row))


func _stat_head(text: String) -> Control:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Palette.BLOOD_BRIGHT)
	return l


# key on the left, the number on the right, and where a number needs saying in
# words -- armour especially -- the plain-language form trails it, dimmer.
func _stat_row(row: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 9)
	var k := Label.new()
	k.text = String(row["k"])
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.add_theme_font_size_override("font_size", 21)
	k.modulate = Color(1.0, 1.0, 1.0, 0.60)
	h.add_child(k)
	var v := Label.new()
	v.text = String(row["v"])
	v.add_theme_font_size_override("font_size", 21)
	h.add_child(v)
	if String(row["n"]) != "":
		var note := Label.new()
		note.text = String(row["n"])
		note.add_theme_font_size_override("font_size", 17)
		note.modulate = Color(1.0, 1.0, 1.0, 0.40)
		h.add_child(note)
	return h
