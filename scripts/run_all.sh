#!/bin/bash
#
# A helper script to run pipeline on multiple projects
# Usage: run_all.sh [-i <timeout>] <log-directory> [threads] [equivalence] [skip-step] [parallel]
# The current directory should contain file "projects.txt"
#
# projects.txt format:
# project1,sha1
# project2,sha2
# ...
#
# Output run.sh's logs to scripts/run-logs directory
#

TRACES_TIMEOUT=20
while getopts :i: opts; do
  case "${opts}" in
    i ) TRACES_TIMEOUT="${OPTARG}" ;;
  esac
done
shift $((${OPTIND} - 1))

LOG_DIR=$1
THREADS=$2
EQUIVALENCE=$3
SKIP_STEP=$4
PARALLEL=${5:-false}
LABEL=$6
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
PROJECT_DIR=${SCRIPT_DIR}/projects

if [[ -z "${LOG_DIR}" ]]; then
  echo "Usage: ./run_all.sh <log-directory>"
  exit 1
fi

if [[ ! -f "projects.txt" ]]; then
  echo "The current directory should contain file projects.txt"
  exit 1
fi

mkdir -p ${SCRIPT_DIR}/run-logs

total=$(cat projects.txt | wc -l)
current=0

while read -r project; do
  space=$(df ${SCRIPT_DIR} | awk 'NR==2 { print $4 }')
  # 100 GiB = 107374182400 bytes = 104857600 (1024-bytes)
  if [[ ${space} -lt 104857600 ]]; then
    echo "No enough space $(space) (1024-bytes) left"
    exit 1
  fi
  
  ((current++))

  name=$(echo ${project} | cut -d "," -f 1)
  sha=$(echo ${project} | cut -d "," -f 2)

  project_name=$(echo ${name} | tr / -)

  echo "Running pipeline on ${name} (${current}/${total})"
  if [[ -n ${SKIP_STEP} ]]; then
    bash ${SCRIPT_DIR}/run.sh -i ${TRACES_TIMEOUT} -p ${PARALLEL} -r ${name} -s ${sha} -t ${THREADS:-6} -e ${EQUIVALENCE:-equality} -x ${SKIP_STEP} ${SCRIPT_DIR}/../extensions/ ${SCRIPT_DIR}/../mop/ ${LOG_DIR} &> ${SCRIPT_DIR}/run-logs/${project_name}.log
  else
    bash ${SCRIPT_DIR}/run.sh -i ${TRACES_TIMEOUT} -p ${PARALLEL} -r ${name} -s ${sha} -t ${THREADS:-6} -e ${EQUIVALENCE:-equality} ${SCRIPT_DIR}/../extensions/ ${SCRIPT_DIR}/../mop/ ${LOG_DIR} &> ${SCRIPT_DIR}/run-logs/${project_name}.log
  fi
  if [[ -n ${LABEL} ]]; then
    mv "${PROJECT_DIR}/${project_name}" "${PROJECT_DIR}/${project_name}-${LABEL}"
    mv "${LOG_DIR}/${project_name}" "${LOG_DIR}/${project_name}-${LABEL}"
  fi
  echo "Finished running pipeline on ${name} (${current}/${total})"
done < projects.txt
