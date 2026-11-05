class_name SurveyShip
extends Node3D
## Phase 19: the offshore survey vessel (ambient, non-boardable, no
## colliders, no affiliation markings). Local frame: -Z is the bow, +Z the
## stern; y = 0 is the waterline. The aft helipad is a raised square deck
## at the stern; `deck_transform()` is the moving pad the helicopter takes
## off from and lands on. Everything is original procedural geometry.

const L := 112.0
const BEAM := 18.0
const PAD_Z := L * 0.5 - 11.0
const PAD_Y := 11.2
const PAD_SIZE := 19.0

var speed := 0.0               # m/s, set by the route each frame
var roll_amp := deg_to_rad(0.7)
var pitch_amp := deg_to_rad(0.35)
var heave_amp := 0.35
var engine_handle := 0
var _base := Transform3D.IDENTITY   # route transform (no sea motion)
var _motion := Node3D.new()
var _wake: MeshInstance3D
var _wake_mat: ShaderMaterial
var _t := 0.0
var _upd := 0.0
var _phase := 0.0


func _ready() -> void:
	name = "SurveyShip"
	_motion.name = "Motion"
	add_child(_motion)
	_build()
	_phase = float(hash(str(get_instance_id())) % 1000) * 0.01


func _exit_tree() -> void:
	if engine_handle > 0:
		SoundService.loop_stop(engine_handle, 0.5)
		engine_handle = 0


