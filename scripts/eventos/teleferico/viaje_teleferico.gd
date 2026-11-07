## viaje_teleferico.gd
## El viaje en TELEFÉRICO entre la RUTA 112 y el MONTE CENIZO (pokeruby src/cable_car.c: `special CableCar` +
## `special CableCarWarp`). Es una escena de pantalla completa que dura 570 fotogramas a 60 fps: se funde a negro, aparece
## la cabina colgada del cable subiendo (o bajando) por la ladera entre pinos y postes, y al acabar vuelve a fundirse a
## negro y se hace el warp a la otra estación (6,4).
##
## Va como CanvasLayer 4 hijo del AdministradorMapa (por debajo de la capa `Menu` 5, que lleva el telón de los fundidos y
## los cuadros de texto), de modo que el fundido lo hace el propio telón del juego:
##   1. oscurecer (telón) -> se construye la escena -> aclarar (revela el viaje);
##   2. 570 fotogramas; al terminar, oscurecer;
##   3. el viaje se libera y el AdministradorMapa hace el warp (conectar_escalera) con el telón ya negro.
## La música es MUS_CABLE_CAR (tema TELEFERICO); al llegar, la de la estación la releva.
##
## Los cuatro fondos son los de la GBA (BG0 la ladera del monte, que se va completando columna a columna; BG1 los pinos,
## BG2 las montañas y BG3 el cable con los postes) y se manejan con la misma lógica que el original (sub_81239E4 / 8123AF8,
## sub_812453C / 8124598, sub_81245F4 / 812476C y sub_812446C), con los u8 de los desplazamientos. Los sprites (cabina,
## puerta, nueve tramos de cable y el jugador de pie dentro) se mueven como sub_8123CB8 / sub_8123D98.
##
## El clima: subiendo empieza despejado y a los 350 fotogramas (0x15E) cae ceniza; bajando empieza con ceniza y a los 265
## (0x109) se despeja. Aquí la ceniza entra y sale con un fundido de 1 s. Además se desplaza 1 px por fotograma, a la derecha
## al subir y a la izquierda al bajar (gSpriteCoordOffsetX y gWeatherPtr->unknown_6FC).
##
## Pendiente respecto al original: el excursionista que cruza el cable una de cada 64 veces (LoadSprites, rval % 64 == 0).
class_name ViajeTeleferico
extends CanvasLayer

enum Sentido { SUBIR, BAJAR }

const MOTIVO_PAUSA: StringName = &"teleferico_viaje"
const TEMA_MUSICA: String = "TELEFERICO"
const CAPA_VIAJE: int = 4
## sub_8123878: el viaje acaba (fundido) en el fotograma 570.
const FOTOGRAMAS_VIAJE: int = 570
const FOTOGRAMAS_POR_SEGUNDO: float = 60.0
## BeginNormalPaletteFade(… 0 … 16): fundido inicial rápido; (… 3 …): 16 pasos de 3 fotogramas.
const DURACION_FUNDIDO_INICIAL: float = 16.0 / FOTOGRAMAS_POR_SEGUNDO
const DURACION_FUNDIDO: float = 48.0 / FOTOGRAMAS_POR_SEGUNDO
const DURACION_CENIZA: float = 1.0

const TEX_CABINA: Texture2D = preload("res://graficos/teleferico/cabina.png")
const TEX_PUERTA: Texture2D = preload("res://graficos/teleferico/puerta.png")
const TEX_CABLE: Texture2D = preload("res://graficos/teleferico/cable.png")

## gCableCarPylonHookTilemapEntries.
const GANCHOS: PackedInt32Array = [0x3000, 0x3001, 0x3002, 0x3003, 0x3004, 0x3005, 0x3006, 0x3007, 0x3008, 0x3009]

## Fotograma en que cambia el clima (unk_0004) y clima de destino: ceniza (WEATHER_ASH) al subir, despejado (WEATHER_SUNNY)
## al bajar.
const FOTOGRAMA_CENIZA_SUBIENDO: int = 0x15E
const FOTOGRAMA_DESPEJA_BAJANDO: int = 0x109

