class_name SueloForzado
extends RefCounted

## Movimiento forzado por el suelo (TryDoMetatileBehaviorForcedMovement de
## pokeruby, src/field_player_avatar.c). Solo decide QUÉ hace la celda; quien
## mueve al personaje es character.gd (`_procesar_suelo_forzado`, al terminar
## cada paso) y NpcBase si algún día lo necesita.
##
## Banderas de TPTileDataMap -> comportamiento de metatile de Rubí:
##   RESBALADIZO                    MB_ICE / MB_TRICK_HOUSE_PUZZLE_8_FLOOR
##                                  (ForcedMovement_Slip: sigue en la dirección en
##                                  que miraba, a PlayerGoSpeed2, sin animación)
##   EMPUJE_<dir>                   MB_WALK_<dir> (PlayerGoSpeed1: camina hacia
##                                  <dir>, girando al personaje y animándolo)
##   EMPUJE_<dir> + EMPUJE_DESLIZANTE
##                                  MB_SLIDE_<dir> (PlayerGoSpeed2 con la mirada
##                                  bloqueada y sin animación de paso)
## Si una celda llevara varias, el orden de prueba de Rubí: resbaladizo, sur,
## norte, oeste, este.

enum Modo {
	NINGUNO,
	RESBALA,  ## ForcedMovement_Slip
	CAMINA,   ## ForcedMovement_Walk*
	DESLIZA,  ## ForcedMovement_Slide*
}

const MASCARA_EMPUJE: int = TPTileDataMap.Flags.EMPUJE_ARRIBA | TPTileDataMap.Flags.EMPUJE_ABAJO \
		| TPTileDataMap.Flags.EMPUJE_IZQUIERDA | TPTileDataMap.Flags.EMPUJE_DERECHA
const MASCARA: int = MASCARA_EMPUJE | TPTileDataMap.Flags.RESBALADIZO


## Comportamiento de unas banderas de celda.
static func modo(flags: int) -> Modo:
	if flags & TPTileDataMap.Flags.RESBALADIZO:
		return Modo.RESBALA
	if flags & MASCARA_EMPUJE:
		return Modo.DESLIZA if flags & TPTileDataMap.Flags.EMPUJE_DESLIZANTE else Modo.CAMINA
	return Modo.NINGUNO


## Dirección en la que empuja la celda: la de la cinta, o `mirada` en el
## suelo resbaladizo. Vector2.ZERO si no empuja.
static func direccion(flags: int, mirada: Vector2) -> Vector2:
	if flags & TPTileDataMap.Flags.RESBALADIZO:
		return mirada
	if flags & TPTileDataMap.Flags.EMPUJE_ABAJO:
		return Vector2.DOWN
	if flags & TPTileDataMap.Flags.EMPUJE_ARRIBA:
		return Vector2.UP
	if flags & TPTileDataMap.Flags.EMPUJE_IZQUIERDA:
		return Vector2.LEFT
	if flags & TPTileDataMap.Flags.EMPUJE_DERECHA:
		return Vector2.RIGHT
	return Vector2.ZERO


## Máscara de EMPUJE_* de una dirección (0 si no es cardinal).
static func empuje_de(direccion_cinta: Vector2) -> int:
	match direccion_cinta:
		Vector2.UP:
			return TPTileDataMap.Flags.EMPUJE_ARRIBA
		Vector2.DOWN:
			return TPTileDataMap.Flags.EMPUJE_ABAJO
		Vector2.LEFT:
			return TPTileDataMap.Flags.EMPUJE_IZQUIERDA
		Vector2.RIGHT:
			return TPTileDataMap.Flags.EMPUJE_DERECHA
	return 0


## Pone en `celda` el movimiento forzado de una cinta y quita el que hubiera
## (los interruptores de la prueba 7 cambian la flecha y sus banderas a la vez).
## `direccion_cinta` ZERO deja la celda sin movimiento forzado.
static func fijar_cinta(datos: TPTileDataMap, celda: Vector2i, direccion_cinta: Vector2, deslizante: bool) -> void:
	if datos == null:
		return
	datos.clear_flag(Vector2(celda), MASCARA | TPTileDataMap.Flags.EMPUJE_DESLIZANTE)
	var mascara := empuje_de(direccion_cinta)
	if mascara == 0:
		return
	if deslizante:
		mascara |= TPTileDataMap.Flags.EMPUJE_DESLIZANTE
	datos.set_flag(Vector2(celda), mascara)
