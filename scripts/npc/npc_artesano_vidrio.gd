@tool
extends "res://scripts/npc/npc_base.gd"

## Route113_GlassWorkshop_EventScript_163565: entrega Saco Hollín y canjea
## ceniza de ruta 113. Recetas y transacciones: taller_vidrio.gd.
const TallerScript = preload("res://scripts/npc/taller_vidrio.gd")
const ESTILO_TEXTO = preload("res://UI/texto_normal_negro.tres")
const MOTIVO_PAUSA: StringName = &"artesano_vidrio"
const MJE_INSTRUCCIONES_SACO: String = "Coge este SACO HOLLÍN y camina entre\\llos montones de ceniza, ¡achís!\\p" \
	+ "Se llenará con la ceniza volcánica,\\l¡achís, achís!\\p" \
	+ "Cuando hayas recogido una buena\\lcantidad, ven a verme, ¡ACHÍS!"

signal _mensaje_terminado
signal _menu_elegido(indice: int)

var taller: TallerVidrio
var _secuencia_activa := false
var _menu: NinePatchRect
var _cursor: PkSelectorSimple
var _indice_menu := 0
var canje_vidrio: CanjeVidrio


func _ready() -> void:
	super._ready()
	set_process_input(false)
	if not Engine.is_editor_hint():
		taller = TallerScript.new(SistemaGuardado, DatabaseManager)
		add_to_group(&"entrada_por_warp")


## OnTransition del taller: solo al entrar por un warp, no al cargar partida.
func al_entrar_por_warp() -> void:
	if taller:
		taller.registrar_entrada_taller()


func _exit_tree() -> void:
	if is_instance_valid(canje_vidrio): canje_vidrio.cancelar()
	_cerrar_menu()
	if _secuencia_activa and not Engine.is_editor_hint():
		Singleton.mantener_pausa(MOTIVO_PAUSA, false)


func _procesar_interaccion() -> void:
	interrupcion_pendiente = false
	if _secuencia_activa:
		return
	if nodo_administrador == null or nodo_administrador.cuadro_dialogo == null or taller == null:
		if jugador and jugador.has_method("esperar_dialogo"):
			jugador.esperar_dialogo(false)
		cambiar_estado(EstadoNPC.IDLE)
		return
	if taller.tiene_saco() and not taller.debe_repetir_instrucciones() \
		and nodo_administrador.has_method("puede_actuar_jugador"):
		if nodo_administrador.puede_actuar_jugador() and nodo_administrador.mapa_actual == _obtener_mapa_propio() \
			and nodo_administrador.coneccion == 0:
			if not taller.saco_entregado():
				# Mismo reconocimiento del saco ya poseído que la secuencia anterior.
				taller.entregar_saco()
				taller.registrar_entrada_taller()
			_ejecutar_canje_vidrio()
		return
	_ejecutar_secuencia()


func _ejecutar_canje_vidrio() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	mirar_jugador()
	var canje: CanjeVidrio = preload("res://escenas/bases_secretas/canje_vidrio.tscn").instantiate()
	canje_vidrio = canje
	nodo_administrador.get_node("Menu").add_child(canje)
	canje.iniciar(self, taller)
	await canje.terminada
	if canje_vidrio == canje:
		canje_vidrio = null
		_secuencia_activa = false
		if is_inside_tree():
			cambiar_estado(EstadoNPC.IDLE)
			_volver_a_direccion_base()
	if is_instance_valid(canje): canje.queue_free()


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_VISIBILITY_CHANGED and not Engine.is_editor_hint() \
		and is_instance_valid(canje_vidrio) and not is_visible_in_tree(): canje_vidrio.cancelar()


