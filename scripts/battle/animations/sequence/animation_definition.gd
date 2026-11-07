extends Resource
class_name BattleAnimationDefinition
## Native presentation data. Never contains damage, accuracy or status rules.

@export var key: String = ""
@export var schema_version: int = 1
@export var coverage: String = "prototype"
@export var source_script: String = ""
@export var steps: Array[Dictionary] = []

const OPERATIONS := ["source_label", "source_sound_pan", "source_control", "source_arg_context", "source_actor_state", "source_arg", "source_variant", "sound_barrier", "background_barrier", "effect", "wait", "barrier", "marker", "variant", "sound", "end"]

## @deprecated: camino de la VM legada; las animaciones nativas no lo usan. Se conserva como referencia y fallback de configuración. Ver scripts/battle/animations/sequence/README.md.
func validation_error(behaviors: Dictionary) -> String:
	if schema_version != 1:
		return "Unsupported animation schema: %d" % schema_version
	if key.is_empty():
		return "Missing animation key"
	for step in steps:
		var op: String = step.get("op", "")
		if op not in OPERATIONS:
			return "Unknown operation: %s" % op
		if op == "effect" and not behaviors.has(str(step.get("behavior", ""))):
			return "Missing behavior: %s" % step.get("behavior", "")
		if op == "effect" and str(step.get("behavior", "")) == "source_species_cry":
			var path := str(step.get("cry_catalog_path", ""))
			if path.is_empty() or not FileAccess.file_exists(path):
				return "Missing species cry catalog: " + path
		# Explicit dependencies must never silently become generic visuals/silence.
		for dependency in ["texture", "path"]:
			if (op == "effect" and dependency == "texture") or (op == "sound" and dependency == "path"):
				if dependency=="texture" and key=="ruby:move/101" and step.get("texture") is Texture2D:
					var night: Variant=load("res://scripts/battle/animations/sequence/source_night_shade_composition.gd")
					if night!=null and night.accepts_texture_dependency(self,step):continue
				if dependency=="texture" and key=="ruby:move/109" and step.get("texture") is Texture2D:
					var confuse: Variant=load("res://scripts/battle/animations/sequence/source_confuse_ray_composition.gd")
					if confuse!=null and confuse.accepts_texture_dependency(self,step):continue
				if dependency=="texture" and key=="ruby:move/146" and step.get("texture") is Texture2D:
					var dizzy: Variant=load("res://scripts/battle/animations/sequence/source_dizzy_punch_composition.gd")
					if dizzy!=null and dizzy.accepts_texture_dependency(self,step):continue
				if dependency=="texture" and key=="ruby:move/152" and step.get("texture") is Texture2D:
					var crab: Variant=load("res://scripts/battle/animations/sequence/source_crabhammer_composition.gd")
					if crab!=null and crab.accepts_texture_dependency(self,step):continue
				if dependency=="texture" and key=="ruby:move/308" and step.get("texture") is Texture2D:
					var hydro: Variant=load("res://scripts/battle/animations/sequence/source_hydro_cannon_composition.gd")
					if hydro!=null and hydro.accepts_texture_dependency(self,step):continue
				if dependency=="texture" and key=="ruby:move/127" and step.get("texture") is Texture2D:
					# Lazy lookup avoids a Definition -> adapter -> Definition preload cycle.
					# Only exact builtin127/whole229/approved ART may omit pathname loading.
					var finite: Variant=load("res://scripts/battle/animations/sequence/source_waterfall_composition.gd")
					if finite!=null and finite.accepts_texture_dependency(self,step):continue
				if dependency=="texture" and key=="ruby:move/338" and step.get("texture") is Texture2D:
					var frenzy: Variant=load("res://scripts/battle/animations/sequence/source_frenzy_plant_composition.gd")
					if frenzy!=null and frenzy.accepts_texture_dependency(self,step):continue
				if dependency=="texture" and key in ["ruby:move/57","ruby:move/330"] and step.get("texture") is Texture2D:
					# Lazy exact-builtin/whole-program gate, never a generic Texture bypass.
					var surf: Variant=load("res://scripts/battle/animations/sequence/source_secret_power_composition.gd")
					if surf!=null and surf.accepts_texture_dependency(self,step):continue
				if dependency=="texture" and key=="ruby:move/59" and step.get("texture") is Texture2D:
					var blizzard: Variant=load("res://scripts/battle/animations/sequence/source_blizzard_composition.gd")
					if blizzard!=null and blizzard.accepts_texture_dependency(self,step):continue
				var path := str(step.get(dependency, ""))
				if path.is_empty() and op == "effect":
					continue # Procedural effects intentionally omit a texture.
				if path.is_empty() or not ResourceLoader.exists(path):
					return "%s: missing %s dependency '%s'; import or correct the resource path" % [key, dependency, path]
				var resource := load(path)
				if (dependency == "texture" and not resource is Texture2D) or (dependency == "path" and not resource is AudioStream):
					return "%s: invalid %s dependency '%s'; expected %s" % [key, dependency, path, "Texture2D" if dependency == "texture" else "AudioStream"]
		if op == "source_variant":
			for branch in step.get("cases",{}).values():
				var nested := BattleAnimationDefinition.new()
				nested.key = key
				nested.steps.assign(branch)
				var error := nested.validation_error(behaviors)
				if not error.is_empty(): return error
		if op == "variant":
			for branch in ["charge", "release"]:
				var nested := BattleAnimationDefinition.new()
				nested.key = key
				nested.steps.assign(step.get(branch, []))
				var error := nested.validation_error(behaviors)
				if not error.is_empty():
					return error
	return ""
