#!/bin/bash

function copy() {
	./gradlew copyCasConfiguration "$@"
}

function help() {
	clear
	echo "******************************************************************"
	tput setaf 2
	echo "Apereo CAS ${casVersion}"
	echo "Enterprise Single SignOn for all earthlings and beyond"
	tput sgr 0
	echo "- https://github.com/apereo/cas"
	echo "- https://apereo.github.io/cas"
	echo "******************************************************************"

	echo -e "Usage: build.sh [command]\n"
	echo -e "\tThe following commands are available:\n"
	echo -e "\tclean: \t\tClean Maven build directory"
	echo -e "\tcli: \t\tRun the CAS command line shell and pass commands"
	echo -e "\tcopy: \t\tCopy config from the project's local etc/cas/config directory to the root /etc/cas/config"
	echo -e "\tdebug: \t\tRun cas.war and listen for Java debugger on port 5000"
	echo -e "\tdependencies: \tGet a report of all dependencies configured in the build"
	echo -e "\tdocker: \tBuild a Docker image based on the current build and configuration"
	echo -e "\tgencert: \tCreate keystore with SSL certificate in location where CAS looks by default"
	echo -e "\tgetview: \tAsk for a view name to be included in the overlay for customizations"
	echo -e "\tgetresource: \tAsk for a resource name (properties/json/etc file) to be included in the overlay for customizations"
	echo -e "\tlistviews: \tList all CAS views that ship with the web application and can be customized in the overlay"
	echo -e "\tpackage: \tClean and build CAS war"
	echo -e "\texplode: \tExplode and unzip and packaged CAS war"
	echo -e "\trun: \t\tBuild and run cas.war via Java as an executable war"
	echo -e "\trunalone: \tBuild and run cas.war on its own as a standalone executable"
	echo -e "\ttomcat: \tDeploy the CAS web application to an external Apache Tomcat server"
	echo -e "\tupdate: \tPackage the CAS overlay by force-updating dependencies and SNAPSHOT versions"
}

function clean() {
	./gradlew clean "$@"
}

function package() {
	./gradlew clean build "$@"
}

function update() {
	./gradlew clean build --refresh-dependencies "$@"
}

function dependencies() {
	./gradlew allDependencies
}

