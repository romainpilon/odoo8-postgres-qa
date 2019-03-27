FROM paraita/centos7
LABEL maintainer="paraita.wohler@tahiti-web-management.com"

ENV container docker
ENV ODOO_RPM_URL http://cdn.tahiti-web-management.com/odoo_8.0.20171001.noarch.rpm
ENV ODOO_SRC_URL http://cdn.tahiti-web-management.com/odoo_8.0.20171001.tar.gz
ENV PG_PATH=/usr/lib/pgsql
ENV PGDATA=$PG_PATH/data

# Bootstrap de l'image centos + installation postgresql
RUN yum -y swap -- remove fakesystemd -- install systemd systemd-libs && \
	yum clean all && yum -y update && yum -y install epel-release && \
	yum -y update && yum -y install wkhtmltopdf python-gevent \
	postgresql-server postgresql-contrib tree less vim \
# dépendances odoo source
	python-pip python-devel git libjpeg-devel libtiff-devel gcc \
	libxslt-devel libxml2-devel graphviz;
RUN localedef -i fr_FR -f UTF-8 fr_FR.UTF-8 && \
	mkdir -p $PGDATA && chmod 770 $PGDATA && \
	chown -R postgres:postgres $PG_PATH;

# Installation de Odoo CE 8 et configuration
RUN curl -o odoo.rpm $ODOO_RPM_URL && yum -y install odoo.rpm && \
	curl -o odoo.tar.gz $ODOO_SRC_URL && mkdir -p /odoo/src && \
	tar --strip-components=1 -C /odoo/src -xvzf odoo.tar.gz;
# certains packages sont mal installés par défaut sur Centos 7 r1503
RUN rm -Rf /usr/lib/python2.7/site-packages/pydot*  \
	/usr/lib/python2.7/site-packages/psycogreen* && \
	pip install -r /odoo/src/requirements.txt;
COPY openerp-server.conf /etc/odoo/

# Création des users/bdd postgresql
ENV LANG "fr_FR.UTF-8"
USER postgres
RUN initdb --pgdata $PGDATA && \
	echo "host all all 0.0.0.0/0 md5" >> $PGDATA/pg_hba.conf && \
	echo "listen_addresses='*'" >> $PGDATA/postgresql.conf && \
	pg_ctl -D $PGDATA -w start && \
	psql -c "create user admin with superuser password 'admin'" && \
	psql -c "create user odoo with superuser password 'odoo'" && \
	createdb -O odoo odoo && \
	psql -c "grant all privileges on database odoo to admin" && \
	pg_ctl -D $PGDATA stop;

EXPOSE 5432 8089 8072

VOLUME ["/odoo/addons"]

USER root
