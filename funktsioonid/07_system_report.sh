#!/bin/bash
# 18. Praktiline näide - süsteemi info funktsioonidega

show_header() {
    echo "======================"
    echo " SYSTEM INFO"
    echo "======================"
}

show_user() {
    echo "Kasutaja: $(whoami)"
}

show_host() {
    echo "Arvuti: $(hostname)"
}

show_kernel() {
    echo "Kernel: $(uname -r)"
}

show_disk() {
    echo
    echo "Kettakasutus:"
    df -h /
}

show_header
show_user
show_host
show_kernel
show_disk
