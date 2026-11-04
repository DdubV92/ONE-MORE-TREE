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
##   Supplier - Phase 14: the camp supplier (real Supplier/Equipment/Wallet:
##              catalog with exact benefits, cart, quote with payroll
##              warnings, idempotent prepaid orders, delivery status) and
##              the truck order (real VehicleService).
##   Gear     - Phase 14: your kit breakdown, camp storage, issuing gear to
##              the crew (the same screen as the tool rack).
##   Mail     - Phase 14: supplier notices generated from the real order
##              records only (company/personal mail arrives in Phase 17).
##   News, Forums, Recordings - labelled "later update" placeholders
##              (Phases 17/19); they never show fake content.
## A small quad inset keeps the cameras at the edge of attention in other
## apps (same four-feed budget: it is the same composite texture).
## Live: time keeps running while you use it; the real pause menu pauses.

signal app_changed(app: String)

const SIZE := Vector2i(1024, 576)
const APPS := ["Cameras", "Supplier", "Gear", "Mail", "News", "Forums", "Recordings"]
const LATER := {
	"News": "Regional news arrives in a later update (Phase 17).",
	"Forums": "The community forums arrive in a later update (Phase 17).",
	"Recordings": "The camera recording archive arrives in a later update (Phase 19). Nothing is being recorded yet.",
}

var monitor: Node3D
var screen: MeshInstance3D
var vp: SubViewport
var overlay: CanvasLayer
var view: TextureRect
var forwarded := 0
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
var cart: Array = []                # Supplier cart lines {"key", "qty"}
var _req := [""]                    # current order request id (idempotency)
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
	# The desktop viewport is NOT inside a container (a hidden container
	# would stop it rendering on the in-world monitor). The seated overlay
	# shows its texture and forwards mouse input into it.
	vp = SubViewport.new()
	vp.size = SIZE
	vp.disable_3d = true
	vp.handle_input_locally = true
	vp.gui_embed_subwindows = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	view = TextureRect.new()
	view.texture = vp.get_texture()
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	view.anchor_left = 0.02
	view.anchor_top = 0.06
	view.anchor_right = 0.72
	view.anchor_bottom = 0.86
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	view.gui_input.connect(_forward_input)
	overlay.add_child(view)
	_build_shell()
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/tv_screen.gdshader")
	mat.set_shader_parameter("feed", vp.get_texture())
	mat.set_shader_parameter("gain", 0.5)
	mat.set_shader_parameter("powered", 1.0)
	screen.material_override = mat
	open_app("Cameras")


## Overlay -> desktop: mouse events are re-expressed in desktop pixels.
func _forward_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouse):
		return
	var e := ev.duplicate() as InputEventMouse
	e.position = to_desktop(e.position, view.size)
	if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and monitor and SoundService.instance() != null:
		# Phase 15: the real mouse on the desk (quiet, local, never relayed).
		SoundService.play("ui.click", monitor.global_position + Vector3(0.25, -0.35, 0.2), {"emit": false})
	vp.push_input(e, true)
	forwarded += 1
	view.accept_event()


## Point in the overlay rect -> desktop pixel (aspect-kept letterbox).
static func to_desktop(p: Vector2, rect: Vector2) -> Vector2:
	var ar := float(SIZE.x) / float(SIZE.y)
	var w := minf(rect.x, rect.y * ar)
	var h := w / ar
	var o := (rect - Vector2(w, h)) * 0.5
	return (p - o) / Vector2(w, h) * Vector2(SIZE)


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
		"Supplier", "Gear", "Mail":
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
	if _shop_box == null or not is_instance_valid(_shop_box):
		return
	for c in _shop_box.get_children():
		c.queue_free()
	var st := func(t: String) -> void:
		if _status:
			_status.text = t
	match app:
		"Supplier":
			GearPanel.build_supplier(_shop_box, cart, _req, st, _refresh_shop)
		"Gear":
			GearPanel.build_gear(_shop_box, st, _refresh_shop)
		"Mail":
			_build_mail()


## Supplier notices derived from the order records (nothing invented).
func _build_mail() -> void:
	_shop_box.add_child(UITheme.label("Camp Mail", 20, UITheme.ACCENT))
	var cs: CampaignService = Game.campaign
	if cs == null or not cs.active or cs.supplier == null or cs.supplier.orders.is_empty():
		_shop_box.add_child(UITheme.label("No messages. Supplier confirmations and delivery notices appear here. (Company and personal mail arrives in a later update.)", 15, UITheme.MUTED))
		return
	for i in range(cs.supplier.orders.size() - 1, -1, -1):
		var o: Dictionary = cs.supplier.orders[i]
		var parts := PackedStringArray()
		for ln in o.lines:
			parts.append("%d x %s" % [int(ln.qty), str(GearCatalog.def(str(ln.key)).name)])
		var body := "From: Camp Supply\nRe: order %s (day %d, %s)\n%s - $%s paid (%s).\nStatus: %s" % [str(o.id), int(o.placed.day), Supplier.hour_words(float(o.placed.t)), ", ".join(parts), Money.format_cents(int(o.total)), str(o.tx), cs.supplier.state_words(o)]
		var l := UITheme.label(body, 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		_shop_box.add_child(l)


# ------------------------------------------------------------ seat + glance

func sit(on: bool) -> void:
	seated = on
	glancing = false
	_update_overlay()
	if on and app in ["Supplier", "Gear", "Mail"]:
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
	var a := str(d.get("app", "Cameras"))
	if a == "Shop":
		a = "Supplier"          # Phase 11-13 saves
	open_app(a if APPS.has(a) else "Cameras")
	if bool(d.get("powered", true)) != powered:
		set_power(bool(d.get("powered", true)))
