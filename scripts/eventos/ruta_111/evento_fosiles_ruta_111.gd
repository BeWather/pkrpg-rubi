## evento_fosiles_ruta_111.gd
## Los dos FÓSILES del DESIERTO de la RUTA 111 (pokeruby data/maps/Route111: objetos 34
## y 35 en (32,38) y (33,38), Route111_EventScript_150023 / _150069).
##
## lockall + msgbox YESNO: con NO, «{PN} dejó el FÓSIL en su sitio». Con SÍ, giveitem
## del fósil elegido, se activan FLAG_HIDE_ROOT_FOSSIL y FLAG_HIDE_CLAW_FOSSIL, el
## elegido desaparece (removeobject), tras 30 fotogramas el otro parpadea
## (Route111_Movement_1500AF) y también desaparece: se ha hundido en la arena. Solo se
## puede conseguir uno de los dos en toda la partida.
extends EventoInteriorMalvalona
class_name EventoFosilesRuta111

const MOTIVO_PAUSA: StringName = &"ruta_111_fosiles"

## FLAG_HIDE_ROOT_FOSSIL / FLAG_HIDE_CLAW_FOSSIL (bandera_ocultar de cada fósil).
const BANDERA_OCULTAR_RAIZ: String = "FLAG_HIDE_ROOT_FOSSIL"
const BANDERA_OCULTAR_GARRA: String = "FLAG_HIDE_CLAW_FOSSIL"

## ITEM_ROOT_FOSSIL / ITEM_CLAW_FOSSIL en la tabla Objetos.
const OBJETO_RAIZ: String = "FOSILRAIZ"
const OBJETO_GARRA: String = "FOSILGARRA"

const TEXTO_RAIZ: String = "RUTA111_FOSIL_RAIZ"
const TEXTO_RAIZ_NO: String = "RUTA111_FOSIL_RAIZ_NO"
const TEXTO_GARRA: String = "RUTA111_FOSIL_GARRA"
const TEXTO_GARRA_NO: String = "RUTA111_FOSIL_GARRA_NO"

## delay 30 entre el removeobject del elegido y el parpadeo del otro.
const FOTOGRAMAS_ANTES_DE_HUNDIRSE: int = 30
## Route111_Movement_1500AF: set_visible/set_invisible alternos con estas esperas
## (delay_4 ×4, delay_8 ×4, delay_16 ×2) y un set_visible final.
const PARPADEO_HUNDIRSE: Array[int] = [4, 4, 4, 4, 8, 8, 8, 8, 16, 16]

@export var fosil_raiz: NodePath
@export var fosil_garra: NodePath


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	escuchar(fosil_raiz, _on_fosil_raiz)
	escuchar(fosil_garra, _on_fosil_garra)


## Route111_EventScript_150023.
func _on_fosil_raiz(npc: Node2D) -> void:
	await _coger(npc, nodo(fosil_garra), OBJETO_RAIZ, TEXTO_RAIZ, TEXTO_RAIZ_NO)


## Route111_EventScript_150069.
func _on_fosil_garra(npc: Node2D) -> void:
	await _coger(npc, nodo(fosil_raiz), OBJETO_GARRA, TEXTO_GARRA, TEXTO_GARRA_NO)


func _coger(elegido: Node2D, otro: Node2D, objeto: String, texto: String, texto_no: String) -> void:
	if not empezar_con(elegido, false):  # lockall: el fósil no se gira
		return
	if not await preguntar_si_no(texto):
		await mensaje(texto_no)
		terminar(false, [elegido])
		return
	if not await dar_objeto(elegido, objeto):
		await mensaje_mochila_llena()
		terminar(false, [elegido])
		return
	admin.cuadro_dialogo.cerrar()  # closemessage
	SistemaGuardado.set_flag(BANDERA_OCULTAR_RAIZ, true)
	SistemaGuardado.set_flag(BANDERA_OCULTAR_GARRA, true)
	elegido.aplicar_bandera_ocultar()  # removeobject
	await esperar_fotogramas(FOTOGRAMAS_ANTES_DE_HUNDIRSE)
	if otro != null:
		await _hundir(otro)
		otro.aplicar_bandera_ocultar()  # removeobject
	terminar(false, [elegido])


## applymovement Route111_Movement_1500AF + waitmovement.
func _hundir(fosil: Node2D) -> void:
	var sprite: CanvasItem = fosil.animated_sprite
	var visible_ahora: bool = true
	for fotogramas in PARPADEO_HUNDIRSE:
		sprite.visible = visible_ahora
		await esperar_fotogramas(fotogramas)
		visible_ahora = not visible_ahora
	sprite.visible = true
