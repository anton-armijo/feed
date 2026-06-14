extends Node3D

@export var grid_width: int = 20
@export var grid_height: int = 20
@export var cell_size: float = 2.0
@export var wall_height: float = 3.0
@export var floor_material: Material
@export var wall_material: Material
@export var seed_value: int = 0
@export var exit_object: PackedScene

## Grid plano 1D: 0 = pasaje, 1 = muro.
## Índice = r * grid_width + c
## PackedByteArray usa memoria contigua → sin boxing, sin punteros indirectos,
## fill() nativa en C++. Hasta 10x más rápido que Array[Array[int]] en grids grandes.
var grid: PackedByteArray

# ─────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	NetworkManager.maze_params_received.connect(_on_maze_params_received)

	if NetworkManager.maze_configured:
		grid_width = NetworkManager.maze_width
		grid_height = NetworkManager.maze_height
		_make_dimensions_odd()
		seed(NetworkManager.maze_seed)
	else:
		_make_dimensions_odd()
		if seed_value != 0:
			seed(seed_value)

	_move_spawn_point()
	_generate_maze()
	_build_maze()

func _on_maze_params_received(w: int, h: int, s: int) -> void:
	regenerate(w, h, s)

func regenerate(new_width: int, new_height: int, using_seed: int = 0) -> void:
	grid_width = new_width
	grid_height = new_height
	_make_dimensions_odd()

	for child in get_children():
		child.queue_free()
	await get_tree().process_frame

	if using_seed != 0:
		seed(using_seed)
	elif seed_value != 0:
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
	var sp := get_node_or_null("../MultiplayerSpawner/SpawnPoint") as Node3D
	if sp:
		sp.position = Vector3(1.5 * cell_size, 0.0, 1.5 * cell_size)

# ─────────────────────────────────────────────────────────────────────────
## OPTIMIZACIÓN 1: grid plano (PackedByteArray) + candidatos como enteros
## (PackedInt32Array).
##
## Cada celda se codifica como un único int32: r * grid_width + c.
## Elimina el overhead de Vector2i (objeto heap), reduce presión en el GC,
## y permite operaciones de lectura/escritura sobre un buffer contiguo.
func _generate_maze() -> void:
	grid = PackedByteArray()
	grid.resize(grid_width * grid_height)
	grid.fill(1)                       # todo muros
	grid[grid_width + 1] = 0           # celda inicial (1, 1)

	var candidates := PackedInt32Array()
	_add_candidates(1, 1, candidates)

	while candidates.size() > 0:
		# Extracción aleatoria O(1): swap-con-último + resize.
		# Evita desplazar los elementos del array (lo cual sería O(n)).
		var pick    := randi() % candidates.size()
		var encoded := candidates[pick]
		candidates[pick] = candidates[candidates.size() - 1]
		candidates.resize(candidates.size() - 1)

		if grid[encoded] == 0:   # duplicado ya abierto → descartar
			continue

		var wr := encoded / grid_width
		var wc := encoded % grid_width

		# Las dos celdas que este muro separa
		var c1r: int; var c1c: int
		var c2r: int; var c2c: int
		if wr % 2 == 0:              # muro entre filas
			c1r = wr - 1; c1c = wc
			c2r = wr + 1; c2c = wc
		else:                         # muro entre columnas
			c1r = wr; c1c = wc - 1
			c2r = wr; c2c = wc + 1

		var c1_open := c1r >= 0 and c1r < grid_height and c1c >= 0 and c1c < grid_width \
					   and grid[c1r * grid_width + c1c] == 0
		var c2_open := c2r >= 0 and c2r < grid_height and c2c >= 0 and c2c < grid_width \
					   and grid[c2r * grid_width + c2c] == 0

		if c1_open != c2_open:
			grid[encoded] = 0
			if not c2_open:
				grid[c2r * grid_width + c2c] = 0
				_add_candidates(c2r, c2c, candidates)
			else:
				grid[c1r * grid_width + c1c] = 0
				_add_candidates(c1r, c1c, candidates)

	grid[1] = 0   # entrada: celda (0, 1)

## Añade los muros entre (r,c) y sus vecinos a distancia 2.
## Solo añade el muro si todavía es 1 (evita duplicados innecesarios).
func _add_candidates(r: int, c: int, candidates: PackedInt32Array) -> void:
	# Izquierda — vecino (r, c-2), muro (r, c-1)
	if c - 2 > 0 and r > 0 and r < grid_height - 1:
		var wi := r * grid_width + (c - 1)
		if grid[wi] == 1:
			candidates.append(wi)

	# Derecha — vecino (r, c+2), muro (r, c+1)
	if c + 2 < grid_width - 1 and r > 0 and r < grid_height - 1:
		var wi := r * grid_width + (c + 1)
		if grid[wi] == 1:
			candidates.append(wi)

	# Arriba — vecino (r-2, c), muro (r-1, c)
	if r - 2 > 0 and c > 0 and c < grid_width - 1:
		var wi := (r - 1) * grid_width + c
		if grid[wi] == 1:
			candidates.append(wi)

	# Abajo — vecino (r+2, c), muro (r+1, c)
	if r + 2 < grid_height - 1 and c > 0 and c < grid_width - 1:
		var wi := (r + 1) * grid_width + c
		if grid[wi] == 1:
			candidates.append(wi)

