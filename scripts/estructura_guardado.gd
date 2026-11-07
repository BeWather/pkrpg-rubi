extends Resource
class_name EstructuraGuardado

const MoveRecord = preload("res://BaseDatos/move_save_record.gd")

const POSICION_POR_DEFECTO: Dictionary = {
	"mapa_actual": "ruta_103",
	"cx": 14,
	"cy": 17,
	"nombre_lugar": "RUTA_103",
	"capa_datos": 0,
	"en_bicicleta": false,
	## BICI_CARRERA o BICI_ACROBATICA del jugador (solo vale con en_bicicleta).
	"tipo_bici": "CARRERA",
	"en_surf": false,
	## [x, y] de la dirección a la que mira el jugador.
	"direccion": [0, 1],
}
const PUNTO_CURACION_POR_DEFECTO: Dictionary = {
	"mapa_actual": "nodo_casa_1_piso_2",
	"cx": 3,
	"cy": 4,
	"capa_datos": 0,
	"nombre_lugar": "VILLA_RAIZ",
}

## Versión del formato del guardado. Historial:
##   "1.0": cada movimiento de un Pokémon era la cadena de `Movimiento._to_string()`
##          ("Movimiento(nombre=GRUÑIDO, pp=40/40, ...)", solo el nombre mostrable).
##   "1.2": registros versionados conservan datos de combate y huecos nulos.
##          Se leen también los formatos 1.0 y 1.1.
##   "1.1": cada movimiento es {nombre_interno, pp_act, pp_mas, pp_tot}
##          (`MovimientoGuardado`). El cargador sigue aceptando la cadena de 1.0 y
##          la migra; `from_dict` deja `version` en la actual, así que al volver a
##          guardar una partida antigua queda ya en el formato nuevo.
const VERSION_FORMATO: String = "1.2"

var version: String = VERSION_FORMATO
var fecha_guardado: String = ""
var tiempo_juego: int = 0 # Segundos
## `inicial`: índice del inicial elegido (VAR_STARTER_MON: 0 TREECKO, 1 TORCHIC,
## 2 MUDKIP); -1 = sin elegir. Ver SistemaGuardado.get_inicial().
var jugador: Dictionary = {"id": 1, "nombre":"ASH","sexo":"M","dinero":3000,"medallas":[],"inicial":-1}
var posicion: Dictionary = POSICION_POR_DEFECTO.duplicate(true)
var punto_curacion: Dictionary = PUNTO_CURACION_POR_DEFECTO.duplicate(true)
## Entrada exterior (warp4 de pokeruby, sub_80535C4): celda de un mapa del
## Overworld desde la que el jugador dio el último paso hacia un warp que lleva a
## un interior. Mismo formato que `punto_curacion` (mapa_actual, cx, cy en celdas
## locales del mapa, capa_datos, nombre_lugar). {} = ninguna. La usan CUERDA
## HUIDA, EXCAVAR y la enfermera del Centro Pokémon (último punto de curación).
var entrada_exterior: Dictionary = {}
var equipo_pokemon: Array[BasePokemon] = []  # Array de BasePokemon (no puede tipificar en @export)
var cajas_pc: Array = []  # Array de cajas PC, cada caja contiene Array de BasePokemon
var indice_caja_activa: int = 0  # Índice de la caja PC actualmente activa
var mochila: Dictionary = {}
## SaveBlock1.pcItems de Ruby; independiente de las cajas de Pokémon.
var objetos_pc: Array = []
var opciones: Opciones = Opciones.new()
## `personalidad_spinda`: personalidad del primer SPINDA atrapado en combate
## (pokeruby `pokedex.spindaPersonality`), para las manchas del sprite de la
## POKéDEX. 0 = patrón "de fábrica". Ver ManchasSpinda.
var pokedex: Dictionary = {"vistos": [], "atrapados": [], ManchasSpinda.CLAVE_POKEDEX: 0}
## Objetos del mapa donde se guardó (EventObject de SaveBlock1 en Gen 3):
## {"mapa": clave, "objetos": {ruta_relativa_al_mapa: estado_npc}}. Solo se
## aplica al continuar la partida en ese mismo mapa.
var estado_mapa: Dictionary = {}
## Guardería de Ruta 117 (`Guarderia.to_dict()`); {} = vacía.
var guarderia: Dictionary = {}
## Revanchas de entrenadores (`SistemaRevanchas.to_dict()`); {} = sin progreso.
var revanchas: Dictionary = {}
## Base propia e inventario de decoración (`SistemaBasesSecretas.to_dict()`).
## {} en partidas antiguas; independiente de mochila y estado temporal del mapa.
var bases_secretas: Dictionary = {}
## Pósters de ganadores, MUSEO de CALAGUA y premio/cuadro pendientes
## (`RegistroConcursos.to_dict()`); {} en partidas antiguas = registro de partida nueva.
var concursos: Dictionary = {}
## Estuche de POKéCUBOS (`EstuchePokecubos.to_dict()`); {} en partidas antiguas =
## estuche vacío.
var pokecubos: Dictionary = {}

