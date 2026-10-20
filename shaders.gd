## Every shader in the project, as source strings. Nothing samples an image
## file: skin, eyes, hair, embroidery and backdrop are all evaluated per pixel.
class_name Shaders
extends RefCounted

const NOISE := """
float hash3(vec3 p){ p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float vnoise3(vec3 x){ vec3 i = floor(x); vec3 f = fract(x); f = f*f*(3.0-2.0*f);
	return mix(mix(mix(hash3(i), hash3(i+vec3(1,0,0)), f.x), mix(hash3(i+vec3(0,1,0)), hash3(i+vec3(1,1,0)), f.x), f.y),
		mix(mix(hash3(i+vec3(0,0,1)), hash3(i+vec3(1,0,1)), f.x), mix(hash3(i+vec3(0,1,1)), hash3(i+vec3(1,1,1)), f.x), f.y), f.z); }
float fbm3(vec3 p){ float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++){ v += a * vnoise3(p); p = p * 2.07 + 3.1; a *= 0.5; } return v; }
float h11(float x){ return fract(sin(x * 127.1) * 43758.5453); }
"""

## Skin: wrap diffuse with a red-shifted terminator (subsurface-ish), soft
## sheen spec, plus painted-in-shader brows, lips, lash line, blush, nostrils.
const SKIN := """
shader_type spatial;
render_mode cull_back;
uniform vec3 skin : source_color = vec3(0.80, 0.62, 0.52);
uniform vec3 lip : source_color = vec3(0.60, 0.30, 0.30);
uniform vec3 brow : source_color = vec3(0.25, 0.15, 0.09);
uniform vec3 blush : source_color = vec3(0.85, 0.42, 0.40);
uniform vec3 shadow_col : source_color = vec3(0.35, 0.22, 0.28);
uniform float eye_sep = 0.0305;
uniform float lip_y = -0.0575;
uniform float freckles = 0.0;
uniform float hairline_y = 0.06;
uniform vec3 hair_col : source_color = vec3(0.3, 0.15, 0.08);
uniform float is_head = 1.0;
varying vec3 hp;
""" + NOISE + """
void vertex(){ hp = vec3(UV.x, UV.y, UV2.x); }
float gauss2(vec2 d, vec2 r){ return exp(-dot(d / r, d / r)); }
// hairline polar angle (radians from the crown) as a function of azimuth; mirrors Hair.hairline()
float hairline_pol(float az){
	float a = abs(az);
	float t[8] = float[](0.0, 0.35, 0.75, 1.1, 1.35, 1.6, 2.2, 3.14159);
	float v[8] = float[](55.0, 56.5, 63.0, 80.0, 92.0, 97.0, 112.0, 124.0);
	float r = v[7];
	for (int i = 0; i < 7; i++) {
		if (a >= t[i] && a <= t[i + 1]) { float k = (a - t[i]) / (t[i + 1] - t[i]); k = k * k * (3.0 - 2.0 * k); r = mix(v[i], v[i + 1], k); }
	}
	return radians(r);
}
void fragment(){
	vec3 c = skin;
	float n = fbm3(hp * 180.0);
	float n2 = fbm3(hp * 900.0);
	c *= 0.94 + 0.10 * n;
	float rough = 0.52 + 0.12 * n2;
	float spec = 0.38;
	if (is_head > 0.5) {
		float ax = abs(hp.x);
		float front = smoothstep(0.035, 0.07, hp.z);
		// redness: cheeks, nose tip, ears
		float bl = gauss2(vec2(ax - 0.042, hp.y + 0.028), vec2(0.020, 0.016)) * front;
		bl += 0.7 * gauss2(vec2(hp.x, hp.y + 0.026), vec2(0.010, 0.010)) * smoothstep(0.09, 0.10, hp.z);
		c = mix(c, c * blush * 1.25, clamp(bl * 0.35, 0.0, 1.0));
		// freckles across the nose and cheeks
		if (freckles > 0.0) {
			float fr = smoothstep(0.72, 0.80, vnoise3(hp * 1400.0)) * gauss2(vec2(hp.x, hp.y + 0.015), vec2(0.05, 0.022)) * front;
			c = mix(c, c * vec3(0.72, 0.52, 0.40), fr * freckles);
		}
		// lips with soft vermilion border and vertical micro-lines
		vec2 lq = vec2(hp.x / 0.0200, (hp.y - lip_y) / 0.0108);
		float lm = (1.0 - smoothstep(0.78, 1.0, length(lq))) * smoothstep(0.077, 0.087, hp.z);
		float lines = 0.96 + 0.04 * sin(hp.x * 2200.0 + n2 * 6.0);
		c = mix(c, lip * lines, lm * 0.85);
		rough = mix(rough, 0.32, lm);
		spec = mix(spec, 0.5, lm);
		// mouth corner / line shadow
		c *= 1.0 - 0.45 * gauss2(vec2(ax - 0.020, hp.y - lip_y), vec2(0.0035, 0.003)) * front;
		// nostrils
		c *= 1.0 - 0.6 * gauss2(vec2(ax - 0.0075, hp.y + 0.0345), vec2(0.0035, 0.0022)) * smoothstep(0.088, 0.096, hp.z);
		// eyes: lash line, lid shadow, inner corner caruncle tint
		float s = sign(hp.x);
		vec2 e = vec2(hp.x - s * eye_sep, hp.y - 0.004);
		float eo = e.x * s;
		float upper = 0.0060 * pow(max(1.0 - (e.x / 0.0128) * (e.x / 0.0128), 0.0), 0.62) + 0.10 * eo;
		float lashline = gauss2(vec2(0.0, (e.y - upper - 0.0004) / 0.0010), vec2(1.0, 1.0)) * front * (1.0 - smoothstep(0.0115, 0.0150, abs(e.x) + max(-eo, 0.0) * 0.25));
		c = mix(c, vec3(0.06, 0.04, 0.035), clamp(lashline, 0.0, 1.0) * 0.9);
		float lid = gauss2(vec2(e.x, e.y - 0.0075), vec2(0.016, 0.0055)) * front;
		c = mix(c, c * shadow_col * 1.6, lid * 0.35);
		c = mix(c, vec3(0.70, 0.36, 0.36), gauss2(vec2(eo + 0.0125, e.y), vec2(0.0022, 0.0018)) * 0.35);
		// eyebrows: tapered arc made of angled hair strokes
		float bx = ax - eye_sep + 0.016; // 0 at inner end
		float by = 0.0205 + 0.0070 * sin(clamp(bx / 0.036, 0.0, 1.0) * 2.5) ;
		float bw = mix(0.0042, 0.0016, clamp(bx / 0.036, 0.0, 1.0));
		float bmask = (1.0 - smoothstep(bw * 0.6, bw, abs(hp.y - by))) * smoothstep(-0.002, 0.003, bx) * (1.0 - smoothstep(0.032, 0.038, bx)) * front;
		float bt = clamp(bx / 0.036, 0.0, 1.0);
		float ang = mix(1.15, 0.12, bt); // hairs grow up at the head, sideways at the tail
		vec2 bd = vec2(bx, (hp.y - by));
		float perp = dot(bd, vec2(-sin(ang), cos(ang)));
		float along = dot(bd, vec2(cos(ang), sin(ang)));
		float lane = floor(perp / 0.00042);
		float strokes = smoothstep(0.25, 0.9, sin(fract(along / 0.0035 + h11(lane) * 7.0) * 3.14159)) * step(0.25, h11(lane * 1.7));
		c = mix(c, brow, bmask * (0.4 + 0.55 * strokes));
		c = mix(c, c * 0.85, gauss2(vec2(bx - 0.016, hp.y - by), vec2(0.022, 0.006)) * front * 0.5);
		// hairline shadow under the hair cap
		if (hairline_y < 1.0) {
			vec3 hd = normalize(hp);
			float pol = acos(clamp(hd.y, -1.0, 1.0));
			float az = atan(hd.x, hd.z);
			float dist = (pol - hairline_pol(az)) * 0.085; // metres below the hairline
			float lane = floor(az * 0.085 / 0.00035);
			float hlen = 0.001 + 0.0035 * pow(h11(lane * 1.37 + 3.0), 3.0);
			float wisp = (1.0 - smoothstep(hlen * 0.6, hlen, dist)) * step(0.35, h11(lane * 0.71));
			wisp *= 0.6 + 0.4 * sin(fract(az * 0.085 / 0.00035) * 3.14159);
			float shade = 1.0 - smoothstep(-0.002, 0.010, dist);
			c = mix(c, c * 0.82, shade);
			c = mix(c, hair_col * 0.8, clamp(wisp * smoothstep(-0.003, 0.0, dist) + (1.0 - smoothstep(-0.003, 0.0, dist)), 0.0, 1.0) * 0.85);
		}
	}
	ALBEDO = c;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
void light(){
	float ndl = dot(NORMAL, LIGHT);
	float w = 0.42;
	float wrap = clamp((ndl + w) / (1.0 + w), 0.0, 1.0);
	float lam = clamp(ndl, 0.0, 1.0);
	// red light bleeds into the terminator - cheap subsurface look
	vec3 sss = vec3(1.0, 0.45, 0.33) * (wrap - lam) * 0.6;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * (vec3(mix(lam, wrap, 0.3)) + sss) / PI;
	vec3 H = normalize(LIGHT + VIEW);
	float ndh = clamp(dot(NORMAL, H), 0.0, 1.0);
	float a = ROUGHNESS * ROUGHNESS;
	float a2 = a * a;
	float dd = ndh * ndh * (a2 - 1.0) + 1.0;
	float D = a2 / (PI * dd * dd);
	float F = 0.03 + 0.97 * pow(1.0 - clamp(dot(VIEW, H), 0.0, 1.0), 5.0);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * lam * D * F * 0.25;
}
"""

