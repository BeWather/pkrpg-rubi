extends Resource
class_name EnigmaBerryData
## Semantic authoring data, not an imported/checksum-certified GBA save blob.
## The battle provider snapshots these fields; later Resource edits are external.
@export_range(0,255) var hold_effect: int=0
@export_range(0,255) var hold_effect_param: int=0
