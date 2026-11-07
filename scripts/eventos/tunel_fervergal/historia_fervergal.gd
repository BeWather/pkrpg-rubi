## historia_fervergal.gd
## Estado de la historia de las PIEZAS DEVON entre la RUTA 116 y el TÚNEL FERVERGAL
## (pokeruby Route116 y RusturfTunnel). Como HistoriaBlasco, no es un nodo: lo
## consultan y avanzan EventoRuta116 y EventoTunelFervergal.
##
## Variables de Gen 3 que no son banderas:
## - VAR_ROUTE116_STATE: 1 al robar las PIEZAS (el SR. ARENQUE llora en la ruta),
##   2 cuando el jugador ya habló con él.
## - VAR_RUSTURF_TUNNEL_STATE: 2 al robar (el soldado MAGMA y PEEKO esperan en
##   (13,4) y (13,5)), 3 al pisar (9,4)/(9,5), 4 o 5 al romper una de las rocas
##   (TryUpdateRusturfTunnelState), 6 con el túnel abierto.
##
## Lo que Rubí deduce con banderas HIDE (FLAG_HIDE_BRINEY_ROUTE116,
## FLAG_HIDE_PEEKO_RUSTURF_TUNNEL, FLAG_HIDE_GRUNT_RUSTURF_TUNNEL) en el proyecto
## sale de BANDERA_ROBADAS (FLAG_DEVON_GOODS_STOLEN): el robo la activa junto con
## ellas y el rescate la apaga a la vez que las vuelve a activar.
class_name HistoriaFervergal
extends RefCounted

## VAR_ROUTE116_STATE.
const CONTADOR_RUTA_116: String = "ruta_116_estado"
## VAR_RUSTURF_TUNNEL_STATE.
const CONTADOR_TUNEL: String = "tunel_fervergal_estado"
## VAR_RUSTBORO_STATE (HistoriaFerrica.CONTADOR; aquí sin referirse a la otra clase
## para no cruzar las dependencias). El rescate lo deja en 4.
const CONTADOR_FERRICA: String = "ferrica_estado"
const FERRICA_PIEZAS_RECUPERADAS: int = 4

## FLAG_DEVON_GOODS_STOLEN (la define CIUDAD FÉRRICA).
const BANDERA_ROBADAS: String = "ferrica_mercancias_robadas"
## FLAG_RECOVERED_DEVON_GOODS: el jugador recuperó las PIEZAS en el túnel.
const BANDERA_RECUPERADAS: String = "piezas_devon_recuperadas"
## FLAG_DELIVERED_DEVON_GOODS (la define la barca del SR. ARENQUE).
const BANDERA_ENTREGADAS: String = "piezas_devon_entregadas"
## FLAG_MET_DEVON_EMPLOYEE.
const BANDERA_EMPLEADO_CONOCIDO: String = "ruta_116_empleado_devon_conocido"
## FLAG_RECEIVED_REPEAT_BALL (≈ FLAG_HIDE_DEVON_EMPLOYEE_ROUTE116 tras irse, y
## clearflag FLAG_HIDE_EMPLOYEE_DEVON_CORP_3F: el empleado vuelve a DEVON 3F).
const BANDERA_ACOPIO_BALL: String = "ruta_116_repeat_ball_recibida"
## FLAG_HIDE_LOST_GLASSES_MAN.
const BANDERA_HOMBRE_GAFAS_SE_FUE: String = "ruta_116_hombre_gafas_oculto"
## FLAG_HIDDEN_ITEM_BLACK_GLASSES: ItemOverworld guarda "item_" + id_item.
const BANDERA_GAFAS_ENCONTRADAS: String = "item_ruta_116_gafas_sol_oculta_01"
## FLAG_RUSTURF_TUNNEL_OPENED.
const BANDERA_TUNEL_ABIERTO: String = "tunel_fervergal_abierto"
## FLAG_RECEIVED_HM04.
const BANDERA_MO04: String = "tunel_fervergal_mo04_recibida"
## FLAG_HIDE_BOYFRIEND_WANDAS_HOUSE / FLAG_HIDE_GIRLFRIEND_WANDAS_HOUSE (inversas):
## SetRusturfTunnelOpen los manda a casa de CLARA, en PUEBLO VERDEGAL.
const BANDERA_CASA_CLARA_NOVIO: String = "verdegal_casa_clara_novio_presente"
const BANDERA_CASA_CLARA_NOVIA: String = "verdegal_casa_clara_novia_presente"
## FLAG_HIDE_MR_BRINEY_ROUTE104_HOUSE (inversa; la define la casa del SR. ARENQUE).
const BANDERA_ARENQUE_CASA: String = "arenque_en_casa"
## FLAG_SYS_POKENAV_GET: DEVON 3F lo activa en el mismo guion que
## setflag FLAG_HIDE_TUNNER_DIGGER_ROUTE116 y clearflag FLAG_HIDE_BOYFRIEND/
## GIRLFRIEND_RUSTURF_TUNNEL.
const BANDERA_POKENAV: String = "pokenav_obtenido"

