#!/bin/bash
#
# Create statistics table
# Usage: stats.sh <project-directory> <project-name> <extension-directory> <mop-directory> [output-directory]
#
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
source ${SCRIPT_DIR}/../experiments/utils.sh
source ${SCRIPT_DIR}/instrumentation/instrument_with_cache.sh
source ${SCRIPT_DIR}/instrumentation/instrument_with_imop.sh

PROFILE=false
MONITORING_ONLY=false
RV_STATS=true
EQUIVALENCE="equality"
while getopts :j:b:m:z:e: opts; do
  case "${opts}" in
    j ) PROFILE="${OPTARG}" ;;
    b ) BASELINE="${OPTARG}" ;;
    m ) MONITORING_ONLY="${OPTARG}" ;;
    z ) RV_STATS="${OPTARG}" ;;
    e ) EQUIVALENCE="${OPTARG}" ;;
  esac
done
shift $((${OPTIND} - 1))

if [[ ${MONITORING_ONLY} == "true" && ${PROFILE} == "true" ]]; then
  PROFILE="false"
  echo "-m (MONITORING_ONLY) option cannot set to true if -j (PROFILE) is also true."
fi

PROJECT_DIR=$1
PROJECT_NAME=$(echo $2 | tr / -)
EXTENSION_DIR=$3
MOP_DIR=$4
OUTPUT_DIR=$5
PROJECT_PATH="${PROJECT_DIR}/${PROJECT_NAME}"
START=-1

if [[ ${BASELINE} != "tracemop" ]]; then
  BASELINE="javamop"
fi

init_variables() {
  local eq=$1
  # original, reduced, redudant, no_trace
  TESTS_TYPE=("all" "reduced" "redundant" "no_trace")
  TESTS_SIZE=(0 0 0 0)
  E2E_TIME=(0 0 0 0)
  E2E_RV_TIME=(0 0 0 0)
  TESTS_TIME=(0 0 0 0)
  TESTS_RV_TIME=(0 0 0 0)
  MAVEN_TIME=(0 0 0 0)
  MAVEN_RV_TIME=(0 0 0 0)
  STATIC_VIOLATION=(0 0 0 0)
  DYNAMIC_VIOLATION=(0 0 0 0)
  EVENTS_COUNT=(0 0 0 0)
  MONITORS_COUNT=(0 0 0 0)
  MONITORING_SAMPLE_COUNT=(0 0 0 0)
  INSTRUMENTATION_SAMPLE_COUNT=(0 0 0 0)
  
  TEST_STATUS=(-1 -1 -1 -1)
  RV_STATUS=(-1 -1 -1 -1)
  STATS_STATUS=(-1 -1 -1 -1)
  
  if [[ ${eq} == "equality" || ${eq} == "perfect" ]]; then
    export FILE_SUFFIX=""
  else
    export FILE_SUFFIX="-${eq}"
  fi
  
  LOG_DIR=${OUTPUT_DIR}/stats${FILE_SUFFIX}
  
  mkdir -p ${LOG_DIR}
  mkdir -p ${LOG_DIR}/violations
  
  if [[ ${START} == -1 ]]; then
    START=0 # first time, so we will run all, reduced, redundant, and no_trace
  else
    START=1 # skip 'all', only run reduced, redundant, and no_trace
  fi
}

check_inputs() {
  if [[ -z "${OUTPUT_DIR}" ]]; then
    echo "Usage: ./stats.sh <project-directory> <project-name> <extension-directory> <mop-directory> [output-directory]"
    exit 1
  fi
  
  if [[ ! ${OUTPUT_DIR} =~ ^/.*  ]]; then
    OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
  fi
}

