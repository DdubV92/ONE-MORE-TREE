class_name ReferenceCove
extends Node3D
## Phase 24 reference fixture: the owner's target painting rebuilt as a
## small, real, walkable place on the island (island r2, a forested cove at
## the western shore). Real terrain, real trees (choppable), real sea and
## surf; the fixture only adds the camp dressing and the staged actors.
##
## Layout is authored in a site frame: x = right, z = forward of the
## reference view (camp on the left, beach curving off to the right).
## Bookmarks: "ref_match" (fixed comparison camera) and "ref_fp" (first
## person at standing eye height by the foreground tree).

const SITE := Vector2(-566.0, -281.0)
const HEADING_DEG := 305.0
## "dressed" (default) or "blockout" (REF_STAGE=blockout): silhouettes only.
static var stage := "dressed"

var frame_o := Vector3.ZERO
var frame_f := Vector3.FORWARD
var frame_r := Vector3.RIGHT
var conflicts: Array = []


static func frame() -> Dictionary:
	var a := deg_to_rad(HEADING_DEG)
	var f := Vector3(sin(a), 0.0, cos(a)).normalized()
	var r := f.cross(Vector3.UP).normalized()
	var o := Vector3(SITE.x, 0.0, SITE.y)
	o.y = World.height_at(o.x, o.z)
	return {"o": o, "f": f, "r": r}


## World position of a frame point (x right, z forward), snapped to ground.
static func at(x: float, z: float, up := 0.0) -> Vector3:
	var fr := frame()
	var p: Vector3 = fr.o + fr.r * x + fr.f * z
	p.y = World.height_at(p.x, p.z) + up
	return p


static func ensure(world: Node) -> ReferenceCove:
	var existing := world.get_node_or_null("ReferenceCove")
	if existing:
		return existing
	var rc := ReferenceCove.new()
	rc.name = "ReferenceCove"
	world.add_child(rc)
	return rc


func _ready() -> void:
	var fr := frame()
	frame_o = fr.o
	frame_f = fr.f
	frame_r = fr.r
	if OS.has_environment("REF_STAGE"):
		stage = OS.get_environment("REF_STAGE")
	if stage == "blockout":
		_build_blockout()
	else:
		_build_dressed()
	_report_conflicts()


func _yaw_facing(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)


func _box(x: float, z: float, size: Vector3, col: Color, yaw_extra := 0.0, up := 0.0, name := "") -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	var p := at(x, z, size.y * 0.5 + up)
	var mi := BuildKit.box(self, size, p - global_position, m, true, _yaw_facing(frame_f) + yaw_extra, name)
	_check(p, maxf(size.x, size.z) * 0.5, name)
	return mi


func _cyl(x: float, z: float, r: float, h: float, col: Color, up := 0.0, name := "") -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	var p := at(x, z, h * 0.5 + up)
	var mi := BuildKit.cylinder(self, r, h, p - global_position, m, true, 12)
	mi.name = name if name != "" else mi.name
	_check(p, r, name)
	return mi


func _check(p: Vector3, radius: float, what: String) -> void:
	for i in World.tree_count():
		if World.removed_trees.has(int(World.trees.id[i])):
			continue
		var d := Vector2(World.trees.x[i] - p.x, World.trees.z[i] - p.z).length()
		if d < radius + 0.6:
			conflicts.append("%s overlaps tree #%d (%.1f m)" % [what, int(World.trees.id[i]), d])


func _report_conflicts() -> void:
	for c in conflicts:
		push_warning("ReferenceCove: " + c)
	print("ReferenceCove %s built at %s heading %.0f, %d tree conflicts" % [stage, SITE, HEADING_DEG, conflicts.size()])


# ------------------------------------------------------------- blockout

func _build_blockout() -> void:
	# Camper (left midground): long side toward the view, door + windows.
	_box(-5.6, 9.5, Vector3(5.6, 2.4, 2.3), Color(0.86, 0.8, 0.68), 0.0, 0.35, "Camper")
	# Fire ring and chair (left of centre), worker stump + woodpile (centre).
	_cyl(-3.0, 6.2, 0.7, 0.25, Color(0.4, 0.38, 0.36), 0.0, "FireRing")
	_box(-2.4, 9.0, Vector3(0.6, 0.9, 0.6), Color(0.7, 0.18, 0.12), 0.0, 0.0, "Chair")
	_cyl(1.3, 7.4, 0.36, 0.5, Color(0.55, 0.38, 0.22), 0.0, "Stump")
	_box(2.9, 8.6, Vector3(3.2, 1.3, 1.1), Color(0.6, 0.42, 0.25), 0.0, 0.0, "Woodpile")
	# Worker and dog stand-ins (capsules), replaced by pixel actors.
	_cyl(0.4, 7.2, 0.25, 1.75, Color(0.7, 0.15, 0.12), 0.0, "WorkerBlock")
	_cyl(-1.3, 6.4, 0.22, 0.55, Color(0.9, 0.86, 0.8), 0.0, "DogBlock")
	# Split-rail fence between camp and beach (front edge + beach side).
	for k in 9:
		var t := float(k) / 8.0
		_cyl(lerpf(-4.0, 4.6, t), lerpf(3.6, 4.6, t), 0.07, 1.1, Color(0.42, 0.3, 0.2), 0.0, "FencePost")
	for k in 5:
		var t2 := float(k) / 4.0
		_cyl(lerpf(4.6, 6.2, t2), lerpf(4.6, 10.5, t2), 0.07, 1.1, Color(0.42, 0.3, 0.2), 0.0, "FencePost")
	# Foreground: thick conifer trunk (left), mossy rocks and ferns.
	_cyl(-4.6, -3.2, 0.55, 9.0, Color(0.38, 0.24, 0.16), 0.0, "ForegroundTrunk")
	_box(-1.6, -1.4, Vector3(1.6, 0.9, 1.3), Color(0.32, 0.36, 0.26), 0.4, 0.0, "MossRock")
	_box(0.8, -2.2, Vector3(1.2, 0.7, 1.0), Color(0.32, 0.36, 0.26), -0.3, 0.0, "MossRock2")
	for k in 6:
		_cyl(-2.8 + k * 0.5, -0.6 - (k % 2) * 0.6, 0.45, 0.5, Color(0.3, 0.5, 0.2), 0.0, "FernBlock")
	# Comparison Terror slot between trunks in the dark forest behind camp.
	_cyl(1.2, 26.0, 0.25, 2.7, Color(0.03, 0.03, 0.04), 0.0, "TerrorSlot")


