extends Node2D
class_name DockEquipoController

# ===================================
# CONTROLADOR DE DOCK EQUIPO
# ===================================
# Este script maneja las funcionalidades específicas del dock del equipo Pokémon
# Incluye navegación, animación, estado y input del equipo.

# Referencias locales a nodos hijos de esta instancia
@onready var slot_equipo_0: Node = $slot0
@onready var slot_equipo_1: Node = $slot1
@onready var slot_equipo_2: Node = $slot2
@onready var slot_equipo_3: Node = $slot3
@onready var slot_equipo_4: Node = $slot4
@onready var slot_equipo_5: Node = $slot5

# Arrays para los sprites de iconos creados dinámicamente
var iconos_sprites: Array[Sprite2D] = []

# Variables de configuración para posicionamiento de iconos
var offset_iconos: Vector2 = Vector2(-17, -4)  # Offset de los iconos respecto al slot

# Posiciones de los slots del equipo (relativas al dock)
const POSICION_EQUIPO_SLOT1: Vector2 = Vector2(25, 52)   # Slot principal
const POSICION_EQUIPO_SLOT2: Vector2 = Vector2(73, 4)    # Slots del equipo
const POSICION_EQUIPO_SLOT3: Vector2 = Vector2(73, 28)
const POSICION_EQUIPO_SLOT4: Vector2 = Vector2(73, 52)
const POSICION_EQUIPO_SLOT5: Vector2 = Vector2(73, 76)
const POSICION_EQUIPO_SLOT6: Vector2 = Vector2(73, 100)
const POSICION_EQUIPO_SALIR: Vector2 = Vector2(73, 132)  # Opción "Salir"

# Posiciones de animación del dock
const POSICION_ESCONDIDO: Vector2 = Vector2(80, -160)  # Dock fuera de pantalla
const POSICION_VISIBLE: Vector2 = Vector2(80, 0)       # Dock visible

# Variables de estado
var equipo_visible: bool = false	# Indica si el dock está visible por completo o solo la pestaña con el nombre
var slot_actual: int = 0  # Slot actualmente seleccionado (0-6, donde 6 = "Salir")
var recordar_slot: int = 0  # Slot para recordar para la navegación horizontal
var slots_equipo: Array[Node] = []
var equipo_pokemon_datos: Array[BasePokemon] = []  # Array con los datos de Pokémon del equipo (FUENTE DE VERDAD)
var tween_animacion: Tween = null

# Variables para animación de reorganización
var tween_reorganizacion: Tween = null
var animacion_reorganizacion_activa: bool = false
const DURACION_ANIMACION_REORGANIZACION: float = 0.3

# Señales para comunicación con el controlador principal
signal equipo_abierto()
signal equipo_cerrado()
signal slot_seleccionado(slot_index: int)
signal slot_cambiado(slot_index: int)  # Nueva señal para cuando cambia el slot actual
signal salir_seleccionado()
signal animacion_iniciada()  # Nueva señal para bloquear input
signal animacion_terminada()  # Nueva señal para desbloquear input
# signal saltar_a_grilla()  # Nueva señal para saltar a la grilla

func _ready():
	# Inicializar estado del dock
	_inicializar_dock()

## Inicializa el estado del dock equipo.
func _inicializar_dock() -> void:
	# Configurar posición inicial (escondido)
	position = POSICION_ESCONDIDO
	equipo_visible = false
	
	# Crear array de slots para fácil acceso
	slots_equipo = [slot_equipo_0, slot_equipo_1, slot_equipo_2, slot_equipo_3, slot_equipo_4, slot_equipo_5]
	
	# Crear sprites de iconos dinámicamente
	_crear_sprites_iconos()
	
	print("🏗️ [DOCK EQUIPO] Dock equipo inicializado")

## Crea los sprites de iconos dinámicamente para cada slot del equipo.
func _crear_sprites_iconos() -> void:
	print("🎨 [DOCK EQUIPO] Creando sprites de iconos...")
	
	# Limpiar sprites existentes si los hay
	for sprite in iconos_sprites:
		if sprite and is_instance_valid(sprite):
			sprite.queue_free()
	iconos_sprites.clear()
	
	# Crear un Sprite2D para cada slot del equipo
	for i in range(6):
		var icono_sprite = Sprite2D.new()
		icono_sprite.name = "icono_slot_%d" % i
		
		# Configurar propiedades del sprite
		icono_sprite.centered = false  # Desactivar centrado para mejor control
		icono_sprite.visible = false   # Inicialmente oculto
		
		# Posicionar el icono en el slot correspondiente
		var posicion_slot = _obtener_posicion_slot_relativa(i)
		icono_sprite.position = posicion_slot + offset_iconos
		
		# Agregar al dock y al array
		add_child(icono_sprite)
		iconos_sprites.append(icono_sprite)
		
		print("🎨 [DOCK EQUIPO] ✅ Icono creado para slot %d en posición %s" % [i, icono_sprite.position])
	
	print("✅ [DOCK EQUIPO] %d sprites de iconos creados" % iconos_sprites.size())