function tomcat() {
	./gradlew clean build -Pexternal=true "$@"

	if [ ! -f apache-tomcat.zip ]; then
		wget -O apache-tomcat.zip "http://www-eu.apache.org/dist/tomcat/tomcat-${tomcatVersion}/v${tomcatFullVersion}/bin/apache-tomcat-${tomcatFullVersion}.zip"
	fi
	rm -Rf ./apache-tomcat
	unzip -o apache-tomcat.zip >/dev/null
	mv apache-tomcat-${tomcatFullVersion} apache-tomcat

	export CATALINA_HOME=./apache-tomcat/
	chmod +x ./apache-tomcat/bin/*.sh
    echo "Attempting to shutdown Apache Tomcat..."
    ./apache-tomcat/bin/shutdown.sh 2>/dev/null

	cp build/libs/cas.war ../apache-tomcat/webapps/
	./apache-tomcat/bin/startup.sh
	tail -F ../apache-tomcat/logs/catalina.out
}

function debug() {
	casWar="build/libs/cas.war"
	package && java -Xdebug -Xrunjdwp:transport=dt_socket,address=5000,server=y,suspend=n -jar $casWar
}

function run() {
	casWar="build/libs/cas.war"
	package && java -XX:TieredStopAtLevel=1 -Xverify:none -jar $casWar
}

function runalone() {
	./gradlew clean build -Pexecutable=true "$@"
	casWar="build/libs/cas.war"
	chmod +x $casWar
   	$casWar
}

function jibdocker() {
   ./gradlew clean build jibDockerBuild "$@"
}

function listviews() {
	explodeApp
	explodedDir=build/cas
	find $explodedDir -type f -name "*.html" | xargs -n 1 basename | sort | more
}

function explodeApp() {
	./gradlew explodeWar
	echo "Exploded the CAS web application file at build/cas"
}

function getresource() {
	explodeApp

	echo "Searching for resource name $@..."
	explodedDir=build/cas

	results=`find $explodedDir -type f -name "*.*" | grep -i "$@"`
	count=`wc -w <<< "$results"`

	if [ "$count" -eq 0 ];then
		echo "No resources could be found matching $@"
		exit 1
	fi
	echo -e "Found resource(s): \n$results"
	if [ "$count" -eq 1 ];then
		fromFile="build/cas/WEB-INF/classes"
		toFile="src/main/resources"

		overlayfile=`echo "${results/$fromFile/$toFile}"`
		overlaypath=`dirname "${overlayfile}"`
		# echo "Overlay file is $overlayfile to be created at $overlaypath"
		mkdir -p $overlaypath
		cp $results $overlaypath
		echo "Created resource at $overlayfile"
		ls $overlayfile
	else
		echo "More than one resource file is found. Narrow down the search query..."
	fi
}

function getview() {
	explodeApp

	echo "Searching for view name $@..."
	explodedDir=build/cas

	results=`find $explodedDir -type f -name "*.html" | grep -i "$@"`
	count=`wc -w <<< "$results"`

	if [ "$count" -eq 0 ];then
		echo "No views could be found matching $@"
		exit 1
	fi
	echo -e "Found view(s): \n$results"
	if [ "$count" -eq 1 ];then
		fromFile="build/cas/WEB-INF/classes"
		toFile="src/main/resources"

		overlayfile=`echo "${results/$fromFile/$toFile}"`
		overlaypath=`dirname "${overlayfile}"`
		# echo "Overlay file is $overlayfile to be created at $overlaypath"
		mkdir -p $overlaypath
		cp $results $overlaypath
		echo "Created view at $overlayfile"
		ls $overlayfile
	else
		echo "More than one view file is found. Narrow down the search query..."
	fi
}

function gencert() {
	if [[ ! -d /etc/cas ]] ; then
		copy
	fi
	which keytool
	if [[ $? -ne 0 ]] ; then
		echo Error: Java JDK \'keytool\' is not installed or is not in the path
		exit 1
	fi
	# override DNAME and CERT_SUBJ_ALT_NAMES before calling or use dummy values
	DNAME="${DNAME:-CN=cas.example.org,OU=Example,OU=Org,C=US}"
	CERT_SUBJ_ALT_NAMES="${CERT_SUBJ_ALT_NAMES:-dns:example.org,dns:localhost,ip:127.0.0.1}"
	echo "Generating keystore for CAS with DN ${DNAME}"
	keytool -genkeypair -alias cas -keyalg RSA -keypass changeit -storepass changeit -keystore /etc/cas/thekeystore -dname ${DNAME} -ext SAN=${CERT_SUBJ_ALT_NAMES}
	keytool -exportcert -alias cas -storepass changeit -keystore /etc/cas/thekeystore -file /etc/cas/cas.cer
}

function cli() {
	rm -f *.log
	CAS_VERSION=$(./gradlew casVersion --quiet)

	echo "CAS version: $CAS_VERSION"
	JAR_FILE_NAME="cas-server-support-shell-${CAS_VERSION}.jar"
	echo "JAR name: $JAR_FILE_NAME"
	JAR_PATH="org/apereo/cas/cas-server-support-shell/${CAS_VERSION}/${JAR_FILE_NAME}"
	echo "JAR path: $JAR_PATH"

	JAR_FILE_LOCAL="$HOME/.m2/repository/$JAR_PATH";
	echo "Local JAR file path: $JAR_FILE_LOCAL";
	if [ -f "$JAR_FILE_LOCAL" ]; then
		echo "Using JAR file locally at $JAR_FILE_LOCAL"
		java -jar $JAR_FILE_LOCAL "$@"
		exit 0;
	fi

	DOWNLOAD_DIR=./build/libs

	COMMAND_FILE="${DOWNLOAD_DIR}/${JAR_FILE_NAME}"
	if [ ! -f "$COMMAND_FILE" ]; then
		mkdir -p $DOWNLOAD_DIR
		wget "https://repo1.maven.org/maven2/${JAR_PATH}" -P ./target
	fi

	echo "Running $COMMAND_FILE"
	java -jar $COMMAND_FILE "$@"
	exit 0;

}

command=$1

if [ -z "$command" ]; then
    echo "No commands provided. Defaulting to [run]"
	command="run"
fi

shift 1

case "$command" in
"copy")
    copy
    ;;
"help")
    help
    ;;
"clean")
	clean "$@"
	;;
"package"|"build")
	package "$@"
	;;
"debug")
	debug "$@"
	;;
"run")
	run "$@"
	;;
"explode")
	explodeApp "$@"
	;;	
"docker")
	jibdocker "$@"
	;;
"gencert")
	gencert "$@"
	;;
"cli")
	cli "$@"
	;;
"update")
	update "$@"
	;;
"dependencies")
	update "$@"
	;;
"runalone")
	runalone "$@"
	;;
"listviews")
	listviews "$@"
	;;
"getview")
	getview "$@"
	;;
"getresource")
	getresource "$@"
	;;
"tomcat")
	tomcat
	;;
esac
