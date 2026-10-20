## Garments and armour, each built by offsetting the body's own surfaces.
class_name Outfits
extends RefCounted

var c: Character
var b: Body

func _setup(ch: Character) -> void:
	c = ch; b = ch.body

static func radial(p: Vector3) -> Vector3:
	return Vector3(p.x, 0.0, p.z + 0.01)

# ---------------------------------------------------------------- helpers
func skirt_fn(y_top: float, y_bot: float, off: float, flare: float, nf: float, amp: float, u0: float, seed: float, extra := 0.0) -> Callable:
	return func(uu: float, v: float) -> Vector3:
		var u = lerpf(u0, 1.0 - u0, uu)
		var y = lerpf(y_top, y_bot, v)
		var th = u * TAU
		var base = b.torso(u, y_top, off)
		var sc = 1.0 + flare * pow(v, 1.25)
		var p = Vector3(base.x * sc, y, base.z * sc + 0.012 * v)
		var need = b.torso(u, clampf(y, Body.Y0, Body.Y1), off + 0.004)
		if y < 0.80:
			need = Vector3(sin(th) * (0.215 + off), y, cos(th) * (0.15 + off))
		var rr = Vector2(p.x, p.z).length()
		var rn = Vector2(need.x, need.z).length()
		if rr < rn:
			var k = rn / maxf(rr, 1e-5)
			p.x *= k; p.z *= k
		var f = Body.folds(th, y, nf, seed) * amp * smoothstep(0.0, 0.6, v)
		p += radial(p).normalized() * (f + extra)
		p.y += 0.008 * sin(th * nf * 0.5 + seed) * v * v
		return p

## Closed torso layer with optional folds and a trim band near an edge.
func bodice(key: String, y0: float, y1: float, off: float, o := {}) -> void:
	var amp: float = o.get("folds", 0.0)
	var nf: float = o.get("nf", 9.0)
	var bb: Body = o.get("body", b)
	var u0: float = o.get("u0", 0.0)
	var closed: bool = u0 == 0.0
	var trim: Array = o.get("trim", []) # [v_from, v_to]
	var P = func(uu: float, v: float) -> Vector3:
		var u = lerpf(u0, 1.0 - u0, uu)
		var y = lerpf(y0, y1, v)
		var p = bb.torso(u, y, off)
		if amp > 0.0:
			var f = Body.folds(u * TAU, y, nf, 1.3) * amp * (0.4 + 0.6 * smoothstep(1.2, 0.95, y))
			p += radial(p).normalized() * f
		return p
	var circ = 0.95
	Geo.patch(c.st(key), P, o.get("nu", 64), o.get("nv", 30), {
		"closed_u": closed, "bfn": c.AUTO(),
		"uvfn": func(u, v, p): return Vector2(u * circ, p.y),
		"uv2fn": func(u, v, p):
			if trim.size() == 2: return Vector2(u * circ, clampf((v - trim[0]) / (trim[1] - trim[0]), 0.0, 1.0))
			return Vector2(u, v),
		"cfn": func(u, v, p):
			var r = 0.0
			if trim.size() == 2 and v >= trim[0] and v <= trim[1]: r = 1.0
			return Color(r, 0, 0, 1),
		"orient": func(u, v, p): return radial(p),
	})

## Skirt / robe hanging from y_top: follows the hips, then flares with folds.
## u0 > 0 leaves a front opening. trims: hem band height (m) and edge band.
func skirt(key: String, y_top: float, y_bot: float, off: float, flare: float, nf: float, amp: float, o := {}) -> void:
	var u0: float = o.get("u0", 0.0)
	var closed: bool = u0 == 0.0
	var hem_band: float = o.get("hem_band", 0.0)
	var edge_band: float = o.get("edge_band", 0.0)
	var seed: float = o.get("seed", 0.7)
	var swing: String = o.get("swing", "")
	var L = y_top - y_bot
	var P = skirt_fn(y_top, y_bot, off, flare, nf, amp, u0, seed)
	var bfn: Callable
	if swing != "":
		var pel: int = c.B.pelvis
		var sf: int = c.B.skirtF
		var sb: int = c.B.skirtB
		bfn = func(u, v, p): return [pel, sf if p.z > 0.0 else sb, smoothstep(0.05, 1.0, v) * 0.9]
	else:
		bfn = c.AUTO()
	var circ = 1.3
	Geo.patch(c.st(key), P, o.get("nu", 96), o.get("nv", 40), {
		"closed_u": closed, "bfn": bfn,
		"uvfn": func(u, v, p): return Vector2(u * circ * (1.0 + flare * v), v * L),
		"uv2fn": func(u, v, p):
			var eh = (1.0 - v) * L
			var es = minf(u, 1.0 - u) * circ * (1.0 + flare * v) if not closed else 1e3
			if eh < es or edge_band == 0.0:
				return Vector2(u * circ * (1.0 + flare * v), 1.0 - clampf(eh / maxf(hem_band, 1e-4), 0.0, 1.0))
			return Vector2(v * L, 1.0 - clampf(es / maxf(edge_band, 1e-4), 0.0, 1.0)),
		"cfn": func(u, v, p):
			var r = 0.0
			if hem_band > 0.0 and (1.0 - v) * L < hem_band: r = 1.0
			if edge_band > 0.0 and not closed and minf(u, 1.0 - u) * circ * (1.0 + flare * v) < edge_band: r = 1.0
			return Color(r, 0, 0.15 * (1.0 - smoothstep(0.0, 0.1, v)), 1),
		"orient": func(u, v, p): return radial(p),
	})

