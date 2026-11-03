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
@export var jacket_texture := "denim_fabric"
@export var shirt := Color(0.82, 0.78, 0.66)
@export var pants := Color(0.24, 0.27, 0.32)
@export var boots := Color(0.28, 0.18, 0.11)
@export var gloves := Color(0.55, 0.42, 0.25)
@export var brow_tilt := 0.0         # expression: + friendly, - stern
@export var posture := 0.0           # -1 slouch .. +1 upright (idle habit)


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
