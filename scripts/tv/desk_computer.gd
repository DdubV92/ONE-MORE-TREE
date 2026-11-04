class_name DeskComputer
extends Node
## Phase 11: the camper desk computer. An original, offline, fictional
## desktop ("CampOS") rendered into one SubViewport that is both the
## in-world monitor image and - while you sit at the desk - a readable
## overlay on the left of the screen, so the window to your right stays in
## view. Apps:
##   Cameras  - the existing live surveillance wall (CameraWall), rehosted:
##              quad, click a tile to focus, previous/next, back, swap
##              interval, microphones, volume, monitor power.
##   Shop     - the existing axe purchases (real Equipment/Wallet API) and
##              the truck order (real VehicleService).
##   Mail, News, Forums, Recordings - labelled "later update" placeholders
##              (Phases 14/17/19); they never show fake content.
## A small quad inset keeps the cameras at the edge of attention in other
## apps (same four-feed budget: it is the same composite texture).
## Live: time keeps running while you use it; the real pause menu pauses.

signal app_changed(app: String)

const SIZE := Vector2i(1024, 576)
const APPS := ["Cameras", "Shop", "Mail", "News", "Forums", "Recordings"]
const LATER := {
	"Mail": "Camp Mail arrives with the supplier and company correspondence in a later update (Phase 14 and Phase 17).",
	"News": "Regional news arrives in a later update (Phase 17).",
	"Forums": "The community forums arrive in a later update (Phase 17).",
	"Recordings": "The camera recording archive arrives in a later update (Phase 19). Nothing is being recorded yet.",
}

var monitor: Node3D
var screen: MeshInstance3D
var vp: SubViewport
var overlay: CanvasLayer
var container: SubViewportContainer
var mat: ShaderMaterial
var app := "Cameras"
var powered := true
var seated := false
var glancing := false
var _shell: Control
var _content: Control
var _inset: TextureRect
var _feed: TextureRect
var _status: Label
var _clock: Label
var _buttons := {}
var _shop_box: VBoxContainer
var clicks := 0                # tile clicks handled (tests)


func setup() -> void:
	var root := get_parent()
	var mons := get_tree().get_nodes_in_group("camper_monitor").filter(func(n: Node) -> bool: return root == null or root.is_ancestor_of(n))
	if mons.is_empty():
		return
	monitor = mons[0]
	screen = monitor.get_node("Screen")
	screen.layers = 1 << (CameraWall.LAYER_TV - 1)
	overlay = CanvasLayer.new()
	overlay.layer = 40
	overlay.visible = false
	add_child(overlay)
	container = SubViewportContainer.new()
	container.stretch = true
	container.anchor_left = 0.02
	container.anchor_top = 0.06
	container.anchor_right = 0.72
	container.anchor_bottom = 0.86
	overlay.add_child(container)
	vp = SubViewport.new()
	vp.size = SIZE
	vp.disable_3d = true
	vp.handle_input_locally = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(vp)
	_build_shell()
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/tv_screen.gdshader")
	mat.set_shader_parameter("feed", vp.get_texture())
	mat.set_shader_parameter("gain", 0.5)
	mat.set_shader_parameter("powered", 1.0)
	screen.material_override = mat
	open_app("Cameras")


# ------------------------------------------------------------ desktop shell

func _build_shell() -> void:
	_shell = Panel.new()
	_shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shell.theme = UITheme.get_theme()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.1)
	_shell.add_theme_stylebox_override("panel", sb)
	vp.add_child(_shell)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 6
	v.offset_bottom = -6
	_shell.add_child(v)
	var bar := HBoxContainer.new()
	v.add_child(bar)
	bar.add_child(UITheme.label("CampOS", 18, UITheme.ACCENT))
	for a in APPS:
		var b := UITheme.button(a + ("" if not LATER.has(a) else " (later)"), func() -> void: open_app(a), 0)
		b.focus_mode = Control.FOCUS_ALL
		_buttons[a] = b
		bar.add_child(b)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(sp)
	_clock = UITheme.label("", 15, UITheme.MUTED)
	bar.add_child(_clock)
	bar.add_child(UITheme.button("Stand up", func() -> void:
		if Game.player and Game.player.has_method("stand_from_couch"):
			Game.player.stand_from_couch(), 0))
	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.clip_contents = true
	v.add_child(_content)
	_status = UITheme.label("", 14, UITheme.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_status)
	_inset = TextureRect.new()
	_inset.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_inset.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_inset.anchor_left = 1.0
	_inset.anchor_right = 1.0
	_inset.anchor_top = 1.0
	_inset.anchor_bottom = 1.0
	_inset.offset_left = -250
	_inset.offset_top = -170
	_inset.offset_right = -10
	_inset.offset_bottom = -34
	_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shell.add_child(_inset)