## Obtiene la posición relativa de un slot específico del equipo.
func _obtener_posicion_slot_relativa(slot: int) -> Vector2:
	match slot:
		0: return POSICION_EQUIPO_SLOT1
		1: return POSICION_EQUIPO_SLOT2
		2: return POSICION_EQUIPO_SLOT3
		3: return POSICION_EQUIPO_SLOT4
		4: return POSICION_EQUIPO_SLOT5
		5: return POSICION_EQUIPO_SLOT6
		_: return POSICION_EQUIPO_SLOT1

## Abre el equipo Pokémon animando el dock desde abajo.
func abrir_equipo() -> void:
	if equipo_visible:
		return  # Ya está abierto
	
	print("👥 [DOCK EQUIPO] Abriendo equipo Pokémon...")
	
	# Cancelar cualquier tween anterior
	_cancelar_tween_actual()
	
	# Configurar estado inicial
	position = POSICION_ESCONDIDO
	equipo_visible = true
	slot_actual = 0  # Empezar en slot 1
	
	# Animar dock hacia posición visible
	tween_animacion = create_tween()
	tween_animacion.set_ease(Tween.EASE_OUT)
	tween_animacion.set_trans(Tween.TRANS_BACK)
	tween_animacion.tween_property(self, "position", POSICION_VISIBLE, 0.5)
	
	# Emitir señal de apertura
	tween_animacion.tween_callback(_finalizar_apertura)

## Cierra el equipo Pokémon animando el dock hacia abajo.
func cerrar_equipo() -> void:
	if not equipo_visible:
		return  # Ya está cerrado
	
	print("👥 [DOCK EQUIPO] Cerrando equipo Pokémon...")
	
	# Cancelar cualquier tween anterior
	_cancelar_tween_actual()
	
	# Animar dock hacia posición escondida
	tween_animacion = create_tween()
	tween_animacion.set_ease(Tween.EASE_IN)
	tween_animacion.set_trans(Tween.TRANS_BACK)
	tween_animacion.tween_property(self, "position", POSICION_ESCONDIDO, 0.4)
	
	# Al completar la animación, finalizar cierre
	tween_animacion.tween_callback(_finalizar_cierre)

## Maneja la navegación dentro del equipo. Invocado desde el controlador principal.
## `permitir_salir_derecha` en false (modo DEJAR de Ruby) confina el cursor al
## panel: derecha desde los slots 1-6 no hace nada en vez de cerrar el equipo.
func navegar_equipo(direccion: Vector2i, permitir_salir_derecha: bool = true) -> bool:
	if not equipo_visible:
		return false
	
	var nuevo_slot = slot_actual
	
	# Navegación vertical dentro del equipo
	if direccion.y != 0:
		nuevo_slot += direccion.y
		
		# Validar límites (0-6, donde 6 = "Salir")
		if nuevo_slot < 0:
			nuevo_slot = 6  # Ir a "Salir"
		elif nuevo_slot > 6:
			nuevo_slot = 0  # Volver al primer slot
		recordar_slot = nuevo_slot  # Actualizar slot a recordar
	
	# Navegación horizontal (solo válida en ciertos casos)
	elif direccion.x != 0:
		if direccion.x < 0:  # Izquierda
			if slot_actual > 0:
				recordar_slot = slot_actual # Recordar el slot actual
				nuevo_slot = 0
		elif direccion.x > 0:  # Derecha
			if slot_actual == 0:
				if recordar_slot == 0:
					recordar_slot = 1
				nuevo_slot = recordar_slot  # Volver al slot recordado
			elif not permitir_salir_derecha:
				return true
			else:
				# Saltar a la grilla y cerrar equipo
				# saltar_a_grilla.emit()
				cerrar_equipo()
				return true
	
	# Actualizar slot actual si cambió
	if nuevo_slot != slot_actual:
		slot_actual = nuevo_slot
		_actualizar_seleccion_visual()
		
		# Emitir señal para notificar el cambio de slot
		slot_cambiado.emit(slot_actual)
		
		print("👥 [DOCK EQUIPO] Navegando a slot %d" % slot_actual)
	
	return true

## Maneja la confirmación de selección en el equipo.
func confirmar_seleccion() -> void:
	if not equipo_visible:
		return
	
	if slot_actual == 6:  # "Salir"
		salir_seleccionado.emit()
		cerrar_equipo()
	else:
		# Seleccionar slot del equipo
		slot_seleccionado.emit(slot_actual)
		print("👥 [DOCK EQUIPO] Slot %d seleccionado" % slot_actual)

## Obtiene la posición del cursor para el slot actual.
func obtener_posicion_cursor() -> Vector2:
	match slot_actual:
		0: return global_position + POSICION_EQUIPO_SLOT1
		1: return global_position + POSICION_EQUIPO_SLOT2
		2: return global_position + POSICION_EQUIPO_SLOT3
		3: return global_position + POSICION_EQUIPO_SLOT4
		4: return global_position + POSICION_EQUIPO_SLOT5
		5: return global_position + POSICION_EQUIPO_SLOT6
		6: return global_position + POSICION_EQUIPO_SALIR
		_: return global_position + POSICION_EQUIPO_SLOT1

