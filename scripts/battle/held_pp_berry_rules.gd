extends RefCounted
## Ruby case1 !moveTurn RESTORE_PP: party PP is accepted before the item script.
const ItemTransaction=preload("res://scripts/battle/held_item_transaction.gd")
const Effects=preload("res://scripts/battle/held_item_effect_provider.gd")
static var source_base_pp: Array=JSON.parse_string(FileAccess.get_file_as_string("res://recursos/animaciones/sketch_base_pp.json"))
static func _valid(battle: Node,accepted: Dictionary) -> bool:
	if not ItemTransaction.valid(battle,accepted) or accepted.pokemon.estad_ps_actual<=0:return false
	var moves: Array=accepted.pokemon.movimientos
	return is_same(moves,accepted.moves) and int(accepted.index)<moves.size() and moves[int(accepted.index)]==accepted.move
static func end_round(battle: Node,lease: Dictionary) -> void:
	if not battle.field_rules.valid(lease) or lease.pokemon.estad_ps_actual<=0:return
	var pokemon: BasePokemon=lease.pokemon;var descriptor: Dictionary=battle.held_item_effects.resolve(battle,pokemon,lease)
	var item: String=descriptor.item
	if int(descriptor.source_effect)!=Effects.RESTORE_PP:return
	var moves: Array=pokemon.movimientos
	for index: int in mini(4,moves.size()):
		var move: Movimiento=moves[index]
		# Ordinary level/snapshot loaders omit raw IDs; use the existing native
		# normalized lookup once, without mutating party data. MOVE_NONE/unknown
		# names remain ineligible and cannot index the immutable Ruby PP table.
		if move==null or move.pp_act!=0:continue
		var id: int=int(move._dato_combate("numero_movimiento",0))
		if id<=0 or id>=source_base_pp.size():continue
		var flow: Dictionary=preload("res://scripts/battle/held_status_berry_rules.gd").admission(battle).flow
		var accepted: Dictionary=ItemTransaction.capture(battle,lease,flow,descriptor)
		accepted.moves=moves;accepted.index=index;accepted.move=move
		if not _valid(battle,accepted):return
		# The party resource is authoritative. Uncopied combat slots share it;
		# Mimic/Transform have distinct resources and must NOT receive this write.
		var base_pp: int=int(source_base_pp[id]);var maximum: int=base_pp+base_pp*clampi(move.pp_mas,0,3)/5
		move.pp_act=mini(int(descriptor.parameter),maximum)
		if not await ItemTransaction.present(battle,accepted) or not _valid(battle,accepted):return
		await battle.mostrar_texto_batalla("¡%s de %s restauró los PP de %s!"%[ObjetosLlevados.nombre_objeto(item),pokemon.get_nombre_combate(),move.nombre])
		if not _valid(battle,accepted):return
		preload("res://scripts/battle/recycle_rules.gd").consume(battle,pokemon,lease)
		return
