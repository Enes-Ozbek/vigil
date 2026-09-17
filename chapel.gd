extends Control

# THE CHAPEL — where gold turns into something permanent.
#
# Two views, not one screen: you choose WHO you are tending, and only then see
# what can be done for them. A wall of every node for every character at once
# is a list; this is a place you walk into.
#
# Drawn rather than assembled from Control children, deliberately: it has to
# match the pact screen's tier colours, glow and shimmer, and that look lives
# in draw calls. A Control root still gives it the scene and the input flow.

enum View { PICK, TREE }

const COLS := 2
const CARD := Vector2(560.0, 130.0)
const GAP := Vector2(40.0, 12.0)

# Big enough to fill the well. These are short sprites in a tall panel, so a
# modest scale leaves the top half of every card empty.
const PORTRAIT_SCALE := 6.5

var _view: View = View.PICK
var _char_i := 0
var _hover := -1
var _t := 0.0
var _flash := ""
var _flash_t := 0.0

var _portraits: Array = []
var _last_click_frame := -1
var _font: Font


func _ready() -> void:
	# A Control with the default STOP filter swallows mouse buttons as GUI
	# input, so _unhandled_input never sees them -- which is why clicking here
	# did nothing while the pact screen (a Node2D using _input) worked fine.
	# Mouse goes through _gui_input; keyboard stays in _unhandled_input.
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	Profile.load_all()
	_build_portraits()


func _build_portraits() -> void:
	_portraits.clear()
	for c in Characters.ALL:
		var anims: Dictionary = c.get("anims", {})
		if anims.has("idle"):
			var a := SpriteAnim.new()
			a.frame_size = c.get("frame", Vector2i(64, 64))
			a.pivot = c.get("pivot", Vector2(32.0, 32.0))
			a.scale = float(c.get("scale", 1.0)) * PORTRAIT_SCALE
			a.play("idle", anims["idle"])
			_portraits.append(a)
		else:
			_portraits.append(null)


func _character_id() -> String:
	return String(Characters.ALL[_char_i]["id"])


func _nodes() -> Array:
	return Upgrades.for_character(_character_id())


func _owned_count(cid: String) -> int:
	return Profile.owned_for(cid).size()


# --- layout ----------------------------------------------------------------

func _pick_rect(i: int) -> Rect2:
	var w := 460.0
	var gap := 40.0
	var total := w * float(Characters.ALL.size()) + gap * float(Characters.ALL.size() - 1)
	var x := size.x * 0.5 - total * 0.5 + float(i) * (w + gap)
	return Rect2(x, 250.0, w, 620.0)


func _card_rect(i: int) -> Rect2:
	var rows := int(ceil(float(_nodes().size()) / float(COLS)))
	var grid := Vector2(CARD.x * COLS + GAP.x, CARD.y * rows + GAP.y * (rows - 1))
	var origin := Vector2(size.x * 0.5 - grid.x * 0.5, 300.0)
	var col := i % COLS
	var row := i / COLS
	return Rect2(origin + Vector2(float(col) * (CARD.x + GAP.x), float(row) * (CARD.y + GAP.y)), CARD)


func _hit(pos: Vector2) -> int:
	var n := Characters.ALL.size() if _view == View.PICK else _nodes().size()
	for i in n:
		var r := _pick_rect(i) if _view == View.PICK else _card_rect(i)
		if r.has_point(pos):
			return i
	return -1


# --- input -----------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_flash_t = maxf(0.0, _flash_t - delta)
	for a in _portraits:
		if a != null:
			a.advance(delta)
	_hover = _hit(get_local_mouse_position())
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(event.position)


# Both routings are wired, because which one a Control actually receives
# depends on its filter and on what sits above it. The frame guard means the
# click is acted on exactly once even if both fire.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_click(event.position)
		return

	if event.is_action_pressed("ui_cancel"):
		if _view == View.TREE:
			_go(View.PICK)
		else:
			get_tree().change_scene_to_file("res://menu.tscn")
		get_viewport().set_input_as_handled()
		return

	if _view == View.TREE:
		if event.is_action_pressed("ui_right"):
			_open(_char_i + 1)
		elif event.is_action_pressed("ui_left"):
			_open(_char_i - 1)


func _click(pos: Vector2) -> void:
	var frame := Engine.get_process_frames()
	if frame == _last_click_frame:
		return                      # already handled this one
	_last_click_frame = frame
	var i := _hit(pos)
	if i < 0:
		return
	if _view == View.PICK:
		_open(i)
	else:
		_buy(i)


func _go(v: View) -> void:
	_view = v
	_t = 0.0                 # replay the entrance
	_hover = -1
	_flash_t = 0.0


func _open(i: int) -> void:
	_char_i = wrapi(i, 0, Characters.ALL.size())
	_go(View.TREE)


