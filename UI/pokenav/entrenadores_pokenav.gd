extends Node2D
class_name EntrenadoresPokenav

## Pantalla ENTRENADORES (Trainer's Eyes) del POKéNAV: lista de entrenadores ya
## vencidos con icono de revancha y lugar, y ficha con retrato y textos oficiales.

signal cerrado

@onready var lista: ListaPokenav = $Lista
@onready var lb_lugar: Label = $Lugar
@onready var detalle: Node2D = $Detalle
@onready var retrato: AnimatedSprite2D = $Detalle/Retrato
@onready var lb_nombre: Label = $Detalle/Textos/Nombre
@onready var lb_estrategia: Label = $Detalle/Textos/Estrategia
@onready var lb_pokemon: Label = $Detalle/Textos/Pokemon
@onready var lb_presentacion_1: Label = $Detalle/Textos/Presentacion1
@onready var lb_presentacion_2: Label = $Detalle/Textos/Presentacion2
@onready var anim: AnimationPlayer = $Anim

var registrados: Array = []
var en_detalle: bool = false
var ocupado: bool = true


func _ready() -> void:
	detalle.visible = false
	registrados = DatosPokenav.entrenadores_registrados()
	var elementos: Array = []
	for entrada: Dictionary in registrados:
		elementos.append({
			"texto": "%s %s" % [entrada["clase"], entrada["nombre"]],
			"marca": DatosPokenav.quiere_revancha(entrada),
		})
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
	lb_lugar.text = str(registrados[indice]["lugar"]) if indice < registrados.size() else ""


func _on_elegida(indice: int) -> void:
	ocupado = true
	lista.activa = false
	_pintar_detalle(indice)
	detalle.visible = true
	lista.visible = false
	lb_lugar.visible = false
	en_detalle = true
	anim.play(&"detalle_entrada")
	await anim.animation_finished
	ocupado = false


func _input(event: InputEvent) -> void:
	if not en_detalle or ocupado or not is_inside_tree():
		return
	if event.is_action_pressed("btn_arriba", true):
		_mover_detalle(-1)
	elif event.is_action_pressed("btn_abajo", true):
		_mover_detalle(1)
	elif event.is_action_pressed("btn_cancelar"):
		Singleton.play_sound.emit("SE_SELECT")
		_cerrar_detalle()
	else:
		return
	get_viewport().set_input_as_handled()


func _mover_detalle(paso: int) -> void:
	var anterior: int = lista.indice
	lista.mover(paso)
	if lista.indice != anterior:
		_pintar_detalle(lista.indice)
		anim.stop()
		anim.play(&"detalle_entrada")


func _cerrar_detalle() -> void:
	ocupado = true
	anim.play(&"detalle_salida")
	await anim.animation_finished
	detalle.visible = false
	en_detalle = false
	lista.visible = true
	lb_lugar.visible = true
	lista.activa = true
	ocupado = false


func _pintar_detalle(indice: int) -> void:
	var entrada: Dictionary = registrados[indice]
	lb_nombre.text = "%s %s" % [entrada["clase"], entrada["nombre"]]
	lb_estrategia.text = str(entrada["estrategia"])
	lb_pokemon.text = str(entrada["pokemon"])
	lb_presentacion_1.text = str(entrada["presentacion"][0])
	lb_presentacion_2.text = str(entrada["presentacion"][1])
	var datos: DatosEntrenador = DatabaseManager.get_entrenador(int(entrada["id"]))
	retrato.visible = datos != null
	if datos != null:
		retrato.frame = datos.num_sprite


func salir() -> void:
	ocupado = true
	await lista.salir()
	anim.play(&"salida")
	await anim.animation_finished
	cerrado.emit()
