# CAS Docker environment

## Install

### HTTPS configuration

Modify `init-letsencrypt.sh` and `data/nginx/app.conf` to add your domain name instead of default ones.

For HTTPS to work, run `./init-letsencrypt.sh` from the server corresponding to the said domain.


### Configure environment

Create `data/cas/${ENV}/application.properties` (where `${ENV}` is a string of your choice) based on `data/cas/ENV/application.sample.properties` and change the values to match your environment 

* `server.url` URL of your CAS installation, eg. https://cas.mydomain.com
* LDAP connection parameters:
    * `ldap.url`
    * `ldap.bindDn` 
    * `ldap.bindCredential`
    * `ldap.baseDn`
* SPNEGO configuraiton
    * `spnego.kerberosRealm`
    * `spnego.kerberosKdc`
    * `spnego.jcifsServicePrincipal`
* Default service to redirect to after login from the CAS and not from an SP
    * `defaultService`

### Build Docker image

To create the docker image from the source, clone this repository and run this command from the repository directory: 

```sh
$ docker build -t cas:latest --build-arg LDAPS_HOST=${LDAPS_HOST} --build-arg ENV=${ENV}.  
```

In this command, replace `${LDAPS_HOST}` with the IP and port of your secure LDAP connection (eg. `111.222.333:636`) and replace `${ENV}` with the same string as the one from the configuration section.

## Run

To start everything, run `docker-compose up -d`.

## Log

To see the log, run `docker-compose logs -f`.