## VAR_ROUTE116_STATE.
enum Ruta116 {
	INICIAL = 0,
	## El robo ya ocurrió: el SR. ARENQUE llora al lado de la entrada del túnel.
	ARENQUE_LLORANDO = 1,
	ARENQUE_HABLADO = 2,
}

## VAR_RUSTURF_TUNNEL_STATE.
enum Tunel {
	INICIAL = 0,
	## El soldado MAGMA y PEEKO esperan en (13,5) y (13,4).
	PERSECUCION = 2,
	EMBOSCADA_VISTA = 3,
	ROCA_ROTA_1 = 4,
	ROCA_ROTA_2 = 5,
	ABIERTO = 6,
}

## Clave de SistemaGuardado → [tipo, equivalente en Gen 3].
const PERSISTENTE := {
	CONTADOR_RUTA_116: ["contador", "VAR_ROUTE116_STATE"],
	CONTADOR_TUNEL: ["contador", "VAR_RUSTURF_TUNNEL_STATE"],
	CONTADOR_FERRICA: ["contador", "VAR_RUSTBORO_STATE"],
	BANDERA_ROBADAS: ["bandera", "FLAG_DEVON_GOODS_STOLEN"],
	BANDERA_RECUPERADAS: ["bandera", "FLAG_RECOVERED_DEVON_GOODS"],
	BANDERA_EMPLEADO_CONOCIDO: ["bandera", "FLAG_MET_DEVON_EMPLOYEE"],
	BANDERA_ACOPIO_BALL: ["bandera", "FLAG_RECEIVED_REPEAT_BALL"],
	BANDERA_HOMBRE_GAFAS_SE_FUE: ["bandera", "FLAG_HIDE_LOST_GLASSES_MAN"],
	BANDERA_TUNEL_ABIERTO: ["bandera", "FLAG_RUSTURF_TUNNEL_OPENED"],
	BANDERA_MO04: ["bandera", "FLAG_RECEIVED_HM04"],
	BANDERA_CASA_CLARA_NOVIO: ["bandera", "FLAG_HIDE_BOYFRIEND_WANDAS_HOUSE (inversa)"],
	BANDERA_CASA_CLARA_NOVIA: ["bandera", "FLAG_HIDE_GIRLFRIEND_WANDAS_HOUSE (inversa)"],
}


static func ruta_116() -> int:
	return SistemaGuardado.get_contador(CONTADOR_RUTA_116)


static func tunel() -> int:
	return SistemaGuardado.get_contador(CONTADOR_TUNEL)


static func piezas_robadas() -> bool:
	return SistemaGuardado.get_flag(BANDERA_ROBADAS)


