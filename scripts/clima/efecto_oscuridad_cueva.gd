class_name EfectoOscuridadCueva
extends EfectoClimaBase

## Oscuridad de las cuevas (gMapHeader.cave de pokeruby, Cueva Granito B1F/B2F):
## todo negro salvo un círculo alrededor del jugador. Sin Destello el radio es de
## RADIO_SIN_DESTELLO px lógicos; con la bandera de Destello (FLAG_SYS_USE_FLASH)
## es RADIO_CON_DESTELLO. Al activarse la bandera con el efecto vivo, el radio
## crece 1 px cada FRAMES_POR_PIXEL frames (animateflash de pokeruby), así que
## basta con poner la bandera para que el círculo se abra solo.
##
## Se dibuja por filas en la pantalla lógica de 240×160 escalada al área visible:
## cada fila tapa lo que queda fuera del círculo con dos rectángulos, sin
## antialiasing, como las ventanas WIN0/WIN1 del GBA. En el GBA el círculo está
## centrado en la pantalla (el jugador); aquí se centra en el jugador en pantalla
## para que también valga con la cámara fija.
##
## El fundido de entrada y salida lo gestiona el controlador con `factor_mezcla`.
## Entre dos mapas oscuros (B1F → B2F) el controlador no recrea el efecto (mismo
## id e intensidad), así que el radio se conserva sin parpadeo.

const ID := &"OSCURIDAD"
## Bandera de partida de Destello (FLAG_SYS_USE_FLASH). Se borra al entrar en un
## mapa exterior, al volar y tras una derrota.
const BANDERA_DESTELLO := "SYS_USE_FLASH"
const RADIO_SIN_DESTELLO := 24
const RADIO_CON_DESTELLO := 72
## animateflash: +1 px de radio cada 2 frames del GBA.
const FRAMES_POR_PIXEL := 2
const SEGUNDOS_POR_PIXEL: float = FRAMES_POR_PIXEL * 1.0 / ConstantesGba.FPS
const TAMANO_REFERENCIA := ConstantesGba.RESOLUCION_LOGICA
const GRUPO_EFECTO := &"efecto_oscuridad_cueva"

## Radio mínimo fijado por el guion del mapa (setflashradius / animateflash de
## pokeruby, p. ej. el GIMNASIO de AZULIZA, que se ilumina al vencer entrenadores).
## 0 = sin guion. El radio efectivo es el mayor entre éste y el del Destello.
static var radio_guion: int = 0
## Del origen del jugador (centro inferior de su celda + (8, 14)) al centro de su
## celda: (8, 8) - (8, 14).
const DESPLAZAMIENTO_CENTRO_JUGADOR := Vector2(0.0, -6.0)
const GRUPO_JUGADOR := &"Personaje"

## Inyectables en tests: estado de la bandera de Destello (bool) y centro del
## círculo en la pantalla lógica (Vector2). null = bandera real / jugador real.
var destello_override: Variant = null
var centro_override: Variant = null

## Radio actual en píxeles lógicos.
var radio: int = RADIO_SIN_DESTELLO
var _acumulado: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group(GRUPO_EFECTO)
	radio = obtener_radio_objetivo()
	set_process(true)


func _process(delta: float) -> void:
	actualizar_radio(delta)
	# El jugador y la cámara se mueven: el círculo se recoloca cada frame.
	queue_redraw()


## Avanza la animación del radio hacia el de la bandera: crece de 1 en 1 px cada
## SEGUNDOS_POR_PIXEL y, si la bandera se apaga, vuelve al radio pequeño de golpe.
func actualizar_radio(delta: float) -> void:
	var objetivo := obtener_radio_objetivo()
	if radio > objetivo:
		radio = objetivo
		_acumulado = 0.0
		return
	if radio == objetivo:
		_acumulado = 0.0
		return
	_acumulado += maxf(0.0, delta)
	while _acumulado >= SEGUNDOS_POR_PIXEL and radio < objetivo:
		_acumulado -= SEGUNDOS_POR_PIXEL
		radio += 1


func obtener_radio_objetivo() -> int:
	var base := RADIO_CON_DESTELLO if _destello_activo() else RADIO_SIN_DESTELLO
	return maxi(base, radio_guion)


func _destello_activo() -> bool:
	if destello_override is bool:
		return destello_override as bool
	return destello_activo()


func _draw() -> void:
	if not debe_dibujar():
		return
	var escala := Vector2(size.x / TAMANO_REFERENCIA.x, size.y / TAMANO_REFERENCIA.y)
	draw_set_transform(Vector2.ZERO, 0.0, escala)
	var color := Color(0.0, 0.0, 0.0, factor_mezcla * intensidad)
	for rect: Rect2 in calcular_rectangulos(obtener_centro(), radio):
		draw_rect(rect, color)


