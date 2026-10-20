## Sculpted head from a signed-distance "clay" model: ~30 smooth-unioned
## primitives (cranium, jaw, cheekbones, brow, nose, lips, eyelids...) with
## carved eye openings. The mesh is a lat-long sphere (poles at the ears)
## whose every vertex is sphere-traced onto the SDF, and whose normal is the
## SDF gradient - so the surface is smooth with no seams or blobs.
## Head-local frame: origin mid-head at eye height, +Z forward, +Y up.
class_name Head
extends RefCounted

var F := {} # face parameters
var eye_c := [Vector3.ZERO, Vector3.ZERO] # [left(+x), right(-x)]
var eye_r := 0.0135
var hw := 0.0128 # eye opening half width
var hu := 0.0052 # upper lid height
var hl := 0.0043 # lower lid height

func _init(params := {}) -> void:
	F = {
		"jaw": 1.0, "chin": 1.0, "nose_len": 1.0, "nose_w": 1.0, "lip": 1.0, "cheek": 1.0,
		"eye_sep": 0.0305, "tilt": 0.10, "brow": 1.0, "face_len": 1.0, "skull_w": 1.0,
	}
	for k in params: F[k] = params[k]
	eye_c[0] = Vector3(F.eye_sep, 0.004, 0.0615)
	eye_c[1] = Vector3(-F.eye_sep, 0.004, 0.0615)

static func ell(p: Vector3, c: Vector3, r: Vector3) -> float:
	var q := (p - c) / r
	var k0 := q.length()
	var k1 := ((p - c) / (r * r)).length()
	return k0 * (k0 - 1.0) / maxf(k1, 1e-9)

static func cone(p: Vector3, a: Vector3, b: Vector3, ra: float, rb: float) -> float:
	var pa := p - a
	var ba := b - a
	var h := clampf(pa.dot(ba) / ba.dot(ba), 0.0, 1.0)
	return (pa - ba * h).length() - lerpf(ra, rb, h)

static func smin(a: float, b: float, k: float) -> float:
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)

static func smax(a: float, b: float, k: float) -> float:
	return -smin(-a, -b, k)

## Eye opening (almond) in eye-local 2D, s = side sign. Negative inside.
func almond(x: float, y: float, s: float) -> float:
	var xo := x * s # +outward
	var t := clampf(absf(x) / hw, 0.0, 1.0)
	var yu := hu * pow(1.0 - t * t, 0.62) * (1.0 + 0.18 * (xo / hw)) # peak slightly outward
	var yl := -hl * pow(1.0 - t * t, 0.85) * (1.0 - 0.15 * (xo / hw))
	var tilt: float = F.tilt * xo
	var yy := y - tilt
	return maxf(maxf(yy - yu, yl - yy), absf(x) - hw)

