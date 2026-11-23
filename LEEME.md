# Crypt Access

Crypt Access hace que Crypt of the NecroDancer (Steam, versión Synchrony 4.2) se pueda jugar sin ver. Habla
a través de tu lector de pantalla (NVDA, JAWS, Narrador, o la voz de Windows si no hay lector) y añade
sonidos posicionales para enemigos, objetos, paredes y salidas.

## Instalación

1. Cierra el juego.
2. Extrae el zip completo en cualquier carpeta.
3. Ejecuta `install.bat`. Encuentra el juego a través de Steam, copia el mod en
   `%LOCALAPPDATA%\NecroDancer\mods\CryptAccess` y añade dos entradas al archivo
   `Necrodancer64\config.json` del juego (guarda una copia `config.json.cryptaccess.bak`).
4. Inicia el juego. Oirás "Crypt Access cargado. Pulsa F1 para la ayuda."

Después de una actualización del juego, o si Steam verifica los archivos, `config.json` puede volver a su
estado original. Si el juego arranca en silencio, ejecuta `install.bat` otra vez.

Si no encuentra el juego, abre una consola en la carpeta extraída y ejecuta:

```
install.bat -GameDir "D:\Ruta\A\Crypt of the NecroDancer"
```

Para quitar el mod, ejecuta `uninstall.bat`.

Notas:

- El juego desactiva el envío a las clasificaciones mientras haya un mod de scripts cargado.
- El mod sigue el idioma del juego.

## Primeros pasos

- La pantalla de título dice "Pulsa cualquier tecla". En una partida nueva sigue la calibración de
  latencia: su primer paso es visual, así que pulsa Escape y confirma Sí para omitirla, o pulsa Arriba
  en cada pulso de la música.
- En una partida nueva empieza un tutorial breve. Retroceso lo omite.
- En el vestíbulo, usa el escáner (Avance de página) para encontrar las escaleras: Zona 1, Selección de
  personaje, Modos adicionales y otras. Camina sobre una escalera para usarla.
- Para jugar por turnos, elige al Bardo en la sala de personajes (camina contra él y confirma), o pon
  Ritmo en "Modo Sin compás" en las opciones de modos adicionales. Con los demás personajes te mueves al
  ritmo de la música.

## Teclas

En todas partes:

- F1: ayuda de la pantalla actual, como una lista. Arriba y Abajo la leen, Escape la cierra.
- R: repetir lo último dicho.
- Control más Arriba o Abajo: leer los detalles de lo último enfocado (la vida y el próximo movimiento de un
  enemigo, el precio y la descripción de un objeto, los detalles de un ajuste), línea a línea.
- Control más Izquierda o Derecha: cambiar entre las listas Detalles, Eventos, Alrededores e Inventario.

En los menús funcionan las teclas del juego (flechas, Intro, Escape, Izquierda y Derecha para cambiar
valores). Cada menú dice su título, su mensaje y la opción elegida con su posición. Los campos de texto
repiten lo que escribes.

Durante el juego:

- Flechas: moverse, cavar y atacar. Las combinaciones de objetos del juego (por ejemplo Arriba más Abajo
  para lanzar) están al final de la lista de inventario (I, y después Control más Arriba).
- Espacio: congelar el juego para pensar; Espacio otra vez continúa con una cuenta atrás.
- Avance y Retroceso de página: la siguiente y la anterior cosa a la vista, la más cercana primero, con su
  dirección en casillas ("Esqueleto, 2 izquierda, 1 arriba, 1 de 5"). Inicio la repite actualizada.
- Mayúsculas más Avance o Retroceso de página: categoría del escáner (todo, enemigos, objetos, salidas y
  puertas, personajes y santuarios, trampas, carteles).
- N: la ruta a pie hasta la cosa elegida en el escáner ("3 derecha, 2 abajo, cava hacia arriba").
- U: la ruta a la zona sin explorar más cercana.
- B: baliza. Suena en cada pulso desde el siguiente giro de la ruta hacia la cosa elegida (o la zona sin
  explorar) hasta que llegas. B otra vez la apaga.
- Mayúsculas más flechas: mover un cursor de revisión por el mapa sin moverte; Fin lo devuelve a ti.
- C: las cuatro casillas a tu alrededor.
- H: vida. G: oro y diamantes. I: inventario. L: profundidad, nivel, tiempo de canción restante y si la
  salida está cerrada. M: multiplicador de monedas.

## Sonidos

- Los enemigos zumban, los objetos tintinean, las paredes suenan sordas después de cada paso.
- Izquierda y derecha en estéreo. Más agudo significa más arriba en el mapa, más grave más abajo. Más fuerte
  es más cerca.
- Un sonido agudo ascendente significa que un enemigo a tu lado actúa en el próximo pulso.

## Ajustes

En el juego: Opciones, Ajustes de mods, Crypt Access. Ahí puedes activar o desactivar los sonidos de
enemigos, objetos y paredes, ajustar su alcance y volumen, añadir un tic de metrónomo, congelar al empezar
cada nivel y elegir si se anuncian los golpes a enemigos y la posición en los menús.

## Multijugador

- El cooperativo local (dos jugadores en un ordenador) funciona: el mod sigue al jugador 1, muestra al
  otro jugador en el escáner y dice "Tu compañero ha muerto" cuando cae.
- Partidas en línea: el juego solo carga mods empaquetados en línea, y Crypt Access se instala sin
  empaquetar, así que el juego lo desactiva al crear o unirse a una partida en línea. El ajuste avanzado
  del juego "Modo de desarrollo de mods de red" (Opciones, Ajustes de mods, Ajustes del sistema de mods,
  con los ajustes avanzados visibles) permite cargar mods sin empaquetar en línea, para desarrollo y
  pruebas; entonces todos los jugadores necesitan el mod.
- En un ordenador sin el cambio de config.json del instalador (un amigo que ve), el mod se queda en
  silencio y deja todas las teclas al juego.

## Créditos y licencias

- La voz usa Prism; sus licencias están en `CryptAccess\licenses`.
- Crypt of the NecroDancer es de Brace Yourself Games. Este mod no contiene código ni recursos del juego.