# ------------------------------------------------------------- dressed
## Positions (frame metres, x right / z forward) shared by the dressing.
const P_CAMPER := Vector2(-5.6, 9.5)
const P_FIRE := Vector2(-3.0, 6.2)
const P_CHAIR := Vector2(-2.5, 8.9)
const P_STUMP := Vector2(1.3, 7.4)
const P_WOODPILE := Vector2(2.9, 7.9)
const P_WORKER := Vector2(0.55, 7.1)
const P_DOG := Vector2(-1.3, 6.3)
const P_TERROR := Vector2(3.6, 24.5)
const P_TRUNK := Vector2(-3.9, 0.2)
## Second foreground conifer: frames the left edge of Reference Match and
## stands beside the First-Person Shoreline start.
const P_TRUNK2 := Vector2(-0.4, -3.4)

var worker: HumanCharacter
var dog: DogCharacter
var terror: Node3D
var lamp_lights: Array[OmniLight3D] = []


func _tex_mat(tex: String, tint := Color.WHITE, scale := 1.0) -> StandardMaterial3D:
	var base := "res://assets/polyhaven/textures/%s/%s" % [tex, tex]
	var m := StandardMaterial3D.new()
	if ResourceLoader.exists(base + "_diff.jpg"):
		m.albedo_texture = load(base + "_diff.jpg")
	if ResourceLoader.exists(base + "_nor_gl.jpg"):
		m.normal_enabled = true
		m.normal_texture = load(base + "_nor_gl.jpg")
	m.albedo_color = tint
	m.roughness = 0.9
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * scale
	return m


## Yaw so a prop's local +X runs along the frame's right axis.
func _yaw() -> float:
	return atan2(frame_f.x, frame_f.z)


func _node_at(x: float, z: float, name: String, up := 0.0) -> Node3D:
	var n := Node3D.new()
	n.name = name
	add_child(n)
	n.global_position = at(x, z, up)
	n.rotation.y = _yaw()
	return n


func _build_dressed() -> void:
	_paint_beach()
	_build_camper()
	_build_woodpile()
	_build_stump_and_fire()
	_build_fence()
	_build_foreground()
	_build_bushes()
	_build_actors()
	_build_terror()
	_build_richness()


# ---- camper: weathered cream-and-rust travel trailer
func _build_camper() -> void:
	var c := _node_at(P_CAMPER.x, P_CAMPER.y, "Camper", 0.42)
	_check(c.global_position, 2.8, "Camper")
	var paint := ShaderMaterial.new()
	paint.shader = load("res://shaders/worn_paint.gdshader")
	paint.set_shader_parameter("rust_line", -0.55)
	paint.set_shader_parameter("wear", 0.12)
	paint.set_shader_parameter("rust", Color(0.42, 0.24, 0.14))
	var roof_paint := ShaderMaterial.new()
	roof_paint.shader = paint.shader
	roof_paint.set_shader_parameter("wear", 0.2)
	roof_paint.set_shader_parameter("rust_line", -9.0)
	roof_paint.set_shader_parameter("paint", Color(0.84, 0.8, 0.72))
	var band := ShaderMaterial.new()
	band.shader = paint.shader
	band.set_shader_parameter("paint", Color(0.62, 0.17, 0.11))
	band.set_shader_parameter("rust", Color(0.32, 0.12, 0.07))
	band.set_shader_parameter("rust_line", -0.2)
	var L := 5.4
	var W := 2.3
	BuildKit.box(c, Vector3(L, 1.75, W), Vector3(0, 0.5, 0), paint, true)
	BuildKit.box(c, Vector3(L + 0.02, 0.62, W + 0.02), Vector3(0, -0.06, 0), band, false)
	# Rounded roof: a half cylinder along the length.
	var roof := BuildKit.cylinder(c, W * 0.5, L, Vector3(0, 1.37, 0), roof_paint, false, 20)
	roof.rotation.z = PI * 0.5
	roof.scale = Vector3(1.0, 1.0, 0.32)
	var trim := StandardMaterial3D.new()
	trim.albedo_color = Color(0.78, 0.78, 0.76)
	trim.metallic = 0.8
	trim.roughness = 0.35
	BuildKit.box(c, Vector3(L + 0.04, 0.05, W + 0.04), Vector3(0, 0.27, 0), trim, false)
	# Amber windows on the side facing the clearing (+Z side of the trailer
	# faces back toward the camera after the yaw: use -Z local = toward camera).
	var side := -W * 0.5 - 0.02
	var amber := StandardMaterial3D.new()
	amber.albedo_color = Color(1.0, 0.72, 0.38)
	amber.emission_enabled = true
	amber.emission = Color(1.0, 0.58, 0.24)
	amber.emission_energy_multiplier = 1.6
	for wx in [-1.6, 0.0]:
		BuildKit.box(c, Vector3(1.05, 0.62, 0.04), Vector3(wx, 0.85, side), trim, false)
		BuildKit.box(c, Vector3(0.95, 0.52, 0.05), Vector3(wx, 0.85, side - 0.01), amber, false)
		var wl := OmniLight3D.new()
		wl.light_color = Color(1.0, 0.62, 0.3)
		wl.light_energy = 0.45
		wl.omni_range = 3.0
		wl.omni_attenuation = 2.0
		wl.shadow_enabled = false
		c.add_child(wl)
		wl.position = Vector3(wx, 0.35, side - 1.5)
	# Door with a small window, steps.
	var door := _tex_mat("weathered_planks", Color(0.75, 0.55, 0.38), 2.0)
	BuildKit.box(c, Vector3(0.78, 1.65, 0.06), Vector3(1.55, 0.42, side), door, false)
	BuildKit.box(c, Vector3(0.36, 0.3, 0.03), Vector3(1.55, 0.95, side - 0.04), amber, false)
	var wood := _tex_mat("weathered_planks", Color(0.6, 0.48, 0.38), 2.0)
	BuildKit.box(c, Vector3(0.9, 0.16, 0.42), Vector3(1.55, -0.3, side - 0.3), wood, true)
	BuildKit.box(c, Vector3(0.9, 0.16, 0.42), Vector3(1.55, -0.12, side - 0.55), wood, false)
	# Practical lamp by the door: a lantern with a warm, local pool.
	var lan := BuildKit.prop(c, "wooden_lantern_01", Vector3(2.2, 1.15, side - 0.12), 0.0, 1.1)
	lan.name = "Lantern"
	var ll := OmniLight3D.new()
	ll.light_color = Color(1.0, 0.6, 0.28)
	ll.light_energy = 1.3
	ll.omni_range = 4.5
	ll.omni_attenuation = 2.0
	ll.shadow_enabled = true
	c.add_child(ll)
	ll.position = Vector3(2.2, 1.2, side - 0.9)
	lamp_lights.append(ll)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	bulb.mesh = sm
	var bm := StandardMaterial3D.new()
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.66, 0.3)
	bm.emission_energy_multiplier = 6.0
	bulb.material_override = bm
	c.add_child(bulb)
	bulb.position = Vector3(2.2, 1.27, side - 0.12)
	# Stovepipe with smoke rising from the roof.
	var pipe := StandardMaterial3D.new()
	pipe.albedo_color = Color(0.2, 0.19, 0.18)
	pipe.metallic = 0.6
	BuildKit.cylinder(c, 0.07, 0.7, Vector3(-1.9, 1.85, 0.3), pipe, false, 10)
	c.add_child(_smoke(Vector3(-1.9, 2.25, 0.3)))
	# Crates and a red plaid chair by the steps.
	BuildKit.prop(c, "wooden_crate_01", Vector3(-2.4, -0.42, side - 0.5), 0.3, 0.8)
	var chair := _node_at(P_CHAIR.x, P_CHAIR.y, "Chair")
	var plaid := StandardMaterial3D.new()
	plaid.albedo_texture = CharMeshKit.plaid_texture()
	plaid.albedo_color = Color(1.25, 0.32, 0.25)
	plaid.uv1_triplanar = true
	plaid.uv1_scale = Vector3.ONE * 6.0
	plaid.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	BuildKit.box(chair, Vector3(0.62, 0.08, 0.55), Vector3(0, 0.42, 0), plaid, true)
	BuildKit.box(chair, Vector3(0.62, 0.6, 0.08), Vector3(0, 0.72, 0.26), plaid, false)
	for lx in [-0.27, 0.27]:
		for lz in [-0.22, 0.22]:
			BuildKit.box(chair, Vector3(0.04, 0.42, 0.04), Vector3(lx, 0.21, lz), wood, false)