func _buy(i: int) -> void:
	var node: Dictionary = _nodes()[i]
	var cid := _character_id()
	var cost := Upgrades.price(node)
	if Profile.owns(cid, String(node["id"])):
		_say("already yours")
	elif Profile.gold < cost:
		_say("%d gold short" % (cost - Profile.gold))
	elif Profile.buy(cid, String(node["id"]), cost):
		_say("%s is yours" % node["name"])


func _say(msg: String) -> void:
	_flash = msg
	_flash_t = 2.2


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.VOID)
	if _view == View.PICK:
		_draw_pick()
	else:
		_draw_tree()

	var cx := size.x * 0.5
	if _flash_t > 0.0:
		_text_center(cx, size.y - 116.0, _flash, 30,
			Color(Palette.COIN, clampf(_flash_t / 0.8, 0.0, 1.0)))


func _draw_header(subtitle: String) -> void:
	var left := size.x * 0.5 - 730.0
	_text(Vector2(left, 108.0), "THE CHAPEL", 54, Palette.BONE)
	draw_rect(Rect2(left, 126.0, 240.0, 2.0), Palette.BLOOD)
	_text(Vector2(left, 162.0), subtitle, 22, Palette.BONE_DIM)
	_text_right(size.x * 0.5 + 730.0, 116.0, "%d gold" % Profile.gold, 44, Palette.COIN)


# --- view one: who are you tending -----------------------------------------

func _draw_pick() -> void:
	_draw_header("who are you tending")
	for i in Characters.ALL.size():
		_draw_pick_card(i)
	_text_center(size.x * 0.5, size.y - 64.0,
		"click one    .    esc to go back", 21, Palette.ASH_DIM)


func _draw_pick_card(i: int) -> void:
	var c: Dictionary = Characters.ALL[i]
	var cid := String(c["id"])
	var base := _pick_rect(i)
	var hot := _hover == i

	var appear := clampf((_t - float(i) * 0.08) / 0.32, 0.0, 1.0)
	if appear <= 0.0:
		return
	var ease := 1.0 - pow(1.0 - appear, 3.0)
	var a := ease
	var box := Rect2(base.position + Vector2(0.0, (1.0 - ease) * 40.0), base.size)
	if hot:
		box = box.grow(8.0)

	var owned := _owned_count(cid)
	var total := Upgrades.for_character(cid).size()
	var done := owned >= total and total > 0
	var accent := Palette.COIN if done else Palette.ASH
	if hot:
		accent = Palette.BLOOD_BRIGHT

	var pulse := 0.5 + 0.5 * sin(_t * 1.7 + float(i))
	if hot or done:
		for g in 5:
			var k := float(g + 1)
			draw_rect(box.grow(k * 3.0), Color(accent, (0.05 * (0.6 + 0.4 * pulse)) / k * a), false, 3.0)

	draw_rect(box, Color(Palette.VOID_LIT, a))
	draw_rect(box, Color(accent, (0.85 if hot else 0.45) * a), false, 3.0 if hot else 2.0)

	# Portrait well, lighter than the card -- these characters are near-black
	# silhouettes and vanish on a dark panel.
	var well := Rect2(box.position + Vector2(20, 20), Vector2(box.size.x - 40.0, 344.0))
	draw_rect(well, Color(0.175, 0.175, 0.205, a))
	draw_rect(well, Color(Palette.ASH_DIM, a), false, 1.0)

	var anim = _portraits[i] if i < _portraits.size() else null
	if anim != null:
		anim.draw_on(self, well.position + Vector2(well.size.x * 0.5, well.size.y - 18.0), false,
			Color(1, 1, 1, a) if hot else Color(0.84, 0.84, 0.84, a))
	else:
		var mid := well.position + well.size * 0.5
		draw_circle(mid, 62.0, Color(Palette.BONE if hot else Palette.BONE_DIM, a))
		draw_arc(mid, 62.0, 0.0, TAU, 40, Color(Palette.ASH, a), 3.0)
		_text_center(mid.x, well.end.y - 22.0, "no art yet", 19, Color(Palette.BONE_DIM, a))

	var p := box.position
	_text_center(p.x + box.size.x * 0.5, p.y + 442.0, String(c["name"]), 34,
		Color(Palette.BONE if hot else Palette.BONE_DIM, a))
	_text_center(p.x + box.size.x * 0.5, p.y + 476.0, String(c["note"]), 20,
		Color(Palette.ASH, a))

	# Progress
	var bar := Rect2(p.x + 40.0, p.y + 516.0, box.size.x - 80.0, 16.0)
	draw_rect(bar, Color(Palette.ASH_DIM, a))
	if total > 0:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(owned) / float(total), bar.size.y)),
			Color(Palette.COIN, a))
	_text_center(p.x + box.size.x * 0.5, p.y + 566.0,
		"%d of %d tended" % [owned, total], 24, Color(Palette.COIN if owned > 0 else Palette.ASH, a))

	var remaining := 0
	for n in Upgrades.for_character(cid):
		if not Profile.owns(cid, String(n["id"])):
			remaining += Upgrades.price(n)
	_text_center(p.x + box.size.x * 0.5, p.y + 598.0,
		"all of it costs %d more" % remaining if remaining > 0 else "wants for nothing",
		20, Color(Palette.BONE_DIM, a))


