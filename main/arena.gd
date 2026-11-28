extends Node2D

const FrontMenu := preload("res://front_menu.gd")
const WARDEN_COST := 3
const GIER_KILLS := 30
const XOLA_DRAFTS := 4

const HeroActions := preload("res://hero_actions.gd")
const HERO_ART := {
	"Gier": preload("res://art/gier.png"),
	"Moonrose": preload("res://art/moonrose.png"),
	"Xola Kain": preload("res://art/xola_kain.png"),
	"The Necroblade": preload("res://art/necroblade.png"),
}
const PLAYER_ART := preload("res://art/vanguard.png")
const ENEMY_ART := preload("res://art/raider.png")
const TERRAIN_ART := preload("res://art/terrain.png")
const TILE_SIZE := Vector2(64, 32)
const FIELD := Rect2(24, 80, 1072, 560)
const SCREEN_CENTER := Vector2(560, 360)
const SPAWN_MARGIN := 32.0
const DESPAWN_RADIUS := 1250.0
const BEACON := Vector2(560, 300)
enum Ability { PRIMARY, SECONDARY, MOVEMENT, SPECIAL }

const CONTROLS := ["LMB", "RMB", "SPACE", "R"]
const ABILITIES := {
	"Vanguard": ["Slash", "Sweep", "Dash", "Aftershock"],
	"Warden": ["Mace", "Shield Bash", "Guard Step", "Bulwark"],
	"Gier": ["Hammerfall", "Faultbreaker", "Leap Slam", "Whirlwind"],
	"Moonrose": ["Piercing Arrow", "Arrow Fan", "Vanish", "Arrow Barrage"],
	"Xola Kain": ["Returning Blade", "Double Orbit", "Trap Leap", "Casting Net"],
	"The Necroblade": ["Siphon", "Grave Harvest", "Totem Step", "Detonate"],
}
const COOLDOWNS := {
	"Vanguard": [0.42, 2.0, 2.4, 5.0],
	"Warden": [0.55, 1.7, 2.7, 5.5],
	"Gier": [0.8, 1.9, 2.9, 7.0],
	"Moonrose": [0.48, 2.0, 3.1, 8.0],
	"Xola Kain": [0.85, 2.4, 3.1, 6.0],
	"The Necroblade": [0.63, 2.5, 3.0, 5.0],
}
const AUGMENTS := {
	"Vanguard": {
		"Kindling": "Slash ignites a patch beneath the first enemy it hits.",
		"Undertow": "Sweep pulls enemies toward you, setting up a close-range follow-up.",
		"Scorched Trail": "Dash leaves fire at both ends of its path.",
		"Double Echo": "Aftershock echoes both attacks when you alternate Slash and Sweep.",
	},
	"Warden": {
		"Crack the Line": "Mace hits against staggered enemies send a shockwave into nearby foes.",
		"Rebound": "Enemies knocked back by Shield Bash damage nearby foes where they land.",
		"Landing Bell": "Guard Step staggers nearby enemies when you land.",
		"Beacon Oath": "Bulwark heals you when the shield blocks a hit.",
	},
	"Gier": {
		"Fault Line": "Hammerfall erupts across a wider area.",
		"Ringing Blow": "Faultbreaker stuns enemies along the line.",
		"Afterquake": "Leap Slam leaves a delayed second eruption.",
		"Wide Swing": "Whirlwind reaches enemies farther from you.",
	},
	"Moonrose": {
		"Silver Fan": "Arrow Fan fires seven arrows instead of five.",
		"Moonstep": "Vanish leaves a decoy that bursts and staggers enemies.",
		"Pinning Rain": "Arrow Barrage briefly staggers on each hit.",
	},
	"Xola Kain": {
		"Hooked Return": "Returning Blade hits harder on the way back.",
		"Wide Orbit": "Double Orbit circles at a larger radius.",
		"Barbed Spring": "Trap Leap's trap damages enemies as well as stunning them.",
		"Tight Weave": "Casting Net pulls enemies farther toward its center.",
	},
	"The Necroblade": {
		"Blood Tithe": "Siphon heals twice as much from enemies hit.",
		"Frenzied Bones": "Skeletons strike more often.",
		"Bone Idol": "Totems withstand more enemy hits.",
		"Grave Powder": "Detonated summons damage a larger area.",
	},
}

