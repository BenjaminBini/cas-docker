# CAS Docker environment

## Install

### HTTPS configuration

Modify `init-letsencrypt.sh` and `data/nginx/app.conf` to add your domain name instead of default ones.

For HTTPS to work, run `./init-letsencrypt.sh` from the server corresponding to the said domain.

### Build Docker image

To create the docker image from the source, clone this repository and run this command from the repository directory: 

```sh
$ docker build -t cas:latest --build-arg LDAP_HOST=${LDAPS_HOST} .  
```

In this command, replace ${LDAPS_HOST} with the IP and port of your secure LDAP connection (eg. `111.222.333:636`).

### Configure environment

Create `etc/cas/application.properties` based on `etc/cas/application.sample.properties` and change the values to match your environment.

* `server.url` URL of your CAS installation, eg. https://cas.mydomain.com
* LDAP connection parameters:
    * `ldap.url`
    * `ldap.bindDn` 
    * `ldap.bindCredential`
    * `ldap.baseDn`

## Run

To start everything, run `docker-compose up -d`.

## Log

To see the log, run `docker-compose logs -f`.