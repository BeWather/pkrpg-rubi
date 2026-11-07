## estado_club_fan_calagua.gd
## Estado del CLUB FAN de CIUDAD CALAGUA (pokeruby src/field_specials.c, bloque
## «Trainer Fan Club»: ResetFanClub, UpdateTrainerFanClubGameClear, sub_810FB10 (suma de fama),
## sub_810FB9C (nuevo fan), sub_810FC18 (fan que se va), GetNumMovedLilycoveFanClubMembers,
## UpdateMovedLilycoveFanClubMembers y ShouldMoveLilycoveFanClubMember).
##
## Dos variables de Gen 3, guardadas como contadores de SistemaGuardado:
## - VAR_LILYCOVE_FAN_CLUB_STATE → `calagua_club_estado`: 0 = aún no eres CAMPEÓN (solo hablan los
##   cuatro primeros), 1 = hay que ver la escena de los primeros fans, 2 = el club funciona.
## - VAR_FANCLUB_UNKNOWN_1 → `calagua_club_fama`, 16 bits: bits 0-6 = fama acumulada (0-20), bit 7 =
##   «ya registrada la LIGA» y bits 8-15 = una bandera por socio (las variables 8-15 de los guiones:
##   CHICA 8, AFICIONADO 9, NINA 10, NINJA 11, CHICO 12, HOMBRE 13, MUJER 14, ANCIANA 15). Un bit
##   activo significa que el socio es fan del jugador (ShouldMoveLilycoveFanClubMember == 1).
## - VAR_FANCLUB_UNKNOWN_2 → `calagua_club_horas`: horas de juego de la última actualización.
##
## Quién la mueve en Rubí y aquí:
## - UpdateTrainerFanClubGameClear (SALÓN DE LA FAMA): `al_pasar_la_liga()`. La LIGA no existe: el
##   evento del club lo llama la primera vez que se entra con SYS_GAME_CLEAR activa.
## - sub_810FB10: CONCURSOS por cable (2), BASE SECRETA (1), TORRE BATALLA y SALA de DRACÓN: pendientes;
##   `sumar_fama(origen)` está disponible pero nadie lo llama aún.
## - sub_810FEFC (tras un combate por cable): `tras_combate_por_cable(gano)`, sin llamadas.
## - UpdateMovedLilycoveFanClubMembers (OnTransition del club): `actualizar_con_el_tiempo()`.
class_name EstadoClubFanCalagua
extends RefCounted

const CONTADOR_ESTADO: String = "calagua_club_estado"
const CONTADOR_FAMA: String = "calagua_club_fama"
const CONTADOR_HORAS: String = "calagua_club_horas"
const BANDERA_LIGA: String = "SYS_GAME_CLEAR"

const BIT_REGISTRADA: int = 7
const MASCARA_FAMA: int = 0x7F
const PRIMER_BIT_SOCIO: int = 8
const NUM_SOCIOS: int = 8
const FAMA_MAXIMA: int = 20
const SOCIOS_PARA_RELEVO: int = 3
const SOCIOS_PARA_IRSE: int = 5
const HORAS_POR_RELEVO: int = 12

## gUnknown_083F8404: fama que suma cada origen (sub_810FB10).
const FAMA_POR_ORIGEN: Array[int] = [2, 1, 2, 1]
## gUnknown_083F8410: orden en que se prueba qué fan se va (variable de cada socio).
const ORDEN_BAJAS: Array[int] = [8, 13, 14, 11, 10, 12, 15, 9]
## Los tres socios que son fans al registrarse la LIGA (0x2000 | 0x100 | 0x400).
const FANS_INICIALES: Array[int] = [13, 8, 10]

## Sustituye a `Random() & 1` (tests): devuelve 0 o 1.
static var moneda: Callable = Callable()


static func estado() -> int:
	return SistemaGuardado.get_contador(CONTADOR_ESTADO)


static func fijar_estado(valor: int) -> void:
	SistemaGuardado.set_contador(CONTADOR_ESTADO, valor)


static func _fama() -> int:
	return SistemaGuardado.get_contador(CONTADOR_FAMA)


static func _fijar_fama(valor: int) -> void:
	SistemaGuardado.set_contador(CONTADOR_FAMA, valor & 0xFFFF)


static func _moneda() -> int:
	return (int(moneda.call()) if moneda.is_valid() else randi()) & 1


## Horas de juego completas (gSaveBlock2.playTimeHours).
static func horas_de_juego() -> int:
	return int(SistemaGuardado.datos_vivos.tiempo_juego) / 3600


## sub_810FF30: ¿ya se registró el paso por la LIGA?
static func registrada() -> bool:
	return (_fama() >> BIT_REGISTRADA) & 1 == 1


## Fama acumulada (bits 0-6).
static func fama() -> int:
	return _fama() & MASCARA_FAMA


