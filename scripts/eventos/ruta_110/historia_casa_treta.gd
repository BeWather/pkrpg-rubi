## historia_casa_treta.gd
## Estado de la CASA TRETA de la RUTA 110 (pokeruby data/maps/Route110_TrickHouse*,
## src/field_specials.c y data/specials.inc). Como HistoriaFerrica, no es un nodo: lo
## consultan y avanzan los eventos de las escenas (entrada/final/pasillo y las ocho
## pruebas) y el cartel de depuración.
##
## `ruta_110_casa_treta.tscn` une tres mapas del decomp en una sola escena, separados por
## huecos vacíos de 7 columnas (Godot = Rubí + desplazamiento):
##   ENTRADA  (Route110_TrickHouseEntrance) desplazamiento (0, 0)   celdas x 0..11,  y 0..7
##   FINAL    (Route110_TrickHouseEnd)      desplazamiento (19, 0)  celdas x 19..30, y 0..7
##   PASILLO  (Route110_TrickHouseCorridor) desplazamiento (38, 0)  celdas x 38..52, y 0..23
## La subsala se deduce por celda (`subsala_por_celda`), no por mapa.
##
## Variables del decomp (include/constants/vars.h) y su equivalente:
##   VAR_TRICK_HOUSE_ROOMS_COMPLETED       -> `casa_treta_salas_completadas`  (0..8)
##   VAR_TRICK_HOUSE_ENTRANCE_STATE        -> `casa_treta_entrada_observado`  (0 los disparadores
##                                            «te estoy observando» están armados, 1 no)
##   VAR_TRICK_HOUSE_ENTRANCE_STATE_2      -> `casa_treta_reto_pendiente`     (1 = acaba de ser
##                                            encontrado: presentación y desaparición)
##   VAR_TRICK_HOUSE_ENTRANCE_STATE_3      -> `casa_treta_maestro_estado`     (EstadoMaestro)
##   VAR_TRICK_HOUSE_STATE                 -> `casa_treta_vuelta_pasillo`     (1 = viene del pasillo)
##   VAR_TRICK_HOUSE_PRIZE_PICKUP          -> `casa_treta_premio_pendiente`   (bandera)
##   VAR_TRICK_HOUSE_PUZZLE_1..8_STATE     -> `casa_treta_prueba_N_estado`    (0 pergamino sin
##                                            leer, 1 leído, 2 puerta abierta)
##   VAR_TRICK_HOUSE_PUZZLE_7_STATE_2      -> `casa_treta_p7_teletransporte`
##   FLAG_TRICK_HOUSE_PUZZLE_7_SWITCH_1..5 -> `casa_treta_p7_interruptor_N`
##
## Correcciones deliberadas respecto a Rubí (decisiones del usuario, ver
## documentacion/20261014-casa-treta-fase1.md):
##  - no existe el warp de la celda (5,2) al acertijo 1: solo se entra por la cortina, y
##    con el nivel real (`salas_completadas() + 1`);
##  - al volver del pasillo al FINAL el MAESTRO no reaparece (solo está al llegar por la
##    puerta de una prueba y hasta que habla), así que no regala un segundo premio;
##  - la puerta de cada prueba se reabre al volver si su estado es 2 (Rubí solo lo hacía
##    en la 1).
class_name HistoriaCasaTreta
extends RefCounted

## Un valor de más de `NIVEL_MAXIMO` salas no existe: tras la 8.ª el MAESTRO se va para siempre.
const NIVEL_MAXIMO: int = 8
const PRUEBAS: int = 8

const CONTADOR_SALAS: String = "casa_treta_salas_completadas"
const CONTADOR_ENTRADA_OBSERVADO: String = "casa_treta_entrada_observado"
const CONTADOR_RETO_PENDIENTE: String = "casa_treta_reto_pendiente"
const CONTADOR_MAESTRO: String = "casa_treta_maestro_estado"
const CONTADOR_VUELTA_PASILLO: String = "casa_treta_vuelta_pasillo"
const BANDERA_PREMIO_PENDIENTE: String = "casa_treta_premio_pendiente"
## Solo depuración: `requisito_cumplido()` devuelve siempre true.
const BANDERA_IGNORAR_REQUISITOS: String = "casa_treta_ignorar_requisitos"
const CONTADOR_P7_TELETRANSPORTE: String = "casa_treta_p7_teletransporte"
## `casa_treta_prueba_N_estado` y `casa_treta_p7_interruptor_N`.
const PLANTILLA_PRUEBA: String = "casa_treta_prueba_%d_estado"
const PLANTILLA_INTERRUPTOR_P7: String = "casa_treta_p7_interruptor_%d"
const INTERRUPTORES_P7: int = 5

