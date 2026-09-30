#!/bin/bash
# 13.-17. Funktsiooni tulemus, return, $?, if-tingimus, return vs exit

liida() {
    local a="$1"
    local b="$2"
    echo "$((a + b))"
}

kontrolli_faili() {
    if [ ! -f "$1" ]; then
        echo "Faili ei leitud!"
        return 1
    fi
    echo "Fail on olemas."
    return 0
}

fail_olemas() {
    [ -f "$1" ]
}

tulemus=$(liida 10 20)
echo "Tulemus: $tulemus"

kontrolli_faili "/etc/passwd"
echo "Olekukood: $?"

kontrolli_faili "/tmp/puudub.txt"
echo "Olekukood: $?"

if fail_olemas "/etc/passwd"; then
    echo "Fail on olemas."
else
    echo "Faili ei leitud."
fi

echo "Skript jätkab tööd (return lõpetab ainult funktsiooni, exit lõpetaks kogu skripti)."
