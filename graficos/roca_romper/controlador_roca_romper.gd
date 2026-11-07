@tool
extends Node2D
class_name ControladorRocaRomper

## Roca rompible con GOLPE ROCA (OBJ_EVENT_GFX_BREAKABLE_ROCK de Gen III).
##
## Referencias pokeruby: data/field_move_scripts.inc (S_BreakableRock,
## S_UseRockSmash, DoRockSmashMovement) y src/fldeff_rocksmash.c
## (SetUpFieldMove_RockSmash: solo hay movimiento de campo con una roca delante).
##
## - Obstáculo sólido: cuelga de "NPCs", está en el grupo "NPC" y expone
##   `coord_celda`, así que AdministradorMapa.next_to_npc() la usa para accionarla
##   y para bloquear el paso (jugador y NPC).
## - A de frente: sin Medalla Dinamo o sin ningún Pokémon con GOLPEROCA solo
##   describe la roca; con ambos pregunta si se usa GOLPE ROCA.
## - Al romperla suena el golpe, corre la animación "romper" y la roca desaparece.
##
## Persistencia: bandera "roca_rota_<id_roca>"; `id_roca` debe ser único (el lápiz
## lo rellena). Casi todas las rocas de Rubí usan FLAG_TEMP_11..1D: la bandera es
## TEMPORAL (`set_flag_temporal`), viaja en la partida guardada y
## ClearTempFieldEventData la borra en cada warp o cruce de mapa
## (`SistemaGuardado.limpiar_temporales()`), así que la roca vuelve a salir al
## volver a entrar. Como el árbol cortable, el nodo no se libera al romperla:
## queda oculto y fuera del grupo "NPC" y reaparece con `temporales_limpiados`.
## Las pocas con bandera propia (FLAG_HIDE_RUSTURF_TUNNEL_ROCK_1/2,
## FLAG_VICTORY_ROAD_ROCK) marcan `bandera_permanente` y no vuelven nunca.
##
## Al acabar emite `rota`: el TÚNEL FERVERGAL la escucha (TryUpdateRusturfTunnelState)
## y character.usar_golpe_roca intenta después el encuentro salvaje
## (ScrSpecial_RockSmashWildEncounter).
##
## Textos de la ROM española oficial (mirubi, extended_script_text_refs.csv).

const TILE_SIZE: int = 16
const OFFSET: Vector2 = Vector2(8, 14)

## FLAG_BADGE03_GET: Medalla Dinamo, índice 2 de `medallas`.
const MEDALLA_DINAMO: int = 2
const MOVIMIENTO_GOLPE_ROCA: String = "GOLPEROCA"
const PREFIJO_BANDERA: String = "roca_rota_"
const PAUSA_ROCA: StringName = &"roca_romper"
## Sonido de Golpe Roca del proyecto (equivalente a SE_W088 de pokeruby).
const RUTA_SONIDO: String = "res://Audio/SE/PRSFX- Rock Smash.wav"
const ANIMACION: StringName = &"romper"

const TEXTO_NO_SE_PUEDE: String = "Es una roca muy dura, pero un\nPOKéMON podría hacerla añicos."
const TEXTO_PREGUNTA: String = "Parece que se puede romper esta roca.\n¿Usas GOLPE ROCA?"

## La roca acaba de romperse (ya oculta y sin bloquear el paso).
signal rota

## Emitida al terminar cada mensaje de un flujo de diálogo (uso interno).
signal _mensaje_terminado

## Celda que ocupa la roca (la lee AdministradorMapa.next_to_npc()).
var coord_celda: Vector2i = Vector2i.ZERO

## Coordenada en tiles. Al cambiarla mueve el nodo al tile correspondiente.
@export var coord: Vector2i = Vector2i.ZERO:
	set(value):
		coord = value
		coord_celda = value
		if is_inside_tree():
			position = Vector2(value.x * TILE_SIZE + OFFSET.x, value.y * TILE_SIZE + OFFSET.y)
			if Engine.is_editor_hint():
				update_configuration_warnings()

## Identificador único de la roca (p. ej. "roca_r116_1"); da nombre a su bandera.
@export var id_roca: String = "":
	set(value):
		id_roca = value
		if is_inside_tree() and Engine.is_editor_hint():
			update_configuration_warnings()

