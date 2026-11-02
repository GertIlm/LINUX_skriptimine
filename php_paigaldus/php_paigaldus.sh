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
