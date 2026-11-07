extends Control
## Ficha de la POKéDEX (A sobre una especie vista de la lista).
## Basado en Task_InitPageScreenMultistep y Task_PageScreenProcessInput de
## pokeruby/src/pokedex.c; datos y formatos de la ROM española oficial
## (entradas_pokedex_es.json: gPokedexEntries en 0x3B58BC).
##
## Arriba/abajo pasa a la siguiente especie vista de la lista; A en PÁG.
## alterna las dos páginas de la descripción (solo capturados); A en ÁREA,
## GRITO o TAM. (este solo capturados) abre esa pestaña, y dentro de ellas
## izquierda/derecha pasan de una a otra; B vuelve.

signal pagina_cerrada(indice: int)

const ENTRADAS = preload("res://UI/pokedex/entradas_pokedex_es.json")
## Pestañas que tapan la ficha, por Seccion.
const SUBPANTALLAS: Dictionary = {
	1: preload("res://UI/pokedex/area-pokedex.tscn"),
	2: preload("res://UI/pokedex/grito-pokedex.tscn"),
	3: preload("res://UI/pokedex/tamano-pokedex.tscn"),
}
const HUELLAS: Texture2D = preload("res://UI/pokedex/graficos/pagina/huellas.png")
const PANEL_CAPTURADO: Texture2D = preload("res://UI/pokedex/graficos/pagina/page-data.png")
const PANEL_NO_CAPTURADO: Texture2D = preload("res://UI/pokedex/graficos/pagina/page-data-no-capturado.png")
const TEXTO_NORMAL: LabelSettings = preload("res://UI/texto_normal_negro.tres")
const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"
const RUTA_FRENTE: String = "res://graficos/pokemon/front/%s.png"
const TAMANO_BASE: Vector2 = Vector2(240, 160)
## BeginNormalPaletteFade de 0 a 16: unos 18 cuadros.
const DURACION_FUNDIDO: float = 0.3

## gDexText_UnknownPoke/Height/Weight de la ROM ES ("???,?  m" se imprime
## antes del número y deja visible la unidad).
const CATEGORIA_DESCONOCIDA: String = "POKéMON (?)"
const PREFIJO_CATEGORIA: String = "POKéMON "
const VALOR_DESCONOCIDO: String = "???,?"
## Píxeles de impresión del decomp (Menu_PrintText en casillas × 8). Las
## etiquetas van 1 px a la izquierda: la fuente deja ese margen al glifo.
const X_CATEGORIA: float = 88.0
const X_VALOR: float = 128.0
const COLORES_CHICO: Array[Color] = [Color("29396b"), Color("000029")]
const COLORES_CHICA: Array[Color] = [Color("a5a6a5"), Color("293942")]

enum Seccion { PAGINA, AREA, GRITO, TAMANO }
## Fotogramas de los botones superiores.
enum Boton { INVISIBLE, INACTIVO, ACTIVO }

@export var es_chica: bool = false:
	set(valor):
		es_chica = valor
		if is_node_ready():
			_aplicar_sexo()

## displaydexinfo: A pasa a página 2 y luego vuelve al combate; B sale.
@export var modo_registro: bool = false

@onready var _botones: Array[AnimatedSprite2D] = [
	$MenuSuperior/botonPagina, $MenuSuperior/botonArea,
	$MenuSuperior/botonGrito, $MenuSuperior/botonTamano,
]
@onready var _panel: Sprite2D = $PageData
@onready var _pagina_2: Sprite2D = $Page2Data
@onready var _texto_1: Label = $PageData/Page1Text
@onready var _texto_2: Label = $Page2Data/Page2Text
@onready var _frente: Sprite2D = $Frente
@onready var _huella: Sprite2D = $Datos/Huella
@onready var _fundido: ColorRect = $Fundido
@onready var _parpadeo_registro: Timer = $ParpadeoRegistro
@onready var _material_bordes: ShaderMaterial = _panel.material as ShaderMaterial

