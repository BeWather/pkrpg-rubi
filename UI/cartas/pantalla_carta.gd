extends Node2D
class_name PantallaCarta

## Pantalla de lectura de CARTAS (pokeruby src/mail.c, HandleReadMail).
##
## Fondo del tipo de carta (12 diseños, borde según el sexo del jugador), hasta
## 5 líneas de palabras desde el tile (3, 4) saltando las vacías, la firma
## «De NOMBRE» y, en CARTA IMAGEN y CARTA SUEÑO, el icono del Pokémon que la
## lleva. A o B cierran la carta (sub_80F8F78).
##
## Se usa desde la mochila (USAR, ItemUseOutOfBattle_Mail: carta vacía) y desde
## el equipo (LEER, PokemonMenu_ReadMail). Se crea con la pantalla ya oscurecida
## y emite `carta_cerrada` con la pantalla oscurecida otra vez.

signal carta_cerrada

## Tile (var3_4, var3_0) de la primera línea y alto de línea (2 tiles).
const ORIGEN_TEXTO: Vector2 = Vector2(24, 32)
const ALTO_LINEA: int = 16
## color10 / color12 de gMailGraphicsTable (RGB555 0x294A/0x6739 y 0x7FFF/0x4631).
const COLOR_OSCURO: Color = Color8(82, 82, 82)
const SOMBRA_OSCURO: Color = Color8(206, 206, 206)
const COLOR_CLARO: Color = Color8(255, 255, 255)
const SOMBRA_CLARO: Color = Color8(140, 140, 140)
## Animación 0 de los iconos (sMonIconAnim_83C2C58): 6 fotogramas por imagen.
const FPS_ICONO: float = 10.0

@onready var spr_fondo: Sprite2D = $Fondo
@onready var nd_lineas: Node2D = $Lineas
@onready var lb_firma: Label = $Firma
@onready var spr_icono: AnimatedSprite2D = $Icono

var carta: DatosCarta = null
var _esperando_cierre: bool = false


func _ready() -> void:
	# Ejecutada sola (F6): CARTA IMAGEN de prueba con palabras.
	if get_tree().current_scene == self:
		scale = Vector2(3, 3)
		var prueba := DatosCarta.new()
		prueba.tipo = DatosCarta.TIPO_IMAGEN
		prueba.palabras = ["¡HOLA!", "AMIGO", "", "", "CARTA", "", "", "", "ADIÓS"]
		prueba.autor = "ROCÍO"
		prueba.especie = 25
		abrir(prueba)


## Muestra `datos` y aclara la pantalla (sub_80F8A28). Se llama oscurecida.
func abrir(datos: DatosCarta) -> void:
	pintar(datos)
	visible = true
	await Singleton.transicion("aclarar")
	_esperando_cierre = true


## Dibuja la carta sin transiciones (también lo usan los tests).
func pintar(datos: DatosCarta) -> void:
	carta = datos
	spr_fondo.texture = load(carta.ruta_fondo(_sexo_jugador())) as Texture2D
	var ajustes: LabelSettings = (lb_firma.label_settings as LabelSettings).duplicate() as LabelSettings
	ajustes.font_color = COLOR_CLARO if carta.texto_claro() else COLOR_OSCURO
	ajustes.shadow_color = SOMBRA_CLARO if carta.texto_claro() else SOMBRA_OSCURO
	# sub_80F8E80: solo avanzan las líneas con texto.
	var textos: Array[String] = []
	if carta.con_texto:
		textos = carta.lineas()
	var fila: int = 0
	for i in nd_lineas.get_child_count():
		var linea: Label = nd_lineas.get_child(i) as Label
		linea.label_settings = ajustes
		var texto: String = textos[i] if i < textos.size() else ""
		linea.visible = not texto.is_empty()
		linea.text = texto
		if linea.visible:
			linea.position = ORIGEN_TEXTO + Vector2(0, fila * ALTO_LINEA)
			fila += 1
	lb_firma.label_settings = ajustes
	lb_firma.visible = carta.con_texto
	lb_firma.text = carta.firma(tr("CARTA_FIRMA"))
	lb_firma.position = carta.posicion_firma()
	_pintar_icono()


func _pintar_icono() -> void:
	var posicion: Vector2 = carta.posicion_icono()
	var ruta: String = "res://graficos/Icons/icon%03d.png" % carta.especie
	spr_icono.visible = posicion.x >= 0 and ResourceLoader.exists(ruta)
	if not spr_icono.visible:
		spr_icono.stop()
		return
	var textura: Texture2D = load(ruta) as Texture2D
	var fotogramas := SpriteFrames.new()
	fotogramas.set_animation_speed(&"default", FPS_ICONO)
	for x in [0, 32]:
		var region := AtlasTexture.new()
		region.atlas = textura
		region.region = Rect2(x, 0, 32, 32)
		fotogramas.add_frame(&"default", region)
	spr_icono.sprite_frames = fotogramas
	spr_icono.position = posicion
	spr_icono.play(&"default")


func _sexo_jugador() -> String:
	if SistemaGuardado == null or SistemaGuardado.datos_vivos == null:
		return "M"
	return str(SistemaGuardado.datos_vivos.jugador.get("sexo", "M"))


func _input(event: InputEvent) -> void:
	if not _esperando_cierre or not visible:
		return
	if event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_cancelar"):
		get_viewport().set_input_as_handled()
		cerrar()


## sub_80F8F78 → sub_80F8FB4: fundido a negro y vuelta a quien abrió la carta.
func cerrar() -> void:
	_esperando_cierre = false
	await Singleton.transicion("oscurecer")
	visible = false
	carta_cerrada.emit()