## Obtiene la posición de un slot específico del equipo.
func obtener_posicion_slot(slot: int) -> Vector2:
	match slot:
		0: return global_position + POSICION_EQUIPO_SLOT1
		1: return global_position + POSICION_EQUIPO_SLOT2
		2: return global_position + POSICION_EQUIPO_SLOT3
		3: return global_position + POSICION_EQUIPO_SLOT4
		4: return global_position + POSICION_EQUIPO_SLOT5
		5: return global_position + POSICION_EQUIPO_SLOT6
		6: return global_position + POSICION_EQUIPO_SALIR
		_: return global_position + POSICION_EQUIPO_SLOT1

## Obtiene el slot actualmente seleccionado.
func obtener_slot_actual() -> int:
	return slot_actual

## Configura el slot actualmente seleccionado.
func configurar_slot_actual(nuevo_slot: int) -> void:
	if nuevo_slot >= 0 and nuevo_slot <= 6:
		var slot_anterior = slot_actual
		slot_actual = nuevo_slot
		_actualizar_seleccion_visual()
		
		# Emitir señal solo si realmente cambió el slot
		if slot_anterior != slot_actual:
			slot_cambiado.emit(slot_actual)

## Verifica si el equipo está visible.
func esta_visible() -> bool:
	return equipo_visible

## Obtiene referencia a un slot específico del equipo.
func obtener_slot_equipo(indice: int) -> Node:
	if indice >= 0 and indice < slots_equipo.size():
		return slots_equipo[indice]
	return null

## Obtiene todos los slots del equipo.
func obtener_todos_los_slots() -> Array[Node]:
	return slots_equipo

## Obtiene el sprite del icono del Pokémon en el slot actual.
func obtener_icono_pokemon_actual() -> Sprite2D:
	if slot_actual >= 0 and slot_actual < iconos_sprites.size():
		return iconos_sprites[slot_actual]
	return null

## Configura el offset de posición para los iconos de los Pokémon.
func configurar_offset_iconos(nuevo_offset: Vector2) -> void:
	offset_iconos = nuevo_offset
	
	# Actualizar posiciones de los iconos existentes
	for i in range(iconos_sprites.size()):
		var icono_sprite = iconos_sprites[i]
		if icono_sprite:
			var posicion_slot = _obtener_posicion_slot_relativa(i)
			icono_sprite.position = posicion_slot + offset_iconos
	
	print("🎨 [DOCK EQUIPO] Offset de iconos actualizado a: %s" % nuevo_offset)

## Actualiza la selección visual del slot actual.
func _actualizar_seleccion_visual() -> void:
	# Esta función puede ser extendida para manejar efectos visuales
	# como resaltar el slot seleccionado
	print("🎯 [DOCK EQUIPO] Actualizando selección visual: slot %d" % slot_actual)

## Cancela el tween actual si existe.
func _cancelar_tween_actual() -> void:
	if tween_animacion and tween_animacion.is_valid():
		tween_animacion.kill()
		tween_animacion = null

## Finaliza la apertura del equipo.
func _finalizar_apertura() -> void:
	print("✅ [DOCK EQUIPO] Equipo abierto completamente")
	equipo_abierto.emit()

## Finaliza el cierre del equipo.
func _finalizar_cierre() -> void:
	equipo_visible = false
	slot_actual = 0
	
	# NO limpiar datos del equipo - deben persistir cuando se cierra el dock
	# Los datos solo se limpian en limpiar_equipo() cuando es explícitamente requerido
	print("📦 [DOCK EQUIPO] Datos del equipo conservados: %d Pokémon" % equipo_pokemon_datos.size())
	
	print("✅ [DOCK EQUIPO] Equipo cerrado completamente")
	equipo_cerrado.emit()

## Carga y muestra el Pokémon del equipo en los slots.
func cargar_equipo_pokemon(equipo_pokemon: Array[BasePokemon]) -> void:
	print("👥 [DOCK EQUIPO] Cargando equipo Pokémon (%d Pokémon)" % equipo_pokemon.size())
	equipo_pokemon_datos = equipo_pokemon.duplicate()
	
	# Limpiar slots existentes
	for i in range(slots_equipo.size()):
		var slot = slots_equipo[i]
		if slot and slot.has_method("limpiar_slot"):
			slot.limpiar_slot()
	
	# Cargar Pokémon en slots
	for i in range(min(equipo_pokemon.size(), slots_equipo.size())):
		var pokemon: BasePokemon = equipo_pokemon[i]
		var slot = slots_equipo[i]
		
		if pokemon and slot and slot.has_method("asignar_pokemon"):
			slot.asignar_pokemon(pokemon)
			print("👥 [DOCK EQUIPO] ✅ Slot %d: %s Nv.%d cargado" % [i, pokemon.nombre_interno, pokemon.nivel])

## Obtiene el Pokémon en un slot específico del equipo.
func obtener_pokemon_en_slot(slot_index: int) -> BasePokemon:
	# Primero intentar obtener desde los datos guardados
	if slot_index >= 0 and slot_index < equipo_pokemon_datos.size():
		return equipo_pokemon_datos[slot_index]
	
	# Fallback: intentar obtener desde el slot de la escena (legacy)
	var slot = obtener_slot_equipo(slot_index)
	if slot and slot.has_method("obtener_pokemon"):
		return slot.obtener_pokemon()
	
	return null

