class_name ResultadosConcurso
extends Node2D
## Pantalla de resultados de un concurso (sub_80C2358 y tareas encadenadas,
## src/contest_link_util.c; anexo de IA/flujo/resultados §4). Muestra las dos rondas
## con barras y marcas, revela los puestos del 4.º al 1.º y presenta al ganador.
##
## Uso: `await resultados.mostrar(motor)` con el motor ya terminado (calcular_final).

signal terminado

const ANCHO_BARRA: int = 88
const MAX_SEGMENTOS: int = 10
## sub_80C2F28: el fondo se desplaza 2 px a la derecha y 1 abajo por frame.
const DESPLAZAMIENTO_FONDO: Vector2 = Vector2(2, 1)
const RUTA_GRITO: String = "res://Audio/SE/Cries/%03dCry.ogg"
const TEXTURA_CONFETI: Texture2D = preload("res://graficos/concurso/confeti.png")
## sub_80C3D04: hasta 40 trozos de confeti, uno cada 5 frames.
const MAX_CONFETI: int = 40
const FOTOGRAMAS_CONFETI: int = 17

@export var escala_tiempo: float = 1.0
@export var con_musica: bool = true
## Si es true no espera A al final (demostraciones y tests).
@export var avance_automatico: bool = false

var motor: MotorConcurso
## Cálculo de sub_80C3F00 por concursante (ver calcular_barras).
var barras: Array[Dictionary] = []
var registro_textos: PackedStringArray = []

var _fondo_desplazamiento: Vector2 = Vector2.ZERO

@onready var _fondo: Sprite2D = $Fondo
@onready var _filas: Array[FilaResultadoConcurso] = [$Filas/Fila0, $Filas/Fila1, $Filas/Fila2, $Filas/Fila3]
@onready var _rotulo: Label = $Rotulo
@onready var _cartel: Node2D = $Cartel
@onready var _texto_cartel: Label = $Cartel/Texto
@onready var _ventana: Control = $Ventana
@onready var _banda: Sprite2D = $Ventana/Banda
@onready var _ganador: Sprite2D = $Ventana/Ganador
@onready var _confeti: Node2D = $Confeti


func _ready() -> void:
	_cartel.visible = false
	_ventana.visible = false


func _process(delta: float) -> void:
	_fondo_desplazamiento += DESPLAZAMIENTO_FONDO * delta * 60.0
	_fondo_desplazamiento.x = fmod(_fondo_desplazamiento.x, 256.0)
	_fondo_desplazamiento.y = fmod(_fondo_desplazamiento.y, 256.0)
	_fondo.region_rect.position = -_fondo_desplazamiento.floor()


## sub_80C3F00: longitud de las barras (88 px = barra llena), marcas de cada ronda y
## ajuste para que solo el ganador llene la barra. Devuelve un diccionario por
## concursante: r1_px, r2_px (con signo), r1_segmentos, r2_segmentos (con signo).
static func calcular_barras(estado: EstadoConcurso) -> Array[Dictionary]:
	var totales: Array[int] = estado.puntos_finales
	var referencia: int = totales.max()
	if referencia < 0:
		referencia = totales.min()
	var divisor: int = maxi(absi(referencia), 1)
	var resultado: Array[Dictionary] = []
	for i in EstadoConcurso.NUM_CONCURSANTES:
		var r1: int = estado.puntos_ronda1[i]
		var r2: int = estado.puntos_ronda2[i]
		var pct1: int = _redondear_decimo(1000 * r1 / divisor)
		var pct2: int = _redondear_decimo(1000 * absi(r2) / divisor)
		var px1: int = _redondear_256(22528 * pct1 / 100)
		var px2: int = _redondear_256(pct2 * 22528 / 100)
		if estado.puestos_finales[i] != 0:
			var con_signo: int = -px2 if r2 < 0 else px2
			if px1 + con_signo == ANCHO_BARRA:
				if con_signo > 0:
					px2 -= 1
				elif px1 > 0:
					px1 -= 1
		resultado.append({
			"r1_px": px1,
			"r2_px": -px2 if r2 < 0 else px2,
			"r1_segmentos": segmentos(r1, 63),
			"r2_segmentos": -segmentos(absi(r2), 80) if r2 < 0 else segmentos(r2, 80),
		})
	return resultado


## r4 / 10 tras sumar 10 si la última cifra es >= 5 (porcentaje redondeado).
static func _redondear_decimo(valor: int) -> int:
	if valor % 10 >= 5:
		valor += 10
	return valor / 10


static func _redondear_256(valor: int) -> int:
	if valor % 256 >= 128:
		valor += 256
	return valor / 256


