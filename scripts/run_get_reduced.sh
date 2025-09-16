#!/bin/bash
#
# Run collect test, collect traces, get reduced, 
# Usage: run_get_reduced.sh -r <repo> [-s <sha>] [-a <tsm-algorithm>] [-e <equivalence>] [-x <skip-steps>] [-o <override-repo>] [-t <threads>] [-i <timeout>] [-b <baseline>] [-m <monitoring-only>] [-z <rv-stats>] <extension-directory> <mop-directory> <log-directory>
#
# Steps:
# 1. Collect tests
# 2. Collect traces
# 3. Generate matrix
# 4. Generate reduced test suites
#
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
ALGORITHM="greedy"
OVERRIDE_REPO=false
TOTAL_STEPS=5
PARALLEL=false
MMMP=false
BASELINE="javamop"
RV_STATS=true
DISABLE_PUT=false
PROJECT_DIR=${SCRIPT_DIR}/projects
mkdir -p ${PROJECT_DIR}

source ${SCRIPT_DIR}/../experiments/constants.sh
source ${SCRIPT_DIR}/../experiments/utils.sh

cd $SCRIPT_DIR

PROFILE="false"
while getopts :r:s:a:e:x:o:t:i:p:j:b:m:z:u: opts; do
    case "${opts}" in
      r ) REPO="${OPTARG}" ;;
      s ) SHA="${OPTARG}" ;;
      a ) ALGORITHM="${OPTARG}" ;;
      e ) EQUIVALENCE="${OPTARG}" ;;
      x ) SKIP_STEP="${OPTARG}" ;;
      o ) OVERRIDE_REPO="${OPTARG}" ;;
      t ) THREADS="${OPTARG}" ;;
      i ) TRACES_TIMEOUT="${OPTARG}" ;;
      p ) PARALLEL="${OPTARG}" ;;
      j ) PROFILE="${OPTARG}" ;;
      b ) BASELINE="${OPTARG}" ;;
      m ) MMMP="${OPTARG}" ;;
      z ) RV_STATS="${OPTARG}" ;;
      u ) DISABLE_PUT="${OPTARG}" ;;
    esac
done
shift $((${OPTIND} - 1))
EXTENSION_DIR=$1
MOP_DIR=$2
LOG_DIR=$3
PROJECT_NAME=$(echo ${REPO} | tr / -)
export IS_MMMP=${MMMP}

# check_status_code will output a file into this directory
mkdir -p ${LOG_DIR}/${PROJECT_NAME}

check_status_code() {
  local error_code=$?
  if [[ ${error_code} -ne 0 ]]; then
    echo "Step $1 failed"
    echo "$1,${error_code}" > "${LOG_DIR}/${PROJECT_NAME}/tsm-result${FILE_SUFFIX}.txt"
    
    echo "Repo:"
    ls -lia ${PROJECT_DIR}/repo${REPO_SUFFIX}
    echo "PWD:"
    pwd
    echo "CWD:"
    ls -lia

    exit 1
  fi
}