## Posiciones iniciales de las esquinas superiores izquierdas de los sprites (los pos1 de LoadSprites).
const CABINA_SUBIENDO := Vector2i(0xB0, 0x2B)
const PUERTA_SUBIENDO := Vector2i(0xC8, 0x63)
const JUGADOR_SUBIENDO := Vector2i(0xC8, 0x49)
const CABINA_BAJANDO := Vector2i(0x68, 0x09)
const PUERTA_BAJANDO := Vector2i(0x80, 0x41)
const JUGADOR_BAJANDO := Vector2i(0x80, 0x27)
## Los nueve tramos de cable: (16 i + 0x60, 8 i - 8).
const TRAMOS_CABLE: int = 9
## Desplazamiento del jugador respecto a la esquina de su sprite de 16x32 (los pies, como un NPC) y de la cabina.
const PIES_JUGADOR := Vector2(8, 30)

signal viaje_terminado

var sentido: Sentido = Sentido.SUBIR
var destino: String = ""
var celda_destino: Vector2i = Vector2i(6, 4)
## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## false recorre el viaje de golpe, sin fundidos ni esperas (tests).
var con_animacion: bool = true

## Fotogramas transcurridos (unk_0006).
var fotograma: int = 0
## unk_0001: 0 esperando el cambio de clima, 1 clima cambiado, 2 viaje, 3 fundiendo, 255 acabado.
var fase: int = 0
var _fotograma_clima: int = 0
var _con_ceniza: bool = false

var fondo_montanas: FondoGba
var fondo_pinos: FondoGba
var fondo_ladera: FondoGba
var fondo_cable: FondoGba
var cabina: Sprite2D
var puerta: Sprite2D
var jugador_sprite: AnimatedSprite2D
var tramos_cable: Array[Sprite2D] = []
var ceniza: EfectoCenizaOverworld = null
var _raiz: Control
var _sprites: Node2D
var _acumulado: float = 0.0
var _construido: bool = false

# --- estado de los fondos (struct CableCarEwramStruct1) ---
var _bg3_x: int = 0  # unk_0014
var _bg3_y: int = 0  # unk_0015
var _bg1_x: int = 0  # unk_000c
var _bg1_y: int = 0  # unk_000d
var _bg0_x: int = 0  # unk_0008
var _bg0_y: int = 0  # unk_0009
var _col_bloque: int = 0  # unk_0018
var _col_fondo: int = 0  # unk_0019
var _fila_fondo: int = 0  # unk_001a
var _ciclo_bloque: int = 0  # unk_001b
var _acum_x: int = 0  # unk_001d
var _acum_y: int = 0  # unk_001e
var _base_x: int = 0  # unk_001f
var _base_y: int = 0  # unk_0020
var _desplazamiento_sprites_x: int = 0  # gSpriteCoordOffsetX
var _ceniza_x: int = 0  # gWeatherPtr->unknown_6FC
## unk_0022[9][12].
var _bloque: Array = []
var _cabina_origen: Vector2i
var _puerta_origen: Vector2i
var _jugador_origen: Vector2i


## Crea el viaje y lo lanza (CableCarWarp + CableCar). El destino es la clave de la otra estación y `celda` donde
## aparece el jugador (6,4). Devuelve el nodo.
static func iniciar(admin: Node, nuevo_sentido: Sentido, estacion_destino: String, celda: Vector2i = Vector2i(6, 4),
		animar: bool = true) -> ViajeTeleferico:
	var viaje := ViajeTeleferico.new()
	viaje.administrador = admin
	viaje.con_animacion = animar
	viaje.configurar(nuevo_sentido, estacion_destino, celda)
	# Se bloquea ya: el evento que lo lanza libera al jugador al terminar, antes de que el viaje haya empezado.
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	admin.add_child(viaje)
	viaje.ejecutar()
	return viaje


func configurar(nuevo_sentido: Sentido, estacion_destino: String, celda: Vector2i = Vector2i(6, 4)) -> void:
	sentido = nuevo_sentido
	destino = estacion_destino
	celda_destino = celda


func _init() -> void:
	layer = CAPA_VIAJE


