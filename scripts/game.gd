extends Node2D

const WORLD_SIZE := Vector2(2400, 900)
const GRAVITY := 1150.0
const RUN_SPEED := 330.0
const JET_FORCE := 1850.0
const BULLET_SPEED := 820.0
const BOT_COUNT := 4

var player: Dictionary
var bots: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var platforms: Array[Rect2] = []
var camera_x := 0.0
var game_started := false
var game_over := false
var score := 0
var last_shot := 0.0
var touch_left := false
var touch_right := false
var touch_jet := false
var touch_fire := false
var touch_aim := Vector2(1, 0)
var screen_size := Vector2(1280, 720)
var menu_button := Rect2(490, 365, 300, 82)

func _ready() -> void:
	_build_map()
	_reset_match()
	set_process(true)
	set_process_input(true)

func _build_map() -> void:
	platforms = [
		Rect2(0, 850, 2400, 50),
		Rect2(190, 690, 330, 26),
		Rect2(620, 550, 310, 26),
		Rect2(1040, 690, 340, 26),
		Rect2(1480, 530, 330, 26),
		Rect2(1900, 690, 310, 26),
		Rect2(1040, 370, 260, 24),
		Rect2(420, 410, 180, 22),
		Rect2(1770, 390, 180, 22)
	]

func _reset_match() -> void:
	player = _fighter(Vector2(130, 790), false)
	bots.clear()
	for i in BOT_COUNT:
		var x := [650.0, 1120.0, 1640.0, 2130.0][i]
		bots.append(_fighter(Vector2(x, 790), true))
	bullets.clear()
	score = 0
	game_over = false

func _fighter(pos: Vector2, is_bot: bool) -> Dictionary:
	return {"pos": pos, "vel": Vector2.ZERO, "hp": 100.0, "bot": is_bot, "cooldown": randf_range(0.4, 1.4), "facing": -1.0 if is_bot else 1.0, "alive": true, "grounded": false}

func _process(delta: float) -> void:
	if not game_started:
		queue_redraw()
		return
	if game_over:
		queue_redraw()
		return
	_update_player(delta)
	_update_bots(delta)
	_update_bullets(delta)
	if player.hp <= 0:
		player.hp = 100
		player.pos = Vector2(130, 790)
		player.vel = Vector2.ZERO
	camera_x = clampf(player.pos.x - 640, 0, WORLD_SIZE.x - 1280)
	queue_redraw()

func _apply_physics(f: Dictionary, delta: float) -> void:
	var old_y: float = f.pos.y
	f.vel.y += GRAVITY * delta
	f.pos += f.vel * delta
	f.pos.x = clampf(f.pos.x, 24, WORLD_SIZE.x - 24)
	f.grounded = false
	for platform in platforms:
		if f.vel.y >= 0 and old_y + 26 <= platform.position.y and f.pos.y + 26 >= platform.position.y and f.pos.x > platform.position.x - 24 and f.pos.x < platform.end.x + 24:
			f.pos.y = platform.position.y - 27
			f.vel.y = 0
			f.grounded = true
	if f.pos.y > WORLD_SIZE.y + 100:
		f.pos = Vector2(130, 790)
		f.vel = Vector2.ZERO

func _update_player(delta: float) -> void:
	var axis := Input.get_axis("move_left", "move_right")
	if touch_left: axis = -1
	if touch_right: axis = 1
	if axis != 0:
		player.facing = signf(axis)
	player.vel.x = move_toward(player.vel.x, axis * RUN_SPEED, 1500 * delta)
	if Input.is_action_pressed("jet") or touch_jet:
		player.vel.y = maxf(player.vel.y - JET_FORCE * delta, -510)
	_apply_physics(player, delta)
	if Input.is_action_pressed("fire") or touch_fire:
		_shoot_player()

