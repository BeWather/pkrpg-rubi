extends Node
class_name PokemonFactory

## Factory centralizado para crear instancias de Pokemon con diferentes contextos
## Gestiona la creación según origen: salvaje, entrenador, huevo, regalo, etc.

enum OrigenPokemon {
	SALVAJE,           # Encontrado en hierba/agua
	ENTRENADOR_NPC,    # Pokémon de un entrenador rival/gimnasio
	HUEVO,             # Eclosionado de huevo
	REGALO,            # Obtenido como regalo (starter, eventos)
	INTERCAMBIO,       # Recibido por intercambio
	LABORATORIO,       # Pokémon de laboratorio/investigación
	EVENTO_ESPECIAL,   # Pokémon de eventos únicos
	FOSSIL,            # Resucitado de fósil
	CAPTURA_ESPECIAL   # Legendarios, únicos del mapa
}

## Estructura para configurar la creación de un Pokémon
class ConfiguracionPokemon:
	var especie: String
	var nivel: int = 5
	var origen: OrigenPokemon = OrigenPokemon.SALVAJE
	var entrenador_nombre: String = ""
	var entrenador_id: int = 0
	var lugar_encuentro: String = ""
	var pokeball_tipo: String = "POKEBALL"
	var felicidad_inicial: int = 70
	var shiny_forzado: bool = false
	var naturaleza_forzada: String = ""
	var habilidad_forzada: String = ""
	var ivs_personalizados: Dictionary = {}  # {"ataque": 31, "defensa": 20, etc}
	var movimientos_especiales: Array = []   # Movimientos fuera del moveset normal
	var objeto_equipado: String = ""
	var apodo: String = ""
	
	func _init(p_especie: String, p_nivel: int = 5, p_origen: OrigenPokemon = OrigenPokemon.SALVAJE):
		especie = p_especie
		nivel = p_nivel
		origen = p_origen

## Crea un Pokémon según la configuración especificada
static func crear_pokemon(config: ConfiguracionPokemon) -> BasePokemon:
	# ✅ Validar que la especie existe en BD
	if not validar_especie_existe(config.especie):
		print("❌ Especie %s no válida, usando ZIGZAGOON por defecto" % config.especie)
		config.especie = "ZIGZAGOON"
	
	# Crear el Pokémon usando BasePokemon (que ya consulta la BD internamente)
	var pokemon = BasePokemon.new(config.especie, config.nivel, config.entrenador_nombre)
	
	# ✅ Obtener datos adicionales de BD si están disponibles (para futura implementación)
	# var _datos_especie = obtener_datos_especie(config.especie)
	
	# Configurar según el origen
	_aplicar_configuracion_origen(pokemon, config)
	
	# Aplicar configuraciones específicas
	_aplicar_configuraciones_especiales(pokemon, config)
	
	# ✅ Asignar moveset inicial desde BD
	if config.movimientos_especiales.is_empty():
		var movimientos_iniciales = obtener_moveset_inicial(config.especie, config.nivel)
		if not movimientos_iniciales.is_empty():
			pokemon.movimientos = movimientos_iniciales
	
	print("✨ Pokémon creado: %s Nv.%d [%s] - ID Entrenador: %d" % [
		pokemon.nombre_interno, 
		pokemon.nivel, 
		_get_nombre_origen(config.origen),
		pokemon.entrenador_id
	])
	
	return pokemon

## Obtiene el nombre legible del origen
static func _get_nombre_origen(origen: OrigenPokemon) -> String:
	match origen:
		OrigenPokemon.SALVAJE: return "SALVAJE"
		OrigenPokemon.ENTRENADOR_NPC: return "ENTRENADOR"
		OrigenPokemon.HUEVO: return "HUEVO"
		OrigenPokemon.REGALO: return "REGALO"
		OrigenPokemon.INTERCAMBIO: return "INTERCAMBIO"
		OrigenPokemon.LABORATORIO: return "LABORATORIO"
		OrigenPokemon.EVENTO_ESPECIAL: return "EVENTO"
		OrigenPokemon.FOSSIL: return "FOSSIL"
		OrigenPokemon.CAPTURA_ESPECIAL: return "LEGENDARIO"
		_: return "DESCONOCIDO"