## Obtiene el Pokémon del slot actualmente seleccionado.
func obtener_pokemon_actual() -> BasePokemon:
	# Solo devolver Pokémon si no estamos en el slot "Salir"
	if slot_actual >= 0 and slot_actual < 6:
		# Usar los datos guardados directamente
		if slot_actual < equipo_pokemon_datos.size():
			var pokemon = equipo_pokemon_datos[slot_actual]
			print("🔍 [DOCK EQUIPO] obtener_pokemon_actual(%d): %s" % [slot_actual, "null" if not pokemon else pokemon.nombre_interno])
			return pokemon
		else:
			print("🔍 [DOCK EQUIPO] obtener_pokemon_actual(%d): fuera de rango (%d)" % [slot_actual, equipo_pokemon_datos.size()])
	else:
		print("🔍 [DOCK EQUIPO] obtener_pokemon_actual(%d): slot 'Salir' o inválido" % slot_actual)
	return null

## Método de limpieza al destruir el dock.
func limpiar() -> void:
	print("🧹 [DOCK EQUIPO] Limpiando dock equipo")
	
	# Cancelar animaciones
	_cancelar_tween_actual()
	
	# Limpiar datos del equipo
	equipo_pokemon_datos.clear()
	
	# Limpiar sprites de iconos
	for sprite in iconos_sprites:
		if sprite and is_instance_valid(sprite):
			sprite.queue_free()
	iconos_sprites.clear()
	
	# Limpiar slots
	for slot in slots_equipo:
		if slot and slot.has_method("limpiar_slot"):
			slot.limpiar_slot()
	
	slots_equipo.clear()

## Maneja el input específico del dock equipo.
# func manejar_input(event: InputEvent) -> bool:
# 	if not equipo_visible:
# 		return false
	
# 	# Solo manejar eventos de teclado
# 	if not event is InputEventKey:
# 		return false
	
# 	var key_event = event as InputEventKey
# 	if not key_event.pressed:
# 		return false
	
# 	# Mapear teclas a direcciones
# 	var direccion = Vector2i.ZERO
	
# 	match key_event.keycode:
# 		KEY_UP, KEY_W:
# 			direccion.y = -1
# 		KEY_DOWN, KEY_S:
# 			direccion.y = 1
# 		KEY_LEFT, KEY_A:
# 			direccion.x = -1
# 		KEY_RIGHT, KEY_D:
# 			direccion.x = 1
# 		KEY_ENTER, KEY_SPACE:
# 			confirmar_seleccion()
# 			return true
# 		KEY_ESCAPE, KEY_X:
# 			cerrar_equipo()
# 			return true
# 		_:
# 			return false
	
# 	# Manejar navegación
# 	if direccion != Vector2i.ZERO:
# 		return navegar_equipo(direccion)
	
# 	return false

## Obtiene las referencias a los slots del equipo.
func _obtener_referencias_slots() -> void:
	slots_equipo.clear()
	slots_equipo = [
		get_node("slot0"),
		get_node("slot1"),
		get_node("slot2"),
		get_node("slot3"),
		get_node("slot4"),
		get_node("slot5")
	]
	print("👥 [EQUIPO CONTROLLER] Referencias de slots obtenidas: %d slots" % slots_equipo.size())

## Actualiza la visualización de los slots del equipo con los datos de Pokemon.
func actualizar_slots(equipo_pokemon: Array[BasePokemon]) -> void:
	print("👥 [EQUIPO CONTROLLER] === ACTUALIZANDO SLOTS ===")
	
	# Guardar los datos del equipo para acceso posterior
	# equipo_pokemon_datos = equipo_pokemon.duplicate()
	print("👥 [EQUIPO CONTROLLER] Datos del equipo guardados: %d Pokémon" % equipo_pokemon_datos.size())
	
	# Obtener referencias a slots si no están cargadas
	if slots_equipo.is_empty():
		_obtener_referencias_slots()
	
	# Actualizar cada slot
	for i in range(6):
		var slot = slots_equipo[i] if i < slots_equipo.size() else null
		var pokemon: BasePokemon = equipo_pokemon[i] if i < equipo_pokemon.size() else null
		
		if slot:
			if pokemon:
				# Mostrar slot con Pokémon
				slot.visible = true
				_cargar_icono_slot(i, pokemon)  # Usar índice en lugar del sprite
				print("👥 [EQUIPO CONTROLLER] ✅ Slot %d: %s Nv.%d" % [i, pokemon.nombre_interno, pokemon.nivel])
			else:
				# Ocultar slot vacío y su icono
				slot.visible = false
				_ocultar_icono_slot(i)
				print("👥 [EQUIPO CONTROLLER] ⭕ Slot %d: vacío" % i)
		else:
			print("⚠️ [EQUIPO CONTROLLER] ❌ Slot %d no encontrado" % i)
	
	print("👥 [EQUIPO CONTROLLER] === FIN ACTUALIZACIÓN ===")

