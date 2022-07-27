#!/usr/bin/env bash
set -euo pipefail

function setup_git () {
	tar -xf "./git/git-${GIT_VERSION}.tar.gz" -C "${GIT}"
	cp "./git/git-${GIT_VERSION}.tar.gz" "${GIT}"
	cp "./git/${GIT_VERSION}" "${HOME}/modulefiles/git"
	cd "${GIT}/git-${GIT_VERSION}"
	make prefix="${GIT}" && make prefix="${GIT}" install
	echo "prepend-path    PATH            ${GIT}/bin" >> "${HOME}/modulefiles/git/${GIT_VERSION}"
    cd "${SCRIPT_PATH}"
}


function setup_cmake () {
	# unzip cmake tarball(prebuild)
	tar -xf "./cmake/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" -C "${CMAKE}"
	cp "./cmake/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" "${CMAKE}"
	cp "./cmake/${CMAKE_VERSION}" "${HOME}/modulefiles/cmake"
	echo "prepend-path    PATH    ${CMAKE}/cmake-${CMAKE_VERSION}-linux-x86_64/bin" >> "${HOME}/modulefiles/cmake/${CMAKE_VERSION}"
	echo "prepend-path    MANPATH ${CMAKE}/cmake-${CMAKE_VERSION}-linux-x86_64/man" >> "${HOME}/modulefiles/cmake/${CMAKE_VERSION}"
	cd "${SCRIPT_PATH}"
}

# Unset all aliases
\unalias -a

# Setup umask
umask 002

# Set this script's path
# shellcheck disable=SC2046
SCRIPT_PATH=$(cd $(dirname "$0") && pwd)

# If intel fortran doesn't exist, Exit with error
if ! type ifort > /dev/null; then
	echo "intel fortran compiler (ifort) doesn't exist. We should build intel fortran."
	echo "Please install intel fortran and try again.(ref https://www.intel.com/content/www/us/en/developer/tools/oneapi/toolkits.html)"
	echo "You can also install intel fortran by running the following command(sudo authority is required): "
	echo "> sudo sh ${SCRIPT_PATH}/intel-fortran.sh"
	exit 1
else
	echo "intel fortran compiler (ifort) exists. We should not build intel fortran."
fi


# Software path
SOFTWARES="${HOME}/tmp/Software"
MODULEFILES="${HOME}/modulefiles"
CMAKE="${SOFTWARES}/cmake"
OPENMPI="${SOFTWARES}/openmpi"
DIRAC="${SOFTWARES}/dirac"
MOLCAS="${SOFTWARES}/molcas"
GIT="${SOFTWARES}/git"

# VERSIONS
GIT_VERSION="2.37.1"
CMAKE_VERSION="3.23.2"

# Create directories for Softwares
mkdir -p "${CMAKE}" "${OPENMPI}" "${DIRAC}" "${MOLCAS}" "${GIT}"

# Create directories for Environment modules
mkdir -p "${MODULEFILES}/git"
mkdir -p "${MODULEFILES}/cmake"

# Clean modulefiles
module purge
module use --append "${MODULEFILES}"

# Setup git
setup_git && module load git/${GIT_VERSION} && git --version

# Setup CMake
setup_cmake && module load cmake/${CMAKE_VERSION} && cmake --version

# Build OpenMPI (intel fortran)

# Build DIRAC

# Build Molcas (interactive)

wait
