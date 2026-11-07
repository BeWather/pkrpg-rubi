class_name ReglasLicuadora
extends RefCounted
## Reglas de la LICUABAYAS de Rubí (src/berry_blender.c de pokeruby), como funciones
## estáticas puras y deterministas: lo aleatorio entra como `tirada` explícita o como
## un RandomNumberGenerator inyectado. No dibuja nada; el controlador de la escena
## (escenas/licuadora/) las llama cada fotograma.
##
## Unidades del decomp:
## - ángulo de la flecha: u16, 0x10000 = una vuelta (`arrowPos`);
## - velocidad: lo que avanza el ángulo por fotograma (`field_56`, empieza en 128);
## - RPM: en centésimas (`max_RPM`, 10000 = 100,00 RPM);
## - progreso: 0..1000 (`field_13E` real y `field_140` visible).
##
## Jugadores: el 0 es el jugador; los rivales NPC son 1, 2 y 3 (gSpecialVar_0x8004
## = número de rivales, así que hay 2-4 jugadores). Cada jugador ocupa una «ranura»
## (0-3, la flecha/esquina de la pantalla) según `ranura_de_jugador()`.
##
## Bayas: diccionarios con las columnas de la tabla `Bayas` (`picante`, `seco`,
## `dulce`, `amargo`, `acido`, `suavidad`, `numero` y opcionalmente `objeto_id`), tal
## como los devuelve `DatabaseManager.obtener_datos_baya()`. `numero` es el índice de
## gBerries + 1 (CHERI = 1 … ENIGMA = 43); en rubi4 CHERI es Objetos.id 126, no el
## ITEM 133 del decomp, así que donde el C hace `item - 133` aquí se usa `numero - 1`.

## Calidad de un pulsado: el retorno de sub_804F16C (0 fuera, 1 zona, 2 centro).
## Mismos valores que `Licuadora.Calidad` (escenas/licuadora/licuadora.gd), que es
## el enum que recibe `Licuadora.mostrar_resultado()`; se define aquí para no
## depender de la escena. Códigos del decomp: FALLO 0x2345, BUENO 0x5432,
## PERFECTO 0x4523.
enum Calidad { FALLO, BUENO, PERFECTO }

const NUM_JUGADORES_MIN: int = 2
const NUM_JUGADORES_MAX: int = 4
const VUELTA: int = 0x10000

## Velocidad al empezar el minijuego (case 21 de sub_804F378) y mínimo de la fricción
## y de los fallos.
const VELOCIDAD_INICIAL: int = 128
const VELOCIDAD_MINIMA: int = 128
## Umbral a partir del cual PERFECTO solo suma 128/d, BUENO deja de sumar, la pantalla
## tiembla y la música acelera.
const UMBRAL_VELOCIDAD_ALTA: int = 1500
## Umbral de la IA: por debajo los rivales juegan «fácil».
const UMBRAL_VELOCIDAD_IA: int = 500
## sub_80500A8: la velocidad baja 1 cuando el contador supera 5 (cada 6 fotogramas).
const FOTOGRAMAS_FRICCION: int = 6
const PROGRESO_MAXIMO: int = 1000
## sub_805194C: la barra visible persigue al progreso real de 2 en 2.
const PASO_BARRA_VISIBLE: int = 2
## Divisores de PERFECTO y BUENO en la barra (sub_804FE70).
const DIVISOR_PROGRESO_PERFECTO: int = 55
const DIVISOR_PROGRESO_BUENO: int = 70
const TEMPO_NORMAL: int = 256
## El contador de fallos de cada jugador no pasa de 999.
const FALLOS_MAXIMOS: int = 999
## sub_804F890(jugador, 5): el FALLO de la IA llega con este retraso (la tarea lo
## envía cuando su contador supera 5).
const RETRASO_FALLO_IA: int = 5