find_redundant_tests_and_no_trace() {
  if [[ ! -f "${PROJECT_PATH}/tests.txt" || ! -f "${PROJECT_PATH}/reduced_tests${FILE_SUFFIX}.txt" ]]; then
    echo "Cannot find tests.txt and/or reduced_tests${FILE_SUFFIX}.txt"
    exit 1;
  fi
  
  echo "Creating redundant_tests${FILE_SUFFIX}.txt and no_trace_tests${FILE_SUFFIX}.txt"
  
  local redundant_or_no_trace_tests=$(comm <(sort ${PROJECT_PATH}/tests.txt) <(sort ${PROJECT_PATH}/reduced_tests${FILE_SUFFIX}.txt) -23)
  local redundant_tests=()
  local no_trace_tests=()
  
  while read -r test_name; do
    # If it contains either of these files, it is a sequential run
    if [ -f "${PROJECT_PATH}/.all-traces/unique-traces.txt" ] || [ -f "${PROJECT_PATH}/.all-traces/unique-traces.txt.gz" ]; then
      if ! grep -q "^${test_name}," "${PROJECT_PATH}/tests.csv"; then
        no_trace_tests+=("${test_name}")
      else
        redundant_tests+=("${test_name}")
      fi
    else # Otherwise, it is a parallel run
      local unique_traces_file="${PROJECT_PATH}/.all-traces/${test_name}/unique-traces.txt"
      local unique_traces_file_compressed="${PROJECT_PATH}/.all-traces/${test_name}/unique-traces.txt.gz"

      if [[ ! -s "${unique_traces_file}" && ! -s "${unique_traces_file_compressed}" ]]; then
        no_trace_tests+=("${test_name}")
      else
        redundant_tests+=("${test_name}")
      fi
    fi
  done <<< ${redundant_or_no_trace_tests}
  
  printf "%s\n" "${redundant_tests[@]}" > "${PROJECT_PATH}/redundant_tests${FILE_SUFFIX}.txt"
  printf "%s\n" "${no_trace_tests[@]}" > "${PROJECT_PATH}/no_trace_tests${FILE_SUFFIX}.txt"
  printf "%s\n" "${redundant_tests[@]}" > "${PROJECT_PATH}/redundant_and_no_trace_tests${FILE_SUFFIX}.txt"
  printf "%s\n" "${no_trace_tests[@]}" >> "${PROJECT_PATH}/redundant_and_no_trace_tests${FILE_SUFFIX}.txt"
}

calculate_tests_size() {
  if [[ ! -f "${PROJECT_PATH}/redundant_tests${FILE_SUFFIX}.txt" || ! -f "${PROJECT_PATH}/no_trace_tests${FILE_SUFFIX}.txt" ]]; then
    echo "Cannot find redundant_tests${FILE_SUFFIX}.txt and/or no_trace_tests${FILE_SUFFIX}.txt file"
    exit 1
  fi
  
  echo "Calculating tests size"
  
  local tests_filename=("tests.txt" "reduced_tests${FILE_SUFFIX}.txt" "redundant_tests${FILE_SUFFIX}.txt" "no_trace_tests${FILE_SUFFIX}.txt")
  for i in $(seq ${START} 3); do
    TESTS_SIZE[$i]=$(grep -cv ^$ < "${PROJECT_PATH}/${tests_filename[$i]}")
  done
}

instrument() {
  echo "Pre-instrumenting code..."
  instrument_with_imop
}

