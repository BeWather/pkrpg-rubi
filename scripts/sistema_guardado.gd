extends Node

# Sistema de guardado para Pokemon Rubi
# Gestiona la persistencia de datos del jugador

## Ruta del archivo de partida guardada; por defecto en el almacenamiento
## del usuario. Se puede redirigir en desarrollo con
## usar_partida_local_para_debug() para inspeccionar el JSON en el proyecto.
var archivo_guardado: String = "user://partida_guardada.json"

const RUTA_PARTIDA_LOCAL_DEBUG: String = "res://partida/partida_guardada.json"

## Redirige guardado/carga a la carpeta partida/ dentro del proyecto.
## Solo util en desarrollo: en exportaciones res:// no es escribible.
func usar_partida_local_para_debug() -> void:
	archivo_guardado = RUTA_PARTIDA_LOCAL_DEBUG
	_logear("🔧 Guardado redirigido a %s" % archivo_guardado)

# Estructura de datos del guardado
var datos_vivos: EstructuraGuardado = EstructuraGuardado.new()
signal partida_cargada()
## Emitida por `limpiar_temporales()` (ClearTempFieldEventData de pokeruby): quien
## tenga en el mundo vivo un estado ligado a banderas temporales (árboles
## cortados, hierba cortada) debe volver al estado del mapa recién cargado.
signal temporales_limpiados()

# Caché local para datos de objetos (para acceso más rápido)
var cache_objetos: Dictionary = {}

## Guardería viva (perezosa) y el `datos_vivos` del que se creó: si alguien
## sustituye `datos_vivos`, se vuelve a crear desde el nuevo diccionario.
var _guarderia: Guarderia = null
var _guarderia_origen: EstructuraGuardado = null
var _revanchas: SistemaRevanchas = null
var _revanchas_origen: EstructuraGuardado = null
var _bases_secretas: SistemaBasesSecretas = null
var _bases_secretas_origen: EstructuraGuardado = null
var _concursos: RegistroConcursos = null
var _concursos_origen: EstructuraGuardado = null
var _estuche_pokecubos: EstuchePokecubos = null
var _estuche_pokecubos_origen: EstructuraGuardado = null

# NOTA: Es la primera función que se llama al entrar en el árbol de nodos. Precede a los _enter_tree de los nodos hijos
func _enter_tree():
	_logear("ENTER TREE", true)

	# Si el equipo está vacío (al iniciar el juego por primera vez),
	# creamos un equipo de prueba para que el jugador tenga algo.
	# if datos_vivos.equipo_pokemon.is_empty():
	#   print("GESTOR_DATOS: El equipo está vacío. Creando equipo de prueba...")
	#   crear_equipo_de_prueba()

func _ready():
	_logear("READY", true)

# FUNCIONES PRINCIPALES DE GUARDADO
func guardar_partida(preservar_posicion: bool = false) -> bool:
	# VAR_INIT_SECRET_BASE: no guardar dentro de una vista previa sin confirmar.
	if is_instance_valid(Singleton.mapa_nodo) and not Singleton.mapa_nodo.permite_guardar():
		return false
	_logear("Iniciando proceso de guardado...", true)

	# Actualizar datos actuales
	if not preservar_posicion:
		actualizar_datos_vivos()

	# Datos vivos actualizados
	_sincronizar_guarderia()
	_sincronizar_revanchas()
	_sincronizar_bases_secretas()
	_sincronizar_concursos()
	_sincronizar_estuche_pokecubos()
	var guardar = datos_vivos.to_dict()

	# Resumir datos de items para reducir tamaño del archivo
	reducir_datos_items(guardar)

	# Guardar archivo
	var archivo = FileAccess.open(archivo_guardado, FileAccess.WRITE)
	if archivo:
		var json_string = _formatear_json_bonito(guardar)
		archivo.store_string(json_string)
		archivo.close()
		_logear("✅ Partida guardada exitosamente")
		return true
	else:
		_logear("❌ Error al guardar archivo")
		return false

## Función para formatear JSON con indentación bonita
func _formatear_json_bonito(data: Dictionary) -> String:
	return JSON.stringify(data, "\t")

func cargar_partida() -> bool:
	_logear("Intentando cargar partida...")

	if not FileAccess.file_exists(archivo_guardado):
		_logear("❌ No existe archivo de guardado, usando valores por defecto")
		return false

	var archivo = FileAccess.open(archivo_guardado, FileAccess.READ)
	if archivo:
		var json_string = archivo.get_as_text()
		archivo.close()

		var json = JSON.new()
		var resultado = json.parse(json_string)

		if resultado == OK:
			datos_vivos.from_dict(json.data)
			reiniciar_guarderia()
			reiniciar_revanchas()
			reiniciar_bases_secretas()
			reiniciar_concursos()
			reiniciar_estuche_pokecubos()
			inicializar_mochila_estructura()
			_inicializar_datos_persistentes()

			# Inicializar cajas PC y generar datos de prueba si están vacías
			inicializar_cajas_pc()
			# _verificar_y_generar_datos_prueba_cajas()

			# Verificar y generar equipo de prueba si está vacío
			# _verificar_y_generar_equipo_prueba()

			print("👥 [SISTEMA_GUARDADO] Equipo final cargado: %d Pokémon" % datos_vivos.equipo_pokemon.size())

			cargar_cache_objetos_mochila() # <-- Recarga el caché de objetos de la mochila
			_logear("✅ Partida cargada exitosamente")
			# Emitir señal para notificar a otros nodos que la partida fue cargada
			if has_signal("partida_cargada"):
				emit_signal("partida_cargada")
			# Singleton arranca en BAJO: aplicar el volumen guardado sin esperar a
			# que se abra la ventana de opciones.
			Singleton.emit_signal("configurar_audio", int(datos_vivos.opciones.nivel_audio))
			# El equipo se reconstruye automáticamente en EstructuraGuardado.from_dict()
			# aplicar_datos_cargados()
			return true
		else:
			_logear("❌ Error al parsear archivo de guardado")
			return false
	else:
		_logear("❌ Error al leer archivo de guardado")
		return false

## Verifica si existe un archivo de partida guardada
func has_partida_guardada() -> bool:
	if FileAccess.file_exists(archivo_guardado):
		_logear("✅ Se encontró archivo de partida guardada")
		return true
	else:
		_logear("⚠️ No existe archivo de partida guardada")
		return false

## Recarga el caché de datos de los objetos de la mochila al cargar partida
func cargar_cache_objetos_mochila():
	limpiar_cache_objetos()
	inicializar_mochila_estructura()
	if datos_vivos.mochila.has("bolsillos"):
		for bolsillo_key in datos_vivos.mochila.bolsillos.keys():
			var items = datos_vivos.mochila.bolsillos[bolsillo_key].items
			for item in items:
				obtener_datos_objeto_completos(item.nombre_interno)

## Reduce los datos de los items en la mochila para el guardado
## Solo conserva nombre_interno y cantidad, eliminando descripción, icono, etc.
func reducir_datos_items(datos_guardar: Dictionary):
	if not datos_guardar.has("mochila") or not datos_guardar.mochila.has("bolsillos"):
		return

	var items_reducidos_total = 0
	for bolsillo_key in datos_guardar.mochila.bolsillos.keys():
		var bolsillo = datos_guardar.mochila.bolsillos[bolsillo_key]
		if bolsillo.has("items") and bolsillo.items is Array:
			var items_reducidos = []
			for item in bolsillo.items:
				if item is Dictionary and item.has("nombre_interno") and item.has("cantidad"):
					# Solo conservar nombre_interno y cantidad
					items_reducidos.append({
						"nombre_interno": item.nombre_interno,
						"cantidad": item.cantidad
					})
					items_reducidos_total += 1
			bolsillo.items = items_reducidos

	if items_reducidos_total > 0:
		_logear("📦 Datos de %d items reducidos para guardado" % items_reducidos_total)

## Resetea el estado vivo a los valores por defecto de una partida nueva y
## guarda. Los valores iniciales salen de la plantilla, que es la única fuente
## de verdad: aquí todavía no hay sexo ni nombre elegidos (los fija la intro
## antes de entrar al mundo), así que se prepara con ambos vacíos.
func partida_nueva() -> bool:
	_logear("Iniciando nueva partida...")

	var plantilla := preparar_plantilla_partida_nueva("", "")
	aplicar_plantilla_partida_nueva(plantilla)

	# Equipo de prueba para que el estado inicial no quede sin Pokémon.
	generar_equipo_inicial_prueba()

	Singleton.reiniciar_memoria_mochila()
	Singleton.equipo_ultimo_cursor = 0

	_logear("🆕 Nueva partida iniciada con valores por defecto.")
	return guardar_partida()

## Crea una nueva partida y guarda el archivo (wrapper para compatibilidad)
func crear_partida_nueva() -> bool:
	_logear("Iniciando creación de partida nueva...")

	var guardada := partida_nueva()
	if guardada:
		_logear("✅ Nueva partida creada exitosamente")
	else:
		_logear("❌ No se pudo guardar la nueva partida")
	return guardada


