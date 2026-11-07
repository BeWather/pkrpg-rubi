extends RefCounted
class_name OpcionesBatallaOverworld

var musica_especifica: String = ""
## Estilos de CatalogoTransicionesBatalla en orden. `automatica` la sustituye
## OverworldBattleManager por la fase 2 que toque según el mapa y los niveles.
var secuencia_transicion: PackedStringArray = PackedStringArray()
var formato_doble: bool = false
## Objeto que lleva el salvaje (setwildbattle <especie>, <nivel>, <objeto>; p. ej. LATIAS con el ROCÍO BONDAD).
## Vacío = sin objeto.
var objeto_salvaje: String = ""


static func para_entrenador(musica: String = "") -> OpcionesBatallaOverworld:
	var opciones := OpcionesBatallaOverworld.new()
	opciones.musica_especifica = musica
	opciones.secuencia_transicion = secuencia_estandar()
	return opciones


static func para_salvaje() -> OpcionesBatallaOverworld:
	var opciones := OpcionesBatallaOverworld.new()
	opciones.secuencia_transicion = secuencia_estandar()
	return opciones


## Fase 1 común (Phase1Task_TransitionAll) + fase 2 elegida por battle_setup.c.
static func secuencia_estandar() -> PackedStringArray:
	return PackedStringArray([CatalogoTransicionesBatalla.DESTELLOS, CatalogoTransicionesBatalla.AUTOMATICA])
