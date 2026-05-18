# Maze generation system for [godot-mapper](https://github.com/ELF32bit/godot-mapper) plugin
![Demonstration](screenshots/demonstration.webp)<br>
This maze generation system automates the assembly of modular rooms.<br>
The rooms are joined together via a minimal **`func_connector`** brush entity.<br>
Self-intersections are prevented by performing **AABB** checks of map brushes.<br>

## Explanation of the system
**`func_connector`** entity is a simple box with an **`angle`** of entrance.<br>
The build system will automatically find boxes with unique sizes to join.<br>
Joinable rooms for each connector are provided by adding **`next`** property.<br>
Here's a value example - `{ "rooms/01-aleph": 50%, "rooms/00-BREAK": 50% }`.<br>
Other room entities can specify **`maze_ignore`** property to disable **AABB** checks.<br>

Maze generator supports the following options.<br>
* **`maze_seed`** is a unique layout of the maze.
* **`maze_max_depth`** for how deep the maze can reach.
* **`maze_unpack`** will unpack rooms as unique nodes.

> Unpacking is designed for isolated rooms locked by doors.

Global room configuration is defined in **`func_connector+.gd`** script.<br>
**Uppercased** naming convention is used for the maps that seal exits.<br>

## How to create interesting rooms
Getting procedural generation right is very difficult without a direction.<br>
22 example rooms are based on the letters of **Phoenician/Hebrew** alphabet.<br>
Languages provide memorable shapes for the rooms as well as how they naturally join.<br>
Moreover, the letters can be further classified to give a special meaning to each room.<br>
There are 3 mother letters, 7 doubles and 12 simples according to Sefer Yetzirah.<br>
