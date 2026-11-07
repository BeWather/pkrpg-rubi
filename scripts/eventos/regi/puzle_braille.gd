## puzle_braille.gd
## Puzles en braille de la cadena de los REGI (pokeruby src/braille_puzzles.c y
## data/maps/{SealedChamber_*,DesertRuins,IslandCave,AncientTomb}/scripts.inc):
##
## - EXCAVAR (CÁMARA SELLADA, sala exterior; ShouldDoBrailleDigEffect): EXCAVAR desde una de
##   `celdas` (bajo el braille del fondo) abre la entrada a la sala interior (DoBrailleDigEffect).
## - FUERZA (RUINAS DESIERTO; ShouldDoBrailleStrengthEffect): FUERZA desde una de `celdas`
##   abre la cámara de REGIROCK (DoBrailleStrengthEffect).
## - VUELO (TUMBA ANTIGUA; ShouldDoBrailleFlyEffect): VUELO desde el centro de la sala abre la
##   cámara de REGISTEEL (UseFlyAncientTomb_Finish). Se puede usar en este interior.
## - ESPERA (CUEVA INSULAR; DoBrailleWait / Task_BrailleWait): leer cualquiera de los grabados
##   de `carteles` y no pulsar nada durante 7200 fotogramas (2 minutos) abre la cámara de
##   REGICE (S_OpenRegiceChamber). Cualquier tecla cierra el grabado y cancela la espera.
## - RELICANTH_WAILORD (CÁMARA SELLADA, sala interior; SealedChamber_InnerRoom_EventScript_15F1E8):
##   tras leer el grabado del fondo, con RELICANTH primero y WAILORD último en el equipo
##   (CheckRelicanthWailord) tiembla la sala, suenan tres puertas y se activa
##   FLAG_REGI_DOORS_OPENED, que abre las entradas de las RUTAS 105, 111 y 120.
##
## En los cuatro primeros, abrir es: `abrir()` de cada CierrePorBandera de `cierres` (que activa
## `bandera`), DrawWholeMapView y SE_BANG. Los movimientos de campo llegan desde el menú del
## equipo (pantalla_equipo_controlador / menu_pausa), que preguntan antes a
## `PuzleBraille.para_movimiento()`: como en Rubí, el puzle se comprueba antes que las
## condiciones normales del movimiento (VUELO en un interior, EXCAVAR sin entrada exterior).
## Con el puzle resuelto el movimiento vuelve a su uso normal.
extends EventoGuionizado
class_name PuzleBraille

enum Tipo { EXCAVAR, FUERZA, VUELO, ESPERA, RELICANTH_WAILORD }

const GRUPO: StringName = &"puzle_braille"
const MOTIVO_PAUSA: StringName = &"puzle_braille"
const MOVIMIENTO_POR_TIPO: Dictionary = {Tipo.EXCAVAR: "EXCAVAR", Tipo.FUERZA: "FUERZA", Tipo.VUELO: "VUELO"}
const SONIDO_APERTURA: String = "SE_BANG"

## Task_BrailleWait: data[1] = 7200 fotogramas sin pulsar nada y 30 más antes de abrir.
const FOTOGRAMAS_ESPERA: int = 7200
const FOTOGRAMAS_TRAS_ESPERA: int = 30

## FLAG_REGI_DOORS_OPENED.
const BANDERA_PUERTAS_REGI: String = "regi_puertas_abiertas"
## FLAG_SYS_BRAILLE_DIG / _STRENGTH / _WAIT / _FLY.
const BANDERA_BRAILLE_EXCAVAR: String = "braille_excavar"
const BANDERA_BRAILLE_FUERZA: String = "braille_fuerza"
const BANDERA_BRAILLE_ESPERA: String = "braille_espera"
const BANDERA_BRAILLE_VUELO: String = "braille_vuelo"