## === NUEVOS DATOS PERSISTENTES ===
var datos_persistentes: Dictionary = {
	"banderas": {},       ## bool: Para estados de eventos y progreso
	"contadores": {},     ## int: Para llevar cuenta de eventos
	"timestamps": {},     ## int: Para eventos basados en tiempo
	"textos": {},         ## String: Para guardar nombres, estados textuales
	"decimales": {}       ## float: Para valores como porcentajes, multiplicadores
}

func to_dict() -> Dictionary:
	# Convertir BasePokemon a diccionarios para JSON
	var equipo_serializado = []
	for pokemon in equipo_pokemon:
		if pokemon is BasePokemon:
			equipo_serializado.append(_pokemon_a_diccionario(pokemon))
		else:
			# Ya es un diccionario, mantenerlo
			equipo_serializado.append(pokemon)

	# Convertir cajas PC a diccionarios para JSON
	var cajas_serializadas = []
	for caja in cajas_pc:
		var caja_serializada = []
		for pokemon in caja:
			if pokemon is BasePokemon:
				caja_serializada.append(_pokemon_a_diccionario(pokemon))
			elif pokemon != null:
				# Ya es un diccionario, mantenerlo
				caja_serializada.append(pokemon)
			else:
				# Slot vacío
				caja_serializada.append(null)
		cajas_serializadas.append(caja_serializada)

	return {
		"version": version,
		"fecha_guardado": fecha_guardado,
		"tiempo_juego": tiempo_juego,
		"jugador": jugador.duplicate(true),
		"posicion": posicion.duplicate(true),
		"punto_curacion": punto_curacion.duplicate(true),
		"entrada_exterior": entrada_exterior.duplicate(true),
		"equipo_pokemon": equipo_serializado,
		"cajas_pc": cajas_serializadas,
		"indice_caja_activa": indice_caja_activa,
		"mochila": mochila.duplicate(true),
		"objetos_pc": objetos_pc.duplicate(true),
		"opciones": opciones.to_dict(),
		"pokedex": pokedex.duplicate(true),
		"estado_mapa": estado_mapa.duplicate(true),
		"guarderia": guarderia.duplicate(true),
		"revanchas": revanchas.duplicate(true),
		"bases_secretas": bases_secretas.duplicate(true),
		"concursos": concursos.duplicate(true),
		"pokecubos": pokecubos.duplicate(true),
		"datos_persistentes": datos_persistentes.duplicate(true)
	}

