class_name RelojJuego
extends RefCounted

## Hora local del juego (`RtcCalcLocalTime` / `gLocalTime` de pokeruby): la hora
## del sistema (el reloj del cartucho) más el desfase que fija el jugador al poner
## el reloj de pared (`gSaveBlock2.localTimeOffset`, RtcInitLocalTimeOffset). Se
## guarda en minutos dentro del día; los días solo se usan para contar semanas (dias_desde_inicio).

## `GetEvolutionTargetSpecies`: de día es de 12:00 a 23:59 y de noche de 0:00
## a 11:59 (EVO_FRIENDSHIP_DAY / EVO_FRIENDSHIP_NIGHT).
const HORA_INICIO_DIA: int = 12

## localTimeOffset en minutos (0..1439), persistente en la partida.
const CONTADOR_DESFASE: String = "reloj_desfase_minutos"
const MINUTOS_DIA: int = 24 * 60

## Marca (día local, en `timestamps`) del inicio de la partida para contar semanas.
const TIMESTAMP_INICIO: String = "reloj_inicio_partida_dia"
const SEGUNDOS_DIA: int = 86400
## GetWeekCount no pasa de 9999.
const MAX_SEMANAS: int = 9999

## Hora forzada para pruebas y depuración (-1 = hora del sistema).
static var hora_forzada: int = -1
## Día local forzado para pruebas (-1 = el del sistema).
static var dia_forzado: int = -1


## Hora local 0-23.
@warning_ignore("integer_division")
static func hora_local() -> int:
	if hora_forzada >= 0:
		return hora_forzada % 24
	return minutos_locales() / 60


## Minuto local 0-59 (con la hora forzada, 0).
static func minuto_local() -> int:
	if hora_forzada >= 0:
		return 0
	return minutos_locales() % 60


## Minutos desde las 0:00 de la hora local.
static func minutos_locales() -> int:
	return posmod(_minutos_sistema() + _desfase(), MINUTOS_DIA)


## RtcInitLocalTimeOffset: a partir de ahora la hora local es `hora`:`minuto`.
static func ajustar(hora: int, minuto: int) -> void:
	var desfase := posmod(hora * 60 + minuto - _minutos_sistema(), MINUTOS_DIA)
	SistemaGuardado.set_contador(CONTADOR_DESFASE, desfase)


static func _desfase() -> int:
	return SistemaGuardado.get_contador(CONTADOR_DESFASE)


static func _minutos_sistema() -> int:
	var ahora := Time.get_datetime_dict_from_system()
	return int(ahora.get("hour", 0)) * 60 + int(ahora.get("minute", 0))


## Día del calendario local (el de gLocalTime.days): días enteros del reloj de pared, con el desfase
## de la hora del juego. Se puede forzar para pruebas con `dia_forzado`.
@warning_ignore("integer_division")
static func dia_local() -> int:
	if dia_forzado >= 0:
		return dia_forzado
	var ahora := Time.get_datetime_dict_from_system()
	var segundos := int(Time.get_unix_time_from_datetime_dict(ahora)) + _desfase() * 60
	return segundos / SEGUNDOS_DIA


## gLocalTime.days: días transcurridos desde que empezó la partida. Rubí cuenta desde que se puso el reloj; aquí
## el inicio es el día en que se consulta por primera vez (las partidas nuevas no guardan su fecha de creación).
static func dias_desde_inicio() -> int:
	var hoy := dia_local()
	if not SistemaGuardado.datos_vivos.datos_persistentes.timestamps.has(TIMESTAMP_INICIO):
		SistemaGuardado.set_timestamp(TIMESTAMP_INICIO, hoy)
	return maxi(hoy - SistemaGuardado.get_timestamp(TIMESTAMP_INICIO), 0)


## GetWeekCount: gLocalTime.days / 7, con tope en 9999.
@warning_ignore("integer_division")
static func semanas_desde_inicio() -> int:
	return mini(dias_desde_inicio() / 7, MAX_SEMANAS)


static func es_de_dia(hora: int = -1) -> bool:
	var h := hora if hora >= 0 else hora_local()
	return h >= HORA_INICIO_DIA and h < 24


static func es_de_noche(hora: int = -1) -> bool:
	var h := hora if hora >= 0 else hora_local()
	return h >= 0 and h < HORA_INICIO_DIA