## Sincroniza los datos vivos con el estado actual del juego antes de guardar.
## Solo actualiza la posición si hay un AdministradorMapa con jugador activo;
## en menús o tests (sin overworld) conserva los valores existentes.
func actualizar_datos_vivos() -> void:
	datos_vivos.fecha_guardado = Time.get_datetime_string_from_system()

	var admin: Node = get_tree().root.get_node_or_null("AdministradorMapa")
	if admin == null or not ("jugador" in admin) or admin.jugador == null:
		_logear("Sin jugador activo; se conservan datos vivos existentes")
		return

	# `posicion.nombre_lugar` guarda la clave de lugar (Lugares), no el texto.
	var nombre_lugar: String = ""
	var tile_idx := Vector2i.ZERO
	if "mapa_actual" in admin and admin.mapa_actual != null:
		if admin.has_method("obtener_seccion_lugar_actual"):
			nombre_lugar = str(admin.call("obtener_seccion_lugar_actual"))
		elif admin.mapa_actual is MapaConfiguracion:
			nombre_lugar = (admin.mapa_actual as MapaConfiguracion).obtener_seccion_efectiva()
		var posicion_base_global: Vector2 = admin.jugador.global_position - admin.jugador_offset
		tile_idx = admin.mapa_actual.global_to_map_cell(posicion_base_global)
		if admin.has_method("guardar_estado_visible_mapa_actual"):
			admin.call("guardar_estado_visible_mapa_actual", tile_idx)
	else:
		tile_idx = Vector2i((admin.jugador.global_position / Singleton.TILE_SIZE).floor())

	datos_vivos.posicion.cx = tile_idx.x
	datos_vivos.posicion.cy = tile_idx.y
	datos_vivos.posicion.mapa_actual = admin.mapa_actual_key if "mapa_actual_key" in admin else datos_vivos.posicion.mapa_actual
	datos_vivos.posicion.nombre_lugar = nombre_lugar
	datos_vivos.posicion.capa_datos = int(Singleton.capa_activa)
	datos_vivos.posicion["en_bicicleta"] = admin.jugador.en_bicicleta if "en_bicicleta" in admin.jugador else false
	datos_vivos.posicion["tipo_bici"] = admin.jugador.tipo_bici if "tipo_bici" in admin.jugador else "CARRERA"
	datos_vivos.posicion["en_surf"] = admin.jugador.en_surf if "en_surf" in admin.jugador else false
	if "facing_direction" in admin.jugador:
		var dir: Vector2 = admin.jugador.facing_direction
		datos_vivos.posicion["direccion"] = [int(dir.x), int(dir.y)]
	datos_vivos.estado_mapa = {}
	if admin.has_method("capturar_estado_objetos_mapa_actual"):
		datos_vivos.estado_mapa = {
			"mapa": datos_vivos.posicion.mapa_actual,
			"objetos": admin.call("capturar_estado_objetos_mapa_actual"),
		}
	_logear("Posición actualizada: %s (%s): (cx=%d, cy=%d, capa=%d)" % [
		datos_vivos.posicion.nombre_lugar,
		datos_vivos.posicion.mapa_actual,
		datos_vivos.posicion.cx,
		datos_vivos.posicion.cy,
		datos_vivos.posicion.capa_datos,
	])


## APLICAR DATOS CARGADOS AL JUEGO
func aplicar_datos_cargados():
	print("🔄 [GUARDADO] Aplicando datos cargados...")

	# Restaurar posición del jugador
	var admin = get_tree().root.get_node_or_null("AdministradorMapa")
	if admin:
		admin.mapa_actual_key = datos_vivos.posicion.mapa_actual
		admin.pos_ini = Vector2(datos_vivos.posicion.cx, datos_vivos.posicion.cy)
		print("📍 [GUARDADO] Posición restaurada: %s (%.0f, %.0f)" % [
			datos_vivos.posicion.mapa_actual,
			datos_vivos.posicion.cx,
			datos_vivos.posicion.cy
		])

	# El equipo ya fue rehidratado, no se necesita hacer más aquí

## FUNCIONES DE ACCESO A DATOS
func get_posicion_guardada() -> Dictionary:
	return datos_vivos.posicion

func set_mapa_actual(mapa: String):
	datos_vivos.posicion.mapa_actual = mapa

func set_posicion_jugador(pos: Vector2):
	datos_vivos.posicion.cx = pos.x
	datos_vivos.posicion.cy = pos.y

func get_punto_curacion() -> Dictionary:
	return datos_vivos.punto_curacion.duplicate(true)

func set_punto_curacion(punto: Dictionary) -> void:
	if punto.is_empty():
		return
	datos_vivos.punto_curacion = punto.duplicate(true)

## Entrada exterior (ver EstructuraGuardado.entrada_exterior); {} = ninguna.
func get_entrada_exterior() -> Dictionary:
	return datos_vivos.entrada_exterior.duplicate(true)

func tiene_entrada_exterior() -> bool:
	return not datos_vivos.entrada_exterior.is_empty()

func set_entrada_exterior(entrada: Dictionary) -> void:
	datos_vivos.entrada_exterior = entrada.duplicate(true)

func get_dinero() -> int:
	return datos_vivos.jugador.dinero

func set_dinero(cantidad: int):
	datos_vivos.jugador.dinero = cantidad

func get_nombre_jugador() -> String:
	return datos_vivos.jugador.nombre

func set_nombre_jugador(nombre: String):
	datos_vivos.jugador.nombre = nombre

## === INICIAL (VAR_STARTER_MON de Rubí) ===
## Orden de los índices que usan los `switch VAR_STARTER_MON` del decomp.
const INICIALES: Array[String] = ["TREECKO", "TORCHIC", "MUDKIP"]

## Índice del inicial elegido: 0 TREECKO, 1 TORCHIC, 2 MUDKIP. Sin elegir (o en
## una partida anterior a este dato) se asume TREECKO.
func get_inicial() -> int:
	var indice := int(datos_vivos.jugador.get("inicial", -1))
	return indice if indice >= 0 and indice < INICIALES.size() else 0

func set_inicial(indice: int) -> void:
	if indice < 0 or indice >= INICIALES.size():
		push_error("[GUARDADO] Inicial fuera de rango: %d" % indice)
		return
	datos_vivos.jugador["inicial"] = indice

## true si ya se eligió el inicial (get_inicial() devuelve TREECKO también sin elegir).
func tiene_inicial_elegido() -> bool:
	var indice := int(datos_vivos.jugador.get("inicial", -1))
	return indice >= 0 and indice < INICIALES.size()

## Registra `pokemon` como el inicial del jugador: guarda su especie (VAR_STARTER_MON)
## y su personalidad, que lo distingue de cualquier otro de la misma especie o del
## que ocupe el primer lugar del equipo. Falso si no es uno de los tres iniciales.
func registrar_inicial(pokemon: BasePokemon) -> bool:
	if pokemon == null:
		return false
	var indice := INICIALES.find(pokemon.nombre_interno)
	if indice < 0:
		push_warning("[GUARDADO] '%s' no es un inicial de Hoenn: no se registra" % pokemon.nombre_interno)
		return false
	set_inicial(indice)
	datos_vivos.jugador["inicial_personalidad"] = pokemon.personalidad
	return true

## El Pokémon inicial elegido, esté en el equipo o en el PC: primero el que tiene la
## personalidad registrada; si no (partida anterior a este dato) el primero de la
## especie elegida; y, si nunca se eligió inicial, el primero del equipo. null si
## no hay ninguno.
func get_pokemon_inicial() -> BasePokemon:
	var candidatos: Array = datos_vivos.equipo_pokemon.duplicate()
	for caja in datos_vivos.cajas_pc:
		if caja is Array:
			candidatos.append_array(caja)
	if not tiene_inicial_elegido():
		return candidatos[0] as BasePokemon if not candidatos.is_empty() else null
	var especie: String = INICIALES[get_inicial()]
	var por_especie: BasePokemon = null
	var personalidad = datos_vivos.jugador.get("inicial_personalidad", null)
	for candidato in candidatos:
		if not (candidato is BasePokemon) or candidato.nombre_interno != especie:
			continue
		if personalidad != null and candidato.personalidad == int(personalidad):
			return candidato
		if por_especie == null:
			por_especie = candidato
	return por_especie

## FUNCIONES DE UTILIDAD
func tiene_guardado() -> bool:
	return FileAccess.file_exists(archivo_guardado)

func borrar_guardado() -> bool:
	if FileAccess.file_exists(archivo_guardado):
		# Abrir el directorio real del archivo: la ruta puede estar redirigida
		# a res://partida/ en modo debug, no siempre es user://.
		var dir = DirAccess.open(archivo_guardado.get_base_dir())
		if dir:
			dir.remove(archivo_guardado.get_file())
			print("🗑️ [GUARDADO] Archivo de guardado eliminado")
			return true
	return false

func exportar_guardado_debug() -> String:
	# Para debug - exportar datos como texto legible
	var texto_debug = "=== DATOS DE GUARDADO DEBUG ===\n"
	texto_debug += "Fecha: %s\n" % datos_vivos.fecha_guardado
	texto_debug += "Mapa: %s\n" % datos_vivos.posicion.mapa_actual
	texto_debug += "Posición: (%.0f, %.0f)\n" % [datos_vivos.posicion.cx, datos_vivos.posicion.cy]
	texto_debug += "Equipo Pokémon: %d\n" % datos_vivos.equipo_pokemon.size()

	for i in range(datos_vivos.equipo_pokemon.size()):
		var poke = datos_vivos.equipo_pokemon[i]
		if poke is BasePokemon: # Verificar que es un objeto
			texto_debug += "  %d. %s Nv.%d (PS: %d/%d)\n" % [
				i+1, poke.nombre_interno, poke.nivel,
				poke.estad_ps_actual, poke.estad_ps
			]

	return texto_debug

# --- GESTIÓN DE DATOS EN TIEMPO REAL ---

## Crea un equipo inicial con Pokémon predefinidos directamente como BasePokemon.
## Esto asegura que el resto del juego siempre tenga datos con los que trabajar.
func crear_equipo_de_prueba():

	# Crear directamente objetos BasePokemon para evitar conversiones
	var zigzagoon = BasePokemon.new("ZIGZAGOON", 2, "ASH")
	zigzagoon.estado = Singleton.ProblemaEstado.DEBILITADO
	zigzagoon.estad_ps_actual = 0  # Debilitado

	var wingull = BasePokemon.new("WINGULL", 3, "ASH")
	wingull.estado = Singleton.ProblemaEstado.PARALIZADO
	wingull.estad_ps_actual = 3  # Barra roja (muy bajo)

	var poochyena = BasePokemon.new("POOCHYENA", 4, "ASH")
	poochyena.estado = Singleton.ProblemaEstado.QUEMADO
	poochyena.estad_ps_actual = 8  # Barra amarilla (medio)

	var mudkip = BasePokemon.new("MUDKIP", 10, "ASH")
	mudkip.estado = Singleton.ProblemaEstado.CONGELADO
	mudkip.estad_ps_actual = 25  # PS normal pero congelado

	# Asignar directamente como objetos BasePokemon
	datos_vivos.equipo_pokemon = [zigzagoon, wingull, poochyena, mudkip]
	print("GESTOR_DATOS: Equipo de prueba creado con %d Pokémon." % datos_vivos.equipo_pokemon.size())

