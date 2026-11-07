class_name FichaOlvidarMovimiento
extends Node2D

## Ficha para elegir qué movimiento olvidar al aprender uno nuevo sin hueco (MT, subida de
## nivel, evolución): `ShowSelectMovePokemonSummaryScreen` (modo PSS_MODE_SELECT_MOVE de
## pokemon_summary_screen.c). Es una copia reducida de la ficha del Pokémon
## (UI/poke-info/pantalla-info.tscn) con solo las páginas MOV. COMBATE y MOV. CONCURSO:
## los cuatro movimientos actuales y, en la 5.ª fila, el nuevo.
##
## Controles (sub_809E260): ↑/↓ mueven el cursor por las 5 filas (circular), ←/→ cambian
## entre combate y concurso, A elige la fila y B elige el nuevo (no olvidar ninguno). Una
## MO no se puede elegir (SummaryScreen_CanForgetSelectedMove): suena SE_FAILURE, la caja
## EFECTO se retira y la descripción avisa hasta la siguiente pulsación (sub_809F814).
## No se puede cambiar de Pokémon.
##
## Sin movimiento nuevo (`nuevo = null`) es la ficha del QUITA-MOVIMIENTOS (`special SelectMove`): la 5.ª
## fila no se dibuja ni se puede elegir, solo los movimientos que el POKéMON conoce, y B devuelve
## INDICE_NUEVO (= cancelar).
##
## Emite `movimiento_elegido(indice)`: 0-3 = olvidar ese movimiento, INDICE_NUEVO = ninguno.
## Uso: `var indice: int = await ficha.elegir(pokemon, nuevo, aprendizaje.es_mo)` (con los
## fundidos a negro de entrada y salida) o `abrir(...)` + la señal (sin fundidos).

signal movimiento_elegido(indice: int)

enum Vista { COMBATE, CONCURSO }

const INDICE_NUEVO: int = 4
const NUM_FILAS: int = 5
const ALTO_FILA: int = 16
const Y_PRIMERA_FILA: int = 16
## BeginNormalPaletteFade(..., 0, 0, 16, ...): 16 pasos de un fotograma.
const DURACION_FUNDIDO: float = 16.0 / 60.0
const SONIDO_SELECCION: String = "SE_SELECT"
## SE_FAILURE: PlaySE(SE_FAILURE) al intentar olvidar una MO.
const SONIDO_FALLO: String = "SE_FAILURE"
const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"
const TEXTURA_TIPOS: Texture2D = preload("res://graficos/tipos-pokemon.png")
const TEXTURA_CATEGORIAS: Texture2D = DibujoConcurso.TEXTURA_CATEGORIAS
const TEXTURA_CORAZONES: Texture2D = DibujoConcurso.TEXTURA_CORAZONES
const PANEL_COMBATE: Texture2D = preload("res://UI/poke-info/pantalla-info-pag3v.png")
const PANEL_CONCURSO: Texture2D = preload("res://UI/poke-info/pantalla-info-pag3v-concurso.png")
const FILA_COMBATE: Texture2D = preload("res://UI/poke-info/ficha-olvidar-fila-nueva.png")
const FILA_CONCURSO: Texture2D = preload("res://UI/poke-info/ficha-olvidar-fila-nueva-concurso.png")
const CAJA_COMBATE: Texture2D = preload("res://UI/poke-info/pantalla-info-pag3-extra.png")
const CAJA_CONCURSO: Texture2D = preload("res://UI/poke-info/pantalla-info-pag3-extra-concurso.png")
## Nombre del movimiento nuevo: rosa en combate y azul en concurso (colores 10 y 9 de
## sSummaryScreenTextColors en sub_80A029C).
const TEXTO_NUEVO_COMBATE: LabelSettings = preload("res://UI/poke-info/texto_mov_nuevo.tres")
const TEXTO_NUEVO_CONCURSO: LabelSettings = preload("res://UI/poke-info/texto_eo_varon.tres")
const MAX_CORAZONES: int = DibujoConcurso.MAX_CORAZONES
const X_CORAZONES: int = 48
const Y_CORAZONES_ATRACTIVO: int = 11
const Y_CORAZONES_INTERFERENCIA: int = 27
## Modulación del número de la Pokédex: el texto ya es #f8f8f8; variocolor lo deja en
## #e8e8a8 (232/248, 232/248, 168/248).
const COLOR_DEX_VARIOCOLOR := Color(0.935484, 0.935484, 0.677419, 1.0)
const COLOR_DEX_NORMAL := Color.WHITE

