extends ColorRect

signal continuar_solicitado
signal nueva_partida_solicitada
signal opciones_solicitadas
signal salir_solicitado

enum Opcion { CONTINUAR, NUEVA_PARTIDA, OPCIONES, SALIR }

## Navegacion disponible segun haya o no partida guardada: sin guardado la
## caja CONTINUAR se oculta y queda fuera del ciclo de seleccion.
const OPCIONES_CON_GUARDADO: Array[Opcion] = [
	Opcion.CONTINUAR,
	Opcion.NUEVA_PARTIDA,
	Opcion.OPCIONES,
	Opcion.SALIR,
]
const OPCIONES_SIN_GUARDADO: Array[Opcion] = [
	Opcion.NUEVA_PARTIDA,
	Opcion.OPCIONES,
	Opcion.SALIR,
]

const COLOR_TEXTO_CHICO := Color(0.15, 0.25, 0.85, 1.0)
const COLOR_TEXTO_CHICA := Color(0.85, 0.15, 0.15, 1.0)

var opcion_actual: Opcion = Opcion.CONTINUAR
var continuar_disponible: bool = false
var _interaccion_habilitada: bool = false

@onready var sel_continuar: NinePatchRect = $SelContinuar
@onready var sel_nueva: NinePatchRect = $SelNueva
@onready var sel_opciones: NinePatchRect = $SelOpciones
@onready var sel_salir: NinePatchRect = $SelSalir
@onready var error_label: Label = $ErrorLabel
@onready var etiqueta_titulo_continuar: Label = $SelContinuar/LbContinue
@onready var etiqueta_nombre_jugador: Label = $SelContinuar/Nombre
@onready var etiqueta_num_dex: Label = $SelContinuar/NumDex
@onready var etiqueta_horas_juego: Label = $SelContinuar/HorasJ
@onready var etiqueta_num_medallas: Label = $SelContinuar/NumMed
@onready var opciones: Array[NinePatchRect] = [
	sel_continuar,
	sel_nueva,
	sel_opciones,
	sel_salir,
]


func _ready() -> void:
	continuar_disponible = SistemaGuardado != null and SistemaGuardado.has_partida_guardada()
	if continuar_disponible:
		SistemaGuardado.cargar_opciones_en_datos_vivos()
	error_label.visible = false
	sel_continuar.visible = continuar_disponible
	opcion_actual = Opcion.CONTINUAR if continuar_disponible else Opcion.NUEVA_PARTIDA
	_actualizar_opcion_seleccionada()
	_actualizar_resumen_guardado()
	_aplicar_textura_bordes()


## Rellena la caja CONTINUAR con los valores del archivo de guardado real:
## nombre del jugador, pokedex vista, horas de juego y medallas.
func _actualizar_resumen_guardado() -> void:
	if not continuar_disponible or SistemaGuardado == null:
		return
	var resumen: Dictionary = SistemaGuardado.cargar_resumen_guardado()
	if resumen.is_empty():
		return
	if resumen.get("nombre", "") != "":
		etiqueta_nombre_jugador.text = str(resumen["nombre"])
	etiqueta_num_dex.text = str(int(resumen.get("pokedex", 0)))
	var segundos: int = int(resumen.get("tiempo", 0))
	etiqueta_horas_juego.text = "%d:%02d" % [int(segundos / 3600.0), int((segundos % 3600) / 60.0)]
	etiqueta_num_medallas.text = str(int(resumen.get("medallas", 0)))
	_aplicar_color_sexo(str(resumen.get("sexo", "M")))


## Como en la tercera generacion, el texto de los detalles de la partida es
## azul si el jugador guardado es chico y rojo si es chica. El titulo
## CONTINUAR conserva el color normal.
func _aplicar_color_sexo(sexo: String) -> void:
	var color: Color = COLOR_TEXTO_CHICA if sexo == "F" else COLOR_TEXTO_CHICO
	for etiqueta: Label in _etiquetas_detalle():
		var ajustes: LabelSettings = etiqueta.label_settings.duplicate()
		ajustes.font_color = color
		etiqueta.label_settings = ajustes


