extends NinePatchRect

@onready var select_box = $cursor
@onready var sonido = $sonido

# Señales
signal efecto_sonido(tipo: String)

enum { LUCHA, POKEMON, MOCHILA, HUIDA }
var menu_opcion_seleccionada = LUCHA
var activo = false

## Opciones visibles y seleccionables (plan 20260912: menús reducidos por
## ruleset, p. ej. SIN_EQUIPO usa solo MOCHILA + HUIDA).
var opciones_habilitadas: Array[int] = [LUCHA, POKEMON, MOCHILA, HUIDA]

## Vecinos fijos del menú 2×2: {opcion: {0: abajo, 1: arriba, 2: derecha, 3: izquierda}}.
## Sin envolvente, igual que la navegación original: en los bordes no hay vecino.
const VECINOS := {
	LUCHA: {0: POKEMON, 2: MOCHILA},
	POKEMON: {1: LUCHA, 2: HUIDA},
	MOCHILA: {0: HUIDA, 3: LUCHA},
	HUIDA: {1: MOCHILA, 3: POKEMON},
}

#signal batalla_menu1_seleccionado(opcion: int)

func _ready() -> void:
	self.visible = false
	self.position = Vector2(136,112)
	posicionar_cursor()

func _unhandled_input(event: InputEvent) -> void:
	if activo == true:
		# Verificar si el nodo padre (batalla) quiere ignorar input temporal
		var padre_batalla = get_parent()
		if padre_batalla and padre_batalla.has_method("get_ignorar_input_temporal") and padre_batalla.get_ignorar_input_temporal():
			if Input.is_action_pressed("btn_accion") or Input.is_action_pressed("btn_cancelar"):
				# Sigue sostenida la tecla que originó el bloqueo: ignorarla y
				# esperar a que la suelten para reactivar el menú.
				if event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_cancelar"):
					return  # Ignorar estas teclas específicas
				elif event.is_action_released("btn_accion") or event.is_action_released("btn_cancelar"):
					padre_batalla.call("reset_ignorar_input_temporal")
				return
			# Ya se soltó antes de que este menú estuviera activo (p. ej.
			# durante una animación larga como un cambio de Pokémon): no hay
			# soltado que esperar, así que se reactiva ya y este mismo evento
			# se procesa normal más abajo en vez de perderse.
			padre_batalla.call("reset_ignorar_input_temporal")

		if event.is_action_pressed("btn_abajo"):
			_mover_seleccion(0)
		elif event.is_action_pressed("btn_arriba"):
			_mover_seleccion(1)
		elif event.is_action_pressed("btn_derecha"):
			_mover_seleccion(2)
		elif event.is_action_pressed("btn_izquierda"):
			_mover_seleccion(3)
		elif event.is_action_pressed("btn_accion"):
			sonido.play()
			#activo = false
			#visible = false
			Singleton.emit_signal("batalla_menu1_seleccionado", menu_opcion_seleccionada)
			#batalla_menu1_seleccionado.emit(menu_opcion_seleccionada)

func posicionar_cursor() -> void:
	match menu_opcion_seleccionada:
		LUCHA:
			select_box.position = Vector2(7,7)
		POKEMON:
			select_box.position = Vector2(7,23)
		MOCHILA:
			select_box.position = Vector2(53,7)
		HUIDA:
			select_box.position = Vector2(53,23)

func cambiar_opcion(opcion) -> void:
	menu_opcion_seleccionada = opcion
	posicionar_cursor()
	emit_signal("efecto_sonido", "seleccion")
	sonido.play()

## Devuelve el cursor a LUCHA sin sonido. Se usa tras un cambio de Pokémon: el
## cursor quedaba en POKEMON y lo habitual en el siguiente turno es atacar.
func cursor_a_lucha() -> void:
	if not _opcion_disponible(LUCHA):
		return
	menu_opcion_seleccionada = LUCHA
	posicionar_cursor()

## Plan 20260912: reduce el menú a un subconjunto de opciones. Las opciones
## fuera del conjunto se ocultan y la navegación las salta.
func configurar_opciones(habilitadas: Array, reiniciar_cursor: bool = true) -> void:
	opciones_habilitadas = []
	for opcion in habilitadas:
		var valor := int(opcion)
		if valor >= LUCHA and valor <= HUIDA and not opciones_habilitadas.has(valor):
			opciones_habilitadas.append(valor)
	if opciones_habilitadas.is_empty():
		opciones_habilitadas = [LUCHA, POKEMON, MOCHILA, HUIDA]
	_aplicar_visibilidad_opciones()
	if reiniciar_cursor or not _opcion_disponible(menu_opcion_seleccionada):
		menu_opcion_seleccionada = opciones_habilitadas[0]
	posicionar_cursor()

func restaurar_opciones() -> void:
	# Al volver a INPUT con el menú completo se conserva la selección previa
	# del cursor (comportamiento original del menú antes del plan 20260912).
	configurar_opciones([LUCHA, POKEMON, MOCHILA, HUIDA], false)

func _aplicar_visibilidad_opciones() -> void:
	_mostrar_opcion("lucha", LUCHA)
	_mostrar_opcion("pokemon", POKEMON)
	_mostrar_opcion("mochila", MOCHILA)
	_mostrar_opcion("huida", HUIDA)

func _mostrar_opcion(nombre_nodo: String, opcion: int) -> void:
	var etiqueta := get_node_or_null(NodePath(nombre_nodo)) as Label
	if etiqueta:
		etiqueta.visible = opciones_habilitadas.has(opcion)

func _opcion_disponible(opcion: int) -> bool:
	return opciones_habilitadas.has(opcion)

## Avanza hacia la vecina según `direccion` (0 abajo, 1 arriba, 2 derecha,
## 3 izquierda) saltando opciones deshabilitadas. Con el menú completo el
## comportamiento es idéntico a la navegación fija anterior.
func _mover_seleccion(direccion: int) -> void:
	var destino: int = menu_opcion_seleccionada
	for _i in opciones_habilitadas.size() + 1:
		var vecinos: Dictionary = VECINOS.get(destino, {})
		if not vecinos.has(direccion):
			return
		destino = int(vecinos[direccion])
		if _opcion_disponible(destino):
			cambiar_opcion(destino)
			return
