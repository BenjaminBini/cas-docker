FROM centos:centos7

MAINTAINER Apereo Foundation

ENV PATH=$PATH:$JRE_HOME/bin
ARG cas_version

RUN yum -y install wget tar unzip git \
    && yum -y clean all

# Download Azul Java, verify the hash, and install \
RUN set -x; \
    java_version=11.0.3; \
    zulu_version=11.31.11-ca; \
    java_hash=20218b15ae5ef1318aed1a3d5dde3219; \
    cd / \
    && wget http://cdn.azul.com/zulu/bin/zulu$zulu_version-jdk$java_version-linux_x64.tar.gz \
    && echo "$java_hash  zulu$zulu_version-jdk$java_version-linux_x64.tar.gz" | md5sum -c - \
    && tar -zxvf zulu$zulu_version-jdk$java_version-linux_x64.tar.gz -C /opt \
    && rm zulu$zulu_version-jdk$java_version-linux_x64.tar.gz \
    && ln -s /opt/zulu$zulu_version-jdk$java_version-linux_x64/ /opt/java-home;

# Download the CAS overlay project \
RUN cd / \
    && mkdir -p /etc/cas/config \
    && mkdir -p /etc/cas/services \
    && mkdir -p cas-overlay/bin \
    && chmod 750 cas-overlay/*.sh \
    && chmod 750 /opt/java-home/bin/java;

COPY etc/cas/thekeystore /etc/cas/
COPY bin/*.* cas-overlay/
COPY etc/cas/config/*.* /etc/cas/config/
COPY etc/cas/services/*.* /etc/cas/services/

EXPOSE 8080 8443

WORKDIR /cas-overlay

ENV JAVA_HOME /opt/java-home
ENV PATH $PATH:$JAVA_HOME/bin:.

RUN mkdir -p ~/.gradle \
    && echo "org.gradle.daemon=false" >> ~/.gradle/gradle.properties \
    && ./gradlew clean build --parallel \
    && rm -rf /root/.gradle

CMD ["/cas-overlay/run-cas.sh"]