# ─────────────────────────────────────────────────────────────────────────
func _build_maze() -> void:
	var exit_object_pos = Vector3(
		(grid_width - 2) * cell_size + cell_size * 0.5,
		 0, 
		grid_height * cell_size - cell_size * 1.5)
	var exit_obj_node = exit_object.instantiate()
	exit_obj_node.position = exit_object_pos
	add_child(exit_obj_node)
	var half_h := wall_height * 0.5
	var half_c := cell_size  * 0.5

	# ── Suelo ────────────────────────────────────────────────────────────
	var total_w := grid_width  * cell_size
	var total_d := grid_height * cell_size
	var floor_center := Vector3(total_w * 0.5, -0.05, total_d * 0.5)

	var floor_body := StaticBody3D.new()
	floor_body.name = "Floor"
	add_child(floor_body)

	var fc := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(total_w, 0.1, total_d)
	fc.shape = fs
	fc.position = floor_center
	floor_body.add_child(fc)

	var fm := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(total_w, 0.1, total_d)
	fb.material = floor_material
	fm.mesh = fb
	fm.position = floor_center
	floor_body.add_child(fm)

	# ── Muros: colisión con fusión greedy de rectángulos ─────────────────
	## OPTIMIZACIÓN 2: en lugar de 1 CollisionShape3D por celda muro,
	## el algoritmo agrupa celdas adyacentes en el rectángulo más grande posible
	## y emite una sola shape para todo el bloque.
	##
	## Procedimiento fila-por-fila:
	##   1. Encuentra una celda muro sin procesar.
	##   2. Extiende a la derecha hasta donde pueda.
	##   3. Extiende hacia abajo mientras TODAS las columnas [c..c_end] sean muro.
	##   4. Emite un único CollisionShape para el rectángulo (r..r_end, c..c_end).
	##
	## En un laberinto 21×21 (~130 celdas muro) esto pasa de ~130 shapes
	## a típicamente 15–30. En un laberinto 201×201 pasa de ~20 000 shapes
	## a ~500, lo que elimina el cuello de botella del motor de física.

	var walls_body := StaticBody3D.new()
	walls_body.name = "Walls"
	add_child(walls_body)

	# Copia de trabajo: 0 = pasaje, 1 = muro pendiente, 2 = ya fusionado
	var visited := grid.duplicate()

	for r in range(grid_height):
		var c := 0
		while c < grid_width:
			if visited[r * grid_width + c] != 1:
				c += 1
				continue

			# Paso 1: extender a la derecha
			var c_end := c
			while c_end + 1 < grid_width and visited[r * grid_width + c_end + 1] == 1:
				c_end += 1

			# Paso 2: extender hacia abajo
			var r_end := r
			while r_end + 1 < grid_height:
				var row_full := true
				for cc in range(c, c_end + 1):
					if visited[(r_end + 1) * grid_width + cc] != 1:
						row_full = false
						break
				if not row_full:
					break
				r_end += 1

			# Paso 3: marcar el rectángulo como procesado
			for rr in range(r, r_end + 1):
				for cc in range(c, c_end + 1):
					visited[rr * grid_width + cc] = 2

			# Paso 4: una sola CollisionShape cubre todo el rectángulo
			var rect_w := (c_end - c + 1) * cell_size
			var rect_d := (r_end - r + 1) * cell_size
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(rect_w, wall_height, rect_d)
			col.shape = shape
			col.position = Vector3(
				c * cell_size + rect_w * 0.5,
				half_h,
				r * cell_size + rect_d * 0.5
			)
			walls_body.add_child(col)

			c = c_end + 1

	# ── Muros: renderizado con MultiMesh ─────────────────────────────────
	## OPTIMIZACIÓN 3: PackedVector3Array para acumular posiciones.
	## Los packed arrays evitan la asignación de Variant en cada append(),
	## lo que es relevante cuando hay miles de instancias.
	var wall_positions := PackedVector3Array()
	for r in range(grid_height):
		for c in range(grid_width):
			if grid[r * grid_width + c] == 1:
				wall_positions.append(Vector3(
					c * cell_size + half_c,
					half_h,
					r * cell_size + half_c
				))

	if wall_positions.is_empty():
		return

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "WallMeshes"
	add_child(mmi)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D

	var wall_box := BoxMesh.new()
	wall_box.size = Vector3(cell_size, wall_height, cell_size)
	wall_box.material = wall_material
	mm.mesh = wall_box               # mesh primero, luego instance_count
	mm.instance_count = wall_positions.size()

	for i in range(wall_positions.size()):
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, wall_positions[i]))

	mmi.multimesh = mm
