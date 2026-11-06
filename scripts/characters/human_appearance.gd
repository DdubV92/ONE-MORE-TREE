class_name HumanAppearance
extends Resource
## Data-driven look for a stylized adult. Four worker variants (Prompt 5+)
## and the preview model share one rig and animation set; only these values
## differ. Personalities are intentionally not defined yet.

@export var label := "Worker"
@export var height := 1.78
@export var build := 1.0            # 0.85 slim .. 1.25 sturdy
@export var skin := Color(0.86, 0.66, 0.52)
@export var hair := Color(0.25, 0.16, 0.1)
@export var hair_style := 0          # 0 short crop, 1 beanie, 2 bun, 3 bald + cap
@export var beard := 0               # 0 none, 1 stubble, 2 full
@export var jacket := Color(0.62, 0.22, 0.16)
@export var jacket_texture := "caban"   # Phase 12: wool work jacket (was a blue denim scan)
@export var shirt := Color(0.82, 0.78, 0.66)
@export var pants := Color(0.24, 0.27, 0.32)
@export var boots := Color(0.28, 0.18, 0.11)
@export var gloves := Color(0.55, 0.42, 0.25)
@export var brow_tilt := 0.0         # expression: + friendly, - stern
@export var posture := 0.0           # -1 slouch .. +1 upright (idle habit)
## Phase 11 face/silhouette controls (restrained ranges, one art family).
@export var jaw := 1.0               # 0.85 narrow .. 1.15 broad
@export var nose := 1.0              # 0.8 small .. 1.25 strong
@export var cheek := 1.0             # cheekbone fullness
@export var ear := 1.0
@export var accent := Color(0.95, 0.75, 0.15)   # small hi-vis/stitch accent
## Phase 24 (reference art): a work hard hat over the hair (alpha 0 = none).
@export var hard_hat := Color(0, 0, 0, 0)
## hair_style: 0 short crop, 1 beanie, 2 bun, 3 cap, 4 curly crop,
## 5 low ponytail, 6 buzz with side part. beard: 0 none, 1 stubble,
## 2 full, 3 moustache.


## The five standard employees (Phase 10 roster) have fixed, authored
## looks keyed by their persistent IDs; replacements use from_seed. The
## look never touches beds, wages, tools, skills or fear.
static func for_employee(emp_id: String, seed_v: int) -> HumanAppearance:
	var a := HumanAppearance.new()
	match emp_id:
		"EMP-01":   # Marta Kell - hard-working, upright, auburn bun
			a.label = "Marta Kell"
			a.height = 1.70; a.build = 1.04; a.skin = Color(0.9, 0.72, 0.6); a.hair = Color(0.5, 0.22, 0.1)
			a.hair_style = 2; a.jacket = Color(0.66, 0.28, 0.14); a.pants = Color(0.26, 0.28, 0.3); a.gloves = Color(0.62, 0.48, 0.28)
			a.brow_tilt = -0.08; a.posture = 0.35; a.jaw = 0.92; a.nose = 0.95; a.accent = Color(0.95, 0.8, 0.2)
		"EMP-02":   # Dale Ostrow - stronger, broad, greying beard
			a.label = "Dale Ostrow"
			a.height = 1.88; a.build = 1.24; a.skin = Color(0.86, 0.64, 0.52); a.hair = Color(0.48, 0.45, 0.42)
			a.hair_style = 0; a.beard = 2; a.jacket = Color(0.2, 0.26, 0.4); a.pants = Color(0.3, 0.27, 0.22); a.boots = Color(0.2, 0.14, 0.09)
			a.brow_tilt = -0.15; a.posture = -0.15; a.jaw = 1.14; a.nose = 1.18; a.cheek = 1.05; a.ear = 1.08
		"EMP-03":   # Priya Lund - observant, slim, dark ponytail
			a.label = "Priya Lund"
			a.height = 1.65; a.build = 0.9; a.skin = Color(0.6, 0.42, 0.3); a.hair = Color(0.07, 0.05, 0.05)
			a.hair_style = 5; a.jacket = Color(0.34, 0.4, 0.24); a.pants = Color(0.2, 0.21, 0.24); a.gloves = Color(0.72, 0.62, 0.42)
			a.brow_tilt = 0.12; a.posture = 0.2; a.jaw = 0.88; a.nose = 0.9; a.cheek = 1.08; a.accent = Color(0.85, 0.35, 0.2)
		"EMP-04":   # Tomas Reyner - timid driver, beanie, stubble, slouch
			a.label = "Tomas Reyner"
			a.height = 1.77; a.build = 0.95; a.skin = Color(0.78, 0.6, 0.45); a.hair = Color(0.22, 0.15, 0.1)
			a.hair_style = 1; a.beard = 1; a.jacket = Color(0.76, 0.58, 0.2); a.pants = Color(0.24, 0.27, 0.32)
			a.brow_tilt = 0.25; a.posture = -0.45; a.jaw = 0.98; a.nose = 1.05; a.ear = 1.05
		"EMP-05":   # Joan Abernathy - sociable skeptic, cap over curls
			a.label = "Joan Abernathy"
			a.height = 1.72; a.build = 1.1; a.skin = Color(0.38, 0.26, 0.18); a.hair = Color(0.09, 0.07, 0.06)
			a.hair_style = 4; a.jacket = Color(0.18, 0.4, 0.4); a.pants = Color(0.3, 0.28, 0.24); a.gloves = Color(0.5, 0.36, 0.2)
			a.brow_tilt = 0.2; a.posture = 0.1; a.jaw = 1.02; a.nose = 1.0; a.cheek = 1.1; a.accent = Color(0.95, 0.55, 0.15)
		_:
			return from_seed(seed_v)
	if emp_id == "EMP-01":
		a.jacket = Color(0.66, 0.17, 0.12)     # the reference worker's red plaid
	workwear(a, hash(emp_id))
	return a


