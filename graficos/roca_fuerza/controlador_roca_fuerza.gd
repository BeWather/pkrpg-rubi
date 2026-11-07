@tool
extends Node2D
class_name ControladorRocaFuerza

## Roca de FUERZA (OBJ_EVENT_GFX_PUSHABLE_BOULDER de Gen III).
##
## Referencias pokeruby: data/field_move_scripts.inc (S_PushableBoulder: textos y
## flujo de A), src/fldeff_strength.c (SetUpFieldMove_Strength) y
## src/field_player_avatar.c (sub_8058F6C / TryPushBoulder: el empujón).
##
## - Obstáculo sólido: cuelga de "NPCs", está en el grupo "NPC" y expone
##   `coord_celda`, así que AdministradorMapa.next_to_npc() la usa para accionarla
##   y para bloquear el paso del jugador y de los NPC.
## - A de frente: sin medalla Calor o sin ningún Pokémon con FUERZA solo describe la
##   roca; con ambos pregunta si se usa FUERZA (la usa el jugador, character.gd usar_fuerza);
##   con FUERZA ya activa recuerda que permite moverla.
## - Con FUERZA activa, caminar contra la roca la empuja una celda si hay sitio
##   (ver puede_empujar). El jugador no avanza hasta que ha terminado de deslizarse.
##
## FUERZA activa (FLAG_SYS_USE_STRENGTH) es estado de ejecución: NO se guarda en la
## partida y AdministradorMapa la apaga al cambiar de mapa. La celda de la roca sí
## se guarda (es un EventObject de SaveBlock1, como los NPC) y se restaura al
## continuar la partida; al salir del mapa y volver, vuelve a su celda de origen,
## como los objetos de Ruby.
##
## Textos: los tres primeros son los de la ROM española oficial (mirubi,
## extended_script_text_refs.csv, FieryPath).

## Tamaño del tile y offset de anclaje (igual que npc_base y baya).
const TILE_SIZE: int = 16
const OFFSET: Vector2 = Vector2(8, 14)

## FLAG_BADGE04_GET: Medalla Calor, índice 3 de `medallas`.
const MEDALLA_CALOR: int = 3
const MOVIMIENTO_FUERZA: String = "FUERZA"

## Duración del deslizamiento: GetWalkNormalMovementAction (16 frames a 60 fps).
const DURACION_EMPUJE: float = 16.0 / 60.0
## SE_W070 de pokeruby (clave de Singleton.se).
const SONIDO_EMPUJE: String = "SE_M_STRENGTH_ATERRIZAJE"
const PAUSA_ROCA: StringName = &"roca_fuerza"

const TEXTO_NO_SE_PUEDE: String = "Es una roca enorme, pero un\nPOKéMON podría apartarla."
const TEXTO_PREGUNTA: String = "Es una roca enorme, pero un\nPOKéMON podría moverla.\\l¿Usas FUERZA?"
const TEXTO_YA_USADA: String = "Usar FUERZA ha permitido desplazar\nla roca a un lado."

## Marcas del TPTileDataMap en las que la roca no puede entrar: tile bloqueado,
## agua (SURF), desniveles (BORDE_*), agujero y suelo agrietado.
const MASCARA_DESTINO_NO_VALIDO: int = TPTileDataMap.Flags.BLOQUEO \
		| TPTileDataMap.Flags.SURF \
		| TPTileDataMap.Flags.BORDE_ARRIBA | TPTileDataMap.Flags.BORDE_ABAJO \
		| TPTileDataMap.Flags.BORDE_IZQUIERDA | TPTileDataMap.Flags.BORDE_DERECHA \
		| TPTileDataMap.Flags.AGUJERO | TPTileDataMap.Flags.SUELO_AGRIETADO

## Emitida al terminar cada mensaje de un flujo de diálogo (uso interno).
signal _mensaje_terminado

## FLAG_SYS_USE_STRENGTH. Estático: es del jugador, no de una roca concreta.
static var _fuerza_activa: bool = false
## Rocas deslizándose ahora mismo (el jugador espera mientras haya alguna).
static var _empujes_en_curso: int = 0

