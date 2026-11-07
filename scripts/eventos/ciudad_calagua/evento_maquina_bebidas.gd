## evento_maquina_bebidas.gd
## MÁQUINA EXPENDEDORA de la AZOTEA del CENTRO COMERCIAL de CIUDAD CALAGUA
## (pokeruby `LilycoveCity_DepartmentStoreRooftop`, bg_event (9,1) y (10,1)).
##
## Guion de Rubí (`..._EventScript_VendingMachine`): lockall; el mensaje con la
## pregunta; la caja de dinero; un `multichoice` con las tres bebidas; se
## comprueba el dinero (`checkmoney`) y el sitio (`checkitemspace`), se cobra
## (`removemoney`), suena SE_VEND, cae la lata («¡Clang!»), va a la mochila y, con
## una probabilidad de 1/64, puede caer otra y, con otro 1/64, una tercera. Las latas
## extra no se cobran.
##
## Los precios son los del guion de Rubí (`checkmoney`/`removemoney`: 200/300/350), no
## los de la tabla Objetos (que tiene la LIMONADA a 400).
extends EventoGuionizado
class_name EventoMaquinaBebidas

const MOTIVO_PAUSA: StringName = &"maquina_bebidas"

const TEXTO_PREGUNTA: String = "CALAGUA_CC_EXPENDEDORA_PREGUNTA"
const TEXTO_NADA: String = "CALAGUA_CC_EXPENDEDORA_NADA"
const TEXTO_CAE: String = "CALAGUA_CC_EXPENDEDORA_CAE"
const TEXTO_EXTRA: String = "CALAGUA_CC_EXPENDEDORA_EXTRA"
const TEXTO_SIN_DINERO: String = "CALAGUA_CC_EXPENDEDORA_SIN_DINERO"
const TEXTO_MOCHILA_LLENA: String = "CALAGUA_CC_EXPENDEDORA_MOCHILA_LLENA"
const TEXTO_OBJETO_GUARDADO: String = "OBJETO_GUARDADO"

const SONIDO_VENTA: StringName = &"SE_VEND"
## Probabilidad de que caiga una lata extra (1/64 en la ROM).
const PROBABILIDAD_EXTRA: int = 64
## Latas extra como máximo por compra (dos tiradas de 1/64 seguidas en el guion).
const MAXIMO_EXTRAS: int = 2
## Las tres bebidas de la máquina, en el orden del menú de Rubí.
const BEBIDAS: Array[String] = ["AGUAFRESCA", "REFRESCO", "LIMONADA"]
## Precio de cada bebida en la máquina (`CheckMoneyFreshWater` / `SodaPop` / `Lemonade`).
const PRECIOS: Dictionary = {"AGUAFRESCA": 200, "REFRESCO": 300, "LIMONADA": 350}

## El cartel (bg_event) que abre la máquina.
@export var cartel: NodePath
## Sustituye al multichoice (tests): devuelve el índice de la bebida elegida.
var elegir_bebida: Callable = Callable()
## Sustituye al sorteo de la lata extra (tests): devuelve true si cae.
var toca_extra: Callable = Callable()
## Sustituye al AdministradorMapa de la raíz (tests).
var administrador: Node = null


func _init() -> void:
	motivo_pausa = MOTIVO_PAUSA


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var maquina := get_node_or_null(cartel)
	if maquina != null and maquina.has_signal("accionado"):
		maquina.accionado.connect(_on_accionado)


func _administrador() -> Node:
	if is_instance_valid(administrador):
		return administrador
	return get_tree().root.get_node_or_null("AdministradorMapa")


func _on_accionado(_cartel: Node) -> void:
	if not comenzar(_administrador()):
		return
	mostrar_cuadro_dinero()
	await _vender()
	terminar(false)


## El menú de bebidas: se repite hasta que el jugador se va.
func _vender() -> void:
	while true:
		await mensaje(TEXTO_PREGUNTA)
		var eleccion := await _elegir()
		if eleccion < 0:
			await mensaje(TEXTO_NADA)
			return
		var bebida: String = BEBIDAS[eleccion]
		if SistemaGuardado.get_dinero_jugador() < precio(bebida):
			await mensaje(TEXTO_SIN_DINERO)
			return
		if not await _entregar(bebida, true):
			await mensaje(TEXTO_MOCHILA_LLENA)
			return
		await mensaje(TEXTO_CAE, true, {"{bebida}": nombre_bebida(bebida)})
		await _mensaje_guardado(bebida)
		# Con una probabilidad de 1/64 cae otra lata, y de nuevo con otro 1/64 una tercera.
		for _extra in MAXIMO_EXTRAS:
			if not _toca_extra():
				break
			if not await _entregar(bebida, false):
				await mensaje(TEXTO_MOCHILA_LLENA)
				return
			await mensaje(TEXTO_EXTRA, true, {"{bebida}": nombre_bebida(bebida)})
			await _mensaje_guardado(bebida)


## El precio de una bebida en la máquina.
func precio(bebida: String) -> int:
	return int(PRECIOS.get(bebida, 0))


## El nombre de la bebida, como lo muestra el texto.
func nombre_bebida(bebida: String) -> String:
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(bebida)
	return str(datos.get("nombre", bebida))


## true si cae la lata extra.
func _toca_extra() -> bool:
	if toca_extra.is_valid():
		return bool(toca_extra.call())
	return randi() % PROBABILIDAD_EXTRA == 0


## Mete la bebida en la mochila y, si `cobrar`, la cobra (las latas extra son gratis).
## false si no cabe.
func _entregar(bebida: String, cobrar: bool) -> bool:
	var resultado: Dictionary = SistemaGuardado.dar_objeto_jugador(bebida, 1)
	if not bool(resultado.get("exito", false)):
		return false
	if cobrar:
		SistemaGuardado.quitar_dinero_jugador(precio(bebida))
		actualizar_cuadro_dinero()
	if Singleton.has_signal("play_sound"):
		Singleton.play_sound.emit(SONIDO_VENTA)
	return true


## Menú con las tres bebidas. Devuelve el índice o -1 si el jugador sale.
func _elegir() -> int:
	if elegir_bebida.is_valid():
		return int(elegir_bebida.call())
	var opciones := PackedStringArray()
	for bebida in BEBIDAS:
		opciones.append(nombre_bebida(bebida))
	var dialogo: NinePatchRect = admin.cuadro_dialogo
	dialogo.cerrar()
	dialogo.preguntaSiNo(tr(TEXTO_PREGUNTA), opciones)
	while true:
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			if parametros.is_empty():
				return -1
			var respuesta := str(parametros[0])
			if respuesta == "Y":
				return 0
			if respuesta.is_valid_int():
				return clampi(int(respuesta), 0, opciones.size() - 1)
			return -1
	return -1


## «{PN} puso {bebida} en el BOLSILLO de {bolsillo}.»
func _mensaje_guardado(bebida: String) -> void:
	var datos: Dictionary = SistemaGuardado.obtener_datos_objeto_completos(bebida)
	await mensaje(TEXTO_OBJETO_GUARDADO, true, {
		"{key}": nombre_bebida(bebida),
		"{bname}": str(datos.get("bolsillo_nombre", "")).to_upper(),
	})