check_inputs() {
  if [[ -z "${REPO}" || -z "${EXTENSION_DIR}" || -z "${MOP_DIR}" || -z "${LOG_DIR}" ]]; then
    echo "Usage: ./run.sh -r <repo> [-s <sha>] [-a <tsm-algorithm>] [-e <equivalence>] [-x <skip-steps>] [-o <override-repo>] [-t <threads>] [-i <timeout>] <extension-directory> <mop-directory> <log-directory>"
    echo "tsm-algorithm: greedy (default), ge, gre, hgs, or random"
    echo "equivalence: equality (default), remove_duplicated_events, remove_duplicated_phrases, or remove_duplicated_events_phrases"
    echo "skip-steps: skip the first <skip-steps> steps"
    echo "override-repo: true (default) - don't clone repo again, or false - reset repo"
    exit 1
  fi

  for eqs in $(echo "${EQUIVALENCE}" | tr ',' '\n'); do
    for eq in $(echo "${eqs}" | tr '-' '\n'); do
      if [[ ${eq} != "equality" && ${eq} != "perfect" && ${eq} != "state" && ${eq} != "prefix" && ${eq} != "detour" && ${eq} != "online_detour" ]]; then
        echo "equivalence: unknown option: ${eq} (in ${eqs})"
        exit 1
      fi
    done
  done
  
  if [[ -d ${PROJECT_DIR}/${PROJECT_NAME}/.all-traces && ${SKIP_STEP} != "0" && ${SKIP_STEP} != "2" && ${SKIP_STEP} != "3" && ${SKIP_STEP} != "4" && ${SKIP_STEP} != "5" ]]; then
    echo "Project already has .all-traces, use -x 0 to override"
    exit 1
  fi
  
  # NOT USED
  export FILE_SUFFIX=""
# if [[ -n "${EQUIVALENCE}" && ${EQUIVALENCE} == "remove_duplicated_events" ]]; then
#   export FILE_SUFFIX="-dup_events"
# elif [[ -n "${EQUIVALENCE}" && ${EQUIVALENCE} == "remove_duplicated_phrases" ]]; then
#   export FILE_SUFFIX="-dup_phrases"
# elif [[ -n "${EQUIVALENCE}" && ${EQUIVALENCE} == "remove_duplicated_events_phrases" ]]; then
#   export FILE_SUFFIX="-dup_events_phrases"
# fi
  
  if [[ ! ${MOP_DIR} =~ ^/.* ]]; then
    MOP_DIR=${SCRIPT_DIR}/${MOP_DIR}
  fi
}

setup() {
  mkdir -p ${TMP_DIR}/junit-test-listener/
  rm -rf ${TMP_DIR}/junit-test-listener/${PROJECT_NAME}
  cp -r ${SCRIPT_DIR}/../junit-listener/junit-test-listener ${TMP_DIR}/junit-test-listener/${PROJECT_NAME}
  pushd ${TMP_DIR}/junit-test-listener/${PROJECT_NAME}
  timeout 600s mvn install -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" &> ${LOG_DIR}/${PROJECT_NAME}/install_test_listener.log
  if [[ $? -ne 0 ]]; then
    rm -rf ${TMP_DIR}/junit-test-listener/${PROJECT_NAME}
    echo "Unable to install test listener"
    exit 1
  fi
  popd
  rm -rf ${TMP_DIR}/junit-test-listener/${PROJECT_NAME}
  
  mkdir -p ${TMP_DIR}/junit-measure-time/
  rm -rf ${TMP_DIR}/junit-measure-time/${PROJECT_NAME}
  cp -r ${SCRIPT_DIR}/../junit-listener/junit-measure-time ${TMP_DIR}/junit-measure-time/${PROJECT_NAME}
  pushd ${TMP_DIR}/junit-measure-time/${PROJECT_NAME}
  timeout 600s mvn install -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" &> ${LOG_DIR}/${PROJECT_NAME}/install_time_listener.log
  if [[ $? -ne 0 ]]; then
    rm -rf ${TMP_DIR}/junit-measure-time/${PROJECT_NAME}
    echo "Unable to install measure test time listener"
    exit 1
  fi
  popd
  rm -rf ${TMP_DIR}/junit-measure-time/${PROJECT_NAME}
  
  mkdir -p ${TMP_DIR}/rvtsm-maven-plugin/
  rm -rf ${TMP_DIR}/rvtsm-maven-plugin/${PROJECT_NAME}
  cp -r ${SCRIPT_DIR}/../rvtsm-maven-plugin ${TMP_DIR}/rvtsm-maven-plugin/${PROJECT_NAME}
  pushd ${TMP_DIR}/rvtsm-maven-plugin/${PROJECT_NAME}
  timeout 600s mvn test-compile -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" &> ${LOG_DIR}/${PROJECT_NAME}/install_plugin.log
  if [[ $? -ne 0 ]]; then
    echo "Unable to compile maven plugin"
    exit 1
  fi
  popd
}

