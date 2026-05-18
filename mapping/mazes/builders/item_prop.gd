extends MapperUtilities

@warning_ignore("unused_parameter")
static func build(map: MapperMap, entity: MapperEntity) -> Node:
	if not map.metadata.has("items_rng"):
		map.metadata["items_rng"] = RandomNumberGenerator.new()
		map.metadata["items_rng"].seed = (map.settings.map_data_seed +
			map.settings.options.get("items_seed", 0))

	var map_path := map.settings.game_maps_directory.path_join(
		preload("__post.gd")._pick_weighted_random({
			"props/01-barrel-brown": 1.0,
			"props/02-barrel-honey": 1.0,
			"props/03-crate-cyan": 1.0,
			"props/04-crate-green": 1.0,
			"props/05-lantern-blue": 1.0,
			"props/06-lantern-red": 1.0,
			"props/07-rock-small": 1.0,
			"props/08-rock-medium": 1.0,
			"props/09-rock-big": 1.0,
			"/": 11.0, # nothing
	}, map.metadata["items_rng"]))
	var scene := map.loader.load_map(map_path)
	if not scene: return null

	var scene_instance: Node3D = scene.instantiate()
	apply_entity_transform(entity, scene_instance, true)
	if entity.brushes.size() == 0: # supporting both point and brush entities
		scene_instance.position += Vector3.DOWN * 8.0 / map.settings.unit_size
	else: scene_instance.position += Vector3.DOWN * entity.aabb.size.y * 0.5

	scene_instance.rotation.y = ( # also adding random rotation to map props
		map.metadata["items_rng"].randf_range(0.0, 2.0 * PI))

	return scene_instance
