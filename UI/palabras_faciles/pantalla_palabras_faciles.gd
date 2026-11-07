extends Node2D
class_name PantallaPalabrasFaciles

## Pantalla de PALABRAS FÁCILES (pokeruby src/easy_chat_1.c y easy_chat_2.c).
##
## Arriba, la frase en huecos (2 columnas × 5 filas en una CARTA, 2 × 3 en la
## canción del BARDO) y la barra
## BORRAR / SALIR / VALE; abajo, al elegir un hueco, la ventana de selección:
## grupos (MODO GRUPO) o letras (MODO A-Z), con el menú derecho SELECT MODO /
## BORRAR / BOTÓN B SALIR, y después la lista de palabras del grupo o letra.
##
## Controles (sub_80E75D8, sub_80E77C8, sub_80E7B40):
## - Frase: cruceta mueve por huecos y barra (con vuelta), START salta a VALE,
##   A elige hueco o acción, B = SALIR.
## - Selección: cruceta (izquierda/derecha pasan por el menú derecho), A elige,
##   B cierra, SELECT cambia de modo.
## - Palabras: cruceta, START/SELECT pasan página, A coloca la palabra en el
##   hueco (el cursor no avanza), B vuelve a la selección.
##
## La ventana de selección se despliega como en el original (sub_80E9EA8, sub_80E9F50,
## sub_80E718C); el paso a la lista de palabras sigue siendo un cambio directo del
## fondo. Se crea con la pantalla oscurecida y emite
## `terminada(aceptada, ids)` con la pantalla oscurecida otra vez; sólo al
## aceptar se devuelven las palabras (sub_80E7D9C).

signal terminada(aceptada: bool, ids: Array[int])

## Usos de la pantalla (gSpecialVar_0x8004): CARTA (4), canción del BARDO (6),
## ENTREVISTA de una sola palabra (GABI y TEO 10, CLUB de FANS 7, CONCURSOS 11) y
## REPORTAJE de cuatro palabras para la tele (5: carta del CLUB de FANS e historia
## del MUSEO OCEÁNICO) y EXPRESION de dos palabras (13: la esposa del BAYÓLOGO).
enum Modo { CARTA, BARDO, ENTREVISTA, REPORTAJE, EXPRESION, SALUDO_TORRE }
enum Estado { OCUPADO, FRASE, SELECCION, PALABRAS, MENSAJE, SI_NO }
enum Pregunta { NINGUNA, BORRAR_TODO, SALIR, DEJAR_DE_ESCRIBIR, ACEPTAR }

const ESCENA: String = "res://UI/palabras_faciles/pantalla_palabras_faciles.tscn"
## Columnas de la frase (unk83) si el modo no dice otra cosa.
const COLUMNAS_FRASE: int = 2
## Huecos: x = (5 + col·11) tiles, y = (unk8A + fila·2) tiles (sub_80E9620).
const ORIGEN_HUECO: Vector2 = Vector2(40, 0)
const PASO_HUECO: Vector2 = Vector2(88, 16)
## Por modo (sub_80E6424, sub_80E948C, gUnknown_083DB7C0, sub_80E9368):
## huecos (unkA), filas (unk84), columnas (unk83; ausente = COLUMNAS_FRASE),
## desplazamiento vertical en px (unk8A · 8),
## desplazamiento horizontal en px ((unk88 − 4) · 8; ausente = 0),
## fondos con el marco de la frase, título y textos de la ventana inferior.
const CONFIG_MODOS: Dictionary = {
	Modo.CARTA: {
		"huecos": 9, "filas": 5, "y": 0,
		"fondos": ["res://graficos/palabras_faciles/fondo_frase.png",
			"res://graficos/palabras_faciles/fondo_palabras.png"],
		"titulo": "", "inicio": "PALABRAS_CARTA_INICIO", "confirmar": "PALABRAS_CARTA_CONFIRMAR",
	},
	Modo.BARDO: {
		"huecos": 6, "filas": 3, "y": 24,
		"fondos": ["res://graficos/palabras_faciles/fondo_frase_bardo.png",
			"res://graficos/palabras_faciles/fondo_palabras_bardo.png"],
		"titulo": "PALABRAS_BARDO_TITULO", "inicio": "PALABRAS_BARDO_INICIO", "confirmar": "PALABRAS_BARDO_CONFIRMAR",
	},
	# Tipo 0 (gUnknown_083DB6A4[1]), como la canción del BARDO. Prompts 1 y 7 (gUnknown_083DB7C0).
	Modo.SALUDO_TORRE: {
		"huecos": 6, "filas": 3, "y": 24,
		"fondos": ["res://graficos/palabras_faciles/fondo_frase_bardo.png",
			"res://graficos/palabras_faciles/fondo_palabras_bardo.png"],
		"titulo": "PALABRAS_SALUDO_TITULO", "inicio": "PALABRAS_SALUDO_INICIO", "confirmar": "PALABRAS_SALUDO_CONFIRMAR",
	},
	# Tipo 2 (gUnknown_083DB6A4[10]): una palabra en (17, 4) tiles, unk88 = 16; el
	# marco de 13×4 tiles en (14, 3) (sub_80E9100). Prompts 3 y 13 (gUnknown_083DB7C0).
	Modo.ENTREVISTA: {
		"huecos": 1, "filas": 1, "y": 32, "x": 96, "marco": Vector2(64, 40),
		"fondos": ["res://graficos/palabras_faciles/fondo_frase_entrevista.png",
			"res://graficos/palabras_faciles/fondo_palabras_entrevista.png"],
		"titulo": "PALABRAS_ENTREVISTA_TITULO", "inicio": "PALABRAS_ENTREVISTA_INICIO",
		"confirmar": "PALABRAS_ENTREVISTA_CONFIRMAR",
	},
	# Tipo 5 (gUnknown_083DB6A4[5]): cuatro palabras en una columna desde (16, 2)
	# tiles, unk88 = 16; el marco de 13×8 tiles en (14, 2) (sub_80E9100). Prompts 16
	# y 13 (gUnknown_083DB7C0).
	Modo.REPORTAJE: {
		"huecos": 4, "filas": 4, "columnas": 1, "y": 16, "x": 96, "marco": Vector2(36, 48),
		"fondos": ["res://graficos/palabras_faciles/fondo_frase_reportaje.png",
			"res://graficos/palabras_faciles/fondo_palabras_reportaje.png"],
		"titulo": "PALABRAS_ENTREVISTA_TITULO", "inicio": "PALABRAS_REPORTAJE_INICIO",
		"confirmar": "PALABRAS_ENTREVISTA_CONFIRMAR",
	},
	# Tipo 3 (gUnknown_083DB6A4[13]): dos palabras en la fila 3 de tiles, unk88 = 5; el
	# marco de 24×4 tiles en (3, 2) (sub_80E948C). Prompts 15 y 13 (gUnknown_083DB7C0).
	Modo.EXPRESION: {
		"huecos": 2, "filas": 1, "y": 24, "x": 8,
		"fondos": ["res://graficos/palabras_faciles/fondo_frase_expresion.png",
			"res://graficos/palabras_faciles/fondo_palabras_expresion.png"],
		"titulo": "PALABRAS_EXPRESION_TITULO", "inicio": "PALABRAS_EXPRESION_INICIO",
		"confirmar": "PALABRAS_ENTREVISTA_CONFIRMAR",
	},
}
## sub_80E8BF4: gráfico del entrevistador (0 = REPORTER_M, 1 = REPORTER_F) y del jugador.
const AVATARES_REPORTERO: Array[String] = ["res://escenas/avatares/npc_020.tres", "res://escenas/avatares/npc_021.tres"]
const AVATARES_JUGADOR: Dictionary = {"M": "res://escenas/avatares/rival_bruno.tres", "F": "res://escenas/avatares/rival_aura.tres"}
const Y_PIES_MARCO: float = 12.0
## Ventana de selección en tiles: columnas 1..24 y filas 10..20 abierta; el panel de botones
## ocupa las columnas 24..30 (sub_80EA24C, sub_80EA4A4, sub_80EA704).
const PASOS_ANCHO_VENTANA: int = 6
const PASOS_ALTO_VENTANA: int = 4
const PASOS_PANEL: int = 5
const X_PANEL: float = 192.0
const ANCHO_PANEL: float = 48.0
## Espera con la ventana plegada al cambiar de modo (unk24 de 2 a 8, sub_80E718C).
const FOTOGRAMAS_CAMBIO_MODO: int = 6
## Lista inferior: 4 filas de 16 px desde y = 88 (sub_80EAD08).
const FILAS_VISIBLES: int = 4
const Y_LISTA: int = 88
## Teclado A-Z (gUnknown_083DBEAC): letras por fila; "" = «otros».
const TECLADO: Array = [
	["A", "B", "C", "D", "E", "F", ""],
	["G", "H", "I", "J", "K", "L"],
	["M", "N", "O", "P", "Q", "R", "S"],
	["T", "U", "V", "W", "X", "Y", "Z"],
]
## Columna en tiles de cada tecla (gUnknown_083DBCC4).
const COLUMNA_TECLA: Array = [
	[1, 3, 5, 8, 10, 12, 15],
	[1, 3, 5, 8, 10, 12],
	[1, 3, 5, 8, 10, 12, 14],
	[1, 3, 5, 8, 10, 12, 14],
]
## Opciones del menú derecho (unk1A8 cuando unk1B7 != 0).
const MENU_MODO: int = 1
const MENU_BORRAR: int = 2
const MENU_SALIR: int = 3
## Fotogramas de contorno.png (32×16 cada uno; tileNum / 8 de las animaciones).
const PIEZA_IZQUIERDA: int = 0
const PIEZA_CAJA_MEDIA: int = 2
const PIEZA_LETRA: int = 3
const PIEZA_CENTRO: int = 4
const PIEZA_DERECHA: int = 6
## Indicador (gSpriteAnimTable_83DBDCC): fotograma 0 = MODO A-Z, 1 = MODO GRUPO.
const INDICADOR_ABC: int = 0
const INDICADOR_GRUPO: int = 1
## Globo pequeño y fotograma vacío de indicador.png (gSpriteAnimTable_83DBDCC).
const INDICADOR_PEQUENO: int = 2
const INDICADOR_VACIO: int = 3
## Triángulos: x2 de −6 a 0, +1 cada 3 fotogramas (sub_80E82BC).
const FOTOGRAMAS_TRIANGULO: int = 3
const FOTOGRAMA: float = 1.0 / 60.0

