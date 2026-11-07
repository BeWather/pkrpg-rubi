extends RefCounted
class_name BattleOwnedMaterialLease
## @deprecated: VM legada de animaciones de batalla (intérprete del bytecode del decomp). Sustituida por las animaciones nativas (escenas/batalla/animaciones_nativas/ y scripts/battle/animations/nativa/). Se conserva solo como referencia y como fallback de configuración (batalla/animaciones_nativas desactivada o lista blanca sin nativo_pendiente_validacion), y para laboratorio, comparador y tests. Ver scripts/battle/animations/sequence/README.md.

## Property-local ownership: do not reclaim an external material or owner tag.
var actor: BattleAnimationActor
var material: Material
var previous: Material
var previous_tag: Variant
var had_tag: bool
var active: bool=false
var token: String

static func attach(bound_actor: BattleAnimationActor, owned: Material) -> BattleOwnedMaterialLease:
	var lease:=BattleOwnedMaterialLease.new()
	lease.actor=bound_actor
	lease.material=owned
	lease.token="source_material:%d"%lease.get_instance_id()
	if not bound_actor.is_present():return lease
	lease.previous=bound_actor.sprite.material
	lease.had_tag=bound_actor.sprite.has_meta("source_material_owner")
	lease.previous_tag=bound_actor.sprite.get_meta("source_material_owner") if lease.had_tag else null
	bound_actor.sprite.set_meta("source_material_owner",lease.token)
	bound_actor.sprite.material=owned
	lease.active=true
	return lease

func owns_current() -> bool:
	return active and is_instance_valid(actor.sprite) and actor.sprite.material==material and str(actor.sprite.get_meta("source_material_owner",""))==token

func release() -> void:
	# Even after texture/generation replacement, remove only the material/tag
	# still owned by this lease. Never read geometry or retarget a new occupant.
	if owns_current():actor.sprite.material=previous
	if active and is_instance_valid(actor.sprite) and str(actor.sprite.get_meta("source_material_owner",""))==token:
		if had_tag:actor.sprite.set_meta("source_material_owner",previous_tag)
		else:actor.sprite.remove_meta("source_material_owner")
	active=false
