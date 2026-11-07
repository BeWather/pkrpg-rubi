## crucero_ss_marea.gd
## Estado del viaje del S.S. MAREA entre CIUDAD PORTUAL y CIUDAD CALAGUA (pokeruby VAR_PORTHOLE_STATE,
## VAR_CRUISE_STEP_COUNT y FLAG_SYS_CRUISE_MODE; data/maps/SSTidalCorridor/scripts.inc y src/field_specials.c).
##
## PORTUAL → CALAGUA: 1 embarque; 2 crucero (al entrar en el pasillo); 3 tras 205 pasos o la ventanilla; la cama en 2 o 3
## pasa a 4 (hemos arribado a CALAGUA).
## CALAGUA → PORTUAL: 5 embarque; 6 al entrar en el pasillo; la cama pasa a 7 (crucero); 8 (hemos arribado a PORTUAL) tras
## 205 pasos, la ventanilla o volver a la cama.
## 9 y 10 los deja la ventanilla al agotar los pasos (desde 2 y 7): el pasillo los resuelve al volver.
class_name CruceroSSMarea
extends RefCounted

const CONTADOR_ESTADO: String = "ss_marea_estado"
const CONTADOR_PASOS: String = "ss_marea_pasos"
const BANDERA_CRUCERO: String = "ss_marea_crucero"
## CountSSTidalStep: el viaje acaba al pasar de 0xCC pasos.
const PASOS_MAXIMOS: int = 0xCC

const EMBARQUE_PORTUAL: int = 1
const EMBARQUE_CALAGUA: int = 5
const LLEGADA_CALAGUA: int = 4
const LLEGADA_PORTUAL: int = 8

const TEXTO_ANUNCIO: String = "SS_MAREA_ANUNCIO"
const TEXTO_VIAJE: String = "SS_MAREA_VIAJE"
const TEXTO_ARRIBO_PORTUAL: String = "SS_MAREA_ARRIBO_PORTUAL"
const TEXTO_ARRIBO_CALAGUA: String = "SS_MAREA_ARRIBO_CALAGUA"

const MAPA_PASILLO: String = "ss_marea_pasillo"
## warp MAP_SS_TIDAL_CORRIDOR, 255, 1, 10.
const CELDA_EMBARQUE: Vector2i = Vector2i(1, 10)
const PUERTO_CALAGUA: String = "ciudad_calagua_puerto"
const PUERTO_PORTUAL: String = "ciudad_portual_puerto"
## warp MAP_*_CITY_HARBOR, 255, 8, 11.
const CELDA_PUERTO: Vector2i = Vector2i(8, 11)
## HEAL_LOCATION_LILYCOVE_CITY / _SLATEPORT_CITY: delante del Centro POKéMON.
const CURACION_CALAGUA: Dictionary = {"mapa_actual": "ciudad_calagua", "cx": 24, "cy": 15, "capa_datos": 0, "nombre_lugar": "CIUDAD_CALAGUA"}
const CURACION_PORTUAL: Dictionary = {"mapa_actual": "ciudad_portual", "cx": 19, "cy": 20, "capa_datos": 0, "nombre_lugar": "CIUDAD_PORTUAL"}


static func estado() -> int:
	return SistemaGuardado.get_contador(CONTADOR_ESTADO)


static func fijar_estado(valor: int) -> void:
	SistemaGuardado.set_contador(CONTADOR_ESTADO, valor)


static func pasos() -> int:
	return SistemaGuardado.get_contador(CONTADOR_PASOS)


## SetSSTidalFlag.
static func iniciar_crucero() -> void:
	SistemaGuardado.set_flag(BANDERA_CRUCERO, true)
	SistemaGuardado.set_contador(CONTADOR_PASOS, 0)


## ResetSSTidalFlag.
static func detener_crucero() -> void:
	SistemaGuardado.set_flag(BANDERA_CRUCERO, false)


## CountSSTidalStep: suma un paso; true si el viaje se ha agotado.
static func contar_paso() -> bool:
	if not SistemaGuardado.get_flag(BANDERA_CRUCERO):
		return false
	var total := pasos() + 1
	SistemaGuardado.set_contador(CONTADOR_PASOS, total)
	return total > PASOS_MAXIMOS


## El embarque de la azafata de cada puerto (setvar VAR_PORTHOLE_STATE antes de BoardFerry).
static func embarcar(destino_calagua: bool) -> void:
	fijar_estado(EMBARQUE_PORTUAL if destino_calagua else EMBARQUE_CALAGUA)


## SSTidalCorridor_MapScript2_15FC9A: anuncio al entrar en el pasillo, o "".
static func aviso_al_entrar() -> String:
	match estado():
		1:
			iniciar_crucero()
			fijar_estado(2)
			return TEXTO_ANUNCIO
		5:
			fijar_estado(6)
			return TEXTO_VIAJE
		9:
			detener_crucero()
			fijar_estado(3)
			return TEXTO_VIAJE
		10:
			detener_crucero()
			fijar_estado(LLEGADA_PORTUAL)
			return TEXTO_ARRIBO_PORTUAL
	return ""


## gUnknown_0815FD0D: anuncio al agotar los pasos caminando por el barco, o "".
static func aviso_por_pasos() -> String:
	match estado():
		2:
			detener_crucero()
			fijar_estado(3)
			return TEXTO_VIAJE
		7:
			detener_crucero()
			fijar_estado(LLEGADA_PORTUAL)
			return TEXTO_ARRIBO_PORTUAL
	return ""


## SSTidalRooms_EventScript_15FD64: anuncio tras descansar en la cama, o "".
static func aviso_tras_cama() -> String:
	match estado():
		2, 3:
			detener_crucero()
			fijar_estado(LLEGADA_CALAGUA)
			return TEXTO_ARRIBO_CALAGUA
		6:
			iniciar_crucero()
			fijar_estado(7)
			return TEXTO_ANUNCIO
		7:
			detener_crucero()
			fijar_estado(LLEGADA_PORTUAL)
			return TEXTO_ARRIBO_PORTUAL
	return ""


## SSTidalCorridor_EventScript_15FE3A: las ventanillas solo muestran el mar en pleno crucero.
static func ventanilla_disponible() -> bool:
	return estado() == 2 or estado() == 7


static func hacia_el_este() -> bool:
	return estado() == 2


## GetSSTidalLocation: [mapa, celda] de la ventanilla según los pasos dados.
static func ubicacion_ventanilla() -> Array:
	var n := pasos()
	var mapa: String
	var x: int
	if hacia_el_este():
		if n < 60:
			mapa = "ruta_134"
			x = n + 19
		elif n < 140:
			mapa = "ruta_133"
			x = n - 60
		else:
			mapa = "ruta_132"
			x = n - 140
	elif n < 66:
		mapa = "ruta_132"
		x = 65 - n
	elif n < 146:
		mapa = "ruta_133"
		x = 145 - n
	else:
		mapa = "ruta_134"
		x = 224 - n
	return [mapa, Vector2i(x, 20)]


## Al agotar los pasos en la ventanilla (Task_HandlePorthole).
static func fin_ventanilla() -> void:
	fijar_estado(9 if hacia_el_este() else 10)