## FLAG_SYS_GAME_CLEAR (la usan GIMNASIO de PETALIA, ferry, rival de CALAGUA…).
const BANDERA_JUEGO_COMPLETADO: String = "SYS_GAME_CLEAR"

## Objetos de suelo (`ItemOverworld.id_item`; la bandera real es `item_<id>`). Cada carta
## es de un acertijo (FLAG_ITEM_TRICK_HOUSE_PUZZLE_*). La PEPITA oculta del FINAL es
## FLAG_HIDDEN_ITEM_1 (0x259).
const ID_ITEM_PEPITA: String = "casa_treta_pepita_01"
const IDS_CARTAS: PackedStringArray = [
	"casa_treta_p1_carta_naranja_01",   # ORANGE_MAIL -> CARNARANJA
	"casa_treta_p2_carta_puerto_01",    # HARBOR_MAIL -> CARTAPUERTO
	"casa_treta_p2_carta_ola_01",       # WAVE_MAIL -> CARTAOLA
	"casa_treta_p3_carta_sombra_01",    # SHADOW_MAIL -> CARTASOMBRA
	"casa_treta_p3_carta_madera_01",    # WOOD_MAIL -> CARTAMADERA
	"casa_treta_p4_carta_iman_01",      # MECH_MAIL -> CARTAIMAN
	"casa_treta_p6_carta_brillo_01",    # GLITTER_MAIL -> CARTABRILLO
	"casa_treta_p7_carta_tropic_01",    # TROPIC_MAIL -> CARTROPIC
	"casa_treta_p8_carta_imagen_01",    # BEAD_MAIL -> CARTAIMAGEN
]

## ENTRANCE_STATE_3.
enum EstadoMaestro {
	ESCONDIDO = 0,         ## escondido en el mueble del nivel (destello con 0-2 salas)
	EN_ACERTIJO = 1,       ## se fue tras ser encontrado: la cortina pregunta si entrar
	PREMIO_PENDIENTE = 2,  ## junto a la cortina con la recompensa que no pudo dar
	PENSANDO = 3,          ## junto a la cortina «ideando nuevos desafíos» (o falta medalla)
	FINALIZADO = 4,        ## las 8 salas hechas: se fue de viaje, la cortina trae su nota
	REGRESO = 5,           ## transitorio: se viene del pasillo; se recalcula al cargar
	TIENDA_PENDIENTE = 6,  ## MECAÑECO 5 con la TIENDA ROJA pendiente (8 salas)
}

## Subsalas de la escena grande.
enum Subsala {
	NINGUNA = -1,
	ENTRADA = 0,
	FINAL = 1,
	PASILLO = 2,
}

const RECT_ENTRADA: Rect2i = Rect2i(0, 0, 12, 8)
const RECT_FINAL: Rect2i = Rect2i(19, 0, 12, 8)
const RECT_PASILLO: Rect2i = Rect2i(38, 0, 15, 24)

