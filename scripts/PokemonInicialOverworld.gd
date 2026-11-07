## PokemonInicialOverworld.gd
## Activador para la escena de selección de pokémon inicial
## Basado en ItemOverworld pero adaptado para cambio de escena
@tool
extends Node2D

# Constantes para posicionamiento
const TILE_SIZE = 16
const OFFSET = Vector2(0, 0)
## Origen LABORATORIO de SistemaGuardado.agregar_pokemon_al_equipo (felicidad 70).
const ORIGEN_LABORATORIO: int = 5

var scn_pantalla_seleccion = preload("res://escenas/inicial/inicial.tscn")

# Configuración del activador

## Capa de datos donde aplicar: -1 todas, >=0 solo capa especificada
@export var capa_datos: int = -1
@export var id_activador: String = ""  ## ID único para la bandera de activación
@export var pokemon_inicial_1: String = ""  ## Nombre interno del primer pokémon
@export var pokemon_inicial_2: String = ""  ## Nombre interno del segundo pokémon
@export var pokemon_inicial_3: String = ""  ## Nombre interno del tercer pokémon
@export var usar_una_sola_vez: bool = true  ## Si solo se puede usar una vez
var coord_celda: Vector2i = Vector2i.ZERO
@export var coord: Vector2i = Vector2i.ZERO:  ## Coordenada en tiles
	set(value):
		coord = value
		coord_celda = value
		if is_inside_tree():
			position = Vector2(value.x * TILE_SIZE + OFFSET.x, value.y * TILE_SIZE + OFFSET.y)
			update_configuration_warnings()

## Estado de proceso para evitar llamadas múltiples
var proceso_activo: bool = false

var nodo_administrador: Node2D = null
var nodo_jugador: Node2D = null

# Ajustar la posición a la coordenada más cercana en la cuadrícula de tiles
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		coord = Vector2i(round((position.x - OFFSET.x) / TILE_SIZE), round((position.y - OFFSET.y) / TILE_SIZE))
		position = Vector2(coord.x * TILE_SIZE + OFFSET.x, coord.y * TILE_SIZE + OFFSET.y)

func _ready():
	## Habilitar notificaciones de transformación en el editor
	if Engine.is_editor_hint():
		set_notify_transform(true)
	else:
		# En tiempo de ejecución, obtener el AdministradorMapa de forma segura
		nodo_administrador = null
		if get_tree().root and get_tree().root.has_node("AdministradorMapa"):
			nodo_administrador = get_tree().root.get_node("AdministradorMapa")
			if nodo_administrador:
				nodo_jugador = nodo_administrador.jugador
			else:
				nodo_jugador = null
		else:
			nodo_jugador = null

	## Agregar al grupo NPC para que sea detectable por el sistema de interacción
	add_to_group("NPC")

	## Verificar si ya fue usado (solo si está configurado para una sola vez)
	if not Engine.is_editor_hint() and usar_una_sola_vez and id_activador != "" and _get_bandera(id_activador):
		visible = false
		print("🎯 [PokemonInicialOverworld] Activador ya usado, ocultando")

	## Logging para desarrollador
	if Engine.is_editor_hint():
		print("🎯 [PokemonInicialOverworld] Configurado: ", id_activador)
		print("🎯 Pokémon disponibles: ", [pokemon_inicial_1, pokemon_inicial_2, pokemon_inicial_3])

	## Validar configuración de pokémon al inicio
	_validar_configuracion_pokemon()

