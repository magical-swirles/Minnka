#!/bin/bash
#
# Check run_all.sh status
# Usage: status.sh <log-directory>
# The current directory should contain file "projects.txt"
#
LOG_DIR=$1

if [[ -z "${LOG_DIR}" ]]; then
  echo "Usage: ./status.sh <log-directory>"
  exit 1
fi

if [[ ! -f "projects.txt" ]]; then
  echo "The current directory should contain file projects.txt"
  exit 1
fi

current_projects=$(cat projects.txt | cut -d ',' -f 1 | tr / -)

for project in $( ls ${LOG_DIR} ); do
  indicator=""
  status="finished"
  reason=""

  if [[ -n $(echo ${current_projects} | grep "${project}") ]]; then
    indicator="*"
  fi

  if [[ -f ${LOG_DIR}/${project}/tsm-result.txt ]]; then
    step=$(cat ${LOG_DIR}/${project}/tsm-result.txt | cut -d ',' -f 1)
    code=$(cat ${LOG_DIR}/${project}/tsm-result.txt | cut -d ',' -f 2)

    if [[ ${step} -ne 0 ]]; then
      status="failed"
      case ${step} in
        1) reason="failed to collect tests";;
        2) reason="failed to collect traces";;
        3) reason="failed to generate csv";;
        4) reason="failed to run tsm";;
        5) reason="failed to generate stats";;
      esac
    else
      if [[ -f ${LOG_DIR}/${project}/stats.csv ]]; then
        reason=$(awk -F ',' 'NR==2 {all_test=$2; all_time=$7; all_violation=$6} NR==3 {reduced_test=$2; reduced_time=$7; reduced_violation=$6; (all_time > 0) ? ratio=reduced_time/all_time : ratio=0; printf "%-5s %-5s %0.2f\t%4.2f\t%4.2f",all_test,reduced_test,ratio,all_time,reduced_time; if(all_violation > reduced_violation) printf "\tunsafe"}' ${LOG_DIR}/${project}/stats.csv)
      else
        status="failed"
        reason="cannot find stats.csv"
      fi
    fi
  else
    status="running"
    indicator="?"
  fi

  printf "%-1s %-40s%-20s%s\n" "${indicator}" ${project} ${status} "${reason}"
done