## Escondite del MAESTRO por nivel (OnWarp, SetHidingSpotPuzzleN).
const ESCONDITES: Array[Vector2i] = [
	Vector2i(6, 3), Vector2i(11, 5), Vector2i(9, 1), Vector2i(3, 1),
	Vector2i(0, 5), Vector2i(11, 1), Vector2i(8, 1), Vector2i(4, 4),
]
## Celda del destello (DoHidingSpotSparkle1..3). Con 3 salas o más no hay destello.
## En el nivel 2 es la celda de debajo de la cajonera, no la del MAESTRO: es el dato de Rubí.
const DESTELLOS: Array[Vector2i] = [Vector2i(6, 3), Vector2i(11, 5), Vector2i(9, 2)]
const SIN_CELDA: Vector2i = Vector2i(-1, -1)
## Celda donde el MAESTRO espera junto a la cortina (5,2) y la propia cortina (5,1).
const CELDA_MAESTRO_PUERTA: Vector2i = Vector2i(5, 2)
const CELDA_CORTINA: Vector2i = Vector2i(5, 1)
## El jugador, tras encontrarlo (warp a (6,2), mirando a la izquierda).
const CELDA_JUGADOR_HALLAZGO: Vector2i = Vector2i(6, 2)
## Offset del FINAL (celda de Rubí + OFFSET_FINAL = celda de Godot).
const OFFSET_FINAL: Vector2i = Vector2i(19, 0)
const CELDA_MAESTRO_FINAL: Vector2i = Vector2i(23, 5)
## Puerta por la que se llega al FINAL (se cierra) y warp hacia el pasillo.
const CELDA_PUERTA_FINAL: Vector2i = Vector2i(29, 1)
const CELDA_ESCALERA_PASILLO: Vector2i = Vector2i(21, 1)
const CELDA_TRIGGER_IGNORAR: Vector2i = Vector2i(21, 2)
## Llegada al PASILLO desde el FINAL ((13,3) y (14,3) de Rubí + (38,0)).
const CELDA_LLEGADA_PASILLO: Vector2i = Vector2i(51, 3)

## Objeto de cada nivel (0..6). El 7 (8.ª prueba) da la TIENDA ROJA (decoración).
const PREMIOS: PackedStringArray = [
	"CARAMELORARO", "TURNOBALL", "PIEDRADURA", "BOLADEHUMO", "MT12", "IMAN", "MAXPP",
]
## DECOR_RED_TENT (31) en catalogo.json; en Zafiro DECOR_BLUE_TENT (32).
const DECORACION_TIENDA_ROJA: int = 31

## Clave de SistemaGuardado -> [tipo, equivalente Gen 3].
const PERSISTENTE := {
	CONTADOR_SALAS: ["contador", "VAR_TRICK_HOUSE_ROOMS_COMPLETED"],
	CONTADOR_ENTRADA_OBSERVADO: ["contador", "VAR_TRICK_HOUSE_ENTRANCE_STATE"],
	CONTADOR_RETO_PENDIENTE: ["contador", "VAR_TRICK_HOUSE_ENTRANCE_STATE_2"],
	CONTADOR_MAESTRO: ["contador", "VAR_TRICK_HOUSE_ENTRANCE_STATE_3"],
	CONTADOR_VUELTA_PASILLO: ["contador", "VAR_TRICK_HOUSE_STATE"],
	BANDERA_PREMIO_PENDIENTE: ["bandera", "VAR_TRICK_HOUSE_PRIZE_PICKUP"],
	BANDERA_IGNORAR_REQUISITOS: ["bandera", "(depuración)"],
	CONTADOR_P7_TELETRANSPORTE: ["contador", "VAR_TRICK_HOUSE_PUZZLE_7_STATE_2"],
}


## ============================================================================
## LECTURA
## ============================================================================

## VAR_TRICK_HOUSE_ROOMS_COMPLETED: acertijos superados = índice (0-based) del siguiente.
static func salas_completadas() -> int:
	return clampi(SistemaGuardado.get_contador(CONTADOR_SALAS), 0, NIVEL_MAXIMO)


static func estado_maestro() -> int:
	return clampi(SistemaGuardado.get_contador(CONTADOR_MAESTRO), EstadoMaestro.ESCONDIDO, EstadoMaestro.TIENDA_PENDIENTE)


## VAR_TRICK_HOUSE_ENTRANCE_STATE: 0 = los cuatro disparadores del suelo están armados.
static func entrada_observada() -> int:
	return SistemaGuardado.get_contador(CONTADOR_ENTRADA_OBSERVADO)


## VAR_TRICK_HOUSE_ENTRANCE_STATE_2 == 1.
static func reto_pendiente() -> bool:
	return SistemaGuardado.get_contador(CONTADOR_RETO_PENDIENTE) == 1


## VAR_TRICK_HOUSE_STATE == 1.
static func vuelta_pasillo() -> bool:
	return SistemaGuardado.get_contador(CONTADOR_VUELTA_PASILLO) == 1