run_tests() {
  local no_trace_file="${PROJECT_PATH}/no_trace_tests${FILE_SUFFIX}.txt"
  
  local options=("all" "reduced" "redundant" "file")
  export INSTALL_AGENT=false
  for i in $(seq ${START} 3); do
    ### Without stats ###
    
    install_agent ${PROJECT_DIR}/${PROJECT_NAME} "${PROJECT_DIR}/repo${REPO_SUFFIX}" ${MOP_DIR} "no-track-agent"
    
    echo "Running ${TESTS_TYPE[$i]} tests"
    bash ${SCRIPT_DIR}/run_tests.sh -j ${PROFILE} ${PROJECT_DIR} ${PROJECT_NAME} ${EXTENSION_DIR}/javamop-extension-1.0.jar ${MOP_DIR} ${options[$i]} true "${no_trace_file}" &> ${LOG_DIR}/${TESTS_TYPE[$i]}.log
    TEST_STATUS[$i]=$?
    E2E_TIME[$i]=$(cat "${PROJECT_PATH}/duration.txt")
    
    ### Track if we want TraceMOP ###
    local track=false
    if [[ ${BASELINE} == "tracemop" ]]; then  # For now, we will run tracemop for all ($i -ne 0 &&)
      track=true
      install_agent ${PROJECT_DIR}/${PROJECT_NAME} "${PROJECT_DIR}/repo" ${MOP_DIR} "track-agent"
      export TRACEDB_PATH="${PROJECT_DIR}/${PROJECT_NAME}/.traces-${TESTS_TYPE[$i]}"
      export TRACEDB_CONFIG_PATH="${SCRIPT_DIR}/.trace-db.config"
      export COLLECT_MONITORS=1
      export COLLECT_TRACES=1
    fi
  
    local extension_jar="${EXTENSION_DIR}/javamop-extension-1.0.jar"
    if [[ ${MONITORING_ONLY} == "true" ]]; then
      instrument_with_imop_use
      extension_jar="${SCRIPT_DIR}/../../imop/extensions/iemop-maven-extension/target/iemop-maven-extension-1.0.jar"
    fi
    echo "Running ${TESTS_TYPE[$i]} tests with RV (timed) (track: ${track})"
    bash ${SCRIPT_DIR}/run_tests.sh -j ${PROFILE} ${PROJECT_DIR} ${PROJECT_NAME} ${extension_jar} ${MOP_DIR} ${options[$i]}-rv true "${no_trace_file}" &> ${LOG_DIR}/${TESTS_TYPE[$i]}-rv.log
    RV_STATUS[$i]=$?
    E2E_RV_TIME[$i]=$(cat "${PROJECT_PATH}/duration.txt")
    cp ${PROJECT_PATH}/violation-counts ${LOG_DIR}/violations/${TESTS_TYPE[$i]}.txt &> /dev/null
    
    if [[ ${BASELINE} == "tracemop" ]]; then
      unset TRACEDB_PATH
      unset TRACEDB_CONFIG_PATH
      unset COLLECT_MONITORS
      unset COLLECT_TRACES
    fi
    
    if [[ ${MONITORING_ONLY} == "true" ]]; then
      instrument_with_imop_reset
    fi
    
    ### Stats ###
    
    if [[ ${RV_STATS} == "true" ]]; then
      install_agent ${PROJECT_DIR}/${PROJECT_NAME} "${PROJECT_DIR}/repo${REPO_SUFFIX}" ${MOP_DIR} "stats-agent"
      
      echo "Running ${TESTS_TYPE[$i]} tests with RV (stats)"
      bash ${SCRIPT_DIR}/run_tests.sh -j ${PROFILE} ${PROJECT_DIR} ${PROJECT_NAME} ${EXTENSION_DIR}/javamop-extension-1.0.jar ${MOP_DIR} ${options[$i]}-rv true "${no_trace_file}" &> ${LOG_DIR}/${TESTS_TYPE[$i]}-stats.log
      STATS_STATUS[$i]=$?
      rm -rf ${PROJECT_PATH}/violation-counts
    fi
  done
  export INSTALL_AGENT=true
}

calculate_tests_time() {
  echo "Calculating tests time"
  for i in $(seq ${START} 3); do
    TESTS_TIME[$i]=$(grep --text "^\[TSM\] JUnit Total Time:" ${LOG_DIR}/${TESTS_TYPE[$i]}.log | cut -d' ' -f5 | paste -sd+ | bc -l)
    TESTS_RV_TIME[$i]=$(grep --text "^\[TSM\] JUnit Total Time:" ${LOG_DIR}/${TESTS_TYPE[$i]}-rv.log | cut -d' ' -f5 | paste -sd+ | bc -l)
    
    TESTS_TIME[$i]=${TESTS_TIME[$i]:-0}
    TESTS_RV_TIME[$i]=${TESTS_RV_TIME[$i]:-0}

    MAVEN_TIME[$i]=$(( ${E2E_TIME[$i]} - ${TESTS_TIME[$i]} ))
    MAVEN_RV_TIME[$i]=$(( ${E2E_RV_TIME[$i]} - ${TESTS_RV_TIME[$i]} ))
  done
}

count_violations() {
  for i in $(seq ${START} 3); do
    local violation_counts_file="${LOG_DIR}/violations/${TESTS_TYPE[$i]}.txt"
    if [[ -f ${violation_counts_file} ]]; then
      STATIC_VIOLATION[$i]=$(wc -l < ${violation_counts_file})
      DYNAMIC_VIOLATION[$i]=$(cut -d' ' -f 1 ${violation_counts_file} | paste -sd+ | bc -l)
    fi
  done
}

count_events_and_monitors() {
  for i in $(seq ${START} 3); do
    EVENTS_COUNT[$i]=$(grep --text "#event -" ${LOG_DIR}/${TESTS_TYPE[$i]}-stats.log | cut -d: -f2 | paste -sd+ | bc -l)
    MONITORS_COUNT[$i]=$(grep --text "#monitors:" ${LOG_DIR}/${TESTS_TYPE[$i]}-stats.log | cut -d: -f2 | paste -sd+ | bc -l)
    
    EVENTS_COUNT[$i]=${EVENTS_COUNT[$i]:-0}
    MONITORS_COUNT[$i]=${MONITORS_COUNT[$i]:-0}
  done
}

