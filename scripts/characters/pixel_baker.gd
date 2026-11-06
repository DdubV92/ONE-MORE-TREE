class_name PixelBaker
extends Node
## Phase 24 HD-2D: bakes a character's REAL rig into directional pixel
## sprite strips at runtime (replacement hires are generated from a seed, so
## sprites cannot be pre-authored). A private World3D holds 8 copies of the
## actor (one per facing, 45 deg apart) for albedo and 8 for view-space
## normals; two orthographic cameras capture a whole 8-direction strip per
## animation frame. Clips bake lazily, one frame per rendered frame, and the
## actor shows its 3D model until its clip is ready.

const CELL := Vector2i(56, 64)          # pixels per facing per frame (humans)
const CELL_DOG := Vector2i(40, 24)      # the dog: 1.7 m x 1.0 m at the same texel size
const PX_M := 0.0433                    # metres per sprite pixel (~4.3 cm)
const FOOT_MARGIN := 0.1                # metres below the feet in a cell
const FPS := 8.0
const MAX_FRAMES := 12
const DIRS := 8
const LAYER_ALBEDO := 1 << 19
const LAYER_NORMAL := 1 << 20

static var _inst: PixelBaker

var _vp_a: SubViewport
var _vp_n: SubViewport
var _root: Node3D
var _queue: Array = []          # [{actor, key, clip, carry}]
var _busy := false
var baked_clips := 0


static func instance() -> PixelBaker:
	if _inst == null or not is_instance_valid(_inst):
		var tree := Engine.get_main_loop() as SceneTree
		if tree == null:
			return null
		_inst = PixelBaker.new()
		_inst.name = "PixelBaker"
		tree.root.add_child.call_deferred(_inst)
	return _inst


static func cell_size_m(cell := CELL) -> Vector2:
	return Vector2(cell) * PX_M


static func cell_for(src: Node) -> Vector2i:
	return CELL_DOG if src is DogCharacter else CELL


func _ready() -> void:
	var size := Vector2i(CELL.x * DIRS, CELL.y)
	_vp_a = _make_vp(size, true)
	_vp_n = _make_vp(size, false)
	_vp_a.own_world_3d = true
	_vp_a.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	add_child(_vp_a)
	_root = Node3D.new()
	_root.name = "BakeStage"
	_vp_a.add_child(_root)
	add_child(_vp_n)
	_vp_n.world_3d = _vp_a.find_world_3d()
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	var we := WorldEnvironment.new()
	we.environment = env
	_root.add_child(we)
	_add_cam(_vp_a, LAYER_ALBEDO)
	_add_cam(_vp_n, LAYER_NORMAL)


func _make_vp(size: Vector2i, _albedo: bool) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	vp.positional_shadow_atlas_size = 0
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.disable_3d = false
	return vp


func _add_cam(vp: SubViewport, mask: int) -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = float(CELL.y) * PX_M
	cam.near = 0.1
	cam.far = 40.0
	cam.cull_mask = mask
	cam.position = Vector3(0.0, cam.size * 0.5 - FOOT_MARGIN, 12.0)
	cam.current = true
	vp.add_child(cam)


## Queue a clip bake for `actor` (a PixelActor). `carry` holds the two grip
## points in the actor's local space when the carry IK pose applies.
func request(actor: Node, key: String, clip: String, carry: Array) -> void:
	for q in _queue:
		if q.actor == actor and q.key == key:
			return
	_queue.append({"actor": actor, "key": key, "clip": clip, "carry": carry})
	if not _busy:
		_run.call_deferred()


func pending() -> int:
	return _queue.size() + (1 if _busy else 0)


func _run() -> void:
	if _busy or not is_inside_tree():
		return
	_busy = true
	while not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		if not is_instance_valid(job.actor):
			continue
		await _bake(job)
	_busy = false


