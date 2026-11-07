extends RefCounted
class_name BasePokemon

const CalculadoraStats := preload("res://BaseDatos/calculadora_stats.gd")

var pid: int = 0
var nombre_interno: String = ""  # nombre_interno de la tabla Pokemon
var nombre: String = ""   # nombre mostrable de la especie (de la tabla Pokemon)
var numero_nacional: int = 0  # Número en la Pokédex Nacional
var sexo: String = ""
var mote: String = ""     # apodo personalizado del Pokémon
var nivel: int = 0
var experiencia: int = 0
var exp_sig_nivel: int = 0
var porcentaje_experiencia: float = 0.0  # Porcentaje de experiencia para el siguiente nivel
var naturaleza: String = ""

## Monotonic live held-item write lease; not inventory or consumption history.
var held_item_revision: int=0
var objeto: String = "":
	set(value):
		held_item_revision+=1
		objeto=value
## Contenido de la CARTA que lleva (struct MailStruct de pokeruby): {"palabras":
## [9 ids de PALABRAS FÁCILES], "autor", "id_entrenador", "especie"}; {} si no
## lleva carta o aún no se ha escrito. Ver DatosCarta.
var carta: Dictionary = {}
var habilidad: String = ""  # nombre_interno de la tabla Habilidades (p. ej. "ESPESURA")
## Habilidad prestada solo durante el combate (RASTRO). No se guarda; la limpia
## HabilidadesCombate.limpiar_combate() al salir del campo o acabar la batalla.
var habilidad_temporal: String = ""
## Tipos que tenía antes de que CAMBIO COLOR los alterase en combate (vacío si no
## ha cambiado). No se guarda; se restauran en HabilidadesCombate.limpiar_combate().
var tipos_originales_combate: Array[String] = []

## Condición del Pokémon DENTRO del combate, que decide el sufijo con el que lo
## nombran los mensajes ("EEVEE salvaje", "EEVEE enemigo"). PROPIO es el valor por
## defecto: los Pokémon del jugador y del equipo/PC no llevan sufijo. Los reservados
## DOMINANTE y OSCURO (Pokémon dominantes / oscuros) aún no los asigna nadie.
enum EtiquetaCombate { PROPIO, SALVAJE, ENTRENADOR, DOMINANTE, OSCURO }
## Sufijos de nombre por etiqueta (el original los pone tras el nombre).
const SUFIJOS_COMBATE: Dictionary = {
	EtiquetaCombate.PROPIO: "",
	EtiquetaCombate.SALVAJE: " salvaje",
	EtiquetaCombate.ENTRENADOR: " enemigo",
	EtiquetaCombate.DOMINANTE: " dominante",
	EtiquetaCombate.OSCURO: " oscuro",
}
## Etiqueta transitoria asignada por la batalla al construir el equipo rival.
## NO se guarda (la lista blanca de EstructuraGuardado._pokemon_a_diccionario no
## la incluye) ni la copia duplicate(); al capturar o acabar la batalla vuelve a
## PROPIO con `limpiar_etiqueta_combate()`.
var etiqueta_combate: int = EtiquetaCombate.PROPIO
var felicidad: int = 0
var huevo: bool = false
## Valor de personalidad de 32 bits (MON_DATA_PERSONALITY). Decide la habilidad
## (bit bajo, ver habilidad_por_personalidad), la evolución de WURMPLE
## (EvolucionPokemon) y las manchas del sprite frontal de SPINDA (ManchasSpinda,
## un byte por mancha); sexo, naturaleza y variocolor siguen siendo
## independientes en el proyecto.
var personalidad: int = 0
## Condición BELLEZA (MON_DATA_BEAUTY, 0-255): evolución de FEEBAS y concursos.
## TODO: POKéCUBOS no implementados; nada la sube todavía.
var belleza: int = 0
## Condiciones CARISMA, DULZURA, INGENIO y DUREZA (MON_DATA_COOL / CUTE / SMART /
## TOUGH, 0-255): ronda 1 de los concursos y el PRESIDENTE del CLUB FAN de CIUDAD
## PORTUAL (>= 200).
## TODO: POKéCUBOS no implementados; nada las sube todavía.
var carisma: int = 0
var dulzura: int = 0
var ingenio: int = 0
var dureza: int = 0
## Brillo (MON_DATA_SHEEN, 0-255): suma en la ronda 1 de los concursos; con 255 el
## Pokémon ya no come POKéCUBOS.
var brillo: int = 0

# Estado de infección Pokérus
var infectado: bool = false
var curado: bool = false
var pokerus_dias_restantes: int = 0  # Días de Pokérus activo (0 = no infectado)
var pokerus_fecha_ultimo_conteo: int = 0  # Fecha (timestamp) del último conteo de Pokérus
# Cepa	Valor de X	Duración (valor de Y)
# A		0			1 día
# B		1			2 días
# C		2			3 días
# D		3			4 días

# Cintas
var cintas: Array = []

#var juego_origen: String
## Clave del lugar de encuentro (ver `Lugares`), p. ej. "RUTA_113" o "INTERCAMBIO".
## El texto se resuelve al mostrarlo con `Lugares.nombre_lugar`.
var encuentro_lugar: String
var encuentro_bola: String
var encuentro_nivel: int
var encuentro_fatidico: bool

var iv_ps: int
var iv_ataque: int
var iv_defensa: int
var iv_ataque_especial: int
var iv_defensa_especial: int
var iv_velocidad: int