# Función auxiliar para convertir BasePokemon a Dictionary (estática: la usa también Guarderia)
static func _pokemon_a_diccionario(pokemon: BasePokemon) -> Dictionary:
	var dict_poke = {}
	# Usar una lista predefinida de propiedades para asegurar consistencia.
	# "movimientos" conserva datos de combate tipados, PP y huecos nulos (1.2).
	var propiedades = [
		"pid", "nombre_interno", "numero_nacional", "sexo", "mote", "nivel",
		"experiencia", "exp_sig_nivel", "naturaleza", "objeto", "carta", "habilidad",
		"felicidad", "personalidad", "belleza", "carisma", "dulzura", "ingenio", "dureza", "brillo",
		"cintas", "marcas", "huevo", "infectado", "curado", "encuentro_lugar",
		"encuentro_bola", "encuentro_nivel", "encuentro_fatidico",
		"iv_ps", "iv_ataque", "iv_defensa", "iv_ataque_especial",
		"iv_defensa_especial", "iv_velocidad",
		"ev_ps", "ev_ataque", "ev_defensa", "ev_ataque_especial",
		"ev_defensa_especial", "ev_velocidad",
		"estad_ps", "estad_ataque", "estad_defensa", "estad_ataque_especial",
		"estad_defensa_especial", "estad_velocidad",
		"tipo_poder_oculto", "tipo_1", "tipo_2", "movimientos",
		"entrenador_id", "entrenador_ids", "entrenador_original",
		"entrenador_sexo", "estado", "estad_ps_actual", "shiny"
	]
	for prop in propiedades:
		if prop=="movimientos":
			var records: Array=[]
			for move: Movimiento in pokemon.movimientos:
				if move==null:records.append(null)
				else:
					records.append(MoveRecord.encode_fields(move.nombre, move.pp_act, move.pp_mas, move.pp_tot, move.datos))
			dict_poke[prop]=records
		elif pokemon.has_method("get_" + prop):
			dict_poke[prop] = pokemon.call("get_" + prop)
		else:
			dict_poke[prop] = pokemon.get(prop)

	return dict_poke