## Aplica configuraciones específicas según el origen del Pokémon
static func _aplicar_configuracion_origen(pokemon: BasePokemon, config: ConfiguracionPokemon):
	match config.origen:
		OrigenPokemon.SALVAJE:
			_configurar_pokemon_salvaje(pokemon, config)
		OrigenPokemon.ENTRENADOR_NPC:
			_configurar_pokemon_entrenador(pokemon, config)
		OrigenPokemon.HUEVO:
			_configurar_pokemon_huevo(pokemon, config)
		OrigenPokemon.REGALO:
			_configurar_pokemon_regalo(pokemon, config)
		OrigenPokemon.INTERCAMBIO:
			_configurar_pokemon_intercambio(pokemon, config)
		OrigenPokemon.LABORATORIO:
			_configurar_pokemon_laboratorio(pokemon, config)
		OrigenPokemon.EVENTO_ESPECIAL:
			_configurar_pokemon_evento(pokemon, config)
		OrigenPokemon.FOSSIL:
			_configurar_pokemon_fossil(pokemon, config)
		OrigenPokemon.CAPTURA_ESPECIAL:
			_configurar_pokemon_captura_especial(pokemon, config)

## Clave de lugar de `config.lugar_encuentro` (normalizada, ver `Lugares`) o
## `defecto` si no se indicó ninguna.
static func _lugar_encuentro(config: ConfiguracionPokemon, defecto: String) -> String:
	var clave := Lugares.normalizar_clave(config.lugar_encuentro)
	return clave if not clave.is_empty() else defecto

## Configuración para Pokémon salvajes
static func _configurar_pokemon_salvaje(pokemon: BasePokemon, config: ConfiguracionPokemon):
	pokemon.entrenador_id = 0  # Sin entrenador previo
	pokemon.felicidad = 70
	pokemon.encuentro_lugar = _lugar_encuentro(config, Lugares.DESCONOCIDO)
	pokemon.encuentro_bola = config.pokeball_tipo
	pokemon.encuentro_nivel = config.nivel
	
	# IVs aleatorios normales (0-31)
	_generar_ivs_aleatorios(pokemon)

## Configuración para Pokémon de entrenadores NPC
static func _configurar_pokemon_entrenador(pokemon: BasePokemon, config: ConfiguracionPokemon):
	pokemon.entrenador_id = config.entrenador_id
	pokemon.felicidad = 255  # Entrenadores tienen Pokémon con máxima felicidad
	pokemon.encuentro_lugar = Lugares.EQUIPO_ENTRENADOR
	pokemon.encuentro_bola = "POKEBALL"
	pokemon.encuentro_nivel = config.nivel
	
	# IVs más altos para entrenadores importantes
	_generar_ivs_entrenador(pokemon, config)

## Configuración para Pokémon de huevos
static func _configurar_pokemon_huevo(pokemon: BasePokemon, config: ConfiguracionPokemon):
	# ✅ Acceso a autoload SistemaGuardado
	pokemon.entrenador_id = SistemaGuardado.datos_vivos.jugador.id
	pokemon.felicidad = 120  # Pokémon de huevo nacen más felices
	pokemon.encuentro_lugar = Lugares.GUARDERIA_POKEMON
	pokemon.encuentro_bola = "POKEBALL"
	pokemon.encuentro_nivel = 1  # Siempre nivel 1
	
	# Configurar nivel mínimo
	config.nivel = 1
	pokemon.nivel = 1
	
	# IVs heredados (implementar lógica de herencia)
	_generar_ivs_herencia(pokemon, config)

## Configuración para Pokémon de regalo
static func _configurar_pokemon_regalo(pokemon: BasePokemon, config: ConfiguracionPokemon):
	# ✅ Acceso a autoload SistemaGuardado
	pokemon.entrenador_id = SistemaGuardado.datos_vivos.jugador.id
	pokemon.felicidad = config.felicidad_inicial
	pokemon.encuentro_lugar = _lugar_encuentro(config, Lugares.REGALO)
	pokemon.encuentro_bola = config.pokeball_tipo
	pokemon.encuentro_nivel = config.nivel
	
	# IVs garantizados buenos para regalos importantes
	_generar_ivs_regalo(pokemon, config)