var ev_ps: int = 0
var ev_ataque: int = 0
var ev_defensa: int = 0
var ev_ataque_especial: int = 0
var ev_defensa_especial: int = 0
var ev_velocidad: int = 0

var estad_ps: int
var estad_ataque: int
var estad_defensa: int
var estad_ataque_especial: int
var estad_defensa_especial: int
var estad_velocidad: int

var tipo_poder_oculto: String
var tipo_1: String
var tipo_2: String
var tipo_1_id: int  # ID del tipo 1 en la BD
var tipo_2_id: int  # ID del tipo 2 en la BD (0 si no tiene segundo tipo)

# var _move: Dictionary = {
#   "nombre": "",
#   "pp_act": 0,
#   "pp_mas": 0,
#   "pp_tot": 0,
#   "datos": "",
# }

var movimientos: Array[Movimiento] = []

var entrenador_id: int
var entrenador_original: String
var entrenador_sexo: String

var estado: int = Singleton.ProblemaEstado.NORMAL: # Estado del Pokémon (ver enum ProblemaEstado)
	set(valor):
		estado = valor
		if valor != Singleton.ProblemaEstado.DORMIDO: turnos_sueno_guardados = 0
		if valor != Singleton.ProblemaEstado.ENVENENADO: veneno_grave_guardado = false
var turnos_sueno_guardados: int = 0 # Parte de status1 que sobrevive al cambio; no se guarda en partida.
var veneno_grave_guardado: bool = false
var shiny: bool = false  # Indica si el Pokémon es variocolor
var estad_ps_actual: int

# Marcas del Pokémon (4 marcas disponibles)
var marcas: Dictionary = {
	"circulo": false,    # ♠ o ●
	"cuadrado": false,   # ♦ o ■
	"triangulo": false,  # ▲
	"corazon": false     # ♥
}

## Índice de orden original en el equipo antes de entrar a batalla.
## Se usa para restaurar el orden original al finalizar la batalla.
var indice_orden_original: int = -1

## Constructor
func _init(
	nombre_interno_param: String = "",
	nivel_param: int = 1,
	entrenador_original_param: String = ""
):
	self.nombre_interno = nombre_interno_param
	self.nivel = nivel_param
	self.entrenador_original = entrenador_original_param
	# Los Pokémon cargados de partida la sobrescriben con la guardada.
	self.personalidad = randi()

	# Usar DatabaseManager autoload en lugar de instancia local
	if DatabaseManager.esta_conectado() and nombre_interno_param != "":
		var datos_pokemon = DatabaseManager.obtener_datos_pokemon(nombre_interno_param)
		if not datos_pokemon.is_empty():
			calcular_estadisticas(datos_pokemon)
		else:
			print("⚠️ [BASEPOKEMON] Pokémon '%s' no encontrado en BD" % nombre_interno_param)
	elif nombre_interno_param != "":
		# Si no hay DB o no se proporciona especie, usar valores por defecto
		print("🔧 [BASEPOKEMON] Creando Pokémon sin BD: %s (Nivel %d)" % [nombre_interno_param, nivel_param])