func _update_bots(delta: float) -> void:
	for bot in bots:
		if not bot.alive: continue
		var diff: Vector2 = player.pos - bot.pos
		var direction := signf(diff.x)
		bot.facing = direction
		if absf(diff.x) > 135:
			bot.vel.x = move_toward(bot.vel.x, direction * 205, 700 * delta)
		else:
			bot.vel.x = move_toward(bot.vel.x, 0, 850 * delta)
		if diff.y < -105 and bot.grounded:
			bot.vel.y = -430
		_apply_physics(bot, delta)
		bot.cooldown -= delta
		if absf(diff.x) < 800 and bot.cooldown <= 0:
			bot.cooldown = randf_range(0.85, 1.5)
			_shoot(bot, player.pos, true)

func _shoot_player() -> void:
	if Time.get_ticks_msec() / 1000.0 - last_shot < 0.22: return
	last_shot = Time.get_ticks_msec() / 1000.0
	var aim := get_global_mouse_position()
	if touch_fire:
		aim = player.pos + touch_aim * 500
	_shoot(player, aim, false)

func _shoot(owner: Dictionary, target: Vector2, from_bot: bool) -> void:
	var direction: Vector2 = (target - owner.pos).normalized()
	if direction.length() < 0.1: direction = Vector2(owner.facing, 0)
	bullets.append({"pos": owner.pos + Vector2(0, -10), "vel": direction * BULLET_SPEED, "enemy": from_bot, "life": 1.8})

func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b.pos += b.vel * delta
		b.life -= delta
		var hit := false
		if b.enemy:
			if b.pos.distance_to(player.pos + Vector2(0, -12)) < 29:
				player.hp -= 13
				hit = true
		else:
			for bot in bots:
				if bot.alive and b.pos.distance_to(bot.pos + Vector2(0, -12)) < 30:
					bot.hp -= 25
					hit = true
					if bot.hp <= 0:
						bot.alive = false
						score += 100
					break
		if hit or b.life <= 0 or b.pos.x < 0 or b.pos.x > WORLD_SIZE.x or b.pos.y < 0 or b.pos.y > WORLD_SIZE.y:
			bullets.remove_at(i)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		game_started = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not game_started:
			game_started = true
			_reset_match()
		elif event.position.y > 500:
			touch_fire = true
	if event is InputEventMouseButton and not event.pressed:
		touch_fire = false
	if event is InputEventScreenTouch:
		_handle_touch(event.position, event.pressed)
	if event is InputEventScreenDrag:
		touch_aim = (event.position - Vector2(640, 350)).normalized()

func _handle_touch(pos: Vector2, pressed: bool) -> void:
	if not game_started:
		if pressed:
			game_started = true
			_reset_match()
		return
	if pos.y > screen_size.y * 0.70:
		if pos.x < screen_size.x * 0.27:
			touch_left = pressed
		elif pos.x < screen_size.x * 0.47:
			touch_right = pressed
		elif pos.x < screen_size.x * 0.72:
			touch_jet = pressed
		else:
			touch_fire = pressed

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, screen_size), Color("#0b1726"))
	_draw_background()
	for p in platforms:
		var r := Rect2(p.position.x - camera_x, p.position.y, p.size.x, p.size.y)
		draw_rect(r, Color("#344e68"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 5)), Color("#56d7e8"))
	_draw_cover()
	if game_started:
		_draw_fighter(player, false)
		for bot in bots:
			if bot.alive: _draw_fighter(bot, true)
		for b in bullets:
			draw_circle(Vector2(b.pos.x - camera_x, b.pos.y), 6, Color("#ffe08a"))
		_draw_hud()
		_draw_touch_hud()
	else:
		_draw_menu()

