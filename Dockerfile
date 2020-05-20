FROM adoptopenjdk/openjdk11:alpine-slim AS overlay

# Create needed directories and copy sources
RUN mkdir -p cas-overlay
COPY ./src cas-overlay/src/
COPY ./gradle/ cas-overlay/gradle/
COPY ./gradlew ./settings.gradle ./build.gradle ./gradle.properties /cas-overlay/

# Init gradle environment
RUN mkdir -p ~/.gradle \
    && echo "org.gradle.daemon=false" >> ~/.gradle/gradle.properties \
    && echo "org.gradle.configureondemand=true" >> ~/.gradle/gradle.properties \
    && cd cas-overlay \
    && chmod 750 ./gradlew \
    && ./gradlew --version;

# Run gradle clean build
RUN cd cas-overlay \
    && ./gradlew clean build --parallel;

FROM adoptopenjdk/openjdk11:alpine-jre AS cas

# Create needed directories
RUN cd / \
    && mkdir -p /etc/cas/config \
    && mkdir -p /etc/cas/services \
    && mkdir -p /etc/cas/saml \
    && mkdir -p /etc/cas/static \
    && mkdir -p cas-overlay;

# Copy CAS config and overlay
COPY etc/cas/ /etc/cas/
COPY etc/cas/config/ /etc/cas/config/
COPY etc/cas/services/ /etc/cas/services/
COPY etc/cas/saml/ /etc/cas/saml/
COPY etc/cas/templates/ /etc/cas/templates/
COPY etc/cas/templates/ /etc/cas/static/
COPY --from=overlay cas-overlay/build/libs/cas.war cas-overlay/

# Install OpenSSL and install cert in Java cacerts
ARG LDAPS_HOST
RUN apk upgrade --update-cache --available && apk add openssl
RUN echo -n | openssl s_client -connect ${LDAPS_HOST} | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' > /etc/cas/ldap.cer
RUN keytool -importcert -file /etc/cas/ldap.cer -alias ldapcert -cacerts -storepass changeit -noprompt

# Expose port 8080
EXPOSE 8080

ENV PATH $PATH:$JAVA_HOME/bin:.

WORKDIR cas-overlay
ENTRYPOINT ["java", "-server", "-noverify", "-Xmx2048M", "-jar", "cas.war"]
