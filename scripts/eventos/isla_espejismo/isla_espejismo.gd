## isla_espejismo.gd
## Sistema de la ISLA ESPEJISMO (pokeruby src/time_events.c).
##
## - VAR_MIRAGE_RND_H/L: número de 32 bits guardado en dos contadores. Arranca a 0 (InitMirageRnd no se usa en
##   Rubí) y cada día que pasa avanza con el generador lineal de UpdateMirageRnd (rnd = 1103515245 * rnd + 12345,
##   aritmética de 32 bits). Lo llama ProgramacionTV.actualizar_por_dias (UpdatePerDay).
## - IsMirageIslandPresent: la isla se ve si algún POKéMON del equipo (con especie: los huevos cuentan) tiene los 16
##   bits bajos de su personalidad iguales a los 16 altos de VAR_MIRAGE_RND.
## - Depuración (cartel de PUEBLO OROMAR con AdministradorMapa.iniciar_debug): `BANDERA_FORZADA` la muestra siempre
##   y `BANDERA_OCULTA` la esconde siempre, sin tocar el número del día.
##
## La isla del mapa la pinta IslaEspejismoRuta (escenas/mapas/isla-espejismo/isla_espejismo.tscn, en la RUTA 130).
class_name IslaEspejismo
extends RefCounted

## VAR_MIRAGE_RND_H / VAR_MIRAGE_RND_L.
const CONTADOR_RND_ALTO: String = "espejismo_rnd_alto"
const CONTADOR_RND_BAJO: String = "espejismo_rnd_bajo"
## Depuración: isla siempre a la vista. Es la bandera que ya leía el vigía de OROMAR.
const BANDERA_FORZADA: String = "espejismo_isla_presente"
## Depuración: isla siempre oculta (gana a BANDERA_FORZADA).
const BANDERA_OCULTA: String = "espejismo_isla_oculta"
## Grupo de los nodos IslaEspejismoRuta cargados, para refrescarlos al cambiar el estado.
const GRUPO: StringName = &"isla_espejismo"

const MULTIPLICADOR: int = 1103515245
const INCREMENTO: int = 12345
const MASCARA_32: int = 0xFFFFFFFF
const MASCARA_16: int = 0xFFFF


## GetMirageRnd.
static func obtener_rnd() -> int:
	var alto := SistemaGuardado.get_contador(CONTADOR_RND_ALTO) & MASCARA_16
	var bajo := SistemaGuardado.get_contador(CONTADOR_RND_BAJO) & MASCARA_16
	return (alto << 16) | bajo


## SetMirageRnd.
static func fijar_rnd(rnd: int) -> void:
	SistemaGuardado.set_contador(CONTADOR_RND_ALTO, (rnd >> 16) & MASCARA_16)
	SistemaGuardado.set_contador(CONTADOR_RND_BAJO, rnd & MASCARA_16)


## UpdateMirageRnd(days).
static func actualizar_por_dias(dias: int) -> void:
	if dias <= 0:
		return
	var rnd := obtener_rnd()
	for i in dias:
		rnd = (MULTIPLICADOR * rnd + INCREMENTO) & MASCARA_32
	fijar_rnd(rnd)


## Valor (16 bits altos del número del día) que debe tener la personalidad de un POKéMON del equipo.
static func valor_buscado() -> int:
	return (obtener_rnd() >> 16) & MASCARA_16


## IsMirageIslandPresent sin las banderas de depuración.
static func presente_por_equipo(equipo: Array = SistemaGuardado.get_equipo()) -> bool:
	var buscado := valor_buscado()
	for poke in equipo:
		if poke is BasePokemon and not (poke as BasePokemon).nombre_interno.is_empty() \
				and ((poke as BasePokemon).personalidad & MASCARA_16) == buscado:
			return true
	return false


## IsMirageIslandPresent, con las banderas de depuración.
static func esta_presente() -> bool:
	if SistemaGuardado.get_flag(BANDERA_OCULTA):
		return false
	if SistemaGuardado.get_flag(BANDERA_FORZADA):
		return true
	return presente_por_equipo()


## Depuración: cambia el número del día para que la isla aparezca con el primer POKéMON del equipo.
static func igualar_con_primer_pokemon() -> bool:
	for poke in SistemaGuardado.get_equipo():
		if poke is BasePokemon:
			var bajo := obtener_rnd() & MASCARA_16
			fijar_rnd((((poke as BasePokemon).personalidad & MASCARA_16) << 16) | bajo)
			return true
	return false


## Vuelve a pintar las islas cargadas (tras cambiar el estado desde el menú de depuración).
static func refrescar(arbol: SceneTree) -> void:
	if arbol != null:
		arbol.call_group(GRUPO, &"aplicar")