@onready var _contenido: Node2D = $Contenido
@onready var _titulo: Sprite2D = $Contenido/Titulo
@onready var _sprite_pokemon: PokemonSprite = $Contenido/PokemonSprite
@onready var _num_dex: Label = $Contenido/num_dex
@onready var _mote: Label = $Contenido/mote
@onready var _panel: Sprite2D = $Contenido/Panel
@onready var _fila_nueva: Sprite2D = $Contenido/Panel/FilaNueva
@onready var _cursor: PkSelectorSimple = $Contenido/Panel/cursor_movil
@onready var _mov_desc: Label = $Contenido/Panel/mov_desc
@onready var _caja: Sprite2D = $Contenido/CajaEfecto
@onready var _potencia: Label = $Contenido/CajaEfecto/mov_potencia
@onready var _precision: Label = $Contenido/CajaEfecto/mov_precision
@onready var _etiqueta_exhib: Label = $Contenido/CajaEfecto/etiqueta_exhib
@onready var _etiqueta_inhib: Label = $Contenido/CajaEfecto/etiqueta_inhib
@onready var _corazones: Node2D = $Contenido/CajaEfecto/Corazones
@onready var _fundido: ColorRect = $Fundido

var pokemon: BasePokemon = null
var movimiento_nuevo: Movimiento = null
var vista: Vista = Vista.COMBATE
var fila: int = 0
var activo: bool = false

var _es_mo: Callable = Callable()
var _iconos: Array[Sprite2D] = []
var _nombres: Array[Label] = []
var _pps: Array[Label] = []
var _sprites_corazon: Array[Sprite2D] = []
## Aviso de MO a la vista (sub_809F814): la siguiente pulsación lo retira.
var _aviso_mo: bool = false
var _resultado: int = -1
var _cancelado: bool = false
var _tween_caja: Tween = null
var _reproductor_se: AudioStreamPlayer = null
var _reproductor_grito: AudioStreamPlayer = null


func _ready() -> void:
	for i in range(NUM_FILAS):
		_iconos.append(get_node("Contenido/Panel/tipo%d" % (i + 1)) as Sprite2D)
		_nombres.append(get_node("Contenido/Panel/mov%d" % (i + 1)) as Label)
		_pps.append(get_node("Contenido/Panel/pp%d" % (i + 1)) as Label)
	for i in range(MAX_CORAZONES * 2):
		var corazon := Sprite2D.new()
		corazon.texture = TEXTURA_CORAZONES
		corazon.centered = false
		corazon.region_enabled = true
		var columna := i % 4
		var fila_corazon := (i % MAX_CORAZONES) / 4
		var y := Y_CORAZONES_ATRACTIVO if i < MAX_CORAZONES else Y_CORAZONES_INTERFERENCIA
		corazon.position = Vector2(X_CORAZONES + columna * 8, y + fila_corazon * 8)
		_corazones.add_child(corazon)
		_sprites_corazon.append(corazon)
	_contenido.visible = false
	_fundido.color.a = 0.0


# --- API ---

