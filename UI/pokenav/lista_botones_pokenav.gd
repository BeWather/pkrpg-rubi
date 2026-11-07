extends Node2D
class_name ListaBotonesPokenav

## Columna de botones del POKéNAV con la opción elegida adelantada y su brillo.
## Los hijos BotonPokenav invisibles se saltan (fila de CINTAS sin cintas).

signal seleccion_cambiada(indice: int)

@onready var brillo: Node2D = $Brillo
@onready var anim_brillo: AnimationPlayer = $Brillo/Anim

var botones: Array[BotonPokenav] = []
var indice: int = 0


func _ready() -> void:
	for hijo: Node in get_children():
		if hijo is BotonPokenav:
			botones.append(hijo)
	brillo.visible = false


func boton_elegido() -> BotonPokenav:
	return botones[indice]


## Los botones entran por la derecha; al terminar, la opción elegida se adelanta y brilla.
func entrar() -> void:
	brillo.visible = false
	var ultimo: BotonPokenav = null
	for boton: BotonPokenav in botones:
		if boton.visible:
			boton.poner_fuera()
			boton.anim.play(&"entrar")
			ultimo = boton
	if ultimo != null:
		await ultimo.anim.animation_finished
	await _elegir_actual()


func _elegir_actual() -> void:
	seleccion_cambiada.emit(indice)
	var elegido: BotonPokenav = boton_elegido()
	await elegido.reproducir(&"elegir")
	if elegido == boton_elegido():
		_colocar_brillo()


func _colocar_brillo() -> void:
	# REG_WIN0V: alto 17 px centrado en la fila.
	brillo.position.y = boton_elegido().position.y
	brillo.visible = true
	anim_brillo.play(&"brillo")


## ARRIBA/ABAJO con vuelta, saltando filas ocultas. Devuelve si cambió.
func mover(direccion: int) -> bool:
	var nuevo: int = indice
	for _i in botones.size():
		nuevo = posmod(nuevo + direccion, botones.size())
		if botones[nuevo].visible:
			break
	if nuevo == indice:
		return false
	brillo.visible = false
	boton_elegido().anim.play(&"soltar")
	indice = nuevo
	_elegir_actual()
	return true


## sub_80F2240: los demás se van a la derecha; el elegido encoge y se desvanece.
func salir_con_elegido() -> void:
	brillo.visible = false
	for boton: BotonPokenav in botones:
		if boton.visible and boton != boton_elegido():
			boton.anim.play(&"salir")
	await boton_elegido().reproducir(&"expandir")


## Todos a la derecha (volver atrás).
func salir() -> void:
	brillo.visible = false
	var ultimo: BotonPokenav = null
	for boton: BotonPokenav in botones:
		if boton.visible:
			boton.anim.play(&"salir_elegido" if boton == boton_elegido() else &"salir")
			ultimo = boton
	if ultimo != null:
		await ultimo.anim.animation_finished
