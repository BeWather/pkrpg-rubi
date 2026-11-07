extends Control
## Pantalla de búsqueda de la Pokédex (SELECT desde la lista).
## Basado en Task_LoadSearchMenu, Task_HandleSearchTopBarInput,
## Task_HandleSearchMenuInput y Task_HandleSearchParameterInput de
## pokeruby/src/pokedex.c. Textos de la ROM española oficial (AXVS).
##
## Al salir emite busqueda_terminada con {"accion": "salir"},
## {"accion": "cambio", "modo", "orden"} o
## {"accion": "busqueda", "modo", "orden", "lista": Array[Dictionary]}.

signal busqueda_terminada(resultado: Dictionary)

const ORDENADOR = preload("res://UI/pokedex/ordenador_pokedex.gd")
const DATOS_PRUEBA = preload("res://UI/pokedex/datos_prueba.gd")
const TAMANO_BASE: Vector2 = Vector2(240, 160)
const DURACION_FUNDIDO: float = 0.25
const OPCIONES_VISIBLES: int = 6
const ALTO_OPCION: float = 16.0
const REPETICION_INICIAL: float = 0.32
const REPETICION: float = 0.14

enum Barra { BUSCAR, CAMBIO, SALIR }
enum Fila { NOMBRE, COLOR, TIPO_1, TIPO_2, ORDEN, MODO, VALE }
enum Estado { FUNDIDO, BARRA, MENU, LISTA, BUSCANDO, RESULTADO, CERRANDO }
## Columnas de los atlas de etiquetas, botones y cajas.
enum Aspecto { NORMAL, ACTIVO, ATENUADO }

const TEXTOS_BARRA: Array[String] = [
	"Buscar POKéMON según los\nparámetros seleccionados.",
	"Cambiar el orden de la POKéDEX.",
	"Volver a la POKéDEX.",
]
const TEXTOS_FILA: Array[String] = [
	"Ordenar por la inicial del nombre.\nSólo POKéMON avistados.",
	"Ordenar por colores.\nSólo POKéMON avistados.",
	"Ordenar por tipo.\nSólo POKéMON capturados.",
	"Ordenar por tipo.\nSólo POKéMON capturados.",
	"Elegir el modo de ordenar la POKéDEX.",
	"Elegir el modo de la POKéDEX.",
	"Realizar la búsqueda.",
]
const TEXTO_BUSCANDO: String = "Buscando...\nEspera un instante."
const TEXTO_REALIZADA: String = "Búsqueda realizada."
const TEXTO_SIN_RESULTADOS: String = "No se encontraron POKéMON coincidentes."

## [título, descripción]. Nombre, color y tipo no tienen descripción.
const OPCIONES_NOMBRE: Array = [
	["CUALQUIERA", ""], ["ABC", ""], ["DEF", ""], ["GHI", ""], ["JKL", ""],
	["MNO", ""], ["PQR", ""], ["STU", ""], ["VWX", ""], ["YZ", ""],
]
const OPCIONES_COLOR: Array = [
	["CUALQUIERA", ""], ["ROJO", ""], ["AZUL", ""], ["AMARILLO", ""], ["VERDE", ""],
	["NEGRO", ""], ["MARRÓN", ""], ["MORADO", ""], ["GRIS", ""], ["BLANCO", ""], ["ROSA", ""],
]
const OPCIONES_TIPO: Array = [
	["TODOS", ""], ["NORMAL", ""], ["LUCHA", ""], ["VOLAD.", ""], ["VENENO", ""],
	["TIERRA", ""], ["ROCA", ""], ["BICHO", ""], ["FANT.", ""], ["ACERO", ""],
	["FUEGO", ""], ["AGUA", ""], ["PLANTA", ""], ["ELÉCT.", ""], ["PSÍQ.", ""],
	["HIELO", ""], ["DRAGÓN", ""], ["SINIE.", ""],
]
const OPCIONES_ORDEN: Array = [
	["NUMÉRICO", "POKéMON ordenados según \nsu numeración."],
	["ALFABÉTICO", "POKéMON avistados y capturados \nordenados alfabéticamente."],
	["MÁS PESADOS", "POKéMON capturados ordenados\nde mayor a menor peso."],
	["MÁS LIGEROS", "POKéMON capturados ordenados\nde menor a mayor peso."],
	["MÁS ALTOS", "POKéMON capturados ordenados\nde mayor a menor altura."],
	["MÁS BAJOS", "POKéMON capturados ordenados\nde menor a mayor altura."],
]
const OPCIONES_MODO: Array = [
	["DEX HOENN", "POKéDEX de la región de HOENN"],
	["DEX NACIONAL", "Edición nacional de POKéDEX"],
]