## Bandera de evento propia en Rubí (no FLAG_TEMP): rota, no reaparece nunca.
@export var bandera_permanente: bool = false

var _admin: Node = null
var _interactuando: bool = false
var _rompiendo: bool = false
## Rota y oculta hasta que se borren las banderas temporales.
var _rota: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		update_configuration_warnings()
		return
	coord_celda = coord
	_migrar_bandera_permanente()
	_reiniciar_sprite()
	# El almacén de temporales se vacía en cada warp o cruce de mapa: la roca vuelve a salir.
	SistemaGuardado.temporales_limpiados.connect(_al_limpiar_temporales)
	if esta_rota(id_roca):
		# Ya rota: no existe (removeobject + su bandera de Rubí).
		_ocultar_rota()
		return
	# Los NPC comprueban este grupo para no pisar la roca (npc_base._celda_libre).
	add_to_group("NPC")


## Partidas anteriores guardaban toda roca rota como bandera permanente: en una
## roca FLAG_TEMP pasa al almacén temporal (sigue rota hasta el próximo warp).
func _migrar_bandera_permanente() -> void:
	if bandera_permanente or id_roca.strip_edges().is_empty():
		return
	var clave := clave_bandera(id_roca)
	if SistemaGuardado.get_flag(clave):
		SistemaGuardado.delete_flag(clave)
		SistemaGuardado.set_flag_temporal(clave, true)


