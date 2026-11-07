@tool
extends Node2D
class_name ControladorArbolCortable

## Árbol cortable con CORTE (OBJ_EVENT_GFX_CUTTABLE_TREE de Gen III).
##
## Referencias pokeruby: data/field_move_scripts.inc (S_CuttableTree,
## DoCutFieldEffectScript, DoTreeCutMovement), src/fldeff_cut.c
## (SetUpFieldMove_Cut: con un árbol cortable delante hay movimiento de campo;
## StartCutTreeFieldEffect: suena SE_M_CUT) y src/event_object_movement.c
## (MovementAction_CutTree: animación de 4 fotogramas y parpadeo hasta desaparecer).
##
## - Obstáculo sólido: cuelga de "NPCs", está en el grupo "NPC" y expone
##   `coord_celda`, así que AdministradorMapa.next_to_npc() lo usa para accionarlo
##   y para bloquear el paso (jugador y NPC). Mismo contrato que ControladorRocaRomper.
## - A de frente: sin Medalla Piedra o sin ningún Pokémon con CORTE solo describe
##   el árbol; con ambos pregunta si se usa CORTE.
## - Al cortarlo suena el corte, corre la animación "cortar" (el árbol se desmenuza),
##   parpadea 32 fotogramas y desaparece.
##
## Persistencia: bandera TEMPORAL "arbol_cortado_<id_arbol>" (FLAG_TEMP_11..14 de
## Rubí) en el almacén de SistemaGuardado (`set_flag_temporal`); `id_arbol` debe
## ser único (el lápiz lo rellena). ClearTempFieldEventData la borra en cada warp
## y al cruzar el borde entre mapas (AdministradorMapa llama a
## `SistemaGuardado.limpiar_temporales()`) y el árbol vuelve a salir: el nodo no
## se libera al cortarlo, queda oculto y fuera del grupo "NPC", y recupera su
## aspecto al emitirse `temporales_limpiados`. No se borra al volver de un menú o
## de una batalla, y viaja en la partida guardada como en Rubí.
##
## Pendiente respecto a Ruby: el encuentro salvaje opcional (no existe al cortar).
##
## Textos de la ROM española oficial (mirubi, extended_script_text_refs.csv).

const TILE_SIZE: int = 16
const OFFSET: Vector2 = Vector2(8, 14)

## FLAG_BADGE01_GET: Medalla Piedra, índice 0 de `medallas`.
const MEDALLA_PIEDRA: int = 0
const MOVIMIENTO_CORTE: String = "CORTE"
const PREFIJO_BANDERA: String = "arbol_cortado_"
const PAUSA_ARBOL: StringName = &"arbol_cortable"
## SE_M_CUT de pokeruby (el mismo que usa CORTE sobre la hierba alta).
const RUTA_SONIDO: String = "res://Audio/SE-AVXS/128_SE_M_CUT.wav"
const ANIMACION: StringName = &"cortar"
## Fotogramas de parpadeo tras la animación (SetMovementDelay 0x20 en CutTree_Step1).
const FOTOGRAMAS_PARPADEO: int = 32

## UseCutPromptText (sin medalla o sin Pokémon solo la primera frase: CannotUseCutText).
const TEXTO_NO_SE_PUEDE: String = "Parece que puedes CORTAR este árbol."
const TEXTO_PREGUNTA: String = "Parece que puedes CORTAR este árbol.\\p¿Usas CORTE?"

## Emitida al terminar cada mensaje de un flujo de diálogo (uso interno).
signal _mensaje_terminado

## Celda que ocupa el árbol (la lee AdministradorMapa.next_to_npc()).
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

## Identificador único del árbol (p. ej. "arbol_r116_1"); da nombre a su bandera.
@export var id_arbol: String = "":
	set(value):
		id_arbol = value
		if is_inside_tree() and Engine.is_editor_hint():
			update_configuration_warnings()