const TEXTO_PUERTA_LEJANA: String = "CAMARA_SELLADA_PUERTA_LEJANA"
## SE_TRUCK_MOVE no está en Singleton.se (es un bucle que se extrajo cortado a ~4 s); aquí
## suena una vez durante el primer temblor (250 fotogramas) y lo corta el primer SE_DOOR.
const SONIDO_TEMBLOR := preload("res://Audio/SE-AVXS/049_SE_TRUCK_MOVE.wav")
const SONIDO_PUERTA: String = "SE_DOOR"
## DoSealedChamberShakingEffect1 / 2: (amplitud vertical, cambios de signo), cada 5 fotogramas.
const TEMBLOR_LARGO: Vector2i = Vector2i(2, 50)
const TEMBLOR_CORTO: Vector2i = Vector2i(3, 2)
const FOTOGRAMAS_PASO_TEMBLOR: int = 5
const FOTOGRAMAS_TRAS_TEMBLOR: int = 40
const ESPECIE_PRIMERA: String = "RELICANTH"
const ESPECIE_ULTIMA: String = "WAILORD"

@export var tipo: Tipo = Tipo.FUERZA
## Bandera que activa el puzle resuelto (la de los CierrePorBandera de `cierres`).
@export var bandera: String = ""
## Celdas desde las que el movimiento de campo resuelve el puzle.
@export var celdas: Array[Vector2i] = []
## CierrePorBandera que se abren al resolverlo.
@export var cierres: Array[NodePath] = []
## CartelImagen que inician la espera (ESPERA) o la comprobación del equipo (RELICANTH_WAILORD).
@export var carteles: Array[NodePath] = []

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## Fotogramas de espera de ESPERA (tests).
var fotogramas_espera: int = FOTOGRAMAS_ESPERA
## false: sin temblores ni pausas de audio (tests).
var con_efectos: bool = true
## true: la próxima comprobación de tecla de la espera la da por pulsada (tests).
var tecla_simulada: bool = false
var _esperando: bool = false


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	add_to_group(GRUPO)
	if Engine.is_editor_hint():
		return
	for ruta in carteles:
		var cartel := get_node_or_null(ruta) as CartelImagen
		if cartel == null:
			continue
		if tipo == Tipo.ESPERA:
			cartel.visor_abierto.connect(_on_visor_abierto)
		elif tipo == Tipo.RELICANTH_WAILORD:
			cartel.visor_cerrado.connect(_on_grabado_leido)


func resuelto() -> bool:
	return not bandera.is_empty() and SistemaGuardado.get_flag(bandera)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa") if is_inside_tree() else null


## ¿Resuelve el puzle usar `movimiento` con el jugador en `celda`? (ShouldDoBraille*Effect)
func acepta(movimiento: String, celda: Vector2i) -> bool:
	return MOVIMIENTO_POR_TIPO.get(tipo, "") == movimiento and not resuelto() and celda in celdas


## Puzle del mapa actual que resuelve `movimiento` desde la celda del jugador, o null.
static func para_movimiento(movimiento: String) -> PuzleBraille:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null:
		return null
	var admin: Node = arbol.root.get_node_or_null("AdministradorMapa")
	if admin == null:
		return null
	var mapa := admin.get("mapa_actual") as MapaConfiguracion
	var jugador: Node = admin.get("jugador")
	if mapa == null or jugador == null:
		return null
	# La celda del jugador como en AdministradorMapa.celda_frente_jugador (sin el paso).
	var desfase: Variant = admin.get("jugador_offset")
	var origen: Vector2 = jugador.global_position - (desfase as Vector2 if desfase is Vector2 else Vector2.ZERO)
	var celda := Vector2i(((origen - mapa.global_position) / Singleton.TILE_SIZE).floor())
	for nodo in arbol.get_nodes_in_group(GRUPO):
		var puzle := nodo as PuzleBraille
		if puzle != null and mapa.is_ancestor_of(puzle) and puzle.acepta(movimiento, celda):
			return puzle
	return null


