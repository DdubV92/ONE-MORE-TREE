extends SceneTree
## Phase 12: retargets the user-supplied Mixamo FBX clips (assets/mixamo_src,
## git-ignored: Adobe's terms do not allow redistributing the raw files) onto
## the HumanCharacter pivot rig and writes data/anim/mixamo_retarget.json,
## which the game uses. Only this derived, rig-specific motion is committed.
##
##   godot --headless --script res://tools/bake_mixamo.gd
##
## Method (per frame, per mapped bone):
##   Q   = C * Gs(t) * Gs_rest^-1 * C^-1      source global delta from its own
##                                           rest, in our frame (C = 180 deg
##                                           about Y: Mixamo faces +Z, we -Z)
##   A   = arc(our rest dir -> source rest dir)  aligns our hanging-arm rest
##                                           with Mixamo's T-pose per bone
##   Go  = Q * A                              our global rotation
##   L   = Go(parent)^-1 * Go                 our local pivot rotation
## Hips translation is stored as offsets normalised by the source hip height;
## each character rescales them and re-plants its feet with its own legs.

const SRC := "res://assets/mixamo_src/%s.fbx"
const OUT := "res://data/anim/mixamo_retarget.json"
const FPS := 30.0
## out name, source file, kind, loop
const CLIPS := [
	["walk", "walking_3", "locomotion", true],
	["run", "running", "locomotion", true],
	["sit", "sitting_1", "seated", true],
	["sit_relaxed", "sitting", "seated", true],
	["lie", "laying_nodding", "lying", true],
]
## our bone -> [mixamo bone, mixamo child used for its direction, our parent]
const MAP := {
	"Hips": ["Hips", "Spine", ""],
	"Spine": ["Spine", "Spine2", "Hips"],
	"Chest": ["Spine2", "Neck", "Spine"],
	"Neck": ["Neck", "Head", "Chest"],
	"Head": ["Head", "HeadTop_End", "Neck"],
	"UpperArmL": ["LeftArm", "LeftForeArm", "Chest"],
	"ForearmL": ["LeftForeArm", "LeftHand", "UpperArmL"],
	"HandL": ["LeftHand", "LeftHandMiddle1", "ForearmL"],
	"UpperArmR": ["RightArm", "RightForeArm", "Chest"],
	"ForearmR": ["RightForeArm", "RightHand", "UpperArmR"],
	"HandR": ["RightHand", "RightHandMiddle1", "ForearmR"],
	"ThighL": ["LeftUpLeg", "LeftLeg", "Hips"],
	"ShinL": ["LeftLeg", "LeftFoot", "ThighL"],
	"FootL": ["LeftFoot", "LeftToeBase", "ShinL"],
	"ThighR": ["RightUpLeg", "RightLeg", "Hips"],
	"ShinR": ["RightLeg", "RightFoot", "ThighR"],
	"FootR": ["RightFoot", "RightToeBase", "ShinR"],
}
const ORDER := ["Hips", "Spine", "Chest", "Neck", "Head", "UpperArmL", "ForearmL", "HandL", "UpperArmR", "ForearmR", "HandR", "ThighL", "ShinL", "FootL", "ThighR", "ShinR", "FootR"]


## Our rig's rest direction of each bone (HumanCharacter: identity pivots,
## limbs hang down, feet point forward (-Z), trunk and head point up).
static func our_rest_dir(b: String) -> Vector3:
	if b.begins_with("Foot"):
		return Vector3(0, -0.27, -0.96).normalized()
	if b in ["Hips", "Spine", "Chest", "Neck", "Head"]:
		return Vector3.UP
	return Vector3.DOWN


func _init() -> void:
	var out := {"source": "Adobe Mixamo animations supplied by the project owner (FBX not redistributed); retargeted by tools/bake_mixamo.gd", "fps": FPS, "bones": ORDER, "clips": {}}
	for spec in CLIPS:
		var clip := _bake(spec[1], spec[2], spec[3])
		if clip.is_empty():
			printerr("skipped ", spec[1])
			continue
		out.clips[spec[0]] = clip
		print("baked %s <- %s: %.2f s, %d frames, speed %.3f hip/s, contacts %s" % [spec[0], spec[1], clip.length, clip.frames, clip.get("speed_norm", 0.0), str(clip.get("contacts", []))])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/anim"))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "", false))
	f.close()
	print("wrote ", OUT)
	quit()


