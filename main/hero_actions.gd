extends RefCounted

const GIER := "Gier"
const MOONROSE := "Moonrose"
const XOLA := "Xola Kain"
const NECRO := "The Necroblade"
const GOLD := Color("#ef9f57")
const LILAC := Color("#d3adff")
const TEAL := Color("#79e0d3")
const GREEN := Color("#9ac989")

var arena
var zones: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var summons: Array[Dictionary] = []
var leap: Dictionary = {}
var lift := 0.0
var hidden := 0.0
var spin := 0.0
var spin_tick := 0.0

func _init(game) -> void:
	arena = game

func has_card(card: String) -> bool:
	return card in arena.deck

func cast(slot: int, aim: Vector2, target: Vector2) -> void:
	var origin: Vector2 = arena.position_in_arena
	var moving: Vector2 = arena.movement_input()
	if moving == Vector2.ZERO:
		moving = aim
	var cursor := target
	match arena.character:
		GIER:
			match slot:
				0:
					var impact := origin + aim * 69.0
					arena.strike(impact, aim, 57.0, -1.0, 1)
					zone("eruption", impact, 75.0 if has_card("Fault Line") else 60.0, 0.5, 0.5)
				1:
					line_hit(origin, origin + aim * 240.0, 24.0, 3, 0.0, 0.9 if has_card("Ringing Blow") else 0.0, [], GOLD)
				2:
					jump(origin, moving, 140.0, true)
				3:
					spin = 3.0
					spin_tick = 0.0
		MOONROSE:
			if slot != 2:
				hidden = 0.0
			match slot:
				0:
					arrow(origin, aim, 390.0, 3, 0.0)
				1:
					var count := 7 if has_card("Silver Fan") else 5
					var hits: Array = []
					for index in range(count):
						var direction := aim.rotated(lerpf(-0.62, 0.62, float(index) / (count - 1)))
						arrow(origin, direction, 237.0, 2, 72.0, hits)
				2:
					arena.add_effect(origin, 36.0, LILAC)
					arena.position_in_arena += moving * 115.0
					hidden = 2.0
					if has_card("Moonstep"):
						zone("decoy", origin, 65.0, 0.42, 0.42)
				3:
					zone("barrage", cursor, 120.0, 5.0, 0.0)
		XOLA:
			match slot:
				0, 1:
					shots.append({"kind": "return" if slot == 0 else "orbit", "origin": origin, "pos": origin, "dir": aim, "age": 0.0, "hits": [], "leg": 0})
				2:
					jump(origin, moving, 114.0, false)
					zone("trap", origin, 65.0, 6.0, 0.0)
				3:
					var radius := 162.0
					for enemy in arena.enemies:
						if enemy.hp > 0 and cursor.distance_to(enemy.pos) <= radius:
							enemy.pos = enemy.pos.move_toward(cursor, 95.0 if has_card("Tight Weave") else 58.0)
							enemy.stagger = maxf(enemy.stagger, 1.2)
					arena.add_effect(cursor, radius, TEAL)
		NECRO:
			match slot:
				0:
					var hits: Array = arena.strike(origin, aim, 93.0, 0.45, 2)
					var heal := mini(hits.size(), 3) * (2 if has_card("Blood Tithe") else 1)
					arena.health = mini(30, arena.health + heal)
				1:
					for enemy in arena.strike(cursor, aim, 87.0, -1.0, 6):
						if enemy.hp <= 0:
							summon("skeleton", enemy.pos, 5.0, 3)
				2:
					summon("totem", origin, 7.0, 6 if has_card("Bone Idol") else 4)
					arena.position_in_arena += moving * 110.0
					arena.add_effect(arena.position_in_arena, 42.0, GREEN)
				3:
					for ally in summons:
						if ally.hp > 0 and ally.life > 0.0:
							var radius := 108.0 if has_card("Grave Powder") else 85.0
							arena.strike(ally.pos, aim, radius, -1.0, 5)
					summons.clear()

func jump(origin: Vector2, direction: Vector2, distance: float, slam: bool) -> void:
	leap = {"from": origin, "to": origin + direction * distance, "age": 0.0, "slam": slam}
	arena.invulnerable = maxf(arena.invulnerable, 0.38)

func zone(kind: String, point: Vector2, radius: float, duration: float, delay: float) -> void:
	zones.append({"kind": kind, "pos": point, "radius": radius, "life": duration, "tick": delay})

