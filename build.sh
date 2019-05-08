#!/bin/bash

image_tag=(`cat gradle.properties | grep "cas.version" | cut -d= -f2`)

echo "Building CAS docker image tagged as [$image_tag]"
read -p "Press [Enter] to continue..." any_key;

docker build --tag="apereo/cas:$image_tag" . \
  && echo "Built CAS image successfully tagged as $image_tag" \
  && docker images "apereo/cas:$image_tag"