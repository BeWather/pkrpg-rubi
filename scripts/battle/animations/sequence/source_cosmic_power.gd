extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Source constructor applies start immediately, then fifteen task callbacks.
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var t: Dictionary={"kind":"source_cosmic_palette","settings":step,"owner":owner,"members":c.resolve("except_attacker"),"amount":int(step.source_args[1]),"destination":int(step.source_args[2]),"age":0,"ticks":15,"update":advance}
	_paint(t,c);return [t]
static func _paint(t: Dictionary,c: BattleAnimationContext) -> void:
	for member: BattleAnimationActor in t.members:
		if c.actors.get(member.id)==member and member.is_present():t.owner._held_blends[member.id]={"color":Color.BLACK,"amount":float(t.amount)/16.0,"source_actor":member}
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	t.amount=int(t.amount)+signi(int(t.destination)-int(t.amount));_paint(t,c)