func ext_curve(crv: Callable, s: float) -> Vector3:
	if s <= 1.0: return crv.call(clampf(s, 0.0, 1.0))
	var e: Vector3 = crv.call(1.0)
	var d: Vector3 = (e - crv.call(0.97)) / 0.03
	return e + d * (s - 1.0)

## Sleeve or wrap around a limb between v0..v1 with folds and optional flare.
func limbwrap(key: String, crv: Callable, rad: Callable, v0: float, v1: float, off: float, o := {}) -> void:
	var amp: float = o.get("folds", 0.0)
	var flare: float = o.get("flare", 0.0)
	var nf: float = o.get("nf", 7.0)
	var band: float = o.get("band", 0.0) # trim band near v1 (fraction)
	var cuff: float = o.get("cuff", 0.0)
	var cc = func(t: float) -> Vector3: return ext_curve(crv, lerpf(v0, v1, t))
	var rf = func(t: float, th: float) -> Vector2:
		var s = lerpf(v0, v1, t)
		var r: Vector2 = rad.call(clampf(s, 0.0, 1.0)) + Vector2(off, off)
		r += Vector2(1, 1) * flare * pow(t, 2.0)
		r += Vector2(1, 1) * cuff * exp(-pow((t - 0.96) / 0.05, 2.0))
		var f = Body.folds(th, s * 3.0, nf, 2.1) * amp * (0.5 + 0.5 * t)
		return r + Vector2(f, f)
	Geo.tube(c.st(key), cc, o.get("nu", 32), o.get("nv", 24), rf, {
		"bfn": c.AUTO(), "up": o.get("up", Vector3.FORWARD),
		"uvfn": func(u, v, p): return Vector2(u * 0.3, v * 0.4),
		"uv2fn": func(u, v, p): return Vector2(u * 0.3, clampf((v - (1.0 - band)) / maxf(band, 1e-4), 0.0, 1.0)),
		"cfn": func(u, v, p): return Color(1.0 if band > 0.0 and v > 1.0 - band else 0.0, 0, 0, 1),
	})

## Rounded band around the torso (belts, sashes).
func belt(key: String, y: float, h: float, off: float, thick: float, o := {}) -> void:
	var tilt: float = o.get("tilt", 0.0)
	var P = func(u: float, v: float) -> Vector3:
		var th = u * TAU
		var yy = y + (v - 0.5) * h + tilt * cos(th)
		var bulge = thick * pow(maxf(sin(PI * v), 0.0), 0.3)
		return b.torso(u, yy, off + bulge)
	Geo.patch(c.st(key), P, 72, 8, {"bfn": c.AUTO(),
		"uvfn": func(u, v, p): return Vector2(u * 0.9, v * h),
		"uv2fn": func(u, v, p): return Vector2(u * 0.9, v),
		"cfn": func(u, v, p): return Color(o.get("band", 0.0), 0.6 * (1.0 - absf(v - 0.5) * 2.0), 0, 1),
		"orient": func(u, v, p): return radial(p)})

