extends Node2D
class_name PantallaCreditos
## Créditos finales (pokeruby src/credits.c, Task_UpdatePage y Task_CreditsTheEnd*): el jugador
## pedalea con la escena de la intro mientras pasan las páginas de BaseDatos/creditos.json;
## después el aviso de copyright y THE END, hasta pulsar un botón.

## Se emite con la pantalla ya en negro.
signal terminada

const RUTA_PAGINAS: String = "res://BaseDatos/creditos.json"
const FOTOGRAMA: float = 1.0 / 60.0
const TEMA_CREDITOS: String = "CREDITOS"
const TEMA_FIN: String = "FINAL"
const FOTOGRAMAS_INICIO: int = 88  # TDB_3 = 0x58
const FOTOGRAMAS_PAGINA: int = 130  # UNK_DEFINE_82
const FOTOGRAMAS_FUNDIDO_TEXTO: int = 16
const FOTOGRAMAS_ANTES_DE_FIN: int = 256  # TDA_12 = 0x100
const FOTOGRAMAS_COPYRIGHT: int = 256  # TDA_0 = 0x100
## TDA_0 pasa de 7200 a 6840: música final a los 6 s de THE END.
const FOTOGRAMAS_HASTA_TEMA_FIN: int = 360
const FOTOGRAMAS_THE_END_MAX: int = 7200
const MITAD_CICLISTA: float = 32.0
const X_CENTRO: float = 120.0
const X_PAREJA_JUGADOR: float = 88.0
const X_PAREJA_RIVAL: float = 152.0
const X_ENTRADA_RIVAL: float = -32.0
const X_SALIDA: float = -64.0
## UNK_DEF_1F3: fotogramas hasta que aparece el rival en el bosque.
const FOTOGRAMAS_ESPERA_RIVAL: int = 0x1F3

@export var ajustes_categoria: LabelSettings
@export var ajustes_nombre: LabelSettings

@onready var _bici: Node2D = $Bicicleteando
@onready var _fondo: FondoBiciCreditos = $Fondo
@onready var _texto: Control = $Texto
@onready var _lineas: Array[Label] = [$Texto/Linea0, $Texto/Linea1, $Texto/Linea2, $Texto/Linea3, $Texto/Linea4]
@onready var _copyright: Sprite2D = $Copyright
@onready var _the_end: Sprite2D = $TheEnd

var _jugador: AnimatedSprite2D
var _rival: AnimatedSprite2D
var _boton_pulsado: bool = false
var _esperando_boton: bool = false


func _ready() -> void:
	var chica: bool = str(SistemaGuardado.datos_vivos.jugador.get("sexo", "M")) == "F"
	_bici.fijar_ciclista(chica)
	_jugador = _bici.get_node("Personaje/Aura" if chica else "Personaje/Bruno")
	_rival = _bici.get_node("Personaje/Bruno" if chica else "Personaje/Aura")
	_colocar(_jugador, X_CENTRO)
	if get_tree().current_scene == self:
		reproducir()


## Muestra la secuencia completa. Debe llamarse con la pantalla en negro.
func reproducir() -> void:
	var datos: Dictionary = _cargar_datos()
	var paginas: Array = datos.get("paginas", [])
	var fondos: Array = datos.get("fondos", [])
	Singleton.reproducir_tema(TEMA_CREDITOS)
	_aplicar_fondo(_fondo_de_pagina(fondos, 0))
	await Singleton.transicion("aclarar")
	await _esperar_fotogramas(FOTOGRAMAS_INICIO)
	for i in paginas.size():
		var cambio: Dictionary = _fondo_de_pagina(fondos, i)
		if i > 0 and not cambio.is_empty():
			await Singleton.transicion("oscurecer")
			_aplicar_fondo(cambio)
			await Singleton.transicion("aclarar")
		await _mostrar_pagina(paginas[i])
	_marcharse()
	await _esperar_fotogramas(FOTOGRAMAS_ANTES_DE_FIN)
	await Singleton.transicion("oscurecer", 0.8)
	_bici.visible = false
	_fondo.visible = false
	_copyright.visible = true
	await Singleton.transicion("aclarar", 0.5)
	await _esperar_fotogramas(FOTOGRAMAS_COPYRIGHT)
	await Singleton.transicion("oscurecer", 0.4)
	_copyright.visible = false
	_the_end.visible = true
	await Singleton.transicion("aclarar", 0.3)
	await _esperar_the_end()
	await Singleton.transicion("oscurecer", 0.5)
	terminada.emit()