collect_tests() {
  if [[ -z ${SKIP_STEP} || ${SKIP_STEP} -lt 1 ]]; then
    echo "[TSM] Step 1/${TOTAL_STEPS}: Collecting tests"
    
    if [[ ${OVERRIDE_REPO} != false ]]; then
      rm -rf "${PROJECT_DIR}/${PROJECT_NAME}"
    fi

    if [[ -n "${SHA}" ]]; then
      (time timeout ${TIMEOUT} bash collect_tests.sh -r ${REPO} -s ${SHA} -u ${DISABLE_PUT} ${EXTENSION_DIR}) &> ${LOG_DIR}/${PROJECT_NAME}/collect_tests.log
      check_status_code 1
    else
      (time timeout ${TIMEOUT} bash collect_tests.sh -r ${REPO} -u ${DISABLE_PUT} ${EXTENSION_DIR}) &> ${LOG_DIR}/${PROJECT_NAME}/collect_tests.log
      check_status_code 1
    fi
  fi
}

collect_traces() {
  if [[ -z ${SKIP_STEP} || ${SKIP_STEP} -lt 2 ]]; then
    echo "[TSM] Step 2/${TOTAL_STEPS}: Collecting traces"
    if [[ -d "${PROJECT_DIR}/${PROJECT_NAME}/.all-traces" ]]; then
      echo "Skip - already have traces"
      return
    fi

    if [[ ${PARALLEL} == false ]]; then
      bash collect_traces_together.sh "${SCRIPT_DIR}/projects" ${REPO} ${EXTENSION_DIR} ${MOP_DIR} ${LOG_DIR} ${THREADS} ${TRACES_TIMEOUT}
    else
      bash collect_traces.sh "${SCRIPT_DIR}/projects" ${REPO} ${EXTENSION_DIR} ${MOP_DIR} ${LOG_DIR} ${THREADS} ${TRACES_TIMEOUT}
    fi
    check_status_code 2
  fi
}

generate_matrix() {
  mkdir -p ${PROJECT_DIR}/${PROJECT_NAME}/tsm-matrix
  mkdir -p ${PROJECT_DIR}/${PROJECT_NAME}/tsm-suite/reduced
  mkdir -p ${PROJECT_DIR}/${PROJECT_NAME}/tsm-suite/redundant
  if [[ -z ${SKIP_STEP} || ${SKIP_STEP} -lt 3 ]]; then
    echo "[TSM] Step 3/${TOTAL_STEPS}: Generating tests/traces csv file"
    if [[ ${PARALLEL} == false ]]; then
      timeout ${TIMEOUT} python3 generate_matrix_together.py "${PROJECT_DIR}/${PROJECT_NAME}" "${PROJECT_DIR}/${PROJECT_NAME}/tsm-matrix/tests${FILE_SUFFIX}-perfect.csv"
    else
      timeout ${TIMEOUT} python3 generate_matrix.py "${PROJECT_DIR}/${PROJECT_NAME}" "${PROJECT_DIR}/${PROJECT_NAME}/tsm-matrix/tests${FILE_SUFFIX}-perfect.csv"
    fi
    check_status_code 3
  fi

  # Create matrix for different notion of equivalence
  if [[ ${EQUIVALENCE} != "perfect" && ${EQUIVALENCE} != "equality" ]]; then
    # Use java to generate matrix
    pushd ${TMP_DIR}/rvtsm-maven-plugin/${PROJECT_NAME}

    mvn test-compile install -DskipTests -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}"
    check_status_code "3.1"
    for eq in $(echo "${EQUIVALENCE}" | tr ',' '\n'); do
      if [[ ${eq} != "equality" && ${eq} != "perfect" ]]; then
        mvn exec:java -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" -Dexec.mainClass="org.rvtsm.equivalence.Equivalence" -Dexec.args="${PROJECT_DIR}/${PROJECT_NAME}/tsm-matrix/tests${FILE_SUFFIX}-perfect.csv ${eq} ${PROJECT_DIR}/${PROJECT_NAME}/tsm-matrix/tests${FILE_SUFFIX}-${eq}.csv" &> ${LOG_DIR}/${PROJECT_NAME}/creating-${eq}.log
        check_status_code "3.2"
      fi
    done
    popd
  fi
}


