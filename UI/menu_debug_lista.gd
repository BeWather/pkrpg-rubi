## Menú de lista para utilidades de depuración en el overworld (guardería,
## árbol de bayas). Solo se instancia con la bandera debug del administrador.
extends NinePatchRect

const ESTILO_TEXTO: LabelSettings = preload("res://UI/texto_normal_negro.tres")
const ALTO_FILA: int = 16
const POSICION: Vector2 = Vector2(8, 4)
const ANCHO: float = 224.0

signal elegido(indice: int)

var _indice: int = 0
var _opciones: int = 0
var _y_opciones: int = 8
var _cursor: PkSelectorSimple = null


## Muestra el menú bajo `padre` y devuelve la opción elegida, o -1 al cancelar.
## `cabecera` son líneas de texto fijas sobre las opciones y `indice_inicial`
## la fila donde arranca el cursor.
static func elegir(padre: Node, opciones: PackedStringArray, cabecera: PackedStringArray = PackedStringArray(), indice_inicial: int = 0) -> int:
	var menu := new()
	padre.add_child(menu)
	menu._montar(opciones, cabecera)
	menu._indice = clampi(indice_inicial, 0, opciones.size() - 1)
	menu._actualizar_cursor()
	# No interpretar la pulsación que abrió el menú.
	await padre.get_tree().process_frame
	menu.set_process_input(true)
	var indice: int = await menu.elegido
	menu.queue_free()
	return indice


func _montar(opciones: PackedStringArray, cabecera: PackedStringArray) -> void:
	set_process_input(false)
	_opciones = opciones.size()
	_y_opciones = 8 + cabecera.size() * ALTO_FILA
	var imagen_tipo := int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	preload("res://scripts/clases/MenuBoxManager.gd").apply_texture_to_ninepatch(self, imagen_tipo)
	patch_margin_left = 8
	patch_margin_top = 8
	patch_margin_right = 8
	patch_margin_bottom = 8
	position = POSICION
	size = Vector2(ANCHO, _y_opciones + _opciones * ALTO_FILA + 8)
	for i in range(cabecera.size()):
		add_child(_etiqueta(cabecera[i], Vector2(12, 8 + i * ALTO_FILA)))
	for i in range(_opciones):
		add_child(_etiqueta(opciones[i], Vector2(12, _y_opciones + i * ALTO_FILA)))
	_cursor = PkSelectorSimple.new()
	_cursor.color = Color(239.0 / 255, 110.0 / 255, 96.0 / 255)
	_cursor.ancho_borde = 1
	_cursor.parpadeo = false
	_cursor.size = Vector2(ANCHO - 14, ALTO_FILA + 1)
	add_child(_cursor)
	_actualizar_cursor()


func _etiqueta(texto: String, posicion: Vector2) -> Label:
	var etiqueta := Label.new()
	etiqueta.label_settings = ESTILO_TEXTO
	etiqueta.text = texto
	etiqueta.position = posicion
	return etiqueta


func _actualizar_cursor() -> void:
	_cursor.position = Vector2(7, _y_opciones - 1 + _indice * ALTO_FILA)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("btn_arriba"):
		_indice = posmod(_indice - 1, _opciones)
		_actualizar_cursor()
	elif event.is_action_pressed("btn_abajo"):
		_indice = (_indice + 1) % _opciones
		_actualizar_cursor()
	elif event.is_action_pressed("btn_accion"):
		elegido.emit(_indice)
	elif event.is_action_pressed("btn_cancelar"):
		elegido.emit(-1)
	else:
		return
	Singleton.play_sound.emit("cursor_menu")
	get_viewport().set_input_as_handled()