## Carga el icono de un Pokémon en un slot específico.
func _cargar_icono_slot(slot_index: int, pokemon: BasePokemon) -> void:
	if slot_index < 0 or slot_index >= iconos_sprites.size():
		print("⚠️ [EQUIPO CONTROLLER] Índice de slot inválido: %d" % slot_index)
		return
	
	var icono_sprite = iconos_sprites[slot_index]
	if not icono_sprite or not pokemon:
		return
	
	# Intentar cargar el icono del Pokémon
	var numero_formateado = "%03d" % pokemon.numero_nacional if pokemon.numero_nacional > 0 else pokemon.nombre_interno
	var ruta_icono = "res://graficos/Icons/icon%s.png" % numero_formateado
	
	# Verificar si el archivo existe
	if ResourceLoader.exists(ruta_icono):
		var icono = load(ruta_icono)
		icono_sprite.texture = icono
		# Configurar región para mostrar solo el primer frame (32x32 desde posición 0,0)
		icono_sprite.region_enabled = true
		icono_sprite.region_rect = Rect2(0, 0, 32, 32)
		icono_sprite.visible = true
		print("🎯 [EQUIPO CONTROLLER] Icono cargado: %s" % ruta_icono)
	else:
		# Usar número nacional directamente
		var ruta_alternativa = "res://graficos/Icons/icon%d.png" % pokemon.numero_nacional
		if ResourceLoader.exists(ruta_alternativa):
			var icono = load(ruta_alternativa)
			icono_sprite.texture = icono
			# Configurar región para mostrar solo el primer frame (32x32 desde posición 0,0)
			icono_sprite.region_enabled = true
			icono_sprite.region_rect = Rect2(0, 0, 32, 32)
			icono_sprite.visible = true
			print("🎯 [EQUIPO CONTROLLER] Icono alternativo: %s" % ruta_alternativa)
		else:
			icono_sprite.visible = false
			print("⚠️ [EQUIPO CONTROLLER] No se encontró icono para %s" % pokemon.nombre_interno)

## Oculta el icono de un slot específico.
func _ocultar_icono_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= iconos_sprites.size():
		return
	
	var icono_sprite = iconos_sprites[slot_index]
	if icono_sprite:
		icono_sprite.visible = false
		icono_sprite.texture = null  # Limpiar textura

# ===================================
# MÉTODOS PARA ANIMACIÓN DE REORGANIZACIÓN
# ===================================

## Obtiene el array de sprites de iconos para animaciones externas.
func obtener_iconos_sprites() -> Array[Sprite2D]:
	return iconos_sprites

## Obtiene la posición relativa de un slot específico (método público).
func obtener_posicion_slot_relativa(slot_index: int) -> Vector2:
	return _obtener_posicion_slot_relativa(slot_index)

# ===================================
# GESTIÓN CENTRALIZADA DEL EQUIPO (FUENTE DE VERDAD)
# ===================================

## Obtiene el array completo del equipo (solo lectura).
# func obtener_equipo() -> Array:
# 	return equipo_pokemon_datos.duplicate()

## Coloca un Pokémon en un slot VACÍO del equipo (con animación y compactación
## automática: si el slot queda detrás del último Pokémon, el icono se desliza
## hasta el primer hueco). Devuelve false sin tocar nada si el slot no es
## válido o ya está ocupado (para intercambiar usar intercambiar_pokemon_en_slot).
func colocar_pokemon_en_slot(slot_index: int, pokemon: BasePokemon) -> bool:
	if slot_index < 0 or slot_index >= 6 or pokemon == null:
		print("⚠️ [DOCK EQUIPO] Índice de slot inválido: %d" % slot_index)
		return false

	# Asegurar que el array tenga 6 elementos
	while equipo_pokemon_datos.size() < 6:
		equipo_pokemon_datos.append(null)

	if equipo_pokemon_datos[slot_index] != null:
		print("⚠️ [DOCK EQUIPO] Slot %d ocupado: no se sobrescribe" % slot_index)
		return false

	# Colocar el Pokémon en el slot solicitado inicialmente
	equipo_pokemon_datos[slot_index] = pokemon
	# Mostrar su icono en ese slot para que la compactación lo deslice.
	_restablecer_posiciones_sprites()
	_cargar_icono_slot(slot_index, pokemon)

	var equipo_anterior = equipo_pokemon_datos.duplicate()
	
	# Realizar compactación automática (mover nulos al final)
	var equipo_compactado = _compactar_equipo_pokemon(equipo_pokemon_datos)
	
	print("✅ [DOCK EQUIPO] Pokémon colocado y compactado: %s" % [pokemon.get_nombre_mostrar() if pokemon else "null"])
	print("🔄 [DOCK EQUIPO] Compactación: %s → %s" % [_debug_equipo_string(equipo_pokemon_datos), _debug_equipo_string(equipo_compactado)])
	
	# Actualizar con el equipo compactado
	equipo_pokemon_datos = equipo_compactado
	
	# Animar la reorganización con compactación
	_animar_reorganizacion_equipo(equipo_anterior, equipo_pokemon_datos)
	return true

## CAMBIO de Ruby: pone `pokemon` en un slot OCUPADO y devuelve el que había,
## sin compactar. Devuelve null sin tocar nada si el slot no es válido o está
## vacío (entonces corresponde colocar_pokemon_en_slot).
func intercambiar_pokemon_en_slot(slot_index: int, pokemon: BasePokemon) -> BasePokemon:
	if slot_index < 0 or slot_index >= 6 or pokemon == null:
		return null
	while equipo_pokemon_datos.size() < 6:
		equipo_pokemon_datos.append(null)
	var anterior: BasePokemon = equipo_pokemon_datos[slot_index]
	if anterior == null:
		return null
	equipo_pokemon_datos[slot_index] = pokemon
	_restablecer_posiciones_sprites()
	actualizar_slots(equipo_pokemon_datos)
	return anterior

