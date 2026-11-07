## camino_bici.gd
## Estado del CAMINO de BICIS de la COSTA (RUTA 110) de pokeruby: la bandera de sistema
## FLAG_SYS_CYCLING_ROAD y la variable VAR_CYCLING_CHALLENGE_STATE.
##
## - `BANDERA_ACTIVO` (FLAG_SYS_CYCLING_ROAD): la activan las casetas de entrada al cruzar con
##   bici delante del GUARDA y la apagan al cruzar en sentido contrario, al VOLAR, al
##   TELETRANSPORTARSE, al usar CUERDA HUIDA y al debilitarse todo el equipo. Mientras está activa
##   el jugador no puede bajarse de la bici (ItemUseOutOfBattle_Bike → DisplayCantGetOffBike…).
## - `CONTADOR_RETO` (VAR_CYCLING_CHALLENGE_STATE): 0 libre, 1 preparado (cruzó la caseta NORTE en
##   BICI CARRERA), 2 en curso (el cronómetro corre), 3 terminado (ya habló con el JUEZ).
##   La caseta NORTE hace 2/3 → 1 al cargarse y 0 al salir; RUTA 110 lo pasa de 1 a 2 y arranca el
##   cronómetro (ScrSpecial_BeginCyclingRoadChallenge) y UpdateCyclingRoadState lo reinicia fuera de
##   la ruta; el JUEZ lo deja en 3 tras puntuar.
## - Datos del reto en curso (gBikeCyclingChallenge, gBikeCollisions, gBikeCyclingTimer): como en
##   Rubí viven en RAM (aquí, variables estáticas) y no se guardan; se reinician en cada carga de
##   mapa (ResetCyclingRoadChallengeData). El récord sí se guarda con la partida (contadores
##   `RECORD_FOTOGRAMAS` y `RECORD_CHOQUES`, VAR_CYCLING_ROAD_RECORD_TIME_L/H y _COLLISIONS).
class_name CaminoBici
extends RefCounted

## FLAG_SYS_CYCLING_ROAD.
const BANDERA_ACTIVO: String = "camino_bici_activo"
## VAR_CYCLING_CHALLENGE_STATE.
const CONTADOR_RETO: String = "camino_bici_reto_estado"

const RETO_LIBRE: int = 0
const RETO_PREPARADO: int = 1
const RETO_EN_CURSO: int = 2
const RETO_TERMINADO: int = 3

## GetPlayerAvatarBike.
const SIN_BICI: int = 0
const BICI_ACROBATICA: int = 1
const BICI_CARRERA: int = 2


## FlagGet(FLAG_SYS_CYCLING_ROAD).
static func activo() -> bool:
	return SistemaGuardado.get_flag(BANDERA_ACTIVO)


## FlagSet / FlagClear(FLAG_SYS_CYCLING_ROAD). Apagada borra la entrada, como las demás
## banderas de sistema que se reinician (Destello).
static func fijar_activo(valor: bool) -> void:
	if valor:
		SistemaGuardado.set_flag(BANDERA_ACTIVO, true)
	else:
		SistemaGuardado.delete_flag(BANDERA_ACTIVO)


## Overworld_ResetStateAfterFly / Teleport / DigEscRope / WhiteOut.
static func apagar() -> void:
	fijar_activo(false)


static func estado_reto() -> int:
	return SistemaGuardado.get_contador(CONTADOR_RETO)


static func fijar_estado_reto(valor: int) -> void:
	SistemaGuardado.set_contador(CONTADOR_RETO, valor)


## GetPlayerAvatarBike: 0 a pie, 1 BICI ACROBÁTICA, 2 BICI CARRERA. `jugador` es el nodo del
## jugador (con `en_bicicleta` y `tipo_bici`).
static func tipo_bici_jugador(jugador: Node) -> int:
	if jugador == null or not bool(jugador.get("en_bicicleta")):
		return SIN_BICI
	if str(jugador.get("tipo_bici")) == "ACROBATICA":
		return BICI_ACROBATICA
	return BICI_CARRERA


## VAR_CYCLING_ROAD_RECORD_TIME_L/H (32 bits en un solo contador) y _COLLISIONS.
const RECORD_FOTOGRAMAS: String = "camino_bici_record_fotogramas"
const RECORD_CHOQUES: String = "camino_bici_record_choques"

## Fotogramas por segundo de la GBA (vblankCounter1).
const FOTOGRAMAS_POR_SEGUNDO: int = 60
## Tope de choques contados (gBikeCollisions < 100).
const MAX_CHOQUES: int = 100

const TEXTO_SEGUNDOS: String = "RUTA110_UNIDAD_SEGUNDOS"
const TEXTO_MAS_DE_99: String = "RUTA110_MAS_DE_99"
const TEXTO_MAS_DE_1_MIN: String = "RUTA110_MAS_DE_1_MIN"

## gBikeCyclingChallenge: el reto está en curso (el cronómetro corre y los choques se cuentan).
static var reto_en_curso: bool = false
## gBikeCollisions.
static var choques: int = 0
## gBikeCyclingTimer: fotograma en que empezó el reto.
static var fotograma_inicio: int = 0
## Sustituye al contador de fotogramas (tests). Vacío: el reloj real a 60 por segundo, como
## gMain.vblankCounter1, que sigue avanzando con menús y combates.
static var fuente_fotogramas: Callable = Callable()


