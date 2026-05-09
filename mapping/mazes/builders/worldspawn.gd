extends MapperUtilities

@warning_ignore("unused_parameter")
static func build(map: MapperMap, entity: MapperEntity) -> Node:
	var node := create_merged_brush_entity(entity, "StaticBody3D")
	if not "rooms/" in map.source_file: return node

	# example... creating unique navigation region for each room
	if map.settings.options.get("maze_unpack", false):
		var navigation_region := create_navigation_region(map, node, true)
		navigation_region.navigation_mesh.geometry_source_geometry_mode = 1
		add_to_navigation_region(node, navigation_region)
		for map_entity in map.classnames.get("item_chest", []):
			add_entity_to_navigation_region(map_entity, navigation_region)
		for map_entity in map.classnames.get("item_prop", []):
			add_entity_to_navigation_region(map_entity, navigation_region)

	return node