## Función llamada por el sistema de interacción
func evento_accion() -> void:
	print("🎯 [PokemonInicialOverworld] Iniciando proceso de selección inicial")

	## Verificar si el proceso ya está activo
	if proceso_activo:
		print("⚠️ [PokemonInicialOverworld] Proceso ya en ejecución, ignorando llamada")
		return

	## Marcar proceso como activo
	proceso_activo = true

	## Verificar si ya fue usado
	if usar_una_sola_vez and id_activador != "" and _get_bandera(id_activador):
		print("⚠️ [PokemonInicialOverworld] Ya fue usado previamente")
		proceso_activo = false  # Liberar bandera
		return

	## Verificar que tengamos al menos un pokémon configurado
	if pokemon_inicial_1 == "" and pokemon_inicial_2 == "" and pokemon_inicial_3 == "":
		print("❌ [PokemonInicialOverworld] Error: No hay pokémon configurados para la selección inicial")
		proceso_activo = false  # Liberar bandera
		return

	# Abrir pantalla de selección del Pokémon inicial
	if nodo_administrador:
		if nodo_jugador:
			nodo_jugador.no_control = true
		Singleton.mantener_pausa(&"pokemon_inicial", true)
		await Singleton.transicion("oscurecer")
		var nodo_menu = nodo_administrador.get_node_or_null("Menu")
		if not nodo_menu:
			print("❌ [PokemonInicialOverworld] Error: No se encontró el nodo Menu")
			proceso_activo = false  # Liberar bandera en caso de error
			if nodo_jugador:
				nodo_jugador.no_control = false
			Singleton.mantener_pausa(&"pokemon_inicial", false)
			return

		var instancia_seleccion = scn_pantalla_seleccion.instantiate()
		instancia_seleccion.connect("seleccion_hecha", _on_seleccion_hecha)
		var opciones: Array = [pokemon_inicial_1, pokemon_inicial_2, pokemon_inicial_3]
		instancia_seleccion.set_iniciales(opciones)
		nodo_menu.add_child(instancia_seleccion)
	else:
		print("❌ [PokemonInicialOverworld] Error: No se encontró el AdministradorMapa")
		proceso_activo = false  # Liberar bandera en caso de error

func _on_seleccion_hecha(pokemon_seleccionado: Dictionary):
	print("🎉 [PokemonInicialOverworld] Selección completada!")
	print("🎉 [PokemonInicialOverworld] Pokémon elegido: ", pokemon_seleccionado.get("name", "Desconocido"))
	print("🎉 [PokemonInicialOverworld] Datos completos: ", pokemon_seleccionado)

	# Obtener datos completos del pokémon desde la base de datos
	var datos_pokemon_inicial = obtener_datos_pokemon_inicial()

	# Buscar los datos del pokémon seleccionado
	var nombre_interno_seleccionado = pokemon_seleccionado.get("nombre_interno", "")
	var datos_completos = {}

	# Buscar en los datos obtenidos cuál corresponde al seleccionado
	for key in datos_pokemon_inicial.keys():
		var pokemon_data = datos_pokemon_inicial[key]
		if pokemon_data.get("nombre_interno", "") == nombre_interno_seleccionado:
			datos_completos = pokemon_data
			break

	# Verificar que tenemos datos suficientes
	if datos_completos.is_empty():
		print("❌ [PokemonInicialOverworld] Error: No se pudieron obtener datos completos para el pokémon seleccionado")
		# Reactivar control del jugador en caso de error
		if nodo_jugador:
			nodo_jugador.no_control = false
		Singleton.mantener_pausa(&"pokemon_inicial", false)
		proceso_activo = false
		return

	print("📊 [PokemonInicialOverworld] Datos del pokémon seleccionado: ", datos_completos)

	# Agregar el pokémon al equipo del jugador usando el sistema de guardado
	var especie_nombre = datos_completos.get("nombre_interno", "")
	var nivel_inicial = 5  # Nivel típico para pokémon inicial

	if especie_nombre != "":
		# Lugar = sección del mapa donde está este evento (CreateMon de pokeruby).
		var exito = entregar_inicial(especie_nombre, _seccion_del_mapa(), nivel_inicial)
		if exito:
			print("✅ [PokemonInicialOverworld] Pokémon agregado exitosamente al equipo del jugador")

			# Actualizar las opciones del menú para mostrar la entrada de Pokémon
			if nodo_administrador and nodo_administrador.has_method("actualizar_opciones_menu"):
				nodo_administrador.actualizar_opciones_menu()
				print("🎮 [PokemonInicialOverworld] Opciones del menú actualizadas")
		else:
			print("❌ [PokemonInicialOverworld] Error: No se pudo agregar el pokémon al equipo (posiblemente equipo lleno)")
	else:
		print("❌ [PokemonInicialOverworld] Error: Nombre interno del pokémon no válido")

	# Marcar como usado si está configurado para una sola vez
	if usar_una_sola_vez and id_activador != "":
		print("🎯 [PokemonInicialOverworld] Marcando como usado: ", id_activador)
		_set_bandera(id_activador, true)

	# Cerrar la pantalla de selección y hacer transición
	var nodo_menu = nodo_administrador.get_node_or_null("Menu")
	if nodo_menu:
		# Buscar y eliminar la instancia de selección
		for hijo in nodo_menu.get_children():
			if hijo.has_signal("seleccion_hecha"):
				hijo.queue_free()
				break

	# Transición de vuelta
	await Singleton.transicion("aclarar")
	# Liberar el control solo después de retirar la escena superpuesta y aclarar.
	if nodo_jugador:
		nodo_jugador.no_control = false
	Singleton.mantener_pausa(&"pokemon_inicial", false)
	print("🎮 [PokemonInicialOverworld] Control del jugador reactivado")
	print("✅ [PokemonInicialOverworld] Proceso de selección inicial completado")

	# Ocultar el activador si está configurado para una sola vez
	# if usar_una_sola_vez:
	# 	visible = false
	# 	print("👻 [PokemonInicialOverworld] Activador ocultado")

	# Liberar bandera de proceso
	proceso_activo = false
	print("🔓 [PokemonInicialOverworld] Proceso liberado, listo para nueva interacción")