## Muestra la ficha de `p_pokemon` con `nuevo` en la 5.ª fila y la deja lista para elegir
## (sin fundidos). `es_mo(indice) -> bool` veta las MO (AprendizajeMovimientos.es_mo).
func abrir(p_pokemon: BasePokemon, nuevo: Movimiento, es_mo: Callable = Callable()) -> void:
	pokemon = p_pokemon
	movimiento_nuevo = nuevo
	_es_mo = es_mo
	_resultado = -1
	_cancelado = false
	_aviso_mo = false
	fila = 0
	vista = Vista.COMBATE
	_mostrar_pokemon()
	_actualizar()
	_contenido.visible = true
	activo = true


## Como en la ROM: fundido a negro sobre la pantalla anterior, la ficha aparece desde negro,
## se elige y vuelve a fundirse. Devuelve el índice elegido (0-3 o INDICE_NUEVO).
func elegir(p_pokemon: BasePokemon, nuevo: Movimiento, es_mo: Callable = Callable()) -> int:
	_resultado = -1
	_cancelado = false
	await _fundir(1.0)
	if _resultado < 0:
		abrir(p_pokemon, nuevo, es_mo)
		activo = false
		await _fundir(0.0)
	if _resultado < 0:
		activo = true
		_reproducir_grito()
		await movimiento_elegido
	if not _cancelado:
		await _fundir(1.0)
	_contenido.visible = false
	_detener_grito()
	if not _cancelado:
		await _fundir(0.0)
	_fundido.color.a = 0.0
	return _resultado


## Atajo para `DialogoAprendizaje`/`DialogoMaquina`: el movimiento pendiente y el veto de MO.
func elegir_aprendizaje(aprendizaje: AprendizajeMovimientos) -> int:
	return await elegir(aprendizaje.pokemon, aprendizaje.crear_movimiento_pendiente(), aprendizaje.es_mo)


## Cierra al momento como si se hubiera pulsado B (sesión de MT/MO invalidada).
func cancelar() -> void:
	if _resultado >= 0:
		return
	_cancelado = true
	_contenido.visible = false
	_fundido.color.a = 0.0
	_elegir(INDICE_NUEVO, false)


## true mientras la ficha acepta pulsaciones.
func esta_activa() -> bool:
	return activo and _resultado < 0


## Movimiento de la fila `indice` (0-3 los actuales, 4 el nuevo).
func movimiento_en_fila(indice: int) -> Movimiento:
	if indice == INDICE_NUEVO:
		return movimiento_nuevo
	if pokemon != null and indice >= 0 and indice < pokemon.movimientos.size():
		return pokemon.movimientos[indice] as Movimiento
	return null


# --- Entrada (sub_809E260) ---

func _input(event: InputEvent) -> void:
	if not esta_activa() or event is InputEventMouseMotion:
		return
	if event.is_action_pressed("btn_arriba"):
		mover_cursor(-1)
	elif event.is_action_pressed("btn_abajo"):
		mover_cursor(1)
	elif event.is_action_pressed("btn_izquierda"):
		cambiar_vista(-1)
	elif event.is_action_pressed("btn_derecha"):
		cambiar_vista(1)
	elif event.is_action_pressed("btn_accion"):
		aceptar()
	elif event.is_action_pressed("btn_cancelar"):
		renunciar()
	else:
		return
	get_viewport().set_input_as_handled()


## ↑/↓: cursor circular por las 5 filas (sub_809E8F0 salta huecos vacíos).
func mover_cursor(direccion: int) -> void:
	_reproducir_se(SONIDO_SELECCION)
	_retirar_aviso_mo()
	for _i in range(NUM_FILAS):
		fila = posmod(fila + direccion, NUM_FILAS)
		if movimiento_en_fila(fila) != null:
			break
	_actualizar_movimiento()


## ←/→: MOV. COMBATE <-> MOV. CONCURSO (SummaryScreenHandleLeftRightInput: sin efecto en
## los extremos).
func cambiar_vista(direccion: int) -> void:
	var nueva: int = int(vista) + direccion
	if nueva < Vista.COMBATE or nueva > Vista.CONCURSO:
		return
	_retirar_aviso_mo()
	_reproducir_se(SONIDO_SELECCION)
	vista = nueva as Vista
	_actualizar()


