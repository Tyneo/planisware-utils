#!/bin/bash
#########################################################
## Script d'installation Planisware automatisé         ##
## - author: Samuel Kauffmann <skauffmann@tyneo.net>   ##
## - version: 1.2                                      ##
##                                                     ##
##    ©2015 Tyneo Consulting - http://tyneo.net        ##
## Planisware est une marque déposée et appartenant à  ##
## la société Planisware - http://planisware.com       ##
## Ce script ne peut être vendu sans l'autorisisation  ##
## écrite de Tyneo Consulting                          ##
## Vous pouvez modifier ce script sans en changer les  ##
## lignes ci-dessus.                                   ##
#########################################################


#########################################################
#########################################################
## Variables de configuration                          ##
#########################################################

#Connexion au serveur FTP Planisware
export PLW_USER_FTP=mon_user
export PLW_PWD_FTP=mon_password
export PLW_INSTALLER_DIR_FTP=ftp.planisware.com/Processes/PlaniswareV6/6.1.1.1/Install
export PLW_INSTALLER_FILE_FTP=plw_install_linux_6.1.0.a.tar.gz

#Configuration de la base de données
export PLW_DB_NAME=planisware
export PLW_DB_USER_PWD=planisware
export PLW_DB_USER=planisware

#Configuration de l'environnement d'installation
export PLW_ENV_NAME=plan

export PLW_INSTALL_DIR=/opt/planisware

#########################################################
## Script d'installation automatisé                    ##
#########################################################
source_rep=`pwd`

# Test que le script est lance en root
if [[ $EUID = 0 ]]; then
   echo "Root is not allowed to install Planisware."
   exit
fi

echo "Sync date time with NTP... "
sudo ntpdate ntp.inria.fr &> /dev/null
echo "done."

# first run apt-get update
echo -n "Running apt-get update && upgrade... "
sudo apt-get update &> /dev/null
echo "done."

echo -n "Installing Ubuntu default JRE... "
sudo apt-get install -y default-jre &> /dev/null
echo "done."

echo -n "Installing Apache (HTTP Server)... "
sudo apt-get install -y apache2 &> /dev/null
echo "done."

echo -n "Installing Postgresql (Database manager)... "
sudo apt-get install -y postgresql &> /dev/null
echo "done."

echo "Create Postgres Database and user for Planisware ($PLW_DB_USER@$PLW_DB_NAME)... "
sudo -u postgres psql -c "CREATE USER $PLW_DB_USER" &> /dev/null
sudo -u postgres psql -c "ALTER USER $PLW_DB_USER WITH PASSWORD '$PLW_DB_USER_PWD'" &> /dev/null
sudo -u postgres psql -c "ALTER ROLE $PLW_DB_USER WITH CREATEDB"; &> /dev/null
sudo -u postgres psql -c "CREATE DATABASE \"$PLW_DB_NAME\" OWNER $PLW_DB_USER"; &> /dev/null
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE \"$PLW_DB_NAME\" to $PLW_DB_USER"; &> /dev/null
echo "done."

echo -n "Create Planisware system group and user (planisware:planisware)... "
sudo addgroup planisware &> /dev/null
sudo useradd planisware -g planisware --shell /bin/bash -M -d /usr/local/planisware -c "Planisware user" &> /dev/null
echo "done."

echo -n "Download Planisware installer... "
mkdir plw_install &> /dev/null
cd plw_install &> /dev/null
wget ftp://$PLW_USER_FTP:$PLW_PWD_FTP@$PLW_INSTALLER_DIR_FTP/$PLW_INSTALLER_FILE_FTP &> /dev/null
tar -xzf $PLW_INSTALLER_FILE_FTP &> /dev/null
echo "done."

#Planisware installation configuration
export PLW_DB_NAME=planisware
export PLW_DB_USER=planisware
export PLW_INSTALL_DIR=/opt/planisware
export PLW_ENV_NAME=plan

PLW_INSTALLER=$source_rep/plw_install/install.sh
sudo mkdir -p $PLW_INSTALL_DIR
cd $PLW_INSTALL_DIR
SKIP=`awk '/^__TARFILE_FOLLOWS__/ { print NR + 1; exit 0; }' $PLW_INSTALLER`
echo -n "Extract installation files to $PLW_INSTALL_DIR... "
sudo tail -n +$SKIP $PLW_INSTALLER | sudo tar -jxf -;
sudo chown -R planisware:planisware $PLW_INSTALL_DIR  &> /dev/null
echo "done."

sudo mkdir -p /usr/local/planisware/ &> /dev/null
sudo chown -R planisware:planisware /usr/local/planisware/  &> /dev/null

