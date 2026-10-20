## Female base body as smooth parametric surfaces: a superellipse torso loft
## (front/back depths, bust, shoulder blades), tubes for limbs along joint
## splines, and articulated hands with three-phalanx fingers. Garments are
## built by offsetting these same functions, so clothes follow the anatomy.
class_name Body
extends RefCounted

# y, half-width, front depth, back depth, z centre, superellipse exponent
var TT := [
	[0.78, 0.118, 0.070, 0.080, 0.000, 2.2],
	[0.86, 0.168, 0.082, 0.108, -0.006, 2.5],
	[0.95, 0.162, 0.080, 0.098, -0.006, 2.5],
	[1.04, 0.124, 0.074, 0.074, 0.000, 2.3],
	[1.12, 0.132, 0.084, 0.078, 0.002, 2.35],
	[1.22, 0.148, 0.092, 0.082, 0.004, 2.45],
	[1.30, 0.158, 0.082, 0.084, -0.004, 2.7],
	[1.365, 0.172, 0.066, 0.076, -0.014, 3.0],
	[1.415, 0.118, 0.056, 0.066, -0.020, 2.6],
	[1.465, 0.056, 0.050, 0.052, -0.026, 2.0],
]
const Y0 := 0.78
const Y1 := 1.465
var bust := 0.024
var J := {} # joint positions

func _init(o := {}) -> void:
	bust = o.get("bust", 0.024)
	for s in [["L", 1.0], ["R", -1.0]]:
		var n: String = s[0]
		var x: float = s[1]
		J["shoulder_" + n] = Vector3(x * 0.172, 1.385, -0.016)
		J["elbow_" + n] = Vector3(x * 0.208, 1.108, -0.034)
		J["wrist_" + n] = Vector3(x * 0.226, 0.868, -0.004)
		J["hip_" + n] = Vector3(x * 0.088, 0.885, 0.0)
		J["knee_" + n] = Vector3(x * 0.094, 0.480, 0.012)
		J["ankle_" + n] = Vector3(x * 0.086, 0.078, -0.022)
	J["pelvis"] = Vector3(0, 0.95, 0)
	J["spine"] = Vector3(0, 1.08, 0)
	J["chest"] = Vector3(0, 1.25, 0)
	J["neck"] = Vector3(0, 1.44, -0.022)
	J["head"] = Vector3(0, 1.585, 0.0)

func _row(y: float) -> Array:
	var r := [0.0, 0.0, 0.0, 0.0, 0.0]
	for k in 5:
		var tbl := []
		for row in TT: tbl.append([row[0], row[k + 1]])
		r[k] = Geo.table(tbl, y)
	return r

static func se(c: float, n: float) -> float:
	return signf(c) * pow(absf(c), 2.0 / n)

## Torso point: u around (0 = front, 0.25 = left/+x), y height, off = offset outward.
func torso(u: float, y: float, off := 0.0) -> Vector3:
	var r := _row(y)
	var th := u * TAU
	var sx := sin(th)
	var cz := cos(th)
	var a: float = r[0] + off
	var b: float = (r[1] if cz > 0.0 else r[2]) + off
	var x := a * se(sx, r[4])
	var z: float = r[3] + b * se(cz, r[4])
	# bust (modest), shoulder blades, buttocks - smooth gaussian sculpt
	var bz := 0.0
	for s in [-1.0, 1.0]:
		bz += bust * exp(-(pow((x - s * 0.072) / 0.052, 2.0) + pow((y - 1.215) / 0.058, 2.0))) * smoothstep(0.0, 0.5, cz)
		bz -= 0.010 * exp(-(pow((x - s * 0.075) / 0.05, 2.0) + pow((y - 1.30) / 0.07, 2.0))) * smoothstep(0.0, -0.5, cz)
		bz -= 0.022 * exp(-(pow((x - s * 0.06) / 0.07, 2.0) + pow((y - 0.88) / 0.07, 2.0))) * smoothstep(0.0, -0.5, cz)
	return Vector3(x, y, z + bz)

func torso_uv(u: float, v: float, off := 0.0, y0 := Y0, y1 := Y1) -> Vector3:
	return torso(u, lerpf(y0, y1, v), off)

## Arm centreline from inside the torso to the wrist.
func arm_curve(side: String) -> Callable:
	var s := 1.0 if side == "L" else -1.0
	var pts := [Vector3(s * 0.11, 1.395, -0.016), J["shoulder_" + side], J["elbow_" + side], J["wrist_" + side]]
	return func(t: float) -> Vector3: return Geo.crspline(pts, t)

