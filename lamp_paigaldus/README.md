# lamp_paigaldus – üks skript LAMP-i paigaldamiseks

**lamp-install.sh** paigaldab ja seadistab ühe käivitamisega LAMP-keskkonna Debian 12 (bookworm) serverisse:

- **Apache2**
- **PHP 8.2** (php8.2, php8.2-cli, php8.2-common, php8.2-mysql, libapache2-mod-php8.2)
- **MySQL Server 8.0** – Oracle MySQL ametlikust APT repositooriumist (mitte MariaDB)

Autor: Gert-Daniel Ilm, VOCO. Testitud 04.11.2026 Proxmoxi konteineris 22330 `gert-bash-lamp` (Debian 12 LXC):
Apache/2.4.68, PHP 8.2.35, MySQL 8.0.46. Väljundid: [kaivitus_1.log](kaivitus_1.log) (puhas masin) ja [kaivitus_2.log](kaivitus_2.log) (korduv käivitus).

Õpilase nimi ja grupp on skripti alguses muutujates `OPILANE` ja `GRUPP`.

## Kasutus

```bash
chmod +x lamp-install.sh
./lamp-install.sh                               # root-kasutajana
MYSQL_ROOT_PASS='MinuParool123' ./lamp-install.sh  # soovi korral oma MySQL root-parooliga
```

Kui parooli ette ei anta, genereerib skript juhusliku parooli. See salvestatakse ainult faili `/root/.my.cnf` (õigused 600), ekraanile seda ei kuvata.

## Tööpõhimõte

Enne iga põhikomponendi paigaldamist kontrollitakse, kas see on juba olemas:

```
KONTROLL -> Kas paigaldatud? -> JAH -> teavita kasutajat
                             -> EI  -> PAIGALDA -> KONTROLLI TULEMUST
```

| Samm | Kontroll | Kui puudub |
|------|----------|------------|
| Abipaketid (wget, ca-certificates, gnupg, debconf-utils, lsb-release) | `dpkg-query` + `grep` | `apt-get install` ainult puuduvad |
| MySQL Server 8.0 | `dpkg-query` (mysql-community-server versioon 8.0.*) / `mysqld --version` | `debconf-set-selections` → `mysql-apt-config_0.8.40-1_all.deb` → `apt-get install mysql-server` |
| Apache2 | `dpkg-query` + `grep` (pakett apache2) | `apt-get install -y apache2` |
| PHP 8.x | `php -r 'echo PHP_MAJOR_VERSION;'` + iga mooduli pakett | PHP 8.2 paketid, `a2enmod php8.2`, Apache2 restart |

Muud tegevused:

- `set -e` ja `DEBIAN_FRONTEND=noninteractive` – vea korral skript peatub, paigaldus ei küsi midagi.
- **debconf-set-selections** annab ette: repo (debian/bookworm), serveri versiooni `mysql-8.0`, MySQL Connectors/Tools välja lülitamise, valikute kinnituse (`Ok`), root-parooli (2×) ja autentimise valiku (*Use Strong Password Encryption*).
- Teenused **mysql** ja **apache2** käivitatakse ja lülitatakse automaatselt käivituma (`systemctl enable/start`), tulemus kontrollitakse (`is-active`, `is-enabled`).
- `/root/.my.cnf` (`[client]`, host, user, password) luuakse `umask 077` + `chmod 600` abil. Korduval käivitusel olemasolevat faili ei muudeta.
- `/var/www/html/index.html` kirjutatakse üle (õpilase nimi, grupp, teade „LAMP paigaldus õnnestus“, paigalduse aeg).
- `/var/www/html/info.php` sisuga `<?php phpinfo(); ?>`.
- Lõpus kontrollitakse `wget`-iga, et http://localhost/ ja info.php töötavad, ning väljastatakse **LAMP REPORT** (versioonid, active/enabled, failid). MySQL root-parooli raportis ei kuvata.

## Kontrollimine

```bash
apache2 -v
php -v
mysql --version
systemctl is-active apache2; systemctl is-enabled apache2
systemctl is-active mysql;   systemctl is-enabled mysql
mysql                        # logib sisse ilma parooli küsimata (/root/.my.cnf)
ls -l /root/.my.cnf          # -rw------- root root
```

Brauseris: `http://SERVERI_IP/` ja `http://SERVERI_IP/info.php`.

## Korduv käivitamine

Teisel käivitamisel skript ei paigalda midagi uuesti ja kuvab:

```
[ OK ] MySQL 8.0 on juba paigaldatud (...).
[ OK ] Apache2 on juba paigaldatud (...).
[ OK ] PHP 8.x on juba paigaldatud (versioon ...).
```