echo -n "Planisware configuration and installation... "
sudo -u planisware bash <<EOF
export PLW_DB_NAME=$PLW_DB_NAME
export PLW_DB_USER=$PLW_DB_USER
export PLW_INSTALL_DIR=$PLW_INSTALL_DIR
export PLW_ENV_NAME=$PLW_ENV_NAME
export INSTALL_CONNECT=1
export INSTALL_IS=1
export INSTALL_DISPATCH=1
export INSTALL_CLUSTER=1
export INSTALL_PLANNING=0
export INSTALL_DOCSEARCH=nil
export INSTALL_MODULE=1
export HTTP_CONNECT=0
export DATABASE_TYPE_INI=postgresql
export DATABASE_TYPE_LISTEN=postgresql
export DATABASE_TYPE=postgresql
export DATABASE_UTF8_MODE=1
export DATABASE_TYPE_INI=postgresql
export OPX2_JAVA_EXE=/usr/bin/java
export CONNECT_PORT="8501"
export DEF_CONNECT=$CONNECT_PORT
export DISPATCH_PORT="8100"
export IS_MASTERSLAVE=y
export DATABASE_LABEL="Host"

sed -i.bak -e "s/ENVNAME=home/ENVNAME=$PLW_ENV_NAME/" $PLW_INSTALL_DIR/tools/install/setup_sat.sh
sed -i.bak -e "s/INSTALLPATH=\/usr\/local\/planisware\/.*/INSTALLPATH=\/usr\/local\/planisware\/$PLW_ENV_NAME/" $PLW_INSTALL_DIR/tools/install/setup_sat.sh
sed -i.bak -e "s/DATABASE_TYPE=oracle/DATABASE_TYPE=postgresql/" $PLW_INSTALL_DIR/tools/install/setup_sat.sh

sed -i.bak -e "s/DATABASE_DESC=\"\"/DATABASE_DESC=\"Planisware\"/" $PLW_INSTALL_DIR/tools/install/setup_sat.sh
sed -i.bak -e "s/DATABASE_USER=\"\"/DATABASE_USER=\"$PLW_DB_USER\"/" $PLW_INSTALL_DIR/tools/install/setup_sat.sh
sed -i.bak -e "s/DATABASE_PASS=\"\"/DATABASE_PASS=\"$PLW_DB_USER\"/" $PLW_INSTALL_DIR/tools/install/setup_sat.sh
sed -i.bak -e "s/DATABASE_SID=\"\"/DATABASE_SID=\"\\\\"\"localhost\\\\\""\"/" $PLW_INSTALL_DIR/tools/install/setup_sat.sh
sed -i.bak -e "s/DATABASE_SQLALIAS=\"\"/DATABASE_SQLALIAS=\"localhost\"/" $PLW_INSTALL_DIR/tools/install/setup_sat.sh

sed -i.bak -e "s/INSTALL_MODULE=\"0\"/INSTALL_MODULE=\"1\"/" $PLW_INSTALL_DIR/tools/install/setup_sat.sh
sed -i.bak -e "s/CONNECT_PORT=8500/CONNECT_PORT=\"8501\"/" $PLW_INSTALL_DIR/tools/install/setup_sat.sh
sed -i.bak -e "s/INSTALL_DISPATCH=0/INSTALL_DISPATCH=1/" $PLW_INSTALL_DIR/tools/install/setup_sat.sh
sed -i.bak -e "s/JRE_OK=\"n\"/JRE_OK=\"y\"/" $PLW_INSTALL_DIR/tools/install/setup_sat.sh
sed -i.bak -e "s/CONF_OK=\"n\"/CONF_OK=\"y\"/" $PLW_INSTALL_DIR/tools/install/setup_sat.sh


$PLW_INSTALL_DIR/tools/install/setup_sat.sh
EOF
echo "done."

echo -n "Configure Apache2 with Planisware... "
sudo ln -s /usr/local/planisware/plan/httpserver/conf/mod_opx2.load /etc/apache2/mods-available/000mod_opx2.load  &> /dev/null
sudo ln -s /usr/local/planisware/plan/httpserver/conf/plw.conf /etc/apache2/sites-available/plan.conf  &> /dev/null
sudo a2enmod 000mod_opx2  &> /dev/null
sudo a2ensite plan.conf  &> /dev/null
echo "done."

echo -n "Restart Apache2 services... "
sudo service apache2 reload
echo "done."

echo ""
echo ""

echo "Congratulation ! Planisare installation is done."
echo ""
echo "- Database information:"
echo "  database name: planisware"
echo "  login: planisware"
echo "  password: planisware"
echo ""
echo "- Admin page (watchdog):"
echo "  login: admin"
echo "  password: plw"
echo ""
echo "Please start planisware with the following command:"
echo " sudo /usr/local/planisware/plan/bin/start_plw"
