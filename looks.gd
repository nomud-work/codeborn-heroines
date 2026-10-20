## Per-character art direction: proportions, face shape, palettes, materials.
class_name Looks
extends RefCounted

static func params(kind: String) -> Dictionary:
	match kind:
		"paladin":
			return {"body": {"bust": 0.020},
				"face": {"jaw": 1.0, "chin": 1.0, "nose_len": 1.0, "nose_w": 0.96, "lip": 0.92, "cheek": 1.05, "brow": 1.05, "tilt": 0.06, "face_len": 0.97},
				"ears": false,
				"hair_bones": [["hairA", "head", Vector3(0, 1.50, -0.075)], ["hairB", "hairA", Vector3(0, 1.30, -0.11)], ["hairC", "hairB", Vector3(0, 1.08, -0.13)]]}
		"mage":
			return {"body": {"bust": 0.022},
				"face": {"jaw": 0.96, "chin": 0.95, "nose_len": 0.97, "nose_w": 1.06, "lip": 1.05, "cheek": 0.98, "brow": 0.9, "tilt": 0.12, "face_len": 0.98},
				"ears": false,
				"hair_bones": [["hairA", "head", Vector3(0, 1.52, -0.06)], ["hairB", "hairA", Vector3(0, 1.32, -0.10)], ["hairC", "hairB", Vector3(0, 1.10, -0.12)]]}
		_:
			return {"body": {"bust": 0.020},
				"face": {"jaw": 1.0, "chin": 1.0, "nose_len": 1.03, "nose_w": 0.95, "lip": 1.0, "cheek": 0.95, "brow": 1.0, "tilt": 0.09, "face_len": 1.02},
				"ears": true,
				"hair_bones": [["hairA", "head", Vector3(0, 1.67, -0.085)], ["hairB", "hairA", Vector3(0, 1.48, -0.13)], ["hairC", "hairB", Vector3(0, 1.30, -0.13)]]}

static func skin_mat(c: Character, col: Color, lip: Color, brow: Color, hair: Color, freck: float, head: bool) -> ShaderMaterial:
	return c.shader_mat("SKIN", Shaders.SKIN, {"skin": col, "lip": lip, "brow": brow, "hair_col": hair,
		"freckles": freck, "is_head": 1.0 if head else 0.0, "eye_sep": c.head.F.eye_sep,
		"hairline_y": 0.074 if head else 10.0})

static func eye_mats(c: Character, a: Color, b: Color, m: Dictionary) -> void:
	for i in 2:
		m["eye_" + str(i)] = c.shader_mat("EYE", Shaders.EYE, {"iris_a": a, "iris_b": b, "side": 1.0 if i == 0 else -1.0,
			"hw": c.head.hw, "hu": c.head.hu, "hl": c.head.hl, "eye_r": c.head.eye_r, "tilt": c.head.F.tilt})

static func hair_mat(c: Character, root: Color, tip: Color, strands: float, opaque := 0.0, extra := {}) -> ShaderMaterial:
	var p := {"root": root, "tip": tip, "strands": strands, "opaque_core": opaque}
	for k in extra: p[k] = extra[k]
	return c.shader_mat("HAIR", Shaders.HAIR, p)