## gUnknown_082162EC[N-2][ranura] = jugador que ocupa la ranura (-1 = nadie).
const JUGADOR_POR_RANURA: Array = [[-1, 0, 1, -1], [-1, 0, 1, 2], [0, 1, 2, 3]]
## gUnknown_082162F8 y gUnknown_08216300[N-2]: ángulo de la flecha al empezar.
const ANGULOS_INICIALES: Array[int] = [0, 0xC000, 0x4000, 0x8000]
const INDICE_ANGULO_INICIAL: Array[int] = [1, 1, 0]
## Desfase del ángulo al empezar a girar el disco (case 12 de sub_804F378).
const DESFASE_ANGULO_ENTRADA: int = 22528
## gUnknown_08216303: inicio de la zona de acierto de cada ranura (en ángulo/256 + 24).
const INICIO_ZONA: Array[int] = [32, 224, 96, 160]
const ANCHO_ZONA: int = 48
const INICIO_PERFECTO: int = 20
const FIN_PERFECTO: int = 28
## Ventana de los rivales 2 y 3 (sub_804F9F4 / sub_804FB1C): ((ángulo + 0x1800) >> 8)
## estrictamente entre z+20 y z+40.
const DESFASE_VENTANA_IA: int = 0x1800
const VENTANA_IA_MIN: int = 20
const VENTANA_IA_MAX: int = 40
## gUnknown_082165DA[N]: divisor del efecto de un pulsado en la velocidad.
const DIVISOR_VELOCIDAD: Array[int] = [1, 1, 2, 3, 4]
## gUnknown_082165BC: bayas básicas (numero - 1) que meten los rivales 1, 2 y 3.
const BAYAS_RIVALES: Array = [
	[4, 3, 2], [0, 4, 3], [1, 0, 4], [2, 1, 0], [3, 2, 1],
	[0, 2, 3], [1, 3, 4], [2, 4, 0], [3, 0, 1], [4, 1, 2],
]
## gUnknown_082165DF: sabores (bit i = sabor i) que valen 2 en un cubo NEGRO.
const MASCARAS_NEGRO: Array[int] = [0x1C, 0x16, 0x13, 0x1A, 0x19, 0x0E, 0x0D, 0x0B, 0x07, 0x15]
const VALOR_SABOR_NEGRO: int = 2
## Colores de 1 sabor (picante…ácido) y del sabor dominante con 2 sabores.
const COLOR_UN_SABOR: Array[int] = [
	Pokecubo.ColorPokecubo.ROJO, Pokecubo.ColorPokecubo.AZUL, Pokecubo.ColorPokecubo.ROSA,
	Pokecubo.ColorPokecubo.VERDE, Pokecubo.ColorPokecubo.AMARILLO,
]
const COLOR_DOS_SABORES: Array[int] = [
	Pokecubo.ColorPokecubo.MORADO, Pokecubo.ColorPokecubo.INDIGO, Pokecubo.ColorPokecubo.MARRON,
	Pokecubo.ColorPokecubo.AZUL_CLARO, Pokecubo.ColorPokecubo.OLIVA,
]
## Con algún sabor por encima de esto (tras la RPM) el cubo es DORADO.
const UMBRAL_DORADO: int = 50
## Bayas.numero de la BAYA ENIGMA (ITEM_ENIGMA_BERRY).
const NUMERO_ENIGMA: int = 43
## Claves de sabor en los diccionarios de baya, en el orden del decomp.
const CLAVES_SABOR: Array[String] = ["picante", "seco", "dulce", "amargo", "acido"]
## sBlenderOpponentsNames (berry_blender.c:306-318): MISTER, LADDIE y LASSIE para
## los rivales 1, 2 y 3 (Blender_SetPlayerNamesLocal). Sin texto todavía.
const CLAVES_NOMBRES_RIVALES: Array[String] = [
	"LICUADORA_RIVAL_1", "LICUADORA_RIVAL_2", "LICUADORA_RIVAL_3",
]


# ============================================================================
# Ranuras, ángulo y ventanas de acierto
# ============================================================================

## field_A2[jugador] (sub_804F238): ranura (0-3) que ocupa `jugador` con
## `num_jugadores` jugadores; -1 si no juega.
static func ranura_de_jugador(jugador: int, num_jugadores: int) -> int:
	var fila: Array = _fila_ranuras(num_jugadores)
	return fila.find(jugador) if jugador >= 0 else -1


## field_9A[ranura]: jugador que ocupa `ranura`, -1 si está vacía.
static func jugador_en_ranura(ranura: int, num_jugadores: int) -> int:
	var fila: Array = _fila_ranuras(num_jugadores)
	if ranura < 0 or ranura >= fila.size():
		return -1
	return int(fila[ranura])