func summon(kind: String, point: Vector2, duration: float, hp: int) -> void:
	summons.append({"kind": kind, "pos": point, "life": duration, "hp": hp, "tick": 0.0})

func arrow(origin: Vector2, direction: Vector2, reach: float, damage: int, push: float, hits: Array = []) -> void:
	shots.append({"kind": "arrow", "pos": origin, "dir": direction, "left": reach, "damage": damage, "push": push, "hits": hits})

func line_hit(start: Vector2, end: Vector2, width: float, damage: int, push: float, stun: float, hits: Array, color: Color) -> void:
	for enemy in arena.enemies:
		if enemy.hp <= 0 or hits.has(enemy.id):
			continue
		var nearest := Geometry2D.get_closest_point_to_segment(enemy.pos, start, end)
		if nearest.distance_squared_to(enemy.pos) > width * width:
			continue
		hits.append(enemy.id)
		enemy.hp -= damage
		enemy.stagger = maxf(enemy.stagger, stun)
		enemy.pos += (end - start).normalized() * push
	if color.a > 0.0:
		arena.add_effect(start, width, color)
		arena.add_effect(end, width, color)
		zone("line", start, width, 0.22, 1.0)
		zones.back()["end"] = end

func update_leap(delta: float) -> bool:
	if leap.is_empty():
		return false
	leap.age = minf(0.36, leap.age + delta)
	var progress: float = leap.age / 0.36
	arena.position_in_arena = leap.from.lerp(leap.to, progress)
	lift = sin(progress * PI) * 48.0
	if progress >= 1.0:
		if leap.slam:
			arena.strike(arena.position_in_arena, Vector2.RIGHT, 115.0, -1.0, 3, 54.0, 0.65)
			if has_card("Afterquake"):
				zone("eruption", arena.position_in_arena, 100.0, 0.5, 0.5)
		leap.clear()
		lift = 0.0
	return true

func update(delta: float) -> void:
	hidden = maxf(0.0, hidden - delta)
	if spin > 0.0:
		var spin_step := minf(spin, delta)
		spin -= spin_step
		spin_tick -= spin_step
		while spin_tick <= 0.0:
			spin_tick += 0.34
			arena.strike(arena.position_in_arena, Vector2.RIGHT, 108.0 if has_card("Wide Swing") else 84.0, -1.0, 2, 12.0)
	update_zones(delta)
	update_shots(delta)
	update_summons(delta)

func update_zones(delta: float) -> void:
	for item in zones:
		var step := minf(item.life, delta)
		item.life -= step
		item.tick -= step
		match item.kind:
			"eruption", "decoy":
				if item.tick <= 0.0:
					arena.strike(item.pos, Vector2.RIGHT, item.radius, -1.0, 4 if item.kind == "eruption" else 0, 25.0, 0.6)
			"barrage":
				while item.tick <= 0.0:
					item.tick += 0.5
					arena.strike(item.pos, Vector2.RIGHT, item.radius, -1.0, 2, 0.0, 0.22 if has_card("Pinning Rain") else 0.0)
			"trap":
				for enemy in arena.enemies:
					if enemy.hp <= 0 or item.pos.distance_to(enemy.pos) > item.radius:
						continue
					var damage := 2 if has_card("Barbed Spring") else 0
					arena.strike(item.pos, Vector2.RIGHT, item.radius, -1.0, damage, 0.0, 1.9)
					item.life = 0.0
					break
	zones = zones.filter(func(item): return item.life > 0.0)

func update_shots(delta: float) -> void:
	for shot in shots:
		var old: Vector2 = shot.pos
		match shot.kind:
			"arrow":
				var step := minf(shot.left, delta * 760.0)
				shot.left -= step
				shot.pos += shot.dir * step
				line_hit(old, shot.pos, 14.0, shot.damage, shot.push, 0.25 if shot.push > 0 else 0.0, shot.hits, Color.TRANSPARENT)
				shot.done = shot.left <= 0.0
			"return", "orbit":
				update_boomerang(shot, delta)
	shots = shots.filter(func(shot): return not shot.done)