## sub_8123FBC(TRUE) + LoadSprites + los pasos 5 y 6 de CableCarMainCallback_Setup: los fondos y los sprites en su
## estado inicial.
func construir() -> void:
	if _construido:
		return
	_construido = true
	var subiendo := sentido == Sentido.SUBIR
	_raiz = Control.new()
	_raiz.size = Vector2(FondoGba.PANTALLA)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_raiz)
	var negro := ColorRect.new()
	negro.color = Color.BLACK
	negro.size = Vector2(FondoGba.PANTALLA)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.add_child(negro)
	fondo_montanas = FondoGba.new()
	fondo_pinos = FondoGba.new()
	fondo_ladera = FondoGba.new()
	fondo_cable = FondoGba.new()
	_sprites = Node2D.new()
	# Orden de dibujo: BG2 (prioridad 3), BG1 (2), los sprites (2), BG0 (1) y BG3 (0).
	for hijo: Node in [fondo_montanas, fondo_pinos, _sprites, fondo_ladera, fondo_cable]:
		_raiz.add_child(hijo)
	# Paso 5: pinos, montañas y el primer poste.
	fondo_pinos.copiar(DatosTeleferico.MAPA_ARBOLES, 0, 17, 32, 15)
	fondo_montanas.copiar(DatosTeleferico.MAPA_MONTANAS, 0, 0, 30, 20)
	fondo_cable.copiar(GANCHOS, 0, 0, 5, 2)
	fondo_cable.copiar(DatosTeleferico.MAPA_POSTE, 0, 2, 2, 20)
	# Paso 6 (y LoadSprites en la bajada): la ladera inicial y el arranque del volcado por columnas.
	if not subiendo:
		fondo_ladera.copiar(DatosTeleferico.MAPA_MONTE, 0x18, 0x1A, 12, 3, 0x24)
	_iniciar_ladera()
	for datos: Array in [[0x48, 0, 14], [0x6C, 12, 17], [0x90, 24, 20], [0x00, 0, 17], [0x24, 0, 20], [0x00, 12, 20],
			[0x24, 12, 23], [0x00, 24, 23]]:
		fondo_ladera.copiar(DatosTeleferico.MAPA_MONTE, datos[1], datos[2], 12, 3, datos[0])
	# sub_8123FBC(TRUE): desplazamientos iniciales.
	if subiendo:
		_bg3_x = 0xB0
		_bg3_y = 0x10
		_bg1_x = 0
		_bg1_y = 0x50
		_cabina_origen = CABINA_SUBIENDO
		_puerta_origen = PUERTA_SUBIENDO
		_jugador_origen = JUGADOR_SUBIENDO
		_fotograma_clima = FOTOGRAMA_CENIZA_SUBIENDO
	else:
		_bg3_x = 0x60
		_bg3_y = 0xE8
		_bg1_x = 0
		_bg1_y = 0x04
		_cabina_origen = CABINA_BAJANDO
		_puerta_origen = PUERTA_BAJANDO
		_jugador_origen = JUGADOR_BAJANDO
		_fotograma_clima = FOTOGRAMA_DESPEJA_BAJANDO
	_bg0_x = 0
	_bg0_y = 0
	_crear_sprites()
	_crear_ceniza(not subiendo)
	_aplicar_desplazamientos()


func _crear_sprites() -> void:
	for i in TRAMOS_CABLE:
		var tramo := Sprite2D.new()
		tramo.texture = TEX_CABLE
		tramo.centered = false
		tramo.position = Vector2(16 * i + 0x60, 8 * i - 8)
		tramos_cable.append(tramo)
	# Del fondo al frente: subprioridades 0x68 (cable), 0x67 (cabina), 0x66 (jugador) y 0x65 (puerta).
	for tramo in tramos_cable:
		_sprites.add_child(tramo)
	cabina = Sprite2D.new()
	cabina.texture = TEX_CABINA
	cabina.centered = false
	_sprites.add_child(cabina)
	jugador_sprite = _crear_sprite_jugador()
	_sprites.add_child(jugador_sprite)
	puerta = Sprite2D.new()
	puerta.texture = TEX_PUERTA
	puerta.centered = false
	_sprites.add_child(puerta)
	_mover_sprites()


## El jugador de pie mirando al sur (AddPseudoObjectEvent con el gráfico de BRENDAN/MAY): se toman los fotogramas del
## propio personaje.
func _crear_sprite_jugador() -> AnimatedSprite2D:
	var sprite := AnimatedSprite2D.new()
	sprite.centered = false
	var admin := _administrador()
	var jugador: Node = admin.get("jugador") if admin != null else null
	var basico: AnimatedSprite2D = jugador.get_node_or_null("basico") as AnimatedSprite2D if jugador != null else null
	if basico != null and basico.sprite_frames != null:
		sprite.sprite_frames = basico.sprite_frames
		sprite.offset = basico.offset
		sprite.animation = &"idle_abajo" if basico.sprite_frames.has_animation(&"idle_abajo") else &"camina_abajo_1"
		sprite.frame = 0
	return sprite