## Eye: sclera, limbal ring, fibrous iris with a collarette, pupil, wet cornea.
## UV = eye-local xy on the unit sphere, UV2.x = z (forward).
const EYE := """
shader_type spatial;
uniform vec3 iris_a : source_color = vec3(0.16, 0.30, 0.36);
uniform vec3 iris_b : source_color = vec3(0.55, 0.45, 0.20);
uniform float iris_r = 0.46;
uniform float pupil_r = 0.14;
uniform float side = 1.0;
uniform float hw = 0.0128;
uniform float hu = 0.006;
uniform float hl = 0.0043;
uniform float eye_r = 0.0135;
uniform float tilt = 0.10;
varying vec3 q;
""" + NOISE + """
void vertex(){ q = vec3(UV, UV2.x); }
void fragment(){
	float r = length(q.xy);
	float ang = atan(q.y, q.x);
	vec3 scl = vec3(0.86, 0.83, 0.80) * (0.92 + 0.06 * fbm3(q * 20.0));
	scl = mix(scl, vec3(0.85, 0.62, 0.60), smoothstep(0.55, 0.95, r) * 0.35);
	float fib = fbm3(vec3(ang * 9.0, r * 22.0, 1.0)) ;
	float fib2 = vnoise3(vec3(ang * 40.0, r * 6.0, 3.0));
	vec3 ir = mix(iris_a, iris_a * 1.5, fib);
	ir = mix(ir, iris_b, smoothstep(0.32, 0.18, r) * 0.8); // warm collarette around the pupil
	ir *= 0.75 + 0.45 * fib2;
	ir *= 1.0 - 0.65 * smoothstep(iris_r * 0.78, iris_r, r); // dark limbal ring
	float im = 1.0 - smoothstep(iris_r - 0.015, iris_r + 0.012, r);
	vec3 c = mix(scl, ir, im * step(0.0, q.z));
	c = mix(c, vec3(0.01), (1.0 - smoothstep(pupil_r - 0.015, pupil_r + 0.01, r)) * step(0.0, q.z));
	// ambient occlusion from the lids: darken near the opening edge
	vec2 e = q.xy * eye_r;
	float xo = e.x * side;
	float t = clamp(abs(e.x) / hw, 0.0, 1.0);
	float yu = hu * pow(1.0 - t * t, 0.62) * (1.0 + 0.18 * xo / hw);
	float yl = -hl * pow(1.0 - t * t, 0.85) * (1.0 - 0.15 * xo / hw);
	float yy = e.y - tilt * xo;
	float edge = min(yu - yy, yy - yl);
	float ao = smoothstep(0.0, 0.0028, edge);
	c *= mix(0.18, 1.0, ao) * mix(0.6, 1.0, smoothstep(0.75, 0.35, abs(q.x))) * mix(0.75, 1.0, smoothstep(-0.002, 0.004, yu - yy - 0.0015));
	ALBEDO = c;
	ROUGHNESS = 0.06;
	SPECULAR = 0.65;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.02;
}
"""

