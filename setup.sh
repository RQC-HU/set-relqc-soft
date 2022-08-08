#!/usr/bin/env bash
set -euo pipefail

function setup_molcas () {
	cd "$MOLCAS/$MOLCAS_TARBALL_NO_EXTENSION"

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
        echo "ERROR: Detected multiple $PROGRAM_NAME ${FILE_TYPE}s in $SCRIPT_PATH/$PROGRAM_NAME directory."
        echo "       Searched for $FILE_TYPE files named '$FIND_CONDITION'."
        echo "       Please remove all but one file."
        echo "Detected ${FILE_TYPE}s:"
        echo "$FILE_NAMES"
        echo "Exiting."
        exit 1
    fi
}

function configure_molcas () {
	echo "Starting Molcas interactive setup"

	# Find the directory for the MOLCAS installation
	# (e.g. molcas84.tar.gz -> molcas84)
	MOLCAS_LICENSE=$(find "$SCRIPT_PATH/molcas" -maxdepth 1 -name "license*")
	MOLCAS_TARBALL=$(find "$SCRIPT_PATH/molcas" -maxdepth 1 -name "molcas*tar*")
	MOLCAS_TARBALL_NO_EXTENSION="$(echo "$MOLCAS_TARBALL" | awk -F'[/]' '{print $NF}' | sed 's/\.tar.*//')"

	# Now we can configure the Molcas package
	echo "Start configuring Molcas package"
	cp -f "$MOLCAS_LICENSE" "$MOLCAS"
	cp -f "$MOLCAS_TARBALL" "$MOLCAS"
	cd "$MOLCAS"
	tar -xf "$MOLCAS_TARBALL"
	# Check if the directory exists
	if [ ! -d "$MOLCAS_TARBALL_NO_EXTENSION" ]; then
		echo "ERROR: MOLCAS installation directory not found."
		echo "Please check the file name (Searched for '$MOLCAS_TARBALL_NO_EXTENSION' in the '$MOLCAS' directory). Exiting."
		exit 1
	fi
	cd "$MOLCAS/$MOLCAS_TARBALL_NO_EXTENSION"
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
	failed_test_files=()
	tests_count=0
	for TEST_SCRIPT_PATH in $(find "$UTCHEM_BUILD_DIR" -name "test.sh")
	do
		# DFT_GEOPT="$(echo "$TEST_SCRIPT_PATH" | grep dft.geopt)"
		# if [ "$DFT_GEOPT" ]; then
		# 	echo "Skipping test script $TEST_SCRIPT_PATH"
		# 	continue
		# fi
		HF="$(echo "$TEST_SCRIPT_PATH" | grep Hartree)"
		RTDDFT="$(echo "$TEST_SCRIPT_PATH" | grep rtddft)"
		if [ "$HF" ] || [ "$RTDDFT" ]; then
			TEST_SCRIPT_DIR="$(dirname "$TEST_SCRIPT_PATH")"
			cd "$TEST_SCRIPT_DIR"
			echo "Start Running a test script under: ${TEST_SCRIPT_DIR}"
			SCRATCH="scratch"
			TEST_RESULTS="test-results"
			mkdir -p ${SCRATCH} ${TEST_RESULTS}
			for ii in *.ut
			do
				echo
				echo "=================================================================="
				echo "Testing..." $ii
				date
				OUTPUT="${ii}out"
				echo "Output file: ${OUTPUT}"
				echo "../../boot/utchem -n ${SETUP_NPROCS} -w ${SCRATCH} $ii >& ${TEST_RESULTS}/$OUTPUT"

				../../boot/utchem -n "${SETUP_NPROCS}" -w "${SCRATCH} $ii" > "${TEST_RESULTS}/$OUTPUT" 2>&1
				date
				echo "End running test script"

				#<< "#COMMENT"
				tests_count=$(($tests_count+1))
				# a.utout.nproc=1 a.utout.nproc=2 a.utout.nproc=4 => a.utout.nproc=4
				reference_output=$( ls "$TEST_SCRIPT_DIR/$OUTPUT" | tail -n 1 )
				result_output="$TEST_SCRIPT_DIR/${TEST_RESULTS}/$OUTPUT"
				references=($(grep "Total Energy.*=" "$reference_output" | awk '{for(i = 1; i <= NF - 2; i++){printf $i}printf " " $NF " "}'))
				results=($(grep "Total Energy.*=" "$result_output" | awk '{for(i = 1; i <= NF - 2; i++){printf $i}printf " " $NF " "}'))

				echo "Start checking test results for $reference_output and $result_output..."
				echo "references: " "${references[@]}"
				echo "results: " "${results[@]}"
				if [ ${#references[@]} -ne ${#results[@]} ] ; then
					failed_test_files+=("$result_output")
					echo "ERROR: references and results are not same length"
					echo "So we don't evaluate the results of Total Energy"
					echo "references:" "${references[@]}"
					echo "results:" "${results[@]}"
					continue
				fi

				for ((i = 1; i < ${#references[@]}; i+=2));
				do
					diff=$( echo "${references[$i]} ${results[$i]}" | awk '{printf $1 - $2}' )
					absdiff=${diff#-}
					threshold=1e-7
					is_pass_test=$( echo "${absdiff} ${threshold}" | awk '{if($1 <= $2) {print "YES"} else {print "NO"}}' )
					all_test_passed="YES"
					echo "Checking abs(reference - result): ${absdiff} <= ${threshold} ? ... ${is_pass_test}"

					if [ "$is_pass_test" = "YES" ] ; then
						echo "TEST PASSED"
					else
						all_test_passed="NO"
						echo "ERROR: TEST FAILED"
						echo "threshold = $threshold"
						echo "Difference between the reference and the result in the calculation of ${references[$((i-1))]} is greater than the threshold."
						echo "references = ${references[$i]} Hartree"
						echo "results = ${results[$i]} Hartree"
						echo "abs(diff) = ${absdiff} Hartree"
						failed_test_files+=("$result_output")
					fi
				done
				if [ $all_test_passed = "YES" ] ; then
					echo "ALL TESTS PASSED for $result_output"
				else
					echo "ERROR: SOME TESTS FAILED for $result_output"
				fi
				#COMMENT
				echo "End checking test results for $reference_output and $result_output..."
				echo "=================================================================="
				echo
			done
			echo "Finished Running test scripts under: ${TEST_SCRIPT_DIR}"
		fi
	done
	echo "Finished testing UTChem"
	echo "------------------------------------------------------------------"
	echo "Summary of UTChem tests"
	echo "ALL TESTS: ${tests_count}"
	echo "FAILED TESTS: ${#failed_test_files[@]}"
	if [ ${#failed_test_files[@]} -ne 0 ]; then
		echo "ERROR: SOME TESTS FAILED"
		echo "FAILED TESTS:"
		for failed_test in "${failed_test_files[@]}"
		do
			echo "  $failed_test"
		done
	else
		echo "ALL TESTS PASSED!"
	fi
	echo "------------------------------------------------------------------"
	set -e
}

function setup_utchem () {
	OMPI_VERSION="$OPENMPI4_VERSION"
	set_ompi_path # set OpenMPI PATH

	UTCHEM_PATCH=$(find "$SCRIPT_PATH/utchem" -maxdepth 1 -type d -name patches)
	UTCHEM_TARBALL=$(find "$SCRIPT_PATH/utchem" -maxdepth 1 -name "utchem*tar*")
	cp -f "${UTCHEM_TARBALL}" "${UTCHEM}"
	cp -rf "${UTCHEM_PATCH}" "${UTCHEM}"
	PATCHDIR=$(find "$SCRIPT_PATH/utchem" -maxdepth 1 -type d -name patches)
	UTCHEM_TARBALL=$(find "$SCRIPT_PATH/utchem" -maxdepth 1 -name "utchem*tar*")

	# Unzip utchem.tar file
	cd "${UTCHEM}"
	tar xf "${UTCHEM_TARBALL}"
    UTCHEM_BUILD_DIR=$(find "$UTCHEM" -mindepth 1 -type d -name "utchem*")
	GA4="${UTCHEM_BUILD_DIR}/ga4-0-2"

	# File location of Patch files and files to patch
	GAMAKEFILE="${GA4}/ga++/GNUmakefile"
	GAPATCH="${PATCHDIR}/ga_patch"
	GLOBALMAKEFILE="${GA4}/global/GNUmakefile"
	GLOBALPATCH="${PATCHDIR}/global_patch"
	GACONFIGFILE="${GA4}/config/makefile.h"
	GACONFIGPATCH="${PATCHDIR}/makefile.h.patch"

	# Patch files (To run "make" command normally)
	patch "${GAMAKEFILE}" "${GAPATCH}"
	patch "${GLOBALMAKEFILE}" "${GLOBALPATCH}"
	patch "${GACONFIGFILE}" "${GACONFIGPATCH}"

	# Use ifort, gcc and g++ to build utchem (64bit linux machine)
	#   If you want to build utchem using gfortran, gcc and g++ (integer8),
	#       change linux_ifort_x86_64_i8.config.sh.in to linux_gcc4_x86_64_i8_config.sh.in and
	#       change linux_ifort_x86_64_i8.makeconfig.in to linux_gcc4_x86_64_i8_makeconfig.in.
	cd "${UTCHEM_BUILD_DIR}/config"
	cp -f linux_mpi_ifort_x86_64_i8.config.sh.in linux_ifc.config.sh.in
	cp -f linux_mpi_ifort_x86_64_i8.makeconfig.in linux_ifc.makeconfig.in


	# Configure utchem
	#   If your system don't have python in /usr/bin, you have to install python 2.x.x to your system
	#   and add the path where you installed python.
	#   (e.g. If you installed a python executable file at /home/users/username/python)
	#   ./configure --python=/home/users/username/python
	cd "${UTCHEM_BUILD_DIR}"
	UTCHEM_MPI="$(dirname "$( which mpif77 | xargs dirname )")"
	./configure --mpi="$UTCHEM_MPI" --python=python 2>&1 | tee "$SCRIPT_PATH/utchem-make.log"

	# Make utchem (${UTCHEM_BUILD_DIR}/boot/utchem is executable file)
	make 2>&1 | tee "$SCRIPT_PATH/utchem-make.log"

	# Run test script
	test_utchem 2>&1 | tee "$SCRIPT_PATH/utchem-test.log"
	cd "$SCRIPT_PATH"
}

function run_dirac_testing () {
	echo "START DIRAC-${DIRAC_VERSION} ${TEST_TYPE} test!!"
    export DIRAC_MPI_COMMAND="mpirun -np $TEST_NPROCS"
	set +e
	make test
	set -e
	cp -f Testing/Temporary/LastTest.log "$DIRAC_BASEDIR/test_results/$TEST_TYPE"
	if [ -f Testing/Temporary/LastTestsFailed.log ]; then
	cp -f Testing/Temporary/LastTestsFailed.log "$DIRAC_BASEDIR/test_results/$TEST_TYPE"
	fi
}

function build_dirac () {
	echo "DIRAC NRPOCS : $DIRAC_NPROCS"
	DIRAC_BASEDIR="$DIRAC/$DIRAC_VERSION"
	cp -rf "$SCRIPT_PATH/dirac/$DIRAC_VERSION" "$DIRAC"
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
	pyenv global "$PYTHON3_VERSION"
	DIRAC_SCR="$HOME/dirac_scr"
	mkdir -p "$DIRAC_SCR"
	DIRAC_NPROCS=$(( $SETUP_NPROCS / 3 ))
	OMPI_VERSION="$OPENMPI3_VERSION" # DIRAC 19.0 and 21.1 use this version of OpenMPI
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
		OMPI_VERSION="$OPENMPI4_VERSION"
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
		OMPI_VERSION="$OPENMPI4_VERSION"
		set_ompi_path # set OpenMPI PATH
		build_dirac 2>&1 | tee "dirac-$DIRAC_VERSION-build-result.log" &
	fi
	wait
	cd "$SCRIPT_PATH"
}

function setup_git () {
	tar -xf "./git/git-${GIT_VERSION}.tar.gz" -C "${GIT}"
	# ${GIT} にコピーされたtarballは使わないが、あとからどのtarballを使ってビルドしたか確認しやすくするためにコピーしておく
	cp -f "./git/git-${GIT_VERSION}.tar.gz" "${GIT}"
	cp -f "./git/${GIT_VERSION}" "${HOME}/modulefiles/git"
	cd "${GIT}/git-${GIT_VERSION}"
	make prefix="${GIT}" -j "$SETUP_NPROCS"  && make prefix="${GIT}" install
	ret=$?
	if [ $ret -ne 0 ]; then
		echo "Git build failed."
		exit $ret
	fi
	echo "prepend-path    PATH            ${GIT}/bin" >> "${HOME}/modulefiles/git/${GIT_VERSION}"
	module load "git/${GIT_VERSION}" && git --version
    cd "${SCRIPT_PATH}"
}

function setup_python () {
	PYENVROOT="$INSTALL_PATH/.pyenv"
	SKIP_PYENV_INSTALL="Y"
	# if PYENVROOT exists, skip clone
	if [ ! -d "$PYENVROOT" ]; then
		git clone https://github.com/pyenv/pyenv.git "$PYENVROOT"
		SKIP_PYENV_INSTALL="N"
	fi
	export PYENV_ROOT="$INSTALL_PATH/.pyenv"
	export PATH="$PYENV_ROOT/bin:$PATH"
	eval "$(pyenv init -)"
	echo "$PYENV_ROOT , $INSTALL_PATH, skip? : $SKIP_PYENV_INSTALL" >> "$SCRIPT_PATH/python-version.log" 2>&1
	echo "$PATH" | tr ':' '\n' >> "$SCRIPT_PATH/python-version.log" 2>&1
	if [ "$SKIP_PYENV_INSTALL" = "N" ]; then
		echo "export PYENV_ROOT=\"$PYENVROOT/.pyenv\"" >> "$HOME/.bashrc"
		echo "command -v pyenv >/dev/null || export PATH=\"$PYENVROOT/bin:\$PATH\"" >> "$HOME/.bashrc"
		echo 'eval "$(pyenv init -)"' >> "$HOME/.bashrc"
		pyenv install "$PYTHON2_VERSION"
		pyenv install "$PYTHON3_VERSION"
	fi
	pyenv global "$PYTHON2_VERSION"
	python -V >> "$SCRIPT_PATH/python-version.log" 2>&1

}

function setup_cmake () {
	# unzip cmake prebuild tarball
	tar -xf "./cmake/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" -C "${CMAKE}"
	# ${CMAKE} にコピーされたtarballは使わないが、あとからどのtarballを使ってビルドしたか確認しやすくするためにコピーしておく
	cp -f "./cmake/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" "${CMAKE}"
	cp -f "./cmake/${CMAKE_VERSION}" "${HOME}/modulefiles/cmake"
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
		OMPI_VERSION="$OPENMPI3_VERSION"
		build_openmpi 2>&1 | tee "openmpi-$OMPI_VERSION-build-result.log"
		# Build OpenMPI 4.1.2 (intel fortran)
		OMPI_VERSION="$OPENMPI4_VERSION"
		build_openmpi 2>&1 | tee "openmpi-$OMPI_VERSION-build-result.log"
	else
		# Parallel build
		echo "CMake will be built in parallel mode."
		# Build OpenMPI 3.1.0 (intel fortran)
		OMPI_VERSION="$OPENMPI3_VERSION"
		build_openmpi 2>&1 | tee "openmpi-$OMPI_VERSION-build-result.log" &
		# Build OpenMPI 4.1.2 (intel fortran)
		OMPI_VERSION="$OPENMPI4_VERSION"
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

function check_molcas_files () {

	MOLCAS_LICENSE=$(find "$SCRIPT_PATH/molcas" -maxdepth 1 -name "license*")
	MOLCAS_TARBALL=$(find "$SCRIPT_PATH/molcas" -maxdepth 1 -name "molcas*tar*")

	# Check if the license file and tarball exist
	if [ -z "${MOLCAS_LICENSE}" ]; then
		echo "ERROR: MOLCAS License file not found."
		echo "Please check the file name (Searched for 'license' in the '$SCRIPT_PATH/molcas' directory). Exiting."
		exit 1
	fi
	if [ -z "${MOLCAS_TARBALL}" ]; then
		echo "ERROR: MOLCAS Tarball file not found."
		echo "Please check the file name (Searched for 'molcas*tar*' in the '$SCRIPT_PATH/molcas' directory). Exiting."
		exit 1
	fi

    # Check if the number of license file and tarball is one in the directory, respectively.
	FILE_NAMES="$MOLCAS_LICENSE"
	FILE_TYPE="license"
	FIND_CONDITION="license*"
	PROGRAM_NAME="molcas"
	check_one_file_only

	FILE_NAMES="$MOLCAS_TARBALL"
	FILE_TYPE="tarball"
	FIND_CONDITION="molcas*tar*"
	PROGRAM_NAME="molcas"
	check_one_file_only
}

function check_utchem_files () {

	UTCHEM_PATCH=$(find "$SCRIPT_PATH/utchem" -maxdepth 1 -type d -name patches)
	UTCHEM_TARBALL=$(find "$SCRIPT_PATH/utchem" -maxdepth 1 -name "utchem*tar*")

	# Check if the license file and tarball exist
	if [ ! -d "${UTCHEM_PATCH}" ]; then
		echo "ERROR: UTCHEM patches directory not found."
		echo "Please check the file name (Searched for 'patches' in the '$SCRIPT_PATH/utchem' directory). Exiting."
		exit 1
	fi
	if [ -z "${UTCHEM_TARBALL}" ]; then
		echo "ERROR: UTCHEM Tarball file not found."
		echo "Please check the file name (Searched for 'utchem*tar*' in the '$SCRIPT_PATH/utchem' directory). Exiting."
		exit 1
	fi

	# Check if the number of tarball is one in the directory.
	FILE_NAMES="$UTCHEM_TARBALL"
	FILE_TYPE="tarball"
	FIND_CONDITION="utchem*tar*"
	PROGRAM_NAME="utchem"
	check_one_file_only
}

function check_files_and_dirs () {
	if [ "$molcas_install" == "YES" ]; then
		mkdir -p "${MOLCAS}"
		check_molcas_files
	fi
	if [ "$utchem_install" == "YES" ] || [ "$dirac_install" == "YES" ]; then
		mkdir -p "${OPENMPI}"
	fi
	if [ "$dirac_install" == "YES" ]; then
		mkdir -p "${DIRAC}"
		mkdir -p "${MODULEFILES}/dirac"
	fi
	if [ "$utchem_install" == "YES" ]; then
		mkdir -p "${UTCHEM}"
		check_utchem_files
	fi
}

function check_install_programs () {
	INSTALL_PROGRAMS=("git" "CMake")
	if [ "$molcas_install" == "YES" ]; then
		INSTALL_PROGRAMS+=("Molcas")
	fi
	if [ "$dirac_install" == "YES" ]; then
		INSTALL_PROGRAMS+=("DIRAC")
	fi
	if [ "$utchem_install" == "YES" ]; then
		INSTALL_PROGRAMS+=("UTChem")
	fi
	if [ "$utchem_install" == "YES" ] || [ "$dirac_install" == "YES" ]; then
		INSTALL_PROGRAMS+=("OpenMPI")
	fi

	echo "The following programs will be installed:"
	for PROGRAM in "${INSTALL_PROGRAMS[@]}"
	do
		echo "$PROGRAM"
	done
}

function whether_install_or_not() {
    ANS="NO"
    while true; do
    read -p "Do you want to install $PROGRAM_NAME? (y/N)" yn
    case $yn in
        [Yy]* ) ANS="YES"; break;;
        [Nn]* ) ANS="NO"; break;;
        * ) ANS="YES"; break;;
    esac
    done
    echo $ANS
}

function set_install_path () {
	# Check if the variable is set
    if [ -z "${INSTALL_PATH:-}" ]; then
        echo "INSTALL_PATH is not set"
        INSTALL_PATH="${HOME}/software"
		echo "INSTALL_PATH is set to default install path: $INSTALL_PATH"
    else
		echo "INSTALL_PATH is set to: $INSTALL_PATH"
	fi

	# If overwrite is not set, change overwrite to NO
	if [ -z "${OVERWRITE:-}" ]; then
		OVERWRITE="NO"
	fi

    # Check if the path exists
	# OVERWRITE is set to YES if the user wants to overwrite the existing installation
	if [ "${OVERWRITE}" = "YES" ]; then
		echo "Warning: OVERWRITE option selected YES.  may overwrite the existing path! $INSTALL_PATH."
		echo "If you want to keep the existing path, do not set OVERWRITE to YES."
		ANS="NO"
		while true; do
			read -p "Do you want to continue? (y/N)" yn
			case $yn in
				[Yy]* ) ANS="YES"; break;;
				[Nn]* ) ANS="NO"; break;;
				* ) ANS="NO"; break;;
			esac
		done
		if [ "$ANS" = "NO" ]; then
			echo "Exiting."
			exit 1
		fi
		echo "OVERWRITE option selected YES. may overwrite the existing path! $INSTALL_PATH."
		return # No need to check if the path exists, because we are overwriting the files.
	else
		if [ -d "$INSTALL_PATH" ]; then
			echo "$INSTALL_PATH is already exists"
			echo "Please remove the directory and run the script again or set the another path that does not exist."
			exit 1
		fi
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

# Set the path of installation directory
set_install_path

# Set this script's path
SCRIPT_PATH=$(cd "$(dirname "$0")" && pwd)

# Software path
MODULEFILES="${HOME}/modulefiles"
CMAKE="${INSTALL_PATH}/cmake"
OPENMPI="${INSTALL_PATH}/openmpi"
DIRAC="${INSTALL_PATH}/DIRAC"
MOLCAS="${INSTALL_PATH}/molcas"
UTCHEM="${INSTALL_PATH}/utchem"
GIT="${INSTALL_PATH}/git"

# VERSIONS
GIT_VERSION="2.37.1"
CMAKE_VERSION="3.23.2"
OPENMPI3_VERSION="3.1.0"
OPENMPI4_VERSION="4.1.2"
PYTHON2_VERSION="2.7.18"
PYTHON3_VERSION="3.9.12"

# Check whether the user wants to install or not
PROGRAM_NAME="MOLCAS"
molcas_install=$(whether_install_or_not)
PROGRAM_NAME="DIRAC"
dirac_install=$(whether_install_or_not)
PROGRAM_NAME="UTCHEM"
utchem_install=$(whether_install_or_not)
check_install_programs

# Check files and directories
check_files_and_dirs

# Create directories for Environment modules
mkdir -p "${MODULEFILES}/git"
mkdir -p "${MODULEFILES}/cmake"

# Clean modulefiles
module purge
module use --append "${MODULEFILES}"

# Setup CMake
mkdir -p "${CMAKE}"
setup_cmake

# Setup git
mkdir -p  "${GIT}"
setup_git

if [ "$molcas_install" == "YES" ]; then
	configure_molcas
fi
# Setup python using pyenv
setup_python
# Congigure Molcas (interactive)
if [ "$molcas_install" == "YES" ]; then
	setup_molcas
else
	echo "Skip Molcas installation."
fi

if [ "$utchem_install" == "YES" ] || [ "$dirac_install" == "YES" ]; then
	# Build OpenMPI (intel fortran, You need to build this to build DIRAC or UTCHEM)
	setup_openmpi
else
	echo "Skip OpenMPI installation."
fi

# Setup utchem
if [ "$utchem_install" == "YES" ]; then
	setup_utchem
else
	echo "Skip utchem installation."
fi


if [ "$dirac_install" == "YES" ]; then
	# Build DIRAC
	setup_dirac
else
	echo "Skip dirac installation."
fi

echo "Build end"
function shutdown() {
    ps -o pid,cmd --tty $(tty) | tail -n +2 | while read -ra line; do
        if [[ ${line[1]} == *sleep* ]]; then
            kill "${line[0]}"
        fi
    done
}

trap shutdown EXIT
