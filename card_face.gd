class_name CardFace

# Draws an Inscryption-styled card: a card that looks INKED, not printed.
#
# Lives in its own file rather than in main.gd because main.gd is already the
# run loop, the HUD and three screens, and this is none of those.
#
# ---------------------------------------------------------------------------
# WHY EVERYTHING HERE IS CROOKED ON PURPOSE
#
# The first version of this file drew the card with draw_rect and solid filled
# polygons. It was clean, symmetrical, perfectly axis-aligned -- and it looked
# like a spreadsheet, because nothing made by hand is any of those things. What
# sells "someone drew this" is not detail, it is ERROR:
#
#   * a line is never straight, and it is never drawn only once
#   * strokes OVERSHOOT at corners, because a pen does not stop on the dot
#   * shading is hatching, not fill -- ink has no grey, only more lines
#   * nothing lines up exactly with anything else
#
# So there is not one draw_rect on the face of this card. Every edge is
# _stroke, every solid shape is _sketch_poly, and every value is built out of
# crossed lines. It costs a few hundred draw calls per card on a screen where
# nothing is moving, which is a fine trade.
#
# All the wobble comes from _wob(), a fixed table read in draw order. The order
# is identical every frame, so the card is crooked in exactly the same way each
# time. Re-rolling jitter per frame would make the whole card crawl, and
# crawling is the fastest way to look fake.
# ---------------------------------------------------------------------------
#
# WHY THE PALETTE BREAKS THE RULE. Everything else in the game is void, ash or
# blood (palette.gd). These are brown, cream and wood: a deliberate fourth
# exception alongside soul motes and pact rarity. A card is an OBJECT being held
# up in front of you, and it reads as one precisely because it does not look
# like the dungeon it came out of.

# Not a tavern card. This came out of a box a dead thing was carrying, so the
# vellum is grey with age rather than cream, the wood is charred rather than
# oiled, and what has soaked into the paper over the years was not tea.
const WOOD_DARK := Color(0.047, 0.036, 0.028)
const WOOD := Color(0.109, 0.082, 0.058)
const WOOD_GRAIN := Color(0.180, 0.140, 0.098)
const PARCH := Color(0.451, 0.416, 0.345)
const PARCH_DIM := Color(0.355, 0.325, 0.266)
const PARCH_DEEP := Color(0.255, 0.232, 0.190)
const INK := Color(0.055, 0.043, 0.036)
const INK_THIN := Color(0.055, 0.043, 0.036, 0.46)
const INK_SOFT := Color(0.600, 0.566, 0.490)      # the engraved highlight
const ROT := Color(0.145, 0.118, 0.086)           # what has crept in from the edges
const OLD_BLOOD := Color(0.243, 0.078, 0.078)
const GILT := Color(0.792, 0.647, 0.318)

const BORDER := 15.0
const NOTCH := 17.0

static var _wobble := PackedFloat32Array()
static var _grain := {}
static var _w := 0            # read head into the wobble table, reset per card

# When true every primitive below draws STRAIGHT and FILLED instead of inked.
#
# One shape library, two looks. The chest cards are parchment and want the full
# shaky treatment; the pact cards are dark panels with neon rarity glow, where a
# hatched woodcut would both clash and cost more per frame than the rest of the
# screen put together -- and unlike the chest screen, pact cards animate, so
# they pay it sixty times a second. Same symbols, drawn flat.
static var _plain := false


# --- the hand ---------------------------------------------------------------

# A fixed table of jitter, walked in draw order. Deterministic by construction:
# the same card drawn twice consumes the same values in the same sequence.
static func _wob(scale := 1.0) -> float:
	if _wobble.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 0x5EED
		for i in 4096:
			_wobble.append(rng.randf_range(-1.0, 1.0))
	_w = (_w + 1) % _wobble.size()
	return _wobble[_w] * scale


# Point the hand at a particular card, on a particular BOIL frame.
#
# Hand-drawn animation does not glide, it BOILS: the same line is inked two or
# three times and the frames are cycled, so the outline shivers in place and
# never sits perfectly still. Nothing made by a person holds an edge to the
# pixel across a second of screen time, and a border that does is the single
# clearest tell that a machine drew it.
#
# Passing a different boil re-seeds the wobble, so the same card comes out
# crooked in a different -- but still fixed and repeatable -- way.
static func set_hand(key: String, boil := 0) -> void:
	_w = (absi(hash(key)) + boil * 617) % 3000


# How many distinct inked frames the boil cycles through, and how fast.
const BOIL_FRAMES := 3
const BOIL_HZ := 7.0


static func boil_frame(t: float) -> int:
	return int(t * BOIL_HZ) % BOIL_FRAMES


# A box drawn by hand, for callers outside this file.
static func sketch_box(ci: CanvasItem, r: Rect2, col: Color, w := 1.6,
		passes := 2, wob := 1.8) -> void:
	_sketch_box(ci, r, col, w, passes, wob)


