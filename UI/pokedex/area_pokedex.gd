extends "res://UI/pokedex/subpantalla_pokedex.gd"
## Pantalla ÁREA de la POKéDEX: mapa de HOENN con las secciones donde vive la
## especie. Basado en pokeruby/src/pokedex_area_screen.c (DrawAreaGlow,
## BuildAreaGlowTilemap, DoAreaGlow, CreateAreaMarkerSprites).
##
## Pueblos y rutas brillan en rojo con un pulso de 64 cuadros; cuevas y la
## ZONA SAFARI parpadean con un marcador. Si hay de los dos, se alternan. Sin
## ninguno se muestra DESCONOCIDA. B vuelve a la ficha (SE_PC_OFF) y
## derecha pasa a GRITO (SE_DEX_PAGE).

const AREAS = preload("res://UI/pokedex/areas_pokedex.gd")
const TABLAS = preload("res://UI/pokedex/tablas_pokedex.gd")
const BRILLO: Texture2D = preload("res://UI/pokedex/graficos/area/area-glow.png")
const MARCADOR: Texture2D = preload("res://UI/pokedex/graficos/area/area-marker.png")
const MENU_BOX_MANAGER = preload("res://scripts/clases/MenuBoxManager.gd")
const CUADRO: float = 1.0 / 60.0
## Casillas de fondo del GBA (32×20) en las que se arma el brillo.
const ANCHO_FONDO: int = 32
const ALTO_FONDO: int = 20
const RELLENO: int = 0xFFFF
## DoAreaGlow: 64 cuadros de pulso; marcadores: 4 medios ciclos de 13.
const CUADROS_PULSO: int = 64
const CUADROS_PARPADEO: int = 13

enum Fase { BRILLO, MARCADORES }

@onready var _mapa: Control = $Mapa
@onready var _brillo: Node2D = $Brillo
@onready var _marcadores: Node2D = $Marcadores
@onready var _desconocida: NinePatchRect = $Desconocida

var area: Dictionary = {"brillo": [], "marcadores": []}
## Índice de casilla de area-glow.png para cada casilla de fondo (-1 = nada).
var casillas_brillo: PackedInt32Array = []
var fase: int = Fase.BRILLO
## Sección donde vaga LATIOS; la ficha la toma de PokedexPartida.
var seccion_errante: String = ""
var _acumulado: float = 0.0
var _contador: int = 0
var _seno_bajo: int = 0
var _seno_alto: int = 0x40
var _ciclo: int = 1


func _preparar() -> void:
	_mapa.configurar_como_pokedex()
	_aplicar_marco()
	var especie := str(entrada.get("nombre_interno", entrada.get("nombre", ""))).to_upper()
	area = AREAS.calcular(especie, seccion_errante)
	casillas_brillo = construir_brillo(area["brillo"])
	_brillo.draw.connect(_dibujar_brillo)
	_brillo.queue_redraw()
	_crear_marcadores()
	_desconocida.visible = AREAS.esta_vacia(area)
	fase = Fase.BRILLO if not area["brillo"].is_empty() else Fase.MARCADORES
	_aplicar_mezcla()


## Marco elegido en las opciones de la partida (menu_box_N).
func _aplicar_marco() -> void:
	var tipo := 1
	if SistemaGuardado.datos_vivos and SistemaGuardado.datos_vivos.opciones:
		tipo = int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	MENU_BOX_MANAGER.apply_texture_to_ninepatch(_desconocida, tipo)


## BuildAreaGlowTilemap: las casillas de las secciones se rellenan y sus
## vecinas reciben bordes y esquinas según hacia dónde queda el relleno.
## La casilla (x, y) de la cuadrícula 28×15 es la (x + 1, y + 2) del fondo.
static func construir_brillo(secciones: Array) -> PackedInt32Array:
	var mapa := PackedInt32Array()
	mapa.resize(ANCHO_FONDO * ALTO_FONDO)
	mapa.fill(0)
	for seccion in secciones:
		for casilla in AREAS.casillas_de(seccion):
			mapa[(casilla.y + 2) * ANCHO_FONDO + casilla.x + 1] = RELLENO
	for y in ALTO_FONDO:
		for x in ANCHO_FONDO:
			if mapa[y * ANCHO_FONDO + x] != RELLENO:
				continue
			_marcar(mapa, x - 1, y, 0x02)
			_marcar(mapa, x + 1, y, 0x01)
			_marcar(mapa, x, y - 1, 0x08)
			_marcar(mapa, x, y + 1, 0x04)
			_marcar(mapa, x - 1, y - 1, 0x10)
			_marcar(mapa, x + 1, y - 1, 0x40)
			_marcar(mapa, x - 1, y + 1, 0x20)
			_marcar(mapa, x + 1, y + 1, 0x80)
	var casillas := PackedInt32Array()
	casillas.resize(mapa.size())
	for i in mapa.size():
		casillas[i] = _casilla_brillo(mapa[i])
	return casillas