@onready var spr_fondo: Sprite2D = $Fondo
@onready var lb_titulo: Label = $Titulo
@onready var nd_huecos: Node2D = $Huecos
@onready var nd_previa: Node2D = $Previa
@onready var spr_marco: Sprite2D = $MarcoEntrevista
@onready var spr_jugador_marco: AnimatedSprite2D = $MarcoEntrevista/Jugador
@onready var spr_reportero_marco: AnimatedSprite2D = $MarcoEntrevista/Reportero
@onready var spr_panel: Sprite2D = $PanelBotones
@onready var nd_ventana_sel: NinePatchRect = $VentanaSeleccion
@onready var nd_lista: Node2D = $VentanaSeleccion/Lista
@onready var nd_teclado: Node2D = $VentanaSeleccion/Teclado
@onready var spr_triangulo_frase: Sprite2D = $TrianguloFrase
@onready var spr_triangulo_lista: Sprite2D = $TrianguloLista
@onready var nd_contorno: Node2D = $Contorno
@onready var spr_contorno_a: Sprite2D = $Contorno/A
@onready var spr_contorno_b: Sprite2D = $Contorno/B
@onready var spr_contorno_c: Sprite2D = $Contorno/C
@onready var spr_flecha_arriba: Sprite2D = $FlechaArriba
@onready var spr_flecha_abajo: Sprite2D = $FlechaAbajo
@onready var nd_botones: Node2D = $Botones
@onready var spr_indicador: Sprite2D = $Indicador
@onready var nd_ventana: NinePatchRect = $Ventana
@onready var lb_mensaje: Label = $Ventana/Texto
@onready var nd_si_no: NinePatchRect = $SiNo
@onready var nd_cursor_si_no: Control = $SiNo/Cursor

var modo: Modo = Modo.CARTA
var estado: Estado = Estado.OCUPADO
## Geometría del modo (CONFIG_MODOS); la barra es la fila siguiente a la frase.
var total_huecos: int = 9
var filas_frase: int = 5
var columnas_frase: int = COLUMNAS_FRASE
var fila_barra: int = 5
var desplazamiento_y: int = 0
var desplazamiento_x: int = 0
var _fondo_frase: Texture2D = null
var _fondo_palabras: Texture2D = null
## Copia de trabajo de la frase (unkC) y la original (unk4).
var ids: Array[int] = []
var ids_originales: Array[int] = []

## Cursor de la frase (unk86 / unk85); fila 5 = barra de acciones.
var fila_frase: int = 0
var col_frase: int = 0
## Hueco que se está editando (unk27).
var hueco_editado: int = 0

