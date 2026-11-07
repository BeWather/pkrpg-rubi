# time_manager.gd (añadido como singleton)
extends Node

const COLOR_CHICA = Color(1, 0.5, 0.5)  # Color rosa claro para diseño de chica
const COLOR_CHICO = Color(0.5, 0.5, 1)  # Color azul claro para diseño de chico
const TILE_SIZE = 16
const Z_INDEX_POR_CAPA = 10  ## Desplazamiento de z_index por cada capa de elevación (ELEVAR/DESCENDER)

## Último bolsillo de la mochila visto por el jugador. Memoria de solo
## runtime (no se guarda en partida): compartida entre batalla y fuera de
## batalla, se reinicia a 0 únicamente al reiniciar el juego.
var mochila_ultimo_bolsillo: int = 0
## Cursor y desplazamiento de cada bolsillo (gBagPocketScrollStates de pokeruby):
## bolsillo -> índice / offset. Solo runtime; las instancias de la mochila
## comparten estos diccionarios por referencia.
var mochila_item_actual: Dictionary = {}
var mochila_offset_lista: Dictionary = {}

## ResetBagScrollPositions de pokeruby: se llama al empezar una partida nueva.
func reiniciar_memoria_mochila() -> void:
	mochila_ultimo_bolsillo = 0
	mochila_item_actual.clear()
	mochila_offset_lista.clear()

## Último POKéMON elegido en la pantalla de equipo fuera de batalla
## (gLastFieldPokeMenuOpened de pokeruby). Solo runtime, como la de la mochila.
var equipo_ultimo_cursor: int = 0

## Modos de pantalla del equipo.
enum ModoPEquipo {
	## Usado desde el menú de pausa o similar.
	NORMAL,
	## Usado en batalla para ver datos, no es obligatorio cambiar de pokémon.
	BATALLA_DATOS,
	## Usado en batalla para cambiar de pokémon cuando el entrenador rival está por enviar uno.
	BATALLA_CAMBIO_OPCIONAL,
	## Usado en batalla para cambiar de pokémon cuando el actual se ha debilitado.
	BATALLA_CAMBIO_FORZADO,
	## Usado en batalla cuando el jugador elige usar un objeto sobre un Pokémon.
	## Selección directa sin submenú secundario: la propia pantalla aplica
	## objeto_a_usar (como USAR_OBJETO) y emite objeto_usado(indice, tuvo_efecto).
	BATALLA_OBJETO,
	## Usado desde la mochila (DAR): al elegir un Pokémon la propia pantalla
	## le da el objeto (objeto_a_dar) y emite dar_objeto_terminado.
	DAR_OBJETO,
	## Usado por la Abuela de la Guardería (ChooseSendDaycareMon): A abre
	## GUARDAR/DATOS/SALIR (un huevo solo DATOS/SALIR); GUARDAR emite
	## pokemon_elegido(indice) y B o SALIR de la lista, seleccion_cancelada.
	GUARDERIA,
	## Usado desde la mochila fuera de combate (USAR una medicina): al elegir un
	## Pokémon la propia pantalla aplica objeto_a_usar (UseMedicine) y emite
	## objeto_usado(indice, tuvo_efecto); B emite seleccion_cancelada.
	USAR_OBJETO,
	## Usado por un NPC que pide elegir un POKéMON del equipo (ChoosePartyMon /
	## SelectMonForNPCTrade, p. ej. el INSPECTOR de MOTES): A emite
	## pokemon_elegido(indice) sin menú secundario (un huevo también vale) y B
	## emite seleccion_cancelada. Quien escucha cierra la pantalla.
	ELEGIR,
	## Inscripción en la TORRE BATALLA (PARTY_MENU_TYPE_BATTLE_TOWER, choose_party.c):
	## A abre ENTRAR (o NO ENTRAR)/DATOS/SALIR y la caja marca PRIMERO/SEGUNDO/TERCERO
	## sin salir de la pantalla; VALE emite equipo_torre_elegido(indices) y B o SALIR,
	## seleccion_cancelada. Quien escucha cierra la pantalla.
	TORRE_BATALLA,
}


# Enum de tipos de Pokémon (orden según BD y frames de AnimatedSprite2D)
enum ProblemaEstado {
	NORMAL = -1,
	DEBILITADO = 0,
	ENVENENADO = 1,
	CONGELADO = 2,
	QUEMADO = 3,
	PARALIZADO = 4,
	DORMIDO = 5,
	POKERUS = 6
}

enum TipoPokemon {
	NORMAL = 0,
	LUCHA = 1,
	VENENO = 2,
	TIERRA = 3,
	VOLADOR = 4,
	BICHO = 5,
	ROCA = 6,
	FANTASMA = 7,
	ACERO = 8,
	FUEGO = 9,
	AGUA = 10,
	PLANTA = 11,
	ELECTRICO = 12,
	PSIQUICO = 13,
	HIELO = 14,
	DRAGON = 15,
	SINIESTRO = 16,
	HADA = 17
}

## Enumerar temas gráficos disponibles para batallas (fondo y suelo)
enum TemaBatalla {
	NO_TIENE,		    # Sin tema específico
	HIERBA_ALTA,        # Batalla en zona de hierba alta
	HIERBA_MUY_ALTA,    # Batalla en zona de hierba muy alta
	ARENA,              # Batalla en playa/desierto
	AGUA,               # Batalla en ríos/lagos
	AGUA_KYOGRE,        # Batalla contra Kyogre
	BAJO_AGUA,          # Batalla en zona submarina
	AGUA_PANTANOSA,     # Batalla en zona pantanosa
	MONTAÑA,            # Batalla en zona montañosa
	CUEVA,              # Batalla en cuevas
	CUEVA_GROUDON,      # Batalla contra Groudon
	EDIFICIO_1,         # Batalla en zona urbana 1
	EDIFICIO_2,         # Batalla en zona urbana 2
	EDIFICIO_3,         # Batalla en zona urbana 3
	CIELO,              # Batalla en el cielo
	ESTADIO_1,          # Batalla en estadio/arena 1
	ESTADIO_2,          # Batalla en estadio/arena 2
	ESTADIO_3,          # Batalla en estadio/arena 3
	ESTADIO_4,          # Batalla en estadio/arena 4
	ESTADIO_5,          # Batalla en estadio/arena 5
	ESTADIO_6,          # Batalla en estadio/arena 6
	ESTADIO_7,          # Batalla en estadio/arena 7
	ESTADIO_8           # Batalla en estadio/arena 8
}

## Enumerar temas gráficos disponibles para batallas (frente)
enum TemaBatallaFrente {
	BASICO,
	HIERBA_ALTA,
	HIERBA_MUY_ALTA,
	ARENA,
	ROCA,
	BURBUJAS,
	AGUA_BAJA,
	AGUA_PROFUNDA,
	MONTAÑA,
	CIELO
}

## Tipos de batalla
enum TipoBatalla {
	SALVAJE_TEST,
	SALVAJE,
	# SALVAJE_DOBLE,
	# SALVAJE_DOMINANTE,
	ENTRENADOR,
	# ENTRENADOR_LIDER,
	# ENTRENADOR_ALTO_MANDO,
	# ENTRENADOR_CAMPEON
}

## Formato de batalla para equipos de entrenador.
enum TipoBatallaEntrenador {
	SIMPLE,
	DOBLE
}

const TIPOS_BATALLA_ENTRENADOR := [
	{
		"id": TipoBatallaEntrenador.SIMPLE,
		"clave": "SIMPLE",
		"label": "Batalla simple"
	},
	{
		"id": TipoBatallaEntrenador.DOBLE,
		"clave": "DOBLE",
		"label": "Batalla doble"
	}
]

## Clima activo durante una batalla.
## Los valores 1-4 coinciden con los del selector en ConfiguracionDebugBatalla.
enum ClimaBatalla {
	NINGUNO = 0,
	SOLEADO = 1,
	LLUVIA = 2,
	TORMENTA_ARENA = 3,
	GRANIZO = 4,
}

## Formato del combate: slots activos por lado (plan 20260912, Alcance 1).
enum FormatoBatalla {
	SIMPLE,
	DOBLE,
}

## Ruleset del combate: qué acciones y salidas existen (plan 20260912, Alcance 1).
## SIN_EQUIPO no se pide al iniciar la batalla: se deriva del estado real del
## equipo (vacío o con todos los Pokémon DEBILITADOS).
enum RulesetBatalla {
	NORMAL,
	ZONA_SALVAJE,
	SIN_EQUIPO,
}