static func premio_pendiente() -> bool:
	return SistemaGuardado.get_flag(BANDERA_PREMIO_PENDIENTE)


static func ignora_requisitos() -> bool:
	return SistemaGuardado.get_flag(BANDERA_IGNORAR_REQUISITOS)


## ¿Ya están las 8 salas? (el MAESTRO se fue de viaje).
static func terminada() -> bool:
	return salas_completadas() >= NIVEL_MAXIMO


## Número (1..8) del acertijo que toca ahora.
static func prueba_siguiente() -> int:
	return mini(salas_completadas() + 1, PRUEBAS)


## ============================================================================
## SUBSALA
## ============================================================================

## ENTRADA, FINAL o PASILLO según la celda de la escena grande.
static func subsala_por_celda(celda: Vector2i) -> int:
	if RECT_ENTRADA.has_point(celda):
		return Subsala.ENTRADA
	if RECT_FINAL.has_point(celda):
		return Subsala.FINAL
	if RECT_PASILLO.has_point(celda):
		return Subsala.PASILLO
	return Subsala.NINGUNA


## ============================================================================
## TABLAS POR NIVEL (0..7)
## ============================================================================

## Escondite del MAESTRO con `nivel` salas hechas.
static func escondite(nivel: int) -> Vector2i:
	if nivel < 0 or nivel >= ESCONDITES.size():
		return SIN_CELDA
	return ESCONDITES[nivel]


## Celda del destello de la pista, o `SIN_CELDA` (niveles 3..7: solo sale el texto).
static func celda_destello(nivel: int) -> Vector2i:
	if nivel < 0 or nivel >= DESTELLOS.size():
		return SIN_CELDA
	return DESTELLOS[nivel]


## «¿Eh? Grrr... ¿Cómo has sabido que estaba escondido...?» del nivel.
static func clave_hallazgo(nivel: int) -> String:
	return "CASA_TRETA_ENTRADA_HALLADO_%d" % (clampi(nivel, 0, PRUEBAS - 1) + 1)


## «Me ha llevado toda la noche…» del nivel (FINAL, justo antes del premio).
static func clave_texto_final(nivel: int) -> String:
	return "CASA_TRETA_FIN_NIVEL_%d" % (clampi(nivel, 0, PRUEBAS - 1) + 1)


## Objeto del nivel 0..6; cadena vacía en el 7 (decoración).
static func objeto_premio(nivel: int) -> String:
	if nivel < 0 or nivel >= PREMIOS.size():
		return ""
	return PREMIOS[nivel]


## CheckReadyForPuzzleN: ¿puede empezar el acertijo `salas + 1`? Con 1..6 salas pide la
## MEDALLA 3..8 (índices 2..7) y con 7 haber vencido a la LIGA (FLAG_SYS_GAME_CLEAR).
static func requisito_cumplido(salas: int = -1) -> bool:
	if ignora_requisitos():
		return true
	if salas < 0:
		salas = salas_completadas()
	if salas <= 0 or salas >= NIVEL_MAXIMO:
		return true
	if salas < NIVEL_MAXIMO - 1:
		return SistemaGuardado.tiene_medalla(salas + 1)
	return SistemaGuardado.get_flag(BANDERA_JUEGO_COMPLETADO)


## ============================================================================
## ESTADO DE LA ENTRADA (map_scripts de Route110_TrickHouseEntrance)
## ============================================================================