func open_app(a: String) -> void:
	app = a
	for c in _content.get_children():
		c.queue_free()
	var wall: CameraWall = Game.tv
	_inset.texture = wall.composite.get_texture() if wall and wall.composite else null
	_inset.visible = a != "Cameras" and wall != null and wall.powered
	match a:
		"Cameras":
			_build_cameras()
		"Shop":
			_build_shop()
		_:
			var l := UITheme.label(str(LATER.get(a, "")), 18)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD
			l.set_anchors_preset(Control.PRESET_FULL_RECT)
			l.offset_left = 20
			l.offset_top = 30
			l.offset_right = -20
			_content.add_child(l)
	for k in _buttons:
		(_buttons[k] as Button).modulate = Color(1.2, 1.1, 0.7) if k == a else Color.WHITE
	app_changed.emit(a)


func _build_cameras() -> void:
	var wall: CameraWall = Game.tv
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(v)
	_feed = TextureRect.new()
	_feed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_feed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_feed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_feed.texture = wall.composite.get_texture() if wall and wall.composite else null
	_feed.gui_input.connect(_feed_input)
	v.add_child(_feed)
	var row := HBoxContainer.new()
	v.add_child(row)
	row.add_child(UITheme.button("Wall (4)", _wall_back, 0))
	row.add_child(UITheme.button("< Prev", func() -> void: _step(-1), 0))
	row.add_child(UITheme.button("Next >", func() -> void: _step(1), 0))
	row.add_child(UITheme.button("Swap speed", func() -> void: _cycle_interval(), 0))
	row.add_child(UITheme.button("Mics on/off", _toggle_mics, 0))
	row.add_child(UITheme.button("Vol -", func() -> void: _vol(-0.1), 0))
	row.add_child(UITheme.button("Vol +", func() -> void: _vol(0.1), 0))
	row.add_child(UITheme.button("Feeds on/off", _toggle_feeds, 0))


func _wall_back() -> void:
	if Game.tv:
		Game.tv.back_to_quad()


func _toggle_mics() -> void:
	if Game.tv:
		Game.tv.set_mic_muted(not Game.tv.mic_muted)


func _vol(d: float) -> void:
	if Game.tv:
		Game.tv.set_volume(Game.tv.tv_volume + d)


func _toggle_feeds() -> void:
	if Game.tv:
		Game.tv.set_power(not Game.tv.powered)
		_inset.visible = app != "Cameras" and Game.tv.powered


func _step(d: int) -> void:
	var wall: CameraWall = Game.tv
	if wall == null:
		return
	if wall.mode != "focus":
		wall.focus_index = wall.tiles[0]
		wall.set_mode("focus")
	wall.focus_step(d)


func _cycle_interval() -> void:
	var wall: CameraWall = Game.tv
	if wall == null:
		return
	var steps := [0.0, 5.0, 10.0, 20.0, 40.0]
	var i := maxi(steps.find(wall.interval), 1)
	i = (i + 1) % steps.size()
	wall.set_interval(steps[i])
	Settings.set_v("tv_interval", steps[i])


## Click on the feed: in the wall, the tile actually shown under the cursor
## right now becomes the focus (labels, texture and mic follow together);
## right-click in focus returns to the wall.
func _feed_input(ev: InputEvent) -> void:
	var wall: CameraWall = Game.tv
	if wall == null or not (ev is InputEventMouseButton) or not (ev as InputEventMouseButton).pressed:
		return
	var mb := ev as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_RIGHT and wall.mode == "focus":
		wall.back_to_quad()
		return
	if mb.button_index != MOUSE_BUTTON_LEFT or wall.mode != "quad":
		return
	var t := tile_at(mb.position, _feed.size)
	if t >= 0:
		clicks += 1
		wall.focus_tile(t)


## Which quad tile is under a point of a feed rect of `rect_size` (the 16:9
## composite is letterboxed to keep its aspect).
static func tile_at(pos: Vector2, rect_size: Vector2) -> int:
	var ar := 16.0 / 9.0
	var w := minf(rect_size.x, rect_size.y * ar)
	var h := w / ar
	var o := (rect_size - Vector2(w, h)) * 0.5
	var u := (pos - o) / Vector2(w, h)
	if u.x < 0.0 or u.y < 0.0 or u.x > 1.0 or u.y > 1.0:
		return -1
	return (1 if u.x >= 0.5 else 0) + (2 if u.y >= 0.5 else 0)


func _build_shop() -> void:
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_content.add_child(sc)
	_shop_box = VBoxContainer.new()
	_shop_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_shop_box)
	_refresh_shop()