@export var dex_nacional_disponible: bool = false

@onready var _botones_barra: Array[Sprite2D] = [$BarraSuperior/Buscar, $BarraSuperior/Cambio, $BarraSuperior/Salir]
@onready var _vale: Sprite2D = $Vale
@onready var _tapa_modo: Sprite2D = $TapaModo
@onready var _linea_1: Label = $Descripcion/Linea1
@onready var _linea_2: Label = $Descripcion/Linea2
@onready var _lista: Node2D = $ListaOpciones
@onready var _cursor_lista: Control = $ListaOpciones/Cursor
@onready var _flecha_arriba: AnimatedSprite2D = $ListaOpciones/FlechaArriba
@onready var _flecha_abajo: AnimatedSprite2D = $ListaOpciones/FlechaAbajo
@onready var _fundido: ColorRect = $Fundido

var estado: int = Estado.FUNDIDO
var barra_actual: int = Barra.BUSCAR
var fila_actual: int = Fila.NOMBRE
## Por fila de opciones (NOMBRE..MODO): posición del cursor en la ventana
## visible y desplazamiento de la lista, como data[2..13] del decomp.
var cursores: Array[int] = [0, 0, 0, 0, 0, 0]
var desplazamientos: Array[int] = [0, 0, 0, 0, 0, 0]
var resultado_busqueda: Array[Dictionary] = []
var _datos: Array[Dictionary] = []
var _configurada: bool = false
var _modo_inicial: int = ORDENADOR.Modo.HOENN
var _orden_inicial: int = ORDENADOR.Orden.NUMERICO
## Cursor y desplazamiento al abrir la lista de opciones, para B.
var _respaldo_lista_opciones: Vector2i = Vector2i.ZERO
var _reproducir: Callable
var _reproductor_f6: AudioStreamPlayer
var _direccion_mantenida: int = 0
var _espera_repeticion: float = 0.0


## Llamar antes o después de añadir la escena al árbol. reproducir recibe la
## clave de Singleton.se; por defecto se usa el reproductor propio o el central.
func configurar(datos: Array[Dictionary], modo: int, orden: int, nacional: bool,
		reproducir: Callable = Callable()) -> void:
	_configurada = true
	_datos = ORDENADOR.normalizar(datos)
	dex_nacional_disponible = nacional
	_modo_inicial = modo if nacional else ORDENADOR.Modo.HOENN
	_orden_inicial = orden
	_reproducir = reproducir
	if is_node_ready():
		_reiniciar()


func _ready() -> void:
	_flecha_arriba.play()
	_flecha_abajo.play()
	if not _configurada:
		configurar(DATOS_PRUEBA.crear(), ORDENADOR.Modo.HOENN, ORDENADOR.Orden.NUMERICO, dex_nacional_disponible)
	_reiniciar()
	call_deferred("_ajustar_vista_previa")
	get_viewport().size_changed.connect(_ajustar_vista_previa)
	_fundido.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_fundido, "modulate:a", 0.0, DURACION_FUNDIDO)
	await tween.finished
	estado = Estado.BARRA


## Task_LoadSearchMenu: nombre, color y tipos vuelven a CUALQUIERA/TODOS;
## orden y modo parten de los de la lista. Sin Dex Nacional, la fila MODO
## desaparece y VALE sube a su lugar.
func _reiniciar() -> void:
	cursores = [0, 0, 0, 0, _orden_inicial, _modo_inicial]
	desplazamientos = [0, 0, 0, 0, 0, 0]
	barra_actual = Barra.BUSCAR
	fila_actual = Fila.NOMBRE
	$Filas/Modo.visible = dex_nacional_disponible
	_tapa_modo.visible = not dex_nacional_disponible
	_vale.position.y = 96.0 if dex_nacional_disponible else 80.0
	_lista.visible = false
	_imprimir_valores()
	_actualizar_resaltado()
	_mostrar_texto(TEXTOS_BARRA[barra_actual])


func _ajustar_vista_previa() -> void:
	if get_tree().current_scene != self:
		return
	var tamano := get_viewport_rect().size
	var factor := minf(tamano.x / TAMANO_BASE.x, tamano.y / TAMANO_BASE.y)
	scale = Vector2.ONE * factor
	position = (tamano - TAMANO_BASE * factor) / 2.0