# --- API Pública del Gestor ---

## Devuelve el equipo actual del jugador.
func get_equipo() -> Array:
	return datos_vivos.equipo_pokemon

## Fuerza la recreación del equipo de prueba (para testing).
func recrear_equipo_prueba() -> void:
	print("🔄 [GUARDADO] Recreando equipo de prueba...")
	datos_vivos.equipo_pokemon.clear()
	crear_equipo_de_prueba()

## Agrega un Pokémon al equipo del jugador.
## @param especie_nombre Nombre interno del pokémon (ej: "TREECKO", "TORCHIC", "MUDKIP")
## @param nivel Nivel del pokémon (por defecto 5)
## @param entrenador_original Nombre del entrenador original (por defecto nombre del jugador)
## @param origen Tipo de origen del Pokémon (por defecto 3 = REGALO)
## @param lugar Clave de lugar (Lugares) donde se recibe; "" = la del origen.
##   pokeruby CreateMon usa la sección del mapa actual, así que los eventos
##   deberían pasar AdministradorMapa.obtener_seccion_lugar_actual().
## @return true si se agregó exitosamente, false si el equipo está lleno
## Como ScriptGiveMon, marca la especie como vista y atrapada en la Pokédex.
func agregar_pokemon_al_equipo(especie_nombre: String, nivel: int = 5, entrenador_original: String = "", origen: int = 3, lugar: String = "") -> bool:
	# Verificar que el equipo no esté lleno (máximo 6 pokémon)
	if datos_vivos.equipo_pokemon.size() >= 6:
		print("❌ [GUARDADO] No se puede agregar %s: equipo lleno (%d/6)" % [especie_nombre, datos_vivos.equipo_pokemon.size()])
		return false

	# Usar nombre del jugador si no se especifica entrenador
	var entrenador = entrenador_original
	if entrenador == "":
		entrenador = datos_vivos.jugador.nombre
		if entrenador == "":
			entrenador = "JUGADOR"

	# TODO: Cuando Godot cargue PokemonFactory, usar esto:
	# var config = PokemonFactory.ConfiguracionPokemon.new(especie_nombre, nivel, origen)
	# config.entrenador_nombre = entrenador
	# config.lugar_encuentro = "LABORATORIO_INICIAL"
	# var nuevo_pokemon = PokemonFactory.crear_pokemon(config)

	# Por ahora, crear directamente con BasePokemon (método original mejorado)
	var nuevo_pokemon = BasePokemon.new(especie_nombre, nivel, entrenador)

	# Configurar propiedades específicas según el origen
	if entrenador_original == "" and origen != 1:
		# El jugador es el EO: nombre, ID y sexo (color del nombre en la ficha).
		_asignar_jugador_como_entrenador_original(nuevo_pokemon)
	else:
		nuevo_pokemon.entrenador_id = datos_vivos.jugador.id if origen != 1 else 0  # 1 = ENTRENADOR_NPC
	nuevo_pokemon.felicidad = _get_felicidad_por_origen(origen)
	var clave_lugar := Lugares.normalizar_clave(lugar) if not lugar.strip_edges().is_empty() else ""
	nuevo_pokemon.encuentro_lugar = clave_lugar if not clave_lugar.is_empty() else _get_lugar_por_origen(origen)
	nuevo_pokemon.encuentro_bola = "POKEBALL"
	nuevo_pokemon.encuentro_nivel = nivel
	nuevo_pokemon.estado = Singleton.ProblemaEstado.NORMAL

	# Agregar al equipo
	datos_vivos.equipo_pokemon.append(nuevo_pokemon)
	registrar_pokemon_atrapado(nuevo_pokemon.nombre_interno)

	print("✅ [GUARDADO] %s agregado al equipo: %s Nv.%d [Origen: %d] (Equipo: %d/6)" % [
		entrenador,
		especie_nombre,
		nivel,
		origen,
		datos_vivos.equipo_pokemon.size()
	])

	return true

## Obtiene la felicidad inicial según el origen del Pokémon
func _get_felicidad_por_origen(origen: int) -> int:
	# 0=SALVAJE, 1=ENTRENADOR_NPC, 2=HUEVO, 3=REGALO, 4=INTERCAMBIO,
	# 5=LABORATORIO, 6=EVENTO_ESPECIAL, 7=FOSSIL, 8=CAPTURA_ESPECIAL
	match origen:
		0: return 70   # SALVAJE
		1: return 255  # ENTRENADOR_NPC
		2: return 120  # HUEVO
		3: return 70   # REGALO
		4: return 70   # INTERCAMBIO
		5: return 70   # LABORATORIO
		6: return 120  # EVENTO_ESPECIAL
		7: return 70   # FOSSIL
		8: return 35   # CAPTURA_ESPECIAL (legendarios)
		_: return 70

## Obtiene la clave de lugar de encuentro (Lugares) según el origen del Pokémon
func _get_lugar_por_origen(origen: int) -> String:
	match origen:
		0: return Lugares.DESCONOCIDO          # SALVAJE
		1: return Lugares.EQUIPO_ENTRENADOR    # ENTRENADOR_NPC
		2: return Lugares.GUARDERIA_POKEMON    # HUEVO
		3: return Lugares.REGALO               # REGALO
		4: return Lugares.INTERCAMBIO          # INTERCAMBIO
		5: return Lugares.LABORATORIO_PROF     # LABORATORIO
		6: return Lugares.EVENTO_ESPECIAL      # EVENTO_ESPECIAL
		7: return Lugares.LABORATORIO_FOSSIL   # FOSSIL
		8: return Lugares.CAPTURA_ESPECIAL     # CAPTURA_ESPECIAL
		_: return Lugares.DESCONOCIDO

## Agrega un Pokémon dañado para probar el sistema de curación
func agregar_pokemon_danado_prueba() -> bool:
	# Agregar un Pikachu dañado
	if agregar_pokemon_al_equipo("PIKACHU", 8, "VIR"):
		var pikachu = datos_vivos.equipo_pokemon[-1]  # Último agregado

		# Dañar PS (dejar a 3 de 25 aprox)
		pikachu.ps_actuales = 3

		# Establecer estado de envenenamiento
		pikachu.estado = Singleton.ProblemaEstado.ENVENENADO

		# Gastar PP de los movimientos
		for movimiento in pikachu.movimientos:
			if movimiento is Movimiento:
				# Usar casi todos los PP
				var pp_a_usar = movimiento.pp_tot - 2
				movimiento.usar_pp(pp_a_usar)

		print("🩹 Pikachu dañado agregado: PS=%d/%d, Estado=%d" % [pikachu.ps_actuales, pikachu.ps_max, pikachu.estado])
		return true
	return false

## Cura completamente todos los Pokémon del equipo (para Centro Pokémon)
func curar_equipo_completo() -> void:
	var equipo = get_equipo()
	if not equipo:
		print("❌ No se puede curar: equipo no encontrado")
		return

	for pokemon in equipo:
		if pokemon is BasePokemon:
			# Restaurar PS al máximo
			pokemon.estad_ps_actual = pokemon.estad_ps
			# Establecer estado como NORMAL (-1)
			pokemon.estado = Singleton.ProblemaEstado.NORMAL
			# Restaurar PP de todos los movimientos
			for movimiento in pokemon.movimientos:
				if movimiento is Movimiento:
					movimiento.restaurar_pp()

	print("✅ Equipo curado completamente")

## === SISTEMA DE BANDERAS ===

func set_flag(nombre: String, valor: bool):
	datos_vivos.datos_persistentes.banderas[nombre] = valor
	# bandera_cambiada.emit(nombre, valor)
	_logear("Bandera '%s' = %s" % [nombre, valor], true)

## Obtiene el valor de una bandera.
## Si no existe, devuelve false.
func get_flag(nombre: String) -> bool:
	return datos_vivos.datos_persistentes.banderas.get(nombre, false)

func toggle_flag(nombre: String):
	var valor_actual = get_flag(nombre)
	set_flag(nombre, not valor_actual)

func has_flag(nombre: String) -> bool:
	var banderas_globales = datos_vivos.datos_persistentes.banderas.keys()
	return nombre in banderas_globales

func delete_flag(nombre: String):
	if has_flag(nombre):
		datos_vivos.datos_persistentes.banderas.erase(nombre)

## === BANDERAS TEMPORALES (FLAG_TEMP_* de pokeruby) ===
## Almacén aparte de las banderas normales: solo guarda las que valen true y se
## vacía con `limpiar_temporales()`. Va dentro de `datos_persistentes`, así que
## se escribe en la partida igual que en Rubí (los flags 0x0-0x1F viajan en
## SaveBlock1 y `CB2_ContinueSavedGame` no los borra), pero AdministradorMapa
## las limpia en los mismos momentos que ClearTempFieldEventData:
## `LoadMapFromCameraTransition` (cruzar el borde entre dos mapas del Overworld)
## y `sub_8053994` (cualquier warp: puertas, VUELO, TELETRANSPORTE, derrota...).
## No se limpian al volver de un menú o de una batalla ni al cargar la partida.

const CLAVE_BANDERAS_TEMPORALES: String = "banderas_temporales"

func _temporales() -> Dictionary:
	var persistentes: Dictionary = datos_vivos.datos_persistentes
	if not (persistentes.get(CLAVE_BANDERAS_TEMPORALES) is Dictionary):
		persistentes[CLAVE_BANDERAS_TEMPORALES] = {}
	return persistentes[CLAVE_BANDERAS_TEMPORALES]

## FlagSet/FlagClear de una FLAG_TEMP_*. Un valor false borra la entrada.
func set_flag_temporal(nombre: String, valor: bool = true) -> void:
	if valor:
		_temporales()[nombre] = true
	else:
		_temporales().erase(nombre)
	_logear("Bandera temporal '%s' = %s" % [nombre, valor], true)