const CINTAS_POKEMON := {
	"CAMPEON": {
		"nombre": "CINTA CAMPEÓN",
		"descripcion": "CINTA del HALL FAMA por ganar al CAMPEÓN.",
		"orden": 0,
	},
	"CARISMA_NORMAL": {
		"nombre": "CINTA CARISMA NORMAL",
		"descripcion": "CONCURSO CARISMA. Ganador nivel normal.",
		"orden": 1,
	},
	"CARISMA_ALTO": {
		"nombre": "CINTA CARISMA ALTO",
		"descripcion": "CONCURSO CARISMA. Ganador nivel alto.",
		"orden": 2,
	},
	"CARISMA_AVANZADO": {
		"nombre": "CINTA CARISMA AVANZADO",
		"descripcion": "CONCURSO CARISMA. Ganador nivel avanzado.",
		"orden": 3,
	},
	"CARISMA_EXPERTO": {
		"nombre": "CINTA CARISMA EXPERTO",
		"descripcion": "CONCURSO CARISMA. Ganador nivel experto.",
		"orden": 4,
	},
	"BELLEZA_NORMAL": {
		"nombre": "CINTA BELLEZA NORMAL",
		"descripcion": "CONCURSO BELLEZA. Ganador nivel normal.",
		"orden": 5,
	},
	"BELLEZA_ALTO": {
		"nombre": "CINTA BELLEZA ALTO",
		"descripcion": "CONCURSO BELLEZA. Ganador nivel alto.",
		"orden": 6,
	},
	"BELLEZA_AVANZADO": {
		"nombre": "CINTA BELLEZA AVANZADO",
		"descripcion": "CONCURSO BELLEZA. Ganador nivel avanzado.",
		"orden": 7,
	},
	"BELLEZA_EXPERTO": {
		"nombre": "CINTA BELLEZA EXPERTO",
		"descripcion": "CONCURSO BELLEZA. Ganador nivel experto.",
		"orden": 8,
	},
	"DULZURA_NORMAL": {
		"nombre": "CINTA DULZURA NORMAL",
		"descripcion": "CONCURSO DULZURA. Ganador nivel normal.",
		"orden": 9,
	},
	"DULZURA_ALTO": {
		"nombre": "CINTA DULZURA ALTO",
		"descripcion": "CONCURSO DULZURA. Ganador nivel alto.",
		"orden": 10,
	},
	"DULZURA_AVANZADO": {
		"nombre": "CINTA DULZURA AVANZADO",
		"descripcion": "CONCURSO DULZURA. Ganador nivel avanzado.",
		"orden": 11,
	},
	"DULZURA_EXPERTO": {
		"nombre": "CINTA DULZURA EXPERTO",
		"descripcion": "CONCURSO DULZURA. Ganador nivel experto.",
		"orden": 12,
	},
	"INGENIO_NORMAL": {
		"nombre": "CINTA INGENIO NORMAL",
		"descripcion": "CONCURSO INGENIO. Ganador nivel normal.",
		"orden": 13,
	},
	"INGENIO_ALTO": {
		"nombre": "CINTA INGENIO ALTO",
		"descripcion": "CONCURSO INGENIO. Ganador nivel alto.",
		"orden": 14,
	},
	"INGENIO_AVANZADO": {
		"nombre": "CINTA INGENIO AVANZADO",
		"descripcion": "CONCURSO INGENIO. Ganador nivel avanzado.",
		"orden": 15,
	},
	"INGENIO_EXPERTO": {
		"nombre": "CINTA INGENIO EXPERTO",
		"descripcion": "CONCURSO INGENIO. Ganador nivel experto.",
		"orden": 16,
	},
	"DUREZA_NORMAL": {
		"nombre": "CINTA DUREZA NORMAL",
		"descripcion": "CONCURSO DUREZA. Ganador nivel normal.",
		"orden": 17,
	},
	"DUREZA_ALTO": {
		"nombre": "CINTA DUREZA ALTO",
		"descripcion": "CONCURSO DUREZA. Ganador nivel alto.",
		"orden": 18,
	},
	"DUREZA_AVANZADO": {
		"nombre": "CINTA DUREZA AVANZADO",
		"descripcion": "CONCURSO DUREZA. Ganador nivel avanzado.",
		"orden": 19,
	},
	"DUREZA_EXPERTO": {
		"nombre": "CINTA DUREZA EXPERTO",
		"descripcion": "CONCURSO DUREZA. Ganador nivel experto.",
		"orden": 20,
	},
	"GANADOR": {
		"nombre": "CINTA GANADOR",
		"descripcion": "CINTA ganada en NIVEL 50 de TORRE BATALLA.",
		"orden": 21,
	},
	"VICTORIA": {
		"nombre": "CINTA VICTORIA",
		"descripcion": "CINTA ganada en NIVEL 100 de TORRE BATALLA.",
		"orden": 22,
	},
	## artistRibbon: ganar un concurso EXPERTO con 800 puntos o más y llevar el
	## cuadro al MUSEO de CALAGUA (GiveMonArtistRibbon, src/contest_util.c).
	"ARTISTA": {
		"nombre": "CINTA ARTISTA",
		"descripcion": "CINTA ganada por ser un modelo a seguir.",
		"orden": 23,
	},
	"ESFUERZO": {
		"nombre": "CINTA ESFUERZO",
		"descripcion": "CINTA por esforzarse de manera excepcional.",
		"orden": 24,
	},
	## Cintas de regalo: en la GBA solo llegan por evento (GiveGiftRibbonToParty), con el
	## orden de los bits de BoxPokemon (src/pokemon.h). La ROM no les da nombre propio.
	"MARINA": {
		"nombre": "CINTA MARINA",
		"descripcion": "CINTA MARINA",
		"orden": 25,
	},
	"TIERRA": {
		"nombre": "CINTA TIERRA",
		"descripcion": "CINTA TIERRA",
		"orden": 26,
	},
	"CIELO": {
		"nombre": "CINTA CIELO",
		"descripcion": "CINTA CIELO",
		"orden": 27,
	},
	"PAIS": {
		"nombre": "CINTA PAÍS",
		"descripcion": "TORNEO REGIONAL 2003. CINTA CAMPEÓN.",
		"orden": 28,
	},
	"NACIONAL": {
		"nombre": "CINTA NACIONAL",
		"descripcion": "CINTA ganada por superar los obstáculos.",
		"orden": 29,
	},
	"PLANETA": {
		"nombre": "CINTA PLANETA",
		"descripcion": "100 victorias seguidas. CINTA conmemorativa.",
		"orden": 30,
	},
	"MUNDIAL": {
		"nombre": "CINTA MUNDIAL",
		"descripcion": "COPA DEL MUNDO 2003. CINTA CAMPEÓN.",
		"orden": 31,
	},
}

var time_scale = 1.0
var mapa_nodo: MapaConfiguracion = null
#var mapa_capa1: TileMapLayer = null 	# Capa de tiles
var capas_datos: Array[TPTileDataMap] = []  ## Todas las capas TPTileDataMap del mapa, ordenadas por layer_id
var capa_activa: int = 0  ## layer_id de la capa de datos activa
var foco_camara = null		## Se le asigna el nodo del jugador para que sea el foco de la cámara
var animacion_pisar_pasto = preload("res://escenas/mapas/animaciones/pasto_pisado.tscn")
var animacion_polvo = preload("res://escenas/mapas/animaciones/polvo_salto.tscn")
var animacion_flecha_salida = preload("res://escenas/mapas/animaciones/fecha_salida_abajo.tscn")



# Registro unificado de temas musicales.
# Carpeta base: res://Audio/emerald/
# Fuente de datos: res://BaseDatos/temas_musicales.json
# Se carga en _ready() para permitir edición sin modificar este script.
var TEMAS_REGISTRADOS: Dictionary = {}


## Buscar archivo del mapa por nombre de forma recursiva tomando de base res://escenas/mapas/
func _buscar_mapa_por_nombre(mapa_nombre: String) -> PackedScene:
	var ruta = _buscar_ruta_mapa_por_nombre("res://escenas/mapas/", mapa_nombre)
	if ruta.is_empty():
		return null
	return load(ruta)

func _buscar_ruta_mapa_por_nombre(base_path: String, mapa_nombre: String) -> String:
	var dir = DirAccess.open(base_path)
	if not dir:
		return ""
	dir.list_dir_begin()
	var file_name = ""
	while true:
		file_name = dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				var found = _buscar_ruta_mapa_por_nombre(base_path + file_name + "/", mapa_nombre)
				if found != "":
					dir.list_dir_end()
					return found
		else:
			# En una exportación las escenas aparecen como `<mapa>.tscn.remap`;
			# load() resuelve la ruta `.tscn` a través del remap.
			var archivo: String = file_name.trim_suffix(".remap")
			if archivo.ends_with(".tscn") and archivo.get_basename().to_lower() == mapa_nombre.to_lower():
				var found_path = base_path + archivo
				dir.list_dir_end()
				return found_path
	dir.list_dir_end()
	return ""




#var dic_puertas: Dictionary = {
	#"puerta_villa_raiz": preload("res://escenas/mapas/animaciones/puerta_casa_villa_raiz.tscn"),
	#"puerta_laboratorio": preload("res://escenas/mapas/animaciones/puerta_laboratorio.tscn")
#}
## Los valores 0..4 conservan las imágenes históricas serializadas. Los valores
## están guardados en las escenas: los estilos nuevos van siempre al final.
enum EstiloWarp {
	PUERTA_CASA_VILLA_RAIZ = 0,
	PUERTA_LABORATORIO = 1,
	PUERTA_CASA_PUEBLO_ESCASO = 2,
	PUERTA_CENTRO_POKEMON = 3,
	NINGUNA = 4,
	ESCALERA_NORMAL = 5,
	ESCALERA_CENTRO_SUBIR = 6,
	ESCALERA_CENTRO_BAJAR = 7,
	SERVICIO_COMBATE = 8,
	SERVICIO_INTERCAMBIO = 9,
	SERVICIO_RECORDS = 10,
	PUERTA_CASA_PETALIA = 11,
	PUERTA_GIMNASIO = 12,
	PUERTA_FERRICA_AZUL = 13,
	PUERTA_FERRICA_MARRON = 14,
	PUERTA_AZULIZA = 15,
	PUERTA_CONCURSO = 16,
	PUERTA_RUTA_110 = 17,
	PUERTA_VERDEGAL = 18,
	PUERTA_PARDAL = 19,
	PUERTA_SAFARI = 20,
	PUERTA_CALAGUA_CLUB = 21,
	PUERTA_CENTRO_COMERCIAL = 22,
	PUERTA_CC_ASCENSOR = 23,
	PUERTA_ALGARIA = 24,
	PUERTA_ALGARIA_INTERIOR = 25,
	PUERTA_OROMAR = 26,
	PUERTA_ESPACIAL = 27,
	PUERTA_NAO = 28,
	PUERTA_NAO_CAMAROTE = 29,
	PUERTA_COLOSALIA = 30,
	PUERTA_GIMNASIO_5 = 31,
	PUERTA_ARRECIPOLIS = 32,
	PUERTA_TORRE_ASCENSOR = 33,
	PUERTA_TORRE_EXTERIOR = 34,
}