static func stroke(ci: CanvasItem, a: Vector2, b: Vector2, col: Color,
		w := 1.6, passes := 2, wob := 2.0) -> void:
	_stroke(ci, a, b, col, w, passes, wob)


# A stroke caught PART WAY through being drawn.
#
# The single clearest way to say "a hand made this" is to show the hand making
# it. A line that fades in was printed; a line whose far end is still travelling
# was drawn. `t` is how much of it exists yet.
static func stroke_drawn(ci: CanvasItem, a: Vector2, b: Vector2, t: float,
		col: Color, w := 1.6, passes := 2, wob := 2.0) -> void:
	var k := clampf(t, 0.0, 1.0)
	if k <= 0.001:
		return
	# No overshoot until the stroke is finished -- a pen does not fling past a
	# corner it has not reached.
	_stroke(ci, a, a.lerp(b, k), col, w, passes, wob, 3.2 if k >= 0.999 else 0.0)


# A box being drawn, one edge at a time, in the order a hand would take them.
static func box_drawn(ci: CanvasItem, r: Rect2, t: float, col: Color,
		w := 1.6, wob := 1.8) -> void:
	var a := r.position
	var b := r.end
	var edges := [[Vector2(a.x, a.y), Vector2(b.x, a.y)],
		[Vector2(b.x, a.y), Vector2(b.x, b.y)],
		[Vector2(b.x, b.y), Vector2(a.x, b.y)],
		[Vector2(a.x, b.y), Vector2(a.x, a.y)]]
	for i in edges.size():
		var span := clampf(t * 4.0 - float(i), 0.0, 1.0)
		stroke_drawn(ci, edges[i][0], edges[i][1], span, col, w, 2, wob)


# One inked line. Never straight, never once: a real stroke bows in the middle,
# overshoots both ends, and gets gone over a second time slightly off.
static func _stroke(ci: CanvasItem, a: Vector2, b: Vector2, col: Color,
		w := 1.6, passes := 2, wob := 2.4, over := 3.2) -> void:
	var d := b - a
	if d.length() < 0.01:
		return
	if _plain:
		ci.draw_line(a, b, col, w)
		return
	var n := d.orthogonal().normalized()
	var ext := d.normalized() * over
	for p in passes:
		var fade := col if p == 0 else Color(col, col.a * 0.42)
		var from := a - ext * (0.6 + _wob(0.4))
		var to := b + ext * (0.6 + _wob(0.4))
		# More interior points than before: four bends read as a nervous hand,
		# two read as a slightly bent ruler.
		var pts := PackedVector2Array()
		pts.append(from)
		for i in range(1, 6):
			pts.append(from.lerp(to, float(i) / 6.0) + n * _wob(wob))
		pts.append(to)
		ci.draw_polyline(pts, fade, maxf(0.5, w + _wob(0.55)))


# A box a person drew: four strokes that miss each other at the corners.
static func _sketch_box(ci: CanvasItem, r: Rect2, col: Color, w := 1.6,
		passes := 2, wob := 1.5) -> void:
	var a := r.position
	var b := r.end
	_stroke(ci, Vector2(a.x, a.y), Vector2(b.x, a.y), col, w, passes, wob)
	_stroke(ci, Vector2(b.x, a.y), Vector2(b.x, b.y), col, w, passes, wob)
	_stroke(ci, Vector2(b.x, b.y), Vector2(a.x, b.y), col, w, passes, wob)
	_stroke(ci, Vector2(a.x, b.y), Vector2(a.x, a.y), col, w, passes, wob)


# Shading, the only way ink can do it: parallel lines, unevenly spaced, each
# one falling short of the edge it is filling toward.
static func _hatch(ci: CanvasItem, pts: PackedVector2Array, col: Color,
		spacing := 5.0, ang := -0.72, w := 1.1) -> void:
	if pts.size() < 3 or _plain:
		return
	var rot := []
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in pts:
		var q := p.rotated(-ang)
		rot.append(q)
		lo = Vector2(minf(lo.x, q.x), minf(lo.y, q.y))
		hi = Vector2(maxf(hi.x, q.x), maxf(hi.y, q.y))
	var y := lo.y + spacing * 0.4
	while y <= hi.y:
		var xs := []
		for i in rot.size():
			var p0: Vector2 = rot[i]
			var p1: Vector2 = rot[(i + 1) % rot.size()]
			if (p0.y <= y and p1.y > y) or (p1.y <= y and p0.y > y):
				xs.append(p0.x + (y - p0.y) / (p1.y - p0.y) * (p1.x - p0.x))
		xs.sort()
		var k := 0
		while k + 1 < xs.size():
			var x0: float = float(xs[k]) + 0.8
			var x1: float = float(xs[k + 1]) - 0.8
			if x1 - x0 > 1.0:
				# Sometimes short of the outline, sometimes over it. A hand
				# filling a shape does not respect the shape, and the strokes
				# that escape are what stop hatching looking like a texture fill.
				_stroke(ci, Vector2(x0 + _wob(2.6), y).rotated(ang),
					Vector2(x1 + _wob(2.6), y).rotated(ang), col, w, 1, 1.3, 0.9)
			k += 2
		y += spacing + _wob(1.0)