## Buckle: rounded-rectangle frame + prong, facing direction n at p.
func buckle(key: String, p: Vector3, n: Vector3, w: float, h: float, r := 0.0045) -> void:
	var f = Geo.frame(n, Vector3.UP)
	var ax: Vector3 = f[0]
	var ay: Vector3 = n.cross(ax).normalized()
	var crv = func(t: float) -> Vector3:
		var a = t * TAU
		var x = Body.se(cos(a), 6.0) * w * 0.5
		var yv = Body.se(sin(a), 6.0) * h * 0.5
		return p + ax * x + ay * yv + n * r
	Geo.tube(c.st(key), crv, 10, 64, func(v, th): return Vector2(r, r * 0.8), {"bfn": c.AUTO(), "closed_u": true,
		"cfn": func(u, v, pp): return Color(0, 0.8, 0, 1)})
	var prong = func(t: float) -> Vector3: return p + ax * lerpf(-w * 0.45, w * 0.3, t) + n * (r * 1.8)
	Geo.tube(c.st(key), prong, 8, 6, func(v, th): return Vector2(r * 0.55, r * 0.55), {"bfn": c.AUTO(),
		"cfn": func(u, v, pp): return Color(0, 0.8, 0, 1)})

## Flat strap along points.
func strap(key: String, pts: Array, w: float, th: float, up: Vector3, band := 0.0) -> void:
	var crv = func(t: float) -> Vector3: return Geo.crspline(pts, t)
	Geo.tube(c.st(key), crv, 12, 48, func(v, a): return Vector2(th * 0.5, w * 0.5), {"bfn": c.AUTO(), "up": up,
		"uvfn": func(u, v, p): return Vector2(u * 0.05, v * 1.2),
		"uv2fn": func(u, v, p): return Vector2(v * 1.2, 0.5 + 0.5 * cos(u * TAU)),
		"cfn": func(u, v, p): return Color(band, 0.5, 0, 1)})

func boot(key: String, side: String, top_v: float, off: float, o := {}) -> void:
	limbwrap(key, b.leg_curve(side), func(s): return b.leg_radius(s), top_v, 1.0, off, {"folds": o.get("folds", 0.0), "nf": 6.0, "cuff": o.get("cuff", 0.0), "nv": 18})
	var a: Vector3 = b.J["ankle_" + side]
	var pts = [a + Vector3(0, 0.035, -0.012), a + Vector3(0, -0.028, 0.006), a + Vector3(0, -0.046, 0.08), a + Vector3(0, -0.05, 0.15), a + Vector3(0, -0.052, 0.175)]
	var crv = func(t: float) -> Vector3: return Geo.crspline(pts, t)
	Geo.tube(c.st(key), crv, 28, 22, func(v, th):
		var cap = sqrt(clampf((1.0 - v) / 0.1, 0.0, 1.0))
		var r = Vector2(Geo.table([[0.0, 0.040 + off], [0.3, 0.045 + off], [0.7, 0.040 + off], [1.0, 0.030]], v), Geo.table([[0.0, 0.046 + off], [0.3, 0.040 + off], [0.7, 0.028 + off], [1.0, 0.022]], v))
		return r * maxf(cap, 0.15), {"bfn": c.AUTO(), "up": Vector3.UP,
			"uvfn": func(u, vv, p): return Vector2(u * 0.3, vv * 0.25)})

## Spherical-band plate (pauldron lames, poleyns). Local +y up, +x outward.
func dome(key: String, centre: Vector3, R: Vector3, th0: float, th1: float, az: float, s: float, thick: float, rim: float, bone: String, o := {}) -> void:
	var tilt: float = o.get("tilt", 0.0)
	var closed = az >= PI - 1e-3
	var S = func(u: float, v: float) -> Vector3:
		var a = lerpf(-az, az, u)
		var th = lerpf(th0, th1, v)
		var d = Vector3(sin(th) * cos(a), cos(th), sin(th) * sin(a))
		d = d.rotated(Vector3.FORWARD, -tilt)
		return centre + Vector3(d.x * R.x * s, d.y * R.y, d.z * R.z)
	Geo.shell(c.st(key), S, 40, 14, thick, rim, {"closed_u": closed, "bfn": c.rigid(bone), "rim_w": o.get("rim_w", 0.14),
		"edges": o.get("edges", [th0 > 0.01, true, true, true]),
		"uvfn": func(u, v, p): return Vector2(u * 0.3, v * 0.15),
		"uv2fn": func(u, v, p): return Vector2(u * 0.35, clampf((v - 0.55) / 0.3, 0.0, 1.0)),
		"cfn": o.get("cfn", Callable()), "invert": o.get("invert", false)})

