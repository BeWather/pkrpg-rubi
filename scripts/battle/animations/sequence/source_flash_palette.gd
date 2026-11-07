extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## normal.c:1501–1576: constructor fill, seven-callback hold,2-callback fade.
static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	if str(step.get("source_callback",""))!="sub_80E388C":return []
	var actors: Array[BattleAnimationActor]=[]
	for actor: BattleAnimationActor in c.actors.values():
		if not actor.is_present() or not actor.sprite.is_visible_in_tree():continue
		if c.contest and actor.id!=c.attacker_id:continue
		actors.append(actor)
	var t: Dictionary={"kind":"source_flash_palette","settings":step.duplicate(true),"owner":owner,"actors":actors,"age":0,"ticks":4096,"stage":0,"counter":0,"amount":16,"update":advance}
	_apply(t,c) # sub_80E39BC writes the faded palettes in the constructor.
	return [t]
static func _apply(t: Dictionary,c: BattleAnimationContext) -> void:
	for actor: BattleAnimationActor in t.actors:
		if c.actors.get(actor.id)!=actor or not actor.is_present():continue
		var held: Dictionary={"color":Color.BLACK,"amount":float(t.amount)/16.0,"source_actor":actor}
		t.owner._held_blends[actor.id]=held;actor.apply_blend(held.color,held.amount)
	# Source background palette mask0xE is projected behind battler sprites,
	# not over the HUD; preserve the established native palette compositor.
	t.owner._source_palette({"age":0,"settings":{"blend_start":int(t.amount),"blend_end":int(t.amount),"blend_delay":1,"color":"ffffff"}})
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	match int(t.stage):
		0:
			t.counter=int(t.counter)+1
			if int(t.counter)>6:t.counter=0;t.stage=1
		1:
			t.counter=int(t.counter)+1
			if int(t.counter)>1:
				t.counter=0;t.amount=int(t.amount)-1
				if int(t.amount)==0:t.stage=2
		2:t.ticks=int(t.age)
	_apply(t,c)
