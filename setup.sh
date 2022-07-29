#!/usr/bin/env bash
set -euo pipefail

function build_dirac () {
	echo "DIRAC NRPOCS : $DIRAC_NPROCS"
	DIRAC_BASEDIR="$DIRAC/$DIRAC_VERSION"
	cp -r "$SCRIPT_PATH/dirac/$DIRAC_VERSION" "$DIRAC"
	cd "$DIRAC_BASEDIR"
	DIRAC_TAR="DIRAC-$DIRAC_VERSION-Source.tar.gz"
	tar xf "$DIRAC_TAR"
	cd "DIRAC-$DIRAC_VERSION-Source"
	PATCH_MEMCONTROL="$DIRAC_BASEDIR/diff_memcon"
	patch -p0 --ignore-whitespace < "$PATCH_MEMCONTROL"
	./setup --mpi --fc=mpif90 --cc=mpicc --cxx=mpicxx --mkl=parallel --int64 --extra-fc-flags="-xHost"  --extra-cc-flags="-xHost"  --extra-cxx-flags="-xHost" --prefix="$DIRAC_BASEDIR"
	cd build
	make -j "$DIRAC_NPROCS" && make install
	cp -f ../LICENSE "$DIRAC_BASEDIR"
	mkdir -p "$DIRAC_BASEDIR/patches"
	cp -f "$PATCH_MEMCONTROL" "$DIRAC_BASEDIR/patches"
	mkdir -p "$DIRAC_BASEDIR"/test_results/serial
    mkdir -p "$DIRAC_BASEDIR"/test_results/parallel
	export DIRAC_MPI_COMMAND="mpirun -np 1"
	set +e
	make test
	set -e
	cp Testing/Temporary/LastTest.log "$DIRAC_BASEDIR"/test_results/serial
	if [ -f Testing/Temporary/LastTestsFailed.log ]; then
	cp Testing/Temporary/LastTestsFailed.log "$DIRAC_BASEDIR"/test_results/serial
	fi
	export DIRAC_MPI_COMMAND="mpirun -np ${DIRAC_NPROCS}"
	set +e
	make test
	set -e
	cp Testing/Temporary/LastTest.log "$DIRAC_BASEDIR"/test_results/parallel
	if [ -f Testing/Temporary/LastTestsFailed.log ]; then
	cp Testing/Temporary/LastTestsFailed.log "$DIRAC_BASEDIR"/test_results/parallel
	fi
	cd "$SCRIPT_PATH"
}

function set_ompi_path () {
	PATH="${OPENMPI}/${OMPI_VERSION}/openmpi-${OMPI_VERSION}-intel/bin:$PATH"
	LIBRARY_PATH="${OPENMPI}/${OMPI_VERSION}/openmpi-${OMPI_VERSION}-intel/lib:$LIBRARY_PATH"
	LD_LIBRARY_PATH="${OPENMPI}/${OMPI_VERSION}/openmpi-${OMPI_VERSION}-intel/lib:$LD_LIBRARY_PATH"
}

function setup_dirac () {
	cd "$SCRIPT_PATH"
	DIRAC_SCR="$HOME/dirac_scr"
	mkdir -p "$DIRAC_SCR"
	DIRAC_NPROCS=$(( $SETUP_NPROCS / 3 ))
	OMPI_VERSION="3.1.0" # DIRAC 19.0 and 21.1 use this version of OpenMPI
	set_ompi_path # set OpenMPI PATH
	if (( $DIRAC_NPROCS <= 1 )); then # Serial build
		echo "DIRAC will be built in serial mode."
		DIRAC_NPROCS=$SETUP_NPROCS
		# Build DIRAC 19.0
		DIRAC_VERSION="19.0"
		build_dirac 2>&1 | tee "dirac-$DIRAC_VERSION-build-result.log"
		# Build DIRAC 21.1
		DIRAC_VERSION="21.1"
		build_dirac 2>&1 | tee "dirac-$DIRAC_VERSION-build-result.log"
		# Build DIRAC 22.0
		DIRAC_VERSION="22.0"
		OMPI_VERSION="4.1.2"
		set_ompi_path # set OpenMPI PATH
		build_dirac 2>&1 | tee "dirac-$DIRAC_VERSION-build-result.log"
	else # Parallel build
		echo "DIRAC will be built in parallel mode."
		# Build DIRAC 19.0
		DIRAC_VERSION="19.0"
		OMPI_VERSION="3.1.0"
		build_dirac 2>&1 | tee "dirac-$DIRAC_VERSION-build-result.log" &
		# Build DIRAC 21.1
		DIRAC_VERSION="21.1"
		build_dirac 2>&1 | tee "dirac-$DIRAC_VERSION-build-result.log" &
		# Build DIRAC 22.0
		DIRAC_VERSION="22.0"
		OMPI_VERSION="4.1.2"
		set_ompi_path # set OpenMPI PATH
		build_dirac 2>&1 | tee "dirac-$DIRAC_VERSION-build-result.log" &
	fi
}

