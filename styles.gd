## Hair styles per character, grown as strand cards over the head SDF.
class_name Styles
extends RefCounted

var c: Character
var hr: Hair
var o: Vector3

func _setup(ch: Character, seed: int) -> void:
	c = ch; o = ch.body.J.head
	hr = Hair.new(ch.head, o, ch.body, seed)

## chain weights: head -> hairA -> hairB -> hairC by height below the head
func chain_bfn() -> Callable:
	var bh: int = c.B.head
	var ids = []
	for n in c.hair_bones: ids.append(c.B[n])
	var ys = [o.y - 0.06, o.y - 0.22, o.y - 0.42, o.y - 0.62]
	return func(u, v, p):
		var y: float = p.y
		if y > ys[0]: return [bh, ids[0], 0.0]
		if y > ys[1]: return [bh, ids[0], smoothstep(ys[0], ys[1], y)]
		if y > ys[2]: return [ids[0], ids[1], smoothstep(ys[1], ys[2], y)]
		return [ids[1], ids[2], clampf(smoothstep(ys[2], ys[3], y), 0.0, 1.0)]

func roots(n: int, pol_max_k := 0.96) -> Array:
	var out = []
	for i in n:
		var az = hr.rng.randf_range(-PI, PI)
		var pm = Hair.hairline(az) * pol_max_k
		var pol = pm * sqrt(hr.rng.randf_range(0.02, 1.0))
		out.append([az, pol])
	return out

## strands combed over the scalp toward a target point (hugging the head)
func toward(n: int, target: Vector3, st: SurfaceTool, width := 0.011, pol_k := 0.97, bfn = null) -> void:
	var strands = []
	var widths = []
	var lay = []
	if bfn == null:
		bfn = func(u, v, p): return [c.B.head, c.B.head, 0.0]
	var tdir = (target - o).normalized()
	for r in roots(n, pol_k):
		var layer = hr.rng.randf()
		var off = 0.0022 + 0.0055 * layer
		var d0 = hr.scalp_dir(r[0], r[1])
		var tj = (tdir + Vector3(hr.rng.randf_range(-0.05, 0.05), hr.rng.randf_range(-0.05, 0.05), 0)).normalized()
		var pts = hr.hug(d0, tj, off, off + 0.004, 14)
		pts[pts.size() - 1] = pts[pts.size() - 1].lerp(target, 0.6)
		strands.append(pts); widths.append(width * hr.rng.randf_range(0.8, 1.2)); lay.append(0.45 + 0.55 * layer)
	hr.cards(st, strands, widths, bfn, lay)

func paladin(ch: Character) -> void:
	_setup(ch, 11)
	hr.cap(c.st("haircap"), 0.0022, c.B.head)
	var T = o + Vector3(0, -0.062, -0.088)
	toward(520, T, c.st("hair"), 0.011)
	# a few loose face-framing strands from the temples
	var strands = []; var ws = []; var lay = []
	for sg in [1.0, -1.0]:
		for k in 2:
			var az: float = sg * (1.0 + 0.08 * k)
			var root = hr.scalp_point(az, Hair.hairline(az) * 0.9, 0.004)
			var comb = func(p, i): return Vector3(sg * 0.15, -1.0, 0.25)
			strands.append(hr.grow(root, Vector3(sg * 0.3, -1, 0.6), 0.10 + 0.015 * k, 10, comb, 0.006, 0.8))
			ws.append(0.013); lay.append(0.9)
	hr.cards(c.st("hair"), strands, ws, func(u, v, p): return [c.B.head, c.B.head, 0.0], lay)
	# braid down the back, over the armour
	var bpts = [T, T + Vector3(0.004, -0.07, -0.025)]
	for y in [1.40, 1.30, 1.20, 1.10, 1.02]:
		var z = c.body.torso(0.5, y, 0.074).z
		bpts.append(Vector3(0.006 * sin(y * 9.0), y, z))
	var centre = func(t: float) -> Vector3: return Geo.crspline(bpts, t)
	hr.braid(c.st("braid"), centre, 0.024, 9.0, chain_bfn())
	# tie and tassel
	var end = centre.call(1.0) as Vector3
	Geo.tube(c.st("leather"), func(t): return end + Vector3(cos(t * TAU) * 0.014, 0.0, sin(t * TAU) * 0.012), 8, 20, func(v, th): return Vector2(0.004, 0.006), {"bfn": chain_bfn()})
	strands = []; ws = []; lay = []
	for k in 40:
		var a = hr.rng.randf() * TAU
		var root = end + Vector3(cos(a) * 0.009, 0.0, sin(a) * 0.008)
		var comb = func(p, i): return Vector3(cos(a) * 0.1, -1.0, sin(a) * 0.1)
		strands.append(hr.grow(root, Vector3(cos(a) * 0.15, -1, sin(a) * 0.15), hr.rng.randf_range(0.07, 0.11), 6, comb, 0.0, 1.0))
		ws.append(0.010); lay.append(hr.rng.randf_range(0.5, 1.0))
	hr.cards(c.st("hair"), strands, ws, chain_bfn(), lay)

