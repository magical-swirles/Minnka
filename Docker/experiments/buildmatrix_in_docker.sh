#!/bin/bash
#
# Build matrices in Docker
# Before running this script, run `docker login`
# Usage: buildmatrix_in_docker.sh <projects-list> <output-dir> [branch=false] [timeout=1440 (min)]
#
SCRIPT_DIR=$(cd $(dirname $0) && pwd)

export EQUIVALENCE="equality"
export THREADS=6
export PARALLEL=false
export BASELINE="javamop"
export MONITORING_ONLY=false
export RV_STATS=true
export FORCE_REINSTR=false
export MMMP=false

while getopts :m: opts; do
  case "${opts}" in
    m ) MMMP="${OPTARG}" ;;
  esac
done
shift $((${OPTIND} - 1))

PROJECTS_LIST=$1
OUTPUT_DIR=$2
BRANCH=$3
TIMEOUT=$4

function check_input() {
  if [[ ! -f ${PROJECTS_LIST} || -z ${OUTPUT_DIR} ]]; then
    echo "Usage: buildmatrix_in_docker.sh <projects-list> <output-dir> [branch=false] [timeout=1440 (min)]"
    exit 1
  fi

  if [[ ! ${OUTPUT_DIR} =~ ^/.* ]]; then
    OUTPUT_DIR=${SCRIPT_DIR}/${OUTPUT_DIR}
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
    TIMEOUT=1440
  fi
}


function run_project() {
  local repo=$1

  OLD_OUTPUT=$(echo "${repo}" | cut -d ',' -f 3)
  sha=$(echo "${repo}" | cut -d ',' -f 2)
  repo=$(echo "${repo}" | cut -d ',' -f 1)
  if [[ -z ${OLD_OUTPUT} ]]; then
    OLD_OUTPUT=${GLOBAL_OLD_OUTPUT_DIR}
  fi

  local project_name=$(echo ${repo} | tr / -)

  local start=$(date +%s%3N)
  echo "Running ${project_name} with SHA ${sha}"
  mkdir -p ${OUTPUT_DIR}/${project_name}

  local id=$(docker run -itd --name ${project_name} minnka:latest)
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
    NEW_TIMEOUT=$((TIMEOUT*60))
    echo "Setting test timeout to ${NEW_TIMEOUT}"
    docker exec -w /home/tsm/tsm ${id} sed -i "s/TIMEOUT=.*/TIMEOUT=${NEW_TIMEOUT}/" experiments/constants.sh
  fi
  
  timeout ${NEW_TIMEOUT} docker exec -w /home/tsm/tsm -e M2_HOME=/home/tsm/apache-maven -e MAVEN_HOME=/home/tsm/apache-maven -e CLASSPATH=/home/tsm/aspectj-1.9.7/lib/aspectjtools.jar:/home/tsm/aspectj-1.9.7/lib/aspectjrt.jar:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar: -e PATH=/home/tsm/apache-maven/bin:/usr/lib/jvm/java-8-openjdk/bin:/home/tsm/aspectj-1.9.7/bin:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin ${id} timeout ${NEW_TIMEOUT} bash scripts/run_get_reduced.sh -e "perfect,state,prefix,online_detour,state-online_detour-prefix" -a "greedy,ge,gre,hgs" -r ${repo} -s ${sha} -p true -m ${MMMP} /home/tsm/tsm/extensions /home/tsm/tsm/mop /home/tsm/tsm/output &> ${OUTPUT_DIR}/${project_name}/docker.log

  docker cp ${id}:/home/tsm/tsm/output ${OUTPUT_DIR}/${project_name}/output
  docker cp ${id}:/home/tsm/tsm/scripts/projects/${project_name} ${OUTPUT_DIR}/${project_name}/project
  docker cp ${id}:/home/tsm/tsm/scripts/projects/repo ${OUTPUT_DIR}/${project_name}/repo

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