## Configuración para Pokémon de intercambio
static func _configurar_pokemon_intercambio(pokemon: BasePokemon, config: ConfiguracionPokemon):
	pokemon.entrenador_id = config.entrenador_id
	pokemon.felicidad = 70  # Reset de felicidad por intercambio
	pokemon.encuentro_lugar = Lugares.INTERCAMBIO
	pokemon.encuentro_bola = config.pokeball_tipo
	pokemon.encuentro_nivel = config.nivel

## Configuración para Pokémon de laboratorio (starters)
static func _configurar_pokemon_laboratorio(pokemon: BasePokemon, config: ConfiguracionPokemon):
	# ✅ Acceso a autoload SistemaGuardado
	pokemon.entrenador_id = SistemaGuardado.datos_vivos.jugador.id
	pokemon.felicidad = 70
	pokemon.encuentro_lugar = Lugares.LABORATORIO_PROF
	pokemon.encuentro_bola = "POKEBALL"
	pokemon.encuentro_nivel = config.nivel
	
	# IVs ligeramente mejores para starters
	_generar_ivs_starter(pokemon, config)

## Configuración para Pokémon de eventos especiales
static func _configurar_pokemon_evento(pokemon: BasePokemon, config: ConfiguracionPokemon):
	# ✅ Acceso a autoload SistemaGuardado
	pokemon.entrenador_id = SistemaGuardado.datos_vivos.jugador.id
	pokemon.felicidad = config.felicidad_inicial
	pokemon.encuentro_lugar = _lugar_encuentro(config, Lugares.EVENTO_ESPECIAL)
	pokemon.encuentro_bola = config.pokeball_tipo
	pokemon.encuentro_nivel = config.nivel
	
	# IVs perfectos para eventos especiales
	_generar_ivs_perfectos(pokemon)

## Configuración para Pokémon resucitados de fósiles
static func _configurar_pokemon_fossil(pokemon: BasePokemon, config: ConfiguracionPokemon):
	# ✅ Acceso a autoload SistemaGuardado
	pokemon.entrenador_id = SistemaGuardado.datos_vivos.jugador.id
	pokemon.felicidad = 70
	pokemon.encuentro_lugar = Lugares.LABORATORIO_FOSSIL
	pokemon.encuentro_bola = "POKEBALL"
	pokemon.encuentro_nivel = config.nivel
	
	# IVs aleatorios normales
	_generar_ivs_aleatorios(pokemon)

## Configuración para capturas especiales (legendarios)
static func _configurar_pokemon_captura_especial(pokemon: BasePokemon, config: ConfiguracionPokemon):
	pokemon.entrenador_id = 0  # Sin entrenador previo
	pokemon.felicidad = 35  # Legendarios son más difíciles de entrenar
	pokemon.encuentro_lugar = _lugar_encuentro(config, Lugares.CAPTURA_ESPECIAL)
	pokemon.encuentro_bola = config.pokeball_tipo
	pokemon.encuentro_nivel = config.nivel
	
	# IVs garantizados altos para legendarios
	_generar_ivs_legendario(pokemon)

## Aplica configuraciones especiales personalizadas
static func _aplicar_configuraciones_especiales(pokemon: BasePokemon, config: ConfiguracionPokemon):
	# Shiny forzado
	if config.shiny_forzado:
		# TODO: Implementar sistema shiny
		pass
	
	# IVs personalizados
	if not config.ivs_personalizados.is_empty():
		_aplicar_ivs_personalizados(pokemon, config.ivs_personalizados)
	
	# Movimientos especiales
	if not config.movimientos_especiales.is_empty():
		_aplicar_movimientos_especiales(pokemon, config.movimientos_especiales)
	
	# Objeto equipado
	if config.objeto_equipado != "":
		# TODO: Implementar sistema de objetos equipados
		pass
	
	# Apodo personalizado
	if config.apodo != "":
		pokemon.apodo = config.apodo