## Escena de animación de cada estilo de puerta. Constante para que el inspector
## del editor (vista previa de estilo_warp) la lea sin instancia del autoload.
const SCN_PUERTAS: Dictionary = {
	EstiloWarp.PUERTA_CASA_VILLA_RAIZ: preload("res://escenas/mapas/animaciones/puerta_casa_villa_raiz.tscn"),
	EstiloWarp.PUERTA_LABORATORIO: preload("res://escenas/mapas/animaciones/puerta_laboratorio.tscn"),
	EstiloWarp.PUERTA_CASA_PUEBLO_ESCASO: preload("res://escenas/mapas/animaciones/puerta_casa_pueblo_escaso.tscn"),
	EstiloWarp.PUERTA_CENTRO_POKEMON: preload("res://escenas/mapas/animaciones/puerta_centro_pokemon.tscn"),
	EstiloWarp.PUERTA_CASA_PETALIA: preload("res://escenas/mapas/animaciones/puerta_casa_petalia.tscn"),
	EstiloWarp.PUERTA_GIMNASIO: preload("res://escenas/mapas/animaciones/puerta_gimnasio.tscn"),
	EstiloWarp.PUERTA_FERRICA_AZUL: preload("res://escenas/mapas/animaciones/puerta_ferrica_azul.tscn"),
	EstiloWarp.PUERTA_FERRICA_MARRON: preload("res://escenas/mapas/animaciones/puerta_ferrica_marron.tscn"),
	EstiloWarp.PUERTA_AZULIZA: preload("res://escenas/mapas/animaciones/puerta_azuliza.tscn"),
	EstiloWarp.PUERTA_CONCURSO: preload("res://escenas/mapas/animaciones/puerta_concurso.tscn"),
	EstiloWarp.PUERTA_RUTA_110: preload("res://escenas/mapas/animaciones/puerta_ruta_110.tscn"),
	EstiloWarp.PUERTA_VERDEGAL: preload("res://escenas/mapas/animaciones/puerta_verdegal.tscn"),
	EstiloWarp.PUERTA_PARDAL: preload("res://escenas/mapas/animaciones/puerta_pardal.tscn"),
	EstiloWarp.PUERTA_SAFARI: preload("res://escenas/mapas/animaciones/puerta_safari.tscn"),
	EstiloWarp.PUERTA_CALAGUA_CLUB: preload("res://escenas/mapas/animaciones/puerta_calagua_club.tscn"),
	EstiloWarp.PUERTA_CENTRO_COMERCIAL: preload("res://escenas/mapas/animaciones/puerta_centro_comercial.tscn"),
	EstiloWarp.PUERTA_ESPACIAL: preload("res://escenas/mapas/animaciones/puerta_espacial.tscn"),
	EstiloWarp.PUERTA_ALGARIA: preload("res://escenas/mapas/animaciones/puerta_algaria.tscn"),
	EstiloWarp.PUERTA_ALGARIA_INTERIOR: preload("res://escenas/mapas/animaciones/puerta_algaria_interior.tscn"),
	EstiloWarp.PUERTA_OROMAR: preload("res://escenas/mapas/animaciones/puerta_oromar.tscn"),
	EstiloWarp.PUERTA_CC_ASCENSOR: preload("res://escenas/mapas/animaciones/puerta_cc_ascensor.tscn"),
	EstiloWarp.PUERTA_NAO: preload("res://escenas/mapas/animaciones/puerta_nao.tscn"),
	EstiloWarp.PUERTA_NAO_CAMAROTE: preload("res://escenas/mapas/animaciones/puerta_nao_camarote.tscn"),
	EstiloWarp.PUERTA_COLOSALIA: preload("res://escenas/mapas/animaciones/puerta_colosalia.tscn"),
	EstiloWarp.PUERTA_GIMNASIO_5: preload("res://escenas/mapas/animaciones/puerta_gimnasio_5.tscn"),
	EstiloWarp.PUERTA_ARRECIPOLIS: preload("res://escenas/mapas/animaciones/puerta_arrecipolis.tscn"),
	EstiloWarp.PUERTA_TORRE_ASCENSOR: preload("res://escenas/mapas/animaciones/puerta_torre_ascensor.tscn"),
	EstiloWarp.PUERTA_TORRE_EXTERIOR: preload("res://escenas/mapas/animaciones/puerta_torre_exterior.tscn"),
}
const RUTA_PUERTA_SERVICIO := "res://escenas/mapas/animaciones/puerta_servicio_ruby.tscn"

## Compatibilidad para eventos ajenos a Warp que aún configuran imagen_puerta.
const enum_puertas = EstiloWarp

func escena_estilo_warp(estilo: int) -> PackedScene:
	if SCN_PUERTAS.has(estilo):
		return SCN_PUERTAS[estilo]
	if estilo in [EstiloWarp.SERVICIO_COMBATE, EstiloWarp.SERVICIO_INTERCAMBIO, EstiloWarp.SERVICIO_RECORDS]:
		return load(RUTA_PUERTA_SERVICIO)
	return null

# Opciones para el sonido
enum NivelAudio {
	NO,
	BAJO,
	NORMAL,
}

# Enums globales para opciones de juego (usados en EstructuraGuardado y UI)
enum VelocidadTexto { LENTA = 1, MEDIA = 2, RAPIDA = 3 }
# enum AnimacionCombate { NO = 0, SI = 1 }
enum TipoCombate { CAMBIAR = 0, MANTENER = 1 }
enum Sonido { NO = 0, BAJO = 1, NORMAL = 2 }
enum Controles { NORMAL = 0, LR = 1, L_A = 2 } # L_A representa L=A mapping