## A: elige la fila; una MO no (SE_FAILURE y aviso en la descripción). Con el aviso a la
## vista, A solo lo retira.
func aceptar() -> void:
	if _aviso_mo:
		_retirar_aviso_mo()
		return
	if fila != INDICE_NUEVO and _es_mo.is_valid() and bool(_es_mo.call(fila)):
		_mostrar_aviso_mo()
		return
	_elegir(fila)


## B: no olvidar ninguno (el nuevo). Con el aviso de MO a la vista solo lo retira.
func renunciar() -> void:
	if _aviso_mo:
		_retirar_aviso_mo()
		return
	_elegir(INDICE_NUEVO)


func _elegir(indice: int, con_sonido: bool = true) -> void:
	if _resultado >= 0:
		return
	activo = false
	_resultado = indice
	if con_sonido:
		_reproducir_se(SONIDO_SELECCION)  # SummaryScreenExit
	movimiento_elegido.emit(indice)


# --- Dibujo ---

func _mostrar_pokemon() -> void:
	if pokemon == null:
		return
	var variocolor := pokemon.es_shiny()
	_num_dex.text = "%03d" % pokemon.numero_nacional
	_num_dex.modulate = COLOR_DEX_VARIOCOLOR if variocolor else COLOR_DEX_NORMAL
	_mote.text = pokemon.get_nombre_mostrar()
	_sprite_pokemon.configurar_pokemon(pokemon.nombre_interno, PokemonSprite.TipoSprite.FRENTE, variocolor, pokemon.personalidad)


## Redibuja la vista actual: pestaña, panel, filas y el movimiento bajo el cursor.
func _actualizar() -> void:
	var concurso := vista == Vista.CONCURSO
	_titulo.region_rect = Rect2(0, int(vista) * 16, 240, 16)
	_panel.texture = PANEL_CONCURSO if concurso else PANEL_COMBATE
	_fila_nueva.texture = FILA_CONCURSO if concurso else FILA_COMBATE
	_fila_nueva.visible = movimiento_nuevo != null
	_caja.texture = CAJA_CONCURSO if concurso else CAJA_COMBATE
	_potencia.visible = not concurso
	_precision.visible = not concurso
	_etiqueta_exhib.visible = concurso
	_etiqueta_inhib.visible = concurso
	_corazones.visible = concurso
	for i in range(NUM_FILAS):
		var mov := movimiento_en_fila(i)
		if mov == null:
			_iconos[i].visible = false
			_nombres[i].text = "-"
			_pps[i].text = "--"
			continue
		_iconos[i].visible = _asignar_icono(_iconos[i], mov, concurso)
		_nombres[i].text = mov.nombre.to_upper()
		if i == INDICE_NUEVO:
			# PP máximos base del nuevo (gBattleMoves[move].pp) en las dos cifras.
			var pp := mov.get_max_pp() if mov.get_max_pp() > 0 else mov.pp_tot
			_pps[i].text = "%2s/%2s" % [str(pp), str(pp)]
			_nombres[i].label_settings = TEXTO_NUEVO_CONCURSO if concurso else TEXTO_NUEVO_COMBATE
		else:
			_pps[i].text = "%2s/%2s" % [str(mov.pp_act), str(mov.pp_tot)]
	_actualizar_movimiento()


## Icono de tipo (combate) o de categoría de concurso (gContestMoves[].contestCategory + 18).
func _asignar_icono(icono: Sprite2D, mov: Movimiento, concurso: bool) -> bool:
	if concurso:
		DibujoConcurso.asignar_icono_categoria(icono, mov)
		return true
	var frame := Singleton.obtener_frame_tipo(Singleton.obtener_id_tipo_por_nombre(mov.get_tipo()))
	if frame < 0:
		return false
	icono.texture = TEXTURA_TIPOS
	icono.region_rect = Rect2(0, frame * 16, 32, 16)
	return true