static func piezas_recuperadas() -> bool:
	return SistemaGuardado.get_flag(BANDERA_RECUPERADAS)


static func tunel_abierto() -> bool:
	return SistemaGuardado.get_flag(BANDERA_TUNEL_ABIERTO)


## RustboroCity_EventScript_StolenGoodsTrigger*: setflag FLAG_DEVON_GOODS_STOLEN,
## VAR_RUSTURF_TUNNEL_STATE 2 y VAR_ROUTE116_STATE 1; el mismo guion quita
## FLAG_HIDE_BRINEY_ROUTE116, FLAG_HIDE_PEEKO_RUSTURF_TUNNEL y
## FLAG_HIDE_GRUNT_RUSTURF_TUNNEL (aquí los muestra BANDERA_ROBADAS), y activa
## FLAG_HIDE_MR_BRINEY_ROUTE104_HOUSE / FLAG_HIDE_PEEKO_BRINEY_HOUSE (`arenque_en_casa`
## en false: DEVON 3F la vuelve a poner). Lo llama el guion del robo de CIUDAD FÉRRICA
## (HistoriaFerrica.robar_piezas, que además deja VAR_RUSTBORO_STATE en 2).
static func iniciar_persecucion() -> void:
	SistemaGuardado.set_flag(BANDERA_ROBADAS, true)
	SistemaGuardado.set_flag(BANDERA_ARENQUE_CASA, false)
	SistemaGuardado.set_contador(CONTADOR_TUNEL, Tunel.PERSECUCION)
	SistemaGuardado.set_contador(CONTADOR_RUTA_116, Ruta116.ARENQUE_LLORANDO)


## RusturfTunnel_EventScript_15C9EA al final: clearflag FLAG_DEVON_GOODS_STOLEN y
## setflag FLAG_RECOVERED_DEVON_GOODS, VAR_BRINEY_HOUSE_STATE 1 (`arenque_casa_persecucion`
## de la casa del SR. ARENQUE) y setflag FLAG_HIDE_BRINEY_ROUTE116 (aquí, el fin de
## BANDERA_ROBADAS) y setvar VAR_RUSTBORO_STATE, 4 (CIUDAD FÉRRICA: HistoriaFerrica).
static func recuperar_piezas() -> void:
	SistemaGuardado.set_flag(BANDERA_ROBADAS, false)
	SistemaGuardado.set_flag(BANDERA_RECUPERADAS, true)
	SistemaGuardado.set_flag("arenque_casa_persecucion", true)  # VAR_BRINEY_HOUSE_STATE 1
	SistemaGuardado.set_contador(CONTADOR_FERRICA, FERRICA_PIEZAS_RECUPERADAS)


## RusturfTunnel_EventScript_SetRusturfTunnelOpen.
static func abrir_tunel() -> void:
	SistemaGuardado.set_contador(CONTADOR_TUNEL, Tunel.ABIERTO)
	SistemaGuardado.set_flag(BANDERA_TUNEL_ABIERTO, true)
	SistemaGuardado.set_flag(BANDERA_CASA_CLARA_NOVIO, true)
	SistemaGuardado.set_flag(BANDERA_CASA_CLARA_NOVIA, true)


## Valores actuales de todo lo persistente (depuración y tests).
static func instantanea() -> Dictionary:
	var datos := {}
	for clave: String in PERSISTENTE:
		datos[clave] = SistemaGuardado.get_flag(clave) if PERSISTENTE[clave][0] == "bandera" \
			else SistemaGuardado.get_contador(clave)
	return datos


## Restaura una instantánea (o, vacía, la partida antes del robo).
static func restablecer(datos: Dictionary = {}) -> void:
	for clave: String in PERSISTENTE:
		if PERSISTENTE[clave][0] == "bandera":
			SistemaGuardado.set_flag(clave, bool(datos.get(clave, false)))
		else:
			SistemaGuardado.set_contador(clave, int(datos.get(clave, 0)))
