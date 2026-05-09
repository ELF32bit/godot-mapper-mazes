extends MapperUtilities

@warning_ignore("unused_parameter")
static func build(map: MapperMap, entity: MapperEntity) -> Node:
	var node := create_merged_brush_entity(entity, "StaticBody3D")
	for child in node.find_children("*", "MeshInstance3D", true, false):
		child.cast_shadow = MeshInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	return node
