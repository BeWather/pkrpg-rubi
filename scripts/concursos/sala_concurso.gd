class_name SalaConcurso
extends RefCounted
## Reglas de la sala del concurso (data/scripts/contest_hall.inc:183-1150 y
## data/maps/LinkContestRoom1/scripts.inc; anexo de IA/flujo/resultados §3.3-3.4): nivel
## de la votación del público, premio que corresponde y su entrega, y lo que se guarda
## al terminar (póster, cuadro temporal, estadísticas).

const RUTA_CONFIG: String = "res://BaseDatos/config_concursos.json"
## Premio de EXPERTO cuando el Pokémon ya tenía la cinta (giveitem ITEM_LUXURY_BALL).
const OBJETO_PREMIO_EXPERTO: String = "LUJOBALL"
const NIVEL_EXPERTO: int = 3
## ShouldReadyContestArtist: 1.º en EXPERTO con al menos 800 puntos.
const PUNTOS_ARTISTA: int = 800
## GAME_STAT_ENTERED_CONTEST / WON_CONTEST / RECEIVED_RIBBONS.
const CONTADOR_PARTICIPADOS: String = "concursos_participados"
const CONTADOR_GANADOS: String = "concursos_ganados"
const CONTADOR_CINTAS: String = "cintas_recibidas"
## FLAG_SYS_RIBBON_GET, FLAG_CONTEST_SKETCH_CREATED y VAR_LILYCOVE_CONTEST_LOBBY_STATE = 1.
const BANDERA_CINTA_OBTENIDA: String = "cinta_obtenida"
const BANDERA_BOCETO: String = "pardal_concurso_boceto_creado"
const BANDERA_ARTISTA: String = "calagua_concurso_artista_pendiente"
## Nivel ALTO = sala de PUEBLO PARDAL (VAR_CONTEST_LOCATION 2): allí se crea el boceto.
const NIVEL_BOCETO: int = 1

## Qué entrega la PRESENTADORA (1A5BAB).
enum Premio {
	## Perdió: «¡Aquí está!…» y «¡Felicidades! Esperamos que vuelvas…».
	NINGUNO,
	## Ganó con la cinta de este nivel ya puesta (y no es EXPERTO): solo felicita.
	REPETIDO,
	## Ganó sin la cinta: ScrSpecial_GiveContestRibbon.
	CINTA,
	## Ganó en EXPERTO con la cinta ya puesta: LUJO BALL (o pendiente si no cabe).
	LUJO_BALL,
}

## Mapa de la sala (escenas/mapas/sala-concurso/sala_concurso.tscn) y celda de llegada
## (warp MAP_LINK_CONTEST_ROOM1, 7, 5; el jugador queda oculto).
const MAPA_SALA: String = "sala_concurso"
const CELDA_LLEGADA: Vector2i = Vector2i(7, 5)

static var _umbrales: Array = []
## Concurso pendiente entre la recepción y la sala (VAR_LINK_CONTEST_ROOM_STATE = 1 + las
## variables especiales del concurso): pokemon, categoria, nivel, ya_tenia_cinta, concursantes,
## aleatorio, vestibulo (escena a la que se vuelve) y celda_regreso. Vacío si no hay ninguno.
static var inscripcion: Dictionary = {}


## ScrSpecial_CheckSelectedMonAndInitContest + lo que la sala necesita para el regreso
## (15FB64: (5,4) en VERDEGAL, PARDAL y PORTUAL, (6,4) en CALAGUA).
static func inscribir(pokemon: BasePokemon, categoria: int, nivel: int, ya_tenia_cinta: bool, vestibulo: String,
		aleatorio: AleatorioConcurso, entrenador: String) -> Dictionary:
	var concursantes := InscripcionConcurso.crear_concursantes(pokemon, categoria, nivel,
		DatosConcurso.compartido(), aleatorio, entrenador)
	inscripcion = {
		"pokemon": pokemon,
		"categoria": categoria,
		"nivel": nivel,
		"ya_tenia_cinta": ya_tenia_cinta,
		"concursantes": concursantes,
		"aleatorio": aleatorio,
		"vestibulo": vestibulo,
		"celda_regreso": Vector2i(6, 4) if nivel == NIVEL_EXPERTO else Vector2i(5, 4),
	}
	return inscripcion


