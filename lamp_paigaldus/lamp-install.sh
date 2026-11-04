#!/bin/bash
#
# lamp-install.sh - üks skript LAMP-i paigaldamiseks
#                   Apache2 + PHP 8.x + MySQL Server 8.0 (Oracle MySQL, mitte MariaDB)
#
# Autor:    Gert-Daniel Ilm, VOCO (IT-süsteemide spetsialist)
# Kuupäev:  04.11.2026
# Süsteem:  Debian 12 (bookworm), testitud Proxmoxi LXC-s 22330 gert-bash-lamp
#
# Kasutus (root-kasutajana):
#     chmod +x lamp-install.sh
#     ./lamp-install.sh
#
#     Soovi korral saab MySQL root-parooli ise ette anda:
#     MYSQL_ROOT_PASS='MinuParool123' ./lamp-install.sh
#     Kui parooli ei anta, genereerib skript juhusliku parooli ja salvestab
#     selle ainult faili /root/.my.cnf (õigused 600).
#
# Tööpõhimõte:
#     Enne iga põhikomponendi (MySQL 8.0, Apache2, PHP 8.x) paigaldamist
#     kontrollitakse, kas see on juba olemas:
#
#         KONTROLL -> Kas paigaldatud? -> JAH -> teavita kasutajat
#                                      -> EI  -> PAIGALDA -> KONTROLLI TULEMUST
#
#     Kõik paigaldused on mitteinteraktiivsed (DEBIAN_FRONTEND=noninteractive,
#     MySQL-i vastused antakse ette debconf-set-selections abil).
#     Skripti võib käivitada korduvalt - juba olemasolevat tarkvara uuesti ei paigaldata.

set -e
export DEBIAN_FRONTEND=noninteractive

# ---------------------------------------------------------------------------
# Muutujad
# ---------------------------------------------------------------------------

OPILANE="Gert-Daniel Ilm"           # õpilase ees- ja perekonnanimi
GRUPP="ITS24"                       # grupp/klass

PHP_VER="8.2"                       # Debian 12 vaikimisi PHP versioon
MYSQL_SERIES="8.0"                  # nõutud MySQL Serveri versioon
MYSQL_APT_DEB="mysql-apt-config_0.8.40-1_all.deb"
MYSQL_APT_URL="https://dev.mysql.com/get/${MYSQL_APT_DEB}"

WEB_DIR="/var/www/html"
INDEX_FAIL="${WEB_DIR}/index.html"
INFO_FAIL="${WEB_DIR}/info.php"
MYCNF="/root/.my.cnf"

ABIPAKETID="wget ca-certificates gnupg debconf-utils lsb-release"
PHP_PAKETID="php${PHP_VER} php${PHP_VER}-cli php${PHP_VER}-common php${PHP_VER}-mysql libapache2-mod-php${PHP_VER}"

PAIGALDUSE_AEG=$(date "+%Y-%m-%d %H:%M:%S")

# MySQL root-parool: keskkonnamuutujast või genereeritakse juhuslikult.
# Parooli ei kuvata kunagi ekraanile.
if [ -n "${MYSQL_ROOT_PASS:-}" ]; then
    PAROOL_ANTUD="jah"
else
    PAROOL_ANTUD="ei"
    MYSQL_ROOT_PASS=$(tr -dc 'A-Za-z0-9' < /dev/urandom 2>/dev/null | head -c 20)
fi

MYSQL_PAIGALDATI="ei"               # muutub "jah", kui MySQL paigaldati selle käivitusega
PHP_PAIGALDATI="ei"                 # muutub "jah", kui PHP-d/mooduleid paigaldati (-> Apache restart)

# ---------------------------------------------------------------------------
# Abifunktsioonid
# ---------------------------------------------------------------------------

info()    { echo -e "\e[1;34m[INFO]\e[0m $*"; }
ok()      { echo -e "\e[1;32m[ OK ]\e[0m $*"; }
hoiatus() { echo -e "\e[1;33m[HOIATUS]\e[0m $*"; }
viga()    { echo -e "\e[1;31m[VIGA]\e[0m $*" >&2; }
pealkiri() { echo; echo -e "\e[1m==== $* ====\e[0m"; }

# Kas pakett on paigaldatud? (dpkg-query + grep)
# Tagastab 0, kui paketi olek on "install ok installed".
pakett_olemas() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

# Paketi paigaldatud versioon (tühi, kui paketti pole)
paketi_versioon() {
    if pakett_olemas "$1"; then
        dpkg-query -W -f='${Version}' "$1"
    fi
}

# Teenuse olek: active/inactive ja enabled/disabled
# (|| true, et set -e ei katkestaks skripti, kui teenus ei tööta)
teenuse_olek()   { systemctl is-active "$1" 2>/dev/null || true; }
teenuse_autost() { systemctl is-enabled "$1" 2>/dev/null || true; }