var se: Dictionary = {
	"SE_SLIDING_DOOR": preload("res://Audio/transiciones_centro/SE_SLIDING_DOOR.wav"),
	"SE_ESCALATOR": preload("res://Audio/transiciones_centro/SE_ESCALATOR.wav"),
	"puerta_salida": preload("res://Audio/SE/Exit Door.wav"),
	"puerta_entrada": preload("res://Audio/SE/Entering Door.wav"),
	"cursor_menu": preload("res://Audio/SE/Choose.WAV"),
	"menu": preload("res://Audio/SE/menu.wav"),
	"pc_abrir": preload("res://Audio/SE/computeropen.wav"),
	"pc_cerrar": preload("res://Audio/SE/computerclose.wav"),
	# Efectos Ruby aprobados (sin gritos). Todos extraídos del APU de la GBA
	# con el motor m4a original (herramientas/extraer_se.py); los ficheros
	# _old son sintetizados o remuestreados y quedan solo como referencia.
	"SE_USE_ITEM_KAIFUKU": preload("res://Audio/SE-AVXS/001_SE_USE_ITEM.wav"),
	"SE_PC_LOGIN": preload("res://Audio/SE-AVXS/002_SE_PC_LOGIN.wav"),
	"SE_PC_OFF": preload("res://Audio/SE-AVXS/003_SE_PC_OFF.wav"),
	"SE_SELECT": preload("res://Audio/SE-AVXS/005_SE_SELECT.wav"),
	"SE_CLICK": preload("res://Audio/SE-AVXS/036_SE_CLICK.wav"),
	"SE_ROTATING_GATE": preload("res://Audio/SE-AVXS/048_SE_ROTATING_GATE.wav"),
	"SE_M_EXPLOSION": preload("res://Audio/SE-AVXS/178_SE_M_EXPLOSION.wav"),
	"SE_M_FLY": preload("res://Audio/SE-AVXS/158_SE_M_FLY.wav"),
	"SE_PIN": preload("res://Audio/SE-AVXS/021_SE_PIN.wav"),
	"SE_SHOP": preload("res://Audio/SE-AVXS/095_SE_SHOP.wav"),  # caja registradora (compras y canjes)
	"SE_FALL_RU_HYUU": preload("res://Audio/SE-AVXS/043_SE_FALL.wav"),
	# Hielo fino del GIMNASIO de ARRECÍPOLIS (HieloFinoMapa).
	"SE_ICE_STAIRS": preload("res://Audio/SE-AVXS/040_SE_ICE_STAIRS.wav"),
	"SE_ICE_BREAK": preload("res://Audio/SE-AVXS/041_SE_ICE_BREAK.wav"),
	"SE_ICE_CRACK": preload("res://Audio/SE-AVXS/042_SE_ICE_CRACK.wav"),
	"SE_UNLOCK": preload("res://Audio/SE-AVXS/044_SE_UNLOCK.wav"),  # puertas del GIMNASIO de PETALIA
	"SE_WARP_IN": preload("res://Audio/SE-AVXS/045_SE_WARP_IN.wav"),
	# Antes apuntaban a 070 y 115, que en songs.h son SE_PUDDLE y
	# SE_BALL_TRAY_BALL: no eran el sonido que su nombre prometía.
	"SE_M_STRENGTH_ATERRIZAJE": preload("res://Audio/SE-AVXS/214_SE_M_STRENGTH.wav"),
	"SE_M_REFLECT": preload("res://Audio/SE-AVXS/207_SE_M_REFLECT.wav"),
	"SE_M_DIVE": preload("res://Audio/SE-AVXS/233_SE_M_DIVE.wav"),  # BUCEO al sumergirse y al emerger (SE_W291)
	"SE_BALL": preload("res://Audio/SE-AVXS/023_SE_BALL.wav"),
	"SE_SUCCESS": preload("res://Audio/SE-AVXS/031_SE_SUCCESS.wav"),
	"SE_FAILURE": preload("res://Audio/SE-AVXS/032_SE_FAILURE.wav"),
	"SE_EXP": preload("res://Audio/SE-AVXS/033_SE_EXP.wav"),
	"SE_LOW_HEALTH": preload("res://Audio/SE-AVXS/090_SE_LOW_HEALTH.wav"),  # un ciclo de 36 cuadros, en bucle (SirenaPsBajos)
	"SE_DOKU": preload("res://Audio/SE-AVXS/079_SE_DOKU.wav"),
	"SE_TRUCK_DOOR": preload("res://Audio/SE-AVXS/052_SE_TRUCK_DOOR.wav"),
	"SE_DANSA": preload("res://Audio/SE-AVXS/010_SE_DANSA.wav"),
	"SE_LEDGE": preload("res://Audio/SE-AVXS/010_SE_DANSA.wav"),  # mismo sonido: songs.h, SE_LEDGE = 10 // SE_DANSA
	"SE_WALL_HIT": preload("res://Audio/SE-AVXS/007_SE_WALL_HIT.wav"),
	"SE_DEX_SCROLL": preload("res://Audio/SE-AVXS/108_SE_DEX_SCROLL.wav"),
	"SE_DEX_PAGE": preload("res://Audio/SE-AVXS/109_SE_DEX_PAGE.wav"),
	"SE_DEX_SEARCH": preload("res://Audio/SE-AVXS/112_SE_DEX_SEARCH.wav"),
	"SE_MU_PACHI": preload("res://Audio/SE-AVXS/035_SE_MU_PACHI.wav"),  # GIMNASIO de AZULIZA: se ilumina la sala
	# Antes 104_SE_BT_START: 104 es SE_MUGSHOT (SE_BT_START es su nombre
	# japonés), así que el sonido era correcto pero el fichero, no.
	"SE_BT_START": preload("res://Audio/SE-AVXS/104_SE_MUGSHOT.wav"),
	"SE_HASHI": preload("res://Audio/SE-AVXS/071_SE_BRIDGE_WALK.wav"),
	"SE_PUDDLE": preload("res://Audio/SE-AVXS/070_SE_PUDDLE.wav"),  # troncos flotantes de PUEBLO OROMAR (TroncosOromarMapa)
	"SE_LAVARIDGE_FALL_WARP": preload("res://Audio/SE-AVXS/039_SE_LAVARIDGE_FALL_WARP.wav"),  # GIMNASIO de LAVACALDA: el jugador se hunde en la arena caliente
	"SE_M_DIG": preload("res://Audio/SE-AVXS/175_SE_M_DIG.wav"),  # GIMNASIO de LAVACALDA: el jugador sale de la arena
	# Tanda 3 (documentacion/20261019-extraccion-se-tanda3.md): APU de la GBA vía herramientas/extraer_se.py.
	# Faltan a propósito 049_SE_TRUCK_MOVE, 053_SE_BERRY_BLENDER y 083_SE_DOWNPOUR: son bucles que
	# salen cortados a ~4 s y no sirven como efecto de un disparo.
	"SE_PC_ON": preload("res://Audio/SE-AVXS/004_SE_PC_ON.wav"),  # PC de casa al encenderse
	"SE_WIN_OPEN": preload("res://Audio/SE-AVXS/006_SE_WIN_OPEN.wav"),  # abrir una ventana/menú del campo
	"SE_NOT_EFFECTIVE": preload("res://Audio/SE-AVXS/012_SE_NOT_EFFECTIVE.wav"),  # golpe poco eficaz
	"SE_EFFECTIVE": preload("res://Audio/SE-AVXS/013_SE_EFFECTIVE.wav"),  # golpe normal
	"SE_SUPER_EFFECTIVE": preload("res://Audio/SE-AVXS/014_SE_SUPER_EFFECTIVE.wav"),  # golpe muy eficaz
	"SE_BALL_OPEN": preload("res://Audio/SE-AVXS/015_SE_BALL_OPEN.wav"),  # la Poké Ball se abre y sale el Pokémon
	"SE_FAINT": preload("res://Audio/SE-AVXS/016_SE_FAINT.wav"),  # Pokémon debilitado
	"SE_FLEE": preload("res://Audio/SE-AVXS/017_SE_FLEE.wav"),  # huida del combate
	"SE_BANG": preload("res://Audio/SE-AVXS/020_SE_BANG.wav"),  # estruendo (Cueva Isla, Nueva Malvalona, puzles braille)
	"SE_DOOR": preload("res://Audio/SE-AVXS/008_SE_DOOR.wav"),  # CÁMARA SELLADA: las puertas de los REGI se abren a lo lejos
	"SE_CONTEST_PLACE": preload("res://Audio/SE-AVXS/024_SE_CONTEST_PLACE.wav"),  # concurso: puesto en el ranking
	"SE_WARP_OUT": preload("res://Audio/SE-AVXS/046_SE_WARP_OUT.wav"),  # salida de un teletransporte
	"SE_TRUCK_STOP": preload("res://Audio/SE-AVXS/050_SE_TRUCK_STOP.wav"),  # camión de mudanzas al parar
	"SE_TRUCK_UNLOAD": preload("res://Audio/SE-AVXS/051_SE_TRUCK_UNLOAD.wav"),  # camión de mudanzas al descargar
	"SE_CARD": preload("res://Audio/SE-AVXS/054_SE_CARD.wav"),  # ficha de entrenador
	"SE_SAVE": preload("res://Audio/SE-AVXS/055_SE_SAVE.wav"),  # partida guardada
	"SE_BALL_BOUNCE_1": preload("res://Audio/SE-AVXS/056_SE_BALL_BOUNCE_1.wav"),  # bola botando (captura, licuadora)
	"SE_BALL_BOUNCE_2": preload("res://Audio/SE-AVXS/057_SE_BALL_BOUNCE_2.wav"),
	"SE_BALL_BOUNCE_3": preload("res://Audio/SE-AVXS/058_SE_BALL_BOUNCE_3.wav"),
	"SE_BALL_BOUNCE_4": preload("res://Audio/SE-AVXS/059_SE_BALL_BOUNCE_4.wav"),
	"SE_BALL_TRADE": preload("res://Audio/SE-AVXS/060_SE_BALL_TRADE.wav"),  # el Pokémon entra en la ball (SE_SUIKOMU)
	"SE_BALL_THROW": preload("res://Audio/SE-AVXS/061_SE_BALL_THROW.wav"),  # lanzamiento de la ball
	"SE_NOTE_C": preload("res://Audio/SE-AVXS/062_SE_NOTE_C.wav"),  # decoración de base secreta: notas del sintetizador/alfombras
	"SE_NOTE_D": preload("res://Audio/SE-AVXS/063_SE_NOTE_D.wav"),
	"SE_NOTE_E": preload("res://Audio/SE-AVXS/064_SE_NOTE_E.wav"),
	"SE_NOTE_F": preload("res://Audio/SE-AVXS/065_SE_NOTE_F.wav"),
	"SE_NOTE_G": preload("res://Audio/SE-AVXS/066_SE_NOTE_G.wav"),
	"SE_NOTE_A": preload("res://Audio/SE-AVXS/067_SE_NOTE_A.wav"),
	"SE_NOTE_B": preload("res://Audio/SE-AVXS/068_SE_NOTE_B.wav"),
	"SE_NOTE_C_HIGH": preload("res://Audio/SE-AVXS/069_SE_NOTE_C_HIGH.wav"),
	"SE_DING_DONG": preload("res://Audio/SE-AVXS/073_SE_DING_DONG.wav"),  # ZONA SAFARI: aviso de fin de partida (SE_PINPON)
	"SE_BALLOON_RED": preload("res://Audio/SE-AVXS/074_SE_BALLOON_RED.wav"),  # decoración de base secreta: globos
	"SE_BALLOON_BLUE": preload("res://Audio/SE-AVXS/075_SE_BALLOON_BLUE.wav"),
	"SE_BALLOON_YELLOW": preload("res://Audio/SE-AVXS/076_SE_BALLOON_YELLOW.wav"),
	"SE_MUD_BALL": preload("res://Audio/SE-AVXS/078_SE_MUD_BALL.wav"),  # decoración de base secreta: bola de barro
	"SE_DOWNPOUR_STOP": preload("res://Audio/SE-AVXS/084_SE_DOWNPOUR_STOP.wav"),  # fin del aguacero
	"SE_ELEVATOR": preload("res://Audio/SE-AVXS/089_SE_ELEVATOR.wav"),  # ascensor (no es bucle: acaba a los 3,86 s)
	"SE_EXP_MAX": preload("res://Audio/SE-AVXS/091_SE_EXP_MAX.wav"),  # barra de experiencia llena
	"SE_CONTEST_HEART": preload("res://Audio/SE-AVXS/096_SE_CONTEST_HEART.wav"),  # concurso: corazón de puntos
	"SE_CONTEST_CURTAIN_RISE": preload("res://Audio/SE-AVXS/097_SE_CONTEST_CURTAIN_RISE.wav"),  # concurso: sube el telón
	"SE_CONTEST_CURTAIN_FALL": preload("res://Audio/SE-AVXS/098_SE_CONTEST_CURTAIN_FALL.wav"),  # concurso: baja el telón
	"SE_SHINY": preload("res://Audio/SE-AVXS/102_SE_SHINY.wav"),  # destello del Pokémon variocolor
	"SE_VEND": preload("res://Audio/SE-AVXS/106_SE_VEND.wav"),  # máquina expendedora
	"SE_ORB": preload("res://Audio/SE-AVXS/107_SE_ORB.wav"),  # Esfera Roja/Azul (Cueva Origen, Cueva Marina)
	"SE_POKENAV_ON": preload("res://Audio/SE-AVXS/110_SE_POKENAV_ON.wav"),  # POKéNAV al encenderse
	"SE_POKENAV_OFF": preload("res://Audio/SE-AVXS/111_SE_POKENAV_OFF.wav"),  # POKéNAV al apagarse
	"SE_EGG_HATCH": preload("res://Audio/SE-AVXS/113_SE_EGG_HATCH.wav"),  # eclosión del huevo
	"SE_BALL_TRAY_ENTER": preload("res://Audio/SE-AVXS/114_SE_BALL_TRAY_ENTER.wav"),  # bandeja de balls del combate
	"SE_BALL_TRAY_EXIT": preload("res://Audio/SE-AVXS/116_SE_BALL_TRAY_EXIT.wav"),
	"SE_GLASS_FLUTE": preload("res://Audio/SE-AVXS/117_SE_GLASS_FLUTE.wav"),  # FLAUTA VIDRIO, FL. BLANCA/NEGRA
	"SE_ITEMFINDER": preload("res://Audio/SE-AVXS/072_SE_ITEMFINDER.wav"),  # BUSCAOBJETOS
	"SE_M_SWEET_SCENT": preload("res://Audio/SE-AVXS/236_SE_M_SWEET_SCENT.wav"),  # AROMA DULCE en el campo
	"SE_M_DETECT": preload("res://Audio/SE-AVXS/209_SE_M_DETECT.wav"),  # Cueva Origen / Cueva Marina (escena de la esfera)
	"SE_M_STAT_INCREASE": preload("res://Audio/SE-AVXS/239_SE_M_STAT_INCREASE.wav"),  # sube una estadística en combate
	"SE_M_STAT_DECREASE": preload("res://Audio/SE-AVXS/245_SE_M_STAT_DECREASE.wav"),  # baja una estadística en combate
}
@warning_ignore("unused_signal")
signal play_sound(sound_name: String)

