extends Control
class_name DialogoBaseSecreta

## Reutiliza el cuadro existente; el menú SÍ/NO se declara en .tscn, sin builder.
signal texto_terminado
signal respuesta(acepta: bool)
@export var cuadro: NinePatchRect
@export var menu: NinePatchRect
@export var cursor: Control
var _indice: int = 0
var _esperar_soltar: bool = true
var _sesion: int = 0


func seleccionar_pc(claves: Array[String], ayudas: Array[String] = []) -> int:
	var opciones: MenuPCBase = get_node_or_null("MenuPC") as MenuPCBase
	if opciones == null:
		return -1
	show()
	var indice: int = await opciones.elegir(claves, ayudas)
	hide()
	return indice


## Solo el propietario de la sesión activa debe cancelar (salida/cambio de mapa).
func cancelar() -> void:
	_sesion += 1
	var opciones: MenuPCBase = get_node_or_null("MenuPC") as MenuPCBase
	if opciones != null and opciones.activa:
		opciones.cancelar()
	if menu.visible:
		menu.hide()
		respuesta.emit(false)
	elif visible:
		texto_terminado.emit()
	if is_instance_valid(cuadro): cuadro.cerrar()
	hide()


func mensaje(texto: String) -> void:
	var sesion: int = _sesion
	show()
	cuadro.mostrar(texto, true, false, texto_terminado.emit)
	await texto_terminado
	if sesion != _sesion:
		return
	cuadro.cerrar()
	hide()


func preguntar(texto: String) -> bool:
	var sesion: int = _sesion
	show()
	cuadro.mostrar(texto, false, false, texto_terminado.emit, true)
	await texto_terminado
	if sesion != _sesion:
		return false
	_indice = 0
	_esperar_soltar = true
	cursor.position.y = 7
	menu.show()
	var acepta: bool = await respuesta
	if sesion != _sesion:
		return false
	menu.hide()
	cuadro.cerrar()
	hide()
	return acepta


func _process(_delta: float) -> void:
	if not visible or menu == null or not menu.visible:
		return
	if _esperar_soltar:
		if not Input.is_action_pressed("btn_accion") and not Input.is_action_pressed("btn_cancelar"):
			_esperar_soltar = false
		return
	if Input.is_action_just_pressed("btn_arriba") or Input.is_action_just_pressed("btn_abajo"):
		_indice = 1 - _indice
		cursor.position.y = 7 + 16 * _indice
	elif Input.is_action_just_pressed("btn_cancelar"):
		menu.hide()
		respuesta.emit(false)
	elif Input.is_action_just_pressed("btn_accion"):
		menu.hide()
		respuesta.emit(_indice == 0)
