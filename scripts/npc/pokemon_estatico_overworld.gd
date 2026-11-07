## pokemon_estatico_overworld.gd
## Pokémon salvaje fijo del overworld que se presenta como una bola del suelo (`Hideout_B1F_
## EventScript_Electrode1/2` de pokeruby `data/scripts/static_pokemon.inc`: dos ELECTRODE de Nv. 30
## disfrazados de bola en la GUARIDA). Hereda de ItemOverworld el aspecto (la bola), el registro en el
## grupo NPC, la celda (`coord`) y el bloqueo de paso.
##
## Guion de Rubí: lock, faceplayer, waitse, playmoncry <especie>, 2, delay 40, waitmoncry,
## setflag FLAG_HIDE_<..> y FLAG_SYS_CTRL_OBJ_DELETE, dowildbattle, clearflag FLAG_SYS_CTRL_OBJ_DELETE,
## release. El objeto desaparece al volver al mapa gane, huya o pierda el jugador, porque
## `FLAG_HIDE_*` se activa ANTES del combate (con la CAPTURA tampoco vuelve).
##
## No es un NPC de `npc_base` (una bola no se mueve ni mira): el mapa solo necesita el nodo en
## `NPCs`, la `especie`, el `nivel` y la bandera que lo oculta.
##
## Los REGI (DesertRuins / IslandCave / AncientTomb_EventScript_*: mismo guion con
## `setwildbattle` + ScrSpecial_StartRegiBattle) usan el mismo nodo con su sprite de overworld
## en `textura` (32x32, apoyado en el borde inferior de su celda, como OBJ_EVENT_GFX_REGIROCK),
## `musica_combate` (MUS_VS_REGI) y `transicion_combate` (B_TRANSITION_GRID_SQUARES).
@tool
extends "res://scripts/ItemOverworld.gd"
class_name PokemonEstaticoOverworld

const MOTIVO_PAUSA: StringName = &"pokemon_estatico"
const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"
## `delay 40` tras el grito (fotogramas a 60 por segundo).
const FOTOGRAMAS_ANTES_DEL_COMBATE: int = 40

## nombre_interno del Pokémon en la tabla Pokemon (p. ej. ELECTRODE).
@export var especie: String = ""
@export_range(1, 100) var nivel: int = 5
## Número nacional del grito (0 = sin grito).
@export var numero_nacional: int = 0
## `bandera_ocultar` (FLAG_HIDE_*, que se activa al enfrentarse a él) la declara ItemOverworld.
## Sprite de overworld en lugar de la bola (vacío: la bola de ow_item.tscn).
@export var textura: Texture2D = null:
	set(valor):
		textura = valor
		_aplicar_textura()
## Tema de Singleton.TEMAS_REGISTRADOS del combate ("" = la música de salvaje del mapa).
@export var musica_combate: String = ""
## Fase 2 de la transición (CatalogoTransicionesBatalla; vacía = la automática del mapa).
@export var transicion_combate: StringName = &""

## false omite el grito (tests).
var con_gritos: bool = true
## Número de combates lanzados en esta visita (tests y depuración).
var combates: int = 0
var _transferido: bool = false


func _ready() -> void:
	super._ready()
	_aplicar_textura()
	if Engine.is_editor_hint():
		return
	aplicar_bandera_ocultar()


## Un sprite de 32x32 centrado en la celda y con su borde inferior en el de la celda.
func _aplicar_textura() -> void:
	var visual := get_node_or_null("Item") as Sprite2D
	if visual == null or textura == null:
		return
	visual.texture = textura
	visual.centered = false
	# El nodo está en (8, 14) de su celda: el borde inferior de la celda queda 2 px más abajo.
	visual.offset = Vector2(-textura.get_width() / 2.0, TILE_SIZE - OFFSET.y - textura.get_height())


## Oculta el objeto si su bandera ya está activa (removeobject de un combate anterior).
func aplicar_bandera_ocultar() -> void:
	if not bandera_ocultar.is_empty() and SistemaGuardado.get_flag(bandera_ocultar):
		visible = false