var entradas: Array[Dictionary] = []
var indice: int = 0
var seccion: int = Seccion.PAGINA
var en_pagina_2: bool = false
## Solo acepta controles tras el fundido y el grito, como el estado 9.
var aceptando_controles: bool = false
var _reproducir: Callable
var _reproductor_se: AudioStreamPlayer
var _reproductor_grito: AudioStreamPlayer
var _configurada: bool = false
var _desde_lista: bool = false
## Pestaña abierta (ÁREA, GRITO o TAM.) y el fundido que cubre la ficha bajo
## la barra superior, que en Rubí no se funde (máscara 0xFFFFFFEB).
var _subpantalla: Control
var _cortina: ColorRect
var _borde_gris: bool = false


## entradas: la lista visible de la Pokédex (principal o resultados).
## desde_lista: el frente ya está en su sitio (lo trajo la lista), así que no
## se funde al entrar, como LoadInfoScreen con data[1] = 1.
func configurar(lista: Array[Dictionary], seleccion: int, chica: bool,
		reproducir: Callable = Callable(), desde_lista: bool = false) -> void:
	_configurada = true
	entradas = lista
	indice = seleccion
	es_chica = chica
	_reproducir = reproducir
	_desde_lista = desde_lista


func _ready() -> void:
	_parpadeo_registro.timeout.connect(_alternar_bordes_registro)
	for boton in _botones:
		boton.stop()
	if not _configurada:
		_configurar_vista_previa()
	_aplicar_sexo()
	_reproductor_grito = AudioStreamPlayer.new()
	_reproductor_grito.name = "ReproductorGrito"
	_reproductor_grito.bus = &"Master"
	add_child(_reproductor_grito)
	_actualizar_botones()
	_mostrar_especie()
	call_deferred("_ajustar_vista_previa")
	_entrar.call_deferred()


## F6: primera especie vista de la fixture.
func _configurar_vista_previa() -> void:
	var ordenador = load("res://UI/pokedex/ordenador_pokedex.gd")
	var datos = ordenador.normalizar(load("res://UI/pokedex/datos_prueba.gd").crear())
	entradas = ordenador.ordenar(datos, ordenador.Modo.HOENN, ordenador.Orden.NUMERICO)
	indice = 0


func _ajustar_vista_previa() -> void:
	if get_tree().current_scene != self:
		return
	var tamano := get_viewport_rect().size
	var factor := minf(tamano.x / TAMANO_BASE.x, tamano.y / TAMANO_BASE.y)
	scale = Vector2.ONE * factor
	position = (tamano - TAMANO_BASE * factor) / 2.0


func _aplicar_sexo() -> void:
	$"Fe-fondo".visible = es_chica
	$"Ma-fondo".visible = not es_chica
	var colores := COLORES_CHICA if es_chica else COLORES_CHICO
	$MenuSuperior.color = colores[0]
	$FondoInferior.color = colores[1]


func _reproducir_efecto(clave: String) -> void:
	if _reproducir.is_valid():
		_reproducir.call(clave)
	elif get_tree().current_scene == self:
		if not is_instance_valid(_reproductor_se):
			_reproductor_se = AudioStreamPlayer.new()
			_reproductor_se.bus = &"Master"
			add_child(_reproductor_se)
		_reproductor_se.stream = Singleton.se[clave]
		_reproductor_se.play()
	else:
		Singleton.play_sound.emit(clave)


func entrada_actual() -> Dictionary:
	return entradas[indice] if indice >= 0 and indice < entradas.size() else {}


static func datos_ficha(nacional: int) -> Dictionary:
	return ENTRADAS.data.get(str(nacional), {})


## UnusedPrintDecimalNum de las versiones métricas: decímetros o hectogramos
## con coma; las decenas siempre (7 → "0,7"), millares y centenas si hay.
static func formatear_medida(valor: int) -> String:
	var millares := valor / 1000
	var centenas := (valor / 100) % 10
	var texto := ""
	if millares > 0:
		texto += str(millares)
	if millares > 0 or centenas > 0:
		texto += str(centenas)
	return texto + "%d,%d" % [(valor / 10) % 10, valor % 10]


