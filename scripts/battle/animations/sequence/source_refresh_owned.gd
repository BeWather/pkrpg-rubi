extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Same sub_81300A4 cure BG1 as Aromatherapy, but Refresh ARG0=0 excludes partner.
const Aroma=preload("res://scripts/battle/animations/sequence/source_aromatherapy.gd")
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var step: Dictionary=s.duplicate(true);step.behavior="source_aroma_mask"
	var tracks: Array[Dictionary]=Aroma.create(step,c,owner)
	for t: Dictionary in tracks:
		var selected: Array=[]
		for member: Dictionary in t.members:
			if member.actor.id==c.attacker_id:selected.append(member)
			else:member.node.free()
		t.members=selected
	return tracks
