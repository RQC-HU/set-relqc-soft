#!/bin/bash

echo $VERSIONS
echo "${VERSIONS[@]}"
for version in ${VERSIONS}; do
    echo "VERSION" $version
    ls dirac/${version}
done

echo "VERSIONS" ${VERSIONS[@]}