## Selección: false = MODO GRUPO, true = MODO A-Z (unk26; se conserva al reabrir).
var modo_abc: bool = false
## Grupos visibles en orden (unk2A, sub_80E6554).
var grupos_visibles: Array[int] = []
## Palabras por letra (índice 0 = «otros», 1..26 = A..Z; sub_80EAECC).
var palabras_por_letra: Array = []
var fila_sel: int = 0
var col_sel: int = 0
var top_sel: int = 0
## Menú derecho activo (unk1B7) y su opción (1..3).
var en_menu: bool = false
var opcion_menu: int = MENU_MODO

## Lista de palabras del grupo o letra elegidos (sub_80E68E8).
var palabras_lista: Array[int] = []
var fila_pal: int = 0
var col_pal: int = 0
var top_pal: int = 0

var pregunta: Pregunta = Pregunta.NINGUNA
var indice_si_no: int = 0
var _retorno_mensaje: Estado = Estado.FRASE
## Al cerrar el mensaje se recupera la frase original (BARDO, sub_80E6D7C 102).
var _restaurar_al_cerrar: bool = false
var _tiempo: float = 0.0
var _fase_contorno: float = 0.0
## Las ventanas se despliegan (solo al abrir de verdad; `preparar` a secas, sin animar).
var _animar: bool = false
## Hay una animación de ventana en curso: la entrada espera.
var _animando: bool = false


func _ready() -> void:
	nd_si_no.visible = false
	(nd_teclado.get_node("Fila0/Otros") as Label).text = tr("PALABRAS_OTROS")
	_mostrar_seleccion(false)
	# Ejecutada sola (F6): carta vacía.
	if get_tree().current_scene == self:
		scale = Vector2(3, 3)
		abrir(Modo.CARTA, [])


## Common_EventScript_ShowEasyChatScreen desde un guion del mapa: cierra el cuadro de
## diálogo, oscurece, abre la pantalla en la capa del menú y, al salir, aclara.
## Devuelve las palabras aceptadas o [] si se cancela (o no hay capa del menú).
static func escribir(desde: Node, modo_pantalla: Modo, frase: Array[int] = [], reportero: int = 0) -> Array[int]:
	var vacia: Array[int] = []
	var raiz := desde.get_tree().root
	var capa: Node = raiz.get_node_or_null("AdministradorMapa/Menu")
	if capa == null:
		return vacia
	var cuadro: Variant = raiz.get_node("AdministradorMapa").get("cuadro_dialogo")
	if cuadro != null:
		cuadro.cerrar()
	await Singleton.transicion("oscurecer")
	var pantalla := (load(ESCENA) as PackedScene).instantiate() as PantallaPalabrasFaciles
	pantalla.z_index = 6
	capa.add_child(pantalla)
	pantalla.abrir(modo_pantalla, frase, reportero)
	var resultado: Array = await pantalla.terminada
	pantalla.queue_free()
	await Singleton.transicion("aclarar")
	if not bool(resultado[0]):
		return vacia
	var ids: Array[int] = []
	ids.assign(resultado[1])
	return ids


## Abre la pantalla con la frase `frase` (se completa con huecos vacíos) y
## aclara (sub_80E62F8). Se llama con la pantalla oscurecida.
func abrir(modo_pantalla: Modo, frase: Array[int], reportero: int = 0) -> void:
	preparar(modo_pantalla, frase, reportero)
	_animar = true
	visible = true
	await Singleton.transicion("aclarar")
	estado = Estado.FRASE


## Estado inicial sin transiciones (también lo usan los tests).
func preparar(modo_pantalla: Modo, frase: Array[int], reportero: int = 0) -> void:
	_configurar_modo(modo_pantalla, reportero)
	ids.clear()
	for i in total_huecos:
		ids.append(frase[i] if i < frase.size() else PalabrasFaciles.PALABRA_VACIA)
	ids_originales = ids.duplicate()
	fila_frase = 0
	col_frase = 0
	modo_abc = false
	pregunta = Pregunta.NINGUNA
	_restaurar_al_cerrar = false
	_calcular_grupos_visibles()
	_calcular_palabras_por_letra()
	_pintar_huecos()
	_volver_a_frase()
	estado = Estado.FRASE


## Geometría, fondos y título del modo; los huecos y líneas que sobran se ocultan.
func _configurar_modo(modo_pantalla: Modo, reportero: int = 0) -> void:
	modo = modo_pantalla
	var config: Dictionary = CONFIG_MODOS[modo]
	total_huecos = int(config["huecos"])
	filas_frase = int(config["filas"])
	columnas_frase = int(config.get("columnas", COLUMNAS_FRASE))
	fila_barra = filas_frase
	desplazamiento_y = int(config["y"])
	desplazamiento_x = int(config.get("x", 0))
	var fondos: Array = config["fondos"]
	_fondo_frase = load(fondos[0]) as Texture2D
	_fondo_palabras = load(fondos[1]) as Texture2D
	spr_marco.visible = config.has("marco")
	if spr_marco.visible:
		spr_marco.position = config["marco"]
		var sexo := str(SistemaGuardado.datos_vivos.jugador.get("sexo", "M"))
		_vestir_marco(spr_jugador_marco, str(AVATARES_JUGADOR.get(sexo, AVATARES_JUGADOR["M"])), &"camina_derecha_1")
		_vestir_marco(spr_reportero_marco, AVATARES_REPORTERO[clampi(reportero, 0, 1)], &"camina_izquierda_1")
	var titulo: String = config["titulo"]
	lb_titulo.text = "" if titulo.is_empty() else tr(titulo)
	nd_huecos.position = Vector2(desplazamiento_x, desplazamiento_y)
	nd_previa.position = Vector2(desplazamiento_x, desplazamiento_y)
	for i in nd_huecos.get_child_count():
		var hueco := nd_huecos.get_child(i) as Node2D
		hueco.visible = i < total_huecos
		hueco.position = ORIGEN_HUECO + Vector2(i % columnas_frase, floori(float(i) / columnas_frase)) * PASO_HUECO
	for i in nd_previa.get_child_count():
		(nd_previa.get_child(i) as CanvasItem).visible = i < filas_frase


func _vestir_marco(sprite: AnimatedSprite2D, avatar: String, animacion: StringName) -> void:
	sprite.sprite_frames = load(avatar) as SpriteFrames
	sprite.animation = animacion
	sprite.frame = 0
	# Los avatares tienen distinto alto: todos pisan la misma línea, como los 16×32 de Rubí.
	sprite.offset.y = Y_PIES_MARCO - sprite.sprite_frames.get_frame_texture(animacion, 0).get_height() / 2.0