func _bake(job: Dictionary) -> void:
	var actor: Node = job.actor
	var src: Node3D = actor.get("character")
	if src == null or not is_instance_valid(src) or not (src.get("anim") as AnimationPlayer).has_animation(str(job.clip)):
		if is_instance_valid(actor):
			actor.call("bake_failed", str(job.key))
		return
	var cell := cell_for(src)
	_frame_for(cell)
	var all: Array = _copies_for(actor, src)
	for c in all:
		(c as Node3D).visible = true
	var src_anim: AnimationPlayer = src.get("anim")
	var clip := str(job.clip)
	var length := src_anim.get_animation(clip).length
	var looped := src_anim.get_animation(clip).loop_mode != Animation.LOOP_NONE
	var frames := clampi(int(ceil(length * FPS)), 1, MAX_FRAMES)
	var step := length / float(frames) if looped else (length / float(maxi(frames - 1, 1)))
	var img_a := Image.create(cell.x * DIRS, cell.y * frames, false, Image.FORMAT_RGBA8)
	var img_n := Image.create(cell.x * DIRS, cell.y * frames, false, Image.FORMAT_RGBA8)
	for c in all:
		c.call("play", clip, 0.0)
	for f in frames:
		var t := minf(step * f, length)
		for c in all:
			(c.get("anim") as AnimationPlayer).seek(t, true)
			if not c is HumanCharacter:
				continue
			var hc := c as HumanCharacter
			hc.arm_ik = clip == "swing" or clip == "saw"
			if hc.arm_ik:
				hc.axe_rig.visible = true
				hc.call("_solve_arms")
			elif (job.carry as Array).size() == 2:
				hc.carry_grips = [hc.to_global(job.carry[0]), hc.to_global(job.carry[1])]
				hc.call("_solve_carry")
		_vp_a.render_target_update_mode = SubViewport.UPDATE_ONCE
		_vp_n.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		if not is_instance_valid(actor):
			break
		var ia := _vp_a.get_texture().get_image()
		var inn := _vp_n.get_texture().get_image()
		ia.convert(Image.FORMAT_RGBA8)
		inn.convert(Image.FORMAT_RGBA8)
		img_a.blit_rect(ia, Rect2i(Vector2i.ZERO, ia.get_size()), Vector2i(0, f * cell.y))
		img_n.blit_rect(inn, Rect2i(Vector2i.ZERO, inn.get_size()), Vector2i(0, f * cell.y))
	for c in all:
		if is_instance_valid(c):
			(c as Node3D).visible = false
	if is_instance_valid(actor):
		baked_clips += 1
		actor.call("bake_done", str(job.key), ImageTexture.create_from_image(img_a), ImageTexture.create_from_image(img_n), frames, looped, length)


## Viewport/camera framing for a cell size (humans and the dog differ).
var _cur_cell := Vector2i.ZERO


func _frame_for(cell: Vector2i) -> void:
	if cell == _cur_cell:
		return
	_cur_cell = cell
	for vp in [_vp_a, _vp_n]:
		vp.size = Vector2i(cell.x * DIRS, cell.y)
		var cam: Camera3D = vp.get_camera_3d()
		cam.size = float(cell.y) * PX_M
		cam.position = Vector3(0.0, cam.size * 0.5 - FOOT_MARGIN, 12.0)


## The 16 posing copies (8 albedo + 8 normal) for one actor, built once
## and reused for every clip (rebuilding rigs per clip would hitch). Freed
## with the actor; rebuilt if its look or tool tier changes.
var _sets := {}       # actor instance id -> {sig, copies}


func _copies_for(actor: Node, src: Node3D) -> Array:
	var id := actor.get_instance_id()
	var sig := ("%d|%s" % [(src as HumanCharacter).appearance.get_instance_id(), (src as HumanCharacter).axe_tier]) if src is HumanCharacter else "dog"
	if _sets.has(id) and str(_sets[id].sig) == sig:
		var ok := true
		for c in _sets[id].copies:
			ok = ok and is_instance_valid(c)
		if ok:
			return _sets[id].copies
	release(actor)
	var nmat := ShaderMaterial.new()
	nmat.shader = load("res://shaders/bake_normals.gdshader")
	var w := cell_size_m(cell_for(src)).x
	var out: Array = []
	for pass_i in 2:
		for k in DIRS:
			var c: Node3D
			if src is HumanCharacter:
				var hc := HumanCharacter.new()
				hc.appearance = (src as HumanCharacter).appearance
				hc.axe_tier = (src as HumanCharacter).axe_tier
				c = hc
			else:
				var dc := DogCharacter.new()
				dc.fur = (src as DogCharacter).fur
				dc.saddle = (src as DogCharacter).saddle
				dc.cream = (src as DogCharacter).cream
				c = dc
			c.process_mode = Node.PROCESS_MODE_DISABLED
			_root.add_child(c)
			c.position = Vector3((float(k) - (DIRS - 1) * 0.5) * w, 0.0, 0.0)
			c.rotation.y = -float(k) * PI * 0.25
			_set_layers(c, LAYER_ALBEDO if pass_i == 0 else LAYER_NORMAL, nmat if pass_i == 1 else null)
			c.visible = false
			out.append(c)
	_sets[id] = {"sig": sig, "copies": out}
	return out


func release(actor: Node) -> void:
	var id := actor.get_instance_id()
	if _sets.has(id):
		for c in _sets[id].copies:
			if is_instance_valid(c):
				c.queue_free()
		_sets.erase(id)


func _set_layers(n: Node, layer: int, mat: Material) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = layer
	if n is GeometryInstance3D and mat != null:
		(n as GeometryInstance3D).material_override = mat
	for c in n.get_children():
		_set_layers(c, layer, mat)
