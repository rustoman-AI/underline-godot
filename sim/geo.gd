class_name Geo
extends RefCounted

## Log-fisheye from data/map_geo.json. Polygon edges are densified before projection.


static func project(lat: float, lon: float, spec: Dictionary) -> Vector2:
	var dx := (lon - float(spec.lon0)) * float(spec.km_per_deg_lon)
	var dy := (lat - float(spec.lat0)) * float(spec.km_per_deg_lat)
	var radius := sqrt(dx * dx + dy * dy)
	if radius < 0.000001:
		return Vector2.ZERO
	# One third of the old log-fisheye. Far coasts stay near the frame edge.
	var k := float(spec.k_km) * 3.0
	var bowed := float(spec.scale) * log(1.0 + radius / k)
	return Vector2(dx / radius * bowed, -dy / radius * bowed)


static func densify_ring(ring: Array, step: float) -> Array:
	var out: Array = []
	var count := ring.size()
	if count == 0 or step <= 0.0:
		return out
	for i in count:
		var a: Array = ring[i]
		var b: Array = ring[(i + 1) % count]
		out.append(a)
		var dlat := float(b[0]) - float(a[0])
		var dlon := float(b[1]) - float(a[1])
		var dist := sqrt(dlat * dlat + dlon * dlon)
		var steps := int(ceil(dist / step))
		if steps <= 1:
			continue
		for s in range(1, steps):
			var t := float(s) / float(steps)
			out.append([float(a[0]) + dlat * t, float(a[1]) + dlon * t])
	return out


static func project_ring(ring: Array, spec: Dictionary, step: float) -> PackedVector2Array:
	var dense := densify_ring(ring, step)
	var out := PackedVector2Array()
	for point in dense:
		var pair: Array = point
		out.append(project(float(pair[0]), float(pair[1]), spec))
	return out


static func self_check() -> PackedStringArray:
	var errs: PackedStringArray = []
	var spec := {
		"lat0": 40.712,
		"lon0": -73.995,
		"km_per_deg_lon": 84.2,
		"km_per_deg_lat": 111.0,
		"k_km": 1.2,
		"scale": 215.0,
	}
	var origin := project(40.712, -73.995, spec)
	if origin.length() > 0.001:
		errs.append("origin %s" % origin)
	var ring := [[40.70, -74.00], [40.71, -74.00]]
	var dense := densify_ring(ring, 0.0025)
	# 0.01 deg / 0.0025 = 4 segments, so 3 inserted points, plus the two corners, and the close-back edge.
	if dense.size() < 5:
		errs.append("densify %d" % dense.size())
	var bowed := project(40.7527, -73.9772, spec)
	if bowed.y >= 0.0:
		errs.append("north should sit up, got %s" % bowed)
	return errs
