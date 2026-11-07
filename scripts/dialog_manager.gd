extends Node

# Sistema de gestión de diálogos centralizado
# Maneja todos los tipos de diálogos: texto, confirmaciones, menús, etc.

signal text_completed
signal confirmation_result(accepted: bool)
signal command_executed(command: String, parameters: Array)

# Referencias a escenas de diálogo
const SCN_CUADRO_DIALOGO = preload("res://UI/cuadro_dialogo.tscn")
const SCN_CONFIRMACION_GUARDADO_SCRIPT = preload("res://UI/guardar/confirmacion_guardado.gd")

# Estado del sistema
var current_dialog: Node = null
var dialog_queue: Array = []
var is_dialog_active: bool = false

# Pool de nodos reutilizables
var dialog_pool: Array = []
var confirmation_pool: Array = []

# Configuración
var dialog_layer: CanvasLayer = null

func _ready():
	print("🗨️ [DIALOG_MANAGER] Inicializando sistema de diálogos")
	_setup_dialog_layer()

## Crea la capa de canvas para diálogos
func _setup_dialog_layer():
	dialog_layer = CanvasLayer.new()
	dialog_layer.name = "DialogLayer"
	dialog_layer.layer = 100  # Por encima de todo
	# El root puede estar ocupado durante el setup inicial; usar call_deferred evita el error:
	# "Parent node is busy setting up children, `add_child()` failed".
	get_tree().root.call_deferred("add_child", dialog_layer)

# =====================================
# API PRINCIPAL
# =====================================

## Muestra un diálogo de texto simple
func show_text(text: String, callback: Callable = Callable(), omitir_sonido_inicio: bool = false) -> void:
	print("🗨️ [DIALOG_MANAGER] Mostrando texto: ", text)
	
	# Usar el cuadro de diálogo existente
	var cuadro_dialogo = Singleton.get_cuadro_dialogo()
	if not cuadro_dialogo:
		print("❌ [DIALOG_MANAGER] No se pudo obtener cuadro de diálogo")
		return
	
	print("🗨️ [DIALOG_MANAGER] Cuadro diálogo obtenido correctamente")
	current_dialog = cuadro_dialogo
	is_dialog_active = true
	
	# Mostrar texto con callback integrado
	# cuadro_dialogo.cartel(text, _create_text_callback(callback))
	# cuadro_dialogo.cartel(text)
	cuadro_dialogo.mostrar(text, true, true, callback, false, omitir_sonido_inicio)

## Crea un callback que limpia el estado y llama al callback original
func _create_text_callback(original_callback: Callable) -> Callable:
	return Callable(self, "_on_text_completed").bind(original_callback)

## Se ejecuta cuando el texto se completa
func _on_text_completed(original_callback: Callable) -> void:
	print("🗨️ [DIALOG_MANAGER] Texto completado")
	
	# Limpiar estado
	current_dialog = null
	is_dialog_active = false
	
	# Emitir señal
	emit_signal("text_completed")
	
	# Ejecutar callback original
	if original_callback.is_valid():
		original_callback.call()
	
	# Procesar siguiente en cola
	_process_dialog_queue()

## Muestra la confirmación específica de guardado
func show_save_confirmation(callback: Callable = Callable()) -> void:
	print("🗨️ [DIALOG_MANAGER] Mostrando confirmación de guardado")
	
	# Por ahora, usar el método temporal hasta que tengamos la escena .tscn
	_show_save_confirmation_temp(callback)

## Método temporal que usa el sistema actual de confirmación
func _show_save_confirmation_temp(callback: Callable) -> void:
	print("🗨️ [DIALOG_MANAGER] _show_save_confirmation_temp iniciado")
	
	# Obtener el nodo menu actual
	var root = get_tree().root
	var admin = root.get_node_or_null("AdministradorMapa")
	if not admin:
		print("❌ [DIALOG_MANAGER] No se encontró AdministradorMapa")
		return
		
	var menu = admin.get_node_or_null("Menu")
	if not menu:
		print("❌ [DIALOG_MANAGER] No se encontró nodo Menu")
		return
	
	print("🗨️ [DIALOG_MANAGER] Creando confirmación de guardado")
	
	# Crear la confirmación como antes pero gestionada por DialogManager
	var confirmation = Control.new()
	confirmation.set_script(SCN_CONFIRMACION_GUARDADO_SCRIPT)
	menu.add_child(confirmation)
	
	print("🗨️ [DIALOG_MANAGER] Confirmación añadida al árbol")
	
	current_dialog = confirmation
	is_dialog_active = true
	
	# Conectar señal; el script de confirmación emite `guardado_completado(acepta: bool)`
	confirmation.connect("guardado_completado", _on_temp_save_confirmation_result.bind(callback))
	print("🗨️ [DIALOG_MANAGER] Señal conectada, iniciando confirmación")
	if confirmation.has_method("iniciar"):
		confirmation.iniciar()
	else:
		# Fallback: si existe configurar por compatibilidad, intentar llamarla
		if confirmation.has_method("configurar"):
			confirmation.configurar("¿Quieres guardar la partida?", {})

