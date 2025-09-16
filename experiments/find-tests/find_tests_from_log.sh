#!/bin/bash
#
# Usage: find_tests_from_log.sh <project-dir> <project>
#
PROJECT_DIR=$1
PROJECT=$2
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

function check_inputs() {
  if [[ ! -d "${PROJECT_DIR}" ]]; then
    echo "cannot find project directory"
    exit 1
  fi
  
  if [[ -z "${PROJECT}" ]]; then
    echo "Usage: find_tests_from_log.sh <project-dir> <project>"
    exit 1
  fi
}

function find_tests() {
  if [[ ${IS_MMMP} == "false" ]]; then
    if [[ ! -d "${PROJECT_DIR}/target/surefire-reports/" ]]; then
      echo "${PROJECT},no found"
      exit 1
    fi
  
    while read -r test_suite; do
      if [[ -n ${test_suite} ]]; then
        python3 ${SCRIPT_DIR}/get_junit_testcases.py ${test_suite} >> ${PROJECT_DIR}/tests.txt
      fi
    done <<< "$(ls ${PROJECT_DIR}/target/surefire-reports/TEST-* 2>/dev/null)"
    
    if [[ -f "${PROJECT_DIR}/target/surefire-reports/testng-results.xml" ]]; then
      python3 ${SCRIPT_DIR}/get_testng_testcases.py "${PROJECT_DIR}/target/surefire-reports/testng-results.xml" >> ${PROJECT_DIR}/tests.txt
    fi
  
    if [[ -f ${PROJECT_DIR}/tests.txt ]]; then
      cat ${PROJECT_DIR}/tests.txt | sort | uniq > tmp.txt && mv tmp.txt ${PROJECT_DIR}/tests.txt
    fi
  else
    for report in $(find ${PROJECT_DIR} -name surefire-reports); do
      module=$(echo ${report} | rev | cut -d '/' -f 3 | rev)
      export MMMP_MODULE=${module}
      
      while read -r test_suite; do
        if [[ -n ${test_suite} ]]; then
          python3 ${SCRIPT_DIR}/get_junit_testcases.py ${test_suite} >> ${PROJECT_DIR}/tests.txt
        fi
      done <<< "$(ls ${report}/TEST-* 2>/dev/null)"
      
      if [[ -f "${report}/testng-results.xml" ]]; then
        python3 ${SCRIPT_DIR}/get_testng_testcases.py "${report}/testng-results.xml" >> ${PROJECT_DIR}/tests.txt
      fi
      
      if [[ -f ${PROJECT_DIR}/tests.txt ]]; then
        cat ${PROJECT_DIR}/tests.txt | sort | uniq > tmp.txt && mv tmp.txt ${PROJECT_DIR}/tests.txt
      fi
      
      unset MMMP_MODULE
    done
  fi
}

check_inputs
find_tests