func _ejecutar_secuencia() -> void:
	_secuencia_activa = true
	cambiar_estado(EstadoNPC.INTERACTING)
	if tipo_movimiento != TipoMovimientoNPC.SIN_MOVIMIENTO:
		mirar_jugador()
	Singleton.mantener_pausa(MOTIVO_PAUSA, true)
	if jugador:
		jugador.start_dialog()
		jugador.no_control = true
	if taller.tiene_saco() and not taller.saco_entregado():
		# Ya lo tenía: registrar la entrega sin duplicarlo y sin repetir instrucciones.
		taller.entregar_saco()
		taller.registrar_entrada_taller()

	# Un solo cuadro para toda la secuencia: los mensajes se encadenan sin
	# cerrarlo y solo _finalizar() lo cierra (closemessage/release de Gen 3).
	if not taller.tiene_saco():
		if not taller.saco_entregado():
			var mje_entrega_saco: String = "Esta zona está cubierta de ceniza\\lvolcánica, ¡achís, achís!\\p"
			mje_entrega_saco += "Yo sé cómo usarla, ¡achís!\\p"
			mje_entrega_saco += "Fabrico objetos de cristal con ella,\\l¿a que molo? ¡¡¡ACHÍS!!!\\p"
			mje_entrega_saco += "Puedes recoger ceniza con esto..."
			await _mostrar_mensaje(mje_entrega_saco)
			if taller.entregar_saco():
				await mostrar_objeto_recibido(TallerVidrio.OBJETO_SACO)
				await _mostrar_mensaje(MJE_INSTRUCCIONES_SACO)
			else:
				await _mostrar_mensaje("Ahora mismo no puedo entregarte el SACO HOLLÍN.")
		else:
			await _mostrar_mensaje("No tienes el SACO HOLLÍN. Debes llevarlo para recoger ceniza.")
		_finalizar()
		return

	# Hasta salir y volver a entrar al taller solo repite las instrucciones.
	if taller.debe_repetir_instrucciones():
		await _mostrar_mensaje(MJE_INSTRUCCIONES_SACO)
		_finalizar()
		return

	var mje_validacion_cantidad: String = "¿Has recogido ceniza?, ¡achís!\\lA ver. ¡Achís, achís!"
	await _mostrar_mensaje(mje_validacion_cantidad)

	var ceniza := taller.ceniza()
	if ceniza < 250:
		var mensaje: String = "Mmmm...\\lNo hay bastante ceniza, ¡achís!\\w\\lNo puedo hacer cristal con esto...\\p"
		mensaje += "A ver... Tienes que dar %d pasos para\\lrecoger suficiente ceniza y que yo\\p" % (250 - ceniza)
		mensaje += "pueda hacerte una FLAUTA AZUL, ¡achís!\\p"
		await _mostrar_mensaje(mensaje)
		_finalizar()
		return

	var mje_tiene_suficientes: String = "¡Oh!\\lTienes un montón de ceniza, ¡achís!\\p"
	mje_tiene_suficientes += "Te voy a hacer un objeto de cristal...\\l¿Cuál quieres? ¡Achís!"
	await _mostrar_mensaje(mje_tiene_suficientes)
	# El menú se superpone al cuadro, que sigue mostrando el último mensaje.
	while _secuencia_activa:
		var indice: int = await _elegir_receta()
		if indice < 0:
			await _mostrar_mensaje("¿No quieres nada por ahora? ¡Vuelve cuando quieras!")
			break
		var receta: Dictionary = TallerVidrio.RECETAS[indice]
		if not taller.disponible(indice):
			await _mostrar_mensaje("Aún no puedo fabricar %s aquí." % receta.nombre)
			continue
		if taller.ceniza() < int(receta.costo):
			await _mostrar_mensaje("Para %s te faltan %d pasos de ceniza." % [receta.nombre, int(receta.costo) - taller.ceniza()])
			continue
		if not await _preguntar_si_no("¿Quieres %s por %d de ceniza?" % [receta.nombre, receta.costo]):
			continue
		match taller.canjear(indice):
			&"entregado":
				await _mostrar_mensaje("¡Ya está lista tu %s! ¡Aquí tienes!" % receta.nombre)
				await mostrar_objeto_recibido(str(receta.objeto))
				break
			&"sin_espacio":
				await _mostrar_mensaje("No cabe en la mochila. Vuelve cuando tengas espacio.")
				break
			_:
				await _mostrar_mensaje("No puedo completar el encargo ahora mismo.")
	_finalizar()


func _finalizar() -> void:
	_cerrar_menu()
	if nodo_administrador and is_instance_valid(nodo_administrador.cuadro_dialogo):
		nodo_administrador.cuadro_dialogo.cerrar()
	if jugador:
		jugador.end_dialog()
		jugador.no_control = false
	Singleton.mantener_pausa(MOTIVO_PAUSA, false)
	_volver_a_direccion_base()
	_secuencia_activa = false
	cambiar_estado(EstadoNPC.IDLE)