## sub_80E7FA8: huecos cuyo texto difiere entre `a` y `b` (compara la grafía,
## no el id: la misma palabra en otro grupo no cuenta como cambio).
static func contar_cambios(a: Array[int], b: Array[int]) -> int:
	var cambios: int = 0
	for i in maxi(a.size(), b.size()):
		var texto_a: String = PalabrasFaciles.texto(a[i]) if i < a.size() else ""
		var texto_b: String = PalabrasFaciles.texto(b[i]) if i < b.size() else ""
		if texto_a != texto_b:
			cambios += 1
	return cambios


func cambios() -> int:
	return contar_cambios(ids_originales, ids)


# ─── Datos ───────────────────────────────────────────────────────────────────

## sub_80E6554: grupos 0..16 siempre; 17..21 si están desbloqueados.
func _calcular_grupos_visibles() -> void:
	grupos_visibles.clear()
	for fila: Dictionary in PalabrasFaciles.grupos():
		var grupo: int = int(fila.get("id", -1))
		if grupo < PalabrasFaciles.GRUPO_EVENTS or PalabrasFaciles.grupo_desbloqueado(grupo):
			grupos_visibles.append(grupo)
	grupos_visibles.sort()


## sub_80EAECC: palabras elegibles agrupadas por su primera letra (sin ¡ ¿ ni
## tildes) y en orden alfabético; las que no empiezan por letra van a «otros».
## Con la misma grafía en varios grupos sólo entra la primera (EC_DUPLICATES).
func _calcular_palabras_por_letra() -> void:
	palabras_por_letra.clear()
	for i in 27:
		palabras_por_letra.append([])
	var vistas: Dictionary = {}
	for grupo: int in grupos_visibles:
		for id_palabra: int in PalabrasFaciles.palabras_disponibles(grupo):
			var texto: String = PalabrasFaciles.texto(id_palabra)
			if vistas.has(texto):
				continue
			vistas[texto] = true
			(palabras_por_letra[indice_letra(texto)] as Array).append(id_palabra)
	for i in palabras_por_letra.size():
		var cubo: Array[int] = []
		cubo.assign(palabras_por_letra[i])
		palabras_por_letra[i] = ordenar_palabras(cubo)


## 1..26 para A..Z según la primera letra (Ñ cuenta como N); 0 = «otros».
static func indice_letra(texto: String) -> int:
	var clave: String = clave_orden(texto)
	if clave.is_empty():
		return 0
	var codigo: int = clave.unicode_at(0)
	if codigo >= 65 and codigo <= 90:
		return codigo - 64
	return 0


## Texto para ordenar y clasificar: mayúsculas, sin ¡ ¿ iniciales ni tildes.
static func clave_orden(texto: String) -> String:
	var clave: String = texto.to_upper().lstrip("¡¿")
	for par: Array in [["Á", "A"], ["É", "E"], ["Í", "I"], ["Ó", "O"], ["Ú", "U"], ["Ü", "U"], ["Ñ", "N~"]]:
		clave = clave.replace(par[0], par[1])
	return clave


## Orden alfabético (gEasyChatGroupOrders / gEasyChatWordsAlphabetized).
static func ordenar_palabras(lista: Array[int]) -> Array[int]:
	var ordenada: Array[int] = lista.duplicate()
	ordenada.sort_custom(func(a: int, b: int) -> bool:
		return clave_orden(PalabrasFaciles.texto(a)) < clave_orden(PalabrasFaciles.texto(b)))
	return ordenada


## Palabras de la tecla (fila, col) del teclado.
func palabras_de_tecla(fila: int, col: int) -> Array:
	var letra: String = TECLADO[fila][col]
	return palabras_por_letra[0 if letra.is_empty() else letra.unicode_at(0) - 64]


# ─── Entrada ─────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible or not is_inside_tree() or _animando:
		return
	match estado:
		Estado.FRASE:
			_input_frase(event)
		Estado.SELECCION:
			_input_seleccion(event)
		Estado.PALABRAS:
			_input_palabras(event)
		Estado.MENSAJE:
			if event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_cancelar"):
				get_viewport().set_input_as_handled()
				_sonido()
				_cerrar_mensaje()
		Estado.SI_NO:
			_input_si_no(event)


func _pulsado(event: InputEvent, accion: String) -> bool:
	return event.is_action_pressed(accion, true)


## sub_80E75D8.
func _input_frase(event: InputEvent) -> void:
	if _pulsado(event, "btn_arriba"):
		fila_frase = posmod(fila_frase - 1, fila_barra + 1)
		_ajustar_columna_frase()
	elif _pulsado(event, "btn_abajo"):
		fila_frase = posmod(fila_frase + 1, fila_barra + 1)
		_ajustar_columna_frase()
	elif _pulsado(event, "btn_izquierda"):
		col_frase = posmod(col_frase - 1, _columnas_frase(fila_frase))
	elif _pulsado(event, "btn_derecha"):
		col_frase = posmod(col_frase + 1, _columnas_frase(fila_frase))
	elif event.is_action_pressed("btn_menu"):
		fila_frase = fila_barra
		col_frase = 2
	elif event.is_action_pressed("btn_accion"):
		get_viewport().set_input_as_handled()
		_sonido()
		elegir_en_frase()
		return
	elif event.is_action_pressed("btn_cancelar"):
		get_viewport().set_input_as_handled()
		_sonido()
		_preguntar_salir()
		return
	else:
		return
	get_viewport().set_input_as_handled()
	_sonido()
	_colocar_triangulo_frase()


func _columnas_frase(fila: int) -> int:
	if fila == fila_barra:
		return 3
	return mini(columnas_frase, total_huecos - fila * columnas_frase)


func _ajustar_columna_frase() -> void:
	col_frase = mini(col_frase, _columnas_frase(fila_frase) - 1)


## A en la frase: hueco → selección; barra → BORRAR / SALIR / VALE.
func elegir_en_frase() -> void:
	if fila_frase < fila_barra:
		hueco_editado = fila_frase * columnas_frase + col_frase
		abrir_seleccion()
		return
	match col_frase:
		0:
			# sub_80E6BC0: la canción del BARDO no se puede borrar entera.
			if modo == Modo.BARDO:
				_mostrar_mensaje(tr("PALABRAS_NO_BORRAR_TODO"), Estado.FRASE)
			else:
				_preguntar(Pregunta.BORRAR_TODO, tr("PALABRAS_BORRAR_TODO"), 1)
		1:
			_preguntar_salir()
		_:
			aceptar()