func _reproducir_efecto(clave: String) -> void:
	if _reproducir.is_valid():
		_reproducir.call(clave)
	elif get_tree().current_scene == self:
		if not is_instance_valid(_reproductor_f6):
			_reproductor_f6 = AudioStreamPlayer.new()
			_reproductor_f6.name = "ReproductorSEF6"
			_reproductor_f6.bus = &"Master"
			add_child(_reproductor_f6)
		_reproductor_f6.stream = Singleton.se[clave]
		_reproductor_f6.play()
	else:
		Singleton.play_sound.emit(clave)


func seleccion(fila: int) -> int:
	return cursores[fila] + desplazamientos[fila]


func _opciones(fila: int) -> Array:
	match fila:
		Fila.NOMBRE:
			return OPCIONES_NOMBRE
		Fila.COLOR:
			return OPCIONES_COLOR
		Fila.TIPO_1, Fila.TIPO_2:
			return OPCIONES_TIPO
		Fila.ORDEN:
			return OPCIONES_ORDEN
		_:
			return OPCIONES_MODO if dex_nacional_disponible else OPCIONES_MODO.slice(0, 1)


func _mostrar_texto(texto: String) -> void:
	var lineas := texto.split("\n")
	_linea_1.text = lineas[0]
	_linea_2.text = lineas[1] if lineas.size() > 1 else ""


func _imprimir_valores() -> void:
	$Filas/Nombre/Valor.text = OPCIONES_NOMBRE[seleccion(Fila.NOMBRE)][0]
	$Filas/Color/Valor.text = OPCIONES_COLOR[seleccion(Fila.COLOR)][0]
	$Filas/Tipo/Valor1.text = OPCIONES_TIPO[seleccion(Fila.TIPO_1)][0]
	$Filas/Tipo/Valor2.text = OPCIONES_TIPO[seleccion(Fila.TIPO_2)][0]
	$Filas/Orden/Valor.text = OPCIONES_ORDEN[seleccion(Fila.ORDEN)][0]
	$Filas/Modo/Valor.text = OPCIONES_MODO[seleccion(Fila.MODO)][0]


## SetInitialSearchMenuBgHighlights + HighlightSelectedSearchMenuItem:
## CAMBIO atenúa nombre, color y tipo; SALIR atenúa todas las filas.
func _actualizar_resaltado() -> void:
	for i in _botones_barra.size():
		_botones_barra[i].frame_coords.x = Aspecto.ACTIVO if i == barra_actual else Aspecto.NORMAL
	var en_menu := estado in [Estado.MENU, Estado.LISTA, Estado.BUSCANDO, Estado.RESULTADO]
	var filas := {
		"Nombre": [Fila.NOMBRE], "Color": [Fila.COLOR], "Tipo": [Fila.TIPO_1, Fila.TIPO_2],
		"Orden": [Fila.ORDEN], "Modo": [Fila.MODO],
	}
	for nombre in filas:
		var nodo := get_node("Filas/" + nombre)
		var atenuada: bool = barra_actual == Barra.SALIR or (barra_actual == Barra.CAMBIO and filas[nombre][0] < Fila.ORDEN)
		var activa: bool = en_menu and fila_actual in filas[nombre]
		var etiqueta := nodo.get_node("Etiqueta") as Sprite2D
		etiqueta.frame_coords.x = Aspecto.ATENUADO if atenuada else (Aspecto.ACTIVO if activa else Aspecto.NORMAL)
		var cajas: Array = [nodo.get_node("Caja1"), nodo.get_node("Caja2")] if nombre == "Tipo" else [nodo.get_node("Caja")]
		for j in cajas.size():
			var con_cursor: bool = en_menu and fila_actual == filas[nombre][j]
			(cajas[j] as Sprite2D).frame = Aspecto.ATENUADO if atenuada else (Aspecto.ACTIVO if con_cursor else Aspecto.NORMAL)
	var vale_activo := en_menu and fila_actual == Fila.VALE
	_vale.frame = Aspecto.ATENUADO if barra_actual == Barra.SALIR else (Aspecto.ACTIVO if vale_activo else Aspecto.NORMAL)


