#!/usr/bin/env bash

if type cmake > /dev/null; then
    # Check cmake version is 3.10 or higher?
    cmakeversion=$(cmake --version | grep "cmake version" | awk '{print $NF}')
    mainversion=$(echo $cmakeversion | awk -F. '{print $1}')
    subversion=$(echo $cmakeversion | awk -F. '{print $2}')
    echo "mainversion: $mainversion"
    echo "subversion: $subversion"
    if [ $mainversion -ge 3 ] && [ $subversion -ge 10 ]; then
        echo "cmake version is 3.10 or higher"
    else
        echo "cmake version is lower than 3.10"
    fi
else
    echo "cmake is not installed"
fi
