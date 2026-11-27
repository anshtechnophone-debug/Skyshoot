extends Node2D

# Skyshoot: a colorful, cartoon-style jetpack tag arena.
const VIEW := Vector2(1280, 720)
const WORLD := Vector2(2500, 900)
const GRAVITY := 1050.0
const RUN_SPEED := 360.0
const JET_FORCE := 1900.0
const MAX_TAGS := 5
const MATCH_LENGTH := 90.0
const MAP_NAMES := ["Sunny Isles", "Candy Canyon", "Cloud Kingdom"]

var platforms: Array[Rect2] = []
var player: Dictionary = {}
var bots: Array[Dictionary] = []
var camera_x := 0.0
var game_state := "menu"
var score := 0
var tags_received := 0
var match_time := MATCH_LENGTH
var tag_cooldown := 0.0
var jet_fuel := 1.0
var map_index := 0
var skin_index := 0
var elapsed := 0.0
var touch_left := false
var touch_right := false
var touch_jet := false
var touch_tag := false
var touch_points: Dictionary = {}

const PLAYER_COLORS := [Color("#36b9ed"), Color("#ff8a65"), Color("#a78bfa"), Color("#55c99a")]
const BOT_COLORS := [Color("#ff9b54"), Color("#f16d9b"), Color("#9bcb55"), Color("#a78bfa")]
const MAP_SKY := [Color("#83dcff"), Color("#ffbd83"), Color("#8b9df5")]
const MAP_HILL := [Color("#54bd83"), Color("#d78a62"), Color("#6874c8")]
const MAP_GROUND := [Color("#58b96d"), Color("#d68a4c"), Color("#6677bd")]

func _ready() -> void:
	_build_map()
	_reset_match()
	set_process(true)
	set_process_input(true)

func _build_map() -> void:
	platforms = [
		Rect2(0, 850, 2500, 60),
		Rect2(180, 690, 330, 28),
		Rect2(610, 550, 310, 28),
		Rect2(1030, 690, 340, 28),
		Rect2(1480, 530, 330, 28),
		Rect2(1910, 680, 390, 28),
		Rect2(1020, 365, 270, 26),
		Rect2(390, 405, 190, 25),
		Rect2(1790, 390, 210, 25),
		Rect2(730, 260, 190, 24),
		Rect2(1430, 245, 190, 24)
	]

func _fighter(pos: Vector2, is_bot: bool, index: int = 0) -> Dictionary:
	return {
		"pos": pos, "vel": Vector2.ZERO, "bot": is_bot, "index": index,
		"facing": -1.0 if is_bot else 1.0, "grounded": false,
		"stunned": 0.0, "cooldown": randf_range(0.7, 1.5),
		"phase": randf_range(0.0, TAU)
	}

func _reset_match() -> void:
	player = _fighter(Vector2(130, 790), false)
	bots.clear()
	var starts := [Vector2(650, 790), Vector2(1120, 790), Vector2(1640, 790), Vector2(2180, 790)]
	for i in range(4):
		bots.append(_fighter(starts[i], true, i))
	score = 0
	tags_received = 0
	match_time = MATCH_LENGTH
	tag_cooldown = 0.0
	jet_fuel = 1.0
	camera_x = 0.0

func _process(delta: float) -> void:
	elapsed += delta
	if game_state != "playing":
		queue_redraw()
		return
	match_time = maxf(0.0, match_time - delta)
	tag_cooldown = maxf(0.0, tag_cooldown - delta)
	_update_player(delta)
	_update_bots(delta)
	if touch_tag or Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER):
		_try_tag()
	for bot in bots:
		bot.stunned = maxf(0.0, bot.stunned - delta)
	camera_x = clampf(player.pos.x - VIEW.x * 0.43, 0.0, WORLD.x - VIEW.x)
	if tags_received >= MAX_TAGS or match_time <= 0.0:
		game_state = "results"
	queue_redraw()

func _apply_physics(f: Dictionary, delta: float) -> void:
	var old_y: float = f.pos.y
	f.vel.y += GRAVITY * delta
	f.pos += f.vel * delta
	f.pos.x = clampf(f.pos.x, 28.0, WORLD.x - 28.0)
	f.grounded = false
	for platform in platforms:
		if f.vel.y >= 0.0 and old_y + 24.0 <= platform.position.y and f.pos.y + 24.0 >= platform.position.y and f.pos.x > platform.position.x - 25.0 and f.pos.x < platform.end.x + 25.0:
			f.pos.y = platform.position.y - 25.0
			f.vel.y = 0.0
			f.grounded = true
	if f.pos.y > WORLD.y:
		f.pos = Vector2(130, 790)
		f.vel = Vector2.ZERO