## Ángulo con el que la flecha empieza el minijuego (case 14 de sub_804F378).
static func angulo_inicial(num_jugadores: int) -> int:
	var n: int = clampi(num_jugadores, NUM_JUGADORES_MIN, NUM_JUGADORES_MAX)
	return ANGULOS_INICIALES[INDICE_ANGULO_INICIAL[n - NUM_JUGADORES_MIN]]


## Ángulo al empezar la animación de entrada del disco (case 12); el disco gira
## +0x200 por fotograma hasta `angulo_inicial()`.
static func angulo_inicio_entrada(num_jugadores: int) -> int:
	return (angulo_inicial(num_jugadores) - DESFASE_ANGULO_ENTRADA) & 0xFFFF


## sub_8051474: la flecha avanza `velocidad` por fotograma (u16, da la vuelta).
static func avanzar_angulo(angulo: int, velocidad: int) -> int:
	return (angulo + velocidad) & 0xFFFF


## gUnknown_08216303[ranura]: inicio de la zona de acierto de la ranura.
static func inicio_zona(ranura: int) -> int:
	return INICIO_ZONA[clampi(ranura, 0, INICIO_ZONA.size() - 1)]


## sub_804F16C: calidad de pulsar A con la flecha en `angulo` (u16) para la ranura
## `ranura`. p = ángulo/256 + 24 (sin dar la vuelta, hasta 279): BUENO en
## [z, z+48), PERFECTO en [z+20, z+28), FALLO fuera.
static func calidad_pulsado(angulo: int, ranura: int) -> Calidad:
	var p: int = ((angulo & 0xFFFF) >> 8) + 24
	var z: int = inicio_zona(ranura)
	if p < z or p >= z + ANCHO_ZONA:
		return Calidad.FALLO
	if p >= z + INICIO_PERFECTO and p < z + FIN_PERFECTO:
		return Calidad.PERFECTO
	return Calidad.BUENO


## Calidad del pulsado del `jugador` (busca su ranura).
static func calidad_pulsado_jugador(angulo: int, jugador: int, num_jugadores: int) -> Calidad:
	var ranura: int = ranura_de_jugador(jugador, num_jugadores)
	if ranura < 0:
		return Calidad.FALLO
	return calidad_pulsado(angulo, ranura)


# ============================================================================
# Velocidad, barra de progreso, RPM y música
# ============================================================================

## gUnknown_082165DA[N].
static func divisor_velocidad(num_jugadores: int) -> int:
	return DIVISOR_VELOCIDAD[clampi(num_jugadores, 0, DIVISOR_VELOCIDAD.size() - 1)]


## sub_804FD30: velocidad tras un pulsado de `calidad`, con d = divisor_velocidad(N):
## - PERFECTO: +384/d si la velocidad es < 1500; si no, +128/d (no hay tope duro:
##   por encima de 1500 sigue subiendo, más despacio);
## - BUENO: +256/d solo si es < 1500;
## - FALLO: −256/d, mínimo 128.
static func velocidad_tras_pulsado(velocidad: int, calidad: Calidad, num_jugadores: int) -> int:
	var d: int = divisor_velocidad(num_jugadores)
	match calidad:
		Calidad.PERFECTO:
			if velocidad < UMBRAL_VELOCIDAD_ALTA:
				return velocidad + 384 / d
			return velocidad + 128 / d
		Calidad.BUENO:
			if velocidad < UMBRAL_VELOCIDAD_ALTA:
				return velocidad + 256 / d
			return velocidad
		_:
			return maxi(velocidad - 256 / d, VELOCIDAD_MINIMA)


## true si un PERFECTO con `velocidad` (la de antes del pulsado) hace temblar la
## pantalla (rama >= 1500 de sub_804FD30). La amplitud aleatoria la decide la escena.
static func pulsado_hace_temblar(velocidad: int, calidad: Calidad) -> bool:
	return calidad == Calidad.PERFECTO and velocidad >= UMBRAL_VELOCIDAD_ALTA


## sub_80500A8: un fotograma de fricción. Recibe la velocidad y el contador de
## fotogramas (field_7E, empieza en 0) y devuelve Vector2i(velocidad, contador):
## cuando el contador supera 5 vuelve a 0 y la velocidad baja 1 si es > 128.
static func paso_friccion(velocidad: int, contador: int) -> Vector2i:
	var c: int = contador + 1
	if c >= FOTOGRAMAS_FRICCION:
		return Vector2i(velocidad - 1 if velocidad > VELOCIDAD_MINIMA else velocidad, 0)
	return Vector2i(velocidad, c)


