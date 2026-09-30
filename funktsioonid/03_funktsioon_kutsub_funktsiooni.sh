#!/bin/bash
# 6. Funktsioonid võivad kutsuda teisi funktsioone

show_user() {
    echo "Kasutaja:"
    whoami
}

show_host() {
    echo "Arvuti:"
    hostname
}

show_system() {
    show_user
    show_host
}

show_system