func _update_player(delta: float) -> void:
	var axis := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		axis -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		axis += 1.0
	if touch_left:
		axis = -1.0
	if touch_right:
		axis = 1.0
	if axis != 0.0:
		player.facing = signf(axis)
	player.vel.x = move_toward(player.vel.x, axis * RUN_SPEED, 1700.0 * delta)
	var jet := Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) or touch_jet
	if jet and jet_fuel > 0.0:
		player.vel.y = maxf(player.vel.y - JET_FORCE * delta, -560.0)
		jet_fuel = maxf(0.0, jet_fuel - delta * 0.30)
	else:
		jet_fuel = minf(1.0, jet_fuel + delta * 0.17)
	_apply_physics(player, delta)

func _update_bots(delta: float) -> void:
	for bot in bots:
		if bot.stunned > 0.0:
			bot.vel.x = move_toward(bot.vel.x, 0.0, 1000.0 * delta)
			_apply_physics(bot, delta)
			continue
		var diff: Vector2 = player.pos - bot.pos
		var direction := signf(diff.x)
		bot.facing = direction
		if absf(diff.x) > 58.0:
			bot.vel.x = move_toward(bot.vel.x, direction * (190.0 + float(bot.index) * 9.0), 720.0 * delta)
		else:
			bot.vel.x = move_toward(bot.vel.x, 0.0, 850.0 * delta)
		if diff.y < -90.0 and bot.grounded:
			bot.vel.y = -440.0
		if absf(diff.x) > 230.0 and diff.y < -120.0:
			bot.vel.y = minf(bot.vel.y, -260.0)
		_apply_physics(bot, delta)
		bot.cooldown -= delta
		if bot.cooldown <= 0.0 and bot.pos.distance_to(player.pos) < 54.0:
			bot.cooldown = 1.7
			tags_received += 1
			player.pos = Vector2(130.0, 790.0)
			player.vel = Vector2.ZERO
			jet_fuel = 1.0

func _try_tag() -> void:
	if tag_cooldown > 0.0:
		return
	var nearest := -1
	var nearest_distance := 100.0
	for i in range(bots.size()):
		if bots[i].stunned > 0.0:
			continue
		var distance: float = player.pos.distance_to(bots[i].pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = i
	if nearest >= 0:
		bots[nearest].stunned = 1.8
		bots[nearest].vel = Vector2(0.0, -190.0)
		score += 100
		tag_cooldown = 0.65

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if game_state == "playing":
				game_state = "paused"
			elif game_state == "paused":
				game_state = "playing"
		elif event.keycode == KEY_R and game_state == "results":
			_reset_match()
			game_state = "playing"
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_ui_click(event.position)
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_points[event.index] = event.position
			_handle_ui_click(event.position)
			_update_touch_flags()
		else:
			touch_points.erase(event.index)
			_update_touch_flags()
	if event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		_update_touch_flags()

func _update_touch_flags() -> void:
	touch_left = false
	touch_right = false
	touch_jet = false
	touch_tag = false
	for point in touch_points.values():
		var p: Vector2 = point
		if p.y > 565.0:
			if p.x < 190.0:
				touch_left = true
			elif p.x < 370.0:
				touch_right = true
			elif p.x < 1010.0:
				touch_jet = true
			else:
				touch_tag = true

func _handle_ui_click(p: Vector2) -> void:
	if game_state == "menu":
		if Rect2(430, 390, 420, 90).has_point(p):
			_reset_match()
			game_state = "playing"
		elif Rect2(430, 500, 420, 62).has_point(p):
			map_index = (map_index + 1) % MAP_NAMES.size()
		elif Rect2(430, 575, 420, 58).has_point(p):
			skin_index = (skin_index + 1) % PLAYER_COLORS.size()
	elif game_state == "paused":
		if Rect2(430, 350, 420, 75).has_point(p):
			game_state = "playing"
		elif Rect2(430, 445, 420, 70).has_point(p):
			game_state = "menu"
	elif game_state == "results":
		if Rect2(430, 410, 420, 78).has_point(p):
			_reset_match()
			game_state = "playing"
		elif Rect2(430, 510, 420, 62).has_point(p):
			game_state = "menu"
	elif game_state == "playing" and p.y < 90.0 and p.x > 1160.0:
		game_state = "paused"
	elif game_state == "playing" and p.y > 560.0 and p.x > 1010.0:
		_try_tag()

func _draw() -> void:
	_draw_world_background()
	_draw_platforms()
	if game_state == "playing" or game_state == "paused" or game_state == "results":
		for bot in bots:
			_draw_character(bot, true)
		_draw_character(player, false)
		_draw_hud()
		if game_state == "paused":
			_draw_overlay("PAUSED", "Take a breather!", "RESUME", "MAIN MENU")
		elif game_state == "results":
			_draw_overlay("MATCH COMPLETE", "Score  %d     Tags received  %d" % [score, tags_received], "PLAY AGAIN", "MAIN MENU")
	_draw_clouds_front()
	if game_state == "menu":
		_draw_menu()

func _draw_world_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW), MAP_SKY[map_index])
	for i in range(7):
		var x := float(i * 230) - fmod(camera_x * 0.22, 1610.0)
		draw_circle(Vector2(x, 165.0 + float((i * 37) % 85)), 105.0, MAP_HILL[map_index].lightened(0.35))
		draw_circle(Vector2(x + 80.0, 190.0), 90.0, MAP_HILL[map_index].lightened(0.35))
	for i in range(11):
		var x := float(i * 145) - fmod(camera_x * 0.48, 1595.0)
		var h := 150.0 + float((i * 43) % 115)
		draw_polygon(PackedVector2Array([Vector2(x - 65, 650), Vector2(x + 45, 650 - h), Vector2(x + 155, 650)]), PackedColorArray([MAP_HILL[map_index], MAP_HILL[map_index], MAP_HILL[map_index]]))
	draw_rect(Rect2(0, 650, VIEW.x, 70), MAP_GROUND[map_index].darkened(0.06))
	_draw_clouds_back()

