#!/bin/bash
#
# Run the entire pipeline
# Usage: run.sh -r <repo> [-s <sha>] [-a <tsm-algorithm>] [-e <equivalence>] [-x <skip-steps>] [-o <override-repo>] [-t <threads>] [-i <timeout>] [-b <baseline>] [-m <monitoring-only>] [-z <rv-stats>] <extension-directory> <mop-directory> <log-directory>
#
# Steps:
# 1. Collect tests
# 2. Collect traces
# 3. Generate matrix
# 4. Generate reduced test suites
# 5. Generate statistics table
#
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
ALGORITHM="greedy"
OVERRIDE_REPO=false
TOTAL_STEPS=5
PROJECT_DIR=${SCRIPT_DIR}/projects
PARALLEL=false
MONITORING_ONLY=false
BASELINE="javamop"
RV_STATS=true

source ${SCRIPT_DIR}/../experiments/constants.sh
source ${SCRIPT_DIR}/../experiments/utils.sh

cd $SCRIPT_DIR

PROFILE="false"
while getopts :r:s:a:e:x:o:t:i:p:j:b:m:z: opts; do
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
      m ) MONITORING_ONLY="${OPTARG}" ;;
      z ) RV_STATS="${OPTARG}" ;;
    esac
done
shift $((${OPTIND} - 1))
EXTENSION_DIR=$1
MOP_DIR=$2
LOG_DIR=$3
PROJECT_NAME=$(echo ${REPO} | tr / -)

# check_status_code will output a file into this directory
mkdir -p ${LOG_DIR}/${PROJECT_NAME}

check_status_code() {
  local error_code=$?
  if [[ ${error_code} -ne 0 ]]; then
    echo "Step $1 failed"
    echo "$1,${error_code}" > "${LOG_DIR}/${PROJECT_NAME}/tsm-result${FILE_SUFFIX}.txt"
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
  
  if [[ -n "${ALGORITHM}" && ${ALGORITHM} != "greedy" && ${ALGORITHM} != "ge" && ${ALGORITHM} != "gre" && ${ALGORITHM} != "hgs" && ${ALGORITHM} != "random" ]]; then
    echo "tsm-algorithm: greedy (default), ge, gre, hgs, or random"
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
  pushd ${SCRIPT_DIR}/../junit-listener/junit-test-listener &> /dev/null
  timeout 120s mvn install -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" &> /dev/null
  if [[ $? -ne 0 ]]; then
    echo "Unable to install test listener"
    exit 1
  fi
  popd &> /dev/null
  
  pushd ${SCRIPT_DIR}/../junit-listener/junit-measure-time &> /dev/null
  timeout 120s mvn install -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" &> /dev/null
  if [[ $? -ne 0 ]]; then
    echo "Unable to install measure test time listener"
    exit 1
  fi
  popd &> /dev/null
  
  pushd ${SCRIPT_DIR}/../rvtsm-maven-plugin &> /dev/null
  timeout 120s mvn test-compile -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" &> /dev/null
  if [[ $? -ne 0 ]]; then
    echo "Unable to compile maven plugin"
    exit 1
  fi
  popd &> /dev/null
}

