extends Node2D
class_name CintasPokenav

## Pantalla CINTAS del POKéNAV: lista de Pokémon con cintas y rejilla de 9 columnas
## (DrawMonRibbonIcons). Los índices 25+ son cintas de regalo, en su propia fila.

signal cerrado

const COLUMNAS: int = 9
const ORIGEN_REJILLA: Vector2 = Vector2(88, 32)
const ORIGEN_REGALOS: Vector2 = Vector2(88, 80)
const PRIMER_REGALO: int = 25
const TAM_GRANDE: int = 32
const TAM_PEQUENA: int = 16

@onready var lista: ListaPokenav = $Lista
@onready var lb_contador: Label = $Contador
@onready var vista: Node2D = $Vista
@onready var spr_pokemon: PokemonSprite = $Vista/Pokemon
@onready var lb_nombre: Label = $Vista/Nombre
@onready var rejilla: Node2D = $Vista/Rejilla
@onready var zoom: Sprite2D = $Vista/Zoom
@onready var lb_linea_1: Label = $Vista/Linea1
@onready var lb_linea_2: Label = $Vista/Linea2
@onready var anim: AnimationPlayer = $Anim
@onready var anim_zoom: AnimationPlayer = $Vista/Zoom/Anim

var pokemon: Array[Dictionary] = []
## Cintas del Pokémon abierto, en orden de pantalla.
var cintas: Array[int] = []
var cursor: int = 0
var en_vista: bool = false
var ocupado: bool = true


func _ready() -> void:
	vista.visible = false
	pokemon = DatosPokenav.pokemon_con_cintas()
	var elementos: Array = []
	for dato: Dictionary in pokemon:
		var uno: BasePokemon = dato["pokemon"]
		elementos.append({"texto": uno.get_nombre_mostrar(), "derecha": "Nv%d" % uno.nivel})
	lista.configurar(elementos)
	lista.movida.connect(_on_movida)
	lista.elegida.connect(_on_elegida)
	lista.cancelada.connect(salir)
	_on_movida(0)


func abrir() -> void:
	anim.play(&"entrada")
	await anim.animation_finished
	await lista.entrar()
	ocupado = false


func _on_movida(indice: int) -> void:
	lb_contador.text = ""
	if indice < pokemon.size():
		lb_contador.text = tr("POKENAV_CINTAS_N").replace("{n}", str((pokemon[indice]["pokemon"] as BasePokemon).cintas.size()))


func _on_elegida(indice: int) -> void:
	ocupado = true
	lista.activa = false
	lista.visible = false
	lb_contador.visible = false
	var uno: BasePokemon = pokemon[indice]["pokemon"]
	PokemonSprite.configurar_desde_pokemon(spr_pokemon, uno)
	lb_nombre.text = "%s/Nv%d" % [uno.get_nombre_mostrar(), uno.nivel]
	cintas = DatosPokenav.indices_cintas(uno)
	_pintar_rejilla()
	cursor = 0
	vista.visible = true
	en_vista = true
	anim.play(&"vista_entrada")
	await anim.animation_finished
	_pintar_cursor()
	ocupado = false


func _input(event: InputEvent) -> void:
	if not en_vista or ocupado or not is_inside_tree():
		return
	if event.is_action_pressed("btn_izquierda", true):
		mover(-1)
	elif event.is_action_pressed("btn_derecha", true):
		mover(1)
	elif event.is_action_pressed("btn_arriba", true):
		mover(-COLUMNAS)
	elif event.is_action_pressed("btn_abajo", true):
		mover(COLUMNAS)
	elif event.is_action_pressed("btn_cancelar"):
		Singleton.play_sound.emit("SE_SELECT")
		_cerrar_vista()
	else:
		return
	get_viewport().set_input_as_handled()


func mover(paso: int) -> void:
	var nuevo: int = cursor + paso
	if nuevo < 0 or nuevo >= cintas.size():
		return
	cursor = nuevo
	Singleton.play_sound.emit("SE_SELECT")
	_pintar_cursor()


func _cerrar_vista() -> void:
	ocupado = true
	if zoom.visible:
		anim_zoom.play(&"zoom_salida")
		await anim_zoom.animation_finished
	anim.play(&"vista_salida")
	await anim.animation_finished
	vista.visible = false
	en_vista = false
	lista.visible = true
	lb_contador.visible = true
	lista.activa = true
	ocupado = false


## Posición de la cinta `n` de las del Pokémon: 3 filas de 9 y regalos aparte.
func posicion_rejilla(n: int) -> Vector2:
	var normales: int = 0
	for indice: int in cintas:
		if indice < PRIMER_REGALO:
			normales += 1
	if n < normales:
		return ORIGEN_REJILLA + Vector2(n % COLUMNAS, n / COLUMNAS) * TAM_PEQUENA
	return ORIGEN_REGALOS + Vector2(n - normales, 0) * TAM_PEQUENA


func _pintar_rejilla() -> void:
	for i in rejilla.get_child_count():
		var celda: Sprite2D = rejilla.get_child(i) as Sprite2D
		celda.visible = i < cintas.size()
		if celda.visible:
			celda.position = posicion_rejilla(i)
			celda.region_rect = Rect2(cintas[i] * TAM_GRANDE, TAM_GRANDE, TAM_PEQUENA, TAM_PEQUENA)


func _pintar_cursor() -> void:
	if cintas.is_empty():
		zoom.visible = false
		return
	var indice: int = cintas[cursor]
	var lineas: Array = DatosPokenav.lineas_cinta(indice)
	lb_linea_1.text = str(lineas[0])
	lb_linea_2.text = str(lineas[1])
	zoom.region_rect = Rect2(indice * TAM_GRANDE, 0, TAM_GRANDE, TAM_GRANDE)
	# Centro de la celda (96 + 16x, 40 + 16y).
	zoom.position = posicion_rejilla(cursor) + Vector2(8, 8)
	zoom.visible = true
	anim_zoom.stop()
	anim_zoom.play(&"zoom_entrada")


func salir() -> void:
	ocupado = true
	await lista.salir()
	anim.play(&"salida")
	await anim.animation_finished
	cerrado.emit()
