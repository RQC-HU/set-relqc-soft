#!/usr/bin/env bash
set -euo pipefail

function setup_molcas () {
	cd "$MOLCAS/$TARBALL_FILENAME_NO_EXTENSION"

	# Build MOLCAS
	make 2>&1 | tee "$SCRIPT_PATH/molcas-make.log"
	ret=$?
	if [ $ret -ne 0 ]; then
		echo "ERROR: Molcas make failed with exit code $ret"
		exit $ret
	fi

	cd "$SCRIPT_PATH"
}

function check_one_file_only () {
    if [ "$( echo "$FILE_NAMES" | wc -l )" -gt 1 ]; then
        echo "ERROR: Detected multiple MOLCAS ${FILE_TYPE}s in $PWD/molcas directory."
        echo "       Searched for $FILE_TYPE files named '$FIND_CONDITION'."
        echo "       Please remove all but one license."
        echo "Detected ${FILE_TYPE}s:"
        echo "$FILE_NAMES"
        echo "Exiting."
        exit 1
    fi
}

function configure_molcas () {
	echo "Starting Molcas interactive setup"
	LICENSE_FILENAME=$(find "$PWD/molcas" -maxdepth 1 -name "license*")
	TARBALL_FILENAME=$(find "$PWD/molcas" -maxdepth 1 -name "molcas*tar*")

	# Check if the license file and tarball exist
	if [ -z "${LICENSE_FILENAME}" ]; then
		echo "ERROR: MOLCAS License file not found."
		echo "Please check the file name (Searched for 'license' in the '$SCRIPT_PATH/molcas' directory). Exiting."
		exit 1
	fi
	if [ -z "${TARBALL_FILENAME}" ]; then
		echo "ERROR: MOLCAS Tarball file not found."
		echo "Please check the file name (Searched for 'molcas*tar*' in the '$SCRIPT_PATH/molcas' directory). Exiting."
		exit 1
	fi

    # Check if the number of license file and tarball is one in the directory, respectively.
	FILE_NAMES="$LICENSE_FILENAME"
	FILE_TYPE="license"
	FIND_CONDITION="license*"
	check_one_file_only

	FILE_NAMES="$TARBALL_FILENAME"
	FILE_TYPE="tarball"
	FIND_CONDITION="molcas*tar*"
	check_one_file_only

	# Find the directory for the MOLCAS installation
	# (e.g. molcas84.tar.gz -> molcas84)
	TARBALL_FILENAME_NO_EXTENSION="$(echo "$TARBALL_FILENAME" | awk -F'[/]' '{print $NF}' | sed 's/\.tar.*//')"

	# Now we can configure the Molcas package
	echo "Start configuring Molcas package"
	cp "$LICENSE_FILENAME" "$MOLCAS"
	cp "$TARBALL_FILENAME" "$MOLCAS"
	cd "$MOLCAS"
	tar -xf "$TARBALL_FILENAME"
	# Check if the directory exists
	if [ ! -d "$TARBALL_FILENAME_NO_EXTENSION" ]; then
		echo "ERROR: MOLCAS installation directory not found."
		echo "Please check the file name (Searched for '$TARBALL_FILENAME_NO_EXTENSION' in the '$MOLCAS' directory). Exiting."
		exit 1
	fi
	cd "$MOLCAS/$TARBALL_FILENAME_NO_EXTENSION"
	# Configure the Molcas package
	./setup
	ret=$?
	if [ $ret -ne 0 ]; then
		echo "ERROR: Molcas setup failed."
		echo "Please check the log file '$SCRIPT_PATH/molcas-setup.log' for more information."
		exit 1
	fi
	cd "$SCRIPT_PATH"
}