collect_tests() {
  if [[ -z ${SKIP_STEP} || ${SKIP_STEP} -lt 1 ]]; then
    echo "[TSM] Step 1/${TOTAL_STEPS}: Collecting tests"
    
    if [[ ${OVERRIDE_REPO} != false ]]; then
      rm -rf "${PROJECT_DIR}/${PROJECT_NAME}"
    fi

    if [[ -n "${SHA}" ]]; then
      (time timeout ${TIMEOUT} bash collect_tests.sh -r ${REPO} -s ${SHA} ${EXTENSION_DIR}) &> ${LOG_DIR}/${PROJECT_NAME}/collect_tests.log
      check_status_code 1
    else
      (time timeout ${TIMEOUT} bash collect_tests.sh -r ${REPO} ${EXTENSION_DIR}) &> ${LOG_DIR}/${PROJECT_NAME}/collect_tests.log
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
  if [[ -z ${SKIP_STEP} || ${SKIP_STEP} -lt 3 ]]; then
    echo "[TSM] Step 3/${TOTAL_STEPS}: Generating tests/traces csv file"
    if [[ ${PARALLEL} == false ]]; then
      timeout ${TIMEOUT} python3 generate_matrix_together.py "${PROJECT_DIR}/${PROJECT_NAME}" "${PROJECT_DIR}/${PROJECT_NAME}/tests${FILE_SUFFIX}.csv" equality
    else
      timeout ${TIMEOUT} python3 generate_matrix.py "${PROJECT_DIR}/${PROJECT_NAME}" "${PROJECT_DIR}/${PROJECT_NAME}/tests${FILE_SUFFIX}.csv" equality
    fi
    check_status_code 3
  fi

  if [[ ${EQUIVALENCE} != "perfect" && ${EQUIVALENCE} != "equality" ]]; then
    # Use java to generate matrix
    pushd ${SCRIPT_DIR}/../rvtsm-maven-plugin &> /dev/null
    for eq in $(echo "${EQUIVALENCE}" | tr ',' '\n'); do
      if [[ ${eq} != "equality" && ${eq} != "perfect" ]]; then
        mvn test-compile -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" 
        mvn exec:java -Dmaven.repo.local="${PROJECT_DIR}/repo${REPO_SUFFIX}" -Dexec.mainClass="org.rvtsm.equivalence.Equivalence" -Dexec.args="${PROJECT_DIR}/${PROJECT_NAME}/tests${FILE_SUFFIX}.csv ${eq} ${PROJECT_DIR}/${PROJECT_NAME}/tests${FILE_SUFFIX}-${eq}.csv"
        check_status_code 3
      fi
    done
    popd &> /dev/null
  fi
}

test_suite_reduction() {
  if [[ -z ${SKIP_STEP} || ${SKIP_STEP} -lt 4 ]]; then
    echo "[TSM] Step 4/${TOTAL_STEPS}: Running test suite minimization"
    for eq in $(echo "${EQUIVALENCE}" | tr ',' '\n'); do
      local tests_csv="${PROJECT_DIR}/${PROJECT_NAME}/tests${FILE_SUFFIX}.csv"
      local tests_txt="${PROJECT_DIR}/${PROJECT_NAME}/tests.txt"
      local reduced_tests_txt="${PROJECT_DIR}/${PROJECT_NAME}/reduced_tests${FILE_SUFFIX}.txt"
      
      if [[ ${eq} != "equality" && ${eq} != "perfect" ]]; then
        tests_csv="${PROJECT_DIR}/${PROJECT_NAME}/tests${FILE_SUFFIX}-${eq}.csv"
        reduced_tests_txt="${PROJECT_DIR}/${PROJECT_NAME}/reduced_tests${FILE_SUFFIX}-${eq}.txt"
      fi
      
      timeout ${TIMEOUT} python3 reduce.py ${tests_csv} ${tests_txt} ${ALGORITHM} ${reduced_tests_txt} NONE
      check_status_code 4
    done
  fi
}

generate_statistics() {
  if [[ -z ${SKIP_STEP} || ${SKIP_STEP} -lt 5 ]]; then
    echo "[TSM] Step 5/${TOTAL_STEPS}: Collecting statistics"
    if [[ -d "${LOG_DIR}/${PROJECT_NAME}/stats${FILE_SUFFIX}" || -f "${LOG_DIR}/${PROJECT_NAME}/stats${FILE_SUFFIX}.csv" ]]; then
      echo "Skip - already have stats"
      return
    fi

    # Install stats agent
    install_agent ${PROJECT_DIR}/${PROJECT_NAME} "${PROJECT_DIR}/repo${REPO_SUFFIX}" ${MOP_DIR} "stats-agent"
    
    export JUNIT_MEASURE_TIME_LISTENER=1
    timeout ${TIMEOUT} bash stats.sh -j ${PROFILE} -b ${BASELINE} -m ${MONITORING_ONLY} -z ${RV_STATS} -e "${EQUIVALENCE}" ${PROJECT_DIR} ${REPO} ${EXTENSION_DIR} ${MOP_DIR} "${LOG_DIR}/${PROJECT_NAME}"
    check_status_code 5
  fi
}

run_pipeline() {
  check_inputs
  setup
  collect_tests
  collect_traces
  generate_matrix
  test_suite_reduction
  generate_statistics

  echo "0,0" > "${LOG_DIR}/${PROJECT_NAME}/tsm-result${FILE_SUFFIX}.txt"
}

echo "TSM version: ($(git rev-parse HEAD) - $(date +%s))"
run_pipeline