## Strand cards (hair, lashes): many sub-strands per card, alpha tested,
## Kajiya-Kay two-lobe anisotropic highlight along the strand direction.
const HAIR := """
shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
uniform vec3 root : source_color = vec3(0.20, 0.10, 0.05);
uniform vec3 tip : source_color = vec3(0.45, 0.25, 0.12);
uniform vec3 spec_tint : source_color = vec3(1.0, 0.9, 0.8);
uniform float strands = 9.0;
uniform float shift = 0.08;
uniform float gloss1 = 300.0;
uniform float gloss2 = 60.0;
uniform float spec1 = 0.35;
uniform float spec2 = 0.25;
uniform float density = 0.75;
uniform float opaque_core = 0.0;
varying vec3 sdir;
varying float sid;
varying float sshift;
""" + NOISE + """
void fragment(){
	float x = UV.x * strands;
	float id = floor(x);
	float f = fract(x);
	float rnd = h11(id + COLOR.a * 97.0);
	float rnd2 = h11(id * 3.1 + COLOR.a * 51.0 + 7.0);
	float len = mix(0.75, 1.0, rnd2);
	float w = mix(0.28, 0.48, rnd) * (1.0 - smoothstep(len * 0.75, len, UV.y));
	float cov = 1.0 - smoothstep(w * 0.55, w, abs(f - 0.5));
	cov *= step(rnd, density) ;
	cov = max(cov, opaque_core * (1.0 - smoothstep(0.25, 0.48, abs(UV.x - 0.5))) * (1.0 - smoothstep(0.7, 1.0, UV.y) * (1.0 - step(0.99, opaque_core))));
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(1.0, 0.92, UV.x);
	float rootfade = smoothstep(0.0, mix(0.06 + 0.06 * rnd2, 0.004 + 0.03 * rnd2, step(0.99, opaque_core)), UV.y);
	ALPHA = cov * mix(edge, 1.0, opaque_core) * COLOR.b * rootfade;
	if (opaque_core > 0.99) {
		float fine = h11(floor(UV.x * 3.0) + 13.0);
		ALPHA = smoothstep(0.0, 0.015 + 0.07 * fine * fine, UV.y);
	}
	ALPHA_SCISSOR_THRESHOLD = 0.4;
	vec3 c = mix(root, tip, smoothstep(0.0, 1.0, UV.y)) * (0.75 + 0.5 * rnd) * (0.8 + 0.2 * COLOR.r);
	ALBEDO = c * mix(0.55, 1.0, COLOR.g); // COLOR.g = self-shadow (inner layers darker)
	ROUGHNESS = 0.75;
	SPECULAR = 0.0;
	sdir = normalize(BINORMAL);
	sshift = (rnd - 0.5) * 0.1;
}
void light(){
	vec3 T = sdir;
	float tl = dot(T, LIGHT);
	float kd = sqrt(max(1.0 - tl * tl, 0.0));
	float ndl = dot(NORMAL, LIGHT);
	float wrap = clamp((ndl + 0.5) / 1.5, 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * mix(kd, 1.0, 0.3) * wrap / PI;
	vec3 H = normalize(LIGHT + VIEW);
	vec3 T1 = normalize(T + NORMAL * (shift + sshift));
	vec3 T2 = normalize(T - NORMAL * (shift * 1.5 - sshift));
	float th1 = dot(T1, H);
	float th2 = dot(T2, H);
	float s1 = pow(sqrt(max(1.0 - th1 * th1, 0.0)), gloss1);
	float s2 = pow(sqrt(max(1.0 - th2 * th2, 0.0)), gloss2);
	float sv = clamp(ndl, 0.0, 1.0) * pow(clamp(dot(NORMAL, H), 0.0, 1.0), 4.0) * 0.25;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * sv * (s1 * spec1 * mix(spec_tint, ALBEDO * 3.0, 0.4) + s2 * spec2 * ALBEDO * 2.0);
}
"""