func _draw_clouds_back() -> void:
	for i in range(9):
		var x := fposmod(float(i * 190) - camera_x * 0.12, 1450.0) - 70.0
		var y := 80.0 + float((i * 41) % 180)
		_draw_cloud(Vector2(x, y), 0.8 + float(i % 3) * 0.15)

func _draw_clouds_front() -> void:
	for i in range(5):
		var x := fposmod(float(i * 310) - camera_x * 0.30, 1500.0) - 80.0
		_draw_cloud(Vector2(x, 620.0 + float(i % 2) * 30.0), 0.55)

func _draw_cloud(p: Vector2, scale: float) -> void:
	var c := Color(1.0, 1.0, 1.0, 0.82)
	draw_circle(p, 24.0 * scale, c)
	draw_circle(p + Vector2(25, -10) * scale, 30.0 * scale, c)
	draw_circle(p + Vector2(53, 2) * scale, 22.0 * scale, c)
	draw_rect(Rect2(p + Vector2(-2, 0) * scale, Vector2(57, 20) * scale), c)

func _draw_platforms() -> void:
	for i in range(platforms.size()):
		var p := platforms[i]
		var r := Rect2(p.position.x - camera_x, p.position.y, p.size.x, p.size.y)
		draw_rect(r, Color("#9b6746"))
		draw_rect(Rect2(r.position, Vector2(r.size.x, 10)), MAP_GROUND[map_index].lightened(0.22))
		draw_line(r.position + Vector2(0, 11), r.position + Vector2(r.size.x, 11), Color("#fff0b0"), 3.0)
		for j in range(int(p.size.x / 48.0)):
			var sx := r.position.x + 20.0 + float(j) * 48.0
			draw_circle(Vector2(sx, r.position.y + 16.0), 3.0, Color("#70452f"))
		if i > 0:
			for j in range(3):
				var sx := r.position.x + 35.0 + float(j) * maxf(35.0, (r.size.x - 70.0) / 3.0)
				draw_line(Vector2(sx, r.position.y + 2), Vector2(sx - 5, r.position.y - 8), Color("#fff2a6"), 3.0)

