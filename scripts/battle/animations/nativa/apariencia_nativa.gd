extends RefCounted
class_name AparienciaNativa
## Cambio de apariencia que se queda tras una animación nativa (Transformación y Sustituto, §24 de
## documentacion/piloto_animaciones_nativas.md). En el original la propia animación cambia la imagen del battler
## (sub_812D7E8 copia los gráficos del defensor; sub_81312E4 carga el muñeco) y la batalla no lo vuelve a hacer; en
## la VM legada lo hace source_transform / source_substitute con BattleOwnedAppearanceLease. Aquí se usa el mismo
## mecanismo y las mismas fuentes (BattleSourceTransform.buffer(), las texturas del muñeco de la VM): la escena pide
## la imagen nueva a mitad de animación y, al acabar sin cancelarse, la confirma; la confirmación solo se aplica si
## el battler sigue con la imagen que tenía al empezar (still_bound) y si el movimiento acertó (la regla de la VM:
## sin resultado, o acierto con efectividad > 0). Nada de esto toca el estado de juego.
##
## §33: el protocolo de los llamadores, igual que en la VM (BattleSourceTransform / BattleSourceSubstitute):
## - BattleMoveActionPresenter pone en la animación las metas `source_transform_guard_required` y
##   `source_transform_snapshot` (Transformación aceptada: guarda del original y buffer congelado al aceptarla) o
##   `source_substitute_guard_required` / `source_substitute_guard` (Sustituto aceptado). Con guarda exigida y
##   ausente o ya no ligada, la VM no crea la pista (ni cambio de imagen ni copia): aquí `anulada`.
## - Con guarda, el contrato se confirma solo si la guarda sigue ligada (`commit_guard`), con el buffer congelado y
##   el `presentation_state` de BattleTransformPresentation.transform_state() (transform_action_id), que
##   BattleTransformPresentation.reconcile() y BattleSubstituteActionCoordinator.accept_transform_handoff() leen.
## - Sustituto ↔ Pokémon (special/5, special/6, general/2 y el robo de general/17): la escena solo enseña la imagen
##   (imagenes_sustituto()); la confirma el llamador como con la VM cancelada o saltada
##   (BattleSubstituteActionCoordinator._commit_mon() / _commit(), BattleSubstitutePresentation.restore_bound()).

const TEXTURA_ESPALDA: String = "res://graficos/batalla/animaciones/substitute_back.png"
const TEXTURA_FRENTE: String = "res://graficos/batalla/animaciones/substitute_front.png"

var contexto: MoveAnimationContext
var permitir: bool = true
## §33: guarda exigida por el llamador y ausente o no ligada: la animación no cambia la imagen (ni la enseña).
var anulada: bool = false
var _contrato: BattleOwnedAppearanceLease
var _guarda_transformacion: BattleOwnedAppearanceLease
var _transformacion_exigida: bool = false
var _buffer: Dictionary = {}
var _guarda_sustituto: BattleOwnedAppearanceLease
var _sustituto_exigido: bool = false


func _init(contexto_: MoveAnimationContext, resultado: ResultadoMovimiento, metas: Object = null) -> void:
	contexto = contexto_
	permitir = resultado == null or (resultado.hit and resultado.effectiveness > 0)
	if metas == null:
		return
	if bool(metas.get_meta(&"source_transform_guard_required", false)):
		_transformacion_exigida = true
		var instantanea: Dictionary = metas.get_meta(&"source_transform_snapshot", {})
		_guarda_transformacion = instantanea.get("guard") as BattleOwnedAppearanceLease
		_buffer = instantanea.get("buffer", {})
	if bool(metas.get_meta(&"source_substitute_guard_required", false)):
		_sustituto_exigido = true
		_guarda_sustituto = metas.get_meta(&"source_substitute_guard", null) as BattleOwnedAppearanceLease


## Solo en una batalla real (el comparador no tiene grupo, especies ni escenario).
static func disponible(contexto_: MoveAnimationContext) -> bool:
	return contexto_ != null and is_instance_valid(contexto_.batalla) and (contexto_.batalla as Object).has_method(&"_obtener_combatiente") \
		and (contexto_.batalla as Object).has_method(&"_pokemon_de_slot")


## §33: como la fábrica de la VM al crear la pista (BattleSourceTransform.create()): con la guarda exigida y ausente,
## de otro battler o ya no ligada, la animación no toca la imagen. La escena lo pregunta antes de empezar.
func transformacion_anulada(sprite: Sprite2D) -> bool:
	if _transformacion_exigida and (_guarda_transformacion == null or _guarda_transformacion.actor.sprite != sprite or not _guarda_transformacion.still_bound()):
		anulada = true
	return anulada


## §33: lo mismo para el muñeco (BattleSourceSubstitute.create()).
func sustituto_anulado(sprite: Sprite2D) -> bool:
	if _sustituto_exigido and (_guarda_sustituto == null or _guarda_sustituto.actor.sprite != sprite or not _guarda_sustituto.still_bound()):
		anulada = true
	return anulada


