# awg-proxy для MIPS-роутеров

Сборка [awg-proxy](https://github.com/timbrs/amneziawg-mikrotik-c) под старые
MIPS-роутеры (mipsel, MIPS32r2, без FPU — например MediaTek MT7628 в ASUS
RT-N11P на прошивке Padavan), у которых нет готовой сборки автора.

awg-proxy превращает обычный WireGuard в AmneziaWG 3.1: WireGuard роутера шлёт
пакеты на локальный порт, awg-proxy маскирует их и отправляет на сервер
AmneziaWG. Так AmneziaWG работает там, где есть только модуль WireGuard ядра и
нет TUN для amneziawg-go.

## Что здесь

- Исходники берутся у автора по тегу из `upstream.env`; сборка проверяет, что
  тег указывает на записанный там коммит. Своих изменений в коде нет.
- `build.sh` собирает статический бинарник `zig cc` со встроенной musl теми же
  флагами, что сборка автора (`-O2`, `-static`, `-s`), только без `-Werror`.
- CI на каждом запуске прогоняет тесты автора на x86_64, собирает их же под
  MIPS и гоняет в qemu (криптография, преобразование пакетов, CPS, MTU),
  затем запускает сам бинарник в qemu. Релиз выпускается на тег `v*`.

## Использование

Скачать бинарник из релиза и сверить сумму:

```sh
curl -fsSLo /tmp/awg-proxy https://github.com/NjemTop/awg-proxy-mips/releases/download/v1.4.5-mips.1/awg-proxy-linux-mipsel
md5sum /tmp/awg-proxy   # сверить с MD5SUMS из релиза
chmod 755 /tmp/awg-proxy
```

Переменные окружения — как в документации автора (`AWG_LISTEN`, `AWG_REMOTE`,
`AWG_JC` … `AWG_H4`, `AWG_S1` … `AWG_S4`, `AWG_I1`, `AWG_SERVER_PUB`,
`AWG_CLIENT_PUB`, `AWG_HEADER_PROTECTION_KEY`).

На ядрах старше 4.18 обязательно `AWG_NO_GSO=1` и `AWG_NO_GRO=1`: старое ядро
не знает опцию `UDP_SEGMENT` и молча отправило бы пачку пакетов одним
датаграммом.

## Сборка у себя

```sh
./build.sh fetch
ZIG="python3 -m ziglang" ./build.sh build    # pip install ziglang==0.13.0
```

## Лицензия

Скрипты сборки — MIT (`LICENSE`). awg-proxy — MIT, © его автора; текст
лицензии лежит в каждом релизе как `LICENSE.awg-proxy`.
