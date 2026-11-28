extends Node2D

const PLAYER_ART := preload("res://art/vanguard.png")
const ENEMY_ART := preload("res://art/raider.png")
const TERRAIN_ART := preload("res://art/terrain.png")
const TILE_SIZE := Vector2(64, 32)
const FIELD := Rect2(24, 80, 1072, 477)
const BEACON := Vector2(560, 300)
const STARTER := ["Strike", "Sweep", "Dash", "Shove"]
const BOOSTERS := ["Cinder Ring", "Rally", "Harpoon", "Kindle"]
const CARDS := {
	"Strike": ["ATTACK", "Deal 3 to the nearest foe."],
	"Sweep": ["ATTACK", "Deal 2 to each foe close by."],
	"Dash": ["UTILITY", "Dash through foes in your travel direction."],
	"Shove": ["UTILITY", "Push nearby foes away and stagger them."],
	"Aftershock": ["SPECIAL", "Repeat your last attack from here."],
	"Bulwark": ["SPECIAL", "Gain a shield. When hit, shove nearby foes."],
	"Cinder Ring": ["ATTACK", "Leave a burning ring that damages foes inside."],
	"Rally": ["UTILITY", "Heal 2 for each nearby staggered foe, up to 6."],
	"Harpoon": ["ATTACK", "Deal 2 to the nearest foe and pull it close."],
	"Kindle": ["UTILITY", "Your next attack also creates a burning ring."],
}

var phase := "title"
var position_in_arena := BEACON
var facing := Vector2.RIGHT
var player_looks_left := false
var player_is_warden := false
var terrain_tiles: Array[Dictionary] = []
var dash_left := 0.0
var health := 30
var beacon_health := 12
var invulnerable := 0.0
var shield := false
var kindled := false
var cooldown := 0.0
var elapsed := 0.0
var spawn_left := 0.0
var kills := 0
var stage := 1
var route := ""
var embers := 0
var warden_unlocked := false
var last_attack := ""
var hand: Array[String] = []
var draw_pile: Array[String] = []
var enemies: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var fires: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

var hud: Label
var notice: Label
var slots: Array[Button] = []
var overlay: PanelContainer
var options: VBoxContainer

func _ready() -> void:
	rng.randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	build_terrain()
	load_progress()
	build_interface()
	show_title()

func build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var theme := Theme.new()
	theme.default_font_size = 18
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#252531") if state_name == "normal" else Color("#393543")
		style.border_color = Color("#ba9562") if state_name in ["hover", "focus"] else Color("#615164")
		style.set_border_width_all(1)
		style.set_corner_radius_all(6)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		if state_name == "focus":
			style.bg_color = Color.TRANSPARENT
		theme.set_stylebox(state_name, "Button", style)
	theme.set_color("font_color", "Button", Color("#f1dfbe"))
	hud = Label.new()
	hud.position = Vector2(28, 15)
	hud.add_theme_font_size_override("font_size", 23)
	layer.add_child(hud)
	notice = Label.new()
	notice.position = Vector2(28, 48)
	notice.modulate = Color("#bdb3a9")
	layer.add_child(notice)
	var hand_row := HBoxContainer.new()
	hand_row.position = Vector2(24, 575)
	hand_row.add_theme_constant_override("separation", 10)
	hand_row.theme = theme
	layer.add_child(hand_row)
	for index in range(4):
		var button := Button.new()
		button.custom_minimum_size = Vector2(260, 116)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 16)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(play_card.bind(index))
		hand_row.add_child(button)
		slots.append(button)
	overlay = PanelContainer.new()
	overlay.position = Vector2(245, 115)
	overlay.custom_minimum_size.x = 630
	overlay.size = Vector2(630, 0)
	overlay.theme = theme
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#171620")
	panel.border_color = Color("#ba9562")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		panel.set_content_margin(side, 25)
	overlay.add_theme_stylebox_override("panel", panel)
	layer.add_child(overlay)
	options = VBoxContainer.new()
	options.add_theme_constant_override("separation", 12)
	overlay.add_child(options)

