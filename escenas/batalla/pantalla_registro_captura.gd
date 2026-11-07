class_name PantallaRegistroCaptura
extends Node2D
## Pantalla entre la ficha de la POKéDEX y la pregunta del mote tras la
## primera captura de una especie (pokeruby atkF2_displaydexinfo, caso 2):
## fondo de edificio con la paleta de la Torre Batalla y BG3_X = 0x100 (la
## mitad sin plataformas, fija), y el sprite del Pokémon deslizándose al
## centro (sub_8090C28). La caja de texto es la de batalla, que queda encima.
## Se queda en pantalla hasta que se cierra la batalla.

## Destino del deslizamiento: centro (120, 80) de un sprite de 64×64.
const DESTINO: Vector2 = Vector2(88, 48)
## sub_8090C28: 2 px por cuadro en X y 1 px en Y, a 60 cuadros por segundo.
const PASO: Vector2 = Vector2(2, 1)
const DURACION_CUADRO: float = 1.0 / 60.0
## BeginNormalPaletteFade de 16 a 0 (como la ficha de la POKéDEX).
const DURACION_FUNDIDO: float = 0.3

@onready var _fundido: ColorRect = $Fundido
@onready var pokemon: Sprite2D = $Pokemon

var _acumulado: float = 0.0


## Un cuadro de sub_8090C28 desde `posicion` (esquina superior izquierda).
static func paso_hacia_destino(posicion: Vector2) -> Vector2:
	return Vector2(
		move_toward(posicion.x, DESTINO.x, PASO.x),
		move_toward(posicion.y, DESTINO.y, PASO.y)
	)


## Avanza el deslizamiento de `sprite` según el tiempo transcurrido; devuelve
## el resto acumulado. Lo comparten esta pantalla y la ficha de la POKéDEX,
## donde empieza el movimiento.
static func deslizar(sprite: Node2D, acumulado: float) -> float:
	while acumulado >= DURACION_CUADRO and sprite.position != DESTINO:
		sprite.position = paso_hacia_destino(sprite.position)
		acumulado -= DURACION_CUADRO
	return acumulado if sprite.position != DESTINO else 0.0


## Coloca el sprite donde lo dejó la ficha y funde el fondo desde negro; el
## sprite no se funde (máscara 0xFFFC: solo paletas de fondo).
func iniciar(posicion_pokemon: Vector2) -> void:
	pokemon.position = posicion_pokemon
	_fundido.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fundido, "modulate:a", 0.0, DURACION_FUNDIDO)
	await tween.finished


func _process(delta: float) -> void:
	if pokemon.position == DESTINO:
		return
	_acumulado = deslizar(pokemon, _acumulado + delta)
