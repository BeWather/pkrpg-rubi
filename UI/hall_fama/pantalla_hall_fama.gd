extends Node2D
class_name PantallaHallFama
## HALL de la FAMA (pokeruby src/hall_of_fame.c, sub_8142320 … sub_81428A0).
##
## Los POKéMON caen uno a uno desde arriba al centro hasta su lugar, mostrando sus datos; al
## terminar el equipo suenan los aplausos con confeti y luego aparece el jugador en el centro,
## se desplaza al costado y salen los cuadros con sus datos. La escena termina al pulsar acción.

## Se emite con la pantalla ya en negro.
signal terminada
signal _accion_pulsada

const FOTOGRAMA: float = 1.0 / 60.0
const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"
const TEMA: String = "SALON_FAMA"
## BeginNormalPaletteFade(…, 12, 12, …): los POKéMON ya mostrados quedan al 75 % del fondo.
const ALFA_ATENUADO: float = 0.25
const ORIGEN_CAIDA: Vector2 = Vector2(120, -40)
const DURACION_CAIDA: float = 16.0 * FOTOGRAMA
const FOTOGRAMAS_DATOS: int = 120
const FOTOGRAMAS_GUARDADO: int = 32
const FOTOGRAMAS_APLAUSOS: int = 400
## sub_8142618: deja de caer confeti cuando quedan 110 fotogramas.
const FOTOGRAMAS_SIN_CONFETI: int = 110
const FOTOGRAMAS_ESPERA_JUGADOR: int = 120
const JUGADOR_X_FINAL: float = 160.0
const ANCHO_PANTALLA: int = 240
const CONFETI_VARIANTES: int = 17
const CONFETI_LADO: int = 8
const CONFETI_Y_MAX: float = 120.0

## sHallOfFame_MonsHalfTeamPositions: con 3 POKéMON o menos solo se usa una fila.
@export var destinos_media_fila: Array[Vector2] = [Vector2(120, 64), Vector2(56, 64), Vector2(184, 64)]
@export var textura_chico: Texture2D
@export var textura_chica: Texture2D
@export var textura_huevo: Texture2D

@onready var _fondo_chica: Sprite2D = $FondoChica
@onready var _fondo_chico: Sprite2D = $FondoChico
@onready var _slots: Array[Sprite2D] = [$Pokes/Slot0, $Pokes/Slot1, $Pokes/Slot2, $Pokes/Slot3, $Pokes/Slot4, $Pokes/Slot5]
@onready var _confeti: Node2D = $Confeti
@onready var _confeti_plantilla: Sprite2D = $Confeti/Plantilla
@onready var _jugador: Sprite2D = $Jugador
@onready var _banda: Control = $Banda
@onready var _bienvenida: Label = $Banda/Bienvenida
@onready var _datos_poke: Control = $Banda/DatosPoke
@onready var _numero: Label = $Banda/DatosPoke/Numero
@onready var _nombre: Label = $Banda/DatosPoke/Nombre
@onready var _especie: Label = $Banda/DatosPoke/Especie
@onready var _nivel: Label = $Banda/DatosPoke/Nivel
@onready var _id: Label = $Banda/DatosPoke/Id
@onready var _cuadro_jugador: Control = $CuadroJugador
@onready var _etiqueta_nombre: Label = $CuadroJugador/EtiquetaNombre
@onready var _valor_nombre: Label = $CuadroJugador/ValorNombre
@onready var _etiqueta_id: Label = $CuadroJugador/EtiquetaId
@onready var _valor_id: Label = $CuadroJugador/ValorId
@onready var _etiqueta_tiempo: Label = $CuadroJugador/EtiquetaTiempo
@onready var _valor_tiempo: Label = $CuadroJugador/ValorTiempo
@onready var _cuadro_felicidades: Control = $CuadroFelicidades
@onready var _felicidades: Label = $CuadroFelicidades/Texto
@onready var _cuadro_guardando: Control = $CuadroGuardando
@onready var _guardando: Label = $CuadroGuardando/Texto
@onready var _banda_superior: Control = $BandaSuperior
@onready var _numero_registro: Label = $BandaSuperior/Numero
@onready var _grito: AudioStreamPlayer = $Grito
@onready var _aplausos: AudioStreamPlayer = $Aplausos

var _esperando_accion: bool = false
var _posiciones: Array[Vector2] = []
var _en_registro: bool = false
var _equipos_registro: Array = []
var _equipo_visible: int = 0
var _poke_visible: int = 0


func _ready() -> void:
	for slot: Sprite2D in _slots:
		_posiciones.append(slot.position)
	if get_tree().current_scene == self:
		reproducir()


## Muestra la secuencia completa. Debe llamarse con la pantalla en negro.
func reproducir(al_grabar: Callable = Callable()) -> void:
	_preparar_jugador()
	var equipo: Array = []
	for pokemon: BasePokemon in SistemaGuardado.get_equipo():
		equipo.append(RegistroHallFama.entrada_de(pokemon))
	await Singleton.transicion("aclarar")
	Singleton.reproducir_tema(TEMA)
	if al_grabar.is_valid():
		await _grabar(al_grabar)
	await _mostrar_equipo(equipo)
	await _aplaudir(equipo.size())
	await _presentar_jugador()
	_esperando_accion = true
	await _accion_pulsada
	await Singleton.transicion("oscurecer", 0.5)
	terminada.emit()


