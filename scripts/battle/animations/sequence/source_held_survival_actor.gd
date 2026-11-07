extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## FC68 -> FAF8 (30 accumulating frames) -> F9B0 (30 held frames).
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var args: Array=s.get("source_args",[])
	if args.size()!=7 or c.resolve("attacker").is_empty():return []
	for i: int in 7:
		if int(args[i])!=[30,128,0,1,2,0,1][i]:return []
	var actor: BattleAnimationActor=c.resolve("attacker")[0]
	var t: Dictionary={"kind":"source_held_survival_actor","settings":s,"owner":owner,"original_actor":actor,"age":0,"ticks":60,"update":advance,"frame":0,"wait":0,"shake":0,"delta":2,"qx":0,"offset":Vector2.ZERO}
	t.cleanup=_cleanup.bind(t);return [t]
static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	if c.actors.get(t.original_actor.id)!=t.original_actor or not t.original_actor.is_present():t.ticks=int(t.age);return
	t.wait=int(t.wait)-1
	if int(t.wait)==-1:
		if int(t.shake)==0:t.shake=int(t.delta);t.delta=-int(t.delta)
		else:t.shake=0
		t.wait=1 if int(t.frame)<30 else 0
	if int(t.frame)<30:t.qx=(int(t.qx)+128)&65535
	t.offset=Vector2(int(t.shake)+(int(t.qx)>>8)*(-1 if t.original_actor.side==0 else 1),0)
	t.owner._held_offsets[t.original_actor.id]=t.offset;t.frame=int(t.frame)+1
static func _cleanup(t: Dictionary) -> void:
	t.erase("cleanup")
	# A completed task retains its offset for the source return sprite. A view
	# cancellation restores only this original actor's pose, never a successor.
	if int(t.frame)<60 and t.owner._held_offsets.get(t.original_actor.id)==t.offset:t.owner._held_offsets[t.original_actor.id]=Vector2.ZERO
