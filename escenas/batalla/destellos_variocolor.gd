extends Node2D
## Destellos de un Pokémon variocolor (TryShinyAnimation, battle_anim_special.c). No es un script de
## gBattleAnims_General: dos tareas esperan 60 fotogramas y crean 5 estrellas cada una, una cada 4 fotogramas.
## La tarea 0 las hace orbitar (sub_8141B20) y la 1 cruzar en diagonal (sub_8141B74) y hace sonar SE_SHINY con
## su primera estrella. El combate sigue cuando acaba la tarea 1 (finishedShinyMonAnim), aunque aún quede
## alguna estrella de la órbita en pantalla.

## finishedShinyMonAnim: los controladores de batalla ya pueden continuar.
signal terminado

const SEGUNDOS_POR_FOTOGRAMA: float = 1.0 / 60.0
const ESPERA_INICIAL: int = 60
const INTERVALO_ESTRELLAS: int = 4
const ESTRELLAS_POR_TAREA: int = 5
const RADIO_ORBITA: float = 24.0
const PASO_ORBITA: int = 12
const FASES_ORBITA: int = 256
const RETARDO_DIAGONAL: int = 4
const INICIO_DIAGONAL: Vector2 = Vector2(-32, 32)
const PASO_DIAGONAL: int = 5
const ULTIMA_POSICION_DIAGONAL: int = 32

@onready var _estrella_grande: Sprite2D = $EstrellaGrande
@onready var _estrella_pequena: Sprite2D = $EstrellaPequena
@onready var sonido: AudioStreamPlayer2D = $Sonido

var finalizados: bool = false
var _fotograma: int = 0
var _creadas: int = 0
var _acumulado: float = 0.0
var _orbitas: Array[Dictionary] = []
var _diagonales: Array[Dictionary] = []


## `centro` son las coordenadas 0/1 del battler (GetBattlerSpriteCoord) en el espacio del padre. El sonido
## se panea como PlaySE12WithPanning: a la izquierda en el jugador y a la derecha en el rival.
func iniciar(centro: Vector2, es_jugador: bool, tamano_campo: Vector2) -> void:
	sonido.position = Vector2(tamano_campo.x * (0.0 if es_jugador else 1.0), tamano_campo.y * 0.5) - centro
	position = centro


func _process(delta: float) -> void:
	_acumulado += delta
	while _acumulado >= SEGUNDOS_POR_FOTOGRAMA:
		_acumulado -= SEGUNDOS_POR_FOTOGRAMA
		avanzar_fotograma()
	if finalizados and _orbitas.is_empty() and _diagonales.is_empty() and not sonido.playing:
		queue_free()


## Un fotograma de la GBA: primero las tareas y luego los callbacks de los sprites.
func avanzar_fotograma() -> void:
	if not finalizados and _creadas == ESTRELLAS_POR_TAREA and _diagonales.is_empty():
		finalizados = true
		terminado.emit()
	if _creadas < ESTRELLAS_POR_TAREA and _fotograma >= ESPERA_INICIAL \
			and (_fotograma - ESPERA_INICIAL) % INTERVALO_ESTRELLAS == 0:
		_crear_estrellas()
	_avanzar_orbitas()
	_avanzar_diagonales()
	_fotograma += 1


func _crear_estrellas() -> void:
	_orbitas.append({"sprite": _nueva_estrella(_creadas), "fase": 0})
	var diagonal: Sprite2D = _nueva_estrella(_creadas)
	diagonal.position = INICIO_DIAGONAL
	diagonal.visible = false
	_diagonales.append({"sprite": diagonal, "espera": 0})
	if _creadas == 0:
		sonido.play()
	_creadas += 1


## La primera estrella es la de 16x16; las tres siguientes, el tile 4 y la última, el tile 5.
func _nueva_estrella(indice: int) -> Sprite2D:
	var estrella: Sprite2D = (_estrella_grande if indice == 0 else _estrella_pequena).duplicate() as Sprite2D
	estrella.visible = true
	if indice == ESTRELLAS_POR_TAREA - 1:
		estrella.frame = 1
	add_child(estrella)
	return estrella


func _avanzar_orbitas() -> void:
	for orbita: Dictionary in _orbitas.duplicate():
		var fase: int = orbita.fase
		var angulo: float = TAU * fase / FASES_ORBITA
		(orbita.sprite as Sprite2D).position = Vector2(floorf(sin(angulo) * RADIO_ORBITA), floorf(cos(angulo) * RADIO_ORBITA))
		orbita.fase = fase + PASO_ORBITA
		if orbita.fase >= FASES_ORBITA:
			(orbita.sprite as Sprite2D).queue_free()
			_orbitas.erase(orbita)


func _avanzar_diagonales() -> void:
	for diagonal: Dictionary in _diagonales.duplicate():
		if diagonal.espera < RETARDO_DIAGONAL:
			diagonal.espera += 1
			continue
		var sprite: Sprite2D = diagonal.sprite
		sprite.visible = true
		sprite.position += Vector2(PASO_DIAGONAL, -PASO_DIAGONAL)
		if sprite.position.x > ULTIMA_POSICION_DIAGONAL:
			sprite.queue_free()
			_diagonales.erase(diagonal)