## CB2_GiveStarter: añade el inicial al equipo (origen LABORATORIO, `seccion` = lugar
## donde se obtiene) y guarda su índice (VAR_STARTER_MON), que decide el equipo del
## rival. La comparten este activador y el rescate de ABEDUL de la Ruta 101.
## Devuelve false si no cupo en el equipo.
static func entregar_inicial(especie_nombre: String, seccion: String = "", nivel: int = 5) -> bool:
	if especie_nombre.is_empty():
		return false
	var exito: bool = SistemaGuardado.agregar_pokemon_al_equipo(especie_nombre, nivel, "",
		ORIGEN_LABORATORIO, seccion)
	if exito:
		# Entra al final del equipo: se registra ESE Pokémon, no «el primero».
		SistemaGuardado.registrar_inicial(SistemaGuardado.get_equipo().back())
	return exito

## Clave de lugar (Lugares) del mapa donde está el evento; "" si no se puede
## resolver (agregar_pokemon_al_equipo usa entonces la del origen).
func _seccion_del_mapa() -> String:
	if nodo_administrador and nodo_administrador.has_method("obtener_seccion_lugar_actual"):
		return str(nodo_administrador.obtener_seccion_lugar_actual())
	return ""

## Funciones auxiliares para banderas
func _get_bandera(bandera: String) -> bool:
	if Engine.is_editor_hint():
		return false
	if is_instance_valid(SistemaGuardado):
		var valor = SistemaGuardado.get_flag(bandera)
		print("🏁 [PokemonInicialOverworld] Leyendo bandera '", bandera, "': ", valor)
		return valor
	return false

func _set_bandera(bandera: String, valor: bool):
	if Engine.is_editor_hint():
		return
	if is_instance_valid(SistemaGuardado):
		SistemaGuardado.set_flag(bandera, valor)
		print("🏁 [PokemonInicialOverworld] Estableciendo bandera '", bandera, "': ", valor)

## Función para resetear el activador (útil para debug)
func resetear_activador():
	if id_activador != "":
		_set_bandera(id_activador, false)
	visible = true
	print("🎯 Activador reseteado: ", id_activador)

