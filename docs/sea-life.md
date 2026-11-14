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
