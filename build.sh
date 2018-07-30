#!/bin/bash

function copy() {
	echo -e "Creating configuration directory under /etc/cas"
	mkdir -p /etc/cas/config

	echo -e "Copying configuration files from etc/cas to /etc/cas"
	cp -rfv ./etc/cas/* /etc/cas
}

function help() {
	clear
	echo "******************************************************************"
	echo "Apereo CAS"
	echo "Enterprise Single SignOn for all earthlings and beyond"
	echo "- https://github.com/apereo/cas"
	echo "- https://apereo.github.io/cas"
	echo "******************************************************************"

	echo -e "Usage: build.sh [maven|gradle] [copy|clean|package|run|update|debug|tomcat|gencert]\n"
	echo "	clean: Clean Maven build directory"
	echo "	cli: Run the CAS command line shell and pass commands"
	echo "	copy: Copy config from the project's local etc/cas/config directory to the root /etc/cas/config"
	echo "	debug: Run cas.war and listen for Java debugger on port 5000"
	echo "	dependencies: Get a report of all dependencies configured in the build"
	echo "	gencert: Create keystore with SSL certificate in location where CAS looks by default"
	echo "	getview: Ask for a view name to be included in the overlay for customizations"
	echo "	listviews: List all CAS views that ship with the web application and can be customized in the overlay"
	echo "	package: Clean and build CAS war"
	echo "	run: Build and run cas.war via Java as an executable war"
	echo "	runalone: Build and run cas.war on its own as a standalone executable"
	echo "	tomcat: Deploy the CAS web application to an external Apache Tomcat server"
	echo "	update: Package the CAS overlay by force-updating dependencies and SNAPSHOT versions"
}

function clean() {
	if [ "$buildTool" = "maven" ]; then
		./mvnw clean "$@"
	else
		./gradlew clean "$@"
	fi
}

function package() {
	clean
	if [ "$buildTool" = "maven" ]; then
		./mvnw package "$@"
	else
		./gradlew build "$@"
	fi
}

function update() {
	clean
	if [ "$buildTool" = "maven" ]; then
		./mvnw package -U "$@"
	else
		./gradlew build --refresh-dependencies "$@"
	fi
}

function dependencies() {
	if [ "$buildTool" = "maven" ]; then
		./mvnw dependency:analyze "$@"
	else
		./gradlew allDependencies
	fi
}

function tomcat() {
	export CATALINA_HOME=./apache-tomcat/
    echo "Attempting to shutdown Apache Tomcat..."
    ./apache-tomcat/bin/shutdown.sh 2>/dev/null
	ps -ef | grep tomcat

    rm -Rf ./apache-tomcat
	./mvnw clean package -P external -T 5 "$@" && cp target/cas.war apache-tomcat/webapps/
	chmod +x ./apache-tomcat/bin/*.sh
	./apache-tomcat/bin/startup.sh
	tail -F ./apache-tomcat/logs/catalina.out
}

function debug() {
	if [ "$buildTool" = "maven" ]; then
		casWar="target/cas.war"
	else
		casWar="build/libs/cas.war"
	fi
	package && java -Xdebug -Xrunjdwp:transport=dt_socket,address=5000,server=y,suspend=n -jar $casWar
}

function run() {
	if [ "$buildTool" = "maven" ]; then
		casWar="target/cas.war"
	else
		casWar="build/libs/cas.war"
	fi
	package && java -XX:TieredStopAtLevel=1 -Xverify:none -jar $casWar
}

function runalone() {
	if [ "$buildTool" = "maven" ]; then
		./mvnw clean package -P default,exec  "$@"
		casWar="target/cas.war"
	else
		./gradlew clean build -Pexecutable=true "$@"
		casWar="build/libs/cas.war"
	fi
	chmod +x $casWar
   	$casWar
}

function listviews() {
	explodeapp
	if [ "$buildTool" = "maven" ]; then
		explodedDir=target/cas
	else
		explodedDir=build/cas
	fi
	find $explodedDir -type f -name "*.html" | xargs -n 1 basename | sort | more
}

function explodeapp() {
	if [ "$buildTool" = "maven" ]; then
		if [ ! -d $PWD/target/cas ];then
			echo "Building the CAS web application and exploding the final war file..."
			./mvnw clean package war:exploded "$@"
		fi
	else
		./gradlew explodeWar
	fi
	echo "Exploded the CAS web application file."
}

function getview() {
	explodeapp
	echo "Searching for view name $@..."
	if [ "$buildTool" = "maven" ]; then
		explodedDir=target/cas
	else
		explodedDir=build/cas
	fi

	results=`find $explodedDir -type f -name "*.html" | grep -i "$@"`

	count=`wc -w <<< "$results"`

	if [ "$count" -eq 0 ];then
		echo "No views could be found matching $@"
		exit 1
	fi
	echo -e "Found view(s): \n$results"
	if [ "$count" -eq 1 ];then
		if [ "$buildTool" = "maven" ]; then
			fromFile="target/cas/WEB-INF/classes"
		else
			fromFile="build/cas/WEB-INF/classes"
		fi
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

	if [ "$buildTool" = "maven" ]; then
		CAS_VERSION=$(./mvnw -q -Dexec.executable="echo" -Dexec.args='${cas.version}' --non-recursive org.codehaus.mojo:exec-maven-plugin:1.3.1:exec 2>/dev/null)
	else
		CAS_VERSION=$(./gradlew casVersion --quiet)
	fi

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

	if [ "$buildTool" = "maven" ]; then
		DOWNLOAD_DIR=./target
	else
		DOWNLOAD_DIR=./build/libs
	fi

	COMMAND_FILE="${DOWNLOAD_DIR}/${JAR_FILE_NAME}"
	if [ ! -f "$COMMAND_FILE" ]; then
		mkdir -p $DOWNLOAD_DIR
		wget "https://repo1.maven.org/maven2/${JAR_PATH}" -P ./target
	fi

	echo "Running $COMMAND_FILE"
	java -jar $COMMAND_FILE "$@"
	exit 0;

}

buildTool=$1
command=$2

if [ -z "$command" ]; then
    echo "No commands provided. Defaulting to [run]"
	command="run"
fi

if [ -z "$buildTool" ]; then
	buildTool="maven"
	echo "Build tool type is unspecified. Defaulting to [$buildTool]"
else
	echo "Using build tool [$buildTool] to [$command] the CAS overlay"
fi

shift 2

case "$command" in
"copy")
    copy
    ;;
"help")
    help
    ;;
*)
	if [ "$buildTool" = "maven" ]; then
		pushd maven-overlay
	else
		pushd gradle-overlay
	fi

	case "$command" in
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
	"tomcat")
		tomcat
		;;
	esac
	popd
esac