func _bake(file: String, kind: String, loop: bool) -> Dictionary:
	if not FileAccess.file_exists(SRC % file):
		return {}
	var doc := FBXDocument.new()
	var st := FBXState.new()
	if doc.append_from_file(SRC % file, st) != OK:
		return {}
	var scene: Node = doc.generate_scene(st)
	var sk: Skeleton3D = scene.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = scene.find_children("*", "AnimationPlayer", true, false)[0]
	var an := ap.get_animation("mixamo_com")
	var prefix := ""
	for b in sk.get_bone_count():
		if sk.get_bone_name(b).ends_with("Hips"):
			prefix = sk.get_bone_name(b).trim_suffix("Hips")
	var idx := func(n: String) -> int: return sk.find_bone(prefix + n)
	var nb := sk.get_bone_count()
	var rest_local: Array[Transform3D] = []
	var rot_tr := PackedInt32Array()
	var pos_tr := PackedInt32Array()
	for b in nb:
		rest_local.append(sk.get_bone_rest(b))
		var path := NodePath("%s:%s" % [str(scene.get_path_to(sk)), sk.get_bone_name(b)])
		rot_tr.append(an.find_track(path, Animation.TYPE_ROTATION_3D))
		pos_tr.append(an.find_track(path, Animation.TYPE_POSITION_3D))
	var rest_g := _globals(sk, rest_local)
	var C := Basis(Vector3.UP, PI)
	var Ci := C.inverse()
	# Rest alignment per mapped bone.
	var align := {}
	for b in ORDER:
		var m: Array = MAP[b]
		var bi: int = idx.call(m[0])
		var ci: int = idx.call(m[1])
		var d_s := C * (rest_g[ci].origin - rest_g[bi].origin).normalized()
		align[b] = Basis(Quaternion(our_rest_dir(b), d_s))
	var hips_i: int = idx.call("Hips")
	var hip_h: float = rest_g[hips_i].origin.y
	var frames := int(round(an.length * FPS))
	if loop:
		frames = maxi(frames, 2)
	var rots := {}
	for b in ORDER:
		rots[b] = []
	var hips := []
	var toes := [[], []]
	var globals_by_frame: Array = []
	for f in frames + (0 if loop else 1):
		var t := minf(f / FPS, an.length)
		var local: Array[Transform3D] = []
		for b in nb:
			var tr: Transform3D = rest_local[b]
			if rot_tr[b] >= 0:
				tr.basis = Basis(an.rotation_track_interpolate(rot_tr[b], t))
			if pos_tr[b] >= 0:
				tr.origin = an.position_track_interpolate(pos_tr[b], t)
			local.append(tr)
		globals_by_frame.append(_globals(sk, local))
	# Lying clips are stored body-relative (the game orients the body on the
	# bed); remove the average hips orientation.
	var norm := Basis.IDENTITY
	if kind == "lying":
		var acc := Quaternion(0, 0, 0, 0)
		for g in globals_by_frame:
			var q: Quaternion = ((g as Array)[hips_i] as Transform3D).basis.get_rotation_quaternion() * rest_g[hips_i].basis.get_rotation_quaternion().inverse()
			if acc.dot(q) < 0.0:
				q = -q
			acc += q
		norm = Basis(acc.normalized()).inverse()
	for g in globals_by_frame:
		var G: Array = g
		var go := {}
		for b in ORDER:
			var m: Array = MAP[b]
			var bi: int = idx.call(m[0])
			var Q: Basis = C * (norm * G[bi].basis) * rest_g[bi].basis.inverse() * Ci
			go[b] = (Q * align[b]).orthonormalized()
		for b in ORDER:
			var parent: String = MAP[b][2]
			var L: Basis = go[b] if parent == "" else (go[parent] as Basis).inverse() * go[b]
			var q := L.get_rotation_quaternion()
			(rots[b] as Array).append_array([snappedf(q.x, 0.00001), snappedf(q.y, 0.00001), snappedf(q.z, 0.00001), snappedf(q.w, 0.00001)])
		var hp: Vector3 = C * (norm * ((G[hips_i] as Transform3D).origin - rest_g[hips_i].origin))
		hips.append_array([snappedf(hp.x / hip_h, 0.0001), snappedf(hp.y / hip_h, 0.0001), snappedf(hp.z / hip_h, 0.0001)])
		for s in 2:
			var ti: int = idx.call("LeftToeBase" if s == 0 else "RightToeBase")
			var fi: int = idx.call("LeftFoot" if s == 0 else "RightFoot")
			(toes[s] as Array).append([C * G[ti].origin, C * G[fi].origin])
	var clip := {"length": snappedf(frames / FPS, 0.0001), "frames": frames, "loop": loop, "kind": kind, "hip_height_src": snappedf(hip_h, 0.0001), "rot": rots, "hips": hips}
	if kind == "locomotion":
		_contacts(clip, toes, hip_h)
	scene.free()
	return clip


## Foot plants (start of stance per side) and the ground speed implied by
## the stance foot sliding backward under the hips (in-place clip).
func _contacts(clip: Dictionary, toes: Array, hip_h: float) -> void:
	var n: int = clip.frames
	var contacts := []
	var slide := 0.0
	var slide_t := 0.0
	for s in 2:
		var ys := PackedFloat32Array()
		for f in n:
			var pair: Array = toes[s][f]
			ys.append((pair[1] as Vector3).y)     # ankle height
		var lo := 1e9
		var hi := -1e9
		for y in ys:
			lo = minf(lo, y)
			hi = maxf(hi, y)
		# Hysteresis: a plant starts when the ankle comes down near its
		# lowest after having lifted clear (no heel/flat double counts).
		var on_th := lo + (hi - lo) * 0.15
		var off_th := lo + (hi - lo) * 0.45
		var down := ys[n - 1] <= on_th
		for pass_i in 2:
			for f in n:
				var y := ys[f]
				if not down and y <= on_th:
					down = true
					if pass_i == 1:
						contacts.append([snappedf(f / FPS, 0.001), s])
				elif down and y >= off_th:
					down = false
		for f in n:
			if ys[f] <= on_th and ys[(f + 1) % n] <= on_th:
				var a: Vector3 = toes[s][f][1]
				var b: Vector3 = toes[s][(f + 1) % n][1]
				slide += absf(b.z - a.z)
				slide_t += 1.0 / FPS
	contacts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	clip["contacts"] = contacts
	clip["speed_norm"] = snappedf((slide / maxf(slide_t, 0.001)) / hip_h, 0.0001)


static func _globals(sk: Skeleton3D, local: Array[Transform3D]) -> Array[Transform3D]:
	var g: Array[Transform3D] = []
	g.resize(local.size())
	for b in local.size():
		var p := sk.get_bone_parent(b)
		g[b] = local[b] if p < 0 else g[p] * local[b]
	return g
