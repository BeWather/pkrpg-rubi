@tool
extends RefCounted
class_name BattleLayout
## Fuente única de la geometría del campo de batalla (coordenadas lógicas
## 240x160). Antes estas cifras estaban duplicadas entre `batalla.tscn` y
## `batalla.gd::posiciones`; ahora `batalla.gd` referencia estas constantes y el
## Editor de Posiciones de Battlers (`herramientas/editor_posiciones_battlers/`)
## las usa para dibujar la vista previa. `batalla.tscn` sigue conteniendo los
## valores (Godot los necesita en la escena) y `test/batalla/battle_layout_test.gd`
## falla si divergen.
##
## Posición final de un sprite de Pokémon = ancla del slot + offset, donde el
## offset es la posición local del nodo `Pokemon` dentro del slot
## (`BattleSlot.fijar_offset_pokemon`, sin acumulación) y el ancla es
## suelo_final + posición del slot relativa al suelo.

## Posición final (tras la intro) de los sprites de suelo. Ambos miden 128x32.
const SUELO_ARRIBA_FINAL := Vector2(112, 48)
const SUELO_ABAJO_FINAL := Vector2(0, 101)
const TAM_SUELO := Vector2(128, 32)

## Posición de cada slot relativa a su suelo (nodo `Campo/btlSuelo*/Slot*`).
## Las de doble salen de gUnknown_0837F578 (pokeruby, coordenadas de battler
## simple/doble) aplicadas como desplazamiento sobre el slot simple validado:
## rival simple (176,40) -> doble (200,40) y (152,32); jugador simple (72,80)
## -> doble (32,80) y (90,88). En doble también se mueve el slot principal.
const SLOT_RIVAL_REL_SUELO := Vector2(32, -26)
const SLOT_JUGADOR_REL_SUELO := Vector2(32, -53)
const SLOT_RIVAL_DOBLE_REL_SUELO := Vector2(56, -26)
const SLOT_RIVAL2_REL_SUELO := Vector2(8, -34)
const SLOT_JUGADOR_DOBLE_REL_SUELO := Vector2(-8, -53)
const SLOT_JUGADOR2_REL_SUELO := Vector2(50, -45)

## Sprites de Pokémon: 64x64, `centered = false`, escala 1.
const TAM_SPRITE := Vector2(64, 64)

## Native source-nominal projection within the logical canvas, not artwork or
## an exact Ruby coordinate-table/species-visual projection.
const SOURCE_NOMINAL_CANVAS_REFERENCE := TAM_SPRITE * 0.5

## Pantalla de batalla y zona de campo. La caja de diálogo cubre y >= ALTO_CAMPO,
## así que lo que el jugador ve del campo es TAM_CAMPO (240x112). El Editor de
## Posiciones de Battlers dibuja solo esa zona.
const TAM_PANTALLA := Vector2(240, 160)
const ALTO_CAMPO := 112
const TAM_CAMPO := Vector2(240, ALTO_CAMPO)

## Sombra bajo el Pokémon: `Sombra1` (Sprite2D centrado, 32x8) hijo de `BattleSlot`,
## en coordenadas locales del slot. No depende del offset del sprite del Pokémon:
## se dibuja/coloca en ancla del slot + SOMBRA_REL_SLOT. Por especie se activa con la
## clave `sombra` de battle_positions.json (por defecto desactivada).
const SOMBRA_REL_SLOT := Vector2(32, 50)
const RUTA_SOMBRA := "res://graficos/batalla/sombra1.png"


## Ancla final del slot rival principal (esquina superior izquierda del sprite
## con offset (0,0)).
static func ancla_rival() -> Vector2:
	return SUELO_ARRIBA_FINAL + SLOT_RIVAL_REL_SUELO


## Ancla final del slot jugador principal.
static func ancla_jugador() -> Vector2:
	return SUELO_ABAJO_FINAL + SLOT_JUGADOR_REL_SUELO


## Posición relativa al suelo de cada actor según el formato. Orden de actores
## del laboratorio de animaciones: 0 jugador izq., 1 jugador der., 2 rival
## izq., 3 rival der. En simple solo existen 0 y 2.
static func slot_rel_suelo(actor_id: int, doble: bool) -> Vector2:
	match actor_id:
		0: return SLOT_JUGADOR_DOBLE_REL_SUELO if doble else SLOT_JUGADOR_REL_SUELO
		1: return SLOT_JUGADOR2_REL_SUELO
		2: return SLOT_RIVAL_DOBLE_REL_SUELO if doble else SLOT_RIVAL_REL_SUELO
		_: return SLOT_RIVAL2_REL_SUELO


## Ancla final (esquina superior izquierda del sprite) de un actor según el formato.
static func ancla_actor(actor_id: int, doble: bool) -> Vector2:
	var suelo := SUELO_ABAJO_FINAL if actor_id < 2 else SUELO_ARRIBA_FINAL
	return suelo + slot_rel_suelo(actor_id, doble)


## Centro de la sombra del slot rival principal (coordenadas del campo).
static func centro_sombra_rival() -> Vector2:
	return ancla_rival() + SOMBRA_REL_SLOT


## Centro de la sombra del slot jugador principal.
static func centro_sombra_jugador() -> Vector2:
	return ancla_jugador() + SOMBRA_REL_SLOT
