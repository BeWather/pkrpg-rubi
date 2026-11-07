extends RefCounted
class_name SuperficiesDecoracion

## Comportamientos originales separados de la colisión y de la ocupación por sprites.
## Clasificar una celda no valida por sí solo una colocación (Validador, fase 5).
enum Tipo { OTRO, SUELO_NORMAL, PARED_NORTE, HUECO, ALFOMBRA_BORDE, ALFOMBRA_CENTRO, BLOQUE_DECORACION }
const MB_NORMAL: int = 0x00
const MB_BLOCK_DECORATION: int = 0xB3
const MB_LARGE_MAT_EDGE: int = 0xB5
const MB_NORTH_WALL: int = 0xB7
const MB_IMPASSABLE: int = 0xB9
const MB_HOLE: int = 0xC2
const MB_LARGE_MAT_CENTER: int = 0xC3


static func tipo(comportamiento: int) -> Tipo:
	match comportamiento:
		MB_NORMAL: return Tipo.SUELO_NORMAL
		MB_NORTH_WALL: return Tipo.PARED_NORTE
		MB_HOLE: return Tipo.HUECO
		MB_LARGE_MAT_EDGE: return Tipo.ALFOMBRA_BORDE
		MB_LARGE_MAT_CENTER: return Tipo.ALFOMBRA_CENTRO
		MB_BLOCK_DECORATION: return Tipo.BLOQUE_DECORACION
	return Tipo.OTRO
