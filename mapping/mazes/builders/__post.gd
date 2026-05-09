const CONFIGURATION := preload("func_connector+.gd")

@warning_ignore("unused_parameter")
static func build(map: MapperMap) -> void:
	if "/generate" in map.source_file:
		return _generate(map)


static func _generate(map: MapperMap) -> void:
	var parameters: Dictionary = {}
	parameters["maze_seed"] = map.settings.options.get("maze_seed", 0)
	parameters["maze_max_depth"] = map.settings.options.get("maze_max_depth", 8)
	parameters["maze_unpack"] = map.settings.options.get("maze_unpack", true)
	parameters["maze_debug"] = map.settings.options.get("maze_debug", false)
	parameters["map_loader"] = map.loader

	# loading start maps from the configuration
	var start_rooms: Dictionary = {}
	for path in CONFIGURATION.START_ROOMS:
		path = map.settings.game_maps_directory.path_join(path)
		var room_scene: PackedScene = null
		if not parameters["maze_unpack"]:
			room_scene = map.loader.load_map(path)
		else: room_scene = map.loader.load_map_raw(path, true)
		if room_scene: start_rooms[path] = room_scene

	# loading all next maps from the configuration
	var all_next_rooms: Dictionary = {}
	for path in CONFIGURATION.ALL_NEXT_ROOMS:
		path = map.settings.game_maps_directory.path_join(path)
		var room_scene: PackedScene = null
		if not parameters["maze_unpack"]:
			room_scene = map.loader.load_map(path)
		else: room_scene = map.loader.load_map_raw(path, true)
		if room_scene: all_next_rooms[path] = room_scene

	# preloading all maps and reading information
	var aabbs: Dictionary = {}
	var connectors: Dictionary = {}
	for scene in start_rooms.values() + all_next_rooms.values():
		var scene_connectors := _find_map_connectors(scene, map.settings.unit_size)
		aabbs[scene] = scene_connectors.get("_aabbs", [])
		connectors[scene] = scene_connectors
		scene_connectors.erase("_aabbs")

	var rng := RandomNumberGenerator.new()
	rng.seed = parameters["maze_seed"]
	_connect_maps_recursively({
		"aabbs": [],
		"root_node": map.node,
		"map": _pick_random(start_rooms.values(), rng),
		"map_transform": Transform3D.IDENTITY,
		"map_connector": null,
		"maps": all_next_rooms,
		"maps_connectors": connectors,
		"maps_aabbs": aabbs,
		"depth": 1,
		"rng": rng,
	}, parameters)

	# cleaning leftover metadata
	if parameters["maze_unpack"]:
		_clean_metadata(map)


static func _clean_metadata(map: MapperMap) -> void:
	for node in map.node.find_children("func_connector", "Node3D", true, false):
		if node.has_meta("MAPPER_AABBS"): node.remove_meta("MAPPER_AABBS")
		for child in node.get_children():
			if child.has_meta("MAPPER_AABB"): node.remove_meta("MAPPER_AABB")
			if child.has_meta("MAPPER_NEXT"): node.remove_meta("MAPPER_NEXT")


static func _find_map_connectors(map: PackedScene, unit_size: float) -> Dictionary:
	var map_instance := map.instantiate()
	var node := map_instance.get_node_or_null("func_connector")
	if not node: return {}

	# trying to find map connectors
	var connectors: Dictionary = {}
	for child in node.get_children():
		if not child is Node3D: continue
		if not child.has_meta("MAPPER_AABB"): continue
		var aabb: AABB = child.get_meta("MAPPER_AABB")
		if not aabb.has_volume(): continue

		# generating unique AABB size signature
		var aabb_id: Array = []
		aabb_id.append(int(aabb.size.x * unit_size))
		aabb_id.append(int(aabb.size.z * unit_size))
		aabb_id.sort() # ignoring rotations in XZ plane
		aabb_id.append(int(aabb.size.y * unit_size))

		# trying to read next maps table
		var next: Variant = null
		if child.has_meta("MAPPER_NEXT"):
			next = child.get_meta("MAPPER_NEXT")

		# also applying AABB offset in the natural direction
		var forward_axis: int = child.basis.z.abs().max_axis_index()
		var aabb_offset := aabb.size[forward_axis] * 0.5
		connectors.get_or_add(aabb_id, []).append({
			"center": aabb.get_center() + child.basis.z * aabb_offset,
			"basis": child.basis,
			"next": next,
		})

	# obtaining map AABBs information from the class root
	connectors["_aabbs"] = node.get_meta("MAPPER_AABBS", [])
	map_instance.free()
	return connectors


