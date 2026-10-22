extends RefCounted
# Plantel de duelistas: aspecto, sable, estadisticas y guardia de cada personaje.
# Son figuras procedimentales originales inspiradas en los personajes (no modelos oficiales).
# Estadisticas: 1.0 = media. speed multiplica la velocidad, power el dano infligido,
# defense divide el dano recibido, reach acerca o aleja la distancia ideal de golpe.

const ORDER := ["anakin", "obiwan", "luke", "vader", "maul", "yoda", "mace", "dooku", "kylo", "rey"]

const DATA := {
	"anakin": {
		"name": "ANAKIN SKYWALKER", "title": "Caballero Jedi", "style": 2,
		"speed": 1.05, "power": 1.1, "defense": 0.95, "reach": 1.0, "scale": 1.0,
		"saber": Color(0.30, 0.55, 1.0),
		"skin": Color(0.86, 0.66, 0.52), "hair": Color(0.26, 0.16, 0.09), "hair_style": "long",
		"torso": Color(0.12, 0.085, 0.065), "over": Color(0.07, 0.05, 0.04), "sleeve": Color(0.11, 0.08, 0.06),
		"legs": Color(0.07, 0.055, 0.045), "boots": Color(0.03, 0.03, 0.03), "belt": Color(0.2, 0.13, 0.07),
		"glove_r": true, "wide_sleeves": true, "skirt": 0.44,
	},
	"obiwan": {
		"name": "OBI-WAN KENOBI", "title": "Maestro Jedi", "style": 0,
		"speed": 1.0, "power": 0.95, "defense": 1.2, "reach": 1.0, "scale": 1.0,
		"saber": Color(0.35, 0.75, 1.0),
		"skin": Color(0.86, 0.66, 0.52), "hair": Color(0.55, 0.27, 0.13), "hair_style": "short", "beard": true,
		"torso": Color(0.77, 0.65, 0.46), "over": Color(0.79, 0.67, 0.49), "sleeve": Color(0.89, 0.83, 0.70),
		"legs": Color(0.80, 0.71, 0.56), "boots": Color(0.27, 0.19, 0.12), "belt": Color(0.35, 0.23, 0.12),
		"wide_sleeves": true, "skirt": 0.44,
	},
	"luke": {
		"name": "LUKE SKYWALKER", "title": "Caballero Jedi", "style": 1,
		"speed": 1.08, "power": 1.0, "defense": 1.0, "reach": 1.0, "scale": 0.97,
		"saber": Color(0.25, 1.0, 0.35),
		"skin": Color(0.93, 0.74, 0.6), "hair": Color(0.7, 0.53, 0.28), "hair_style": "short",
		"torso": Color(0.07, 0.07, 0.08), "over": Color(0.09, 0.09, 0.1), "sleeve": Color(0.07, 0.07, 0.08),
		"legs": Color(0.06, 0.06, 0.07), "boots": Color(0.03, 0.03, 0.03), "belt": Color(0.05, 0.05, 0.05),
		"glove_r": true, "skirt": 0.3,
	},
	"vader": {
		"name": "DARTH VADER", "title": "Senor Oscuro de los Sith", "style": 0,
		"speed": 0.85, "power": 1.3, "defense": 1.25, "reach": 1.1, "scale": 1.1,
		"saber": Color(1.0, 0.12, 0.1),
		"skin": Color(0.05, 0.05, 0.06), "hair_style": "none", "helmet": "vader",
		"torso": Color(0.05, 0.05, 0.06), "over": Color(0.03, 0.03, 0.035), "sleeve": Color(0.05, 0.05, 0.06),
		"legs": Color(0.05, 0.05, 0.06), "boots": Color(0.02, 0.02, 0.02), "belt": Color(0.3, 0.3, 0.32),
		"glove_r": true, "glove_l": true, "skirt": 0.62, "cape": Color(0.02, 0.02, 0.02), "chest_box": true,
		"guard": "upright",
	},
	"maul": {
		"name": "DARTH MAUL", "title": "Aprendiz Sith", "style": 2,
		"speed": 1.2, "power": 0.95, "defense": 0.9, "reach": 1.0, "scale": 0.98,
		"saber": Color(1.0, 0.1, 0.08), "double": true,
		"skin": Color(0.62, 0.07, 0.08), "hair_style": "none", "face": "maul", "horns": true,
		"torso": Color(0.07, 0.07, 0.07), "over": Color(0.05, 0.05, 0.05), "sleeve": Color(0.06, 0.06, 0.06),
		"legs": Color(0.05, 0.05, 0.05), "boots": Color(0.03, 0.03, 0.03), "belt": Color(0.12, 0.12, 0.12),
		"glove_r": true, "glove_l": true, "wide_sleeves": true, "skirt": 0.52, "guard": "double",
	},
	"yoda": {
		"name": "MAESTRO YODA", "title": "Gran Maestro Jedi", "style": 2,
		"speed": 1.3, "power": 0.85, "defense": 1.05, "reach": 0.78, "scale": 0.56,
		"saber": Color(0.3, 1.0, 0.3),
		"skin": Color(0.47, 0.58, 0.32), "hair": Color(0.88, 0.88, 0.85), "hair_style": "wisps", "face": "yoda",
		"torso": Color(0.62, 0.52, 0.38), "over": Color(0.52, 0.43, 0.3), "sleeve": Color(0.58, 0.48, 0.34),
		"legs": Color(0.5, 0.42, 0.3), "boots": Color(0.47, 0.58, 0.32), "belt": Color(0.4, 0.3, 0.2),
		"wide_sleeves": true, "skirt": 0.6,
	},
	"mace": {
		"name": "MACE WINDU", "title": "Maestro del Consejo", "style": 1,
		"speed": 1.0, "power": 1.15, "defense": 1.1, "reach": 1.0, "scale": 1.03,
		"saber": Color(0.7, 0.25, 1.0),
		"skin": Color(0.33, 0.22, 0.15), "hair_style": "none",
		"torso": Color(0.55, 0.42, 0.28), "over": Color(0.42, 0.3, 0.19), "sleeve": Color(0.6, 0.47, 0.32),
		"legs": Color(0.45, 0.34, 0.22), "boots": Color(0.15, 0.1, 0.07), "belt": Color(0.25, 0.16, 0.1),
		"wide_sleeves": true, "skirt": 0.44,
	},
	"dooku": {
		"name": "CONDE DOOKU", "title": "Lord Sith Tyranus", "style": 0,
		"speed": 0.95, "power": 1.05, "defense": 1.15, "reach": 1.05, "scale": 1.05,
		"saber": Color(1.0, 0.15, 0.1), "curved": true,
		"skin": Color(0.88, 0.72, 0.62), "hair": Color(0.88, 0.88, 0.88), "hair_style": "short", "beard": true,
		"torso": Color(0.08, 0.06, 0.06), "over": Color(0.12, 0.08, 0.06), "sleeve": Color(0.08, 0.06, 0.06),
		"legs": Color(0.07, 0.05, 0.05), "boots": Color(0.03, 0.03, 0.03), "belt": Color(0.5, 0.42, 0.2),
		"skirt": 0.6, "cape": Color(0.22, 0.09, 0.05), "guard": "fencer",
	},
	"kylo": {
		"name": "KYLO REN", "title": "Lider de los Caballeros de Ren", "style": 2,
		"speed": 1.0, "power": 1.25, "defense": 1.0, "reach": 1.05, "scale": 1.08,
		"saber": Color(1.0, 0.1, 0.06), "crossguard": true, "unstable": true,
		"skin": Color(0.05, 0.05, 0.05), "hair_style": "none", "helmet": "kylo",
		"torso": Color(0.04, 0.04, 0.04), "over": Color(0.06, 0.06, 0.06), "sleeve": Color(0.05, 0.05, 0.05),
		"legs": Color(0.04, 0.04, 0.04), "boots": Color(0.02, 0.02, 0.02), "belt": Color(0.08, 0.08, 0.08),
		"glove_r": true, "glove_l": true, "wide_sleeves": true, "skirt": 0.6, "cape": Color(0.03, 0.03, 0.03),
	},
	"rey": {
		"name": "REY", "title": "Ultima de los Jedi", "style": 1,
		"speed": 1.12, "power": 0.95, "defense": 1.0, "reach": 1.0, "scale": 0.94,
		"saber": Color(1.0, 0.85, 0.15),
		"skin": Color(0.9, 0.72, 0.58), "hair": Color(0.3, 0.19, 0.11), "hair_style": "buns",
		"torso": Color(0.88, 0.82, 0.7), "over": Color(0.82, 0.75, 0.62), "sleeve": Color(0.55, 0.52, 0.48),
		"legs": Color(0.78, 0.72, 0.6), "boots": Color(0.3, 0.22, 0.15), "belt": Color(0.4, 0.28, 0.17),
		"skirt": 0.36,
	},
}

static func get_data(key: String) -> Dictionary:
	return DATA.get(key, DATA["anakin"])

static func display_name(key: String) -> String:
	return String(get_data(key)["name"])
