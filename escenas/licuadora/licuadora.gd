## Pantalla de la Licuadora de Bayas (berry_blender.c). Las secuencias fijas
## (entrada del disco, temblor, fundidos, cuenta atrás, bayas, marcas) son
## animaciones del AnimationPlayer de cada escena; este script solo pone los
## datos de juego que cambian a cada fotograma (ángulo, RPM, progreso, nombres)
## y crea los elementos efímeros.
class_name Licuadora
extends Control

## Reenvía los sonidos pedidos por las animaciones (claves de `Singleton.se`).
signal sonido_solicitado(clave: String)
## START terminó de caer: empieza el minijuego (field_0++ en sub_80518CC).
signal cuenta_atras_terminada

enum Calidad { FALLO, BUENO, PERFECTO }

const MARCA := preload("res://escenas/licuadora/marca_resultado.tscn")
const PARTICULA := preload("res://escenas/licuadora/particula_licuadora.tscn")
const BAYA := preload("res://escenas/licuadora/baya_lanzada.tscn")
const TEXTO_NEGRO := preload("res://UI/texto_normal_negro.tres")
const TEXTO_ROJO := preload("res://UI/texto_normal_rojo.tres")

const POS_FLECHAS: Array[Vector2] = [Vector2(72, 32), Vector2(168, 32), Vector2(72, 128), Vector2(168, 128)]
## gUnknown_082162CC: sentido hacia el que se desplaza la marca respecto a su flecha.
const SENTIDO_MARCA: Array[Vector2] = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
const CENTRO := Vector2(120, 80)
const VUELTA := 65536.0

@onready var _anim: AnimationPlayer = %AnimationPlayer
@onready var _disco: Sprite2D = %Disco
@onready var _progreso: TextureProgressBar = %Progreso
@onready var _digitos: Node2D = %Digitos
@onready var _nombres: Node2D = %Nombres
@onready var _flechas: Node2D = %Flechas
@onready var _efectos: Node2D = %Efectos
@onready var _cuenta: ElementoLicuadora = %CuentaAtras

var _azar := RandomNumberGenerator.new()


func _ready() -> void:
	_cuenta.sonido_solicitado.connect(sonido_solicitado.emit)
	_cuenta.terminado.connect(cuenta_atras_terminada.emit)
	for flecha in _flechas.get_children():
		flecha.get_node("AnimationPlayer").play(&"espera")


## Fundido desde negro; la entrada del disco (zoom + giro) va en paralelo.
func reproducir_entrada() -> void:
	await reproducir_fundido_entrada()
	await reproducir_giro_entrada()
	await reproducir_temblor_inicio()


## Fundido desde negro (BeginNormalPaletteFade 16 → 0).
func reproducir_fundido_entrada() -> void:
	_anim.play(&"fundido_entrada")
	await _anim.animation_finished


## Zoom y giro del disco (case 14 de sub_804F378: REG_DISPCNT |= 0x400 enciende BG2).
func reproducir_giro_entrada() -> void:
	mostrar_disco(true)
	_anim.play(&"entrada")
	await _anim.animation_finished


## Temblor al encajar el disco (sub_8051B8C).
func reproducir_temblor_inicio() -> void:
	_anim.play(&"temblor_inicio")
	await _anim.animation_finished


## Disco (BG2) visible o no: al elegir baya (sub_804E56C, REG_DISPCNT = 0x1341) solo
## se ven el marco y las flechas.
func mostrar_disco(visible_disco: bool) -> void:
	(get_node("%Entrada") as Node2D).visible = visible_disco


## Pantalla en negro sin animación (la escena entra tras un fundido del mapa).
func poner_en_negro() -> void:
	_anim.stop()
	(get_node("Negro") as ColorRect).color.a = 1.0


## Desplazamiento del temblor (field_144, field_146 de sub_8051AC8): el GBA desplaza
## el fondo BG1, el disco y los sprites `-desplazamiento` píxeles.
func establecer_temblor(desplazamiento: Vector2) -> void:
	(get_node("Mundo") as Node2D).position = -desplazamiento
	_flechas.position = -desplazamiento
	_efectos.position = -desplazamiento