## ShouldMoveLilycoveFanClubMember: ¿es fan del jugador el socio de la variable `variable` (8-15)?
static func es_fan(variable: int) -> bool:
	return (_fama() >> variable) & 1 == 1


## GetNumMovedLilycoveFanClubMembers.
static func cantidad_fans() -> int:
	var total: int = 0
	for i in NUM_SOCIOS:
		if (_fama() >> (i + PRIMER_BIT_SOCIO)) & 1 == 1:
			total += 1
	return total


## UpdateTrainerFanClubGameClear: la primera vez tras la LIGA, tres socios son fans, estado = 1 y se
## guarda la hora. Devuelve true si registró algo.
static func al_pasar_la_liga() -> bool:
	if registrada():
		return false
	var valor: int = _fama() | (1 << BIT_REGISTRADA)
	for variable in FANS_INICIALES:
		valor |= 1 << variable
	_fijar_fama(valor)
	SistemaGuardado.set_contador(CONTADOR_HORAS, horas_de_juego())
	fijar_estado(1)
	return true


## sub_810FB10: suma fama según el origen (0-3) y devuelve la fama resultante. Solo con el club en marcha
## (estado 2). Al llegar a 20: con menos de 3 fans consigue uno nuevo y vuelve a 0; si no, se queda en 20.
static func sumar_fama(origen: int) -> int:
	if estado() == 2:
		var suma: int = (_fama() & MASCARA_FAMA) + FAMA_POR_ORIGEN[clampi(origen, 0, FAMA_POR_ORIGEN.size() - 1)]
		if suma >= FAMA_MAXIMA:
			if cantidad_fans() < SOCIOS_PARA_RELEVO:
				nuevo_fan()
				_fijar_fama(_fama() & 0xFF80)
			else:
				_fijar_fama((_fama() & 0xFF80) | FAMA_MAXIMA)
		else:
			_fijar_fama(_fama() + FAMA_POR_ORIGEN[clampi(origen, 0, FAMA_POR_ORIGEN.size() - 1)])
	return _fama() & MASCARA_FAMA


## sub_810FB9C: un socio que no era fan lo pasa a ser (el último candidato si la moneda no elige antes).
## Devuelve su posición (0-7).
static func nuevo_fan() -> int:
	var resultado: int = 0
	for i in NUM_SOCIOS:
		var variable: int = i + PRIMER_BIT_SOCIO
		if (_fama() >> variable) & 1 == 0:
			resultado = i
			if _moneda() == 1:
				_fijar_fama(_fama() | (1 << variable))
				return resultado
	_fijar_fama(_fama() | (1 << (resultado + PRIMER_BIT_SOCIO)))
	return resultado


## sub_810FC18: un fan deja de serlo (nunca el único que queda). Devuelve su posición en ORDEN_BAJAS.
static func baja_de_fan() -> int:
	if cantidad_fans() == 1:
		return 0
	var resultado: int = 0
	for i in ORDEN_BAJAS.size():
		if (_fama() >> ORDEN_BAJAS[i]) & 1 == 1:
			resultado = i
			if _moneda() == 1:
				_fijar_fama(_fama() ^ (1 << ORDEN_BAJAS[i]))
				return resultado
	if (_fama() >> ORDEN_BAJAS[resultado]) & 1 == 1:
		_fijar_fama(_fama() ^ (1 << ORDEN_BAJAS[resultado]))
	return resultado


## UpdateMovedLilycoveFanClubMembers (OnTransition con el club en marcha): con 5 fans o más, un fan se
## va por cada 12 horas de juego desde la última actualización (hasta 8 veces).
static func actualizar_con_el_tiempo() -> void:
	var horas: int = horas_de_juego()
	if horas >= 999:
		return
	var vueltas: int = 0
	while true:
		if cantidad_fans() < SOCIOS_PARA_IRSE:
			SistemaGuardado.set_contador(CONTADOR_HORAS, horas)
			break
		if vueltas == 8:
			break
		if horas - SistemaGuardado.get_contador(CONTADOR_HORAS) < HORAS_POR_RELEVO:
			return
		baja_de_fan()
		SistemaGuardado.set_contador(CONTADOR_HORAS, SistemaGuardado.get_contador(CONTADOR_HORAS) + HORAS_POR_RELEVO)
		vueltas += 1


## sub_810FEFC (tras un combate por cable con el club en marcha): ganar suma un fan; perder, lo quita.
static func tras_combate_por_cable(gano: bool) -> void:
	if estado() != 2:
		return
	if registrada():
		actualizar_con_el_tiempo()
		SistemaGuardado.set_contador(CONTADOR_HORAS, horas_de_juego())
	if gano:
		nuevo_fan()
	else:
		baja_de_fan()
