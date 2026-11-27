extends Node2D

const WORLD_SIZE := Vector2(2400, 900)
const GRAVITY := 1150.0
const RUN_SPEED := 330.0
const JET_FORCE := 1850.0
const BOT_COUNT := 4
const PLAYER_TAG_RANGE := 92.0
const BOT_TAG_RANGE := 48.0
const MAX_TAGS := 5

var player: Dictionary
var bots: Array[Dictionary] = []
var platforms: Array[Rect2] = []
var camera_x := 0.0
var game_started := false
var game_over := false
var score := 0
var tags_received := 0
var tag_cooldown := 0.0
var match_time := 0.0
var touch_left := false
var touch_right := false
var touch_jet := false
var touch_tag := false
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
		var x: float = [650.0, 1120.0, 1640.0, 2130.0][i]
		bots.append(_fighter(Vector2(x, 790), true))
	score = 0
	tags_received = 0
	tag_cooldown = 0.0
	match_time = 0.0
	game_over = false

func _fighter(pos: Vector2, is_bot: bool) -> Dictionary:
	return {
		"pos": pos, "vel": Vector2.ZERO, "bot": is_bot,
		"cooldown": randf_range(0.4, 1.4), "facing": -1.0 if is_bot else 1.0,
		"grounded": false, "stunned": 0.0
	}

func _process(delta: float) -> void:
	if not game_started or game_over:
		queue_redraw()
		return
	match_time += delta
	tag_cooldown = maxf(0.0, tag_cooldown - delta)
	_update_player(delta)
	_update_bots(delta)
	if touch_tag or Input.is_key_pressed(KEY_E):
		_tag_bot()
	_update_stuns(delta)
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
	var axis := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		axis = -1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		axis = 1.0
	if touch_left:
		axis = -1.0
	if touch_right:
		axis = 1.0
	if axis != 0:
		player.facing = signf(axis)
	player.vel.x = move_toward(player.vel.x, axis * RUN_SPEED, 1500 * delta)
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_SPACE) or touch_jet:
		player.vel.y = maxf(player.vel.y - JET_FORCE * delta, -510)
	_apply_physics(player, delta)

func _update_bots(delta: float) -> void:
	for bot in bots:
		if bot.stunned > 0.0:
			bot.vel.x = move_toward(bot.vel.x, 0.0, 900.0 * delta)
			_apply_physics(bot, delta)
			continue
		var diff: Vector2 = player.pos - bot.pos
		var direction := signf(diff.x)
		bot.facing = direction
		if absf(diff.x) > 58:
			bot.vel.x = move_toward(bot.vel.x, direction * 205.0, 700.0 * delta)
		else:
			bot.vel.x = move_toward(bot.vel.x, 0.0, 850.0 * delta)
		if diff.y < -105 and bot.grounded:
			bot.vel.y = -430.0
		_apply_physics(bot, delta)
		bot.cooldown -= delta
		if bot.cooldown <= 0.0 and bot.pos.distance_to(player.pos) < BOT_TAG_RANGE:
			bot.cooldown = 1.8
			tags_received += 1
			player.pos = Vector2(130, 790)
			player.vel = Vector2.ZERO
			if tags_received >= MAX_TAGS:
				game_over = true