## Remueve un Pokémon del equipo con reorganización automática y compactación.
func remover_pokemon_de_slot(slot_index: int) -> BasePokemon:
	if slot_index < 0 or slot_index >= equipo_pokemon_datos.size():
		print("⚠️ [DOCK EQUIPO] Índice de slot inválido: %d" % slot_index)
		return null
	
	var pokemon_removido: BasePokemon = equipo_pokemon_datos[slot_index]
	if not pokemon_removido:
		print("ℹ️ [DOCK EQUIPO] No hay Pokémon en slot %d para remover" % slot_index)
		return null
	
	# Capturar estado anterior
	var equipo_anterior = equipo_pokemon_datos.duplicate()
	
	# Remover el Pokémon
	equipo_pokemon_datos[slot_index] = null
	iconos_sprites[slot_index].visible = false  # Ocultar icono inmediatamente
	
	# Realizar compactación automática
	var equipo_compactado = _compactar_equipo_pokemon(equipo_pokemon_datos)
	
	print("🗑️ [DOCK EQUIPO] Removiendo %s del slot %d" % [pokemon_removido.get_nombre_mostrar(), slot_index])
	print("🔄 [DOCK EQUIPO] Compactación tras remoción: %s → %s" % [_debug_equipo_string(equipo_pokemon_datos), _debug_equipo_string(equipo_compactado)])
	
	# Actualizar con el equipo compactado
	equipo_pokemon_datos = equipo_compactado
	
	# Animar la reorganización con compactación
	_animar_reorganizacion_equipo(equipo_anterior, equipo_pokemon_datos)
	
	return pokemon_removido

## Inserta un Pokémon en una posición específica, empujando otros hacia abajo.
func insertar_pokemon_en_posicion(slot_index: int, pokemon: BasePokemon) -> void:
	if slot_index < 0 or slot_index >= 6:
		print("⚠️ [DOCK EQUIPO] Índice de slot inválido: %d" % slot_index)
		return
	
	# Capturar estado anterior
	var equipo_anterior = equipo_pokemon_datos.duplicate()
	
	# Asegurar que el array tenga 6 elementos
	while equipo_pokemon_datos.size() < 6:
		equipo_pokemon_datos.append(null)
	
	# Mover Pokémon hacia abajo desde la posición de inserción
	for i in range(equipo_pokemon_datos.size() - 1, slot_index, -1):
		equipo_pokemon_datos[i] = equipo_pokemon_datos[i - 1]
	
	# Insertar el nuevo Pokémon
	equipo_pokemon_datos[slot_index] = pokemon
	
	print("📥 [DOCK EQUIPO] %s insertado en slot %d" % [pokemon.get_nombre_mostrar(), slot_index])
	
	# Animar la reorganización
	_animar_reorganizacion_equipo(equipo_anterior, equipo_pokemon_datos)

## Actualiza los slots visuales desde los datos internos del controlador.
func actualizar_slots_desde_controlador() -> void:
	print("👥 [CONTROLADOR] === ACTUALIZANDO SLOTS DESDE DATOS INTERNOS ===")
	
	# DEBUG: Verificar contenido del equipo interno
	print("🔍 [DEBUG] Equipo interno tiene %d Pokémon:" % equipo_pokemon_datos.size())
	for i in range(equipo_pokemon_datos.size()):
		if equipo_pokemon_datos[i]:
			print("🔍 [DEBUG]   Slot %d: %s Nv.%d" % [i, equipo_pokemon_datos[i].nombre_interno, equipo_pokemon_datos[i].nivel])
		else:
			print("🔍 [DEBUG]   Slot %d: (vacío)" % i)
	
	# Actualizar slots con datos internos
	actualizar_slots(equipo_pokemon_datos)
	
	print("👥 [CONTROLADOR] === FIN ACTUALIZACIÓN SLOTS ===")

## Limpia completamente el equipo.
func limpiar_equipo() -> void:
	print("🧹 [CONTROLADOR] Limpiando equipo completo")
	
	equipo_pokemon_datos.clear()
	equipo_pokemon_datos.resize(6)  # 6 slots vacíos
	
	# Limpiar slots visuales
	for slot in slots_equipo:
		if slot and slot.has_method("limpiar_slot"):
			slot.limpiar_slot()
	
	print("🧹 [CONTROLADOR] Equipo limpiado - %d slots vacíos" % equipo_pokemon_datos.size())

## Obtiene una copia completa del array del equipo.
func obtener_equipo_completo() -> Array:
	return equipo_pokemon_datos.duplicate()

# ===================================
# SISTEMA DE ANIMACIÓN DE REORGANIZACIÓN
# ===================================

