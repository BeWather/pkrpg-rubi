## evento_familia_estratega.gd
## Familia ESTRATEGA ante la puerta de su casa en la Ruta 111 (pokeruby
## Route111_EventScript_1501D1 y Route111_MapScript1_14FFB9).
##
## Hablar con VÍCTOR ofrece cuatro combates seguidos sin presentación de
## entrenador (trainerbattle_no_intro). Tras cada victoria el vencido entra en la
## casa y sale el siguiente miembro por la puerta. Perder corta la serie: al
## volver a activarse el mapa solo queda VÍCTOR y se empieza de nuevo
## (goto_if_not_defeated TRAINER_VICKY). Vencida VICKY, la familia se queda
## dentro de la casa (el interior está pendiente).
##
## Los miembros son `npc_entrenador_evento`: el evento escucha su señal `hablado`
## y dirige el guion con las acciones de EventoGuionizado.
## Diálogos: claves RUTA111_ESTRATEGA_* y RUTA111_<MIEMBRO>_* de dialogos.csv.
extends EventoGuionizado
class_name EventoFamiliaEstratega

const MOTIVO_PAUSA: StringName = &"familia_estratega"
const BANDERAS_LANDMARK = preload("res://scripts/mapas/banderas_landmark.gd")
## Equivale a haber vencido a TRAINER_VICKY: la familia ya no está fuera.
const BANDERA_VENCIDA: String = "ruta_111_familia_estratega_vencida"

const TEXTO_PROPUESTA: String = "RUTA111_ESTRATEGA_PROPUESTA"
const TEXTO_RECHAZO: String = "RUTA111_ESTRATEGA_RECHAZO"
## Mensaje antes del combate de cada miembro (VÍCTOR: "¡Así me gusta!").
const TEXTOS_ANTES: Array[String] = [
	"RUTA111_ESTRATEGA_ACEPTA", "RUTA111_VICTORIA_INI", "RUTA111_VIVI_INI", "RUTA111_VICKY_INI",
]
## Mensaje de cada miembro tras perder.
const TEXTOS_DESPUES: Array[String] = [
	"RUTA111_VICTOR_POST", "RUTA111_VICTORIA_POST", "RUTA111_VIVI_POST", "RUTA111_VICKY_POST",
]
## Route111_Movement_15035B: el jugador espera 3 × delay_16 entre miembros.
const ESPERA_ENTRE_MIEMBROS: float = 48.0 / 60.0
## Pausa de la puerta cuando no hay animación asignada.
const ESPERA_PUERTA_SIN_ANIMACION: float = 0.2

## VÍCTOR, VICTORIA, VIVI y VICKY en orden de combate. El primero espera fuera;
## el resto empieza oculto en la puerta.
@export var miembros: Array[NodePath] = []
## Puerta de la casa (opendoor/closedoor 13,113): por ella entran y salen.
@export var celda_puerta: Vector2i = Vector2i(13, 113)
## Warp de PUERTAS de la casa: de él salen el estilo de la animación, el sonido y la
## posición de la puerta. Sin él se usa `imagen_puerta`.
@export var warp_puerta: NodePath
## Estilo de puerta (Singleton.EstiloWarp) cuando no hay `warp_puerta`. NINGUNA = sin animación.
@export var imagen_puerta: Singleton.enum_puertas = Singleton.enum_puertas.NINGUNA

var _celdas_iniciales: Array[Vector2i] = []
var _animacion_puerta: AnimatedSprite2D = null
var _puerta_abierta: bool = false


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for miembro in _miembros():
		_celdas_iniciales.append(miembro.coord)
	var lider := _miembro(0)
	if lider != null and lider.has_signal("hablado"):
		lider.hablado.connect(_on_lider_hablado)
	var mapa := obtener_mapa()
	if mapa != null:
		mapa.mapa_activado.connect(_on_mapa_activado)
	preparar()


func _on_mapa_activado(_por_warp: bool) -> void:
	preparar()


## Route111_MapScript1_14FFB9 al entrar en el mapa: sin VICKY vencida solo
## VÍCTOR espera fuera; vencida, no queda nadie.
func preparar() -> void:
	if _en_curso:
		return
	var vencida := SistemaGuardado.get_flag(BANDERA_VENCIDA)
	var lista := _miembros()
	for i in lista.size():
		var miembro: Node2D = lista[i]
		colocar(miembro, _celdas_iniciales[i])
		miembro.visible = i == 0 and not vencida


func _miembros() -> Array[Node2D]:
	var lista: Array[Node2D] = []
	for ruta in miembros:
		var nodo := get_node_or_null(ruta) as Node2D
		if nodo != null:
			lista.append(nodo)
	return lista


