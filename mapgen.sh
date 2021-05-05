#!/bin/bash

set -xe

# Install PostgreSQL

wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | \
    sudo apt-key add -

sudo sh -c 'sudo add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) universe"'
sudo sh -c 'sudo add-apt-repository "deb http://archive.ubuntu.com/ubuntu $(lsb_release -sc) multiverse"'

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ xenial-pgdg main" >> /etc/apt/sources.list.d/postgresql.list'
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" |sudo tee  /etc/apt/sources.list.d/pgdg.list'

sudo apt-get update
sudo apt-get -y install postgresql-13 postgresql-13-postgis-3  unzip

# Update the postgres configuration file to trust everyone
sudo sh -c 'cat << EOF > /etc/postgresql/13/main/pg_hba.conf
# PostgreSQL Client Authentication Configuration File
# ===================================================
#
# Refer to the "Client Authentication" section in the PostgreSQL
# documentation for a complete description of this file.  A short
# synopsis follows.
#
# This file controls: which hosts are allowed to connect, how clients
# are authenticated, which PostgreSQL user names they can use, which
# databases they can access.  Records take one of these forms:
#
# local         DATABASE  USER  METHOD  [OPTIONS]
# host          DATABASE  USER  ADDRESS  METHOD  [OPTIONS]
# hostssl       DATABASE  USER  ADDRESS  METHOD  [OPTIONS]
# hostnossl     DATABASE  USER  ADDRESS  METHOD  [OPTIONS]
# hostgssenc    DATABASE  USER  ADDRESS  METHOD  [OPTIONS]
# hostnogssenc  DATABASE  USER  ADDRESS  METHOD  [OPTIONS]
#
# (The uppercase items must be replaced by actual values.)
#
# The first field is the connection type: "local" is a Unix-domain
# socket, "host" is either a plain or SSL-encrypted TCP/IP socket,
# "hostssl" is an SSL-encrypted TCP/IP socket, and "hostnossl" is a
# non-SSL TCP/IP socket.  Similarly, "hostgssenc" uses a
# GSSAPI-encrypted TCP/IP socket, while "hostnogssenc" uses a
# non-GSSAPI socket.
#
# DATABASE can be "all", "sameuser", "samerole", "replication", a
# database name, or a comma-separated list thereof. The "all"
# keyword does not match "replication". Access to replication
# must be enabled in a separate record (see example below).
#
# USER can be "all", a user name, a group name prefixed with "+", or a
# comma-separated list thereof.  In both the DATABASE and USER fields
# you can also write a file name prefixed with "@" to include names
# from a separate file.
#
# ADDRESS specifies the set of hosts the record matches.  It can be a
# host name, or it is made up of an IP address and a CIDR mask that is
# an integer (between 0 and 32 (IPv4) or 128 (IPv6) inclusive) that
# specifies the number of significant bits in the mask.  A host name
# that starts with a dot (.) matches a suffix of the actual host name.
# Alternatively, you can write an IP address and netmask in separate
# columns to specify the set of hosts.  Instead of a CIDR-address, you
# can write "samehost" to match any of the servers own IP addresses,
# or "samenet" to match any address in any subnet that the server is
# directly connected to.
#
# METHOD can be "trust", "reject", "md5", "password", "scram-sha-256",
# "gss", "sspi", "ident", "peer", "pam", "ldap", "radius" or "cert".
# Note that "password" sends passwords in clear text; "md5" or
# "scram-sha-256" are preferred since they send encrypted passwords.
#
# OPTIONS are a set of options for the authentication in the format
# NAME=VALUE.  The available options depend on the different
# authentication methods -- refer to the "Client Authentication"
# section in the documentation for a list of which options are
# available for which authentication methods.
#
# Database and user names containing spaces, commas, quotes and other
# special characters must be quoted.  Quoting one of the keywords
# "all", "sameuser", "samerole" or "replication" makes the name lose
# its special character, and just match a database or username with
# that name.
#
# This file is read on server startup and when the server receives a
# SIGHUP signal.  If you edit the file on a running system, you have to
# SIGHUP the server for the changes to take effect, run "pg_ctl reload",
# or execute "SELECT pg_reload_conf()".
#
# Put your actual configuration here
# ----------------------------------
#
# If you want to allow non-local connections, you need to add more
# "host" records.  In that case you will also need to make PostgreSQL
# listen on a non-local interface via the listen_addresses
# configuration parameter, or via the -i or -h command line switches.