static func _m(c: Color, rough := 0.6, metal := 0.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


# ------------------------------------------------------------- geometry

## Lofted hull: stations along the length, each a half-section (keel to
## deck edge) mirrored. The bow tapers to a raked stem; the stern is a flat
## transom; the deck line rises toward the bow (sheer).
func _hull_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 16
	var stations: Array = []
	for i in n + 1:
		var u := float(i) / n                     # 0 bow .. 1 stern
		var z := lerpf(-L * 0.5, L * 0.5, u)
		var half := BEAM * 0.5
		if u < 0.3:
			half *= pow(sin(u / 0.3 * PI * 0.5), 0.75)
		half = maxf(half, 0.25)
		var deck := lerpf(10.2, 7.2, smoothstep(0.0, 0.55, u))
		var keel := -5.0 * clampf(u / 0.08, 0.35, 1.0)
		var rake := (1.0 - u / 0.3) * 7.0 if u < 0.3 else 0.0   # raked stem
		stations.append({"z": z, "half": half, "deck": deck, "keel": keel, "rake": rake})
	# Section profile (fractions of half-beam, height from keel to deck).
	var prof := [[0.0, 0.0], [0.55, 0.05], [0.9, 0.25], [1.0, 0.5], [1.0, 1.0]]
	var rings: Array = []
	for s in stations:
		var ring: Array = []
		for side in [-1.0, 1.0]:
			var pts: Array = []
			for p in prof:
				pts.append(Vector3(side * float(s.half) * float(p[0]), lerpf(float(s.keel), float(s.deck), float(p[1])), float(s.z) - float(s.rake) * float(p[1])))
			if side < 0:
				pts.reverse()
			ring.append_array(pts)
		rings.append(ring)
	var m: int = (rings[0] as Array).size()
	for i in n:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for k in m - 1:
			_quad(st, a[k], a[k + 1], b[k + 1], b[k])
	# Deck (top) and transom (stern face).
	var last: Array = rings[n]
	for i in n:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		_quad(st, a[m - 1], a[0], b[0], b[m - 1])
	for k in m / 2 - 1:
		_quad(st, last[k], last[k + 1], last[m - 2 - k], last[m - 1 - k])
	return st.commit()


## One face per quad with an explicit OUTWARD flat normal (away from the
## hull's centre line), so shading is clean; the material is double-sided.
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length() < 1e-6:
		n = (c - a).cross(d - a)
	n = n.normalized()
	var ctr := (a + b + c + d) * 0.25
	var inside := Vector3(0.0, 2.0, clampf(ctr.z, -L * 0.5 + 10.0, L * 0.5 - 1.0))
	if n.dot(ctr - inside) < 0.0:
		n = -n
	for v in [a, b, c, a, c, d]:
		st.set_normal(n)
		st.add_vertex(v)


func _build() -> void:
	var hull_m := _m(Color(0.16, 0.19, 0.23), 0.55, 0.3)
	hull_m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var anti := _m(Color(0.35, 0.12, 0.1), 0.7, 0.1)
	var white := _m(Color(0.86, 0.87, 0.86), 0.45, 0.05)
	var grey := _m(Color(0.52, 0.54, 0.55), 0.5, 0.4)
	var pad := _m(Color(0.36, 0.38, 0.38), 0.85, 0.1)
	var paint := _m(Color(0.82, 0.82, 0.78), 0.8, 0.0)
	var dark := _m(Color(0.05, 0.06, 0.07), 0.15, 0.6)
	var orange := _m(Color(0.86, 0.42, 0.12), 0.6, 0.0)
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = _hull_mesh()
	hull.material_override = hull_m
	_motion.add_child(hull)
	# Boot-top band just above the waterline.
	BuildKit.box(_motion, Vector3(BEAM * 1.002, 0.8, L * 0.66), Vector3(0, 0.25, 6.0), anti, false, 0.0, "BootTop")
	# Superstructure (forward of midships), three tiers + bridge.
	BuildKit.box(_motion, Vector3(15.5, 3.2, 26.0), Vector3(0, 8.8, -14.0), white, false, 0.0, "House1")
	BuildKit.box(_motion, Vector3(14.0, 3.0, 20.0), Vector3(0, 11.9, -16.0), white, false, 0.0, "House2")
	BuildKit.box(_motion, Vector3(17.5, 2.8, 9.0), Vector3(0, 14.8, -20.5), white, false, 0.0, "Bridge")
	BuildKit.box(_motion, Vector3(17.6, 1.0, 0.2), Vector3(0, 15.2, -25.05), dark, false, 0.0, "BridgeWindows")
	for sx in [-1.0, 1.0]:
		BuildKit.box(_motion, Vector3(0.2, 1.0, 8.0), Vector3(sx * 8.81, 15.2, -20.5), dark, false, 0.0, "BridgeSide")
		BuildKit.box(_motion, Vector3(0.2, 0.7, 18.0), Vector3(sx * 7.06, 12.3, -16.0), dark, false, 0.0, "Ports")
		# Lifeboats (orange, no text) on davits.
		BuildKit.box(_motion, Vector3(2.2, 2.0, 7.0), Vector3(sx * 9.0, 9.6, -6.0), orange, false, 0.0, "Lifeboat")
	# Mast with radar dome; funnel; survey A-frame and deck crane aft.
	BuildKit.cylinder(_motion, 0.35, 8.0, Vector3(0, 20.2, -19.0), grey, false, 8)
	BuildKit.box(_motion, Vector3(5.0, 0.25, 0.4), Vector3(0, 21.5, -19.0), grey, false, 0.0, "Yard")
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	dome.mesh = sm
	dome.material_override = white
	dome.position = Vector3(0, 24.6, -19.0)
	_motion.add_child(dome)
	BuildKit.box(_motion, Vector3(5.0, 7.0, 6.5), Vector3(0, 12.8, -1.5), grey, false, 0.0, "Funnel")
	BuildKit.box(_motion, Vector3(5.1, 0.8, 6.6), Vector3(0, 16.5, -1.5), dark, false, 0.0, "FunnelTop")
	BuildKit.box(_motion, Vector3(0.6, 9.0, 0.6), Vector3(-6.0, 11.5, 15.0), grey, false, 0.0, "CranePost")
	BuildKit.box(_motion, Vector3(0.5, 0.5, 14.0), Vector3(-6.0, 15.5, 9.0), grey, false, 0.0, "CraneJib")
	# Raised aft helipad on a support frame, with a pale perimeter line and
	# a plain touchdown ring (no letters, numbers or emblems).
	BuildKit.box(_motion, Vector3(PAD_SIZE, 0.5, PAD_SIZE), Vector3(0, PAD_Y - 0.25, PAD_Z), pad, false, 0.0, "Helipad")
	for sx in [-1.0, 1.0]:
		BuildKit.box(_motion, Vector3(0.12, 0.03, PAD_SIZE - 0.6), Vector3(sx * (PAD_SIZE * 0.5 - 0.4), PAD_Y + 0.02, PAD_Z), paint, false)
		BuildKit.box(_motion, Vector3(PAD_SIZE - 0.6, 0.03, 0.12), Vector3(0, PAD_Y + 0.02, PAD_Z + sx * (PAD_SIZE * 0.5 - 0.4)), paint, false)
		for zz in [-6.0, 6.0]:
			BuildKit.box(_motion, Vector3(0.5, PAD_Y - 7.0, 0.5), Vector3(sx * 7.5, (PAD_Y + 7.0) * 0.5 - 0.5, PAD_Z + zz), grey, false)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 4.6
	tm.outer_radius = 5.0
	tm.rings = 32
	ring.mesh = tm
	ring.scale = Vector3(1, 0.04, 1)
	ring.material_override = paint
	ring.position = Vector3(0, PAD_Y + 0.02, PAD_Z)
	_motion.add_child(ring)
	# Navigation lights (port red, starboard green, masthead white).
	var nav := [[Vector3(-8.9, 15.4, -22.0), Color(1, 0.1, 0.05)], [Vector3(8.9, 15.4, -22.0), Color(0.1, 1, 0.2)], [Vector3(0, 23.4, -19.0), Color(1, 1, 0.95)]]
	for nl in nav:
		var e := StandardMaterial3D.new()
		e.albedo_color = nl[1]
		e.emission_enabled = true
		e.emission = nl[1]
		e.emission_energy_multiplier = 3.0
		BuildKit.box(_motion, Vector3(0.4, 0.4, 0.4), nl[0], e, false)
	_build_wake()
	# Never in the physics world: no collision, no interaction, no shadow
	# cost at range beyond the hull.
	for c in _motion.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).visibility_range_end = 6000.0


