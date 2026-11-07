extends "res://UI/pokedex/subpantalla_pokedex.gd"
## Pestaña GRITO de la ficha. Basado en pokeruby/src/pokedex_cry_screen.c y
## Task_HandleCryScreenInput de pokedex.c.
##
## Al entrar se pausa la música (m4aMPlayStop); A reproduce el grito y la onda
## lo dibuja a la derecha mientras se desplaza 2 px por cuadro hacia la
## izquierda; la aguja del medidor sigue el volumen. B vuelve a la ficha,
## izquierda va a ÁREA y derecha a TAM. (solo capturados; si no, SE_FAILURE).
##
## La onda lee el audio real del grito con un AudioEffectCapture en su propio
## bus, como Rubí lee el búfer PCM del mezclador.

const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"
const RUTA_FRENTE: String = "res://graficos/pokemon/front/%s.png"
const BUS_GRITO: StringName = &"GritoPokedex"
const CUADRO: float = 1.0 / 60.0
## Frecuencia del mezclador del GBA en Rubí: la onda toma una muestra de cada
## dos de su búfer, así que se salta el equivalente en la del motor.
const FRECUENCIA_GBA: float = 13379.0
## Ventana de la onda: 240×56 en y 96 (LoadCryWaveformWindow).
const ANCHO_ONDA: int = 240
const ALTO_ONDA: int = 56
const CENTRO_ONDA: int = 28
const AVANCE_ONDA: int = 2
## sWaveformColor (índices 8-15 de la paleta) según la fila: azul en el centro
## y blanco en los extremos.
const COLORES_ONDA: Array[Color] = [
	Color8(148, 148, 255), Color8(156, 156, 255), Color8(172, 172, 255), Color8(189, 189, 255),
	Color8(205, 205, 255), Color8(222, 222, 255), Color8(238, 238, 255), Color8(255, 255, 255),
]
const INDICES_COLOR_ONDA: PackedInt32Array = [15, 14, 13, 12, 11, 10, 9, 8, 8, 9, 10, 11, 12, 13, 14, 15]
## Aguja: 256 unidades por vuelta; +32 en reposo (45° a la izquierda), -32 a
## fondo de escala. Avanza 5 unidades por cuadro hacia el objetivo.
const AGUJA_REPOSO: int = 0x20
const AGUJA_MAXIMO: int = -0x20
const AGUJA_PASO: int = 5
## PlayCry2 con volumen 125 de 127.
const VOLUMEN_GRITO_DB: float = -0.14

@onready var _frente: Sprite2D = $Frente
@onready var _nombre: Label = $Nombre
@onready var _onda: Control = $Onda
@onready var _aguja: Sprite2D = $Aguja
@onready var _boton_activo: Sprite2D = $BotonActivo

var reproductor_grito: AudioStreamPlayer
## Columnas visibles de la onda, de izquierda a derecha: [y desde, y hasta].
var columnas: Array[Vector2i] = []
## cryState: 0 = en silencio (línea plana); 1..8 = dibujando el búfer.
var estado_onda: int = 0
var rotacion_aguja: int = AGUJA_REPOSO
var objetivo_aguja: int = AGUJA_REPOSO
var _paso_aguja: int = AGUJA_PASO
var _bufer: PackedInt32Array = []
var _ultima_y: int = CENTRO_ONDA
var _captura: AudioEffectCapture
var _muestras: PackedFloat32Array = []
var _espera_repeticion: int = 0
var _reinicio_pendiente: int = 0
var _boton_pulsado: bool = false
var _acumulado: float = 0.0
var _musica_mapa: AudioStreamPlayer
var _musica_pausada: bool = false


func _preparar() -> void:
	_frente.texture = _obtener_frente()
	_nombre.text = str(entrada.get("nombre", "")).to_upper()
	_preparar_audio()
	columnas.resize(ANCHO_ONDA)
	columnas.fill(Vector2i(CENTRO_ONDA, CENTRO_ONDA))
	_bufer.resize(16)
	_onda.draw.connect(_dibujar_onda)
	_actualizar_aguja_visual()
	_pausar_musica()


func _obtener_frente() -> Texture2D:
	var ruta := str(entrada.get("sprite", RUTA_FRENTE % str(entrada.get("nombre", "")).to_upper()))
	return load(ruta) as Texture2D if ResourceLoader.exists(ruta) else null


