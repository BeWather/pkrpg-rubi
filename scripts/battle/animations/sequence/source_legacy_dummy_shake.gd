extends RefCounted
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Finite canonical dummy callbacks; never a generic camera or visible sprite.
const SITES := {
	"ruby:move/88":["Move_ROCK_THROW",{0:[2099,6,15,1]}],
	"ruby:move/157":["Move_ROCK_SLIDE",{0:[2121,7,11,1]}],
	"ruby:move/246":["Move_ANCIENT_POWER",{10:[6859,4,10,1]}],
	"ruby:move/267":["Move_ANCIENT_POWER",{12:[6859,4,10,1]}],
	"ruby:move/290":["Move_SECRET_POWER",{362:[2099,6,15,1]}],
	"ruby:move/232":["Move_METAL_CLAW",{9:[7277,-4,10,3],16:[7284,-4,10,3]}],
	"ruby:move/337":["Move_DRAGON_CLAW",{34:[8604,-4,10,3],47:[8617,-4,10,3]}],
}
const Same=preload("res://scripts/battle/animations/sequence/source_cutting_slice.gd")

static func create(step: Dictionary,c: BattleAnimationContext,owner: Node2D) -> Variant:
	if not owner is BattleAnimationSequenceRunner or not BattleAnimationSequenceRegistry.is_builtin_source_definition(owner.definition):return null
	var sites: Array=SITES.get(owner.definition.key,[])
	if sites.is_empty() or owner.definition.source_script!=sites[0] or not sites[1].has(owner._pc):return null
	var a: Array=sites[1][owner._pc]
	var expected: Dictionary={"op":"effect","behavior":"shake","ticks":a[2],"selector":"all","x":0,"y":-int(a[1]),"source_line":a[0]}
	if owner._pc>=owner.definition.steps.size() or owner._pc>=owner._steps.size():return null
	if not Same._same(owner.definition.steps[owner._pc],expected) or not Same._same(owner._steps[owner._pc],expected):return null
	var literal:=step.duplicate(true)
	if literal.has("source_command_priority"):
		if owner._pc==0:return null
		var label: Dictionary=owner.definition.steps[owner._pc-1]
		if label.get("op")!="source_label" or not Same._same(label.get("source_line"),a[0]):return null
		var args: Array=[a[1],1,a[2],a[3]]
		if int(a[3])==3:args.append(1)
		if not Same._same(label.get("source_args"),args):return null
		if not Same._same(literal.source_command_priority,BattleSourcePriority.command_metadata(label)):return null
		literal.erase("source_command_priority")
	if not Same._same(literal,expected):return null
	var track: Dictionary={"kind":"source_legacy_dummy_shake","age":0,"ticks":int(a[2])+1,"duration":int(a[2]),"amplitude":int(a[1]),"settings":step.duplicate(true),"pose":Vector2.ZERO,"context":c,"nodes":[],"update":advance}
	if int(a[3])==3:
		var targets:=c.resolve("target")
		if targets.is_empty():return []
		track.actor=targets[0]
	else:
		var subjects:=_backgrounds(c)
		if subjects.is_empty():
			owner.error_message="Missing native BG3 backdrop provider for "+owner.definition.key
			owner.finish("failed");return []
		for node: Node2D in subjects:
			track.nodes.append({"node":node,"parent":node.get_parent(),"base":node.position,"expected":node.position,"delta":Vector2.ZERO})
		track.cleanup=release.bind(track)
	var tracks: Array[Dictionary]=[track]
	return tracks

static func _backgrounds(c: BattleAnimationContext) -> Array:
	# Real battle: ONLY the sky/backdrop; ground parents carry actors and must not move.
	var battle: Node=c.field.get_parent()
	if battle.scene_file_path=="res://escenas/batalla/batalla.tscn" and c.field.name=="Campo":
		var backdrop:=c.field.get_node_or_null("btlFondo")
		return [backdrop] if backdrop is Sprite2D else []
	# Existing lab creates exactly this native polygon as its first field child.
	var root: Node=c.field
	while root!=null:
		if root.scene_file_path=="res://herramientas/laboratorio_animaciones/laboratorio_animaciones.tscn":
			if root.field!=c.field or c.field.get_child_count()==0:return []
			var backdrop: Node=c.field.get_child(0)
			return [backdrop] if backdrop is Polygon2D else []
		root=root.get_parent()
	return []

static func _local(c: BattleAnimationContext,parent: Node2D,delta: Vector2) -> Vector2:
	return parent.global_transform.affine_inverse().basis_xform(c.field.global_transform.basis_xform(delta))

static func advance(t: Dictionary,c: BattleAnimationContext) -> void:
	var previous: Vector2=t.pose
	var active: bool=int(t.age)<=int(t.duration)
	var register: int=-int(t.amplitude) if active and (int(t.age)/2)%2==1 else 0
	if t.has("actor"):
		if c.actors.get(t.actor.id)!=t.actor or not t.actor.is_present():t.pose=Vector2.ZERO;return
		# At normal retirement, a last external literal is not our previous delta.
		if not active and t.actor.sprite.position!=t.actor._expected_position:t.actor._base_position+=previous
		t.pose=_local(c,t.actor.sprite.get_parent(),Vector2(0,register))
		return
	if not active:release(t);return
	for item: Dictionary in t.nodes:
		if not is_instance_valid(item.node) or not item.node.is_inside_tree() or item.node.get_parent()!=item.parent:continue
		item.base+=item.node.position-item.expected
		item.delta=_local(c,item.parent,Vector2(0,-register))
		item.node.position=item.base+item.delta;item.expected=item.node.position

static func release(t: Dictionary) -> void:
	t.erase("cleanup") # Break the callback/dictionary ownership cycle exactly once.
	for item: Dictionary in t.nodes:
		if is_instance_valid(item.node) and item.node.get_parent()==item.parent and item.node.position==item.expected:item.node.position=item.base