## Imagen del defensor para el atacante (la de BattleSourceTransform.buffer(), con la paleta 6/16 hacia el blanco):
## {"texture", "flip_h"}, o vacío si no se puede. §33: con la Transformación aceptada por la batalla, el buffer que
## se congeló al aceptarla (como context.source_transform_buffer en la VM) y la guarda del original.
func preparar_transformacion() -> Dictionary:
	var vista: BattleAnimationContext = BattleAnimationContext.from_legacy(contexto)
	var atacantes: Array[BattleAnimationActor] = vista.resolve("attacker")
	var objetivos: Array[BattleAnimationActor] = vista.resolve("target")
	if atacantes.is_empty() or objetivos.is_empty():
		return {}
	if transformacion_anulada(atacantes[0].sprite):
		return {}
	_contrato = BattleOwnedAppearanceLease.capture(atacantes[0])
	var seleccion: Dictionary = _buffer.duplicate(true) if not _buffer.is_empty() else BattleSourceTransform.buffer(vista, atacantes[0], objetivos[0])
	if _transformacion_exigida:
		_contrato.commit_guard = _guarda_transformacion
		if _guarda_transformacion.before.has("shadow"):
			_contrato.before.shadow = _guarda_transformacion.before.shadow
		_contrato.replacement = seleccion
		_contrato.replacement.presentation_state = BattleTransformPresentation.transform_state(_contrato, contexto.action_id)
	else:
		_contrato.replacement = seleccion
	return {"texture": seleccion.texture, "flip_h": bool(seleccion.flip_h)}


## El muñeco del sustituto (espalda o frente según el lado del atacante): {"texture", "flip_h"}, o vacío.
## §33: con el Sustituto aceptado por la batalla, solo sobre la guarda del original (commit_guard).
func preparar_sustituto() -> Dictionary:
	var slot: BattleSlot = contexto.slot_atacante
	if not is_instance_valid(slot) or not is_instance_valid(slot.sprite_pokemon):
		return {}
	var sprite: Sprite2D = slot.sprite_pokemon
	if sustituto_anulado(sprite):
		return {}
	var actor: BattleAnimationActor = BattleAnimationActor.new(int(slot.posicion_batalla), 0 if slot.es_jugador else 1, sprite, slot)
	_contrato = BattleOwnedAppearanceLease.capture(actor)
	_contrato.commit_guard = _guarda_sustituto
	var textura: Texture2D = load(TEXTURA_ESPALDA if slot.es_jugador else TEXTURA_FRENTE) as Texture2D
	var especie: String = BattleOwnedAppearanceLease.appearance_species(sprite, slot.animation_generation)
	_contrato.replacement = {"texture": textura, "species": str(sprite.get_meta("animation_species", especie)), "kind": "substitute", "flip_h": sprite.flip_h}
	return {"texture": textura, "flip_h": sprite.flip_h}


## Fin de la animación sin cancelar: la imagen nueva se queda (si el battler sigue siendo el mismo y acertó).
func confirmar() -> void:
	if _contrato == null:
		return
	_contrato.ready = true
	_contrato.finalize(permitir)
	_contrato = null


## Cancelada o sin imagen: no cambia nada.
func descartar() -> void:
	if _contrato != null:
		_contrato.finalize(false)
	_contrato = null


## §33: las dos imágenes de un battler con sustituto, para las escenas que pasan de una a otra (special/5, special/6,
## general/2 y general/17), leídas del estado de presentación que la batalla ya registró
## (BattleSubstitutePresentation.owned_state(), el mismo que lee BattleSubstituteLifecycle._capture_swap() en la VM):
## {"tras_sustituto": el battler enseña el muñeco, "pokemon": {...}, "sustituto": {...}} con {"texture", "flip_h",
## "hframes", "vframes", "frame", "region_enabled", "region_rect"} de cada imagen. Sin estado registrado (laboratorio,
## comparador sin muñeco), la imagen actual del battler como Pokémon y el muñeco de su lado. No confirma nada.
static func imagenes_sustituto(slot: BattleSlot) -> Dictionary:
	if not is_instance_valid(slot) or not is_instance_valid(slot.sprite_pokemon):
		return {}
	var sprite: Sprite2D = slot.sprite_pokemon
	var estado: Dictionary = BattleSubstitutePresentation.owned_state(slot)
	var muneco: Dictionary = {"texture": load(TEXTURA_ESPALDA if slot.es_jugador else TEXTURA_FRENTE) as Texture2D, "flip_h": sprite.flip_h}
	var pokemon: Dictionary = _imagen(sprite)
	var tras_sustituto: bool = false
	match str(estado.get("kind", "")):
		"substitute":
			tras_sustituto = true
			muneco = _imagen(sprite)
			pokemon = (estado.get("previous", {}) as Dictionary).duplicate()
		"substitute_mon":
			var registro: Dictionary = estado.get("substitute_state", {})
			if registro.has("texture"):
				muneco = {"texture": registro.texture, "flip_h": bool(registro.get("flip_h", sprite.flip_h))}
				for propiedad: String in (registro.get("frame_properties", {}) as Dictionary):
					muneco[propiedad] = registro.frame_properties[propiedad]
	if not pokemon.has("texture") or pokemon.texture == null:
		pokemon = _imagen(sprite)
	return {"tras_sustituto": tras_sustituto, "pokemon": pokemon, "sustituto": muneco}


static func _imagen(sprite: Sprite2D) -> Dictionary:
	return {"texture": sprite.texture, "flip_h": sprite.flip_h, "flip_v": sprite.flip_v, "hframes": sprite.hframes, "vframes": sprite.vframes,
		"frame": sprite.frame, "region_enabled": sprite.region_enabled, "region_rect": sprite.region_rect}
