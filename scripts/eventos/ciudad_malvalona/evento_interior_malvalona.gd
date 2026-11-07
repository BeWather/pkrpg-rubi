## evento_interior_malvalona.gd
## Base de los guiones de los interiores de CIUDAD MALVALONA (casas, BICICLETERÍA,
## CASINO y GIMNASIO): utilidades comunes de EventoGuionizado que ahí no están (menú
## de opciones, cuadro de FICHAS) y el arranque de una conversación con un NPC.
extends EventoGuionizado
class_name EventoInteriorMalvalona

const TEXTO_MOCHILA_LLENA: String = "MOCHILA_LLENA_REGALO"
const CUADRO_FICHAS := preload("res://UI/cuadro_fichas/cuadro_fichas.tscn")

const L := Vector2.LEFT
const R := Vector2.RIGHT
const U := Vector2.UP
const D := Vector2.DOWN

## Sustituye al AdministradorMapa de la raíz del árbol (tests).
var administrador: Node = null
## Recuadro de FICHAS mientras esté a la vista (mostrar_cuadro_fichas).
var _cuadro_fichas: CuadroFichas = null


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


## lock (+ faceplayer): false si ya hay un guion en curso o no hay administrador. El
## jugador queda libre en ese caso (como el resto de eventos del proyecto).
func empezar_con(npc: Node2D, mirar_al_jugador: bool = true) -> bool:
	var administrador_npc: Node = npc.nodo_administrador if npc.nodo_administrador != null else _administrador()
	if _en_curso or not comenzar(administrador_npc):
		if not _en_curso and npc.jugador and npc.jugador.has_method("esperar_dialogo"):
			npc.jugador.esperar_dialogo(false)
		return false
	npc.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	if mirar_al_jugador:
		npc.mirar_jugador()
	return true


## multichoice: índice de la opción elegida (cancelar con B = la última). Con dos
## opciones el menú responde "Y" / "N"; con más, el índice. Una opción «descripción|precio»
## se dibuja en dos columnas. `esquina_superior_derecha`: el menú va pegado arriba a la
## derecha de la pantalla (como los multichoice de la tienda de FICHAS de Rubí).
func elegir_opcion(clave: String, opciones: PackedStringArray, esquina_superior_derecha: bool = false) -> int:
	var dialogo: NinePatchRect = admin.cuadro_dialogo
	dialogo.cerrar()
	var texto := tr(clave) if not clave.is_empty() else ""
	if esquina_superior_derecha:
		# Posición por defecto del menú: borde derecho a 216 y base a 112 (sobre el
		# cuadro de texto); crece hacia arriba una fila por opción a partir de la tercera.
		var desplazamiento := Vector2(24.0, -64.0 + 16.0 * maxi(opciones.size() - 2, 0))
		dialogo.preguntaSiNo(texto, opciones, 0, desplazamiento)
	else:
		dialogo.preguntaSiNo(texto, opciones)
	while true:
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			var respuesta := str(parametros[0]) if not parametros.is_empty() else "N"
			if respuesta == "Y":
				return 0
			if respuesta.is_valid_int():
				return clampi(int(respuesta), 0, opciones.size() - 1)
			return opciones.size() - 1
	return opciones.size() - 1


## showcoinsbox: recuadro con las FICHAS, bajo el del dinero. Se oculta con
## terminar().
func mostrar_cuadro_fichas() -> void:
	if not is_instance_valid(admin):
		return
	if not is_instance_valid(_cuadro_fichas):
		_cuadro_fichas = CUADRO_FICHAS.instantiate()
		var capa: Node = admin.get_node_or_null("Menu")
		(capa if capa != null else admin).add_child(_cuadro_fichas)
	_cuadro_fichas.establecer_fichas(MonederoFichas.fichas())


## updatecoinsbox.
func actualizar_cuadro_fichas() -> void:
	if is_instance_valid(_cuadro_fichas):
		_cuadro_fichas.establecer_fichas(MonederoFichas.fichas())


## hidecoinsbox.
func ocultar_cuadro_fichas() -> void:
	if is_instance_valid(_cuadro_fichas):
		_cuadro_fichas.queue_free()
	_cuadro_fichas = null


func terminar(control_transferido: bool = false, npcs: Array = []) -> void:
	ocultar_cuadro_fichas()
	super.terminar(control_transferido, npcs)


## Common_EventScript_ShowBagIsFull.
func mensaje_mochila_llena() -> void:
	await mensaje(TEXTO_MOCHILA_LLENA)


## Nodo hijo de la escena por NodePath relativo al evento (null si no existe).
func nodo(ruta: NodePath) -> Node2D:
	if ruta.is_empty():
		return null
	return get_node_or_null(ruta) as Node2D


## Conecta `hablado` de un NPC de tipo npc_evento.
func escuchar(ruta: NodePath, receptor: Callable) -> void:
	var npc := nodo(ruta)
	if npc != null and npc.has_signal("hablado"):
		npc.hablado.connect(receptor)