## sub_80E77C8.
func _input_seleccion(event: InputEvent) -> void:
	if _pulsado(event, "btn_arriba"):
		if not _mover_seleccion_vertical(-1):
			return
	elif _pulsado(event, "btn_abajo"):
		if not _mover_seleccion_vertical(1):
			return
	elif _pulsado(event, "btn_izquierda"):
		_mover_seleccion_horizontal(-1)
	elif _pulsado(event, "btn_derecha"):
		_mover_seleccion_horizontal(1)
	elif event.is_action_pressed("btn_select"):
		get_viewport().set_input_as_handled()
		_sonido()
		cambiar_modo()
		return
	elif event.is_action_pressed("btn_accion"):
		get_viewport().set_input_as_handled()
		elegir_en_seleccion()
		return
	elif event.is_action_pressed("btn_cancelar"):
		get_viewport().set_input_as_handled()
		_sonido()
		cerrar_seleccion()
		return
	else:
		return
	get_viewport().set_input_as_handled()
	_sonido()
	_actualizar_seleccion()


func _filas_seleccion() -> int:
	return TECLADO.size() if modo_abc else ceili(grupos_visibles.size() / 2.0)


func _columnas_seleccion(fila: int) -> int:
	if modo_abc:
		return (TECLADO[fila] as Array).size()
	return mini(2, grupos_visibles.size() - fila * 2)


## Devuelve false si no hubo movimiento (en MODO GRUPO no hay vuelta).
func _mover_seleccion_vertical(direccion: int) -> bool:
	if en_menu:
		opcion_menu = posmod(opcion_menu - MENU_MODO + direccion, 3) + MENU_MODO
		return true
	if modo_abc:
		fila_sel = posmod(fila_sel + direccion, TECLADO.size())
	else:
		var nueva: int = fila_sel + direccion
		if nueva < 0 or nueva >= _filas_seleccion():
			return false
		fila_sel = nueva
		if fila_sel < top_sel:
			top_sel = fila_sel
		elif fila_sel >= top_sel + FILAS_VISIBLES:
			top_sel = fila_sel - FILAS_VISIBLES + 1
	col_sel = mini(col_sel, _columnas_seleccion(fila_sel) - 1)
	return true


## Izquierda/derecha: la columna «nº de columnas» es el menú derecho.
func _mover_seleccion_horizontal(direccion: int) -> void:
	var columnas: int = _columnas_seleccion(fila_sel)
	if en_menu:
		en_menu = false
		col_sel = 0 if direccion > 0 else columnas - 1
		return
	var nueva: int = col_sel + direccion
	if nueva < 0 or nueva >= columnas:
		en_menu = true
		opcion_menu = clampi(fila_sel - top_sel, MENU_MODO, MENU_SALIR)
		return
	col_sel = nueva


## A en la selección: menú derecho, grupo o letra.
func elegir_en_seleccion() -> void:
	if en_menu:
		_sonido()
		match opcion_menu:
			MENU_MODO:
				cambiar_modo()
			MENU_BORRAR:
				# En la canción del BARDO no hace nada (sub_80E6FC8).
				if modo != Modo.BARDO:
					ids[hueco_editado] = PalabrasFaciles.PALABRA_VACIA
					_pintar_huecos()
			_:
				cerrar_seleccion()
		return
	var lista: Array[int] = []
	if modo_abc:
		lista.assign(palabras_de_tecla(fila_sel, col_sel))
	else:
		lista = ordenar_palabras(PalabrasFaciles.palabras_disponibles(grupos_visibles[fila_sel * 2 + col_sel]))
	# Las letras sin palabras no responden (unk4142[letra] == 0).
	if lista.is_empty():
		return
	_sonido()
	abrir_palabras(lista)


## sub_80E7B40.
func _input_palabras(event: InputEvent) -> void:
	var filas: int = _filas_palabras()
	if _pulsado(event, "btn_arriba"):
		if fila_pal == 0:
			return
		fila_pal -= 1
		top_pal = mini(top_pal, fila_pal)
	elif _pulsado(event, "btn_abajo"):
		if fila_pal >= filas - 1:
			return
		fila_pal += 1
		if fila_pal >= top_pal + FILAS_VISIBLES:
			top_pal = fila_pal - FILAS_VISIBLES + 1
	elif _pulsado(event, "btn_izquierda") or _pulsado(event, "btn_derecha"):
		if _columnas_palabras(fila_pal) < 2:
			return
		col_pal = 1 - col_pal
	elif _pulsado(event, "btn_menu"):
		if not pasar_pagina(-1):
			return
	elif _pulsado(event, "btn_select"):
		if not pasar_pagina(1):
			return
	elif event.is_action_pressed("btn_accion"):
		get_viewport().set_input_as_handled()
		_sonido()
		elegir_palabra()
		return
	elif event.is_action_pressed("btn_cancelar"):
		get_viewport().set_input_as_handled()
		_sonido()
		volver_a_seleccion()
		return
	else:
		return
	get_viewport().set_input_as_handled()
	_sonido()
	col_pal = mini(col_pal, _columnas_palabras(fila_pal) - 1)
	_pintar_palabras()


func _filas_palabras() -> int:
	return ceili(palabras_lista.size() / 2.0)


func _columnas_palabras(fila: int) -> int:
	return mini(2, palabras_lista.size() - fila * 2)


## START (−1) / SELECT (+1): hasta 4 filas, sin salir de la lista.
func pasar_pagina(direccion: int) -> bool:
	var max_top: int = maxi(0, _filas_palabras() - FILAS_VISIBLES)
	var paso: int = mini(FILAS_VISIBLES, top_pal) if direccion < 0 else mini(FILAS_VISIBLES, max_top - top_pal)
	if paso <= 0:
		return false
	top_pal += paso * direccion
	fila_pal = clampi(fila_pal + paso * direccion, 0, _filas_palabras() - 1)
	return true


## sub_80E7324: la palabra va al hueco y se vuelve a la frase. En la canción
## del BARDO, si cambió la letra, se pasa directamente a confirmarla.
func elegir_palabra() -> void:
	var indice: int = fila_pal * 2 + col_pal
	if indice < palabras_lista.size():
		ids[hueco_editado] = palabras_lista[indice]
	_pintar_huecos()
	_volver_a_frase()
	if modo == Modo.BARDO and cambios() != 0:
		aceptar()


func _input_si_no(event: InputEvent) -> void:
	if event.is_action_pressed("btn_arriba") or event.is_action_pressed("btn_abajo"):
		var nuevo: int = 1 - indice_si_no
		if (event.is_action_pressed("btn_arriba") and indice_si_no == 0) \
				or (event.is_action_pressed("btn_abajo") and indice_si_no == 1):
			get_viewport().set_input_as_handled()
			return
		indice_si_no = nuevo
		_sonido()
		_colocar_cursor_si_no()
	elif event.is_action_pressed("btn_accion"):
		_sonido()
		responder(indice_si_no == 0)
	elif event.is_action_pressed("btn_cancelar"):
		_sonido()
		responder(false)
	else:
		return
	get_viewport().set_input_as_handled()