# A solid shape, drawn the way ink makes solids: hatched twice at crossed
# angles, then outlined.
static func _sketch_poly(ci: CanvasItem, pts: Array, col: Color,
		spacing := 4.2, outline := true) -> void:
	var p := PackedVector2Array(pts)
	if _plain:
		ci.draw_colored_polygon(p, col)
		return
	_hatch(ci, p, col, spacing, -0.72, 1.2)
	_hatch(ci, p, Color(col, col.a * 0.55), spacing * 1.35, 0.78, 1.0)
	if outline:
		for i in p.size():
			_stroke(ci, p[i], p[(i + 1) % p.size()], col, 1.7, 3, 1.5, 2.2)


# --- the card ---------------------------------------------------------------

static func draw_card(ci: CanvasItem, font: Font, r: Rect2, card: Dictionary,
		hot: bool) -> void:
	var id := String(card.get("id", "?"))
	# Same read head every frame -> the same crooked card every frame.
	_w = absi(hash(id)) % 3000

	_plank(ci, r)
	_paper(ci, r, id)

	var f := Rect2(r.position + Vector2(BORDER, BORDER),
		r.size - Vector2(BORDER * 2.0, BORDER * 2.0))

	# name, underscored by hand rather than sat in a filled band
	var nm := String(card.get("name", "?"))
	var ny := f.position.y + 38.0
	_centred(ci, font, f.get_center().x + 1.0, ny + 1.0, nm, 26, Color(INK_SOFT, 0.45))
	_centred(ci, font, f.get_center().x, ny, nm, 26, INK)
	var nw := minf(font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x * 0.62,
		f.size.x * 0.42)
	_stroke(ci, Vector2(f.get_center().x - nw, ny + 12.0),
		Vector2(f.get_center().x + nw, ny + 12.0), INK_THIN, 1.4, 2, 1.2)

	# the well, and the thing carved into it
	var well := Rect2(r.position + Vector2(38.0, 74.0), Vector2(r.size.x - 76.0, 182.0))
	_hatch(ci, PackedVector2Array([well.position, Vector2(well.end.x, well.position.y),
		well.end, Vector2(well.position.x, well.end.y)]),
		Color(PARCH_DEEP, 0.20), 10.0, 0.78, 1.0)
	_sketch_box(ci, well, INK, 2.0, 2, 1.8)
	_icon(ci, String(card.get("icon", "blade")), well.get_center(), 54.0)

	# cost, in blood
	var sy := well.end.y + 30.0
	_stroke(ci, Vector2(f.position.x + 26.0, sy - 16.0), Vector2(f.end.x - 26.0, sy - 16.0),
		INK_THIN, 1.4, 2, 1.6)
	# RARITY, in blood. One drop a tier, IN the tier's own colour.
	#
	# On a chest card this was only ever weight, because those are all Damned.
	# Pacts live on these cards now too, and there rarity is real information --
	# so it is encoded twice, as a COUNT and as a HUE. Either alone would do;
	# both means it survives a glance, and it survives colourblindness.
	var tier := int(card.get("tier", 3))
	var rare := tier_ink(tier)
	for i in tier:
		_drop(ci, Vector2(r.get_center().x - float(tier - 1) * 17.0 + float(i) * 34.0, sy), rare)

	# what it does
	var lines := _wrap(font, String(card.get("boon", "")), 19, r.size.x - 74.0)
	for i in mini(lines.size(), 3):
		_centred(ci, font, r.get_center().x + _wob(0.8), r.end.y - 84.0 + float(i) * 24.0,
			lines[i], 19, INK)

	if hot:
		_gilding(ci, r, GILT.lerp(tier_ink(tier), 0.45))


# The wooden plank, whittled rather than cut: the outline is a closed run of
# crooked strokes, and the grain is scratched down the exposed edges.
static func _plank(ci: CanvasItem, r: Rect2) -> void:
	var p := _corners(r, 0.0)
	ci.draw_colored_polygon(p, WOOD_DARK)
	ci.draw_colored_polygon(_corners(r, 4.0), WOOD)
	for i in p.size():
		_stroke(ci, p[i], p[(i + 1) % p.size()], WOOD_DARK, 2.4, 2, 1.8, 3.0)
	for i in 14:
		var y := r.position.y + 12.0 + float(i) * (r.size.y - 24.0) / 14.0
		_stroke(ci, Vector2(r.position.x + 3.0, y), Vector2(r.position.x + 14.0, y),
			WOOD_GRAIN, 1.0, 1, 1.4)
		_stroke(ci, Vector2(r.end.x - 14.0, y), Vector2(r.end.x - 3.0, y),
			WOOD_GRAIN, 1.0, 1, 1.4)