func sdf(p: Vector3) -> float:
	var jw: float = F.jaw
	var fl: float = F.face_len
	var sw: float = F.skull_w
	var d := ell(p, Vector3(0, 0.029, -0.013), Vector3(0.0725 * sw, 0.088, 0.094))
	# face mass + forehead plane
	d = smin(d, ell(p, Vector3(0, -0.016 * fl, 0.028), Vector3(0.052, 0.070 * fl, 0.066)), 0.022)
	d = smin(d, ell(p, Vector3(0, 0.050, 0.034), Vector3(0.061, 0.058, 0.051)), 0.022)
	for s in [-1.0, 1.0]:
		# jaw line: round cones from the jaw angle to the chin
		d = smin(d, cone(p, Vector3(s * 0.042 * jw, -0.052 * fl, -0.020), Vector3(s * 0.011, -0.090 * fl, 0.052), 0.013, 0.010), 0.022)
		# cheekbones (zygomatic) and soft cheeks
		var ck: float = F.cheek
		d = smin(d, ell(p, Vector3(s * 0.044, -0.013, 0.050), Vector3(0.016, 0.011, 0.019) * ck), 0.026)
		d = smin(d, ell(p, Vector3(s * 0.030, -0.030 * fl, 0.054), Vector3(0.016, 0.017, 0.019)), 0.020)
		# temples slightly hollow
		d = smax(d, -ell(p, Vector3(s * 0.078 * sw, 0.025, 0.045), Vector3(0.012, 0.022, 0.02)), 0.012)
	# chin and muzzle
	var ch: float = F.chin
	d = smin(d, ell(p, Vector3(0, -0.091 * fl, 0.059), Vector3(0.016 * ch, 0.014, 0.015)), 0.012)
	d = smin(d, ell(p, Vector3(0, -0.053 * fl, 0.066), Vector3(0.030, 0.027, 0.026)), 0.014)
	# neck
	d = smin(d, cone(p, Vector3(0, -0.040, -0.027), Vector3(0, -0.21, -0.032), 0.046, 0.053), 0.016)
	# brow ridge (soft for a female face)
	var br: float = F.brow
	d = smin(d, cone(p, Vector3(-0.036, 0.027, 0.0775), Vector3(0.036, 0.027, 0.0775), 0.0085 * br, 0.0085 * br), 0.016)
	# eye sockets
	for i in 2:
		var c: Vector3 = eye_c[i]
		d = smax(d, -ell(p, c + Vector3(0, 0.004, 0.020), Vector3(0.019, 0.012, 0.008)), 0.012)
	# nose
	var nl: float = F.nose_len
	var nw: float = F.nose_w
	var tip := Vector3(0, -0.027 * nl, 0.1035)
	d = smin(d, cone(p, Vector3(0, 0.016, 0.0815), tip + Vector3(0, 0.004, -0.004), 0.0062 * nw, 0.0085 * nw), 0.008)
	d = smin(d, ell(p, tip, Vector3(0.0095 * nw, 0.0085, 0.0088)), 0.006)
	for s in [-1.0, 1.0]:
		d = smin(d, ell(p, Vector3(s * 0.0115 * nw, -0.031 * nl, 0.0905), Vector3(0.0072, 0.0062, 0.0072)), 0.005)
	d = smin(d, ell(p, Vector3(0, -0.033 * nl, 0.097), Vector3(0.0055, 0.0042, 0.0062)), 0.004)
	# lips
	var lp: float = F.lip
	var ly := -0.0575 * fl
	d = smin(d, ell(p, Vector3(0, ly + 0.0058, 0.0855), Vector3(0.0190, 0.0048 * lp, 0.0080)), 0.006)
	for s in [-1.0, 1.0]:
		d = smin(d, ell(p, Vector3(s * 0.0058, ly + 0.0062, 0.0895), Vector3(0.0058, 0.0031 * lp, 0.0034)), 0.003)
	d = smin(d, ell(p, Vector3(0, ly - 0.0060, 0.0830), Vector3(0.0160, 0.0056 * lp, 0.0085)), 0.006)
	# philtrum groove and mouth line
	d = smax(d, -cone(p, Vector3(0, ly + 0.017, 0.0955), Vector3(0, ly + 0.009, 0.0960), 0.0018, 0.0022), 0.003)
	d = smax(d, -ell(p, Vector3(0, ly + 0.0002, 0.0968), Vector3(0.020, 0.0007, 0.0045)), 0.0016)
	# eyelids: shells over the eyeballs, then carve the almond openings
	for i in 2:
		var c: Vector3 = eye_c[i]
		var s := 1.0 if i == 0 else -1.0
		var q := p - c
		d = smin(d, q.length() - (eye_r + 0.0011), 0.0035)
		# upper lid crease: a soft fold above the opening
		d = smin(d, ell(p, c + Vector3(0.001 * s, 0.0085, 0.0085), Vector3(0.0135, 0.0032, 0.006)), 0.004)
		var a := almond(q.x, q.y, s)
		var tunnel := maxf(a, -q.z)
		d = smax(d, -tunnel, 0.0012)
	return d

func grad(p: Vector3) -> Vector3:
	var e := 0.00025
	var k1 := Vector3(1, -1, -1); var k2 := Vector3(-1, -1, 1)
	var k3 := Vector3(-1, 1, -1); var k4 := Vector3(1, 1, 1)
	return (k1 * sdf(p + k1 * e) + k2 * sdf(p + k2 * e) + k3 * sdf(p + k3 * e) + k4 * sdf(p + k4 * e)).normalized()

## Direction on the sphere with poles on the X axis (ears).
static func dir(u: float, v: float) -> Vector3:
	var ph := v * PI
	var th := u * TAU
	return Vector3(-cos(ph), sin(ph) * cos(th), sin(ph) * sin(th))

func trace(d: Vector3, offset := 0.0) -> Vector3:
	var r := 0.27
	for i in 90:
		var dist := sdf(d * r) - offset
		if dist < 0.00002:
			break
		r -= maxf(dist * 0.9, 0.00003)
	return d * r

## Build the skin mesh. UV = head-local (x, y), UV2 = (z, 0) for shader masks.
func build(st: SurfaceTool, nu: int, nv: int, bone: int, origin: Vector3) -> void:
	var P := func(u: float, v: float) -> Vector3: return trace(dir(u, v)) + origin
	Geo.patch(st, P, nu, nv, {
		"nfn": func(u, v, p): return grad(p - origin),
		"uvfn": func(u, v, p): return Vector2(p.x - origin.x, p.y - origin.y),
		"uv2fn": func(u, v, p): return Vector2(p.z - origin.z, 0.0),
		"bones": [bone],
	})