## Anima la reorganización general del equipo.
func _animar_reorganizacion_equipo(equipo_anterior: Array, equipo_nuevo: Array) -> void:
	if animacion_reorganizacion_activa:
		print("⚠️ [DOCK EQUIPO] Animación en progreso, completando reorganización directamente")
		# El tween anterior ya no debe terminar con sus datos (quedaron obsoletos).
		if tween_reorganizacion and tween_reorganizacion.is_valid():
			tween_reorganizacion.kill()
		_finalizar_reorganizacion(equipo_nuevo)
		return

	print("🎬 [DOCK EQUIPO] Iniciando animación de reorganización")
	
	# Calcular movimientos necesarios
	var movimientos = _calcular_movimientos_reorganizacion(equipo_anterior, equipo_nuevo)
	
	if movimientos.is_empty():
		print("ℹ️ [DOCK EQUIPO] No hay movimientos necesarios, actualizando directamente")
		_finalizar_reorganizacion(equipo_nuevo)
		return
	
	# Iniciar animación
	animacion_reorganizacion_activa = true
	animacion_iniciada.emit()  # Bloquear input en el controlador principal
	
	# Crear tween
	if tween_reorganizacion:
		tween_reorganizacion.kill()
	tween_reorganizacion = create_tween()
	tween_reorganizacion.set_parallel(true)
	
	# Animar movimientos
	for movimiento in movimientos:
		print("🎯 [DOCK EQUIPO] Animando %s: slot %d → slot %d" % [movimiento.pokemon.get_nombre_mostrar(), movimiento.slot_origen, movimiento.slot_destino])
		tween_reorganizacion.tween_property(movimiento.sprite, "position", movimiento.posicion_destino, DURACION_ANIMACION_REORGANIZACION)
	
	# Callback al terminar
	tween_reorganizacion.finished.connect(_on_reorganizacion_terminada.bind(equipo_nuevo), CONNECT_ONE_SHOT)

## Anima específicamente la reorganización cuando se remueve un Pokémon.
func _animar_reorganizacion_por_remocion(equipo_anterior: Array, slot_removido: int) -> void:
	if animacion_reorganizacion_activa:
		print("⚠️ [DOCK EQUIPO] Animación en progreso, completando remoción directamente")
		_finalizar_reorganizacion_remocion(slot_removido)
		return
	
	print("🎬 [DOCK EQUIPO] Iniciando animación de reorganización por remoción (slot %d)" % slot_removido)
	
	# Calcular movimientos por remoción
	var movimientos = _calcular_movimientos_remocion(equipo_anterior, slot_removido)
	
	if movimientos.is_empty():
		print("ℹ️ [DOCK EQUIPO] No hay Pokémon para mover después del slot removido")
		_finalizar_reorganizacion_remocion(slot_removido)
		return
	
	# Iniciar animación
	animacion_reorganizacion_activa = true
	animacion_iniciada.emit()  # Bloquear input en el controlador principal
	
	# Crear tween
	if tween_reorganizacion:
		tween_reorganizacion.kill()
	tween_reorganizacion = create_tween()
	tween_reorganizacion.set_parallel(true)
	
	# Animar movimientos hacia arriba
	for movimiento in movimientos:
		print("🎯 [DOCK EQUIPO] Moviendo hacia arriba %s: slot %d → slot %d" % [movimiento.pokemon.get_nombre_mostrar(), movimiento.slot_origen, movimiento.slot_destino])
		tween_reorganizacion.tween_property(movimiento.sprite, "position", movimiento.posicion_destino, DURACION_ANIMACION_REORGANIZACION)
	
	# Callback al terminar
	tween_reorganizacion.finished.connect(_on_reorganizacion_remocion_terminada.bind(slot_removido), CONNECT_ONE_SHOT)

## Calcula los movimientos necesarios para reorganización general.
func _calcular_movimientos_reorganizacion(equipo_anterior: Array, equipo_nuevo: Array) -> Array:
	var movimientos = []
	
	# Comparar posiciones para detectar Pokémon que se movieron
	for slot_nuevo in range(equipo_nuevo.size()):
		var pokemon_nuevo = equipo_nuevo[slot_nuevo] if slot_nuevo < equipo_nuevo.size() else null
		
		if pokemon_nuevo != null:
			# Buscar dónde estaba este Pokémon en el equipo anterior
			var slot_anterior = _encontrar_pokemon_en_equipo(pokemon_nuevo, equipo_anterior)
			
			if slot_anterior != -1 and slot_anterior != slot_nuevo:
				var icono_sprite = iconos_sprites[slot_anterior] if slot_anterior < iconos_sprites.size() else null
				if icono_sprite and icono_sprite.visible:
					var posicion_destino = _obtener_posicion_slot_relativa(slot_nuevo) + offset_iconos
					movimientos.append({
						"sprite": icono_sprite,
						"posicion_destino": posicion_destino,
						"slot_origen": slot_anterior,
						"slot_destino": slot_nuevo,
						"pokemon": pokemon_nuevo
					})
	
	return movimientos

## Calcula los movimientos necesarios para reorganización por remoción.
func _calcular_movimientos_remocion(equipo_anterior: Array, slot_removido: int) -> Array:
	var movimientos = []
	
	# Buscar Pokémon que están después del slot removido
	for slot_origen in range(slot_removido + 1, equipo_anterior.size()):
		var pokemon_en_slot = equipo_anterior[slot_origen]
		
		if pokemon_en_slot != null:
			var slot_destino = slot_origen - 1  # Mover hacia arriba
			var icono_sprite = iconos_sprites[slot_origen] if slot_origen < iconos_sprites.size() else null
			
			if icono_sprite and icono_sprite.visible:
				var posicion_destino = _obtener_posicion_slot_relativa(slot_destino) + offset_iconos
				movimientos.append({
					"sprite": icono_sprite,
					"posicion_destino": posicion_destino,
					"slot_origen": slot_origen,
					"slot_destino": slot_destino,
					"pokemon": pokemon_en_slot
				})
	
	return movimientos