# Función auxiliar para convertir Dictionary a BasePokemon (estática: la usa también Guarderia)
static func _diccionario_a_pokemon(datos_poke: Dictionary) -> BasePokemon:
	# Crear una instancia de BasePokemon usando los datos del diccionario
	var pokemon = BasePokemon.new(
		datos_poke.get("nombre_interno", "MISSINGNO"),
		datos_poke.get("nivel", 1),
		datos_poke.get("entrenador_original", "DESCONOCIDO"),
	)

	# Restaurar todos los demás atributos guardados
	# Mapeo para compatibilidad con nombres de propiedades antiguos
	var mapeo_propiedades = {
		"iv_atq": "iv_ataque",
		"iv_def": "iv_defensa",
		"iv_vel": "iv_velocidad",
		"iv_atq_esp": "iv_ataque_especial",
		"iv_def_esp": "iv_defensa_especial",
		"ev_atq": "ev_ataque",
		"ev_def": "ev_defensa",
		"ev_vel": "ev_velocidad",
		"ev_atq_esp": "ev_ataque_especial",
		"ev_def_esp": "ev_defensa_especial",
		# Mapeo para PS
		"ps_max": "estad_ps",
		"ps_actuales": "estad_ps_actual"
	}

	# Propiedades a ignorar (que no existen en BasePokemon)
	var propiedades_ignorar = ["entrenador_ids"]
	# El tipo es de la especie: el constructor ya lo leyó de la BD, y partidas
	# antiguas guardaban tipos actuales (HADA). Sin especie en la BD, vale lo guardado.
	if not pokemon.tipo_1.is_empty():
		propiedades_ignorar.append_array(["tipo_1", "tipo_2"])

	for key in datos_poke:
		if key not in ["nombre_interno", "nivel", "entrenador_original"] and key not in propiedades_ignorar:
			# Usar mapeo si existe, sino usar la clave original
			var propiedad_real = mapeo_propiedades.get(key, key)

			# Manejo especial para movimientos: convertir entradas a objetos Movimiento
			if propiedad_real == "movimientos":
				var movimientos_array: Array[Movimiento] = []
				var movimientos_data = datos_poke[key]
				for mov_data in movimientos_data:
					if mov_data == null:
						movimientos_array.append(null)
						continue
					if mov_data is Movimiento:
						movimientos_array.append(mov_data)
						continue
					# Entrada {nombre_interno, pp_*} (1.1) o cadena legada (1.0): se
					# hidrata desde la BD por nombre_interno (Movimiento.desde_guardado).
					var mov_obj: Movimiento = Movimiento.desde_guardado(mov_data)
					if mov_obj != null:
						movimientos_array.append(mov_obj)
				pokemon.movimientos = movimientos_array
			# Marcas: se mezclan sobre las cuatro por defecto (partidas sin la clave
			# o con claves de más no rompen la ficha).
			elif propiedad_real == "marcas":
				var marcas_guardadas = datos_poke[key]
				if marcas_guardadas is Dictionary:
					for marca in pokemon.marcas:
						pokemon.marcas[marca] = bool(marcas_guardadas.get(marca, false))
			elif propiedad_real == "cintas":
				var cintas_guardadas = datos_poke[key]
				pokemon.cintas = cintas_guardadas.duplicate() if cintas_guardadas is Array else []
			# Verificar que la propiedad existe antes de asignarla
			elif pokemon.has_method("set_" + propiedad_real) or propiedad_real in pokemon:
				pokemon.set(propiedad_real, datos_poke[key])
			else:
				print("⚠️ [ESTRUCTURA_GUARDADO] Propiedad '%s' no existe en BasePokemon, ignorando" % propiedad_real)

	# Partidas antiguas guardaban la habilidad en inglés ("Overgrow").
	pokemon.habilidad = BasePokemon.normalizar_habilidad(pokemon.habilidad)
	# Partidas antiguas guardaban objetos con la clave de PokeAPI ("kings-rock").
	pokemon.objeto = AliasObjetos.clave_actual(pokemon.objeto)
	# Partidas antiguas guardaban el lugar como clave de escena ("ruta_113") o
	# nombre legible ("RUTA 101"): se pasa a clave de zona ("RUTA_113").
	pokemon.encuentro_lugar = Lugares.normalizar_clave(pokemon.encuentro_lugar)
	# Partidas antiguas usaban la curva NORMAL (n^3) para todas las especies:
	# se conserva el nivel y la experiencia se ajusta al rango de ese nivel.
	pokemon.ajustar_experiencia_a_curva()
	return pokemon

