class_name UiTheme

# One Theme for every Control in the game, built from palette.gd.
#
# This is the point of using Control nodes instead of draw_string: styling is
# declared once here and every button, label and checkbox picks it up. The old
# hand-drawn HUD had colours and sizes repeated at each call site.

static var _cached: Theme = null


static func get_theme() -> Theme:
	if _cached != null:
		return _cached

	var t := Theme.new()
	t.default_font = ThemeDB.fallback_font
	t.default_font_size = 26

	t.set_stylebox("normal", "Button", _box(Palette.VOID_LIT, Palette.ASH_DIM, 2))
	t.set_stylebox("hover", "Button", _box(Color(0.16, 0.13, 0.15), Palette.BLOOD, 3))
	t.set_stylebox("pressed", "Button", _box(Color(0.22, 0.10, 0.12), Palette.BLOOD_BRIGHT, 3))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Palette.BLOOD, 2))
	t.set_stylebox("disabled", "Button", _box(Palette.VOID, Palette.ASH_DIM, 1))

	t.set_color("font_color", "Button", Palette.BONE_DIM)
	t.set_color("font_hover_color", "Button", Palette.BONE)
	t.set_color("font_pressed_color", "Button", Palette.BONE)
	t.set_color("font_disabled_color", "Button", Palette.ASH_DIM)
	t.set_font_size("font_size", "Button", 26)

	t.set_color("font_color", "Label", Palette.BONE_DIM)
	t.set_font_size("font_size", "Label", 24)

	t.set_color("font_color", "CheckButton", Palette.BONE_DIM)
	t.set_color("font_hover_color", "CheckButton", Palette.BONE)
	t.set_font_size("font_size", "CheckButton", 24)

	_cached = t
	return t


static func _box(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb
