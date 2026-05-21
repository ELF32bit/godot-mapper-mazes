extends MapperUtilities

@warning_ignore("unused_parameter")
static func build(map: MapperMap) -> void:
	if "/generate" in map.source_file:
		var _merged_connectors := _generate_maze(map)


static func _generate_maze(map: MapperMap) -> Array[Dictionary]:
	var parameters: Dictionary = {}
	parameters["map_loader"] = map.loader
	parameters["configuration"] = map.loader.load_script(
		map.settings.game_builders_directory.path_join("func_connector+"))

	var options := map.settings.options
	parameters["maze_seed"] = options.get("maze_seed", 0)
	parameters["maze_max_depth"] = options.get("maze_max_depth", 8)
	parameters["maze_end_depth"] = options.get("maze_end_depth", 2)
	parameters["maze_unpack"] = options.get("maze_unpack", false)
	parameters["maze_debug"] = options.get("maze_debug", false)

	# loading all maps from the configuration
	var start_maps: Dictionary = {}
	var middle_maps: Dictionary = {}
	var end_maps: Dictionary = {}

	var unique_scenes: Dictionary = {}
	var dir := map.settings.game_maps_directory
	var s1 = parameters["configuration"].START_MAPS.size()
	var s2 = s1 + parameters["configuration"].MIDDLE_MAPS.size()
	var map_paths = parameters["configuration"].START_MAPS
	map_paths += parameters["configuration"].MIDDLE_MAPS
	map_paths += parameters["configuration"].END_MAPS

	for index in range(map_paths.size()):
		var path := dir.path_join(map_paths[index])
		var map_scene: PackedScene = null
		if not parameters["maze_unpack"]:
			map_scene = map.loader.load_map(path)
		else: map_scene = map.loader.load_map_raw(path, true)
		if not map_scene: continue

		unique_scenes[map_scene] = map_scene
		if index < s1: start_maps[path] = map_scene
		elif index < s2: middle_maps[path] = map_scene
		else: end_maps[path] = map_scene

	# preloading all maps and reading information
	var aabbs: Dictionary = {}
	var connectors: Dictionary = {}
	var merged_connectors: Array[Dictionary] = []
	for scene in unique_scenes:
		var scene_connectors := _find_map_connectors(scene, map.settings.unit_size)
		aabbs[scene] = scene_connectors.get("_aabbs", [])
		connectors[scene] = scene_connectors
		scene_connectors.erase("_aabbs")

	var has_end: Array = [null]
	var rng := RandomNumberGenerator.new()
	rng.seed = parameters["maze_seed"]
	_connect_maps_recursively({
		"aabbs": [],
		"root_node": map.node,
		"merged_connectors": merged_connectors,
		"map": _pick_random(start_maps.values(), rng),
		"map_transform": Transform3D.IDENTITY,
		"map_connector_path": null,
		"map_connector": null,
		"maps_aabbs": aabbs,
		"maps_connectors": connectors,
		"maps": start_maps.merged(middle_maps.merged(end_maps)),
		"next_maps": middle_maps.merged(end_maps),
		"end_maps": end_maps,
		"has_end": has_end,
		"depth": 1,
		"rng": rng,
	}, parameters)
	if not has_end[0] and end_maps.size():
		push_warning("The end map was not generated, try a different maze seed.")

	if parameters["maze_unpack"]: # clearing leftover connectors after unpacking
		for node in map.node.find_children("func_connector", "Node3D", true, false):
			if node.has_meta("MAPPER_MAP_AABBS"): node.free()
	return merged_connectors


static func _find_map_connectors(map: PackedScene, unit_size: float) -> Dictionary:
	var map_instance := map.instantiate()
	var node := map_instance.get_node_or_null("func_connector")
	if not (node and node.has_meta("MAPPER_MAP_AABBS")):
		map_instance.free()
		return {}

	# trying to find map connectors
	var connectors: Dictionary = {}
	for child in node.get_children():
		if not child is Node3D: continue
		if not child.has_meta("MAPPER_AABB"): continue
		var aabb: AABB = child.get_meta("MAPPER_AABB")

		# generating unique AABB size signature
		var forward_axis: int = child.basis.z.abs().max_axis_index()
		var right_axis: int = child.basis.x.abs().max_axis_index()
		var up_axis: int = child.basis.y.abs().max_axis_index()

		var axes: Array = [0, 1, 2]
		axes.erase(forward_axis)
		if up_axis in axes:
			axes.erase(up_axis)
			right_axis = axes[0]
		elif right_axis in axes:
			axes.erase(right_axis)
			up_axis = axes[0]
		else:
			right_axis = axes[1]
			up_axis = axes[0]

		var aabb_id: Array = []
		aabb_id.append(roundi(aabb.size[right_axis] * unit_size))
		aabb_id.append(roundi(aabb.size[forward_axis] * unit_size))
		aabb_id.sort() # ignoring rotations in a local XZ plane
		aabb_id.append(roundi(aabb.size[up_axis] * unit_size))

		# trying to read next maps table
		var next: Variant = null
		if child.has_meta("MAPPER_MAZE_NEXT"):
			next = child.get_meta("MAPPER_MAZE_NEXT")

		# also applying AABB offset in the natural direction
		var aabb_offset := aabb.size[forward_axis] * 0.5
		connectors.get_or_add(aabb_id, []).append({
			"center": aabb.get_center() + child.basis.z * aabb_offset,
			"aabb": aabb.expand(aabb.get_center() + child.basis.z * aabb_offset * 3.0),
			"basis": child.basis,
			"next": next,
		})

	# obtaining map AABBs information from the class root
	connectors["_aabbs"] = node.get_meta("MAPPER_MAP_AABBS", [])
	map_instance.free()
	return connectors


