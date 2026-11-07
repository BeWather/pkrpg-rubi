## evento_rival_ruta_103.gd
## Primer combate contra el rival (pokeruby Route103_EventScript_14EB92).
##
## El rival espera en (10,2) de Rubí mirando hacia arriba, apuntando qué POKéMON
## hay en la ruta. Al hablarle: murmura, suena su música, mira al jugador, "!",
## saluda y combate. Tras ganar se despide y se va saltando el saliente; el
## camino depende de hacia dónde mira el jugador (VAR_FACING):
## - mirando arriba (el jugador está debajo y le tapa el paso): rodea por la
##   izquierda (Route103_Movement_14ED67 / 14ED6B);
## - si no: baja recto (Route103_Movement_14ED71 / 14ED74).
## Perder no cambia nada: el rival sigue esperando.
##
## Efectos de la historia que Rubí aplica al final (VAR_BIRCH_LAB_STATE, rival
## en PUEBLO ESCASO…) quedan pendientes; solo se activa `bandera_completado`
## (FLAG_DEFEATED_RIVAL_ROUTE103).
extends EventoRival

## playse SE_DANSA del guion (Route103_EventScript_14ED0C / 14ED29): suena justo
## antes del paso que cruza el saliente. El salto de los NPC no lleva sonido propio.
const SONIDO_SALTO_BORDE := "SE_DANSA"

## npc_rival del mapa.
@export var rival: NodePath

## Celda donde espera, tomada de la escena.
var _celda_inicial: Vector2i = Vector2i.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var npc := _rival()
	if npc == null:
		push_warning("[RIVAL_RUTA_103] Falta el NPC del rival")
		return
	_celda_inicial = npc.coord
	npc.hablado.connect(_on_rival_hablado)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(func(_por_warp: bool) -> void: preparar())
	preparar()


func _rival() -> Node2D:
	return get_node_or_null(rival) as Node2D


## Rival fuera hasta vencerlo (FLAG_HIDE_RIVAL_ROUTE103 lo pone removeobject).
func preparar() -> void:
	if _en_curso:
		return
	var npc := _rival()
	if npc == null:
		return
	colocar(npc, _celda_inicial)
	npc.visible = not completado()


func _on_rival_hablado(npc: Node2D) -> void:
	if _en_curso or completado():
		return
	if not comenzar(npc.nodo_administrador):
		if npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	var direccion_jugador: Vector2 = _direccion_jugador()

	await mensaje(texto("MURMULLO"))
	reproducir_musica_encuentro()
	npc.mirar_jugador()  # Common_Movement_FacePlayer
	await exclamacion(npc)
	await esperar_fotogramas(48)
	await mensaje(texto("SALUDO"))

	var resultado := await combatir_rival()
	if resultado != &"victoria":
		terminar(resultado == &"derrota_transferida", [npc])
		return

	await mensaje(texto("TRAS_COMBATE"))
	admin.cuadro_dialogo.cerrar()  # closemessage
	await salir(npc, direccion_jugador)
	npc.visible = false  # removeobject
	marcar_completado()
	restaurar_musica_mapa()
	terminar(false, [npc])


## Camino de salida. Al pisar el saliente, npc_base hace el salto de dos casillas
## (jump_2_down); como en el guion, el sonido lo emite el evento justo antes.
func salir(npc: Node2D, direccion_jugador: Vector2) -> void:
	if direccion_jugador == Vector2.UP:
		await recorrer(npc, [Vector2.LEFT, Vector2.DOWN, Vector2.DOWN])
		Singleton.play_sound.emit(SONIDO_SALTO_BORDE)
		await caminar(npc, Vector2.DOWN)
		await esperar_fotogramas(16)
		await recorrer(npc, [Vector2.DOWN, Vector2.DOWN, Vector2.DOWN])
	else:
		await recorrer(npc, [Vector2.DOWN, Vector2.DOWN])
		Singleton.play_sound.emit(SONIDO_SALTO_BORDE)
		await caminar(npc, Vector2.DOWN)
		await esperar_fotogramas(16)
		await recorrer(npc, [Vector2.DOWN, Vector2.DOWN])


## VAR_FACING: dirección a la que mira el jugador al hablar.
func _direccion_jugador() -> Vector2:
	var jugador: Node = admin.get("jugador") if is_instance_valid(admin) else null
	if jugador == null:
		return Vector2.DOWN
	return jugador.facing_direction
