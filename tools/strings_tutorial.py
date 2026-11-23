"""Tutorial lesson strings for every language. Run: python tools/strings_tutorial.py (adds or updates keys)."""
import os
import re

S = {
    "setting.tutorialHints": {
        "EN": "Tutorial lessons for the mod keys", "ES": "Lecciones del tutorial sobre las teclas del mod",
        "DE": "Tutorial-Lektionen zu den Mod-Tasten", "FR": "Leçons du tutoriel sur les touches du mod",
        "IT": "Lezioni del tutorial sui tasti della mod", "PTBR": "Lições do tutorial sobre as teclas do mod",
        "RU": "Уроки обучения по клавишам мода", "JA": "MODキーのチュートリアル解説",
        "KO": "모드 키 튜토리얼 안내", "ZHCN": "模组按键教程提示", "ZHTW": "模組按鍵教學提示",
    },
    "tutorial.start": {
        "EN": "Crypt Access tutorial. Move with the arrow keys, one step on each beat of the music. If you need time to think, Space freezes the game and Space again resumes. F1 lists every key at any moment.",
        "ES": "Tutorial de Crypt Access. Muévete con las flechas, un paso en cada pulso de la música. Si necesitas tiempo para pensar, Espacio congela el juego y Espacio otra vez continúa. F1 te dice todas las teclas en cualquier momento.",
        "DE": "Crypt-Access-Tutorial. Bewege dich mit den Pfeiltasten, ein Schritt auf jeden Beat der Musik. Wenn du Zeit zum Nachdenken brauchst, friert die Leertaste das Spiel ein, und nochmals Leertaste setzt es fort. F1 nennt dir jederzeit alle Tasten.",
        "FR": "Tutoriel de Crypt Access. Déplacez-vous avec les flèches, un pas à chaque pulsation de la musique. Pour prendre le temps de réfléchir, Espace fige le jeu et Espace encore le relance. F1 donne toutes les touches à tout moment.",
        "IT": "Tutorial di Crypt Access. Muoviti con le frecce, un passo a ogni battito della musica. Se ti serve tempo per pensare, la barra spaziatrice blocca il gioco e premendola di nuovo riprende. F1 elenca tutti i tasti in qualsiasi momento.",
        "PTBR": "Tutorial do Crypt Access. Mova-se com as setas, um passo a cada batida da música. Se precisar de tempo para pensar, Espaço congela o jogo e Espaço de novo continua. F1 lista todas as teclas a qualquer momento.",
        "RU": "Обучение Crypt Access. Двигайтесь стрелками, по шагу на каждый такт музыки. Если нужно подумать, Пробел замораживает игру, повторный Пробел продолжает. F1 в любой момент перечисляет все клавиши.",
        "JA": "Crypt Access のチュートリアル。矢印キーで、音楽のビートごとに1歩ずつ動きます。考える時間が必要なら、スペースキーでゲームを止め、もう一度押すと再開します。F1 でいつでもすべてのキーを確認できます。",
        "KO": "Crypt Access 튜토리얼. 화살표 키로 음악의 박자마다 한 걸음씩 움직입니다. 생각할 시간이 필요하면 스페이스로 게임을 멈추고 다시 스페이스로 계속합니다. F1은 언제든 모든 키를 알려 줍니다.",
        "ZHCN": "Crypt Access 教程。用方向键移动，音乐每一拍走一步。需要思考时，按空格键冻结游戏，再按一次继续。随时按 F1 查看所有按键。",
        "ZHTW": "Crypt Access 教學。用方向鍵移動，音樂每一拍走一步。需要思考時，按空白鍵凍結遊戲，再按一次繼續。隨時按 F1 查看所有按鍵。",
    },
    "tutorial.moved": {
        "EN": "After each step you hear a soft thud from every side that has a wall. C tells you the four tiles around you.",
        "ES": "Después de cada paso oyes un golpe sordo por cada lado donde hay pared. C te dice las cuatro casillas a tu alrededor.",
        "DE": "Nach jedem Schritt hörst du ein dumpfes Geräusch von jeder Seite, an der eine Wand ist. C nennt dir die vier Felder um dich herum.",
        "FR": "Après chaque pas, vous entendez un bruit sourd de chaque côté où se trouve un mur. C décrit les quatre cases autour de vous.",
        "IT": "Dopo ogni passo senti un tonfo da ogni lato in cui c'è un muro. C ti descrive le quattro caselle intorno a te.",
        "PTBR": "Depois de cada passo você ouve um baque de cada lado que tem parede. C descreve as quatro casas ao seu redor.",
        "RU": "После каждого шага вы слышите глухой звук с каждой стороны, где есть стена. C описывает четыре клетки вокруг вас.",
        "JA": "1歩ごとに、壁のある方向からにぶい音が鳴ります。C で周りの4マスを確認できます。",
        "KO": "한 걸음마다 벽이 있는 쪽에서 둔탁한 소리가 납니다. C는 주변 네 칸을 알려 줍니다.",
        "ZHCN": "每走一步，有墙的方向会传来一声闷响。按 C 查看你周围的四个格子。",
        "ZHTW": "每走一步，有牆的方向會傳來一聲悶響。按 C 查看你周圍的四個格子。",
    },
    "tutorial.item": {
        "EN": "There is something in sight. Page Down lists what you can see, nearest first, with how many tiles left, right, up or down. Page Up goes back, Home repeats. Items chime from where they are.",
        "ES": "Hay algo a la vista. Avance de página te dice lo que puedes ver, lo más cercano primero, con cuántas casillas a la izquierda, derecha, arriba o abajo. Retroceso de página vuelve atrás e Inicio repite. Los objetos tintinean desde donde están.",
        "DE": "Es ist etwas in Sicht. Bild ab nennt, was du sehen kannst, das Nächste zuerst, mit wie vielen Feldern links, rechts, oben oder unten. Bild auf geht zurück, Pos1 wiederholt. Gegenstände klingeln von ihrem Platz aus.",
        "FR": "Il y a quelque chose en vue. Page suivante énumère ce que vous voyez, le plus proche d'abord, avec le nombre de cases à gauche, à droite, en haut ou en bas. Page précédente revient en arrière, Origine répète. Les objets tintent depuis leur position.",
        "IT": "C'è qualcosa in vista. Pagina giù elenca ciò che vedi, dal più vicino, con quante caselle a sinistra, a destra, su o giù. Pagina su torna indietro, Inizio ripete. Gli oggetti tintinnano dal punto in cui si trovano.",
        "PTBR": "Há algo à vista. Page Down lista o que você vê, o mais próximo primeiro, com quantas casas à esquerda, direita, acima ou abaixo. Page Up volta, Home repete. Os itens tilintam de onde estão.",
        "RU": "Что-то в поле зрения. Page Down перечисляет то, что видно, начиная с ближайшего, и сколько клеток влево, вправо, вверх или вниз. Page Up возвращает назад, Home повторяет. Предметы звенят оттуда, где лежат.",
        "JA": "何かが見えています。Page Down で見えるものを近い順に、左右上下に何マスかと一緒に読み上げます。Page Up で戻り、Home で繰り返します。アイテムはその場所からチャイムが鳴ります。",
        "KO": "무언가가 보입니다. Page Down은 보이는 것을 가까운 순서대로, 왼쪽, 오른쪽, 위, 아래로 몇 칸인지와 함께 알려 줍니다. Page Up은 이전으로, Home은 반복합니다. 아이템은 있는 곳에서 종소리가 납니다.",
        "ZHCN": "视野中有东西。按 Page Down 由近到远列出可见的东西，并说明在左右上下几格。Page Up 返回，Home 重复。物品会从所在位置发出铃声。",
        "ZHTW": "視野中有東西。按 Page Down 由近到遠列出可見的東西，並說明在左右上下幾格。Page Up 返回，Home 重複。物品會從所在位置發出鈴聲。",
    },
    "tutorial.chest": {
        "EN": "A chest is in sight. Walk into it to open it; a locked chest needs a key. To get somewhere, select it with Page Down and press N: you hear the walkable route, such as 2 right, 1 down.",
        "ES": "Hay un cofre a la vista. Camina contra él para abrirlo; un cofre cerrado necesita una llave. Para llegar a un sitio, elígelo con Avance de página y pulsa N: oirás la ruta a pie, por ejemplo 2 derecha, 1 abajo.",
        "DE": "Eine Truhe ist in Sicht. Laufe dagegen, um sie zu öffnen; eine verschlossene Truhe braucht einen Schlüssel. Um irgendwo hinzukommen, wähle es mit Bild ab und drücke N: Du hörst den Weg, zum Beispiel 2 nach rechts, 1 nach unten.",
        "FR": "Un coffre est en vue. Avancez dessus pour l'ouvrir ; un coffre verrouillé demande une clé. Pour aller quelque part, choisissez-le avec Page suivante et appuyez sur N : vous entendez le chemin, par exemple 2 à droite, 1 en bas.",
        "IT": "C'è uno scrigno in vista. Muoviti contro di esso per aprirlo; uno scrigno chiuso richiede una chiave. Per raggiungere un punto, sceglilo con Pagina giù e premi N: sentirai il percorso, per esempio 2 a destra, 1 giù.",
        "PTBR": "Há um baú à vista. Ande contra ele para abri-lo; um baú trancado precisa de uma chave. Para chegar a um lugar, escolha-o com Page Down e pressione N: você ouve o caminho, por exemplo 2 para a direita, 1 para baixo.",
        "RU": "В поле зрения сундук. Шагните в него, чтобы открыть; запертому сундуку нужен ключ. Чтобы куда-то дойти, выберите цель через Page Down и нажмите N: вы услышите путь, например 2 вправо, 1 вниз.",
        "JA": "宝箱が見えています。ぶつかると開きます。カギのかかった宝箱にはカギが必要です。どこかへ行くには Page Down で選んで N を押すと、たとえば「右に2、下に1」のように道順が聞こえます。",
        "KO": "상자가 보입니다. 부딪히면 열립니다. 잠긴 상자는 열쇠가 필요합니다. 어딘가로 가려면 Page Down으로 고르고 N을 누르세요. 예를 들어 오른쪽 2, 아래 1처럼 길을 알려 줍니다.",
        "ZHCN": "视野中有宝箱。走向它即可打开；上锁的宝箱需要钥匙。想去某处时，用 Page Down 选中它再按 N，会听到路线，例如右 2，下 1。",
        "ZHTW": "視野中有寶箱。走向它即可打開；上鎖的寶箱需要鑰匙。想去某處時，用 Page Down 選中它再按 N，會聽到路線，例如右 2，下 1。",
    },
    "tutorial.enemy": {
        "EN": "An enemy is near. Enemies buzz from where they are on every beat: left or right in your ears, higher when they are above you, lower when below, louder when close. A sharp rising sound means an enemy next to you acts on the next beat. Select one with Page Down, then Control plus Up tells its health and when it moves. Walk into an enemy to attack it.",
        "ES": "Hay un enemigo cerca. Los enemigos zumban desde donde están en cada pulso: a la izquierda o a la derecha en tus oídos, más agudos si están arriba de ti, más graves si están abajo, más fuertes si están cerca. Un sonido agudo ascendente significa que un enemigo a tu lado actúa en el próximo pulso. Elige uno con Avance de página y Control más Arriba te dice su vida y cuándo se mueve. Camina contra un enemigo para atacarlo.",
        "DE": "Ein Gegner ist in der Nähe. Gegner summen auf jedem Beat von ihrem Platz aus: links oder rechts in deinen Ohren, höher, wenn sie über dir sind, tiefer, wenn sie unter dir sind, lauter, wenn sie nah sind. Ein scharfer, steigender Ton heißt, dass ein Gegner neben dir auf dem nächsten Beat handelt. Wähle einen mit Bild ab, dann nennt Strg plus Pfeil hoch seine Lebenspunkte und wann er sich bewegt. Laufe gegen einen Gegner, um ihn anzugreifen.",
        "FR": "Un ennemi est proche. Les ennemis bourdonnent depuis leur position à chaque pulsation : à gauche ou à droite dans vos oreilles, plus aigus quand ils sont au-dessus de vous, plus graves en dessous, plus forts quand ils sont proches. Un son aigu qui monte signifie qu'un ennemi à côté de vous agit à la prochaine pulsation. Choisissez-en un avec Page suivante, puis Ctrl plus flèche haut donne sa vie et quand il bouge. Avancez sur un ennemi pour l'attaquer.",
        "IT": "C'è un nemico vicino. I nemici ronzano dal loro punto a ogni battito: a sinistra o a destra nelle orecchie, più acuti se sono sopra di te, più gravi se sono sotto, più forti se sono vicini. Un suono acuto che sale significa che un nemico accanto a te agisce al prossimo battito. Scegline uno con Pagina giù, poi Ctrl più freccia su dice la sua vita e quando si muove. Muoviti contro un nemico per attaccarlo.",
        "PTBR": "Há um inimigo por perto. Os inimigos zumbem de onde estão a cada batida: à esquerda ou à direita nos ouvidos, mais agudos quando estão acima de você, mais graves abaixo, mais altos quando perto. Um som agudo que sobe significa que um inimigo ao seu lado age na próxima batida. Escolha um com Page Down e Control mais seta para cima diz a vida dele e quando ele se move. Ande contra um inimigo para atacá-lo.",
        "RU": "Рядом враг. Враги жужжат со своего места на каждый такт: слева или справа в ушах, выше, если они над вами, ниже, если под вами, громче, если близко. Резкий нарастающий звук значит, что враг рядом с вами действует на следующий такт. Выберите врага через Page Down, затем Control плюс стрелка вверх скажет его здоровье и когда он ходит. Шагните во врага, чтобы атаковать.",
        "JA": "敵が近くにいます。敵はビートごとにその場所からブーンと鳴ります。左右は耳で、上にいると高く、下にいると低く、近いほど大きく聞こえます。鋭く上がる音は、となりの敵が次のビートで動くという合図です。Page Down で選び、Ctrl と上矢印で体力と動くタイミングがわかります。敵にぶつかると攻撃します。",
        "KO": "적이 가까이 있습니다. 적은 박자마다 있는 곳에서 윙 소리를 냅니다. 왼쪽 오른쪽은 귀로, 위에 있으면 높게, 아래에 있으면 낮게, 가까우면 크게 들립니다. 날카롭게 올라가는 소리는 옆의 적이 다음 박자에 움직인다는 뜻입니다. Page Down으로 고른 뒤 Ctrl과 위 화살표를 누르면 체력과 움직이는 때를 알려 줍니다. 적에게 부딪히면 공격합니다.",
        "ZHCN": "附近有敌人。敌人每拍都会从所在位置发出嗡嗡声：左右在耳中区分，在你上方更高，在下方更低，越近越响。尖锐上升的声音表示你旁边的敌人会在下一拍行动。用 Page Down 选中一个，再按 Ctrl 加上方向键可听到它的生命值和行动时机。走向敌人即可攻击。",
        "ZHTW": "附近有敵人。敵人每拍都會從所在位置發出嗡嗡聲：左右在耳中區分，在你上方更高，在下方更低，越近越響。尖銳上升的聲音表示你旁邊的敵人會在下一拍行動。用 Page Down 選中一個，再按 Ctrl 加上方向鍵可聽到它的生命值和行動時機。走向敵人即可攻擊。",
    },
    "tutorial.kill": {
        "EN": "Well done. Shift plus Page Down changes what the scanner lists: everything, enemies, items, exits and doors, characters and shrines, traps, signs. H tells your health, G your gold.",
        "ES": "Bien hecho. Mayúsculas más Avance de página cambia lo que lista el escáner: todo, enemigos, objetos, salidas y puertas, personajes y santuarios, trampas, carteles. H te dice tu vida y G tu oro.",
        "DE": "Gut gemacht. Umschalt plus Bild ab ändert, was der Scanner auflistet: alles, Gegner, Gegenstände, Ausgänge und Türen, Figuren und Schreine, Fallen, Schilder. H nennt deine Lebenspunkte, G dein Gold.",
        "FR": "Bien joué. Maj plus Page suivante change ce que liste le scanner : tout, ennemis, objets, sorties et portes, personnages et sanctuaires, pièges, panneaux. H donne votre vie, G votre or.",
        "IT": "Ben fatto. Maiusc più Pagina giù cambia ciò che elenca lo scanner: tutto, nemici, oggetti, uscite e porte, personaggi e santuari, trappole, cartelli. H dice la tua vita, G il tuo oro.",
        "PTBR": "Muito bem. Shift mais Page Down muda o que o scanner lista: tudo, inimigos, itens, saídas e portas, personagens e santuários, armadilhas, placas. H diz sua vida e G seu ouro.",
        "RU": "Отлично. Shift плюс Page Down меняет то, что показывает сканер: всё, врагов, предметы, выходы и двери, персонажей и алтари, ловушки, надписи. H говорит здоровье, G золото.",
        "JA": "よくできました。Shift と Page Down でスキャナーの対象を切り替えます。すべて、敵、アイテム、出口とドア、キャラクターとほこら、トラップ、看板。H で体力、G でゴールドがわかります。",
        "KO": "잘했습니다. Shift와 Page Down으로 스캐너가 보여 줄 것을 바꿉니다. 전체, 적, 아이템, 출구와 문, 캐릭터와 성소, 함정, 표지판. H는 체력, G는 골드를 알려 줍니다.",
        "ZHCN": "干得好。Shift 加 Page Down 切换扫描内容：全部、敌人、物品、出口和门、角色和圣坛、陷阱、标牌。H 查看生命值，G 查看金币。",
        "ZHTW": "做得好。Shift 加 Page Down 切換掃描內容：全部、敵人、物品、出口和門、角色和神龕、陷阱、標牌。H 查看生命值，G 查看黃金。",
    },
    "tutorial.door": {
        "EN": "A door is in sight; walk into it to open it. When you do not know where to go, U gives the route to the nearest unexplored area, and B plays a guiding sound along that route on every beat until you arrive.",
        "ES": "Hay una puerta a la vista; camina contra ella para abrirla. Cuando no sepas adónde ir, U te da la ruta a la zona sin explorar más cercana, y B pone un sonido guía en esa ruta en cada pulso hasta que llegas.",
        "DE": "Eine Tür ist in Sicht; laufe dagegen, um sie zu öffnen. Wenn du nicht weißt, wohin, nennt U den Weg zum nächsten unerforschten Bereich, und B spielt auf jedem Beat einen Leitton entlang dieses Weges, bis du ankommst.",
        "FR": "Une porte est en vue ; avancez dessus pour l'ouvrir. Quand vous ne savez pas où aller, U donne le chemin vers la zone inexplorée la plus proche, et B joue un son guide sur ce chemin à chaque pulsation jusqu'à votre arrivée.",
        "IT": "C'è una porta in vista; muoviti contro di essa per aprirla. Quando non sai dove andare, U ti dà il percorso verso la zona inesplorata più vicina, e B suona un segnale guida lungo quel percorso a ogni battito finché arrivi.",
        "PTBR": "Há uma porta à vista; ande contra ela para abri-la. Quando não souber para onde ir, U dá o caminho até a área inexplorada mais próxima, e B toca um som guia nesse caminho a cada batida até você chegar.",
        "RU": "В поле зрения дверь; шагните в неё, чтобы открыть. Если не знаете, куда идти, U даёт путь к ближайшей неисследованной области, а B на каждый такт звучит вдоль этого пути, пока вы не дойдёте.",
        "JA": "ドアが見えています。ぶつかると開きます。どこへ行けばいいかわからないときは、U で一番近い未探索の場所への道順を、B でそこまでビートごとに案内音を鳴らします。",
        "KO": "문이 보입니다. 부딪히면 열립니다. 어디로 갈지 모를 때는 U가 가장 가까운 미탐험 지역까지의 길을 알려 주고, B는 도착할 때까지 박자마다 그 길을 따라 안내음을 냅니다.",
        "ZHCN": "视野中有门；走向它即可打开。不知道去哪时，按 U 获得通往最近未探索区域的路线，按 B 会在每拍沿路线播放引导音，直到你到达。",
        "ZHTW": "視野中有門；走向它即可打開。不知道去哪時，按 U 取得通往最近未探索區域的路線，按 B 會在每拍沿路線播放引導音，直到你到達。",
    },
    "tutorial.finish": {
        "EN": "The end of the tutorial is near. In a run, I tells your items and their key combinations, L the depth, the time left in the song and whether the exit stairs are locked, and Shift plus arrows let you look at tiles without moving. Backspace skips the tutorial.",
        "ES": "El final del tutorial está cerca. En una partida, I te dice tus objetos y sus combinaciones de teclas, L la profundidad, el tiempo que le queda a la canción y si las escaleras de salida están cerradas, y Mayúsculas más flechas te deja mirar casillas sin moverte. Retroceso omite el tutorial.",
        "DE": "Das Ende des Tutorials ist nah. In einem Durchlauf nennt I deine Gegenstände und ihre Tastenkombinationen, L die Tiefe, die restliche Zeit des Lieds und ob die Ausgangstreppe verschlossen ist, und Umschalt plus Pfeiltasten lässt dich Felder ansehen, ohne dich zu bewegen. Rücktaste überspringt das Tutorial.",
        "FR": "La fin du tutoriel approche. Pendant une partie, I donne vos objets et leurs combinaisons de touches, L la profondeur, le temps restant de la chanson et si l'escalier de sortie est verrouillé, et Maj plus flèches permet d'examiner les cases sans bouger. Retour arrière passe le tutoriel.",
        "IT": "La fine del tutorial è vicina. In una partita, I dice i tuoi oggetti e le loro combinazioni di tasti, L la profondità, il tempo rimasto della canzone e se le scale d'uscita sono chiuse, e Maiusc più frecce ti fa esaminare le caselle senza muoverti. Backspace salta il tutorial.",
        "PTBR": "O fim do tutorial está perto. Em uma partida, I diz seus itens e as combinações de teclas, L a profundidade, o tempo restante da música e se a escada de saída está trancada, e Shift mais setas deixa você examinar casas sem se mover. Backspace pula o tutorial.",
        "RU": "Конец обучения близко. В забеге I называет ваши предметы и их сочетания клавиш, L глубину, оставшееся время песни и заперта ли лестница выхода, а Shift плюс стрелки позволяет осматривать клетки, не двигаясь. Backspace пропускает обучение.",
        "JA": "チュートリアルの終わりが近づいています。プレイ中は、I で持ち物とキーの組み合わせ、L で深さと曲の残り時間と出口の階段がロックされているか、Shift と矢印で動かずにマスを調べられます。Backspace でチュートリアルを飛ばせます。",
        "KO": "튜토리얼이 곧 끝납니다. 게임 중에는 I가 아이템과 키 조합을, L이 깊이와 곡의 남은 시간과 출구 계단이 잠겼는지를 알려 주고, Shift와 화살표로 움직이지 않고 칸을 살펴볼 수 있습니다. Backspace는 튜토리얼을 건너뜁니다.",
        "ZHCN": "教程即将结束。游戏中，按 I 查看物品和按键组合，按 L 查看深度、歌曲剩余时间以及出口楼梯是否上锁，按 Shift 加方向键可以不移动地查看格子。Backspace 跳过教程。",
        "ZHTW": "教學即將結束。遊戲中，按 I 查看物品和按鍵組合，按 L 查看深度、歌曲剩餘時間以及出口樓梯是否上鎖，按 Shift 加方向鍵可以不移動地查看格子。Backspace 跳過教學。",
    },
}

root = os.path.join(os.path.dirname(__file__), "..", "mod", "CryptAccess", "scripts")
for lang in ["EN", "ES", "DE", "FR", "IT", "PTBR", "RU", "JA", "KO", "ZHCN", "ZHTW"]:
    p = os.path.join(root, "Lang%s.lua" % lang)
    t = open(p, encoding="utf-8").read()
    nl = "\r\n" if "\r\n" in t else "\n"
    for key, values in S.items():
        v = values[lang].replace('"', '\\"')
        line = '\t["%s"] = "%s",' % (key, v)
        pattern = re.compile(r'^\t\["%s"\] = ".*?",\r?$' % re.escape(key), re.M)
        if pattern.search(t):
            t = pattern.sub(lambda m: line, t)
        else:
            i = t.rstrip().rfind("}")
            t = t[:i] + line + nl + t[i:]
    open(p, "w", encoding="utf-8").write(t)
print("ok")
