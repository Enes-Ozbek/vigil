class_name Dungeon
extends Node2D

# The ruined chapel floor the whole game is fought on.
#
# Drawn, not tiled from an asset -- flagstones, cracks, rubble, a wall band and
# braziers, all procedural. The vignette lives in main.gd instead, because it
# frames the VIEW rather than the map. Everything is generated ONCE from a fixed seed
# in setup() and only iterated during _draw, so the layout never shimmers
# between frames and the per-frame cost stays flat.
#
# Colour discipline: the floor is built entirely out of VOID-family values from
# palette.gd, so it can never compete with the sprites for attention. The only
# actual colour down here is brazier light, and that is BLOOD.

const TILE := 48.0
const WALL_THICK := 20.0
const SEED := 20260820

var size := Vector2(960, 540)

var _tiles: Array = []        # {rect, colour}
var _cracks: Array = []       # PackedVector2Array polylines
var _rubble: Array = []       # {pos, radius, colour}
var _braziers: Array = []     # {pos, phase, rate}
var _t := 0.0

# What the player can currently see, in world units. Everything off it is
# skipped, so the per-frame cost stays flat however large the arena gets.
# Set by main each frame; a zero rect means "draw everything".
var view := Rect2():
	set(v):
		# Scrolling the world moves this node's TRANSFORM, which the renderer
		# reapplies to the command list it already has -- so a moving view is
		# not by itself a reason to redraw. Only a view that has moved far
		# enough to expose ground the last cull threw away is.
		view = v
		var moved := (v.position - _built_view.position).abs()
		if moved.x > TILE or moved.y > TILE or v.size != _built_view.size:
			_cull_dirty = true

const FLICKER_HZ := 20.0      # the braziers breathe; they do not need 60fps

var _vis_tiles: Array = []
var _vis_cracks: Array = []
var _vis_rubble: Array = []
var _built_view := Rect2(Vector2(-99999, -99999), Vector2.ZERO)
var _cull_dirty := true
var _flicker_t := 0.0


func _ready() -> void:
	z_index = -50             # behind the player, enemies and bullets


func setup(arena_size: Vector2) -> void:
	size = arena_size
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	_build_tiles(rng)
	_build_cracks(rng)
	_build_rubble(rng)

	_build_braziers(rng)
	_cull_dirty = true
	queue_redraw()


# Lit on a grid rather than at fixed corners, so a bigger arena gets more of
# them instead of the same six spread thinner.
func _build_braziers(rng: RandomNumberGenerator) -> void:
	_braziers = []
	var cols := maxi(2, int(round(size.x / 420.0)))
	var rows := maxi(2, int(round(size.y / 300.0)))
	for cy in rows:
		for cx in cols:
			var p := Vector2(
				(float(cx) + 0.5) / float(cols) * size.x,
				(float(cy) + 0.5) / float(rows) * size.y)
			p += Vector2(rng.randf_range(-34.0, 34.0), rng.randf_range(-26.0, 26.0))
			_braziers.append({
				"pos": p, "phase": rng.randf() * TAU, "rate": rng.randf_range(4.5, 7.5)})


func _build_tiles(rng: RandomNumberGenerator) -> void:
	_tiles = []
	var cols := int(ceil(size.x / TILE))
	var rows := int(ceil(size.y / TILE))
	for cy in rows:
		for cx in cols:
			# Every other row is offset half a tile, like real flagstones.
			var ox := 0.0 if cy % 2 == 0 else TILE * 0.5
			var r := Rect2(float(cx) * TILE + ox + 1.0, float(cy) * TILE + 1.0,
				TILE - 2.0, TILE - 2.0)
			var roll := rng.randf()
			var col: Color
			if roll < 0.055:
				col = Palette.PIT            # a flagstone that is simply gone
			elif roll < 0.30:
				col = Palette.STONE_DARK
			elif roll > 0.93:
				col = Palette.STONE_LIT
			else:
				col = Palette.STONE
			# tiny per-tile jitter so no two stones read as identical
			var j := rng.randf_range(-0.008, 0.008)
			_tiles.append({"rect": r, "col": Color(col.r + j, col.g + j, col.b + j)})