## Estado 4: número, nombre, categoría, medidas, huella y página 1.
func _mostrar_especie() -> void:
	_parpadeo_registro.stop()
	_borde_gris = false
	_material_bordes.set_shader_parameter(&"borde_gris", false)
	var entrada := entrada_actual()
	var nacional := int(entrada.get("nacional", 0))
	var ficha := datos_ficha(nacional)
	var capturado := bool(entrada.get("atrapado", false))
	en_pagina_2 = false
	_pagina_2.visible = false
	_panel.texture = PANEL_CAPTURADO if capturado else PANEL_NO_CAPTURADO
	$Datos/Numero.text = "%03d" % int(entrada.get("numero_mostrado", entrada.get("numero", 0)))
	$Datos/Nombre.text = str(entrada.get("nombre", "")).to_upper()
	var categoria := CATEGORIA_DESCONOCIDA
	if capturado and not ficha.is_empty():
		categoria = PREFIJO_CATEGORIA + str(ficha["categoria"])
	# AlignString tipo 1: alineado a la derecha del ancho de "POKéMON (?)";
	# si es más largo, empieza en la columna 11.
	var hueco := maxf(0.0, _ancho(CATEGORIA_DESCONOCIDA) - _ancho(categoria))
	_colocar($Datos/Categoria, categoria, X_CATEGORIA + hueco)
	_mostrar_medida($Datos/Altura, int(ficha.get("altura_dm", 0)), capturado and not ficha.is_empty())
	_mostrar_medida($Datos/Peso, int(ficha.get("peso_hg", 0)), capturado and not ficha.is_empty())
	_huella.visible = capturado and nacional > 0
	if _huella.visible:
		_huella.region_rect = Rect2(((nacional - 1) % 16) * 16, ((nacional - 1) / 16) * 16, 16, 16)
	_texto_1.text = str(ficha.get("pagina_1", "")) if capturado else ""
	_texto_2.text = str(ficha.get("pagina_2", "")) if capturado else ""
	_frente.texture = _obtener_frente(entrada)


## El número se imprime alineado a la derecha del hueco de "???,?".
func _mostrar_medida(etiqueta: Label, valor: int, conocido: bool) -> void:
	var texto := formatear_medida(valor) if conocido else VALOR_DESCONOCIDO
	_colocar(etiqueta, texto, X_VALOR + _ancho(VALOR_DESCONOCIDO) - _ancho(texto))


func _colocar(etiqueta: Label, texto: String, x_impresion: float) -> void:
	etiqueta.text = texto
	etiqueta.position.x = x_impresion - 1.0
	etiqueta.size.x = _ancho(texto) + 2.0


func _ancho(texto: String) -> float:
	return TEXTO_NORMAL.font.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXTO_NORMAL.font_size).x


func _obtener_frente(entrada: Dictionary) -> Texture2D:
	var ruta := str(entrada.get("sprite", RUTA_FRENTE % str(entrada.get("nombre", "")).to_upper()))
	if ResourceLoader.exists(ruta):
		return load(ruta) as Texture2D
	push_warning("Pokédex: no se encontró el sprite de frente: " + ruta)
	return null


## Con ÁREA abierta, PÁG. desaparece (pokedex_navbar_3.bin).
func _actualizar_botones() -> void:
	for i in _botones.size():
		_botones[i].frame = Boton.ACTIVO if i == seccion else Boton.INACTIVO
	if is_instance_valid(_subpantalla):
		_botones[Seccion.PAGINA].frame = Boton.INVISIBLE


## Estados 6-10: fundido de entrada, grito y controles al terminar el grito.
## Desde la lista el frente ya está iluminado; al cambiar de especie se funde.
func _entrar() -> void:
	aceptando_controles = false
	_fundido.modulate.a = 1.0
	_frente.modulate = Color.WHITE if _desde_lista else Color.BLACK
	_desde_lista = false
	var tween := create_tween().set_parallel()
	tween.tween_property(_fundido, "modulate:a", 0.0, DURACION_FUNDIDO)
	tween.tween_property(_frente, "modulate", Color.WHITE, DURACION_FUNDIDO)
	await tween.finished
	# sub_8090A3C: cambia la paleta cada 16 cuadros tras el fundido,
	# incluso mientras se reproduce el grito; ambas páginas comparten material.
	if modo_registro and bool(entrada_actual().get("atrapado", false)):
		_parpadeo_registro.start()
	await _reproducir_grito()
	aceptando_controles = true


