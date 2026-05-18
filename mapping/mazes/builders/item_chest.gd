extends MapperUtilities

@warning_ignore("unused_parameter")
static func build(map: MapperMap, entity: MapperEntity) -> Node:
	if not map.metadata.has("items_rng"):
		map.metadata["items_rng"] = RandomNumberGenerator.new()
		map.metadata["items_rng"].seed = (map.settings.map_data_seed +
			map.settings.options.get("items_seed", 0))

	var map_path := map.settings.game_maps_directory.path_join(
		preload("__post.gd")._pick_weighted_random({
			"chests/01-golden": 1.0,
			"chests/02-trapped": 1.0,
			"chests/03-bloody": 1.0,
			"/": 7.0, # nothing
	}, map.metadata["items_rng"]))
	var scene := map.loader.load_map(map_path)
	if not scene: return null

	var scene_instance: Node3D = scene.instantiate()
	apply_entity_transform(entity, scene_instance, true)
	if entity.brushes.size() == 0: # supporting both point and brush entities
		scene_instance.position += Vector3.DOWN * 8.0 / map.settings.unit_size
	else: scene_instance.position += Vector3.DOWN * entity.aabb.size.y * 0.5

	return scene_instance
