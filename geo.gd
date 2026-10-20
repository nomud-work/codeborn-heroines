## Procedural geometry kit. Parametric patch -> SurfaceTool with optional exact
## normals, vertex colours (r = trim mask, g = edge wear, b = cavity), UV/UV2
## and skin weights. Also: rolled-rim shells and tubes along curves.
class_name Geo
extends RefCounted

static var tri_count := {}

static func new_st(skinned := true) -> SurfaceTool:
	var st := SurfaceTool.new()
	if skinned:
		st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

## opts: closed_u, nfn(u,v,p)->n, cfn(u,v,p)->Color, uvfn(u,v,p)->Vector2,
## uv2fn(u,v,p)->Vector2, bfn(u,v,p)->[b0,b1,w1], bones [b0], uvs Vector2,
## flip (bool) invert facing, base (int) running vertex count holder (Array[1])
static func patch(st: SurfaceTool, P: Callable, nu: int, nv: int, o := {}) -> void:
	var closed_u: bool = o.get("closed_u", true)
	var nfn: Callable = o.get("nfn", Callable())
	var cfn: Callable = o.get("cfn", Callable())
	var uvfn: Callable = o.get("uvfn", Callable())
	var uv2fn: Callable = o.get("uv2fn", Callable())
	var bfn: Callable = o.get("bfn", Callable())
	var bones: Array = o.get("bones", [])
	var uvs: Vector2 = o.get("uvs", Vector2(1, 1))
	var outward: bool = o.get("outward", true)
	var flip: bool = o.get("flip", false)
	var orient: Callable = o.get("orient", Callable())
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var centroid := Vector3.ZERO
	var W := nu + 1
	for j in nv + 1:
		for i in W:
			var p: Vector3 = P.call(float(i) / nu, float(j) / nv)
			pos.append(p)
			centroid += p
	centroid /= pos.size()
	var e := 0.125 / float(maxi(nu, nv))
	var flip_sum := 0.0
	for j in nv + 1:
		for i in W:
			var u := float(i) / nu
			var v := float(j) / nv
			var k := j * W + i
			var n: Vector3
			if nfn.is_valid():
				n = nfn.call(u, v, pos[k])
			else:
				var ua := fposmod(u + e, 1.0) if closed_u else minf(u + e, 1.0)
				var ub := fposmod(u - e, 1.0) if closed_u else maxf(u - e, 0.0)
				var du: Vector3 = P.call(ua, v) - P.call(ub, v)
				var dv: Vector3 = P.call(u, minf(v + e, 1.0)) - P.call(u, maxf(v - e, 0.0))
				n = du.cross(dv)
				if n.length_squared() < 1e-16:
					# pole: use neighbouring row
					var vv := 0.02 if v < 0.5 else 0.98
					du = P.call(fposmod(u + e, 1.0), vv) - P.call(fposmod(u - e, 1.0), vv)
					dv = P.call(u, minf(vv + e, 1.0)) - P.call(u, maxf(vv - e, 0.0))
					n = du.cross(dv)
					if n.length_squared() < 1e-16:
						n = pos[k] - centroid
			n = n.normalized()
			if orient.is_valid():
				var od: Vector3 = orient.call(u, v, pos[k])
				if n.dot(od) < 0.0: n = -n
			flip_sum += n.dot(pos[k] - centroid)
			nrm.append(n)
	var sgn := 1.0
	if outward and closed_u and flip_sum < 0.0 and not nfn.is_valid() and not orient.is_valid():
		sgn = -1.0
	if flip:
		sgn = -sgn
	var base: int = _vcount(st)
	for j in nv + 1:
		for i in W:
			var k := j * W + i
			var u := float(i) / nu
			var v := float(j) / nv
			st.set_normal(nrm[k] * sgn)
			if uvfn.is_valid():
				st.set_uv(uvfn.call(u, v, pos[k]))
			else:
				st.set_uv(Vector2(u * uvs.x, v * uvs.y))
			st.set_uv2(uv2fn.call(u, v, pos[k]) if uv2fn.is_valid() else Vector2.ZERO)
			if cfn.is_valid():
				st.set_color(cfn.call(u, v, pos[k]))
			else:
				st.set_color(Color(0, 0, 0, 1))
			if bfn.is_valid():
				var b: Array = bfn.call(u, v, pos[k])
				st.set_bones(PackedInt32Array([b[0], b[1], 0, 0]))
				st.set_weights(PackedFloat32Array([1.0 - b[2], b[2], 0.0, 0.0]))
			elif bones.size() > 0:
				st.set_bones(PackedInt32Array([bones[0], 0, 0, 0]))
				st.set_weights(PackedFloat32Array([1.0, 0.0, 0.0, 0.0]))
			st.add_vertex(pos[k])
	_vadd(st, (nv + 1) * W)
	for j in nv:
		for i in nu:
			var a := j * W + i
			var b := a + 1
			var c := a + W
			var d := c + 1
			var cr: Vector3 = (pos[b] - pos[a]).cross(pos[c] - pos[a])
			var ref: Vector3 = nrm[a] * sgn
			if cr.length_squared() < 1e-20:
				cr = (pos[d] - pos[b]).cross(pos[c] - pos[b])
				ref = nrm[d] * sgn
			if cr.dot(ref) > 0.0:
				st.add_index(base + a); st.add_index(base + c); st.add_index(base + b)
				st.add_index(base + b); st.add_index(base + c); st.add_index(base + d)
			else:
				st.add_index(base + a); st.add_index(base + b); st.add_index(base + c)
				st.add_index(base + b); st.add_index(base + d); st.add_index(base + c)

