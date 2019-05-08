#!/bin/bash

image_tag=(`cat gradle.properties | grep "cas.version" | cut -d= -f2`)
docker run -d -p 8080:8080 -p 8443:8443 --name="cas" apereo/cas:"${image_tag}"
docker logs -f cas