## Tube-plate around a limb segment with rolled rims at both ends.
func limbplate(key: String, crv: Callable, rad: Callable, v0: float, v1: float, off: float, thick: float, rim: float, o := {}) -> void:
	var front: float = o.get("front", 1.0) # 1 = full tube, <1 = open band facing forward
	var S = func(u: float, v: float) -> Vector3:
		var s = lerpf(v0, v1, v)
		var p0: Vector3 = crv.call(clampf(s, 0.0, 1.0))
		var p1: Vector3 = crv.call(clampf(s + 0.01, 0.0, 1.0))
		var t = (p1 - p0).normalized()
		var f = Geo.frame(t, Vector3.FORWARD)
		var n: Vector3 = f[0]
		var bb: Vector3 = f[1]
		var a = lerpf(-PI * front, PI * front, u) + PI * 0.5
		var r: Vector2 = rad.call(s) + Vector2(off, off) * (1.0 + 0.15 * sin(v * PI))
		return p0 + n * cos(a) * r.x + bb * sin(a) * r.y
	Geo.shell(c.st(key), S, 40, 16, thick, rim, {"closed_u": front >= 1.0, "bfn": c.AUTO(), "rim_w": o.get("rim_w", 0.12),
		"uvfn": func(u, v, p): return Vector2(u * 0.3, v * 0.2), "invert": o.get("invert", false),
		"cfn": o.get("cfn", Callable())})

