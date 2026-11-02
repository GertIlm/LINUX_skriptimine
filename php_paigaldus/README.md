# php_paigaldus

BASH haldus – praks3 (Teenuste paigaldus – php). Autor: Gert-Daniel Ilm, VOCO.

## php_paigaldus.sh

Skript kontrollib, kas **php** on masinasse paigaldatud.

- **ei ole paigaldatud** – paigaldab `php` koos veebiserveris töötamiseks vajalike abipakettidega
  (`libapache2-mod-php`, `php-mysql`; kui veebiserverit pole, siis ka `apache2`), teeb vajalikud
  muudatused konfiguratsioonifailides ja kontrollib testlehega, et veebiserver käivitab php koodi
- **on juba paigaldatud** – teatab sellest ning näitab php asukohta (`which php`), versiooni ja apache2 php moodulit

Väljund on analoogne skriptiga `apache_paigaldus.sh` (repo `bash_skriptimine`).

### Miks mitte php7.0?

Juhendis on toodud paketid `php7.0`, `libapache2-mod-php7.0` ja `php7.0-mysql`, kuid neid Debian 12 (bookworm)
hoidlates ei ole – Debian 12 vaikimisi PHP on **8.2**. Seepärast kasutab skript metapakette
`php`, `libapache2-mod-php` ja `php-mysql`, mis paigaldavad distributsiooni vaikimisi PHP versiooni
(Debian 12 → 8.2, Debian 13 → 8.4). Nii töötab skript muutmata kujul ka uuemates versioonides.

### Tööpõhimõte

```
                 ┌───────────────────────────────┐
                 │ root õigused? (id -u = 0)     │── ei ──> "Viga: ..." , exit 1
                 └───────────────┬───────────────┘
                                 │ jah
                 ┌───────────────┴───────────────┐
                 │ Kas php on paigaldatud?       │
                 │ dpkg-query ... | grep -c      │
                 └───────────────┬───────────────┘
                      ei (0)     │     jah (1)
         ┌───────────────────────┴───────────────────────┐
         ▼                                               ▼
 (apache2 puudub? -> lisa ka apache2)        "php on juba paigaldatud"
 apt-get install php libapache2-mod-php      which php, php -v
                 php-mysql                   apache2ctl -M | grep php
 konfiguratsioon:                            systemctl is-active apache2
   - apache2 php moodul lubatud
   - dir.conf: index.php esimeseks
   - php.ini: date.timezone = Europe/Tallinn
 systemctl restart apache2
 testleht /var/www/html/test.php -> kontroll
```

Paigalduse tuvastamiseks kasutatakse käsku

```bash
dpkg-query -W -f='${Status}' php 2>/dev/null | grep -c "ok installed"
```

mis tagastab `1`, kui pakett on paigaldatud, ja `0`, kui ei ole.

### Konfiguratsioonifailide muudatused

| Fail | Muudatus | Miks |
|------|----------|------|
| apache2 moodulid (`a2enmod`) | `php8.2` moodul lubatud, vajadusel `mpm_event` → `mpm_prefork` | php moodul töötab ainult koos prefork MPM-iga |
| `/etc/apache2/mods-available/dir.conf` | `DirectoryIndex index.php index.html ...` | kataloogi avamisel eelistatakse `index.php` faili |
| `/etc/php/8.2/apache2/php.ini` | `date.timezone = Europe/Tallinn` | php kuupäevafunktsioonid kasutavad Eesti aega |

Enne muutmist tehakse failidest varukoopia (`.bak`). Muudatuste järel taaskäivitatakse `apache2`.

### Kontrollimine

Skript käivitatakse root kasutajana:

```bash
chmod +x php_paigaldus.sh
sh php_paigaldus.sh
```

### Näidiskatsed

Testitud puhtas masinas `gert-bash-praks3` (Proxmox LXC 22320, Debian 12.12, enne katset php ja apache2 puudusid).

**1. php ei ole paigaldatud** – skript paigaldab paketid ja seadistab need:

```
php ei ole paigaldatud.
Veebiserverit apache2 ei leitud - paigaldame ka selle.
Paigaldame php ja vajalikud lisad: apache2 libapache2-mod-php php-mysql
...
The following NEW packages will be installed:
  apache2 apache2-bin apache2-data apache2-utils libapache2-mod-php
  libapache2-mod-php8.2 libapr1 libaprutil1 libaprutil1-dbd-sqlite3
  libaprutil1-ldap libcurl4 liblua5.3-0 libsodium23 php php-common php-mysql
  php8.2 php8.2-cli php8.2-common php8.2-mysql php8.2-opcache php8.2-readline
  psmisc
...
php on edukalt paigaldatud.
Paigaldatud PHP versioon: 8.2
apache2 php moodul (php8.2) on lubatud.
Muudetud /etc/apache2/mods-available/dir.conf: DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm
Muudetud /etc/php/8.2/apache2/php.ini: date.timezone = Europe/Tallinn
apache2 taaskäivitatud: active
Kontroll OK - http://localhost/test.php vastas: PHP töötab! Versioon: 8.2.35
```

**2. php on juba paigaldatud** – skript teatab sellest ja näitab php asukohta ning versiooni:

```
php on juba paigaldatud.
/usr/bin/php
PHP 8.2.35 (cli) (built: Oct 21 2026 06:29:51) (NTS)
 php_module (shared)
apache2: active
```

**3. käivitamine tavakasutajana** – skript keeldub (väljumiskood 1):

```
Viga: skripti peab käivitama root kasutaja (või sudo abil).
```
