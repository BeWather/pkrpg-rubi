extends RefCounted
## Orden regional de Hoenn. Solo fixture de F6: no consulta BD ni guardado.
## Nacional, color, altura y peso copiados de poke.db; tipos de 3.ª gen
## (la BD tiene los actuales: RALTS/KIRLIA/GARDEVOIR añaden HADA).

## [nombre, nacional, tipos, color, altura (m), peso (kg)]
const ESPECIES: Array = [
	["TREECKO", 252, ["PLANTA"], "Green", 0.5, 5.0],
	["GROVYLE", 253, ["PLANTA"], "Green", 0.9, 21.6],
	["SCEPTILE", 254, ["PLANTA"], "Green", 1.7, 52.2],
	["TORCHIC", 255, ["FUEGO"], "Red", 0.4, 2.5],
	["COMBUSKEN", 256, ["FUEGO", "LUCHA"], "Red", 0.9, 19.5],
	["BLAZIKEN", 257, ["FUEGO", "LUCHA"], "Red", 1.9, 52.0],
	["MUDKIP", 258, ["AGUA"], "Blue", 0.4, 7.6],
	["MARSHTOMP", 259, ["AGUA", "TIERRA"], "Blue", 0.7, 28.0],
	["SWAMPERT", 260, ["AGUA", "TIERRA"], "Blue", 1.5, 81.9],
	["POOCHYENA", 261, ["SINIESTRO"], "Gray", 0.5, 13.6],
	["MIGHTYENA", 262, ["SINIESTRO"], "Gray", 1.0, 37.0],
	["ZIGZAGOON", 263, ["NORMAL"], "Brown", 0.4, 17.5],
	["LINOONE", 264, ["NORMAL"], "White", 0.5, 32.5],
	["WURMPLE", 265, ["BICHO"], "Red", 0.3, 3.6],
	["SILCOON", 266, ["BICHO"], "White", 0.6, 10.0],
	["BEAUTIFLY", 267, ["BICHO", "VOLADOR"], "Yellow", 1.0, 28.4],
	["CASCOON", 268, ["BICHO"], "Purple", 0.7, 11.5],
	["DUSTOX", 269, ["BICHO", "VENENO"], "Green", 1.2, 31.6],
	["LOTAD", 270, ["AGUA", "PLANTA"], "Green", 0.5, 2.6],
	["LOMBRE", 271, ["AGUA", "PLANTA"], "Green", 1.2, 32.5],
	["LUDICOLO", 272, ["AGUA", "PLANTA"], "Green", 1.5, 55.0],
	["SEEDOT", 273, ["PLANTA"], "Brown", 0.5, 4.0],
	["NUZLEAF", 274, ["PLANTA", "SINIESTRO"], "Brown", 1.0, 28.0],
	["SHIFTRY", 275, ["PLANTA", "SINIESTRO"], "Brown", 1.3, 59.6],
	["TAILLOW", 276, ["NORMAL", "VOLADOR"], "Blue", 0.3, 2.3],
	["SWELLOW", 277, ["NORMAL", "VOLADOR"], "Blue", 0.7, 19.8],
	["WINGULL", 278, ["AGUA", "VOLADOR"], "White", 0.6, 9.5],
	["PELIPPER", 279, ["AGUA", "VOLADOR"], "Yellow", 1.2, 28.0],
	["RALTS", 280, ["PSIQUICO"], "White", 0.4, 6.6],
	["KIRLIA", 281, ["PSIQUICO"], "White", 0.8, 20.2],
	["GARDEVOIR", 282, ["PSIQUICO"], "White", 1.6, 48.4],
	["SURSKIT", 283, ["BICHO", "AGUA"], "Blue", 0.5, 1.7],
	["MASQUERAIN", 284, ["BICHO", "VOLADOR"], "Blue", 0.8, 3.6],
	["SHROOMISH", 285, ["PLANTA"], "Brown", 0.4, 4.5],
	["BRELOOM", 286, ["PLANTA", "LUCHA"], "Green", 1.2, 39.2],
	["SLAKOTH", 287, ["NORMAL"], "Brown", 0.8, 24.0],
	["VIGOROTH", 288, ["NORMAL"], "White", 1.4, 46.5],
	["SLAKING", 289, ["NORMAL"], "Brown", 2.0, 130.5],
	["ABRA", 63, ["PSIQUICO"], "Brown", 0.9, 19.5],
	["KADABRA", 64, ["PSIQUICO"], "Brown", 1.3, 56.5],
	["ALAKAZAM", 65, ["PSIQUICO"], "Brown", 1.5, 48.0],
]
const VISTOS: Array[int] = [1, 4, 7, 10, 11, 12, 14, 15, 16, 19, 22, 25, 27, 29, 32, 34, 35, 39, 40]
const ATRAPADOS: Array[int] = [1, 4, 7, 10, 12, 14, 19, 25, 29, 34]


static func crear() -> Array[Dictionary]:
	var datos: Array[Dictionary] = []
	for i in ESPECIES.size():
		var especie: Array = ESPECIES[i]
		datos.append({
			"numero": i + 1,
			"nacional": especie[1],
			"nombre": especie[0],
			"tipos": especie[2],
			"color": especie[3],
			"altura": especie[4],
			"peso": especie[5],
			"visto": i + 1 in VISTOS,
			"atrapado": i + 1 in ATRAPADOS,
		})
	return datos