## FLDEFF_USE_STRENGTH / FLDEFF_USE_DIG / FLDEFF_USE_FLY_ANCIENT_TOMB: sale el Pokémon y se
## abre la cámara, sin mensaje.
func ejecutar(pokemon: BasePokemon, jugador: Node) -> void:
	if not comenzar(_administrador()):
		return
	if jugador != null and jugador.has_method("usar_movimiento_braille"):
		await jugador.usar_movimiento_braille(pokemon)
	abrir()
	terminar()


## setmetatile de la entrada + DrawWholeMapView + SE_BANG + setflag.
func abrir() -> void:
	for ruta in cierres:
		var cierre := get_node_or_null(ruta) as CierrePorBandera
		if cierre != null:
			cierre.abrir()
	if not bandera.is_empty():
		SistemaGuardado.set_flag(bandera, true)
	Singleton.play_sound.emit(SONIDO_APERTURA)


# ---------------------------------------------------------------------------
# ESPERA (CUEVA INSULAR)
# ---------------------------------------------------------------------------

## IslandCave_EventScript_15EF59 / 15EF7C: con el puzle sin resolver, DoBrailleWait.
## Task_BrailleWait cuenta 7200 fotogramas desde que se abre el grabado:
## - case 1 (grabado abierto): la primera tecla lo cierra con SE_SELECT, pero la cuenta
##   sigue y el jugador sigue bloqueado (lockall). Si llega a 0 así, se borra el grabado,
##   30 fotogramas más y se abre la cámara.
## - case 2 (grabado cerrado): una segunda tecla devuelve el control y cancela la espera;
##   si la cuenta llega a 0 sin pulsar nada, se abre la cámara.
func _on_visor_abierto(visor: VisorImagenCartel) -> void:
	if resuelto() or _esperando:
		return
	visor.cerrar_con_cualquier_tecla = true
	_esperando = true
	# Conectada después que la del cartel: corre cuando este ya ha soltado al jugador,
	# y lo vuelve a bloquear en el mismo fotograma.
	visor.cerrado.connect(_on_grabado_cerrado_en_espera.bind(visor), CONNECT_ONE_SHOT)
	var restantes := fotogramas_espera
	while restantes > 0 and _visor_sigue_abierto(visor):
		await get_tree().process_frame
		restantes -= 1
	if restantes <= 0:
		# case 1 -> 3 -> 4: se borra el grabado, 30 fotogramas y S_OpenRegiceChamber.
		if not comenzar(_administrador()):
			_esperando = false
			return
		if is_instance_valid(visor):
			visor.cerrar()
		await esperar_fotogramas(FOTOGRAMAS_TRAS_ESPERA)
		_abrir_camara_regice()
		return
	# case 2: grabado cerrado con una tecla, jugador bloqueado por el guion.
	if not en_curso():
		_esperando = false
		return
	while restantes > 0:
		await get_tree().process_frame
		if _tecla_pulsada():
			_esperando = false
			terminar()
			return
		restantes -= 1
	_abrir_camara_regice()


## `visor` sin tipo: puede llegar ya liberado.
func _visor_sigue_abierto(visor: Variant) -> bool:
	return is_instance_valid(visor) and not (visor as Node).is_queued_for_deletion()


## case 1 con la primera tecla: Menu_EraseScreen + SE_SELECT; el jugador no recupera el
## control (sigue el lockall del guion del grabado).
func _on_grabado_cerrado_en_espera(visor: Variant) -> void:
	if not is_instance_valid(visor) or not (visor as VisorImagenCartel).cerrado_por_tecla:
		return
	Singleton.play_sound.emit("SE_SELECT")
	comenzar(_administrador())


## BrailleWait_CheckButtonPress: A, B, START, SELECT o la cruceta.
func _tecla_pulsada() -> bool:
	if tecla_simulada:
		tecla_simulada = false
		return true
	for accion: StringName in VisorImagenCartel.ACCIONES_CUALQUIER_TECLA:
		if Input.is_action_just_pressed(accion):
			return true
	return false