## sub_81428CC / sub_8142A28: visor del PC, del equipo más reciente al más antiguo.
func abrir_registro() -> void:
	_preparar_jugador()
	_equipos_registro = RegistroHallFama.equipos(SistemaGuardado.datos_vivos.datos_persistentes)
	_equipo_visible = _equipos_registro.size() - 1
	_banda_superior.visible = true
	_en_registro = true
	_cargar_equipo_registro()


## sub_8142DF4: acción pasa al equipo anterior, cancelar sale y arriba/abajo cambian de POKéMON.
func _entrada_registro(event: InputEvent) -> void:
	if event.is_action_pressed("btn_accion"):
		if _equipo_visible > 0:
			_equipo_visible -= 1
			_cargar_equipo_registro()
		else:
			_cerrar_registro()
	elif event.is_action_pressed("btn_cancelar"):
		_cerrar_registro()
	elif event.is_action_pressed("btn_arriba") and _poke_visible > 0:
		_poke_visible -= 1
		_resaltar_poke_registro()
	elif event.is_action_pressed("btn_abajo") and _poke_visible < _pokes_registro().size() - 1:
		_poke_visible += 1
		_resaltar_poke_registro()
	else:
		return
	get_viewport().set_input_as_handled()


func _cerrar_registro() -> void:
	_en_registro = false
	_grito.stop()
	terminada.emit()


func _pokes_registro() -> Array:
	return _equipos_registro[_equipo_visible].get("pokemon", [])


## sub_8142B04.
func _cargar_equipo_registro() -> void:
	var pokes: Array = _pokes_registro()
	_poke_visible = 0
	_numero_registro.text = tr("HALL_FAMA_REGISTRO").replace(
		"{numero}", str(int(_equipos_registro[_equipo_visible].get("numero", 0))))
	for i in _slots.size():
		var slot: Sprite2D = _slots[i]
		slot.visible = i < pokes.size()
		if slot.visible:
			slot.texture = _textura(pokes[i])
			slot.position = _destino(i, pokes.size())
	_resaltar_poke_registro()


## sub_8142CC8.
func _resaltar_poke_registro() -> void:
	var pokes: Array = _pokes_registro()
	for i in pokes.size():
		_slots[i].modulate.a = 1.0 if i == _poke_visible else ALFA_ATENUADO
	var entrada: Dictionary = pokes[_poke_visible]
	_grito.stop()
	_reproducir_grito(entrada)
	_escribir_datos(entrada)


## sub_8142274: «GUARDANDO...» con SE_SAVE durante 32 fotogramas.
func _grabar(al_grabar: Callable) -> void:
	_cuadro_guardando.visible = true
	_banda.visible = false
	Singleton.play_sound.emit("SE_SAVE")
	al_grabar.call()
	await _esperar_fotogramas(FOTOGRAMAS_GUARDADO)
	_cuadro_guardando.visible = false
	_banda.visible = true


func _unhandled_input(event: InputEvent) -> void:
	if _en_registro:
		if not event.is_echo():
			_entrada_registro(event)
		return
	if _esperando_accion and event.is_action_pressed("btn_accion"):
		_esperando_accion = false
		get_viewport().set_input_as_handled()
		_accion_pulsada.emit()


func _preparar_jugador() -> void:
	var datos: Dictionary = SistemaGuardado.datos_vivos.jugador
	var chico: bool = str(datos.get("sexo", "M")) == "M"
	_fondo_chico.visible = chico
	_fondo_chica.visible = not chico
	_jugador.texture = textura_chico if chico else textura_chica
	_etiqueta_nombre.text = tr("HALL_FAMA_NOMBRE")
	_valor_nombre.text = str(datos.get("nombre", ""))
	_etiqueta_id.text = tr("HALL_FAMA_ID_JUGADOR")
	_valor_id.text = "%05d" % int(datos.get("id", 0))
	_etiqueta_tiempo.text = tr("HALL_FAMA_TIEMPO")
	var tiempo: int = int(SistemaGuardado.datos_vivos.tiempo_juego)
	_valor_tiempo.text = "%d : %02d" % [tiempo / 3600, (tiempo % 3600) / 60]
	_felicidades.text = tr("HALL_FAMA_FELICIDADES").replace("\\n", "\n")
	_bienvenida.text = tr("HALL_FAMA_BIENVENIDA")
	_guardando.text = tr("HALL_FAMA_GUARDANDO").replace("\\n", "\n")


func _mostrar_equipo(equipo: Array) -> void:
	var cantidad: int = mini(equipo.size(), _slots.size())
	for i in cantidad:
		var pokemon: Dictionary = equipo[i]
		var slot: Sprite2D = _slots[i]
		var destino: Vector2 = _destino(i, cantidad)
		for j in i:
			_slots[j].modulate.a = ALFA_ATENUADO
		_datos_poke.visible = false
		slot.texture = _textura(pokemon)
		slot.position = ORIGEN_CAIDA
		slot.visible = true
		var caida := create_tween()
		caida.tween_property(slot, "position", destino, DURACION_CAIDA)
		await caida.finished
		_reproducir_grito(pokemon)
		_escribir_datos(pokemon)
		await _esperar_fotogramas(FOTOGRAMAS_DATOS)