## Route110_TrickHouseEntrance_OnTransition (todo salvo el landmark, que lo pone
## BanderasLandmark al cargar el mapa). El orden importa.
static func al_transicion_entrada() -> void:
	if vuelta_pasillo():  # EnterFromCorridor
		SistemaGuardado.set_contador(CONTADOR_VUELTA_PASILLO, 0)
		SistemaGuardado.set_contador(CONTADOR_MAESTRO, EstadoMaestro.REGRESO)
		SistemaGuardado.set_contador(CONTADOR_ENTRADA_OBSERVADO, 1)
		return
	if premio_pendiente():  # SetReadyToGiveReward
		SistemaGuardado.set_contador(CONTADOR_ENTRADA_OBSERVADO, 1)
		SistemaGuardado.set_contador(CONTADOR_MAESTRO,
				EstadoMaestro.TIENDA_PENDIENTE if terminada() else EstadoMaestro.PREMIO_PENDIENTE)
		return
	if reto_pendiente():  # MoveTrickMasterToDoor: el estado no se toca
		return
	var estado := estado_maestro()
	if estado == EstadoMaestro.REGRESO or estado == EstadoMaestro.PENSANDO or estado == EstadoMaestro.ESCONDIDO:
		estado = _recalcular_estado_maestro()
		SistemaGuardado.set_contador(CONTADOR_MAESTRO, estado)
	match estado:  # ReadyBeingWatchedTrigger / SetNotBeingWatched1..3
		EstadoMaestro.ESCONDIDO:
			SistemaGuardado.set_contador(CONTADOR_ENTRADA_OBSERVADO, 0)
		EstadoMaestro.EN_ACERTIJO, EstadoMaestro.PENSANDO, EstadoMaestro.FINALIZADO:
			SistemaGuardado.set_contador(CONTADOR_ENTRADA_OBSERVADO, 1)


## CheckReadyForNextPuzzle: ESCONDIDO salvo que falte la medalla/LIGA (PENSANDO) o estén
## las 8 salas (FINALIZADO).
static func _recalcular_estado_maestro() -> int:
	if terminada():
		return EstadoMaestro.FINALIZADO
	if not requisito_cumplido():
		return EstadoMaestro.PENSANDO
	return EstadoMaestro.ESCONDIDO


## Route110_TrickHouseCorridor_OnTransition: setvar VAR_TRICK_HOUSE_STATE, 1.
static func al_transicion_pasillo() -> void:
	SistemaGuardado.set_contador(CONTADOR_VUELTA_PASILLO, 1)


## «Te estoy observando...»: ENTRANCE_STATE = 1.
static func marcar_observado() -> void:
	SistemaGuardado.set_contador(CONTADOR_ENTRADA_OBSERVADO, 1)


## ¿Sale el destello tras «Te estoy observando...»? Solo con 0, 1 o 2 salas.
static func hay_destello(nivel: int) -> bool:
	return celda_destello(nivel) != SIN_CELDA


## `TrickMasterFound`: ENTRANCE_STATE_2 = 1 (justo antes del warp a (6,2)).
static func marcar_hallado() -> void:
	SistemaGuardado.set_contador(CONTADOR_RETO_PENDIENTE, 1)


## Fin de `BeginChallenge`: el MAESTRO se fue por la pared.
static func terminar_presentacion() -> void:
	SistemaGuardado.set_contador(CONTADOR_MAESTRO, EstadoMaestro.EN_ACERTIJO)
	SistemaGuardado.set_contador(CONTADOR_RETO_PENDIENTE, 0)


## `GotReward`: la recompensa pendiente ya se entregó.
static func recompensa_entregada() -> void:
	SistemaGuardado.set_flag(BANDERA_PREMIO_PENDIENTE, false)
	SistemaGuardado.set_contador(CONTADOR_MAESTRO, EstadoMaestro.PENSANDO)


## `ReceivedTent`: la TIENDA ROJA pendiente ya se entregó; el MECAÑECO se esfuma.
static func tienda_entregada() -> void:
	SistemaGuardado.set_flag(BANDERA_PREMIO_PENDIENTE, false)
	SistemaGuardado.set_contador(CONTADOR_MAESTRO, EstadoMaestro.REGRESO)


## Acción de la cortina (`Route110_TrickHouseEntrance_EventScript_Door`).
enum AccionCortina { NINGUNA, ES_UNA_CORTINA, PREGUNTAR_ENTRAR, NOTA_VIAJE }


static func accion_cortina() -> int:
	match estado_maestro():
		EstadoMaestro.ESCONDIDO:
			return AccionCortina.ES_UNA_CORTINA
		EstadoMaestro.EN_ACERTIJO:
			return AccionCortina.PREGUNTAR_ENTRAR
		EstadoMaestro.FINALIZADO:
			return AccionCortina.NOTA_VIAJE
		EstadoMaestro.REGRESO:
			return AccionCortina.NOTA_VIAJE if terminada() else AccionCortina.ES_UNA_CORTINA
	return AccionCortina.NINGUNA  # 2, 3 y 6: el MAESTRO tapa la cortina, no se alcanza