## sub_804FE70: progreso real tras un pulsado. `velocidad` es la de DESPUÉS de aplicar
## `velocidad_tras_pulsado()` (el C cambia la velocidad antes de sumar):
## PERFECTO +vel/55, BUENO +vel/70, FALLO no suma. Tope 1000 (el C solo recorta en
## PERFECTO; con BUENO puede pasarse, pero la barra visible termina en el mismo
## fotograma, así que el resultado observable es el mismo).
static func progreso_tras_pulsado(progreso: int, velocidad: int, calidad: Calidad) -> int:
	var nuevo: int = progreso
	match calidad:
		Calidad.PERFECTO:
			nuevo += velocidad / DIVISOR_PROGRESO_PERFECTO
		Calidad.BUENO:
			nuevo += velocidad / DIVISOR_PROGRESO_BUENO
	return mini(nuevo, PROGRESO_MAXIMO)


## sub_805194C: la barra visible sube 2 por fotograma mientras sea menor que el real.
static func paso_barra_visible(visible: int, real: int) -> int:
	return visible + PASO_BARRA_VISIBLE if visible < real else visible


## sub_80501FC: el minijuego acaba cuando la barra visible llega a 1000.
static func ha_terminado(barra_visible: int) -> bool:
	return barra_visible >= PROGRESO_MAXIMO


## sub_8051A1C: RPM en centésimas para una velocidad (360000·v / 65536).
static func rpm_de_velocidad(velocidad: int) -> int:
	return 360000 * maxi(velocidad, 0) / VUELTA


## sub_8051A3C: actualiza la RPM máxima (u16) con la velocidad actual.
static func actualizar_rpm_maxima(rpm_maxima: int, velocidad: int) -> int:
	return mini(maxi(rpm_maxima, rpm_de_velocidad(velocidad)), 0xFFFF)


## sub_804FE70: tempo de MUS_CYCLING tras un pulsado (m4aMPlayTempoControl, 256 = normal).
static func tempo_musica(velocidad: int) -> int:
	if velocidad > UMBRAL_VELOCIDAD_ALTA:
		return (velocidad - 750) / 20 + TEMPO_NORMAL
	return TEMPO_NORMAL


# ============================================================================
# IA de los rivales (sub_804F8C8, sub_804F9F4, sub_804FB1C)
# ============================================================================

## Tirada de la IA: Random() / 655, de 0 a 100.
static func tirada_ia(rng: RandomNumberGenerator) -> int:
	return rng.randi_range(0, 0xFFFF) / 655


## true si la flecha está en la ventana en la que decide el `rival` (1-3). Cada tarea
## decide UNA vez por pasada: el controlador debe recordar si ya decidió y olvidarlo
## cuando esta función vuelva a dar false (gTasks[].data[0]).
## - Rival 1: el centro PERFECTO de su ranura (sub_804F16C == 2).
## - Rivales 2 y 3: ((ángulo + 0x1800) & 0xFFFF) >> 8 en (z+20, z+40), abierto.
static func en_ventana_ia(rival: int, angulo: int, num_jugadores: int) -> bool:
	var ranura: int = ranura_de_jugador(rival, num_jugadores)
	if rival < 1 or rival > 3 or ranura < 0:
		return false
	if rival == 1:
		return calidad_pulsado(angulo, ranura) == Calidad.PERFECTO
	var p: int = ((angulo + DESFASE_VENTANA_IA) & 0xFFFF) >> 8
	var z: int = inicio_zona(ranura)
	return p > z + VENTANA_IA_MIN and p < z + VENTANA_IA_MAX


