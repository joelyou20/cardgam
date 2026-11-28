extends Control

const GOLD := Color("#edbf84")
const INK := Color("#f7e6ce")
const MUTED := Color("#bcb0ba")
const GREEN := Color("#a7ceb0")
const SURFACE := Color("#241f2c")
const BORDER := Color("#655266")

var arena
var content: VBoxContainer
var page := "home"

func _init(game, menu_theme: Theme) -> void:
	arena = game
	theme = menu_theme
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("#17141e")
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content = VBoxContainer.new()
	content.custom_minimum_size.x = 912
	content.add_theme_constant_override("separation", 20)
	center.add_child(content)

func style(fill: Color, edge: Color, corner := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.set_corner_radius_all(corner)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		box.set_content_margin(side, 14)
	return box

func label(text: String, size_px: int, color: Color = INK) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", size_px)
	node.add_theme_color_override("font_color", color)
	return node

func button(text: String, action: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 42
	node.pressed.connect(action)
	return node

func accent(node: Button) -> void:
	node.add_theme_stylebox_override("normal", style(Color("#a77545"), GOLD))
	node.add_theme_stylebox_override("hover", style(Color("#c08c56"), GOLD))
	node.add_theme_color_override("font_color", Color("#161019"))
	node.add_theme_color_override("font_hover_color", Color("#161019"))

func portrait(name: String, extent: Vector2, locked: bool) -> TextureRect:
	var image := TextureRect.new()
	image.texture = arena.HERO_ART.get(name, arena.PLAYER_ART)
	image.custom_minimum_size = extent
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if locked:
		image.self_modulate = Color("#121017")
	elif name == "Warden":
		image.self_modulate = Color("#9fccc8")
	return image

func show_page(destination: String) -> void:
	page = destination
	show()
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	content.add_child(header)
	var brand := label("Cardgam", 26, GOLD)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(brand)
	var home := button("Home", show_page.bind("home"))
	var unlocks := button("Unlocks", show_page.bind("unlocks"))
	header.add_child(home)
	header.add_child(unlocks)
	header.add_child(label("   %d embers" % arena.embers, 16, GOLD))
	if page == "home":
		accent(home)
		build_home()
	elif page == "roster":
		build_roster()
	else:
		accent(unlocks)
		build_unlocks()
	if page != "home":
		content.add_child(button("Back to main menu", show_page.bind("home")))

func build_home() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", style(SURFACE, BORDER))
	content.add_child(panel)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 328
	row.add_theme_constant_override("separation", 30)
	panel.add_child(row)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 14)
	row.add_child(text)
	text.add_child(label("Cardgam", 64, GOLD))
	text.add_child(label("Survive the horde. Build your abilities as you go.", 18, MUTED))
	var play := button("Play", show_page.bind("roster"))
	play.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	play.custom_minimum_size = Vector2(172, 52)
	accent(play)
	text.add_child(play)
	row.add_child(portrait("Vanguard", Vector2(295, 265), false))
	play.grab_focus()

func build_roster() -> void:
	content.add_child(label("Choose a character", 35, GOLD))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	content.add_child(grid)
	for name in arena.ABILITIES:
		var unlocked: bool = arena.is_character_unlocked(name)
		var action: Callable = arena.start_run.bind(name) if unlocked else show_page.bind("unlocks")
		var tile := button("", action)
		tile.custom_minimum_size = Vector2(290, 175)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.tooltip_text = "Start as %s" % name if unlocked else "View the requirement for %s" % name
		tile.add_theme_stylebox_override("normal", style(Color("#292431") if unlocked else Color("#38313f"), BORDER))
		tile.add_theme_stylebox_override("hover", style(Color("#3f3241"), GOLD))
		grid.add_child(tile)
		var body := VBoxContainer.new()
		body.alignment = BoxContainer.ALIGNMENT_CENTER
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(body)
		body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		body.add_child(portrait(name, Vector2(100, 98), not unlocked))
		var title := label(name, 21)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(title)
		var status := label("Play" if unlocked else "Locked · view requirement", 14, GREEN if unlocked else MUTED)
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(status)

func build_unlocks() -> void:
	content.add_child(label("Character unlocks", 35, GOLD))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	content.add_child(list)
	for name in arena.ABILITIES:
		var info: Dictionary = arena.unlock_info(name)
		var unlocked: bool = arena.is_character_unlocked(name)
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", style(SURFACE, BORDER))
		list.add_child(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		panel.add_child(row)
		var title := label(name, 17)
		title.custom_minimum_size.x = 157
		row.add_child(title)
		var requirement := label(info.requirement, 16, MUTED)
		requirement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(requirement)
		if name == "Warden" and not unlocked and arena.embers >= arena.WARDEN_COST:
			row.add_child(button("Unlock · %d embers" % arena.WARDEN_COST, arena.unlock_warden))
		else:
			row.add_child(label("Unlocked" if unlocked else info.progress, 16, GREEN if unlocked else GOLD))