func _crear_ceniza(activa: bool) -> void:
	ceniza = EfectoCenizaOverworld.new()
	ceniza.posicion_camara_override = Vector2.ZERO
	_raiz.add_child(ceniza)
	ceniza.configurar(1.0, Rect2(Vector2.ZERO, Vector2(FondoGba.PANTALLA)))
	ceniza.set_factor_mezcla(1.0 if activa else 0.0)
	_con_ceniza = activa


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	if not is_inside_tree():
		return null
	return get_tree().root.get_node_or_null("AdministradorMapa")


## ============================================================================
## SECUENCIA (CableCar, CableCarMainCallback_*, sub_8123878)
## ============================================================================

## Todo el viaje: fundido, escena, 570 fotogramas, fundido y warp.
func ejecutar() -> void:
	var admin := _administrador()
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	if con_animacion:
		await Singleton.transicion("oscurecer", DURACION_FUNDIDO_INICIAL)  # BeginNormalPaletteFade(0, 0, 16)
	construir()
	if con_animacion:
		Singleton.reproducir_tema(TEMA_MUSICA, true)  # FadeInNewBGM(MUS_CABLE_CAR, 1)
		await Singleton.transicion("aclarar", DURACION_FUNDIDO)
		_acumulado = 0.0
		while fase != 255 and fotograma < FOTOGRAMAS_VIAJE:
			await get_tree().process_frame
			_acumulado += get_process_delta_time() * FOTOGRAMAS_POR_SEGUNDO
			while _acumulado >= 1.0 and fotograma < FOTOGRAMAS_VIAJE:
				_acumulado -= 1.0
				avanzar_fotograma()
		await Singleton.transicion("oscurecer", DURACION_FUNDIDO)  # BeginNormalPaletteFade(3, 0, 16) + FadeOutBGM
	else:
		avanzar_fotogramas(FOTOGRAMAS_VIAJE)
	fase = 255
	# WarpIntoMap: el telón sigue negro mientras el administrador cambia de mapa.
	if admin != null and admin.has_method("conectar_escalera"):
		admin.conectar_escalera(destino, Vector2(celda_destino), Vector2.DOWN, false)
		if con_animacion:
			while is_instance_valid(admin) and int(admin.get("coneccion")) != 0:
				await get_tree().process_frame
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	viaje_terminado.emit()
	queue_free()


func avanzar_fotogramas(cantidad: int) -> void:
	for _i in cantidad:
		avanzar_fotograma()


## Un fotograma: primero la tarea del reloj y el clima (sub_8123878, prioridad 0) y luego la del desplazamiento
## (sub_81239E4 al subir, sub_8123AF8 al bajar, prioridad 1).
func avanzar_fotograma() -> void:
	if not _construido:
		construir()
	fotograma += 1
	match fase:
		0:
			if fotograma == _fotograma_clima:
				_cambiar_clima()
				fase = 1
		1:
			fase = 2
		2:
			if fotograma >= FOTOGRAMAS_VIAJE:
				fase = 3
	if fase == 255:
		return
	if sentido == Sentido.SUBIR:
		_desplazar_subiendo()
	else:
		_desplazar_bajando()
	_desplazar_ceniza()
	_aplicar_desplazamientos()
	_mover_sprites()


## ChangeWeather: la ceniza entra al subir y sale al bajar.
func _cambiar_clima() -> void:
	var activa := sentido == Sentido.SUBIR
	_con_ceniza = activa
	if ceniza == null:
		return
	if not con_animacion or not is_inside_tree():
		ceniza.set_factor_mezcla(1.0 if activa else 0.0)
		return
	var tween := create_tween()
	tween.tween_method(ceniza.set_factor_mezcla, ceniza.factor_mezcla, 1.0 if activa else 0.0, DURACION_CENIZA)


func con_ceniza() -> bool:
	return _con_ceniza


