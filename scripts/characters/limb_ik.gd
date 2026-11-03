class_name LimbIK
extends RefCounted
## Analytic two-bone IK helpers shared by humans and the dog.
## Convention: every limb pivot points along its local -Y in rest pose.


## Planar (sagittal) solve: hip at origin, target (dy, dz) in the parent's
## Y/Z plane. Returns [upper_angle, lower_angle] as rotations about +X (a
## positive angle swings the limb toward -Z / forward). `bend_forward` puts
## the middle joint (knee) toward -Z; false bends it toward +Z (dog elbow).
static func solve_planar(dy: float, dz: float, upper: float, lower: float, bend_forward := true) -> Vector2:
	var dist := clampf(Vector2(dy, dz).length(), absf(upper - lower) + 0.001, upper + lower - 0.0005)
	var theta_d := atan2(-dz, -dy)
	var beta := acos(clampf((upper * upper + dist * dist - lower * lower) / (2.0 * upper * dist), -1.0, 1.0))
	var gamma := acos(clampf((upper * upper + lower * lower - dist * dist) / (2.0 * upper * lower), -1.0, 1.0))
	if bend_forward:
		return Vector2(theta_d + beta, -(PI - gamma))
	return Vector2(theta_d - beta, PI - gamma)


## Full 3D two-bone solve on live nodes. `upper`/`lower` are pivots whose
## -Y axis runs along the bone; `pole` is a world-space hint for the middle
## joint. Writes global bases (keeps scale 1).
static func solve_nodes(upper: Node3D, lower: Node3D, end_len: float, target: Vector3, pole: Vector3) -> void:
	var s := upper.global_position
	var a := lower.position.length()
	var b := end_len
	var d := target - s
	var dist := clampf(d.length(), absf(a - b) + 0.001, a + b - 0.0005)
	var dn := d.normalized()
	var x := (a * a - b * b + dist * dist) / (2.0 * dist)
	var h := sqrt(maxf(a * a - x * x, 0.0))
	var p := (pole - s)
	p = (p - dn * p.dot(dn))
	p = p.normalized() if p.length() > 0.0001 else Vector3.FORWARD
	var elbow := s + dn * x + p * h
	var t := s + dn * dist
	upper.global_basis = _basis_down(elbow - s, p)
	lower.global_basis = _basis_down(t - elbow, p)


static func _basis_down(dir: Vector3, pole: Vector3) -> Basis:
	var y := -dir.normalized()
	var xax := y.cross(pole).normalized()
	if xax.length() < 0.001:
		xax = Vector3.RIGHT
	var z := xax.cross(y).normalized()
	return Basis(xax, y, z)