# DO NOT DISABLE!
# If you change this first entry you will need to make sure that the
# database superuser can access the database using some other method.
# Noninteractive access to all databases is required during automatic
# maintenance (custom daily cronjobs, replication, and similar tasks).
#
# Database administrative login by Unix domain socket
local   all             postgres                                trust

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     trust
# IPv4 local connections:
host    all             all             127.0.0.1/32            trust
# IPv6 local connections:
host    all             all             ::1/128                 trust
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     trust
host    replication     all             127.0.0.1/32            trust
host    replication     all             ::1/128                 trust
EOF'

sudo sh -c 'cat << EOF > /etc/postgresql/13/main/conf.d/osm_tuning.conf
shared_buffers = 1GB
work_mem = 50MB
maintenance_work_mem = 10GB
autovacuum_work_mem = 2GB
wal_level = minimal
checkpoint_timeout = 60min
max_wal_size = 10GB
checkpoint_completion_target = 0.9
max_wal_senders = 0
random_page_cost = 1.0
EOF'
sudo -u postgres psql --username=postgres --dbname=postgres -c "SELECT pg_reload_conf();"

sudo -u postgres createuser osmuser

sudo -u postgres createdb --encoding=UTF8 --owner=osmuser osm

sudo -u postgres psql --username=postgres --dbname=osm -c "CREATE EXTENSION postgis;"

sudo -u postgres psql --username=postgres --dbname=osm -c "CREATE EXTENSION postgis_topology;"

sudo -u postgres psql --username=postgres --dbname=osm -c "CREATE EXTENSION hstore;"

sudo apt-get -y install osm2pgsql

# get the latest Hamburg extract for OSM

cd /tmp

wget https://planet.openstreetmap.org/planet/planet-latest.osm.bz2
# wget https://download.geofabrik.de/europe/germany/hamburg-latest.osm.bz2

# bzip2 -d hamburg-latest.osm.bz2
bzip2 -d planet-latest.osm.bz2

wget https://svn.openstreetmap.org/applications/rendering/mapnik/generate_image.py

wget https://svn.openstreetmap.org/applications/rendering/mapnik/generate_tiles.py

# INSTALL carto

# curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -

# sudo apt-get install -y nodejs

# sudo npm -g install carto

# git clone --depth 1 --branch v4.20.0 https://github.com/gravitystorm/openstreetmap-carto

# cd openstreetmap-carto

# carto project.mml >osm.xml

# INSTALL mapnik

cd /tmp

echo "Old freetype version:"
dpkg -l|grep freetype6

sudo add-apt-repository -y ppa:no1wantdthisname/ppa
sudo apt-get update
sudo apt-get install -y libfreetype6 libfreetype6-dev
echo "Updated freetype version:"
dpkg -l|grep freetype6

sudo apt-get update

sudo apt-get install -y libboost-all-dev libmapnik-dev python-mapnik

# INSTALL fonts

sudo apt-get install -y ttf-unifont fonts-open-sans fonts-noto-cjk fonts-noto-hinted fonts-noto-unhinted

cd /tmp

mkdir noto

cd noto

# Grab some extra noto fonts from Google

# install for fc-cache
sudo apt-get install -y fontconfig

wget https://noto-website-2.storage.googleapis.com/pkgs/Noto-hinted.zip

unzip Noto-hinted.zip

sudo cp /tmp/noto/*.otf /usr/share/fonts/opentype/noto/

sudo cp /tmp/noto/*.ttf /usr/share/fonts/truetype/noto

fc-cache

# Generate tiles

cd /tmp

sudo apt-get install -y mapnik-utils

sudo su - postgres -c "cd /tmp; osm2pgsql --cache=64000 -G --hstore -U osmuser -d osm planet-latest.osm" 

sudo -u postgres mkdir -p /tmp/tiles

sudo unzip /tmp/Guestbook.zip -d /tmp

sudo -u postgres python gen-tiles.py

echo "finished" > /tmp/done.txt
