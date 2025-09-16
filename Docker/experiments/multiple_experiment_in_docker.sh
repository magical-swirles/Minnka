#!/bin/bash
#
# Run multiple versions experiment in Docker
# Before running this script, run `docker login`
# Usage: multiple_experiment_in_docker.sh <projects-list> <output-dir> <traces-dir> [branch=false] [timeout=86400 (sec)]
#
SCRIPT_DIR=$(cd $(dirname $0) && pwd)

PROJECTS_LIST=$1
OUTPUT_DIR=$2
TRACES_DIR=$3
BRANCH=$4
TIMEOUT=$5
SKIP_RUN=$6

function check_input() {
  if [[ ! -f ${PROJECTS_LIST} || -z ${OUTPUT_DIR} || ! -d ${TRACES_DIR} ]]; then
    echo "Usage: multiple_experiment_in_docker.sh <projects-list> <output-dir> <traces-dir> [branch=false] [timeout=86400 (sec)]"
    exit 1
  fi

  if [[ ! ${OUTPUT_DIR} =~ ^/.* ]]; then
    OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
  fi
  
  if [[ ! ${TRACES_DIR} =~ ^/.* ]]; then
    TRACES_DIR=${SCRIPT_DIR}/${TRACES_DIR}
  fi

  mkdir -p ${OUTPUT_DIR}

  if [[ ! -s ${PROJECTS_LIST} ]]; then
    echo "${PROJECTS_LIST} is empty..."
    exit 0
  fi

  if [[ -z $(grep "###" ${PROJECTS_LIST}) ]]; then
    echo "You must end your projects-list file with ###"
    exit 1
  fi

  if [[ -z ${TIMEOUT} ]]; then
    TIMEOUT=86400
  fi
  
  if [[ -z ${SKIP_RUN} ]]; then
    SKIP_RUN="false"
  fi
}


