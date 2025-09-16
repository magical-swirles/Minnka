#!/bin/bash
#
# Run tests
# Usage: run_tests.sh <project-directory> <project-name> <extension-for-rv> <mop-directory> <option> <time> [file]
#
# option:
# all           Run all tests
# all-rv        Run all tests with RV
# reduced       Run reduced tests
# reduced-rv    Run reduced tests with RV
# redundant     Run redundant tests
# redundant-rv  Run redundant tests with RV
# file          Run tests in `file`
# file-rv       Run tests in `file` with RV
#
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
STATUS_CODE=0
source ${SCRIPT_DIR}/../experiments/utils.sh

# Download the profiler and build JFRReader
function setup_profiling() {
  if [[ ${PROFILE} == "true" ]]; then
    if [[ ! -d "${SCRIPT_DIR}/async-profiler-2.9-linux-x64" ]]; then
      pushd "${SCRIPT_DIR}" &> /dev/null
      wget https://github.com/async-profiler/async-profiler/releases/download/v2.9/async-profiler-2.9-linux-x64.tar.gz
      tar xf async-profiler-2.9-linux-x64.tar.gz
      rm async-profiler-2.9-linux-x64.tar.gz
      popd &> /dev/null
    fi
    pushd "${SCRIPT_DIR}/../profiling/JFRReader" &> /dev/null
    mvn clean package
    popd &> /dev/null
  fi
}

# Convert relative path to absolute path
function convert_to_absolute_paths() {
  if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
    PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
  fi
  
  if [[ ! ${EXTENSION_JAR} =~ ^/.* ]]; then
    EXTENSION_JAR=${SCRIPT_DIR}/${EXTENSION_JAR}
  fi
  
  if [[ ! ${MOP_DIR} =~ ^/.* ]]; then
    MOP_DIR=${SCRIPT_DIR}/${MOP_DIR}
  fi
  
  if [[ ! ${FILE_PATH} =~ ^/.* ]]; then
    FILE_PATH=${SCRIPT_DIR}/${FILE_PATH}
  fi
}

function check_inputs() {
  if [[ ! -f "${PROJECT_DIR}/${PROJECT_NAME}/tests.txt" ]]; then
    echo "Please run 'collect_tests.sh' first"
    exit 1
  fi
  
  if [[ ${RUN_OPTION} == "reduced" || ${RUN_OPTION} == "reduced-rv" ]] && [[ ! -f "${PROJECT_DIR}/${PROJECT_NAME}/reduced_tests${FILE_SUFFIX}.txt" ]]; then
    echo "Cannot find file reduced_tests${FILE_SUFFIX}.txt"
    echo "Please run 'generate_matrix.py' first"
    exit 1
  fi
  
  if [[ ${RUN_OPTION} == "redundant" || ${RUN_OPTION} == "redundant" ]] && [[ ! -f "${PROJECT_DIR}/${PROJECT_NAME}/redundant_tests${FILE_SUFFIX}.txt" ]]; then
    echo "Cannot find file redundant_tests${FILE_SUFFIX}.txt"
    exit 1
  fi
  
  if [[ ${RUN_OPTION} == "file" || ${RUN_OPTION} == "file-rv" ]] && [[ ! -f ${FILE_PATH} ]]; then
    echo "Cannot find file ${FILE_PATH}"
    exit 1
  fi
}


function install_no_trace_agent() {
  if [[ ${INSTALL_AGENT:-true} == true ]]; then
    install_agent ${PROJECT_DIR}/${PROJECT_NAME} "${PROJECT_DIR}/repo${REPO_SUFFIX}" ${MOP_DIR} "no-track-agent"
  fi
}

function run_tests_with_option() {
  local option=$1
  local test_suite=$2
  pushd "${PROJECT_DIR}/${PROJECT_NAME}" &> /dev/null
  # No need to store the traces
  install_no_trace_agent
  
  # Set tmp directory to avoid conflict
  local tmp_dir="/tmp/tsm-tmp-${PROJECT_NAME}"
  rm -rf ${tmp_dir} && mkdir ${tmp_dir}

  local start=$(date +%s%3N)

  if [[ ${PROFILE} == "true" ]]; then
    export MOP_AGENT_PATH="-javaagent:\${settings.localRepository}/javamop-agent/javamop-agent/1.0/javamop-agent-1.0.jar -agentpath:${SCRIPT_DIR}/async-profiler-2.9-linux-x64/build/libasyncProfiler.so=start,interval=5ms,event=wall,file=profile.jfr"
  fi

  if [[ -n ${test_suite} ]]; then
    time mvn -Dsurefire.exitTimeout=10000000 -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" -Djava.io.tmpdir=${tmp_dir} ${option} "${test_suite}"
    STATUS_CODE=$?
  else
    time mvn -Dsurefire.exitTimeout=10000000 -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" -Djava.io.tmpdir=${tmp_dir} ${option}
    STATUS_CODE=$?
  fi
  
  if [[ ${PROFILE} == "true" ]]; then
    # Get all project's packages
    if [[ ! -f packages.txt ]]; then
      grep --include "*.java" -rhE "package [a-zA-Z0-9_]+(\.[a-zA-Z0-9_]+)*;" . | grep "^package" | cut -d ' ' -f 2 | sed 's/;.*//g' | sort -u > packages.txt
    fi
    java -jar ${SCRIPT_DIR}/../profiling/JFRReader/target/JFRReader-1.0-SNAPSHOT-jar-with-dependencies.jar profile.jfr packages.txt rv
    mv profile.jfr "${RUN_OPTION}-profile.jfr"
    mv output.csv "${RUN_OPTION}-output.csv"
    unset MOP_AGENT_PATH
  fi

  local end=$(date +%s%3N)
  DURATION=$((end - start))
  
  # We need to add write permission because projects like apache/commons-io will create non-writable directories in tmp_dir
  chmod -R +w ${tmp_dir} && rm -rf ${tmp_dir}
  popd &> /dev/null
}

