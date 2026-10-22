# Duelo Estelar PC v0.5.0

## Instalación
1. Descomprime el ZIP en una carpeta sin espacios raros.
2. En Godot 4.3 o superior, selecciona **Importar** y elige `project.godot`.
3. Pulsa **F5**. Elige héroe, dificultad e Historia o Duelo.
4. Mando DualShock 4: stick izquierdo moverse, cuadrado/R2 atacar, L1/L2 bloquear, triángulo/R1 empujar, círculo esquivar, X saltar, L3 correr.
5. Teclado: WASD movimiento, J atacar, K bloquear, Q empuje, E esquivar, Espacio salto, Shift correr, C cámara, R reiniciar.

## Alcance de esta entrega
- Modelo humanoide procedural articulado con brazos, piernas, cabeza, túnica y sable.
- Robots B1 y B2 procedurales con cuerpo, cabeza y brazos diferenciados.
- Animaciones procedurales de correr, caminar, bloquear y atacar.
- Hangar modular de ciencia ficción con suelo técnico, techo, pilares, contenedores, luces y puerta final.
- Combate, selección de personaje, IA, dificultades, juego con DualShock 4 y misión 01 heredados de v0.4.0.

**No incluye** modelos licenciados, voces, música, cinemáticas, ni una campaña completa. Los personajes todavía son estilizados y el aspecto puede diferir sustancialmente del juego de PS2.

## Errores y diagnóstico
Si aparece un error en Godot, abre **Depurador > Errores**, copia mensaje, archivo y línea. Un aviso HIDAPI al conectar/desconectar el mando puede ser un problema del controlador físico, independiente del proyecto. Se recomienda verificar el mando en `joy.cpl` de Windows.

## Organización
- `scenes/arena.tscn`: escena principal.
- `scripts/game.gd`: menú, arena, modo historia y elementos de escenario.
- `scripts/fighter.gd`: IA, combate, modelos procedurales y animación.