var hero := HeroActions.new(self)
var next_enemy_id := 0

var phase := "title"
var position_in_arena := BEACON
var facing := Vector2.RIGHT
var player_looks_left := false
var player_is_warden := false
var dash_left := 0.0
var health := 30
var beacon_health := 12
var invulnerable := 0.0
var shield := false
var cooldowns := [0.0, 0.0, 0.0, 0.0]
var elapsed := 0.0
var spawn_left := 0.0
var kills := 0
var stage := 1
var route := ""
var embers := 0
var warden_unlocked := false
var total_kills := 0
var total_drafts := 0
var crossing_won := false
var captain_defeated := false
var run_unlocks: Array[String] = []
var character := "Vanguard"
var last_attack := -1
var previous_attack := -1
var deck: Array[String] = []
var enemies: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var fires: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

var front_menu: Control
var hud: Label
var notice: Label
var overlay: PanelContainer
var options: VBoxContainer

func _ready() -> void:
	rng.randomize()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	front_menu = FrontMenu.new(self, theme)
	layer.add_child(front_menu)

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

func add_option(label: String, action: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size.y = 50
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(action)
	options.add_child(button)

func show_title() -> void:
	open_front_page("home")

func open_front_page(page: String) -> void:
	player_is_warden = false
	character = "Vanguard"
	hero = HeroActions.new(self)
	phase = "title"
	deck.clear()
	enemies.clear()
	fires.clear()
	effects.clear()
	route = ""
	position_in_arena = BEACON
	hud.text = ""
	notice.text = ""
	overlay.hide()
	front_menu.show_page(page)

func is_character_unlocked(name: String) -> bool:
	match name:
		"Vanguard": return true
		"Warden": return warden_unlocked
		"Gier": return total_kills >= GIER_KILLS
		"Moonrose": return crossing_won
		"Xola Kain": return total_drafts >= XOLA_DRAFTS
		"The Necroblade": return captain_defeated
	return false

func unlock_info(name: String) -> Dictionary:
	match name:
		"Warden":
			return {"requirement": "Spend %d embers." % WARDEN_COST, "progress": "%d / %d embers" % [mini(embers, WARDEN_COST), WARDEN_COST]}
		"Gier":
			return {"requirement": "Defeat %d enemies across finished runs." % GIER_KILLS, "progress": "%d / %d enemies" % [mini(total_kills, GIER_KILLS), GIER_KILLS]}
		"Moonrose":
			return {"requirement": "Win the crossing fight with the beacon intact.", "progress": "Crossing pending"}
		"Xola Kain":
			return {"requirement": "Draft %d augment cards across runs." % XOLA_DRAFTS, "progress": "%d / %d augments" % [mini(total_drafts, XOLA_DRAFTS), XOLA_DRAFTS]}
		"The Necroblade":
			return {"requirement": "Defeat the road captain on the old road.", "progress": "Captain pending"}
	return {"requirement": "Available from the start.", "progress": ""}

func unlock_warden() -> void:
	if warden_unlocked or embers < WARDEN_COST:
		return
	embers -= WARDEN_COST
	warden_unlocked = true
	save_progress()
	front_menu.show_page("unlocks")

func start_run(chosen_character: String) -> void:
	if phase != "title" or not is_character_unlocked(chosen_character):
		return
	front_menu.hide()
	character = chosen_character
	player_is_warden = character == "Warden"
	deck.clear()
	run_unlocks.clear()
	health = 30
	kills = 0
	stage = 1
	route = ""
	begin_fight()

func begin_fight() -> void:
	hero = HeroActions.new(self)
	next_enemy_id = 0
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
	cooldowns.fill(0.0)
	last_attack = -1
	previous_attack = -1
	shield = false
	elapsed = 0.0
	spawn_left = 0.2
	if route == "road":
		spawn_enemy(true)
	overlay.hide()

func _unhandled_input(event: InputEvent) -> void:
	var ability := -1
	var target := get_global_mouse_position()
	if event is InputEventMouseButton and event.pressed and phase == "fight":
		target = event.position
		if event.button_index == MOUSE_BUTTON_LEFT:
			ability = Ability.PRIMARY
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			ability = Ability.SECONDARY
	elif event is InputEventKey and event.pressed and not event.echo:
		if phase == "booster":
			var option: int = [KEY_1, KEY_2, KEY_3].find(event.keycode)
			if option >= 0 and option + 2 < options.get_child_count():
				(options.get_child(option + 2) as Button).pressed.emit()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_SPACE:
			ability = Ability.MOVEMENT
		elif event.keycode == KEY_R:
			ability = Ability.SPECIAL
	if ability >= 0 and phase == "fight":
		var aim := (target - SCREEN_CENTER).normalized()
		use_ability(ability, aim if aim != Vector2.ZERO else facing, position_in_arena + target - SCREEN_CENTER)
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
	for index in range(cooldowns.size()):
		cooldowns[index] = maxf(0.0, cooldowns[index] - delta)
	invulnerable = maxf(0.0, invulnerable - delta)
	var direction := movement_input()
	var leaping := hero.update_leap(delta)
	if not leaping and dash_left > 0.0:
		var step := minf(delta, dash_left)
		dash_left -= step
		position_in_arena += facing * 690.0 * step
		if dash_left <= 0.0:
			if "Scorched Trail" in deck:
				create_fire(position_in_arena)
			if "Landing Bell" in deck:
				strike(position_in_arena, facing, 75.0, -1.0, 0, 0.0, 1.3)
	elif not leaping:
		face_direction(direction)
		position_in_arena += direction * (310.0 if hero.spin > 0.0 else 226.0) * delta
	spawn_left -= delta
	if spawn_left <= 0.0:
		spawn_enemy()
		spawn_left = maxf(0.28, 0.83 - elapsed * 0.019 - (stage - 1) * 0.12)
	hero.update(delta)
	update_fires(delta)
	for enemy in enemies:
		move_enemy(enemy, delta)
	enemies = enemies.filter(enemy_is_relevant)
	for effect in effects:
		effect.life -= delta
	effects = effects.filter(func(effect): return effect.life > 0)
	remove_defeated()
	update_hud()
	if health <= 0 or beacon_health <= 0:
		finish_run(false)
	elif stage == 1 and (elapsed >= 24.0 or elapsed >= 12.0 and deck.is_empty()):
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
	var status := PackedStringArray()
	for index in range(CONTROLS.size()):
		var recovery: float = cooldowns[index]
		var suffix := " %.1fs" % recovery if recovery > 0 else ""
		status.append("%s  %s%s" % [CONTROLS[index], ABILITIES[character][index], suffix])
	notice.text = "     ·     ".join(status)

func enemy_is_relevant(enemy: Dictionary) -> bool:
	if enemy.hp <= 0 or enemy.elite:
		return true
	var anchor := BEACON if enemy.raider else position_in_arena
	return anchor.distance_squared_to(enemy.pos) <= DESPAWN_RADIUS * DESPAWN_RADIUS

func spawn_enemy(elite := false) -> void:
	var raider := route == "bridge" and rng.randf() < 0.52
	var anchor := BEACON if raider else position_in_arena
	var spawn_area := FIELD.grow(SPAWN_MARGIN)
	var point := Vector2(rng.randf_range(spawn_area.position.x, spawn_area.end.x), rng.randf_range(spawn_area.position.y, spawn_area.end.y))
	match rng.randi_range(0, 3):
		0: point.x = spawn_area.position.x
		1: point.x = spawn_area.end.x
		2: point.y = spawn_area.position.y
		3: point.y = spawn_area.end.y
	if elite:
		point = Vector2(940, 240)
	else:
		point += anchor - SCREEN_CENTER
	next_enemy_id += 1
	enemies.append({
		"id": next_enemy_id,
		"pos": point,
		"hp": 24 if elite else 3,
		"speed": 115.0 if elite else rng.randf_range(80.0, 137.0),
		"stagger": 0.0,
		"attack": 0.0,
		"elite": elite,
		"looks_left": point.x > position_in_arena.x,
		"raider": raider,
	})

func move_enemy(enemy: Dictionary, delta: float) -> void:
	if enemy.hp <= 0:
		return
	enemy.attack -= delta
	if enemy.stagger > 0:
		enemy.stagger -= delta
		return
	var ally := hero.lure(enemy.pos)
	var target := BEACON if enemy.raider else position_in_arena
	if not ally.is_empty():
		target = ally.pos
	elif not enemy.raider and hero.hidden > 0.0:
		target = enemy.pos
	var offset: Vector2 = target - enemy.pos
	if absf(offset.x) > 1.0:
		enemy.looks_left = offset.x < 0.0
	var contact := 30.0 if enemy.elite else 21.0
	if offset.length() > contact:
		enemy.pos += offset.normalized() * enemy.speed * delta
	if enemy.attack > 0.0:
		return
	var distance: float = enemy.pos.distance_to(position_in_arena)
	if not ally.is_empty() and offset.length() <= contact:
		ally.hp -= 1
		enemy.attack = 0.62
	elif distance <= contact and invulnerable <= 0.0:
		enemy.attack = 0.8
		invulnerable = 0.65
		if shield:
			shield = false
			strike(position_in_arena, facing, 95.0, -1.0, 2, 85.0, 0.9)
			if "Beacon Oath" in deck:
				health = mini(30, health + 4)
		else:
			health = maxi(0, health - (4 if enemy.elite else 2))
			hero.hidden = 0.0
			add_effect(position_in_arena, 28, Color("#ef746a"))
	elif enemy.raider and ally.is_empty() and offset.length() <= contact:
		beacon_health = maxi(0, beacon_health - 1)
		enemy.attack = 1.0
		add_effect(BEACON, 29, Color("#ef746a"))

func use_ability(ability: int, aim: Vector2, target := Vector2.INF) -> void:
	if phase != "fight" or cooldowns[ability] > 0.0:
		return
	if ability == Ability.SPECIAL and character == "Vanguard" and last_attack == -1:
		return
	# Movement keeps its original direction even if you attack during the dash.
	if dash_left <= 0.0:
		face_direction(aim)
	cooldowns[ability] = COOLDOWNS[character][ability]
	if HERO_ART.has(character):
		hero.cast(ability, aim, target if target.is_finite() else position_in_arena + aim * 240.0)
		remove_defeated()
		update_hud()
		return
	match ability:
		Ability.PRIMARY, Ability.SECONDARY:
			perform_attack(ability, aim)
			previous_attack = last_attack
			last_attack = ability
		Ability.MOVEMENT:
			var direction := movement_input()
			face_direction(direction if direction != Vector2.ZERO else aim)
			dash_left = 0.15 if player_is_warden else 0.22
			invulnerable = maxf(invulnerable, dash_left + (0.2 if player_is_warden else 0.05))
			add_effect(position_in_arena, 32, Color("#91cbbb"))
			if "Scorched Trail" in deck:
				create_fire(position_in_arena)
		Ability.SPECIAL:
			if player_is_warden:
				shield = true
				add_effect(position_in_arena, 38, Color("#91cbbb"))
			else:
				perform_attack(last_attack, aim)
				if "Double Echo" in deck and previous_attack >= 0 and previous_attack != last_attack:
					perform_attack(previous_attack, aim)
	remove_defeated()
	update_hud()

func perform_attack(ability: int, aim: Vector2) -> void:
	if player_is_warden:
		if ability == Ability.PRIMARY:
			var targets := strike(position_in_arena, aim, 78.0, 0.15, 3)
			if "Crack the Line" in deck:
				for enemy in targets:
					if enemy.stagger > 0.0:
						strike(enemy.pos, aim, 55.0, -1.0, 2, 0.0, 0.0, enemy)
		else:
			var targets := strike(position_in_arena, aim, 95.0, 0.3, 1, 72.0, 1.6)
			if "Rebound" in deck:
				for enemy in targets:
					strike(enemy.pos, aim, 46.0, -1.0, 2, 0.0, 0.0, enemy)
	elif ability == Ability.PRIMARY:
		var targets := strike(position_in_arena, aim, 104.0, 0.48, 3)
		if "Kindling" in deck and not targets.is_empty():
			create_fire(targets[0].pos)
	else:
		var shove := -65.0 if "Undertow" in deck else 30.0
		strike(position_in_arena, aim, 120.0, -1.0, 2, shove, 0.55)

func strike(origin: Vector2, aim: Vector2, reach: float, arc: float, damage: int, knockback := 0.0, stagger := 0.0, excluded := {}) -> Array[Dictionary]:
	var hits: Array[Dictionary] = []
	for enemy in enemies:
		var offset: Vector2 = enemy.pos - origin
		if enemy.hp <= 0 or is_same(enemy, excluded) or offset.length_squared() > reach * reach:
			continue
		if offset != Vector2.ZERO and offset.normalized().dot(aim) < arc:
			continue
		enemy.hp -= damage
		enemy.stagger = maxf(enemy.stagger, stagger)
		var displacement := knockback
		if knockback < 0.0:
			displacement = -minf(-knockback, maxf(0.0, offset.length() - 20.0))
		enemy.pos += offset.normalized() * displacement
		hits.append(enemy)
	add_effect(origin, reach, Color("#f8c780") if damage > 0 else Color("#91cbbb"), aim if arc > -1.0 else Vector2.ZERO, arc)
	return hits

func create_fire(point: Vector2) -> void:
	fires.append({"pos": point, "life": 1.55, "tick": 0.0})

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

func add_effect(point: Vector2, radius: float, color: Color, aim := Vector2.ZERO, arc := -1.0) -> void:
	effects.append({"pos": point, "radius": radius, "color": color, "life": 0.27, "aim": aim, "arc": arc})

func open_booster() -> void:
	phase = "booster"
	var current := "Your deck: " + ", ".join(deck) if not deck.is_empty() else "Your deck has no augments yet."
	show_menu(character + " booster", "Choose one passive augment. It applies as soon as you return to combat.\n" + current)
	var pool: Dictionary = AUGMENTS[character]
	var pack := pool.keys().filter(func(card): return card not in deck)
	for index in range(mini(3, pack.size())):
		var card: String = pack.pop_at(rng.randi_range(0, pack.size() - 1))
		add_option("%d   ·   %s   /   %s" % [index + 1, card, pool[card]], draft_card.bind(card))

func draft_card(card: String) -> void:
	if phase != "booster" or not AUGMENTS[character].has(card) or card in deck:
		return
	deck.append(card)
	total_drafts += 1
	if total_drafts == XOLA_DRAFTS:
		run_unlocks.append("Xola Kain")
	save_progress()
	if elapsed < 24.0:
		phase = "fight"
		overlay.hide()
		return
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
	if phase != "fight":
		return
	phase = "results"
	var reward := 1 + int(stage == 2) + int(won)
	embers += reward
	if total_kills < GIER_KILLS and total_kills + kills >= GIER_KILLS:
		run_unlocks.append("Gier")
	total_kills += kills
	if won and route == "bridge" and not crossing_won:
		crossing_won = true
		run_unlocks.append("Moonrose")
	if won and route == "road" and not captain_defeated:
		captain_defeated = true
		run_unlocks.append("The Necroblade")
	save_progress()
	var outcome := "The boat made it through." if route == "bridge" else "The road is open."
	if not won:
		outcome = "The beacon went dark." if beacon_health <= 0 else "You fell before reaching safety."
	var summary := "%d foes defeated. You earned %d embers.\nTotal embers: %d." % [kills, reward, embers]
	if not run_unlocks.is_empty():
		summary += "\n\nUnlocked: " + ", ".join(run_unlocks)
	show_menu(outcome, summary)
	add_option("Return to character select", open_front_page.bind("roster"))
	add_option("Main menu", show_title)

func load_progress() -> void:
	var save := ConfigFile.new()
	if save.load("user://progress.cfg") == OK:
		embers = int(save.get_value("progress", "embers", 0))
		warden_unlocked = bool(save.get_value("progress", "warden", false))
		total_kills = int(save.get_value("progress", "total_kills", 0))
		total_drafts = int(save.get_value("progress", "total_drafts", 0))
		crossing_won = bool(save.get_value("progress", "crossing_won", false))
		captain_defeated = bool(save.get_value("progress", "captain_defeated", false))

func save_progress() -> void:
	var save := ConfigFile.new()
	save.set_value("progress", "embers", embers)
	save.set_value("progress", "warden", warden_unlocked)
	save.set_value("progress", "total_kills", total_kills)
	save.set_value("progress", "total_drafts", total_drafts)
	save.set_value("progress", "crossing_won", crossing_won)
	save.set_value("progress", "captain_defeated", captain_defeated)
	if save.save("user://progress.cfg") != OK:
		push_warning("Could not save run progress.")

func camera_offset() -> Vector2:
	return (position_in_arena - SCREEN_CENTER).round()

func draw_terrain(offset: Vector2) -> void:
	var visible_world := Rect2(FIELD.position + offset, FIELD.size)
	var row_step := TILE_SIZE.y / 2.0
	var first_row := floori(visible_world.position.y / row_step) - 1
	var last_row := ceili(visible_world.end.y / row_step)
	for row in range(first_row, last_row):
		var stagger := posmod(row, 2) * TILE_SIZE.x / 2.0
		var first_col := floori((visible_world.position.x - stagger) / TILE_SIZE.x)
		var last_col := ceili((visible_world.end.x - stagger) / TILE_SIZE.x)
		for column in range(first_col, last_col):
			var tile := Rect2(Vector2(column * TILE_SIZE.x + stagger, row * row_step), TILE_SIZE)
			var clipped := visible_world.intersection(tile)
			if not clipped.has_area():
				continue
			var pattern := posmod(column * 73 + row * 37 + column * row * 17, 23)
			var variant := 0 if pattern < 13 else 1 + (pattern - 13) % 3
			var source := Rect2(clipped.position - tile.position + Vector2(variant * TILE_SIZE.x, 0), clipped.size)
			draw_texture_rect_region(TERRAIN_ART, Rect2(clipped.position - offset, clipped.size), source)

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

func draw_player(feet: Vector2) -> void:
	var tint := Color("#9fccc8") if player_is_warden else Color.WHITE
	if hero.hidden > 0.0:
		tint.a = 0.26
	var art: Texture2D = HERO_ART.get(character, PLAYER_ART)
	var looks_left := player_looks_left
	if hero.spin > 0.0:
		looks_left = fmod(hero.spin * 11.0, 2.0) > 1.0
		var angle := hero.spin * -14.0
		draw_arc(feet, 56.0, angle, angle + PI * 1.45, 32, Color("#ef9f57"), 4.0, true)
	draw_actor(art, feet - Vector2(0, hero.lift), 48.0, looks_left, tint)
	if shield:
		draw_arc(feet, 21.0, 0, TAU, 24, Color("#91cbbb"), 2.0)

func draw_enemy(enemy: Dictionary, feet: Vector2) -> void:
	var height := 57.0 if enemy.elite else 38.0
	var tint := Color("#e2bbf6") if enemy.elite else Color.WHITE
	if enemy.raider:
		tint = Color("#ffbe88")
	if enemy.stagger > 0.0:
		tint = Color("#91a5bd")
	draw_actor(ENEMY_ART, feet, height, enemy.looks_left, tint)
	if enemy.elite:
		var bar := feet + Vector2(-22, -height - 7)
		draw_rect(Rect2(bar, Vector2(44, 4)), Color("#432b38"))
		draw_rect(Rect2(bar, Vector2(44.0 * enemy.hp / 24.0, 4)), Color("#f8af88"))

func draw_objective_marker(world_target: Vector2, offset: Vector2, label: String) -> void:
	var target := world_target - offset
	var inset := FIELD.grow(-55.0)
	if inset.has_point(target):
		return
	var direction := (target - SCREEN_CENTER).normalized()
	var half_size := inset.size / 2.0
	var reach := minf(half_size.x / maxf(absf(direction.x), 0.001), half_size.y / maxf(absf(direction.y), 0.001))
	var marker := SCREEN_CENTER + direction * reach
	var side := direction.orthogonal() * 6.0
	draw_colored_polygon(PackedVector2Array([marker + direction * 9.0, marker - direction * 4.0 + side, marker - direction * 4.0 - side]), Color("#ffc778"))
	draw_string(ThemeDB.fallback_font, marker + Vector2(-46, 23), label, HORIZONTAL_ALIGNMENT_CENTER, 92, 14, Color("#ffe2b0"))

func _draw() -> void:
	var offset := camera_offset()
	draw_rect(Rect2(0, 0, 1120, 720), Color("#111018"))
	draw_rect(FIELD, Color("#2a3035"))
	draw_terrain(offset)
	if route == "bridge":
		draw_circle(BEACON - offset, 29.0, Color("#ffc778"), false, 2.0)
		draw_circle(BEACON - offset, 12.0, Color("#ffc778"))
	for fire in fires:
		draw_circle(fire.pos - offset, 72.0, Color(0.96, 0.38, 0.19, 0.19))
		draw_circle(fire.pos - offset, 72.0, Color("#dc764d"), false, 2.0)
	hero.draw_world(offset)
	var actors := enemies.duplicate()
	actors.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	var player_drawn := false
	for enemy in actors:
		var feet: Vector2 = enemy.pos - offset
		if not FIELD.grow(65.0).has_point(feet):
			continue
		if not player_drawn and enemy.pos.y >= position_in_arena.y:
			draw_player(SCREEN_CENTER)
			player_drawn = true
		draw_enemy(enemy, feet)
	if not player_drawn:
		draw_player(SCREEN_CENTER)
	for effect in effects:
		var color: Color = effect.color
		color.a = effect.life / 0.27
		var half_arc: float = PI if effect.aim == Vector2.ZERO else acos(effect.arc)
		var angle: float = effect.aim.angle()
		draw_arc(effect.pos - offset, effect.radius * (1.0 - effect.life), angle - half_arc, angle + half_arc, 32, color, 3.0)
	# Keep world effects out of the HUD margins.
	draw_rect(Rect2(0, 0, 1120, FIELD.position.y), Color("#111018"))
	draw_rect(Rect2(0, FIELD.end.y, 1120, 720 - FIELD.end.y), Color("#111018"))
	draw_rect(Rect2(0, FIELD.position.y, FIELD.position.x, FIELD.size.y), Color("#111018"))
	draw_rect(Rect2(FIELD.end.x, FIELD.position.y, 1120 - FIELD.end.x, FIELD.size.y), Color("#111018"))
	draw_rect(FIELD, Color("#615164"), false, 2.0)
	if route == "bridge":
		draw_objective_marker(BEACON, offset, "Beacon")
	elif route == "road":
		for enemy in enemies:
			if enemy.elite:
				draw_objective_marker(enemy.pos, offset, "Captain")
				break