## gSearchMovementMap_*: [izquierda, derecha, arriba, abajo]; -1 = sin salida.
func _mapa_movimiento() -> Dictionary:
	var mapa := {}
	if barra_actual == Barra.BUSCAR:
		mapa[Fila.NOMBRE] = [-1, -1, -1, Fila.COLOR]
		mapa[Fila.COLOR] = [-1, -1, Fila.NOMBRE, Fila.TIPO_1]
		mapa[Fila.TIPO_1] = [-1, Fila.TIPO_2, Fila.COLOR, Fila.ORDEN]
		mapa[Fila.TIPO_2] = [Fila.TIPO_1, -1, Fila.COLOR, Fila.ORDEN]
		mapa[Fila.ORDEN] = [-1, -1, Fila.TIPO_1, -1]
	else:
		mapa[Fila.ORDEN] = [-1, -1, -1, -1]
	if dex_nacional_disponible:
		mapa[Fila.ORDEN][3] = Fila.MODO
		mapa[Fila.MODO] = [-1, -1, Fila.ORDEN, Fila.VALE]
		mapa[Fila.VALE] = [-1, -1, Fila.MODO, -1]
	else:
		mapa[Fila.ORDEN][3] = Fila.VALE
		mapa[Fila.VALE] = [-1, -1, Fila.ORDEN, -1]
	return mapa


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.is_echo():
		return
	match estado:
		Estado.BARRA:
			_entrada_barra(event)
		Estado.MENU:
			_entrada_menu(event)
		Estado.LISTA:
			_entrada_lista(event)
		Estado.RESULTADO:
			if event.is_action_pressed(&"btn_accion"):
				_confirmar_resultado()
	get_viewport().set_input_as_handled()


func _entrada_barra(event: InputEvent) -> void:
	if event.is_action_pressed(&"btn_izquierda") or event.is_action_pressed(&"btn_derecha"):
		var destino := clampi(barra_actual + (-1 if event.is_action_pressed(&"btn_izquierda") else 1), Barra.BUSCAR, Barra.SALIR)
		if destino != barra_actual:
			barra_actual = destino
			_actualizar_resaltado()
			_mostrar_texto(TEXTOS_BARRA[barra_actual])
			_reproducir_efecto("SE_DEX_PAGE")
	elif event.is_action_pressed(&"btn_accion"):
		if barra_actual == Barra.SALIR:
			_cerrar({"accion": "salir"})
			return
		_reproducir_efecto("SE_PIN")
		_ir_a_fila(Fila.NOMBRE if barra_actual == Barra.BUSCAR else Fila.ORDEN)
	elif event.is_action_pressed(&"btn_cancelar"):
		_cerrar({"accion": "salir"})


func _ir_a_fila(fila: int) -> void:
	estado = Estado.MENU
	fila_actual = fila
	_actualizar_resaltado()
	_mostrar_texto(TEXTOS_FILA[fila_actual])


func _entrada_menu(event: InputEvent) -> void:
	if event.is_action_pressed(&"btn_cancelar"):
		# Orden y modo vuelven a los de la lista (dexOrderBackup/dexModeBackup).
		_reproducir_efecto("SE_BALL")
		cursores[Fila.ORDEN] = _orden_inicial
		cursores[Fila.MODO] = _modo_inicial
		desplazamientos[Fila.ORDEN] = 0
		desplazamientos[Fila.MODO] = 0
		_imprimir_valores()
		estado = Estado.BARRA
		_actualizar_resaltado()
		_mostrar_texto(TEXTOS_BARRA[barra_actual])
		return
	if event.is_action_pressed(&"btn_accion"):
		if fila_actual == Fila.VALE:
			_confirmar_vale()
		else:
			_reproducir_efecto("SE_PIN")
			_abrir_lista()
		return
	var direcciones := [&"btn_izquierda", &"btn_derecha", &"btn_arriba", &"btn_abajo"]
	for i in direcciones.size():
		if event.is_action_pressed(direcciones[i]):
			var destino: int = _mapa_movimiento()[fila_actual][i]
			if destino >= 0:
				fila_actual = destino
				_actualizar_resaltado()
				_mostrar_texto(TEXTOS_FILA[fila_actual])
				_reproducir_efecto("SE_SELECT")
			return


func _confirmar_vale() -> void:
	var modo := seleccion(Fila.MODO) if dex_nacional_disponible else ORDENADOR.Modo.HOENN
	var orden := seleccion(Fila.ORDEN)
	if barra_actual == Barra.CAMBIO:
		_cerrar({"accion": "cambio", "modo": modo, "orden": orden})
		return
	estado = Estado.BUSCANDO
	_mostrar_texto(TEXTO_BUSCANDO)
	_reproducir_efecto("SE_DEX_SEARCH")
	resultado_busqueda = ORDENADOR.buscar(_datos, modo, orden, seleccion(Fila.NOMBRE),
			seleccion(Fila.COLOR), seleccion(Fila.TIPO_1), seleccion(Fila.TIPO_2))
	# El resultado se anuncia al terminar SE_DEX_SEARCH (IsSEPlaying).
	await get_tree().create_timer(Singleton.se["SE_DEX_SEARCH"].get_length()).timeout
	if estado != Estado.BUSCANDO:
		return
	estado = Estado.RESULTADO
	if resultado_busqueda.is_empty():
		_mostrar_texto(TEXTO_SIN_RESULTADOS)
		_reproducir_efecto("SE_FAILURE")
	else:
		_mostrar_texto(TEXTO_REALIZADA)
		_reproducir_efecto("SE_SUCCESS")


