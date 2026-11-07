extends RefCounted
class_name ResultadoMovimiento
## Resultado ya calculado de un movimiento de daño. `MoveResolver` lo produce
## sin efectos secundarios (Decisión D3, SDD `2026-09-14-battle-architecture-split`):
## antes solo existía como el valor de retorno de `calcular_dano()` más un
## campo de instancia (`mensaje_dano`) que la función escribía como canal
## lateral. Quien lo recibe decide cuándo mostrarlo y cuándo aplicarlo.

## Daño final ya redondeado a entero (0 si el movimiento no afecta o no tiene
## potencia). Ver la nota de truncamiento en calcular_dano().
var damage: int = 0
## Multiplicador de efectividad de tipo ya resuelto (0.0 = inmune).
var effectiveness: float = 1.0
## Mensaje de resultado ("¡Es super efectivo!", "No es muy eficaz...", etc.).
var message: String = ""
## Sin sistema de precisión implementado todavía (Decisión D6): siempre true.
## El campo existe para que el futuro director de animaciones (Etapa 3) no
## tenga que cambiar de forma cuando la precisión se implemente.
var hit: bool = true
## true si el golpe fue crítico (daño ×2). Solo se calcula si el llamador pasa
## `permitir_criticos` a `MoveResolver.calcular_dano`.
var critico: bool = false