## sub_81239E4.
func _desplazar_subiendo() -> void:
	_bg3_x = (_bg3_x - 1) & 0xFF
	if fotograma % 2 == 0:
		_bg3_y = (_bg3_y - 1) & 0xFF
	if fotograma % 8 == 0:
		_bg1_x = (_bg1_x - 1) & 0xFF
		_bg1_y = (_bg1_y - 1) & 0xFF
	match _bg3_x:
		175:
			fondo_cable.rellenar(0, 0, 22, 2, 10)
		40:
			fondo_cable.rellenar(0, 3, 0, 2, 2)
		32:
			fondo_cable.rellenar(0, 2, 0, 1, 2)
		16:
			fondo_cable.copiar(GANCHOS, 0, 0, 5, 2)
			fondo_cable.copiar(DatosTeleferico.MAPA_POSTE, 0, 2, 2, 30)
			_bg3_y = 64
	_paso_ladera_subiendo()


## sub_8123AF8.
func _desplazar_bajando() -> void:
	_bg3_x = (_bg3_x + 1) & 0xFF
	if fotograma % 2 == 0:
		_bg3_y = (_bg3_y + 1) & 0xFF
	if fotograma % 8 == 0:
		_bg1_x = (_bg1_x + 1) & 0xFF
		_bg1_y = (_bg1_y + 1) & 0xFF
	match _bg3_x:
		176:
			fondo_cable.copiar(DatosTeleferico.MAPA_POSTE, 0, 2, 2, 30)
		16:
			fondo_cable.rellenar(0, 2, 0, 3, 2)
			fondo_cable.rellenar(0, 0, 22, 2, 10)
			_bg3_y = 192
		32:
			fondo_cable.poner(2, 0, GANCHOS[2])
			fondo_cable.poner(3, 0, GANCHOS[3])
			fondo_cable.poner(2, 1, GANCHOS[7])
			fondo_cable.poner(3, 1, GANCHOS[8])
		40:
			fondo_cable.poner(4, 0, GANCHOS[4])
			fondo_cable.poner(4, 1, GANCHOS[9])
	_paso_ladera_bajando()


## sub_812453C.
func _paso_ladera_subiendo() -> void:
	_bg0_x = (_base_x - _acum_x) & 0xFF
	_bg0_y = (_base_y - _acum_y) & 0xFF
	_acum_x += 1
	if _acum_x % 4 == 0:
		_acum_y += 1
	if _acum_x > 16:
		_columna_subiendo()


## sub_8124598.
func _paso_ladera_bajando() -> void:
	_bg0_x = (_base_x + _acum_x) & 0xFF
	_bg0_y = (_base_y + _acum_y) & 0xFF
	_acum_x += 1
	if _acum_x % 4 == 0:
		_acum_y += 1
	if _acum_x > 16:
		_columna_bajando()


## sub_81248AC: estado inicial del volcado de la ladera.
func _iniciar_ladera() -> void:
	_bloque = []
	for i in 9:
		var fila: Array = []
		fila.resize(12)
		fila.fill(0)
		_bloque.append(fila)
	if sentido == Sentido.SUBIR:
		_ciclo_bloque = 2
		_col_fondo = 0
		_fila_fondo = 20
		_col_bloque = 12
		_rehacer_bloque()
		_columna_subiendo()
	else:
		_ciclo_bloque = 2
		_col_fondo = 28
		_fila_fondo = 20
		_col_bloque = 4
		_rehacer_bloque()
		_columna_bajando()


## sub_812446C: el bloque de 9x12 entradas con el que se van rellenando las columnas.
func _rehacer_bloque() -> void:
	var desplazamiento := 0x24 * (_ciclo_bloque + 2)
	var k := 0
	for i in 3:
		for j in 12:
			_bloque[i][j] = DatosTeleferico.MAPA_MONTE[desplazamiento]
			desplazamiento += 1
			_bloque[i + 3][j] = DatosTeleferico.MAPA_MONTE[k]
			_bloque[i + 6][j] = DatosTeleferico.MAPA_MONTE[0x24 + k]
			k += 1
	_ciclo_bloque = (_ciclo_bloque + 1) % 3


## sub_81245F4.
func _columna_subiendo() -> void:
	_acum_x = 0
	_acum_y = 0
	_base_x = _bg0_x
	_base_y = _bg0_y
	_col_fondo = (_col_fondo + 30) % 32
	_col_bloque = (_col_bloque - 2) & 0xFF
	var primera_fila := (_fila_fondo + 23) % 32
	for i in 9:
		var fila := (primera_fila + i) % 32
		fondo_ladera.poner(_col_fondo, fila, _bloque[i][_col_bloque])
		fondo_ladera.poner((_col_fondo + 1) % 32, fila, _bloque[i][_col_bloque + 1])
	fondo_ladera.rellenar(0, (_col_fondo + 30) % 32, 0, 2, 32)
	if _col_bloque == 0:
		_fila_fondo = (_fila_fondo + 29) % 32
		_col_bloque = 12
		_rehacer_bloque()
		fondo_ladera.rellenar(0, 0, (_fila_fondo + 1) % 32, 32, 9)