## Busca la posición de un Pokémon específico en un equipo.
func _encontrar_pokemon_en_equipo(pokemon: BasePokemon, equipo: Array) -> int:
	for i in range(equipo.size()):
		if equipo[i] == pokemon:
			return i
	return -1

## Callback cuando termina la animación de reorganización general.
func _on_reorganizacion_terminada(_equipo_nuevo: Array) -> void:
	print("✅ [DOCK EQUIPO] Animación de reorganización terminada")
	# Los datos ya se actualizaron al iniciar la animación: usar los vigentes.
	_finalizar_reorganizacion(equipo_pokemon_datos)

## Callback cuando termina la animación de reorganización por remoción.
func _on_reorganizacion_remocion_terminada(slot_removido: int) -> void:
	print("✅ [DOCK EQUIPO] Animación de remoción terminada")
	_finalizar_reorganizacion_remocion(slot_removido)

## Finaliza la reorganización actualizando los datos.
func _finalizar_reorganizacion(equipo_nuevo: Array) -> void:
	equipo_pokemon_datos = equipo_nuevo.duplicate()
	
	# Restablecer posiciones de sprites después de la animación
	_restablecer_posiciones_sprites()
	
	actualizar_slots(equipo_pokemon_datos)
	_completar_animacion()

## Finaliza la reorganización por remoción.
func _finalizar_reorganizacion_remocion(slot_removido: int) -> void:
	# Hacer la reorganización real del array
	for i in range(slot_removido, equipo_pokemon_datos.size() - 1):
		equipo_pokemon_datos[i] = equipo_pokemon_datos[i + 1]
	
	# El último slot queda vacío
	equipo_pokemon_datos[equipo_pokemon_datos.size() - 1] = null
	
	# Restablecer posiciones de sprites después de la animación
	_restablecer_posiciones_sprites()
	
	actualizar_slots(equipo_pokemon_datos)
	_completar_animacion()

## Completa cualquier animación y desbloquea input.
func _completar_animacion() -> void:
	animacion_reorganizacion_activa = false
	animacion_terminada.emit()  # Desbloquear input en el controlador principal
	print("🎬 [DOCK EQUIPO] Animación completada - input desbloqueado")

## Restablece las posiciones de los sprites de iconos a sus slots correctos.
func _restablecer_posiciones_sprites() -> void:
	print("🔄 [DOCK EQUIPO] Restableciendo posiciones de sprites...")
	
	for i in range(iconos_sprites.size()):
		var icono_sprite = iconos_sprites[i]
		if icono_sprite and is_instance_valid(icono_sprite):
			# Calcular la posición correcta para este slot
			var posicion_correcta = _obtener_posicion_slot_relativa(i) + offset_iconos
			icono_sprite.position = posicion_correcta
			print("🔄 [DOCK EQUIPO] Sprite slot %d reestablecido a posición %s" % [i, posicion_correcta])
	
	print("✅ [DOCK EQUIPO] Posiciones de sprites restablecidas")

# ===================================
# FUNCIONES DE COMPACTACIÓN AUTOMÁTICA
# ===================================

## Compacta un array de Pokémon moviendo todos los nulos al final.
func _compactar_equipo_pokemon(equipo: Array[BasePokemon]) -> Array[BasePokemon]:
	var equipo_compactado: Array[BasePokemon] = []
	var nulos_count = 0
	
	# Primero agregar todos los Pokémon no nulos
	for pokemon in equipo:
		if pokemon != null:
			equipo_compactado.append(pokemon)
		else:
			nulos_count += 1
	
	# Luego agregar los nulos al final
	for i in range(nulos_count):
		equipo_compactado.append(null)
	
	# Asegurar que siempre tengamos exactamente 6 slots
	while equipo_compactado.size() < 6:
		equipo_compactado.append(null)
	
	# Truncar si hay más de 6 (no debería pasar, pero por seguridad)
	if equipo_compactado.size() > 6:
		equipo_compactado = equipo_compactado.slice(0, 6)
	
	return equipo_compactado

## Genera una representación en string del equipo para debug.
func _debug_equipo_string(equipo: Array) -> String:
	var debug_items = []
	for i in range(equipo.size()):
		if equipo[i] != null:
			debug_items.append("%d:%s" % [i, equipo[i].nombre_interno])
		else:
			debug_items.append("%d:null" % i)
	return "[%s]" % ",".join(debug_items)

## Encuentra el primer slot disponible (null) en el equipo.
func encontrar_primer_slot_disponible() -> int:
	for i in range(min(6, equipo_pokemon_datos.size())):
		if equipo_pokemon_datos[i] == null:
			return i
	return -1  # No hay slots disponibles

## Cuenta cuántos Pokémon hay en el equipo (slots no nulos).
func contar_pokemon_en_equipo() -> int:
	var count = 0
	for pokemon in equipo_pokemon_datos:
		if pokemon != null:
			count += 1
	return count
