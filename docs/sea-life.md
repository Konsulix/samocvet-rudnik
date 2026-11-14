# Морская жизнь на находках «морского дна» — кандидаты (Sketchfab)

14.11. Лист превью — `art/refs/sea_life_candidates.jpg` (номера те же; лист и превью в git не кладём). Все модели
скачиваемые, лицензия CC0 или CC BY (NonCommercial и ShareAlike отброшены). Поиск — публичный API Sketchfab: ~60 запросов,
модели ffishAsia-and-floraZia по морским словам, подборки baxterbaxter «Coral», «ocean», «Fossil», музейные коллекции
Smithsonian, RISD Nature Lab, NHM Wien. ★ — рекомендую взять первыми.

## Что сейчас рисует код и что заменят модели

- Трилобит на плите и аммонит на плите (`show = matrix`): только морские лилии-криноиды `SpecSea.lily` (ген `lilies`, 50%),
  пузырьки `SpecSea.bubbles`, блики `caustics`. Водорослей, кораллов, губок, звёзд, ежей, раковин там нет — **это добавят модели**.
- Жемчужница на плите трилобита (`SpecPearl.oyster`) — своя, кодом, остаётся.
- `SpecSea.weed`, `anemone`, `starfish` — только у жемчуга-вида (его нет в пулах). Модели групп «Водоросли», «Актинии»,
  «Морские звёзды» заменят их и там.
- Морские лилии: живых сканов нет (только ископаемые чашечки). Предлагаю лилии кодом оставить.

## Наблюдения

- Водорослей-сканов почти нет (вне воды они опадают): годные — рисованные модели CC BY (1–8); 9 — скан фукуса пятном на пляже.
- Кораллы и губки — много хороших сканов (музеи; l.olinger — живые губки Карибов), но тяжёлые: 0,3–5 млн треугольников,
  архивы 50–500 МБ. Облегчать до 3–8 тыс. треугольников, как насекомых.
- У ffishAsia рядом кубик-калибратор (скрипт подготовки его убирает).
- Почти всё не ffishAsia — CC BY: в `CREDITS.md` нужны автор и ссылка.


## Водоросли

