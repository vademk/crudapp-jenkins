FROM mysql:8.0.19
COPY ./dump/lena.sql /docker-entrypoint-initdb.d/init.sql