func _etiquetas_detalle() -> Array[Label]:
	var etiquetas: Array[Label] = []
	for hijo: Node in sel_continuar.get_children():
		if hijo is Label and hijo != etiqueta_titulo_continuar:
			etiquetas.append(hijo)
	return etiquetas


func mostrar_menu() -> void:
	visible = true
	_interaccion_habilitada = true
	sel_continuar.visible = continuar_disponible
	if not continuar_disponible and opcion_actual == Opcion.CONTINUAR:
		opcion_actual = Opcion.NUEVA_PARTIDA
	_actualizar_opcion_seleccionada()
	_aplicar_textura_bordes()


func ocultar_menu() -> void:
	_interaccion_habilitada = false
	error_label.visible = false
	visible = false


func restaurar_menu() -> void:
	mostrar_menu()


func mostrar_error(mensaje: String) -> void:
	error_label.text = mensaje
	error_label.visible = true
	mostrar_menu()


func _input(event: InputEvent) -> void:
	if not visible or not _interaccion_habilitada:
		return
	# Cada rama marca el evento como manejado: si el menu confirma una
	# accion (ej: CONTINUAR) y el juego arranca de forma sincrona dentro de
	# este mismo evento, sin set_input_as_handled el resto del arbol (menú
	# de pausa incluido) seguiria recibiendo ese mismo evento fisico.
	if event.is_action_pressed("btn_arriba"):
		get_viewport().set_input_as_handled()
		Singleton.emit_signal("play_sound", "cursor_menu")
		_mover_seleccion(-1)
	elif event.is_action_pressed("btn_abajo"):
		get_viewport().set_input_as_handled()
		Singleton.emit_signal("play_sound", "cursor_menu")
		_mover_seleccion(1)
	elif event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_menu"):
		get_viewport().set_input_as_handled()
		_seleccionar_opcion()
	elif event.is_action_pressed("btn_cancelar"):
		get_viewport().set_input_as_handled()
		_emitir_intencion(salir_solicitado)


func _seleccionar_opcion() -> void:
	# CONTINUAR solo existe en el menu cuando hay partida guardada: al no ser
	# visible tampoco es alcanzable desde la navegacion.
	if opcion_actual == Opcion.CONTINUAR and not continuar_disponible:
		return
	match opcion_actual:
		Opcion.CONTINUAR:
			_emitir_intencion(continuar_solicitado)
		Opcion.NUEVA_PARTIDA:
			_emitir_intencion(nueva_partida_solicitada)
		Opcion.OPCIONES:
			_emitir_intencion(opciones_solicitadas)
		Opcion.SALIR:
			_emitir_intencion(salir_solicitado)


func _emitir_intencion(intencion: Signal) -> void:
	if not _interaccion_habilitada:
		return
	_interaccion_habilitada = false
	intencion.emit()


## Opciones alcanzables con btn_arriba/btn_abajo: sin partida guardada el
## ciclo empieza en NUEVA_PARTIDA y nunca pasa por CONTINUAR.
func _opciones_navegables() -> Array[Opcion]:
	return OPCIONES_SIN_GUARDADO if not continuar_disponible else OPCIONES_CON_GUARDADO


func _mover_seleccion(direccion: int) -> void:
	var navegables: Array[Opcion] = _opciones_navegables()
	var indice: int = navegables.find(opcion_actual)
	opcion_actual = navegables[posmod(maxi(indice, 0) + direccion, navegables.size())]
	_actualizar_opcion_seleccionada()


func _nodo_de_opcion(opcion: Opcion) -> NinePatchRect:
	match opcion:
		Opcion.CONTINUAR:
			return sel_continuar
		Opcion.NUEVA_PARTIDA:
			return sel_nueva
		Opcion.OPCIONES:
			return sel_opciones
		_:
			return sel_salir


func _actualizar_opcion_seleccionada() -> void:
	for nodo: NinePatchRect in opciones:
		nodo.z_index = 0
	_nodo_de_opcion(opcion_actual).z_index = 2


func _aplicar_textura_bordes() -> void:
	if SistemaGuardado == null:
		return
	var imagen_tipo: int = SistemaGuardado.datos_vivos.opciones.imagen_tipo
	for nodo: NinePatchRect in opciones:
		MenuBoxManager.apply_texture_to_ninepatch(nodo, imagen_tipo)