static func _corners(r: Rect2, inset: float) -> PackedVector2Array:
	var a := r.position + Vector2(inset, inset)
	var b := r.end - Vector2(inset, inset)
	var n := NOTCH - inset * 0.5
	return PackedVector2Array([
		Vector2(a.x + n, a.y), Vector2(b.x - n, a.y), Vector2(b.x, a.y + n),
		Vector2(b.x, b.y - n), Vector2(b.x - n, b.y), Vector2(a.x + n, b.y),
		Vector2(a.x, b.y - n), Vector2(a.x, a.y + n)])


# Paper: a torn edge, fibres, foxing, and a few old stains. The speckle is
# cached per card rather than re-rolled, for the same reason the wobble is.
static func _paper(ci: CanvasItem, r: Rect2, id: String) -> void:
	var f := Rect2(r.position + Vector2(BORDER, BORDER),
		r.size - Vector2(BORDER * 2.0, BORDER * 2.0))
	# a torn outline rather than a rectangle
	var edge := PackedVector2Array()
	var steps := 13
	for i in steps:
		edge.append(Vector2(f.position.x + f.size.x * float(i) / float(steps),
			f.position.y + _wob(2.2)))
	for i in steps:
		edge.append(Vector2(f.end.x + _wob(2.2),
			f.position.y + f.size.y * float(i) / float(steps)))
	for i in steps:
		edge.append(Vector2(f.end.x - f.size.x * float(i) / float(steps), f.end.y + _wob(2.2)))
	for i in steps:
		edge.append(Vector2(f.position.x + _wob(2.2),
			f.end.y - f.size.y * float(i) / float(steps)))
	ci.draw_colored_polygon(edge, PARCH)

	for s in _speckles(id):
		ci.draw_circle(f.position + s["p"] * f.size, s["r"], s["c"])
	# Stains. Most are age; one is not, and the one that is not is why the blood
	# drops further down do not read as decoration.
	var si := 0
	for s in _stains(id):
		var blood: bool = si >= 3
		_blot(ci, f.position + s["p"] * f.size, s["r"],
			OLD_BLOOD if blood else ROT, blood)
		si += 1
	# fibres in the paper
	for i in 26:
		var a := f.get_center() + Vector2(_wob(0.5) * f.size.x, _wob(0.5) * f.size.y)
		_stroke(ci, a, a + Vector2(_wob(9.0), _wob(4.0)), Color(PARCH_DIM, 0.30), 1.0, 1, 0.5, 0.0)
	# Rot, creeping in from the edges -- and ONLY the edges. Hatching the whole
	# outline filled the entire face with even diagonals, which does not read as
	# aged paper, it reads as ruled notepaper. Bands down each side instead,
	# darkening in three steps so the corners go first.
	for step in 3:
		var b := 34.0 - float(step) * 11.0
		var a := 0.05 + float(step) * 0.045
		for band in [Rect2(f.position, Vector2(f.size.x, b)),
				Rect2(Vector2(f.position.x, f.end.y - b), Vector2(f.size.x, b)),
				Rect2(f.position, Vector2(b, f.size.y)),
				Rect2(Vector2(f.end.x - b, f.position.y), Vector2(b, f.size.y))]:
			ci.draw_rect(band, Color(ROT, a))

	# Stray marks: a nick, a scratch, somewhere a hand rested. Nothing here means
	# anything, which is exactly why it reads as an object that has been carried
	# rather than an image that was generated.
	for i in 5:
		var a := f.position + Vector2((_wob(0.5) + 0.5) * f.size.x, (_wob(0.5) + 0.5) * f.size.y)
		_stroke(ci, a, a + Vector2(_wob(16.0), _wob(11.0)), Color(INK, 0.20), 1.1, 1, 1.6, 1.0)


static func _speckles(id: String) -> Array:
	if _grain.has(id):
		return _grain[id]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var out := []
	for i in 210:
		var pale := rng.randf() < 0.30
		out.append({
			"p": Vector2(rng.randf(), rng.randf()),
			"r": rng.randf_range(0.9, 3.4),
			# On dark vellum the pale flecks are what keep it from reading as a
			# flat grey card, so they carry more weight than the dark ones.
			"c": Color(0.706, 0.671, 0.588, rng.randf_range(0.10, 0.26)) if pale
				else Color(0.180, 0.157, 0.126, rng.randf_range(0.08, 0.18)),
		})
	_grain[id] = out
	return out