func _reiniciar_sprite() -> void:
	var sprite := get_node_or_null("SpriteRocaRomper") as AnimatedSprite2D
	if sprite != null:
		sprite.stop()
		sprite.animation = ANIMACION
		sprite.frame = 0
		sprite.visible = true
		sprite.sprite_frames.set_animation_loop(ANIMACION, false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and Engine.is_editor_hint():
		var celda := Vector2i(
			round((position.x - OFFSET.x) / TILE_SIZE),
			round((position.y - OFFSET.y) / TILE_SIZE)
		)
		coord = celda
		position = Vector2(coord.x * TILE_SIZE + OFFSET.x, coord.y * TILE_SIZE + OFFSET.y)


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if id_roca.strip_edges().is_empty():
		avisos.append("id_roca está vacío: la roca reaparecerá cada vez que se recargue el mapa. Asigna un id único, p. ej. \"roca_r116_1\".")
	if get_parent() != null and get_parent().name != &"NPCs":
		avisos.append("La roca debe ser hija del nodo \"NPCs\" del mapa: si no, no bloquea el paso.")
	return avisos


# ──────────────────────────────────────────────────────────────────────────────
# PERSISTENCIA
# ──────────────────────────────────────────────────────────────────────────────

## Clave de la bandera de la roca `id` en SistemaGuardado.
static func clave_bandera(id: String) -> String:
	return PREFIJO_BANDERA + id


## ¿Está rota la roca `id`? Mira la bandera temporal (desde la última carga de
## mapa) y la permanente. Un id vacío nunca queda marcado.
static func esta_rota(id: String) -> bool:
	if id.strip_edges().is_empty():
		return false
	var clave := clave_bandera(id)
	return SistemaGuardado.get_flag_temporal(clave) or SistemaGuardado.get_flag(clave)


# ──────────────────────────────────────────────────────────────────────────────
# REGLAS (puras)
# ──────────────────────────────────────────────────────────────────────────────

## ¿Se puede ofrecer GOLPE ROCA al pulsar A? Hace falta la Medalla Dinamo y algún
## Pokémon del equipo con GOLPEROCA; si no, solo se describe la roca.
static func puede_usar_golpe_roca(tiene_medalla: bool, hay_pokemon_con_movimiento: bool) -> bool:
	return tiene_medalla and hay_pokemon_con_movimiento


## SetUpFieldMove_RockSmash: la roca rompible a la que mira el jugador (null si no hay).
static func roca_frente_jugador() -> ControladorRocaRomper:
	var arbol: SceneTree = Engine.get_main_loop() as SceneTree
	if arbol == null:
		return null
	var admin: Node = arbol.root.get_node_or_null("AdministradorMapa")
	if admin == null or admin.get("mapa_actual") == null or admin.get("jugador") == null:
		return null
	var roca: Node = admin.next_to_npc(admin.celda_frente_jugador())
	return roca as ControladorRocaRomper if roca is ControladorRocaRomper and not roca.esta_rompiendose() else null


## Solo mientras corre la animación: una roca ya rota y oculta no cuenta.
func esta_rompiendose() -> bool:
	return _rompiendo and not _rota


# ──────────────────────────────────────────────────────────────────────────────
# ROMPER
# ──────────────────────────────────────────────────────────────────────────────

## RockSmashMovement (rock_smash_break) + removeobject: suena el golpe, corre la
## animación y la roca desaparece hasta que el mapa se vuelva a cargar (FLAG_TEMP)
## o para siempre (`bandera_permanente`). Termina cuando ya no es visible.
func romper() -> void:
	if _rompiendo:
		return
	_rompiendo = true
	if not id_roca.strip_edges().is_empty():
		if bandera_permanente:
			SistemaGuardado.set_flag(clave_bandera(id_roca), true)
		else:
			SistemaGuardado.set_flag_temporal(clave_bandera(id_roca), true)
	_reproducir_sonido()
	var sprite := get_node_or_null("SpriteRocaRomper") as AnimatedSprite2D
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(ANIMACION):
		sprite.play(ANIMACION)
		await sprite.animation_finished
		if not is_inside_tree():
			return
	# Una carga de mapa pudo hacerla reaparecer a mitad de la animación.
	if not _rompiendo:
		return
	_ocultar_rota()
	rota.emit()


## removeobject: oculta, sin grupo "NPC" (ya no es obstáculo) y sin liberarse,
## para poder reaparecer.
func _ocultar_rota() -> void:
	_rota = true
	_rompiendo = true
	remove_from_group("NPC")
	visible = false


## ClearTempFieldEventData borró la bandera: el objeto se recrea desde la
## plantilla del mapa (LoadObjEventTemplatesFromHeader).
func _al_limpiar_temporales() -> void:
	if not _rompiendo and not _rota:
		return
	if esta_rota(id_roca):
		return
	_rompiendo = false
	_rota = false
	visible = true
	_reiniciar_sprite()
	if not is_in_group("NPC"):
		add_to_group("NPC")


func _reproducir_sonido() -> void:
	if not ResourceLoader.exists(RUTA_SONIDO):
		return
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = load(RUTA_SONIDO) as AudioStream
	# Cuelga de la raíz: el mapa de la roca puede liberarse antes de que acabe el
	# sonido y los hijos de "NPCs" deben ser todos CanvasItem (AdministradorMapa.next_to_npc).
	reproductor.finished.connect(reproductor.queue_free)
	get_tree().root.add_child(reproductor)
	reproductor.play()


func _administrador() -> Node:
	if _admin == null and is_inside_tree():
		_admin = get_tree().root.get_node_or_null("AdministradorMapa")
	return _admin


# ──────────────────────────────────────────────────────────────────────────────
# INTERACCIÓN  (S_BreakableRock de field_move_scripts.inc)
# ──────────────────────────────────────────────────────────────────────────────

## Punto de entrada desde AdministradorMapa (A frente a la roca).
func evento_accion() -> void:
	if _rompiendo or not _preparar_interaccion():
		return
	var jugador: Node = _admin.jugador
	var pokemon: Variant = jugador.pokemon_con_movimiento(MOVIMIENTO_GOLPE_ROCA) if jugador != null else null
	if not puede_usar_golpe_roca(SistemaGuardado.tiene_medalla(MEDALLA_DINAMO), pokemon != null):
		await _mostrar(TEXTO_NO_SE_PUEDE)
	elif await _preguntar_si_no(TEXTO_PREGUNTA):
		_cerrar_interaccion()
		await jugador.usar_golpe_roca(pokemon, self, true)
		return
	_cerrar_interaccion()


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


func _mostrar(texto: String) -> void:
	var cuadro: NinePatchRect = _admin.cuadro_dialogo
	cuadro.mostrar(texto, true, true, _mensaje_terminado.emit, false, cuadro.esta_activo)
	await _mensaje_terminado


## Pregunta SÍ/NO; cancelar equivale a NO.
func _preguntar_si_no(texto: String) -> bool:
	var cuadro: NinePatchRect = _admin.cuadro_dialogo
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
