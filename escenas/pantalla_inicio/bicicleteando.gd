extends Node2D
## Paralaje horizontal + bandeo vertical de la escena del ciclista.
## Especificación visual: escenas/pantalla_inicio/notas_escena_bicicleteando.md
##
## Cada capa (montañas, filas de árboles, campo) contiene un sprite plantilla de
## 128px de ancho. Los sprites derivan hacia la derecha; al hacerlo se clonan a la
## izquierda para mantener la cobertura de los 240px de pantalla y se eliminan al
## salir por la derecha. Cada capa avanza a su propia velocidad para simular
## profundidad (paralaje). El nodo DesplazoY banda verticalmente todo su conjunto.
##
## Además selecciona aleatoriamente (sembrado con timestamp) uno de los dos
## ciclistas (Aura o Bruno) y aplica un efecto de saltitos verticales de 1px sobre
## el Personaje para simular pequeños desniveles del terreno.

const ANCHO_SPRITE := 128
const ANCHO_PANTALLA := 240
const FPS_REFERENCIA := 60.0

# Bandedo vertical sinusoidal de DesplazoY (ida y vuelta).
const AMPLITUD_BOB := 36.0
const FRAMES_IDA_BOB := 140.0

# Saltitos de terreno sobre Personaje (desniveles en píxeles).
const SALTO_TERRENO_PX := 1

# Velocidad de cada capa expresada en "frames a 60fps para recorrer 128px".
# A mayor valor, más lento (mayor sensación de profundidad).
@export_group("Velocidades (frames por 128px a 60fps)")
@export var frames_montanas := 8192.0
@export var frames_arboles_f4 := 1536.0
@export var frames_arboles_f3 := 1024.0
@export var frames_arboles_f2 := 768.0
@export var frames_arboles_f1 := 512.0
@export var frames_campo := 32.0

# 1.0 = deriva hacia la derecha (según las notas). -1.0 invierte el sentido.
@export var direccion: float = 1.0

@export_group("Ciclista")
## Sembrar la selección aleatoria con el timestamp para que cambie en cada arranque.
@export var sembrar_con_timestamp: bool = true
## Tiempo de espera, en segundos, desde el final de un saltito hasta el siguiente.
@export var segundos_entre_saltitos_min: float = 0.33
@export var segundos_entre_saltitos_max: float = 1
## Duración, en segundos, de cada saltito. Se sortea un valor uniforme entre
## estos dos extremos para que no todos duren exactamente lo mismo.
@export var segundos_duracion_saltito_min: float = 0.10
@export var segundos_duracion_saltito_max: float = 0.30

@onready var _desplazo_y: Node2D = $DesplazoY
@onready var _personaje: Node2D = $Personaje
@onready var _aura: AnimatedSprite2D = $Personaje/Aura
@onready var _bruno: AnimatedSprite2D = $Personaje/Bruno

var _capas: Array = []  # Array de instancias de la clase interna Capa.
var _base_y_desplazo: float = 0.0
var _acumulado_bob: float = 0.0
var _segundos_hasta_proximo_salto: float = 0.0
var _segundos_salto_restantes: float = 0.0
var _salto_activo: bool = false
var _base_y_personaje: float = 0.0
var _ciclista_activo: AnimatedSprite2D = null


class Capa:
	var contenedor: Node2D
	var plantilla: Sprite2D
	var base_y: float
	var px_por_segundo: float
	var desplazamiento: float = 0.0
	var activos: Dictionary = {}  # int (índice de tile k) -> Sprite2D


func _ready() -> void:
	_base_y_desplazo = _desplazo_y.position.y
	_base_y_personaje = _personaje.position.y
	if sembrar_con_timestamp:
		# Time.get_ticks_usec() cambia en cada arranque -> siempre otra selección.
		seed(Time.get_ticks_usec())
	_seleccionar_ciclista_aleatorio()
	# Sembramos el primer intervalo para que no salte de inmediato.
	_segundos_hasta_proximo_salto = _sortear_segundos(
		segundos_entre_saltitos_min, segundos_entre_saltitos_max
	)
	_construir_capa($Montanas, $Montanas/Montanas1, frames_montanas)
	_construir_capa($DesplazoY/ArbolesF4, $DesplazoY/ArbolesF4/Arboles4, frames_arboles_f4)
	_construir_capa($DesplazoY/ArbolesF3, $DesplazoY/ArbolesF3/Arboles3, frames_arboles_f3)
	_construir_capa($DesplazoY/ArbolesF2, $DesplazoY/ArbolesF2/Arboles2, frames_arboles_f2)
	_construir_capa($DesplazoY/ArbolesF1, $DesplazoY/ArbolesF1/Arboles1, frames_arboles_f1)
	_construir_capa($DesplazoY/Campo, $DesplazoY/Campo/Campo1, frames_campo)
	for capa: Capa in _capas:
		# La plantilla solo sirve como origen de los duplicados: se oculta.
		capa.plantilla.visible = false
		_reconciliar_capa(capa)