func arm_radius(v: float) -> Vector2:
	var r := Geo.table([[0.0, 0.045], [0.25, 0.050], [0.42, 0.041], [0.62, 0.033], [0.72, 0.036], [0.86, 0.031], [1.0, 0.025]], v)
	var flat := Geo.table([[0.0, 1.0], [0.6, 1.0], [0.85, 0.82], [1.0, 0.72]], v)
	return Vector2(r, r * flat)

func leg_curve(side: String) -> Callable:
	var s := 1.0 if side == "L" else -1.0
	var pts := [Vector3(s * 0.075, 0.98, -0.01), J["hip_" + side], J["knee_" + side], J["ankle_" + side]]
	return func(t: float) -> Vector3: return Geo.crspline(pts, t)

func leg_radius(v: float) -> Vector2:
	var r := Geo.table([[0.0, 0.09], [0.12, 0.092], [0.35, 0.080], [0.62, 0.050], [0.74, 0.054], [0.86, 0.042], [1.0, 0.032]], v)
	return Vector2(r, r * 1.05)

## Hand hanging at the wrist: palm toward the thigh, fingers relaxed.
func hand(st: SurfaceTool, side: String, bone: int, grip := 0.0, o := {}) -> void:
	var s := 1.0 if side == "L" else -1.0
	var w: Vector3 = J["wrist_" + side]
	var down := Vector3(0.06 * s, -1, 0.05).normalized()
	var fwd := Vector3(0, 0, 1)
	var inward := Vector3(-s, 0, 0)
	var oo := o.duplicate(); oo["bones"] = [bone]
	# palm: lofted flattened tube, wider at the knuckles
	var palm := func(t: float) -> Vector3: return w + down * (0.005 + 0.088 * t)
	Geo.tube(st, palm, 20, 10, func(v, th):
		var cap := sqrt(clampf(minf(v / 0.12, (1.0 - v) / 0.18), 0.0, 1.0))
		return Vector2(lerpf(0.026, 0.037, smoothstep(0.0, 0.8, v)), lerpf(0.016, 0.012, v)) * maxf(cap, 0.25), oo.merged({"up": fwd, "closed_u": true}))
	var fz := [0.025, 0.008, -0.009, -0.025]
	var fl := [0.070, 0.078, 0.073, 0.058]
	var fr := [0.0082, 0.0086, 0.0080, 0.0070]
	for k in 4:
		var base: Vector3 = w + down * 0.085 + fwd * fz[k] * 0.95 + inward * 0.002
		var pts := [base]
		var d := down + fwd * (0.06 * (1.5 - k))
		var segs := [0.45, 0.32, 0.23]
		var bend := [0.22 + grip, 0.42 + grip * 1.5, 0.28 + grip]
		var p := base
		var dir := d.normalized()
		for q in 3:
			dir = dir.rotated(fwd.cross(dir).normalized() * -1.0 * s * -1.0, 0.0)
			dir = (dir + inward * tan(bend[q]) * 0.9).normalized()
			p = p + dir * fl[k] * segs[q]
			pts.append(p)
		var crv := func(t: float) -> Vector3: return Geo.crspline(pts, t)
		var rr: float = fr[k]
		Geo.tube(st, crv, 10, 12, func(v, th):
			var cap := sqrt(clampf((1.0 - v) / 0.12, 0.0, 1.0))
			var knuckle := 1.0 + 0.08 * exp(-pow((v - 0.45) / 0.06, 2.0)) + 0.06 * exp(-pow((v - 0.77) / 0.05, 2.0))
			return Vector2(rr, rr * 0.92) * lerpf(1.0, 0.72, v) * knuckle * maxf(cap, 0.3), oo.merged({"up": inward, "closed_u": true}))
	# thumb
	var tb: Vector3 = w + down * 0.025 + fwd * 0.022 + inward * 0.008
	var tpts := [tb, tb + (down * 0.6 + fwd * 0.55 + inward * 0.25).normalized() * 0.032,
		tb + (down * 0.9 + fwd * 0.55 + inward * 0.55).normalized() * 0.058,
		tb + (down * 1.0 + fwd * 0.35 + inward * 0.9).normalized() * 0.076]
	Geo.tube(st, func(t): return Geo.crspline(tpts, t), 10, 12, func(v, th):
		var cap := sqrt(clampf((1.0 - v) / 0.14, 0.0, 1.0))
		return Vector2(0.0105, 0.0095) * lerpf(1.15, 0.75, v) * maxf(cap, 0.3), oo.merged({"up": inward, "closed_u": true}))

## Cloth folds: sharp-valleyed ridges whose phase drifts with height.
static func folds(th: float, y: float, n: float, seed: float) -> float:
	var a := sin(th * n + sin(y * 7.0 + seed) * 1.3 + seed)
	var b := sin(th * n * 2.3 + y * 5.0 + seed * 2.0)
	return (1.0 - absf(a)) * 0.75 + b * 0.25 - 0.5