## FlagGet de una FLAG_TEMP_*. Si no existe, false.
func get_flag_temporal(nombre: String) -> bool:
	return bool(_temporales().get(nombre, false))

## Claves temporales activas que empiezan por `prefijo` (todas si va vacío).
func claves_temporales(prefijo: String = "") -> PackedStringArray:
	var claves := PackedStringArray()
	for clave: String in _temporales():
		if prefijo.is_empty() or clave.begins_with(prefijo):
			claves.append(clave)
	return claves

## ClearTempFieldEventData: vacía el almacén y avisa con `temporales_limpiados`.
func limpiar_temporales() -> void:
	_temporales().clear()
	_logear("Banderas temporales limpiadas", true)
	temporales_limpiados.emit()

## === LUGARES VISITADOS (VUELO) ===
## Equivalente a FLAG_VISITED_<PUEBLO> de pokeruby: cada pueblo/ciudad fija su
## bandera al entrar (MAP_SCRIPT_ON_TRANSITION) y el mapa de VUELO solo deja
## elegir los visitados. Se guarda como bandera "visitado_<clave_mapa>" (clave =
## nombre base de la escena, la misma que `vuelo_destino.mapa`), así las
## partidas antiguas sin esas banderas cargan sin migración.

const PREFIJO_BANDERA_VISITADO: String = "visitado_"
## Villa Raíz cuenta como visitada desde el principio (el jugador empieza allí),
## también en partidas antiguas que no tienen la bandera.
const LUGAR_VISITADO_INICIAL: String = "villa_raiz"

## Caché de mapas destino de VUELO (region_map_metadata.json); vacía = sin cargar.
var _mapas_destino_vuelo: PackedStringArray = []

## Marca el mapa `clave` como visitado. Idempotente.
func marcar_lugar_visitado(clave: String) -> void:
	var clave_norm := _clave_lugar_visitado(clave)
	if clave_norm.is_empty():
		return
	_inicializar_datos_persistentes()
	var bandera := PREFIJO_BANDERA_VISITADO + clave_norm
	if not get_flag(bandera):
		set_flag(bandera, true)

## ¿El jugador visitó el mapa `clave`? Villa Raíz siempre cuenta como visitada.
func lugar_visitado(clave: String) -> bool:
	var clave_norm := _clave_lugar_visitado(clave)
	if clave_norm.is_empty():
		return false
	if clave_norm == LUGAR_VISITADO_INICIAL:
		return true
	var banderas: Variant = datos_vivos.datos_persistentes.get("banderas", {})
	return banderas is Dictionary and bool(banderas.get(PREFIJO_BANDERA_VISITADO + clave_norm, false))

## ¿`clave` es el mapa de algún destino de VUELO? Solo esos se marcan visitados.
func es_destino_vuelo(clave: String) -> bool:
	if _mapas_destino_vuelo.is_empty():
		var metadata := RegionMapMetadata.new()
		if metadata.cargar() != OK:
			push_warning("[SISTEMA_GUARDADO] Sin destinos de VUELO: %s" % metadata.ultimo_error)
			return false
		_mapas_destino_vuelo = metadata.mapas_destino_vuelo()
	return _mapas_destino_vuelo.has(_clave_lugar_visitado(clave))

func _clave_lugar_visitado(clave: String) -> String:
	return clave.strip_edges().to_lower()

## === SISTEMA DE DATOS PERSISTENTES ===

## Inicializar estructura de datos persistentes.
## Agrega las secciones vacías si no las tiene: banderas, contadores, timestamps, textos, decimales
func _inicializar_datos_persistentes():
	if not datos_vivos.datos_persistentes.has("banderas"):
		datos_vivos.datos_persistentes["banderas"] = {}
	if not datos_vivos.datos_persistentes.has("contadores"):
		datos_vivos.datos_persistentes["contadores"] = {}
	if not datos_vivos.datos_persistentes.has("timestamps"):
		datos_vivos.datos_persistentes["timestamps"] = {}
	if not datos_vivos.datos_persistentes.has("textos"):
		datos_vivos.datos_persistentes["textos"] = {}
	if not datos_vivos.datos_persistentes.has("decimales"):
		datos_vivos.datos_persistentes["decimales"] = {}
	if not datos_vivos.datos_persistentes.has(CLAVE_BANDERAS_TEMPORALES):
		datos_vivos.datos_persistentes[CLAVE_BANDERAS_TEMPORALES] = {}

## === CONTADORES ===
func get_contador(nombre: String, por_defecto: int = 0) -> int:
	return datos_vivos.datos_persistentes.contadores.get(nombre, por_defecto)

func set_contador(nombre: String, valor: int):
	datos_vivos.datos_persistentes.contadores[nombre] = valor
	_logear("Contador '%s' = %d" % [nombre, valor], true)

func incrementar_contador(nombre: String, cantidad: int = 1) -> int:
	var nuevo_valor = get_contador(nombre) + cantidad
	set_contador(nombre, nuevo_valor)
	return nuevo_valor

func decrementar_contador(nombre: String, cantidad: int = 1) -> int:
	var nuevo_valor = max(0, get_contador(nombre) - cantidad)
	set_contador(nombre, nuevo_valor)
	return nuevo_valor

func reset_contador(nombre: String):
	set_contador(nombre, 0)

## === TIMESTAMPS ===
func get_timestamp(nombre: String) -> int:
	return datos_vivos.datos_persistentes.timestamps.get(nombre, 0)

func set_timestamp(nombre: String, valor: int = -1):
	var tiempo: int
	if valor >= 0:
		tiempo = valor
	else:
		tiempo = int(Time.get_unix_time_from_system())
	datos_vivos.datos_persistentes.timestamps[nombre] = tiempo
	_logear("Timestamp '%s' = %d" % [nombre, tiempo], true)

func get_tiempo_transcurrido(nombre: String) -> int:
	## Retorna segundos transcurridos desde el timestamp
	var timestamp = get_timestamp(nombre)
	if timestamp == 0:
		return -1  ## No existe el timestamp
	return int(Time.get_unix_time_from_system()) - timestamp

func ha_pasado_tiempo(nombre: String, segundos: int) -> bool:
	var transcurrido = get_tiempo_transcurrido(nombre)
	return transcurrido >= segundos if transcurrido >= 0 else false

## === TEXTOS ===
func get_texto(nombre: String) -> String:
	return datos_vivos.datos_persistentes.textos.get(nombre, "")

func set_texto(nombre: String, valor: String):
	datos_vivos.datos_persistentes.textos[nombre] = valor
	_logear("Texto '%s' = '%s'" % [nombre, valor], true)

## ¿Se guardó alguna vez el texto `nombre` (aunque sea "")?
func has_texto(nombre: String) -> bool:
	return datos_vivos.datos_persistentes.textos.has(nombre)

## === DECIMALES ===
func get_decimal(nombre: String) -> float:
	return datos_vivos.datos_persistentes.decimales.get(nombre, 0.0)

func set_decimal(nombre: String, valor: float):
	datos_vivos.datos_persistentes.decimales[nombre] = valor
	_logear("Decimal '%s' = %.2f" % [nombre, valor], true)

func incrementar_decimal(nombre: String, cantidad: float = 1.0) -> float:
	var nuevo_valor = get_decimal(nombre) + cantidad
	set_decimal(nombre, nuevo_valor)
	return nuevo_valor

## === GUARDERÍA ===

## Guardería de Ruta 117, creada de forma perezosa desde `datos_vivos.guarderia`.
func get_guarderia() -> Guarderia:
	if _guarderia == null or _guarderia_origen != datos_vivos:
		_guarderia = Guarderia.new()
		_guarderia.from_dict(datos_vivos.guarderia)
		_guarderia_origen = datos_vivos
	return _guarderia

## Descarta la guardería cacheada (al cargar o empezar partida).
func reiniciar_guarderia() -> void:
	_guarderia = null
	_guarderia_origen = null

## Vuelca la guardería viva en `datos_vivos.guarderia` antes de guardar.
func _sincronizar_guarderia() -> void:
	if _guarderia != null and _guarderia_origen == datos_vivos:
		datos_vivos.guarderia = _guarderia.to_dict()

## Registro de concursos (pósters, museo, premios), creado de forma perezosa desde
## `datos_vivos.concursos`.
func get_registro_concursos() -> RegistroConcursos:
	if _concursos == null or _concursos_origen != datos_vivos:
		_concursos = RegistroConcursos.from_dict(datos_vivos.concursos)
		_concursos_origen = datos_vivos
	return _concursos

func reiniciar_concursos() -> void:
	_concursos = null
	_concursos_origen = null

## Vuelca el registro vivo en `datos_vivos.concursos` antes de guardar.
func _sincronizar_concursos() -> void:
	if _concursos != null and _concursos_origen == datos_vivos:
		datos_vivos.concursos = _concursos.to_dict()

## === POKéCUBOS ===

## CAJA POKéCUBOS (40 huecos), creada de forma perezosa desde `datos_vivos.pokecubos`.
## Partidas sin bloque de pokécubos cargan con el estuche vacío.
func obtener_estuche_pokecubos() -> EstuchePokecubos:
	if _estuche_pokecubos == null or _estuche_pokecubos_origen != datos_vivos:
		_estuche_pokecubos = EstuchePokecubos.from_dict(datos_vivos.pokecubos)
		_estuche_pokecubos_origen = datos_vivos
	return _estuche_pokecubos

## Descarta el estuche cacheado (al cargar o empezar partida).
func reiniciar_estuche_pokecubos() -> void:
	_estuche_pokecubos = null
	_estuche_pokecubos_origen = null

## Vuelca el estuche vivo en `datos_vivos.pokecubos` antes de guardar.
func _sincronizar_estuche_pokecubos() -> void:
	if _estuche_pokecubos != null and _estuche_pokecubos_origen == datos_vivos:
		datos_vivos.pokecubos = _estuche_pokecubos.to_dict()

## === REVANCHAS ===

