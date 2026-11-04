# LINUX_skriptimine

Linux skriptimise (Haldustegevuste automatiseerimine) praktikumid – Gert-Daniel Ilm, VOCO.

Kaustad: `praks1/`, `funktsioonid/`, `kasutajate_haldus/`, `home_backup/`, `praks2/`, `php_paigaldus/`, `lamp_paigaldus/`.

## home_backup/kodukataloogid_backup.sh
Varundab kõigi kasutajate kodukataloogid failideks `<kasutaja>.<pp.kk.aaaa>.tar.gz` kataloogi `/home_bcp`.
Töötab sõltumata käivitamise kohast. Kasutus: `sudo ./kodukataloogid_backup.sh [lähtekaust] [sihtkaust]`

## praks2/backupexec.sh
Varukoopia kuupäeva ja kontrolliga kaustast `praks2/src`: vaba ruumi kontroll, `.backupignore`,
kuiv jooks (`-n`), kompressori valik (`-c zstd|gzip|xz|auto`), arhiivi ja SHA-256 kontroll,
N viimase koopia hoidmine (`-k N`), logi `praks2/logs/backup.log`, ajutine kaust `mktemp` + `trap`.
Abi: `./backupexec.sh -h`

## php_paigaldus/php_paigaldus.sh
Kontrollib, kas php on paigaldatud; kui ei ole, paigaldab `php`, `libapache2-mod-php` ja `php-mysql`
(vajadusel ka `apache2`), seadistab apache2 php mooduli, `dir.conf` (index.php esimeseks) ja `php.ini`
(ajavöönd) ning kontrollib testlehega, et veebiserver käivitab php koodi. Kui php on juba olemas,
näitab selle asukohta ja versiooni. Kasutus: `sudo sh php_paigaldus.sh`. Vt `php_paigaldus/README.md`.

## lamp_paigaldus/lamp-install.sh
Üks skript LAMP-i paigaldamiseks (Debian 12): Apache2 + PHP 8.2 + MySQL Server 8.0 (Oracle MySQL APT, mitte MariaDB).
Enne iga komponendi paigaldamist kontrollib, kas see on juba olemas; puuduva paigaldab mitteinteraktiivselt
(MySQL `debconf-set-selections` abil), käivitab teenused (active + enabled), loob `/root/.my.cnf` (600),
muudab Apache vaikimisi lehe, loob `info.php` ja kuvab lõpus LAMP REPORT-i. Korduval käivitusel midagi uuesti ei paigaldata.
Kasutus: `chmod +x lamp-install.sh && ./lamp-install.sh` (root). Vt `lamp_paigaldus/README.md`.
