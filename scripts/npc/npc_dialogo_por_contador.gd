@tool
## npc_dialogo_por_contador.gd
## NPC cuyo msgbox depende de una variable de Gen 3 (`switch VAR_TEMP_1 / case N, texto`, sin guion
## propio más allá de lock + faceplayer): el texto es `textos_por_valor[contador]`; si el valor no
## tiene texto, el de siempre (CondicionTexto / id_texto). Es el caso de los cuatro CHICOS de la
## CASA de CALAGUA (LilycoveCity_House3), que dicen lo mismo entre sí en cada visita: quien fija el
## contador al entrar en el mapa es el evento de la escena (EventoCasasCalagua).
## Bloqueo del jugador y diálogo: npc_dialogo_condicional.gd.
extends "res://scripts/npc/npc_dialogo_condicional.gd"

## Contador de SistemaGuardado (variable de Gen 3).
@export var contador: String = ""
## Texto de cada valor del contador (índice = valor).
@export var textos_por_valor: PackedStringArray = PackedStringArray()


func _consumir_id_texto() -> String:
	if not contador.is_empty():
		var valor: int = SistemaGuardado.get_contador(contador)
		if valor >= 0 and valor < textos_por_valor.size() and not textos_por_valor[valor].is_empty():
			return textos_por_valor[valor]
	return super._consumir_id_texto()