## Callback temporal para confirmación de guardado
func _on_temp_save_confirmation_result(accepted: bool, callback: Callable) -> void:
	print("🗨️ [DIALOG_MANAGER] Resultado confirmación temporal: ", accepted)
	
	# Limpiar el diálogo actual
	if current_dialog and is_instance_valid(current_dialog):
		current_dialog.queue_free()
	
	current_dialog = null
	is_dialog_active = false
	
	# Ejecutar callback
	if callback.is_valid():
		callback.call(accepted)
	
	emit_signal("confirmation_result", accepted)

## Muestra una confirmación genérica SI/NO
func show_confirmation(question: String, callback: Callable = Callable()) -> void:
	print("🗨️ [DIALOG_MANAGER] Confirmación: ", question)
	# TODO: Implementar confirmación genérica
	show_text(question, callback)

## Cierra el diálogo actual
func close_current_dialog() -> void:
	if current_dialog and is_instance_valid(current_dialog):
		print("🗨️ [DIALOG_MANAGER] Cerrando diálogo actual")
		_return_dialog_to_pool(current_dialog)
		current_dialog = null
		is_dialog_active = false
		
		# Procesar siguiente en cola
		_process_dialog_queue()

# =====================================
# GESTIÓN INTERNA
# =====================================

## Muestra un diálogo usando la función de configuración
func _show_dialog(dialog: Node, setup_func: Callable) -> void:
	if is_dialog_active:
		print("🗨️ [DIALOG_MANAGER] Diálogo en cola")
		dialog_queue.append({"dialog": dialog, "setup": setup_func})
		return
	
	current_dialog = dialog
	is_dialog_active = true
	
	# Añadir a la capa de diálogos
	dialog_layer.add_child(dialog)
	
	# Configurar y mostrar
	setup_func.call()

## Procesa la cola de diálogos pendientes
func _process_dialog_queue() -> void:
	if dialog_queue.size() > 0:
		var next_dialog = dialog_queue.pop_front()
		_show_dialog(next_dialog.dialog, next_dialog.setup)

## Obtiene un diálogo de texto del pool o crea uno nuevo
func _get_text_dialog() -> Node:
	if dialog_pool.size() > 0:
		return dialog_pool.pop_back()
	
	var dialog = SCN_CUADRO_DIALOGO.instantiate()
	
	# Conectar señales para limpieza automática
	if not dialog.is_connected("texto_completado", _on_text_dialog_completed):
		dialog.connect("texto_completado", _on_text_dialog_completed)
	if not dialog.is_connected("comando_ejecutado", _on_command_executed):
		dialog.connect("comando_ejecutado", _on_command_executed)
	
	return dialog

## Obtiene una confirmación de guardado del pool o crea una nueva
func _get_save_confirmation() -> Node:
	if confirmation_pool.size() > 0:
		return confirmation_pool.pop_back()
	
	var confirmation = Control.new()
	confirmation.set_script(SCN_CONFIRMACION_GUARDADO_SCRIPT)
	return confirmation

## Devuelve un diálogo al pool para reutilización
func _return_dialog_to_pool(dialog: Node) -> void:
	if dialog_layer.is_ancestor_of(dialog):
		dialog_layer.remove_child(dialog)
	
	# Resetear estado del diálogo
	if dialog.has_method("reset_state"):
		dialog.reset_state()
	
	# Determinar tipo y devolver al pool correspondiente
	if dialog.get_script() == SCN_CONFIRMACION_GUARDADO_SCRIPT:
		confirmation_pool.append(dialog)
	else:
		dialog_pool.append(dialog)

# =====================================
# CALLBACKS DE SEÑALES
# =====================================

## Se ejecuta cuando un diálogo de texto se completa
func _on_text_dialog_completed() -> void:
	print("🗨️ [DIALOG_MANAGER] Diálogo de texto completado")
	emit_signal("text_completed")
	close_current_dialog()

## Se ejecuta cuando un comando de escape es ejecutado desde el diálogo
func _on_command_executed(command: String, parameters: Array) -> void:
	print("🗨️ [DIALOG_MANAGER] Comando ejecutado: ", command, " | ", parameters)
	emit_signal("command_executed", command, parameters)

## Se ejecuta cuando se confirma/cancela el guardado
func _on_save_confirmation_result(accepted: bool, callback: Callable) -> void:
	print("🗨️ [DIALOG_MANAGER] Resultado confirmación guardado: ", accepted)
	emit_signal("confirmation_result", accepted)
	
	# Ejecutar callback específico
	if callback.is_valid():
		callback.call(accepted)
	
	close_current_dialog()

# =====================================
# UTILIDADES
# =====================================

## Verifica si hay algún diálogo activo
func is_any_dialog_active() -> bool:
	return is_dialog_active

## Limpia la cola de diálogos pendientes
func clear_dialog_queue() -> void:
	print("🗨️ [DIALOG_MANAGER] Limpiando cola de diálogos")
	for item in dialog_queue:
		_return_dialog_to_pool(item.dialog)
	dialog_queue.clear()

## Retorna el número de diálogos en cola
func get_dialog_count() -> int:
	return dialog_queue.size()

# =====================================
# DEBUG
# =====================================

## Información de depuración
func debug_info() -> Dictionary:
	return {
		"active": is_dialog_active,
		"current": current_dialog.get_class() if current_dialog else "none",
		"queue_size": dialog_queue.size(),
		"text_pool": dialog_pool.size(),
		"confirmation_pool": confirmation_pool.size()
	}
