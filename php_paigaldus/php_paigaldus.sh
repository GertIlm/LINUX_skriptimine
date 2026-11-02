
TEENUS=php

LISAPAKETID="libapache2-mod-php php-mysql"

VEEBISERVER=apache2

TESTLEHT=/var/www/html/test.php
TESTURL=http://localhost/test.php

if [ "$(id -u)" -ne 0 ]; then
    echo "Viga: skripti peab käivitama root kasutaja (või sudo abil)."
    exit 1
fi


PHP=$(dpkg-query -W -f='${Status}' $TEENUS 2>/dev/null | grep -c "ok installed")


if [ "$PHP" -eq 0 ]; then
   
    echo "$TEENUS ei ole paigaldatud."

   
    APACHE2=$(dpkg-query -W -f='${Status}' $VEEBISERVER 2>/dev/null | grep -c "ok installed")
    if [ "$APACHE2" -eq 0 ]; then
        echo "Veebiserverit $VEEBISERVER ei leitud - paigaldame ka selle."
        LISAPAKETID="$VEEBISERVER $LISAPAKETID"
    fi

    echo "Paigaldame $TEENUS ja vajalikud lisad: $LISAPAKETID"

   
    DEBIAN_FRONTEND=noninteractive apt-get install -y $TEENUS $LISAPAKETID

   
    if [ $? -eq 0 ]; then
        echo "$TEENUS on edukalt paigaldatud."
    else
        echo "Viga: $TEENUS paigaldamine ebaõnnestus!"
        exit 1
    fi

  
    PHP_VERSIOON=$(php -r 'echo PHP_MAJOR_VERSION . "." . PHP_MINOR_VERSION;')
    echo "Paigaldatud PHP versioon: $PHP_VERSIOON"

   
    if apache2ctl -M 2>/dev/null | grep -q "php"; then
        echo "apache2 php moodul (php$PHP_VERSIOON) on lubatud."
    else
        echo "Lubame apache2 php mooduli (php$PHP_VERSIOON)..."
        a2dismod mpm_event
        a2enmod mpm_prefork php$PHP_VERSIOON
    fi

   
    DIRCONF=/etc/apache2/mods-available/dir.conf
    if grep -q "DirectoryIndex index.php" $DIRCONF; then
        echo "$DIRCONF: index.php on juba esimesel kohal."
    else
        cp $DIRCONF $DIRCONF.bak
        sed -i -e 's/ index\.php//' -e 's/DirectoryIndex/DirectoryIndex index.php/' $DIRCONF
        echo "Muudetud $DIRCONF: $(grep DirectoryIndex $DIRCONF | tr -s ' \t' ' ')"
    fi

   
    PHPINI=/etc/php/$PHP_VERSIOON/apache2/php.ini
    if [ -f "$PHPINI" ]; then
        cp $PHPINI $PHPINI.bak
        sed -i 's|^;*date\.timezone *=.*|date.timezone = Europe/Tallinn|' $PHPINI
        echo "Muudetud $PHPINI: $(grep '^date.timezone' $PHPINI)"
    fi

   
    systemctl restart $VEEBISERVER
    echo "$VEEBISERVER taaskäivitatud: $(systemctl is-active $VEEBISERVER)"

   
    printf '%s\n' '<?php echo "PHP töötab! Versioon: " . phpversion() . "\n"; ?>' > $TESTLEHT
    VASTUS=$(php -r "echo @file_get_contents('$TESTURL');")
    if echo "$VASTUS" | grep -q "PHP töötab"; then
        echo "Kontroll OK - $TESTURL vastas: $VASTUS"
    else
        echo "Hoiatus: $TESTURL ei tagastanud oodatud vastust - kontrolli $VEEBISERVER ja $TEENUS seadistust."
    fi

elif [ "$PHP" -eq 1 ]; then
  
    echo "$TEENUS on juba paigaldatud."

    which php
    php -v | head -n 1

    
    apache2ctl -M 2>/dev/null | grep "php"
    echo "$VEEBISERVER: $(systemctl is-active $VEEBISERVER)"
fi


exit 0