## Calcula las estadísticas del Pokémon basándose en su especie, nivel, IVs y EVs.
func calcular_estadisticas(fila_poke: Dictionary = {}):
	self.pid = fila_poke.get("id") # ID único del Pokémon en la BD

	# Cargar el nombre mostrable de la especie
	self.nombre = fila_poke.get("nombre", self.nombre_interno)  # fallback al nombre interno si no existe

	# Cargar número nacional para mostrar el icono correcto
	self.numero_nacional = fila_poke.get("numero_nacional")

	# fila_poke es un diccionario que tiene una clave llamada base_ps
	var base_ps = fila_poke["base_ps"]
	# calcular un iv_ps aleatorio entre 0 y 31
	self.iv_ps = randi() % 32
	self.ev_ps = 0
	self.estad_ps = get_calc_stat_hp(base_ps, self.iv_ps, self.ev_ps, self.nivel)
	self.estad_ps_actual = self.estad_ps

	var base_ataque = fila_poke["base_atq"]
	self.iv_ataque = randi() % 32
	self.ev_ataque = 0
	self.estad_ataque = get_calc_stat(base_ataque, self.iv_ataque, self.ev_ataque, self.nivel)

	var base_defensa = fila_poke["base_def"]
	self.iv_defensa = randi() % 32
	self.ev_defensa = 0
	self.estad_defensa = get_calc_stat(base_defensa, self.iv_defensa, self.ev_defensa, self.nivel)

	var base_ataque_especial = fila_poke["base_atq_esp"]
	self.iv_ataque_especial = randi() % 32
	self.ev_ataque_especial = 0
	self.estad_ataque_especial = get_calc_stat(base_ataque_especial, self.iv_ataque_especial, self.ev_ataque_especial, self.nivel)

	var base_defensa_especial = fila_poke["base_def_esp"]
	self.iv_defensa_especial = randi() % 32
	self.ev_defensa_especial = 0
	self.estad_defensa_especial = get_calc_stat(base_defensa_especial, self.iv_defensa_especial, self.ev_defensa_especial, self.nivel)

	var base_velocidad = fila_poke["base_vel"]
	self.iv_velocidad = randi() % 32
	self.ev_velocidad = 0
	self.estad_velocidad = get_calc_stat(base_velocidad, self.iv_velocidad, self.ev_velocidad, self.nivel)

	#var base_experiencia = fila_poke["base_experiencia"]
	var ratio_crecimiento = fila_poke["ratio_crecimiento"]
	self.experiencia = get_exp_nivel(self.nivel, ratio_crecimiento)
	self.exp_sig_nivel = get_exp_nivel(self.nivel + 1, ratio_crecimiento)

	self.felicidad = fila_poke["base_felicidad"]

	var habilidad_1 = fila_poke["habilidad_1"]
	var habilidad_2 = fila_poke["habilidad_2"]
	# var _habilidad_oculta = fila_poke["habilidad_oculta"]  # Para uso futuro

	# CreateBoxMon: con segunda habilidad, el bit bajo de la personalidad elige la
	# ranura (MON_DATA_ALT_ABILITY = personality & 1).
	self.habilidad = habilidad_por_personalidad(habilidad_1, habilidad_2, self.personalidad)
	if self.habilidad == "SIN_HABILIDAD":
		print("⚠️ %s no tiene habilidades válidas, usando fallback" % nombre_interno)

	var prob_sexo = fila_poke["prob_sexo"]

	# prob_sexo representa la probabilidad (0-100) de que el Pokémon sea HEMBRA
	if prob_sexo == null:
		# Pokémon sin sexo (legendarios, artificiales, etc.)
		self.sexo = "SIN_SEXO"
		print("🚫 %s: Sin sexo (legendario/artificial)" % nombre_interno)
	elif prob_sexo == 0:
		# Pokémon 100% macho (ej: Nidoran♂, Tauros, Hitmonlee, etc.)
		self.sexo = "M"
		print("♂️ %s: Siempre macho (prob_sexo=0)" % nombre_interno)
	elif prob_sexo == 100:
		# Pokémon 100% hembra (ej: Nidoran♀, Chansey, Miltank, etc.)
		self.sexo = "F"
		print("♀️ %s: Siempre hembra (prob_sexo=100)" % nombre_interno)
	else:
		# Pokémon con probabilidad normal de género
		# prob_sexo es la probabilidad (0-100) de ser HEMBRA
		var random_gender = randi() % 100
		if random_gender < prob_sexo:
			self.sexo = "F"
			print("♀️ %s: Hembra (prob_fem: %d%%)" % [nombre_interno, prob_sexo])
		else:
			self.sexo = "M"
			print("♂️ %s: Macho (prob_fem: %d%%, prob_masc: %d%%)" % [nombre_interno, prob_sexo, 100 - prob_sexo])

	# Asignar naturaleza aleatoria desde DatabaseManager
	self.naturaleza = DatabaseManager.obtener_naturaleza_aleatoria()

	self.tipo_poder_oculto = get_poder_oculto(self.iv_ps, self.iv_ataque, self.iv_defensa, self.iv_velocidad, self.iv_ataque_especial, self.iv_defensa_especial)

	# Convertir IDs de tipos a nombres y guardar IDs usando DatabaseManager
	self.tipo_1_id = fila_poke["tipo_1_id"]
	self.tipo_1 = DatabaseManager.obtener_nombre_tipo_por_id(fila_poke["tipo_1_id"])

	if fila_poke["tipo_2_id"] != null:
		self.tipo_2_id = fila_poke["tipo_2_id"]
		self.tipo_2 = DatabaseManager.obtener_nombre_tipo_por_id(fila_poke["tipo_2_id"])
	else:
		self.tipo_2_id = 0
		self.tipo_2 = ""

	self.movimientos = get_movs_nivel(self.nombre_interno, self.nivel)

## Delegan en CalculadoraStatsPokemon: fuente unica de la formula, compartida
## con el Editor de Instancia de Pokemon del plugin.
func get_calc_stat_hp(f_base_hp: int, f_iv: int, f_ev: int, f_nivel: int) -> int:
	return CalculadoraStats.stat_ps(f_base_hp, f_iv, f_ev, f_nivel)

func get_calc_stat(f_base: int, f_iv: int, f_ev: int, f_nivel: int) -> int:
	return CalculadoraStats.stat_general(f_base, f_iv, f_ev, f_nivel)

## Delega en CalculadoraStatsPokemon (misma formula, compartida con las
## herramientas del plugin que no pueden instanciar BasePokemon).
func get_exp_nivel(f_nivel: int, f_ratio_crecimiento: String) -> int:
	return CalculadoraStats.experiencia_nivel(f_nivel, f_ratio_crecimiento)

## Lleva `experiencia` al rango valido de `nivel` en la curva real de la especie
## y recalcula `exp_sig_nivel` (ver CalculadoraStatsPokemon.ajustar_experiencia_a_nivel).
## Lo usa la carga de partidas: las guardadas cuando todas las especies usaban
## la curva NORMAL (n^3) pueden tener una experiencia fuera del rango del nivel.
func ajustar_experiencia_a_curva() -> void:
	if not DatabaseManager.esta_conectado():
		return
	var datos_pokemon = DatabaseManager.obtener_datos_pokemon(self.nombre_interno)
	if datos_pokemon.is_empty():
		return
	var ratio_crecimiento := str(datos_pokemon.get("ratio_crecimiento", ""))
	self.experiencia = CalculadoraStats.ajustar_experiencia_a_nivel(self.experiencia, self.nivel, ratio_crecimiento)
	self.exp_sig_nivel = get_exp_nivel(self.nivel + 1, ratio_crecimiento)

