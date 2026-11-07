extends NinePatchRect

signal efecto_sonido(tipo: String)

@onready var select_box = $cursor
@onready var sonido = $sonido
@onready var mov1 = $mov1
@onready var mov2 = $mov2
@onready var mov3 = $mov3
@onready var mov4 = $mov4
@onready var pp = $pp
@onready var tipo = $tipo

enum { MOV1, MOV2, MOV3, MOV4 }
var menu_movimiento_seleccionado = MOV1
var activo = false
var movimientos: Array[Movimiento] = []

func _ready() -> void:
	self.visible = false
	self.position = Vector2(0,112)
	posicionar_cursor()

func _unhandled_input(event: InputEvent) -> void:
	if activo == true:
		# Verificar si el nodo padre (batalla) quiere ignorar input temporal
		var padre_batalla = get_parent()
		if padre_batalla and padre_batalla.has_method("get_ignorar_input_temporal") and padre_batalla.get_ignorar_input_temporal():
			if Input.is_action_pressed("btn_accion") or Input.is_action_pressed("btn_cancelar"):
				# Sigue sostenida la tecla que originó el bloqueo: ignorarla y
				# esperar a que la suelten para reactivar el menú.
				if event.is_action_pressed("btn_accion") or event.is_action_pressed("btn_cancelar"):
					return  # Ignorar estas teclas específicas
				elif event.is_action_released("btn_accion") or event.is_action_released("btn_cancelar"):
					padre_batalla.call("reset_ignorar_input_temporal")
				return
			# Ya se soltó antes de que este menú estuviera activo (p. ej.
			# durante una animación larga como un cambio de Pokémon): no hay
			# soltado que esperar, así que se reactiva ya y este mismo evento
			# se procesa normal más abajo en vez de perderse.
			padre_batalla.call("reset_ignorar_input_temporal")
		
		if event.is_action_pressed("btn_abajo"):
			match menu_movimiento_seleccionado:
				MOV1:
					cambiar_opcion(MOV3)
				MOV2:
					cambiar_opcion(MOV4)
		elif event.is_action_pressed("btn_arriba"):
			match menu_movimiento_seleccionado:
				MOV3:
					cambiar_opcion(MOV1)
				MOV4:
					cambiar_opcion(MOV2)
		elif event.is_action_pressed("btn_derecha"):
			match menu_movimiento_seleccionado:
				MOV1:
					cambiar_opcion(MOV2)
				MOV3:
					cambiar_opcion(MOV4)
		elif event.is_action_pressed("btn_izquierda"):
			match menu_movimiento_seleccionado:
				MOV2:
					cambiar_opcion(MOV1)
				MOV4:
					cambiar_opcion(MOV3)
		elif event.is_action_pressed("btn_accion"):
			# Verificar que el movimiento seleccionado existe
			var indice_movimiento = -1
			match menu_movimiento_seleccionado:
				MOV1:
					indice_movimiento = 0
				MOV2:
					indice_movimiento = 1
				MOV3:
					indice_movimiento = 2
				MOV4:
					indice_movimiento = 3
			
			# Solo permitir selección si el movimiento existe
			if indice_movimiento >= 0 and indice_movimiento < movimientos.size() and movimientos[indice_movimiento] != null:
				sonido.play()
				activo = false
				visible = false
				Singleton.emit_signal("batalla_movimiento_seleccionado", menu_movimiento_seleccionado)
			else:
				print("⚠️ No se puede seleccionar movimiento inexistente (índice: %d, tamaño: %d)" % [indice_movimiento, movimientos.size()])
		elif event.is_action_pressed("btn_cancelar"):
			sonido.play()
			activo = false
			visible = false
			Singleton.emit_signal("batalla_movimiento_seleccionado", -1)


func posicionar_cursor() -> void:
	match menu_movimiento_seleccionado:
		MOV1:
			select_box.position = Vector2(6,7)
		MOV2:
			select_box.position = Vector2(87,7)
		MOV3:
			select_box.position = Vector2(6,23)
		MOV4:
			select_box.position = Vector2(87,23)

func cambiar_opcion(opcion) -> void:
	# Verificar que la opción corresponde a un movimiento existente
	var indice_destino = -1
	match opcion:
		MOV1:
			indice_destino = 0
		MOV2:
			indice_destino = 1
		MOV3:
			indice_destino = 2
		MOV4:
			indice_destino = 3
	
	# Solo cambiar si el movimiento existe
	if indice_destino >= 0 and indice_destino < movimientos.size() and movimientos[indice_destino] != null:
		menu_movimiento_seleccionado = opcion
		posicionar_cursor()
		emit_signal("efecto_sonido", "seleccion")
		set_cuadro_pp()
		sonido.play()
	else:
		print("⚠️ No se puede navegar a movimiento inexistente (índice: %d)" % indice_destino)

func set_movs(f_movs: Array[Movimiento]) -> void:
	movimientos = f_movs
	print("🔧 set_movs: Recibidos %d movimientos" % movimientos.size())
	
	# Resetear todos los labels
	mov1.text = "--"
	mov2.text = "--"
	mov3.text = "--"
	mov4.text = "--"
	
	# Llenar solo los movimientos disponibles
	for i in range(min(movimientos.size(), 4)):
		var mov: Movimiento = movimientos[i]
		var nombre_mov = "--"
		
		if mov != null and mov.nombre != "":
			nombre_mov = str(mov.nombre)
		
		match i:
			0:
				mov1.text = nombre_mov
			1:
				mov2.text = nombre_mov
			2:
				mov3.text = nombre_mov
			3:
				mov4.text = nombre_mov
	
	# Resetear selección a un movimiento válido
	resetear_seleccion_valida()
	
	# Actualizar info del movimiento seleccionado
	set_cuadro_pp()

func resetear_seleccion_valida() -> void:
	# Si no hay movimientos, mantener MOV1 pero no permitir selección
	if movimientos.size() == 0:
		menu_movimiento_seleccionado = MOV1
		return
	
	# Si la selección actual no es válida, resetear a MOV1
	var indice_actual = -1
	match menu_movimiento_seleccionado:
		MOV1:
			indice_actual = 0
		MOV2:
			indice_actual = 1
		MOV3:
			indice_actual = 2
		MOV4:
			indice_actual = 3
	
	if indice_actual >= movimientos.size() or movimientos[indice_actual] == null:
		menu_movimiento_seleccionado = MOV1
		posicionar_cursor()
		print("🔄 Selección resetada a MOV1")

func set_cuadro_pp() -> void:
	# Verificar que el array de movimientos no esté vacío
	if movimientos.size() == 0:
		pp.text = "PP --/--"
		tipo.text = "---"
		return
	
	var indice_movimiento = -1
	match menu_movimiento_seleccionado:
		MOV1:
			indice_movimiento = 0
		MOV2:
			indice_movimiento = 1
		MOV3:
			indice_movimiento = 2
		MOV4:
			indice_movimiento = 3
	
	# Verificar que el índice sea válido
	if indice_movimiento >= 0 and indice_movimiento < movimientos.size():
		var mov: Movimiento = movimientos[indice_movimiento]
		if mov != null:
			pp.text = "PP " + str(mov.pp_act) + "/" + str(mov.pp_tot)
			if mov.datos != null and typeof(mov.datos) == TYPE_DICTIONARY:
				tipo.text = mov.get_tipo()
			else:
				tipo.text = "???"
		else:
			pp.text = "PP --/--"
			tipo.text = "---"
	else:
		pp.text = "PP --/--"
		tipo.text = "---"