## Revanchas de entrenadores, creadas de forma perezosa desde `datos_vivos.revanchas`.
func get_revanchas() -> SistemaRevanchas:
	if _revanchas == null or _revanchas_origen != datos_vivos:
		_revanchas = SistemaRevanchas.new()
		_revanchas.from_dict(datos_vivos.revanchas)
		_revanchas_origen = datos_vivos
	return _revanchas

## Descarta las revanchas cacheadas (al cargar o empezar partida).
func reiniciar_revanchas() -> void:
	_revanchas = null
	_revanchas_origen = null

## Vuelca las revanchas vivas en `datos_vivos.revanchas` antes de guardar.
func _sincronizar_revanchas() -> void:
	if _revanchas != null and _revanchas_origen == datos_vivos:
		datos_vivos.revanchas = _revanchas.to_dict()


## Estado local de base propia y decoración, reconstruido al sustituir datos_vivos.
func get_bases_secretas() -> SistemaBasesSecretas:
	if _bases_secretas == null or _bases_secretas_origen != datos_vivos:
		_bases_secretas = SistemaBasesSecretas.new()
		_bases_secretas.from_dict(datos_vivos.bases_secretas)
		_bases_secretas_origen = datos_vivos
	return _bases_secretas


func reiniciar_bases_secretas() -> void:
	_bases_secretas = null
	_bases_secretas_origen = null


## Una versión desconocida permanece intacta en la estructura; no degradarla al guardar.
func _sincronizar_bases_secretas() -> void:
	if _bases_secretas != null and _bases_secretas_origen == datos_vivos \
		and _bases_secretas.es_compatible():
		datos_vivos.bases_secretas = _bases_secretas.to_dict()


## Medallas conseguidas (`jugador["medallas"]` es un array de bool).
func contar_medallas() -> int:
	var medallas: Variant = datos_vivos.jugador.get("medallas", [])
	return medallas.count(true) if medallas is Array else 0

## FlagGet(FLAG_BADGE01_GET + indice): ¿tiene la medalla `indice` (0 = Piedra)?
func tiene_medalla(indice: int) -> bool:
	var medallas: Variant = datos_vivos.jugador.get("medallas", [])
	return medallas is Array and indice >= 0 and indice < (medallas as Array).size() and bool((medallas as Array)[indice])

## === UTILIDADES ===
func limpiar_datos_persistentes():
	## Limpia todos los datos persistentes (usar con cuidado): vuelve a la
	## estructura por defecto de EstructuraGuardado, banderas incluidas.
	## (datos_vivos es un Resource: no tiene has(), el campo siempre existe.)
	if datos_vivos == null:
		return
	datos_vivos.datos_persistentes = EstructuraGuardado.new().datos_persistentes.duplicate(true)
	_logear("Datos persistentes limpiados")

func exportar_datos_persistentes() -> Dictionary:
	## Para debug - obtener una copia de todos los datos persistentes
	_inicializar_datos_persistentes()
	return datos_vivos.datos_persistentes.duplicate(true)

## === FUNCIONES AUXILIARES PARA NPCs ===

## Obtiene el dinero del jugador
func get_dinero_jugador() -> int:
	return datos_vivos.jugador.dinero

## Da dinero al jugador
func dar_dinero_jugador(cantidad: int):
	datos_vivos.jugador.dinero += cantidad
	_logear("Jugador obtuvo %d$ (Total: %d$)" % [cantidad, datos_vivos.jugador.dinero], true)

## Quita dinero al jugador
func quitar_dinero_jugador(cantidad: int) -> bool:
	if datos_vivos.jugador.dinero >= cantidad:
		datos_vivos.jugador.dinero -= cantidad
		_logear("Jugador gastó %d$ (Restante: %d$)" % [cantidad, datos_vivos.jugador.dinero])
		return true
	else:
		_logear("Jugador no tiene suficiente dinero (%d$ necesario, %d$ disponible)" % [cantidad, datos_vivos.jugador.dinero])
		return false


# === SISTEMA DE INVENTARIO ===

## Inicializa la estructura completa de la mochila si no existe
func inicializar_mochila_estructura() -> void:
	if typeof(datos_vivos.mochila) != TYPE_DICTIONARY or not datos_vivos.mochila.has("bolsillos"):
		datos_vivos.mochila = {
			"sexo": "F",
			"bolsillos": {
				"0": {"items": []},
				"1": {"items": []},
				"2": {"items": []},
				"3": {"items": []},
				"4": {"items": []}
			}
		}
		_logear("Estructura de mochila inicializada", true)

## Obtiene el icono de un objeto
func _get_icono_objeto(objeto_id: String) -> String:
	var iconos = {
		"1 CORTE": "[img]res://UI/mochila/txt_mo.png[/img]",
		"2 VUELO": "[img]res://UI/mochila/txt_mo.png[/img]",
		"3 SURF": "[img]res://UI/mochila/txt_mo.png[/img]"
	}
	return iconos.get(objeto_id, "")

## Obtiene todos los datos de un objeto desde caché local, base de datos o fallback.
## {"nombre_interno", "nombre", "icono", "descripcion", "bolsillo_id", "bolsillo_nombre", "precio", "orden"}
func obtener_datos_objeto_completos(nombre_interno: String) -> Dictionary:
	# 1. Verificar primero en el caché local
	nombre_interno = nombre_interno.strip_edges().to_upper()
	if cache_objetos.has(nombre_interno):
		var datos_cache = cache_objetos[nombre_interno]
		_logear("Objeto '%s' del caché" % nombre_interno, true)
		return datos_cache

	var datos_objeto = {
		"nombre_interno": nombre_interno,
		"nombre": nombre_interno,
		"icono": _get_icono_objeto(nombre_interno),
		"descripcion": "",
		"bolsillo_id": -1,
		"bolsillo_nombre": "",
		"precio": 10,
		"orden": 0,
		"usable_in_battle": false,
		"uso_campo": "",  # Objetos.uso_campo ("" si NULL); ver UsoObjetosCampo
	}

	# 2. Consultar base de datos si está disponible
	if DatabaseManager and DatabaseManager.esta_conectado():
		var nombres_bolsillos = DatabaseManager.obtener_nombres_bolsillos()
		var datos_bd = DatabaseManager.obtener_datos_objeto(nombre_interno)
		if not datos_bd.is_empty():
			# Usar datos de la base de datos
			datos_objeto.nombre = datos_bd.get("nombre", nombre_interno).strip_edges().to_upper()
			datos_objeto.descripcion = datos_bd.get("descripcion", datos_objeto.descripcion)
			# Los datos incompletos pueden traer NULL desde SQLite.
			# Conservar -1 si no pertenecen a uno de los cinco bolsillos activos.
			var bolsillo_bd: Variant = datos_bd.get("bolsillo_id")
			if bolsillo_bd is int and bolsillo_bd >= 1 and bolsillo_bd <= nombres_bolsillos.size():
				datos_objeto.bolsillo_id = bolsillo_bd - 1  # BD: 1-5; mochila: 0-4.
				datos_objeto.bolsillo_nombre = nombres_bolsillos[datos_objeto.bolsillo_id].nombre
			datos_objeto.precio = datos_bd.get("precio", 10)
			datos_objeto.orden = datos_bd.get("orden", 0)
			datos_objeto.usable_in_battle = bool(datos_bd.get("usable_in_battle", false))
			var uso_campo_bd: Variant = datos_bd.get("uso_campo")
			datos_objeto.uso_campo = uso_campo_bd if uso_campo_bd is String else ""

			_logear("Objeto '%s' de la BD" % nombre_interno, true)
		else:
			_logear("Objeto '%s' no encontrado en BD, usando datos fallback" % nombre_interno)
	else:
		_logear("BD no disponible, usando datos fallback para objeto '%s'" % nombre_interno)

	# 3. Guardar en caché para futuros accesos
	cache_objetos[nombre_interno] = datos_objeto

	return datos_objeto

## Limpia el caché de objetos (útil para recargar datos desde BD)
func limpiar_cache_objetos():
	cache_objetos.clear()
	_logear("Caché de objetos limpiado", true)

## Expande un item simple (nombre_interno + cantidad) con todos los datos necesarios
func _expandir_item_con_datos_completos(item_simple: Dictionary) -> Dictionary:
	var datos_completos = obtener_datos_objeto_completos(item_simple.nombre_interno)
	return {
		"nombre_interno": datos_completos.nombre_interno,
		"nombre": datos_completos.nombre,
		"icono": datos_completos.icono,
		"descripcion": datos_completos.descripcion,
		"cantidad": int(item_simple.cantidad),
		"bolsillo_id": datos_completos.bolsillo_id,
		"bolsillo_nombre": datos_completos.bolsillo_nombre,
		"usable_in_battle": datos_completos.usable_in_battle,
		"uso_campo": datos_completos.get("uso_campo", ""),
	}

## Añade un objeto al bolsillo específico de la mochila
func dar_objeto_jugador(objeto_id: String, cantidad: int = 1) -> Dictionary:

	objeto_id = objeto_id.strip_edges().to_upper()
	var datos_objeto = obtener_datos_objeto_completos(objeto_id)
	var resultado = {"bolsillo_nombre": datos_objeto.bolsillo_nombre, "bolsillo_id": datos_objeto.bolsillo_id, "exito": true, "mensaje": ""}

	var bolsillo_str = str(datos_objeto.bolsillo_id)
	var items = datos_vivos.mochila.bolsillos[bolsillo_str].items

	# Buscar si el objeto ya existe
	var objeto_existente = null
	for item in items:
		if item.nombre_interno == objeto_id:
			objeto_existente = item
			break

	if objeto_existente:
		objeto_existente.cantidad += cantidad
	else:
		# Crear nuevo objeto con estructura simplificada
		var nuevo_item = {
			"nombre_interno": objeto_id,
			"cantidad": cantidad
		}
		items.append(nuevo_item)
		if int(bolsillo_str) in BOLSILLOS_ORDEN_AUTOMATICO:
			ordenar_bolsillo(int(bolsillo_str))

	_logear("Jugador obtuvo %d x %s en bolsillo %s" % [cantidad, objeto_id, datos_objeto.bolsillo_nombre], true)
	return resultado