func set_experiencia(nueva_experiencia: int) -> void:
	self.experiencia = nueva_experiencia
	calcular_porcentaje_experiencia()

## Sube de nivel al Pokémon recalculando estadísticas con los IVs/EVs existentes.
## Añade al PS actual la diferencia ganada (no cura por completo).
func subir_nivel() -> void:
	if self.nivel >= 100:
		return

	var datos_pokemon = DatabaseManager.obtener_datos_pokemon(self.nombre_interno)
	if datos_pokemon.is_empty():
		print("⚠️ No se encontraron datos para subir de nivel a %s" % self.nombre_interno)
		return

	var ratio_crecimiento = datos_pokemon["ratio_crecimiento"]
	var ps_max_anterior = self.estad_ps

	self.nivel += 1

	self.estad_ps               = get_calc_stat_hp(datos_pokemon["base_ps"],      self.iv_ps,               self.ev_ps,               self.nivel)
	self.estad_ataque           = get_calc_stat(   datos_pokemon["base_atq"],     self.iv_ataque,           self.ev_ataque,           self.nivel)
	self.estad_defensa          = get_calc_stat(   datos_pokemon["base_def"],     self.iv_defensa,          self.ev_defensa,          self.nivel)
	self.estad_ataque_especial  = get_calc_stat(   datos_pokemon["base_atq_esp"], self.iv_ataque_especial,  self.ev_ataque_especial,  self.nivel)
	self.estad_defensa_especial = get_calc_stat(   datos_pokemon["base_def_esp"], self.iv_defensa_especial, self.ev_defensa_especial, self.nivel)
	self.estad_velocidad        = get_calc_stat(   datos_pokemon["base_vel"],     self.iv_velocidad,        self.ev_velocidad,        self.nivel)

	# Añadir al PS actual la diferencia ganada (nunca superar el nuevo máximo)
	var diferencia_ps = self.estad_ps - ps_max_anterior
	self.estad_ps_actual = min(self.estad_ps_actual + diferencia_ps, self.estad_ps)

	self.exp_sig_nivel = get_exp_nivel(self.nivel + 1, ratio_crecimiento)
	calcular_porcentaje_experiencia()

	print("🎉 ¡%s subió al nivel %d!" % [self.nombre_interno, self.nivel])

## Esta función se encarga de calcular el porcentaje de experiencia.
## y actualizar cualquier UI o lógica relacionada
func calcular_porcentaje_experiencia() -> void:
	porcentaje_experiencia = get_porcentaje_experiencia()

## Función que devuelve el porcentaje de completitud para alcanzar el siguiente nivel.
## Si el Pokémon está en el nivel 100, devuelve 0
func get_porcentaje_experiencia() -> float:
	# Si el Pokémon está en el nivel máximo, no puede ganar más experiencia
	if self.nivel >= 100:
		return 0.0

	# Necesitamos obtener el ratio de crecimiento para calcular la experiencia requerida
	var ratio_crecimiento = ""

	# Obtener el ratio de crecimiento desde DatabaseManager
	var datos_pokemon = DatabaseManager.obtener_datos_pokemon(self.nombre_interno)
	if not datos_pokemon.is_empty():
		ratio_crecimiento = datos_pokemon["ratio_crecimiento"]
	else:
		print("⚠️ No se encontró el ratio de crecimiento para %s, usando NORMAL" % self.nombre_interno)
		ratio_crecimiento = "NORMAL"

	# Calcular la experiencia requerida para el nivel actual y el siguiente
	var exp_nivel_actual = get_exp_nivel(self.nivel, ratio_crecimiento)
	var exp_siguiente_nivel = get_exp_nivel(self.nivel + 1, ratio_crecimiento)

	# Calcular la experiencia necesaria para pasar de nivel
	var exp_necesaria_para_subir = exp_siguiente_nivel - exp_nivel_actual

	# Calcular la experiencia ganada desde el inicio del nivel actual
	var exp_ganada_en_nivel = self.experiencia - exp_nivel_actual

	# Calcular el porcentaje (entre 0.0 y 1.0)
	var porcentaje = 0.0
	if exp_necesaria_para_subir > 0:
		porcentaje = float(exp_ganada_en_nivel) / float(exp_necesaria_para_subir)
		# Asegurar que esté entre 0.0 y 1.0
		porcentaje = clamp(porcentaje, 0.0, 1.0)

	print("📊 [EXP] %s Nivel %d: %d/%d exp (%.1f%%)" % [
		self.nombre_interno,
		self.nivel,
		exp_ganada_en_nivel,
		exp_necesaria_para_subir,
		porcentaje * 100.0
	])

	return porcentaje

## Delega en CalculadoraStatsPokemon (misma tabla, compartida con las
## herramientas del plugin que no pueden instanciar BasePokemon).
func get_poder_oculto(f_iv_ps: int, f_iv_ataque: int, f_iv_defensa: int, f_iv_velocidad: int, f_iv_ataque_especial: int, f_iv_defensa_especial: int) -> String:
	return CalculadoraStats.tipo_poder_oculto(f_iv_ps, f_iv_ataque, f_iv_defensa, f_iv_velocidad, f_iv_ataque_especial, f_iv_defensa_especial)

