## npc_rival.gd
## El rival en el overworld: se viste de AURA o BRUNO según el sexo del jugador
## (Common_EventScript_SetupRivalGfxId / SetupRivalOnBikeGfxId). No tiene
## lógica de encuentro: la pone el evento del mapa (EventoRival), que escucha
## `hablado`. Sin nadie escuchando se comporta como un NPC normal (id_texto).
@tool
extends "res://scripts/npc/npc_base.gd"

signal hablado(npc: Node2D)

## Sprite en BICI CARRERA en lugar de a pie.
@export var en_bici: bool = false:
	set(valor):
		en_bici = valor
		if is_node_ready():
			vestir()


func _ready() -> void:
	vestir()
	super._ready()


## Asigna los SpriteFrames y el offset del rival de la partida.
func vestir() -> void:
	var sexo := "M" if Engine.is_editor_hint() else ""
	selec_frames = Rival.sprite(en_bici, sexo)
	if animated_sprite:
		animated_sprite.offset = Rival.offset_sprite(en_bici, sexo)
		animated_sprite.sprite_frames = selec_frames
		direccion_inicial()


func evento_accion() -> void:
	if estado_actual == EstadoNPC.MOVING:
		interrupcion_pendiente = true
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(true)
		return
	_procesar_interaccion()


func _procesar_interaccion() -> void:
	if hablado.get_connections().is_empty():
		super._procesar_interaccion()
		return
	interrupcion_pendiente = false
	hablado.emit(self)