## Quita un objeto del bolsillo específico de la mochila
func quitar_objeto_jugador(objeto_id: String, cantidad: int = 1, bolsillo: int = 0) -> bool:
	if not tiene_objeto(objeto_id, cantidad, bolsillo):
		return false

	var bolsillo_str = str(bolsillo)
	var items = datos_vivos.mochila.bolsillos[bolsillo_str].items

	for i in range(items.size()):
		var item = items[i]
		if item.nombre_interno == objeto_id:
			item.cantidad -= cantidad
			if item.cantidad <= 0:
				items.remove_at(i)
			break

	_logear("Jugador perdió %d x %s del bolsillo %d" % [cantidad, objeto_id, bolsillo], true)
	return true

## Bolsillos que Ruby ordena solos por número de objeto (SortItemSlots en
## item_menu.c): MT/MO (2) y Bayas (3). En ellos no se ordena con SELECT.
const BOLSILLOS_ORDEN_AUTOMATICO: Array[int] = [2, 3]

## Intercambia dos objetos de un bolsillo (SELECT en la mochila, sub_80A3E70).
func intercambiar_objetos(bolsillo: int, a: int, b: int) -> bool:
	var bolsillo_str: String = str(bolsillo)
	if not datos_vivos.mochila.has("bolsillos") or not datos_vivos.mochila.bolsillos.has(bolsillo_str):
		return false
	var items: Array = datos_vivos.mochila.bolsillos[bolsillo_str].items
	if a < 0 or b < 0 or a >= items.size() or b >= items.size():
		return false
	var temporal = items[a]
	items[a] = items[b]
	items[b] = temporal
	return true

func ordenar_bolsillos_automaticos() -> void:
	for bolsillo: int in BOLSILLOS_ORDEN_AUTOMATICO:
		ordenar_bolsillo(bolsillo)

## Ordena un bolsillo como SortItemSlots: MT01..MT50 y luego MO01..MO08; las
## bayas por su número (tabla Bayas); el resto por id de la tabla Objetos.
func ordenar_bolsillo(bolsillo: int) -> void:
	var bolsillo_str: String = str(bolsillo)
	if not datos_vivos.mochila.has("bolsillos") or not datos_vivos.mochila.bolsillos.has(bolsillo_str):
		return
	var items: Array = datos_vivos.mochila.bolsillos[bolsillo_str].items
	var claves: Dictionary = {}
	for item in items:
		var nombre_interno: String = str(item.nombre_interno)
		claves[nombre_interno] = _clave_orden(bolsillo, nombre_interno)
	items.sort_custom(func(x, y) -> bool:
		return claves[str(x.nombre_interno)] < claves[str(y.nombre_interno)])

func _clave_orden(bolsillo: int, nombre_interno: String) -> int:
	var nombre: String = nombre_interno.to_upper()
	if bolsillo == 2:
		var numero: int = nombre.substr(2).to_int()
		if nombre.begins_with("MT") or nombre.begins_with("TM"):
			return numero
		if nombre.begins_with("MO") or nombre.begins_with("HM"):
			return 100 + numero
	var id: int = int(DatabaseManager.obtener_datos_objeto(nombre_interno).get("id", 0))
	if bolsillo == 3:
		var numero_baya: int = int(DatabaseManager.obtener_datos_baya(id).get("numero", 0))
		if numero_baya > 0:
			return numero_baya
	# Sin número propio (p. ej. bayas de 4ª gen): detrás, por id.
	return 1000 + id

## Verifica si el jugador tiene cierta cantidad de un objeto en un bolsillo específico
func tiene_objeto(objeto_id: String, cantidad: int = 1, bolsillo: int = 0) -> bool:

	var bolsillo_str = str(bolsillo)
	if not datos_vivos.mochila.bolsillos.has(bolsillo_str):
		return false

	var items = datos_vivos.mochila.bolsillos[bolsillo_str].items
	for item in items:
		if item.nombre_interno == objeto_id:
			return item.cantidad >= cantidad

	return false

## Obtiene la cantidad de un objeto específico en un bolsillo
func get_cantidad_objeto(objeto_id: String, bolsillo: int = 0) -> int:

	var bolsillo_str = str(bolsillo)
	if not datos_vivos.mochila.bolsillos.has(bolsillo_str):
		return 0

	var items = datos_vivos.mochila.bolsillos[bolsillo_str].items
	for item in items:
		if item.nombre_interno == objeto_id:
			return item.cantidad

	return 0

## Devuelve la estructura completa de la mochila con datos expandidos
func get_inventario() -> Dictionary:
	# Las pruebas de batalla pueden ejecutarse sin partida guardada; garantizar
	# aquí la estructura evita que los consumidores tengan que conocer ese caso.
	inicializar_mochila_estructura()

	var inventario_expandido = datos_vivos.mochila.duplicate()

	# Expandir cada bolsillo con los datos completos de los objetos
	for bolsillo_key in inventario_expandido.bolsillos.keys():
		var bolsillo = inventario_expandido.bolsillos[bolsillo_key]
		var items_expandidos = []

		for item_simple in bolsillo.items:
			var item_expandido = _expandir_item_con_datos_completos(item_simple)
			items_expandidos.append(item_expandido)

		bolsillo.items = items_expandidos

	return inventario_expandido

## Obtiene los datos de un bolsillo específico con objetos expandidos
func get_bolsillo(bolsillo: int) -> Dictionary:

	var bolsillo_str = str(bolsillo)
	if datos_vivos.mochila.bolsillos.has(bolsillo_str):
		var bolsillo_data = datos_vivos.mochila.bolsillos[bolsillo_str].duplicate()

		# Expandir items con datos completos
		var items_expandidos = []
		for item_simple in bolsillo_data.items:
			var item_expandido = _expandir_item_con_datos_completos(item_simple)
			items_expandidos.append(item_expandido)

		bolsillo_data.items = items_expandidos

		# Convertir "cifras" a "decimales" para compatibilidad
		if bolsillo_data.has("cifras"):
			bolsillo_data.decimales = bolsillo_data.cifras
			bolsillo_data.erase("cifras")

		return bolsillo_data

	return {"decimales": 0, "items": []}

## Establece el sexo para el diseño de la mochila
func set_mochila_sexo(sexo: String):
	datos_vivos.mochila.sexo = sexo

## Obtiene el sexo para el diseño de la mochila
func get_mochila_sexo() -> String:
	return datos_vivos.mochila.get("sexo", "F")

## === GESTIÓN DE CAJAS PC ===

## Tamaño máximo del equipo (pokeruby PARTY_SIZE).
const MAX_POKEMON_EQUIPO: int = 6
## Número de cajas del PC (pokeruby TOTAL_BOXES_COUNT).
const TOTAL_CAJAS_PC: int = 14
## Slots por caja del PC (pokeruby IN_BOX_COUNT).
const SLOTS_POR_CAJA_PC: int = 30

## Destino de un Pokémon recibido (pokeruby GiveMonToPlayer:
## MON_GIVEN_TO_PARTY / MON_GIVEN_TO_PC / MON_CANT_GIVE).
enum DestinoPokemon { EQUIPO, PC, SIN_ESPACIO }

## Inicializa las cajas PC si no existen.
func inicializar_cajas_pc() -> void:
	if datos_vivos.cajas_pc.is_empty():
		print("📦 [SISTEMA_GUARDADO] Inicializando cajas PC...")
		# Crear 14 cajas vacías, cada una con 30 slots
		for i in range(TOTAL_CAJAS_PC):
			var caja = []
			caja.resize(SLOTS_POR_CAJA_PC)
			for j in range(SLOTS_POR_CAJA_PC):
				caja[j] = null  # Inicializar todos los slots como vacíos
			datos_vivos.cajas_pc.append(caja)
		print("📦 [SISTEMA_GUARDADO] %d cajas PC creadas" % datos_vivos.cajas_pc.size())
	_normalizar_cajas_pc()

## Deja exactamente TOTAL_CAJAS_PC cajas de SLOTS_POR_CAJA_PC slots. La pantalla
## de cajas llegó a manejar 16 cajas: los Pokémon de cajas (o slots) sobrantes
## de partidas antiguas pasan al primer hueco libre de las cajas reales y, si no
## caben, se conservan en cajas extra al final (nunca se descartan; se vuelven a
## recolocar en cuanto haya sitio). Esas cajas extra no reciben capturas.
func _normalizar_cajas_pc() -> void:
	var cajas: Array = datos_vivos.cajas_pc
	var sobrantes: Array[BasePokemon] = []
	for i in range(cajas.size()):
		if not (cajas[i] is Array):
			cajas[i] = []
		var caja: Array = cajas[i]
		var inicio_sobrante: int = SLOTS_POR_CAJA_PC if i < TOTAL_CAJAS_PC else 0
		for slot in range(inicio_sobrante, caja.size()):
			if caja[slot] is BasePokemon:
				sobrantes.append(caja[slot])
	if sobrantes.is_empty() and cajas.size() == TOTAL_CAJAS_PC and cajas.all(func(c: Array) -> bool: return c.size() == SLOTS_POR_CAJA_PC):
		return

	cajas.resize(TOTAL_CAJAS_PC)
	for i in range(TOTAL_CAJAS_PC):
		if not (cajas[i] is Array):
			cajas[i] = []
		cajas[i].resize(SLOTS_POR_CAJA_PC)
	if datos_vivos.indice_caja_activa < 0 or datos_vivos.indice_caja_activa >= TOTAL_CAJAS_PC:
		datos_vivos.indice_caja_activa = 0

	var sin_hueco: Array[BasePokemon] = []
	for pokemon in sobrantes:
		var hueco := _buscar_hueco_en_cajas(cajas)
		if hueco.x < 0:
			sin_hueco.append(pokemon)
		else:
			cajas[hueco.x][hueco.y] = pokemon
	for inicio in range(0, sin_hueco.size(), SLOTS_POR_CAJA_PC):
		var caja_extra: Array = []
		caja_extra.assign(sin_hueco.slice(inicio, inicio + SLOTS_POR_CAJA_PC))
		caja_extra.resize(SLOTS_POR_CAJA_PC)
		cajas.append(caja_extra)
	if not sobrantes.is_empty():
		_logear("📦 %d Pokémon de cajas antiguas recolocados (%d sin hueco)" % [sobrantes.size() - sin_hueco.size(), sin_hueco.size()])

