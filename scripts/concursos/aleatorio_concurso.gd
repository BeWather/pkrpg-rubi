class_name AleatorioConcurso
extends RefCounted
## Random() de pokeruby para los concursos: cada tirada es un u16 (0..65535) y las
## reglas lo reducen igual que el original (`% 10`, `% 100`, `% 3`, `% (4 - i)`,
## `& 0xFF`). El original avanza el RNG en cada VBlank, así que su estado no se
## reproduce; lo que se conserva es el orden lógico de las tiradas.
##
## Para tests: `fijar_secuencia()` hace que las próximas tiradas devuelvan esos
## valores (después sigue el generador con semilla).

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _secuencia: Array[int] = []
## Número de tiradas hechas (para comprobar el orden en tests).
var tiradas: int = 0


func _init(semilla: int = 0) -> void:
	if semilla != 0:
		_rng.seed = semilla
	else:
		_rng.randomize()


## Las próximas tiradas devolverán estos valores, en orden.
func fijar_secuencia(valores: Array[int]) -> void:
	_secuencia = valores.duplicate()


## Random(): u16.
func u16() -> int:
	tiradas += 1
	if not _secuencia.is_empty():
		return _secuencia.pop_front() & 0xFFFF
	return _rng.randi() & 0xFFFF


## Random() % n.
func modulo(n: int) -> int:
	return u16() % n
