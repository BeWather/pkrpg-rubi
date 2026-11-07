extends Node
## PILOTO (opcion B): escena boot del proceso del JUEGO, lanzada por la ventana
## nativa del editor via EditorInterface.play_custom_scene().
##
## Lee la ConfiguracionDebugBatalla guardada en res://BaseDatos/temp, la
## convierte a DatosInicioBatalla (desde_diccionario) e instancia batalla.tscn
## llamando a iniciar_batalla_con_configuracion().
##
## En modo headless (validacion automatica) se autocierra tras unos segundos.

const ScriptConfiguracion := preload("res://escenas/batalla/debug/configuracion_debug_batalla.gd")
const DatosInicioBatallaScript := preload("res://escenas/batalla/datos_inicio_batalla.gd")
const TiposEntrenadorData := preload("res://BaseDatos/tipos_entrenador.gd")

const RUTA_CONFIG := "res://BaseDatos/temp/configuracion_debug_batalla.tres"
const RUTA_BATALLA := "res://escenas/batalla/batalla.tscn"
const SEGUNDOS_AUTO_SALIDA_HEADLESS := 2.5


func _ready() -> void:
	print("=== [PILOTO DEBUG BATALLA] boot del proceso de juego ===")
	_cargar_partida()
	_mostrar_etiqueta()

	var config := _leer_configuracion()
	if config == null:
		print("[PILOTO] ERROR: no se encontro el Resource en %s. Abre la ventana nativa del plugin y pulsa 'Preparar batalla'." % RUTA_CONFIG)
		_salir_si_headless()
		return

	print("[PILOTO] Configuracion recibida: %s" % config.resumen())

	_aplicar_jugador(config)
	_aplicar_opciones(config)

	var datos: DatosInicioBatalla = _convertir_a_datos_inicio(config)
	if datos == null:
		print("[PILOTO] ERROR: no se pudo construir DatosInicioBatalla.")
		_salir_si_headless()
		return

	var errores: PackedStringArray = datos.obtener_errores_validacion()
	if not errores.is_empty():
		print("[PILOTO] DatosInicioBatalla invalida: %s" % ", ".join(errores))
		_salir_si_headless()
		return

	print("[PILOTO] Validacion OK. Instanciando %s ..." % RUTA_BATALLA)
	_lanzar_batalla(datos, config)
	_salir_si_headless()


func _leer_configuracion() -> ScriptConfiguracion:
	if not ResourceLoader.exists(RUTA_CONFIG):
		return null
	return load(RUTA_CONFIG) as ScriptConfiguracion


func _convertir_a_datos_inicio(config: ScriptConfiguracion) -> DatosInicioBatalla:
	var diccionario := config.a_diccionario_inicio()
	var equipo := _construir_equipo_jugador(config)
	if not equipo.is_empty():
		diccionario["equipo_jugador"] = equipo
	if config.es_entrenador():
		diccionario["entrenador"] = _construir_entrenador(config)
	var datos := DatosInicioBatallaScript.desde_diccionario(diccionario)
	if config.es_salvaje():
		datos.equipo_rival = _construir_equipo_rival_salvaje(config)
	elif config.es_entrenador() and datos.entrenador != null:
		datos.equipo_rival = _construir_equipo_rival_entrenador(datos.entrenador)
	return datos


func _construir_equipo_rival_salvaje(config: ScriptConfiguracion) -> Array[BasePokemon]:
	var equipo: Array[BasePokemon] = []
	var nombre := config.especie_salvaje.strip_edges().to_upper()
	if nombre.is_empty() or not DatabaseManager.existe_pokemon(nombre):
		nombre = "RHYDON"
	var pokemon := BasePokemon.new(nombre, config.nivel_salvaje, "salvaje")
	if not config.salvaje_datos.is_empty():
		pokemon.aplicar_snapshot(config.salvaje_datos)
	equipo.append(pokemon)
	print("[PILOTO] Equipo rival salvaje construido: %s Nv.%d" % [nombre, config.nivel_salvaje])
	return equipo


func _construir_equipo_rival_entrenador(entrenador: DatosEntrenador) -> Array[BasePokemon]:
	var equipo: Array[BasePokemon] = []
	for pokemon_data in entrenador.pokemon:
		var nombre: String = pokemon_data.nombre_interno
		var nivel: int = pokemon_data.nivel
		if not DatabaseManager.existe_pokemon(nombre):
			continue
		var pokemon := BasePokemon.new(nombre, nivel, entrenador.clase_entrenador)
		if not pokemon_data.objeto.is_empty():
			pokemon.objeto = pokemon_data.objeto
		MovimientosEntrenador.aplicar(pokemon, pokemon_data.movimientos)
		equipo.append(pokemon)
	if equipo.is_empty():
		equipo.append(BasePokemon.new("RHYDON", 25, entrenador.clase_entrenador))
	print("[PILOTO] Equipo rival entrenador construido: %d pokemon" % equipo.size())
	return equipo


