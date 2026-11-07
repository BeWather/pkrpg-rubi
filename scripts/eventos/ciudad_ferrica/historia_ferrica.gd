## historia_ferrica.gd
## Estado de la historia de CIUDAD FÉRRICA, su GIMNASIO y DEVON S.A. (pokeruby
## data/maps/RustboroCity, RustboroCity_Gym y RustboroCity_DevonCorp_*). Como
## HistoriaFervergal, no es un nodo: lo consultan y avanzan los eventos del mapa.
##
## VAR_RUSTBORO_STATE (`ferrica_estado`):
##   0 antes de la MEDALLA PIEDRA; 1 con ella (la pone el GIMNASIO: `vencer_gimnasio`);
##   2 tras el robo de las PIEZAS DEVON (RustboroCity_EventScript_StolenGoodsScene);
##   3 cuando el empleado pide ayuda (EmployeeAskToGetGoods); 4 con las PIEZAS
##   recuperadas en el TÚNEL FERVERGAL (RusturfTunnel_EventScript_15C9EA);
##   5 con las PIEZAS devueltas (ReturnGoods).
##
## Lo que Rubí guarda con banderas HIDE aquí es positivo:
## - FLAG_HIDE_DEVON_RUSTBORO → `ferrica_empleado_devon_presente` (inversa): el
##   empleado del exterior existe desde el robo hasta la devolución.
## - VAR_DEVON_CORP_3F_STATE 1 → `ferrica_devon_presidente_visto`.
class_name HistoriaFerrica
extends RefCounted

## VAR_RUSTBORO_STATE.
const CONTADOR: String = "ferrica_estado"
## FLAG_RETURNED_DEVON_GOODS (ya existía en el exterior).
const BANDERA_DEVUELTAS: String = "ferrica_mercancias_devueltas"
## FLAG_HIDE_DEVON_RUSTBORO (inversa).
const BANDERA_EMPLEADO_PRESENTE: String = "ferrica_empleado_devon_presente"
## VAR_DEVON_CORP_3F_STATE 1.
const BANDERA_PRESIDENTE_VISTO: String = "ferrica_devon_presidente_visto"
## FLAG_HIDE_RIVAL_RUSTBORO (inversa; ya existía en el exterior).
const BANDERA_RIVAL: String = "ferrica_rival_esperando"
## FLAG_RECEIVED_HM01.
const BANDERA_MO01: String = "ferrica_mo01_recibida"
## FLAG_RECEIVED_TM_ROCK_TOMB (la MT39).
const BANDERA_MT39: String = "ferrica_mt39_recibida"
## FLAG_RECEIVED_QUICK_CLAW.
const BANDERA_GARRA_RAPIDA: String = "ferrica_garra_rapida_recibida"
## FLAG_RECEIVED_PREMIER_BALL_RUSTBORO.
const BANDERA_HONOR_BALL: String = "ferrica_honor_ball_recibida"
## FLAG_RECEIVED_EXP_SHARE.
const BANDERA_REPARTIR_EXP: String = "ferrica_reparto_exp_recibido"
## FLAG_RECEIVED_FOSSIL_MON.
const BANDERA_FOSIL_RECIBIDO: String = "ferrica_fosil_recibido"
## VAR_FOSSIL_RESURRECTION_STATE (0 nada, 1 regenerando, 2 listo).
const CONTADOR_FOSIL: String = "ferrica_fosil_estado"
## VAR_WHICH_FOSSIL_REVIVED (1 FÓSIL RAÍZ → LILEEP, 2 FÓSIL GARRA → ANORITH).
const CONTADOR_FOSIL_ELEGIDO: String = "ferrica_fosil_elegido"
## FLAG_RUSTBORO_NPC_TRADE_COMPLETED (nadie la activa: el intercambio no existe).
const BANDERA_INTERCAMBIO: String = "ferrica_intercambio_completado"
## FLAG_DELIVERED_STEVEN_LETTER (la define la barca del SR. ARENQUE).
const BANDERA_CARTA: String = "carta_maximo_entregada"
## FLAG_MET_DEVON_EMPLOYEE (la define la RUTA 116).
const BANDERA_EMPLEADO_CONOCIDO: String = "ruta_116_empleado_devon_conocido"

enum Estado {
	INICIAL = 0,
	GIMNASIO_VENCIDO = 1,
	PIEZAS_ROBADAS = 2,
	AYUDA_PEDIDA = 3,
	PIEZAS_RECUPERADAS = 4,
	PIEZAS_DEVUELTAS = 5,
}

enum Fosil {
	NADA = 0,
	REGENERANDO = 1,
	LISTO = 2,
}