func _alternar_bordes_registro() -> void:
	_borde_gris = not _borde_gris
	_material_bordes.set_shader_parameter(&"borde_gris", _borde_gris)


## PlayCry2 tras el fundido; la entrada espera a que termine (estado 9).
func _reproducir_grito() -> void:
	var ruta := RUTA_GRITO % int(entrada_actual().get("nacional", 0))
	if not ResourceLoader.exists(ruta):
		return
	_reproductor_grito.stream = load(ruta) as AudioStream
	_reproductor_grito.play()
	await _reproductor_grito.finished


## Salida de displaydexinfo (sub_8090A3C): sin SE_PC_OFF y fundiendo solo las
## paletas de fondo (0xFFFC). El sprite sigue visible y empieza a deslizarse
## al centro (sub_8090C28); PantallaRegistroCaptura continúa el movimiento
## desde posicion_frente().
func _salir_registro() -> void:
	var tween := create_tween()
	tween.tween_property(_fundido, "modulate:a", 1.0, DURACION_FUNDIDO)
	var acumulado := 0.0
	while tween.is_running():
		await get_tree().process_frame
		acumulado = PantallaRegistroCaptura.deslizar(_frente, acumulado + get_process_delta_time())


func posicion_frente() -> Vector2:
	return _frente.position


func _fundir_a_negro() -> void:
	var tween := create_tween().set_parallel()
	tween.tween_property(_fundido, "modulate:a", 1.0, DURACION_FUNDIDO)
	tween.tween_property(_frente, "modulate", Color.BLACK, DURACION_FUNDIDO)
	await tween.finished


func _unhandled_input(event: InputEvent) -> void:
	# La subpantalla abierta recibe sus propios controles.
	if not is_visible_in_tree() or is_instance_valid(_subpantalla):
		return
	get_viewport().set_input_as_handled()
	if not aceptando_controles or event.is_echo():
		return
	if event.is_action_pressed(&"btn_cancelar"):
		cerrar()
	elif event.is_action_pressed(&"btn_accion"):
		_confirmar()
	elif modo_registro:
		return
	elif event.is_action_pressed(&"btn_izquierda") or event.is_action_pressed(&"btn_derecha"):
		var destino := clampi(seccion + (-1 if event.is_action_pressed(&"btn_izquierda") else 1), Seccion.PAGINA, Seccion.TAMANO)
		if destino != seccion:
			seccion = destino
			_actualizar_botones()
			_reproducir_efecto("SE_DEX_PAGE")
	elif event.is_action_pressed(&"btn_arriba") or event.is_action_pressed(&"btn_abajo"):
		cambiar_especie(-1 if event.is_action_pressed(&"btn_arriba") else 1)


## A en PÁG. alterna la descripción (sub_8090C68, solo capturados). ÁREA y
## GRITO se abren siempre; TAM. solo con captura (si no, SE_FAILURE).
func _confirmar() -> void:
	if modo_registro and en_pagina_2:
		cerrar()
		return
	var capturado := bool(entrada_actual().get("atrapado", false))
	match seccion:
		Seccion.PAGINA:
			if capturado:
				en_pagina_2 = not en_pagina_2
				_pagina_2.visible = en_pagina_2
				_reproducir_efecto("SE_PIN")
		Seccion.AREA, Seccion.GRITO:
			abrir_subpantalla(seccion)
		Seccion.TAMANO:
			if capturado:
				abrir_subpantalla(seccion)
			else:
				_reproducir_efecto("SE_FAILURE")


