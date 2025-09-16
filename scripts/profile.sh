#!/bin/bash
#
# Run project with profiler
# Usage: profile.sh <repo> <sha> <path-to-profiler> <output-dir> [test]
#
REPO=$1
SHA=$2
PROJECT_NAME=$(echo ${REPO} | tr / -)
PROFILER_PATH=$3
OUTPUT_DIR=$4
TEST_FILE=$5
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

source ${SCRIPT_DIR}/../experiments/constants.sh
source ${SCRIPT_DIR}/../experiments/utils.sh

function check_inputs() {
  if [[ -z ${OUTPUT_DIR} ]]; then
    echo "Usage: profile.sh <repo> <sha> <path-to-profiler> <output-dir> [test]"
    exit 1
  fi
  
  if [[ ! -f ${PROFILER_PATH} ]]; then
    echo "cannot find profiler"
    echo "Usage: profile.sh <repo> <sha> <path-to-profiler> <output-dir> [test]"
    exit 1
  fi
  
  if [[ -n ${TEST_FILE} && ! -s ${TEST_FILE} ]]; then
    echo "cannot find test file"
    echo "Usage: profile.sh <repo> <sha> <path-to-profiler> <output-dir> [test]"
    exit 1
  fi
  
  if [[ ! -f "${MAVEN_HOME}/lib/ext/profiler-extension-1.0.jar" ]]; then
    cp ${SCRIPT_DIR}/../extensions/profiler-extension-1.0.jar ${MAVEN_HOME}/lib/ext/profiler-extension-1.0.jar
  fi
}

function convert_to_absolute_paths() {
  if [[ ! ${PROFILER_PATH} =~ ^/.* ]]; then
    PROFILER_PATH=${SCRIPT_DIR}/${PROFILER_PATH}
  fi
  
  if [[ -n ${TEST_FILE} && ! ${TEST_FILE} =~ ^/.* ]]; then
    TEST_FILE=${SCRIPT_DIR}/${TEST_FILE}
  fi

  if [[ ! ${OUTPUT_DIR} =~ ^/.* ]]; then
    OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
  fi
  
  OUTPUT_DIR=${OUTPUT_DIR}/${PROJECT_NAME}
  mkdir -p ${OUTPUT_DIR}/logs
}

function clone() {
  pushd ${OUTPUT_DIR} &> /dev/null
  git clone https://github.com/${REPO} project &> ${OUTPUT_DIR}/logs/clone.log
  pushd project &> /dev/null
  git checkout ${SHA} &>> ${OUTPUT_DIR}/logs/clone.log
  # Handle PUTs
  # Change @Parameters(name...) to @Parameters, so default name is {index}
  grep -rl --include="*.java" "@Parameterized.Parameters" | xargs grep -l --include="*.java" "org.junit.runners.Parameterized" | xargs sed -i -e 's/@Parameterized\.Parameters\(.*\)/@Parameterized.Parameters/g'
  grep -rl --include="*.java" "@Parameters" | xargs grep -l --include="*.java" "org.junit.runners.Parameterized" | xargs sed -i -e 's/@Parameters\(.*\)/@Parameters/g'
  grep -rl --include="pom.xml" "forkCount" | xargs sed -i -e 's/<forkCount>.*<\/forkCount>/<forkCount>1<\/forkCount>/g'

  if [[ -f ${SCRIPT_DIR}/../experiments/treat_special.sh ]]; then
    # Run treat_special script
    bash ${SCRIPT_DIR}/../experiments/treat_special.sh ${OUTPUT_DIR}/project ${PROJECT_NAME}
  fi
  
  popd &> /dev/null
  popd &> /dev/null
}

function profile() {
  local repo=${OUTPUT_DIR}/repo
  local status=-1
  local test_suite=""
  export COLLECT_TRACES=1
  mkdir -p /tmp/tsm && chmod -R +w /tmp/tsm && rm -rf /tmp/tsm && mkdir -p /tmp/tsm
  
  pushd ${OUTPUT_DIR}/project &> /dev/null
  
  if [[ -n ${TEST_FILE} ]]; then
    test_suite=$(cat ${TEST_FILE} | sed -z '$ s/\n$//;s/\n/,/g') # Replace \n with ,
  fi
  
  echo "Installing agent..."
  install_agent ${OUTPUT_DIR}/project ${repo} ${SCRIPT_DIR}/../mop "no-track-agent" &> ${OUTPUT_DIR}/logs/setup.log
  
  echo "Compiling"
  (time timeout ${TIMEOUT} mvn -Dmaven.repo.local=${repo} -Djava.io.tmpdir=/tmp/tsm -Dmaven.ext.class.path="${SCRIPT_DIR}/../extensions/javamop-extension-1.0.jar" ${SKIP} test-compile) &> ${OUTPUT_DIR}/logs/compile.log
  status=$?
  
  if [[ ${status} -ne 0 ]]; then
    echo "Compile failed"
    exit 1
  fi

  echo "First run (download dependencies)"
  if [[ -n ${test_suite} ]]; then
    (time timeout ${TIMEOUT} mvn -Dmaven.repo.local=${repo} -Djava.io.tmpdir=/tmp/tsm -Dmaven.ext.class.path="${SCRIPT_DIR}/../extensions/javamop-extension-1.0.jar" -Dtest="${test_suite}" surefire:test) &> ${OUTPUT_DIR}/logs/test-run.log
    status=$?
  else
    (time timeout ${TIMEOUT} mvn -Dmaven.repo.local=${repo} -Djava.io.tmpdir=/tmp/tsm -Dmaven.ext.class.path="${SCRIPT_DIR}/../extensions/javamop-extension-1.0.jar" surefire:test) &> ${OUTPUT_DIR}/logs/test-run.log
    status=$?
  fi

  delete_violations
  
  if [[ ${status} -ne 0 ]]; then
    echo "First run failed"
    exit 1
  fi

  export PROFILER_PATH=${PROFILER_PATH}
  mkdir -p /tmp/tsm && chmod -R +w /tmp/tsm && rm -rf /tmp/tsm && mkdir -p /tmp/tsm

  echo "Second run (download dependencies)"
  if [[ -n ${test_suite} ]]; then
    (time timeout ${TIMEOUT} mvn -Dmaven.repo.local=${repo} -Djava.io.tmpdir=/tmp/tsm -Dmaven.ext.class.path="${SCRIPT_DIR}/../extensions/javamop-extension-1.0.jar" -Dtest="${test_suite}" surefire:test) &> ${OUTPUT_DIR}/logs/test-profile.log
    status=$?
  else
    (time timeout ${TIMEOUT} mvn -Dmaven.repo.local=${repo} -Djava.io.tmpdir=/tmp/tsm -Dmaven.ext.class.path="${SCRIPT_DIR}/../extensions/javamop-extension-1.0.jar" surefire:test) &> ${OUTPUT_DIR}/logs/test-profile.log
    status=$?
  fi

  move_violations ${OUTPUT_DIR} violation-counts

  if [[ -n $(find -name "profile.jfr") ]]; then
    move_jfr ${OUTPUT_DIR} profile.jfr
  else
    echo "Cannot find profile.jfr"
    exit 1
  fi

  if [[ ${status} -ne 0 ]]; then
    echo "Second run failed"
    exit 1
  fi

  echo "${PROJECT_NAME} OK!"
}

export RVMLOGGINGLEVEL=UNIQUE
check_inputs
convert_to_absolute_paths
clone
profile