function run_project() {
  local repo=$1
  deinstr=$(echo "${repo}" | cut -d ',' -f 2)
  repo=$(echo "${repo}" | cut -d ',' -f 1)

  local project_name=$(echo ${repo} | tr / -)

  local start=$(date +%s%3N)
  echo "Running ${project_name} with de-instrumentation ${deinstr}"
  mkdir -p ${OUTPUT_DIR}/${project_name}

  local id=$(docker run -itd --name multiple-${project_name} minnka:latest)
  docker exec -w /home/tsm/tsm ${id} git pull
  if [[ $? -ne 0 ]]; then
    echo "$(date) Unable to pull project ${project_name}, try again in 60 seconds" |& tee -a docker.log
    sleep 60
    docker exec -w /home/tsm/tsm ${id} git pull
    if [[ $? -ne 0 ]]; then
      echo "$(date) Skip ${project_name} because script can't pull" |& tee -a docker.log
      return
    fi
  fi
  
  if [[ -n ${BRANCH} && ${BRANCH} != "false" ]]; then
    docker exec -w /home/tsm/tsm ${id} git checkout ${BRANCH}
    docker exec -w /home/tsm/tsm ${id} git pull
  fi
  
  if [[ -n ${TIMEOUT} ]]; then
    echo "Setting test timeout to ${TIMEOUT}"
    docker exec -w /home/tsm/tsm ${id} sed -i "s/TIMEOUT=.*/TIMEOUT=${TIMEOUT}/" experiments/constants.sh
  fi
  
  local skip=0
  if [[ ! -d ${TRACES_DIR}/${project_name}/project/tsm-suite ]]; then
    echo "$(date) Skip ${project_name} because tsm-suite is missing" |& tee -a docker.log
    return
  fi
  
  if [[ ! -d ${TRACES_DIR}/${project_name}/project/tsm-matrix ]]; then
    echo "$(date) Skip ${project_name} because tsm-matrix is missing" |& tee -a docker.log
    return
  fi
  
  if [[ ! -f ${SCRIPT_DIR}/../../sha/${project_name}.txt ]]; then
    echo "$(date) Skip ${project_name} because sha is missing" |& tee -a docker.log
    return
  fi
  
  coverage_file=/home/tsm/tsm/papers/fse26/data/codecov/${project_name}.txt
  
  docker cp ${TRACES_DIR}/${project_name}/project/tsm-suite ${id}:/home/tsm
  docker cp ${TRACES_DIR}/${project_name}/project/tsm-matrix ${id}:/home/tsm
  
  if [[ -f ${SCRIPT_DIR}/../../papers/fse26/data/codecov/${project_name}.txt ]]; then
    echo "Running command: timeout ${TIMEOUT} bash multiple_versions_experiment.sh -r ${repo} -s /home/tsm/tsm/sha/${project_name}.txt -m /home/tsm/tsm-matrix/tests-state-online_detour-prefix.csv -l /home/tsm/tsm-matrix/tests-perfect-location.csv -t /home/tsm/tsm-suite/reduced/reduced_tests-state-online_detour-prefix-greedy-none.txt -c ${coverage_file} -d ${deinstr} /home/tsm/tsm/extensions /home/tsm/tsm/mop /home/tsm/tsm/output"
    timeout ${TIMEOUT} docker exec -w /home/tsm/tsm/scripts -e M2_HOME=/home/tsm/apache-maven -e MAVEN_HOME=/home/tsm/apache-maven -e CLASSPATH=/home/tsm/aspectj-1.9.7/lib/aspectjtools.jar:/home/tsm/aspectj-1.9.7/lib/aspectjrt.jar:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar: -e PATH=/home/tsm/apache-maven/bin:/usr/lib/jvm/java-8-openjdk/bin:/home/tsm/aspectj-1.9.7/bin:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin ${id} timeout ${TIMEOUT} bash multiple_versions_experiment.sh -r ${repo} -s /home/tsm/tsm/sha/${project_name}.txt -m /home/tsm/tsm-matrix/tests-state-online_detour-prefix.csv -l /home/tsm/tsm-matrix/tests-perfect-location.csv -t /home/tsm/tsm-suite/reduced/reduced_tests-state-online_detour-prefix-greedy-none.txt -c ${coverage_file} -d ${deinstr} /home/tsm/tsm/extensions /home/tsm/tsm/mop /home/tsm/tsm/output &> ${OUTPUT_DIR}/${project_name}/docker.log
  else
    echo "Running command: timeout ${TIMEOUT} bash multiple_versions_experiment.sh -r ${repo} -s /home/tsm/tsm/sha/${project_name}.txt -m /home/tsm/tsm-matrix/tests-state-online_detour-prefix.csv -l /home/tsm/tsm-matrix/tests-perfect-location.csv -t /home/tsm/tsm-suite/reduced/reduced_tests-state-online_detour-prefix-greedy-none.txt -d ${deinstr} /home/tsm/tsm/extensions /home/tsm/tsm/mop /home/tsm/tsm/output"
    timeout ${TIMEOUT} docker exec -w /home/tsm/tsm/scripts -e M2_HOME=/home/tsm/apache-maven -e MAVEN_HOME=/home/tsm/apache-maven -e CLASSPATH=/home/tsm/aspectj-1.9.7/lib/aspectjtools.jar:/home/tsm/aspectj-1.9.7/lib/aspectjrt.jar:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar: -e PATH=/home/tsm/apache-maven/bin:/usr/lib/jvm/java-8-openjdk/bin:/home/tsm/aspectj-1.9.7/bin:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin ${id} timeout ${TIMEOUT} bash multiple_versions_experiment.sh -r ${repo} -s /home/tsm/tsm/sha/${project_name}.txt -m /home/tsm/tsm-matrix/tests-state-online_detour-prefix.csv -l /home/tsm/tsm-matrix/tests-perfect-location.csv -t /home/tsm/tsm-suite/reduced/reduced_tests-state-online_detour-prefix-greedy-none.txt -d ${deinstr} /home/tsm/tsm/extensions /home/tsm/tsm/mop /home/tsm/tsm/output &> ${OUTPUT_DIR}/${project_name}/docker.log
  fi

  docker cp ${id}:/home/tsm/tsm/output ${OUTPUT_DIR}/${project_name}
  docker rm -f ${id}
  
  local end=$(date +%s%3N)
  local duration=$((end - start))
  echo "$(date) Finished running ${project_name} in ${duration} ms" |& tee -a docker.log
}

function run_all() {
  local start=$(date +%s%3N)
  while true; do
    if [[ ! -s ${PROJECTS_LIST} ]]; then
      echo "${PROJECTS_LIST} is empty..."
      exit 0
    fi

    local project=$(head -n 1 ${PROJECTS_LIST})
    if [[ ${project} == "###" ]]; then
      local end=$(date +%s%3N)
      local duration=$((end - start))
      echo "$(date) Finished running all projects in ${duration} ms" |& tee -a docker.log

      exit 0
    fi

    if [[ -z $(grep "###" ${PROJECTS_LIST}) ]]; then
      echo "You must end your projects-list file with ###"
      exit 1
    fi

    sed -i 1d ${PROJECTS_LIST}
    echo $project >> ${PROJECTS_LIST}
    run_project ${project} $@
  done

}

check_input
run_all $@