## sub_80C3990 / sub_80C39E4: ceil(puntos / divisor), al menos 1 si hay puntos, máx. 10.
static func segmentos(puntos: int, divisor: int) -> int:
	if puntos <= 0:
		return 0
	return clampi(ceili(float(puntos) / divisor), 1, MAX_SEGMENTOS)


# === Secuencia ===

func mostrar(motor_concurso: MotorConcurso) -> void:
	motor = motor_concurso
	var estado: EstadoConcurso = motor.estado
	barras = calcular_barras(estado)
	_rotulo.text = _rotulo_concurso(estado)
	for i in EstadoConcurso.NUM_CONCURSANTES:
		var fila: FilaResultadoConcurso = _filas[i]
		fila.escala_tiempo = escala_tiempo
		var c: ConcursanteConcurso = motor.concursante(i)
		fila.configurar(c, DatabaseManager.obtener_numero_nacional(c.especie))
		fila.segmentos_ronda1 = int(barras[i]["r1_segmentos"])
		fila.segmentos_ronda2 = absi(int(barras[i]["r2_segmentos"]))
	if con_musica:
		Singleton.reproducir_tema("CONCURSO_RESULTADOS")
	await esperar(30.0)
	# 1: «¡Anunciamos los resultados!» y «¡Resultados de la primera votación!».
	await mostrar_cartel(_t("CONCURSO_RESULTADOS_ANUNCIO", {}))
	await esperar(21.0)
	await mostrar_cartel(_t("CONCURSO_RESULTADOS_RONDA1", {}))
	await _animar_ronda(1)
	await esperar(21.0)
	await mostrar_cartel(_t("CONCURSO_RESULTADOS_RONDA2", {}))
	await _animar_ronda(2)
	# 5: puestos del 4.º al 1.º cada 40 frames.
	await esperar(31.0)
	for puesto in range(3, -1, -1):
		var i: int = estado.puestos_finales.find(puesto)
		if i >= 0:
			_filas[i].mostrar_puesto(puesto)
			TiempoConcurso.sonar(self, "SE_CONTEST_PLACE")
		if puesto > 0:
			await esperar(40.0)
	await esperar(31.0)
	var ganador: int = estado.ganador()
	_filas[ganador].resaltar_ganador()
	# 6-7: «¡Ha ganado …!» y presentación del ganador.
	await esperar(21.0)
	var c_ganador: ConcursanteConcurso = motor.concursante(ganador)
	await mostrar_cartel(_t("CONCURSO_RESULTADOS_GANO", {"mon": c_ganador.mote, "entrenador": c_ganador.entrenador}), false)
	await _presentar_ganador(c_ganador)
	# 8: espera A y marca a los 4 como vistos en la POKéDEX.
	if not (avance_automatico or escala_tiempo <= 0.0):
		await _esperar_a()
	for c in estado.concursantes:
		if SistemaGuardado != null and not c.especie.is_empty():
			SistemaGuardado.registrar_pokemon_visto(c.especie)
	terminado.emit()


## sub_80C26E4 / sub_80C27EC: un paso por segmento; en cada paso, los concursantes que
## aún tienen segmentos encienden una marca y su barra crece hasta la fracción.
func _animar_ronda(ronda: int) -> void:
	var clave_seg: String = "r1_segmentos" if ronda == 1 else "r2_segmentos"
	var pasos: int = 0
	for b in barras:
		pasos = maxi(pasos, absi(int(b[clave_seg])))
	for paso in pasos:
		var animaciones: Array[FilaResultadoConcurso] = []
		for i in EstadoConcurso.NUM_CONCURSANTES:
			var seg: int = int(barras[i][clave_seg])
			if paso >= absi(seg):
				continue
			var fila: FilaResultadoConcurso = _filas[i]
			var destino: int
			if ronda == 1:
				fila.encender_marca_ronda1()
				destino = _fraccion(int(barras[i]["r1_px"]), seg, paso)
			else:
				fila.encender_marca_ronda2(seg < 0)
				var r2: int = int(barras[i]["r2_px"])
				var avance: int = _fraccion(absi(r2), absi(seg), paso)
				destino = int(barras[i]["r1_px"]) + (avance if r2 >= 0 else -avance)
			animaciones.append(fila)
			fila.animar_barra(destino)
		if not animaciones.is_empty():
			TiempoConcurso.sonar(self, "SE_PIN")
		while animaciones.any(func(f: FilaResultadoConcurso) -> bool: return f.animando_barra):
			await get_tree().process_frame
		await esperar(1.0)


## ((px << 16) / segmentos) × (paso + 1), redondeado al entero más próximo.
static func _fraccion(px: int, seg: int, paso: int) -> int:
	if seg == 0:
		return px
	var valor: int = ((px << 16) / seg) * (paso + 1)
	if valor % 0x10000 >= 0x8000:
		valor += 0x10000
	return valor >> 16