# ---------------------------------------------------------------- paladin
func paladin(ch: Character) -> void:
	_setup(ch)
	var ab = Body.new({"bust": 0.012}) # armour form: smoothed bust, same frame
	# gambeson under-layer at the arms and thighs
	for s in ["L", "R"]:
		limbwrap("under", b.arm_curve(s), func(v): return b.arm_radius(v), 0.05, 0.98, 0.010, {"folds": 0.0025, "nf": 6.0})
		limbwrap("under", b.leg_curve(s), func(v): return b.leg_radius(v), 0.02, 0.70, 0.012, {"folds": 0.003})
	bodice("under", 0.80, 1.40, 0.010, {"folds": 0.002})
	# cuirass with keel ridge, filigree band under the neckline
	var S = func(u: float, v: float) -> Vector3:
		var y = lerpf(1.0, 1.43, v)
		var p = ab.torso(u, y, lerpf(0.016, 0.030, smoothstep(0.0, 0.45, v)) + 0.006 * sin(v * PI))
		var keel = 0.007 * exp(-pow(p.x / 0.03, 2.0)) * smoothstep(0.0, 0.5, cos(u * TAU)) * sin(v * PI)
		p.z += keel
		return p
	Geo.shell(c.st("steel"), S, 96, 40, 0.004, 0.005, {"closed_u": true, "bfn": c.AUTO(), "rim_w": 0.05,
		"uvfn": func(u, v, p): return Vector2(u * 1.0, p.y),
		"uv2fn": func(u, v, p): return Vector2(u * 1.0, clampf((v - 0.80) / 0.11, 0.0, 1.0)),
		"cfn": func(u, v, p): return Color(1.0 if v > 0.80 and v < 0.91 else 0.0, 0, 0, 1)})
	# gorget lames
	for k in 3:
		var G = func(u: float, v: float) -> Vector3:
			var y = lerpf(1.405 + 0.024 * k, 1.435 + 0.024 * k, v)
			var r = lerpf(0.080, 0.058, (y - 1.40) / 0.08)
			var th = u * TAU
			return Vector3(sin(th) * r, y, -0.024 + cos(th) * r * 0.92)
		Geo.shell(c.st("steel"), G, 48, 6, 0.003, 0.003, {"closed_u": true, "bfn": c.AUTO(), "rim_w": 0.25})
	# faulds: three overlapping hoops below the waist
	for k in 3:
		var F = func(u: float, v: float) -> Vector3:
			return ab.torso(u, lerpf(1.035 - 0.05 * k, 0.965 - 0.05 * k, v), 0.040 + 0.006 * k)
		Geo.shell(c.st("steel"), F, 72, 8, 0.003, 0.004, {"closed_u": true, "bfn": c.AUTO(), "rim_w": 0.22})
	belt("leather", 1.03, 0.032, 0.046, 0.004)
	buckle("gold", b.torso(0.0, 1.03, 0.054), Vector3(0, 0, 1), 0.042, 0.036)
	# tabard front and back panels with embroidered borders
	for back in [false, true]:
		var uc = 0.5 if back else 0.0
		var W = 0.30
		var Lt = 0.56
		var SK = skirt_fn(0.955, 0.955 - Lt, 0.020, 0.20, 13.0, 0.0, 0.0, 0.3, 0.016)
		var T = func(u: float, v: float) -> Vector3:
			var uu = fposmod(uc + (u - 0.5) * 0.25, 1.0)
			var p: Vector3 = SK.call(uu, v)
			var f = Body.folds(u * 9.0, p.y, 3.0, 0.4 if back else 1.7) * 0.006 * smoothstep(0.0, 0.5, v)
			p += radial(p).normalized() * (f + 0.006 * v)
			return p
		var bw = 0.032
		var pel: int = c.B.pelvis
		var sw: int = c.B.skirtB if back else c.B.skirtF
		Geo.patch(c.st("tabard"), T, 24, 30, {"closed_u": false,
			"bfn": func(u, v, p): return [pel, sw, smoothstep(0.0, 1.0, v) * 0.9],
			"uvfn": func(u, v, p): return Vector2(u * W, v * Lt),
			"uv2fn": func(u, v, p):
				var eh = (1.0 - v) * Lt
				var es = minf(u, 1.0 - u) * W
				if eh < es: return Vector2(u * W, 1.0 - eh / bw)
				return Vector2(v * Lt, 1.0 - es / bw),
			"cfn": func(u, v, p): return Color(1.0 if minf((1.0 - v) * Lt, minf(u, 1.0 - u) * W) < bw else 0.0, 0, 0, 1),
			"orient": func(u, v, p): return Vector3(0, 0, -1 if back else 1)})
	skirt("under", 0.955, 0.44, 0.020, 0.20, 13.0, 0.007, {"swing": "y", "seed": 0.3})
	# pauldrons: four overlapping lames per shoulder
	for s in ["L", "R"]:
		var sg = 1.0 if s == "L" else -1.0
		var sc: Vector3 = b.J["shoulder_" + s] + Vector3(sg * 0.012, 0.012, 0.0)
		dome("steel", sc, Vector3(0.090, 0.075, 0.095), 0.0, 0.62, PI, sg, 0.004, 0.005, "upperarm_" + s, {"tilt": sg * 0.35,
			"cfn": func(u, v, p): return Color(1.0 if v > 0.62 and v < 0.86 else 0.0, 0, 0, 1)})
		for k in 3:
			var r = 0.094 + 0.006 * k
			dome("steel", sc + Vector3(0, -0.012 * k, 0), Vector3(r, r * 0.86, r * 1.02), 0.52 + 0.26 * k, 0.86 + 0.26 * k, PI * 0.62, sg, 0.0035, 0.0045, "upperarm_" + s, {"tilt": sg * 0.35, "rim_w": 0.2})
		# rerebrace, couter, vambrace
		var ac = b.arm_curve(s)
		var ar = func(v): return b.arm_radius(v)
		limbplate("steel", ac, ar, 0.30, 0.56, 0.020, 0.003, 0.004)
		var el: Vector3 = b.J["elbow_" + s]
		dome("steel", el + Vector3(0, 0.0, -0.01), Vector3(0.05, 0.055, 0.05), 0.0, 1.2, PI, sg, 0.003, 0.004, "forearm_" + s, {"tilt": 0.0})
		limbplate("steel", ac, ar, 0.66, 0.93, 0.017, 0.003, 0.004, {"cfn": func(u, v, p): return Color(0, 0, 0, 1)})
		limbwrap("leather", ac, ar, 0.90, 1.0, 0.016, {"flare": 0.012, "nv": 6})
		b.hand(c.st("leather"), s, c.B["hand_" + s], 0.12)
		# legs: greaves over boots, knee cops
		var lc = b.leg_curve(s)
		var lr = func(v): return b.leg_radius(v)
		boot("leather", s, 0.60, 0.010)
		limbplate("steel", lc, lr, 0.60, 0.92, 0.020, 0.003, 0.004, {"front": 0.55})
		var kn: Vector3 = b.J["knee_" + s]
		dome("steel", kn + Vector3(0, 0, 0.0), Vector3(0.058, 0.062, 0.064), 0.0, 1.25, PI, sg, 0.003, 0.004, "shin_" + s, {"tilt": 0.0, "edges": [false, true, true, true]})