@warning_ignore("unused_signal")
signal batalla_menu1_seleccionado(opcion: int)
@warning_ignore("unused_signal")
signal batalla_movimiento_seleccionado(opcion: int)
@warning_ignore("unused_signal")
signal buscar_evento_accion(coord_celda: Vector2i, mapa_origen: Node)


# Tabla de tipos de movimiento
# https://www.nintenderos.com/wp-content/uploads/2024/01/tabla-tipo-pokemon.jpg.webp
var tabla_tipos: Dictionary = {
	"NORMAL"   : { "NORMAL": 1.0, "LUCHA": 1.0, "VOLADOR": 1.0, "VENENO": 1.0, "TIERRA": 1.0, "ROCA": 0.5, "BICHO": 1.0, "FANTASMA": 0.0, "ACERO": 0.5, "FUEGO": 1.0, "AGUA": 1.0, "PLANTA": 1.0, "ELECTRICO": 1.0, "PSIQUICO": 1.0, "HIELO": 1.0, "DRAGON": 1.0, "SINIESTRO": 1.0, "HADA": 1.0 },
	"LUCHA"    : { "NORMAL": 2.0, "LUCHA": 1.0, "VOLADOR": 0.5, "VENENO": 0.5, "TIERRA": 1.0, "ROCA": 2.0, "BICHO": 0.5, "FANTASMA": 0.0, "ACERO": 2.0, "FUEGO": 1.0, "AGUA": 1.0, "PLANTA": 1.0, "ELECTRICO": 1.0, "PSIQUICO": 0.5, "HIELO": 2.0, "DRAGON": 1.0, "SINIESTRO": 2.0, "HADA": 0.5 },
	"VOLADOR"  : { "NORMAL": 1.0, "LUCHA": 2.0, "VOLADOR": 1.0, "VENENO": 1.0, "TIERRA": 1.0, "ROCA": 0.5, "BICHO": 2.0, "FANTASMA": 1.0, "ACERO": 0.5, "FUEGO": 1.0, "AGUA": 1.0, "PLANTA": 2.0, "ELECTRICO": 0.5, "PSIQUICO": 1.0, "HIELO": 1.0, "DRAGON": 1.0, "SINIESTRO": 1.0, "HADA": 1.0 },
	"VENENO"   : { "NORMAL": 1.0, "LUCHA": 1.0, "VOLADOR": 1.0, "VENENO": 0.5, "TIERRA": 0.5, "ROCA": 0.5, "BICHO": 1.0, "FANTASMA": 0.5, "ACERO": 0.0, "FUEGO": 1.0, "AGUA": 1.0, "PLANTA": 2.0, "ELECTRICO": 1.0, "PSIQUICO": 1.0, "HIELO": 1.0, "DRAGON": 1.0, "SINIESTRO": 1.0, "HADA": 2.0 },
	"TIERRA"   : { "NORMAL": 1.0, "LUCHA": 1.0, "VOLADOR": 0.0, "VENENO": 2.0, "TIERRA": 1.0, "ROCA": 2.0, "BICHO": 0.5, "FANTASMA": 1.0, "ACERO": 2.0, "FUEGO": 2.0, "AGUA": 1.0, "PLANTA": 0.5, "ELECTRICO": 2.0, "PSIQUICO": 1.0, "HIELO": 1.0, "DRAGON": 1.0, "SINIESTRO": 1.0, "HADA": 1.0 },
	"ROCA"     : { "NORMAL": 1.0, "LUCHA": 0.5, "VOLADOR": 2.0, "VENENO": 1.0, "TIERRA": 0.5, "ROCA": 1.0, "BICHO": 2.0, "FANTASMA": 1.0, "ACERO": 0.5, "FUEGO": 2.0, "AGUA": 1.0, "PLANTA": 1.0, "ELECTRICO": 1.0, "PSIQUICO": 1.0, "HIELO": 2.0, "DRAGON": 1.0, "SINIESTRO": 1.0, "HADA": 1.0 },
	"BICHO"    : { "NORMAL": 1.0, "LUCHA": 0.5, "VOLADOR": 0.5, "VENENO": 0.5, "TIERRA": 1.0, "ROCA": 1.0, "BICHO": 1.0, "FANTASMA": 0.5, "ACERO": 0.5, "FUEGO": 0.5, "AGUA": 1.0, "PLANTA": 2.0, "ELECTRICO": 1.0, "PSIQUICO": 2.0, "HIELO": 1.0, "DRAGON": 1.0, "SINIESTRO": 2.0, "HADA": 0.5 },
	"FANTASMA" : { "NORMAL": 0.0, "LUCHA": 1.0, "VOLADOR": 1.0, "VENENO": 1.0, "TIERRA": 1.0, "ROCA": 1.0, "BICHO": 1.0, "FANTASMA": 2.0, "ACERO": 1.0, "FUEGO": 1.0, "AGUA": 1.0, "PLANTA": 1.0, "ELECTRICO": 1.0, "PSIQUICO": 2.0, "HIELO": 1.0, "DRAGON": 1.0, "SINIESTRO": 0.5, "HADA": 1.0 },
	"ACERO"    : { "NORMAL": 1.0, "LUCHA": 1.0, "VOLADOR": 1.0, "VENENO": 1.0, "TIERRA": 1.0, "ROCA": 2.0, "BICHO": 1.0, "FANTASMA": 1.0, "ACERO": 0.5, "FUEGO": 0.5, "AGUA": 0.5, "PLANTA": 1.0, "ELECTRICO": 0.5, "PSIQUICO": 1.0, "HIELO": 2.0, "DRAGON": 1.0, "SINIESTRO": 1.0, "HADA": 2.0 },
	"FUEGO"    : { "NORMAL": 1.0, "LUCHA": 1.0, "VOLADOR": 1.0, "VENENO": 1.0, "TIERRA": 1.0, "ROCA": 0.5, "BICHO": 2.0, "FANTASMA": 1.0, "ACERO": 2.0, "FUEGO": 0.5, "AGUA": 0.5, "PLANTA": 2.0, "ELECTRICO": 1.0, "PSIQUICO": 1.0, "HIELO": 2.0, "DRAGON": 0.5, "SINIESTRO": 1.0, "HADA": 1.0 },
	"AGUA"     : { "NORMAL": 1.0, "LUCHA": 1.0, "VOLADOR": 1.0, "VENENO": 1.0, "TIERRA": 2.0, "ROCA": 2.0, "BICHO": 1.0, "FANTASMA": 1.0, "ACERO": 1.0, "FUEGO": 2.0, "AGUA": 0.5, "PLANTA": 0.5, "ELECTRICO": 1.0, "PSIQUICO": 1.0, "HIELO": 1.0, "DRAGON": 0.5, "SINIESTRO": 1.0, "HADA": 1.0 },
	"PLANTA"   : { "NORMAL": 1.0, "LUCHA": 1.0, "VOLADOR": 0.5, "VENENO": 0.5, "TIERRA": 2.0, "ROCA": 2.0, "BICHO": 0.5, "FANTASMA": 1.0, "ACERO": 0.5, "FUEGO": 0.5, "AGUA": 2.0, "PLANTA": 0.5, "ELECTRICO": 1.0, "PSIQUICO": 1.0, "HIELO": 1.0, "DRAGON": 0.5, "SINIESTRO": 1.0, "HADA": 1.0 },
	"ELECTRICO": { "NORMAL": 1.0, "LUCHA": 1.0, "VOLADOR": 2.0, "VENENO": 1.0, "TIERRA": 0.0, "ROCA": 1.0, "BICHO": 1.0, "FANTASMA": 1.0, "ACERO": 1.0, "FUEGO": 1.0, "AGUA": 2.0, "PLANTA": 0.5, "ELECTRICO": 0.5, "PSIQUICO": 1.0, "HIELO": 1.0, "DRAGON": 0.5, "SINIESTRO": 1.0, "HADA": 1.0 },
	"PSIQUICO" : { "NORMAL": 1.0, "LUCHA": 2.0, "VOLADOR": 1.0, "VENENO": 2.0, "TIERRA": 1.0, "ROCA": 1.0, "BICHO": 1.0, "FANTASMA": 1.0, "ACERO": 0.5, "FUEGO": 1.0, "AGUA": 1.0, "PLANTA": 1.0, "ELECTRICO": 1.0, "PSIQUICO": 0.5, "HIELO": 1.0, "DRAGON": 1.0, "SINIESTRO": 0.0, "HADA": 1.0 },
	"HIELO"    : { "NORMAL": 1.0, "LUCHA": 1.0, "VOLADOR": 2.0, "VENENO": 1.0, "TIERRA": 2.0, "ROCA": 1.0, "BICHO": 1.0, "FANTASMA": 1.0, "ACERO": 0.5, "FUEGO": 0.5, "AGUA": 0.5, "PLANTA": 2.0, "ELECTRICO": 1.0, "PSIQUICO": 1.0, "HIELO": 0.5, "DRAGON": 2.0, "SINIESTRO": 1.0, "HADA": 1.0 },
	"DRAGON"   : { "NORMAL": 1.0, "LUCHA": 1.0, "VOLADOR": 1.0, "VENENO": 1.0, "TIERRA": 1.0, "ROCA": 1.0, "BICHO": 1.0, "FANTASMA": 1.0, "ACERO": 0.5, "FUEGO": 1.0, "AGUA": 1.0, "PLANTA": 1.0, "ELECTRICO": 1.0, "PSIQUICO": 1.0, "HIELO": 1.0, "DRAGON": 2.0, "SINIESTRO": 1.0, "HADA": 0.0 },
	"SINIESTRO": { "NORMAL": 1.0, "LUCHA": 0.5, "VOLADOR": 1.0, "VENENO": 1.0, "TIERRA": 1.0, "ROCA": 1.0, "BICHO": 1.0, "FANTASMA": 2.0, "ACERO": 1.0, "FUEGO": 1.0, "AGUA": 1.0, "PLANTA": 1.0, "ELECTRICO": 1.0, "PSIQUICO": 2.0, "HIELO": 1.0, "DRAGON": 1.0, "SINIESTRO": 0.5, "HADA": 0.5 },
	"HADA"     : { "NORMAL": 1.0, "LUCHA": 2.0, "VOLADOR": 1.0, "VENENO": 0.5, "TIERRA": 1.0, "ROCA": 1.0, "BICHO": 1.0, "FANTASMA": 1.0, "ACERO": 0.5, "FUEGO": 0.5, "AGUA": 1.0, "PLANTA": 1.0, "ELECTRICO": 1.0, "PSIQUICO": 1.0, "HIELO": 1.0, "DRAGON": 2.0, "SINIESTRO": 2.0, "HADA": 1.0 },
}

