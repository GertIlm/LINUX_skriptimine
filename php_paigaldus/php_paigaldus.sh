#!/bin/bash
# ==================================================================
# Skript:     php_paigaldus.sh
# Autor:      Gert-Daniel Ilm
# Kuupäev:    02.11.2026
# Aine:       Skriptimisvahendid - BASH haldus, praks3
#             (Teenuste paigaldus - php)
#
# Kirjeldus:  Skript kontrollib, kas php on masinasse paigaldatud.
#               - kui EI OLE paigaldatud, siis paigaldab php koos
#                 veebiserveris töötamiseks vajalike abipakettidega
#                 (libapache2-mod-php, php-mysql; vajadusel ka
#                 veebiserveri apache2), teeb vajalikud muudatused
#                 konfiguratsioonifailides ja kontrollib, et
#                 veebiserver käivitab php koodi
#               - kui ON paigaldatud, siis annab sellest teada ning
#                 näitab php asukohta, versiooni ja apache2 mooduli
#
# Märkus:     Juhendis mainitud php7.0 pakette Debian 12 (bookworm)
#             hoidlates ei ole - Debian 12 vaikimisi PHP on 8.2.
#             Seepärast paigaldame metapaketid php, libapache2-mod-php
#             ja php-mysql, mis toovad kaasa just selle PHP versiooni,
#             mida distributsioon pakub (Debian 12 -> php8.2,
#             Debian 13 -> php8.4). Nii töötab skript muutmata kujul
#             ka uuemates versioonides.
#
# Kasutamine: skript tuleb käivitada root kasutajana (või sudo-ga)
#               chmod +x php_paigaldus.sh
#               ./php_paigaldus.sh
#             või
#               sh php_paigaldus.sh
#             (skript on kirjutatud POSIX sh süntaksis, seega töötab
#             nii bash-i kui ka sh/dash-iga)
# ==================================================================

# Teenus (pakett), mille olemasolu kontrollime ja vajadusel paigaldame
TEENUS=php
# Abipaketid php tööks veebiserveris:
#   libapache2-mod-php - apache2 moodul, mis käivitab php koodi
#   php-mysql          - php tugi MySQL/MariaDB andmebaasiga töötamiseks
LISAPAKETID="libapache2-mod-php php-mysql"
# Veebiserver, mille all php töötab
VEEBISERVER=apache2
# Testleht, millega kontrollime, et veebiserver käivitab php koodi
TESTLEHT=/var/www/html/test.php
TESTURL=http://localhost/test.php

# ------------------------------------------------------------------
# 1. Õiguste kontroll
# Pakettide paigaldamiseks ja konfiguratsioonifailide muutmiseks on
# vaja root õigusi. Käsk "id -u" annab kasutaja ID, root ID on 0.
# ------------------------------------------------------------------
if [ "$(id -u)" -ne 0 ]; then
    echo "Viga: skripti peab käivitama root kasutaja (või sudo abil)."
    exit 1
fi

# ------------------------------------------------------------------
# 2. Kontrollime, kas php on paigaldatud
# dpkg-query -W -f='${Status}' näitab paketi olekut, paigaldatud
# paketi korral on väljund "install ok installed".
# 2>/dev/null peidab veateate "no packages found matching ...",
# kui sellist paketti masinas üldse ei ole.
# grep -c loeb, mitu korda leiti tekst "ok installed":
#   1 -> php on paigaldatud
#   0 -> php ei ole paigaldatud
# Tulemuse salvestame muutujasse PHP.
# ------------------------------------------------------------------
PHP=$(dpkg-query -W -f='${Status}' $TEENUS 2>/dev/null | grep -c "ok installed")

