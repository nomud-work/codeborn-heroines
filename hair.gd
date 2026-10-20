## Hair generated as geometry: an opaque strand-shaded scalp cap traced onto
## the head SDF, plus hundreds of strand cards grown root-to-tip with gravity,
## combing and collision against the head SDF and the torso. Braids are three
## interleaved strand tubes. Every card carries per-card random IDs and a
## layer-depth shadow term for the anisotropic hair shader.
class_name Hair
extends RefCounted

var head: Head
var origin: Vector3
var body: Body
var rng := RandomNumberGenerator.new()

func _init(h: Head, o: Vector3, b: Body, seed := 1) -> void:
	head = h; origin = o; body = b; rng.seed = seed

func sdf_w(p: Vector3) -> float:
	return head.sdf(p - origin)

func push_out(p: Vector3, off: float) -> Vector3:
	var d := sdf_w(p) - off
	if d < 0.0:
		var g := head.grad(p - origin)
		p -= g * d * 1.05
	# torso / shoulders: radial push against the body cross-section
	if p.y < origin.y - 0.10 and p.y > Body.Y0:
		var q := p
		var ang := atan2(q.x, q.z)
		var u := fposmod(ang / TAU, 1.0)
		var surf := body.torso(u, clampf(q.y, Body.Y0, Body.Y1), off + 0.012)
		var c := Vector3(0, q.y, surf.z * 0.0 - 0.01)
		var rs := Vector2(surf.x, surf.z - c.z).length()
		var rp := Vector2(q.x, q.z - c.z).length()
		if rp < rs:
			var k := rs / maxf(rp, 1e-5)
			p.x = q.x * k
			p.z = c.z + (q.z - c.z) * k
	return p

## polar from the crown (0) toward the hairline; azimuth 0 = front
func scalp_dir(az: float, pol: float) -> Vector3:
	return Vector3(sin(pol) * sin(az), cos(pol), sin(pol) * cos(az))

static func hairline(az: float) -> float:
	var a := absf(wrapf(az, -PI, PI))
	return deg_to_rad(Geo.table([[0.0, 55.0], [0.35, 56.5], [0.75, 63.0], [1.1, 80.0], [1.35, 92.0], [1.6, 97.0], [2.2, 112.0], [PI, 124.0]], a))

func scalp_point(az: float, pol: float, off: float) -> Vector3:
	return head.trace(scalp_dir(az, pol), off) + origin

## Opaque cap: strands flow from crown/part toward the hairline.
func cap(st: SurfaceTool, off: float, bone: int, part_az := 0.0) -> void:
	var P := func(u: float, v: float) -> Vector3:
		var az := (u - 0.5) * TAU + part_az
		return scalp_point(az, hairline(az) * (0.02 + 0.98 * v), off)
	Geo.patch(st, P, 72, 26, {
		"nfn": func(u, v, p): return head.grad(p - origin),
		"uvfn": func(u, v, p): return Vector2(u * 90.0, 1.0 - v),
		"cfn": func(u, v, p): return Color(rng.randf(), 0.55, 1.0, u),
		"bones": [bone],
	})

## Grow one strand polyline. comb(p, i) -> preferred direction.
func grow(root: Vector3, dir0: Vector3, length: float, n: int, comb: Callable, off: float, grav := 1.0) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var p := root
	var d := dir0.normalized()
	var step := length / n
	pts.append(p)
	for i in n:
		var c: Vector3 = comb.call(p, i)
		d = (d + c * 0.35 + Vector3(0, -1, 0) * 0.22 * grav * (float(i) / n + 0.3)).normalized()
		p = p + d * step
		p = push_out(p, off * (1.0 + 0.4 * float(i) / n))
		if i > 0:
			d = (p - pts[pts.size() - 1]).normalized()
		pts.append(p)
	return pts

