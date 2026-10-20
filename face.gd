## Face assembly: skin head, eyeballs, eyelashes, ears.
class_name Face
extends RefCounted

static func eye_mesh(st: SurfaceTool, h: Head, i: int, origin: Vector3, bone: int) -> void:
	var c: Vector3 = h.eye_c[i] + origin
	var r := h.eye_r
	var P := func(u: float, v: float) -> Vector3:
		var ph := v * PI
		var th := u * TAU
		var d := Vector3(sin(ph) * cos(th), sin(ph) * sin(th), cos(ph))
		var bulge := 0.07 * pow(maxf(0.0, (0.55 - ph) / 0.55), 1.6) # cornea
		return c + d * r * (1.0 + bulge)
	Geo.patch(st, P, 40, 28, {
		"uvfn": func(u, v, p): return Vector2((p - c).x / r, (p - c).y / r),
		"uv2fn": func(u, v, p): return Vector2((p - c).z / r, 0.0),
		"bones": [bone],
		"orient": func(u, v, p): return p - c,
	})

## Lash ribbons rooted on the lid margin, curling out and up.
static func lashes(st: SurfaceTool, h: Head, i: int, origin: Vector3, bone: int, upper: bool) -> void:
	var c: Vector3 = h.eye_c[i] + origin
	var s := 1.0 if i == 0 else -1.0
	var R := h.eye_r + 0.0013
	var hw := h.hw
	var P := func(u: float, v: float) -> Vector3:
		var x := lerpf(-hw * 0.92, hw * 1.02, u) * s
		var xo := x * s
		var t := clampf(absf(x) / hw, 0.0, 1.0)
		var y: float
		if upper:
			y = h.hu * pow(1.0 - t * t, 0.62) * (1.0 + 0.18 * xo / hw)
		else:
			y = -h.hl * pow(1.0 - t * t, 0.85) * (1.0 - 0.15 * xo / hw)
		y += h.F.tilt * xo
		var z := sqrt(maxf(R * R - x * x - y * y, 0.0))
		var root := c + Vector3(x, y, z)
		var n := Vector3(x, y, z).normalized()
		var up := Vector3(0, 1 if upper else -1, 0)
		var ln := (0.0066 if upper else 0.0024) * (0.45 + 0.55 * sin(clampf(u * 0.9 + 0.12, 0.0, 1.0) * PI * 0.92))
		var out := (n * (0.75 if upper else 0.45) + up * (0.35 if upper else 0.6) + Vector3(s * 0.25 * u, 0, 0)).normalized()
		var curl := up * ln * 0.55 * v * v
		return root + out * ln * v + curl
	Geo.patch(st, P, 16, 4, {
		"closed_u": false, "bones": [bone],
		"uvfn": func(u, v, p): return Vector2(u, v),
		"cfn": func(u, v, p): return Color(0.5, 1.0, 1.0, 0.3 if upper else 0.7),
	})

## Ear: a tilted shell with a rolled helix and a concha hollow.
static func ear(st: SurfaceTool, side: float, origin: Vector3, bone: int) -> void:
	var c := origin + Vector3(side * 0.071, -0.006, -0.008)
	var P := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		# outline: taller than wide, narrower lobe
		var ry := 0.029 * (1.0 if sin(th) > 0.0 else 0.9)
		var rz := 0.017 * (1.0 - 0.25 * maxf(0.0, -sin(th)))
		var rr := v # 0 centre -> 1 rim
		var y := sin(th) * ry * rr
		var z := cos(th) * rz * rr - 0.002
		var helix := 0.0045 * exp(-pow((rr - 0.9) / 0.09, 2.0))
		var bowl := -0.006 * (1.0 - rr * rr) * (1.0 - smoothstep(0.6, 0.95, rr))
		var x := side * (0.002 + 0.0065 * rr * (1.0 + 0.4 * maxf(0.0, -cos(th))) + helix + bowl)
		return c + Vector3(x, y, z).rotated(Vector3.UP, side * 0.12)
	Geo.patch(st, P, 36, 10, {"bones": [bone], "orient": func(u, v, p): return Vector3(side, 0, 0),
		"uvfn": func(u, v, p): return Vector2((p - origin).x, (p - origin).y),
		"uv2fn": func(u, v, p): return Vector2((p - origin).z, 0.0)})