## ============================================================================
## FINAL (map_scripts de Route110_TrickHouseEnd)
## ============================================================================

## `TrickMasterExit`: ROOMS_COMPLETED += 1 al irse el MAESTRO.
static func completar_sala() -> int:
	var nuevo := mini(salas_completadas() + 1, NIVEL_MAXIMO)
	SistemaGuardado.set_contador(CONTADOR_SALAS, nuevo)
	return nuevo


## PRIZE_PICKUP: `true` cuando no cupo el premio (BagFull / NoRoomForTent).
static func fijar_premio_pendiente(valor: bool) -> void:
	SistemaGuardado.set_flag(BANDERA_PREMIO_PENDIENTE, valor)


## ============================================================================
## PRUEBAS
## ============================================================================

static func clave_prueba(numero: int) -> String:
	return PLANTILLA_PRUEBA % clampi(numero, 1, PRUEBAS)


## 0 pergamino sin leer, 1 leído (código memorizado), 2 puerta abierta.
static func estado_prueba(numero: int) -> int:
	return SistemaGuardado.get_contador(clave_prueba(numero))


## Route110_TrickHousePuzzleN_EventScript_Scroll: 0 -> 1. Devuelve true si es la
## primera lectura («encontró un pergamino» + «memorizó el código»).
static func leer_pergamino(numero: int) -> bool:
	if estado_prueba(numero) != 0:
		return false
	SistemaGuardado.set_contador(clave_prueba(numero), 1)
	return true


## `Route110_TrickHousePuzzleN_EventScript_Door` con el pergamino leído: estado 2.
## Falso (puerta cerrada, «escribe el código secreto aquí») si no se leyó.
static func abrir_puerta(numero: int) -> bool:
	if estado_prueba(numero) == 0:
		return false
	SistemaGuardado.set_contador(clave_prueba(numero), 2)
	return true


## ¿Debe cargarse la puerta de la prueba ya abierta? (estado 2: se reabre en las ocho).
static func puerta_abierta(numero: int) -> bool:
	return estado_prueba(numero) >= 2


## Interruptores de la prueba 7 (FLAG_TRICK_HOUSE_PUZZLE_7_SWITCH_1..5).
static func interruptor_p7(numero: int) -> bool:
	return SistemaGuardado.get_flag(PLANTILLA_INTERRUPTOR_P7 % clampi(numero, 1, INTERRUPTORES_P7))


static func fijar_interruptor_p7(numero: int, valor: bool) -> void:
	SistemaGuardado.set_flag(PLANTILLA_INTERRUPTOR_P7 % clampi(numero, 1, INTERRUPTORES_P7), valor)


## ============================================================================
## DEPURACIÓN Y TESTS (escrituras que dejan un estado coherente, §8.3 del análisis)
## ============================================================================

## Nivel 0..8: fija las salas y deja el resto en el estado que daría una visita nueva
## (MAESTRO escondido, o «pensando»/finalizado según medallas y nivel).
static func forzar_nivel(salas: int) -> void:
	SistemaGuardado.set_contador(CONTADOR_SALAS, clampi(salas, 0, NIVEL_MAXIMO))
	SistemaGuardado.set_contador(CONTADOR_RETO_PENDIENTE, 0)
	SistemaGuardado.set_contador(CONTADOR_VUELTA_PASILLO, 0)
	SistemaGuardado.set_flag(BANDERA_PREMIO_PENDIENTE, false)
	SistemaGuardado.set_contador(CONTADOR_MAESTRO, EstadoMaestro.ESCONDIDO)
	al_transicion_entrada()