func _refresh_shop() -> void:
	if _shop_box == null:
		return
	for c in _shop_box.get_children():
		c.queue_free()
	var cs: CampaignService = Game.campaign
	_shop_box.add_child(UITheme.label("Camp Supply (company account)", 20, UITheme.ACCENT))
	if cs == null or not cs.active:
		_shop_box.add_child(UITheme.label("Orders are only available during a campaign.", 16))
		return
	_shop_box.add_child(UITheme.label("Cash $%s · wages owed $%s · tonight's payroll $%s" % [Money.format_cents(cs.wallet.cash), Money.format_cents(cs.payroll.owed_total()), Money.format_cents(cs.payroll.todays_estimate())], 15))
	for tier in ["medium", "large"]:
		var mult: float = {"medium": 1.40, "large": 1.96}[tier]
		var owned := cs.equipment.boss_has(tier)
		var price := cs.equipment.price(tier)
		var row := HBoxContainer.new()
		var l := UITheme.label("%s axe: x%.2f cutting rate (more work per hit) · $%s%s" % [tier.capitalize(), mult, Money.format_cents(price), "  · OWNED" if owned else ""], 15)
		l.custom_minimum_size = Vector2(620, 0)
		row.add_child(l)
		if not owned:
			var t2: String = tier
			row.add_child(UITheme.button("Buy", func() -> void:
				var r := cs.equipment.buy(t2)
				_status.text = ("Bought: the %s axe is at the tool rack and equipped." % t2) if bool(r.get("ok", false)) else str(r.get("reason", "Not possible."))
				if bool(r.get("ok", false)):
					cs.equipment.equip_tier(t2)
				_refresh_shop(), 0))
		_shop_box.add_child(row)
	if Game.vehicles:
		var u: Dictionary = Game.vehicles.unlock_state()
		var row2 := HBoxContainer.new()
		var l2 := UITheme.label("Logging pickup: 3 seats, 3 trees' worth of logs · $%s · owned %d of 2%s" % [Money.format_cents(int(u.price)), int(u.owned), "" if bool(u.unlocked) else " · unlocks after %.0f trees' worth delivered" % float(u.get("need", 0))], 15)
		l2.custom_minimum_size = Vector2(620, 0)
		row2.add_child(l2)
		if int(u.owned) < 2:
			row2.add_child(UITheme.button("Order", func() -> void:
				var r2: Dictionary = Game.vehicles.buy()
				_status.text = "Pickup delivered to the camp bays." if bool(r2.get("ok", false)) else str(r2.get("reason", "Not possible."))
				_refresh_shop(), 0))
		_shop_box.add_child(row2)
	_shop_box.add_child(UITheme.label("Gloves, boots, helmets and chainsaws: not stocked yet (a later update).", 14, UITheme.MUTED))


# ------------------------------------------------------------ seat + glance

func sit(on: bool) -> void:
	seated = on
	glancing = false
	_update_overlay()
	if on and app == "Shop":
		_refresh_shop()


func set_glance(g: bool) -> void:
	glancing = g
	_update_overlay()


func _update_overlay() -> void:
	if overlay == null:
		return
	var show := seated and not glancing and powered
	overlay.visible = show
	if seated:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if show else Input.MOUSE_MODE_CAPTURED


func set_power(on: bool) -> void:
	powered = on
	if mat:
		mat.set_shader_parameter("powered", 1.0 if on else 0.0)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if on else SubViewport.UPDATE_DISABLED
	if Game.tv:
		Game.tv.set_power(on)
	_update_overlay()


func _process(_delta: float) -> void:
	if monitor == null:
		return
	if seated and not glancing and powered and not get_tree().paused and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cs: CampaignService = Game.campaign
	if _clock and cs and cs.active:
		_clock.text = "Day %d · %s" % [cs.clock.day, ["daylight", "dusk", "night"][cs.clock.phase()]]
	var wall: CameraWall = Game.tv
	if _status and app == "Cameras" and wall:
		_status.text = ("Focus: %s %s · LIVE · right-click or Wall (4) to go back" % [wall.cam_id(wall.focus_index), wall.cam_name(wall.focus_index)]) if wall.mode == "focus" else "Wall: four live cameras, one swaps every %s · click a feed to focus it%s" % ["(frozen)" if wall.interval <= 0.0 else "%d s" % int(wall.interval), " · mics muted" if wall.mic_muted else ""]


func capture() -> Dictionary:
	return {"app": app, "powered": powered}


func restore(d: Dictionary) -> void:
	open_app(str(d.get("app", "Cameras")) if APPS.has(str(d.get("app", ""))) else "Cameras")
	if bool(d.get("powered", true)) != powered:
		set_power(bool(d.get("powered", true)))