function run_tests_from_file_with_options() {
  local tests_option=$1
  local tests_file=$2
  local test_suite=$(cat ${tests_file} | sed -z '$ s/\n$//;s/\n/,/g') # Replace \n with ,
  if [[ -n ${test_suite} ]]; then
    run_tests_with_option "${tests_option}" "-Dtest=${test_suite}"
  fi
}

function run_tests() {
  export RVMLOGGINGLEVEL=UNIQUE
  rm -rf ${PROJECT_DIR}/${PROJECT_NAME}/violation-counts

  case ${RUN_OPTION} in
    all)
      run_tests_with_option "org.apache.maven.plugins:maven-surefire-plugin:3.1.2:test"
      ;;
    all-rv)
      run_tests_with_option "surefire:test -Dmaven.ext.class.path=${EXTENSION_JAR}"
      ;;
    reduced)
      local reduced_tests_txt="${PROJECT_DIR}/${PROJECT_NAME}/reduced_tests${FILE_SUFFIX}.txt"
      run_tests_from_file_with_options "org.apache.maven.plugins:maven-surefire-plugin:3.1.2:test" "${reduced_tests_txt}"
      ;;
    reduced-rv)
      local reduced_tests_txt="${PROJECT_DIR}/${PROJECT_NAME}/reduced_tests${FILE_SUFFIX}.txt"
      run_tests_from_file_with_options "surefire:test -Dmaven.ext.class.path=${EXTENSION_JAR}" "${reduced_tests_txt}"
      ;;
    redundant)
      local redundant_tests_txt="${PROJECT_DIR}/${PROJECT_NAME}/redundant_tests${FILE_SUFFIX}.txt"
      run_tests_from_file_with_options "org.apache.maven.plugins:maven-surefire-plugin:3.1.2:test" "${redundant_tests_txt}"
      ;;
    redundant-rv)
      local redundant_tests_txt="${PROJECT_DIR}/${PROJECT_NAME}/redundant_tests${FILE_SUFFIX}.txt"
      run_tests_from_file_with_options "surefire:test -Dmaven.ext.class.path=${EXTENSION_JAR}" "${redundant_tests_txt}"
      ;;
    file)
      run_tests_from_file_with_options "org.apache.maven.plugins:maven-surefire-plugin:3.1.2:test" "${FILE_PATH}"
      ;;
    file-rv)
      run_tests_from_file_with_options "surefire:test -Dmaven.ext.class.path=${EXTENSION_JAR}" "${FILE_PATH}"
      ;;
    *)
      echo "Invalid option: {all|all-rv|reduced|reduced-rv|redundant|redundant-rv|file|file-rv}"
      exit 1
    ;;
  esac
}

PROFILE="false"
while getopts :j: opts; do
  case "${opts}" in
    j ) PROFILE="${OPTARG}" ;;
  esac
done
shift $((${OPTIND} - 1))

PROJECT_DIR=$1
PROJECT_NAME=$(echo $2 | tr / -)
EXTENSION_JAR=$3
MOP_DIR=$4
RUN_OPTION=$5
TRACK_TIME=$6
FILE_PATH=$7
DURATION=0

if [[ -z "$5" ]]; then
  echo "Usage: ./run_tests.sh [-j <profile:true/false>] <project-directory> <project-name> <extension-for-rv> <mop-directory> <option> <time> [file]"
  echo "       option: {all|all-rv|reduced|reduced-rv|redundant|redundant-rv|file|file-rv}"
  exit 1
fi

setup_profiling
convert_to_absolute_paths
check_inputs
run_tests

if [[ ${TRACK_TIME} == "true" ]]; then
  echo ${DURATION} > ${PROJECT_DIR}/${PROJECT_NAME}/duration.txt
  echo "[TSM] Duration: ${DURATION}"
fi

exit ${STATUS_CODE}