## sub_80C2A8C: la ventana se abre, el Pokémon entra desde x = 272 hasta 120 (grito al
## frame 10), cae confeti, a los 121 frames sale por la izquierda y la ventana se cierra.
func _presentar_ganador(c: ConcursanteConcurso) -> void:
	_ganador.texture = PokemonSpriteManager.cargar_sprite_frente(c.especie, c.shiny, c.personalidad)
	_ganador.position.x = 272.0
	_ventana.visible = true
	await _abrir_ventana(true)
	var numero: int = DatabaseManager.obtener_numero_nacional(c.especie)
	var frames: int = 0
	var confeti: int = 0
	while _ganador.position.x > 120.0:
		_ganador.position.x = maxf(_ganador.position.x - 4.0, 120.0)
		frames += 1
		if frames == 10:
			_sonar_grito(numero)
		if frames % 5 == 0 and confeti < MAX_CONFETI:
			_lanzar_confeti()
			confeti += 1
		await esperar(1.0)
	for k in 121:
		if k % 5 == 0 and confeti < MAX_CONFETI:
			_lanzar_confeti()
			confeti += 1
		await esperar(1.0)
	while _ganador.position.x > -32.0:
		_ganador.position.x -= 6.0
		await esperar(1.0)
	await _abrir_ventana(false)
	_ventana.visible = false


## WIN0 se abre (o cierra) verticalmente 2 px por frame hasta 32 px de alto a cada lado.
func _abrir_ventana(abrir: bool) -> void:
	var centro: float = 80.0
	var alto: float = 0.0 if abrir else 32.0
	while (abrir and alto < 32.0) or (not abrir and alto > 0.0):
		alto += 2.0 if abrir else -2.0
		_ventana.position.y = centro - alto
		_ventana.size.y = alto * 2.0
		(_ventana.get_node("Banda") as Sprite2D).position.y = -(centro - alto)
		_ganador.position.y = 80.0 - _ventana.position.y
		await esperar(1.0)


func _lanzar_confeti() -> void:
	var trozo := Sprite2D.new()
	trozo.texture = TEXTURA_CONFETI
	trozo.vframes = FOTOGRAMAS_CONFETI
	trozo.frame = randi() % FOTOGRAMAS_CONFETI
	trozo.position = Vector2(randf_range(8.0, 232.0), -8.0)
	_confeti.add_child(trozo)
	# sub_80C3DF0: cae con vaivén senoidal.
	var tween := trozo.create_tween()
	var duracion: float = maxf(2.0 * escala_tiempo, 0.05)
	tween.tween_method(func(t: float) -> void:
		trozo.position = Vector2(trozo.position.x + sin(t * TAU * 2.0) * 0.6, -8.0 + t * 176.0), 0.0, 1.0, duracion)
	tween.tween_callback(trozo.queue_free)


func _sonar_grito(numero: int) -> void:
	var ruta: String = RUTA_GRITO % numero
	if numero <= 0 or not ResourceLoader.exists(ruta):
		return
	var reproductor := AudioStreamPlayer.new()
	reproductor.stream = load(ruta)
	add_child(reproductor)
	reproductor.finished.connect(reproductor.queue_free)
	reproductor.play()


## Cartel deslizante (sub_80C3698 / sub_80C3764): entra por la derecha y, si `retirar`,
## sale por la izquierda tras unos frames.
func mostrar_cartel(texto: String, retirar: bool = true) -> void:
	registro_textos.append(texto)
	_texto_cartel.text = texto
	_cartel.visible = true
	_cartel.position.x = 240.0
	while _cartel.position.x > 0.0:
		_cartel.position.x = maxf(_cartel.position.x - 10.0, 0.0)
		await esperar(1.0)
	await esperar(60.0)
	if not retirar:
		return
	while _cartel.position.x > -240.0:
		_cartel.position.x -= 10.0
		await esperar(1.0)
	_cartel.visible = false


func _rotulo_concurso(estado: EstadoConcurso) -> String:
	return "%s · %s" % [tr("CONCURSO_NIVEL_%d" % estado.nivel), tr("CONCURSO_CATEGORIA_%d" % estado.categoria)]


func _esperar_a() -> void:
	while not (Input.is_action_just_pressed("btn_accion") or Input.is_action_just_pressed("btn_cancelar")):
		await get_tree().process_frame


func _t(clave: String, valores: Dictionary) -> String:
	var texto: String = tr(clave)
	for k in valores:
		texto = texto.replace("{%s}" % k, str(valores[k]))
	return texto


func esperar(frames: float) -> void:
	await TiempoConcurso.esperar(self, frames, escala_tiempo)
