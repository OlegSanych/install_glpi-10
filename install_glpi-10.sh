#!/bin/bash
#
# Скрипт установки GLPI 10 на Astra Linux 1.7.x, Debian 11, Ubuntu 22.04
#
# Автор идеи: jr0w3
# Доработка и адаптация под ALSE 1.7.x: OlegSanych 
# Version: 1.1.1
#

function warn(){
    echo -e '\e[31m'$1'\e[0m';
}
function info(){
    echo -e '\e[36m'$1'\e[0m';
}

function check_root()
{
# Проверка привилегий root
if [[ "$(id -u)" -ne 0 ]]
then
        warn "Этот скрипт должен быть запущен от root" >&2
  exit 1
else
        info "Root привилегии: OK"
fi
}

function check_distro()
{
# Переменные 
## Версия Debian
DEBIAN_VERSIONS=("11")
## Версия Astra Linux
ASTRA_VERSIONS=("1.7_x86-64")
# Версия Ubuntu
UBUNTU_VERSIONS=("22.04")

# Получение имени дистрибутива
DISTRO=$(lsb_release -is)

# Получение версии дистрибутива
VERSION=$(lsb_release -rs)

# Проверяет, является ли этот дистрибутив Debian или Astra Linux
if [ "$DISTRO" == "Debian" ] || [ "AstraLinux" ]; then
        # Проверяет, является ли версия Debian или Astra Libux приемлемой
        if [[ " ${DEBIAN_VERSIONS[*]} " == *" $VERSION "* ]] || [[ " ${ASTRA_VERSIONS[*]} " == *" $VERSION "* ]]; then
                info "Ваша версия операционной системы ($DISTRO $VERSION) совместима."
        else
                warn "Ваша версия операционной системы ($DISTRO $VERSION) не поддерживается."
                warn "Вы можете продолжить выполнение скрипта принудительно, на свой страх и риск."
                info "Продолжить? [yes/no]"
                read response
                if [ $response == "yes" ]; then
                info "Идет выполнение..."
                elif [ $response == "no" ]; then
                info "Выход..."
                exit 1
                else
                warn "Недопустимый ответ. Выход..."
                exit 1
                fi
        fi

# Проверяет, является ли этот дистрибутив Ubuntu
elif [ "$DISTRO" == "Ubuntu" ]; then
        # Проверяет, является ли версия Ubuntu приемлемой
        if [[ " ${UBUNTU_VERSIONS[*]} " == *" $VERSION "* ]]; then
                info "Ваша версия операционной системы ($DISTRO $VERSION) совместима."
        else
                warn "Ваша версия операционной системы ($DISTRO $VERSION) не поддерживается."
                warn "Вы можете продолжить выполнение скрипта принудительно, на свой страх и риск."
                info "Продолжить? [yes/no]"
                read response
                if [ $response == "yes" ]; then
                info "Идет выполнение..."
                elif [ $response == "no" ]; then
                info "Выход..."
                exit 1
                else
                warn "Недопустимый ответ. Выход..."
                exit 1
                fi
        fi
# Если это совсем другой дистрибутив
else
        warn "Ваш дистрибутив отличается от Astra Linux, Debian, Ubuntu и не поддерживается!"
        exit 1
fi
}

function network_info()
{
INTERFACE=$(ip route | awk 'NR==1 {print $5}')
IPADRESS=$(ip addr show $INTERFACE | grep inet | awk '{ print $2; }' | sed 's/\/.*$//' | head -n 1)
HOST=$(hostname)
}

function confirm_installation()
{
warn "Теперь требуется скачать необходимые пакеты и настроить GLPI."
info "Продолжить? [yes/no]"
read confirm
if [ $confirm == "yes" ]; then
        info "Идет выполнение..."
elif [ $confirm == "no" ]; then
        info "Выход..."
        exit 1
else
        warn "Недопустимый ответ. Выход..."
        exit 1
fi
}

function install_packages()
{
info "Идет установка пакетов..."
sleep 1
apt update
if [ "$DISTRO" == "AstraLinux" ]; then
apt install --yes --no-install-recommends \
    wget \
    apache2 \
    mariadb-server \
    perl \
    curl \
    jq \
    php8.1 \
    info "Идет установка рассширений для php..."
    apt install --yes --no-install-recommends \
    php8.1-ldap \
    php8.1-imap \
    php8.1-apcu \
    #php8.1-xmlrpc \
    #php8.1-cas \
    php8.1-mysqli \
    php8.1-mbstring \
    php8.1-curl \
    php8.1-gd \
    php8.1-simplexml \
    php8.1-xml \
    php8.1-intl \
    php8.1-zip \
    php8.1-bz2
else
apt install --yes --no-install-recommends \
    apache2 \
    mariadb-server \
    perl \
    curl \
    jq \
    php
    info "Идет установка рассширений для php..."
    apt install --yes --no-install-recommends \
    php-ldap \
    php-imap \
    php-apcu \
    php-xmlrpc \
    php-cas \
    php-mysqli \
    php-mbstring \
    php-curl \
    php-gd \
    php-simplexml \
    php-xml \
    php-intl \
    php-zip \
    php-bz2
fi
systemctl enable mariadb
systemctl enable apache2
}