## Decisión del `rival` (1-3) al entrar en su ventana, con la `velocidad` actual y una
## `tirada` de 0-100 (`tirada_ia()`). Devuelve
## {"pulsa": bool, "calidad": Calidad, "retraso": int}: si `pulsa` es false no hace
## nada esta pasada; un FALLO llega con `retraso` = 5 fotogramas (sub_804F890), los
## aciertos con 0. (No se reproduce el modo debug field_14B, todo PERFECTO.)
##
## Rival 1: vel < 500 → siempre BUENO (el C sobrescribe el resultado); < 1500 →
##   >80 PERFECTO, 21-80 BUENO, <10 FALLO; ≥ 1500 → >90 PERFECTO, 71-90 BUENO, <30 FALLO.
## Rival 2: < 500 → >66 PERFECTO, si no BUENO; ≥ 500 → >65 PERFECTO, 41-65 BUENO, <10 FALLO.
## Rival 3: < 500 → >88 PERFECTO, si no BUENO; ≥ 500 → >60 PERFECTO, 56-60 BUENO, <5 FALLO.
static func decidir_ia(rival: int, velocidad: int, tirada: int) -> Dictionary:
	var r: int = tirada
	match rival:
		1:
			if velocidad < UMBRAL_VELOCIDAD_IA:
				return _accion_ia(Calidad.BUENO)
			if velocidad < UMBRAL_VELOCIDAD_ALTA:
				if r > 80:
					return _accion_ia(Calidad.PERFECTO)
				if r >= 21:
					return _accion_ia(Calidad.BUENO)
				if r < 10:
					return _accion_ia(Calidad.FALLO)
				return _sin_accion_ia()
			if r > 90:
				return _accion_ia(Calidad.PERFECTO)
			if r >= 71:
				return _accion_ia(Calidad.BUENO)
			if r < 30:
				return _accion_ia(Calidad.FALLO)
			return _sin_accion_ia()
		2:
			if velocidad < UMBRAL_VELOCIDAD_IA:
				return _accion_ia(Calidad.PERFECTO if r > 66 else Calidad.BUENO)
			if r > 65:
				return _accion_ia(Calidad.PERFECTO)
			if r >= 41:
				return _accion_ia(Calidad.BUENO)
			if r < 10:
				return _accion_ia(Calidad.FALLO)
			return _sin_accion_ia()
		3:
			if velocidad < UMBRAL_VELOCIDAD_IA:
				return _accion_ia(Calidad.PERFECTO if r > 88 else Calidad.BUENO)
			if r > 60:
				return _accion_ia(Calidad.PERFECTO)
			if r >= 56:
				return _accion_ia(Calidad.BUENO)
			if r < 5:
				return _accion_ia(Calidad.FALLO)
			return _sin_accion_ia()
	return _sin_accion_ia()


static func _accion_ia(calidad: Calidad) -> Dictionary:
	return {"pulsa": true, "calidad": calidad, "retraso": RETRASO_FALLO_IA if calidad == Calidad.FALLO else 0}


static func _sin_accion_ia() -> Dictionary:
	return {"pulsa": false, "calidad": Calidad.FALLO, "retraso": 0}


# ============================================================================
# Bayas de los rivales (sub_804F1BC)
# ============================================================================

## Bayas.numero (1-5, siempre básicas y distintas) que meten los rivales cuando el
## jugador mete `baya_jugador` (diccionario con `numero` y sabores), para
## `num_jugadores` jugadores. r = numero − 1; si r ≥ 5, r = r % 5 + 5. Con la ENIGMA,
## r = índice del primer sabor mínimo + 5. Ej.: CHERI → ASPEAR, RAWST, PECHA.
static func numeros_bayas_rivales(baya_jugador: Dictionary, num_jugadores: int) -> Array[int]:
	var numero: int = int(baya_jugador.get("numero", 1))
	var r: int
	if numero == NUMERO_ENIGMA:
		var sabores: Array[int] = sabores_de_baya(baya_jugador)
		r = 0
		for i in Pokecubo.NUM_SABORES:
			if sabores[r] > sabores[i]:
				r = i
		r += 5
	else:
		r = maxi(numero - 1, 0)
		if r >= 5:
			r = r % 5 + 5
	var resultado: Array[int] = []
	for k in clampi(num_jugadores - 1, 0, 3):
		resultado.append(int(BAYAS_RIVALES[r][k]) + 1)
	return resultado


## Versión con la BD: bayas completas (filas de `Bayas`) de los rivales a partir del
## Objetos.id de la baya del jugador. [] si no es una baya de la licuadora.
static func bayas_rivales_desde_bd(objeto_id_jugador: int, num_jugadores: int) -> Array[Dictionary]:
	var resultado: Array[Dictionary] = []
	var baya: Dictionary = DatabaseManager.obtener_datos_baya(objeto_id_jugador)
	if baya.is_empty():
		return resultado
	for numero in numeros_bayas_rivales(baya, num_jugadores):
		resultado.append(DatabaseManager.obtener_datos_baya_por_numero(numero))
	return resultado


