@tool
extends Control
class_name LienzoBattlers
## Lienzo del Editor de Posiciones de Battlers: dibuja el campo de batalla
## visible (BattleLayout.TAM_CAMPO, 240x112, sin la zona que en batalla cubre la
## caja de diálogo) ampliado a un factor entero (x3 o x4, filtro nearest) con el
## fondo y los dos suelos del tema, el sprite frontal del rival y el de espalda
## del jugador exactamente donde los coloca el juego (ancla del slot + offset) y,
## opcionalmente, guías de referencia. Solo usa `_draw()` (sin SubViewport).
##
## Orden de dibujo idéntico al de `batalla.tscn`: fondo, suelo superior con su
## sombra (si la especie la tiene) y sprite rival (hijos del suelo), suelo inferior con
## su sombra y sprite jugador. La sombra (`Sombra1` del BattleSlot) va debajo del
## sprite, centrada en ancla + BattleLayout.SOMBRA_REL_SLOT y sin sumar el offset del
## sprite. Todo lo que cae fuera de 240x112 se recorta (`clip_contents`), igual que
## en batalla.
##
## El lienzo no guarda datos: recibe los offsets con `mostrar()` y avisa de los
## cambios hechos por el usuario (arrastre / teclado) con `offset_cambiado`.

## El usuario movió el sprite de `lado` (`&"enemy"` / `&"player"`) a `nuevo`.
signal offset_cambiado(lado: StringName, nuevo: Vector2i)
## El lado activo (el que mueven las flechas) cambió.
signal lado_activo_cambiado(lado: StringName)

const LADO_ENEMIGO := PosicionesBattlersJSON.LADO_ENEMIGO
const LADO_JUGADOR := PosicionesBattlersJSON.LADO_JUGADOR

const ZOOM_DEFECTO := 3
const RUTA_SPRITES := "res://graficos/pokemon/%s/%s.png"

const COLOR_BASE := Color(0.10, 0.10, 0.13)
const COLOR_PLACEHOLDER := Color(0.85, 0.25, 0.65, 0.45)
const COLOR_GUIA_RIVAL := Color(0.30, 0.85, 1.00, 0.65)
const COLOR_GUIA_JUGADOR := Color(1.00, 0.65, 0.25, 0.65)
const COLOR_ACTIVO := Color(1.00, 0.95, 0.30, 0.95)

## Factor de ampliación entero (>= 1). Cambiarlo no altera ninguna coordenada lógica.
var zoom: int = ZOOM_DEFECTO:
	set(valor):
		zoom = maxi(1, valor)
		custom_minimum_size = BattleLayout.TAM_CAMPO * zoom
		queue_redraw()

var guias_visibles: bool = true:
	set(valor):
		guias_visibles = valor
		queue_redraw()

## Lado que mueven las flechas (`LADO_ENEMIGO` / `LADO_JUGADOR`).
var lado_activo: StringName = LADO_ENEMIGO

## false bloquea el arrastre y `mover_activo` (p. ej. si el JSON no se pudo cargar).
var editable: bool = true

var _clave: String = ""
var _sombra: bool = false
var _textura_sombra: Texture2D = null
var _offset_enemigo := Vector2i.ZERO
var _offset_jugador := Vector2i.ZERO
var _fondo: Texture2D = null
var _suelo: Texture2D = null
var _textura_enemigo: Texture2D = null
var _textura_jugador: Texture2D = null

var _arrastrando: bool = false
var _arrastre_origen := Vector2.ZERO
var _arrastre_offset_inicial := Vector2i.ZERO


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_mode = Control.FOCUS_ALL
	clip_contents = true
	custom_minimum_size = BattleLayout.TAM_CAMPO * zoom


# ─── API pública ───────────────────────────────────────────────────────────────

## Muestra una especie. `offsets` = {"enemy": Vector2i, "player": Vector2i,
## "sombra": bool (opcional, por defecto false)};
## `tema` = {"fondo": ruta, "suelo": ruta} (`EscenarioBatalla.rutas()` de un
## escenario de batalla).
func mostrar(clave: String, offsets: Dictionary, tema: Dictionary, shiny: bool = false) -> void:
	_clave = clave
	_offset_enemigo = offsets.get("enemy", Vector2i.ZERO)
	_offset_jugador = offsets.get("player", Vector2i.ZERO)
	_sombra = bool(offsets.get("sombra", false))
	_fondo = _cargar_textura(String(tema.get("fondo", "")))
	_suelo = _cargar_textura(String(tema.get("suelo", "")))
	_textura_enemigo = _cargar_textura(ruta_sprite(clave, LADO_ENEMIGO, shiny))
	_textura_jugador = _cargar_textura(ruta_sprite(clave, LADO_JUGADOR, shiny))
	queue_redraw()


## Ruta del PNG del sprite: `front/` (o `front-shiny/`) para el rival, `back/`
## (o `back-shiny/`) para el jugador.
static func ruta_sprite(clave: String, lado: StringName, shiny: bool = false) -> String:
	var carpeta := "front" if lado == LADO_ENEMIGO else "back"
	if shiny:
		carpeta += "-shiny"
	return RUTA_SPRITES % [carpeta, clave]