static func materials(c: Character, kind: String) -> Dictionary:
	var m := {}
	m["lashes"] = hair_mat(c, Color(0.03, 0.02, 0.02), Color(0.06, 0.04, 0.035), 90.0, 0.0, {"density": 0.95, "spec1": 0.15, "spec2": 0.05})
	match kind:
		"paladin":
			var hc := Color(0.55, 0.30, 0.14)
			m["skin_head"] = skin_mat(c, Color(0.86, 0.68, 0.58), Color(0.66, 0.36, 0.34), Color(0.42, 0.22, 0.11), hc, 0.5, true)
			m["skin_body"] = skin_mat(c, Color(0.86, 0.68, 0.58), Color(), Color(), hc, 0.0, false)
			eye_mats(c, Color(0.30, 0.42, 0.30), Color(0.55, 0.42, 0.16), m)
			m["hair"] = hair_mat(c, Color(0.26, 0.12, 0.055), Color(0.52, 0.29, 0.15), 14.0, 0.0, {"spec1": 0.22, "spec2": 0.18})
			m["haircap"] = hair_mat(c, Color(0.24, 0.11, 0.05), Color(0.42, 0.22, 0.11), 1.0, 1.0, {"spec1": 0.22, "spec2": 0.18})
			m["braid"] = hair_mat(c, Color(0.28, 0.13, 0.06), Color(0.48, 0.26, 0.13), 10.0, 1.0, {"spec1": 0.22, "spec2": 0.18})
			m["steel"] = c.surface("steel", Color(0.78, 0.79, 0.82), 6.0, {"metal": 1.0, "rough_mul": 0.42, "normal_depth": 0.22, "wear_k": 0.9, "wear_col": Color(1.0, 1.0, 1.0), "thread": Color(0.95, 0.72, 0.32), "trim_scale": 18.0, "pattern": 0.0, "seed": 31})
			m["gold"] = c.surface("steel", Color(0.95, 0.70, 0.30), 8.0, {"metal": 1.0, "rough_mul": 0.45, "wear_k": 0.6, "seed": 33})
			m["tabard"] = c.surface("wool", Color(0.12, 0.20, 0.45), 9.0, {"thread": Color(0.92, 0.74, 0.36), "trim_scale": 14.0, "pattern": 0.0, "sheen": 0.15, "seed": 41})
			m["under"] = c.surface("wool", Color(0.30, 0.17, 0.13), 10.0, {"seed": 42, "sheen": 0.25})
			m["leather"] = c.surface("leather", Color(0.32, 0.19, 0.11), 7.0, {"seed": 51, "wear_k": 0.5, "wear_col": Color(1.2, 1.0, 0.9)})
		"mage":
			var hc := Color(0.06, 0.05, 0.06)
			m["skin_head"] = skin_mat(c, Color(0.52, 0.34, 0.25), Color(0.40, 0.18, 0.18), Color(0.07, 0.05, 0.05), hc, 0.0, true)
			m["skin_body"] = skin_mat(c, Color(0.52, 0.34, 0.25), Color(), Color(), hc, 0.0, false)
			eye_mats(c, Color(0.24, 0.13, 0.06), Color(0.48, 0.30, 0.12), m)
			m["hair"] = hair_mat(c, Color(0.035, 0.03, 0.035), Color(0.10, 0.08, 0.09), 16.0, 0.0, {"spec_tint": Color(0.75, 0.80, 1.0), "spec1": 0.45})
			m["haircap"] = hair_mat(c, Color(0.04, 0.035, 0.04), Color(0.08, 0.07, 0.08), 1.0, 1.0, {"spec_tint": Color(0.75, 0.80, 1.0)})
			m["dress"] = c.surface("linen", Color(0.86, 0.82, 0.74), 11.0, {"thread": Color(0.85, 0.66, 0.30), "trim_scale": 22.0, "pattern": 2.0, "sheen": 0.3, "seed": 61})
			m["robe"] = c.surface("wool", Color(0.07, 0.22, 0.30), 9.0, {"thread": Color(0.92, 0.72, 0.34), "trim_scale": 16.0, "pattern": 0.0, "sheen": 0.15, "seed": 62})
			m["sash"] = c.surface("linen", Color(0.55, 0.10, 0.12), 12.0, {"thread": Color(0.95, 0.78, 0.40), "trim_scale": 26.0, "pattern": 1.0, "sheen": 0.3, "seed": 63})
			m["gold"] = c.surface("steel", Color(0.95, 0.72, 0.32), 8.0, {"metal": 1.0, "rough_mul": 0.4, "wear_k": 0.5, "seed": 33})
			var gm := StandardMaterial3D.new()
			gm.albedo_color = Color(0.05, 0.45, 0.55); gm.roughness = 0.05; gm.metallic_specular = 0.9
			gm.emission_enabled = true; gm.emission = Color(0.05, 0.35, 0.45); gm.emission_energy_multiplier = 0.6
			m["gem"] = gm
		_:
			var hc := Color(0.20, 0.11, 0.06)
			m["skin_head"] = skin_mat(c, Color(0.78, 0.60, 0.47), Color(0.58, 0.32, 0.29), Color(0.20, 0.12, 0.07), hc, 0.25, true)
			m["skin_body"] = skin_mat(c, Color(0.78, 0.60, 0.47), Color(), Color(), hc, 0.0, false)
			eye_mats(c, Color(0.30, 0.22, 0.10), Color(0.45, 0.42, 0.18), m)
			m["hair"] = hair_mat(c, Color(0.10, 0.055, 0.03), Color(0.30, 0.17, 0.09), 14.0)
			m["haircap"] = hair_mat(c, Color(0.12, 0.065, 0.035), Color(0.25, 0.14, 0.07), 1.0, 1.0)
			m["shirt"] = c.surface("linen", Color(0.72, 0.68, 0.58), 12.0, {"seed": 71, "sheen": 0.2})
			m["leather"] = c.surface("leather", Color(0.36, 0.22, 0.12), 7.0, {"seed": 72, "wear_k": 0.6, "wear_col": Color(1.25, 1.05, 0.9), "thread": Color(0.80, 0.70, 0.52), "trim_scale": 30.0, "pattern": 2.0})
			m["leather2"] = c.surface("leather", Color(0.16, 0.10, 0.07), 7.0, {"seed": 73, "wear_k": 0.5, "wear_col": Color(1.3, 1.1, 0.9)})
			m["cloak"] = c.surface("wool", Color(0.12, 0.17, 0.10), 8.0, {"seed": 74, "sheen": 0.15, "thread": Color(0.62, 0.52, 0.30), "trim_scale": 20.0, "pattern": 1.0})
			m["pants"] = c.surface("wool", Color(0.22, 0.20, 0.17), 10.0, {"seed": 75, "sheen": 0.15})
			m["steel"] = c.surface("steel", Color(0.70, 0.70, 0.72), 6.0, {"metal": 1.0, "rough_mul": 0.6, "wear_k": 0.8, "seed": 31})
			m["wood"] = c.surface("wood", Color(0.45, 0.30, 0.18), 6.0, {"seed": 76})
			m["fletch"] = hair_mat(c, Color(0.75, 0.72, 0.66), Color(0.55, 0.20, 0.15), 30.0, 0.0, {"density": 1.0, "spec1": 0.05})
	return m