## Cursor, descripción y caja EFECTO del movimiento bajo el cursor (sub_80A0428).
func _actualizar_movimiento() -> void:
	_cursor.position.y = Y_PRIMERA_FILA + fila * ALTO_FILA
	var mov := movimiento_en_fila(fila)
	if mov == null:
		_mov_desc.text = ""
		_potencia.text = "---"
		_precision.text = "---"
		_pintar_corazones(0, 0)
		return
	if vista == Vista.CONCURSO:
		_mov_desc.text = mov.get_descripcion_concurso()
		_pintar_corazones(mov.get_atractivo(), mov.get_interferencia())
	else:
		_mov_desc.text = mov.get_descripcion()
		# sub_80A04CC: potencia <= 1 y precisión 0 se muestran como "---".
		_potencia.text = "---" if mov.get_potencia() <= 1 else str(mov.get_potencia())
		_precision.text = "---" if mov.get_precision() <= 0 else str(mov.get_precision())


## sub_80A057C: corazones de atractivo e interferencia.
func _pintar_corazones(atractivo: int, interferencia: int) -> void:
	DibujoConcurso.pintar_corazones(_sprites_corazon, atractivo, interferencia)


## Número de corazones llenos de atractivo e interferencia a la vista (para pruebas).
func corazones_llenos() -> Vector2i:
	return DibujoConcurso.contar_corazones_llenos(_sprites_corazon)


# --- Aviso de MO (sub_809F9D0 / sub_809F814) ---

func _mostrar_aviso_mo() -> void:
	_reproducir_se(SONIDO_FALLO)
	_aviso_mo = true
	_mov_desc.text = DatosMaquinas.texto("MAQUINA_NO_OLVIDAR_MO")  # gOtherText_CantForgetHMs
	_deslizar_caja(-float(CAJA_COMBATE.get_width()))


func _retirar_aviso_mo() -> void:
	if not _aviso_mo:
		return
	_aviso_mo = false
	_deslizar_caja(0.0)
	_actualizar_movimiento()


func _deslizar_caja(x: float) -> void:
	if _tween_caja != null:
		_tween_caja.kill()
	if not is_inside_tree():
		_caja.position.x = x
		return
	_tween_caja = create_tween()
	_tween_caja.tween_property(_caja, "position:x", x, 0.1)


# --- Fundidos y sonido ---

func _fundir(alfa: float) -> void:
	var desde := _fundido.color.a
	var t := 0.0
	while t < DURACION_FUNDIDO and not _cancelado and is_inside_tree():
		await get_tree().process_frame
		t += get_process_delta_time()
		_fundido.color.a = lerpf(desde, alfa, minf(t / DURACION_FUNDIDO, 1.0))
	_fundido.color.a = 0.0 if _cancelado else alfa


func _reproducir_se(sonido: String) -> void:
	if not Singleton.se.has(sonido):
		return
	if not is_instance_valid(_reproductor_se):
		_reproductor_se = AudioStreamPlayer.new()
		add_child(_reproductor_se)
	_reproductor_se.stream = Singleton.se[sonido]
	_reproductor_se.play()


## SummaryScreen_SpritePlayCry: el grito suena al terminar el fundido de entrada.
func _reproducir_grito() -> void:
	if pokemon == null or pokemon.huevo or pokemon.numero_nacional <= 0:
		return
	var ruta := RUTA_GRITO % pokemon.numero_nacional
	if not ResourceLoader.exists(ruta):
		return
	if not is_instance_valid(_reproductor_grito):
		_reproductor_grito = AudioStreamPlayer.new()
		add_child(_reproductor_grito)
	_reproductor_grito.stream = load(ruta) as AudioStream
	_reproductor_grito.play()


func _detener_grito() -> void:
	if is_instance_valid(_reproductor_grito):
		_reproductor_grito.stop()