func get_movs_nivel(f_especie: String, f_nivel: int) -> Array[Movimiento]:
	var rel_mov_nv: PackedStringArray = []
	var dat_mov: Array[Movimiento] = []

	# Obtener el número nacional del Pokémon usando DatabaseManager
	var datos_pokemon = DatabaseManager.obtener_datos_pokemon(f_especie)
	var poke_numero_nacional = 0
	if not datos_pokemon.is_empty():
		poke_numero_nacional = datos_pokemon.get("numero_nacional", 0)

	# Obtener movimientos específicos por nivel usando DatabaseManager
	if poke_numero_nacional > 0:
		var movimientos_data = DatabaseManager.obtener_movimientos_pokemon_nivel(poke_numero_nacional, f_nivel)
		for mov_data in movimientos_data:
			if mov_data["nombre_interno"] not in rel_mov_nv:
				rel_mov_nv.append(mov_data["nombre_interno"])

	# Si no hay movimientos específicos, usar movimientos básicos variados según el tipo
	if rel_mov_nv.size() == 0:
		print("⚠️ %s no tiene movimientos específicos, asignando movimientos variados" % f_especie)
		rel_mov_nv = PackedStringArray(DatabaseManager.obtener_movimientos_basicos_por_tipo(
			datos_pokemon.get("tipo_1", "NORMAL") if not datos_pokemon.is_empty() else "NORMAL"
		))

	# Buscar datos de movimientos usando DatabaseManager
	for nombre_mov in rel_mov_nv:
		var datos_movimiento_completo = DatabaseManager.obtener_datos_movimiento(nombre_mov)
		if not datos_movimiento_completo.is_empty():
			dat_mov.append(Movimiento.desde_fila_bd(datos_movimiento_completo))

	# Si aún no hay datos, crear movimiento por defecto
	if dat_mov.size() == 0:
		print("⚠️ No se encontraron datos de movimientos para %s, creando movimiento por defecto" % f_especie)
		dat_mov.append(crear_movimiento_por_defecto())

	var nombres_movs: Array[String] = []
	for m in dat_mov:
		nombres_movs.append(m.nombre)
	print("🎯 %s tiene %d movimientos: %s" % [f_especie, dat_mov.size(), nombres_movs])
	return dat_mov

## Crea un movimiento por defecto usando el método estático de la clase Movimiento.
func crear_movimiento_por_defecto() -> Movimiento:
	return Movimiento.crear_por_defecto()

## Función para obtener el nombre del tipo por su ID
func obtener_nombre_tipo_por_id(tipo_id) -> String:
	if tipo_id == null:
		return ""

	return DatabaseManager.obtener_nombre_tipo_por_id(tipo_id)

## Nombre que muestra el juego para un huevo (GetMonNick con MON_DATA_IS_EGG).
const NOMBRE_HUEVO: String = "HUEVO"

## Función para obtener el nombre a mostrar del Pokémon.
## Un huevo se muestra siempre como "HUEVO".
## Si tiene mote/apodo, devuelve el mote.
## Si no, devuelve el nombre de la especie.
func get_nombre_mostrar() -> String:
	if huevo:
		return NOMBRE_HUEVO
	if mote != null and mote != "":
		return mote
	elif nombre != null and nombre != "":
		return nombre
	else:
		return nombre_interno  # fallback al nombre interno

## Nombre tal como lo dicen los mensajes de combate: `get_nombre_mostrar()` más el
## sufijo de su etiqueta ("EEVEE salvaje", "EEVEE enemigo"). Con etiqueta PROPIO
## (Pokémon del jugador) coincide con `get_nombre_mostrar()`, así que es seguro
## usarlo para cualquier combatiente. NO usar en HUD, EXP, POKéDEX ni motes.
func get_nombre_combate() -> String:
	return get_nombre_mostrar() + String(SUFIJOS_COMBATE.get(etiqueta_combate, ""))

## Devuelve la etiqueta de combate a PROPIO (captura, fin de batalla).
func limpiar_etiqueta_combate() -> void:
	etiqueta_combate = EtiquetaCombate.PROPIO

## Puede salir a combatir: no es un huevo y le quedan PS.
func puede_combatir() -> bool:
	return not huevo and estad_ps_actual > 0

## Habilidad que corresponde a `personalidad` (CreateBoxMon): la segunda ranura
## si la especie la tiene y el bit bajo vale 1; si no, la primera. "SIN_HABILIDAD"
## si la especie no tiene ninguna.
static func habilidad_por_personalidad(habilidad_1: Variant, habilidad_2: Variant, personalidad: int) -> String:
	var primera: String = "" if habilidad_1 == null else str(habilidad_1).strip_edges()
	var segunda: String = "" if habilidad_2 == null else str(habilidad_2).strip_edges()
	if not segunda.is_empty() and (personalidad & 1) == 1:
		return segunda
	if not primera.is_empty():
		return primera
	return "SIN_HABILIDAD"


## Recalcula la habilidad con la personalidad actual (huevos de la guardería,
## cuya personalidad se fija después de crear el Pokémon).
func asignar_habilidad_por_personalidad() -> void:
	var fila: Dictionary = DatabaseManager.obtener_datos_pokemon(nombre_interno)
	if fila.is_empty():
		return
	habilidad = habilidad_por_personalidad(fila.get("habilidad_1"), fila.get("habilidad_2"), personalidad)


## Nombre mostrable de la habilidad (Habilidades.nombre).
func get_nombre_habilidad() -> String:
	var datos := DatabaseManager.obtener_datos_habilidad(habilidad)
	return str(datos.get("nombre", habilidad))