func _get_configuration_warnings() -> PackedStringArray:
	var avisos := PackedStringArray()
	if especie.strip_edges().is_empty():
		avisos.append("especie está vacío: no habrá combate.")
	if bandera_ocultar.strip_edges().is_empty():
		avisos.append("bandera_ocultar está vacío: el Pokémon reaparecerá al recargar el mapa.")
	return avisos


## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null


## AdministradorMapa de la raíz del árbol, o el sustituto de los tests.
func _obtener_administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return super._obtener_administrador()


## Lo llama el sistema de interacción (AdministradorMapa) al accionar la casilla.
func evento_accion() -> void:
	if _en_proceso or not visible:
		return
	var admin: Node = _obtener_administrador()
	if admin == null or admin.get("cuadro_dialogo") == null or admin.get("battle_manager") == null:
		push_warning("[PokemonEstatico] '%s': AdministradorMapa/gestor de batalla no disponible." % name)
		return
	await _secuencia(admin)


func _secuencia(admin: Node) -> void:
	_en_proceso = true
	_admin_interaccion = admin
	_transferido = false
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	var jugador: Node = admin.get("jugador")
	if jugador != null:
		jugador.start_dialog()
		jugador.no_control = true
	# waitse + playmoncry + delay 40 + waitmoncry.
	var grito := _reproducir_grito()
	await get_tree().create_timer(FOTOGRAMAS_ANTES_DEL_COMBATE / 60.0).timeout
	if is_instance_valid(grito) and (grito as AudioStreamPlayer).playing:
		await (grito as AudioStreamPlayer).finished
	# setflag FLAG_HIDE_<..> antes de dowildbattle.
	if not bandera_ocultar.is_empty():
		SistemaGuardado.set_flag(bandera_ocultar, true)
	combates += 1
	var manager: Variant = admin.get("battle_manager")
	var ejecucion: ResultadoEjecucionBatalla = await manager.combatir_salvaje(
		especie, nivel, _lugar(admin), opciones_combate())
	if ejecucion.fue_rechazada():
		push_warning("[PokemonEstatico] Combate rechazado (%s): %s" % [ejecucion.codigo_error, ejecucion.mensaje_error])
		if not bandera_ocultar.is_empty():
			SistemaGuardado.set_flag(bandera_ocultar, false)
	else:
		visible = false  # el objeto se retira al volver al mapa
		if ResultadoBatalla.es_derrota_jugador(ejecucion.resultado):
			_transferido = manager.recuperar_derrota_estandar()
	_liberar_jugador()


## setwildbattle + dowildbattle, o la música y transición propias (ScrSpecial_StartRegiBattle).
func opciones_combate() -> OpcionesBatallaOverworld:
	var opciones := OpcionesBatallaOverworld.para_salvaje()
	opciones.musica_especifica = musica_combate
	if not transicion_combate.is_empty():
		opciones.secuencia_transicion = PackedStringArray([CatalogoTransicionesBatalla.DESTELLOS, transicion_combate])
	return opciones


## playmoncry <especie>, 2.
func _reproducir_grito() -> AudioStreamPlayer:
	var ruta := RUTA_GRITO % numero_nacional
	if not con_gritos or numero_nacional <= 0 or not ResourceLoader.exists(ruta):
		return null
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = load(ruta) as AudioStream
	reproductor.finished.connect(reproductor.queue_free)
	add_child(reproductor)
	reproductor.play()
	return reproductor


## Clave de la zona del encuentro (la sección del mapa, como los salvajes de hierba).
func _lugar(admin: Node) -> String:
	if admin.has_method("obtener_seccion_lugar_actual"):
		return str(admin.obtener_seccion_lugar_actual())
	return ""


## release. Tras una derrota el coordinador de derrota ya tiene el control del jugador.
func _liberar_jugador() -> void:
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	if not _transferido and is_instance_valid(_admin_interaccion):
		var jugador: Node = _admin_interaccion.get("jugador")
		if jugador != null:
			jugador.end_dialog()
			jugador.no_control = false
	_en_proceso = false
	_admin_interaccion = null
