extends Resource
class_name Partida

var nombre_jugador: String = "MA7AS"
var mapa_actual
var mapa_posicion: Vector2 = Vector2(0,0)

func _init():
	mapa_actual = "villa_raiz"
	mapa_actual.nombre = "mapa_1"
	mapa_actual.posicion = mapa_posicion
	mapa_actual.nombre_jugador = nombre_jugador
	mapa_actual.nombre_mapa = "mapa_1"

func save_player_data():
	ResourceSaver.save(self, "res://partida/partida.tres")

func load_player_data():
	return load("res://partida/partida.tres")