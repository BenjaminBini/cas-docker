CAS Overlay Template
=======================

Generic CAS WAR overlay to exercise the latest versions of CAS. This overlay could be freely used as a starting template for local CAS war overlays.

# Versions

- CAS `6.0.x`
- JDK `11`

# Overview

The project structure contains two variants for Apache Maven and Gradle WAR overlays, inside `maven-overlay` and `gradle-overlay` respectively. You may invoke
build commands using the `build.sh` script to work with your chosen overlay using:

```bash
./build.sh [maven|gradle] [command]
```

To see what commands are available to the build script, run:

```bash
./build.sh help
```

# Configuration

- The `etc` directory contains the configuration files and directories that need to be copied to `/etc/cas/config`.
- The mechanics of the build are controlled for both Apache Maven and Gradle using the `build.properties` file.

# Deployment

- Create a keystore file `thekeystore` under `/etc/cas`. Use the password `changeit` for both the keystore and the key/certificate entries.
- Ensure the keystore is loaded up with keys and certificates of the server.

On a successful deployment via the following methods, CAS will be available at:

* `https://cas.server.name:8443/cas`

## Executable WAR

Run the CAS web application as an executable WAR.

```bash
./build.sh run
```

## External

Deploy the binary web application file `cas.war` after a successful build to a servlet container of choice.