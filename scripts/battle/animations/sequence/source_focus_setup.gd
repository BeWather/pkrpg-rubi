extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Selector2 normal palette fade: attacker OBJ only, no BG overlay or flame recolor.
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actor: BattleAnimationActor=c.resolve("attacker")[0]
	return [{"kind":"source_focus_pulse","settings":s,"owner":owner,"original_actor":actor,"age":0,"ticks":int(s.ticks),"amount":0,"destination":11,"obj_half":true,"delay_counter":0,"finishing":-1,"cycles":2,"update":advance}]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or not t.original_actor.is_present():t.ticks=int(t.age);return
	if int(t.finishing)>=0:
		t.finishing=int(t.finishing)+1
		if int(t.finishing)==6:
			t.cycles=int(t.cycles)-1
			if int(t.cycles)==0:t.ticks=int(t.age)
			else:t.amount=11;t.destination=0;t.obj_half=true;t.delay_counter=0;t.finishing=-1
		return
	if not bool(t.obj_half):
		if int(t.delay_counter)<2:t.delay_counter=int(t.delay_counter)+1;return
		t.delay_counter=0 # BG half advances the fade clock, but selector2 has NO BG bits.
	else:t.owner._held_blends[t.original_actor.id]={"color":Color.RED,"amount":float(t.amount)/16.0,"source_actor":t.original_actor}
	t.obj_half=not bool(t.obj_half)
	if not bool(t.obj_half):
		if int(t.amount)==int(t.destination):t.finishing=0
		else:t.amount=mini(int(t.amount)+2,int(t.destination)) if int(t.amount)<int(t.destination) else maxi(int(t.amount)-2,int(t.destination))