## Clave de SistemaGuardado → [tipo, equivalente en Gen 3].
const PERSISTENTE := {
	CONTADOR: ["contador", "VAR_RUSTBORO_STATE"],
	BANDERA_DEVUELTAS: ["bandera", "FLAG_RETURNED_DEVON_GOODS"],
	BANDERA_EMPLEADO_PRESENTE: ["bandera", "FLAG_HIDE_DEVON_RUSTBORO (inversa)"],
	BANDERA_PRESIDENTE_VISTO: ["bandera", "VAR_DEVON_CORP_3F_STATE 1"],
	BANDERA_RIVAL: ["bandera", "FLAG_HIDE_RIVAL_RUSTBORO (inversa)"],
	BANDERA_MO01: ["bandera", "FLAG_RECEIVED_HM01"],
	BANDERA_MT39: ["bandera", "FLAG_RECEIVED_TM_ROCK_TOMB"],
	BANDERA_GARRA_RAPIDA: ["bandera", "FLAG_RECEIVED_QUICK_CLAW"],
	BANDERA_HONOR_BALL: ["bandera", "FLAG_RECEIVED_PREMIER_BALL_RUSTBORO"],
	BANDERA_REPARTIR_EXP: ["bandera", "FLAG_RECEIVED_EXP_SHARE"],
	BANDERA_FOSIL_RECIBIDO: ["bandera", "FLAG_RECEIVED_FOSSIL_MON"],
	CONTADOR_FOSIL: ["contador", "VAR_FOSSIL_RESURRECTION_STATE"],
	CONTADOR_FOSIL_ELEGIDO: ["contador", "VAR_WHICH_FOSSIL_REVIVED"],
	BANDERA_INTERCAMBIO: ["bandera", "FLAG_RUSTBORO_NPC_TRADE_COMPLETED"],
}


## VAR_RUSTBORO_STATE. Con la MEDALLA PIEDRA ya cuenta como 1 aunque el contador
## siga en 0 (partidas anteriores al GIMNASIO de FÉRRICA).
static func estado() -> int:
	var contador := SistemaGuardado.get_contador(CONTADOR)
	if contador < Estado.GIMNASIO_VENCIDO and SistemaGuardado.tiene_medalla(0):
		return Estado.GIMNASIO_VENCIDO
	return contador


static func piezas_devueltas() -> bool:
	return SistemaGuardado.get_flag(BANDERA_DEVUELTAS)


static func presidente_visto() -> bool:
	return SistemaGuardado.get_flag(BANDERA_PRESIDENTE_VISTO)


static func estado_fosil() -> int:
	return SistemaGuardado.get_contador(CONTADOR_FOSIL)


## RustboroCity_Gym_EventScript_RoxanneDefeated: setvar VAR_RUSTBORO_STATE, 1.
static func vencer_gimnasio() -> void:
	if SistemaGuardado.get_contador(CONTADOR) < Estado.GIMNASIO_VENCIDO:
		SistemaGuardado.set_contador(CONTADOR, Estado.GIMNASIO_VENCIDO)


## RustboroCity_EventScript_StolenGoodsScene (al final): FLAG_DEVON_GOODS_STOLEN y
## el estado del TÚNEL y la RUTA 116 (HistoriaFervergal), VAR_RUSTBORO_STATE 2 y
## el empleado, que vuelve a la ciudad en (30,10) (clearflag FLAG_HIDE_DEVON_RUSTBORO).
static func robar_piezas() -> void:
	HistoriaFervergal.iniciar_persecucion()
	SistemaGuardado.set_contador(CONTADOR, Estado.PIEZAS_ROBADAS)
	SistemaGuardado.set_flag(BANDERA_EMPLEADO_PRESENTE, true)


## RustboroCity_EventScript_EmployeeAskToGetGoods: VAR_RUSTBORO_STATE 3.
static func pedir_ayuda() -> void:
	SistemaGuardado.set_contador(CONTADOR, Estado.AYUDA_PEDIDA)


## RustboroCity_EventScript_ReturnGoods: FLAG_RETURNED_DEVON_GOODS,
## setflag FLAG_HIDE_DEVON_RUSTBORO y VAR_RUSTBORO_STATE 5.
static func devolver_piezas() -> void:
	SistemaGuardado.set_flag(BANDERA_DEVUELTAS, true)
	SistemaGuardado.set_flag(BANDERA_EMPLEADO_PRESENTE, false)
	SistemaGuardado.set_contador(CONTADOR, Estado.PIEZAS_DEVUELTAS)


## RustboroCity_DevonCorp_3F_OnFrame (MeetPresident), al final del guion: el POKéNAV y
## lo que desbloquea (excavador de la RUTA 116, pareja del TÚNEL, SR. ARENQUE en su
## casa y el rival esperando en FÉRRICA).
static func recibir_pokenav() -> void:
	SistemaGuardado.set_flag(HistoriaFervergal.BANDERA_POKENAV, true)
	SistemaGuardado.set_flag(HistoriaFervergal.BANDERA_ARENQUE_CASA, true)
	SistemaGuardado.set_flag(BANDERA_RIVAL, true)
	SistemaGuardado.set_flag(BANDERA_PRESIDENTE_VISTO, true)


## Valores actuales de todo lo persistente (depuración y tests).
static func instantanea() -> Dictionary:
	var datos := {}
	for clave: String in PERSISTENTE:
		datos[clave] = SistemaGuardado.get_flag(clave) if PERSISTENTE[clave][0] == "bandera" \
			else SistemaGuardado.get_contador(clave)
	return datos


## Restaura una instantánea (o, vacía, la partida sin avanzar en FÉRRICA).
static func restablecer(datos: Dictionary = {}) -> void:
	for clave: String in PERSISTENTE:
		if PERSISTENTE[clave][0] == "bandera":
			SistemaGuardado.set_flag(clave, bool(datos.get(clave, false)))
		else:
			SistemaGuardado.set_contador(clave, int(datos.get(clave, 0)))