## Lados cuyo PNG no existe (se dibuja un placeholder).
func lados_sin_sprite() -> Array[StringName]:
	var faltan: Array[StringName] = []
	if _textura_enemigo == null:
		faltan.append(LADO_ENEMIGO)
	if _textura_jugador == null:
		faltan.append(LADO_JUGADOR)
	return faltan


func obtener_offset(lado: StringName) -> Vector2i:
	return _offset_enemigo if lado == LADO_ENEMIGO else _offset_jugador


func tiene_sombra() -> bool:
	return _sombra


## Muestra u oculta la sombra bajo ambos sprites (solo refresco visual).
func fijar_sombra(activa: bool) -> void:
	_sombra = activa
	queue_redraw()


## Rectángulo lógico (campo 240x112) de la sombra de un lado: centrada en
## ancla + SOMBRA_REL_SLOT; no depende del offset del sprite.
func rect_sombra(lado: StringName) -> Rect2:
	var centro := BattleLayout.centro_sombra_rival() if lado == LADO_ENEMIGO else BattleLayout.centro_sombra_jugador()
	var tam := _sombra_textura().get_size() if _sombra_textura() != null else Vector2(32, 8)
	return Rect2(centro - tam / 2.0, tam)


## Fija el offset de un lado. Con `emitir = true` avisa con `offset_cambiado`
## (cambios del usuario); sin emitir es solo refresco visual.
func fijar_offset(lado: StringName, valor: Vector2i, emitir: bool = false) -> void:
	if lado == LADO_ENEMIGO:
		_offset_enemigo = valor
	else:
		_offset_jugador = valor
	queue_redraw()
	if emitir:
		offset_cambiado.emit(lado, valor)


func set_lado_activo(lado: StringName) -> void:
	if lado_activo == lado:
		return
	lado_activo = lado
	queue_redraw()
	lado_activo_cambiado.emit(lado)


## Desplaza el lado activo `delta` píxeles lógicos (flechas del teclado).
func mover_activo(delta: Vector2i) -> void:
	if not editable:
		return
	fijar_offset(lado_activo, obtener_offset(lado_activo) + delta, true)


## Rectángulo lógico (campo 240x112) del sprite de un lado: ancla + offset, 64x64.
func rect_sprite(lado: StringName) -> Rect2:
	var ancla := BattleLayout.ancla_rival() if lado == LADO_ENEMIGO else BattleLayout.ancla_jugador()
	var textura := _textura_enemigo if lado == LADO_ENEMIGO else _textura_jugador
	var tam := textura.get_size() if textura != null else BattleLayout.TAM_SPRITE
	return Rect2(ancla + Vector2(obtener_offset(lado)), tam)


## Lado cuyo sprite está bajo `pos_logica` (el jugador se dibuja encima), o `&""`.
func lado_en(pos_logica: Vector2) -> StringName:
	if rect_sprite(LADO_JUGADOR).has_point(pos_logica):
		return LADO_JUGADOR
	if rect_sprite(LADO_ENEMIGO).has_point(pos_logica):
		return LADO_ENEMIGO
	return &""


# ─── Arrastre (público para poder simularlo desde pruebas) ─────────────────────

## Empieza un arrastre en `pos_local` (píxeles del control). Devuelve false si no
## hay ningún sprite bajo el cursor. El sprite bajo el cursor fija el lado activo.
func iniciar_arrastre(pos_local: Vector2) -> bool:
	if not editable:
		return false
	var lado := lado_en(pos_local / float(zoom))
	if lado == &"":
		return false
	set_lado_activo(lado)
	_arrastrando = true
	_arrastre_origen = pos_local
	_arrastre_offset_inicial = obtener_offset(lado)
	return true


## Mueve el sprite arrastrado; el delta se redondea a píxel lógico.
func mover_arrastre(pos_local: Vector2) -> void:
	if not _arrastrando:
		return
	var delta := ((pos_local - _arrastre_origen) / float(zoom)).round()
	var nuevo := _arrastre_offset_inicial + Vector2i(delta)
	if nuevo != obtener_offset(lado_activo):
		fijar_offset(lado_activo, nuevo, true)


func terminar_arrastre() -> void:
	_arrastrando = false


func esta_arrastrando() -> bool:
	return _arrastrando


func _gui_input(evento: InputEvent) -> void:
	var boton := evento as InputEventMouseButton
	if boton != null and boton.button_index == MOUSE_BUTTON_LEFT:
		if boton.pressed:
			grab_focus()
			iniciar_arrastre(boton.position)
		else:
			terminar_arrastre()
		accept_event()
		return
	var movimiento := evento as InputEventMouseMotion
	if movimiento != null:
		if _arrastrando:
			mover_arrastre(movimiento.position)
			accept_event()
		else:
			var sobre_sprite := lado_en(movimiento.position / float(zoom)) != &""
			mouse_default_cursor_shape = Control.CURSOR_MOVE if sobre_sprite else Control.CURSOR_ARROW


# ─── Dibujo ────────────────────────────────────────────────────────────────────