## A V-shaped foam wake on the water behind the stern plus a bow wave. A
## tiny shader fades it along its length and at the edges and stretches
## it with speed.
func _build_wake() -> void:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float strength = 1.0;
uniform float tm = 0.0;
float h(vec2 p){ return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float n2(vec2 p){ vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
	return mix(mix(h(i), h(i+vec2(1,0)), f.x), mix(h(i+vec2(0,1)), h(i+vec2(1,1)), f.x), f.y); }
void fragment(){
	float along = UV.y;               // 0 at the stern, 1 at the far end
	float across = abs(UV.x - 0.5) * 2.0;
	float arms = smoothstep(0.55, 0.95, across) * (1.0 - smoothstep(0.95, 1.0, across));
	float core = (1.0 - smoothstep(0.0, 0.45, across)) * (1.0 - smoothstep(0.0, 0.5, along));
	float foam = max(arms * 0.8, core) * n2(vec2(UV.x * 40.0, UV.y * 120.0 - tm * 3.0)) * 1.4;
	ALBEDO = vec3(0.93, 0.96, 0.97);
	ALPHA = clamp(foam * (1.0 - along) * strength, 0.0, 0.85);
}
"""
	_wake_mat = ShaderMaterial.new()
	_wake_mat.shader = sh
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	_wake = MeshInstance3D.new()
	_wake.name = "Wake"
	_wake.mesh = pm
	_wake.material_override = _wake_mat
	_wake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wake)      # not on the motion node: the wake stays on the water
	var bow := MeshInstance3D.new()
	bow.name = "BowWave"
	var bm := PlaneMesh.new()
	bm.size = Vector2(BEAM * 1.5, 14.0)
	bow.mesh = bm
	bow.material_override = _wake_mat
	bow.position = Vector3(0, 0.15, -L * 0.5 + 4.0)
	bow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bow)


# --------------------------------------------------------------- motion

## The route sets the base transform (on the circle, facing tangent);
## subtle sea motion is applied to the visual child only, so the route
## geometry stays exact.
func set_route(pos: Vector3, forward: Vector3, spd: float) -> void:
	speed = spd
	var f := Vector3(forward.x, 0, forward.z).normalized()
	_base = Transform3D(Basis.looking_at(f, Vector3.UP), Vector3(pos.x, World.sea_level, pos.z))
	global_transform = _base


func _process(delta: float) -> void:
	_t += delta
	# Bounded updates: sea motion and wake animate at full rate near the
	# camera, at 5 Hz far away (the silhouette barely changes).
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var far := cam == null or cam.global_position.distance_to(global_position) > 2500.0
	_upd -= delta
	if far and _upd > 0.0:
		return
	_upd = 0.2
	var tt := _t + _phase
	_motion.position = Vector3(0, sin(tt * 0.45) * heave_amp, 0)
	_motion.rotation = Vector3(sin(tt * 0.31) * pitch_amp, 0, sin(tt * 0.23 + 1.0) * roll_amp)
	var len := clampf(speed * 18.0, 40.0, 260.0)
	_wake.scale = Vector3(BEAM * lerpf(1.6, 3.4, clampf(speed / 12.0, 0, 1)), 1, len)
	_wake.position = Vector3(0, 0.12, L * 0.5 + len * 0.5 - 2.0)
	_wake_mat.set_shader_parameter("strength", clampf(0.35 + speed / 12.0, 0.35, 1.0))
	_wake_mat.set_shader_parameter("tm", _t)


## The pad's world transform (moving with the ship's sea motion).
func deck_transform() -> Transform3D:
	return global_transform * _motion.transform * Transform3D(Basis.IDENTITY, Vector3(0, PAD_Y, PAD_Z))


## World points worth checking for line of sight to the hull.
func sight_points() -> Array[Vector3]:
	var g := global_transform
	return [g * Vector3(0, 15.0, -20.0), g * Vector3(0, 6.0, 0.0), g * Vector3(0, PAD_Y + 1.0, PAD_Z), g * Vector3(0, 7.0, -L * 0.42), g * Vector3(0, 24.0, -19.0)]


func start_engine() -> void:
	if engine_handle <= 0:
		engine_handle = SoundService.loop("offshore.ship.engine", self, {"offset": Vector3(0, 6, 0)})