## TryDoInfoScreenScroll: siguiente especie vista en esa dirección, sin dar la
## vuelta. Fundido, SE_DEX_SCROLL, página 1 y grito de la nueva especie.
func cambiar_especie(direccion: int) -> void:
	if modo_registro:
		return
	var destino := indice + direccion
	while destino >= 0 and destino < entradas.size() and not bool(entradas[destino].get("visto", false)):
		destino += direccion
	if destino < 0 or destino >= entradas.size():
		return
	aceptando_controles = false
	_reproductor_grito.stop()
	_reproducir_efecto("SE_DEX_SCROLL")
	await _fundir_a_negro()
	indice = destino
	_mostrar_especie()
	await _entrar()


## A en una pestaña: SE_PIN, la ficha se funde salvo la barra superior y se
## abre la pestaña.
func abrir_subpantalla(destino: int) -> void:
	if modo_registro:
		return
	aceptando_controles = false
	_reproductor_grito.stop()
	_reproducir_efecto("SE_PIN")
	var tween := create_tween().set_parallel()
	tween.tween_property(_obtener_cortina(), "modulate:a", 1.0, DURACION_FUNDIDO)
	tween.tween_property(_frente, "modulate", Color.BLACK, DURACION_FUNDIDO)
	await tween.finished
	_mostrar_contenido_ficha(false)
	_crear_subpantalla(destino)


func _crear_subpantalla(destino: int) -> void:
	seccion = destino
	_subpantalla = SUBPANTALLAS[destino].instantiate()
	# Por encima de la ficha y debajo de MenuSuperior (z 2).
	_subpantalla.z_index = 1
	_subpantalla.configurar(entrada_actual(), es_chica, _reproducir)
	if destino == Seccion.AREA:
		_subpantalla.seccion_errante = PokedexPartida.seccion_errante()
	_subpantalla.cerrada.connect(_al_cerrar_subpantalla)
	add_child(_subpantalla)
	# La pestaña entra desde negro con su propio fundido y deja ver los fondos.
	_obtener_cortina().modulate.a = 0.0
	_actualizar_botones()


## La pestaña ya está en negro: pasa a otra (izquierda/derecha) o vuelve a la
## ficha, que se reconstruye sin grito (data[3] = 1) con la pestaña resaltada.
func _al_cerrar_subpantalla(destino: int) -> void:
	_obtener_cortina().modulate.a = 1.0
	_subpantalla.queue_free()
	_subpantalla = null
	if destino != Seccion.PAGINA:
		_crear_subpantalla(destino)
		return
	_actualizar_botones()
	_mostrar_contenido_ficha(true)
	var tween := create_tween().set_parallel()
	tween.tween_property(_cortina, "modulate:a", 0.0, DURACION_FUNDIDO)
	tween.tween_property(_frente, "modulate", Color.WHITE, DURACION_FUNDIDO)
	await tween.finished
	aceptando_controles = true


## Las pestañas dejan ver los fondos de la ficha (barra, rayas, franja inferior)
## pero no sus datos.
func _mostrar_contenido_ficha(visible_ficha: bool) -> void:
	_frente.visible = visible_ficha
	_panel.visible = visible_ficha
	$Datos.visible = visible_ficha
	_pagina_2.visible = visible_ficha and en_pagina_2


func _obtener_cortina() -> ColorRect:
	if not is_instance_valid(_cortina):
		_cortina = ColorRect.new()
		_cortina.name = "FundidoBajoBarra"
		_cortina.color = Color.BLACK
		_cortina.size = TAMANO_BASE
		_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_cortina.z_index = 1
		_cortina.modulate.a = 0.0
		add_child(_cortina)
	return _cortina


## B: fundido a negro, SE_PC_OFF y vuelta a la lista en la especie actual.
func cerrar() -> void:
	aceptando_controles = false
	_parpadeo_registro.stop()
	_reproductor_grito.stop()
	if modo_registro:
		await _salir_registro()
	else:
		_reproducir_efecto("SE_PC_OFF")
		await _fundir_a_negro()
	pagina_cerrada.emit(indice)
	if get_tree().current_scene == self:
		get_tree().quit()
