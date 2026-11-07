@tool
class_name CalculadoraStatsPokemon
extends RefCounted
## Fuente UNICA de las formulas de estadisticas de Pokemon.
##
## La usan BasePokemon (entidad del juego) y el Editor de Instancia de Pokemon
## (herramienta @tool del plugin). Cualquier UI o sistema nuevo debe llamar
## aqui: NUNCA copiar la formula, para que editor y juego muestren siempre los
## mismos numeros. Las estadisticas son datos derivados y no se persisten en
## la BBDD (alli solo viven las entradas: IVs, EVs, nivel, naturaleza).

## Tabla del Poder Oculto: indice = suma de bits de IV impar modulo 16.
const TIPOS_PODER_OCULTO: Array[String] = [
	"LUCHA", "VOLADOR", "VENENO", "TIERRA", "ROCA", "BICHO", "FANTASMA", "ACERO",
	"FUEGO", "AGUA", "PLANTA", "ELECTRICO", "PSIQUICO", "HIELO", "DRAGON", "SINIESTRO",
]


## PS maximos.
static func stat_ps(base: int, iv: int, ev: int, nivel: int) -> int:
	return int((2.0 * float(base) + float(iv) + float(ev) / 4.0) * float(nivel) / 100.0 + float(nivel) + 10.0)


## Resto de estadisticas. mult_naturaleza: 1.0 neutra, 1.1 aumentada,
## 0.9 reducida (con 1.0 el redondeo es neutro y replica la formula base).
static func stat_general(base: int, iv: int, ev: int, nivel: int, mult_naturaleza: float = 1.0) -> int:
	var stat := int((2.0 * float(base) + float(iv) + float(ev) / 4.0) * float(nivel) / 100.0 + 5.0)
	return int(round(float(stat) * mult_naturaleza))


## Curvas de crecimiento (indices de `gExperienceTables` en pokeruby).
const RATIO_NORMAL := "NORMAL"          # GROWTH_MEDIUM_FAST
const RATIO_ERRATICO := "ERRATICO"      # GROWTH_ERRATIC
const RATIO_FLUCTUANTE := "FLUCTUANTE"  # GROWTH_FLUCTUATING
const RATIO_PARABOLICO := "PARABOLICO"  # GROWTH_MEDIUM_SLOW
const RATIO_RAPIDO := "RAPIDO"          # GROWTH_FAST
const RATIO_LENTO := "LENTO"            # GROWTH_SLOW

## Nombres que acepta `experiencia_nivel`. La columna `Pokemon.ratio_crecimiento`
## de poke.db guarda los nombres de PokeAPI (`medium_slow`, ...); los nombres
## en espanol se mantienen por compatibilidad con el codigo existente.
const ALIAS_RATIO_CRECIMIENTO := {
	"NORMAL": RATIO_NORMAL,
	"MEDIUM": RATIO_NORMAL,
	"MEDIUM_FAST": RATIO_NORMAL,
	"ERRATICO": RATIO_ERRATICO,
	"ERRATIC": RATIO_ERRATICO,
	"SLOW_THEN_VERY_FAST": RATIO_ERRATICO,
	"FLUCTUANTE": RATIO_FLUCTUANTE,
	"FLUCTUATING": RATIO_FLUCTUANTE,
	"FAST_THEN_VERY_SLOW": RATIO_FLUCTUANTE,
	"PARABOLICO": RATIO_PARABOLICO,
	"MEDIUM_SLOW": RATIO_PARABOLICO,
	"RAPIDO": RATIO_RAPIDO,
	"FAST": RATIO_RAPIDO,
	"LENTO": RATIO_LENTO,
	"SLOW": RATIO_LENTO,
}

const NIVEL_MAXIMO := 100