static func _connect_maps_recursively(data: Dictionary, parameters: Dictionary) -> void:
	if data["depth"] > parameters["maze_max_depth"] + 1: return
	if data["map"] == null: return

	# finding the loading path for the current next map
	var maps_path: Variant = null
	var map_path: Variant = data["maps"].find_key(data["map"])
	var dir: String = parameters["map_loader"].settings.game_maps_directory
	if map_path != null: maps_path = map_path.trim_prefix(dir + "/")

	# unpacking the current next map as unique nodes
	var map: PackedScene = data["map"]
	if parameters["maze_unpack"] and data["depth"] != 1:
		map = parameters["map_loader"].load_map_raw(map_path, false)

	# creating the current map instance
	var map_instance: Node3D = map.instantiate()
	map_instance.set_meta("MAPPER_DEPTH", data["depth"])
	data["root_node"].add_child(map_instance, true)
	map_instance.transform = data["map_transform"]

	# adding the current map AABBs to the maze
	for aabb in data["maps_aabbs"][data["map"]]:
		data["aabbs"].append(data["map_transform"] * aabb)
		if parameters.get("maze_debug", false): # creating debug meshes
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = BoxMesh.new()
			mesh_instance.mesh.size = data["aabbs"][-1].size
			mesh_instance.position = data["aabbs"][-1].get_center()
			data["root_node"].add_child(mesh_instance, false)

	# finding active connectors
	var active_connectors: Array[Array] = []
	var connectors: Dictionary = data["maps_connectors"][data["map"]]
	for unique_connector in connectors:
		for connector in connectors[unique_connector]:
			if connector == data["map_connector"]: continue
			active_connectors.append([connector, unique_connector])

	# trying to activate discovered connectors in a random order
	while active_connectors.size():
		var active_connector: Array = _pick_random(active_connectors, data["rng"], true)
		var unique_connector: Array = active_connector[1]
		var connector: Dictionary = active_connector[0]

		# figuring out the priority table of the next maps for the connector
		var next_maps: Dictionary = {}
		if connector["next"] != null:
			var next: Dictionary = connector["next"]
			for next_map_path in next:
				next_maps[dir.path_join(next_map_path)] = next[next_map_path]
		elif CONFIGURATION.NEXT_ROOM_WEIGHTS.has(maps_path):
			var next: Dictionary = CONFIGURATION.NEXT_ROOM_WEIGHTS[maps_path]
			for next_map_path in next:
				next_maps[dir.path_join(next_map_path)] = next[next_map_path]
		else: # creating equal priority table for all the next maps
			for next_map_path in data["maps"]:
				next_maps[next_map_path] = 1.0
			next_maps["/"] = 1.0

		# trying to add next maps to the current connector
		next_maps = next_maps.duplicate()
		while next_maps.size():
			var next_map_path: String = _pick_weighted_random(next_maps, data["rng"], true)
			var next_map: PackedScene = data["maps"].get(next_map_path, null)
			if not next_map: break

			# using only uppercased maps at the deepest level
			if data["depth"] == parameters["maze_max_depth"]:
				var path := next_map_path.get_file().get_basename()
				if path.to_upper() != path:
					continue

			# finding next map connectors and trying to align them
			var next_map_connectors: Dictionary = data["maps_connectors"][next_map]
			var next_connectors: Array = next_map_connectors.get(unique_connector, [])
			if not next_connectors.size() > 0: continue

			var has_connected := false
			next_connectors = next_connectors.duplicate()
			while not has_connected and next_connectors.size():
				var next_connector: Dictionary = _pick_random(next_connectors, data["rng"], true)

				# transforming next map coordinates to align with the connector
				var t1 := Transform3D(connector["basis"], connector["center"])
				var t2 := Transform3D(next_connector["basis"], next_connector["center"])
				t2.basis = t2.basis.looking_at(+t2.basis.z, t2.basis.y)
				var transform: Transform3D = data["map_transform"] * t1 * t2.affine_inverse()

				# intersecting maze and next map AABBs
				var is_fitting := true
				for next_map_aabb in data["maps_aabbs"][next_map]:
					var next_aabb: AABB = transform * next_map_aabb
					for aabb in data["aabbs"]:
						if next_aabb.intersection(aabb).get_volume() > 0.1:
							is_fitting = false
							break
					if not is_fitting: break
				if not is_fitting: continue
				has_connected = true

				# preparing recursion data for the next map
				var new_data := data.duplicate()
				new_data["map"] = next_map
				new_data["map_transform"] = transform
				new_data["map_connector"] = next_connector
				new_data["depth"] = new_data["depth"] + 1
				new_data["rng"] = RandomNumberGenerator.new()
				new_data["rng"].seed = data["rng"].randi()

				# starting depth first recursion
				_connect_maps_recursively(new_data, parameters)
			if has_connected:
				break


static func _pick_weighted_random(dictionary: Dictionary, rng: RandomNumberGenerator, erase: bool = false) -> Variant:
	if not dictionary.size(): return "/"
	var max_weight: float = 0.0
	for weight in dictionary.values():
		max_weight += weight
	var r: float = rng.randf_range(0.0, max_weight)
	var keys := dictionary.keys()
	for key in keys:
		r -= dictionary[key]
		if r > 0.0: continue
		if erase: dictionary.erase(key)
		return key
	if erase: dictionary.erase(keys[-1])
	return keys[-1]


static func _pick_random(array: Array, rng: RandomNumberGenerator, erase: bool = false) -> Variant:
	if not array.size(): return null
	var index := posmod(rng.randi(), array.size())
	var element: Variant = array[index]
	if erase: array.remove_at(index)
	return element