# ─── Frase: acciones de la barra ─────────────────────────────────────────────

## sub_80E6C84: en una CARTA, una sola pregunta; en la canción del BARDO,
## «¿Dejas de escribir?» y luego «no se guardará»; en la ENTREVISTA, sólo
## «¿Dejas de escribir?» (gOtherText_QuitEditing). NO por defecto en todas.
func _preguntar_salir() -> void:
	if modo == Modo.BARDO or modo == Modo.SALUDO_TORRE:
		_preguntar(Pregunta.DEJAR_DE_ESCRIBIR, tr("PALABRAS_DEJAR_DE_ESCRIBIR"), 1)
	elif modo == Modo.ENTREVISTA or modo == Modo.REPORTAJE or modo == Modo.EXPRESION:
		_preguntar(Pregunta.SALIR, tr("PALABRAS_DEJAR_DE_ESCRIBIR"), 1)
	else:
		_preguntar(Pregunta.SALIR, tr("PALABRAS_CARTA_CANCELAR"), 1)


## sub_80E6D7C: frase vacía → aviso; CARTA sin cambios → como SALIR; si no,
## vista previa y «¿es esto?» con SÍ por defecto.
func aceptar() -> void:
	if frase_vacia():
		_mostrar_mensaje(tr("PALABRAS_FRASE_VACIA"), Estado.FRASE)
		return
	if modo == Modo.CARTA and ids == ids_originales:
		_preguntar_salir()
		return
	_pintar_previa(true)
	_preguntar(Pregunta.ACEPTAR, tr(str(CONFIG_MODOS[modo]["confirmar"])), 0)


func frase_vacia() -> bool:
	for id_palabra: int in ids:
		if id_palabra != PalabrasFaciles.PALABRA_VACIA:
			return false
	return true


func responder(si: bool) -> void:
	nd_si_no.visible = false
	var actual: Pregunta = pregunta
	pregunta = Pregunta.NINGUNA
	match actual:
		Pregunta.BORRAR_TODO:
			if si:
				for i in ids.size():
					ids[i] = PalabrasFaciles.PALABRA_VACIA
				_pintar_huecos()
		Pregunta.DEJAR_DE_ESCRIBIR:
			if si:
				_preguntar(Pregunta.SALIR, tr("PALABRAS_NO_SE_GUARDARA"), 1)
				return
		Pregunta.SALIR:
			if si:
				terminar(false)
				return
		Pregunta.ACEPTAR:
			_pintar_previa(false)
			if si:
				terminar(true)
				return
			# BARDO con la letra cambiada: aviso y vuelta a la canción original.
			if modo == Modo.BARDO and cambios() != 0:
				_restaurar_al_cerrar = true
				_mostrar_mensaje(tr("PALABRAS_BARDO_UN_ELEMENTO"), Estado.FRASE)
				return
	_volver_a_frase()


## sub_80E752C: fundido a negro y vuelta a quien abrió la pantalla.
func terminar(aceptada: bool) -> void:
	estado = Estado.OCUPADO
	var resultado: Array[int] = ids.duplicate() if aceptada else ids_originales.duplicate()
	await Singleton.transicion("oscurecer")
	visible = false
	terminada.emit(aceptada, resultado)


# ─── Transiciones entre ventanas ─────────────────────────────────────────────

## sub_80E6AC4: cursor en la frase y el mensaje inicial.
func _volver_a_frase() -> void:
	_mostrar_seleccion(false)
	spr_fondo.texture = _fondo_frase
	spr_triangulo_frase.visible = true
	_colocar_triangulo_frase()
	_mostrar_texto_ventana(tr(str(CONFIG_MODOS[modo]["inicio"])))
	estado = Estado.FRASE


## sub_80E6F68 / sub_80E683C: cursor al principio; el modo se conserva.
func abrir_seleccion() -> void:
	fila_sel = 0
	col_sel = 0
	top_sel = 0
	en_menu = false
	nd_ventana.visible = false
	spr_triangulo_frase.visible = true
	_colocar_triangulo_frase()
	_mostrar_seleccion(true)
	_actualizar_seleccion()
	estado = Estado.SELECCION
	if _animar:
		_animar_apertura()


## sub_80E7114: cierra la selección; el cursor sigue en el mismo hueco.
func cerrar_seleccion() -> void:
	_volver_a_frase()
	if _animar:
		_animar_cierre()


## sub_80E718C: alterna MODO GRUPO / MODO A-Z con el cursor al principio.
func cambiar_modo() -> void:
	modo_abc = not modo_abc
	fila_sel = 0
	col_sel = 0
	top_sel = 0
	en_menu = false
	if _animar:
		_animar_cambio_modo()
	else:
		_actualizar_seleccion()


## sub_80E7218 / sub_80E68E8: lista de palabras con el cursor al principio.
func abrir_palabras(lista: Array[int]) -> void:
	palabras_lista = lista
	fila_pal = 0
	col_pal = 0
	top_pal = 0
	spr_fondo.texture = _fondo_palabras
	_mostrar_seleccion(false)
	# La lista cubre otra zona: la ventana solo la contiene, sin dibujarse ni recortar.
	nd_ventana_sel.visible = true
	nd_ventana_sel.self_modulate.a = 0.0
	_fijar_ventana(Rect2(0, 0, 240, 160))
	nd_lista.visible = true
	spr_triangulo_frase.visible = true
	spr_triangulo_lista.visible = true
	nd_botones.visible = true
	_pintar_palabras()
	estado = Estado.PALABRAS


## sub_80E73D0: de la lista a la selección, conservando su cursor.
func volver_a_seleccion() -> void:
	spr_fondo.texture = _fondo_frase
	spr_triangulo_lista.visible = false
	nd_botones.visible = false
	_mostrar_seleccion(true)
	_actualizar_seleccion()
	estado = Estado.SELECCION


# ─── Dibujo ──────────────────────────────────────────────────────────────────

## sub_80E95A4: cada hueco muestra su palabra o 5 guiones si está vacío.
func _pintar_huecos() -> void:
	for i in nd_huecos.get_child_count():
		var hueco: Node2D = nd_huecos.get_child(i) as Node2D
		var vacio: bool = i >= ids.size() or ids[i] == PalabrasFaciles.PALABRA_VACIA
		(hueco.get_node("Texto") as Label).text = "" if vacio else PalabrasFaciles.texto(ids[i])
		(hueco.get_node("Guiones") as CanvasItem).visible = vacio