## [picante, seco, dulce, amargo, ácido] de un diccionario de baya.
static func sabores_de_baya(baya: Dictionary) -> Array[int]:
	var sabores: Array[int] = []
	for clave in CLAVES_SABOR:
		sabores.append(int(baya.get(clave, 0)))
	return sabores


# ============================================================================
# Cálculo del POKéCUBO (Blender_CalculatePokeblock + Blender_GetPokeblockColor)
# ============================================================================

## mult = maxRPM / 333 + 100 (en %); 100,00 RPM (10000) → 130.
static func multiplicador_rpm(rpm_maxima: int) -> int:
	return clampi(rpm_maxima, 0, 0xFFFF) / 333 + 100


## Blender_CalculatePokeblock (berry_blender.c:1998-2094). `bayas` = una por jugador
## (el número de jugadores es bayas.size()), `rpm_maxima` en centésimas.
## Si sale NEGRO, sus 3 sabores a 2 se eligen con `MASCARAS_NEGRO[Random() % 10]`:
## se usa `indice_mascara_negro` si es 0-9, si no `rng` (o uno nuevo aleatorio).
## 1. S[j] = Σ sabor_j y S5 = Σ suavidad.
## 2. Resta circular: S0−S1, S1−S2, S2−S3, S3−S4, S4−S0 (original).
## 3. neg = sabores negativos, que pasan a 0; a los positivos se les resta neg (mín. 0).
## 4. S[i] = redondeo(S[i]·mult/100) (resto de la décima > 4 → +1).
## 5. color (color_por_sabores); suavidad = S5/N − N (mín. 0, sin RPM).
## 6. NEGRO → máscara; todo se recorta a 255.
static func calcular_pokecubo(bayas: Array, rpm_maxima: int, rng: RandomNumberGenerator = null,
		indice_mascara_negro: int = -1) -> Pokecubo:
	var n: int = bayas.size()
	if n <= 0:
		return Pokecubo.new()
	var s: Array[int] = [0, 0, 0, 0, 0]
	var suave: int = 0
	for baya in bayas:
		var sabores_baya: Array[int] = sabores_de_baya(baya)
		for j in Pokecubo.NUM_SABORES:
			s[j] += sabores_baya[j]
		suave += int(baya.get("suavidad", 0))

	var s0: int = s[0]
	s[0] -= s[1]
	s[1] -= s[2]
	s[2] -= s[3]
	s[3] -= s[4]
	s[4] -= s0

	var negativos: int = 0
	for i in Pokecubo.NUM_SABORES:
		if s[i] < 0:
			s[i] = 0
			negativos += 1
	for i in Pokecubo.NUM_SABORES:
		if s[i] > 0:
			s[i] = maxi(s[i] - negativos, 0)

	var mult: int = multiplicador_rpm(rpm_maxima)
	for i in Pokecubo.NUM_SABORES:
		var v: int = s[i] * mult / 10
		var resto: int = v % 10
		v /= 10
		if resto > 4:
			v += 1
		s[i] = v

	var color: int = color_por_sabores(s, bayas, negativos)
	var suavidad: int = maxi(suave / n - n, 0)
	if color == Pokecubo.ColorPokecubo.NEGRO:
		var indice: int = indice_mascara_negro
		if indice < 0 or indice >= MASCARAS_NEGRO.size():
			var generador: RandomNumberGenerator = rng
			if generador == null:
				generador = RandomNumberGenerator.new()
				generador.randomize()
			indice = generador.randi_range(0, 0xFFFF) % MASCARAS_NEGRO.size()
		var mascara: int = MASCARAS_NEGRO[indice]
		for i in Pokecubo.NUM_SABORES:
			s[i] = VALOR_SABOR_NEGRO if (mascara >> i) & 1 else 0
	return Pokecubo.crear(color, s, mini(suavidad, Pokecubo.VALOR_MAXIMO))


