## historia_villa_raiz.gd
## Estado de la historia de VILLA RAÍZ (pokeruby data/maps/LittlerootTown*/ y
## data/scripts/players_house.inc), consultado por los eventos del pueblo, de las
## casas y del laboratorio. No es un nodo ni guarda nada: lo que persiste vive en
## SistemaGuardado (banderas y contadores).
##
## Variables de pokeruby:
## - VAR_LITTLEROOT_INTRO_STATE → contador `CONTADOR_INTRO` (secuencial 1..7).
##   0 = partida sin intro (anterior a estos eventos o arranque de depuración):
##   se trata como intro terminada (7).
## - VAR_LITTLEROOT_STATE, VAR_LITTLEROOT_RIVAL_STATE y VAR_BIRCH_LAB_STATE se
##   deducen de banderas, como VAR_ROUTE101_STATE en EventoRescateAbedul.
##
## Casas: casa 1 (nodo_casa_1_*) es la de BRUNO (BRENDAN), casa 2 la de AURA (MAY).
## La del jugador depende de su sexo, igual que en Rubí.
class_name HistoriaVillaRaiz
extends RefCounted

## VAR_LITTLEROOT_INTRO_STATE.
const CONTADOR_INTRO: String = "villa_raiz_intro"

## FLAG_RESCUED_BIRCH (la pone el bolso de ABEDUL en la Ruta 101).
const BANDERA_RESCATADO: String = "abedul_rescatado"
## VAR_ROUTE101_STATE 3 / inicial ya elegido (Ruta 101 o Bandolera).
const BANDERA_INICIAL: String = "inicial_seleccionado"
## FLAG_DEFEATED_RIVAL_ROUTE103 (bandera_completado del EventoRival de la Ruta 103).
const BANDERA_RIVAL_RUTA_103: String = "ruta_103_rival_vencido"
## VAR_LITTLEROOT_RIVAL_STATE 3: ya conociste al rival en su cuarto.
const BANDERA_RIVAL_CONOCIDO: String = "villa_raiz_rival_conocido"
## FLAG_MET_RIVAL_MOM (VAR_LITTLEROOT_HOUSES_STATE(_2) 2): la madre del rival ya te
## ha visto entrar en su casa y se ha presentado.
const BANDERA_MADRE_RIVAL_CONOCIDA: String = "villa_raiz_madre_rival_conocida"
## FLAG_RIVAL_LEFT_FOR_ROUTE103: salió de casa camino de la RUTA 103.
const BANDERA_RIVAL_SE_FUE: String = "villa_raiz_rival_se_fue"
## VAR_LITTLEROOT_STATE 2: el niño de la salida norte ya avisó de los gritos.
const BANDERA_AVISO_SOCORRO: String = "villa_raiz_aviso_socorro"
## VAR_BIRCH_LAB_STATE 3: aceptaste ir a ver al rival.
const BANDERA_VER_RIVAL: String = "laboratorio_ver_rival"
## FLAG_SYS_POKEDEX_GET (PokedexPartida).
const BANDERA_POKEDEX: String = PokedexPartida.BANDERA
## FLAG_ADVENTURE_STARTED.
const BANDERA_AVENTURA: String = "aventura_iniciada"
## FLAG_RECEIVED_RUNNING_SHOES / FLAG_SYS_B_DASH.
const BANDERA_DEPORTIVAS: String = "deportivas_recibidas"
## Activa mientras no se pueda correr: la pone la partida nueva y la quita MAMÁ al
## dar las DEPORTIVAS (las partidas anteriores no la tienen y siguen corriendo).
const BANDERA_SIN_DEPORTIVAS: String = "sin_deportivas"
## FLAG_HIDE_MAP_NAME_POPUP (AdministradorMapa.BANDERA_OCULTAR_CARTEL_LUGAR).
const BANDERA_OCULTAR_CARTEL: String = "ocultar_cartel_lugar"
## FLAG_SET_WALL_CLOCK.
const BANDERA_RELOJ: String = "reloj_puesto"
## FLAG_SYS_TV_HOME: la tele de casa ya se usó (informe del GIMNASIO de PETALIA).
const BANDERA_TELE: String = "tele_casa"
## FLAG_HIDE_RIVAL_BIRCH_LAB vuelto a activar en BeginWallyTutorial (PetalburgCity_Gym):
## el rival deja el laboratorio. La activa HistoriaBlasco.salir_con_blasco().
const BANDERA_RIVAL_DEJA_LABORATORIO: String = "laboratorio_rival_se_fue"
## FLAG_RECEIVED_AMULET_COIN: MAMÁ ya dio la MON. AMULETO.
const BANDERA_MONEDA_AMULETO: String = "moneda_amuleto_recibida"
## FLAG_RECEIVED_SS_TICKET: PAPÁ ya dio el TICKET BARCO.
const BANDERA_TICKET_BARCO: String = "villa_raiz_ticket_barco_recibido"
## FLAG_SYS_GAME_CLEAR.
const BANDERA_JUEGO_COMPLETADO: String = "SYS_GAME_CLEAR"

## VAR_LITTLEROOT_INTRO_STATE.
enum Intro {
	SIN_INTRO = 0,
	CAMION_CHICO = 1,
	CAMION_CHICA = 2,
	ENTRAR_EN_CASA = 3,
	VER_CUARTO = 4,
	PONER_RELOJ = 5,
	INFORME_GIMNASIO = 6,
	TERMINADA = 7,
}


