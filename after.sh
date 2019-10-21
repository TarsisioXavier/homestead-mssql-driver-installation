#!/bin/sh

# | ============================================================================
# | ADD THE MICROSOFT REPOSITORY INTO SOURCES
# | ============================================================================
sudo curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
sudo curl https://packages.microsoft.com/config/ubuntu/18.10/prod.list > /etc/apt/sources.list.d/mssql-release.list

# | Update packages to install dependencies
# | ---------------------------------------
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install msodbcsql17
sudo ACCEPT_EULA=Y apt-get install mssql-tools
sudo apt -fy install unixodbc unixodbc-dev

# | Maps MSSQL binaries into PATH
# | -----------------------------
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc

# | ============================================================================
# | INSTALLING SQL SERVER DRIVERS
# | ============================================================================
# | 
# | Create a directory to work on
# | -----------------------------
mkdir /tmp/mssql
cd /tmp/mssql

wget https://pecl.php.net/get/sqlsrv-5.6.1.tgz
wget https://pecl.php.net/get/pdo_sqlsrv-5.6.1.tgz

# | ----------------------------------------------------------------------------
# | Installing drivers for multiple PHP versions
# | ----------------------------------------------------------------------------
for version in 7.1 7.2 7.3; do
    if phpize$version -v >> /dev/null; then
        tar -xvzf ./sqlsrv-5.6.1.tgz
        cd /tmp/mssql/sqlsrv-5.6.1

        # | Compiling and installing the drivers (NGINX only)
        # | -------------------------------------------------
        sudo phpize$version
        sudo ./configure --with-php-config=php-config$version

        sudo make
        sudo make install

        cd /tmp/mssql
        tar -xvzf ./pdo_sqlsrv-5.6.1.tgz
        cd /tmp/mssql/pdo_sqlsrv-5.6.1

        sudo phpize$version
        sudo ./configure --with-php-config=php-config$version

        sudo make
        sudo make install

        sudo echo "extension=sqlsrv.so" > /etc/php/$version/mods-available/sqlsrv.ini
        sudo echo "extension=pdo_sqlsrv.so" > /etc/php/$version/mods-available/pdo_sqlsrv.ini

        # | Link the drivers on PHP-FPM
        # | ---------------------------
        sudo ln -s /etc/php/$version/mods-available/sqlsrv.ini /etc/php/$version/cli/conf.d/20-sqlsrv.ini
        sudo ln -s /etc/php/$version/mods-available/sqlsrv.ini /etc/php/$version/fpm/conf.d/20-sqlsrv.ini
        sudo ln -s /etc/php/$version/mods-available/pdo_sqlsrv.ini /etc/php/$version/cli/conf.d/30-pdo_sqlsrv.ini
        sudo ln -s /etc/php/$version/mods-available/pdo_sqlsrv.ini /etc/php/$version/fpm/conf.d/30-pdo_sqlsrv.ini

        # | Set the right permissions
        # | -------------------------
        sudo chmod 644 /etc/php/$version/mods-available/sqlsrv.ini
        sudo chmod 644 /etc/php/$version/mods-available/pdo_sqlsrv.ini
        sudo chmod 777 /etc/php/$version/fpm/conf.d/30-pdo_sqlsrv.ini
        sudo chmod 777 /etc/php/$version/fpm/conf.d/30-pdo_sqlsrv.ini

        cd /tmp/mssql
        sudo rm -r /tmp/mssql/sqlsrv-5.6.1
        sudo rm -r /tmp/mssql/pdo_sqlsrv-5.6.1
    fi

    sudo /etc/init.d/php$version-fpm restart
done

# | Remove temporary folder
# | -----------------------
cd ~/
rm -r /tmp/mssql
