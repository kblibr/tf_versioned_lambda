#!/bin/bash

set -e

CURDIR=$(pwd)
DIR="$SOURCE_REPO"
# join a relative path or give the full path
joinpath() {
  [[ "$2" = /* ]] && echo "$2" || echo "$1/${2#./}"
}

echo "This is a custom version of this script!"
die () {
  echo >&2 "$@"
  exit 1
}

if [ -z ${AWS_ACCESS_KEY_ID+x} ]; then
  die "must have AWS_ACCESS_KEY_ID set"
fi

if [ -z ${AWS_SECRET_ACCESS_KEY+x} ]; then
  die "must have AWS_SECRET_ACCESS_KEY set"
fi

lambdaName=$1
lambdaDir=$2
lambdaDest=$3
configContents=$4
echo "building docker container"
mytmpdir=`mktemp -d 2>/dev/null || mktemp -d -t 'lambda'`
sourceDir=$(joinpath "${CURDIR}" "${lambdaDir}")
cd $mytmpdir
cp -r $DIR/* .
cp -r $sourceDir/* .

echo "$configContents" > config.json
docker build \
  --pull \
  -f Dockerfile.lambda.node \
  -t lambda_builder_${lambdaName} \
  --build-arg LAMBDA_DEST=${lambdaDest} . || die "failed to build image"

echo "running docker container to build and upload lambda"
docker run \
  -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} \
  -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} \
  -e AWS_SECURITY_TOKEN=${AWS_SECURITY_TOKEN} \
  -e AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN} \
  lambda_builder_${lambdaName} || die "failed to run image"
rm -rf $mytmpdir