func _cargar_datos() -> Dictionary:
	var archivo := FileAccess.open(RUTA_PAGINAS, FileAccess.READ)
	if archivo == null:
		push_error("[CREDITOS] No se pudo abrir %s" % RUTA_PAGINAS)
		return {}
	var datos: Variant = JSON.parse_string(archivo.get_as_text())
	return datos if datos is Dictionary else {}


func _fondo_de_pagina(fondos: Array, pagina: int) -> Dictionary:
	for fondo: Dictionary in fondos:
		if int(fondo.get("pagina", -1)) == pagina:
			return fondo
	return {}


## SetBikeScene: el fondo y dónde va cada ciclista en esa parte de los créditos.
func _aplicar_fondo(cambio: Dictionary) -> void:
	_fondo.mostrar(str(cambio.get("fondo", "")))
	if bool(cambio.get("pareja", false)):
		_colocar(_jugador, X_PAREJA_JUGADOR)
		_mostrar_rival(X_PAREJA_RIVAL)
	elif bool(cambio.get("rival", false)):
		# Casos 3 y 10: el rival entra por la izquierda, un píxel cada 4 fotogramas.
		_colocar(_jugador, X_CENTRO)
		_mostrar_rival(X_ENTRADA_RIVAL)
		var entrada := create_tween()
		entrada.tween_interval(FOTOGRAMAS_ESPERA_RIVAL * FOTOGRAMA)
		entrada.tween_property(_rival, "position:x", X_PAREJA_JUGADOR - MITAD_CICLISTA,
			(X_PAREJA_JUGADOR - X_ENTRADA_RIVAL) * 4.0 * FOTOGRAMA)


func _mostrar_rival(x: float) -> void:
	_colocar(_rival, x)
	_rival.visible = true
	_rival.play(&"pedaleando")


func _colocar(ciclista: Node2D, x: float) -> void:
	ciclista.position.x = x - MITAD_CICLISTA


## Task_BikeScene caso 30: al acabar las páginas ambos se alejan a 1 px por fotograma.
func _marcharse() -> void:
	var salida := create_tween().set_parallel()
	for ciclista: Node2D in [_jugador, _rival]:
		salida.tween_property(ciclista, "position:x", X_SALIDA,
			(ciclista.position.x - X_SALIDA) * FOTOGRAMA)


func _mostrar_pagina(pagina: Array) -> void:
	for i in _lineas.size():
		var entrada: Dictionary = pagina[i] if i < pagina.size() else {}
		_lineas[i].text = str(entrada.get("texto", ""))
		_lineas[i].label_settings = ajustes_categoria if bool(entrada.get("categoria", false)) else ajustes_nombre
	await _fundir_texto(1.0)
	await _esperar_fotogramas(FOTOGRAMAS_PAGINA)
	await _fundir_texto(0.0)


func _fundir_texto(alfa: float) -> void:
	var fundido := create_tween()
	fundido.tween_property(_texto, "modulate:a", alfa, FOTOGRAMAS_FUNDIDO_TEXTO * FOTOGRAMA)
	await fundido.finished


## Task_CreditsTheEnd6: la música final a los 6 s; termina con un botón o a los 2 min.
func _esperar_the_end() -> void:
	_esperando_boton = true
	for transcurridos in FOTOGRAMAS_THE_END_MAX:
		if _boton_pulsado:
			break
		if transcurridos == FOTOGRAMAS_HASTA_TEMA_FIN:
			Singleton.reproducir_tema(TEMA_FIN)
		await get_tree().process_frame
	_esperando_boton = false


func _unhandled_input(event: InputEvent) -> void:
	if _esperando_boton and (event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_cancelar")):
		_boton_pulsado = true
		get_viewport().set_input_as_handled()


func _esperar_fotogramas(n: int) -> void:
	await get_tree().create_timer(n * FOTOGRAMA).timeout