static func _stains(id: String) -> Array:
	var k := id + "~s"
	if _grain.has(k):
		return _grain[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(k)
	var out := []
	for i in 5:
		out.append({"p": Vector2(rng.randf_range(0.10, 0.90), rng.randf_range(0.18, 0.94)),
			"r": rng.randf_range(14.0, 32.0)})
	_grain[k] = out
	return out


# A stain that soaked in, not a circle someone stamped. Perfectly round marks
# were the single most obviously machine-made thing left on the card: real ones
# spread unevenly along the paper's grain, darken toward the middle, and throw
# a few specks past their own edge.
static func _blot(ci: CanvasItem, at: Vector2, rad: float, col: Color, spatter: bool) -> void:
	var lobes := 13
	var edge := []
	for i in lobes:
		var a := TAU * float(i) / float(lobes)
		# bias the wobble so the blot is lopsided rather than merely bumpy
		edge.append(Vector2(cos(a), sin(a)) * rad * (0.72 + absf(_wob(0.42))))
	for layer in 3:
		var k := 1.0 - float(layer) * 0.26
		var pts := PackedVector2Array()
		for e in edge:
			pts.append(at + e * k)
		ci.draw_colored_polygon(pts, Color(col, 0.055 + float(layer) * 0.03))
	if spatter:
		for i in 9:
			ci.draw_circle(at + Vector2(_wob(rad * 1.9), _wob(rad * 1.9)),
				absf(_wob(2.0)) + 0.5, Color(col, 0.14))


# Dried blood for a Common, verdigris for a Grim, tarnished gold for a Damned --
# the same three signals the neon panels used, dulled to something that could
# have soaked into old paper.
static func tier_ink(tier: int) -> Color:
	match tier:
		2:
			return Color(0.216, 0.404, 0.196)
		3:
			return Color(0.639, 0.451, 0.114)
		_:
			return OLD_BLOOD


static func _drop(ci: CanvasItem, at: Vector2, col := OLD_BLOOD) -> void:
	var pts := [at + Vector2(0.0, -8.0)]
	for i in range(1, 12):
		var a := PI * -0.5 + TAU * float(i) / 12.0
		pts.append(at + Vector2(sin(a) * 9.0, 4.0 - cos(a) * 9.0))
	# Dried, not fresh. Palette.BLOOD is the game's danger colour and at full
	# strength it was the only saturated thing on the card, which pulled the eye
	# to the cost instead of to what the card actually does.
	_sketch_poly(ci, pts, col, 3.0)


static func _gilding(ci: CanvasItem, r: Rect2, col := GILT) -> void:
	var p := _corners(r, 0.0)
	for i in p.size():
		_stroke(ci, p[i], p[(i + 1) % p.size()], col, 3.0, 2, 1.6, 3.5)
	var q := _corners(r.grow(-7.0), 0.0)
	for i in q.size():
		_stroke(ci, q[i], q[(i + 1) % q.size()], Color(col, 0.5), 1.6, 1, 1.4, 2.0)


# --- the symbols ------------------------------------------------------------
#
# Woodcut, not illustration: heavy shapes, hatched rather than filled, no fine
# detail. Anything that needs a second look to identify has failed.

# Draw one symbol. `ink` is the mark, `cut` is whatever shows through a gap in
# it -- parchment on a chest card, the panel behind on a pact card.
static func draw_symbol(ci: CanvasItem, kind: String, c: Vector2, s: float,
		ink: Color, cut: Color, plain := false) -> void:
	var was := _plain
	_plain = plain
	_icon(ci, kind, c, s, ink, cut)
	_plain = was


static func _icon(ci: CanvasItem, kind: String, c: Vector2, s: float,
		INK := INK, PARCH := PARCH) -> void:
	match kind:
		"blade":                      # a broken sword
			_sketch_poly(ci, [c + Vector2(0, -s * 1.10), c + Vector2(s * 0.21, -s * 0.62),
				c + Vector2(s * 0.21, s * 0.16), c + Vector2(-s * 0.21, s * 0.16),
				c + Vector2(-s * 0.21, -s * 0.62)], INK, 4.6)
			_sketch_poly(ci, [c + Vector2(-s * 0.72, s * 0.16), c + Vector2(s * 0.72, s * 0.16),
				c + Vector2(s * 0.66, s * 0.36), c + Vector2(-s * 0.66, s * 0.36)], INK, 3.6)
			_sketch_poly(ci, [c + Vector2(-s * 0.11, s * 0.36), c + Vector2(s * 0.11, s * 0.36),
				c + Vector2(s * 0.11, s * 0.86), c + Vector2(-s * 0.11, s * 0.86)], INK, 3.4)
			_ring(ci, c + Vector2(0, s * 0.98), s * 0.20, INK)
			# the break: two strokes cutting across the blade
			_stroke(ci, c + Vector2(-s * 0.26, -s * 0.16), c + Vector2(s * 0.26, -s * 0.34),
				PARCH, 3.0, 1, 1.0)
			_stroke(ci, c + Vector2(-s * 0.26, -s * 0.06), c + Vector2(s * 0.26, -s * 0.24),
				PARCH, 2.4, 1, 1.0)
		"split":
			_stroke(ci, c + Vector2(0, s * 0.98), c + Vector2(0, s * 0.08), INK, 4.0, 3, 1.2)
			for d in [-1.0, 1.0]:
				var tip := c + Vector2(d * s * 0.60, -s * 0.82)
				_stroke(ci, c + Vector2(0, s * 0.08), tip, INK, 3.6, 3, 1.4)
				_sketch_poly(ci, [tip + Vector2(d * s * 0.20, -s * 0.20),
					tip + Vector2(-d * s * 0.22, 0.0),
					tip + Vector2(d * s * 0.04, s * 0.26)], INK, 3.2)
		"urn":
			_sketch_poly(ci, [c + Vector2(-s * 0.60, -s * 0.98), c + Vector2(s * 0.60, -s * 0.98),
				c + Vector2(s * 0.60, -s * 0.78), c + Vector2(-s * 0.60, -s * 0.78)], INK, 3.6)
			_sketch_poly(ci, [c + Vector2(-s * 0.44, -s * 0.78), c + Vector2(s * 0.44, -s * 0.78),
				c + Vector2(s * 0.68, s * 0.30), c + Vector2(s * 0.34, s * 0.92),
				c + Vector2(-s * 0.34, s * 0.92), c + Vector2(-s * 0.68, s * 0.30)], INK, 5.0)
			_stroke(ci, c + Vector2(0, -s * 0.42), c + Vector2(0, s * 0.46), PARCH, 4.0, 1, 1.0)
			_stroke(ci, c + Vector2(-s * 0.30, -s * 0.10), c + Vector2(s * 0.30, -s * 0.10),
				PARCH, 4.0, 1, 1.0)
		"crown":
			_sketch_poly(ci, [c + Vector2(-s * 0.80, s * 0.28), c + Vector2(-s * 0.60, -s * 0.60),
				c + Vector2(-s * 0.28, s * 0.00), c + Vector2(0, -s * 0.86),
				c + Vector2(s * 0.28, s * 0.00), c + Vector2(s * 0.60, -s * 0.60),
				c + Vector2(s * 0.80, s * 0.28)], INK, 4.8)
			_sketch_poly(ci, [c + Vector2(-s * 0.80, s * 0.28), c + Vector2(s * 0.80, s * 0.28),
				c + Vector2(s * 0.80, s * 0.56), c + Vector2(-s * 0.80, s * 0.56)], INK, 3.6)
		"eye":
			var lid := [c + Vector2(-s * 0.98, 0)]
			for i in range(1, 7):
				lid.append(c + Vector2(-s * 0.98 + s * 1.96 * float(i) / 6.0,
					-s * 0.62 * sin(PI * float(i) / 6.0)))
			lid.append(c + Vector2(s * 0.98, 0))
			for i in range(1, 7):
				lid.append(c + Vector2(s * 0.98 - s * 1.96 * float(i) / 6.0,
					s * 0.62 * sin(PI * float(i) / 6.0)))
			_hatch(ci, PackedVector2Array(lid), Color(INK, 0.5), 6.0, -0.72, 1.0)
			for i in lid.size():
				_stroke(ci, lid[i], lid[(i + 1) % lid.size()], INK, 2.0, 2, 1.0, 1.0)
			_ring(ci, c, s * 0.34, INK)
			_disc(ci, c, s * 0.17, INK)
			for i in 5:
				var a := PI * (0.15 + 0.175 * float(i))
				_stroke(ci, c - Vector2(cos(a), sin(a)) * s * 1.02,
					c - Vector2(cos(a), sin(a)) * s * 1.30, INK, 1.6, 1, 1.0)
		"swift":
			for d in [-1.0, 0.0, 1.0]:
				var y: float = d * s * 0.50
				_sketch_poly(ci, [c + Vector2(-s * 0.92, y - s * 0.08),
					c + Vector2(s * 0.30, y - s * 0.08), c + Vector2(s * 0.30, y - s * 0.26),
					c + Vector2(s * 0.90, y), c + Vector2(s * 0.30, y + s * 0.26),
					c + Vector2(s * 0.30, y + s * 0.08),
					c + Vector2(-s * 0.92, y + s * 0.08)], INK, 3.4)
		"shield":
			_sketch_poly(ci, [c + Vector2(-s * 0.72, -s * 0.84), c + Vector2(s * 0.72, -s * 0.84),
				c + Vector2(s * 0.72, s * 0.14), c + Vector2(0, s * 1.00),
				c + Vector2(-s * 0.72, s * 0.14)], INK, 5.2)
			_stroke(ci, c + Vector2(0, -s * 0.60), c + Vector2(0, s * 0.56), PARCH, 5.0, 1, 1.0)
			_stroke(ci, c + Vector2(-s * 0.42, -s * 0.18), c + Vector2(s * 0.42, -s * 0.18),
				PARCH, 5.0, 1, 1.0)
		"pierce":
			for i in 3:
				var x := -s * 0.46 + float(i) * s * 0.52
				_stroke(ci, c + Vector2(x, -s * 0.78), c + Vector2(x, -s * 0.24), INK, 3.0, 2, 1.2)
				_stroke(ci, c + Vector2(x, s * 0.24), c + Vector2(x, s * 0.78), INK, 3.0, 2, 1.2)
			_sketch_poly(ci, [c + Vector2(-s * 1.02, s * 0.10), c + Vector2(s * 0.62, s * 0.10),
				c + Vector2(s * 0.62, s * 0.30), c + Vector2(s * 1.10, 0),
				c + Vector2(s * 0.62, -s * 0.30), c + Vector2(s * 0.62, -s * 0.10),
				c + Vector2(-s * 1.02, -s * 0.10)], INK, 3.0)
		"coin":
			_ring(ci, c, s * 0.84, INK, 2.4)
			_ring(ci, c, s * 0.62, INK, 1.6)
			_disc(ci, c, s * 0.28, INK)
			for i in 8:
				var a := TAU * float(i) / 8.0
				_stroke(ci, c + Vector2(cos(a), sin(a)) * s * 0.86,
					c + Vector2(cos(a), sin(a)) * s * 1.02, INK, 1.8, 1, 1.0)
		"fang":
			_sketch_poly(ci, [c + Vector2(-s * 0.84, -s * 0.76), c + Vector2(s * 0.84, -s * 0.76),
				c + Vector2(s * 0.60, -s * 0.34), c + Vector2(-s * 0.60, -s * 0.34)], INK, 3.6)
			for d in [-0.54, 0.0, 0.54]:
				_sketch_poly(ci, [c + Vector2(d * s - s * 0.22, -s * 0.34),
					c + Vector2(d * s + s * 0.22, -s * 0.34),
					c + Vector2(d * s, s * 0.90)], INK, 3.4)
		"heart":                      # health
			_sketch_poly(ci, [c + Vector2(0, s * 0.96), c + Vector2(-s * 0.92, -s * 0.10),
				c + Vector2(-s * 0.92, -s * 0.52), c + Vector2(-s * 0.50, -s * 0.86),
				c + Vector2(0, -s * 0.50), c + Vector2(s * 0.50, -s * 0.86),
				c + Vector2(s * 0.92, -s * 0.52), c + Vector2(s * 0.92, -s * 0.10)], INK, 4.6)
		"sprig":                      # regeneration
			_stroke(ci, c + Vector2(0, s * 0.98), c + Vector2(0, -s * 0.86), INK, 3.0, 3, 1.6)
			for i in 3:
				var y := -s * 0.52 + float(i) * s * 0.52
				for d in [-1.0, 1.0]:
					_sketch_poly(ci, [c + Vector2(0, y), c + Vector2(d * s * 0.70, y - s * 0.30),
						c + Vector2(d * s * 0.30, y + s * 0.24)], INK, 3.0)
		"leech":                      # health drawn out of a kill
			# Sweep left -> bottom -> right and close to the tip. Sweeping the
			# FULL circle from the tip crosses the outline over itself, which
			# hatching tolerates but draw_colored_polygon refuses to triangulate
			# -- so the plain version came out completely blank.
			var drop := [c + Vector2(0, -s * 1.00)]
			for i in 13:
				var a := PI * (1.0 - float(i) / 12.0)
				drop.append(c + Vector2(cos(a) * s * 0.68, s * 0.24 + sin(a) * s * 0.68))
			_sketch_poly(ci, drop, INK, 4.0)
			# the cross is cut OUT of the drop, so it reads as blood becoming health
			_stroke(ci, c + Vector2(0, -s * 0.14), c + Vector2(0, s * 0.62), PARCH, 5.5, 1, 0.8)
			_stroke(ci, c + Vector2(-s * 0.26, s * 0.24), c + Vector2(s * 0.26, s * 0.24), PARCH, 5.5, 1, 0.8)
		"boot":                       # move speed
			_sketch_poly(ci, [c + Vector2(-s * 0.34, -s * 0.90), c + Vector2(s * 0.16, -s * 0.90),
				c + Vector2(s * 0.16, s * 0.24), c + Vector2(s * 0.88, s * 0.40),
				c + Vector2(s * 0.88, s * 0.82), c + Vector2(-s * 0.34, s * 0.82)], INK, 4.2)
			for i in 3:
				var y := -s * 0.60 + float(i) * s * 0.44
				_stroke(ci, c + Vector2(-s * 0.56, y), c + Vector2(-s * 1.10, y), INK, 2.0, 1, 1.2)
		"rings":                      # area
			for i in 3:
				_ring(ci, c, s * (0.34 + float(i) * 0.30), INK, 2.4 - float(i) * 0.5)
			_disc(ci, c, s * 0.13, INK)
		"dart":                       # projectile speed
			_sketch_poly(ci, [c + Vector2(s * 1.02, 0), c + Vector2(s * 0.20, -s * 0.52),
				c + Vector2(s * 0.36, 0), c + Vector2(s * 0.20, s * 0.52)], INK, 3.0)
			for i in 3:
				var y := -s * 0.46 + float(i) * s * 0.46
				_stroke(ci, c + Vector2(s * 0.10, y), c + Vector2(-s * 0.98 + float(i % 2) * s * 0.24, y),
					INK, 2.4, 2, 1.3)
		"tail":                       # projectile lifetime
			_sketch_poly(ci, [c + Vector2(s * 1.00, 0), c + Vector2(s * 0.24, -s * 0.46),
				c + Vector2(s * 0.24, s * 0.46)], INK, 3.0)
			var trail := PackedVector2Array()
			for i in 9:
				var t := float(i) / 8.0
				trail.append(c + Vector2(s * 0.24 - t * s * 1.28, sin(t * PI * 1.8) * s * 0.34))
			ci.draw_polyline(trail, INK, 2.6)
		"ricochet":                   # bounce
			var path := [c + Vector2(-s * 1.00, s * 0.62), c + Vector2(-s * 0.24, -s * 0.56),
				c + Vector2(s * 0.34, s * 0.34), c + Vector2(s * 0.92, -s * 0.62)]
			for i in path.size() - 1:
				_stroke(ci, path[i], path[i + 1], INK, 2.8, 2, 1.4)
			for pt in [path[1], path[2]]:
				_disc(ci, pt, s * 0.13, INK)
		"impact":                     # knockback
			_sketch_poly(ci, [c + Vector2(-s * 0.98, -s * 0.42), c + Vector2(-s * 0.30, -s * 0.42),
				c + Vector2(-s * 0.30, s * 0.42), c + Vector2(-s * 0.98, s * 0.42)], INK, 3.4)
			for i in 5:
				var a := -0.75 + float(i) * 0.375
				_stroke(ci, c + Vector2(cos(a), sin(a)) * s * 0.42,
					c + Vector2(cos(a), sin(a)) * s * 1.04, INK, 2.4, 2, 1.3)
		"magnet":                     # pickup radius
			# A proper horseshoe. Rings with a dot in them read as a target, which
			# is what the first attempt at this drew and what it was mistaken for.
			var R := s * 0.82
			var tw := s * 0.36
			var leg := s * 0.62
			var off := Vector2(0.0, -s * 0.22)
			var pts := []
			for i in 13:
				var a := PI + PI * float(i) / 12.0
				pts.append(c + off + Vector2(cos(a) * R, sin(a) * R))
			pts.append(c + off + Vector2(R, leg))
			pts.append(c + off + Vector2(R - tw, leg))
			for i in 13:
				var a := TAU - PI * float(i) / 12.0
				pts.append(c + off + Vector2(cos(a) * (R - tw), sin(a) * (R - tw)))
			pts.append(c + off + Vector2(-(R - tw), leg))
			pts.append(c + off + Vector2(-R, leg))
			_sketch_poly(ci, pts, INK, 4.0)
		"mote":                       # experience
			for i in 4:
				var a := TAU * float(i) / 8.0
				_stroke(ci, c - Vector2(cos(a), sin(a)) * s * 0.98,
					c + Vector2(cos(a), sin(a)) * s * 0.98, INK, 2.2, 2, 1.3)
			_disc(ci, c, s * 0.30, INK)
		"veil":                       # dodge
			for i in 3:
				var y := -s * 0.50 + float(i) * s * 0.50
				var wisp := PackedVector2Array()
				for k in 9:
					var t := float(k) / 8.0
					wisp.append(c + Vector2(-s * 0.98 + t * s * 1.96,
						y + sin(t * PI * 2.0 + float(i)) * s * 0.20))
				ci.draw_polyline(wisp, Color(INK, 1.0 - float(i) * 0.22), 2.6)
		_:
			_ring(ci, c, s * 0.6, INK)


static func _ring(ci: CanvasItem, c: Vector2, rad: float, col: Color, w := 2.0) -> void:
	if _plain:
		ci.draw_arc(c, rad, 0.0, TAU, 26, col, w)
		return
	var pts := []
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * (rad + _wob(1.0)))
	for i in pts.size():
		_stroke(ci, pts[i], pts[(i + 1) % pts.size()], col, w, 2, 0.8, 1.0)


static func _disc(ci: CanvasItem, c: Vector2, rad: float, col: Color) -> void:
	if _plain:
		ci.draw_circle(c, rad, col)
		return
	var pts := []
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * rad)
	_sketch_poly(ci, pts, col, 2.6)


# --- text -------------------------------------------------------------------

static func _centred(ci: CanvasItem, font: Font, cx: float, y: float, msg: String,
		size: int, col: Color) -> void:
	var w := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	ci.draw_string(font, Vector2(cx - w * 0.5, y), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func _wrap(font: Font, msg: String, size: int, max_w: float) -> Array:
	var out := []
	var line := ""
	for word in msg.split(" ", false):
		var t := word if line == "" else line + " " + word
		if font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w and line != "":
			out.append(line)
			line = word
		else:
			line = t
	if line != "":
		out.append(line)
	return out