static var _counts := {}
static func _vcount(st: SurfaceTool) -> int:
	return _counts.get(st.get_instance_id(), 0)
static func _vadd(st: SurfaceTool, n: int) -> void:
	_counts[st.get_instance_id()] = _vcount(st) + n

static func frame(d: Vector3, ref := Vector3.RIGHT) -> Array:
	if absf(d.dot(ref)) > 0.95:
		ref = Vector3.BACK if absf(d.dot(Vector3.BACK)) < 0.95 else Vector3.UP
	var e1 := (ref - d * d.dot(ref)).normalized()
	var e2 := d.cross(e1).normalized()
	return [e1, e2]

## Catmull-Rom through points, t in [0,1]
static func crspline(pts: Array, t: float) -> Vector3:
	var n := pts.size() - 1
	var f := clampf(t, 0.0, 1.0) * n
	var i := mini(int(f), n - 1)
	var s := f - i
	var p0: Vector3 = pts[maxi(i - 1, 0)]
	var p1: Vector3 = pts[i]
	var p2: Vector3 = pts[i + 1]
	var p3: Vector3 = pts[mini(i + 2, n)]
	if i == 0: p0 = p1 * 2.0 - p2
	if i + 2 > n: p3 = p2 * 2.0 - p1
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * s + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * s * s + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * s * s * s)

## piecewise-smooth scalar table lookup: tbl = [[t, val], ...]
static func table(tbl: Array, t: float) -> float:
	if t <= tbl[0][0]: return tbl[0][1]
	for k in tbl.size() - 1:
		if t <= tbl[k + 1][0]:
			var f: float = (t - tbl[k][0]) / maxf(tbl[k + 1][0] - tbl[k][0], 1e-6)
			return lerpf(tbl[k][1], tbl[k + 1][1], f * f * (3.0 - 2.0 * f))
	return tbl[tbl.size() - 1][1]

## Rotation-minimising frames along a sampled curve.
static func rmf(pts: PackedVector3Array, up := Vector3.FORWARD) -> Array:
	var T := []
	var N := []
	var n := pts.size()
	for i in n:
		var t: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		T.append(t)
	var f: Array = frame(T[0], up)
	N.append(f[0])
	for i in range(1, n):
		var prev: Vector3 = N[i - 1]
		var t: Vector3 = T[i]
		var nn := (prev - t * t.dot(prev)).normalized()
		N.append(nn)
	return [T, N]

## Tube along a curve: rfn(v, th) -> Vector2 (radius along N, along B)
static func tube(st: SurfaceTool, curve: Callable, nu: int, nv: int, rfn: Callable, o := {}) -> void:
	var samples := PackedVector3Array()
	for j in nv + 1:
		samples.append(curve.call(float(j) / nv))
	var fr := rmf(samples, o.get("up", Vector3.FORWARD))
	var T: Array = fr[0]
	var N: Array = fr[1]
	var P := func(u: float, v: float) -> Vector3:
		var fj := v * nv
		var j := mini(int(fj), nv - 1)
		var s := fj - j
		var c: Vector3 = samples[j].lerp(samples[j + 1], s)
		var t: Vector3 = (T[j] as Vector3).lerp(T[j + 1], s).normalized()
		var n: Vector3 = (N[j] as Vector3).lerp(N[j + 1], s)
		n = (n - t * t.dot(n)).normalized()
		var b := t.cross(n)
		var th := u * TAU
		var r: Vector2 = rfn.call(v, th)
		return c + n * cos(th) * r.x + b * sin(th) * r.y
	patch(st, P, nu, nv, o)