func update_boomerang(shot: Dictionary, delta: float) -> void:
	var old: Vector2 = shot.pos
	shot.age += delta
	var outbound := 0.42 if shot.kind == "return" else 0.16
	var orbit_end := 1.65
	var next: Vector2
	var leg := 0
	if shot.kind == "return" and shot.age <= outbound:
		next = shot.origin + shot.dir * (shot.age / outbound) * 186.0
	elif shot.kind == "orbit" and shot.age < orbit_end:
		var progress := clampf((shot.age - outbound) / (orbit_end - outbound), 0.0, 1.0)
		var radius := 95.0 if has_card("Wide Orbit") else 72.0
		next = arena.position_in_arena + shot.dir.rotated(progress * TAU * 2.0) * radius * minf(1.0, shot.age / outbound)
		leg = floori(progress * 2.0)
	else:
		next = old.move_toward(arena.position_in_arena, 620.0 * delta)
		leg = 2
	if leg != shot.leg:
		shot.hits.clear()
		shot.leg = leg
	shot.pos = next
	var damage := 3 if leg == 2 and shot.kind == "return" and has_card("Hooked Return") else 2
	line_hit(old, next, 20.0, damage, 0.0, 0.0, shot.hits, Color.TRANSPARENT)
	shot.done = (leg == 2 and next.distance_to(arena.position_in_arena) < 12.0) or shot.age > 5.0

func update_summons(delta: float) -> void:
	for ally in summons:
		ally.life -= delta
		if ally.kind != "skeleton" or ally.hp <= 0 or ally.life <= 0.0:
			continue
		ally.tick -= delta
		var target := closest_enemy(ally.pos)
		if target.is_empty():
			continue
		if ally.pos.distance_to(target.pos) > 25.0:
			ally.pos = ally.pos.move_toward(target.pos, 215.0 * delta)
		elif ally.tick <= 0.0:
			ally.tick = 0.48 if has_card("Frenzied Bones") else 0.7
			target.hp -= 2
			arena.add_effect(target.pos, 24.0, GREEN)
	summons = summons.filter(func(ally): return ally.hp > 0 and ally.life > 0.0)

func closest_enemy(point: Vector2) -> Dictionary:
	var best := {}
	var distance := INF
	for enemy in arena.enemies:
		var candidate: float = point.distance_squared_to(enemy.pos)
		if enemy.hp > 0 and candidate < distance:
			best = enemy
			distance = candidate
	return best

func lure(point: Vector2) -> Dictionary:
	var best := {}
	var distance := INF
	for ally in summons:
		var candidate: float = point.distance_squared_to(ally.pos)
		var radius := 235.0 if ally.kind == "totem" else 38.0
		if ally.hp > 0 and ally.life > 0.0 and candidate < minf(distance, radius * radius):
			best = ally
			distance = candidate
	return best

func draw_world(offset: Vector2) -> void:
	for item in zones:
		var point: Vector2 = item.pos - offset
		match item.kind:
			"line":
				arena.draw_line(point, item.end - offset, Color(GOLD, item.life / 0.22), 7.0, true)
			"eruption", "decoy", "trap", "barrage":
				var color := GOLD if item.kind == "eruption" else (TEAL if item.kind == "trap" else LILAC)
				arena.draw_circle(point, item.radius, Color(color, 0.12))
				arena.draw_circle(point, item.radius, Color(color, 0.72), false, 2.0, true)
				if item.kind == "barrage":
					for index in range(9):
						var angle := index * 2.4 + floorf(item.life * 16.0) * 0.45
						var drop := point + Vector2.from_angle(angle) * (28 + index * 9)
						arena.draw_line(drop + Vector2(-8, -27), drop, Color(color, 0.72), 2.0)
	for ally in summons:
		var point: Vector2 = ally.pos - offset
		if ally.kind == "totem":
			arena.draw_circle(point, 18.0, Color(GREEN, 0.3))
			arena.draw_line(point, point + Vector2(0, -30), GREEN, 5.0)
			arena.draw_circle(point + Vector2(0, -30), 7.0, GREEN)
		else:
			arena.draw_actor(arena.ENEMY_ART, point, 29.0, false, Color("#a5ffad"))
	for shot in shots:
		var point: Vector2 = shot.pos - offset
		if shot.kind == "arrow":
			arena.draw_line(point - shot.dir * 21.0, point, LILAC, 3.0)
		else:
			var angle: float = shot.age * 22.0
			arena.draw_arc(point, 10.0, angle, angle + PI * 0.8, 10, TEAL, 4.0, true)