func debe_dibujar() -> bool:
	return factor_mezcla > 0.0 and intensidad > 0.0 and size.x > 0.0 and size.y > 0.0


## Centro del círculo en la pantalla lógica: el centro de la celda del jugador
## menos la esquina visible de la cámara. Sin jugador, el centro de la pantalla.
func obtener_centro() -> Vector2:
	if centro_override is Vector2:
		return centro_override as Vector2
	var jugador := _obtener_jugador()
	if jugador == null:
		return TAMANO_REFERENCIA * 0.5
	return (jugador.global_position + DESPLAZAMIENTO_CENTRO_JUGADOR - obtener_posicion_camara()).round()


func _obtener_jugador() -> Node2D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(GRUPO_JUGADOR) as Node2D


## Rectángulos (pantalla lógica) que tapan todo menos el círculo de `radio_px`
## centrado en `centro`: por cada fila, la parte a la izquierda y a la derecha de
## la cuerda del círculo; las filas que no lo cortan, enteras. Píxel a píxel: un
## píxel queda iluminado si su centro está dentro del círculo.
static func calcular_rectangulos(centro: Vector2, radio_px: int) -> Array[Rect2]:
	var rectangulos: Array[Rect2] = []
	var ancho := TAMANO_REFERENCIA.x
	for fila: int in range(int(TAMANO_REFERENCIA.y)):
		var dy := float(fila) + 0.5 - centro.y
		var cuadrado := float(radio_px * radio_px) - dy * dy
		if cuadrado <= 0.0:
			rectangulos.append(Rect2(0.0, fila, ancho, 1.0))
			continue
		var semicuerda := sqrt(cuadrado)
		# Primer y último píxel cuyo centro (x + 0.5) cae dentro de la cuerda.
		var inicio := clampf(ceilf(centro.x - semicuerda - 0.5), 0.0, ancho)
		var fin := clampf(floorf(centro.x + semicuerda - 0.5) + 1.0, 0.0, ancho)
		if fin <= inicio:
			rectangulos.append(Rect2(0.0, fila, ancho, 1.0))
			continue
		if inicio > 0.0:
			rectangulos.append(Rect2(0.0, fila, inicio, 1.0))
		if fin < ancho:
			rectangulos.append(Rect2(fin, fila, ancho - fin, 1.0))
	return rectangulos


## setflashradius (`animar` = false: el radio salta al instante) o animateflash
## (`animar` = true: el círculo crece 1 px cada FRAMES_POR_PIXEL frames). El valor
## queda guardado, así que el efecto que se cree después ya nace con él.
static func fijar_radio_guion(px: int, animar: bool, arbol: SceneTree = null) -> void:
	radio_guion = maxi(px, 0)
	if animar:
		return
	var bucle: SceneTree = arbol if arbol != null else Engine.get_main_loop() as SceneTree
	if bucle == null:
		return
	for nodo: Node in bucle.get_nodes_in_group(GRUPO_EFECTO):
		var efecto := nodo as EfectoOscuridadCueva
		if efecto != null:
			efecto.radio = efecto.obtener_radio_objetivo()
			efecto.queue_redraw()


## Al salir del mapa con guion de luz: vuelve a los radios por defecto.
static func limpiar_radio_guion() -> void:
	radio_guion = 0


## Duración de la animación del radio de 24 a 72 px (~1,6 s).
static func duracion_destello() -> float:
	return (RADIO_CON_DESTELLO - RADIO_SIN_DESTELLO) * SEGUNDOS_POR_PIXEL


static func destello_activo() -> bool:
	return SistemaGuardado.get_flag(BANDERA_DESTELLO)


static func activar_destello() -> void:
	SistemaGuardado.set_flag(BANDERA_DESTELLO, true)


## FlagClear(FLAG_SYS_USE_FLASH): mapa exterior, VUELO o derrota.
static func apagar_destello() -> void:
	SistemaGuardado.delete_flag(BANDERA_DESTELLO)


## ¿`mapa` es una cueva oscura? (su clima inicial es la oscuridad).
static func es_mapa_oscuro(mapa: MapaConfiguracion) -> bool:
	return mapa != null and mapa.clima_inicial != null and mapa.clima_inicial.id == ID


## SetUpFieldMove_Flash + comprobación de medalla del menú: hace falta la Medalla
## Puño (índice 1 de `medallas`), estar en una cueva oscura y no haber usado ya
## Destello en ella.
static func puede_usar_destello(mapa: MapaConfiguracion, medallas: Variant, ya_usado: bool) -> bool:
	return tiene_medalla_puno(medallas) and es_mapa_oscuro(mapa) and not ya_usado


## FlagGet(FLAG_BADGE02_GET): Medalla Puño, índice 1 de `medallas`.
static func tiene_medalla_puno(medallas: Variant) -> bool:
	return medallas is Array and (medallas as Array).size() > 1 and bool((medallas as Array)[1])