# ---------------------------------------------------------------- mage
func mage(ch: Character) -> void:
	_setup(ch)
	# high-collared dress with an embroidered yoke
	bodice("dress", 0.98, 1.462, 0.006, {"folds": 0.0018, "nf": 12.0, "trim": [0.80, 0.93]})
	var col = func(u: float, v: float) -> Vector3:
		var y = lerpf(1.44, 1.505, v)
		var th = u * TAU
		var r = lerpf(0.064, 0.058, v) + 0.002 * sin(v * PI)
		return Vector3(sin(th) * r, y, -0.026 + cos(th) * r * 0.98)
	Geo.shell(c.st("dress"), col, 48, 8, 0.003, 0.003, {"closed_u": true, "bfn": c.AUTO(), "rim_w": 0.15,
		"uvfn": func(u, v, p): return Vector2(u * 0.4, v * 0.06),
		"uv2fn": func(u, v, p): return Vector2(u * 0.4, v),
		"cfn": func(u, v, p): return Color(1, 0, 0, 1)})
	skirt("dress", 1.04, 0.012, 0.008, 1.05, 14.0, 0.012, {"swing": "y", "hem_band": 0.06, "seed": 0.9})
	# open over-robe: fitted torso, long split panels, wide embroidered edges
	bodice("robe", 0.96, 1.425, 0.018, {"u0": 0.055, "folds": 0.002, "nf": 8.0, "nu": 56})
	skirt("robe", 0.98, 0.10, 0.022, 0.95, 9.0, 0.020, {"u0": 0.07, "swing": "y", "hem_band": 0.10, "edge_band": 0.06, "seed": 2.1})
	# front edge trims running up the torso of the robe
	for sgn in [1.0, -1.0]:
		var E = func(u: float, v: float) -> Vector3:
			var y = lerpf(0.97, 1.43, v)
			var uu = (0.055 + u * 0.035) * sgn
			return b.torso(fposmod(uu, 1.0), y, 0.0215)
		Geo.patch(c.st("robe"), E, 4, 24, {"closed_u": false, "bfn": c.AUTO(),
			"uvfn": func(u, v, p): return Vector2(u * 0.05, p.y),
			"uv2fn": func(u, v, p): return Vector2(p.y, u),
			"cfn": func(u, v, p): return Color(1, 0, 0, 1),
			"orient": func(u, v, p): return radial(p)})
	# bell sleeves
	for s in ["L", "R"]:
		var ac = b.arm_curve(s)
		var ar = func(v): return b.arm_radius(v)
		limbwrap("dress", ac, ar, 0.55, 0.99, 0.006, {"folds": 0.0015})
		limbwrap("robe", ac, ar, 0.04, 1.06, 0.013, {"flare": 0.075, "folds": 0.008, "nf": 7.0, "band": 0.16, "nu": 48, "nv": 34})
		b.hand(c.st("skin_body"), s, c.B["hand_" + s], 0.08)

	# sash with knot and hanging tails
	belt("sash", 1.035, 0.05, 0.026, 0.006, {"band": 1.0})
	var kp = b.torso(0.035, 1.03, 0.04)
	for k in 2:
		var off = Vector3(0.012 + 0.025 * k, 0, 0)
		var pts = [kp + off, kp + off + Vector3(0.006, -0.12, 0.03), kp + off + Vector3(0.012 * k, -0.28, 0.06 + 0.01 * k), kp + off + Vector3(0.02, -0.42, 0.075)]
		strap("sash", pts, 0.05, 0.004, Vector3(0, 0, 1), 1.0)
	c.st("sash")
	Geo.ellipsoid(c.st("sash"), kp + Vector3(0.02, 0.0, 0.008), Vector3(0.028, 0.03, 0.016), 20, 12, {"bfn": c.AUTO()})
	# stole
	for sg in [1.0, -1.0]:
		var pts = [Vector3(sg * 0.055, 1.47, -0.07), Vector3(sg * 0.085, 1.45, 0.02), Vector3(sg * 0.075, 1.36, 0.105), Vector3(sg * 0.07, 1.16, 0.115), Vector3(sg * 0.07, 0.95, 0.12), Vector3(sg * 0.068, 0.62, 0.15)]
		strap("sash", pts, 0.055, 0.003, Vector3(0, 0, 1), 1.0)
	# pendant on a chain
	var chain = [Vector3(-0.045, 1.47, 0.03), Vector3(-0.02, 1.34, 0.115), Vector3(0, 1.31, 0.122), Vector3(0.02, 1.34, 0.115), Vector3(0.045, 1.47, 0.03)]
	Geo.tube(c.st("gold"), func(t): return Geo.crspline(chain, t), 6, 60, func(v, th): return Vector2(0.0012, 0.0012), {"bfn": c.AUTO()})
	var pc = Vector3(0, 1.29, 0.128)

	Geo.ellipsoid(c.st("gold"), pc, Vector3(0.017, 0.023, 0.006), 24, 14, {"bfn": c.AUTO()})
	Geo.ellipsoid(c.st("gem"), pc + Vector3(0, 0, 0.004), Vector3(0.010, 0.015, 0.006), 24, 14, {"bfn": c.AUTO()})
	# ring
	var w: Vector3 = b.J.wrist_L
	Geo.tube(c.st("gold"), func(t): return w + Vector3(-0.004 + 0.0105 * cos(t * TAU), -0.118, 0.010 + 0.0105 * sin(t * TAU)), 6, 24, func(v, th): return Vector2(0.0016, 0.0016), {"bfn": c.AUTO()})