func mage(ch: Character) -> void:
	_setup(ch, 22)
	hr.cap(c.st("haircap"), 0.0022, c.B.head)
	var strands = []; var ws = []; var lay = []
	for r in roots(900, 0.97):
		var az: float = r[0]
		var layer = hr.rng.randf()
		var off = 0.0025 + 0.008 * layer
		var side = signf(sin(az)) if absf(sin(az)) > 0.04 else (1.0 if hr.rng.randf() > 0.5 else -1.0)
		var front = absf(az) < 1.5
		var azf = side * maxf(absf(az), 1.25 + 0.15 * hr.rng.randf()) if front else az
		var polf = 1.62 if front else lerpf(1.62, 2.05, (absf(az) - 1.5) / (PI - 1.5))
		var d0 = hr.scalp_dir(az, r[1])
		var d1 = hr.scalp_dir(azf, polf)
		var pts = hr.hug(d0, d1, off, off + 0.006, 10, 0.4)
		var fwd = 0.25 if (front and absf(az) < 1.0 and hr.rng.randf() < 0.55) else -0.12
		var comb = func(p, i): return Vector3(side * 0.05, -0.6, fwd * (1.0 - float(i) / 16.0))
		pts = hr.fall(pts, hr.rng.randf_range(0.30, 0.42), 16, comb, off + 0.01)
		strands.append(pts); ws.append(0.011 * hr.rng.randf_range(0.8, 1.25)); lay.append(0.4 + 0.6 * layer)
	hr.cards(c.st("hair"), strands, ws, chain_bfn(), lay)

func ranger(ch: Character) -> void:
	_setup(ch, 33)
	hr.cap(c.st("haircap"), 0.0022, c.B.head)
	var G = o + Vector3(0, 0.088, -0.072)
	toward(460, G, c.st("hair"), 0.011, 0.97)
	# hair tie
	Geo.tube(c.st("leather2"), func(t): return G + Vector3(cos(t * TAU) * 0.016, sin(t * TAU) * 0.010, 0.0).rotated(Vector3.RIGHT, -0.9), 8, 24, func(v, th): return Vector2(0.006, 0.006), {"bfn": c.AUTO()})
	# ponytail: lifts up and back, then falls with gravity and a little wave
	var strands = []; var ws = []; var lay = []
	for k in 300:
		var a = hr.rng.randf() * TAU
		var rr = sqrt(hr.rng.randf()) * 0.013
		var root = G + Vector3(cos(a) * rr, sin(a) * rr * 0.7, -0.008)
		var spread = Vector3(cos(a), 0, sin(a) * 0.5) * rr * 5.0
		var ph = hr.rng.randf() * TAU
		var comb = func(p, i):
			var t = float(i) / 18.0
			return (Vector3(0, 0.1 - 2.4 * t, -0.8 + 0.75 * t) + spread * t + Vector3(0.10 * sin(t * 7.0 + ph), 0, 0)).normalized()
		var pts = hr.grow(root, Vector3(0, 0.25, -1.0), hr.rng.randf_range(0.30, 0.40), 18, comb, 0.008, 1.6)
		strands.append(pts); ws.append(0.012 * hr.rng.randf_range(0.8, 1.2)); lay.append(hr.rng.randf_range(0.45, 1.0))
	hr.cards(c.st("hair"), strands, ws, chain_bfn(), lay)
	# side locks in front of the ears
	strands = []; ws = []; lay = []
	for sg in [1.0, -1.0]:
		for k in 3:
			var az: float = sg * (1.05 + 0.07 * k)
			var root = hr.scalp_point(az, Hair.hairline(az) * 0.92, 0.004)
			var comb = func(p, i): return Vector3(sg * 0.05, -1.0, 0.18)
			strands.append(hr.grow(root, Vector3(sg * 0.2, -1, 0.5), 0.08 + 0.012 * k, 10, comb, 0.006, 0.8))
			ws.append(0.013); lay.append(0.9)
	hr.cards(c.st("hair"), strands, ws, func(u, v, p): return [c.B.head, c.B.head, 0.0], lay)
