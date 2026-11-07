extends RefCounted
class_name BattleAnimationDirector
## Etapa 3, SDD 2026-09-14-battle-architecture-split: punto único de entrada
## para reproducir la animación de un movimiento. Decisión D2 (design.md):
## a partir de acá, la creación de Tweens para animaciones de movimiento pasa
## por este director (o por las animaciones que instancia), no directamente
## por `batalla.gd` — el resto de las animaciones (intro, PS, menús) todavía
## no migraron; ver la tabla de etapas en design.md.

## Busca la animación adecuada para el movimiento vía `MoveAnimationRegistry`
## y la arranca. Devuelve la animación en marcha: quien llama espera sus
## señales `impacto`/`finalizada` (ver `battle-move-animation` spec).
static func reproducir(contexto: MoveAnimationContext, movimiento: Movimiento, resultado: ResultadoMovimiento) -> MoveAnimation:
	if not contexto.authoritative_action:
		contexto.source_move_turn = int(movimiento.datos.get("animation_move_turn", contexto.source_move_turn))
		contexto.source_hit_index = int(movimiento.datos.get("animation_hit_index", contexto.source_hit_index))
	# Freeze accepted presentation inputs before deferred playback; never recalculate damage.
	contexto.source_power = contexto.source_power_override if contexto.source_power_override>=0 else maxi(0,movimiento.get_potencia())
	contexto.source_damage = maxi(0,resultado.damage) if resultado != null else 0
	var animacion := MoveAnimationRegistry.obtener_animacion(movimiento, contexto)
	_arrancar(contexto, resultado, animacion)
	return animacion

## Cede un frame antes de arrancar la animación para que quien llama tenga
## garantizado poder conectar/esperar `impacto`/`finalizada` antes de que la
## animación emita la primera — evita el punto muerto de esperar una señal
## que ya se emitió (mismo problema que `_esperar_tween` resolvió en la
## Etapa 1 de la intro).
static func _arrancar(contexto: MoveAnimationContext, resultado: ResultadoMovimiento, animacion: MoveAnimation) -> void:
	if not is_instance_valid(contexto.batalla) or not contexto.batalla.is_inside_tree():
		_settle_unavailable(animacion)
		return
	await contexto.batalla.get_tree().process_frame
	if is_instance_valid(contexto.batalla) and contexto.batalla.is_inside_tree():
		animacion.reproducir(contexto, resultado)
	else:
		_settle_unavailable(animacion)

## Presentation-only entry for tools and custom sequences; no moveset checks.
## §32: las animaciones generales, de estado y especiales con escena nativa van por AnimacionAuxiliarNativa si
## MoveAnimationRegistry.motivo_vm_auxiliar() lo permite (batalla real, opción activa, lista blanca); si no, la VM.
## La rama de la VM legada (BattleAnimationSequenceRegistry.animation_for_key()) está obsoleta: en producción solo se
## alcanza por configuración. Ver scripts/battle/animations/sequence/README.md.
static func play_key(key: String, context: BattleAnimationContext, status: bool = false) -> BattleSequenceAnimation:
	var animation: BattleSequenceAnimation = AnimacionAuxiliarNativa.crear(key, context, status)
	if animation == null:
		animation = BattleAnimationSequenceRegistry.animation_for_key(key, status)
	animation.play_context(context)
	return animation

static func _settle_unavailable(animation: MoveAnimation) -> void:
	if animation is BattleSequenceAnimation:
		animation.cancel()
	else:
		animation._emitir_impacto()
		animation._emitir_finalizada()