count_monitoring_and_instrumentation_samples() {
  local monitoring_columns=("RVMONITOR" "MONITORING" "SPECIFICATION" "RVMONITOR_LOCK" "MONITORING_LOCK")
  local instrumentation_columns=("ASPECTJ" "ASPECTJ_INSTRUMENTATION" "ASPECTJ_RUNTIME" "ASPECTJ_OTHER")
  for i in $(seq ${START} 3); do
    local mcount=0
    for column in "${monitoring_columns[@]}"; do
      if [ -f "${PROJECT_PATH}/${TESTS_TYPE[$i]}-rv-output.csv" ]; then
        mcount=$(($mcount + $(bash ${SCRIPT_DIR}/get_cell.sh -f ${PROJECT_PATH}/${TESTS_TYPE[$i]}-rv-output.csv -c "${column}" -r 2 -m "mixed")))
      fi
    done
    MONITORING_SAMPLE_COUNT[$i]="${mcount}"
    local icount=0
    for column in "${instrumentation_columns[@]}"; do
      if [ -f "${PROJECT_PATH}/${TESTS_TYPE[$i]}-rv-output.csv" ]; then
        icount=$(($icount + $(bash ${SCRIPT_DIR}/get_cell.sh -f ${PROJECT_PATH}/${TESTS_TYPE[$i]}-rv-output.csv -c "${column}" -r 2 -m "mixed")))
      fi
    done
    INSTRUMENTATION_SAMPLE_COUNT[$i]="${icount}"
    
    MONITORING_SAMPLE_COUNT[$i]=${MONITORING_SAMPLE_COUNT[$i]:-0}
    INSTRUMENTATION_SAMPLE_COUNT[$i]=${INSTRUMENTATION_SAMPLE_COUNT[$i]:-0}
  done
}

generate_spcs_csv() {
  for i in $(seq ${START} 2); do   # START to 2 only, we don't need to find specs for no_trace test
    python3 ${SCRIPT_DIR}/find_specs_info.py ${LOG_DIR}/${TESTS_TYPE[$i]}-stats.log ${LOG_DIR}/${TESTS_TYPE[$i]}-rv-spcs.csv
  done
}

generate_stats_csv() {
  echo "tests set,# of tests,dynamic violations,events,monitors,static violations,MOP test,MOP e2e,MOP mvn,NoMOP test,NoMOP e2e,NoMOP mvn,monitoring samples,instrumentation samples,test status,mop status,stats status" > ${OUTPUT_DIR}/stats${FILE_SUFFIX}.csv

  for i in {0..3}; do  # we start from 0 instead of START
    local tests_rv=$(echo "scale=3; ${TESTS_RV_TIME[$i]} / 1000" | bc)
    local e2e_rv=$(echo "scale=3; ${E2E_RV_TIME[$i]} / 1000" | bc)
    local mvn_rv=$(echo "scale=3; ${MAVEN_RV_TIME[$i]} / 1000" | bc)
    local tests=$(echo "scale=3; ${TESTS_TIME[$i]} / 1000" | bc)
    local e2e=$(echo "scale=3; ${E2E_TIME[$i]} / 1000" | bc)
    local mvn=$(echo "scale=3; ${MAVEN_TIME[$i]} / 1000" | bc)
    echo "${TESTS_TYPE[$i]},${TESTS_SIZE[$i]},${DYNAMIC_VIOLATION[$i]},${EVENTS_COUNT[$i]},${MONITORS_COUNT[$i]},${STATIC_VIOLATION[$i]},${tests_rv},${e2e_rv},${mvn_rv},${tests},${e2e},${mvn},${MONITORING_SAMPLE_COUNT[$i]},${INSTRUMENTATION_SAMPLE_COUNT[$i]},${TEST_STATUS[$i]},${RV_STATUS[$i]},${STATS_STATUS[$i]}" >> ${OUTPUT_DIR}/stats${FILE_SUFFIX}.csv
  done
}

check_inputs

for eq in $(echo "${EQUIVALENCE}" | tr ',' '\n'); do
  init_variables ${eq}
  find_redundant_tests_and_no_trace
  calculate_tests_size
  if [[ ${MONITORING_ONLY} == "true" ]]; then
    instrument
  fi
  run_tests
  calculate_tests_time
  count_violations
  if [[ ${RV_STATS} == "true" ]]; then
    count_events_and_monitors
  fi
  if [[ ${PROFILE} == "true" ]]; then
    count_monitoring_and_instrumentation_samples
  fi
  if [[ ${RV_STATS} == "true" ]]; then
    generate_spcs_csv
  fi
  generate_stats_csv
done
echo "Log directory: ${LOG_DIR}"
