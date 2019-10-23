#!/bin/sh

# | ============================================================================
# | ADD THE MICROSOFT REPOSITORY INTO SOURCES
# | ============================================================================
echo "Registring Microsoft's GPG key"
curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
curl https://packages.microsoft.com/config/ubuntu/18.10/prod.list > /etc/apt/sources.list.d/mssql-release.list

# | Update packages to install dependencies
# | ---------------------------------------
echo "Updating repositories"
apt-get update

echo "Installing drivers' packages dependencies"
ACCEPT_EULA=Y apt-get install msodbcsql17
ACCEPT_EULA=Y apt-get install mssql-tools
apt -fy install unixodbc unixodbc-dev

# | Link MSSQL Tools into your's binaries
# | -------------------------------------
ln -s /opt/mssql-tools/bin/sqlcmd /usr/bin/sqlcmd
ln -s /opt/mssql-tools/bin/bcp /usr/bin/bcp

# | ============================================================================
# | INSTALLING SQL SERVER DRIVERS
# | ============================================================================
# | 
# | Create a directory to work on
# | -----------------------------
mkdir /tmp/mssql
cd /tmp/mssql

echo "Downloading drivers"
wget https://pecl.php.net/get/sqlsrv-5.6.1.tgz
wget https://pecl.php.net/get/pdo_sqlsrv-5.6.1.tgz

# | ----------------------------------------------------------------------------
# | Installing drivers for multiple PHP versions
# | ----------------------------------------------------------------------------
for version in 7.1 7.2 7.3; do
    if phpize$version -v >> /dev/null; then
        echo "Installing drivers for PHP $version"
        tar -xvzf ./sqlsrv-5.6.1.tgz
        cd /tmp/mssql/sqlsrv-5.6.1

        # | Compiling and installing the drivers (NGINX only)
        # | -------------------------------------------------
        phpize$version
        ./configure --with-php-config=php-config$version

        make
        make install

        cd /tmp/mssql
        tar -xvzf ./pdo_sqlsrv-5.6.1.tgz
        cd /tmp/mssql/pdo_sqlsrv-5.6.1

        phpize$version
        ./configure --with-php-config=php-config$version

        make
        make install

        echo "extension=sqlsrv.so" > /etc/php/$version/mods-available/sqlsrv.ini
        echo "extension=pdo_sqlsrv.so" > /etc/php/$version/mods-available/pdo_sqlsrv.ini

        # | Link the drivers on PHP-FPM
        # | ---------------------------
        ln -s /etc/php/$version/mods-available/sqlsrv.ini /etc/php/$version/cli/conf.d/20-sqlsrv.ini
        ln -s /etc/php/$version/mods-available/sqlsrv.ini /etc/php/$version/fpm/conf.d/20-sqlsrv.ini
        ln -s /etc/php/$version/mods-available/pdo_sqlsrv.ini /etc/php/$version/cli/conf.d/30-pdo_sqlsrv.ini
        ln -s /etc/php/$version/mods-available/pdo_sqlsrv.ini /etc/php/$version/fpm/conf.d/30-pdo_sqlsrv.ini

        # | Set the right permissions
        # | -------------------------
        chmod 644 /etc/php/$version/mods-available/sqlsrv.ini
        chmod 644 /etc/php/$version/mods-available/pdo_sqlsrv.ini
        chmod 777 /etc/php/$version/fpm/conf.d/30-pdo_sqlsrv.ini
        chmod 777 /etc/php/$version/fpm/conf.d/30-pdo_sqlsrv.ini

        cd /tmp/mssql
        rm -r /tmp/mssql/sqlsrv-5.6.1
        rm -r /tmp/mssql/pdo_sqlsrv-5.6.1
    fi

    /etc/init.d/php$version-fpm restart
done

# | Remove temporary folder
# | -----------------------
echo "Removing temporary folder"
cd ~/
rm -r /tmp/mssql
