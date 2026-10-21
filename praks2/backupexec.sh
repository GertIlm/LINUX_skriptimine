#!/bin/bash
# backupexec.sh - esimene versioon (ülesanded 1-3 ja 9)
# Teeb src kaustast zstd arhiivi, kontrollib seda ja arvutab SHA-256.
SKRIPTI_KAUST="$(cd "$(dirname "$0")" && pwd)"
SRC="$SKRIPTI_KAUST/src"
DEST="$SKRIPTI_KAUST/backup"
mkdir -p "$DEST"

ARHIIV="$DEST/$(basename "$SRC")_$(date '+%F_%H-%M-%S').tar.zst"
tar -I 'zstd -19 -T0' -cf "$ARHIIV" -C "$(dirname "$SRC")" "$(basename "$SRC")"
echo "Loodud: $ARHIIV"

# kontroll: arhiiv avaneb ja sisaldab alamkaustu
tar -I 'zstd -d' -tf "$ARHIIV" | head -n 5

# suurus
echo "Suurus: $(du -h "$ARHIIV" | awk '{print $1}')"

# kontrollsumma
cd "$DEST" && sha256sum "$(basename "$ARHIIV")" > "$(basename "$ARHIIV").sha256"
sha256sum -c "$(basename "$ARHIIV").sha256"
