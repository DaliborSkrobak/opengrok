#!/bin/bash

#
# Build and optionally push new image to Docker hub.
#
# When pushing, this script uses the following Travis secure variables:
#  - DOCKER_USERNAME
#  - DOCKER_PASSWORD
#
# These are set via https://travis-ci.com/OpenGrok/docker/settings
#

set -x
set -e

if [[ -n $TRAVIS_TAG ]]; then
	VERSION="$TRAVIS_TAG"
	VERSION_SHORT=$( echo $VERSION | cut -d. -f1,2 )
else
	VERSION="latest"
	VERSION_SHORT="latest"
fi

if [[ -z $VERSION ]]; then
	echo "empty VERSION"
	exit 1
fi

if [[ -z $VERSION_SHORT ]]; then
	echo "empty VERSION_SHORT"
	exit 1
fi

# Build the image.
docker build \
    -t opengrok/docker:$VERSION \
    -t opengrok/docker:$VERSION_SHORT \
    -t opengrok/docker:latest .

#
# Run the image in container. This is not strictly needed however
# serves as additional test in automatic builds.
#
docker run -d opengrok/docker
docker ps -a

# Travis can only work on master since it needs encrypted variables.
if [ "${TRAVIS_PULL_REQUEST}" != "false" ]; then
	echo "Not publishing docker image for pull requests"
	exit 0
fi

# The push only works on the main repository.
if [[ "${TRAVIS_REPO_SLUG}" != "oracle/opengrok" ]]; then
	echo "Not publishing docker image for non main repository"
	exit 0
fi

# Allow Docker publish for release builds only.
if [[ -z $TRAVIS_TAG ]]; then
	echo "TRAVIS_TAG is empty"
	exit 0
fi

if [[ -z $DOCKER_USERNAME ]]; then
	echo "DOCKER_USERNAME is empty"
	exit 1
fi

if [[ -z $DOCKER_PASSWORD ]]; then
	echo "DOCKER_PASSWORD is empty"
	exit 1
fi

# Publish the image to Docker hub.
if [ -n "$DOCKER_PASSWORD" -a -n "$DOCKER_USERNAME" -a -n "$VERSION" ]; then
	echo "Logging into docker"
	echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

	# All the tags need to be pushed individually:
	for tag in $VERSION $VERSION_SHORT latest; do
		echo "Pushing docker image for tag $tag"
		docker push opengrok/docker:$tag
	done
fi