## Bus propio con captura para leer lo que suena, encaminado al maestro.
func _preparar_audio() -> void:
	var indice := AudioServer.get_bus_index(BUS_GRITO)
	if indice < 0:
		AudioServer.add_bus()
		indice = AudioServer.bus_count - 1
		AudioServer.set_bus_name(indice, BUS_GRITO)
		AudioServer.set_bus_send(indice, &"Master")
		AudioServer.add_bus_effect(indice, AudioEffectCapture.new())
	_captura = AudioServer.get_bus_effect(indice, 0) as AudioEffectCapture
	_captura.clear_buffer()
	reproductor_grito = AudioStreamPlayer.new()
	reproductor_grito.name = "ReproductorGrito"
	reproductor_grito.bus = BUS_GRITO
	reproductor_grito.volume_db = VOLUMEN_GRITO_DB
	var ruta := RUTA_GRITO % int(entrada.get("nacional", 0))
	if ResourceLoader.exists(ruta):
		reproductor_grito.stream = load(ruta) as AudioStream
	add_child(reproductor_grito)


## m4aMPlayStop al entrar; se reanuda al pulsar el botón que sale.
func _pausar_musica() -> void:
	_musica_mapa = Singleton.obtener_nodo("ReproductorMusica") as AudioStreamPlayer
	if _musica_mapa != null and _musica_mapa.playing and not _musica_mapa.stream_paused:
		_musica_mapa.stream_paused = true
		_musica_pausada = true


func _al_salir() -> void:
	if _musica_pausada and is_instance_valid(_musica_mapa):
		_musica_mapa.stream_paused = false
	_musica_pausada = false


func _exit_tree() -> void:
	_al_salir()


func _al_pulsar(evento: InputEvent) -> void:
	if evento.is_action_pressed(&"btn_accion"):
		reproducir_grito()
	elif evento.is_action_pressed(&"btn_cancelar"):
		salir(Destino.PAGINA, "SE_PC_OFF")
	elif evento.is_action_pressed(&"btn_izquierda"):
		salir(Destino.AREA, "SE_DEX_PAGE")
	elif evento.is_action_pressed(&"btn_derecha"):
		if bool(entrada.get("atrapado", false)):
			salir(Destino.TAMANO, "SE_DEX_PAGE")
		else:
			_reproducir_efecto("SE_FAILURE")


## CryScreenPlayButton: 4 cuadros entre pulsaciones; si ya suena, se corta y
## vuelve a empezar 2 cuadros después.
func reproducir_grito() -> void:
	_boton_pulsado = true
	if _espera_repeticion > 0 or reproductor_grito.stream == null:
		return
	_espera_repeticion = 4
	if reproductor_grito.playing:
		reproductor_grito.stop()
		_reinicio_pendiente = 2
	else:
		_iniciar_grito()


func _iniciar_grito() -> void:
	_captura.clear_buffer()
	_muestras.clear()
	reproductor_grito.play()
	estado_onda = 1
	_rellenar_bufer()


func _process(delta: float) -> void:
	_leer_captura()
	_acumulado += delta
	while _acumulado >= CUADRO:
		_acumulado -= CUADRO
		avanzar_cuadro()


func _leer_captura() -> void:
	if _captura == null:
		return
	var disponibles := _captura.get_frames_available()
	if disponibles <= 0:
		return
	for muestra in _captura.get_buffer(disponibles):
		_muestras.append((muestra.x + muestra.y) * 0.5)
	# Basta con el último cuadro de audio.
	var maximo := int(AudioServer.get_mix_rate() / 10.0)
	if _muestras.size() > maximo:
		_muestras = _muestras.slice(_muestras.size() - maximo)


## UpdateCryWaveformWindow + LoadPlayArrowPalette + sprite de la aguja.
func avanzar_cuadro() -> void:
	if _espera_repeticion > 0:
		_espera_repeticion -= 1
	if _reinicio_pendiente > 0:
		_reinicio_pendiente -= 1
		if _reinicio_pendiente == 0:
			_iniciar_grito()
	_desplazar_onda()
	if estado_onda == 0:
		_agregar_columna(CENTRO_ONDA)
		_agregar_columna(CENTRO_ONDA)
	else:
		_agregar_columna(_y_de(_bufer[2 * (estado_onda - 1)]))
		_agregar_columna(_y_de(_bufer[2 * (estado_onda - 1) + 1]))
		if estado_onda == 2:
			_fijar_objetivo_aguja(_pico_bufer() * 208 / 256)
		elif estado_onda == 6:
			_fijar_objetivo_aguja(_bufer[10] * 208 / 256)
		estado_onda += 1
		if estado_onda > 8:
			if reproductor_grito.playing:
				estado_onda = 1
				_rellenar_bufer()
			else:
				estado_onda = 0
	_mover_aguja()
	_boton_activo.visible = _boton_pulsado or reproductor_grito.playing
	_boton_pulsado = false
	_onda.queue_redraw()