enum enum_dir_cartel { TODAS_DIRECCIONES, ABAJO}

func set_time_scale(new_scale):
	Engine.time_scale = new_scale

func _ready():
	# Fondo negro solo en el juego; el editor conserva el gris por defecto
	RenderingServer.set_default_clear_color(Color.BLACK)
	set_time_scale(time_scale)
	_cargar_temas_musicales()
	connect("configurar_audio", Callable(self, "_on_configurar_audio"))
	_on_configurar_audio(NivelAudio.BAJO)
	# Activar procesamiento para contabilizar tiempo de juego
	set_process(true)

## Carga el diccionario TEMAS_REGISTRADOS desde BaseDatos/temas_musicales.json.
func _cargar_temas_musicales() -> void:
	var path := "res://BaseDatos/temas_musicales.json"
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[Singleton] No se pudo abrir %s — los temas musicales estarán vacíos." % path)
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) == TYPE_DICTIONARY and data.has("temas"):
		TEMAS_REGISTRADOS = data["temas"]
		print("[Singleton] Temas musicales cargados: %d entradas" % TEMAS_REGISTRADOS.size())
	else:
		push_error("[Singleton] Formato inválido en temas_musicales.json")

## Registra el mapa actual y resuelve la capa de datos preferida.
## Si la capa solicitada no existe, intenta layer_id=0; si tampoco existe, deja solo el layer_id.
func set_tile_map(map: MapaConfiguracion) -> void:
	set_tile_map_con_capa(map, 0)

func set_tile_map_con_capa(map: MapaConfiguracion, preferred_layer_id: int) -> void:
	mapa_nodo = map
	capas_datos = []
	capa_activa = preferred_layer_id
	# Recoger TODOS los nodos TPTileDataMap (búsqueda recursiva)
	if map != null:
		_recoger_capas_datos(map)
	capas_datos.sort_custom(func(a, b): return a.layer_id < b.layer_id)
	var capa_resuelta: TPTileDataMap = map.get_capa_resuelta(preferred_layer_id) if map != null else null
	if capa_resuelta == null:
		_aplicar_z_index_foco_por_capa(0)
		if map == null or capas_datos.is_empty():
			print("⚠️ [Singleton] No se encontró nodo TPTileDataMap en el mapa: %s" % (String(map.name) if map != null else "<null>"))
		else:
			print("⚠️ [Singleton] No existe layer_id=%d ni fallback layer_id=0 en el mapa %s" % [preferred_layer_id, map.name])
	else:
		capa_activa = capa_resuelta.layer_id
		_aplicar_z_index_foco_por_capa(capa_activa)
		print("📍 [Singleton] Capas de datos cargadas: %d (activa: layer_id=%d, solicitada=%d)" % [capas_datos.size(), capa_activa, preferred_layer_id])

## Recolecta recursivamente todos los nodos TPTileDataMap del árbol dado.
func _recoger_capas_datos(node: Node) -> void:
	for child in node.get_children():
		if child is TPTileDataMap:
			capas_datos.append(child)
		_recoger_capas_datos(child)

## Devuelve el TPTileDataMap cuyo layer_id coincide, o null si no existe.
## Con mapa registrado delega en él (salta grupos ocultos, como las mareas de MareaCueva).
func get_capa_por_id(layer_id: int) -> TPTileDataMap:
	if is_instance_valid(mapa_nodo):
		return mapa_nodo.get_capa_por_id(layer_id)
	for capa in capas_datos:
		if capa.layer_id == layer_id:
			return capa
	return null

## Cambia la capa de datos activa al layer_id indicado.
## Ajusta el z_index del jugador según la capa: capa_activa * Z_INDEX_POR_CAPA.
func set_capa_activa(layer_id: int) -> void:
	var capa := get_capa_por_id(layer_id)
	if capa != null:
		capa_activa = layer_id
		_aplicar_z_index_foco_por_capa(layer_id)
		print("📍 [Singleton] Capa activa → layer_id=%d  z_index=%d" % [layer_id, _obtener_z_index_actual_foco()])
	else:
		push_warning("[Singleton] No existe capa con layer_id=%d" % layer_id)

## Se le asigna el nodo del jugador para que sea el foco de la cámara
func set_foco_camara(foco):
	foco_camara = foco
	_aplicar_z_index_foco_por_capa(capa_activa)
	print("seteado foco: ", foco, " pos", foco.position)

func _aplicar_z_index_foco_por_capa(layer_id: int) -> void:
	if not (foco_camara is CanvasItem):
		return
	var base_z_index := _obtener_base_z_index_foco()
	var offset_elevacion := 0
	if foco_camara.has_method(&"get_offset_elevacion"):
		offset_elevacion = int(foco_camara.get_offset_elevacion())  # PUNTO_ELEVADO vigente
	foco_camara.z_index = base_z_index + layer_id * Z_INDEX_POR_CAPA + offset_elevacion

func _obtener_base_z_index_foco() -> int:
	if not (foco_camara is CanvasItem):
		return 0
	if foco_camara.has_meta("z_index_base"):
		return int(foco_camara.get_meta("z_index_base"))
	return int(posmod(foco_camara.z_index, Z_INDEX_POR_CAPA))