func from_dict(d: Dictionary) -> void:
	# Lo anterior a VERSION_FORMATO se migra en esta carga (movimientos, objetos,
	# lugares...), así que al volver a guardar queda ya en la versión actual.
	version = VERSION_FORMATO
	fecha_guardado = d.get("fecha_guardado", fecha_guardado)
	tiempo_juego = d.get("tiempo_juego", tiempo_juego)
	jugador = d.get("jugador", jugador).duplicate(true)
	var posicion_cargada: Variant = d.get("posicion", {})
	posicion = POSICION_POR_DEFECTO.duplicate(true)
	if posicion_cargada is Dictionary:
		for key in posicion_cargada.keys():
			posicion[key] = posicion_cargada[key]
	var punto_cargado: Variant = d.get("punto_curacion", {})
	punto_curacion = PUNTO_CURACION_POR_DEFECTO.duplicate(true)
	if punto_cargado is Dictionary:
		for key in punto_cargado.keys():
			punto_curacion[key] = punto_cargado[key]
	var entrada_cargada: Variant = d.get("entrada_exterior", {})
	entrada_exterior = entrada_cargada.duplicate(true) if entrada_cargada is Dictionary else {}
	# `nombre_lugar` guarda la clave de lugar; migra nombres legibles antiguos.
	_normalizar_nombre_lugar(posicion)
	_normalizar_nombre_lugar(punto_curacion)

	# Reconstruir equipo de BasePokemon desde diccionarios
	var equipo_datos = d.get("equipo_pokemon", [])
	equipo_pokemon = []
	for datos_poke in equipo_datos:
		if datos_poke is Dictionary:
			var pokemon = _diccionario_a_pokemon(datos_poke)
			equipo_pokemon.append(pokemon)
		else:
			# Ya es un BasePokemon (no debería pasar, pero por seguridad)
			equipo_pokemon.append(datos_poke)

	# Reconstruir cajas PC de BasePokemon desde diccionarios
	var cajas_datos = d.get("cajas_pc", [])
	cajas_pc = []
	for caja_datos in cajas_datos:
		var caja_reconstruida = []
		for datos_pokemon in caja_datos:
			if datos_pokemon is Dictionary:
				var pokemon = _diccionario_a_pokemon(datos_pokemon)
				caja_reconstruida.append(pokemon)
			elif datos_pokemon == null:
				# Slot vacío
				caja_reconstruida.append(null)
			else:
				# Ya es un BasePokemon
				caja_reconstruida.append(datos_pokemon)
		cajas_pc.append(caja_reconstruida)
	# Caja activa (gPokemonStorage.currentBox): destino de capturas y caja con la
	# que abre el PC. El JSON la devuelve como float; partidas antiguas → 0.
	indice_caja_activa = int(d.get("indice_caja_activa", 0))

	mochila = d.get("mochila", mochila).duplicate(true)
	AliasObjetos.migrar_mochila(mochila)
	# Las partidas antiguas empiezan vacías, nunca reciben la poción inicial.
	var almacen_cargado: Variant = d.get("objetos_pc", [])
	objetos_pc = almacen_cargado.duplicate(true) if almacen_cargado is Array else []
	objetos_pc = AliasObjetos.migrar_lista(objetos_pc)
	opciones.from_dict(d.get("opciones", {}))
	pokedex = d.get("pokedex", pokedex).duplicate(true)
	# Partidas antiguas no tienen la personalidad de SPINDA; el JSON la deja en float.
	pokedex[ManchasSpinda.CLAVE_POKEDEX] = ManchasSpinda.personalidad_en_pokedex(pokedex)
	var estado_mapa_cargado: Variant = d.get("estado_mapa", {})
	estado_mapa = estado_mapa_cargado.duplicate(true) if estado_mapa_cargado is Dictionary else {}
	var guarderia_cargada: Variant = d.get("guarderia", {})
	guarderia = guarderia_cargada.duplicate(true) if guarderia_cargada is Dictionary else {}
	var revanchas_cargadas: Variant = d.get("revanchas", {})
	revanchas = revanchas_cargadas.duplicate(true) if revanchas_cargadas is Dictionary else {}
	var bases_cargadas: Variant = d.get("bases_secretas", {})
	bases_secretas = bases_cargadas.duplicate(true) if bases_cargadas is Dictionary else {}
	var concursos_cargados: Variant = d.get("concursos", {})
	concursos = concursos_cargados.duplicate(true) if concursos_cargados is Dictionary else {}
	var pokecubos_cargados: Variant = d.get("pokecubos", {})
	pokecubos = pokecubos_cargados.duplicate(true) if pokecubos_cargados is Dictionary else {}

	## Inicializar datos_persistentes si no existen
	var default_persistentes = {
		"banderas": {},
		"contadores": {},
		"timestamps": {},
		"textos": {},
		"decimales": {}
	}
	datos_persistentes = d.get("datos_persistentes", default_persistentes).duplicate(true)

	## Migración: Si existen banderas en el nivel raíz, moverlas a datos_persistentes
	if d.has("banderas"):
		datos_persistentes["banderas"] = d.get("banderas", {}).duplicate(true)

## Migra `nombre_lugar` de un diccionario de posición a clave de lugar
## ("RUTA 103" → "RUTA_103", "ruta_113" → sección de ese mapa).
static func _normalizar_nombre_lugar(datos_posicion: Dictionary) -> void:
	if not datos_posicion.has("nombre_lugar"):
		return
	var valor: Variant = datos_posicion["nombre_lugar"]
	datos_posicion["nombre_lugar"] = Lugares.normalizar_clave(str(valor) if valor != null else "")