# ------------------------------------------------------------------
# 3. Tingimuslause - muutuja väärtuse järgi otsustame, mida teha
# ------------------------------------------------------------------
if [ "$PHP" -eq 0 ]; then
    # "ok installed" ei leitud ühtegi korda -> php puudub
    echo "$TEENUS ei ole paigaldatud."

    # php tööks veebis on vaja veebiserverit - kui apache2 puudub,
    # lisame selle paigaldatavate pakettide hulka
    APACHE2=$(dpkg-query -W -f='${Status}' $VEEBISERVER 2>/dev/null | grep -c "ok installed")
    if [ "$APACHE2" -eq 0 ]; then
        echo "Veebiserverit $VEEBISERVER ei leitud - paigaldame ka selle."
        LISAPAKETID="$VEEBISERVER $LISAPAKETID"
    fi

    echo "Paigaldame $TEENUS ja vajalikud lisad: $LISAPAKETID"

    # Uuendame pakettide nimekirja ja paigaldame paketid.
    # DEBIAN_FRONTEND=noninteractive - paigaldus ei esita küsimusi
    # -y vastab paigaldaja küsimusele automaatselt "jah"
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y $TEENUS $LISAPAKETID

    # $? sisaldab eelmise käsu väljumiskoodi (exit code):
    # 0 = käsk õnnestus, muu väärtus = tekkis viga
    if [ $? -eq 0 ]; then
        echo "$TEENUS on edukalt paigaldatud."
    else
        echo "Viga: $TEENUS paigaldamine ebaõnnestus!"
        exit 1
    fi

    # --------------------------------------------------------------
    # 4. Konfiguratsioonifailide muudatused
    # Paigaldatud PHP versioon (nt 8.2) on vajalik mooduli nime ja
    # konfiguratsioonifailide teede jaoks (/etc/php/8.2/...).
    # --------------------------------------------------------------
    PHP_VERSIOON=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')
    echo "Paigaldatud PHP versioon: $PHP_VERSIOON"

    # 4.1 apache2 php moodul peab olema lubatud.
    # Paigaldamisel lubatakse see tavaliselt automaatselt, kuid
    # kontrollime üle. php moodul töötab ainult koos mpm_prefork-iga,
    # seega vajadusel lülitame mpm_event välja.
    if apache2ctl -M 2>/dev/null | grep -q "php"; then
        echo "apache2 php moodul (php$PHP_VERSIOON) on lubatud."
    else
        echo "Lubame apache2 php mooduli (php$PHP_VERSIOON)..."
        a2dismod mpm_event
        a2enmod mpm_prefork php$PHP_VERSIOON
    fi

    # 4.2 DirectoryIndex (fail dir.conf) määrab, millist faili
    # kataloogi avamisel esimesena näidatakse. Tõstame index.php
    # esimeseks, et php leht oleks eelistatud index.html ees.
    # Enne muutmist teeme failist varukoopia (.bak).
    DIRCONF=/etc/apache2/mods-available/dir.conf
    if grep -q "DirectoryIndex index.php" $DIRCONF; then
        echo "$DIRCONF: index.php on juba esimesel kohal."
    else
        cp $DIRCONF $DIRCONF.bak
        sed -i -e 's/ index\.php//' -e 's/DirectoryIndex/DirectoryIndex index.php/' $DIRCONF
        echo "Muudetud $DIRCONF: $(grep DirectoryIndex $DIRCONF | tr -s ' \t' ' ')"
    fi

    # 4.3 php.ini - määrame ajavööndi (date.timezone), muidu
    # kasutavad php kuupäevafunktsioonid UTC aega.
    PHPINI=/etc/php/$PHP_VERSIOON/apache2/php.ini
    if [ -f "$PHPINI" ]; then
        cp $PHPINI $PHPINI.bak
        sed -i 's|^;*date\.timezone *=.*|date.timezone = Europe/Tallinn|' $PHPINI
        echo "Muudetud $PHPINI: $(grep '^date.timezone' $PHPINI)"
    fi

    # 4.4 Muudatuste rakendamiseks taaskäivitame veebiserveri
    systemctl restart $VEEBISERVER
    echo "$VEEBISERVER taaskäivitatud: $(systemctl is-active $VEEBISERVER)"

    # --------------------------------------------------------------
    # 5. Kontrollime, et veebiserver käivitab php koodi
    # Loome testlehe ja pärime selle veebiserverist. Päringu teeme
    # php enda abil (file_get_contents), nii ei ole vaja curl-i.
    # Kui php ei tööta, tagastaks veebiserver lähtekoodi "<?php ...".
    # --------------------------------------------------------------
    # (printf '%s\n' kirjutab teksti muutmata kujul - sh/dash echo
    # tõlgendaks muidu "\n" reavahetuseks)
    printf '%s\n' '<?php echo "PHP töötab! Versioon: " . phpversion() . "\n"; ?>' > $TESTLEHT
    VASTUS=$(php -r "echo @file_get_contents('$TESTURL');")
    if echo "$VASTUS" | grep -q "PHP töötab"; then
        echo "Kontroll OK - $TESTURL vastas: $VASTUS"
    else
        echo "Hoiatus: $TESTURL ei tagastanud oodatud vastust - kontrolli $VEEBISERVER ja $TEENUS seadistust."
    fi
fi

# Skript lõpetas töö edukalt - väljumiskood 0
exit 0
