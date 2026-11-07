extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Exact sub_80DBCFC→sub_80DBD58 task phases, separate from gameplay exit.
static func create(s: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Array[Dictionary]:
	var actor: BattleAnimationActor=c.resolve("attacker")[0];var rises: int=8 if actor.side==0 else 4
	return [{"kind":"source_counter_actor","actor":actor,"owner":owner,"age":0,"ticks":21+rises,"rises":rises,"base_x":actor.anchor(c.field,"origin").x,"settings":s,"pose":{},"update":advance}]
static func advance(t: Dictionary,_c: BattleAnimationContext) -> void:
	var age: int=int(t.age);var affine_age: int=mini(age,20)
	var offset:=Vector2(0,-8*clampi(age-20,0,int(t.rises)))
	var scale:=Vector2(256.0/(256+64*affine_age),256.0/(256-4*affine_age))
	if age==21+int(t.rises):
		# The source hides, sets x272 and resets the affine matrix. Hold the
		# invisible task result until the surrounding BG restore finishes.
		t.actor.apply_source_state("hidden",true);t.owner._held_offsets[t.actor.id]=Vector2(272-float(t.base_x),offset.y);offset=Vector2.ZERO;scale=Vector2.ONE
	t.pose={"offset":offset,"scale":scale}
