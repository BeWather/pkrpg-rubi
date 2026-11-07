## npc_rival_dialogo.gd
## Rival que solo habla (checkplayergender + msgbox): `{RIVAL}` en id_texto e
## id_texto_primera_vez se sustituye por AURA o BRUNO (Rival.clave()). La primera
## vez usa id_texto_primera_vez y activa bandera_primera_vez (FLAG_MET_RIVAL_*).
@tool
extends "res://scripts/npc/npc_rival.gd"


func _consumir_id_texto() -> String:
	return super._consumir_id_texto().replace("{RIVAL}", Rival.clave())
