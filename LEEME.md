# Crypt Access

Crypt Access hace que Crypt of the NecroDancer (Steam, versión Synchrony 4.2) se pueda jugar sin ver. Habla
a través de tu lector de pantalla (NVDA, JAWS, Narrador, o la voz de Windows si no hay lector) y añade
sonidos posicionales para enemigos, objetos, paredes y salidas.

## Instalación

Lo más fácil: descarga `CryptOfTheNecroDancerAccessibilityInstaller.exe` de la última versión en
https://github.com/gomods1/crypt_access/releases y ejecútalo. Encuentra el juego, descarga el mod y luego
puede actualizarlo o desinstalarlo. O instala desde el zip:

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
- Un doble pitido agudo significa que un enemigo actúa en el próximo pulso. Por defecto solo suena para
  un enemigo a tu lado; el ajuste "Sonido de enemigo a punto de actuar" puede hacerlo sonar para todos
  los enemigos al alcance (útil para emboscarlos), o nunca.

## Descripciones de lo que hay en pantalla

- Cinemáticas: los vídeos de la historia y de introducción se describen escena por escena entre las
  frases habladas. También se describen las pantallas de título, y en los créditos se nombra a cada
  monstruo que pasa bailando.
- Personajes, enemigos, jefes y tenderos: selecciona uno con Avance de página y Control más Arriba lee su
  vida y su próximo movimiento, cómo es y cómo se comporta, cuánto daño hace y cada cuántos pulsos actúa.
  La cuadrícula de personajes y los diálogos con retrato (personajes desbloqueados, la confirmación de
  Bard) describen el retrato.
- La primera vez que ves un tipo nuevo de enemigo, se describe una vez. El mod recuerda los que ya
  conoces.
- Lugares: el aspecto de cada zona se describe al entrar en ella por primera vez en una partida, y los
  niveles de jefe y los jefes cuando aparece su presentación.
- Combates: el mod dice cuándo un enemigo te agarra o te suelta, cuándo te congelan o te confunden y
  cuándo se te pasa, cuándo un enemigo embiste, un mímico o un enemigo dormido despierta, un espadachín
  desvía tu golpe, un enemigo lanza un hechizo (aliento de fuego o de hielo, rayos, viento, confusión,
  invocaciones), explota algo o aparece un enemigo de la nada.

## Ajustes

En el juego: Opciones, Ajustes de mods, Crypt Access. Ahí puedes activar o desactivar los sonidos de
enemigos, objetos y paredes, elegir qué enemigos avisan antes de actuar, ajustar su alcance y volumen, añadir un tic de metrónomo, congelar al empezar
cada nivel y elegir si se anuncian los golpes a enemigos y la posición en los menús. Cuatro interruptores
activan o desactivan las descripciones: cinemáticas y pantallas de título, tipos nuevos de enemigos,
combates, y zonas, niveles de jefe y jefes.

## Modos en los que el mod no puede ayudar

- El desafío diario: el juego descarga todos los mods para jugarlo, así que ahí no se oye nada.
- El editor de niveles: se maneja con el ratón. El mod lo avisa al entrar y desactiva sus teclas para que
  lleguen al editor.

## Multijugador

- El cooperativo local (dos jugadores en un ordenador) funciona: el mod sigue al jugador 1, muestra al
  otro jugador en el escáner con su nombre y dice cuándo muere.
- Las partidas en línea funcionan cuando todos los jugadores tienen el mismo paquete de Crypt Access:
  - El juego solo lleva mods empaquetados a una partida en línea, y cada jugador carga exactamente los
    mods del anfitrión. El instalador pone el paquete `CryptAccess-<versión>.necromod` en
    `%LOCALAPPDATA%\NecroDancer\mods`, y el mod lo vuelve a poner ahí cada vez que arranca el juego. Al
    crear una partida, el juego cambia Crypt Access a ese paquete por sí solo.
  - Tus amigos necesitan el mismo archivo: que descarguen `CryptAccess-<versión>.necromod` de la misma
    versión publicada y lo pongan en su carpeta `%LOCALAPPDATA%\NecroDancer\mods` (el juego la crea). No
    ejecutan el instalador, así que el mod se queda en silencio en su ordenador y deja todas las teclas a
    su juego.
  - Crea la partida por dirección IP, o desactiva "Habilitar juego cruzado" en el menú de anfitrión antes
    de crearla. Con el juego cruzado activado, el juego desactiva todos los mods que su servidor no ha
    aprobado, Crypt Access incluido. El menú de anfitrión te avisa.
  - Cuando llega la lista de mods de la partida, el mod dice "Crypt Access está activo en esta partida en
    línea", o explica por qué el juego va a desactivarlo (juego cruzado, falta el paquete, otra versión).
- En una partida en línea:
  - Se leen en voz alta los mensajes del chat y los avisos del juego (alguien entra o sale). T abre el
    chat. Ajuste: "Leer en voz alta los mensajes del chat".
  - O: los jugadores de la partida, con personaje, vida y dónde están. Control más Arriba lee la lista
    jugador por jugador.
  - El escáner nombra a los demás jugadores ("Ana, Melody"), y sus muertes se anuncian con su nombre.
  - Cuando mueres observas a otro jugador: el mod dice a quién, Izquierda o Derecha cambia e Intro
    vuelve a la partida cuando el juego lo permite. El escáner y las teclas de estado siguen al jugador
    que observas.
  - Se anuncian las pausas del anfitrión, su final y el aviso de "problemas de red" del juego. Solo el
    anfitrión puede pausar con Espacio.
- El desafío diario desactiva todos los mods, en línea o no.

## Créditos y licencias

- La voz usa Prism; sus licencias están en `CryptAccess\licenses`.
- Crypt of the NecroDancer es de Brace Yourself Games. Este mod no contiene código ni recursos del juego.
