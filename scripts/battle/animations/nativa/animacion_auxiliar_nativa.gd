extends BattleSequenceAnimation
class_name AnimacionAuxiliarNativa
## §32 (documentacion/piloto_animaciones_nativas.md): vía nativa de BattleAnimationDirector.play_key() para las
## animaciones que no son de movimiento (ruby:general/*, ruby:status/*, ruby:special/*). Envuelve un
## AnimacionEscenaNativa con la API de BattleSequenceAnimation que usan los llamadores (esperar_finalizada(),
## state, definition, lifecycle_aborted, wait_marker(), cancel()/skip(), `runner` siempre null) sin duplicar estado
## de juego: solo reproduce la escena y avisa al acabar.
##
## Política: la de MoveAnimationRegistry.motivo_vm_auxiliar() (opción de proyecto, lista blanca por estado de
## estado_migracion.json, solo con batalla real, sin dobles ni varios objetivos; §33: con sustituto y transformación sí).
## §33: las de sustituto (special/5, special/6, general/2) solo enseñan la imagen; la confirma el llamador como con la VM.
## Si no se cumple, crear() devuelve null y play_key() sigue con la VM.

## Nombres para herramientas (laboratorio nativo): clave -> nombre legible.
const NOMBRES: Dictionary = {
	"ruby:general/1": "Cambio de estadística", "ruby:general/2": "Sustituto se desvanece",
	"ruby:general/3": "Sustituto aparece", "ruby:general/5": "Objeto tirado (Desarme)",
	"ruby:general/6": "Atrapado (daño por turno)", "ruby:general/7": "Efecto de objeto",
	"ruby:general/9": "Aguantó (Cinta Focus)", "ruby:general/10": "Lluvia (continúa)", "ruby:general/11": "Sol (continúa)",
	"ruby:general/12": "Tormenta de arena (continúa)", "ruby:general/13": "Granizo (continúa)",
	"ruby:general/14": "Drenadoras", "ruby:general/16": "Robo de objeto", "ruby:general/17": "Robo (Snatch)",
	"ruby:general/18": "Premonición (golpe)", "ruby:general/19": "Deseo Oculto (golpe)",
	"ruby:general/20": "Puño Certero (preparación)", "ruby:general/21": "Arraigo (curación)",
	"ruby:general/22": "Deseo (curación)",
	"ruby:status/0": "Envenenado", "ruby:status/1": "Confuso", "ruby:status/2": "Quemado", "ruby:status/3": "Enamorado",
	"ruby:status/4": "Dormido", "ruby:status/5": "Paralizado", "ruby:status/6": "Congelado", "ruby:status/7": "Maldito",
	"ruby:status/8": "Pesadilla", "ruby:special/5": "Sustituto a Pokémon", "ruby:special/6": "Pokémon a sustituto",
}

var nativa: AnimacionEscenaNativa
var contexto_nativo: MoveAnimationContext
var _cancelando: String = ""


## La animación nativa para `key` en este contexto, o null si debe ir por la VM.
static func crear(key: String, contexto: BattleAnimationContext, status: bool = false) -> AnimacionAuxiliarNativa:
	if not MoveAnimationRegistry.es_auxiliar(key) or not MoveAnimationRegistry.usar_animaciones_nativas:
		return null
	if not MoveAnimationRegistry.motivo_vm_auxiliar(key, contexto).is_empty():
		return null
	var adaptador: AnimacionEscenaNativa = AnimacionEscenaNativa.para_clave(key)
	if adaptador == null:
		return null
	var animacion: AnimacionAuxiliarNativa = AnimacionAuxiliarNativa.new()
	animacion.definition = BattleAnimationSequenceRegistry.get_definition(key, status)
	animacion.nativa = adaptador
	animacion.contexto_nativo = MoveAnimationRegistry.contexto_auxiliar(contexto)
	adaptador.argumento_auxiliar = int(contexto.get_meta("source_general_argument", -1))
	return animacion


## Las animaciones de estado y las especiales usan el mismo battler como atacante y objetivo
## (move_anim_start_t2 / InitAndLaunchSpecialAnimation): las herramientas lo usan para montar el contexto.
static func mismo_battler(key: String) -> bool:
	return key.begins_with("ruby:status/") or key.begins_with("ruby:special/")


func play_context(context: BattleAnimationContext) -> void:
	if state != "pending":
		return
	if nativa == null or contexto_nativo == null or not is_instance_valid(context.field) or not context.field.is_inside_tree():
		_complete("failed")
		return
	# Como la VM: una animación nueva corta la que siguiera activa en el campo.
	var previa: Variant = context.field.get_meta("active_move_animation") if context.field.has_meta("active_move_animation") else null
	if previa is WeakRef:
		var activa: Variant = (previa as WeakRef).get_ref()
		if is_instance_valid(activa) and activa != self:
			activa.cancel()
	context.field.set_meta("active_move_animation", weakref(self))
	state = "running"
	nativa.impacto.connect(_al_impacto_nativo)
	nativa.finalizada.connect(_al_fin_nativo, CONNECT_ONE_SHOT)
	nativa.reproducir(contexto_nativo, null)


func cancel() -> void:
	_cortar("cancelled")


func skip() -> void:
	_cortar("completed")


func _cortar(estado_final: String) -> void:
	if state == "running" and nativa != null:
		_cancelando = estado_final
		nativa.cancelar()
	else:
		_complete(estado_final)


func _al_impacto_nativo() -> void:
	if not _impacto_emitido:
		_on_marker({"name": "impact", "state": "native"})


func _al_fin_nativo() -> void:
	_complete(_cancelando if not _cancelando.is_empty() else "completed")
