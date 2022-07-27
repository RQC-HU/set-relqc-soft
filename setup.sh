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
	# unzip cmake prebuild tarball
	tar -xf "./cmake/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" -C "${CMAKE}"
	# ${CMAKE} にコピーされたtarballは使わないが、あとからどのtarballを使ってビルドしたか確認しやすくするためにコピーしておく
	cp "./cmake/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" "${CMAKE}"
	cp "./cmake/${CMAKE_VERSION}" "${HOME}/modulefiles/cmake"
	echo "prepend-path    PATH    ${CMAKE}/cmake-${CMAKE_VERSION}-linux-x86_64/bin" >> "${HOME}/modulefiles/cmake/${CMAKE_VERSION}"
	echo "prepend-path    MANPATH ${CMAKE}/cmake-${CMAKE_VERSION}-linux-x86_64/man" >> "${HOME}/modulefiles/cmake/${CMAKE_VERSION}"
	cd "${SCRIPT_PATH}"
}

function setup_openmpi() {
	# openmpi (8-byte integer)
	OMPI_VERSION=$1
	cd "${SCRIPT_PATH}"
	OMPI_TARBALL="./openmpi/openmpi-${OMPI_VERSION}.tar.bz2"
	OMPI_INSTALL_PREFIX="${OPENMPI}/${OMPI_VERSION}/openmpi-${OMPI_VERSION}-intel"
	mkdir -p "${OPENMPI}/${OMPI_VERSION}"
	tar -xf "${OMPI_TARBALL}" -C "${OPENMPI}/${OMPI_VERSION}"
	cd "${OPENMPI}/${OMPI_VERSION}/openmpi-${OMPI_VERSION}"
	./configure CC=icc CXX=icpc FC=ifort FCFLAGS=-i8  CFLAGS=-m64  CXXFLAGS=-m64 --enable-mpi-cxx --enable-mpi-fortran=usempi --prefix="${OMPI_INSTALL_PREFIX}"
	make && make install && make check
}

# Unset all aliases
\unalias -a

# Setup umask
umask 0022

# Set the number of process
expr $SETUP_NPROCS / 2 > /dev/null 2>&1 || SETUP_NPROCS=1 # Is $SETUP_NPROCS a number? If not, set it to 1.
MAX_NPROCS=$(grep -c  processor /proc/cpuinfo)
if (( $SETUP_NPROCS < 0 )); then # invalid number of processes (negative numbers, etc.)
  echo "invalid number of processes: $SETUP_NPROCS"
  echo "use default number of processes: 1"
  SETUP_NPROCS=1
elif (( $SETUP_NPROCS > $MAX_NPROCS )); then # number of processes is larger than the number of processors
  echo "number of processors you want to use: $SETUP_NPROCS"
  echo "number of processors you can use: $MAX_NPROCS"
  echo "use max number of processes: $MAX_NPROCS"
  SETUP_NPROCS=$MAX_NPROCS
fi

# Set this script's path
# shellcheck disable=SC2046
SCRIPT_PATH=$(cd $(dirname "$0") && pwd)

# If intel fortran doesn't exist, Exit with error
if ! type ifort > /dev/null; then
	echo "intel fortran compiler (ifort) doesn't exist. We should build intel fortran."
	echo "Please install intel fortran and try again.(ref https://www.intel.com/content/www/us/en/developer/tools/oneapi/toolkits.html)"
	echo "You can also install intel fortran by running the following command(sudo authority and internet access are required): "
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

# # Setup git
# setup_git && module load git/${GIT_VERSION} && git --version

# # Setup CMake
# setup_cmake && module load cmake/${CMAKE_VERSION} && cmake --version

# Build OpenMPI (intel fortran)
OPENMPI_NPROCS=$(( $SETUP_NPROCS / 2 ))
if (( $OPENMPI_NPROCS < 1 )); then
	# Serial build
	echo "CMake will be built in serial mode."
	# Build OpenMPI 3.1.0 (intel fortran)
	setup_openmpi 3.1.0
	# Build OpenMPI 4.1.2 (intel fortran)
    setup_openmpi 4.1.2
else
	# Parallel build
	echo "CMake will be built in parallel mode."
	# Build OpenMPI 3.1.0 and 4.1.2 (intel fortran)
	setup_openmpi 3.1.0 ${OPENMPI_NPROCS} | tee -a 3.1.0 & setup_openmpi 4.1.2 ${OPENMPI_NPROCS} | tee -a 4.1.2
fi



# Build DIRAC

# Build Molcas (interactive)

wait