## Celda que ocupa la roca; la lee AdministradorMapa.next_to_npc() para accionarla
## y para bloquear el paso (jugador y NPC).
var coord_celda: Vector2i = Vector2i.ZERO

## Coordenada en tiles. Al cambiarla mueve el nodo al tile correspondiente (salvo
## durante el deslizamiento, que lo anima la propia roca).
@export var coord: Vector2i = Vector2i.ZERO:
	set(value):
		coord = value
		coord_celda = value
		if is_inside_tree() and not _deslizando:
			position = Vector2(value.x * TILE_SIZE + OFFSET.x, value.y * TILE_SIZE + OFFSET.y)
			if Engine.is_editor_hint():
				update_configuration_warnings()

var _admin: Node = null
var _deslizando: bool = false
var _interactuando: bool = false
var _tween: Tween = null


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		update_configuration_warnings()
		return
	coord_celda = coord
	# Los NPC comprueban este grupo para no pisar la roca (npc_base._celda_libre).
	add_to_group("NPC")


## Celda actual (el destino si va a mitad de empujón). La recoge
## AdministradorMapa.capturar_estado_objetos_mapa_actual() por estar en el grupo "NPC".
func exportar_estado_guardado() -> Dictionary:
	return {"cx": coord_celda.x, "cy": coord_celda.y}


## Al continuar la partida: la roca recupera la celda guardada.
func restaurar_estado_guardado(datos: Dictionary) -> void:
	coord = Vector2i(int(datos.get("cx", coord_celda.x)), int(datos.get("cy", coord_celda.y)))