static func ellipsoid(st: SurfaceTool, c: Vector3, r: Vector3, nu := 24, nv := 16, o := {}) -> void:
	var P := func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var ph := v * PI
		return c + Vector3(sin(ph) * cos(th) * r.x, -cos(ph) * r.y, sin(ph) * sin(th) * r.z)
	patch(st, P, nu, nv, o)

## Plate with thickness and a rolled rim (after The Ninth Vigil's shellGeo):
## S(u,v) is the outer surface; the rim rolls outward then back to the inner
## face; COLOR.g carries edge wear (1 on the rim crest). closed_u wraps u.
static func shell(st: SurfaceTool, S: Callable, nu: int, nv: int, thick: float, rim: float, o := {}) -> void:
	var closed_u: bool = o.get("closed_u", false)
	var rim_w: float = o.get("rim_w", 0.06) # parameter width of rim band
	var cfn: Callable = o.get("cfn", Callable())
	var ee := 0.002
	var norm_at := func(u: float, v: float) -> Vector3:
		var ua := fposmod(u + ee, 1.0) if closed_u else minf(u + ee, 1.0)
		var ub := fposmod(u - ee, 1.0) if closed_u else maxf(u - ee, 0.0)
		var du: Vector3 = S.call(ua, v) - S.call(ub, v)
		var dv: Vector3 = S.call(u, minf(v + ee, 1.0)) - S.call(u, maxf(v - ee, 0.0))
		return du.cross(dv).normalized()
	# orientation: test against centroid-ish
	var c0: Vector3 = (S.call(0.25, 0.5) + S.call(0.75, 0.5)) * 0.5
	var sg := 1.0
	if (norm_at.call(0.5, 0.5) as Vector3).dot(S.call(0.5, 0.5) - c0) < 0.0 and closed_u:
		sg = -1.0
	if o.get("invert", false):
		sg = -sg
	var edges: Array = o.get("edges", [true, true, true, true]) # v0, v1, u0, u1
	var edge := func(u: float, v: float) -> float:
		var e := 1e3
		if edges[0]: e = minf(e, v)
		if edges[1]: e = minf(e, 1.0 - v)
		if not closed_u:
			if edges[2]: e = minf(e, u)
			if edges[3]: e = minf(e, 1.0 - u)
		return e
	var outer := func(u: float, v: float) -> Vector3:
		var e: float = edge.call(u, v)
		var n: Vector3 = norm_at.call(u, v) * sg
		var x := clampf(1.0 - e / rim_w, 0.0, 1.0)
		var bead := rim * sin(x * PI) * (1.0 if x < 0.999 else 0.0) # raised rolled bead
		var drop := -thick * smoothstep(0.85, 1.0, x) # curl down to the inner face at the very edge
		return S.call(u, v) + n * (bead + drop)
	var wear := func(u: float, v: float, p: Vector3) -> Color:
		var e: float = edge.call(u, v)
		var x := clampf(1.0 - e / rim_w, 0.0, 1.0)
		var w := sin(x * PI) if x > 0.2 else 0.0
		var c := Color(0, clampf(w, 0, 1), 0, 1)
		if cfn.is_valid():
			var c2: Color = cfn.call(u, v, p)
			c.r = c2.r; c.b = c2.b; c.g = maxf(c.g, c2.g)
		return c
	var ori := func(u, v, p): return (norm_at.call(u, v) as Vector3) * sg
	var oo := o.duplicate()
	oo["orient"] = ori
	oo["cfn"] = wear
	oo["closed_u"] = closed_u
	oo["outward"] = false
	patch(st, outer, nu, nv, oo)
	# inner face, offset inward, reversed
	var inner := func(u: float, v: float) -> Vector3:
		var n: Vector3 = norm_at.call(u, v) * sg
		return S.call(u, v) - n * thick
	var oi := o.duplicate()
	oi["closed_u"] = closed_u
	oi["outward"] = false
	oi["orient"] = func(u, v, p): return -(norm_at.call(u, v) as Vector3) * sg
	oi["cfn"] = func(u, v, p): return Color(0, 0, 0.6, 1)
	patch(st, inner, maxi(nu / 2, 4), maxi(nv / 2, 2), oi)

static func finish(st: SurfaceTool, mesh: ArrayMesh, mat: Material, tag := "") -> void:
	st.generate_tangents()
	st.set_material(mat)
	var arr := st.commit_to_arrays()
	var n := (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	tri_count[tag] = tri_count.get(tag, 0) + n
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	_counts.erase(st.get_instance_id())