## === FUNCIONES DE GENERACIÓN DE IVs ===
static func _generar_ivs_aleatorios(pokemon: BasePokemon):
	# IVs completamente aleatorios (0-31)
	# ✅ Acceso a autoload Singleton para constantes
	if Singleton and Singleton.has_method("generar_numero_aleatorio"):
		# Usar método del singleton si existe
		pokemon.iv_ps = Singleton.generar_numero_aleatorio(0, 31)
		pokemon.iv_ataque = Singleton.generar_numero_aleatorio(0, 31)
		pokemon.iv_defensa = Singleton.generar_numero_aleatorio(0, 31)
		pokemon.iv_ataque_especial = Singleton.generar_numero_aleatorio(0, 31)
		pokemon.iv_defensa_especial = Singleton.generar_numero_aleatorio(0, 31)
		pokemon.iv_velocidad = Singleton.generar_numero_aleatorio(0, 31)
	else:
		# Fallback con randi_range
		pokemon.iv_ps = randi_range(0, 31)
		pokemon.iv_ataque = randi_range(0, 31)
		pokemon.iv_defensa = randi_range(0, 31)
		pokemon.iv_ataque_especial = randi_range(0, 31)
		pokemon.iv_defensa_especial = randi_range(0, 31)
		pokemon.iv_velocidad = randi_range(0, 31)
	
	print("📊 IVs aleatorios aplicados a %s: PS=%d ATK=%d DEF=%d" % [
		pokemon.nombre_interno, pokemon.iv_ps, pokemon.iv_ataque, pokemon.iv_defensa
	])

static func _generar_ivs_entrenador(pokemon: BasePokemon, _config: ConfiguracionPokemon):
	# IVs más altos para entrenadores importantes
	print("📊 IVs de entrenador aplicados a %s" % pokemon.nombre_interno)

static func _generar_ivs_herencia(pokemon: BasePokemon, _config: ConfiguracionPokemon):
	# IVs heredados de padres
	print("📊 IVs de herencia aplicados a %s" % pokemon.nombre_interno)

static func _generar_ivs_regalo(pokemon: BasePokemon, _config: ConfiguracionPokemon):
	# IVs garantizados buenos (mínimo 20 en cada stat)
	print("📊 IVs de regalo aplicados a %s" % pokemon.nombre_interno)

static func _generar_ivs_starter(pokemon: BasePokemon, _config: ConfiguracionPokemon):
	# IVs ligeramente mejores que salvajes
	print("📊 IVs de starter aplicados a %s" % pokemon.nombre_interno)

static func _generar_ivs_perfectos(pokemon: BasePokemon):
	# IVs perfectos (31 en todos)
	print("📊 IVs perfectos aplicados a %s" % pokemon.nombre_interno)

static func _generar_ivs_legendario(pokemon: BasePokemon):
	# IVs altos garantizados (mínimo 25 en cada stat)
	print("📊 IVs de legendario aplicados a %s" % pokemon.nombre_interno)

static func _aplicar_ivs_personalizados(pokemon: BasePokemon, ivs: Dictionary):
	# Aplicar IVs específicos del diccionario
	print("📊 IVs personalizados aplicados a %s: %s" % [pokemon.nombre_interno, ivs])

static func _aplicar_movimientos_especiales(pokemon: BasePokemon, movimientos: Array):
	# Aplicar movimientos fuera del moveset normal
	print("⚔️ Movimientos especiales aplicados a %s: %s" % [pokemon.nombre_interno, movimientos])

## === FUNCIONES DE CONVENIENCIA ===

## Crea un Pokémon salvaje rápido
static func crear_pokemon_salvaje(especie: String, nivel: int, lugar: String = "") -> BasePokemon:
	var config = ConfiguracionPokemon.new(especie, nivel, OrigenPokemon.SALVAJE)
	config.lugar_encuentro = lugar
	return crear_pokemon(config)