## sub_812476C.
func _columna_bajando() -> void:
	_acum_x = 0
	_acum_y = 0
	_base_x = _bg0_x
	_base_y = _bg0_y
	_col_fondo = (_col_fondo + 2) % 32
	_col_bloque = (_col_bloque + 2) & 0xFF
	for i in 9:
		var fila := (_fila_fondo + i) % 32
		fondo_ladera.poner(_col_fondo, fila, _bloque[i][_col_bloque])
		fondo_ladera.poner((_col_fondo + 1) % 32, fila, _bloque[i][_col_bloque + 1])
	fondo_ladera.rellenar(0, _col_fondo, (_fila_fondo + 23) % 32, 2, 9)
	if _col_bloque == 10:
		_fila_fondo = (_fila_fondo + 3) % 32
		_col_bloque = 0xFE
		_rehacer_bloque()


## Final de sub_81239E4 / sub_8123AF8 + Ash_Main: al subir gSpriteCoordOffsetX avanza en módulo 128; al bajar retrocede en
## módulo 248 y, tras el cambio de clima (Ash_Main ya no corre), retrocede directamente unknown_6FC.
func _desplazar_ceniza() -> void:
	if sentido == Sentido.SUBIR:
		_desplazamiento_sprites_x = (_desplazamiento_sprites_x + 1) % 128
	elif fotograma < _fotograma_clima:
		_desplazamiento_sprites_x = (_desplazamiento_sprites_x + 247) % 248
	else:
		_ceniza_x = (_ceniza_x + 247) % 248
		return
	_ceniza_x = _desplazamiento_sprites_x
	while _ceniza_x > 0xEF:
		_ceniza_x -= 0xF0


func _aplicar_desplazamientos() -> void:
	# sub_807FAA8 suma unknown_6FC a la x de los sprites; EfectoCenizaOverworld resta la cámara.
	ceniza.posicion_camara_override = Vector2(-_ceniza_x, 0)
	fondo_cable.desplazamiento = Vector2i(_bg3_x, _bg3_y)
	fondo_pinos.desplazamiento = Vector2i(_bg1_x, _bg1_y)
	fondo_ladera.desplazamiento = Vector2i(_bg0_x, _bg0_y)
	fondo_montanas.desplazamiento = Vector2i.ZERO


## Posición de la cabina y de lo que va con ella (sub_8123CB8 / sub_8123D98): -(u8)(0.14 t) en x y -(u8)(0.067 t) en y al
## subir, y lo contrario al bajar; el jugador además sube y baja 1 px cada 11 fotogramas.
func desplazamiento_cabina() -> Vector2i:
	var dx := int(0.14 * fotograma) & 0xFF
	var dy := int(0.067 * fotograma) & 0xFF
	return Vector2i(-dx, -dy) if sentido == Sentido.SUBIR else Vector2i(dx, dy)


func _mover_sprites() -> void:
	if cabina == null:
		return
	var d := desplazamiento_cabina()
	cabina.position = Vector2(_cabina_origen + d)
	puerta.position = Vector2(_puerta_origen + d)
	# sub_8123D98: y2 = 17 durante 11 fotogramas (data[3] de 0 a 10) y 16 durante los 11 siguientes.
	var salto := 1 if fotograma % 22 < 11 else 0
	jugador_sprite.position = Vector2(_jugador_origen + d) + PIES_JUGADOR + Vector2(0, salto)


## Estado de depuración y tests.
func instantanea() -> Dictionary:
	return {
		"fotograma": fotograma, "fase": fase,
		"bg0": Vector2i(_bg0_x, _bg0_y), "bg1": Vector2i(_bg1_x, _bg1_y), "bg3": Vector2i(_bg3_x, _bg3_y),
		"cabina": cabina.position if cabina != null else Vector2.ZERO,
		"ceniza": _con_ceniza,
		"ceniza_x": _ceniza_x,
	}
