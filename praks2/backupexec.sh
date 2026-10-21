#!/bin/bash
# ------------------------------------------------------------------
# backupexec.sh - varukoopia kuupäeva ja kontrolliga
# Autor: Gert-Daniel Ilm (VOCO), 21.10.2026
#
# Teeb kaustast src arhiivi src_AAAA-KK-PP_TT-MM-SS.tar.<zst|gz|xz>
# ja teeb kõik ülesannete 1-11 sammud automaatselt:
#   - vaba ruumi kontroll (du -sb / df -B1)            (8)
#   - .backupignore välistused (--exclude-from)         (5, 11)
#   - kuiv jooks -n, arhiivi ei looda                   (6)
#   - kompressori valik: zstd, gzip, xz või auto        (1, 10)
#   - kontroll, kas sama nimega arhiiv on juba olemas
#   - arhiivi kontroll: avaneb + sisaldab alamkaustu    (2)
#   - arhiivi suurus (du -h)                            (3)
#   - SHA-256 kontrollsumma + sha256sum -c              (9)
#   - alles jäävad ainult N viimast koopiat             (4)
#   - logimine faili logs/backup.log                    (7)
#   - ajutine kaust mktemp -d, koristus trap EXIT       (12)
#
# Kasutus: ./backupexec.sh [-n] [-c zstd|gzip|xz|auto] [-k N] [-m MB]
#                          [-s lähtekaust] [-d sihtkaust] [-h]
#   -n  kuiv jooks (näitab, mis läheks arhiivi)
#   -c  kompressor (vaikimisi auto = valib väikseima arhiivi)
#   -k  mitu viimast koopiat alles hoida (vaikimisi 3)
#   -m  mitu MB peab pärast varundust vabaks jääma (vaikimisi 10)
#   -s  lähtekaust (vaikimisi <skripti kaust>/src)
#   -d  sihtkaust  (vaikimisi <skripti kaust>/backup)
# Skript töötab sõltumata käivitamise kohast (teed skripti kaustast).
# ------------------------------------------------------------------
set -uo pipefail

SKRIPTI_KAUST="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SKRIPTI_KAUST/src"
DEST="$SKRIPTI_KAUST/backup"
LOGDIR="$SKRIPTI_KAUST/logs"
LOG="$LOGDIR/backup.log"
KEEP=3
MIN_MB=10
KOMPRESSOR="auto"
KUIV=0
TMP=""

# ---------- abifunktsioonid ----------
log() {   # log TASE TEADE -> ekraanile ja logifaili
    printf '[%s] %-5s %s\n' "$(date '+%F %T')" "$1" "$2" | tee -a "$LOG"
}
viga() { log "VIGA" "$1"; exit 1; }
abi()  { sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

koristus() {   # käivitub alati skripti lõpus (trap EXIT)
    local kood=$?
    if [ -n "$TMP" ] && [ -d "$TMP" ]; then
        rm -rf "$TMP"
        echo "Ajutine kaust $TMP kustutatud."
    fi
    if [ "$kood" -eq 0 ]; then
        log "INFO" "BACKUP END (OK)"
    else
        log "INFO" "BACKUP END (VIGA, kood $kood)"
    fi
}

# ---------- argumendid ----------
while getopts ":nc:k:m:s:d:h" opt; do
    case "$opt" in
        n) KUIV=1 ;;
        c) KOMPRESSOR="$OPTARG" ;;
        k) KEEP="$OPTARG" ;;
        m) MIN_MB="$OPTARG" ;;
        s) SRC="$(realpath -m "$OPTARG")" ;;
        d) DEST="$(realpath -m "$OPTARG")" ;;
        h) abi ;;
        *) echo "Tundmatu võti. Abi: $0 -h" >&2; exit 2 ;;
    esac
done

mkdir -p "$LOGDIR"
trap koristus EXIT
log "INFO" "BACKUP START ($SRC -> $DEST)"

# ---------- eelkontrollid ----------
[ -d "$SRC" ] || viga "Lähtekausta $SRC ei ole olemas"
[[ "$KEEP" =~ ^[1-9][0-9]*$ ]] || viga "-k peab olema positiivne täisarv"
[[ "$MIN_MB" =~ ^[0-9]+$ ]] || viga "-m peab olema täisarv (MB)"
case "$KOMPRESSOR" in
    auto|zstd|gzip|xz) ;;
    *) viga "Tundmatu kompressor: $KOMPRESSOR (lubatud: zstd, gzip, xz, auto)" ;;
esac
for k in tar sha256sum gzip xz zstd; do
    command -v "$k" >/dev/null || viga "Puudub programm: $k"
done

ALUS="$(dirname "$SRC")"        # nt ~/skriptlinux/praks2
NIMI="$(basename "$SRC")"       # nt src
TMP="$(mktemp -d)"              # ajutine kaust, trap kustutab selle lõpus

