extends Node3D

@export var grid_width: int = 20
@export var grid_height: int = 20
@export var cell_size: float = 2.0
@export var wall_height: float = 3.0
@export var floor_material: Material
@export var wall_material: Material
@export var seed_value: int = 0

var grid: Array = []

func _ready() -> void:
	_make_dimensions_odd()
	if seed_value != 0:
		seed(seed_value)
	_move_spawn_point()
	_generate_maze()
	_build_maze()

func regenerate(new_width: int, new_height: int) -> void:
	grid_width = new_width
	grid_height = new_height
	_make_dimensions_odd()

	for child in get_children():
		child.queue_free()
	await get_tree().process_frame

	if seed_value != 0:
		seed(hash(Time.get_ticks_msec()))
	_move_spawn_point()
	_generate_maze()
	_build_maze()

func _make_dimensions_odd() -> void:
	if grid_width % 2 == 0:
		grid_width += 1
	if grid_height % 2 == 0:
		grid_height += 1

func _move_spawn_point() -> void:
	var spawn_point: Node3D = get_node_or_null("../MultiplayerSpawner/SpawnPoint")
	if spawn_point:
		spawn_point.position = Vector3(1.5 * cell_size, 0.0, 1.5 * cell_size)

func _generate_maze() -> void:
	grid = []
	for r: int in range(grid_height):
		grid.append([])
		for c: int in range(grid_width):
			grid[r].append(1)

	var start_r: int = 1
	var start_c: int = 1
	grid[start_r][start_c] = 0

	var walls: Array[Vector2i] = []
	_add_walls(start_r, start_c, walls)

	while not walls.is_empty():
		var idx: int = randi() % walls.size()
		var wall: Vector2i = walls[idx]
		var wr: int = wall.y
		var wc: int = wall.x
		walls[idx] = walls[walls.size() - 1]
		walls.resize(walls.size() - 1)

		if grid[wr][wc] == 0:
			continue

		var cell1_passage: bool = false
		var cell2_passage: bool = false
		var cell1_r: int = 0
		var cell1_c: int = 0
		var cell2_r: int = 0
		var cell2_c: int = 0

		if wr % 2 == 0:
			cell1_r = wr - 1
			cell1_c = wc
			cell2_r = wr + 1
			cell2_c = wc
		else:
			cell1_r = wr
			cell1_c = wc - 1
			cell2_r = wr
			cell2_c = wc + 1

		if cell1_r >= 0 and cell1_r < grid_height and cell1_c >= 0 and cell1_c < grid_width:
			cell1_passage = grid[cell1_r][cell1_c] == 0
		if cell2_r >= 0 and cell2_r < grid_height and cell2_c >= 0 and cell2_c < grid_width:
			cell2_passage = grid[cell2_r][cell2_c] == 0

		if cell1_passage != cell2_passage:
			grid[wr][wc] = 0
			if not cell2_passage:
				grid[cell2_r][cell2_c] = 0
				_add_walls(cell2_r, cell2_c, walls)
			else:
				grid[cell1_r][cell1_c] = 0
				_add_walls(cell1_r, cell1_c, walls)

	grid[0][1] = 0

func _add_walls(r: int, c: int, walls: Array[Vector2i]) -> void:
	var dirs: Array[Vector2i] = [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)]
	for dir: Vector2i in dirs:
		var nr: int = r + dir.y
		var nc: int = c + dir.x
		if nr > 0 and nr < grid_height - 1 and nc > 0 and nc < grid_width - 1:
			var wr: int = (r + nr) / 2
			var wc: int = (c + nc) / 2
			if grid[wr][wc] == 1:
				walls.append(Vector2i(wc, wr))

func _build_maze() -> void:
	var half_w: float = cell_size / 2.0
	var half_h: float = wall_height / 2.0

	# ── Suelo ──────────────────────────────────────────────────────────────
	var floor_center := Vector3(
		grid_width  * cell_size / 2.0,
		-0.05,
		grid_height * cell_size / 2.0
	)

	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	add_child(floor_body)

	var floor_col := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(grid_width * cell_size, 0.1, grid_height * cell_size)
	floor_col.shape = floor_shape
	floor_col.position = floor_center  # BUG FIX 1: la colisión debe coincidir con el mesh visual.
									   # Sin esto queda centrada en el origen (0,0,0) mientras el
									   # mesh está al centro del laberinto → los jugadores caen.
	floor_body.add_child(floor_col)

	var floor_mesh := MeshInstance3D.new()
	var floor_box := BoxMesh.new()
	floor_box.size = Vector3(grid_width * cell_size, 0.1, grid_height * cell_size)
	floor_box.material = floor_material
	floor_mesh.mesh = floor_box
	floor_mesh.position = floor_center
	floor_body.add_child(floor_mesh)

	# ── Paredes: colisión ──────────────────────────────────────────────────
	# BUG FIX 2: un StaticBody3D por celda crea 10 000–20 000 cuerpos de
	# física en una cuadrícula 200×200, lo que paraliza el motor.
	# Solución: un único StaticBody3D con todos los CollisionShape3D como
	# hijos, compartiendo la misma BoxShape3D (solo difieren en posición).

	var walls_body := StaticBody3D.new()
	walls_body.name = "Walls"
	add_child(walls_body)

	# Forma compartida: todos los bloques tienen el mismo tamaño, así que
	# podemos reutilizar el mismo recurso BoxShape3D en cada CollisionShape3D.
	var shared_shape := BoxShape3D.new()
	shared_shape.size = Vector3(cell_size, wall_height, cell_size)

	var wall_positions: Array[Vector3] = []

	for r: int in range(grid_height):
		for c: int in range(grid_width):
			if grid[r][c] == 0:
				continue

			var pos := Vector3(c * cell_size + half_w, half_h, r * cell_size + half_w)
			wall_positions.append(pos)

			var col := CollisionShape3D.new()
			col.shape = shared_shape  # reutilizar el mismo recurso de forma
			col.position = pos
			walls_body.add_child(col)

	# ── Paredes: renderizado ───────────────────────────────────────────────
	# MultiMeshInstance3D agrupa miles de instancias en una sola draw call.
	# Con MeshInstance3D separados el renderer se ahogaría con 200×200.

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "WallMeshes"
	add_child(mmi)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = wall_positions.size()

	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(cell_size, wall_height, cell_size)
	wall_box.material = wall_material
	mm.mesh = wall_box

	for i: int in range(wall_positions.size()):
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, wall_positions[i]))

	mmi.multimesh = mm