# --- view two: the tree ----------------------------------------------------

func _draw_tree() -> void:
	var c: Dictionary = Characters.ALL[_char_i]
	var cid := _character_id()
	_draw_header(String(c["name"]))

	var owned := _owned_count(cid)
	var total := _nodes().size()
	_text_right(size.x * 0.5 + 730.0, 152.0, "%d of %d tended" % [owned, total], 20, Palette.ASH)

	for i in _nodes().size():
		_draw_node(i)

	_text_center(size.x * 0.5, size.y - 64.0,
		"click to buy    .    left / right for another    .    esc to go back",
		21, Palette.ASH_DIM)


func _draw_node(i: int) -> void:
	var node: Dictionary = _nodes()[i]
	var base := _card_rect(i)
	var tier := int(node.get("tier", 1))
	var tcol := _tier_colour(tier)
	var cost := Upgrades.price(node)
	var owned := Profile.owns(_character_id(), String(node["id"]))
	var afford := Profile.gold >= cost
	var hot := _hover == i

	var appear := clampf((_t - float(i) * 0.05) / 0.28, 0.0, 1.0)
	if appear <= 0.0:
		return
	var ease := 1.0 - pow(1.0 - appear, 3.0)
	var a := ease
	var box := Rect2(base.position + Vector2(0.0, (1.0 - ease) * 26.0), base.size)
	if hot and not owned:
		box = box.grow(5.0)

	# An unaffordable node is dimmed, not hidden: you should see what you are
	# saving for.
	var live := owned or afford
	var dim := 1.0 if live else 0.45
	var pulse := 0.5 + 0.5 * sin(_t * (1.4 + 0.5 * float(tier)) + float(i))

	if live:
		var strength := (0.03 + 0.045 * float(tier - 1)) * (0.6 + 0.4 * pulse)
		if hot and not owned:
			strength *= 2.2
		for g in 5:
			var k := float(g + 1)
			draw_rect(box.grow(k * 3.0), Color(tcol, strength / k * a), false, 3.0)

	draw_rect(box, Color(Palette.VOID_LIT, a))
	draw_rect(box, Color(tcol, (0.05 + 0.05 * float(tier - 1)) * dim * a))
	if owned:
		draw_rect(box, Color(Palette.COIN, 0.06 * a))
	draw_rect(box, Color(tcol, (0.8 if hot and live else 0.55) * dim * a),
		false, 3.0 if hot and live else 2.0)
	draw_rect(Rect2(box.position.x, box.position.y, 6.0, box.size.y), Color(tcol, dim * a))

	var p := box.position
	_text_fit(p + Vector2(24, 44), String(node["name"]), 30, Color(tcol, dim * a), box.size.x - 190.0)
	_text_fit(p + Vector2(24, 78), String(node["desc"]), 22,
		Color(Palette.BONE_DIM, dim * a), box.size.x - 190.0)
	_text(p + Vector2(24, 110), Pacts.TIER_NAMES[tier].to_upper(), 17, Color(tcol, 0.7 * dim * a))

	if owned:
		_text_right(box.end.x - 22.0, p.y + 60.0, "OWNED", 26, Color(Palette.COIN, a))
	else:
		_text_right(box.end.x - 22.0, p.y + 60.0, "%d" % cost, 32,
			Color(Palette.COIN if afford else Palette.ASH, a))
		_text_right(box.end.x - 22.0, p.y + 88.0, "gold", 18,
			Color(Palette.COIN if afford else Palette.ASH, 0.7 * a))


static func _tier_colour(tier: int) -> Color:
	match tier:
		3: return Palette.TIER_DAMNED
		2: return Palette.TIER_GRIM
		_: return Palette.TIER_COMMON


# --- text helpers ----------------------------------------------------------

func _width(msg: String, sz: int) -> float:
	return _font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x


func _text(pos: Vector2, msg: String, sz := 24, col := Palette.BONE) -> void:
	draw_string(_font, pos, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _text_fit(pos: Vector2, msg: String, sz: int, col: Color, max_w: float) -> void:
	var s := sz
	while s > 12 and _width(msg, s) > max_w:
		s -= 1
	draw_string(_font, pos, msg, HORIZONTAL_ALIGNMENT_LEFT, -1, s, col)


func _text_right(right_x: float, y: float, msg: String, sz: int, col: Color) -> void:
	draw_string(_font, Vector2(right_x - _width(msg, sz), y), msg,
		HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _text_center(cx: float, y: float, msg: String, sz: int, col: Color) -> void:
	draw_string(_font, Vector2(cx - _width(msg, sz) * 0.5, y), msg,
		HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)