# ---------------------------------------------------------------- ranger
func ranger(ch: Character) -> void:
	_setup(ch)
	bodice("shirt", 0.95, 1.462, 0.006, {"folds": 0.002})
	for s in ["L", "R"]:
		var ac = b.arm_curve(s)
		var ar = func(v): return b.arm_radius(v)
		limbwrap("shirt", ac, ar, 0.04, 0.74, 0.014, {"folds": 0.005, "nf": 7.0, "flare": 0.006})
		# bracers with strap rings
		limbplate("leather", ac, ar, 0.66, 0.95, 0.014, 0.003, 0.0035, {"cfn": func(u, v, p): return Color(0, 0, 0, 1)})
		for k in 3:
			var vv = 0.71 + 0.08 * k
			limbwrap("leather2", ac, ar, vv, vv + 0.022, 0.0195, {"nv": 3, "nu": 24})
		b.hand(c.st("leather2"), s, c.B["hand_" + s], 0.15)
		# trousers and tall boots
		var lc = b.leg_curve(s)
		var lr = func(v): return b.leg_radius(v)
		limbwrap("pants", lc, lr, 0.0, 0.72, 0.010, {"folds": 0.004, "nf": 6.0})
		boot("leather2", s, 0.56, 0.012, {"cuff": 0.010, "folds": 0.002})
	bodice("pants", 0.80, 1.0, 0.009)
	# jerkin: leather shell, open lacing band at the centre front (diamond tooling)
	var S = func(u: float, v: float) -> Vector3:
		var uu = lerpf(0.02, 0.98, u)
		return b.torso(uu, lerpf(0.86, 1.39, v), 0.017 + 0.004 * smoothstep(0.3, 0.0, v))
	Geo.shell(c.st("leather"), S, 80, 34, 0.004, 0.003, {"closed_u": false, "bfn": c.AUTO(), "rim_w": 0.035,
		"uvfn": func(u, v, p): return Vector2(u * 0.95, p.y),
		"uv2fn": func(u, v, p): return Vector2(p.y * 1.0, clampf(minf(u, 1.0 - u) / 0.035, 0.0, 1.0)),
		"cfn": func(u, v, p): return Color(1.0 if minf(u, 1.0 - u) < 0.035 else 0.0, 0, 0, 1)})
	# laces across the opening
	for k in 6:
		var y = 0.94 + 0.075 * k
		var pl = b.torso(0.022, y, 0.023)
		var pr = b.torso(0.978, y + 0.03, 0.023)
		var pts = [pl, (pl + pr) * 0.5 + Vector3(0, 0.015, 0.006), pr]
		Geo.tube(c.st("leather2"), func(t): return Geo.crspline(pts, t), 6, 10, func(v, th): return Vector2(0.0018, 0.0018), {"bfn": c.AUTO()})
	belt("leather2", 0.90, 0.040, 0.024, 0.004, {"tilt": 0.018})
	buckle("steel", b.torso(0.0, 0.918, 0.032), Vector3(0, 0, 1), 0.040, 0.036)
	# pouch on the right hip
	var pp = b.torso(0.86, 0.86, 0.06)
	Geo.shell(c.st("leather"), func(u, v):
		var th = lerpf(-1.2, 1.2, u)
		return pp + Vector3(-0.045 * sin(th) * 0.5 - 0.02, lerpf(0.04, -0.06, v), 0.03 * cos(th)), 16, 10, 0.004, 0.004, {"closed_u": false, "bfn": c.AUTO(), "rim_w": 0.15})
	# hooded capelet: mantle over the shoulders + hood folded down behind the neck
	var M = func(u: float, v: float) -> Vector3:
		var y = lerpf(1.47, 1.20, v)
		var th = u * TAU
		var p = b.torso(u, clampf(y, Body.Y0, 1.46), 0.0)
		var r = Vector2(p.x, p.z + 0.015).length()
		var sh = b.torso(u, 1.37, 0.0)
		var rsh = Vector2(sh.x, sh.z + 0.015).length()
		var R = maxf(r, rsh * smoothstep(1.47, 1.36, y)) + 0.035 + 0.02 * v + Body.folds(th, y, 10.0, 0.5) * 0.012 * v
		R += 0.05 * v * v * maxf(0.0, -cos(th)) # drapes further at the back
		var dir = Vector2(p.x, p.z + 0.015).normalized()
		return Vector3(dir.x * R, y - 0.01 * v * sin(th * 5.0), dir.y * R - 0.015)
	Geo.patch(c.st("cloak"), M, 96, 22, {"bfn": c.AUTO(), "orient": func(u, v, p): return radial(p),
		"uvfn": func(u, v, p): return Vector2(u * 1.2, p.y),
		"uv2fn": func(u, v, p): return Vector2(u * 1.2, clampf((v - 0.84) / 0.12, 0.0, 1.0)),
		"cfn": func(u, v, p): return Color(1.0 if v > 0.84 and v < 0.96 else 0.0, 0, 0, 1)})
	var hood = func(t: float) -> Vector3:
		var a = lerpf(-1.9, 1.9, t)
		return Vector3(sin(a) * 0.105, 1.475 - 0.02 * cos(a), -0.03 - cos(a) * 0.095)
	Geo.tube(c.st("cloak"), hood, 24, 40, func(v, th): return Vector2(0.032, 0.026) * pow(sin(v * PI), 0.6) * (1.0 + 0.05 * sin(th * 3.0 + v * 9.0)), {"bfn": c.AUTO(), "up": Vector3.UP,
		"uvfn": func(u, v, p): return Vector2(u * 0.2, v * 0.6)})
	# clasp
	Geo.ellipsoid(c.st("steel"), Vector3(0, 1.43, 0.065), Vector3(0.012, 0.012, 0.005), 18, 10, {"bfn": c.AUTO()})
	# quiver baldric across the chest + quiver with fletchings on the back
	var bal = [Vector3(0.12, 1.42, -0.06), Vector3(0.14, 1.40, 0.05), Vector3(0.05, 1.26, 0.118), Vector3(-0.08, 1.06, 0.112), Vector3(-0.15, 0.95, 0.02), Vector3(-0.12, 0.98, -0.10), Vector3(0.02, 1.2, -0.12), Vector3(0.12, 1.42, -0.06)]
	strap("leather2", bal, 0.036, 0.004, Vector3(0, 0, 1))
	buckle("steel", Vector3(0.0, 1.20, 0.124), Vector3(0.05, 0.15, 1).normalized(), 0.03, 0.03, 0.0035)
	var qa = Vector3(-0.10, 0.98, -0.15)
	var qb = Vector3(0.10, 1.42, -0.17)
	Geo.shell(c.st("leather"), func(u, v):
		var a = u * TAU
		var p = qa.lerp(qb, v)
		var f = Geo.frame((qb - qa).normalized(), Vector3.FORWARD)
		var r = 0.040 + 0.004 * v
		return p + (f[0] as Vector3) * cos(a) * r + (f[1] as Vector3) * sin(a) * r * 0.85, 24, 12, 0.003, 0.004, {"closed_u": true, "bfn": c.AUTO(), "rim_w": 0.12, "edges": [false, true, true, true]})
	var qd = (qb - qa).normalized()
	for k in 7:
		var ang = k * 0.9
		var o = Vector3(cos(ang) * 0.022, 0, sin(ang) * 0.018)
		var a0 = qb + o - qd * 0.03
		var a1 = qb + o + qd * (0.10 + 0.01 * (k % 3))
		Geo.tube(c.st("wood"), func(t): return a0.lerp(a1, t), 6, 2, func(v, th): return Vector2(0.0035, 0.0035), {"bfn": c.AUTO()})
		for f in 3:
			var fa = ang + f * TAU / 3.0
			var fd = Vector3(cos(fa), 0, sin(fa)) * 0.012
			var p0 = a1 - qd * 0.07
			Geo.patch(c.st("fletch"), func(u, v): return p0.lerp(a1, v) + fd * u * (0.6 + 0.4 * sin(v * PI)), 1, 6, {"closed_u": false, "bfn": c.AUTO(),
				"uvfn": func(u, v, p): return Vector2(u, v), "cfn": func(u, v, p): return Color(0.5, 1.0, 1.0, 0.1 * k + 0.03 * f)})