## Obtiene todas las cajas PC.
func obtener_cajas_pc() -> Array:
	inicializar_cajas_pc()
	return datos_vivos.cajas_pc

## Obtiene una caja específica.
func obtener_caja_pc(caja_index: int) -> Array:
	inicializar_cajas_pc()
	if caja_index >= 0 and caja_index < datos_vivos.cajas_pc.size():
		return datos_vivos.cajas_pc[caja_index]
	return []

## Establece los datos de una caja específica.
func establecer_caja_pc(caja_index: int, datos_caja: Array) -> void:
	inicializar_cajas_pc()
	if caja_index >= 0 and caja_index < datos_vivos.cajas_pc.size():
		datos_vivos.cajas_pc[caja_index] = datos_caja.duplicate()
		print("📦 [SISTEMA_GUARDADO] Caja %d actualizada con %d Pokémon" % [caja_index, _contar_pokemon_en_caja(datos_caja)])

## Recibe un Pokémon capturado conservando la MISMA instancia (IVs,
## naturaleza, movimientos, PS, estado, variocolor, sexo...). Asigna al
## jugador como entrenador original; `encuentro_bola`, `encuentro_nivel` y
## `encuentro_lugar` deben venir ya fijados por quien llama.
## Va al equipo si hay hueco; si no, al primer slot libre del PC empezando por
## la caja activa y dando la vuelta por todas las cajas (pokeruby
## GiveMonToPlayer/SendMonToPC, src/pokemon_2.c).
## Devuelve {"destino": DestinoPokemon, "caja": int, "slot": int}; "caja" es
## -1 salvo en PC y "slot" es -1 si no se pudo guardar.
func recibir_pokemon_capturado(pokemon: BasePokemon) -> Dictionary:
	var resultado := {"destino": DestinoPokemon.SIN_ESPACIO, "caja": -1, "slot": -1}
	if pokemon == null:
		return resultado

	_asignar_jugador_como_entrenador_original(pokemon)
	# Estado exclusivo de batalla: no debe viajar con el Pokémon.
	pokemon.indice_orden_original = -1

	if datos_vivos.equipo_pokemon.size() < MAX_POKEMON_EQUIPO:
		datos_vivos.equipo_pokemon.append(pokemon)
		resultado["destino"] = DestinoPokemon.EQUIPO
		resultado["slot"] = datos_vivos.equipo_pokemon.size() - 1
		_logear("%s recibido en el equipo (%d/%d)" % [pokemon.nombre_interno, datos_vivos.equipo_pokemon.size(), MAX_POKEMON_EQUIPO])
		return resultado

	var hueco := _buscar_hueco_libre_pc()
	if hueco.x < 0:
		_logear("❌ %s no cabe: equipo y cajas del PC llenos" % pokemon.nombre_interno)
		return resultado

	_preparar_pokemon_para_caja(pokemon)
	var caja: Array = datos_vivos.cajas_pc[hueco.x]
	if caja.size() < SLOTS_POR_CAJA_PC:
		caja.resize(SLOTS_POR_CAJA_PC)
	caja[hueco.y] = pokemon
	resultado["destino"] = DestinoPokemon.PC
	resultado["caja"] = hueco.x
	resultado["slot"] = hueco.y
	_logear("📦 %s enviado al PC: caja %d, slot %d" % [pokemon.nombre_interno, hueco.x, hueco.y])
	return resultado

## true si el equipo está completo y no queda ningún slot libre en las cajas
## del PC (pokeruby PlayerPartyAndPokemonStorageFull).
func almacenamiento_lleno() -> bool:
	if datos_vivos.equipo_pokemon.size() < MAX_POKEMON_EQUIPO:
		return false
	return _buscar_hueco_libre_pc().x < 0

## Primer slot libre (x = caja, y = slot) recorriendo las cajas desde la activa
## y dando la vuelta; Vector2i(-1, -1) si están todas llenas. Un slot `null`
## o fuera del tamaño guardado de la caja cuenta como libre.
func _buscar_hueco_libre_pc() -> Vector2i:
	return _buscar_hueco_en_cajas(obtener_cajas_pc())

## Como `_buscar_hueco_libre_pc` sobre `cajas`, solo en las TOTAL_CAJAS_PC
## cajas reales (las extra de partidas antiguas no son visibles en el PC).
func _buscar_hueco_en_cajas(cajas: Array) -> Vector2i:
	var total := mini(cajas.size(), TOTAL_CAJAS_PC)
	if total == 0:
		return Vector2i(-1, -1)
	var inicio := clampi(datos_vivos.indice_caja_activa, 0, total - 1)
	for desplazamiento in range(total):
		var indice_caja := (inicio + desplazamiento) % total
		var caja: Array = cajas[indice_caja]
		for slot in range(SLOTS_POR_CAJA_PC):
			if slot >= caja.size() or caja[slot] == null:
				return Vector2i(indice_caja, slot)
	return Vector2i(-1, -1)

## === POKéDEX ===
## `datos_vivos.pokedex` guarda listas de nombres internos en mayúsculas (sin
## repetir): así sobreviven al JSON sin la conversión int→float de los
## números y los lectores actuales solo usan `.size()`.

## Marca la especie como vista (pokeruby: al entrar el rival en combate).
## Idempotente.
func registrar_pokemon_visto(especie: String) -> void:
	# Antes de obtener la POKéDEX solo las capturas conservan registros.
	if not PokedexPartida.obtenida():
		return
	_agregar_a_pokedex("vistos", especie)

## Marca la especie como atrapada, y por tanto también vista. Idempotente.
func registrar_pokemon_atrapado(especie: String) -> void:
	_agregar_a_pokedex("vistos", especie)
	_agregar_a_pokedex("atrapados", especie)

## pokeruby atkF1_trysetcaughtmondexflags: la PRIMERA captura en combate de un
## SPINDA guarda su personalidad para el sprite de la POKéDEX (huevos,
## intercambios y regalos no la tocan). Llamarlo ANTES de
## registrar_pokemon_atrapado(): si la especie ya estaba atrapada no hace nada.
func registrar_personalidad_spinda_capturado(pokemon: BasePokemon) -> void:
	if pokemon == null:
		return
	ManchasSpinda.registrar_primera_captura(datos_vivos.pokedex, pokemon.nombre_interno,
			pokemon.personalidad, pokemon_atrapado(pokemon.nombre_interno))

## Personalidad del SPINDA de la POKéDEX (0 si nunca se atrapó ninguno). Para
## el sprite de la ficha, siempre con la paleta normal.
func personalidad_spinda_pokedex() -> int:
	return ManchasSpinda.personalidad_en_pokedex(datos_vivos.pokedex)

func pokemon_visto(especie: String) -> bool:
	return _lista_pokedex("vistos").has(_clave_pokedex(especie))

func pokemon_atrapado(especie: String) -> bool:
	return _lista_pokedex("atrapados").has(_clave_pokedex(especie))

func _agregar_a_pokedex(lista: String, especie: String) -> void:
	var clave := _clave_pokedex(especie)
	if clave.is_empty():
		return
	var registros := _lista_pokedex(lista)
	if not registros.has(clave):
		registros.append(clave)

## Devuelve (creándola si falta) la lista `lista` de la Pokédex viva.
func _lista_pokedex(lista: String) -> Array:
	if not (datos_vivos.pokedex.get(lista) is Array):
		datos_vivos.pokedex[lista] = []
	return datos_vivos.pokedex[lista]

func _clave_pokedex(especie: String) -> String:
	return especie.strip_edges().to_upper()

## Fija al jugador actual como entrenador original del Pokémon.
func _asignar_jugador_como_entrenador_original(pokemon: BasePokemon) -> void:
	var nombre := str(datos_vivos.jugador.get("nombre", "")).strip_edges()
	pokemon.entrenador_original = nombre if not nombre.is_empty() else "JUGADOR"
	pokemon.entrenador_id = int(datos_vivos.jugador.get("id", 0))
	pokemon.entrenador_sexo = str(datos_vivos.jugador.get("sexo", "M"))

## Un Pokémon que entra en una caja vuelve con los PP restaurados (pokeruby
## MonRestorePP en SendMonToPC). La BoxPokemon de Gen 3 tampoco guarda PS
## actuales ni problema de estado, así que se guarda curado.
func _preparar_pokemon_para_caja(pokemon: BasePokemon) -> void:
	for movimiento in pokemon.movimientos:
		if movimiento is Movimiento:
			movimiento.restaurar_pp()
	pokemon.estad_ps_actual = pokemon.estad_ps
	pokemon.estado = Singleton.ProblemaEstado.NORMAL

## Verifica si las cajas PC están vacías y genera datos de prueba si es necesario.
# func _verificar_y_generar_datos_prueba_cajas() -> void:
#   var cajas_vacias = true

#   # Verificar si hay algún Pokémon en las cajas
#   for caja in datos_vivos.cajas_pc:
#       for pokemon in caja:
#           if pokemon != null:
#               cajas_vacias = false
#               break
#       if not cajas_vacias:
#           break

#   # Si todas las cajas están vacías, generar datos de prueba
#   if cajas_vacias:
#       print("📦 [SISTEMA_GUARDADO] Cajas PC vacías, generando datos de prueba...")
#       generar_datos_prueba_cajas_pc()
#       # Guardar inmediatamente para persistir los datos de prueba
#       guardar_partida()
#       print("💾 [SISTEMA_GUARDADO] Datos de prueba guardados en archivo")

## Verifica si el equipo está vacío y genera Pokémon de prueba si es necesario.
# func _verificar_y_generar_equipo_prueba() -> void:
#   # Verificar si el equipo está vacío
#   if datos_vivos.equipo_pokemon.is_empty():
#       print("👥 [SISTEMA_GUARDADO] Equipo vacío, generando Pokémon de prueba...")
#       generar_equipo_inicial_prueba()
#       # Guardar inmediatamente para persistir los datos
#       guardar_partida()
#       print("💾 [SISTEMA_GUARDADO] Equipo de prueba guardado en archivo")

