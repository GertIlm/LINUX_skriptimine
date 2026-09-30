#!/bin/bash
# 7.-10. Argumendid: $1, $2, $#, "$@"

tervita() {
    echo "Tere, $1!"
}

kasutaja_info() {
    echo "Nimi: $1"
    echo "Vanus: $2"
}

liida() {
    if [ $# -ne 2 ]; then
        echo "Viga: sisesta kaks arvu!"
        return 1
    fi
    echo "$(($1 + $2))"
}

kontrolli() {
    echo "Argumentide arv: $#"
}

naita() {
    echo "Funktsioonile anti:"
    for argument in "$@"
    do
        echo "$argument"
    done
}

tervita "Mari"
tervita "Jüri"
tervita "Anna"
kasutaja_info "Mari" 18
liida 10 5
liida 10
kontrolli üks kaks kolm
naita "üks" "kaks" "kolm"
