extends Node2D
class_name ListaPokenav

## Lista desplazable de 8 filas del POKéNAV (búsqueda de condición, ENTRENADORES y CINTAS).
## `configurar` recibe [{texto: String, derecha: String, marca: bool}].

signal movida(indice: int)
signal elegida(indice: int)
signal cancelada

const FILAS: int = 8

@onready var filas: Node2D = $Contenido/Filas
@onready var flecha: Sprite2D = $Contenido/Flecha
@onready var flecha_arriba: Sprite2D = $Contenido/FlechaArriba
@onready var flecha_abajo: Sprite2D = $Contenido/FlechaAbajo
@onready var anim: AnimationPlayer = $Anim

var elementos: Array = []
var indice: int = 0
var inicio: int = 0
var activa: bool = false


func configurar(p_elementos: Array, p_indice: int = 0) -> void:
	elementos = p_elementos
	indice = clampi(p_indice, 0, maxi(elementos.size() - 1, 0))
	inicio = clampi(indice - FILAS + 1, 0, maxi(elementos.size() - FILAS, 0))
	_pintar()


func entrar() -> void:
	anim.play(&"entrada")
	await anim.animation_finished
	activa = true


func salir() -> void:
	activa = false
	anim.play(&"salida")
	await anim.animation_finished


func _input(event: InputEvent) -> void:
	if not activa or not is_inside_tree():
		return
	if event.is_action_pressed("btn_arriba", true):
		mover(-1)
	elif event.is_action_pressed("btn_abajo", true):
		mover(1)
	elif event.is_action_pressed("btn_izquierda", true):
		mover(-FILAS)
	elif event.is_action_pressed("btn_derecha", true):
		mover(FILAS)
	elif event.is_action_pressed("btn_accion"):
		if elementos.is_empty():
			return
		Singleton.play_sound.emit("SE_SELECT")
		elegida.emit(indice)
	elif event.is_action_pressed("btn_cancelar"):
		Singleton.play_sound.emit("SE_SELECT")
		cancelada.emit()
	else:
		return
	get_viewport().set_input_as_handled()


## La lista no da la vuelta: se detiene en los extremos.
func mover(paso: int) -> void:
	var nuevo: int = clampi(indice + paso, 0, maxi(elementos.size() - 1, 0))
	if nuevo == indice:
		return
	indice = nuevo
	if indice < inicio:
		inicio = indice
	elif indice >= inicio + FILAS:
		inicio = indice - FILAS + 1
	Singleton.play_sound.emit("SE_SELECT")
	_pintar()
	movida.emit(indice)


func _pintar() -> void:
	for i in FILAS:
		var fila: Node2D = filas.get_child(i) as Node2D
		var hay: bool = inicio + i < elementos.size()
		fila.visible = hay
		if hay:
			var dato: Dictionary = elementos[inicio + i]
			(fila.get_node(^"Texto") as Label).text = str(dato.get("texto", ""))
			(fila.get_node(^"Derecha") as Label).text = str(dato.get("derecha", ""))
			(fila.get_node(^"Marca") as Sprite2D).visible = bool(dato.get("marca", false))
	flecha.visible = not elementos.is_empty()
	flecha.position.y = (indice - inicio) * 16 + 16
	flecha_arriba.visible = inicio > 0
	flecha_abajo.visible = inicio + FILAS < elementos.size()