func _smoke(pos: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "StoveSmoke"
	p.position = pos
	p.amount = 28
	p.lifetime = 7.0
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 12, 8))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 8.0
	pm.initial_velocity_min = 0.45
	pm.initial_velocity_max = 0.7
	pm.gravity = Vector3(0.18, 0.06, 0.05)
	pm.scale_min = 0.5
	pm.scale_max = 0.9
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.3))
	curve.add_point(Vector2(1, 2.4))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.12, 0.6, 1.0])
	grad.colors = PackedColorArray([Color(0.75, 0.72, 0.7, 0.0), Color(0.78, 0.76, 0.74, 0.32), Color(0.8, 0.78, 0.76, 0.14), Color(0.8, 0.8, 0.8, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var quad := QuadMesh.new()
	quad.size = Vector2(0.8, 0.8)
	var m := FirePit._billboard_mat(FirePit._sprite("smoke"), false)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	quad.material = m
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


# ---- tightly stacked logs with strapping
func _build_woodpile() -> void:
	var w := _node_at(P_WOODPILE.x, P_WOODPILE.y, "Woodpile")
	_check(w.global_position, 1.6, "Woodpile")
	var bark := _tex_mat("pine_bark", Color(0.85, 0.7, 0.58), 1.5)
	var grain := ShaderMaterial.new()
	grain.shader = load("res://shaders/end_grain.gdshader")
	var r := 0.17
	var length := 2.7
	var rows := [6, 5, 4, 3]
	for row in rows.size():
		var n: int = rows[row]
		for k in n:
			var z := (float(k) - (n - 1) * 0.5) * r * 2.02
			var y := r + row * r * 1.74
			var log := BuildKit.cylinder(w, r * (0.92 + 0.08 * sin(float(k * 7 + row))), length, Vector3(0, y, z), bark, row == 0, 10)
			log.rotation.z = PI * 0.5
			for e in [-1.0, 1.0]:
				var cap := BuildKit.cylinder(w, r * 0.95, 0.02, Vector3(e * length * 0.5, y, z), grain, false, 12)
				cap.rotation.z = PI * 0.5
	var strap := StandardMaterial3D.new()
	strap.albedo_color = Color(0.55, 0.42, 0.26)
	for sx in [-0.7, 0.7]:
		BuildKit.box(w, Vector3(0.05, 1.3, 2.25), Vector3(sx, 0.62, 0), strap, false)
	var col := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(length, 1.3, 2.1)
	cs.shape = bs
	col.add_child(cs)
	w.add_child(col)
	col.position = Vector3(0, 0.65, 0)


# ---- stump (with a split log on it) and the stone fire ring
func _build_stump_and_fire() -> void:
	var st := _node_at(P_STUMP.x, P_STUMP.y, "ChoppingStump")
	BuildKit.prop(st, "tree_stump_01", Vector3.ZERO, 0.4, 1.0, Vector3(0.7, 0.5, 0.7))
	var f := FirePit.new()
	f.name = "CampFire"
	f.radius = 0.75
	add_child(f)
	f.global_position = at(P_FIRE.x, P_FIRE.y)


# ---- split-rail fence between the clearing and the beach
func _build_fence() -> void:
	var wood := _tex_mat("weathered_planks", Color(0.66, 0.52, 0.4), 2.5)
	# Front run has a walk-through gap (camp path); beach-side run closes it.
	var runs := [[Vector2(-4.2, 3.6), Vector2(-0.9, 3.95)], [Vector2(1.3, 4.2), Vector2(4.6, 4.6)], [Vector2(4.6, 4.6), Vector2(6.3, 10.8)]]
	for run in runs:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var n := int(ceil(a.distance_to(b) / 2.2))
		var prev := Vector3.INF
		for k in n + 1:
			var t := float(k) / n
			var q := a.lerp(b, t)
			var p := at(q.x, q.y)
			BuildKit.box(self, Vector3(0.13, 1.15, 0.13), p + Vector3(0, 0.55, 0) - global_position, wood, true, _yaw() + 0.05 * sin(k * 3.1))
			if prev != Vector3.INF:
				for hgt in [0.48, 0.92]:
					var a3 := prev + Vector3(0, hgt, 0)
					var b3 := p + Vector3(0, hgt, 0)
					var rail := BuildKit.box(self, Vector3(0.1, 0.1, a3.distance_to(b3) + 0.2), (a3 + b3) * 0.5 - global_position, wood, false)
					rail.look_at_from_position(rail.position, b3 - global_position, Vector3.UP)
			prev = p


# ---- near-left foreground: thick conifer trunk, ferns, mossy rocks
func _build_foreground() -> void:
	var bark := _tex_mat("pine_bark", Color(0.92, 0.66, 0.5), 0.6)
	# A few low drooping boughs into frame (cards from the tree builder look).
	var needle := StandardMaterial3D.new()
	needle.albedo_color = Color(0.2, 0.3, 0.14)
	needle.roughness = 0.9
	var trunks := [[P_TRUNK, 0.62, 14.0, 1.2], [P_TRUNK2, 0.7, 16.0, 2.6]]
	for ti in trunks.size():
		var td: Array = trunks[ti]
		var tp: Vector2 = td[0]
		var trunk := _node_at(tp.x, tp.y, "ForegroundConifer" if ti == 0 else "ForegroundConifer%d" % (ti + 1))
		BuildKit.cylinder(trunk, float(td[1]), float(td[2]), Vector3(0, float(td[2]) * 0.5, 0), bark, true, 16, 0.42)
		for k in 5:
			var a := float(td[3]) + k * 0.5
			var bough := BuildKit.box(trunk, Vector3(2.6, 0.08, 0.9), Vector3(cos(a) * 1.4, 7.5 + k * 1.2, sin(a) * 1.4), needle, false, -a)
			bough.rotation.z = -0.25
	var rocks := RockBuilder.build_variants(4)
	var rmat := RockBuilder.material()
	var stones := [[-2.2, 1.4, 1.3, 0.4], [0.6, 0.9, 0.95, -0.7], [-3.0, 3.4, 0.8, 1.6], [5.6, 2.6, 0.75, 0.2], [7.2, 6.2, 1.1, 2.4], [6.6, 0.8, 0.6, 1.0], [3.6, 1.6, 0.5, 2.0], [4.2, 2.2, 1.4, 0.3], [6.0, 3.2, 0.9, 1.2], [2.6, 3.4, 0.7, 2.2], [2.4, 0.9, 1.5, 0.9], [3.8, 1.9, 1.0, 2.8]]
	for i in stones.size():
		var sd: Array = stones[i]
		var r := MeshInstance3D.new()
		r.name = "MossRock%d" % i
		r.mesh = rocks[i % rocks.size()]
		r.material_override = rmat
		add_child(r)
		r.global_position = at(sd[0], sd[1], -0.15)
		r.scale = Vector3.ONE * float(sd[2])
		r.rotation.y = float(sd[3])
	# Layered ferns, densest in the near-left corner and along the fence.
	var ferns := [[-2.9, 1.6, 1.6], [-1.2, 2.0, 1.3], [-2.4, 3.0, 1.4], [-3.6, 2.2, 1.5], [0.0, 1.8, 1.1], [-4.2, 4.0, 1.2], [-1.6, 3.4, 1.0], [1.4, 3.0, 0.9], [3.4, 3.6, 0.9], [5.2, 4.0, 1.0], [-5.6, 5.4, 1.1], [-7.4, 8.4, 1.3], [-0.4, 3.2, 0.8], [2.4, 2.4, 0.8], [-3.2, 5.0, 0.9], [4.4, 2.2, 0.7]]
	# Big fronds crowding the near-left corner (the painting's foreground).
	ferns.append_array([[-1.4, 0.4, 2.3], [-2.6, 0.2, 2.6], [-0.2, 0.6, 1.9], [-3.4, 1.0, 2.2], [0.9, 0.3, 1.6]])
	# ...and the Reference Match corner by the second conifer.
	ferns.append_array([[1.4, 0.8, 2.4], [2.9, 1.5, 2.0], [1.0, 2.2, 1.8], [3.4, 2.7, 1.5], [4.4, 1.2, 1.6], [2.2, 3.0, 1.3], [0.4, 1.4, 2.1], [5.4, 2.4, 1.2]])
	for i in ferns.size():
		var fd: Array = ferns[i]
		var fp := BuildKit.prop(self, "fern_02", at(fd[0], fd[1]) - global_position, float(i) * 1.7, float(fd[2]))
		fp.name = "Fern%d" % i


# ---- red-berry bushes at the camp edge
func _build_bushes() -> void:
	var u: Node = get_parent().get("undergrowth") if get_parent() else null
	var meshes: Array = u.get("meshes") if u else []
	var berry := StandardMaterial3D.new()
	berry.albedo_color = Color(0.72, 0.08, 0.06)
	berry.roughness = 0.35
	var bushes := [[-6.6, 4.6, 1.0], [-8.4, 6.6, 0.9], [7.0, 12.4, 0.85], [-1.0, 12.6, 0.8], [-3.8, 10.8, 0.8], [5.6, 6.2, 0.7], [8.4, 2.6, 0.75], [-7.8, 10.6, 0.9], [-5.0, 2.4, 0.95]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 2411
	for i in bushes.size():
		var bd: Array = bushes[i]
		var b := _node_at(bd[0], bd[1], "BerryBush%d" % i)
		b.scale = Vector3.ONE * float(bd[2])
		if not meshes.is_empty():
			var mi := MeshInstance3D.new()
			mi.mesh = meshes[0]
			b.add_child(mi)
		for k in 26:
			var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.0, 1.0), rng.randf_range(-1, 1)).normalized()
			var be := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.035
			sm.height = 0.07
			be.mesh = sm
			be.material_override = berry
			b.add_child(be)
			be.position = Vector3(dir.x * 0.9, 1.1 + dir.y * 0.8, dir.z * 0.9)


# ---- richness pass (owner: "rich detailed look", painting as the target)
## Trailer detail (rounded ends, framed curtained windows, hitch with
## propane tanks, wheel, roof vents), hanging fence lanterns, denser ferns
## along the fence and beach edge, and dark stones under the clear shallows.
func _build_richness() -> void:
	var c := get_node_or_null("Camper") as Node3D
	if c != null:
		var L := 5.4
		var W := 2.3
		var side := -W * 0.5 - 0.02
		var paint := ShaderMaterial.new()
		paint.shader = load("res://shaders/worn_paint.gdshader")
		paint.set_shader_parameter("rust_line", -0.55)
		paint.set_shader_parameter("wear", 0.12)
		paint.set_shader_parameter("rust", Color(0.42, 0.24, 0.14))
		var band := ShaderMaterial.new()
		band.shader = paint.shader
		band.set_shader_parameter("paint", Color(0.62, 0.17, 0.11))
		band.set_shader_parameter("rust", Color(0.32, 0.12, 0.07))
		band.set_shader_parameter("rust_line", -0.2)
		var trim := StandardMaterial3D.new()
		trim.albedo_color = Color(0.8, 0.8, 0.78)
		trim.metallic = 0.8
		trim.roughness = 0.3
		var dark := StandardMaterial3D.new()
		dark.albedo_color = Color(0.08, 0.07, 0.07)
		dark.roughness = 0.9
		# Rounded vintage ends.
		for ex in [-L * 0.5, L * 0.5]:
			var cap := BuildKit.cylinder(c, W * 0.5, 1.75, Vector3(ex, 0.5, 0), paint, false, 20)
			cap.scale = Vector3(0.34, 1.0, 1.0)
			var bcap := BuildKit.cylinder(c, W * 0.5 + 0.01, 0.62, Vector3(ex, -0.06, 0), band, false, 20)
			bcap.scale = Vector3(0.35, 1.0, 1.0)
			var rcap := MeshInstance3D.new()
			var sph := SphereMesh.new()
			sph.radius = W * 0.5
			sph.height = W
			rcap.mesh = sph
			rcap.material_override = paint
			c.add_child(rcap)
			rcap.position = Vector3(ex, 1.37, 0)
			rcap.scale = Vector3(0.34, 0.32, 1.0)
		# Second chrome strip above the band, framed windows with curtains.
		BuildKit.box(c, Vector3(L + 0.04, 0.035, W + 0.04), Vector3(0, 1.28, 0), trim, false)
		var curtain := StandardMaterial3D.new()
		curtain.albedo_color = Color(0.96, 0.86, 0.66)
		curtain.emission_enabled = true
		curtain.emission = Color(1.0, 0.7, 0.4)
		curtain.emission_energy_multiplier = 0.5
		for wx in [-1.6, 0.0]:
			for cx in [-0.36, 0.36]:
				BuildKit.box(c, Vector3(0.2, 0.5, 0.02), Vector3(wx + cx, 0.86, side - 0.04), curtain, false)
			BuildKit.box(c, Vector3(0.04, 0.54, 0.03), Vector3(wx, 0.85, side - 0.045), trim, false)
			BuildKit.box(c, Vector3(1.12, 0.06, 0.1), Vector3(wx, 0.52, side - 0.05), trim, false)
		# Door frame and handle.
		BuildKit.box(c, Vector3(0.9, 0.05, 0.05), Vector3(1.55, 1.27, side - 0.03), trim, false)
		for dx in [1.12, 1.98]:
			BuildKit.box(c, Vector3(0.05, 1.7, 0.05), Vector3(dx, 0.42, side - 0.03), trim, false)
		BuildKit.box(c, Vector3(0.12, 0.04, 0.05), Vector3(1.85, 0.5, side - 0.08), trim, false)
		# Hitch A-frame with two propane tanks.
		var front := -L * 0.5 - 0.35
		for zz in [-0.45, 0.45]:
			var arm := BuildKit.box(c, Vector3(1.2, 0.08, 0.08), Vector3(front - 0.4, -0.38, zz * 0.5), dark, false)
			arm.rotation.y = -zz * 0.7
		BuildKit.cylinder(c, 0.05, 0.4, Vector3(front - 0.95, -0.55, 0), dark, false, 8)
		var tank := StandardMaterial3D.new()
		tank.albedo_color = Color(0.86, 0.84, 0.8)
		tank.roughness = 0.45
		for zz in [-0.24, 0.24]:
			BuildKit.cylinder(c, 0.17, 0.5, Vector3(front - 0.15, -0.1, zz), tank, false, 14)
			BuildKit.cylinder(c, 0.05, 0.08, Vector3(front - 0.15, 0.2, zz), trim, false, 8)
		# Wheel and wheel well.
		BuildKit.box(c, Vector3(1.0, 0.42, 0.03), Vector3(0.75, -0.18, side - 0.01), dark, false)
		var tyre := BuildKit.cylinder(c, 0.33, 0.22, Vector3(0.75, -0.42, side + 0.08), dark, false, 18)
		tyre.rotation.x = PI * 0.5
		var hub := BuildKit.cylinder(c, 0.14, 0.24, Vector3(0.75, -0.42, side + 0.07), trim, false, 12)
		hub.rotation.x = PI * 0.5
		# Roof vents.
		for vx in [-0.7, 1.0]:
			BuildKit.box(c, Vector3(0.45, 0.14, 0.45), Vector3(vx, 1.76, 0.0), trim, false)
	# Warm low-sun spill over the camp clearing (the painting lights the
	# camp, the trailer and the crew in gold although the real sun sits
	# behind the shoreline trees here): a broad, soft, shadowless fill.
	var spill := OmniLight3D.new()
	spill.name = "CampSunSpill"
	spill.light_color = Color(1.0, 0.66, 0.36)
	spill.light_energy = 0.75
	spill.omni_range = 13.0
	spill.omni_attenuation = 1.4
	spill.shadow_enabled = false
	add_child(spill)
	spill.global_position = at(2.0, 4.0, 5.5)
	# Hanging lanterns on the fence posts, each with a warm pool.
	for lp in [Vector2(-2.6, 3.75), Vector2(2.2, 4.3)]:
		var pos := at(lp.x, lp.y, 1.18) - global_position
		var lan := BuildKit.prop(self, "wooden_lantern_01", pos, 0.4, 0.9)
		lan.name = "FenceLantern"
		var ol := OmniLight3D.new()
		ol.light_color = Color(1.0, 0.6, 0.28)
		ol.light_energy = 0.9
		ol.omni_range = 3.6
		ol.omni_attenuation = 2.0
		ol.shadow_enabled = false
		add_child(ol)
		ol.position = pos + Vector3(0, 0.15, 0)
		lamp_lights.append(ol)
	# Denser ferns: along the fence, round the trailer, at the beach edge.
	var ferns := [[-3.6, 3.0, 1.3], [-2.0, 3.1, 1.1], [-0.6, 3.2, 0.9], [2.0, 3.6, 1.0], [3.4, 3.8, 1.2], [4.9, 5.4, 1.1],
		[5.6, 7.6, 1.0], [6.0, 9.6, 1.2], [-8.6, 8.8, 1.4], [-8.0, 12.0, 1.3], [-4.2, 12.4, 1.1], [-2.0, 13.6, 1.0],
		[1.4, 13.0, 1.1], [4.2, 12.6, 1.2], [9.4, 1.0, 1.0], [9.8, 6.4, 1.1], [10.4, 11.0, 0.9], [10.0, 15.6, 1.2],
		[-9.6, 5.0, 1.5], [-6.0, 1.0, 1.6], [7.4, 1.4, 1.3], [8.0, 4.6, 1.0]]
	for i in ferns.size():
		var fd: Array = ferns[i]
		var fp := BuildKit.prop(self, "fern_02", at(fd[0], fd[1]) - global_position, float(i) * 2.3, float(fd[2]))
		fp.name = "RichFern%d" % i
	# Dark stones under the clear shallows (the caustics play over them).
	var rocks := RockBuilder.build_variants(4)
	var rmat := RockBuilder.material()
	var rng := RandomNumberGenerator.new()
	rng.seed = 9061
	for i in 16:
		var fz := rng.randf_range(-6.0, 32.0)
		var fx := beach_line(fz) + rng.randf_range(0.8, 7.5)
		var sc := rng.randf_range(0.5, 1.2)
		var p := at(fx, fz)
		if p.y > World.sea_level - 0.25:
			continue
		var r := MeshInstance3D.new()
		r.name = "ShallowStone%d" % i
		r.mesh = rocks[i % rocks.size()]
		r.material_override = rmat
		add_child(r)
		r.global_position = Vector3(p.x, minf(p.y + 0.15 * sc, World.sea_level - 0.18), p.z)
		r.scale = Vector3(1.4, 0.45, 1.1) * sc
		r.rotation.y = rng.randf() * TAU


# ---- staged actors: the worker chopping at the stump, the dog watching
func _build_actors() -> void:
	worker = HumanCharacter.new()
	worker.name = "FixtureWorker"
	worker.appearance = HumanAppearance.for_employee("EMP-01", 1)
	add_child(worker)
	worker.global_position = at(P_WORKER.x, P_WORKER.y)
	var to_stump := at(P_STUMP.x, P_STUMP.y) - worker.global_position
	worker.rotation.y = atan2(-to_stump.x, -to_stump.z)
	worker.play("swing", 0.0)
	PixelActor.attach(worker)
	dog = DogCharacter.new()
	dog.name = "FixtureDog"
	add_child(dog)
	dog.global_position = at(P_DOG.x, P_DOG.y)
	var to_w := worker.global_position - dog.global_position
	dog.rotation.y = atan2(-to_w.x, -to_w.z)
	dog.play("sit", 0.0)
	PixelActor.attach(dog)


# ---- comparison Terror: a tall dark figure between the trunks
func _build_terror() -> void:
	terror = Node3D.new()
	terror.name = "ComparisonTerror"
	add_child(terror)
	terror.global_position = at(P_TERROR.x, P_TERROR.y)
	var spr := Sprite3D.new()
	spr.texture = _terror_texture()
	spr.pixel_size = 0.045
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	spr.shaded = true
	spr.offset = Vector2(0, 32)
	terror.add_child(spr)
	# The eyes are faint and self-lit: just enough to pick it out.
	var eyes := Sprite3D.new()
	eyes.texture = _terror_texture(true)
	eyes.pixel_size = 0.045
	eyes.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	eyes.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	eyes.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	eyes.shaded = false
	eyes.modulate = Color(1.6, 1.5, 1.3)
	eyes.offset = Vector2(0, 32)
	terror.add_child(eyes)
	# Scripted only for the Reference Match comparison shot; in play the
	# normal encounter director decides when anything appears here.
	terror.visible = false


static func _terror_texture(eyes_only := false) -> ImageTexture:
	var w := 16
	var h := 64
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var body := Color(0.03, 0.03, 0.035, 1.0)
	for y in h:
		for x in w:
			var cx := float(x) - 7.5
			var on := false
			if y < 9:                                  # head
				on = absf(cx) < 2.6 and y > 1
			elif y < 13:                               # neck
				on = absf(cx) < 1.2
			elif y < 36:                               # torso + arms hanging long
				var shoulder := 4.6 - float(y - 13) * 0.05
				on = absf(cx) < shoulder and not (absf(cx) > 2.6 and absf(cx) < 3.4 and y > 16)
				if absf(cx) >= 3.4 and absf(cx) < 4.6 and y > 16:
					on = true
			elif y < 44:                               # long fingers past the hips
				on = (absf(cx) > 3.6 and absf(cx) < 4.4) or absf(cx) < 2.4
			else:                                      # thin legs
				on = absf(absf(cx) - 1.4) < 0.8
			if on and not eyes_only:
				img.set_pixel(x, h - 1 - y, body)
	if eyes_only or true:
		for ex in [6, 9]:
			var c := Color(1.0, 0.96, 0.85, 1.0)
			if eyes_only:
				img.set_pixel(ex, h - 1 - 5, c)
	return ImageTexture.create_from_image(img)


## Reference Match shows the comparison figure; play hides it again.
func set_comparison(on: bool) -> void:
	if terror:
		terror.visible = on


# ------------------------------------------------------------- modes
## Reference Match: a fixed comparison camera with the scripted figure.
## Any movement key or click returns control to the first-person player.
## In play, the figure belongs to the encounter director: the fixture asks
## for a family T01 ("The Tall Woman Beyond the Trees") reservation when the
## player looks toward the treeline, and shows it only if the director
## grants one (its own budget, quiet gaps, cooldowns and nightly limits).
const TERROR_FAMILY := 0
const GLIMPSE_S := 4.5
var match_cam: Camera3D
var _glimpse_left := 0.0
var _glimpse_try := 6.0
var glimpses := 0


func enter_match() -> void:
	var vp: Dictionary = Viewpoints.all().get("ref_match", {})
	if vp.is_empty():
		return
	if match_cam == null:
		match_cam = Camera3D.new()
		match_cam.name = "ReferenceMatchCamera"
		match_cam.fov = 70.0
		match_cam.far = 6000.0
		add_child(match_cam)
	match_cam.fov = float(vp.get("fov", 70.0))
	match_cam.global_position = vp.pos
	match_cam.look_at(vp.look)
	match_cam.make_current()
	set_comparison(true)


func exit_match() -> void:
	if match_cam and match_cam.current:
		match_cam.current = false
		var pc: Camera3D = Game.player.get("camera") if Game.player else null
		if pc:
			pc.make_current()
	set_comparison(false)


func in_match() -> bool:
	return match_cam != null and match_cam.current


func _unhandled_input(event: InputEvent) -> void:
	if not in_match():
		return
	var leave: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	for a in ["move_forward", "move_back", "move_left", "move_right", "jump", "ui_cancel"]:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			leave = true
	if leave:
		exit_match()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if in_match() or terror == null:
		return
	if _glimpse_left > 0.0:
		_glimpse_left -= delta
		if _glimpse_left <= 0.0:
			terror.visible = false
			if Game.director:
				Game.director.release("REF-COVE", 900.0)
		return
	_glimpse_try -= delta
	if _glimpse_try > 0.0:
		return
	_glimpse_try = 8.0
	var cam := get_viewport().get_camera_3d()
	if cam == null or Game.director == null:
		return
	var to_t := terror.global_position - cam.global_position
	var d := to_t.length()
	if d < 10.0 or d > 45.0 or (-cam.global_basis.z).dot(to_t / d) < 0.82:
		return
	if Game.director.reserve("REF-COVE", TERROR_FAMILY, "treeline_glimpse"):
		terror.visible = true
		_glimpse_left = GLIMPSE_S
		glimpses += 1


# ------------------------------------------------------------- beach
## The cove's real shore is a rocky slope. For the reference composition the
## fixture paints the terrain's beach channel over the slope down to the
## waterline - in memory only, never in the frozen world data - so the same
## terrain and ocean shaders produce sand, wet copper sand and live swash
## (waves running up and back) here. Restored when the fixture leaves.
var _mask_backup := {}       # byte index -> original value
var _height_backup := {}     # height index -> original value
## Waterline of the fixture beach in frame x, as a function of frame z: the
## shore curves away to the right into the distance, like the painting.
static func beach_line(fz: float) -> float:
	return 17.0 + clampf((fz - 6.0) * 0.14, -1.2, 6.5)


## The real cove drops to the sea as a 1:2 rock bank. The painting has a sand
## beach and a wide turquoise shallow shelf, so the fixture *fills* the slope
## in memory (never lowers it, so trees, undergrowth and rocks stay grounded;
## rocks poke out of the sand): a gentle dry beach, a wet swash zone and a
## shallow shelf that blends back into the real seabed. Terrain rendering,
## collision, water depth, swash and surf all read the same heights, so the
## beach is real to walk on. Restored when the fixture leaves.
func _raise_beach() -> void:
	var fr := frame()
	var box := _grid_box(fr, 6.0, 46.0, -26.0, 64.0)
	var hg: PackedFloat32Array = World.height
	var sea := World.sea_level
	for j in range(box[1], box[3] + 1):
		for i in range(box[0], box[2] + 1):
			var wp := Vector3(World.origin.x + i * World.cs, 0.0, World.origin.y + j * World.cs)
			var d := wp - (fr.o as Vector3)
			var fx := d.dot(fr.r as Vector3)
			var fz := d.dot(fr.f as Vector3)
			var xl := beach_line(fz)
			var dx := fx - xl                       # + seaward
			# Dry beach 1:14 above the waterline, wet slope 1:9 below, then a
			# shallow shelf at -1.7 m that fades into the real seabed.
			var target := sea + (-dx / 10.0 if dx < 0.0 else maxf(-dx / 8.0, -1.6))
			target = minf(target, sea + 1.9)
			var w := (1.0 - smoothstep(xl + 13.0, xl + 22.0, fx)) * smoothstep(-24.0, -12.0, fz) * (1.0 - smoothstep(50.0, 62.0, fz)) * smoothstep(7.0, 10.0, fx)
			var k := j * World.W + i
			var h0 := hg[k]
			var h1 := lerpf(h0, maxf(h0, target), w)
			if h1 > h0 + 0.001:
				if not _height_backup.has(k):
					_height_backup[k] = h0
				hg[k] = h1
	World.height = hg
	var world := get_parent()
	var terrain: TerrainSystem = world.get("terrain")
	if terrain:
		terrain.refresh_collision(box[0], box[1], box[2], box[3])
	else:
		World.height_texture.update(Image.create_from_data(World.W, World.H, false, Image.FORMAT_RF, World.height.to_byte_array()))
	# Shrubs and grass that grew on the old rock bank give way to sand.
	var fo: Vector3 = fr.o
	var fr3: Vector3 = fr.r
	var ff3: Vector3 = fr.f
	var on_sand := func(x: float, z: float) -> bool:
		var q := Vector3(x, 0.0, z) - fo
		var qx := q.dot(fr3)
		var qz := q.dot(ff3)
		return qx > 10.5 and qz > -12.0 and qz < 50.0
	var area := Rect2(World.origin + Vector2(box[0], box[1]) * World.cs, Vector2(box[2] - box[0], box[3] - box[1]) * World.cs)
	var ug: UndergrowthSystem = world.get("undergrowth")
	if ug:
		ug.exclude(on_sand, area)
	var gc: Node = world.get("ground_cover")
	if gc and gc.has_method("invalidate"):
		gc.invalidate(area)
	var water: WaterSystem = world.get("water")
	if water and water.surf:
		water.surf.rebuild(water)
	print("ReferenceCove beach: %d height samples filled" % _height_backup.size())


## Grid index box [i0, j0, i1, j1] covering a frame-space rectangle.
static func _grid_box(fr: Dictionary, fx0: float, fx1: float, fz0: float, fz1: float) -> Array:
	var x0 := INF
	var x1 := -INF
	var z0 := INF
	var z1 := -INF
	for c in [[fx0, fz0], [fx1, fz0], [fx0, fz1], [fx1, fz1]]:
		var p: Vector3 = (fr.o as Vector3) + (fr.r as Vector3) * float(c[0]) + (fr.f as Vector3) * float(c[1])
		x0 = minf(x0, p.x)
		x1 = maxf(x1, p.x)
		z0 = minf(z0, p.z)
		z1 = maxf(z1, p.z)
	return [maxi(int(floor((x0 - World.origin.x) / World.cs)), 0), maxi(int(floor((z0 - World.origin.y) / World.cs)), 0),
		mini(int(ceil((x1 - World.origin.x) / World.cs)), World.W - 1), mini(int(ceil((z1 - World.origin.y) / World.cs)), World.H - 1)]


func _paint_beach() -> void:
	_raise_beach()
	var fr := frame()
	var x0 := INF
	var x1 := -INF
	var z0 := INF
	var z1 := -INF
	for c in [[8.0, -16.0], [40.0, -16.0], [8.0, 56.0], [40.0, 56.0]]:
		var p: Vector3 = fr.o + fr.r * float(c[0]) + fr.f * float(c[1])
		x0 = minf(x0, p.x)
		x1 = maxf(x1, p.x)
		z0 = minf(z0, p.z)
		z1 = maxf(z1, p.z)
	var o2: Vector3 = fr.o
	var r3: Vector3 = fr.r
	var f3: Vector3 = fr.f
	var i0 := int(floor((x0 - World.origin.x) / World.cs))
	var i1 := int(ceil((x1 - World.origin.x) / World.cs))
	var j0 := int(floor((z0 - World.origin.y) / World.cs))
	var j1 := int(ceil((z1 - World.origin.y) / World.cs))
	# Packed arrays are values: edit one local copy, assign back once.
	var m: PackedByteArray = World.masks
	for j in range(maxi(j0, 0), mini(j1, World.H - 1) + 1):
		for i in range(maxi(i0, 0), mini(i1, World.W - 1) + 1):
			var wp := Vector3(World.origin.x + i * World.cs, 0.0, World.origin.y + j * World.cs)
			var d := wp - o2
			var fx := d.dot(r3)
			var fz := d.dot(f3)
			var xl := beach_line(fz)
			var w := smoothstep(9.0, 12.0, fx) * (1.0 - smoothstep(xl + 9.0, xl + 15.0, fx)) * smoothstep(-15.0, -8.0, fz) * (1.0 - smoothstep(46.0, 55.0, fz))
			if w <= 0.01:
				continue
			var t := (j * World.W + i) * 4
			for ch in 4:
				if not _mask_backup.has(t + ch):
					_mask_backup[t + ch] = m[t + ch]
			m[t] = int(maxf(m[t], 255.0 * w))
			m[t + 1] = int(m[t + 1] * (1.0 - w))
			m[t + 2] = int(m[t + 2] * (1.0 - w))
			m[t + 3] = int(m[t + 3] * (1.0 - 0.9 * w))
	World.masks = m
	_push_masks()
	# Dark shore rocks along the waterline and in the shallows: the water's
	# contact foam breaks around them.
	var rocks := RockBuilder.build_variants(4)
	var rmat := RockBuilder.material()
	var shore := [[10.9, 5.0, 0.9], [12.1, 9.2, 0.7], [13.3, 3.0, 1.1], [14.3, 7.4, 0.8], [15.1, 12.6, 1.3], [16.1, 4.6, 0.6], [12.7, 15.2, 0.9], [17.1, 9.6, 1.0], [11.3, 18.4, 0.8], [14.5, 20.4, 1.2], [17.9, 15.0, 0.7], [10.1, 1.2, 0.6], [20.1, 6.2, 1.1], [21.7, 11.8, 0.8], [20.9, 22.6, 1.4], [24.1, 17.2, 0.9], [19.3, 0.4, 0.9], [25.5, 28.0, 1.6], [22.5, 34.0, 1.0]]
	for i in shore.size():
		var sd: Array = shore[i]
		var r := MeshInstance3D.new()
		r.name = "ShoreRock%d" % i
		r.mesh = rocks[(i + 1) % rocks.size()]
		r.material_override = rmat
		add_child(r)
		var p := at(sd[0], sd[1])
		p.y = minf(p.y, World.height_at(p.x, p.z)) - 0.4 * float(sd[2])
		r.global_position = p
		r.scale = Vector3(1.3, 0.8, 1.1) * float(sd[2]) * 1.8
		r.rotation.y = float(i) * 1.37


func _push_masks() -> void:
	var img := Image.create_from_data(World.W, World.H, false, Image.FORMAT_RGBA8, World.masks)
	img.generate_mipmaps()
	World.mask_texture.update(img)


func _exit_tree() -> void:
	if not _height_backup.is_empty():
		var hg: PackedFloat32Array = World.height
		for k in _height_backup:
			hg[int(k)] = float(_height_backup[k])
		World.height = hg
		_height_backup.clear()
		World.height_texture.update(Image.create_from_data(World.W, World.H, false, Image.FORMAT_RF, World.height.to_byte_array()))
	if _mask_backup.is_empty():
		return
	var m: PackedByteArray = World.masks
	for t in _mask_backup:
		m[int(t)] = int(_mask_backup[t])
	World.masks = m
	_push_masks()
	_mask_backup.clear()