function test_utchem () {
	set +e
	echo "Start testing UTChem..."
	for TEST_PATH in $(find "$UTCHEM_BUILD_DIR" -name "test.sh" | sed "s/\/test.sh//g")
	do
		cd "${TEST_PATH}"
		echo "Start Running test scripts under: ${TEST_PATH}"
		WORK="scrach"
		TITLE="test-results"
		mkdir -p "${WORK}"
		mkdir -p "${TITLE}"
		for ii in *.ut
		do
			echo
			echo "=================================================================="
			echo "UTChem Parallel Testing... $TEST_PATH/$ii"
			date
			OUTPUT=${TITLE}/${ii}out
			echo "$UTCHEM_BUILD_DIR/boot/utchem -w ${WORK} $ii >& $OUTPUT"

			"$UTCHEM_BUILD_DIR"/boot/utchem -w "${WORK}" "$ii" 2>&1 | tee "$OUTPUT"

			date
			echo "=================================================================="
			echo
		done
	done
	set -e
	cd "$SCRIPT_PATH"
}

function setup_utchem () {
	cp "${SCRIPT_PATH}/utchem/utchem.2008.8.12.tar" "${UTCHEM}"
	cp -r "${SCRIPT_PATH}/utchem/patches" "${UTCHEM}"
	PATCHDIR="${UTCHEM}/patches"
	UTCHEM_BUILD_DIR="${UTCHEM}/utchem"
	UTCHEM_TARBALL="${UTCHEM}/utchem.2008.8.12.tar"
	GA4="${UTCHEM_BUILD_DIR}/ga4-0-2"

	# File location of Patch files and files to patch
	GAMAKEFILE="${GA4}/ga++/GNUmakefile"
	GAPATCH="${PATCHDIR}/ga_patch"
	GLOBALMAKEFILE="${GA4}/global/GNUmakefile"
	GLOBALPATCH="${PATCHDIR}/global_patch"
	GACONFIGFILE="${GA4}/config/makefile.h"
	GACONFIGPATCH="${PATCHDIR}/makefile.h.patch"

	# Unzip utchem.tar file
	cd "${UTCHEM}"
	tar xf "${UTCHEM_TARBALL}"

	# Patch files (To run "make" command normally)
	patch "${GAMAKEFILE}" "${GAPATCH}"
	patch "${GLOBALMAKEFILE}" "${GLOBALPATCH}"
	patch "${GACONFIGFILE}" "${GACONFIGPATCH}"

	# Use ifort, gcc and g++ to build utchem (64bit linux machine)
	#   If you want to build utchem using gfortran, gcc and g++ (integer8),
	#       change linux_ifort_x86_64_i8.config.sh.in to linux_gcc4_x86_64_i8_config.sh.in and
	#       change linux_ifort_x86_64_i8.makeconfig.in to linux_gcc4_x86_64_i8_makeconfig.in.
	cd "${UTCHEM_BUILD_DIR}/config"
	cp linux_ifort_x86_64_i8.config.sh.in linux_ifc.config.sh.in
	cp linux_ifort_x86_64_i8.makeconfig.in linux_ifc.makeconfig.in


	# Configure utchem
	#   If your system don't have python in /usr/bin, you have to install python 2.x.x to your system
	#   and add the path where you installed python.
	#   (e.g. If you installed a python executable file at /home/users/username/python)
	#   ./configure --python=/home/users/username/python
	cd "${UTCHEM_BUILD_DIR}"
	./configure --python=python2

	# Make utchem (${UTCHEM_BUILD_DIR}/boot/utchem is executable file)
	make

	# Run test script
	test_utchem > utchem-test.log 2>&1

	cd "$SCRIPT_PATH"
}

function run_dirac_testing () {
	echo "START DIRAC-${DIRAC_VERSION} ${TEST_TYPE} test!!"
    export DIRAC_MPI_COMMAND="mpirun -np $TEST_NPROCS"
	set +e
	make test
	set -e
	cp Testing/Temporary/LastTest.log "$DIRAC_BASEDIR/test_results/$TEST_TYPE"
	if [ -f Testing/Temporary/LastTestsFailed.log ]; then
	cp Testing/Temporary/LastTestsFailed.log "$DIRAC_BASEDIR/test_results/$TEST_TYPE"
	fi
}