static func es_chico() -> bool:
	return str(SistemaGuardado.datos_vivos.jugador.get("sexo", "M")) == "M"


## 1 (casa de BRUNO) o 2 (casa de AURA): la del jugador.
static func casa_jugador() -> int:
	return 1 if es_chico() else 2


## VAR_LITTLEROOT_HOUSES_STATE 3 (ReadyReceiveSSTicketEvent): tras la LIGA, PAPÁ espera
## en casa con el TICKET BARCO. Vale también para partidas que ya habían pasado la LIGA.
static func ticket_barco_por_recibir() -> bool:
	return SistemaGuardado.get_flag(BANDERA_JUEGO_COMPLETADO) and not SistemaGuardado.get_flag(BANDERA_TICKET_BARCO)


## Clave de mapa de la planta baja de la casa del jugador.
static func mapa_casa_jugador() -> String:
	return "nodo_casa_%d_piso_1" % casa_jugador()


## VAR_LITTLEROOT_INTRO_STATE (0 cuenta como intro terminada).
static func intro() -> int:
	var valor := SistemaGuardado.get_contador(CONTADOR_INTRO)
	return Intro.TERMINADA if valor <= Intro.SIN_INTRO else valor


static func set_intro(valor: int) -> void:
	SistemaGuardado.set_contador(CONTADOR_INTRO, valor)


## Partida nueva al salir del camión (VAR_LITTLEROOT_INTRO_STATE 1 o 2) y sin
## poder correr hasta tener las DEPORTIVAS.
static func empezar_intro() -> void:
	if SistemaGuardado.get_contador(CONTADOR_INTRO) > Intro.SIN_INTRO:
		return
	set_intro(Intro.CAMION_CHICO if es_chico() else Intro.CAMION_CHICA)
	SistemaGuardado.set_flag(BANDERA_SIN_DEPORTIVAS, true)
	# FLAG_HIDE_MAP_NAME_POPUP: sin cartel de VILLA RAÍZ hasta entrar en casa.
	SistemaGuardado.set_flag(BANDERA_OCULTAR_CARTEL, true)


## VAR_LITTLEROOT_STATE: 0 al llegar, 1 tras conocer al rival, 2 tras el aviso del
## niño (o con inicial), 3 con la POKéDEX (MAMÁ espera con las DEPORTIVAS), 4 con las
## DEPORTIVAS.
static func estado_pueblo() -> int:
	if SistemaGuardado.get_flag(BANDERA_DEPORTIVAS):
		return 4
	if SistemaGuardado.get_flag(BANDERA_POKEDEX):
		return 3
	# Con inicial (rescate o Bandolera de las partidas anteriores) ya no se vigila la salida.
	if SistemaGuardado.get_flag(BANDERA_AVISO_SOCORRO) or SistemaGuardado.get_flag(BANDERA_INICIAL):
		return 2
	if SistemaGuardado.get_flag(BANDERA_RIVAL_CONOCIDO):
		return 1
	return 0


## VAR_BIRCH_LAB_STATE: 0 sin rescate, 2 tras elegir el inicial en el rescate, 3 tras
## aceptar ir a ver al rival, 4 tras vencerle en la RUTA 103, 5 con la POKéDEX.
static func estado_laboratorio() -> int:
	if SistemaGuardado.get_flag(BANDERA_POKEDEX):
		return 5
	if SistemaGuardado.get_flag(BANDERA_RIVAL_RUTA_103):
		return 4
	if SistemaGuardado.get_flag(BANDERA_VER_RIVAL):
		return 3
	if SistemaGuardado.get_flag(BANDERA_RESCATADO):
		return 2
	return 0


## FLAG_HIDE_BIRCH_IN_LAB: ABEDUL está en el laboratorio desde el rescate.
static func abedul_en_laboratorio() -> bool:
	return SistemaGuardado.get_flag(BANDERA_RESCATADO)


## FLAG_HIDE_RIVAL_BIRCH_LAB: el rival vuelve al laboratorio tras la RUTA 103 y lo
## deja cuando el jugador sale del GIMNASIO de PETALIA con BLASCO.
static func rival_en_laboratorio() -> bool:
	return SistemaGuardado.get_flag(BANDERA_RIVAL_RUTA_103) \
		and not SistemaGuardado.get_flag(BANDERA_RIVAL_DEJA_LABORATORIO)


## FLAG_HIDE_{MAY,BRENDAN}_UPSTAIRS: el rival espera en su cuarto hasta conocerle.
static func rival_en_su_cuarto() -> bool:
	return not SistemaGuardado.get_flag(BANDERA_RIVAL_CONOCIDO)


## VAR_LITTLEROOT_HOUSES_STATE(_2) 1: al entrar por primera vez en la casa del rival,
## su madre sale a presentarse. Solo en la partida nueva: no se repite ni se dispara
## si ya conociste al rival (o la historia está más avanzada, estado_pueblo() > 0,
## como las partidas anteriores a esta escena).
static func madre_rival_por_conocer() -> bool:
	return not SistemaGuardado.get_flag(BANDERA_MADRE_RIVAL_CONOCIDA) and estado_pueblo() == 0


## Puede correr (FLAG_SYS_B_DASH).
static func puede_correr() -> bool:
	return not SistemaGuardado.get_flag(BANDERA_SIN_DEPORTIVAS)


## Clave de texto con la variante del rival: "<base>_AURA" o "<base>_BRUNO".
static func texto_rival(base: String) -> String:
	return "%s_%s" % [base, Rival.clave()]
