extends RefCounted
class_name SistemaRevanchas

## Estado y reglas de las revanchas de entrenadores de Rubí
## (`src/battle_setup.c:1272-1486` de pokeruby), sin nodos ni UI.
##
## - `pasos` = `trainerRematchStepCounter` (0..255).
## - `listas` = `trainerRematches[]` disperso: índice de entrada -> 1..5.
## - `tiers_vencidos` = flags de entrenador de los tiers >= 2. El tier 1 lo sigue
##   llevando cada NPC con `<npc_id>_combate`, así que quien llama filtra los
##   candidatos del sorteo y solo pregunta por entrenadores ya vencidos.
##
## `tabla` es inyectable para los tests (por defecto, `TablaRevanchas.entradas()`).

const PASOS_REVANCHA: int = 255  # TRAINER_REMATCH_STEPS
const MEDALLAS_MINIMAS: int = 5  # HasAtLeastFiveBadges
const PROBABILIDAD_MAXIMA: int = 30  # Random() % 100 <= 30 -> 31 %

var pasos: int = 0
var listas: Dictionary = {}
var tiers_vencidos: Dictionary = {}
var tabla: Array = []


func _init(p_tabla: Array = []) -> void:
	tabla = p_tabla if not p_tabla.is_empty() else TablaRevanchas.entradas()


## `IncrementRematchStepCounter`: un paso del jugador.
func procesar_paso(medallas: int) -> void:
	if medallas < MEDALLAS_MINIMAS:
		return
	pasos = mini(pasos + 1, PASOS_REVANCHA)


## `TryUpdateRandomTrainerRematches` + `UpdateRandomTrainerEyeRematches`.
## `candidatos`: índices de entrada del mapa cuyo tier 1 ya está vencido.
## `rng`: `RandomNumberGenerator` o cualquier objeto con `randi()` (tests).
## Devuelve true si alguien del mapa quiere revancha (y reinicia `pasos`).
func sortear_mapa(candidatos: Array, medallas: int, rng: Object) -> bool:
	if medallas < MEDALLAS_MINIMAS or pasos < PASOS_REVANCHA:
		return false
	var exito := false
	var vistos := {}
	for i in candidatos:
		var indice := int(i)
		if vistos.has(indice) or indice < 0 or indice >= tabla.size():
			continue
		vistos[indice] = true
		if esta_lista(indice):
			exito = true
		elif rng.randi() % 100 <= PROBABILIDAD_MAXIMA:
			listas[indice] = _valor_lista(indice)
			exito = true
	if exito:
		pasos = 0
	return exito


func esta_lista(indice: int) -> bool:
	return listas.has(indice)


## `ShouldTryRematchBattle` (con el tier 1 ya vencido): lista, o tier 2 ya vencido.
func debe_ofrecer_revancha(indice: int) -> bool:
	if indice < 0 or indice >= tabla.size():
		return false
	return esta_lista(indice) or esta_vencido(_ids(indice)[1])


## `GetRematchTrainerIdFromTable`: primer tier no vencido; si todos lo están, el último.
func id_revancha(indice: int) -> int:
	var ids := _ids(indice)
	for j in range(1, TablaRevanchas.NUM_TIERS):
		if ids[j] == 0:
			return ids[j - 1]
		if not esta_vencido(ids[j]):
			return ids[j]
	return ids[TablaRevanchas.NUM_TIERS - 1]


func esta_vencido(id: int) -> bool:
	return tiers_vencidos.has(id)


## `SetTrainerFlagsAfterTrainerEyeRematch`: marca el tier y la entrada deja de estar lista.
func registrar_victoria(id: int) -> void:
	if id <= 0:
		return
	tiers_vencidos[id] = true
	var indice := TablaRevanchas.indice_por_cualquier_id_en(tabla, id)
	if indice >= 0:
		listas.erase(indice)


func indice_por_primer_id(id: int) -> int:
	return TablaRevanchas.indice_por_primer_id_en(tabla, id)


func indice_por_cualquier_id(id: int) -> int:
	return TablaRevanchas.indice_por_cualquier_id_en(tabla, id)


## Índices en estado lista (para un futuro Ojo Entrenador / luz del PokéNav).
func indices_listos() -> Array[int]:
	var resultado: Array[int] = []
	for indice in listas:
		resultado.append(int(indice))
	resultado.sort()
	return resultado


## === DEBUG (`start_menu_debug.c:1215-1270`) ===

func debug_llenar_pasos() -> void:
	pasos = PASOS_REVANCHA


func debug_marcar_lista(indice: int) -> void:
	if indice >= 0 and indice < tabla.size():
		listas[indice] = _valor_lista(indice)


func debug_limpiar() -> void:
	pasos = 0
	listas.clear()
	tiers_vencidos.clear()


## === SERIALIZACIÓN ===

func to_dict() -> Dictionary:
	var listas_dict := {}
	for indice in listas:
		listas_dict[str(indice)] = int(listas[indice])
	var vencidos: Array = []
	for id in tiers_vencidos:
		vencidos.append(int(id))
	vencidos.sort()
	return {"pasos": pasos, "listas": listas_dict, "tiers_vencidos": vencidos}


func from_dict(d: Dictionary) -> void:
	pasos = clampi(int(d.get("pasos", 0)), 0, PASOS_REVANCHA)
	listas = {}
	var listas_cargadas: Variant = d.get("listas", {})
	if listas_cargadas is Dictionary:
		for clave in listas_cargadas:
			var valor := int(listas_cargadas[clave])
			if valor != 0:
				listas[int(clave)] = valor
	tiers_vencidos = {}
	var vencidos_cargados: Variant = d.get("tiers_vencidos", [])
	if vencidos_cargados is Array:
		for id in vencidos_cargados:
			tiers_vencidos[int(id)] = true


## Valor de `trainerRematches[i]` al quedar lista: primer tier (1..4) no vencido,
## 5 si todos lo están, o el alcanzado si la cadena se corta (WALLY -> 4).
func _valor_lista(indice: int) -> int:
	var ids := _ids(indice)
	var r := 1
	while r < TablaRevanchas.NUM_TIERS and ids[r] != 0 and esta_vencido(ids[r]):
		r += 1
	return r


func _ids(indice: int) -> Array:
	return tabla[indice]["ids"]