## Escribe el conjunto coherente de variables para que el MAESTRO esté en `estado`
## (no confía en el recálculo de OnTransition, que pisaría lo escrito).
static func forzar_estado_maestro(estado: int) -> void:
	var salas := salas_completadas()
	match estado:
		EstadoMaestro.ESCONDIDO:
			if salas >= NIVEL_MAXIMO:
				salas = NIVEL_MAXIMO - 1
			_escribir(salas, EstadoMaestro.ESCONDIDO, 0, 0, false)
		EstadoMaestro.EN_ACERTIJO:
			if salas >= NIVEL_MAXIMO:
				salas = NIVEL_MAXIMO - 1
			_escribir(salas, EstadoMaestro.EN_ACERTIJO, 1, 0, false)
		EstadoMaestro.PREMIO_PENDIENTE:
			salas = clampi(salas, 1, NIVEL_MAXIMO - 1)
			_escribir(salas, EstadoMaestro.PREMIO_PENDIENTE, 1, 0, true)
		EstadoMaestro.PENSANDO:
			if salas >= NIVEL_MAXIMO:
				salas = NIVEL_MAXIMO - 1
			_escribir(salas, EstadoMaestro.PENSANDO, 1, 0, false)
		EstadoMaestro.FINALIZADO:
			_escribir(NIVEL_MAXIMO, EstadoMaestro.FINALIZADO, 1, 0, false)
		EstadoMaestro.TIENDA_PENDIENTE:
			_escribir(NIVEL_MAXIMO, EstadoMaestro.TIENDA_PENDIENTE, 1, 0, true)


static func _escribir(salas: int, maestro: int, observado: int, reto: int, premio: bool) -> void:
	SistemaGuardado.set_contador(CONTADOR_SALAS, salas)
	SistemaGuardado.set_contador(CONTADOR_MAESTRO, maestro)
	SistemaGuardado.set_contador(CONTADOR_ENTRADA_OBSERVADO, observado)
	SistemaGuardado.set_contador(CONTADOR_RETO_PENDIENTE, reto)
	SistemaGuardado.set_contador(CONTADOR_VUELTA_PASILLO, 0)
	SistemaGuardado.set_flag(BANDERA_PREMIO_PENDIENTE, premio)


## «Re-armar pista» (true) / «Apagar» (false): ENTRANCE_STATE 0 / 1. Solo tiene sentido
## con el MAESTRO escondido; con otro estado se ignora para no dejar un estado incoherente.
static func fijar_observado(armado: bool) -> void:
	if estado_maestro() != EstadoMaestro.ESCONDIDO:
		return
	SistemaGuardado.set_contador(CONTADOR_ENTRADA_OBSERVADO, 0 if armado else 1)


## «Simular hallazgo»: ENTRANCE_STATE_2 = 1 (se presenta al cargar la entrada). Con las
## 8 salas se baja a 7 para que la presentación tenga sentido.
static func simular_hallazgo() -> void:
	var salas := mini(salas_completadas(), NIVEL_MAXIMO - 1)
	SistemaGuardado.set_contador(CONTADOR_SALAS, salas)
	SistemaGuardado.set_contador(CONTADOR_MAESTRO, EstadoMaestro.ESCONDIDO)
	SistemaGuardado.set_contador(CONTADOR_ENTRADA_OBSERVADO, 1)
	SistemaGuardado.set_contador(CONTADOR_RETO_PENDIENTE, 1)
	SistemaGuardado.set_contador(CONTADOR_VUELTA_PASILLO, 0)
	SistemaGuardado.set_flag(BANDERA_PREMIO_PENDIENTE, false)


## «Simular regreso del pasillo»: VAR_TRICK_HOUSE_STATE = 1; la próxima carga de la
## entrada deja el MAESTRO en REGRESO y recalcula en la visita siguiente.
static func simular_regreso_pasillo() -> void:
	SistemaGuardado.set_contador(CONTADOR_RETO_PENDIENTE, 0)
	SistemaGuardado.set_flag(BANDERA_PREMIO_PENDIENTE, false)
	SistemaGuardado.set_contador(CONTADOR_VUELTA_PASILLO, 1)


## «Premio pendiente sí/no» (PRIZE_PICKUP) con el estado del MAESTRO coherente:
## sí -> PREMIO_PENDIENTE (o TIENDA_PENDIENTE con 8 salas); no -> PENSANDO si estaba
## pendiente.
static func forzar_premio_pendiente(valor: bool) -> void:
	if valor:
		forzar_estado_maestro(EstadoMaestro.TIENDA_PENDIENTE if terminada() else EstadoMaestro.PREMIO_PENDIENTE)
		return
	SistemaGuardado.set_flag(BANDERA_PREMIO_PENDIENTE, false)
	var estado := estado_maestro()
	if estado == EstadoMaestro.PREMIO_PENDIENTE:
		SistemaGuardado.set_contador(CONTADOR_MAESTRO, EstadoMaestro.PENSANDO)
	elif estado == EstadoMaestro.TIENDA_PENDIENTE:
		SistemaGuardado.set_contador(CONTADOR_MAESTRO, EstadoMaestro.FINALIZADO)


