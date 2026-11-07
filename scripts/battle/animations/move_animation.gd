extends RefCounted
class_name MoveAnimation
## Clase base de las animaciones de movimiento (Etapa 3, SDD
## 2026-09-14-battle-architecture-split). `MoveResolver` ya calculó el
## resultado antes de que esto corra: la animación decide CUÁNDO se ve el
## impacto, nunca SI el movimiento acierta o cuánto daño hace.
##
## Contrato: sobreescribir `reproducir()`, llamar a `_emitir_impacto()` en el
## instante visual del golpe y a `_emitir_finalizada()` cuando la animación
## termina del todo (en vez de emitir las señales directamente — ver abajo).
## `BattleAnimationDirector` garantiza que quien llama tiene oportunidad de
## conectar `impacto` antes de que `reproducir()` corra ni un frame, pero
## `finalizada` puede terminar disparándose mientras quien llama todavía
## está ocupado con otro await en paralelo (p. ej. el tween de la barra de
## PS tras 'impacto') — por eso quien consume esta clase debe usar
## `esperar_impacto()`/`esperar_finalizada()`, no `await animacion.impacto`
## directo, para no quedarse esperando una señal que ya se emitió (mismo
## problema que resolvió `_esperar_tween` en la Etapa 1 de la intro).

signal impacto
signal finalizada

var _impacto_emitido := false
var _finalizada_emitida := false

## Las subclases deben sobreescribir esto. La implementación base es un
## fallback trivial (impacto y fin inmediatos); no debería alcanzarse en la
## práctica, `MoveAnimationRegistry` siempre resuelve a una animación
## concreta.
func reproducir(_contexto: MoveAnimationContext, _resultado: ResultadoMovimiento) -> void:
	_emitir_impacto()
	_emitir_finalizada()

## Las subclases llaman a esto en el instante visual del golpe, en vez de
## `impacto.emit()` directamente.
func _emitir_impacto() -> void:
	_impacto_emitido = true
	impacto.emit()

## Las subclases llaman a esto cuando la animación termina del todo, en vez
## de `finalizada.emit()` directamente.
func _emitir_finalizada() -> void:
	_finalizada_emitida = true
	finalizada.emit()

## Espera a 'impacto' sin quedarse colgado si ya se emitió.
func esperar_impacto() -> void:
	if not _impacto_emitido:
		await impacto

## Espera a 'finalizada' sin quedarse colgado si ya se emitió.
func esperar_finalizada() -> void:
	if not _finalizada_emitida:
		await finalizada