## Descripción de la habilidad (Habilidades.descripcion).
func get_descripcion_habilidad() -> String:
	var datos := DatabaseManager.obtener_datos_habilidad(habilidad)
	return str(datos.get("descripcion", ""))

## Pasa a nombre_interno una habilidad guardada con el nombre inglés
## (partidas anteriores a la tabla Habilidades en español: "Overgrow" -> "ESPESURA").
static func normalizar_habilidad(valor: String) -> String:
	var datos := DatabaseManager.obtener_datos_habilidad(valor)
	return str(datos.get("nombre_interno", valor))

# === CONCURSOS: CONDICIÓN Y CINTAS ===

## Niveles de concurso en el orden de CONTEST_RANK_* (sufijo de las claves de
## Singleton.CINTAS_POKEMON: "CARISMA_NORMAL"...).
const NIVELES_CINTA_CONCURSO: Array[String] = ["NORMAL", "ALTO", "AVANZADO", "EXPERTO"]
const CINTA_ARTISTA: String = "ARTISTA"

## Condición de una categoría de concurso (Movimiento.CategoriaConcurso).
func condicion_concurso(categoria: int) -> int:
	match categoria:
		Movimiento.CategoriaConcurso.CARISMA: return carisma
		Movimiento.CategoriaConcurso.BELLEZA: return belleza
		Movimiento.CategoriaConcurso.DULZURA: return dulzura
		Movimiento.CategoriaConcurso.INGENIO: return ingenio
		_: return dureza

## Clave de la cinta de una categoría y un nivel (0 NORMAL … 3 EXPERTO).
static func clave_cinta_concurso(categoria: int, nivel: int) -> String:
	return "%s_%s" % [Movimiento.NOMBRES_CATEGORIA_CONCURSO[categoria], NIVELES_CINTA_CONCURSO[nivel]]

## MON_DATA_<CAT>_RIBBON de pokeruby: cuántas cintas consecutivas de la categoría
## tiene desde NORMAL (0 ninguna … 4 hasta EXPERTO).
func nivel_cinta_concurso(categoria: int) -> int:
	var nivel: int = 0
	while nivel < NIVELES_CINTA_CONCURSO.size() and cintas.has(clave_cinta_concurso(categoria, nivel)):
		nivel += 1
	return nivel

## ScrSpecial_GiveContestRibbon: añade la cinta del nivel siguiente. Devuelve la
## clave añadida, o "" si ya tenía la de EXPERTO.
func subir_cinta_concurso(categoria: int) -> String:
	var nivel: int = nivel_cinta_concurso(categoria)
	if nivel >= NIVELES_CINTA_CONCURSO.size():
		return ""
	var clave: String = clave_cinta_concurso(categoria, nivel)
	cintas.append(clave)
	return clave

## artistRibbon.
func tiene_cinta_artista() -> bool:
	return cintas.has(CINTA_ARTISTA)

# === SISTEMA DE MARCAS ===

## Activar/desactivar una marca específica
func set_marca(tipo_marca: String, activo: bool) -> void:
	"""
	Establece el estado de una marca específica.
	Tipos válidos: 'circulo', 'cuadrado', 'triangulo', 'corazon'
	"""
	if marcas.has(tipo_marca):
		marcas[tipo_marca] = activo
		print("🏷️ [MARCA] %s: %s → %s" % [nombre_interno, tipo_marca, "ON" if activo else "OFF"])
	else:
		print("❌ [MARCA] Tipo de marca inválido: %s" % tipo_marca)

## Obtiene el estado de una marca específica.
func get_marca(tipo_marca: String) -> bool:
	return marcas.get(tipo_marca, false)

## Alternar estado de una marca específica.
func toggle_marca(tipo_marca: String) -> void:
	if marcas.has(tipo_marca):
		set_marca(tipo_marca, not marcas[tipo_marca])

