#!/bin/sh

echo "Checking java..."
java -version

echo "Creating CAS configuration directories..."
mkdir -p /etc/cas/config
mkdir -p /etc/cas/services

echo "Running CAS..."
java -Xms512m -Xmx2048M -XX:+TieredCompilation -XX:TieredStopAtLevel=1 -jar docker/cas/cas.war