func _build_cracks(rng: RandomNumberGenerator) -> void:
	_cracks = []
	var count := int(9.0 * (size.x * size.y) / (960.0 * 540.0))
	for i in count:
		var pts := PackedVector2Array()
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var dir := Vector2.RIGHT.rotated(rng.randf() * TAU)
		var steps := rng.randi_range(4, 9)
		for k in steps:
			pts.append(p)
			dir = dir.rotated(rng.randf_range(-0.7, 0.7))
			p += dir * rng.randf_range(14.0, 34.0)
		pts.append(p)
		_cracks.append(pts)


func _build_rubble(rng: RandomNumberGenerator) -> void:
	_rubble = []
	var count := int(150.0 * (size.x * size.y) / (960.0 * 540.0))
	for i in count:
		var p := Vector2(rng.randf() * size.x, rng.randf() * size.y)
		var dark := rng.randf() < 0.7
		_rubble.append({
			"pos": p,
			"r": rng.randf_range(0.8, 2.4),
			"col": Palette.PIT if dark else Palette.STONE_LIT,
		})


func _process(delta: float) -> void:
	_t += delta
	# The only thing down here that animates is brazier light, and it breathes
	# slowly. Redrawing the whole floor sixty times a second to move it is the
	# most expensive way to do the least visible work in the game.
	_flicker_t += delta
	if _cull_dirty or _flicker_t >= 1.0 / FLICKER_HZ:
		_flicker_t = 0.0
		queue_redraw()


func _draw() -> void:
	var vis := view.grow(80.0) if view.size != Vector2.ZERO else Rect2(Vector2.ZERO, size)
	if _cull_dirty:
		_recull(vis)

	draw_rect(Rect2(Vector2.ZERO, size), Palette.MORTAR)
	for t in _vis_tiles:
		draw_rect(t["rect"], t["col"])
	for c in _vis_cracks:
		draw_polyline(c, Palette.PIT, 1.5)
	for r in _vis_rubble:
		draw_circle(r["pos"], r["r"], r["col"])

	_draw_braziers(vis)
	_draw_walls()


# Walking the whole map to decide what is on screen costs the same whether the
# view moved a pixel or not, so it is done when the view moves rather than when
# a frame happens -- roughly 1,500 rejections a frame becomes a few a second.
func _recull(vis: Rect2) -> void:
	_cull_dirty = false
	_built_view = view
	_vis_tiles = []
	_vis_cracks = []
	_vis_rubble = []
	for t in _tiles:
		if vis.intersects(t["rect"]):
			_vis_tiles.append(t)
	for c in _cracks:
		if c.size() > 0 and vis.has_point(c[0]):
			_vis_cracks.append(c)
	for r in _rubble:
		if vis.has_point(r["pos"]):
			_vis_rubble.append(r)


# Pools of red light. Each brazier breathes on its own phase and rate, so the
# floor never pulses in unison.
func _draw_braziers(vis: Rect2) -> void:
	for b in _braziers:
		if not vis.grow(140.0).has_point(b["pos"]):
			continue
		var flick: float = 0.86 + 0.14 * sin(_t * float(b["rate"]) + float(b["phase"])) \
			+ 0.05 * sin(_t * float(b["rate"]) * 2.7)
		var reach: float = 120.0 * flick
		for i in 9:
			var k := 1.0 - float(i) / 9.0
			draw_circle(b["pos"], reach * k, Color(Palette.BLOOD, 0.035 * (1.0 - k) + 0.012))
		draw_circle(b["pos"], 5.0 * flick, Color(Palette.BLOOD_BRIGHT, 0.85))
		draw_circle(b["pos"], 2.2 * flick, Color(1.0, 0.86, 0.72, 0.9))


func _draw_walls() -> void:
	var w := WALL_THICK
	draw_rect(Rect2(0, 0, size.x, w), Palette.WALL)
	draw_rect(Rect2(0, size.y - w, size.x, w), Palette.WALL)
	draw_rect(Rect2(0, 0, w, size.y), Palette.WALL)
	draw_rect(Rect2(size.x - w, 0, w, size.y), Palette.WALL)

	# Block joints along the top wall, so the border reads as masonry.
	for x in range(0, int(size.x), 42):
		draw_line(Vector2(float(x), 0.0), Vector2(float(x), w), Palette.PIT, 1.0)
		draw_line(Vector2(float(x) + 21.0, size.y - w), Vector2(float(x) + 21.0, size.y),
			Palette.PIT, 1.0)
	draw_line(Vector2(0, w), Vector2(size.x, w), Palette.WALL_CAP, 1.0)
	draw_line(Vector2(0, size.y - w), Vector2(size.x, size.y - w), Palette.WALL_CAP, 1.0)