# .backupignore: eemaldame kommentaarid, tühjad read ja lõpu "/"
# (GNU tar ei tunne mustrit "imgs/", aga tunneb mustrit "imgs")
VALISTUS=()
if [ -f "$SRC/.backupignore" ]; then
    grep -v '^[[:space:]]*\(#\|$\)' "$SRC/.backupignore" | sed 's#/*$##' > "$TMP/valistused.txt"
    VALISTUS=(--exclude-from="$TMP/valistused.txt")
    log "INFO" ".backupignore: $(wc -l < "$TMP/valistused.txt") reeglit ($(paste -sd' ' "$TMP/valistused.txt"))"
fi

# ---------- kuiv jooks ----------
if [ "$KUIV" -eq 1 ]; then
    log "INFO" "KUIV JOOKS - arhiivi ei looda, need failid läheksid arhiivi:"
    tar -cf - "${VALISTUS[@]}" -C "$ALUS" "$NIMI" | tar -tvf -
    log "INFO" "Kokku $(tar -cf - "${VALISTUS[@]}" -C "$ALUS" "$NIMI" | tar -tf - | wc -l) kirjet"
    exit 0
fi

# ---------- vaba ruum ----------
mkdir -p "$DEST"
VAJA=$(du -sb "$SRC" | awk '{print $1}')
VABA=$(df -B1 "$DEST" | awk 'NR==2{print $4}')
NOUE=$(( VAJA * 2 + MIN_MB * 1024 * 1024 ))   # 2x andmed (ajutine + valmis) + varu
log "INFO" "Andmeid $VAJA B, vaba ruumi $VABA B, vaja vähemalt $NOUE B"
if [ "$VABA" -lt "$NOUE" ]; then
    viga "Vaba ruumi on liiga vähe - varundust ei tehta"
fi

# ---------- arhiivi loomine ajutisse kausta ----------
AEG="$(date '+%F_%H-%M-%S')"
declare -A LAIEND=([zstd]=zst [gzip]=gz [xz]=xz)
declare -A VOTI=([zstd]="zstd -19 -T0" [gzip]="gzip -9" [xz]="xz -6")

if [ "$KOMPRESSOR" = "auto" ]; then
    VALIK="zstd gzip xz"          # proovime kõiki ja valime väikseima
else
    VALIK="$KOMPRESSOR"
fi

PARIM=""
PARIM_S=0
for k in $VALIK; do
    f="$TMP/${NIMI}_$AEG.tar.${LAIEND[$k]}"
    tar -I "${VOTI[$k]}" -cf "$f" "${VALISTUS[@]}" -C "$ALUS" "$NIMI" \
        || viga "tar ($k) ebaõnnestus"
    s=$(stat -c %s "$f")
    log "INFO" "Kompressor $k: $s B"
    if [ -z "$PARIM" ] || [ "$s" -lt "$PARIM_S" ]; then
        PARIM="$k"; PARIM_S="$s"
    fi
done
log "INFO" "Valitud kompressor: $PARIM ($PARIM_S B)"

ARHIIV="${NIMI}_$AEG.tar.${LAIEND[$PARIM]}"
if [ -e "$DEST/$ARHIIV" ]; then
    viga "Arhiiv $ARHIIV on juba olemas - üle ei kirjutata"
fi

# ---------- arhiivi kontroll (avaneb ja sisaldab alamkaustu) ----------
SISU="$TMP/sisu.txt"
tar -I "$PARIM -d" -tf "$TMP/$ARHIIV" > "$SISU" || viga "Arhiiv ei avane!"
ALAM=$(grep -c "^$NIMI/.\+/$" "$SISU")
[ "$ALAM" -gt 0 ] || viga "Arhiivis pole alamkaustu"
log "INFO" "Arhiiv avaneb: $(wc -l < "$SISU") kirjet, $ALAM alamkausta"
head -n 5 "$SISU"

# ---------- teisaldamine sihtkausta + SHA-256 ----------
mv "$TMP/$ARHIIV" "$DEST/" || viga "Arhiivi teisaldamine ebaõnnestus"
KONTROLL=$(cd "$DEST" && sha256sum "$ARHIIV" > "$ARHIIV.sha256" && sha256sum -c "$ARHIIV.sha256" 2>&1)
log "INFO" "sha256sum -c: $KONTROLL"
[[ "$KONTROLL" == *": OK" ]] || viga "SHA-256 kontroll EBAÕNNESTUS"
log "INFO" "Arhiiv: $DEST/$ARHIIV ($(du -h "$DEST/$ARHIIV" | awk '{print $1}'))"

# ---------- alles ainult KEEP viimast koopiat ----------
mapfile -t VANAD < <(ls -1t "$DEST"/"${NIMI}"_*.tar.* 2>/dev/null \
                     | grep -v '\.sha256$' | tail -n +$((KEEP + 1)))
for v in "${VANAD[@]}"; do
    rm -f -- "$v" "$v.sha256"
    log "INFO" "Kustutatud vana koopia: $(basename "$v")"
done
log "INFO" "Alles $(ls -1 "$DEST"/"${NIMI}"_*.tar.* | grep -vc '\.sha256$') koopiat (max $KEEP)"

echo "VARUNDUS EDUKAS: $DEST/$ARHIIV"
exit 0