## sub_80E97C0: vista previa de ACEPTAR (palabras de cada fila juntas).
func _pintar_previa(mostrar: bool) -> void:
	nd_huecos.visible = not mostrar
	nd_previa.visible = mostrar
	spr_triangulo_frase.visible = not mostrar
	if not mostrar:
		return
	for fila in filas_frase:
		var linea: Array = []
		for col in _columnas_frase(fila):
			linea.append(ids[fila * columnas_frase + col])
		(nd_previa.get_child(fila) as Label).text = PalabrasFaciles.frase(linea)


func _mostrar_seleccion(mostrar: bool) -> void:
	nd_ventana_sel.visible = mostrar
	nd_ventana_sel.self_modulate.a = 1.0
	spr_panel.visible = mostrar
	_fijar_ventana(_rect_ventana(PASOS_ANCHO_VENTANA, PASOS_ALTO_VENTANA))
	spr_panel.position.x = X_PANEL
	nd_lista.visible = mostrar and not modo_abc
	nd_teclado.visible = mostrar and modo_abc
	nd_contorno.visible = mostrar
	spr_indicador.visible = mostrar
	spr_flecha_arriba.visible = false
	spr_flecha_abajo.visible = false
	spr_triangulo_lista.visible = false
	nd_botones.visible = false


func _actualizar_seleccion() -> void:
	nd_lista.visible = not modo_abc
	nd_teclado.visible = modo_abc
	if not _animando:
		spr_indicador.frame = _fotograma_indicador()
	if not modo_abc:
		for fila in FILAS_VISIBLES:
			for col in 2:
				var indice: int = (top_sel + fila) * 2 + col
				var texto: String = PalabrasFaciles.nombre_grupo(grupos_visibles[indice]) if indice < grupos_visibles.size() else ""
				_etiqueta_lista(fila, col, texto, 16 + col * 88)
	_colocar_flechas(top_sel, maxi(0, _filas_seleccion() - FILAS_VISIBLES), 100, 0, not modo_abc)
	_colocar_contorno()


func _fotograma_indicador() -> int:
	return INDICADOR_ABC if modo_abc else INDICADOR_GRUPO


# ─── Animaciones de la ventana de selección ──────────────────────────────────

## Rectángulo tras `ancho` pasos de sub_80EA24C (2 tiles por lado) y `alto` de sub_80EA4A4
## (1 tile por lado): desde una tira de 2 filas en el centro hasta las columnas 1..24 y las
## filas 10..20.
static func _rect_ventana(ancho: int, alto: int) -> Rect2:
	return Rect2((13 - 2 * ancho) * 8, (14 - alto) * 8, (4 * ancho - 1) * 8, (2 + 2 * alto) * 8)


## La ventana recorta su contenido, que conserva sus coordenadas de pantalla.
func _fijar_ventana(rect: Rect2) -> void:
	nd_ventana_sel.position = rect.position
	nd_ventana_sel.size = rect.size
	nd_lista.position = -rect.position
	nd_teclado.position = -rect.position


## Panel con `pasos` columnas a la vista: asoma por detrás de la ventana (sub_80EA704).
func _fijar_panel(pasos: int) -> void:
	spr_panel.position.x = X_PANEL - ANCHO_PANEL + (pasos + 1) * 8


func _ocultar_cursor_seleccion() -> void:
	nd_contorno.visible = false
	spr_flecha_arriba.visible = false
	spr_flecha_abajo.visible = false


func _esperar_fotogramas(fotogramas: int) -> void:
	await get_tree().create_timer(fotogramas * FOTOGRAMA).timeout


## sub_80E9EA8: se ensancha, crece en alto y sale el panel; después el globo y el cursor.
func _animar_apertura() -> void:
	_animando = true
	_ocultar_cursor_seleccion()
	spr_indicador.visible = false
	spr_panel.visible = false
	for ancho in range(1, PASOS_ANCHO_VENTANA + 1):
		_fijar_ventana(_rect_ventana(ancho, 0))
		await _esperar_fotogramas(1)
	for alto in range(1, PASOS_ALTO_VENTANA + 1):
		_fijar_ventana(_rect_ventana(PASOS_ANCHO_VENTANA, alto))
		await _esperar_fotogramas(1)
	spr_panel.visible = true
	for pasos in range(PASOS_PANEL + 1):
		_fijar_panel(pasos)
		await _esperar_fotogramas(1)
	# gSpriteAnim_83DBDA8 / 83DBDB4: globo pequeño 2 fotogramas y el modo.
	spr_indicador.visible = true
	spr_indicador.frame = INDICADOR_PEQUENO
	await _esperar_fotogramas(2)
	_terminar_animacion_seleccion()


## sub_80E9F50: el panel se esconde, baja el alto y se estrecha hasta desaparecer.
func _animar_cierre() -> void:
	_animando = true
	var mensaje_visible: bool = nd_ventana.visible
	nd_ventana.visible = false
	nd_ventana_sel.visible = true
	spr_panel.visible = true
	# gSpriteAnim_83DBDC0: globo pequeño y vacío.
	spr_indicador.visible = true
	spr_indicador.frame = INDICADOR_PEQUENO
	for pasos in range(PASOS_PANEL, -1, -1):
		_fijar_panel(pasos)
		if pasos == PASOS_PANEL - 2:
			spr_indicador.visible = false
		await _esperar_fotogramas(1)
	spr_panel.visible = false
	for alto in range(PASOS_ALTO_VENTANA - 1, -1, -1):
		_fijar_ventana(_rect_ventana(PASOS_ANCHO_VENTANA, alto))
		await _esperar_fotogramas(1)
	for ancho in range(PASOS_ANCHO_VENTANA - 1, 0, -1):
		_fijar_ventana(_rect_ventana(ancho, 0))
		await _esperar_fotogramas(1)
	nd_ventana_sel.visible = false
	_fijar_ventana(_rect_ventana(PASOS_ANCHO_VENTANA, PASOS_ALTO_VENTANA))
	spr_panel.position.x = X_PANEL
	nd_ventana.visible = mensaje_visible
	_animando = false


## sub_80E718C: la ventana se pliega, cambia el contenido y se despliega; el panel no se mueve.
func _animar_cambio_modo() -> void:
	_animando = true
	_ocultar_cursor_seleccion()
	_parpadear_indicador()
	for alto in range(PASOS_ALTO_VENTANA - 1, -1, -1):
		_fijar_ventana(_rect_ventana(PASOS_ANCHO_VENTANA, alto))
		await _esperar_fotogramas(1)
	_actualizar_seleccion()
	_ocultar_cursor_seleccion()
	await _esperar_fotogramas(FOTOGRAMAS_CAMBIO_MODO)
	for alto in range(1, PASOS_ALTO_VENTANA + 1):
		_fijar_ventana(_rect_ventana(PASOS_ANCHO_VENTANA, alto))
		await _esperar_fotogramas(1)
	_terminar_animacion_seleccion()