## Aplica los campos de un snapshot (dict producido por AutogeneradorPokemon o
## por la partida guardada) sobre este BasePokemon ya construido.
## Solo sobreescribe las claves presentes — los campos ausentes quedan tal como
## los calculó el constructor. Pensado para el boot de pruebas de batalla:
## el editor captura la instancia completa pero el boot debe crear BasePokemon
## desde especie+nivel; después llama a este método para restaurar el resto.
func aplicar_snapshot(entrada: Dictionary) -> void:
	if entrada.is_empty():
		return
	# Scalares que no requieren recalcular estadísticas.
	if entrada.has("sexo"):
		sexo = str(entrada["sexo"])
	if entrada.has("naturaleza"):
		naturaleza = str(entrada["naturaleza"])
	if entrada.has("habilidad"):
		habilidad = normalizar_habilidad(str(entrada["habilidad"]))
	if entrada.has("objeto"):
		objeto = str(entrada["objeto"])
	if entrada.has("shiny"):
		shiny = bool(entrada["shiny"])
	if entrada.has("mote"):
		mote = str(entrada["mote"])
	if entrada.has("entrenador_original"):
		entrenador_original = str(entrada["entrenador_original"])
	if entrada.has("encuentro_lugar"):
		# Clave de lugar (Lugares); migra claves de escena y nombres legibles.
		encuentro_lugar = Lugares.normalizar_clave(str(entrada["encuentro_lugar"]))
	if entrada.has("encuentro_bola"):
		encuentro_bola = str(entrada["encuentro_bola"])

	# IVs: si el snapshot los trae, aplicarlos y recalcular estadísticas.
	var tiene_ivs := entrada.has("iv_ps") or entrada.has("iv_ataque") or entrada.has("iv_defensa")
	if tiene_ivs:
		iv_ps               = int(entrada.get("iv_ps",               iv_ps))
		iv_ataque           = int(entrada.get("iv_ataque",           iv_ataque))
		iv_defensa          = int(entrada.get("iv_defensa",          iv_defensa))
		iv_ataque_especial  = int(entrada.get("iv_ataque_especial",  iv_ataque_especial))
		iv_defensa_especial = int(entrada.get("iv_defensa_especial", iv_defensa_especial))
		iv_velocidad        = int(entrada.get("iv_velocidad",        iv_velocidad))
		_recalcular_stats_con_ivs_actuales()

	# Movimientos: entradas de guardado ({nombre_interno, pp_act, pp_mas, pp_tot}),
	# cadenas legadas de partidas antiguas o dicts ligeros del autogenerador
	# ({nombre_interno, nombre, pp}, PP completos). Ver MovimientoGuardado.
	var movs_entrada: Variant = entrada.get("movimientos", [])
	if movs_entrada is Array and not (movs_entrada as Array).is_empty():
		var movs_nuevos: Array[Movimiento] = []
		for mov_entrada in (movs_entrada as Array):
			if mov_entrada == null:
				movs_nuevos.append(null)
				continue
			if mov_entrada is Dictionary:
				for field: String in ["pp_act", "pp_mas"]:
					if mov_entrada.has(field) and not preload("res://BaseDatos/move_save_record.gd").integral(mov_entrada[field]): return
			var movimiento: Movimiento = Movimiento.desde_guardado(mov_entrada)
			if movimiento != null:
				movs_nuevos.append(movimiento)
		if not movs_nuevos.is_empty():
			movimientos = movs_nuevos

	# Estado y PS actuales: al final, para que el PS parta del máximo ya recalculado.
	if entrada.has("estado"):
		estado = int(entrada["estado"])
	if entrada.has("estad_ps_actual"):
		estad_ps_actual = mini(int(entrada["estad_ps_actual"]), estad_ps)

## Recalcula todas las estadísticas usando los IVs/EVs/nivel actuales.
## Requiere una consulta a la BD para obtener las bases de la especie.
func _recalcular_stats_con_ivs_actuales() -> void:
	var datos_poke := DatabaseManager.obtener_datos_pokemon(nombre_interno)
	if datos_poke.is_empty():
		return
	estad_ps               = get_calc_stat_hp(int(datos_poke.get("base_ps",      0)), iv_ps,               ev_ps,               nivel)
	estad_ataque           = get_calc_stat(   int(datos_poke.get("base_atq",     0)), iv_ataque,           ev_ataque,           nivel)
	estad_defensa          = get_calc_stat(   int(datos_poke.get("base_def",     0)), iv_defensa,          ev_defensa,          nivel)
	estad_ataque_especial  = get_calc_stat(   int(datos_poke.get("base_atq_esp", 0)), iv_ataque_especial,  ev_ataque_especial,  nivel)
	estad_defensa_especial = get_calc_stat(   int(datos_poke.get("base_def_esp", 0)), iv_defensa_especial, ev_defensa_especial, nivel)
	estad_velocidad        = get_calc_stat(   int(datos_poke.get("base_vel",     0)), iv_velocidad,        ev_velocidad,        nivel)
	estad_ps_actual = estad_ps

## Devuelve una cadena con los símbolos de las marcas activas. Útil para mostrar en la UI.
func get_marcas_texto() -> String:
	var texto = ""
	if marcas.circulo: texto += "●"
	if marcas.cuadrado: texto += "■"
	if marcas.triangulo: texto += "▲"
	if marcas.corazon: texto += "♥"
	return texto

## Devuelve un array con los nombres de las marcas activas.
func get_marcas_activas() -> Array:
	var activas = []
	for marca in marcas:
		if marcas[marca]:
			activas.append(marca)
	return activas

## Limpiar todas las marcas.
func limpiar_marcas() -> void:
	for marca in marcas:
		marcas[marca] = false

# === FORMATEO DE DATOS ===

## Formatear ID del entrenador a 5 dígitos
func get_entrenador_id_formateado() -> String:
	"""
	Formatea el ID del entrenador a exactamente 5 dígitos.
	- Completa con ceros a la izquierda si es menor a 5 dígitos
	- Filtra a 5 dígitos si es mayor (toma los últimos 5)
	"""
	if entrenador_id <= 0:
		return "00000"  # ID por defecto si no es válido

	# Convertir a string y tomar solo los últimos 5 dígitos
	var id_string = str(entrenador_id)
	if id_string.length() > 5:
		# Si tiene más de 5 dígitos, tomar los últimos 5
		id_string = id_string.substr(id_string.length() - 5, 5)

	# Completar con ceros a la izquierda hasta 5 dígitos
	return id_string.pad_zeros(5)

## Generar ID aleatorio de 5 cifras (10000-99999).
func generar_id_entrenador_aleatorio() -> void:
	entrenador_id = randi_range(10000, 99999)
	print("🎲 [ID] Nuevo ID generado para %s: %s" % [nombre_interno, get_entrenador_id_formateado()])