var _admin: Node = null
var _interactuando: bool = false
var _cortando: bool = false
## true mientras el árbol está cortado y oculto (a la espera de volver a crecer).
var _cortado: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		set_notify_transform(true)
		update_configuration_warnings()
		return
	coord_celda = coord
	var sprite := get_node_or_null("SpriteArbolCortable") as AnimatedSprite2D
	if sprite != null:
		sprite.stop()
		sprite.animation = ANIMACION
		sprite.frame = 0
		sprite.sprite_frames.set_animation_loop(ANIMACION, false)
	# El almacén de temporales se vacía en cada warp o cruce de mapa: el árbol vuelve a salir.
	SistemaGuardado.temporales_limpiados.connect(_al_limpiar_temporales)
	if esta_cortado(id_arbol):
		# Cortado desde la última carga de mapa: no existe (removeobject + FLAG_TEMP).
		_ocultar_cortado()
		return
	# Los NPC comprueban este grupo para no pisar el árbol (npc_base._celda_libre).
	add_to_group("NPC")


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
	if id_arbol.strip_edges().is_empty():
		avisos.append("id_arbol está vacío: el árbol reaparecerá cada vez que se recargue el mapa. Asigna un id único, p. ej. \"arbol_r116_1\".")
	if get_parent() != null and get_parent().name != &"NPCs":
		avisos.append("El árbol debe ser hijo del nodo \"NPCs\" del mapa: si no, no bloquea el paso.")
	return avisos


# ──────────────────────────────────────────────────────────────────────────────
# PERSISTENCIA
# ──────────────────────────────────────────────────────────────────────────────

## Clave de la bandera temporal del árbol `id` en SistemaGuardado.
static func clave_bandera(id: String) -> String:
	return PREFIJO_BANDERA + id


## ¿Se cortó el árbol `id` desde la última carga de mapa? Un id vacío nunca queda
## marcado.
static func esta_cortado(id: String) -> bool:
	return not id.strip_edges().is_empty() and SistemaGuardado.get_flag_temporal(clave_bandera(id))


# ──────────────────────────────────────────────────────────────────────────────
# REGLAS (puras)
# ──────────────────────────────────────────────────────────────────────────────

## ¿Se puede ofrecer CORTE al pulsar A? Hace falta la Medalla Piedra y algún
## Pokémon del equipo con CORTE; si no, solo se describe el árbol.
static func puede_usar_corte(tiene_medalla: bool, hay_pokemon_con_movimiento: bool) -> bool:
	return tiene_medalla and hay_pokemon_con_movimiento


## SetUpFieldMove_Cut: el árbol cortable al que mira el jugador (null si no hay).
static func arbol_frente_jugador() -> ControladorArbolCortable:
	var arbol_escena: SceneTree = Engine.get_main_loop() as SceneTree
	if arbol_escena == null:
		return null
	var admin: Node = arbol_escena.root.get_node_or_null("AdministradorMapa")
	if admin == null or admin.get("mapa_actual") == null or admin.get("jugador") == null:
		return null
	var arbol: Node = admin.next_to_npc(admin.celda_frente_jugador())
	return arbol as ControladorArbolCortable if arbol is ControladorArbolCortable and not arbol.esta_cortandose() else null


func esta_cortandose() -> bool:
	return _cortando


# ──────────────────────────────────────────────────────────────────────────────
# CORTAR
# ──────────────────────────────────────────────────────────────────────────────