func _exit_tree() -> void:
	# Si el mapa se libera con la roca a medias, el jugador no se queda bloqueado.
	if _deslizando:
		_deslizando = false
		_empujes_en_curso = maxi(0, _empujes_en_curso - 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		# Snap al tile más cercano al arrastrar en el editor.
		var celda := Vector2i(
			round((position.x - OFFSET.x) / TILE_SIZE),
			round((position.y - OFFSET.y) / TILE_SIZE)
		)
		coord = celda
		position = Vector2(coord.x * TILE_SIZE + OFFSET.x, coord.y * TILE_SIZE + OFFSET.y)


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if get_parent() != null and get_parent().name != &"NPCs":
		avisos.append("La roca debe ser hija del nodo \"NPCs\" del mapa: si no, no bloquea el paso.")
	return avisos


# ──────────────────────────────────────────────────────────────────────────────
# ESTADO DE FUERZA  (FLAG_SYS_USE_STRENGTH)
# ──────────────────────────────────────────────────────────────────────────────

static func fuerza_activa() -> bool:
	return _fuerza_activa


static func activar_fuerza() -> void:
	_fuerza_activa = true


## FlagClear(FLAG_SYS_USE_STRENGTH): cambio de mapa, VUELO, teletransporte...
static func desactivar_fuerza() -> void:
	_fuerza_activa = false


## ¿Hay alguna roca deslizándose? El jugador no puede moverse mientras tanto.
static func empuje_en_curso() -> bool:
	return _empujes_en_curso > 0


# ──────────────────────────────────────────────────────────────────────────────
# REGLAS DEL EMPUJÓN  (puras, sin escena)
# ──────────────────────────────────────────────────────────────────────────────

## Flag de bloqueo direccional de TPTileDataMap para salir de una celda hacia
## `direccion` (0 si no es una dirección cardinal).
static func flag_bloqueo_direccional(direccion: Vector2i) -> int:
	match direccion:
		Vector2i.UP:
			return TPTileDataMap.Flags.BLOQUEO_ARRIBA
		Vector2i.DOWN:
			return TPTileDataMap.Flags.BLOQUEO_ABAJO
		Vector2i.LEFT:
			return TPTileDataMap.Flags.BLOQUEO_IZQUIERDA
		Vector2i.RIGHT:
			return TPTileDataMap.Flags.BLOQUEO_DERECHA
	return 0


## ¿Puede la roca pasar de una celda a la contigua en `direccion`?
## - `flags_origen` / `flags_destino`: marcas de TPTileDataMap de ambas celdas.
## - `destino_ocupado`: NPC, otra roca, el jugador o un warp en la celda destino.
## - `destino_en_mapa`: la celda destino está dentro del mapa de la roca.
static func puede_empujar(flags_origen: int, flags_destino: int, direccion: Vector2i, destino_ocupado: bool, destino_en_mapa: bool) -> bool:
	if direccion.x * direccion.x + direccion.y * direccion.y != 1:
		return false
	if destino_ocupado or not destino_en_mapa:
		return false
	var bloqueo_salida: int = flag_bloqueo_direccional(direccion)
	if bloqueo_salida != 0 and (flags_origen & bloqueo_salida) != 0:
		return false
	return (flags_destino & MASCARA_DESTINO_NO_VALIDO) == 0


# ──────────────────────────────────────────────────────────────────────────────
# EMPUJÓN
# ──────────────────────────────────────────────────────────────────────────────

## Intenta empujar la roca una celda hacia `direccion`. Devuelve true si empieza a
## deslizarse (con su sonido); si no se puede, o FUERZA no está activa, no hace
## nada y no suena nada.
func empujar(direccion: Vector2i) -> bool:
	if _deslizando or not _fuerza_activa or not is_inside_tree():
		return false
	var destino: Vector2i = coord_celda + direccion
	var mapa: MapaConfiguracion = _mapa()
	var tp: TPTileDataMap = mapa.get_capa_resuelta(Singleton.capa_activa) if mapa != null else null
	var flags_origen: int = tp.get_flags(Vector2(coord_celda)) if tp != null else 0
	var flags_destino: int = tp.get_flags(Vector2(destino)) if tp != null else 0
	if not puede_empujar(flags_origen, flags_destino, direccion, _celda_ocupada(destino, mapa), _celda_en_mapa(destino, mapa)):
		return false

	_levantar_polvo(position)  # En la celda que deja, antes de que se desplace.
	_deslizando = true
	_empujes_en_curso += 1
	coord = destino  # Reserva la celda ya: los NPC y el jugador la ven ocupada.
	_reproducir_sonido(SONIDO_EMPUJE)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var posicion_final := Vector2(destino.x * TILE_SIZE + OFFSET.x, destino.y * TILE_SIZE + OFFSET.y)
	_tween = create_tween()
	_tween.tween_property(self, "position", posicion_final, DURACION_EMPUJE)
	_tween.finished.connect(_al_terminar_empuje, CONNECT_ONE_SHOT)
	return true


## Polvo de aterrizaje (el del salto de cornisa) en `pos_origen`, posición de la
## roca en su padre. Cuelga del padre y no de la roca para quedarse en la celda.
func _levantar_polvo(pos_origen: Vector2) -> void:
	var padre: Node = get_parent()
	if padre == null:
		return
	var polvo: Node2D = Singleton.animacion_polvo.instantiate()
	polvo.set_meta(&"sin_reflejo", true)
	polvo.position = pos_origen + Vector2(0, -4)  # Mismo ajuste que el del jugador: a los pies.
	padre.add_child(polvo)


func _al_terminar_empuje() -> void:
	if not _deslizando:
		return
	_deslizando = false
	_empujes_en_curso = maxi(0, _empujes_en_curso - 1)
	position = Vector2(coord_celda.x * TILE_SIZE + OFFSET.x, coord_celda.y * TILE_SIZE + OFFSET.y)


## MapaConfiguracion al que pertenece la roca (el ancestro, o el mapa actual).
func _mapa() -> MapaConfiguracion:
	var nodo: Node = get_parent()
	while nodo != null:
		if nodo is MapaConfiguracion:
			return nodo as MapaConfiguracion
		nodo = nodo.get_parent()
	var admin: Node = _administrador()
	return admin.get("mapa_actual") as MapaConfiguracion if admin != null else null


func _celda_en_mapa(celda: Vector2i, mapa: MapaConfiguracion) -> bool:
	if mapa == null:
		return false
	if mapa.mapa_rect_px == Rect2():
		return true
	return mapa.mapa_rect_px.has_point(Vector2(celda) * TILE_SIZE)


## NPC, otra roca, el jugador (parado o llegando) o un warp en la celda. Un objeto
## oculto (bg_hidden_item_event) no la ocupa: la roca puede quedarse encima.
func _celda_ocupada(celda: Vector2i, mapa: MapaConfiguracion) -> bool:
	var admin: Node = _administrador()
	if admin != null and (admin.has_method("ocupante_bloqueante") or admin.has_method("next_to_npc")):
		var otro: Node = admin.ocupante_bloqueante(celda) if admin.has_method("ocupante_bloqueante") \
				else admin.next_to_npc(celda)
		if otro != null and otro != self:
			return true
	var jugador: Node = admin.get("jugador") if admin != null else null
	if jugador != null:
		if "pos_celda_act" in jugador and jugador.pos_celda_act == celda:
			return true
		if jugador.has_method("obtener_celda_destino") and jugador.obtener_celda_destino() == celda:
			return true
	for grupo: StringName in [&"Escaleras", &"Salidas", &"Puertas"]:
		for warp: Node in get_tree().get_nodes_in_group(grupo):
			if mapa != null and not mapa.is_ancestor_of(warp):
				continue
			if "coord_celda" in warp and warp.coord_celda == celda:
				return true
	return false


func _reproducir_sonido(clave: String) -> void:
	if not Singleton.se.has(clave):
		return
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = Singleton.se[clave]
	reproductor.finished.connect(reproductor.queue_free)
	add_child(reproductor)
	reproductor.play()


func _administrador() -> Node:
	if _admin == null and is_inside_tree():
		_admin = get_tree().root.get_node_or_null("AdministradorMapa")
	return _admin


# ──────────────────────────────────────────────────────────────────────────────
# INTERACCIÓN  (S_PushableBoulder de field_move_scripts.inc)
# ──────────────────────────────────────────────────────────────────────────────

## Punto de entrada desde AdministradorMapa (A frente a la roca).
func evento_accion() -> void:
	if _deslizando or not _preparar_interaccion():
		return
	var jugador: Node = _admin.jugador
	var pokemon: Variant = jugador.pokemon_con_movimiento(MOVIMIENTO_FUERZA) if jugador != null else null
	if not SistemaGuardado.tiene_medalla(MEDALLA_CALOR):
		await _mostrar(TEXTO_NO_SE_PUEDE)
	elif _fuerza_activa:
		await _mostrar(TEXTO_YA_USADA)
	elif pokemon == null:
		await _mostrar(TEXTO_NO_SE_PUEDE)
	elif await _preguntar_si_no(TEXTO_PREGUNTA):
		_cerrar_interaccion()
		await jugador.usar_fuerza(pokemon)
		return
	_cerrar_interaccion()


## Bloquea al jugador para el diálogo. false si no hay caja o ya hay un flujo.
func _preparar_interaccion() -> bool:
	if _interactuando:
		return false
	if _administrador() == null or _admin.cuadro_dialogo == null:
		return false
	_interactuando = true
	Singleton.mantener_pausa(PAUSA_ROCA, true)
	if _admin.jugador:
		_admin.jugador.no_control = true
	return true


func _cerrar_interaccion() -> void:
	_interactuando = false
	if _admin == null:
		return
	if _admin.cuadro_dialogo:
		_admin.cuadro_dialogo.cerrar()
	Singleton.mantener_pausa(PAUSA_ROCA, false)
	if _admin.jugador:
		_admin.jugador.no_control = false


## Muestra un mensaje y espera a que termine (msgbox de Gen 3).
func _mostrar(texto: String) -> void:
	var cuadro: NinePatchRect = _admin.cuadro_dialogo
	cuadro.mostrar(texto, true, true, _mensaje_terminado.emit, false, cuadro.esta_activo)
	await _mensaje_terminado


## Pregunta SÍ/NO; cancelar equivale a NO.
func _preguntar_si_no(texto: String) -> bool:
	var cuadro: NinePatchRect = _admin.cuadro_dialogo
	# preguntaSiNo() exige IDLE: cerrar() y reabrir en el mismo frame no se ve.
	var continua: bool = cuadro.esta_activo
	cuadro.cerrar()
	cuadro.omitir_siguiente_sonido_inicio = continua
	cuadro.preguntaSiNo(texto)
	while true:
		var datos: Array = await cuadro.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			return not parametros.is_empty() and str(parametros[0]) == "Y"
	return false
