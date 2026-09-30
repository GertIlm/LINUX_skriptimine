#!/bin/bash
# 11.-12. Funktsiooni muutujad ja local

globaalne() {
    nimi="Mari"
}

lokaalne() {
    local linn="Tartu"
    echo "Funktsiooni sees: $linn"
}

tervita() {
    local nimi="$1"
    echo "Tere, $nimi!"
}

globaalne
echo "Pärast funktsiooni on nimi: $nimi"

lokaalne
echo "Väljaspool funktsiooni on linn: '$linn' (tühi, sest local)"

tervita "Gert"
