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
		if STORE_SIMPLE_MAP_AABB:
			class_root.set_meta("MAPPER_MAP_AABBS", _get_map_aabb(map))
		else: class_root.set_meta("MAPPER_MAP_AABBS", _get_map_aabbs(map))

	return node


static func _get_map_aabbs(map: MapperMap, grow_by: float = 1.0) -> Array[AABB]:
	var aabbs: Array[AABB] = []
	for entity in map.entities:
		if entity.get_bool_property("maze_ignore", false):
			continue
		for brush in entity.brushes:
			if brush.aabb.has_surface():
				aabbs.append(brush.aabb)
		if entity.brushes.size() == 0:
			if entity.get_origin_property(null) != null:
				var aabb := AABB(entity.center, Vector3.ZERO)
				aabbs.append(aabb.grow(grow_by))
	return aabbs


static func _get_map_aabb(map: MapperMap) -> Array[AABB]:
	var aabb := AABB()
	var aabb_is_empty := true
	for entity in map.entities:
		if entity.get_bool_property("maze_ignore", false):
			continue
		if entity.brushes.size() == 0:
			if entity.get_origin_property(null) != null:
				if aabb_is_empty:
					aabb = AABB(entity.center, Vector3.ZERO)
					aabb_is_empty = false
				else: aabb = aabb.expand(entity.center)
		elif entity.aabb.has_surface():
			if aabb_is_empty:
				aabb = AABB(entity.aabb)
				aabb_is_empty = false
			else: aabb = aabb.merge(entity.aabb)
	if aabb_is_empty: return []
	return [aabb]