## Phase 24 reference look: every crew member wears a plaid work shirt in
## their own colour and a work hard hat (identity stays readable by colour,
## build, beard and height).
static func workwear(a: HumanAppearance, seed_v: int) -> void:
	a.jacket_texture = "plaid"
	const HATS := [Color(0.86, 0.64, 0.24), Color(0.92, 0.74, 0.2), Color(0.88, 0.5, 0.16), Color(0.9, 0.88, 0.82)]
	a.hard_hat = HATS[absi(seed_v) % HATS.size()]


static func presets() -> Array[HumanAppearance]:
	var out: Array[HumanAppearance] = []
	var a := HumanAppearance.new()
	a.label = "Worker A - tall, red flannel jacket, beard"
	a.height = 1.86
	a.build = 1.12
	a.skin = Color(0.88, 0.68, 0.55)
	a.hair = Color(0.35, 0.2, 0.1)
	a.beard = 2
	a.jacket = Color(0.62, 0.2, 0.15)
	a.brow_tilt = 0.1
	out.append(a)
	var b := HumanAppearance.new()
	b.label = "Worker B - compact, beanie, olive jacket"
	b.height = 1.64
	b.build = 1.0
	b.skin = Color(0.55, 0.38, 0.27)
	b.hair = Color(0.08, 0.06, 0.05)
	b.hair_style = 1
	b.jacket = Color(0.35, 0.4, 0.22)
	b.pants = Color(0.3, 0.25, 0.2)
	b.brow_tilt = 0.25
	b.posture = 0.4
	out.append(b)
	var c := HumanAppearance.new()
	c.label = "Worker C - slim, hair bun, mustard jacket"
	c.height = 1.72
	c.build = 0.88
	c.skin = Color(0.95, 0.78, 0.66)
	c.hair = Color(0.7, 0.45, 0.2)
	c.hair_style = 2
	c.jacket = Color(0.78, 0.58, 0.18)
	c.pants = Color(0.18, 0.2, 0.26)
	c.brow_tilt = -0.05
	out.append(c)
	var d := HumanAppearance.new()
	d.label = "Worker D - broad, cap, stubble, navy jacket"
	d.height = 1.79
	d.build = 1.24
	d.skin = Color(0.36, 0.24, 0.17)
	d.hair = Color(0.1, 0.08, 0.07)
	d.hair_style = 3
	d.beard = 1
	d.jacket = Color(0.18, 0.24, 0.4)
	d.pants = Color(0.32, 0.3, 0.26)
	d.brow_tilt = -0.2
	d.posture = -0.5
	out.append(d)
	return out


## Deterministic original look from a seed (crew members and candidates).
## Appearance is independent of personality and competence.
static func from_seed(seed_v: int) -> HumanAppearance:
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var a := HumanAppearance.new()
	a.label = "seed %d" % seed_v
	a.height = r.randf_range(1.6, 1.9)
	a.build = r.randf_range(0.88, 1.24)
	const SKINS := [Color(0.95, 0.78, 0.66), Color(0.88, 0.68, 0.55), Color(0.76, 0.55, 0.42), Color(0.55, 0.38, 0.27), Color(0.42, 0.29, 0.2), Color(0.32, 0.22, 0.15)]
	const HAIRS := [Color(0.08, 0.06, 0.05), Color(0.25, 0.16, 0.1), Color(0.45, 0.28, 0.14), Color(0.7, 0.45, 0.2), Color(0.55, 0.52, 0.5), Color(0.82, 0.7, 0.45)]
	const JACKETS := [Color(0.62, 0.2, 0.15), Color(0.35, 0.4, 0.22), Color(0.78, 0.58, 0.18), Color(0.18, 0.24, 0.4), Color(0.3, 0.3, 0.32), Color(0.55, 0.32, 0.2), Color(0.2, 0.38, 0.36), Color(0.5, 0.15, 0.3)]
	const PANTS := [Color(0.24, 0.27, 0.32), Color(0.3, 0.25, 0.2), Color(0.18, 0.2, 0.26), Color(0.32, 0.3, 0.26), Color(0.2, 0.22, 0.18)]
	a.skin = SKINS[r.randi() % SKINS.size()]
	a.hair = HAIRS[r.randi() % HAIRS.size()]
	a.hair_style = r.randi() % 7
	a.beard = r.randi() % 4 if r.randf() < 0.55 else 0
	a.jaw = r.randf_range(0.88, 1.12)
	a.nose = r.randf_range(0.85, 1.2)
	a.cheek = r.randf_range(0.92, 1.08)
	a.jacket = JACKETS[r.randi() % JACKETS.size()]
	a.pants = PANTS[r.randi() % PANTS.size()]
	a.boots = Color(0.28, 0.18, 0.11).lerp(Color(0.12, 0.1, 0.09), r.randf())
	a.gloves = Color(0.55, 0.42, 0.25).lerp(Color(0.6, 0.55, 0.2), r.randf() * 0.6)
	a.brow_tilt = r.randf_range(-0.2, 0.25)
	a.posture = r.randf_range(-0.5, 0.45)
	workwear(a, seed_v)
	return a