## BufferCryWaveformSegment: 16 valores, una muestra de cada dos (a la
## frecuencia del GBA), del audio más reciente; cada uno es la muestra × 2
## en un byte con signo.
func _rellenar_bufer() -> void:
	var salto := maxi(1, int(round(2.0 * AudioServer.get_mix_rate() / FRECUENCIA_GBA)))
	var inicio := maxi(0, _muestras.size() - salto * 16)
	for i in 16:
		var indice := inicio + i * salto
		var muestra := _muestras[indice] if indice < _muestras.size() else 0.0
		var valor := (int(round(clampf(muestra, -1.0, 1.0) * 127.0)) * 2) & 0xFF
		_bufer[i] = valor - 256 if valor > 127 else valor


## DrawWaveformSegment: ((amp + 127) · 256 en 16 bits) / 1152, como máximo 55.
static func _y_de(valor: int) -> int:
	var temporal := ((valor + 127) * 256) & 0xFFFF
	return mini(int(temporal / 1152.0), ALTO_ONDA - 1)


func _pico_bufer() -> int:
	var pico := 0
	for valor in _bufer:
		pico = maxi(pico, valor)
	return pico


## Cada columna nueva traza un tramo desde la y anterior (sin incluirla) hasta
## la nueva; siempre al menos 1 píxel.
func _agregar_columna(y: int) -> void:
	var desde := _ultima_y
	if y > desde:
		desde += 1
	elif y < desde:
		desde -= 1
	columnas.append(Vector2i(desde, y))
	_ultima_y = y


func _desplazar_onda() -> void:
	if columnas.size() >= AVANCE_ONDA:
		columnas = columnas.slice(AVANCE_ONDA)


func _dibujar_onda() -> void:
	var x0 := ANCHO_ONDA - columnas.size()
	for i in columnas.size():
		var tramo: Vector2i = columnas[i]
		for y in range(mini(tramo.x, tramo.y), maxi(tramo.x, tramo.y) + 1):
			_onda.draw_rect(Rect2(x0 + i, y, 1, 1), color_onda(y))


## sWaveformColor[((y / 3) - 1) & 15], con los índices 8-15 de la paleta.
static func color_onda(y: int) -> Color:
	return COLORES_ONDA[INDICES_COLOR_ONDA[(y / 3 - 1) & 15] - 8]


## SetCryMeterNeedleTarget: 0..64 va de reposo a fondo; fuera de rango, a fondo.
func _fijar_objetivo_aguja(desplazamiento: int) -> void:
	var objetivo := AGUJA_REPOSO - desplazamiento
	if objetivo > AGUJA_REPOSO or objetivo < AGUJA_MAXIMO:
		objetivo = AGUJA_MAXIMO
	objetivo_aguja = objetivo
	_paso_aguja = AGUJA_PASO


## Al pasarse del objetivo se queda en él y el objetivo vuelve a 0 (vertical).
## En silencio regresa al reposo frenando de 5 a 1 unidades por cuadro.
func _mover_aguja() -> void:
	if estado_onda == 0:
		objetivo_aguja = AGUJA_REPOSO
		_paso_aguja = maxi(1, _paso_aguja - 1) if rotacion_aguja > 0 else AGUJA_PASO
	if rotacion_aguja < objetivo_aguja:
		rotacion_aguja += _paso_aguja
		if rotacion_aguja > objetivo_aguja:
			rotacion_aguja = objetivo_aguja
			objetivo_aguja = 0
	elif rotacion_aguja > objetivo_aguja:
		rotacion_aguja -= _paso_aguja
		if rotacion_aguja < objetivo_aguja:
			rotacion_aguja = objetivo_aguja
			objetivo_aguja = 0
	_actualizar_aguja_visual()


## Positivo = antihorario en el GBA; el pivote es la base de la aguja.
func _actualizar_aguja_visual() -> void:
	_aguja.rotation = -rotacion_aguja * TAU / 256.0