## Espera el botón y deja el cuadro abierto para el siguiente mensaje.
func _mostrar_mensaje(texto: String) -> void:
	continuar_dialogo(tr(texto), true, _mensaje_terminado.emit)
	await _mensaje_terminado


func _preguntar_si_no(texto: String) -> bool:
	var dialogo: NinePatchRect = nodo_administrador.cuadro_dialogo
	# preguntaSiNo() exige IDLE: cerrar() y reabrir en el mismo frame no se ve.
	var continua: bool = dialogo.esta_activo
	dialogo.cerrar()
	dialogo.omitir_siguiente_sonido_inicio = continua
	dialogo.preguntaSiNo(tr(texto))
	while true:
		var datos: Array = await dialogo.comando_ejecutado
		if datos.size() >= 2 and str(datos[0]) == "respuesta_confirmacion":
			var parametros: Array = datos[1]
			return not parametros.is_empty() and str(parametros[0]) == "Y"
	return false


func _elegir_receta() -> int:
	_indice_menu = 0
	_menu = NinePatchRect.new()
	var imagen_tipo := int(SistemaGuardado.datos_vivos.opciones.imagen_tipo)
	preload("res://scripts/clases/MenuBoxManager.gd").apply_texture_to_ninepatch(_menu, imagen_tipo)
	_menu.patch_margin_left = 8
	_menu.patch_margin_top = 8
	_menu.patch_margin_right = 8
	_menu.patch_margin_bottom = 8
	_menu.position = Vector2(8, 4)
	_menu.size = Vector2(170, (TallerVidrio.RECETAS.size() + 1) * 16 + 16)
	for indice in range(TallerVidrio.RECETAS.size()):
		var receta: Dictionary = TallerVidrio.RECETAS[indice]
		var etiqueta := Label.new()
		etiqueta.label_settings = ESTILO_TEXTO
		etiqueta.text = "%s  %d" % [receta.nombre, receta.costo]
		etiqueta.position = Vector2(16, 8 + indice * 16)
		_menu.add_child(etiqueta)
	var salir := Label.new()
	salir.label_settings = ESTILO_TEXTO
	salir.text = "SALIR"
	salir.position = Vector2(16, 8 + TallerVidrio.RECETAS.size() * 16)
	_menu.add_child(salir)
	_cursor = PkSelectorSimple.new()
	_cursor.color = Color(239.0 / 255, 110.0 / 255, 96.0 / 255)
	_cursor.ancho_borde = 1
	_cursor.parpadeo = false
	_cursor.size = Vector2(154, 17)
	_menu.add_child(_cursor)
	_actualizar_cursor()
	var capa := get_tree().root.get_node_or_null("AdministradorMapa/Menu")
	if capa == null:
		capa = self
	capa.add_child(_menu)
	# No interpretar la misma pulsación que cerró el diálogo anterior.
	await get_tree().process_frame
	set_process_input(true)
	var indice: int = await _menu_elegido
	_cerrar_menu()
	return indice


func _actualizar_cursor() -> void:
	_cursor.position = Vector2(7, 7 + _indice_menu * 16)


func _input(event: InputEvent) -> void:
	if _menu == null:
		return
	if event.is_action_pressed("btn_arriba"):
		_indice_menu = posmod(_indice_menu - 1, TallerVidrio.RECETAS.size() + 1)
		_actualizar_cursor()
	elif event.is_action_pressed("btn_abajo"):
		_indice_menu = (_indice_menu + 1) % (TallerVidrio.RECETAS.size() + 1)
		_actualizar_cursor()
	elif event.is_action_pressed("btn_accion"):
		_menu_elegido.emit(_indice_menu if _indice_menu < TallerVidrio.RECETAS.size() else -1)
	elif event.is_action_pressed("btn_cancelar"):
		_menu_elegido.emit(-1)
	else:
		return
	# El clic del menú cubre el inicio del mensaje siguiente (continuar_dialogo no lo repite).
	Singleton.play_sound.emit("cursor_menu")
	get_viewport().set_input_as_handled()


func _cerrar_menu() -> void:
	set_process_input(false)
	if is_instance_valid(_menu):
		_menu.queue_free()
	_menu = null
	_cursor = null