## Generic surface for cloth / leather / metal. Generated maps + vertex colour:
## COLOR.r = embroidery/filigree band, COLOR.g = edge wear, COLOR.b = cavity.
const SURFACE := """
shader_type spatial;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float uv_scale = 8.0;
uniform float metal = 0.0;
uniform float rough_mul = 1.0;
uniform float normal_depth = 1.0;
uniform float sheen = 0.0;
uniform vec3 thread : source_color = vec3(0.85, 0.65, 0.25);
uniform float thread_metal = 0.8;
uniform float trim_scale = 60.0;
uniform float pattern = 0.0; // 0 vine scroll, 1 knot band, 2 diamond
uniform vec3 wear_col : source_color = vec3(1.0);
uniform float wear_k = 0.0;
""" + NOISE + """
float vine(vec2 p){
	// p.x along band (repeating), p.y across 0..1
	float y = p.y - 0.5;
	float s = sin(p.x * 6.2831);
	float stem = abs(y - 0.22 * s) - 0.035;
	vec2 cell = vec2(fract(p.x) - 0.5, y);
	float side = s > 0.0 ? -1.0 : 1.0;
	vec2 cc = vec2(fract(p.x + 0.25) - 0.5, y + side * 0.12);
	float curl = abs(length(cc) - 0.16) - 0.03;
	float leaf = length((cell - vec2(0.0, 0.0)) * vec2(1.0, 2.2)) - 0.06;
	float border = min(abs(p.y - 0.06), abs(p.y - 0.94)) - 0.028;
	return min(min(stem, curl), min(border, 1e3 + leaf));
}
float knot(vec2 p){
	float y = p.y - 0.5;
	float a = abs(y - 0.25 * sin(p.x * 6.2831)) - 0.05;
	float b = abs(y + 0.25 * sin(p.x * 6.2831)) - 0.05;
	float border = min(abs(p.y - 0.06), abs(p.y - 0.94)) - 0.03;
	return min(min(a, b), border);
}
float diamond(vec2 p){
	vec2 q = vec2(fract(p.x) - 0.5, p.y - 0.5);
	float d = abs(abs(q.x) + abs(q.y) - 0.3) - 0.04;
	float dot_ = length(q) - 0.06;
	float border = min(abs(p.y - 0.06), abs(p.y - 0.94)) - 0.03;
	return min(min(d, dot_), border);
}
void fragment(){
	vec2 uv = UV * uv_scale;
	vec3 a = texture(albedo_tex, uv).rgb * tint;
	float r = texture(rough_tex, uv).r * rough_mul;
	vec3 nm = texture(normal_tex, uv).rgb;
	float m = metal;
	float wear = COLOR.g * wear_k;
	float cav = COLOR.b;
	// coupled wear: rims burnish brighter, smoother; cavities darker, rougher
	a = mix(a, a * wear_col * 1.6, wear);
	r = mix(r, r * 0.45, wear);
	a *= 1.0 - 0.45 * cav;
	r = mix(r, 1.0, cav * 0.3);
	float band = COLOR.r;
	if (band > 0.01) {
		vec2 tp = vec2(UV2.x * trim_scale, UV2.y);
		float dd = pattern < 0.5 ? vine(tp) : (pattern < 1.5 ? knot(tp) : diamond(tp));
		float th = (1.0 - smoothstep(-0.01, 0.015, dd)) * band;
		float st = 0.85 + 0.15 * sin(UV2.x * trim_scale * 90.0); // satin-stitch ridges
		a = mix(a, thread * st, th);
		m = mix(m, thread_metal, th);
		r = mix(r, 0.32, th);
	}
	ALBEDO = a;
	ROUGHNESS = clamp(r, 0.04, 1.0);
	METALLIC = m;
	SPECULAR = mix(0.22, 0.5, m);
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_depth;
	RIM = sheen;
	RIM_TINT = 0.6;
}
"""