func iniciar_cuenta_atras() -> void:
	_cuenta.get_node("AnimationPlayer").play(&"cuenta_atras")


func reproducir_fundido_salida() -> void:
	_anim.play(&"fundido_salida")
	await _anim.animation_finished


## Ángulo del disco en las unidades del decomp (u16, 0x10000 = una vuelta). El
## GBA gira en sentido antihorario con ángulos crecientes; Godot, en horario.
func establecer_angulo(angulo: int) -> void:
	_disco.rotation = -TAU * float(angulo) / VUELTA


## Velocidad `field_56` en las unidades del decomp; escribe las cifras de RPM
## como sub_8051A3C (360000 * v / 0x10000, cinco dígitos con el punto fijo).
func establecer_velocidad(velocidad: int) -> void:
	var valor := int(360000.0 * velocidad / VUELTA)
	var cifras: Array[Node] = [
		_digitos.get_node("Cifra0"), _digitos.get_node("Cifra1"), _digitos.get_node("Cifra2"),
		_digitos.get_node("Cifra3"), _digitos.get_node("Cifra4"),
	]
	for cifra in cifras:
		(cifra as Sprite2D).frame = valor % 10
		@warning_ignore("integer_division")
		valor = valor / 10


## Progreso 0-1000 de la barra superior (`field_140`).
func establecer_progreso(valor: int) -> void:
	_progreso.value = valor


func establecer_jugador(ranura: int, nombre: String, local: bool) -> void:
	var etiqueta := _nombres.get_node("Nombre%d" % ranura) as Label
	etiqueta.text = nombre
	etiqueta.label_settings = TEXTO_ROJO if local else TEXTO_NEGRO
	_flechas.get_node("Flecha%d/AnimationPlayer" % ranura).play(&"reposo")


func pulsar_flecha(ranura: int) -> void:
	_flechas.get_node("Flecha%d/AnimationPlayer" % ranura).play(&"pulsar")


## Marca de resultado junto a la flecha y chispas (sub_804FC48 + sub_805156C).
func mostrar_resultado(ranura: int, calidad: Calidad, angulo: int) -> void:
	var marca := MARCA.instantiate() as ElementoLicuadora
	marca.position = POS_FLECHAS[ranura] - 10.0 * SENTIDO_MARCA[ranura]
	_agregar_efecto(marca)
	marca.get_node("AnimationPlayer").play([&"fallo", &"bueno", &"perfecto"][calidad])
	_lanzar_chispas(angulo)


## Baya que entra rebotando desde el lado de su jugador (sub_804E7C0).
func lanzar_baya(ranura: int, textura: Texture2D) -> void:
	var baya := BAYA.instantiate() as ElementoLicuadora
	_agregar_efecto(baya)
	baya.get_node("Baya").texture = textura
	baya.get_node("AnimationPlayer").play("lanzar_%d" % ranura)


func _lanzar_chispas(angulo: int) -> void:
	for i in _azar.randi_range(1, 2):
		var fase := (angulo + _azar.randi_range(0, 19)) & 0xFF
		var chispa := PARTICULA.instantiate() as ParticulaLicuadora
		# gSineTable[fase] / 4: 256 pasos por vuelta y amplitud 256, o sea radio 64.
		chispa.position = CENTRO + Vector2.from_angle(TAU * fase / 256.0) * 64.0
		chispa.velocidad = Vector2(_azar.randi_range(-15, 16), _azar.randi_range(-15, 16)) / 8.0
		_agregar_efecto(chispa)
		chispa.get_node("AnimationPlayer").play(&"destello")


func _agregar_efecto(nodo: ElementoLicuadora) -> void:
	nodo.sonido_solicitado.connect(sonido_solicitado.emit)
	_efectos.add_child(nodo)
