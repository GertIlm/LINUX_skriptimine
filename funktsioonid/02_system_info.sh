#!/bin/bash
# 2.-5. Miks funktsioone kasutada - sama tegevus mitu korda, ka tsüklist

system_info() {
    echo "===================="
    echo "SÜSTEEMI INFO"
    echo "===================="
    hostname
    uname -r
    whoami
}

hello() {
    echo "Tere!"
}

system_info
system_info

for i in {1..5}
do
    hello
done