func _miembro(indice: int) -> Node2D:
	var lista := _miembros()
	return lista[indice] if indice < lista.size() else null


## ============================================================================
## GUION (Route111_EventScript_1501D1)
## ============================================================================

func _on_lider_hablado(lider: Node2D) -> void:
	if _en_curso:
		return
	if not comenzar(lider.nodo_administrador):
		if lider.jugador and lider.jugador.has_method("esperar_dialogo"):
			lider.jugador.esperar_dialogo(false)
		return
	lider.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
	lider.mirar_jugador()  # faceplayer
	# setflag FLAG_LANDMARK_WINSTRATE_FAMILY: el landmark "La familia ESTRATEGA"
	# aparece en el mapa de región en cuanto se habla con VÍCTOR, aunque se rechace.
	BANDERAS_LANDMARK.activar(BANDERAS_LANDMARK.WINSTRATE_FAMILY)

	if not await preguntar_si_no(TEXTO_PROPUESTA):
		await mensaje(TEXTO_RECHAZO)
		terminar(false, _miembros())
		return

	var lista := _miembros()
	for i in lista.size():
		var miembro: Node2D = lista[i]
		if i > 0:
			await _salir_de_casa(miembro)
			await get_tree().create_timer(ESPERA_ENTRE_MIEMBROS).timeout
		await mensaje(TEXTOS_ANTES[i])
		var musica: String = miembro.musica_batalla
		var resultado := await combatir(miembro.entrenador_id, "" if musica == "Por defecto" else musica)
		if resultado != &"victoria":
			terminar(resultado == &"derrota_transferida", _miembros())
			return
		var ultimo := i == lista.size() - 1
		if ultimo:
			# VICKY se despide antes de volver a casa.
			await mensaje(TEXTOS_DESPUES[i])
		miembro.cambiar_estado(NpcBase.EstadoNPC.INTERACTING)
		mirar(miembro, Vector2.UP)  # walk_in_place_fastest_up
		await _abrir_puerta()
		if not ultimo:
			await mensaje(TEXTOS_DESPUES[i])
		await _entrar_en_casa(miembro)
		# La puerta sigue abierta para el siguiente miembro: se cierra cuando ha salido.
		if ultimo:
			await _cerrar_puerta()

	SistemaGuardado.set_flag(BANDERA_VENCIDA, true)
	terminar(false, _miembros())


## addobject en la puerta + walk_down. La puerta ya está abierta (la abrió el miembro
## vencido al entrar) y se cierra cuando este ha salido.
func _salir_de_casa(miembro: Node2D) -> void:
	await _abrir_puerta()
	colocar(miembro, celda_puerta)
	miembro.visible = true
	await caminar(miembro, Vector2.DOWN)
	await _cerrar_puerta()


## walk_up hacia la puerta + removeobject.
func _entrar_en_casa(miembro: Node2D) -> void:
	await caminar(miembro, Vector2.UP)
	miembro.visible = false


## ============================================================================
## PUERTA (opendoor / closedoor)
## ============================================================================

func _abrir_puerta() -> void:
	if _puerta_abierta:
		return
	_puerta_abierta = true
	var warp := get_node_or_null(warp_puerta) as Warp
	Singleton.emit_signal("play_sound", warp.sonido_puerta() if warp != null else &"puerta_entrada")
	var animacion := _obtener_animacion_puerta()
	if animacion == null:
		await get_tree().create_timer(ESPERA_PUERTA_SIN_ANIMACION).timeout
		return
	animacion.visible = true
	animacion.play("abrir_puerta")
	await animacion.animation_finished


func _cerrar_puerta() -> void:
	if not _puerta_abierta:
		return
	_puerta_abierta = false
	var animacion := _obtener_animacion_puerta()
	if animacion == null:
		await get_tree().create_timer(ESPERA_PUERTA_SIN_ANIMACION).timeout
		return
	animacion.play("cerrar_puerta")
	await animacion.animation_finished
	animacion.visible = false


func _obtener_animacion_puerta() -> AnimatedSprite2D:
	if _animacion_puerta == null:
		var warp := get_node_or_null(warp_puerta) as Warp
		var estilo: int = warp.estilo_warp if warp != null else imagen_puerta
		var escena := Singleton.escena_estilo_warp(estilo)
		if escena == null:
			return null
		_animacion_puerta = escena.instantiate()
		_animacion_puerta.visible = false
		# Misma posición que la animación de un Warp de tipo PUERTAS.
		_animacion_puerta.position = Vector2(celda_puerta.x * 16 + 8, celda_puerta.y * 16 + 6)
		add_child(_animacion_puerta)
	return _animacion_puerta