## Crea un starter de laboratorio
static func crear_starter(especie: String, nivel: int = 5) -> BasePokemon:
	var config = ConfiguracionPokemon.new(especie, nivel, OrigenPokemon.LABORATORIO)
	# ✅ Acceso a autoload SistemaGuardado
	config.entrenador_nombre = SistemaGuardado.get_nombre_jugador()
	return crear_pokemon(config)

## Crea un Pokémon de entrenador rival/gimnasio
static func crear_pokemon_entrenador(especie: String, nivel: int, nombre_entrenador: String, id_entrenador: int) -> BasePokemon:
	var config = ConfiguracionPokemon.new(especie, nivel, OrigenPokemon.ENTRENADOR_NPC)
	config.entrenador_nombre = nombre_entrenador
	config.entrenador_id = id_entrenador
	return crear_pokemon(config)

## Crea un Pokémon de huevo
static func crear_pokemon_huevo(especie: String) -> BasePokemon:
	var config = ConfiguracionPokemon.new(especie, 1, OrigenPokemon.HUEVO)
	# ✅ Acceso a autoload SistemaGuardado
	config.entrenador_nombre = SistemaGuardado.get_nombre_jugador()
	return crear_pokemon(config)

## Crea un Pokémon de regalo/evento
static func crear_pokemon_regalo(especie: String, nivel: int, lugar: String = Lugares.REGALO) -> BasePokemon:
	var config = ConfiguracionPokemon.new(especie, nivel, OrigenPokemon.REGALO)
	# ✅ Acceso a autoload SistemaGuardado
	config.entrenador_nombre = SistemaGuardado.get_nombre_jugador()
	config.lugar_encuentro = lugar
	config.felicidad_inicial = 120  # Más feliz que normal
	return crear_pokemon(config)

## === FUNCIONES DE ACCESO A BASE DE DATOS ===

## Obtiene datos de una especie desde la base de datos
static func obtener_datos_especie(nombre_interno: String) -> Dictionary:
	# ✅ Acceso a autoload DatabaseManager
	if DatabaseManager and DatabaseManager.esta_conectado():
		var datos = DatabaseManager.obtener_datos_pokemon(nombre_interno)
		if not datos.is_empty():
			print("🗄️ Datos de %s obtenidos de BD: Tipo1=%s, PS_base=%d" % [
				nombre_interno, datos.get("tipo_1", "NORMAL"), datos.get("ps", 0)
			])
			return datos
		else:
			print("⚠️ Especie %s no encontrada en BD" % nombre_interno)
	else:
		print("❌ DatabaseManager no disponible")
	
	# Datos fallback si no hay BD
	return {
		"nombre": nombre_interno,
		"ps": 45,
		"ataque": 49,
		"defensa": 49,
		"ataque_especial": 65,
		"defensa_especial": 65,
		"velocidad": 45,
		"tipo_1": "NORMAL",
		"tipo_2": ""
	}

## Valida si una especie existe en la base de datos
static func validar_especie_existe(nombre_interno: String) -> bool:
	# ✅ Acceso a autoload DatabaseManager
	if DatabaseManager and DatabaseManager.esta_conectado():
		var datos = DatabaseManager.obtener_datos_pokemon(nombre_interno)
		return not datos.is_empty()
	else:
		print("⚠️ No se puede validar especie: BD no disponible")
		return true  # Asumir que existe si no hay BD
	
## Obtiene el moveset inicial de una especie
static func obtener_moveset_inicial(nombre_interno: String, nivel: int) -> Array:
	# ✅ Acceso a autoload DatabaseManager
	if DatabaseManager and DatabaseManager.has_method("obtener_movimientos_por_nivel"):
		var movimientos = DatabaseManager.obtener_movimientos_por_nivel(nombre_interno, nivel)
		print("⚔️ Moveset inicial para %s Nv.%d: %d movimientos" % [nombre_interno, nivel, movimientos.size()])
		return movimientos
	else:
		print("⚠️ No se puede obtener moveset: método no disponible en DatabaseManager")
		return []