static func _marcar(mapa: PackedInt32Array, x: int, y: int, bandera: int) -> void:
	if x < 0 or x >= ANCHO_FONDO or y < 0 or y >= ALTO_FONDO:
		return
	var i := y * ANCHO_FONDO + x
	if mapa[i] != RELLENO:
		mapa[i] |= bandera


## Paso final de BuildAreaGlowTilemap: las esquinas tapadas por un borde se
## descartan y la combinación elige la casilla de area-glow.png.
static func _casilla_brillo(valor: int) -> int:
	if valor == RELLENO:
		return 0x10
	if valor == 0:
		return -1
	if valor & 0x02:
		valor &= 0xFFCF
	if valor & 0x01:
		valor &= 0xFF3F
	if valor & 0x08:
		valor &= 0xFFAF
	if valor & 0x04:
		valor &= 0xFF5F
	var bordes := valor & 0x0F
	var esquinas := valor & 0xF0
	if esquinas == 0:
		return bordes
	match bordes:
		0:
			return (esquinas >> 4) + 0x10
		2:
			return bordes + (esquinas >> 4) + 0x1E
		1:
			return bordes + (esquinas >> 6) + 0x20
		8:
			return bordes + 0x20 + (1 if esquinas & 0x80 else 0) + (2 if esquinas & 0x20 else 0)
		4:
			return bordes + 0x21 + (1 if esquinas & 0x40 else 0) + (2 if esquinas & 0x10 else 0)
		5, 6:
			return bordes + 0x27
		9, 10:
			return bordes + 0x25
	return bordes


## BG0 con VOFS = -8: la casilla de fondo (x, y) se ve en (8·x, 8·y + 8).
func _dibujar_brillo() -> void:
	for i in casillas_brillo.size():
		var casilla := casillas_brillo[i]
		if casilla < 0:
			continue
		var destino := Rect2((i % ANCHO_FONDO) * 8, (i / ANCHO_FONDO) * 8 + 8, 8, 8)
		_brillo.draw_texture_rect_region(BRILLO, destino, Rect2((casilla % 4) * 8, (casilla / 4) * 8, 8, 8))


func _crear_marcadores() -> void:
	for marcador in area["marcadores"]:
		var sprite := Sprite2D.new()
		sprite.name = str(marcador["seccion"])
		sprite.texture = MARCADOR
		sprite.position = marcador["centro"]
		sprite.visible = false
		_marcadores.add_child(sprite)


## DoAreaGlow a 60 cuadros por segundo.
func _process(delta: float) -> void:
	_acumulado += delta
	while _acumulado >= CUADRO:
		_acumulado -= CUADRO
		avanzar_cuadro()


func avanzar_cuadro() -> void:
	if fase == Fase.BRILLO:
		_contador += 1
		if _contador & 1:
			_seno_bajo = (_seno_bajo + 4) & 0x7F
		else:
			_seno_alto = (_seno_alto + 4) & 0x7F
		_aplicar_mezcla()
		if _contador == CUADROS_PULSO:
			_contador = 0
			if not area["marcadores"].is_empty():
				fase = Fase.MARCADORES
		return
	_contador += 1
	if _contador >= CUADROS_PARPADEO:
		_contador = 0
		_ciclo += 1
		if _ciclo > 4:
			_ciclo = 1
			if not area["brillo"].is_empty():
				fase = Fase.BRILLO
	for sprite in _marcadores.get_children():
		sprite.visible = fase == Fase.MARCADORES and not (_ciclo & 1)


## gSineTable (Q8.8) >> 4 da EVA y EVB entre 0 y 16.
func _aplicar_mezcla() -> void:
	var material_brillo := _brillo.material as ShaderMaterial
	material_brillo.set_shader_parameter("eva", (_seno(_seno_bajo) >> 4) / 16.0)
	material_brillo.set_shader_parameter("evb", (_seno(_seno_alto) >> 4) / 16.0)


static func _seno(indice: int) -> int:
	return int(256.0 * sin(indice * TAU / 256.0))


## Task_PokedexAreaScreen_1: no hay izquierda (ÁREA es la primera pestaña).
func _al_pulsar(evento: InputEvent) -> void:
	if evento.is_action_pressed(&"btn_cancelar"):
		salir(Destino.PAGINA, "SE_PC_OFF")
	elif evento.is_action_pressed(&"btn_derecha"):
		salir(Destino.GRITO, "SE_DEX_PAGE")