func _destino(indice: int, cantidad: int) -> Vector2:
	return destinos_media_fila[indice] if cantidad <= destinos_media_fila.size() else _posiciones[indice]


func _textura(entrada: Dictionary) -> Texture2D:
	if bool(entrada.get("huevo", false)):
		return textura_huevo
	return PokemonSpriteManager.cargar_sprite_frente(str(entrada.get("nombre_interno", "")),
		bool(entrada.get("shiny", false)), int(entrada.get("personalidad", -1)))


func _escribir_datos(entrada: Dictionary) -> void:
	var huevo: bool = bool(entrada.get("huevo", false))
	_datos_poke.visible = true
	_nombre.text = str(entrada.get("nombre", ""))
	_numero.visible = not huevo
	_especie.visible = not huevo
	_nivel.visible = not huevo
	_id.visible = not huevo
	if huevo:
		return
	_numero.text = tr("HALL_FAMA_NUMERO").replace("{numero}", "%03d" % int(entrada.get("numero_nacional", 0)))
	_especie.text = "/%s %s" % [str(entrada.get("especie", "")), _simbolo_sexo(entrada)]
	_nivel.text = tr("HALL_FAMA_NIVEL").replace("{nivel}", str(int(entrada.get("nivel", 0))))
	_id.text = tr("HALL_FAMA_ID").replace("{id}", "%05d" % (int(entrada.get("entrenador_id", 0)) & 0xFFFF))


func _simbolo_sexo(entrada: Dictionary) -> String:
	if str(entrada.get("nombre_interno", "")).begins_with("NIDORAN"):
		return ""
	match str(entrada.get("sexo", "")):
		"M":
			return "♂"
		"F":
			return "♀"
	return ""


func _reproducir_grito(entrada: Dictionary) -> void:
	var numero: int = int(entrada.get("numero_nacional", 0))
	if bool(entrada.get("huevo", false)) or numero <= 0:
		return
	var ruta: String = RUTA_GRITO % numero
	if ResourceLoader.exists(ruta):
		_grito.stream = load(ruta) as AudioStream
		_grito.play()


## sub_8142570 / sub_8142618: el equipo a color, bienvenida, aplausos y confeti.
func _aplaudir(cantidad: int) -> void:
	for i in mini(cantidad, _slots.size()):
		_slots[i].modulate.a = 1.0
	_datos_poke.visible = false
	_bienvenida.visible = true
	_aplausos.play()
	for restante in range(FOTOGRAMAS_APLAUSOS, 0, -1):
		if restante % 4 == 0 and restante > FOTOGRAMAS_SIN_CONFETI:
			_soltar_confeti()
		await get_tree().process_frame
	_bienvenida.visible = false
	for i in mini(cantidad, _slots.size()):
		_slots[i].modulate.a = ALFA_ATENUADO


## sub_81438C4 + sub_814386C: cae con vaivén sinusoidal y desaparece a los 120 px.
func _soltar_confeti() -> void:
	var trozo: Sprite2D = _confeti_plantilla.duplicate()
	var variante: int = randi() % CONFETI_VARIANTES
	trozo.region_rect = Rect2(0, variante * CONFETI_LADO, CONFETI_LADO, CONFETI_LADO)
	var x: float = float(randi() % ANCHO_PANTALLA)
	trozo.position = Vector2(x, -float(randi() % CONFETI_LADO))
	trozo.visible = true
	_confeti.add_child(trozo)
	var pixeles_por_fotograma: float = 1.0 if randi() % 4 != 0 else 2.0
	var caida := create_tween()
	caida.tween_method(_mover_confeti.bind(trozo, x), 0.0, CONFETI_Y_MAX,
		CONFETI_Y_MAX / pixeles_por_fotograma * FOTOGRAMA)
	caida.tween_callback(trozo.queue_free)


func _mover_confeti(recorrido: float, trozo: Sprite2D, x: float) -> void:
	trozo.position = Vector2(x + sin(recorrido * 0.1) * 9.0, recorrido)


## sub_8142738 / sub_8142794: el jugador en el centro; a los 2 s se desplaza a un costado.
func _presentar_jugador() -> void:
	_banda.visible = false
	_jugador.visible = true
	await _esperar_fotogramas(FOTOGRAMAS_ESPERA_JUGADOR)
	var desplazo := create_tween()
	desplazo.tween_property(_jugador, "position:x", JUGADOR_X_FINAL,
		(JUGADOR_X_FINAL - _jugador.position.x) * FOTOGRAMA)
	await desplazo.finished
	_cuadro_jugador.visible = true
	_cuadro_felicidades.visible = true


func _esperar_fotogramas(n: int) -> void:
	await get_tree().create_timer(n * FOTOGRAMA).timeout