## gSpriteAnim_83DBD80 / 83DBD94: pequeño, vacío, pequeño y el modo nuevo, 4 fotogramas cada uno.
func _parpadear_indicador() -> void:
	for fotograma: int in [INDICADOR_PEQUENO, INDICADOR_VACIO, INDICADOR_PEQUENO]:
		spr_indicador.frame = fotograma
		await _esperar_fotogramas(4)
	spr_indicador.frame = _fotograma_indicador()


func _terminar_animacion_seleccion() -> void:
	_animando = false
	nd_contorno.visible = true
	_actualizar_seleccion()


func _pintar_palabras() -> void:
	for fila in FILAS_VISIBLES:
		for col in 2:
			var indice: int = (top_pal + fila) * 2 + col
			var texto: String = PalabrasFaciles.texto(palabras_lista[indice]) if indice < palabras_lista.size() else ""
			_etiqueta_lista(fila, col, texto, 48 + col * 88)
	# sub_80E8860: x = col·88 + 44, y = (fila − top)·16 + 96 (centro).
	spr_triangulo_lista.position = Vector2(col_pal * 88 + 44, (fila_pal - top_pal) * 16 + 96)
	_colocar_flechas(top_pal, maxi(0, _filas_palabras() - FILAS_VISIBLES), 120, 1, true)


func _etiqueta_lista(fila: int, col: int, texto: String, x: int) -> void:
	var etiqueta: Label = nd_lista.get_node("Fila%d/Col%d" % [fila, col]) as Label
	etiqueta.text = texto
	etiqueta.position.x = x


## sub_80E8A7C: flechas en y = 84 / 156, según queden filas arriba o abajo.
func _colocar_flechas(top: int, max_top: int, x: int, fotograma: int, mostrar: bool) -> void:
	spr_flecha_arriba.position = Vector2(x, 84)
	spr_flecha_abajo.position = Vector2(x, 156)
	spr_flecha_arriba.frame = fotograma
	spr_flecha_abajo.frame = fotograma
	spr_flecha_arriba.visible = mostrar and top != 0
	spr_flecha_abajo.visible = mostrar and top != max_top


## sub_80E8534 / sub_80E85F8: las tres piezas del contorno según lo elegido.
func _colocar_contorno() -> void:
	spr_contorno_b.visible = false
	spr_contorno_c.visible = false
	if en_menu:
		spr_contorno_a.frame = PIEZA_IZQUIERDA
		spr_contorno_a.position = Vector2(214, opcion_menu * 16 + 96)
		spr_contorno_c.frame = PIEZA_CAJA_MEDIA
		spr_contorno_c.position = spr_contorno_a.position + Vector2(28, 0)
		spr_contorno_c.visible = true
	elif not modo_abc:
		spr_contorno_a.frame = PIEZA_IZQUIERDA
		spr_contorno_a.position = Vector2(col_sel * 88 + 32, (fila_sel - top_sel) * 16 + 96)
		spr_contorno_b.frame = PIEZA_CENTRO
		spr_contorno_b.position = spr_contorno_a.position + Vector2(32, 0)
		spr_contorno_b.visible = true
		spr_contorno_c.frame = PIEZA_DERECHA
		spr_contorno_c.position = spr_contorno_a.position + Vector2(64, 0)
		spr_contorno_c.visible = true
	elif (TECLADO[fila_sel][col_sel] as String).is_empty():
		spr_contorno_a.frame = PIEZA_IZQUIERDA
		spr_contorno_a.position = Vector2(151, 96)
		spr_contorno_c.frame = PIEZA_DERECHA
		spr_contorno_c.position = spr_contorno_a.position + Vector2(21, 0)
		spr_contorno_c.visible = true
	else:
		spr_contorno_a.frame = PIEZA_LETRA
		spr_contorno_a.position = Vector2(COLUMNA_TECLA[fila_sel][col_sel] * 8 + 31, fila_sel * 16 + 96)


## sub_80E8268: centro del triángulo en el hueco o en la barra.
func _colocar_triangulo_frase() -> void:
	if fila_frase == fila_barra:
		spr_triangulo_frase.position = Vector2((col_frase * 7 + 3) * 8 + 4, 96)
	else:
		spr_triangulo_frase.position = Vector2(desplazamiento_x + (4 + col_frase * 11) * 8 + 4, desplazamiento_y + fila_frase * 16 + 8)


func _process(delta: float) -> void:
	_tiempo += delta
	# sub_80E82BC: x2 de −6 a 0 (+1 cada 3 fotogramas), sólo con el cursor activo.
	var paso: int = int(_tiempo / (FOTOGRAMA * FOTOGRAMAS_TRIANGULO)) % 7
	spr_triangulo_frase.offset.x = (paso - 6) if estado == Estado.FRASE else 0
	spr_triangulo_lista.offset.x = (paso - 6) if estado == Estado.PALABRAS else 0
	# sub_80E85F8: el contorno late con la mezcla alfa (fase +5/256 por fotograma).
	_fase_contorno = fmod(_fase_contorno + delta * 60.0 * 5.0 / 256.0, 1.0)
	nd_contorno.modulate.a = 0.5 + 0.5 * sin(_fase_contorno * TAU) * 0.5


# ─── Mensajes ────────────────────────────────────────────────────────────────

func _mostrar_texto_ventana(texto: String) -> void:
	nd_ventana.visible = true
	lb_mensaje.text = FormateadorLigaduras.formatear(texto).replace("\\n", "\n")


## Mensaje que espera A o B y vuelve a `retorno`.
func _mostrar_mensaje(texto: String, retorno: Estado) -> void:
	spr_triangulo_frase.visible = false
	_mostrar_texto_ventana(texto)
	_retorno_mensaje = retorno
	estado = Estado.MENSAJE


func _cerrar_mensaje() -> void:
	if _restaurar_al_cerrar:
		_restaurar_al_cerrar = false
		ids = ids_originales.duplicate()
		_pintar_huecos()
	if _retorno_mensaje == Estado.FRASE:
		_volver_a_frase()


## DisplayYesNoMenu(23, 8) con `por_defecto` (0 = SÍ, 1 = NO).
func _preguntar(tipo: Pregunta, texto: String, por_defecto: int) -> void:
	pregunta = tipo
	spr_triangulo_frase.visible = false
	_mostrar_texto_ventana(texto)
	nd_si_no.visible = true
	indice_si_no = por_defecto
	_colocar_cursor_si_no()
	estado = Estado.SI_NO


func _colocar_cursor_si_no() -> void:
	nd_cursor_si_no.position.y = 7 + indice_si_no * 16


func _sonido() -> void:
	Singleton.play_sound.emit("SE_SELECT")