## Crea las instancias BasePokemon del equipo activo elegido en la ventana.
## Aqui SI se puede expandir a instancia completa: el boot corre en el proceso
## del juego con la base de datos conectada.
##   - origen PARTIDA: usa la copia editada en memoria si el usuario la toco;
##     si no, deja que la batalla lea el equipo tal cual de la partida.
##   - origen PRUEBA: usa el equipo B del Resource (memoria de prueba).
## Nunca se escribe en el JSON de la partida.
func _construir_equipo_jugador(config: ScriptConfiguracion) -> Array:
	var entradas: Array = []
	if config.origen_equipo == 1:
		entradas = config.equipo_prueba
	elif not config.equipo_partida_memoria.is_empty():
		entradas = config.equipo_partida_memoria
	if entradas.is_empty():
		return []
	var equipo: Array = []
	for entrada in entradas:
		var nombre := str(entrada.get("nombre_interno", "")).strip_edges().to_upper()
		if nombre.is_empty():
			continue
		var pokemon := BasePokemon.new(nombre, maxi(int(entrada.get("nivel", 5)), 1), SistemaGuardado.get_nombre_jugador())
		pokemon.aplicar_snapshot(entrada)
		# El snapshot no trae el ID: sin él, todo el equipo contaría como intercambiado.
		pokemon.entrenador_id = int(entrada.get("entrenador_id", SistemaGuardado.datos_vivos.jugador.get("id", 0)))
		equipo.append(pokemon)
	print("[PILOTO] Equipo del jugador inyectado desde la ventana (%s): %d pokemon" % [
		"PRUEBA" if config.origen_equipo == 1 else "PARTIDA (editado)",
		equipo.size(),
	])
	return equipo


## Reconstruye DatosEntrenador desde el registro JSON que viajo dentro del Resource.
func _construir_entrenador(config: ScriptConfiguracion) -> DatosEntrenador:
	var entrenador := DatosEntrenador.new()
	entrenador.nombre = config.entrenador_nombre
	entrenador.clase_entrenador = config.entrenador_clase
	var registro: Dictionary = config.entrenador_datos
	if not registro.is_empty():
		entrenador.frase_derrota = str(registro.get("frase_derrota", "..."))
		entrenador.musica_id = str(registro.get("musica_id", "BATALLA_ENTRENADOR_1"))
		entrenador.ratio_dinero = int(registro.get(
			"ratio_dinero",
			TiposEntrenadorData.obtener_ratio_dinero(str(registro.get("clase_entrenador", "ENTRENADOR")))
		))
		entrenador.num_sprite = int(registro.get("num_sprite", 1))
		for objeto in registro.get("objetos", []):
			entrenador.objetos.append(str(objeto))
		entrenador.set_pokemon_desde_diccionarios(registro.get("pokemon", []))
	return entrenador


func _lanzar_batalla(datos: DatosInicioBatalla, config: ScriptConfiguracion) -> void:
	var batalla = load(RUTA_BATALLA).instantiate()
	# La casilla "animaciones" de la ventana controla la intro completa: sin
	# ella la batalla arranca directa en INPUT (saltar_animaciones).
	if config.opciones.has("animacion_combate"):
		batalla.saltar_animaciones = not bool(config.opciones.get("animacion_combate", true))
	add_child(batalla)
	await get_tree().process_frame
	batalla.iniciar_batalla_con_configuracion(datos)
	_reproducir_musica(config)


## En el flujo real la musica la aporta el mapa (MapaConfiguracion.musica_batalla)
## o el NPC entrenador, a traves del ReproductorMusica de AdministradorMapa.
## Aqui no hay mapa cargado, asi que el boot crea su propio reproductor.
var _reproductor: NuevoAudioStreamPlayer = null


func _reproducir_musica(config: ScriptConfiguracion) -> void:
	# Resolución unificada con el flujo real (ver
	# Singleton.reproducir_tema_batalla_mapa() /
	# BattleLaunchService.resolver_tema_musica_batalla()): config.musica_id es
	# una anulación manual de la ventana de pruebas; si no hay, se usa la
	# musica_id propia del entrenador cuando aplica. No hay mapa vivo en este
	# proceso, así que no hay música de mapa que aportar como segunda fuente.
	var musica_entrenador := ""
	if config.es_entrenador():
		musica_entrenador = str(config.entrenador_datos.get("musica_id", ""))
	var musica_preferida: String = config.musica_id if not config.musica_id.is_empty() else musica_entrenador
	var musica := BattleLaunchService.resolver_tema_musica_batalla(musica_preferida, "")
	if _reproductor == null:
		_reproductor = NuevoAudioStreamPlayer.new()
		add_child(_reproductor)
	_reproductor.reproducir_tema(musica, 0)
	print("[PILOTO] Musica de batalla: ", musica)