## Función para obtener los IDs de tipos desde los datos cargados.
func obtener_tipos_desde_bd() -> Array[int]:
	var tipos: Array[int] = []

	if tipo_1_id > 0:
		tipos.append(tipo_1_id)

	if tipo_2_id > 0:
		tipos.append(tipo_2_id)

	return tipos

## Función para obtener los nombres de tipos del Pokémon.
func obtener_nombres_tipos() -> Array[String]:
	var tipos: Array[String] = []

	if tipo_1 != "":
		tipos.append(tipo_1)

	if tipo_2 != "":
		tipos.append(tipo_2)

	return tipos

## Regenerar naturaleza aleatoria para el Pokémon.
func regenerar_naturaleza() -> void:
	var naturaleza_anterior = self.naturaleza
	self.naturaleza = DatabaseManager.obtener_naturaleza_aleatoria()
	print("🔄 [NATURALEZA] %s: %s → %s" % [nombre_interno, naturaleza_anterior, self.naturaleza])

## Función para verificar si el Pokémon es variocolor (shiny).
func es_shiny() -> bool:
	return self.shiny

## Función para activar o desactivar el estado variocolor del Pokémon.
func hacer_variocolor(activar: bool = true) -> void:
	var anterior = self.shiny
	self.shiny = activar
	print("✨ [VARIOCOLOR] %s: %s → %s" % [
		get_nombre_mostrar(),
		"Shiny" if anterior else "Normal",
		"Shiny" if self.shiny else "Normal"
	])

## Función para establecer el estado de curado (del Pokérus).
func set_curado(estado_pokerus: bool) -> void:
	self.curado = estado_pokerus
	print("🔧 [PANTALLA_INFO] Estado de curado: %s" % [self.curado])

## Función para duplicar el objeto BasePokemon.
func duplicate() -> BasePokemon:
	var copia = BasePokemon.new()

	# Copiar todas las propiedades
	copia.pid = self.pid
	copia.nombre_interno = self.nombre_interno
	copia.nombre = self.nombre
	copia.numero_nacional = self.numero_nacional
	copia.sexo = self.sexo
	copia.mote = self.mote
	copia.nivel = self.nivel
	copia.experiencia = self.experiencia
	copia.exp_sig_nivel = self.exp_sig_nivel
	copia.porcentaje_experiencia = self.porcentaje_experiencia
	copia.naturaleza = self.naturaleza

	copia.objeto = self.objeto
	copia.carta = self.carta.duplicate(true)
	copia.habilidad = self.habilidad
	copia.felicidad = self.felicidad
	copia.huevo = self.huevo
	copia.personalidad = self.personalidad
	copia.belleza = self.belleza
	copia.carisma = self.carisma
	copia.dulzura = self.dulzura
	copia.ingenio = self.ingenio
	copia.dureza = self.dureza
	copia.brillo = self.brillo

	copia.infectado = self.infectado
	copia.curado = self.curado
	copia.pokerus_dias_restantes = self.pokerus_dias_restantes
	copia.pokerus_fecha_ultimo_conteo = self.pokerus_fecha_ultimo_conteo

	copia.cintas = self.cintas.duplicate()

	#copia.juego_origen = self.juego_origen
	copia.encuentro_lugar = self.encuentro_lugar
	copia.encuentro_bola = self.encuentro_bola
	copia.encuentro_nivel = self.encuentro_nivel
	copia.encuentro_fatidico = self.encuentro_fatidico

	copia.iv_ps = self.iv_ps
	copia.iv_ataque = self.iv_ataque
	copia.iv_defensa = self.iv_defensa
	copia.iv_ataque_especial = self.iv_ataque_especial
	copia.iv_defensa_especial = self.iv_defensa_especial
	copia.iv_velocidad = self.iv_velocidad

	copia.ev_ps = self.ev_ps
	copia.ev_ataque = self.ev_ataque
	copia.ev_defensa = self.ev_defensa
	copia.ev_ataque_especial = self.ev_ataque_especial
	copia.ev_defensa_especial = self.ev_defensa_especial
	copia.ev_velocidad = self.ev_velocidad

	copia.estad_ps = self.estad_ps
	copia.estad_ataque = self.estad_ataque
	copia.estad_defensa = self.estad_defensa
	copia.estad_ataque_especial = self.estad_ataque_especial
	copia.estad_defensa_especial = self.estad_defensa_especial
	copia.estad_velocidad = self.estad_velocidad

	copia.tipo_poder_oculto = self.tipo_poder_oculto
	copia.tipo_1 = self.tipo_1
	copia.tipo_2 = self.tipo_2
	copia.tipo_1_id = self.tipo_1_id
	copia.tipo_2_id = self.tipo_2_id

	# Copiar movimientos (asumiendo que Movimiento tiene un método duplicate)
	copia.movimientos = [] as Array[Movimiento]
	for mov in self.movimientos:
		if mov == null:
			copia.movimientos.append(null)
		elif mov is Movimiento:
			copia.movimientos.append(mov.duplicate())
		else:
			print("❌ [DUPLICAR] Movimiento inválido en %s" % self.nombre_interno)

	copia.entrenador_id = self.entrenador_id
	copia.entrenador_original = self.entrenador_original
	copia.entrenador_sexo = self.entrenador_sexo
	copia.estado = self.estado
	copia.shiny = self.shiny
	copia.estad_ps_actual = self.estad_ps_actual

	copia.marcas = self.marcas.duplicate()
	return copia
