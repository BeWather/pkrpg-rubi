## comprar_decoracion.gd
## Pantalla de compra de una TIENDA DE DECORACIÓN (`pokemartdecoration` de pokeruby). Es la misma
## pantalla de la tienda de objetos (`comprar.tscn`: lista con precio, descripción, dinero, flechas
## y repetición de las teclas), heredada para cambiar solo la compra:
##   - la lista son decoraciones del catálogo de bases secretas (`DatosTiendaDecoracion.detalle`);
##   - se compra de una en una, sin cantidad: «{nombre}, ¿verdad? Te costará {precio}. ¿De acuerdo?»
##     con SÍ/NO (`gOtherText_ThatWillBe2`);
##   - sin dinero → «No tienes suficiente dinero.»; sin sitio en su categoría → «No hay sitio para
##     {nombre}.» (`gOtherText_SpaceForIsFull`); sin cobrar en ninguno de los dos casos;
##   - al comprar: «¡Gracias! Se enviará a tu PC.» y la decoración va al inventario de bases
##     secretas (`CompraDecoracion`), no a la mochila.
## Se abre con `configurar_tienda(ids_de_decoracion, quien_la_abre)`, igual que la de objetos, y emite
## `compra_cerrada` al salir (la última fila, «Salir», o el botón de cancelar).
extends CompraUI
class_name CompraDecoracionUI

## Se emite tras cada compra con la decoración comprada (ya cobrada y en el inventario).
signal compra_realizada(decoracion_id: int)

const SONIDO_COMPRA: String = "SE_SHOP"

## Ids de decoración de la lista, en el orden de la tienda.
var ids_decoracion: Array[int] = []
## true mientras espera la respuesta SÍ/NO (evita pulsar otra fila).
var _preguntando: bool = false


## Igual que la de objetos, pero la lista son ids de decoración (no nombres de objeto).
func configurar_tienda(inventario: Array, vendedor: Node):
	ids_decoracion.clear()
	for decoracion_id: Variant in inventario:
		ids_decoracion.append(int(decoracion_id))
	vendedor_ref = vendedor
	_crear_lista_objetos()
	_actualizar_display()
	if not is_inside_tree():
		await tree_entered
	await get_tree().create_timer(0.3).timeout
	input_activo = true
	set_process_input(true)


func _crear_lista_objetos():
	objetos_disponibles.clear()
	for decoracion_id: int in ids_decoracion:
		var datos: Dictionary = DatosTiendaDecoracion.detalle(decoracion_id)
		if datos.is_empty():
			push_warning("[CompraDecoracionUI] Decoración %d fuera del catálogo: omitida" % decoracion_id)
			continue
		objetos_disponibles.append({
			"id": str(decoracion_id),
			"decoracion_id": decoracion_id,
			"nombre": datos["nombre"],
			"precio": datos["precio"],
			"descripcion": datos["descripcion"],
			"stock": -1,
		})
	# «CANCELAR» de Rubí: la última fila deja de comprar.
	objetos_disponibles.append({
		"id": "salir",
		"nombre": tr("DECORACION_TIENDA_SALIR"),
		"precio": 0,
		"descripcion": tr("DECORACION_TIENDA_SALIR_DESCRIPCION"),
		"stock": -1,
	})


## A sobre una fila: «Salir» cierra; sin dinero avisa; si no, pregunta SÍ/NO.
func _confirmar_compra():
	_detener_nav_vertical()
	input_activo = false
	if _preguntando or objetos_disponibles.is_empty() or item_actual >= objetos_disponibles.size():
		return
	var objeto: Dictionary = objetos_disponibles[item_actual]
	if objeto["id"] == "salir":
		_cerrar_pantalla()
		return
	var decoracion_id: int = int(objeto["decoracion_id"])
	if not CompraDecoracion.puede_pagar(decoracion_id):
		_mostrar_mensaje(DatosTiendaDecoracion.texto(DatosTiendaDecoracion.TEXTO_SIN_DINERO))
		return
	_preguntar_compra(decoracion_id)


## `gOtherText_ThatWillBe2` + SÍ/NO. NO (o cancelar) vuelve a la lista sin tocar nada.
func _preguntar_compra(decoracion_id: int) -> void:
	_preguntando = true
	var acepta: bool = await _preguntar_si_no(DatosTiendaDecoracion.texto(
			DatosTiendaDecoracion.TEXTO_CONFIRMAR, DatosTiendaDecoracion.reemplazos(decoracion_id)))
	_preguntando = false
	if not acepta:
		_cerrar_cuadro()
		input_activo = true
		return
	_ejecutar_compra_decoracion(decoracion_id)


## `Task_DoItemPurchase`: revalida dinero y sitio, entrega la decoración y cobra.
func _ejecutar_compra_decoracion(decoracion_id: int) -> void:
	var reemplazos: Dictionary = DatosTiendaDecoracion.reemplazos(decoracion_id)
	match CompraDecoracion.comprar(decoracion_id):
		CompraDecoracion.COMPRADA:
			if Singleton.has_signal("play_sound"):
				Singleton.play_sound.emit(SONIDO_COMPRA)
			_actualizar_dinero()
			_actualizar_display()
			compra_realizada.emit(decoracion_id)
			_mostrar_mensaje(DatosTiendaDecoracion.texto(DatosTiendaDecoracion.TEXTO_GRACIAS, reemplazos))
		CompraDecoracion.SIN_SITIO:
			_mostrar_mensaje(DatosTiendaDecoracion.texto(DatosTiendaDecoracion.TEXTO_SIN_SITIO, reemplazos))
		CompraDecoracion.SIN_DINERO:
			_mostrar_mensaje(DatosTiendaDecoracion.texto(DatosTiendaDecoracion.TEXTO_SIN_DINERO))
		_:
			# Catálogo o guardado no válidos: no se cobra, se vuelve a la lista.
			_cerrar_cuadro()
			input_activo = true


## Pregunta SÍ/NO con el cuadro de diálogo y espera la respuesta (cancelar equivale a NO).
func _preguntar_si_no(texto: String) -> bool:
	if cuadro_dialogo == null:
		cuadro_dialogo = Singleton.get_cuadro_dialogo()
	if cuadro_dialogo == null:
		return false
	cuadro_dialogo.z_index = 3
	cuadro_dialogo.cerrar()
	cuadro_dialogo.preguntaSiNo(texto)
	while true:
		var datos: Array = await cuadro_dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			return not parametros.is_empty() and str(parametros[0]) == "Y"
	return false


func _cerrar_cuadro() -> void:
	if cuadro_dialogo:
		cuadro_dialogo.z_index = 1
		cuadro_dialogo.cierra_dialogo()