find_redundant() {
  local original_tests_file=$1
  local reduced_tests_file=$2
  local output_file=$3

  comm <(sort ${original_tests_file}) <(sort ${reduced_tests_file}) -23 > ${output_file}
}


test_suite_reduction() {
  if [[ -z ${SKIP_STEP} || ${SKIP_STEP} -lt 4 ]]; then
    echo "[TSM] Step 4/${TOTAL_STEPS}: Running test suite minimization"
    
    # Create tiebreaker file
    if [[ ${IS_MMMP} != "true" ]]; then
      pushd ${PROJECT_DIR}/${PROJECT_NAME}
      echo "Creating tiebreaker file"
      mvn -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:reduce -DartifactDir=.rvtsm -Dtiebreaker=time -Dimplementation=none -DsurefireReportsForTiebreak=${PROJECT_DIR}/${PROJECT_NAME}/initial-surefire-reports -DskipAllPreviousSteps=true -DtestMethodList=${PROJECT_DIR}/${PROJECT_NAME}/tests${FILE_SUFFIX}.txt -DdisablePUT=${DISABLE_PUT} &> ${LOG_DIR}/${PROJECT_NAME}/creating-tiebreaker.log
      check_status_code "4.1"
      popd
    fi

    local tests_txt="${PROJECT_DIR}/${PROJECT_NAME}/tests.txt"
    # Create reduced test suite for all equivalence, TSM algorithm, and none/time tiebreaker
    for eq in $(echo "${EQUIVALENCE}" | tr ',' '\n'); do
      for algo in $(echo "${ALGORITHM}" | tr ',' '\n'); do
        tests_csv="${PROJECT_DIR}/${PROJECT_NAME}/tsm-matrix/tests${FILE_SUFFIX}-${eq}.csv"
        
        echo "[reduce_suite] Running config ${eq}-${algo}-none"
        reduced_tests_txt="${PROJECT_DIR}/${PROJECT_NAME}/tsm-suite/reduced/reduced_tests${FILE_SUFFIX}-${eq}-${algo}-none.txt"
        redundant_tests_txt="${PROJECT_DIR}/${PROJECT_NAME}/tsm-suite/redundant/redundant_tests${FILE_SUFFIX}-${eq}-${algo}-none.txt"
        timeout ${TIMEOUT} python3 reduce.py ${tests_csv} ${tests_txt} ${algo} ${reduced_tests_txt} NONE
        check_status_code "4.2"
        find_redundant ${tests_txt} ${reduced_tests_txt} ${redundant_tests_txt}
        
        if [[ ${IS_MMMP} != "true" ]]; then
          echo "[reduce_suite] Running config ${eq}-${algo}-time"
          reduced_tests_txt="${PROJECT_DIR}/${PROJECT_NAME}/tsm-suite/reduced/reduced_tests${FILE_SUFFIX}-${eq}-${algo}-time.txt"
          redundant_tests_txt="${PROJECT_DIR}/${PROJECT_NAME}/tsm-suite/redundant/redundant_tests${FILE_SUFFIX}-${eq}-${algo}-time.txt"
          timeout ${TIMEOUT} python3 reduce.py ${tests_csv} ${tests_txt} ${algo} ${reduced_tests_txt} ${PROJECT_DIR}/${PROJECT_NAME}/.rvtsm/time-tiebreaker.csv
          check_status_code "4.3"
          find_redundant ${tests_txt} ${reduced_tests_txt} ${redundant_tests_txt}
        fi
      done
    done
    
    mv ${tests_txt} ${PROJECT_DIR}/${PROJECT_NAME}/tsm-suite/
  fi
}

run_pipeline() {
  check_inputs
  setup
  collect_tests
  collect_traces
  generate_matrix
  test_suite_reduction
  
  echo "[TSM] OK!"

  echo "0,0" > "${LOG_DIR}/${PROJECT_NAME}/tsm-result${FILE_SUFFIX}.txt"
}

echo "TSM version: ($(git rev-parse HEAD) - $(date +%s))"
run_pipeline