## Blender_GetPokeblockColor (berry_blender.c:1884-1976), en este orden:
## 1. todos los sabores a 0 o más de 3 negativos → NEGRO;
## 2. dos jugadores con la misma baya → NEGRO (la ENIGMA solo si coinciden sabores y
##    suavidad, sub_80502A4);
## 3. más de 3 sabores > 0 → BLANCO; 3 → GRIS;
## 4. algún sabor > 50 → DORADO;
## 5. 1 sabor → ROJO/AZUL/ROSA/VERDE/AMARILLO;
## 6. 2 sabores → el del más fuerte (empate: el de menor índice) en
##    MORADO/ÍNDIGO/MARRÓN/AZUL CLARO/OLIVA.
## `sabores` ya multiplicados por la RPM; `num_negativos` = sabores negativos antes
## de recortarlos.
static func color_por_sabores(sabores: Array[int], bayas: Array, num_negativos: int) -> int:
	var ceros: int = 0
	for i in Pokecubo.NUM_SABORES:
		if sabores[i] == 0:
			ceros += 1
	if ceros == Pokecubo.NUM_SABORES or num_negativos > 3:
		return Pokecubo.ColorPokecubo.NEGRO
	if hay_bayas_repetidas(bayas):
		return Pokecubo.ColorPokecubo.NEGRO
	var presentes: Array[int] = []
	for i in Pokecubo.NUM_SABORES:
		if sabores[i] > 0:
			presentes.append(i)
	if presentes.size() > 3:
		return Pokecubo.ColorPokecubo.BLANCO
	if presentes.size() == 3:
		return Pokecubo.ColorPokecubo.GRIS
	for i in Pokecubo.NUM_SABORES:
		if sabores[i] > UMBRAL_DORADO:
			return Pokecubo.ColorPokecubo.DORADO
	if presentes.size() == 1:
		return COLOR_UN_SABOR[presentes[0]]
	if presentes.size() == 2:
		var dominante: int = presentes[0] if sabores[presentes[0]] >= sabores[presentes[1]] else presentes[1]
		return COLOR_DOS_SABORES[dominante]
	return Pokecubo.ColorPokecubo.VACIO


## true si dos jugadores metieron la misma baya (mismo `numero`, o `objeto_id` si no
## hay `numero`). Para la ENIGMA, además deben coincidir sabores y suavidad.
static func hay_bayas_repetidas(bayas: Array) -> bool:
	for i in bayas.size():
		for j in range(i + 1, bayas.size()):
			var a: Dictionary = bayas[i]
			var b: Dictionary = bayas[j]
			var id_a: int = _id_baya(a, i)
			if id_a != _id_baya(b, j):
				continue
			if int(a.get("numero", 0)) != NUMERO_ENIGMA:
				return true
			if sabores_de_baya(a) == sabores_de_baya(b) \
					and int(a.get("suavidad", 0)) == int(b.get("suavidad", 0)):
				return true
	return false


static func _id_baya(baya: Dictionary, indice: int) -> int:
	if baya.has("numero"):
		return int(baya["numero"])
	if baya.has("objeto_id"):
		return 1000 + int(baya["objeto_id"])
	return -1 - indice


# ============================================================================
# Puntuación y ranking (Blender_SortScores)
# ============================================================================

## 1e6·PERFECTOS + 1e3·BUENOS + (1000 − FALLOS).
static func puntuacion(perfectos: int, buenos: int, fallos: int) -> int:
	return 1000000 * perfectos + 1000 * buenos + (1000 - fallos)


## Suma un fallo al contador sin pasar de 999.
static func sumar_fallo(fallos: int) -> int:
	return fallos + 1 if fallos < FALLOS_MAXIMOS else fallos


## Blender_SortBasedOnPoints: índices de jugador ordenados de mayor a menor
## puntuación con el mismo algoritmo de intercambios del C (así los empates quedan
## igual que en Rubí).
static func ordenar_ranking(puntuaciones: Array) -> Array[int]:
	var puestos: Array[int] = []
	for i in puntuaciones.size():
		puestos.append(i)
	for i in puestos.size():
		for j in puestos.size():
			if int(puntuaciones[puestos[i]]) > int(puntuaciones[puestos[j]]):
				var tmp: int = puestos[i]
				puestos[i] = puestos[j]
				puestos[j] = tmp
	return puestos


## Clave de traducción del nombre del `rival` (1-3); "" fuera de rango.
static func clave_nombre_rival(rival: int) -> String:
	if rival < 1 or rival > CLAVES_NOMBRES_RIVALES.size():
		return ""
	return CLAVES_NOMBRES_RIVALES[rival - 1]


static func _fila_ranuras(num_jugadores: int) -> Array:
	var n: int = clampi(num_jugadores, NUM_JUGADORES_MIN, NUM_JUGADORES_MAX)
	return JUGADOR_POR_RANURA[n - NUM_JUGADORES_MIN]