## Umbrales de la votación del público de cada nivel (config_concursos.json).
static func umbrales(nivel: int) -> Array[int]:
	if _umbrales.is_empty() and FileAccess.file_exists(RUTA_CONFIG):
		var config: Variant = JSON.parse_string(FileAccess.get_file_as_string(RUTA_CONFIG))
		if config is Dictionary and config.get("umbrales_votacion") is Array:
			_umbrales = config["umbrales_votacion"]
	var lista: Array[int] = []
	if nivel >= 0 and nivel < _umbrales.size():
		for valor in _umbrales[nivel]:
			lista.append(int(valor))
	return lista


## 1A5455: cuántos miembros del público aplauden (0-8) a un concursante según su
## puntuación de la ronda 1 (cada umbral se supera con `>`).
static func nivel_votacion(puntos_ronda1: int, nivel: int) -> int:
	var cantidad: int = 0
	for umbral in umbrales(nivel):
		if puntos_ronda1 > umbral:
			cantidad += 1
	return cantidad


## 1A5C12 / 1A5CE5.
static func premio(gano: bool, ya_tenia_cinta: bool, nivel: int) -> Premio:
	if not gano:
		return Premio.NINGUNO
	if ya_tenia_cinta:
		return Premio.LUJO_BALL if nivel == NIVEL_EXPERTO else Premio.REPETIDO
	return Premio.CINTA


static func prepara_artista(gano: bool, nivel: int, puntos_finales: int) -> bool:
	return gano and nivel == NIVEL_EXPERTO and puntos_finales >= PUNTOS_ARTISTA


## Lo que se guarda siempre al acabar (Contest_SaveWinner(rango) y (0xFE), estadística
## de participación del regreso) y, si ganó el jugador, sus estadísticas y banderas.
## Devuelve el premio que la sala debe anunciar.
static func cerrar_concurso(motor: MotorConcurso, ya_tenia_cinta: bool, registro: RegistroConcursos) -> Premio:
	var estado: EstadoConcurso = motor.estado
	var ganador: int = estado.ganador()
	var gano: bool = ganador == estado.indice_jugador
	var datos_ganador: Dictionary = RegistroConcursos.ganador_desde(motor.concursante(ganador), estado.categoria)
	if registro != null:
		registro.registrar_ganador(estado.nivel, datos_ganador)
		registro.cuadro_pendiente = datos_ganador.duplicate()
	var tipo: Premio = premio(gano, ya_tenia_cinta, estado.nivel)
	if SistemaGuardado == null:
		return tipo
	SistemaGuardado.incrementar_contador(CONTADOR_PARTICIPADOS)
	if gano:
		SistemaGuardado.incrementar_contador(CONTADOR_GANADOS)
		if estado.nivel == NIVEL_BOCETO and tipo != Premio.REPETIDO:
			SistemaGuardado.set_flag(BANDERA_BOCETO, true)
	if prepara_artista(gano, estado.nivel, estado.puntos_finales[ganador]):
		SistemaGuardado.set_flag(BANDERA_ARTISTA, true)
	return tipo


## ScrSpecial_GiveContestRibbon: la cinta del nivel siguiente, con su estadística y la
## bandera de «ha recibido una cinta». Devuelve la clave añadida ("" si no había).
static func entregar_cinta(pokemon: BasePokemon, categoria: int) -> String:
	var clave: String = pokemon.subir_cinta_concurso(categoria)
	if not clave.is_empty() and SistemaGuardado != null:
		SistemaGuardado.incrementar_contador(CONTADOR_CINTAS)
		SistemaGuardado.set_flag(BANDERA_CINTA_OBTENIDA, true)
	return clave