## Genera un equipo inicial con 2 Pokémon de prueba usando PokemonFactory.
func generar_equipo_inicial_prueba() -> void:
	print("👥 [SISTEMA_GUARDADO] Generando equipo inicial de prueba...")

	# Limpiar equipo actual por si acaso
	datos_vivos.equipo_pokemon.clear()

	# Crear 2 Pokémon iniciales usando PokemonFactory
	var especies_iniciales = ["TREECKO", "POOCHYENA"]  # Pokémon típicos de inicio

	for i in range(especies_iniciales.size()):
		var especie = especies_iniciales[i]

		# Crear configuración para PokemonFactory
		var config = PokemonFactory.ConfiguracionPokemon.new(
			especie,
			5,  # Nivel 5
			PokemonFactory.OrigenPokemon.LABORATORIO
		)

		# Configurar como Pokémon inicial
		config.entrenador_nombre = datos_vivos.jugador.nombre if datos_vivos.jugador.nombre != "" else "ASH"
		config.entrenador_id = datos_vivos.jugador.id
		config.lugar_encuentro = "LABORATORIO_PROF"
		config.pokeball_tipo = "POKEBALL"

		# Crear el Pokémon usando PokemonFactory
		var pokemon = PokemonFactory.crear_pokemon(config)

		if pokemon:
			datos_vivos.equipo_pokemon.append(pokemon)
			print("👥 [SISTEMA_GUARDADO] Pokémon inicial agregado: %s Nv.%d" % [pokemon.nombre_interno, pokemon.nivel])

	print("✅ [SISTEMA_GUARDADO] Equipo inicial generado: %d Pokémon" % datos_vivos.equipo_pokemon.size())


## Lee la sección opciones del archivo guardado y la aplica a datos_vivos.opciones
## sin tocar el resto del estado vivo. Para que el menú de inicio muestre los
## bordes y ajustes de la última partida guardada.
func cargar_opciones_en_datos_vivos() -> bool:
	if not has_partida_guardada():
		return false
	var archivo = FileAccess.open(archivo_guardado, FileAccess.READ)
	if archivo == null:
		return false
	var json_string = archivo.get_as_text()
	archivo.close()
	var json = JSON.new()
	if json.parse(json_string) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false
	var opciones_dict: Dictionary = json.data.get("opciones", {})
	if opciones_dict.is_empty():
		return false
	datos_vivos.opciones.from_dict(opciones_dict)
	_logear("✅ Opciones del guardado aplicadas a datos_vivos")
	return true


## Devuelve un resumen ligero leído directamente del archivo de guardado,
## sin tocar datos_vivos. Para pintar la caja CONTINUAR del menu de inicio.
func cargar_resumen_guardado() -> Dictionary:
	if not has_partida_guardada():
		return {}
	var archivo = FileAccess.open(archivo_guardado, FileAccess.READ)
	if archivo == null:
		return {}
	var json_string = archivo.get_as_text()
	archivo.close()

	var json = JSON.new()
	if json.parse(json_string) != OK or typeof(json.data) != TYPE_DICTIONARY:
		_logear("❌ Resumen de guardado ilegible")
		return {}

	var jugador: Dictionary = json.data.get("jugador", {})
	var pokedex: Dictionary = json.data.get("pokedex", {})
	var persistentes = json.data.get("datos_persistentes", {})
	var banderas: Dictionary = persistentes.get("banderas", {}) if persistentes is Dictionary else {}
	var atrapados: Array = pokedex.get("atrapados", []) if pokedex.get("atrapados", []) is Array else []
	var medallas = jugador.get("medallas", [])
	var medallas_conseguidas: int = medallas.count(true) if medallas is Array else 0
	var tiempo_segundos: int = int(json.data.get("tiempo_juego", 0))

	return {
		"nombre": str(jugador.get("nombre", "")),
		"sexo": str(jugador.get("sexo", "M")),
		"pokedex": PokedexPartida.contar_atrapados_resumen(atrapados, banderas),
		"tiempo": tiempo_segundos,
		"medallas": medallas_conseguidas,
	}


## Construye la plantilla de una partida nueva con los datos minimos para
## iniciar el juego, a partir de sexo y nombre elegidos. NO escribe disco ni
## toca datos_vivos; el estado vivo se aplica al arrancar con aplicar_plantilla().
func preparar_plantilla_partida_nueva(sexo: String, nombre: String) -> Dictionary:
	var plantilla := {
		"jugador": {
			"id": int(randi() % 90000 + 10000),
			"nombre": nombre,
			"sexo": sexo,
			"dinero": 3000,
			"medallas": [],
		},
		"posicion": {
			"mapa_actual": "camion",
			"cx": 7,
			"cy": 7,
			"capa_datos": 0,
			"nombre_lugar": "CAMION",
		},
		"punto_curacion": EstructuraGuardado.PUNTO_CURACION_POR_DEFECTO.duplicate(true),
		"opciones": {
			"velocidad_texto": Singleton.VelocidadTexto.MEDIA,
			"animacion_combate": true,
			"tipo_combate": Singleton.TipoCombate.CAMBIAR,
			"nivel_audio": Singleton.Sonido.BAJO,
			"controles": Singleton.Controles.NORMAL,
			"imagen_tipo": 1,
		},
	}
	return plantilla


## Aplica la plantilla minima de partida nueva solo al estado vivo.
## Preserva las opciones que el jugador eligió en el menú de inicio para que
## viajen intactas a la nueva partida. El guardado lo invoca el jugador.
func aplicar_plantilla_partida_nueva(plantilla: Dictionary) -> bool:
	# Conservar opciones actuales antes de reiniciar el estado vivo: el jugador
	# puede haber cambiado ajustes desde el menú de inicio.
	var opciones_actuales: Opciones = datos_vivos.opciones

	datos_vivos = EstructuraGuardado.new()
	datos_vivos.opciones = opciones_actuales
	reiniciar_guarderia()
	reiniciar_revanchas()
	reiniciar_bases_secretas()
	reiniciar_concursos()
	reiniciar_estuche_pokecubos()

	var jugador: Dictionary = plantilla.get("jugador", {})
	for clave in ["id", "nombre", "sexo", "dinero", "medallas"]:
		datos_vivos.jugador[clave] = jugador.get(clave, datos_vivos.jugador.get(clave))
	datos_vivos.tiempo_juego = 0

	var posicion: Dictionary = plantilla.get("posicion", {})
	for clave in posicion.keys():
		datos_vivos.posicion[clave] = posicion[clave]

	datos_vivos.equipo_pokemon = []
	inicializar_mochila_estructura()
	datos_vivos.objetos_pc = [{"nombre_interno": "POCION", "cantidad": 1}]
	_inicializar_datos_persistentes()
	# Inicio de la partida para el contador de semanas (GetWeekCount); RelojJuego lo crea si falta (partidas antiguas).
	set_timestamp(RelojJuego.TIMESTAMP_INICIO, RelojJuego.dia_local())
	marcar_lugar_visitado(LUGAR_VISITADO_INICIAL)
	inicializar_cajas_pc()

	_logear("🆕 Plantilla de partida nueva aplicada.")
	return true

## Genera un Pokémon de prueba con un número nacional específico usando PokemonFactory.
func _crear_pokemon_de_prueba(numero_nacional: int) -> BasePokemon:
	# Obtener datos de la especie desde la base de datos
	var datos_especie = DatabaseManager.obtener_pokemon_por_numero(numero_nacional)

	if datos_especie.is_empty():
		print("⚠️ [SISTEMA_GUARDADO] No se encontró especie #%d en la base de datos" % numero_nacional)
		return null

	# Crear configuración para PokemonFactory
	var config = PokemonFactory.ConfiguracionPokemon.new(
		datos_especie.get("nombre_interno", "UNKNOWN"),
		randi_range(15, 45),
		PokemonFactory.OrigenPokemon.REGALO
	)

	# Configurar como regalo de prueba
	config.entrenador_nombre = "SISTEMA"
	config.lugar_encuentro = "DATOS_PRUEBA"
	config.pokeball_tipo = "POKEBALL"

	# Crear el Pokémon usando PokemonFactory
	var pokemon = PokemonFactory.crear_pokemon(config)

	if pokemon:
		print("📦 [SISTEMA_GUARDADO] Pokémon de prueba creado: %s #%d Nv.%d" % [pokemon.nombre_interno, numero_nacional, pokemon.nivel])

	return pokemon

## Cuenta cuántos Pokémon hay en una caja.
func _contar_pokemon_en_caja(caja: Array) -> int:
	var count = 0
	for pokemon in caja:
		if pokemon != null:
			count += 1
	return count

## Obtiene el índice de la caja activa.
func obtener_indice_caja_activa() -> int:
	return datos_vivos.indice_caja_activa

## === LOGGING ===
## Los mensajes de detalle (escrituras de banderas/contadores/etc.) solo salen con esto activo.
var log_detallado: bool = false
const LOG_MAX_CARACTERES: int = 120
const LOG_MAX_POR_FRAME: int = 5
var _log_frame: int = -1
var _log_emitidos: int = 0
var _log_omitidos: int = 0

## `detalle`: mensaje poco importante, descartado salvo `log_detallado`.
## Con muchas escrituras en un mismo frame solo se imprimen las primeras.
func _logear(tag: String, detalle: bool = false) -> void:
	if detalle and not log_detallado:
		return
	var frame := Engine.get_process_frames()
	if frame != _log_frame:
		if _log_omitidos > 0:
			print("🧭 [SISTEMA_GUARDADO] (%d mensajes omitidos)" % _log_omitidos)
		_log_frame = frame
		_log_emitidos = 0
		_log_omitidos = 0
	if _log_emitidos >= LOG_MAX_POR_FRAME:
		_log_omitidos += 1
		return
	_log_emitidos += 1
	if tag.length() > LOG_MAX_CARACTERES:
		tag = tag.substr(0, LOG_MAX_CARACTERES) + "…"
	print("🧭 [SISTEMA_GUARDADO] → %s" % tag)