function mariadb_configure()
{
info "Идет настройка БД MariaDB..."
sleep 1
SLQROOTPWD=$(openssl rand -base64 48 | cut -c1-12 )
SQLGLPIPWD=$(openssl rand -base64 48 | cut -c1-12 )
systemctl start mariadb
sleep 1

# Установка пароля root
mysql -e "UPDATE mysql.user SET Password = PASSWORD('$SLQROOTPWD') WHERE User = 'root'"

# Удаление анонимных учетных записей пользователей
mysql -e "DELETE FROM mysql.user WHERE User = ''"

# Отключение удаленного входа в систему root
mysql -e "DELETE FROM mysql.user WHERE User = 'root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"

# Удаление тестовой базы данных
mysql -e "DROP DATABASE test"

# Обновление привелегий пользователя
mysql -e "FLUSH PRIVILEGES"

mysql -u root -p'$SLQROOTPWD' <<EOF
# Создание новой базы данных
CREATE DATABASE glpi;
# Создание нового пользователя
CREATE USER 'glpi_user'@'localhost' IDENTIFIED BY '$SQLGLPIPWD';
# Предоставление привилегий новому пользователю для новой базы данных
GRANT ALL PRIVILEGES ON glpi.* TO 'glpi_user'@'localhost';
# Обновление привелегий пользователя
FLUSH PRIVILEGES;
EOF
}

function install_glpi()
{
info "Идет загрузка и установка последней версии GLPI..."
# Получение ссылки на загрузку последней версии GLPI
DOWNLOADLINK=$(curl -s https://api.github.com/repos/glpi-project/glpi/releases/latest | jq -r '.assets[0].browser_download_url')
wget -O /tmp/glpi-latest.tgz $DOWNLOADLINK
tar xzf /tmp/glpi-latest.tgz -C /var/www/html/

# Добавление прав на каталог
chown -R www-data:www-data /var/www/html/glpi
chmod -R 775 /var/www/html/glpi

# Настройка виртуального хоста
cat > /etc/apache2/sites-available/000-default.conf << EOF
<VirtualHost *:80>
       DocumentRoot /var/www/html/glpi/public  
       <Directory /var/www/html/glpi/public>
                Require all granted
                RewriteEngine On
                RewriteCond %{REQUEST_FILENAME} !-f
                RewriteRule ^(.*)$ index.php [QSA,L]
        </Directory>
        
        LogLevel warn
        ErrorLog \${APACHE_LOG_DIR}/error-glpi.log
        CustomLog \${APACHE_LOG_DIR}/access-glpi.log combined
        
</VirtualHost>
EOF

# Настройка параметров веб-сервера Apache
echo "ServerSignature Off" >> /etc/apache2/apache2.conf
echo "ServerTokens Prod" >> /etc/apache2/apache2.conf
if [ "$DISTRO" == "AstraLinux" ]; then
    echo "AstraMode off" >> /etc/apache2/apache2.conf
fi

# Настройка задач планировщика
echo "*/2 * * * * www-data /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/cron.d/glpi

# Включение модуля Apache mod rewrite
a2enmod rewrite && systemctl restart apache2
}

function setup_db()
{
info "Идет настройка GLPI..."
cd /var/www/html/glpi
php bin/console db:install --db-name=glpi --db-user=glpi_user --db-password=$SQLGLPIPWD --no-interaction
rm -rf /var/www/html/glpi/install
}

function display_credentials()
{
info "=======> Учетные данные GLPI  <======="
warn "Важно!!! Необходимо записать и сохранить эти данные. Если они будут утеряны, то восстановить их будет невозможно"
info "==> GLPI:"
info "По умолчанию используются следующие учетные записи пользователей:"
info "Имя пользователя      -  Пароль       -  Уровень доступа"
info "glpi                  -  glpi         -  admin account,"
info "tech                  -  tech         -  technical account,"
info "normal                -  normal       -  normal account,"
info "post-only             -  postonly     -  post-only account."
echo ""
info "Доступ к странице авторизации:"
info "http://$IPADRESS или http://$HOST" 
echo ""
info "==> Учетные данные БД:"
info "root пароль:           $SLQROOTPWD"
info "glpi_user пароль:      $SQLGLPIPWD"
info "Имя БД:                glpi"
info "<==========================================>"
echo ""
info "Если у вас возникнут какие-либо проблемы с этим скриптом, пожалуйста, сообщите об этом на GitHub: "
}


check_root
check_distro
confirm_installation
network_info
install_packages
mariadb_configure
install_glpi
setup_db
display_credentials