func _draw_background() -> void:
	for x in range(0, 2500, 100):
		var sx := float(x) - camera_x * 0.35
		draw_line(Vector2(sx, 0), Vector2(sx, 900), Color(0.16, 0.27, 0.37, 0.32), 1)
	for y in range(0, 900, 90):
		draw_line(Vector2(0, y), Vector2(1280, y), Color(0.16, 0.27, 0.37, 0.25), 1)
	for i in range(18):
		var x := float(i * 150) - camera_x * 0.45
		var h := 120.0 + float((i * 73) % 230)
		draw_rect(Rect2(x, 820 - h, 105, h), Color("#1b3045"))
		for wy in range(int(830 - h), 810, 32):
			for wx in range(14, 90, 28):
				draw_rect(Rect2(x + wx, wy, 11, 8), Color(0.35, 0.75, 0.85, 0.35))

func _draw_cover() -> void:
	for x in [570, 990, 1430, 1860]:
		var r := Rect2(float(x) - camera_x, 790, 95, 60)
		draw_rect(r, Color("#263d53"))
		draw_rect(r, Color("#6d91ad"), false, 3)

func _draw_fighter(f: Dictionary, enemy: bool) -> void:
	var p: Vector2 = f.pos - Vector2(camera_x, 0)
	var body_color := Color("#ff9f5c") if enemy else Color("#4dc7ff")
	draw_circle(p + Vector2(0, -39), 12, Color("#f3d7c3") if enemy else Color("#e9f7ff"))
	draw_rect(Rect2(p + Vector2(-15, -29), Vector2(30, 34)), body_color)
	draw_rect(Rect2(p + Vector2(-13, 3), Vector2(10, 22)), Color("#263b55"))
	draw_rect(Rect2(p + Vector2(4, 3), Vector2(10, 22)), Color("#263b55"))
	draw_rect(Rect2(p + Vector2(-20, -54), Vector2(40, 5)), Color("#263447"))
	draw_rect(Rect2(p + Vector2(-20, -54), Vector2(40 * f.hp / 100.0, 5)), Color("#70e39a") if f.hp > 35 else Color("#ff6b6b"))

func _draw_hud() -> void:
	draw_rect(Rect2(18, 16, 370, 56), Color(0.04, 0.09, 0.15, 0.88))
	draw_string(ThemeDB.fallback_font, Vector2(32, 39), "SKYSHOOT  |  HP %d  |  SCORE %d" % [int(player.hp), score], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(32, 61), "AI FIGHTERS: %d" % _living_bots(), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#9fdcf0"))
	if _living_bots() == 0:
		draw_string(ThemeDB.fallback_font, Vector2(450, 120), "TRAINING CLEAR!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#78f0c0"))

func _draw_touch_hud() -> void:
	_draw_button(Rect2(24, 610, 88, 78), "LEFT")
	_draw_button(Rect2(124, 610, 88, 78), "RIGHT")
	_draw_button(Rect2(1000, 610, 100, 78), "JET")
	_draw_button(Rect2(1110, 610, 145, 78), "FIRE")

func _draw_button(r: Rect2, label: String) -> void:
	draw_rect(r, Color(0.1, 0.27, 0.38, 0.86))
	draw_rect(r, Color("#78dff5"), false, 2)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(12, 46), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)

func _draw_menu() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.035, 0.07, 0.91))
	draw_string(ThemeDB.fallback_font, Vector2(390, 245), "SKYSHOOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 78, Color("#6be3ff"))
	draw_string(ThemeDB.fallback_font, Vector2(430, 292), "JETPACK ARENA  •  TRAINING GROUNDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#c6d9ed"))
	draw_rect(menu_button, Color("#087eaa"))
	draw_rect(menu_button, Color("#80edff"), false, 3)
	draw_string(ThemeDB.fallback_font, Vector2(555, 416), "PLAY PRACTICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(440, 490), "4 AI opponents  •  Solo training match", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#a9bfd5"))
	draw_string(ThemeDB.fallback_font, Vector2(400, 580), "A/D or touch to move   |   SPACE / JET to fly   |   CLICK / FIRE to shoot", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#9bb2c9"))

func _living_bots() -> int:
	var count := 0
	for bot in bots:
		if bot.alive: count += 1
	return count
