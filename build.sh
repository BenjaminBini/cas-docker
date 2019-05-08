#!/bin/bash

image_tag=(`./gradlew casVersion -q`)

echo "Building CAS docker image tagged as [$image_tag]"
read -p "Press [Enter] to continue..." any_key;

docker build --tag="apereo/cas:$image_tag" . \
  && echo "Built CAS image successfully tagged as $image_tag" \
  && docker images "apereo/cas:$image_tag"