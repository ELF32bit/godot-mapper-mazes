extends MapperUtilities

const STORE_SIMPLE_MAP_AABB := false

@warning_ignore("unused_parameter")
static func build(map: MapperMap, entity: MapperEntity) -> Node:
	var node := Marker3D.new()
	apply_entity_transform(entity, node, true)
	node.set_meta("MAPPER_MAZE_NEXT", entity.get_variant_property("next", null))
	node.set_meta("MAPPER_AABB", entity.aabb)

	# also storing map AABBs on the class root node
	var class_root := map.node.get_node("func_connector")
	if not class_root.has_meta("MAPPER_MAP_AABBS"):
		if map.settings.options.get("maze_ignore", false):
			class_root.set_meta("MAPPER_MAP_AABBS", [])
		elif STORE_SIMPLE_MAP_AABB:
			class_root.set_meta("MAPPER_MAP_AABBS", _get_map_aabb(map))
		else: class_root.set_meta("MAPPER_MAP_AABBS", _get_map_aabbs(map))

	return node


static func _get_map_aabbs(map: MapperMap, grow_by: float = 0.25) -> Array[AABB]:
	var aabbs: Array[AABB] = []
	for entity in map.entities:
		if entity.get_bool_property("maze_ignore", false):
			continue
		for brush in entity.brushes:
			if brush.aabb.has_surface():
				aabbs.append(brush.aabb)
		if entity.brushes.size() == 0:
			if entity.get_origin_property(null) != null:
				var point_aabb := AABB(entity.center, Vector3.ZERO)
				point_aabb = point_aabb.grow(grow_by)
				aabbs.append(point_aabb)
	return aabbs


static func _get_map_aabb(map: MapperMap, grow_by: float = 0.25) -> Array[AABB]:
	var aabb := AABB()
	var aabb_is_empty := true
	for entity in map.entities:
		if entity.get_bool_property("maze_ignore", false):
			continue
		if entity.brushes.size() == 0:
			if entity.get_origin_property(null) != null:
				var point_aabb := AABB(entity.center, Vector3.ZERO)
				point_aabb = point_aabb.grow(grow_by)
				if aabb_is_empty:
					aabb = point_aabb
					aabb_is_empty = false
				else: aabb = aabb.merge(point_aabb)
		elif entity.aabb.has_surface():
			if aabb_is_empty:
				aabb = entity.aabb
				aabb_is_empty = false
			else: aabb = aabb.merge(entity.aabb)
	if aabb_is_empty: return []
	return [aabb]