## «Pergaminos: reiniciar los 8».
static func reiniciar_pruebas() -> void:
	for numero in range(1, PRUEBAS + 1):
		SistemaGuardado.set_contador(clave_prueba(numero), 0)
	for numero in range(1, INTERRUPTORES_P7 + 1):
		SistemaGuardado.set_flag(PLANTILLA_INTERRUPTOR_P7 % numero, false)
	SistemaGuardado.set_contador(CONTADOR_P7_TELETRANSPORTE, 0)


## «Reiniciar cartas»: las 9 cartas y la PEPITA vuelven a poder recogerse. No quita
## nada de la mochila.
static func reiniciar_cartas() -> void:
	for id_item in IDS_CARTAS:
		SistemaGuardado.set_flag("item_" + id_item, false)
	SistemaGuardado.set_flag("item_" + ID_ITEM_PEPITA, false)


## «REINICIAR CASA TRETA»: todo a cero. No toca medallas ni objetos ya obtenidos.
static func restablecer() -> void:
	for clave: String in PERSISTENTE:
		if PERSISTENTE[clave][0] == "bandera":
			SistemaGuardado.set_flag(clave, false)
		else:
			SistemaGuardado.set_contador(clave, 0)
	reiniciar_pruebas()
	reiniciar_cartas()


## Valores actuales de todo lo persistente (depuración y tests).
static func instantanea() -> Dictionary:
	var datos := {}
	for clave: String in PERSISTENTE:
		datos[clave] = SistemaGuardado.get_flag(clave) if PERSISTENTE[clave][0] == "bandera" \
				else SistemaGuardado.get_contador(clave)
	for numero in range(1, PRUEBAS + 1):
		datos[clave_prueba(numero)] = estado_prueba(numero)
	for numero in range(1, INTERRUPTORES_P7 + 1):
		datos[PLANTILLA_INTERRUPTOR_P7 % numero] = interruptor_p7(numero)
	return datos


## Incoherencias del estado actual (vacío = coherente). Lo usan el menú de depuración
## y los tests para comprobar que ninguna escritura deja una combinación imposible.
static func incoherencias() -> PackedStringArray:
	var avisos := PackedStringArray()
	var salas := salas_completadas()
	var maestro := estado_maestro()
	var premio := premio_pendiente()
	if maestro == EstadoMaestro.PREMIO_PENDIENTE and (not premio or salas < 1 or salas >= NIVEL_MAXIMO):
		avisos.append("PREMIO_PENDIENTE exige premio y 1..7 salas")
	if maestro == EstadoMaestro.TIENDA_PENDIENTE and (not premio or salas != NIVEL_MAXIMO):
		avisos.append("TIENDA_PENDIENTE exige premio y 8 salas")
	if maestro == EstadoMaestro.FINALIZADO and salas != NIVEL_MAXIMO:
		avisos.append("FINALIZADO exige 8 salas")
	# EN_ACERTIJO con 8 salas es legítimo un rato: el MAESTRO se va al terminar la 8.ª y
	# el estado no se recalcula hasta volver del pasillo.
	if salas == NIVEL_MAXIMO and maestro in [EstadoMaestro.ESCONDIDO, EstadoMaestro.PENSANDO]:
		avisos.append("con 8 salas el MAESTRO ya no está escondido ni pensando")
	if premio and maestro in [EstadoMaestro.ESCONDIDO, EstadoMaestro.EN_ACERTIJO, EstadoMaestro.PENSANDO,
			EstadoMaestro.FINALIZADO]:
		avisos.append("premio pendiente con el MAESTRO en %d" % maestro)
	if maestro == EstadoMaestro.ESCONDIDO and entrada_observada() == 0 and reto_pendiente():
		avisos.append("reto pendiente con los disparadores armados")
	return avisos