func _seleccionar_ciclista_aleatorio() -> void:
	# randi() % 2 elige 0 (Aura) o 1 (Bruno). Uno visible + pedaleando,
	# el otro invisible (su bici va como hijo y se oculta junto con él).
	fijar_ciclista(randi() % 2 == 0)


## Fuerza el ciclista visible (los créditos muestran al jugador real).
func fijar_ciclista(usar_aura: bool) -> void:
	_ciclista_activo = _aura if usar_aura else _bruno
	var inactivo: AnimatedSprite2D = _bruno if usar_aura else _aura
	_ciclista_activo.visible = true
	inactivo.visible = false
	# Aseguramos que el elegido esté pedaleando desde el frame 0.
	_ciclista_activo.animation = &"pedaleando"
	_ciclista_activo.frame = 0
	_ciclista_activo.frame_progress = 0.0
	_ciclista_activo.play(&"pedaleando")


func _construir_capa(contenedor: Node2D, plantilla: Sprite2D, frames_por_128: float) -> void:
	var capa := Capa.new()
	capa.contenedor = contenedor
	capa.plantilla = plantilla
	capa.base_y = plantilla.position.y
	capa.px_por_segundo = (ANCHO_SPRITE / frames_por_128) * FPS_REFERENCIA * direccion
	capa.desplazamiento = 0.0
	capa.activos.clear()
	_capas.append(capa)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	for capa: Capa in _capas:
		capa.desplazamiento += capa.px_por_segundo * delta
		_reconciliar_capa(capa)
	_actualizar_bob(delta)
	_actualizar_saltitos(delta)


func _reconciliar_capa(capa: Capa) -> void:
	# screen_x del tile k = k * ANCHO_SPRITE + desplazamiento.
	# Mantenemos visibles los tiles que cubren [-ANCHO_SPRITE, ANCHO_PANTALLA].
	var desp: float = capa.desplazamiento
	var k_min: int = floori((-ANCHO_SPRITE - desp) / ANCHO_SPRITE)
	var k_max: int = floori((ANCHO_PANTALLA - desp) / ANCHO_SPRITE)

	# Eliminar los que ya salieron de rango.
	var claves: Array = capa.activos.keys()
	for clave in claves:
		var k: int = int(clave)
		if k < k_min or k > k_max:
			(capa.activos[k] as Sprite2D).queue_free()
			capa.activos.erase(k)

	# Clonar a la izquierda lo que falte y reposicionar lo existente.
	for k: int in range(k_min, k_max + 1):
		if capa.activos.has(k):
			(capa.activos[k] as Sprite2D).position.x = k * ANCHO_SPRITE + desp
		else:
			var sprite: Sprite2D = capa.plantilla.duplicate()
			sprite.position = Vector2(k * ANCHO_SPRITE + desp, capa.base_y)
			sprite.visible = true
			capa.contenedor.add_child(sprite)
			capa.activos[k] = sprite


func _actualizar_bob(delta: float) -> void:
	# Ciclo completo = 2 * 140 frames. Coseno suavizado: 0 -> +36 -> 0.
	_acumulado_bob += delta
	var ciclo: float = (FRAMES_IDA_BOB * 2.0) / FPS_REFERENCIA
	var t: float = fmod(_acumulado_bob, ciclo)
	var y: float = _base_y_desplazo + AMPLITUD_BOB * (0.5 - 0.5 * cos(TAU * t / ciclo))
	_desplazo_y.position.y = y


func _actualizar_saltitos(delta: float) -> void:
	# La espera y la duración se descuentan en segundos, independientes del FPS.
	if _ciclista_activo == null:
		return
	if _salto_activo:
		_segundos_salto_restantes -= delta
		if _segundos_salto_restantes > 0.0:
			return
		# Terminó el saltito: volver a la base y empezar una nueva espera.
		_salto_activo = false
		_personaje.position.y = _base_y_personaje
		_segundos_hasta_proximo_salto = _sortear_segundos(
			segundos_entre_saltitos_min, segundos_entre_saltitos_max
		)
		return

	_segundos_hasta_proximo_salto -= delta
	if _segundos_hasta_proximo_salto > 0.0:
		# Aún no toca salto: mantener la posición base.
		_personaje.position.y = _base_y_personaje
		return

	# Comienza un saltito con duración y dirección aleatorias.
	var signo: int = 1 if randf() < 0.5 else -1
	_personaje.position.y = _base_y_personaje + float(signo * SALTO_TERRENO_PX)
	_salto_activo = true
	_segundos_salto_restantes = _sortear_segundos(
		segundos_duracion_saltito_min, segundos_duracion_saltito_max
	)


func _sortear_segundos(valor_min: float, valor_max: float) -> float:
	# Ordenamos los extremos para tolerar valores invertidos en el inspector.
	return randf_range(minf(valor_min, valor_max), maxf(valor_min, valor_max))
