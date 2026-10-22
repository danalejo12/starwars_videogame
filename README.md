# Duelo Estelar PC

Juego de duelos con sables de luz en 3D hecho en **Godot 4.7** (renderizador Compatibility), inspirado en Star Wars. Fan game sin ánimo de lucro: todos los personajes, escenarios y sonidos se generan por código con primitivas y shaders; no incluye modelos, imágenes ni audio oficiales.

## Cómo jugar

1. Instala [Godot 4.7](https://godotengine.org/download).
2. Abre Godot, pulsa **Importar** y elige `project.godot` de esta carpeta.
3. Pulsa **F5**.

En la pantalla de selección elige un personaje para cada lado, el escenario y el modo.

## Modos

- **Versus 2 jugadores**: duelo local al mejor de 3 rondas.
- **Duelo vs IA**: 5 dificultades (Fácil a Leyenda).
- **Historia**: elimina 5 droides B1/B2 en el hangar y alcanza la salida.

## Personajes

Anakin Skywalker, Obi-Wan Kenobi, Luke Skywalker, Darth Vader, Darth Maul (doble hoja), Yoda, Mace Windu, Conde Dooku, Kylo Ren y Rey. Cada uno tiene aspecto, guardia, color de sable, velocidad, daño, defensa y alcance propios (`scripts/characters.gd`).

## Escenarios

- **Mustafar**: plataforma del complejo minero sobre un mar de lava, cascadas de lava, torres colectoras, brasas, ceniza y erupciones.
- **Hangar**: hangar de un crucero con consolas, contenedores y naves.

## Controles

| Acción | Jugador 1 (teclado) | Jugador 2 (teclado) | Mando (PS4) |
|---|---|---|---|
| Mover | WASD | Flechas | Stick izquierdo |
| Atacar | J / clic izquierdo | M / Num1 | Cuadrado / R2 |
| Bloquear | K / clic derecho | Coma / Num2 | L1 / L2 |
| Esquivar | E | Punto / Num3 | Círculo |
| Empuje de la Fuerza | Q | N / Num0 | Triángulo / R1 |
| Saltar | Espacio | Num Enter | X |
| Estilos de combate | 1 / 2 / 3 | Num7 / 8 / 9 | Cruceta |
| Aimbot on/off · cambiar objetivo | T · TAB | — | Share · cruceta abajo |
| Reiniciar | R | — | Options |

El jugador 1 usa el mando 1 y el jugador 2 el mando 2.

## Combate

- Sables agarrados con ambas manos mediante cinemática inversa; ataques direccionales con anticipación, golpe, seguimiento y paso de pies.
- Bloqueo direccional: el sable se coloca en la trayectoria del golpe y las hojas chocan en el punto real de contacto. Bloquear justo antes del impacto es una **parada perfecta** (cámara lenta y contraataque).
- El personaje se encara automáticamente a quien le ataca, y el aimbot fija el objetivo y acerca al personaje a la distancia ideal de golpe. La IA apunta según la dificultad.
- Sonido sintetizado: zumbido del sable según su velocidad, tajos, choques, quemaduras, encendido, empuje y blaster.

## Estructura

| Archivo | Contenido |
|---|---|
| `scripts/game.gd` | Menú, modos, rondas, cámara, HUD, efectos |
| `scripts/fighter.gd` | Luchador: movimiento, combate, IA, aimbot |
| `scripts/jedi_rig.gd` | Cuerpo procedimental, poses de sable e IK |
| `scripts/characters.gd` | Datos de los 10 personajes |
| `scripts/mustafar.gd` | Escenario de Mustafar |
| `scripts/sfx.gd` | Sonidos sintetizados |
| `scripts/autotest*.gd` | Pruebas automáticas (solo con argumentos de línea de comandos) |

Pruebas: `godot --path . -- --autotest <carpeta> [--mustafar|--historia|--versus]`, `-- --autotest-aim`, `-- --autotest-facing`, `-- --autotest-roster <carpeta>`.
