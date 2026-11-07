## historia_cueva_cardumen.gd
## Banderas de los ingredientes de la CAMPANA CONCHA (pokeruby FLAG_HIDE_TOOK_SHOAL_SALT_1..4 y
## FLAG_HIDE_TOOK_SHOAL_SHELL_1..4, FLAG_SYS_SHOAL_ITEM y `dotimebasedevents`).
##
## Las cuatro SAL CARDUMEN y las cuatro CONCHAS CARDUMEN de la cueva se recogen una vez; cada día vuelven. En
## Rubí el reloj activa FLAG_SYS_SHOAL_ITEM al cambiar el día y el VIEJO de la entrada (`dotimebasedevents`) borra
## las ocho banderas si está activa. Aquí no hay un reloj que avise del cambio de día: se guarda el día de
## calendario local en que se repuso por última vez (el mismo que npc_regalo_diario) y se repone al hablar con el
## VIEJO si ya es otro.
class_name HistoriaCuevaCardumen
extends RefCounted

const SAL: String = "sal"
const CONCHA: String = "concha"
const CANTIDAD_DE_CADA: int = 4
const OBJETO_SAL: String = "SALCARDUMEN"
const OBJETO_CONCHA: String = "CCARDUMEN"
const OBJETO_CAMPANA: String = "CASCABELCONCHA"
## Día (días desde 1970, hora local) en que se repusieron los ingredientes por última vez.
const CONTADOR_DIA: String = "cueva_cardumen_dia_ingredientes"


## Bandera de «ya cogido» del ingrediente `numero` (1-4) de `tipo` (SAL / CONCHA).
static func bandera_recogido(tipo: String, numero: int) -> String:
	return "cueva_cardumen_%s_%d_recogida" % [tipo, numero]


static func recogido(tipo: String, numero: int) -> bool:
	return SistemaGuardado.get_flag(bandera_recogido(tipo, numero))


static func marcar_recogido(tipo: String, numero: int, valor: bool = true) -> void:
	SistemaGuardado.set_flag(bandera_recogido(tipo, numero), valor)


## `dotimebasedevents` + `call_if_set FLAG_SYS_SHOAL_ITEM`: si es otro día, vuelven los ocho ingredientes.
## Devuelve true si se repusieron.
static func reponer_si_nuevo_dia() -> bool:
	var dia: int = DefinicionClimaCiclo.dia_actual()
	if SistemaGuardado.get_contador(CONTADOR_DIA) == dia:
		return false
	for numero in range(1, CANTIDAD_DE_CADA + 1):
		marcar_recogido(SAL, numero, false)
		marcar_recogido(CONCHA, numero, false)
	SistemaGuardado.set_contador(CONTADOR_DIA, dia)
	return true