## Carga la partida debug del proyecto (res://partida/partida_guardada.json, el
## mismo archivo que lee la ventana del plugin) para que la batalla use datos
## reales: equipo, nombre, sexo (sprite), velocidad de texto, borde de menus
## (imagen_tipo) y tipo de combate.
func _cargar_partida() -> void:
	if OS.is_debug_build():
		SistemaGuardado.usar_partida_local_para_debug()
	if not SistemaGuardado.has_partida_guardada():
		print("[PILOTO] Sin partida guardada: la batalla usara valores por defecto (sin equipo).")
		return
	var ok := SistemaGuardado.cargar_partida()
	var equipo := SistemaGuardado.get_equipo()
	var opciones: Variant = SistemaGuardado.datos_vivos.get("opciones") if SistemaGuardado.datos_vivos != null else null
	print("[PILOTO] Partida cargada: %s | Equipo: %d/6 | nombre: %s (%s)" % [
		str(ok),
		equipo.size(),
		SistemaGuardado.get_nombre_jugador(),
		str(SistemaGuardado.datos_vivos.jugador.get("sexo", "?")),
	])
	if opciones != null:
		print("[PILOTO] Opciones: vtexto=%s borde=%s combate=%s anims=%s" % [
			str(opciones.velocidad_texto),
			str(opciones.imagen_tipo),
			str(opciones.tipo_combate),
			str(opciones.animacion_combate),
		])
	if equipo.is_empty():
		print("[PILOTO] AVISO: el equipo de la partida esta vacio; la batalla ira sin Pokemon del jugador.")


## Sobrescribe EN MEMORIA las opciones de batalla con las editadas en la
## ventana (la partida en disco no se toca).
func _aplicar_opciones(config: ScriptConfiguracion) -> void:
	if config.opciones.is_empty():
		return
	var opciones = SistemaGuardado.datos_vivos.opciones
	if opciones == null:
		return
	opciones.velocidad_texto = int(config.opciones.get("velocidad_texto", opciones.velocidad_texto))
	opciones.imagen_tipo = int(config.opciones.get("imagen_tipo", opciones.imagen_tipo))
	opciones.tipo_combate = int(config.opciones.get("tipo_combate", opciones.tipo_combate))
	opciones.animacion_combate = bool(config.opciones.get("animacion_combate", opciones.animacion_combate))
	opciones.nivel_audio = int(config.opciones.get("nivel_audio", opciones.nivel_audio))
	opciones.controles = int(config.opciones.get("controles", opciones.controles))
	print("[PILOTO] Opciones de prueba aplicadas en memoria: ", config.opciones)


## Sobrescribe EN MEMORIA nombre/sexo del jugador con los valores de prueba
## de la ventana (la partida en disco no se toca). Afecta al sprite de espalda
## de la batalla y al nombre de entrenador de los pokes creados por el boot.
func _aplicar_jugador(config: ScriptConfiguracion) -> void:
	if config.jugador_nombre.is_empty() and config.jugador_sexo.is_empty():
		return
	var jugador: Dictionary = SistemaGuardado.datos_vivos.jugador
	if not config.jugador_nombre.is_empty():
		jugador["nombre"] = config.jugador_nombre
	if config.jugador_sexo == "M" or config.jugador_sexo == "F":
		jugador["sexo"] = config.jugador_sexo
	print("[PILOTO] Jugador de prueba: %s (%s) -- solo en memoria." % [str(jugador.get("nombre", "?")), str(jugador.get("sexo", "?"))])


func _mostrar_etiqueta() -> void:
	var capa := CanvasLayer.new()
	add_child(capa)
	var etiqueta := Label.new()
	etiqueta.text = "PILOTO DEBUG BATALLA (boot)"
	etiqueta.position = Vector2(12, 8)
	capa.add_child(etiqueta)
	# La etiqueta se muestra solo 3 segundos y luego se elimina (capa y label).
	var temporizador := get_tree().create_timer(1.0)
	await temporizador.timeout
	if is_instance_valid(etiqueta):
		etiqueta.queue_free()
	if is_instance_valid(capa):
		capa.queue_free()


## Metodo con nombre (no lambda) para que el await se propague completo.
func _salir_si_headless() -> void:
	if DisplayServer.get_name() != "headless":
		return
	await get_tree().create_timer(SEGUNDOS_AUTO_SALIDA_HEADLESS).timeout
	print("[PILOTO] Fin del piloto headless.")
	get_tree().quit()