func _draw_character(f: Dictionary, enemy: bool) -> void:
	var p: Vector2 = f.pos - Vector2(camera_x, 0)
	var moving := absf(f.vel.x) > 30.0
	var bob := sin(elapsed * (12.0 if moving else 3.0) + f.phase) * (3.0 if moving else 1.5)
	var body := BOT_COLORS[int(f.index)] if enemy else PLAYER_COLORS[skin_index]
	if enemy and f.stunned > 0.0:
		body = Color("#b9f5a5")
	var facing: float = f.facing
	var head := p + Vector2(0, -43 + bob)
	var torso := p + Vector2(0, -19 + bob)
	# Soft shadow and backpack.
	draw_circle(p + Vector2(0, 2), 18.0, Color(0.12, 0.20, 0.25, 0.22))
	draw_rect(Rect2(p + Vector2(-20 * facing - 4, -28 + bob), Vector2(10, 25)), Color("#5d6b83"))
	draw_circle(p + Vector2(-20 * facing, -17 + bob), 6, Color("#a9d9ed"))
	# Legs and shoes animate while running.
	var stride := sin(elapsed * 13.0 + f.phase) * (8.0 if moving else 1.5)
	draw_line(torso + Vector2(-7, 8), p + Vector2(-8 + stride, 2), Color("#39445e"), 8.0)
	draw_line(torso + Vector2(7, 8), p + Vector2(8 - stride, 2), Color("#39445e"), 8.0)
	draw_rounded_rect(Rect2(p + Vector2(-16 + stride, -3), Vector2(16, 8)), 4, Color("#fff0cf"))
	draw_rounded_rect(Rect2(p + Vector2(1 - stride, -3), Vector2(16, 8)), 4, Color("#fff0cf"))
	# Arms, body and neck.
	draw_line(torso + Vector2(-10, -1), torso + Vector2(-18, 13), Color("#f0c5a3"), 7.0)
	draw_line(torso + Vector2(10, -1), torso + Vector2(18, 12), Color("#f0c5a3"), 7.0)
	draw_rounded_rect(Rect2(p + Vector2(-15, -34 + bob), Vector2(30, 32)), 9, body)
	draw_circle(head, 15, Color("#ffd9b8"))
	# Hair cap, eyes and cheerful expression.
	draw_arc(head + Vector2(0, -3), 14, PI, TAU, 24, Color("#563e38"), 7.0)
	draw_circle(head + Vector2(5 * facing, -1), 2.2, Color("#26384c"))
	draw_circle(head + Vector2(10 * facing, 5), 2.0, Color("#e98578"))
	draw_arc(head + Vector2(5 * facing, 5), 5, 0.1, 1.8, 12, Color("#9b554d"), 1.5)
	if not enemy and touch_jet or (not enemy and Input.is_key_pressed(KEY_SPACE)):
		draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -7), p + Vector2(0, 13 + randf_range(0, 4)), p + Vector2(9, -7)]), Color("#ffbd4a"))
	if enemy and f.stunned > 0.0:
		for j in range(3):
			var a := elapsed * 2.0 + float(j) * TAU / 3.0
			draw_circle(head + Vector2(cos(a) * 22.0, sin(a) * 12.0 - 22.0), 3.5, Color("#fff17a"))

func _draw_hud() -> void:
	draw_rounded_rect(Rect2(22, 18, 430, 92), 18, Color(0.12, 0.22, 0.32, 0.88))
	draw_string(ThemeDB.fallback_font, Vector2(42, 49), "SKYSHOOT", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("#fff5d6"))
	draw_string(ThemeDB.fallback_font, Vector2(42, 82), "SCORE  %d     TAGS  %d/%d" % [score, tags_received, MAX_TAGS], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	draw_rounded_rect(Rect2(475, 27, 250, 20), 10, Color(0.12, 0.22, 0.32, 0.8))
	draw_rounded_rect(Rect2(479, 31, 242.0 * jet_fuel, 12), 6, Color("#ffe27a"))
	draw_string(ThemeDB.fallback_font, Vector2(475, 67), "JETPACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(850, 54), "%02d:%02d" % [int(match_time) / 60, int(match_time) % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color.WHITE)
	draw_rounded_rect(Rect2(1170, 20, 86, 60), 14, Color("#f5a85b"))
	draw_string(ThemeDB.fallback_font, Vector2(1188, 57), "PAUSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#543c3b"))
	_draw_touch_controls()

func _draw_touch_controls() -> void:
	_draw_control(Rect2(24, 590, 88, 88), "◀")
	_draw_control(Rect2(124, 590, 88, 88), "▶")
	_draw_control(Rect2(990, 590, 110, 88), "JET")
	_draw_control(Rect2(1115, 590, 140, 88), "TAG")

func _draw_control(r: Rect2, label: String) -> void:
	draw_circle(r.position + r.size * 0.5, 39, Color(0.12, 0.28, 0.38, 0.72))
	draw_arc(r.position + r.size * 0.5, 39, 0, TAU, 40, Color("#fff1c5"), 3.0)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(26, 54), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)