## Studio environment for reflections/ambient: grey dome + three softboxes.
const SKY := """
shader_type sky;
uniform vec3 key_dir = vec3(0.6, 0.5, 0.6);
uniform vec3 rim_dir = vec3(-0.5, 0.4, -0.7);
uniform vec3 fill_dir = vec3(-0.8, 0.1, 0.5);
void sky(){
	vec3 d = EYEDIR;
	vec3 c = vec3(0.22, 0.22, 0.24) * (0.55 + 0.7 * smoothstep(-0.3, 0.7, d.y));
	c += vec3(0.10, 0.09, 0.08) * smoothstep(0.0, -0.4, d.y); // floor bounce
	c += vec3(0.35, 0.34, 0.33) * exp(-pow(d.y / 0.12, 2.0)); // bright horizon band (studio walls)
	c += vec3(4.0, 3.8, 3.5) * smoothstep(0.90, 0.95, dot(d, normalize(key_dir)));
	c += vec3(3.0, 2.9, 2.8) * smoothstep(0.93, 0.97, dot(d, normalize(rim_dir)));
	c += vec3(1.0, 1.1, 1.3) * smoothstep(0.85, 0.93, dot(d, normalize(fill_dir)));
	c += vec3(0.6) * smoothstep(0.985, 0.995, d.y); // overhead strip
	COLOR = c;
}
"""

## Studio cyclorama: soft radial gradient on the sweep, a faint floor pool.
const BACKDROP := """
shader_type spatial;
uniform vec3 top : source_color = vec3(0.36, 0.37, 0.40);
uniform vec3 bottom : source_color = vec3(0.16, 0.16, 0.18);
varying vec3 wp;
""" + NOISE + """
void vertex(){ wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment(){
	float g = smoothstep(-0.5, 3.5, wp.y);
	vec3 c = mix(bottom, top, g);
	float pool = exp(-dot(wp.xz, wp.xz) / 3.0);
	c *= 0.85 + 0.25 * pool;
	c *= 0.985 + 0.03 * vnoise3(wp * 40.0);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
"""