func show_menu(title: String, description: String) -> void:
	for child in options.get_children():
		options.remove_child(child)
		child.queue_free()
	overlay.show()
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 36)
	heading.modulate = Color("#edc18a")
	options.add_child(heading)
	var detail := Label.new()
	detail.text = description
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	options.add_child(detail)
	overlay.set_deferred("size", Vector2(630, 0))
	refresh_hand()

func add_option(label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 50
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	options.add_child(button)

func show_title() -> void:
	player_is_warden = false
	phase = "title"
	hand.clear()
	enemies.clear()
	fires.clear()
	effects.clear()
	route = ""
	position_in_arena = BEACON
	hud.text = ""
	notice.text = ""
	show_menu("Cardgam", "Survive the first wave, draft a card, and decide what happens at the crossing.\n\nMove with WASD or arrows. Play a card with 1–4 or click it.\n\nEmbers: %d" % embers)
	add_option("Play as Vanguard · Aftershock", start_run.bind("Aftershock"))
	if warden_unlocked:
		add_option("Play as Warden · Bulwark", start_run.bind("Bulwark"))
	elif embers >= 3:
		add_option("Unlock Warden · 3 embers", unlock_warden)
	else:
		add_option("Warden · unlocks for 3 embers", func(): pass)
		(options.get_child(-1) as Button).disabled = true

func unlock_warden() -> void:
	embers -= 3
	warden_unlocked = true
	save_progress()
	show_title()

func start_run(special: String) -> void:
	player_is_warden = special == "Bulwark"
	hand.assign(STARTER)
	draw_pile.assign([special])
	health = 30
	kills = 0
	stage = 1
	route = ""
	last_attack = ""
	shield = false
	kindled = false
	begin_fight()

func begin_fight() -> void:
	phase = "fight"
	position_in_arena = BEACON + Vector2(0, 85) if route == "bridge" else BEACON
	facing = Vector2.RIGHT
	player_looks_left = false
	enemies.clear()
	fires.clear()
	effects.clear()
	beacon_health = 12
	dash_left = 0.0
	invulnerable = 1.0
	cooldown = 0.0
	elapsed = 0.0
	spawn_left = 0.2
	if route == "road":
		spawn_enemy(true)
	overlay.hide()
	refresh_hand()

func refresh_hand() -> void:
	for index in range(slots.size()):
		var button := slots[index]
		button.visible = not hand.is_empty()
		button.disabled = phase != "fight"
		if index < hand.size():
			var card := hand[index]
			button.text = "%d  ·  %s\n%s\n%s" % [index + 1, CARDS[card][0], card, CARDS[card][1]]
			button.modulate = Color("#ffc87e") if card in BOOSTERS else Color.WHITE

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = [KEY_1, KEY_2, KEY_3, KEY_4].find(event.keycode)
		if index < 0:
			return
		if phase == "fight":
			play_card(index)
			get_viewport().set_input_as_handled()
		elif phase == "booster" and index < 3:
			(options.get_child(index + 2) as Button).pressed.emit()
			get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if phase == "fight":
		update_fight(delta)
	queue_redraw()

func movement_input() -> Vector2:
	var direction := Vector2.ZERO
	direction.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	direction.y = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	return direction.normalized()

func face_direction(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		facing = direction
	if not is_zero_approx(direction.x):
		player_looks_left = direction.x < 0.0

func update_fight(delta: float) -> void:
	elapsed += delta
	cooldown = maxf(0.0, cooldown - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	var direction := movement_input()
	if dash_left > 0.0:
		dash_left -= delta
		position_in_arena += facing * 690.0 * delta
	else:
		face_direction(direction)
		position_in_arena += direction * 226.0 * delta
	position_in_arena = clamp_to_field(position_in_arena)
	spawn_left -= delta
	if spawn_left <= 0.0:
		spawn_enemy()
		spawn_left = maxf(0.28, 0.83 - elapsed * 0.019 - (stage - 1) * 0.12)
	update_fires(delta)
	for enemy in enemies:
		move_enemy(enemy, delta)
	for effect in effects:
		effect.life -= delta
	effects = effects.filter(func(effect): return effect.life > 0)
	remove_defeated()
	update_hud()
	if health <= 0 or beacon_health <= 0:
		finish_run(false)
	elif stage == 1 and elapsed >= 24.0:
		open_booster()
	elif stage == 2 and (route == "bridge" and elapsed >= 23.0 or route == "road" and not enemies.any(func(enemy): return enemy.elite)):
		finish_run(true)

func update_hud() -> void:
	var objective := "Survive %ds" % maxi(0, ceili(24.0 - elapsed))
	if route == "bridge":
		objective = "Protect the beacon · %d/12 · %ds" % [beacon_health, maxi(0, ceili(23.0 - elapsed))]
	elif route == "road":
		objective = "Defeat the road captain"
	hud.text = "HP %d/30     /     Fight %d of 2     /     %s     /     %d defeated" % [health, stage, objective, kills]
	notice.text = "WASD / arrows to move     •     1–4 / click to play     •     %s" % ("Recovering…" if cooldown > 0.0 else "Cards ready")

func clamp_to_field(point: Vector2) -> Vector2:
	return point.clamp(FIELD.position + Vector2(12, 12), FIELD.end - Vector2(12, 12))

func spawn_enemy(elite := false) -> void:
	var edge := rng.randi_range(0, 3)
	var point := Vector2(rng.randf_range(FIELD.position.x, FIELD.end.x), rng.randf_range(FIELD.position.y, FIELD.end.y))
	match edge:
		0: point.x = FIELD.position.x
		1: point.x = FIELD.end.x
		2: point.y = FIELD.position.y
		3: point.y = FIELD.end.y
	if elite:
		point = Vector2(940, 240)
	enemies.append({
		"pos": point,
		"hp": 24 if elite else 3,
		"speed": 115.0 if elite else rng.randf_range(80.0, 137.0),
		"stagger": 0.0,
		"attack": 0.0,
		"elite": elite,
		"looks_left": point.x > position_in_arena.x,
		"raider": route == "bridge" and rng.randf() < 0.52,
	})

func move_enemy(enemy: Dictionary, delta: float) -> void:
	if enemy.hp <= 0:
		return
	enemy.attack -= delta
	if enemy.stagger > 0:
		enemy.stagger -= delta
		return
	var target := BEACON if enemy.raider else position_in_arena
	var offset: Vector2 = target - enemy.pos
	if absf(offset.x) > 1.0:
		enemy.looks_left = offset.x < 0.0
	var contact := 30.0 if enemy.elite else 21.0
	if offset.length() > contact:
		enemy.pos += offset.normalized() * enemy.speed * delta
	if enemy.attack > 0.0:
		return
	var distance: float = enemy.pos.distance_to(position_in_arena)
	if distance <= contact and invulnerable <= 0.0:
		enemy.attack = 0.8
		invulnerable = 0.65
		if shield:
			shield = false
			perform_card("Shove")
		else:
			health = maxi(0, health - (4 if enemy.elite else 2))
			add_effect(position_in_arena, 28, Color("#ef746a"))
	elif enemy.raider and offset.length() <= contact:
		beacon_health = maxi(0, beacon_health - 1)
		enemy.attack = 1.0
		add_effect(BEACON, 29, Color("#ef746a"))

func nearest_enemy() -> Dictionary:
	var nearest := {}
	var distance := INF
	for enemy in enemies:
		var candidate: float = position_in_arena.distance_squared_to(enemy.pos)
		if enemy.hp > 0 and candidate < distance:
			distance = candidate
			nearest = enemy
	return nearest

func play_card(index: int) -> void:
	if phase != "fight" or cooldown > 0.0 or index < 0 or index >= hand.size():
		return
	var card := hand[index]
	if card == "Aftershock" and last_attack.is_empty():
		return
	if card in ["Strike", "Harpoon"] and nearest_enemy().is_empty():
		return
	draw_pile.push_back(card)
	hand[index] = draw_pile.pop_front()
	cooldown = 0.34
	perform_card(card)
	remove_defeated()
	refresh_hand()

func perform_card(card: String) -> void:
	if CARDS[card][0] == "ATTACK":
		last_attack = card
		if kindled:
			kindled = false
			create_fire()
	match card:
		"Strike", "Harpoon":
			var enemy := nearest_enemy()
			if not enemy.is_empty():
				add_effect(enemy.pos, 24, Color("#f8c780"))
				enemy.hp -= 3 if card == "Strike" else 2
				if card == "Harpoon":
					enemy.pos = enemy.pos.move_toward(position_in_arena, 145.0)
					enemy.stagger = 0.55
		"Sweep", "Shove", "Rally":
			var radius := 195.0 if card == "Rally" else 88.0
			add_effect(position_in_arena, radius, Color("#91cbbb") if card == "Rally" else Color("#f8c780"))
			var healed := 0
			for enemy in enemies:
				var offset: Vector2 = enemy.pos - position_in_arena
				if enemy.hp <= 0 or offset.length_squared() > radius * radius:
					continue
				match card:
					"Sweep": enemy.hp -= 2
					"Shove":
						enemy.pos = clamp_to_field(enemy.pos + offset.normalized() * 97.0)
						enemy.stagger = 1.5
					"Rally":
						if enemy.stagger > 0:
							healed += 2
			if card == "Rally":
				health = mini(30, health + mini(6, healed))
		"Dash":
			face_direction(movement_input())
			dash_left = 0.19
			invulnerable = maxf(invulnerable, 0.24)
			add_effect(position_in_arena, 35, Color("#91cbbb"))
		"Aftershock":
			perform_card(last_attack)
		"Bulwark":
			shield = true
		"Kindle":
			kindled = true
		"Cinder Ring":
			create_fire()

func create_fire() -> void:
	fires.append({"pos": position_in_arena, "life": 2.0, "tick": 0.0})

func update_fires(delta: float) -> void:
	for fire in fires:
		fire.life -= delta
		fire.tick -= delta
		if fire.life <= 0 or fire.tick > 0:
			continue
		fire.tick = 0.45
		for enemy in enemies:
			if fire.pos.distance_squared_to(enemy.pos) <= 72.0 * 72.0:
				enemy.hp -= 1
	fires = fires.filter(func(fire): return fire.life > 0)

func remove_defeated() -> void:
	var before := enemies.size()
	enemies = enemies.filter(func(enemy): return enemy.hp > 0)
	kills += before - enemies.size()

func add_effect(point: Vector2, radius: float, color: Color) -> void:
	effects.append({"pos": point, "radius": radius, "color": color, "life": 0.27})

func open_booster() -> void:
	phase = "booster"
	show_menu("Open the cache", "Choose one card to add to your deck.")
	var pack := BOOSTERS.duplicate()
	for index in range(3):
		var card: String = pack.pop_at(rng.randi_range(0, pack.size() - 1))
		add_option("%d   ·   %s   /   %s" % [index + 1, card, CARDS[card][1]], draft_card.bind(card))

func draft_card(card: String) -> void:
	draw_pile.push_front(card)
	phase = "story"
	show_menu("The ferryman’s signal", "The ferryman needs the beacon lit to guide his boat through the fog. Raiders are already on the bank. An old road bypasses the crossing, but its captain bars the way.")
	add_option("Stay at the crossing · defend the beacon", choose_route.bind("bridge"))
	add_option("Take the old road · defeat the captain", choose_route.bind("road"))

func choose_route(choice: String) -> void:
	route = choice
	stage = 2
	health = mini(30, health + 8)
	begin_fight()

func finish_run(won: bool) -> void:
	phase = "results"
	var reward := 1 + int(stage == 2) + int(won)
	embers += reward
	save_progress()
	var outcome := "The boat made it through." if route == "bridge" else "The road is open."
	if not won:
		outcome = "The beacon went dark." if beacon_health <= 0 else "You fell before reaching safety."
	show_menu(outcome, "%d foes defeated. You earned %d embers.\nTotal embers: %d." % [kills, reward, embers])
	add_option("Return to character select", show_title)

func load_progress() -> void:
	var save := ConfigFile.new()
	if save.load("user://progress.cfg") == OK:
		embers = int(save.get_value("progress", "embers", 0))
		warden_unlocked = bool(save.get_value("progress", "warden", false))

func save_progress() -> void:
	var save := ConfigFile.new()
	save.set_value("progress", "embers", embers)
	save.set_value("progress", "warden", warden_unlocked)
	if save.save("user://progress.cfg") != OK:
		push_warning("Could not save run progress.")

func build_terrain() -> void:
	# Offset each half-height row by half a tile to form a 2:1 diamond grid.
	var row_count := ceili(FIELD.size.y / (TILE_SIZE.y / 2.0))
	var column_count := ceili(FIELD.size.x / TILE_SIZE.x)
	for row in range(-1, row_count):
		for column in range(-1, column_count):
			var offset := Vector2(column * TILE_SIZE.x + posmod(row, 2) * TILE_SIZE.x / 2.0, row * TILE_SIZE.y / 2.0)
			var tile := Rect2(FIELD.position + offset, TILE_SIZE)
			var clipped := FIELD.intersection(tile)
			if not clipped.has_area():
				continue
			var pattern := posmod(column * 73 + row * 37 + column * row * 17, 23)
			var variant := 0
			if pattern >= 13:
				variant = 1 + (pattern - 13) % 3
			var source := Rect2(clipped.position - tile.position + Vector2(variant * TILE_SIZE.x, 0), clipped.size)
			terrain_tiles.append({"destination": clipped, "source": source})

func draw_actor(art: Texture2D, feet: Vector2, height: float, looks_left: bool, tint: Color) -> void:
	feet = feet.round()
	var width := roundf(height * art.get_width() / art.get_height())
	var shadow := PackedVector2Array()
	for index in range(16):
		shadow.append(feet + Vector2.from_angle(TAU * index / 16.0) * Vector2(width * 0.31, 4))
	draw_colored_polygon(shadow, Color(0.06, 0.055, 0.075, 0.62))
	draw_set_transform(feet, 0.0, Vector2(-1, 1) if looks_left else Vector2.ONE)
	draw_texture_rect(art, Rect2(-width / 2.0, -height, width, height), false, tint)
	draw_set_transform(Vector2.ZERO)

func draw_player() -> void:
	var tint := Color("#9fccc8") if player_is_warden else Color.WHITE
	draw_actor(PLAYER_ART, position_in_arena, 48.0, player_looks_left, tint)
	if shield or kindled:
		draw_arc(position_in_arena, 21.0, 0, TAU, 24, Color("#91cbbb") if shield else Color("#e78a55"), 2.0)

func draw_enemy(enemy: Dictionary) -> void:
	var height := 57.0 if enemy.elite else 38.0
	var tint := Color("#e2bbf6") if enemy.elite else Color.WHITE
	if enemy.raider:
		tint = Color("#ffbe88")
	if enemy.stagger > 0.0:
		tint = Color("#91a5bd")
	draw_actor(ENEMY_ART, enemy.pos, height, enemy.looks_left, tint)
	if enemy.elite:
		var bar: Vector2 = enemy.pos + Vector2(-22, -height - 7)
		draw_rect(Rect2(bar, Vector2(44, 4)), Color("#432b38"))
		draw_rect(Rect2(bar, Vector2(44.0 * enemy.hp / 24.0, 4)), Color("#f8af88"))

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1120, 720), Color("#111018"))
	draw_rect(FIELD, Color("#2a3035"))
	for tile in terrain_tiles:
		draw_texture_rect_region(TERRAIN_ART, tile.destination, tile.source)
	draw_rect(FIELD, Color("#615164"), false, 2.0)
	if route == "bridge":
		draw_circle(BEACON, 29.0, Color("#ffc778"), false, 2.0)
		draw_circle(BEACON, 12.0, Color("#ffc778"))
	for fire in fires:
		draw_circle(fire.pos, 72.0, Color(0.96, 0.38, 0.19, 0.19))
		draw_circle(fire.pos, 72.0, Color("#dc764d"), false, 2.0)
	var actors := enemies.duplicate()
	actors.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	var player_drawn := false
	for enemy in actors:
		if not player_drawn and enemy.pos.y >= position_in_arena.y:
			draw_player()
			player_drawn = true
		draw_enemy(enemy)
	if not player_drawn:
		draw_player()
	for effect in effects:
		var color: Color = effect.color
		color.a = effect.life / 0.27
		draw_circle(effect.pos, effect.radius * (1.0 - effect.life), color, false, 3.0)