## Obtiene los datos de los pokémon inicial desde la base de datos
func obtener_datos_pokemon_inicial() -> Dictionary:
	print("🔍 [PokemonInicialOverworld] Iniciando búsqueda en base de datos...")

	var database_manager = get_node_or_null("/root/DatabaseManager")
	if not database_manager:
		print("❌ [PokemonInicialOverworld] Error: No se encontró DatabaseManager")
		return {}

	var resultado = {}
	var pokemon_configurados = [pokemon_inicial_1, pokemon_inicial_2, pokemon_inicial_3]

	for i in range(pokemon_configurados.size()):
		var nombre_interno = pokemon_configurados[i]
		if nombre_interno == "":
			print("⚠️ [PokemonInicialOverworld] Pokémon en posición ", i+1, " no configurado")
			continue

		print("🔍 [PokemonInicialOverworld] Buscando datos para: ", nombre_interno)

		# Obtener datos del pokémon desde la base de datos
		var datos_pokemon = database_manager.obtener_datos_pokemon(nombre_interno)

		if datos_pokemon.is_empty():
			print("❌ [PokemonInicialOverworld] Pokémon no encontrado en BD: ", nombre_interno)
			continue

		# Obtener la ruta de la imagen
		var ruta_imagen = obtener_ruta_imagen_pokemon(nombre_interno)

		# Estructura de datos compatible con inicial.gd
		var datos_procesados = {
			"name": datos_pokemon.get("nombre", nombre_interno),
			"description": datos_pokemon.get("categoria", "POKéMON"),
			"nombre_interno": nombre_interno,
			"numero_nacional": datos_pokemon.get("numero_nacional", 0),
			"texture_path": ruta_imagen,
			"position": Vector2.ZERO  # Se asignará desde inicial.gd
		}

		resultado["pokemon_" + str(i+1)] = datos_procesados
		print("✅ [PokemonInicialOverworld] Datos procesados para ", nombre_interno, ": ", datos_procesados.name, " - ", datos_procesados.description)

	print("📊 [PokemonInicialOverworld] Total pokémon procesados: ", resultado.size())
	return resultado

## Obtiene la ruta de la imagen de un pokémon
func obtener_ruta_imagen_pokemon(nombre_interno: String) -> String:
	# Ruta estándar donde están las imágenes frontales de pokémon
	var ruta_base = "res://graficos/pokemon/front/"
	var ruta_completa = ruta_base + nombre_interno + ".png"

	# Verificar si el archivo existe
	if ResourceLoader.exists(ruta_completa):
		print("🖼️ [PokemonInicialOverworld] Imagen encontrada: ", ruta_completa)
		return ruta_completa
	else:
		print("⚠️ [PokemonInicialOverworld] Imagen no encontrada: ", ruta_completa, " - usando imagen por defecto")
		# Retornar una imagen por defecto o la de un pokémon base
		return ruta_base + "MISSINGNO.png"  # O cualquier imagen por defecto que tengas

## Valida la configuración de pokémon al inicio
func _validar_configuracion_pokemon():
	print("🔍 [PokemonInicialOverworld] Validando configuración de pokémon...")

	var pokemon_validos = 0
	var pokemon_configurados = [pokemon_inicial_1, pokemon_inicial_2, pokemon_inicial_3]

	for i in range(pokemon_configurados.size()):
		var nombre_interno = pokemon_configurados[i]
		if nombre_interno != "":
			pokemon_validos += 1
			print("✅ [PokemonInicialOverworld] Pokémon ", i+1, " configurado: ", nombre_interno)
		else:
			print("⚠️ [PokemonInicialOverworld] Pokémon ", i+1, " no configurado")

	if pokemon_validos == 0:
		print("❌ [PokemonInicialOverworld] Error: No hay pokémon configurados")
	else:
		print("📊 [PokemonInicialOverworld] Total pokémon configurados: ", pokemon_validos, "/3")

## Función para validar configuración
## TODO: Revisar donde se presentan estos mensajes
func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()

	if id_activador == "":
		warnings.append("ID del activador no está configurado")

	if pokemon_inicial_1 == "" and pokemon_inicial_2 == "" and pokemon_inicial_3 == "":
		warnings.append("No hay pokémon configurados. Configure al menos uno.")

	return warnings