## gMain.vblankCounter1.
static func fotograma_actual() -> int:
	if fuente_fotogramas.is_valid():
		return int(fuente_fotogramas.call())
	return Time.get_ticks_msec() * FOTOGRAMAS_POR_SEGUNDO / 1000


## ResetCyclingRoadChallengeData: en cada carga de mapa (warp, cruce de borde, cargar partida).
static func reiniciar_datos_reto() -> void:
	reto_en_curso = false
	choques = 0
	fotograma_inicio = 0


## ScrSpecial_BeginCyclingRoadChallenge.
static func comenzar_reto() -> void:
	reto_en_curso = true
	choques = 0
	fotograma_inicio = fotograma_actual()


## Bike_TryAdvanceCyclingRoadCollisions: una colisión del jugador en bici (objeto, pared o
## terreno que no deja correr).
static func registrar_choque() -> void:
	if reto_en_curso and choques < MAX_CHOQUES:
		choques += 1


## FinishCyclingRoadChallenge: devuelve {fotogramas, choques, resultado, record_nuevo} y guarda el
## récord si mejora el anterior (o no había ninguno).
static func terminar_reto() -> Dictionary:
	var fotogramas: int = fotograma_actual() - fotograma_inicio
	var puntuacion: int = calcular_resultado(fotogramas, choques)
	var record_nuevo: bool = _registrar_record(fotogramas, choques)
	return {"fotogramas": fotogramas, "choques": choques, "resultado": puntuacion, "record_nuevo": record_nuevo}


## RecordCyclingRoadResults.
static func _registrar_record(fotogramas: int, colisiones: int) -> bool:
	var actual: int = SistemaGuardado.get_contador(RECORD_FOTOGRAMAS)
	if actual > fotogramas or actual == 0:
		SistemaGuardado.set_contador(RECORD_FOTOGRAMAS, fotogramas)
		SistemaGuardado.set_contador(RECORD_CHOQUES, colisiones)
		return true
	return false


## GetRecordedCyclingRoadResults: {fotogramas, choques} del mejor récord, o {} si no hay.
static func record() -> Dictionary:
	var fotogramas: int = SistemaGuardado.get_contador(RECORD_FOTOGRAMAS)
	if fotogramas == 0:
		return {}
	return {"fotogramas": fotogramas, "choques": SistemaGuardado.get_contador(RECORD_CHOQUES)}


## gStringVar1 de DetermineCyclingRoadResults: el número de choques sin ceros a la izquierda
## (más de 99 → «más de 99»). En inglés lleva « times» detrás; en el español de la ROM el
## sufijo está vacío.
static func texto_choques(colisiones: int) -> String:
	if colisiones > 99:
		return TranslationServer.translate(TEXTO_MAS_DE_99)
	var texto: String = str(colisiones)
	if TranslationServer.get_locale().begins_with("en"):
		texto += " times"
	return texto


## gStringVar2: segundos alineados a la derecha en 2 cifras, separador decimal (coma en español,
## punto en inglés) y centésimas con 2 cifras («  7,50 segundos»); a partir de 3600 fotogramas
## «más de 1 min».
static func texto_tiempo(fotogramas: int) -> String:
	if fotogramas >= FOTOGRAMAS_POR_SEGUNDO * 60:
		return TranslationServer.translate(TEXTO_MAS_DE_1_MIN)
	var separador: String = "." if TranslationServer.get_locale().begins_with("en") else ","
	var segundos: String = str(fotogramas / FOTOGRAMAS_POR_SEGUNDO).lpad(2, " ")
	var centesimas: String = str((fotogramas % FOTOGRAMAS_POR_SEGUNDO) * 100 / FOTOGRAMAS_POR_SEGUNDO).pad_zeros(2)
	return "%s%s%s %s" % [segundos, separador, centesimas, TranslationServer.translate(TEXTO_SEGUNDOS)]


## DetermineCyclingRoadResults: puntuación 0-10 según los choques (0 → 5, <4 → 4, <10 → 3,
## <20 → 2, <100 → 1) más el tiempo en segundos (≤10 → 5, ≤15 → 4, ≤20 → 3, ≤40 → 2, <60 → 1).
## `fotogramas` a 60 por segundo.
static func calcular_resultado(fotogramas: int, colisiones: int) -> int:
	var resultado: int = 0
	if colisiones == 0:
		resultado = 5
	elif colisiones < 4:
		resultado = 4
	elif colisiones < 10:
		resultado = 3
	elif colisiones < 20:
		resultado = 2
	elif colisiones < 100:
		resultado = 1
	var segundos: int = fotogramas / 60
	if segundos <= 10:
		resultado += 5
	elif segundos <= 15:
		resultado += 4
	elif segundos <= 20:
		resultado += 3
	elif segundos <= 40:
		resultado += 2
	elif segundos < 60:
		resultado += 1
	return resultado