# Tagab, et teenus töötab ja käivitub koos süsteemiga
teenus_toole() {
    local teenus="$1"
    if [ "$(teenuse_autost "$teenus")" != "enabled" ]; then
        info "Lülitan sisse teenuse $teenus automaatse käivitumise"
        systemctl enable "$teenus" >/dev/null 2>&1
    fi
    if [ "$(teenuse_olek "$teenus")" != "active" ]; then
        info "Käivitan teenuse $teenus"
        systemctl start "$teenus"
    fi
    if [ "$(teenuse_olek "$teenus")" = "active" ] && [ "$(teenuse_autost "$teenus")" = "enabled" ]; then
        ok "Teenus $teenus: active, enabled"
    else
        viga "Teenus $teenus ei tööta korralikult: $(teenuse_olek "$teenus"), $(teenuse_autost "$teenus")"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Eelkontrollid
# ---------------------------------------------------------------------------

if [ -z "$BASH_VERSION" ]; then
    echo "Käivita skript bashiga: ./lamp-install.sh või bash lamp-install.sh" >&2
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
    viga "Skript tuleb käivitada root-kasutajana (sudo -i või su -)."
    exit 1
fi

# HOME ja PATH võivad Proxmoxi konsoolis puudulikud olla:
# mysql klient otsib .my.cnf faili $HOME alt, apache2/a2enmod asuvad /usr/sbin all
export HOME="${HOME:-/root}"
export PATH="$PATH:/usr/local/sbin:/usr/sbin:/sbin"

. /etc/os-release
DISTRO="${ID}"
KOODNIMI="${VERSION_CODENAME}"
if [ "$DISTRO" != "debian" ] || [ "$KOODNIMI" != "bookworm" ]; then
    hoiatus "Skript on tehtud Debian 12 (bookworm) jaoks, see süsteem on: ${PRETTY_NAME}"
fi

echo
echo "LAMP paigaldus - Apache2 + PHP ${PHP_VER} + MySQL ${MYSQL_SERIES}"
echo "Õpilane: ${OPILANE}, grupp: ${GRUPP}"
echo "Algus:   ${PAIGALDUSE_AEG}"

# ===========================================================================
# 1. Skripti ettevalmistamine: paketiloend ja abipaketid
# ===========================================================================
pealkiri "1. Paketiloend ja abipaketid"

info "Uuendan paketiloendit (apt-get update)"
apt-get update -qq

PUUDU=""
for p in $ABIPAKETID; do
    if pakett_olemas "$p"; then
        ok "Abipakett $p on juba paigaldatud."
    else
        PUUDU="$PUUDU $p"
    fi
done
if [ -n "$PUUDU" ]; then
    info "Paigaldan puuduvad abipaketid:$PUUDU"
    apt-get install -y -qq $PUUDU > /dev/null
    ok "Abipaketid paigaldatud:$PUUDU"
fi

# ===========================================================================
# 2. MySQL Server 8.0 (Oracle MySQL APT repositoorium)
# ===========================================================================
pealkiri "2. MySQL Server ${MYSQL_SERIES}"

# MariaDB ja Oracle MySQL ei saa korraga olla - MariaDB puhul katkestame
if pakett_olemas mariadb-server; then
    viga "Süsteemis on MariaDB (mariadb-server). Töö nõuab Oracle MySQL ${MYSQL_SERIES}-t."
    viga "Eemalda MariaDB käsitsi ja käivita skript uuesti."
    exit 1
fi

# Kontroll: kas MySQL Server 8.0 on paigaldatud?
MYSQL_PAKETI_VER=$(paketi_versioon mysql-community-server)
if [ -z "$MYSQL_PAKETI_VER" ]; then
    MYSQL_PAKETI_VER=$(paketi_versioon mysql-server)
fi

if [[ "$MYSQL_PAKETI_VER" == ${MYSQL_SERIES}.* ]] || \
   { command -v mysqld > /dev/null && mysqld --version 2>/dev/null | grep -q "Ver ${MYSQL_SERIES}\."; }; then
    # JAH -> teavita ja ära paigalda uuesti
    ok "MySQL ${MYSQL_SERIES} on juba paigaldatud ($(mysql --version | awk '{print $3}'))."

elif [ -n "$MYSQL_PAKETI_VER" ]; then
    # Mõni muu MySQL versioon - üle ei kirjuta
    hoiatus "MySQL on paigaldatud, kuid versioon on ${MYSQL_PAKETI_VER} (mitte ${MYSQL_SERIES}). Ei paigalda üle."

else
    # EI -> paigalda MySQL 8.0
    info "MySQL ${MYSQL_SERIES} puudub - paigaldan Oracle MySQL APT repositooriumist."

    # 2.1 debconf-set-selections: vastused mysql-apt-config ja mysql-community-server
    #     paketi küsimustele, et paigaldus oleks mitteinteraktiivne.
    #     - repo-distro / repo-codename:  Debian 12 (bookworm)
    #     - select-server:                MySQL Server 8.0
    #     - select-connectors:            mittevajalikud MySQL Tools/Connectors paketid välja
    #     - select-product:               Ok (valikute kinnitamine)
    #     - root-pass / re-root-pass:     MySQL root-parool
    #     - default-auth-override:        autentimise valik (caching_sha2_password)
    info "Eelseadistan debconf vastused (debconf-set-selections)"
    debconf-set-selections <<EOF
mysql-apt-config mysql-apt-config/repo-distro select ${DISTRO}
mysql-apt-config mysql-apt-config/repo-codename select ${KOODNIMI}
mysql-apt-config mysql-apt-config/select-server select mysql-${MYSQL_SERIES}
mysql-apt-config mysql-apt-config/select-connectors select Disabled
mysql-apt-config mysql-apt-config/select-product select Ok
mysql-community-server mysql-community-server/root-pass password ${MYSQL_ROOT_PASS}
mysql-community-server mysql-community-server/re-root-pass password ${MYSQL_ROOT_PASS}
mysql-community-server mysql-server/default-auth-override select Use Strong Password Encryption (RECOMMENDED)
EOF

    # 2.2 Oracle MySQL APT konfiguratsioonipakett
    if pakett_olemas mysql-apt-config; then
        info "mysql-apt-config on juba olemas - seadistan uuesti (MySQL ${MYSQL_SERIES})"
        dpkg-reconfigure -f noninteractive mysql-apt-config
    else
        info "Laadin alla ${MYSQL_APT_DEB}"
        wget -q -O "/tmp/${MYSQL_APT_DEB}" "$MYSQL_APT_URL"
        info "Paigaldan konfiguratsioonipaketi"
        apt-get install -y -qq "/tmp/${MYSQL_APT_DEB}" > /dev/null
        rm -f "/tmp/${MYSQL_APT_DEB}"
    fi

    # Kontroll: kas repo seadistati MySQL 8.0 peale?
    if grep -rqs "mysql-${MYSQL_SERIES}" /etc/apt/sources.list.d/; then
        ok "Oracle MySQL APT repositoorium seadistatud (mysql-${MYSQL_SERIES})."
    else
        viga "MySQL APT repositooriumi seadistamine ebaõnnestus (mysql-${MYSQL_SERIES} puudub)."
        exit 1
    fi

    # 2.3 Paketiloendi uuendus ja mysql-server paigaldus
    info "Uuendan paketiloendit"
    apt-get update -qq
    info "Paigaldan mysql-server (see võib võtta mõne minuti)"
    apt-get install -y -qq mysql-server > /dev/null

    # Kontrolli tulemust
    if [[ "$(paketi_versioon mysql-community-server)" == ${MYSQL_SERIES}.* ]]; then
        ok "MySQL paigaldatud: $(mysql --version | awk '{print $3}')"
        MYSQL_PAIGALDATI="jah"
    else
        viga "MySQL ${MYSQL_SERIES} paigaldamine ebaõnnestus."
        exit 1
    fi
fi

# 2.4 MySQL teenus: töötab ja käivitub automaatselt
if pakett_olemas mysql-community-server || pakett_olemas mysql-server; then
    teenus_toole mysql
fi

# 2.5 /root/.my.cnf - root saab kasutada mysql klienti ilma parooli sisestamata
kirjuta_mycnf() {
    # umask 077 -> fail luuakse kohe ainult root-ile loetavana
    ( umask 077
      cat > "$MYCNF" <<EOF
[client]
host=localhost
user=root
password=${MYSQL_ROOT_PASS}
EOF
    )
    chmod 600 "$MYCNF"
    chown root:root "$MYCNF"
}

if [ "$MYSQL_PAIGALDATI" = "jah" ]; then
    # MySQL paigaldati praegu -> parool on teada, loome faili
    kirjuta_mycnf
    ok "Loodud $MYCNF (õigused 600)."
elif [ -f "$MYCNF" ]; then
    # Fail on olemas eelmisest käivitusest - ei muuda (parool peab jääma samaks)
    chmod 600 "$MYCNF"
    ok "$MYCNF on juba olemas - ei muuda."
elif [ "$PAROOL_ANTUD" = "jah" ]; then
    kirjuta_mycnf
    ok "Loodud $MYCNF etteantud parooliga (õigused 600)."
else
    hoiatus "$MYCNF puudub ja MySQL root-parool pole teada."
    hoiatus "Käivita: MYSQL_ROOT_PASS='parool' ./lamp-install.sh"
fi

# Kontroll: kas mysql töötab ilma parooli küsimata?
if [ -f "$MYCNF" ] && mysql -e "SELECT VERSION();" > /dev/null 2>&1; then
    ok "mysql klient töötab ilma parooli sisestamata ($MYCNF)."
else
    hoiatus "mysql klient ei saanud $MYCNF abil ühendust."
fi