function setup_git () {
	tar -xf "./git/git-${GIT_VERSION}.tar.gz" -C "${GIT}"
	# ${GIT} にコピーされたtarballは使わないが、あとからどのtarballを使ってビルドしたか確認しやすくするためにコピーしておく
	cp "./git/git-${GIT_VERSION}.tar.gz" "${GIT}"
	cp "./git/${GIT_VERSION}" "${HOME}/modulefiles/git"
	cd "${GIT}/git-${GIT_VERSION}"
	make prefix="${GIT}" -j "$SETUP_NPROCS"  && make prefix="${GIT}" install
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

function build_openmpi() {
	# openmpi (8-byte integer)
	cd "${SCRIPT_PATH}"
	OMPI_TARBALL="./openmpi/openmpi-${OMPI_VERSION}.tar.bz2"
	OMPI_INSTALL_PREFIX="${OPENMPI}/${OMPI_VERSION}/openmpi-${OMPI_VERSION}-intel"
	mkdir -p "${OPENMPI}/${OMPI_VERSION}"
	tar -xf "${OMPI_TARBALL}" -C "${OPENMPI}/${OMPI_VERSION}"
	cd "${OPENMPI}/${OMPI_VERSION}/openmpi-${OMPI_VERSION}"
	./configure CC=icc CXX=icpc FC=ifort FCFLAGS=-i8  CFLAGS=-m64  CXXFLAGS=-m64 --enable-mpi-cxx --enable-mpi-fortran=usempi --prefix="${OMPI_INSTALL_PREFIX}"
	make -j "$OPENMPI_NPROCS" && make install && make check
}

function setup_openmpi() {
	OPENMPI_NPROCS=$(( $SETUP_NPROCS / 2 ))
	if (( $OPENMPI_NPROCS < 1 )); then
		# Serial build
		echo "CMake will be built in serial mode."
		# Build OpenMPI 3.1.0 (intel fortran)
		OMPI_VERSION="3.1.0"
		build_openmpi 2>&1 | tee "openmpi-$OMPI_VERSION-build-result.log"
		# Build OpenMPI 4.1.2 (intel fortran)
		OMPI_VERSION="4.1.2"
		build_openmpi 2>&1 | tee "openmpi-$OMPI_VERSION-build-result.log"
	else
		# Parallel build
		echo "CMake will be built in parallel mode."
		# Build OpenMPI 3.1.0 (intel fortran)
		OMPI_VERSION="3.1.0"
		build_openmpi 2>&1 | tee "openmpi-$OMPI_VERSION-build-result.log" &
		# Build OpenMPI 4.1.2 (intel fortran)
		OMPI_VERSION="4.1.2"
		build_openmpi 2>&1 | tee "openmpi-$OMPI_VERSION-build-result.log" &
	fi
}

function set_process_number () {
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
}


# Unset all aliases
\unalias -a

# Setup umask
umask 0022

# If intel fortran doesn't exist, Exit with error
if ! type ifort > /dev/null; then
	echo "intel fortran compiler (ifort) doesn't exist. We should build intel fortran."
	echo "Please install intel fortran and try again.(ref https://www.intel.com/content/www/us/en/developer/tools/oneapi/toolkits.html)"
	echo "You can also install intel fortran by running the following command(sudo authority and internet access are required): "
	echo "> sudo sh ${SCRIPT_PATH}/intel-fortran.sh"
	exit 1
fi

# Check $MKLROOT is set or not
if [ -z "$MKLROOT" ]; then
	echo "MKLROOT is not set."
	echo "Please set MKLROOT environment variable."
	exit 1
fi

# Set the number of process
set_process_number

# Set this script's path
SCRIPT_PATH=$(cd "$(dirname "$0")" && pwd)

# Software path
SOFTWARES="${HOME}/tmp/Software"
MODULEFILES="${HOME}/modulefiles"
CMAKE="${SOFTWARES}/cmake"
OPENMPI="${SOFTWARES}/openmpi"
DIRAC="${SOFTWARES}/DIRAC"
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
setup_git
module load git/${GIT_VERSION} && git --version

# Setup CMake
setup_cmake
module load cmake/${CMAKE_VERSION} && cmake --version

# Build OpenMPI (intel fortran)
setup_openmpi

wait

# Build DIRAC
setup_dirac

wait
# Build Molcas (interactive)


echo "Build end"
