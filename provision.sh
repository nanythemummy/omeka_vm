#!/bin/sh
export DEBIAN_FRONTEND=noninteractive
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US.UTF-8
dpkg-reconfigure locales

echo "Installing Mysql and some other helpful utilities"
echo "========================"
yes Y | apt-get install gnupg
yes Y | apt-get install wget
yes Y | apt-get install unzip


echo "Installing Apache2..."
echo "========================"
yes Y | apt-get install apache2
/usr/sbin/a2enmod rewrite

echo "Installing php"
echo "========================"
yes Y | apt-get install php libapache2-mod-php php-mysql php-xml

echo "Installing Mysql"
echo "========================"
if [ -d "/home/vagrant/mysql_install" ]; then
    rm -rf /home/vagrant/mysql_install
fi
mkdir mysql_install
cd mysql_install
downloadurl=$(echo "https://repo.mysql.com//mysql-apt-config_0.8.23-1_all.deb" | sed 's/0.8.23-1/'${MYSQL_VERSION}'/')
pkname=$(echo "mysql-apt-config_0.8.23-1_all.deb" | sed 's/0.8.23-1/'${MYSQL_VERSION}'/')
echo "Downloading $downloadurl"
wget $downloadurl
dpkg -i $pkname
apt-get update
apt-get install -y mysql-server

echo "Setting up omeka user and omeka table."
echo "Omeka user will be $DB_USER. the Omeka table is called omeka_db"
echo "========================="
mysql -e "CREATE DATABASE omeka_db CHARACTER SET utf8 COLLATE utf8_general_ci"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED by '$DB_PASSWORD'"
mysql -e "GRANT ALL PRIVILEGES ON omeka_db.* TO '$DB_USER'@'localhost'"

echo "Getting and setting up omeka."
echo "=========================="
cd /var/www/html
if  [ ! -d omeka ]; then
    wget https://github.com/omeka/Omeka/releases/download/v$OMEKA_VERSION/omeka-$OMEKA_VERSION.zip
    yes y | unzip omeka-$OMEKA_VERSION.zip
    mv omeka-$OMEKA_VERSION ./omeka
    rm omeka-$OMEKA_VERSION.zip
fi
cd omeka
cat db.ini | sed 's/^host *= "X*"/host = "localhost"/' | sed 's/^username *= "X*"/username ="'${DB_USER}'"/' | sed 's/^dbname *= "X*"/dbname="omeka_db"/' | sed 's/password *= "X*"/password = "'${DB_PASSWORD}'"/' > /home/vagrant/stuff.ini
mv /home/vagrant/stuff.ini db.ini
chown -R www-data:www-data .
echo "Configuring Apache to allow rewrites on the omeka directory"
echo "=========================="
if ! grep -q "/var/www/html/omeka" /etc/apache2/apache2.conf; then
    linestoadd="<Directory /var/www/html/omeka/>\n AllowOverride All\n Require all granted\n </Directory>\n"
    /etc/init.d/apache2 stop
    if [ -e ~/apache2.conf.new ]; then
        rm ~/apache2.conf.new
    fi
    cat /etc/apache2/apache2.conf | sed "/<Directory \/var\/www\/>/i ${linestoadd}"> ~/apache2.conf.new
    mv /etc/apache2/apache2.conf /etc/apache2/apache2.conf.old
    mv ~/apache2.conf.new /etc/apache2/apache2.conf
else
    echo "ALREADY ALLOWS REWRITE FOR OMEKA"
fi
echo "Installing Imagemagick--the convert file will be in /usr/bin"
echo "========================"
yes Y |  apt-get install imagemagick

/etc/init.d/apache2 restart