func _cargar_textura(ruta: String) -> Texture2D:
	if ruta.is_empty() or not ResourceLoader.exists(ruta):
		return null
	return load(ruta) as Texture2D


func _draw() -> void:
	var k := float(zoom)
	draw_rect(Rect2(Vector2.ZERO, BattleLayout.TAM_CAMPO * k), COLOR_BASE)
	if _fondo != null:
		draw_texture_rect(_fondo, Rect2(Vector2.ZERO, _fondo.get_size() * k), false)

	# Mismo orden que batalla.tscn: cada sprite es hijo de su suelo.
	_dibujar_suelo(BattleLayout.SUELO_ARRIBA_FINAL)
	_dibujar_sombra(LADO_ENEMIGO)
	_dibujar_sprite(LADO_ENEMIGO)
	_dibujar_suelo(BattleLayout.SUELO_ABAJO_FINAL)
	_dibujar_sombra(LADO_JUGADOR)
	_dibujar_sprite(LADO_JUGADOR)

	if guias_visibles:
		_dibujar_guias()


func _dibujar_suelo(posicion: Vector2) -> void:
	if _suelo == null:
		return
	var k := float(zoom)
	draw_texture_rect(_suelo, Rect2(posicion * k, _suelo.get_size() * k), false)


func _sombra_textura() -> Texture2D:
	if _textura_sombra == null:
		_textura_sombra = _cargar_textura(BattleLayout.RUTA_SOMBRA)
	return _textura_sombra


func _dibujar_sombra(lado: StringName) -> void:
	if not _sombra or _sombra_textura() == null:
		return
	var k := float(zoom)
	var rect := rect_sombra(lado)
	draw_texture_rect(_textura_sombra, Rect2(rect.position * k, rect.size * k), false)


func _dibujar_sprite(lado: StringName) -> void:
	var k := float(zoom)
	var rect := rect_sprite(lado)
	var destino := Rect2(rect.position * k, rect.size * k)
	var textura := _textura_enemigo if lado == LADO_ENEMIGO else _textura_jugador
	if textura != null:
		draw_texture_rect(textura, destino, false)
		return
	# Placeholder: PNG ausente.
	draw_rect(destino, COLOR_PLACEHOLDER)
	draw_rect(destino, COLOR_PLACEHOLDER.lightened(0.5), false, 1.0)
	draw_line(destino.position, destino.end, COLOR_PLACEHOLDER.lightened(0.5), 1.0)
	draw_line(Vector2(destino.end.x, destino.position.y), Vector2(destino.position.x, destino.end.y),
		COLOR_PLACEHOLDER.lightened(0.5), 1.0)


func _dibujar_guias() -> void:
	var k := float(zoom)
	_dibujar_guias_lado(BattleLayout.ancla_rival(), BattleLayout.SUELO_ARRIBA_FINAL, COLOR_GUIA_RIVAL)
	_dibujar_guias_lado(BattleLayout.ancla_jugador(), BattleLayout.SUELO_ABAJO_FINAL, COLOR_GUIA_JUGADOR)
	# Lado activo: contorno del sprite en su posición actual.
	var rect := rect_sprite(lado_activo)
	draw_rect(_rect_visible(Rect2(rect.position * k, rect.size * k)), COLOR_ACTIVO, false, 2.0)


## Las guías se limitan al campo 240x112: una línea justo en el borde inferior
## (p. ej. la base del ancla del jugador, y = 112) se sube 1 px de pantalla para
## que no la recorte `clip_contents`.
func _y_visible(y: float) -> float:
	return minf(y, BattleLayout.TAM_CAMPO.y * float(zoom) - 1.0)


func _rect_visible(rect: Rect2) -> Rect2:
	var visible := rect
	visible.end.y = _y_visible(rect.end.y)
	return visible


func _dibujar_guias_lado(ancla: Vector2, suelo: Vector2, color: Color) -> void:
	var k := float(zoom)
	var tenue := Color(color.r, color.g, color.b, color.a * 0.6)
	# Caja 64x64 del ancla (posición del sprite con offset (0,0)).
	draw_rect(_rect_visible(Rect2(ancla * k, BattleLayout.TAM_SPRITE * k)), color, false, 1.0)
	# Eje vertical central del suelo (de arriba a abajo del campo).
	var x_eje := (suelo.x + BattleLayout.TAM_SUELO.x / 2.0) * k
	draw_line(Vector2(x_eje, 0), Vector2(x_eje, BattleLayout.TAM_CAMPO.y * k), tenue, 1.0)
	var x_ini := suelo.x * k
	var x_fin := (suelo.x + BattleLayout.TAM_SUELO.x) * k
	# Línea de contacto: borde inferior del ancla.
	var y_contacto := _y_visible((ancla.y + BattleLayout.TAM_SPRITE.y) * k)
	draw_line(Vector2(x_ini, y_contacto), Vector2(x_fin, y_contacto), color, 1.0)
	# Centro horizontal del suelo.
	var y_centro := _y_visible((suelo.y + BattleLayout.TAM_SUELO.y / 2.0) * k)
	draw_line(Vector2(x_ini, y_centro), Vector2(x_fin, y_centro), tenue, 1.0)
