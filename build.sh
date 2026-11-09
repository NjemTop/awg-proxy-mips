#!/bin/sh
# Сборка awg-proxy под MIPS-роутеры (mipsel, MIPS32r2, без FPU) из исходников
# автора тем же набором флагов, что и его сборка через musl-gcc.
#
#   ./build.sh fetch       скачать исходники автора и сверить коммит
#   ./build.sh build       собрать dist/awg-proxy-linux-mipsel и контрольные суммы
#   ./build.sh test-qemu   собрать модульные тесты автора под MIPS и прогнать в qemu
#   ./build.sh smoke       запустить собранный бинарник в qemu без настроек
#
# ZIG — команда компилятора zig (по умолчанию "python3 -m ziglang"),
# QEMU — эмулятор (по умолчанию qemu-mipsel-static).
set -eu
cd "$(dirname "$0")"
. ./upstream.env

ZIG=${ZIG:-"python3 -m ziglang"}
QEMU=${QEMU:-qemu-mipsel-static}
TARGET="-target mipsel-linux-musl -mcpu=mips32r2 -msoft-float"
# Флаги автора (Makefile) без -Werror: clang zig ругается на макрос CMSG_NXTHDR
# из musl (сравнение знакового и беззнакового), это не ошибка кода.
CFLAGS="-O2 -Wall -Wextra -std=c11 -D_GNU_SOURCE -ffunction-sections -fdata-sections"
SRCS="src/main.c src/proxy.c src/transform.c src/blake2s.c src/chacha20.c src/cps.c src/fastrand.c src/base64.c src/log.c"
TEST_SRCS="src/blake2s.c src/chacha20.c src/cps.c src/transform.c src/fastrand.c src/base64.c src/log.c"
# Тесты автора без сети: криптография, преобразование пакетов, CPS, MTU.
QEMU_TESTS="blake2s chacha20 cps transform base64 session mtu"
BIN=dist/awg-proxy-linux-mipsel

case "${1:-build}" in
fetch)
    rm -rf upstream
    git clone --quiet --depth 1 --branch "$UPSTREAM_TAG" "$UPSTREAM_REPO" upstream
    actual=$(git -C upstream rev-parse HEAD)
    if [ "$actual" != "$UPSTREAM_COMMIT" ]; then
        echo "upstream $UPSTREAM_TAG is $actual, expected $UPSTREAM_COMMIT" >&2
        exit 1
    fi
    ;;
build)
    mkdir -p dist
    (cd upstream && $ZIG cc $TARGET $CFLAGS -DVERSION="\"${UPSTREAM_TAG#v}-mipsel\"" \
        -static -Wl,--gc-sections -s -o "../$BIN" $SRCS -lpthread)
    cp upstream/LICENSE dist/LICENSE.awg-proxy
    (cd dist && sha256sum awg-proxy-linux-mipsel > SHA256SUMS && md5sum awg-proxy-linux-mipsel > MD5SUMS)
    file "$BIN"
    file "$BIN" | grep -q "MIPS32 rel2.*statically linked"
    cat dist/SHA256SUMS dist/MD5SUMS
    ;;
test-qemu)
    mkdir -p build
    for test in $QEMU_TESTS; do
        (cd upstream && $ZIG cc $TARGET -O1 -Wall -Wextra -std=c11 -D_GNU_SOURCE -static \
            -o "../build/test_$test" "src/test_$test.c" $TEST_SRCS)
        echo "== test_$test (mipsel, qemu)"
        "$QEMU" "build/test_$test"
    done
    ;;
smoke)
    # Без переменных окружения программа должна запуститься, перечислить
    # недостающие AWG_* и выйти: значит, процессор и libc подходят.
    out=$(env -i "$QEMU" "$BIN" 2>&1 || true)
    echo "$out"
    echo "$out" | grep -q "missing required environment variables"
    ;;
*)
    echo "usage: $0 fetch|build|test-qemu|smoke" >&2
    exit 2
    ;;
esac