## Nombre canonico (RATIO_*) de un ratio de crecimiento, sin distinguir
## mayusculas. Un ratio desconocido o vacio (especie sin datos) usa NORMAL.
static func normalizar_ratio_crecimiento(ratio_crecimiento: String) -> String:
	return ALIAS_RATIO_CRECIMIENTO.get(ratio_crecimiento.strip_edges().to_upper(), RATIO_NORMAL)


## Experiencia total necesaria para alcanzar [param nivel] segun el ratio de
## crecimiento (ver `normalizar_ratio_crecimiento`). Reproduce exactamente
## `gExperienceTables` de pokeruby (src/data/pokemon/experience_tables.h): las
## formulas de cada curva con division entera de C, salvo los niveles 0 y 1,
## que la tabla fija a 0 y 1 (la formula PARABOLICO daria -54 en el nivel 1).
@warning_ignore("integer_division")
static func experiencia_nivel(nivel: int, ratio_crecimiento: String) -> int:
	if nivel <= 0:
		return 0
	if nivel == 1:
		return 1
	var n := nivel
	var cubo := n * n * n
	match normalizar_ratio_crecimiento(ratio_crecimiento):
		RATIO_LENTO:
			return 5 * cubo / 4
		RATIO_RAPIDO:
			return 4 * cubo / 5
		RATIO_PARABOLICO:
			return 6 * cubo / 5 - 15 * n * n + 100 * n - 140
		RATIO_ERRATICO:
			if n <= 50:
				return (100 - n) * cubo / 50
			elif n <= 68:
				return (150 - n) * cubo / 100
			elif n <= 98:
				return ((1911 - 10 * n) / 3) * cubo / 500
			return (160 - n) * cubo / 100
		RATIO_FLUCTUANTE:
			if n <= 15:
				return ((n + 1) / 3 + 24) * cubo / 50
			elif n <= 36:
				return (n + 14) * cubo / 50
			return ((n / 2) + 32) * cubo / 50
	return cubo


## Devuelve [param experiencia] ajustada al rango valido de [param nivel] en la
## curva: [exp(nivel), exp(nivel + 1) - 1], y exactamente exp(100) en el nivel
## maximo. Si ya es valida no cambia (idempotente). Se usa al cargar partidas
## guardadas antes de que las curvas leyeran bien la BBDD (todas las especies
## usaban n^3): el nivel guardado manda y la experiencia se lleva al valor
## valido mas cercano (el minimo del nivel si se quedo corta, o a un punto del
## siguiente nivel si lo superaba), sin subir ni bajar nunca de nivel.
static func ajustar_experiencia_a_nivel(experiencia: int, nivel: int, ratio_crecimiento: String) -> int:
	var nivel_valido := clampi(nivel, 1, NIVEL_MAXIMO)
	var minimo := experiencia_nivel(nivel_valido, ratio_crecimiento)
	if nivel_valido >= NIVEL_MAXIMO:
		return minimo
	var maximo := experiencia_nivel(nivel_valido + 1, ratio_crecimiento) - 1
	return clampi(experiencia, minimo, maximo)


## Tipo del Poder Oculto a partir de los IVs (orden: PS, Ataque, Defensa,
## Velocidad, At. Esp., Def. Esp.). Copia EXACTA de la tabla historica de
## BasePokemon (que ahora delega aqui): suma de bits de IV impar modulo 16.
static func tipo_poder_oculto(iv_ps: int, iv_ataque: int, iv_defensa: int, iv_velocidad: int, iv_ataque_especial: int, iv_defensa_especial: int) -> String:
	var ivs: Array[int] = [iv_ps, iv_ataque, iv_defensa, iv_velocidad, iv_ataque_especial, iv_defensa_especial]
	var tipo := 0
	for i in range(6):
		if ivs[i] % 2 == 1:
			tipo += 2 ** i
	tipo = tipo % 16
	# https://pokemon.fandom.com/es/wiki/C%C3%A1lculo_del_poder_oculto
	return TIPOS_PODER_OCULTO[tipo]