static func _connect_maps_recursively(data: Dictionary, parameters: Dictionary) -> void:
	if data["depth"] > parameters["maze_max_depth"] + 1: return
	if data["map"] == null: return

	# finding loading paths for the current map
	var map_weights: Dictionary = parameters["configuration"].NEXT_MAP_WEIGHTS
	var dir: String = parameters["map_loader"].settings.game_maps_directory
	var map_path: String = data["maps"].find_key(data["map"])
	var maps_path := map_path.trim_prefix(dir + "/")

	# unpacking current next map as unique nodes
	var map: PackedScene = data["map"]
	if parameters["maze_unpack"] and data["depth"] != 1:
		map = parameters["map_loader"].load_map_raw(map_path, false)

	# creating current map instance
	var map_instance: Node3D = map.instantiate()
	data["root_node"].add_child(map_instance, true)
	map_instance.transform = data["map_transform"]

	# storing useful metadata for the current map instance
	map_instance.set_meta("MAPPER_MAZE_DEPTH", data["depth"])
	if data["map_connector_path"] != null:
		map_instance.set_meta("MAPPER_MAZE_NEIGHBOURS",
			{ data["map_connector_path"]: 1 })
	else:
		map_instance.set_meta("MAPPER_MAZE_NEIGHBOURS", {})
	if data["depth"] == 1:
		map_instance.set_meta("MAPPER_MAZE_START", true)
	elif data["has_end"][0] == data["map"]:
		map_instance.set_meta("MAPPER_MAZE_END", true)

	# adding current map AABBs to the maze
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

		# figuring out the priority table of next maps for the connector
		var next_maps: Dictionary = {}
		if connector["next"] != null:
			var next: Dictionary = connector["next"]
			for next_map_path in next:
				next_maps[dir.path_join(next_map_path)] = next[next_map_path]
		elif map_weights.has(maps_path):
			var next: Dictionary = map_weights[maps_path]
			for next_map_path in next:
				next_maps[dir.path_join(next_map_path)] = next[next_map_path]
		else: # creating equal priority table for all the next maps
			for next_map_path in data["next_maps"]:
				next_maps[next_map_path] = 1.0

		# not spawning the end map until a certain depth is reached
		if (data["depth"] + 1) < parameters["maze_end_depth"] or data["has_end"][0]:
			for next_map_path in next_maps.keys():
				if next_map_path in data["end_maps"]:
					next_maps.erase(next_map_path)

		# using uppercased maps to seal the deepest levels of the maze and the end map
		if data["depth"] == parameters["maze_max_depth"] or data["has_end"][0] == data["map"]:
			for next_map_path in next_maps.keys():
				var path: String = next_map_path.get_file().get_basename()
				if path.to_upper() != path: next_maps.erase(next_map_path)

		# trying to add next maps to the current connector
		while next_maps.size():
			var next_map_path: String = _pick_weighted_random(next_maps, data["rng"], true)
			var next_map: PackedScene = data["next_maps"].get(next_map_path, null)
			if not next_map: break

			# finding next map connectors and trying to align them
			var next_map_connectors: Dictionary = data["maps_connectors"][next_map]
			var next_connectors: Array = next_map_connectors.get(unique_connector, [])
			if not next_connectors.size() > 0: continue

			var has_connected := false
			next_connectors = next_connectors.duplicate(false)
			while not has_connected and next_connectors.size():
				var next_connector: Dictionary = _pick_random(next_connectors, data["rng"], true)

				# transforming next map coordinates to align with the connector
				var t1 := Transform3D(connector["basis"], connector["center"])
				var t2 := Transform3D(next_connector["basis"], next_connector["center"])
				t2.basis = Basis.looking_at(+t2.basis.z, t2.basis.y)
				var transform: Transform3D = data["map_transform"] * t1 * t2.affine_inverse()

				# intersecting the maze and next map AABBs
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

				# checking if the next map is the end map
				if not data["has_end"][0]:
					if next_map_path in data["end_maps"]:
						data["has_end"][0] = next_map

				# adding current connector to the merged connectors
				data["merged_connectors"].append({
					"depth": data["depth"],
					"aabb": data["map_transform"] * connector["aabb"],
					"center": data["map_transform"] * connector["center"],
					"next": next_map_path, "previous": map_path })
				var b: Basis = data["map_transform"].basis * connector["basis"]
				data["merged_connectors"][-1]["basis"] = Basis.looking_at(+b.z, b.y)

				# preparing recursion data for the next map
				var new_data := data.duplicate(false)
				new_data["map"] = next_map
				new_data["map_transform"] = transform
				new_data["map_connector_path"] = map_path
				new_data["map_connector"] = next_connector
				new_data["depth"] = new_data["depth"] + 1
				new_data["rng"] = RandomNumberGenerator.new()
				new_data["rng"].seed = data["rng"].randi()

				# starting depth first recursion
				var map_neighbours: Dictionary = map_instance.get_meta("MAPPER_MAZE_NEIGHBOURS")
				map_neighbours[next_map_path] = map_neighbours.get(next_map_path, 0) + 1
				_connect_maps_recursively(new_data, parameters)
			if has_connected:
				break


static func _pick_weighted_random(dictionary: Dictionary, rng: RandomNumberGenerator, erase: bool = false) -> Variant:
	if not dictionary.size(): return null
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