## StartCutTreeFieldEffect (SE_M_CUT) + TreeCutMovement (cut_tree) + removeobject:
## suena el corte, corre la animación, parpadea y el árbol desaparece hasta que el
## mapa se vuelva a cargar (FLAG_TEMP). Termina cuando ya no es visible.
func cortar() -> void:
	if _cortando:
		return
	_cortando = true
	if not id_arbol.strip_edges().is_empty():
		SistemaGuardado.set_flag_temporal(clave_bandera(id_arbol), true)
	reproducir_sonido_corte()
	var sprite := get_node_or_null("SpriteArbolCortable") as AnimatedSprite2D
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(ANIMACION):
		sprite.play(ANIMACION)
		await sprite.animation_finished
		# MovementAction_CutTree_Step2: alterna la visibilidad cada fotograma.
		for _i: int in FOTOGRAMAS_PARPADEO:
			sprite.visible = not sprite.visible
			await get_tree().process_frame
			if not is_inside_tree():
				return
	# Una carga de mapa pudo hacerlo crecer de nuevo a mitad de la animación.
	if not _cortando:
		return
	_ocultar_cortado()


## removeobject: oculto, sin grupo "NPC" (ya no es obstáculo) y sin liberarse,
## para poder volver a crecer.
func _ocultar_cortado() -> void:
	_cortado = true
	_cortando = true
	remove_from_group("NPC")
	visible = false


## ClearTempFieldEventData borró la bandera: el objeto se recrea desde la
## plantilla del mapa (LoadObjEventTemplatesFromHeader).
func _al_limpiar_temporales() -> void:
	if not _cortando and not _cortado:
		return
	if esta_cortado(id_arbol):
		return
	_cortando = false
	_cortado = false
	visible = true
	var sprite := get_node_or_null("SpriteArbolCortable") as AnimatedSprite2D
	if sprite != null:
		sprite.stop()
		sprite.animation = ANIMACION
		sprite.frame = 0
		sprite.visible = true
	if not is_in_group("NPC"):
		add_to_group("NPC")


## SE_M_CUT. Cuelga de la raíz: los hijos de "NPCs" deben ser todos CanvasItem
## (AdministradorMapa.next_to_npc) y el sonido sigue tras ocultarse el árbol.
static func reproducir_sonido_corte() -> void:
	var arbol_escena := Engine.get_main_loop() as SceneTree
	if arbol_escena == null or not ResourceLoader.exists(RUTA_SONIDO):
		return
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = load(RUTA_SONIDO) as AudioStream
	reproductor.finished.connect(reproductor.queue_free)
	arbol_escena.root.add_child(reproductor)
	reproductor.play()


func _administrador() -> Node:
	if _admin == null and is_inside_tree():
		_admin = get_tree().root.get_node_or_null("AdministradorMapa")
	return _admin


# ──────────────────────────────────────────────────────────────────────────────
# INTERACCIÓN  (S_CuttableTree de field_move_scripts.inc)
# ──────────────────────────────────────────────────────────────────────────────

## Punto de entrada desde AdministradorMapa (A frente al árbol).
func evento_accion() -> void:
	if _cortando or not _preparar_interaccion():
		return
	var jugador: Node = _admin.jugador
	var pokemon: Variant = jugador.pokemon_con_movimiento(MOVIMIENTO_CORTE) if jugador != null else null
	if not puede_usar_corte(SistemaGuardado.tiene_medalla(MEDALLA_PIEDRA), pokemon != null):
		await _mostrar(TEXTO_NO_SE_PUEDE)
	elif await _preguntar_si_no(TEXTO_PREGUNTA):
		_cerrar_interaccion()
		await jugador.usar_corte(pokemon, self, true)
		return
	_cerrar_interaccion()


func _preparar_interaccion() -> bool:
	if _interactuando:
		return false
	if _administrador() == null or _admin.cuadro_dialogo == null:
		return false
	_interactuando = true
	Singleton.mantener_pausa(PAUSA_ARBOL, true)
	if _admin.jugador:
		_admin.jugador.no_control = true
	return true


func _cerrar_interaccion() -> void:
	_interactuando = false
	if _admin == null:
		return
	if _admin.cuadro_dialogo:
		_admin.cuadro_dialogo.cerrar()
	Singleton.mantener_pausa(PAUSA_ARBOL, false)
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
