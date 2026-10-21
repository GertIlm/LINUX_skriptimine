#!/bin/bash
# ------------------------------------------------------------------
# kodukataloogid_backup.sh
# Autor: Gert-Daniel Ilm (VOCO, IT-süsteemide spetsialist), 21.10.2026
#
# Varundab kõigi kasutajate kodukataloogid.
# Iga kodukataloog arhiveeritakse ja pakitakse eraldi faili kujul
#     <kasutaja>.<pp.kk.aaaa>.tar.gz   (nt mari.21.10.2026.tar.gz)
# ja salvestatakse varukoopiate kataloogi (vaikimisi /home_bcp).
#
# Skript töötab sõltumata sellest, millises kataloogis see käivitatakse:
# kõik teed on absoluutsed ja tar -C vahetab ise töökataloogi.
#
# Kasutus:  sudo ./kodukataloogid_backup.sh [lähtekaust] [sihtkaust]
#           vaikimisi lähtekaust=/home  sihtkaust=/home_bcp
# ------------------------------------------------------------------

lahtekaust="${1:-/home}"          # kust varundada
sihtkaust="${2:-/home_bcp}"       # kuhu varukoopiad panna
kuupaev="$(date +%d.%m.%Y)"       # kuupäev failinimesse, nt 21.10.2026

# Kontroll 1: teiste kasutajate failide lugemiseks on vaja root-õigusi
if [ "$(id -u)" -ne 0 ]; then
    echo "VIGA: käivita skript root-õigustes (sudo $0)" >&2
    exit 1
fi

# Kontroll 2: lähtekaust peab olemas olema
if [ ! -d "$lahtekaust" ]; then
    echo "VIGA: lähtekausta $lahtekaust ei ole olemas" >&2
    exit 1
fi

# Loome sihtkausta (kui puudub) ja lubame seda lugeda ainult rootil
mkdir -p "$sihtkaust"
chmod 700 "$sihtkaust"

echo "Käivitatud kataloogist: $(pwd)"
echo "Varundan: $lahtekaust -> $sihtkaust (kuupäev $kuupaev)"

loendur=0
for kataloog in "$lahtekaust"/*/; do
    [ -d "$kataloog" ] || continue                 # lähtekaust on tühi
    kasutaja="$(basename "$kataloog")"
    # ei varunda varukoopiate kausta ennast (kui see asub lähtekaustas)
    [ "$(realpath "$kataloog")" = "$(realpath -m "$sihtkaust")" ] && continue
    arhiiv="$sihtkaust/$kasutaja.$kuupaev.tar.gz"

    # tar -c loob arhiivi, -z pakib gzip-iga, -f failinimi,
    # -C läheb enne arhiveerimist lähtekausta (arhiivis on tee kasutaja/...)
    if tar -czf "$arhiiv" -C "$lahtekaust" "$kasutaja"; then
        suurus="$(du -h "$arhiiv" | cut -f1)"
        echo "  OK   $kasutaja -> $arhiiv ($suurus)"
        loendur=$((loendur + 1))
    else
        echo "  VIGA $kasutaja varundamine ebaõnnestus" >&2
    fi
done

echo "Valmis: $loendur kodukataloogi varundatud."
ls -lh "$sihtkaust"
