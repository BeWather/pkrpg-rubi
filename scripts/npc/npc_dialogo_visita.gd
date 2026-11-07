## npc_dialogo_visita.gd
## npc_dialogo_condicional con un mensaje distinto la primera vez de cada visita al
## mapa (goto_if_set FLAG_TEMP_*, setflag FLAG_TEMP_*): las banderas temporales se
## limpian al cambiar de mapa (SistemaGuardado.set_flag_temporal), así que al
## volver a entrar toca otra vez el mensaje largo.
## - id_texto_primera_vez: mensaje de la primera conversación de la visita.
## - bandera_temporal: nombre de la bandera temporal (vacío: sin variante).
## - id_texto: mensaje de las siguientes conversaciones de la visita.
@tool
extends "res://scripts/npc/npc_dialogo_condicional.gd"

@export var bandera_temporal: String = ""


func _consumir_id_texto() -> String:
	if not bandera_temporal.is_empty() and not id_texto_primera_vez.is_empty() \
			and not SistemaGuardado.get_flag_temporal(bandera_temporal):
		SistemaGuardado.set_flag_temporal(bandera_temporal, true)
		return id_texto_primera_vez
	return super._consumir_id_texto()
