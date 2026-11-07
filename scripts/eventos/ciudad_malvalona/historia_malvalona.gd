## historia_malvalona.gd
## Estado persistente de los interiores de CIUDAD MALVALONA que no es del GIMNASIO
## (casas, BICICLETERÍA y CASINO): banderas y valores de SistemaGuardado con su
## equivalente en Rubí. No es un nodo: lo consultan los guiones, el cartel de
## depuración y los tests (patrón HistoriaBlasco / HistoriaCasaTreta).
class_name HistoriaMalvalona
extends RefCounted

## FLAG_RECEIVED_HM06 (CASA 1).
const BANDERA_MO06: String = "malvalona_mo06_recibida"
## FLAG_RECEIVED_COIN_CASE (CASA 2).
const BANDERA_MONEDERO: String = "malvalona_monedero_recibido"
## FLAG_RECEIVED_BIKE / FLAG_DECLINED_BIKE (BICICLETERÍA).
const BANDERA_BICI_RECIBIDA: String = "malvalona_bici_recibida"
const BANDERA_BICI_RECHAZADA: String = "malvalona_bici_rechazada"
## FLAG_RECEIVED_STARTER_DOLL y FLAG_RECEIVED_20_COINS (CASINO).
const BANDERA_MUNECO_INICIAL: String = "malvalona_muneco_inicial_recibido"
const BANDERA_20_FICHAS: String = "malvalona_fichas_20_recibidas"
## FLAG_RECEIVED_TM_SHOCK_WAVE (GIMNASIO).
const BANDERA_MT34: String = "malvalona_mt34_recibida"
## FLAG_HIDE_WATTSON_MAUVILLE (inversa), FLAG_GOT_TM_THUNDERBOLT_FROM_WATTSON,
## FLAG_RECEIVED_BASEMENT_KEY y VAR_NEW_MAUVILLE_STATE == 2 (exterior).
const BANDERA_ERICO_FUERA: String = "malvalona_erico_fuera"
const BANDERA_MT_RAYO: String = "malvalona_mt_rayo_recibida"
const BANDERA_LLAVE_SOTANO: String = "malvalona_llave_sotano_recibida"
const BANDERA_NUEVA_MALVALONA: String = "nueva_malvalona_completada"

const OBJETO_BICI_CARRERA: String = "BICICARRERA"
const OBJETO_BICI_ACROBATICA: String = "BICIACROBAT"
const OBJETO_CARTA_PUERTO: String = "CARTAPUERTO"
const OBJETO_MONEDERO: String = "MONEDERO"

## Clave de SistemaGuardado → [tipo, equivalente en Gen 3].
const PERSISTENTE := {
	BANDERA_MO06: ["bandera", "FLAG_RECEIVED_HM06"],
	BANDERA_MONEDERO: ["bandera", "FLAG_RECEIVED_COIN_CASE"],
	BANDERA_BICI_RECIBIDA: ["bandera", "FLAG_RECEIVED_BIKE"],
	BANDERA_BICI_RECHAZADA: ["bandera", "FLAG_DECLINED_BIKE"],
	BANDERA_MUNECO_INICIAL: ["bandera", "FLAG_RECEIVED_STARTER_DOLL"],
	BANDERA_20_FICHAS: ["bandera", "FLAG_RECEIVED_20_COINS"],
	BANDERA_MT34: ["bandera", "FLAG_RECEIVED_TM_SHOCK_WAVE"],
	BANDERA_ERICO_FUERA: ["bandera", "!FLAG_HIDE_WATTSON_MAUVILLE"],
	BANDERA_MT_RAYO: ["bandera", "FLAG_GOT_TM_THUNDERBOLT_FROM_WATTSON"],
	BANDERA_LLAVE_SOTANO: ["bandera", "FLAG_RECEIVED_BASEMENT_KEY"],
	BANDERA_NUEVA_MALVALONA: ["bandera", "VAR_NEW_MAUVILLE_STATE == 2"],
	MonederoFichas.CONTADOR: ["contador", "gSaveBlock1.coins"],
}


## Bolsillo de la mochila de un objeto (0..4).
static func bolsillo(objeto: String) -> int:
	return int(SistemaGuardado.obtener_datos_objeto_completos(objeto).get("bolsillo_id", 0))


static func tiene(objeto: String) -> bool:
	return SistemaGuardado.tiene_objeto(objeto, 1, bolsillo(objeto))


static func quitar(objeto: String) -> bool:
	return SistemaGuardado.quitar_objeto_jugador(objeto, 1, bolsillo(objeto))


## SwapRegisteredBike: si lo registrado en SELECT es una de las dos bicis, pasa a
## ser la otra.
static func cambiar_bici_registrada() -> void:
	var registrado := UsoObjetosCampo.objeto_registrado()
	if registrado == OBJETO_BICI_CARRERA:
		SistemaGuardado.set_texto(UsoObjetosCampo.TEXTO_REGISTRADO, OBJETO_BICI_ACROBATICA)
	elif registrado == OBJETO_BICI_ACROBATICA:
		SistemaGuardado.set_texto(UsoObjetosCampo.TEXTO_REGISTRADO, OBJETO_BICI_CARRERA)


## Valores actuales de todo lo persistente (depuración y tests).
static func instantanea() -> Dictionary:
	var datos := {}
	for clave: String in PERSISTENTE:
		datos[clave] = SistemaGuardado.get_flag(clave) if PERSISTENTE[clave][0] == "bandera" \
			else SistemaGuardado.get_contador(clave)
	return datos


## Restaura una instantánea (o, vacía, la partida antes de pisar MALVALONA).
static func restablecer(datos: Dictionary = {}) -> void:
	for clave: String in PERSISTENTE:
		if PERSISTENTE[clave][0] == "bandera":
			SistemaGuardado.set_flag(clave, bool(datos.get(clave, false)))
		else:
			SistemaGuardado.set_contador(clave, int(datos.get(clave, 0)))


## Reinicia solo las entregas y decisiones de los interiores (no las banderas de
## ERICO del exterior, ni el MONEDERO ni las fichas).
static func reiniciar_regalos() -> void:
	for clave in [BANDERA_MO06, BANDERA_MONEDERO, BANDERA_BICI_RECIBIDA, BANDERA_BICI_RECHAZADA,
			BANDERA_MUNECO_INICIAL, BANDERA_20_FICHAS, BANDERA_MT34]:
		SistemaGuardado.set_flag(clave, false)