## Tras el mensaje solo se acepta A: con resultados abre la lista filtrada;
## sin resultados vuelve al menú con los mismos parámetros.
func _confirmar_resultado() -> void:
	if resultado_busqueda.is_empty():
		_reproducir_efecto("SE_BALL")
		_ir_a_fila(Fila.VALE)
		return
	_cerrar({
		"accion": "busqueda",
		"modo": seleccion(Fila.MODO) if dex_nacional_disponible else ORDENADOR.Modo.HOENN,
		"orden": seleccion(Fila.ORDEN),
		"lista": resultado_busqueda,
	})


func _abrir_lista() -> void:
	estado = Estado.LISTA
	_respaldo_lista_opciones = Vector2i(cursores[fila_actual], desplazamientos[fila_actual])
	_lista.visible = true
	_dibujar_lista()


func _dibujar_lista() -> void:
	var opciones := _opciones(fila_actual)
	var desplazamiento := desplazamientos[fila_actual]
	for i in OPCIONES_VISIBLES:
		var etiqueta := $ListaOpciones/Opciones.get_child(i) as Label
		var indice := desplazamiento + i
		etiqueta.text = opciones[indice][0] if indice < opciones.size() else ""
	_cursor_lista.position.y = 7.0 + cursores[fila_actual] * ALTO_OPCION
	_flecha_arriba.visible = opciones.size() > OPCIONES_VISIBLES and desplazamiento > 0
	_flecha_abajo.visible = opciones.size() > OPCIONES_VISIBLES and desplazamiento < opciones.size() - OPCIONES_VISIBLES
	_mostrar_texto(opciones[seleccion(fila_actual)][1])


func _entrada_lista(event: InputEvent) -> void:
	if event.is_action_pressed(&"btn_accion") or event.is_action_pressed(&"btn_cancelar"):
		_direccion_mantenida = 0
		if event.is_action_pressed(&"btn_accion"):
			_reproducir_efecto("SE_PIN")
		else:
			_reproducir_efecto("SE_BALL")
			cursores[fila_actual] = _respaldo_lista_opciones.x
			desplazamientos[fila_actual] = _respaldo_lista_opciones.y
		_lista.visible = false
		_imprimir_valores()
		_ir_a_fila(fila_actual)
		return
	for accion in [&"btn_arriba", &"btn_abajo"]:
		if event.is_action_released(accion):
			_direccion_mantenida = 0
		elif event.is_action_pressed(accion):
			_direccion_mantenida = -1 if accion == &"btn_arriba" else 1
			_espera_repeticion = REPETICION_INICIAL
			_mover_en_lista(_direccion_mantenida)


func _process(delta: float) -> void:
	if estado != Estado.LISTA or _direccion_mantenida == 0:
		return
	_espera_repeticion -= delta
	if _espera_repeticion <= 0.0:
		_mover_en_lista(_direccion_mantenida)
		_espera_repeticion = REPETICION


## El cursor se mueve dentro de las 6 líneas visibles; en el borde se desplaza
## la lista hasta numOptions - 6.
func _mover_en_lista(direccion: int) -> void:
	var total := _opciones(fila_actual).size()
	var cursor := cursores[fila_actual]
	var desplazamiento := desplazamientos[fila_actual]
	if direccion < 0:
		if cursor > 0:
			cursor -= 1
		elif desplazamiento > 0:
			desplazamiento -= 1
	else:
		if cursor < OPCIONES_VISIBLES - 1 and cursor + desplazamiento < total - 1:
			cursor += 1
		elif desplazamiento < total - OPCIONES_VISIBLES:
			desplazamiento += 1
	if cursor == cursores[fila_actual] and desplazamiento == desplazamientos[fila_actual]:
		return
	cursores[fila_actual] = cursor
	desplazamientos[fila_actual] = desplazamiento
	_reproducir_efecto("SE_SELECT")
	_dibujar_lista()


func _cerrar(resultado: Dictionary) -> void:
	estado = Estado.CERRANDO
	_direccion_mantenida = 0
	_reproducir_efecto("SE_PC_OFF")
	var tween := create_tween()
	tween.tween_property(_fundido, "modulate:a", 1.0, DURACION_FUNDIDO)
	await tween.finished
	busqueda_terminada.emit(resultado)
	# En F6 no hay Pokédex a la que volver.
	if get_tree().current_scene == self:
		get_tree().quit()