func _obtener_z_index_actual_foco() -> int:
	if not (foco_camara is CanvasItem):
		return 0
	return int(foco_camara.z_index)

# func conectar_escalera(destino: String, _posicion: Vector2, _direccion: Vector2 = Vector2.DOWN, _dar_paso: bool = false) -> void:
# 	if mapa_nodo:
# 		mapa_nodo.queue_free()

# 	mapa_nodo = _buscar_mapa_por_nombre(destino).instantiate()
	#get_tree().current_scene.add_child(current_map)
	#var player = get_tree().root.get_node("Jugador")
	#player.position = player_position

#func _on_play_sound(sound_name: String) -> void:
	#if sound_name in se:
		#var sfx_player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
		#add_child(sfx_player)
		#sfx_player.stream = se[sound_name]
		#sfx_player.play()
		## Opcional: Conectar la señal finished del reproductor para eliminarlo después de que termine de reproducir
		#sfx_player.connect("finished", Callable(sfx_player, "queue_free"))
	#else:
		#print("Sound not found: ", sound_name)

@warning_ignore("unused_signal")
signal play_musica_fondo(recurso: String, ini: float, fin: float)

var no_move: bool = false      # Indica que no se deben mover los personajes de sus posiciones porque hay menú o diálogo

# Datos de batalla pendiente para pasar a la escena de batalla
# var datos_batalla_pendiente: Dictionary = {}

@warning_ignore("unused_signal")
signal salir_ventana_opciones()

# Acumulador para tiempo de juego (fraccional). Se suma a SistemaGuardado.datos_vivos.tiempo_juego cuando >= 1s
var _tiempo_acumulador: float = 0.0
var _window_focused: bool = true

signal configurar_audio(opcion: int)
@warning_ignore("unused_signal")
signal opciones_cambiadas()

func _on_configurar_audio(opcion: int) -> void:
	match opcion:
		NivelAudio.NO:
			var bus = AudioServer.get_bus_index("Master")
			AudioServer.set_bus_mute(bus, true)
		NivelAudio.BAJO:
			var bus = AudioServer.get_bus_index("Master")
			AudioServer.set_bus_mute(bus, false)
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), -10)
		NivelAudio.NORMAL:
			var bus = AudioServer.get_bus_index("Master")
			AudioServer.set_bus_mute(bus, false)
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), 0)

# === FUNCIONES DE TIPOS DE POKÉMON ===

## Convierte un ID de tipo de BD al nombre del tipo.
func obtener_nombre_tipo_por_id(tipo_id: int) -> String:
	match tipo_id:
		1: return "NORMAL"
		2: return "LUCHA"
		3: return "VENENO"
		4: return "TIERRA"
		5: return "VOLADOR"
		6: return "BICHO"
		7: return "ROCA"
		8: return "FANTASMA"
		9: return "ACERO"
		10: return "FUEGO"
		11: return "AGUA"
		12: return "PLANTA"
		13: return "ELECTRICO"
		14: return "PSIQUICO"
		15: return "HIELO"
		16: return "DRAGON"
		17: return "SINIESTRO"
		18: return "HADA"
		_: return "DESCONOCIDO"

## Convierte un nombre de tipo al ID de BD.
func obtener_id_tipo_por_nombre(nombre_tipo: String) -> int:
	match nombre_tipo.to_upper():
		"NORMAL": return 1
		"LUCHA": return 2
		"VENENO": return 3
		"TIERRA": return 4
		"VOLADOR": return 5
		"BICHO": return 6
		"ROCA": return 7
		"FANTASMA": return 8
		"ACERO": return 9
		"FUEGO": return 10
		"AGUA": return 11
		"PLANTA": return 12
		"ELECTRICO": return 13
		"PSIQUICO": return 14
		"HIELO": return 15
		"DRAGON": return 16
		"SINIESTRO": return 17
		"HADA": return 18
		_: return 0

## Convierte un ID de tipo de BD al frame del AnimatedSprite2D (0-17).
func obtener_frame_tipo(tipo_id: int) -> int:
	if tipo_id >= 1 and tipo_id <= 18:
		return tipo_id - 1
	else:
		return -1  # Frame inválido

## Convierte un nombre de estado a su valor enum correspondiente.
func obtener_enum_estado(estado: String) -> int:
	match estado.to_upper():
		"DEBILITADO": return ProblemaEstado.DEBILITADO
		"ENVENENADO": return ProblemaEstado.ENVENENADO
		"CONGELADO": return ProblemaEstado.CONGELADO
		"QUEMADO": return ProblemaEstado.QUEMADO
		"PARALIZADO": return ProblemaEstado.PARALIZADO
		"DORMIDO": return ProblemaEstado.DORMIDO
		"POKERUS": return ProblemaEstado.POKERUS
		_: return ProblemaEstado.NORMAL # No tiene problemas de estado

func obtener_nombre_estado(estado_enum: int) -> String:
	match estado_enum:
		ProblemaEstado.DEBILITADO: return "DEBILITADO"
		ProblemaEstado.ENVENENADO: return "ENVENENADO"
		ProblemaEstado.CONGELADO: return "CONGELADO"
		ProblemaEstado.QUEMADO: return "QUEMADO"
		ProblemaEstado.PARALIZADO: return "PARALIZADO"
		ProblemaEstado.DORMIDO: return "DORMIDO"
		ProblemaEstado.POKERUS: return "POKERUS"
		_: return "NORMAL"

func transicion(tipo: String, duracion: float = 0.3) -> bool:
	print("🔄 [SINGLETON] Iniciando transición:", tipo)
	match tipo:
		"aclarar":
			var telon = obtener_nodo("Telon")
			if telon:
				print("🔄 [SINGLETON] Aclarando telón...")
				telon.aclarar(duracion)
				await telon.pantalla_aclarada
				return true

		"oscurecer":
			var telon = obtener_nodo("Telon")
			if telon:
				print("🔄 [SINGLETON] Oscureciendo telón...")
				telon.oscurecer(duracion)
				await telon.pantalla_oscurecida
				return true

	print("🔄 [SINGLETON] Transición no reconocida:", tipo)
	return false

## Obtiene un nodo por su nombre desde el árbol de nodos, buscando de forma recursiva.
## Actualmente solo implementado para 'Telon'.
func obtener_nodo(nombre: String) -> Node:
	match nombre:
		"Telon":
			var admin = get_tree().root.get_node_or_null("AdministradorMapa")
			if admin:
				return admin.get_node_or_null("Menu/Telon")
			else:
				print("❌ [SINGLETON] No se encontró el nodo 'AdministradorMapa' para acceder al Telón")
				return null
		"Admin":
			var admin = get_tree().root.get_node_or_null("AdministradorMapa")
			if admin:
				return admin
			else:
				print("❌ [SINGLETON] No se encontró el nodo 'AdministradorMapa'")
				return null
		"Jugador":
			var admin = get_tree().root.get_node_or_null("AdministradorMapa")
			if admin:
				return admin.jugador
			else:
				print("❌ [SINGLETON] No se encontró el nodo 'AdministradorMapa' para acceder al Jugador")
				return null
		"Menu":
			var admin = get_tree().root.get_node_or_null("AdministradorMapa")
			if admin:
				return admin.get_node_or_null("Menu")
			else:
				print("❌ [SINGLETON] No se encontró el nodo 'AdministradorMapa' para acceder al Menú")
				return null
		"CapaBatalla":
			var canva: CanvasLayer = get_tree().root.get_node_or_null("CapaBatalla")
			if canva:
				return canva
			else:
				canva = CanvasLayer.new()
				canva.name = "CapaBatalla"
				canva.layer = 10
				# call_deferred para evitar "Parent node is busy setting up children" durante _ready()
				get_tree().root.add_child.call_deferred(canva)
				return canva
		"ReproductorMusica":
			var admin = get_tree().root.get_node_or_null("AdministradorMapa")
			if admin:
				return admin.musica_player
			else:
				print("❌ [SINGLETON] No se encontró el nodo 'AdministradorMapa' para acceder al Reproductor de Música")
				return null
	return null

## Imprime los nodos hijos de un nodo dado.
func imprimir_nodos_hijos(nodo: Node):
	if not nodo:
		print("❌ [SINGLETON] Nodo no válido.")
		return

	print("🔍 [SINGLETON] Nodos hijos de:", nodo.name)
	for hijo in nodo.get_children():
		print("  -", hijo.name)

func format_number(number: int) -> String:
	var num_str: String = str(number)
	var result: String = ""
	var count: int = 0
	var is_negative: bool = false

	if number < 0:
		is_negative = true
		num_str = str(abs(number))

	# Recorre el número al revés para añadir los puntos
	for i in range(num_str.length() - 1, -1, -1):
		result = num_str[i] + result
		count += 1
		if count % 3 == 0 and i != 0:
			result = "." + result

	# Añade el signo negativo si el número era negativo
	if is_negative:
		result = "-" + result

	return result


## FLAG_SYS_POKENAV_GET: muestra POKéNAV en el menú de pausa.
const BANDERA_POKENAV: String = "pokenav_obtenido"