function build_dirac () {
	echo "DIRAC NRPOCS : $DIRAC_NPROCS"
	DIRAC_BASEDIR="$DIRAC/$DIRAC_VERSION"
	cp -r "$SCRIPT_PATH/dirac/$DIRAC_VERSION" "$DIRAC"
	cd "$DIRAC_BASEDIR"
	# Unzip tarball
	DIRAC_TAR="DIRAC-$DIRAC_VERSION-Source.tar.gz"
	tar xf "$DIRAC_TAR"
	cd "DIRAC-$DIRAC_VERSION-Source"
	# Patch DIRAC integer(4) to integer(8) (max_mem)
	PATCH_MEMCONTROL="$DIRAC_BASEDIR/diff_memcon"
	patch -p0 --ignore-whitespace < "$PATCH_MEMCONTROL"
	# Configure DIRAC
	./setup --mpi --fc=mpif90 --cc=mpicc --cxx=mpicxx --mkl=parallel --int64 --extra-fc-flags="-xHost"  --extra-cc-flags="-xHost"  --extra-cxx-flags="-xHost" --prefix="$DIRAC_BASEDIR"
	cd build
	# Build DIRAC
	make -j "$DIRAC_NPROCS" && make install
	# Serial test
	TEST_TYPE="serial"
	TEST_NPROCS=1
	mkdir -p "$DIRAC_BASEDIR"/test_results/serial
	run_dirac_testing
	# Parallel test
	TEST_TYPE="parallel"
	TEST_NPROCS=${DIRAC_NPROCS}
    mkdir -p "$DIRAC_BASEDIR"/test_results/parallel
	run_dirac_testing
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
		OMPI_VERSION="3.1.0"
		build_dirac 2>&1 | tee "dirac-$DIRAC_VERSION-build-result.log" &
		# Build DIRAC 22.0
		DIRAC_VERSION="22.0"
		OMPI_VERSION="4.1.2"
		set_ompi_path # set OpenMPI PATH
		build_dirac 2>&1 | tee "dirac-$DIRAC_VERSION-build-result.log" &
	fi
	wait
	cd "$SCRIPT_PATH"
}

function setup_git () {
	tar -xf "./git/git-${GIT_VERSION}.tar.gz" -C "${GIT}"
	# ${GIT} にコピーされたtarballは使わないが、あとからどのtarballを使ってビルドしたか確認しやすくするためにコピーしておく
	cp "./git/git-${GIT_VERSION}.tar.gz" "${GIT}"
	cp "./git/${GIT_VERSION}" "${HOME}/modulefiles/git"
	cd "${GIT}/git-${GIT_VERSION}"
	make prefix="${GIT}" -j "$SETUP_NPROCS"  && make prefix="${GIT}" install
	ret=$?
	if [ $ret -ne 0 ]; then
		echo "Git build failed."
		exit $ret
	fi
	echo "prepend-path    PATH            ${GIT}/bin" >> "${HOME}/modulefiles/git/${GIT_VERSION}"
	module load git/${GIT_VERSION} && git --version
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
    module load cmake/${CMAKE_VERSION} && cmake --version
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
	wait
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
UTCHEM="${SOFTWARES}/utchem"
GIT="${SOFTWARES}/git"

# VERSIONS
GIT_VERSION="2.37.1"
CMAKE_VERSION="3.23.2"

# Create directories for Softwares
mkdir -p "${CMAKE}" "${OPENMPI}" "${DIRAC}" "${MOLCAS}" "${GIT}" "${UTCHEM}"

# Create directories for Environment modules
mkdir -p "${MODULEFILES}/git"
mkdir -p "${MODULEFILES}/cmake"

# Clean modulefiles
module purge
module use --append "${MODULEFILES}"

# Setup CMake
setup_cmake

# Setup git
setup_git

# Congigure Molcas (interactive)
configure_molcas
setup_molcas &

# Setup utchem
setup_utchem 2>&1 | tee "$SCRIPT_PATH/utchem-make.log" &
wait

# Build OpenMPI (intel fortran, You need to build this to build DIRAC)
setup_openmpi

# Build DIRAC
setup_dirac

echo "Build end"