## case 4: S_OpenRegiceChamber y releaseall.
func _abrir_camara_regice() -> void:
	_esperando = false
	abrir()
	terminar()


# ---------------------------------------------------------------------------
# RELICANTH_WAILORD (CÁMARA SELLADA, sala interior)
# ---------------------------------------------------------------------------

## CheckRelicanthWailord: RELICANTH el primero y WAILORD el último del equipo (los huevos son
## SPECIES_EGG para MON_DATA_SPECIES2).
static func equipo_relicanth_wailord(equipo: Array) -> bool:
	if equipo.is_empty():
		return false
	var primero := equipo[0] as BasePokemon
	var ultimo := equipo[equipo.size() - 1] as BasePokemon
	return primero != null and not primero.huevo and primero.nombre_interno == ESPECIE_PRIMERA \
		and ultimo != null and not ultimo.huevo and ultimo.nombre_interno == ESPECIE_ULTIMA


func _on_grabado_leido() -> void:
	if resuelto() or not equipo_relicanth_wailord(SistemaGuardado.get_equipo()):
		return
	await abrir_puertas_regi()


## SealedChamber_InnerRoom_EventScript_15F1E8 desde `fadeoutbgm 0`.
func abrir_puertas_regi() -> void:
	if not comenzar(_administrador()):
		return
	var musica := _pausar_musica()
	var temblor := _reproducir_temblor()
	await _sacudir(TEMBLOR_LARGO)
	await esperar_fotogramas(FOTOGRAMAS_TRAS_TEMBLOR)
	for _puerta in 3:
		await _sacudir(TEMBLOR_CORTO)
		if is_instance_valid(temblor):
			temblor.stop()
			temblor.queue_free()
		Singleton.play_sound.emit(SONIDO_PUERTA)
		await esperar_fotogramas(FOTOGRAMAS_TRAS_TEMBLOR)
	await mensaje(TEXTO_PUERTA_LEJANA)
	_reanudar_musica(musica)
	SistemaGuardado.set_flag(bandera if not bandera.is_empty() else BANDERA_PUERTAS_REGI, true)
	terminar()


## SealedChamberShakingEffect: cada 5 fotogramas cambia de signo la amplitud vertical.
func _sacudir(temblor: Vector2i) -> void:
	var camara: Node = admin.get("cam") if is_instance_valid(admin) else null
	if not con_efectos or camara == null or not camara.has_method("sacudir_camara_pasos"):
		return
	camara.call("sacudir_camara_pasos", 0, temblor.x, temblor.y, FOTOGRAMAS_PASO_TEMBLOR)
	await esperar_fotogramas(temblor.y * FOTOGRAMAS_PASO_TEMBLOR)


func _reproducir_temblor() -> AudioStreamPlayer:
	if not con_efectos:
		return null
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = SONIDO_TEMBLOR
	add_child(reproductor)
	reproductor.play()
	return reproductor


## fadeoutbgm 0: la música del mapa se calla hasta el fadeinbgm. Como la Fanfarria, se
## para también su _process, que la relanzaría.
func _pausar_musica() -> AudioStreamPlayer:
	if not con_efectos:
		return null
	var musica := Singleton.obtener_nodo("ReproductorMusica") as AudioStreamPlayer
	if musica != null:
		musica.set_meta(&"procesaba_antes_de_puzle", musica.is_processing())
		musica.set_process(false)
		musica.stream_paused = true
	return musica


## fadeinbgm 0.
func _reanudar_musica(musica: AudioStreamPlayer) -> void:
	if is_instance_valid(musica):
		musica.stream_paused = false
		musica.set_process(bool(musica.get_meta(&"procesaba_antes_de_puzle", true)))
		musica.remove_meta(&"procesaba_antes_de_puzle")