## Configuración del menú de pausa
var opciones_menu_pausa: Array[Variant] = [
	{
		"nombre": "POKéDEX",
		"visible": false,  # Se activa cuando el jugador obtiene la Pokédex
		"accion": "pokedex"
	},
	{
		"nombre": "POKéMON",
		"visible": false,  # Se activa cuando el jugador tiene Pokémon
		"accion": "pokemon"
	},
	{
		"nombre": "MOCHILA",
		"visible": true,
		"accion": "mochila"
	},
	{
		"nombre": "POKéNAV",
		"visible": false,  # Se activa cuando el jugador obtiene el PokéNav
		"accion": "pokenav"
	},
	{
		"nombre": "JUGADOR",  # Ficha del entrenador
		"visible": true,
		"accion": "jugador"
	},
	{
		"nombre": "GUARDAR",
		"visible": true,
		"accion": "guardar"
	},
	{
		"nombre": "OPCIONES",
		"visible": true,
		"accion": "opciones"
	},
	{
		"nombre": "SALIR",
		"visible": true,
		"accion": "salir"
	}
]

## Función para activar/desactivar opciones del menú
func establecer_opcion_menu_visible(accion: String, visible: bool):
	for opcion in opciones_menu_pausa:
		if opcion.accion == accion:
			opcion.visible = visible
			break

## Función para actualizar el nombre de una opción del menú
func establecer_nombre_opcion_menu(accion: String, nuevo_nombre: String):
	for opcion in opciones_menu_pausa:
		if opcion.accion == accion:
			opcion.nombre = nuevo_nombre
			break

## Función para actualizar el nombre del jugador en el menú
func actualizar_nombre_jugador_menu() -> void:
	var nombre_jugador: String = SistemaGuardado.get_nombre_jugador()

	# Si el nombre está vacío, usar "JUGADOR" como fallback
	if nombre_jugador == null or nombre_jugador == "":
		nombre_jugador = "JUGADOR"

	establecer_nombre_opcion_menu("jugador", nombre_jugador)
	print("🎮 [SINGLETON] Nombre de jugador actualizado en menú: %s" % nombre_jugador.to_upper())

## Función para obtener opciones visibles del menú
func obtener_opciones_menu_visibles() -> Array:
	var opciones_visibles = []
	for opcion in opciones_menu_pausa:
		if opcion.visible:
			opciones_visibles.append(opcion)
	return opciones_visibles

func get_cuadro_dialogo() -> NinePatchRect:
	return get_tree().root.get_node_or_null("AdministradorMapa/Menu/CuadroDialogo")

## Método de conveniencia para mostrar texto usando DialogManager
func mostrar_texto(texto: String, callback: Callable = Callable(), omitir_sonido_inicio: bool = false) -> void:
	if has_node("/root/DialogManager"):
		DialogManager.show_text(texto, callback, omitir_sonido_inicio)
	else:
		# Fallback al sistema anterior
		var cuadro = get_cuadro_dialogo()
		if cuadro:
			cuadro.mostrar(texto, true, true, callback, false, omitir_sonido_inicio)

## Método de conveniencia para mostrar confirmación de guardado
func mostrar_confirmacion_guardado(callback: Callable = Callable()) -> void:
	if has_node("/root/DialogManager"):
		DialogManager.show_save_confirmation(callback)
	else:
		print("❌ DialogManager no disponible")


func _process(delta: float) -> void:
	"""Cuenta tiempo de juego en segundos y lo guarda en SistemaGuardado.datos_vivos.tiempo_juego.
	Solo cuenta cuando la ventana tiene foco y el juego no está en estado de pausa (no_move == false).
	"""
	# Usar el estado actualizado por _notification
	if not _window_focused:
		return

	if no_move:
		return

	# Solo actualizar si SistemaGuardado está presente
	if typeof(SistemaGuardado) == TYPE_NIL or not SistemaGuardado.datos_vivos:
		return

	_tiempo_acumulador += delta
	if _tiempo_acumulador >= 1.0:
		var segundos = int(_tiempo_acumulador)
		SistemaGuardado.datos_vivos.tiempo_juego = int(SistemaGuardado.datos_vivos.tiempo_juego) + segundos
		_tiempo_acumulador -= float(segundos)


func _notification(what: int) -> void:
	# Actualizar estado de foco de ventana (compatibilidad entre plataformas)
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_window_focused = true
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_window_focused = false

## Función de prueba temporal para el sistema de guardado
func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept") and Input.is_key_pressed(KEY_F5):
		print("🧪 [PRUEBA] Iniciando prueba del sistema de guardado...")
		_probar_sistema_guardado()

## Función de prueba para verificar el sistema de guardado con menú de confirmación
func _probar_sistema_guardado():
	print("🧪 [PRUEBA] Probando confirmación de guardado...")
	mostrar_confirmacion_guardado()  # Esto debería llamar a DialogManager.show_save_confirmation()

## Función para obtener el nombre del lugar
func _get_nombre_lugar() -> String:
	## Buscar mapa actual en el nodo administrador de mapas
	var admin_mapas = get_tree().root.get_node_or_null("AdministradorMapa")
	if admin_mapas:
		var mapa_actual = admin_mapas.mapa_actual
		if mapa_actual:
			# Interiores sin nombre propio heredan el de su mapa exterior asociado.
			var nombre: String = admin_mapas.obtener_nombre_lugar_actual()
			if not nombre.is_empty():
				return nombre
			_loggear("❌ El mapa actual '%s' no tiene seccion (clave de lugar) configurada." % mapa_actual.name)
		else:
			_loggear("❌ No se encontró el mapa actual.")
	return "Desconocido"

## Reproducir música de fondo. `interrumpir_transicion` corta el fundido en curso
## (p. ej. el del tema del mapa al entrar) en vez de descartar esta petición.
func reproducir_tema(nombre: String, interrumpir_transicion: bool = false) -> void:
	var reproductor: NuevoAudioStreamPlayer = obtener_nodo("ReproductorMusica")
	if reproductor:
		reproductor.reproducir_tema(nombre, 0, false, interrumpir_transicion) # Tipo 0 es inmediato
	else:
		_loggear("❌ No se encontró el ReproductorMusica para reproducir tema: %s" % nombre)

## Reproducir música de batalla del mapa actual. `musica_preferida` permite que
## el llamador (p.ej. un NPC entrenador con música propia) tenga prioridad
## sobre la del mapa — misma resolución para ambos casos que usa
## BattleLaunchService.resolver_tema_musica_batalla(), con "BATALLA_SALVAJE_1"
## como último recurso.
func reproducir_tema_batalla_mapa(musica_preferida: String = "") -> void:
	var admin_mapas = get_tree().root.get_node_or_null("AdministradorMapa")
	var musica_mapa := ""
	if admin_mapas:
		var mapa_actual: MapaConfiguracion = admin_mapas.mapa_actual
		if mapa_actual:
			musica_mapa = mapa_actual.obtener_musica_batalla_efectiva()
		if musica_mapa == "" or not Singleton.TEMAS_REGISTRADOS.has(musica_mapa):
			_loggear("❌ El mapa actual no tiene configurada música de batalla.")
	else:
		_loggear("❌ No se encontró el AdministradorMapa para obtener música de batalla.")
	reproducir_tema(BattleLaunchService.resolver_tema_musica_batalla(musica_preferida, musica_mapa))

## Función de logging para debugging
func _loggear(mensaje: String) -> void:
	print("💾 [SINGLETON] → " + mensaje)


## ===== PAUSA DEL JUEGO =====
## Estado de pausa de juego (menú abierto, batalla, diálogo, transición...).
## NO usa el pausado del motor (get_tree().paused): se modela como un conjunto
## de MOTIVOS para que varias causas puedan solaparse sin pisarse (cerrar el
## menú no debe reanudar una batalla en curso) y para poder consultar quién
## mantiene la pausa.
## La consulta para actores del overworld es AdministradorMapa.puede_actuar_*().

## Motivo -> número de solicitudes de pausa activas de ese motivo.
var _pausas: Dictionary = {}


## Pausa el juego por `motivo` (StringName: &"menu", &"batalla", &"dialogo"...).
## Es reentrante: dos llamadas a pausar() necesitan dos a reanudar().
func pausar(motivo: StringName) -> void:
	_pausas[motivo] = int(_pausas.get(motivo, 0)) + 1


## Quita una solicitud de pausa de `motivo`.
func reanudar(motivo: StringName) -> void:
	var solicitudes := int(_pausas.get(motivo, 0)) - 1
	if solicitudes > 0:
		_pausas[motivo] = solicitudes
		return
	if solicitudes < 0:
		# Reanudar un motivo que nunca pausó no debe reanudar causas ajenas.
		push_warning("[PAUSA] reanudar('%s') sin pausa previa de ese motivo" % motivo)
		return
	_pausas.erase(motivo)


## ¿Está el juego pausado ahora mismo?
func esta_pausado() -> bool:
	return not _pausas.is_empty()


## Activa o desactiva un motivo SIN contar: expresa un ESTADO ("el diálogo está
## abierto"), no una solicitud. Es idempotente, así que repetir la llamada o
## llamadas desbalanceadas no dejan el juego pausado para siempre.
## No mezclar sobre la misma clave con pausar()/reanudar() (que sí cuentan).
func mantener_pausa(motivo: StringName, activa: bool) -> void:
	if activa:
		_pausas[motivo] = 1
	else:
		_pausas.erase(motivo)


## Motivos que mantienen la pausa ahora mismo (para depurar o mostrar en logs).
func motivos_pausa() -> Array:
	return _pausas.keys()


## Borra todos los motivos. Solo para tests, depuración o cambios de escena.
func limpiar_pausas() -> void:
	_pausas.clear()