## Strand cards: ribbons facing away from the head axis.
func cards(st: SurfaceTool, strands: Array, widths: Array, bfn: Callable, layer: Array) -> void:
	for k in strands.size():
		var pts: PackedVector3Array = strands[k]
		var w: float = widths[k]
		var lay: float = layer[k]
		var id := rng.randf()
		var var_c := rng.randf()
		var n := pts.size()
		var P := func(u: float, v: float) -> Vector3:
			var fi := v * (n - 1)
			var i := mini(int(fi), n - 2)
			var s := fi - i
			var c: Vector3 = pts[i].lerp(pts[i + 1], s)
			var t: Vector3 = (pts[i + 1] - pts[i]).normalized()
			var outd := c - (origin + Vector3(0, -0.02, -0.01))
			outd.y *= 0.3
			var side := t.cross(outd).normalized()
			var ww := w * lerpf(0.75, 1.0, smoothstep(0.0, 0.15, v)) * lerpf(1.0, 0.45, smoothstep(0.6, 1.0, v))
			return c + side * (u - 0.5) * ww
		Geo.patch(st, P, 1, n - 1, {
			"closed_u": false,
			"uvfn": func(u, v, p): return Vector2(u, v),
			"cfn": func(u, v, p): return Color(var_c, lay, 1.0, id),
			"bfn": bfn,
			"orient": func(u, v, p): return p - origin,
		})

## Braid: three strand tubes interleaving around a centre curve.
func braid(st: SurfaceTool, centre: Callable, radius: float, crosses: float, bfn: Callable, taper_end := 0.92) -> void:
	for k in 3:
		var ph := TAU * k / 3.0
		var samples := PackedVector3Array()
		var N := 160
		for j in N + 1:
			samples.append(centre.call(float(j) / N))
		var fr := Geo.rmf(samples, Vector3(0, 0, -1))
		var T: Array = fr[0]
		var Nn: Array = fr[1]
		var crv := func(t: float) -> Vector3:
			var j := mini(int(t * N), N - 1)
			var c: Vector3 = samples[j]
			var tt: Vector3 = T[j]
			var nn: Vector3 = Nn[j]
			var bb := tt.cross(nn)
			var a := t * crosses * TAU + ph
			var r := radius * lerpf(1.0, 0.55, smoothstep(0.0, taper_end, t))
			return c + nn * sin(a) * r * 0.9 + bb * sin(2.0 * a) * r * 0.42
		var sr := radius * 0.62
		Geo.tube(st, crv, 14, 220, func(v, th):
			var tap := lerpf(1.0, 0.6, smoothstep(0.0, taper_end, v))
			return Vector2(sr, sr * 0.8) * tap, {
				"uvfn": func(u, v, p): return Vector2(u * 3.0, v * crosses * 3.0),
				"cfn": func(u, v, p): return Color(0.5, 0.85, 1.0, float(k) * 0.33),
				"bfn": bfn, "up": Vector3(0, 0, -1)})

## Scalp-hugging path: quadratic Bezier between directions (bent up over the
## crown), each sample sphere-traced back onto the head at a layer offset.
func hug(d0: Vector3, d1: Vector3, off0: float, off1: float, n: int, lift := 1.0) -> PackedVector3Array:
	var C := (d0 + d1)
	C = (C + Vector3(0, lift, 0) * (1.2 - C.length() * 0.5)).normalized()
	var pts := PackedVector3Array()
	for i in n + 1:
		var t := float(i) / n
		var d := (d0 * (1.0 - t) * (1.0 - t) + C * 2.0 * t * (1.0 - t) + d1 * t * t).normalized()
		pts.append(head.trace(d, lerpf(off0, off1, t)) + origin)
	return pts

## Continue a polyline with gravity, combing and collisions.
func fall(pts: PackedVector3Array, length: float, n: int, comb: Callable, off: float) -> PackedVector3Array:
	var p: Vector3 = pts[pts.size() - 1]
	var d: Vector3 = (p - pts[pts.size() - 2]).normalized()
	var step := length / n
	for i in n:
		var cdir: Vector3 = comb.call(p, i)
		d = (d + cdir * 0.5 + Vector3(0, -0.45, 0)).normalized()
		var q := push_out(p + d * step, off)
		d = (q - p).normalized()
		p = q
		pts.append(p)
	return pts