Зачем: качается на плите (sea_life mode 0); сейчас водорослей на дне нет вовсе.

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| ★1 | [Kelp](https://sketchfab.com/3d-models/d1758bd85ec04eaab14fe50028108a10) | mazelya | CC BY | 365 тыс. |
| 2 | [Kelp Foliage](https://sketchfab.com/3d-models/edd33166f4974c218ed389c29949ee36) | pmruiz-wilson | CC BY | 55 тыс. |
| ★3 | [Kelp with animation](https://sketchfab.com/3d-models/22f71d83535c41c1bfa12b2d3e64af0e) | cswindley | CC BY | 49 тыс. |
| ★4 | [Red Algae](https://sketchfab.com/3d-models/f7a750d678884214879e8950da40eba7) | FranzAlvior | CC BY | 42 тыс. |
| ★5 | [Claret Tall Seaweed](https://sketchfab.com/3d-models/6a07131b52b34d8992861d3c3ba82a29) | Blaret | CC BY | 35 тыс. |
| 6 | [Kelp L](https://sketchfab.com/3d-models/611e0bdd8b5c4530b436d4b5f5a96b35) | stefanorivera | CC BY | 32 тыс. |
| ★7 | [Claret Wiggle Seaweed](https://sketchfab.com/3d-models/3f11b36110704b38abafc624a8e99d9c) | Blaret | CC BY | 17 тыс. |
| 8 | [Seaweed Asset](https://sketchfab.com/3d-models/5444487c06d647dfab90960142b9edc2) | mehgap | CC BY | 18 тыс. |
| 9 | [Fucus spiralis FREE](https://sketchfab.com/3d-models/b2b2c22ac7ee4abaa721f2390615c25b) | yelizegi | CC BY | 1381 тыс. |

## Кораллы живые и мягкие

Зачем: яркое пятно цвета у края плиты, позади трилобита.

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| ★10 | [Corallium Rubrum](https://sketchfab.com/3d-models/9bbf54afce7841b38c6585ee0f8d2a59) | Septentrion | CC BY | 2688 тыс. |
| 11 | [Red Coral](https://sketchfab.com/3d-models/de6fc9d6fd614a97a1d4853c5324bd22) | Septentrion | CC BY | 4996 тыс. |
| ★12 | [Organ pipe coral (NHMW-ZOO-EV-0000128)](https://sketchfab.com/3d-models/76c61c261b974999883ed5c41aa4e2cb) | NHMWien | CC BY | 1000 тыс. |
| ★13 | [Red Organ Pipe Coral](https://sketchfab.com/3d-models/eaaaffad58a14c52b36c3d6550c54167) | RISDNaturelab | CC BY | 500 тыс. |
| ★14 | [Corky sea finger (NHMW-ZOO-EV-0000170)](https://sketchfab.com/3d-models/87c445f8ca1a49b684b9378793edd676) | NHMWien | CC BY | 750 тыс. |
| ★15 | [Blue Coral](https://sketchfab.com/3d-models/28a6da41dc6b40bfaaec9a8a4eea4fc0) | RISDNaturelab | CC BY | 1000 тыс. |
| 16 | [Flat #315: March 14, 2017](https://sketchfab.com/3d-models/aa2e593ff83c41ec855f13c5e50f88a2) | l.olinger | CC BY | 1679 тыс. |
| ★17 | [Soft Coral Patch (Whitsunday Islands)](https://sketchfab.com/3d-models/7e31a58d8ac941e7a162d4791f62ef85) | MarcoKHC | CC BY | 750 тыс. |
| ★18 | [Soft Coral (Alcyonium digitatum)](https://sketchfab.com/3d-models/fac26f8bccf645128cdaa7db97c09617) | squireM | CC BY | 295 тыс. |
| 19 | [Sea fan corals](https://sketchfab.com/3d-models/011954081a224acfb64cea3414d4adfe) | blueyerobotics | CC BY | 495 тыс. |
| ★20 | [Blastomussa coral fragment](https://sketchfab.com/3d-models/ef98952826504564801f0b3ed91aecb0) | RISDNaturelab | CC BY | 500 тыс. |
| 21 | [Modern coral #2](https://sketchfab.com/3d-models/784ce93e1ea34ecb92ff1e8623a0ce9d) | Landy42 | CC BY | 3768 тыс. |
| 22 | [Acropora formosa](https://sketchfab.com/3d-models/0187c5d4ab7f491d821725f7a7511c6b) | qqman | CC BY | 700 тыс. |

## Кораллы-скелеты

Зачем: белый/кремовый куст или «мозг» — фон и рамка находки.

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| ★23 | [coral test](https://sketchfab.com/3d-models/e1ac5b24f1fe48699da740ffdb4d45aa) | chei_ucsd | CC BY | 3830 тыс. |
| 24 | [Coral 3 - Birch Aquarium](https://sketchfab.com/3d-models/9506d019d2b042f0a7586f3c736115e9) | chei_ucsd | CC BY | 2800 тыс. |
| 25 | [Octopus Coral](https://sketchfab.com/3d-models/abc751e09b6948a3b2fc658755917c6f) | RISDNaturelab | CC BY | 999 тыс. |
| ★26 | [Pocillopora verrucosa fresh sample](https://sketchfab.com/3d-models/2c193de29f7f4f88baf4d9075c07403f) | therlab | CC BY | 896 тыс. |
| 27 | [Staghorn coral](https://sketchfab.com/3d-models/8c14ba2dddcb48cb9650e84fb60260e5) | RISDNaturelab | CC BY | 655 тыс. |
| ★28 | [Staghorn Coral](https://sketchfab.com/3d-models/ede640745c16457a9345ef1fa9e8d4d4) | pixforge.id | CC BY | 1945 тыс. |
| 29 | [Oculina sp. skeleton](https://sketchfab.com/3d-models/bb6342dba38d4e7c8ed98c621d9e6f0a) | therlab | CC BY | 428 тыс. |
| 30 | [Cold-water coral (Lophelia pertusa)](https://sketchfab.com/3d-models/c5b44e8152a54baba631dc9af7d4b5c2) | squireM | CC BY | 657 тыс. |
| 31 | [Boulder Brain Coral / Colpophyllia natans](https://sketchfab.com/3d-models/04fd73b333734ab880c29f87e8ef276d) | patric_ocean | CC BY | 2434 тыс. |
| ★32 | [Rose Brain Coral](https://sketchfab.com/3d-models/26f4071ad44a41eeb7b179045135522d) | RISDNaturelab | CC BY | 405 тыс. |
| 33 | [Turbinaria sp. skeleton](https://sketchfab.com/3d-models/6911cb95564d49beaba52d8e9e62ffab) | therlab | CC BY | 1347 тыс. |
| 34 | [Fungia](https://sketchfab.com/3d-models/77d7daebe2294f05ae6f7a132dd58f69) | qqman | CC BY | 400 тыс. |
| ★35 | [Fungia sp. skeleton](https://sketchfab.com/3d-models/971b70e6f25146d2ba0b4e943c78dc3f) | therlab | CC BY | 955 тыс. |

## Губки

Зачем: цветные бочонки, трубки, комки — самые «сочные» сканы.

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| ★36 | [#28: Aplysina fistularis](https://sketchfab.com/3d-models/a4380f3b6e6a4cc991e7dc4cb8d455a8) | l.olinger | CC BY | 1289 тыс. |
| ★37 | [#24: Aiolochroia crassa](https://sketchfab.com/3d-models/f3807242f37442d9812d8167f797b9ce) | l.olinger | CC BY | 976 тыс. |
| 38 | [#44: Verongula gigantea](https://sketchfab.com/3d-models/95946ad2565d475bbabcc990cfcb98e7) | l.olinger | CC BY | 743 тыс. |
| ★39 | [#45: Verongula rigida](https://sketchfab.com/3d-models/61625f1f82504151a1d32346d1088ffc) | l.olinger | CC BY | 733 тыс. |
| ★40 | [#19: Geodia neptuni](https://sketchfab.com/3d-models/33173d91b1844a3daab12dd8e487f439) | l.olinger | CC BY | 636 тыс. |
| 41 | [Yellow Tube Sea Sponge](https://sketchfab.com/3d-models/820da7fd539549a0a6274048116eeeb3) | RISDNaturelab | CC BY | 500 тыс. |
| ★42 | [Orange Puffball Sea Sponge](https://sketchfab.com/3d-models/9a1d1f335f274039bf791192c39dcc7b) | RISDNaturelab | CC BY | 500 тыс. |
| 43 | [#30: Aplysina lacunosa](https://sketchfab.com/3d-models/9e435555fed141f7b208e3eb709caa18) | l.olinger | CC BY | 445 тыс. |
| ★44 | [#54: Neofibularia nolitangere](https://sketchfab.com/3d-models/35df3dd951e847f09a6d4241273cf3a4) | l.olinger | CC BY | 423 тыс. |
| ★45 | [#14: Mycale laxissima](https://sketchfab.com/3d-models/0cc01189170f4ead8b078d5c4e859265) | l.olinger | CC BY | 365 тыс. |
| 46 | [#11: Agelas dilitata](https://sketchfab.com/3d-models/3c823f769e9345c79ea2b87d9cd26d6a) | l.olinger | CC BY | 346 тыс. |
| 47 | [#1: Verongula gigantea](https://sketchfab.com/3d-models/a862f4636aa841d98c478c406320498a) | l.olinger | CC BY | 1535 тыс. |

## Актинии

Зачем: щупальца шевелятся (рябь, mode 1); сейчас актиния кодом только у жемчуга.

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| ★48 | [Elegant anemone (Sagartia elegans)](https://sketchfab.com/3d-models/5aaaa72bf63249e6aa8b8d5adb66aba6) | squireM | CC BY | 87 тыс. |
| ★49 | [Plumrose anemone (Metridium dianthus)](https://sketchfab.com/3d-models/6d740cf173754d568297c3a4447089b3) | squireM | CC BY | 34 тыс. |
| ★50 | [Purple Sea Anemone L](https://sketchfab.com/3d-models/990715cf0df144fc81aaaf5ff4764700) | stefanorivera | CC BY | 24 тыс. |
| ★51 | [Pink Sea Anemone L](https://sketchfab.com/3d-models/44c7357fcc6c4fbbb13e72f1ceb058bf) | stefanorivera | CC BY | 23 тыс. |
| 52 | [Blue Sea Anemone L](https://sketchfab.com/3d-models/f2542a8681584d048e515c660e6866fe) | stefanorivera | CC BY | 22 тыс. |
| 53 | [Sea anemone pink from Poly by Google](https://sketchfab.com/3d-models/10ec200cadfd44439b3ea9e807d2d88a) | ie-niels | CC BY | 20 тыс. |

## Морские звёзды

Зачем: лежит на плите плашмя; сейчас звезда кодом только у жемчуга.

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| ★54 | [イトマキヒトデ Blue Bat Star, Patiria pectinifera](https://sketchfab.com/3d-models/14319712a5f445fe8a1eb461eadf6527) | ffishAsia-and-floraZia | CC0 | 723 тыс. |
| ★55 | [モミジガイ Sand Sea Star, Astropecten scoparius](https://sketchfab.com/3d-models/0a9e1faf6a024323991cdcd3f04ed1c6) | ffishAsia-and-floraZia | CC0 | 434 тыс. |
| 56 | [イトマキヒトデ Blue Bat Star, Patiria pectinifera](https://sketchfab.com/3d-models/9cfeaef5c08d4a889c4982318c22be5c) | ffishAsia-and-floraZia | CC0 | 336 тыс. |
| ★57 | [ウデフリクモヒトデ Brittle Star, O. lopendrina](https://sketchfab.com/3d-models/62fa903f21d84754a1cf8cd95f235488) | ffishAsia-and-floraZia | CC0 | 172 тыс. |
| 58 | [ニホンクモヒトデ Brittle Star, O. japonicus](https://sketchfab.com/3d-models/da1968d4e0434afd9fc0abb37b9c050d) | ffishAsia-and-floraZia | CC0 | 116 тыс. |
| 59 | [Cushion Sea Star](https://sketchfab.com/3d-models/dbcc468ad62949529bd8031b06434765) | RISDNaturelab | CC BY | 1000 тыс. |
| ★60 | [Sunflower Sea Star](https://sketchfab.com/3d-models/cc973ed5fcd748c8aab5f37ae6b7b6f1) | RISDNaturelab | CC BY | 500 тыс. |
| 61 | [Sea Star](https://sketchfab.com/3d-models/a017feaa16de43f3b491f7163cdfa1ad) | RISDNaturelab | CC BY | 495 тыс. |

## Ежи, плоские ежи, голотурии

Зачем: на плите и на песке; иглы ежа — сочный силуэт.

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| ★62 | [ムラサキウニ Purple Sea Urchin, H. crassispina](https://sketchfab.com/3d-models/895f20119aea4b8886afc9aa3eb557a4) | ffishAsia-and-floraZia | CC0 | 726 тыс. |
| ★63 | [ヒラタブンブク Heart Urchin, Lovenia elongata](https://sketchfab.com/3d-models/acc010cf7e73486d9ac0694211dad8ce) | ffishAsia-and-floraZia | CC0 | 625 тыс. |
| ★64 | [Sea Urchin - Chondrocidaris brevispina](https://sketchfab.com/3d-models/4d032ce1ea9f4e249e2430d4de58f875) | chei_ucsd | CC BY | 1323 тыс. |
| 65 | [Sputnik Urchin](https://sketchfab.com/3d-models/592c0c996bfa4b7cbb790c1274e00c60) | RISDNaturelab | CC BY | 1000 тыс. |
| ★66 | [Modern Cidarid Sea Urchin A](https://sketchfab.com/3d-models/8d44fbc8db6f40d192910f9889770fc6) | ImmersiveBBK | CC BY | 520 тыс. |
| 67 | [Sea urchin](https://sketchfab.com/3d-models/ab47fae826b04257a5991b23caf5c77f) | karolinabadz | CC BY | 398 тыс. |
| 68 | [Echinoid: Strongylocentrotus (PRI 78783)](https://sketchfab.com/3d-models/ff7eca213f1b4afcb22ec5457f244c1b) | DigitalAtlasOfAncientLife | CC0 | 307 тыс. |
| ★69 | [Sand Dollar](https://sketchfab.com/3d-models/644cd300b35746df8b6245f9aca132f6) | RISDNaturelab | CC BY | 1000 тыс. |
| 70 | [Keyhole Arrowhead Sand Dollar](https://sketchfab.com/3d-models/45f6acb2ce0d477d8547dd20353b4fe7) | RISDNaturelab | CC BY | 500 тыс. |
| ★71 | [アカナマコ Japanese Spiky Sea Cucumber](https://sketchfab.com/3d-models/6f011a5c78cf4a1296d537156bd2769b) | ffishAsia-and-floraZia | CC0 | 804 тыс. |

## Раковины

Зачем: соседи трилобита/аммонита на дне: перламутр и узор.

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| 72 | [アツエゾボラ 🐚 Thick Neptune Snail, N. heros](https://sketchfab.com/3d-models/3cbcbaf1b60f4c80a57c5cd9e820692f) | ffishAsia-and-floraZia | CC0 | 2458 тыс. |
| ★73 | [ヒオウギガイ Noble Scallop, Mimachlamys nobilis](https://sketchfab.com/3d-models/50e113c8e44a46c29aabbf21e71f986d) | ffishAsia-and-floraZia | CC0 | 1593 тыс. |
| ★74 | [ツキヒガイ Japanses Moon Scallop, Y. japonicum](https://sketchfab.com/3d-models/f140a2cf2f1940448b723f31cc103cdd) | ffishAsia-and-floraZia | CC0 | 1529 тыс. |
| 75 | [ヒオウギガイ Noble Scallop, Mimachlamys nobilis](https://sketchfab.com/3d-models/a4c50a36963544be95e74aa4bd8cb846) | ffishAsia-and-floraZia | CC0 | 1407 тыс. |
| 76 | [オオコシダカガンガラ？ 🐚 Pfeiffer's Top Shell](https://sketchfab.com/3d-models/818ed75ca81c46abb7133ff8bae3539e) | ffishAsia-and-floraZia | CC0 | 1366 тыс. |
| ★77 | [スジウズラガイ 🐚 Giant Tun, Tonna olearium](https://sketchfab.com/3d-models/ebae705d0a404d4595f7ec10b3765579) | ffishAsia-and-floraZia | CC0 | 1350 тыс. |
| ★78 | [ヤコウガイ 🐚 Great Green Turban, T. marmoratus](https://sketchfab.com/3d-models/d22c7263e6f645359e1626468026aef1) | ffishAsia-and-floraZia | CC0 | 1294 тыс. |
| 79 | [ヒオウギガイ Noble Scallop, Mimachlamys nobilis](https://sketchfab.com/3d-models/dbec5aaa532740be9851d8719c15d8e5) | ffishAsia-and-floraZia | CC0 | 1039 тыс. |
| 80 | [メガイアワビ 🐚 Disk Abalone, Haliotis gigantea](https://sketchfab.com/3d-models/08588c309bcf4440a675058b713f49da) | ffishAsia-and-floraZia | CC0 | 1027 тыс. |
| ★81 | [ナンカイボラ 🐚 Knobbed Triton, Charonia lampas](https://sketchfab.com/3d-models/789ecd663bf34038a3c1e9e9ef273f50) | ffishAsia-and-floraZia | CC0 | 1026 тыс. |
| 82 | [カコボラ 🐚 Giant Triton, Monoplex parthenopeus](https://sketchfab.com/3d-models/931a1315a5724dbb8a792abcbe8efa6e) | ffishAsia-and-floraZia | CC0 | 993 тыс. |
| ★83 | [ヒメシャコガイ Boring Clam, Tridacna crocea](https://sketchfab.com/3d-models/af688a0ed6044ab99d0ec20c57fd3b18) | ffishAsia-and-floraZia | CC0 | 945 тыс. |
| 84 | [アラスジケマンガイ Comb Venus, Gafrarium pectinatum](https://sketchfab.com/3d-models/9122caa7b72a4299b023950fc2799e90) | ffishAsia-and-floraZia | CC0 | 940 тыс. |
| 85 | [ダンベイキサゴ 🐚 Button Top Shell, U. giganteum](https://sketchfab.com/3d-models/192b214f18db43f28f7d45718f4f7c31) | ffishAsia-and-floraZia | CC0 | 902 тыс. |
| ★86 | [Snail: Conus marmoreus (PRI 76850)](https://sketchfab.com/3d-models/96870cd0220b46c68d66ea534a20626b) | DigitalAtlasOfAncientLife | CC0 | 415 тыс. |
| 87 | [ヒザラガイ Japanese Chiton, A. japonica](https://sketchfab.com/3d-models/211283513abe42d68caca72e0911eb53) | ffishAsia-and-floraZia | CC0 | 409 тыс. |

## Усоногие, асцидии, мшанки, черви

Зачем: мелкие обрастания по краю плиты и на раковинах.

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| ★88 | [カメノテ Goose Barnacle, Capitulum mitella](https://sketchfab.com/3d-models/6f560775fe144114beda8f12e99ec341) | ffishAsia-and-floraZia | CC0 | 1590 тыс. |
| 89 | [カメノテ Goose Barnacle, Capitulum mitella](https://sketchfab.com/3d-models/b898b79f5230464c9bf6a78e507c0556) | ffishAsia-and-floraZia | CC0 | 512 тыс. |
| ★90 | [マボヤ Korean Common Sea Squirt, H. roretzi](https://sketchfab.com/3d-models/03e655bf5bd24aae9736ab0eb869c290) | ffishAsia-and-floraZia | CC0 | 1319 тыс. |
| 91 | [シロボヤ Stalked Sea Squirt, Styela clava](https://sketchfab.com/3d-models/734f2cc9848748e9b62a41a6f8039267) | ffishAsia-and-floraZia | CC0 | 835 тыс. |
| ★92 | [クロフジツボ 🐚 Acorn Barnacle, T. japonica](https://sketchfab.com/3d-models/c17e5dcfd65040bd8fcedd56af149219) | ffishAsia-and-floraZia | CC0 | 987 тыс. |
| 93 | [Crustaceans: Balanus sp. (PRI 71767)](https://sketchfab.com/3d-models/feb8da8331ac47f48eb4654a6aff7efe) | DigitalAtlasOfAncientLife | CC0 | 353 тыс. |
| 94 | [Barnacles: Balanus concavus (PRI 78785)](https://sketchfab.com/3d-models/03e76be9e7334ac9bc78549f48d505e0) | DigitalAtlasOfAncientLife | CC0 | 303 тыс. |
| ★95 | [Bryozoan: Archimedes wortheni (PRI 70774)](https://sketchfab.com/3d-models/f59b8d00f3204bceab30f2e63693a79d) | DigitalAtlasOfAncientLife | CC0 | 255 тыс. |
| 96 | [Annelida: Dodecaceria fewkesi (PRI 81227)](https://sketchfab.com/3d-models/8b617c19d15c4a05b66beafff58fbe68) | DigitalAtlasOfAncientLife | CC0 | 415 тыс. |
| 97 | [Worm Tubes](https://sketchfab.com/3d-models/47f09864cabe4821bccf5e129713d8b4) | UIPaleoRepository | CC BY | 999 тыс. |

## Морские лилии (только ископаемые)

Зачем: живых лилий-сканов нет; ископаемые чашечки — сосед на плите, живые лилии остаются кодом.

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| 98 | [Megistrocrinus Crinoid](https://sketchfab.com/3d-models/336976725d5b4ffe8aecfd515c5a7199) | UIPaleoRepository | CC BY | 916 тыс. |
| 99 | [Crinoid Calyx+ Arms+ Stem Stump](https://sketchfab.com/3d-models/7bf495310fec495aa5022e7f6f198330) | UIPaleoRepository | CC BY | 578 тыс. |
| 100 | [Crinoid Calyx+ Arms](https://sketchfab.com/3d-models/55fe34fbc55b4591a9a73f8433787fe0) | UIPaleoRepository | CC BY | 477 тыс. |
| 101 | [Crinoid](https://sketchfab.com/3d-models/111cc772c92a473f9fe5be459aaefc89) | WirtualneMuzeaMalopolski | CC0 | 283 тыс. |

## Рекомендованный набор (★, 50 моделей)

Водоросли 5 · живые кораллы 8 · скелеты кораллов 5 · губки 7 · актинии 4 · звёзды 4 · ежи и голотурия 6 · раковины 7 · обрастания 4.
Номера: 1, 3, 4, 5, 7, 10, 12, 13, 14, 15, 17, 18, 20, 23, 26, 28, 32, 35, 36, 37, 39, 40, 42, 44, 45, 48, 49, 50, 51, 54, 55, 57, 60, 62, 63, 64, 66, 69, 71, 73, 74, 77, 78, 81, 83, 86, 88, 90, 92, 95.
Скачивать в `C:/Users/Максим/Desktop/sea_life/<номер>_<имя>/` (формат glb или gltf, если Sketchfab предлагает).

## Подборка pikaia2 «ancient sea life» (номера A1–A62)

Лист — `art/refs/ancient_sea_candidates.jpg`. В подборке 292 модели; скачиваемых CC0 или CC BY — 62 (остальные без скачивания,
NonCommercial или ShareAlike). ★ — интересные.

Как их можно использовать:
- **Окаменелости-тела под гены, как черепа зверей** (скан = тело, генератор растит на нём своё: пирит, опал, кристаллы в
  трещинах, друзы в камерах): рыбы в плите (Lepidotes, Dapedium), череп ихтиозавра, зуб мегалодона, эвриптерид, мечехвосты,
  ортоцерас, наутилус, гетероморф Nostoceras.
- **Соседи на плите**: мелкие аммониты, ежи, табулята Pleurodictyum, кораллы, морские лилии (ископаемые).
- **Живые реконструкции** (FreddyFoxFreddy: тилозавр, долихоринхопс, офтальмозавр, кретоксирина) — не находки, а призраки для
  легендарных эффектов, как призраки зверей у черепов (`SpecBeastFx`).
- Свои трилобит и аммонит в генераторе остаются главными (их не трогаем). Сканы трилобитов и аммонитов (A1–A4, A9–A25) нужны
  как ориентир родов для `GENUS`/генов аммонита или как редкие «музейные» находки.

### Два морских рудника (идея, не решено)

- **Палеозой — рудник трилобитов**: трилобиты (роды), эвриптериды, мечехвосты, ортоцерасы, морские лилии, табуляты и ругозы,
  мшанки, брахиоподы. Легендарное — живой аномалокарис (уже есть), эвриптерид.
- **Мезозой — рудник аммонитов**: аммониты, аммолит, гетероморфы, белемниты, наутилусы, рыбы в плите, ихтиозавр,
  зуб акулы. Легендарное — призрак ихтиозавра/тилозавра.
- Живое дно (водоросли, губки, кораллы, звёзды, ежи) — общее у обоих.
- Сейчас трилобит и аммонит лежат в бухте Кракена (рудник 3, Whalebone Cove), там их можно оставить по одному.

### Трилобиты и членистоногие

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| ★A1 | [Trilobite: E. crassituberculata (PRI 49811)](https://sketchfab.com/3d-models/03f611a973144635b4a9019afe7393f0) | DigitalAtlasOfAncientLife | CC0 | 252 тыс. |
| ★A2 | [Trilobite 4](https://sketchfab.com/3d-models/e7e43723a9cc41a1966908fb9b0cdea7) | Landy42 | CC BY | 1455 тыс. |
| ★A3 | [Trilobite #3](https://sketchfab.com/3d-models/5cb18ea7ccbb4fe19342f5bbb86ae89a) | Landy42 | CC BY | 1462 тыс. |
| ★A4 | [Phacops, trilobite](https://sketchfab.com/3d-models/b4187b150b5c448d9a4b0a42ef307dbc) | anco.lankreijer | CC BY | 74 тыс. |
| ★A5 | [Eurypterid: Pterygotus sp. (PRI 50322)](https://sketchfab.com/3d-models/421a47bc3b0a4986a8304ab8e240480d) | DigitalAtlasOfAncientLife | CC0 | 182 тыс. |
| A6 | [Horseshoe crab: Carcinoscorpius rotundicauda](https://sketchfab.com/3d-models/d429e1e8c6d34f2fb9b79ee4c85b753f) | DigitalAtlasOfAncientLife | CC0 | 95 тыс. |
| ★A7 | [Horseshoe crab: Limulus polyphemus (PRI)](https://sketchfab.com/3d-models/1e425587f84e4b66913dec45850bbdb3) | DigitalAtlasOfAncientLife | CC0 | 149 тыс. |
| A8 | [Arthropod: Limulus (horseshoe crab)](https://sketchfab.com/3d-models/b300292543ea4d2da7a3f2490c653630) | DigitalAtlasOfAncientLife | CC0 | 122 тыс. |

### Аммониты, наутилусы, ортоцерасы

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| A9 | [Fossil Ammonite](https://sketchfab.com/3d-models/a6f39739ac074f0c8b5aa521f728e39f) | ExplorMorLabs | CC BY | 10 тыс. |
| ★A10 | [Mammites nodosoides](https://sketchfab.com/3d-models/6da4d09b7d1f48298f394136deb87af6) | MUVHN | CC BY | 3824 тыс. |
| ★A11 | [Ammonite Heteromorfo Nostoceras](https://sketchfab.com/3d-models/89aaa73f44514ef385bb47cb51d66eb7) | MUVHN | CC BY | 1073 тыс. |
| ★A12 | [Ammonoid Cleoniceras besairei](https://sketchfab.com/3d-models/5dd26bb6dcf34d13bffc47006f463a69) | MUVHN | CC BY | 953 тыс. |
| A13 | [Ammonites (Perisphinctes sp.)](https://sketchfab.com/3d-models/b9d45b4134354a02baadee4dee62f14a) | MUVHN | CC BY | 190 тыс. |
| A14 | [Czekanowskites rieberi](https://sketchfab.com/3d-models/ae023017e0f34cf8b5cc0d98899da3ac) | Paleogirl | CC BY | 90 тыс. |
| A15 | [Australiceras jacki](https://sketchfab.com/3d-models/9d67d17d8da6488582baf8a81db8d355) | Paleogirl | CC BY | 49 тыс. |
| A16 | [Harpoceras radians](https://sketchfab.com/3d-models/f700c20667f54313965d364e5f3f3ade) | Paleogirl | CC BY | 70 тыс. |
| A17 | [Cardioceras cordatum](https://sketchfab.com/3d-models/d7c6049eb470474683fdff2cd7eab5f1) | Paleogirl | CC BY | 60 тыс. |
| ★A18 | [Polyptychites ramulicosta](https://sketchfab.com/3d-models/195567b2f4fe44e6b38b1ad5240ff320) | ScarboroughMuseums | CC BY | 492 тыс. |
| ★A19 | [Nautilus](https://sketchfab.com/3d-models/27879a30c57844d0978df8f1fae2ec74) | ScarboroughMuseums | CC BY | 628 тыс. |
| A20 | [Perisphinctes (Properisphinctes) bernensis](https://sketchfab.com/3d-models/61078b4e5ef3412aab4d6ba9c4404938) | ScarboroughMuseums | CC BY | 1499 тыс. |
| A21 | [Ammonites and Ichthyosaur bones.](https://sketchfab.com/3d-models/587dbd914980440fa80cb1756da92a9f) | ScarboroughMuseums | CC BY | 64 тыс. |
| ★A22 | [Perisphinctes sp](https://sketchfab.com/3d-models/fc6c4766cf7345528c5b1ad1ec58b12a) | jovilgo | CC BY | 449 тыс. |
| A23 | [Nautilus Shell](https://sketchfab.com/3d-models/9b4acc4a177c41e984a0199c6fdcf90e) | RISDNaturelab | CC BY | 397 тыс. |
| A24 | [Chambered Nautilus](https://sketchfab.com/3d-models/ad379c7c5ca345ac801bd249d864c94f) | RISDNaturelab | CC BY | 500 тыс. |
| ★A25 | [Orthocerátido Michelinoceras](https://sketchfab.com/3d-models/b823b148c1e34beb8f280f6ba0115c5b) | MUVHN | CC BY | 1706 тыс. |

### Рыбы и морские ящеры (окаменелости)

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| A26 | [Vertebrate: Fish (PRI 53568)](https://sketchfab.com/3d-models/e62fbf61257c462c842ac31354de49a9) | DigitalAtlasOfAncientLife | CC0 | 147 тыс. |
| A27 | [Lepidotes elvensis TU256b](https://sketchfab.com/3d-models/0b3bdc3995b04b89b6e9ce51f6658762) | mnhnl | CC BY | 499 тыс. |
| ★A28 | [Lepidotes elvensis TU938](https://sketchfab.com/3d-models/7cc52279fe1a4032934c71344fba19c8) | mnhnl | CC BY | 499 тыс. |
| A29 | [Ichthyosaur TU867](https://sketchfab.com/3d-models/d088f9da65d340e4995d3a22c580c2cc) | mnhnl | CC BY | 499 тыс. |
| ★A30 | [Dapedium pholidotum TU962](https://sketchfab.com/3d-models/1e39c696dc55413a87cdc7e12516f073) | mnhnl | CC BY | 499 тыс. |
| ★A31 | [Ichthyosaur skull TV112](https://sketchfab.com/3d-models/bd1450d31f1b4a48a878977ecd3cfe4a) | mnhnl | CC BY | 499 тыс. |
| A32 | [Lepidotes elvensis TV240b](https://sketchfab.com/3d-models/3a4a64a3b84f4431a44402f6f9f3c238) | mnhnl | CC BY | 499 тыс. |
| A33 | [Lepidotes elvensis TV240a](https://sketchfab.com/3d-models/5b1471157fc1458989bee9b4080d1836) | mnhnl | CC BY | 499 тыс. |
| ★A34 | [Xiphactinus Audax Fossil Skull](https://sketchfab.com/3d-models/9f26fe5bc6be4ee790283c9d22df7cb3) | gamingassets | CC BY | 315 тыс. |
| ★A35 | [ChM PV9565 - Megalodon Shark Tooth](https://sketchfab.com/3d-models/a2396234fe08463cacaf809bf9b59fdc) | charlestonmuseum | CC BY | 58 тыс. |
| A36 | [Vertèbre de Muraenosaurus](https://sketchfab.com/3d-models/c2db14f7e57f4dce85c36d475159e767) | HRDP | CC BY | 796 тыс. |
| A37 | [Plesiosaur or Pliosaur Fossil (Femur)](https://sketchfab.com/3d-models/0fb83dc80e9d4561b30adff8c1f9cb8f) | Jameswest | CC BY | 254 тыс. |

### Морские ящеры и рыбы — реконструкции

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| ★A38 | [Tylosaurus](https://sketchfab.com/3d-models/17a0332ed82b4383ae9fda9fa32b1080) | FreddyFoxFreddy | CC BY | 195 тыс. |
| A39 | [styxosaurus snowii](https://sketchfab.com/3d-models/c0ee838a9345458b91ef2cca3ba94542) | FreddyFoxFreddy | CC BY | 66 тыс. |
| A40 | [Dolichorhynchops](https://sketchfab.com/3d-models/3d208b94eb1e405ea1fe94c2f47316a6) | FreddyFoxFreddy | CC BY | 967 тыс. |
| A41 | [Tylosaurus Head](https://sketchfab.com/3d-models/0aad75bad3244aa18c2457b3c4c0dadc) | FreddyFoxFreddy | CC BY | 1317 тыс. |
| ★A42 | [Opthalmosaurus](https://sketchfab.com/3d-models/ef76282850be4509b0a0d54453e5b324) | FreddyFoxFreddy | CC BY | 1480 тыс. |
| A43 | [Cretoxyrhina](https://sketchfab.com/3d-models/cb6c498b19cf432ea8effdd71ab6b8d3) | FreddyFoxFreddy | CC BY | 1338 тыс. |
| A44 | [Dallasaurus](https://sketchfab.com/3d-models/bfec76fbd5624d9fa9375668565af45c) | FreddyFoxFreddy | CC BY | 134 тыс. |

### Прочее: кораллы, ежи, лилии, раковины

| № | Модель | Автор | Лицензия | Треуг. |
|---|---|---|---|---|
| ★A45 | [Coral: Septastrea marylandica (PRI 70753)](https://sketchfab.com/3d-models/9a19bced8af1473489e2b7573f54b836) | DigitalAtlasOfAncientLife | CC0 | 581 тыс. |
| A46 | [Unknown Fossil](https://sketchfab.com/3d-models/432bac3ec4404399980bc3565baaffc0) | GLC-UHEAS | CC BY | 114 тыс. |
| A47 | [Unknown Fossil](https://sketchfab.com/3d-models/014237b4fdba446d996ff55c0628afd4) | GLC-UHEAS | CC BY | 300 тыс. |
| ★A48 | [Pleurodictyum sp.](https://sketchfab.com/3d-models/cfcf79481f6742959152e1f8f1362e96) | Paleogirl | CC BY | 440 тыс. |
| ★A49 | [Echinoid: Strongylocentrotus (PRI 78783)](https://sketchfab.com/3d-models/ff7eca213f1b4afcb22ec5457f244c1b) | DigitalAtlasOfAncientLife | CC0 | 307 тыс. |
| A50 | [Echinoid: Heterocentrotus mamillatus (PRI)](https://sketchfab.com/3d-models/32114c05e2674863acedd311c7dee0ab) | DigitalAtlasOfAncientLife | CC0 | 212 тыс. |
| ★A51 | [Crinoid: Agaricocrinus americanus (PRI 70601)](https://sketchfab.com/3d-models/2db9524514314cdcb82ca92dfd6f1dff) | DigitalAtlasOfAncientLife | CC0 | 764 тыс. |
| A52 | [Crinoid](https://sketchfab.com/3d-models/111cc772c92a473f9fe5be459aaefc89) | WirtualneMuzeaMalopolski | CC0 | 283 тыс. |
| A53 | [Crinoid](https://sketchfab.com/3d-models/d931cdf0a69047cfac9398eaa6eb1849) | lbriney | CC BY | 196 тыс. |
| A54 | [Turritella apicalis](https://sketchfab.com/3d-models/e6ac042fdf6a4f37be2da8d423472a7f) | Paleogirl | CC BY | 80 тыс. |
| A55 | [Heilprinia caloosaensis](https://sketchfab.com/3d-models/99d3abda2a2f4f57b6271e425135a531) | Paleogirl | CC BY | 79 тыс. |
| A56 | [Protocardia texana (steinkern)](https://sketchfab.com/3d-models/927bfb6d9aad4f81bde87692873997b7) | Paleogirl | CC BY | 80 тыс. |
| A57 | [Globigerina bulloides [Geo B8502 865cm Shell-2]](https://sketchfab.com/3d-models/2ab8073629f648d283b06f385561b816) | GigaDB | CC BY | 500 тыс. |
| A58 | [Ozarkodinid Conodont Apparatus](https://sketchfab.com/3d-models/aad2e949abc444c8840feecf532510c4) | micropalaeontology | CC BY | 136 тыс. |
| A59 | [P Conodont Elements](https://sketchfab.com/3d-models/02fb4242dfda47fdbba614445b48139f) | micropalaeontology | CC BY | 77 тыс. |
| A60 | [GEOL110 Lab Test Sample 259](https://sketchfab.com/3d-models/fa087d032b974410b09c575df91a073a) | Cjoneal | CC BY | 104 тыс. |
| A61 | [Réplica-pez](https://sketchfab.com/3d-models/b0098a28f0024c94a35abf77fe7fef2a) | biomarco | CC BY | 22 тыс. |
| A62 | [Fossil Photogrammetry](https://sketchfab.com/3d-models/8e10a7e210824e23833b04a9b1abe82f) | nomthewise | CC BY | 14 тыс. |
## Решение 14.11

- Рудник 3 (бухта Кракена) — минералы + **одно** ископаемое + живое дно. **Решено: аммониты**: Кракен —
  головоногий, аммониты, наутилусы и белемниты — его родня (мезозой). Трилобит из пула бухты уходит.
- Отдельный новый рудник — **палеозойское море, трилобиты** (роды, эвриптериды, мечехвосты, ортоцерасы, лилии, древние
  кораллы, аномалокарис). Подводные находки бухты переделать под это разделение.
- Порядок: сначала живое дно (нужно и бухте, и будущему руднику); пулы и рудник — потом, код пулов пока не трогать.