func _tag_bot() -> void:
	if tag_cooldown > 0.0:
		return
	var nearest: int = -1
	var nearest_distance := PLAYER_TAG_RANGE
	for i in range(bots.size()):
		if bots[i].stunned > 0.0:
			continue
		var distance: float = player.pos.distance_to(bots[i].pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = i
	if nearest >= 0:
		bots[nearest].stunned = 1.6
		bots[nearest].vel = Vector2(0, -160)
		score += 100
		tag_cooldown = 0.55

func _update_stuns(delta: float) -> void:
	for bot in bots:
		bot.stunned = maxf(0.0, bot.stunned - delta)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			game_started = false
		elif event.keycode == KEY_R and game_over:
			_reset_match()
			game_started = true
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not game_started:
			game_started = true
			_reset_match()
		elif game_over:
			_reset_match()
		else:
			_tag_bot()
	if event is InputEventScreenTouch:
		_handle_touch(event.position, event.pressed)

func _handle_touch(pos: Vector2, pressed: bool) -> void:
	if not game_started or game_over:
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
			touch_tag = pressed

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
			_draw_fighter(bot, true)
		_draw_hud()
		_draw_touch_hud()
		if game_over:
			draw_rect(Rect2(300, 270, 680, 170), Color(0.02, 0.07, 0.12, 0.94))
			draw_string(ThemeDB.fallback_font, Vector2(455, 335), "MATCH OVER", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color("#ffcf78"))
			draw_string(ThemeDB.fallback_font, Vector2(390, 385), "Press R or tap to play again", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
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
	var body_color := Color("#ffb45c") if enemy else Color("#4dc7ff")
	if enemy and f.stunned > 0.0:
		body_color = Color("#7ee6b0")
	draw_circle(p + Vector2(0, -39), 12, Color("#f3d7c3") if enemy else Color("#e9f7ff"))
	draw_rect(Rect2(p + Vector2(-15, -29), Vector2(30, 34)), body_color)
	draw_rect(Rect2(p + Vector2(-13, 3), Vector2(10, 22)), Color("#263b55"))
	draw_rect(Rect2(p + Vector2(4, 3), Vector2(10, 22)), Color("#263b55"))
	if enemy and f.stunned > 0.0:
		draw_arc(p + Vector2(0, -30), 27, 0, TAU, 32, Color("#8fffc0"), 3.0)

func _draw_hud() -> void:
	draw_rect(Rect2(18, 16, 500, 76), Color(0.04, 0.09, 0.15, 0.88))
	draw_string(ThemeDB.fallback_font, Vector2(32, 39), "SKYSHOOT  |  TAGS %d/%d  |  SCORE %d" % [tags_received, MAX_TAGS, score], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(32, 66), "AI RUNNERS: %d  |  TAG RANGE: CLOSE" % BOT_COUNT, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#9fdcf0"))
	if score >= BOT_COUNT * 100:
		draw_string(ThemeDB.fallback_font, Vector2(450, 120), "ARENA MASTER!", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("#78f0c0"))

func _draw_touch_hud() -> void:
	_draw_button(Rect2(24, 610, 88, 78), "LEFT")
	_draw_button(Rect2(124, 610, 88, 78), "RIGHT")
	_draw_button(Rect2(1000, 610, 100, 78), "JET")
	_draw_button(Rect2(1110, 610, 145, 78), "TAG")

func _draw_button(r: Rect2, label: String) -> void:
	draw_rect(r, Color(0.1, 0.27, 0.38, 0.86))
	draw_rect(r, Color("#78dff5"), false, 2)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(12, 46), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)

func _draw_menu() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.015, 0.035, 0.07, 0.91))
	draw_string(ThemeDB.fallback_font, Vector2(390, 245), "SKYSHOOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 78, Color("#6be3ff"))
	draw_string(ThemeDB.fallback_font, Vector2(430, 292), "JETPACK TAG ARENA  •  TRAINING GROUNDS", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#c6d9ed"))
	draw_rect(menu_button, Color("#087eaa"))
	draw_rect(menu_button, Color("#80edff"), false, 3)
	draw_string(ThemeDB.fallback_font, Vector2(555, 416), "PLAY PRACTICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(440, 490), "4 AI opponents  •  Solo tag match", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#a9bfd5"))
	draw_string(ThemeDB.fallback_font, Vector2(335, 560), "A/D MOVE  |  SPACE JETPACK  |  E / CLICK TO TAG", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#9bb2c9"))
	draw_string(ThemeDB.fallback_font, Vector2(465, 592), "TAG NEARBY RUNNERS TO EARN POINTS", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#8ce7ff"))
