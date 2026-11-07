extends RefCounted
class_name BattleHeldItemEffectProvider
## Ruby held identity -> source hold-effect data. Never executes an item effect.
const EnigmaData=preload("res://scripts/battle/enigma_berry_data.gd")
const ENIGMA="BAYAENIGMA"
# Source enum values, not catalog indices or translated names.
const NONE=0
const RESTORE_HP=1
const RESTORE_PP=7
const CURE_CONFUSION=8
const CURE_STATUS=9
const CONFUSE_SPICY=10
const CONFUSE_SOUR=14
const ATTACK_UP=15
const SP_DEFENSE_UP=19
const CRITICAL_UP=20
const RANDOM_STAT_UP=21
const RESTORE_STATS=23
const CURE_ATTRACT=28
const CHOICE_BAND=29
const DOUBLE_PRIZE=32
const FOCUS_BAND=39
const LEFTOVERS=43
const SHELL_BELL=62
const LAST_KNOWN=66 # HOLD_EFFECT_STICK; raw storage remains u8.
const FIXED={
	"BAYAARANJA":[1,10],"BAYAZIDRA":[1,30],"ZUMOBAYA":[1,20],
	"BAYAZREZA":[2,0],"BAYAATANIA":[3,0],"BAYAMELOC":[4,0],"BAYASAFRE":[5,0],"BAYAPERASI":[6,0],
	"BAYAZANAMA":[7,10],"BAYACAQUIC":[8,0],"BAYAZIUELA":[9,0],
	"BAYAHIGOG":[10,8],"BAYAWIKI":[11,8],"BAYAANGO":[12,8],"BAYAGUAYA":[13,8],"BAYAPABAYA":[14,8],
	"BAYALICHI":[15,4],"BAYAGONLAN":[16,4],"BAYAASLAC":[17,4],"BAYAYAPATI":[18,4],"BAYAARICOC":[19,4],
	"BAYAZONLAN":[20,4],"BAYAARABOL":[21,4],"HIERBABLANCA":[23,0],"HIERBAMENTAL":[28,0],"CINTAELEGIDA":[29,0],"MONEDAAMULETO":[32,10],"CINTAFOCUS":[39,10],"RESTOS":[43,10],"CASCABELCONCHA":[62,8]}
var revision: int=0:
	get:return _revision
var _revision: int=0
var _banks: Dictionary={}

static func _profile(data: Variant) -> Array:
	if not data is EnigmaData:return []
	var effect: Variant=data.hold_effect;var parameter: Variant=data.hold_effect_param
	if not effect is int or not parameter is int:return []
	if effect<0 or effect>255 or parameter<0 or parameter>255:return []
	# Native authoring safety, not Ruby's menu/checksum validity gate.
	if ((effect>=CONFUSE_SPICY and effect<=RANDOM_STAT_UP) or effect==SHELL_BELL) and parameter==0:return []
	return [effect,parameter]

func configure(saved_profile: Variant=null,link_profiles: Variant={},bank_overrides: Variant={}) -> bool:
	if not link_profiles is Dictionary or not bank_overrides is Dictionary:return false
	var next: Dictionary={}
	var saved: Array=[]
	if saved_profile!=null:
		saved=_profile(saved_profile)
		if saved.is_empty():return false
	# Nonempty modeled link profiles never inherit the local save payload.
	if link_profiles.is_empty() and not saved.is_empty():next[0]=saved.duplicate();next[2]=saved.duplicate()
	for profiles: Dictionary in [link_profiles,bank_overrides]:
		for bank: Variant in profiles:
			if not bank is int or bank<0 or bank>3:return false
			var value: Array=_profile(profiles[bank])
			if value.is_empty():return false
			next[bank]=value
	# Only validated scalar snapshots cross this atomic commit boundary.
	_banks=next;_revision+=1;return true

func describe(item: String,bank: int) -> Dictionary:
	var values: Array=FIXED.get(item,[NONE,0])
	if item==ENIGMA:values=_banks.get(bank,[NONE,0])
	var effect: int=int(values[0]);var supported: bool=effect in range(1,22) or effect in [RESTORE_STATS,CURE_ATTRACT,DOUBLE_PRIZE,FOCUS_BAND,LEFTOVERS,SHELL_BELL]
	var descriptor: Dictionary={"item":item,"source_effect":effect,"parameter":int(values[1]),"bank":bank,"provider_revision":revision,"known":effect<=LAST_KNOWN,"supported":supported,"coverage":"implemented_nonconsuming_family" if effect in [DOUBLE_PRIZE,FOCUS_BAND,LEFTOVERS,SHELL_BELL] else ("implemented_consuming_family" if supported else ("none" if effect==NONE else "REQUIRED_UNIMPLEMENTED"))}
	descriptor.make_read_only();return descriptor

func resolve(battle: Node,actor: BasePokemon,lease: Dictionary) -> Dictionary:
	return describe(ObjetosLlevados.en_combate(actor),battle.field_rules.source_bank(lease.bank))
