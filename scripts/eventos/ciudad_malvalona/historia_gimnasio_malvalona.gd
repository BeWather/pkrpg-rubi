## historia_gimnasio_malvalona.gd
## Estado del puzle de los interruptores del GIMNASIO de CIUDAD MALVALONA (pokeruby
## VAR_MAUVILLE_GYM_STATE y FLAG_MAUVILLE_GYM_BARRIERS_STATE, data/maps/MauvilleCity_Gym).
##
## Como en Rubí, el estado se guarda con la partida (ni la var 0x4093 ni la bandera 0x63
## son temporales): guardar dentro del GIMNASIO y cargar conserva las barreras. El puzle
## vuelve al estado A con los tres interruptores levantados solo al entrar al GIMNASIO
## desde otro mapa (en Rubí lo hace MauvilleCity_OnTransition, y la ciudad es el único
## acceso): EventoGimnasioMalvalona llama a `entrar()` al llegar por warp.
## Se mantiene aquí, sin nodos, para que los tests y el cartel de depuración lo
## manipulen sin escena.
##
## - `interruptor()`: 0 = ninguno pisado, 1..3 = el último pisado (VAR_MAUVILLE_GYM_STATE).
## - `barreras()`: false = estado A (el de map.bin), true = estado B (barreras alternas).
## - Vencido ERICO (medalla DINAMO, FLAG_DEFEATED_MAUVILLE_GYM) el puzle está
##   desactivado: estado D, derivado de la medalla y no de este contador.
class_name HistoriaGimnasioMalvalona
extends RefCounted

## FLAG_BADGE03_GET (MEDALLA DINAMO); también hace de FLAG_DEFEATED_MAUVILLE_GYM.
const INDICE_MEDALLA: int = 2
const INTERRUPTORES: int = 3
## VAR_MAUVILLE_GYM_STATE (contador) y FLAG_MAUVILLE_GYM_BARRIERS_STATE (bandera).
const CONTADOR_INTERRUPTOR: String = "malvalona_gimnasio_interruptor"
const BANDERA_BARRERAS: String = "malvalona_gimnasio_barreras"

## Estado que pide el cartel de depuración para la próxima entrada al GIMNASIO
## (barreras, interruptor); [] = ninguno. Se consume en `entrar()`.
static var _forzado: Array = []


static func interruptor() -> int:
	return clampi(SistemaGuardado.get_contador(CONTADOR_INTERRUPTOR), 0, INTERRUPTORES)


static func barreras() -> bool:
	return SistemaGuardado.get_flag(BANDERA_BARRERAS)


## FLAG_DEFEATED_MAUVILLE_GYM.
static func desactivado() -> bool:
	return SistemaGuardado.tiene_medalla(INDICE_MEDALLA)


## Switch1/2/3 (n = 1..3): pisar un interruptor distinto del último alterna las
## barreras. Devuelve false (sin cambios) si el puzle está desactivado o es el mismo
## interruptor que el último.
static func pisar(n: int) -> bool:
	if n < 1 or n > INTERRUPTORES or desactivado() or interruptor() == n:
		return false
	establecer(not barreras(), n)
	return true


## Estado inicial: A con los tres interruptores levantados.
static func reiniciar() -> void:
	establecer(false, 0)


## Escribe el estado de una vez (depuración y tests).
static func establecer(barreras_activas: bool, interruptor_pisado: int) -> void:
	SistemaGuardado.set_flag(BANDERA_BARRERAS, barreras_activas)
	SistemaGuardado.set_contador(CONTADOR_INTERRUPTOR, clampi(interruptor_pisado, 0, INTERRUPTORES))


## Pide un estado para la próxima entrada al GIMNASIO (cartel de depuración).
static func forzar(barreras_activas: bool, interruptor_pisado: int) -> void:
	_forzado = [barreras_activas, clampi(interruptor_pisado, 0, INTERRUPTORES)]


## Estado con el que empezará la próxima entrada al GIMNASIO: [barreras, interruptor].
static func pendiente() -> Array:
	return _forzado.duplicate() if not _forzado.is_empty() else [false, 0]


static func hay_forzado() -> bool:
	return not _forzado.is_empty()


static func descartar_forzado() -> void:
	_forzado = []


## Al entrar al GIMNASIO desde otro mapa (MauvilleCity_OnTransition): el estado pedido
## por la depuración o el inicial. Cargar la partida dentro NO pasa por aquí.
static func entrar() -> void:
	if _forzado.is_empty():
		reiniciar()
		return
	establecer(bool(_forzado[0]), int(_forzado[1]))
	_forzado = []


## ERICO está en su GIMNASIO salvo desde que se vence a NORMAN hasta que da la MT24 en
## la ciudad (FLAG_HIDE_WATTSON_MAUVILLE_GYM).
static func erico_en_gimnasio() -> bool:
	return not (SistemaGuardado.get_flag(HistoriaMalvalona.BANDERA_ERICO_FUERA) \
			and not SistemaGuardado.get_flag(HistoriaMalvalona.BANDERA_MT_RAYO))