func _draw_menu() -> void:
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(0.08, 0.16, 0.24, 0.28))
	draw_rounded_rect(Rect2(285, 80, 710, 565), 34, Color(0.10, 0.23, 0.31, 0.90))
	draw_string(ThemeDB.fallback_font, Vector2(405, 195), "SKYSHOOT!", HORIZONTAL_ALIGNMENT_LEFT, -1, 82, Color("#fff1a6"))
	draw_string(ThemeDB.fallback_font, Vector2(405, 238), "THE GREAT JETPACK TAG ADVENTURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#d7f5ff"))
	_draw_character(_fighter(Vector2(640 + sin(elapsed * 2.0) * 12.0, 350 + sin(elapsed * 3.0) * 8.0), false), false)
	_draw_character(_fighter(Vector2(555, 360), true, 0), true)
	_draw_character(_fighter(Vector2(730, 360), true, 1), true)
	_draw_menu_button(Rect2(430, 430, 420, 75), "PLAY GAME", Color("#54c98b"))
	_draw_menu_button(Rect2(430, 520, 420, 54), "WORLD: " + MAP_NAMES[map_index], Color("#66bfe9"))
	_draw_menu_button(Rect2(430, 585, 420, 45), "HERO COLOR: " + str(skin_index + 1), Color("#ad91ef"))
	draw_string(ThemeDB.fallback_font, Vector2(430, 670), "RUN • FLY • TAG • HAVE FUN!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

func _draw_menu_button(r: Rect2, label: String, color: Color) -> void:
	draw_rounded_rect(r, 15, color)
	draw_rounded_rect_outline(r, 15, Color("#fff5d6"), 3.0)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(0, r.size.y * 0.66), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 21, Color("#26394b"))

func _draw_overlay(title: String, subtitle: String, primary: String, secondary: String) -> void:
	draw_rect(Rect2(0, 0, VIEW.x, VIEW.y), Color(0.04, 0.10, 0.16, 0.72))
	draw_rounded_rect(Rect2(300, 205, 680, 365), 32, Color("#fff0cf"))
	draw_string(ThemeDB.fallback_font, Vector2(365, 300), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 43, Color("#35536b"))
	draw_string(ThemeDB.fallback_font, Vector2(365, 345), subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("#526b7e"))
	_draw_menu_button(Rect2(430, 390, 420, 70), primary, Color("#65d49b"))
	_draw_menu_button(Rect2(430, 480, 420, 58), secondary, Color("#85cbed"))

func _draw_rounded_rect(r: Rect2, radius: float, color: Color) -> void:
	draw_rect(r, color)
	draw_circle(r.position + Vector2(radius, radius), radius, color)
	draw_circle(r.position + Vector2(r.size.x - radius, radius), radius, color)
	draw_circle(r.position + Vector2(radius, r.size.y - radius), radius, color)
	draw_circle(r.position + r.size - Vector2(radius, radius), radius, color)

func draw_rounded_rect(r: Rect2, radius: float, color: Color) -> void:
	_draw_rounded_rect(r, radius, color)

func draw_rounded_rect_outline(r: Rect2, radius: float, color: Color, width: float) -> void:
	draw_arc(r.position + Vector2(radius, radius), radius, PI, PI * 1.5, 12, color, width)
	draw_arc(r.position + Vector2(r.size.x - radius, radius), radius, PI * 1.5, TAU, 12, color, width)
	draw_arc(r.position + r.size - Vector2(radius, radius), radius, 0, PI * 0.5, 12, color, width)
	draw_arc(r.position + Vector2(radius, r.size.y - radius), radius, PI * 0.5, PI, 12, color, width)
	draw_line(r.position + Vector2(radius, 0), r.position + Vector2(r.size.x - radius, 0), color, width)
	draw_line(r.position + Vector2(radius, r.size.y), r.position + Vector2(r.size.x - radius, r.size.y), color, width)

func draw_rounded_rect_unused() -> void:
	pass
