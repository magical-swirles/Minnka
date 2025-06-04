#!/bin/bash
#
# Run evolution's experiment in Docker
# Before running this script, run `docker login`
# Usage: evolution_in_docker.sh <projects-list> <output-dir> [branch=false] [timeout=1440 (min)]
# Input format:
# repo,seq-or-par,scheme (notion),algorithm (e.g., greedy),tiebreaker (e.g., none)
#
SCRIPT_DIR=$(cd $(dirname $0) && pwd)

PROJECTS_LIST=$1
OUTPUT_DIR=$2
BRANCH=$3
TIMEOUT=$4

function check_input() {
  if [[ ! -f ${PROJECTS_LIST} || -z ${OUTPUT_DIR} ]]; then
    echo "Usage: evolution_in_docker.sh <projects-list> <output-dir> [branch=false] [timeout=1440 (min)]"
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

  local tiebreaker=$(echo "${repo}" | cut -d ',' -f 5)
  local algorithm=$(echo "${repo}" | cut -d ',' -f 4)
  local scheme=$(echo "${repo}" | cut -d ',' -f 3)
  local seq_par=$(echo "${repo}" | cut -d ',' -f 2)
  repo=$(echo "${repo}" | cut -d ',' -f 1)

  if [[ -z ${tiebreaker} ]]; then
    echo "Project format is incorrect (${repo})"
    continue
  fi
  
  seq_par="true"
  if [[ ${seq_par} == "seq" ]]; then
    seq_par="false"
  fi

  local project_name=$(echo ${repo} | tr / -)

  local start=$(date +%s%3N)
  echo "Running ${project_name} with SHA ${sha}"
  mkdir -p ${OUTPUT_DIR}/${project_name}

  local id=$(docker run -itd --name ${project_name} minnka)
  docker exec -w /home/minnka/minnka ${id} git pull
  if [[ $? -ne 0 ]]; then
    echo "Unable to pull project ${project_name}, try again in 60 seconds" |& tee -a docker.log
    sleep 60
    docker exec -w /home/minnka/minnka ${id} git pull
    if [[ $? -ne 0 ]]; then
      echo "Skip ${project_name} because script can't pull" |& tee -a docker.log
      return
    fi
  fi
  
  if [[ -n ${BRANCH} && ${BRANCH} != "false" ]]; then
    docker exec -w /home/minnka/minnka ${id} git checkout ${BRANCH}
    docker exec -w /home/minnka/minnka ${id} git pull
  fi
  
  if [[ -n ${TIMEOUT} ]]; then
    NEW_TIMEOUT=$((TIMEOUT*60))
    echo "Setting test timeout to ${NEW_TIMEOUT}"
    docker exec -w /home/minnka/minnka ${id} sed -i "s/TIMEOUT=.*/TIMEOUT=${NEW_TIMEOUT}/" experiments/constants.sh
  fi

  echo "Running command: timeout ${NEW_TIMEOUT} bash scripts/evolution_experimentsh.sh -p ${repo} -s /home/minnka/minnka/sha/${project_name}.txt -a ${seq_par} -t ${tiebreaker} -r ${algorithm} -e ${scheme} /home/minnka/minnka/scripts/projects/${project_name} /home/minnka/minnka/scripts/projects/repo"
  timeout ${NEW_TIMEOUT} docker exec -w /home/minnka/minnka -e M2_HOME=/home/minnka/apache-maven -e MAVEN_HOME=/home/minnka/apache-maven -e CLASSPATH=/home/minnka/aspectj-1.9.7/lib/aspectjtools.jar:/home/minnka/aspectj-1.9.7/lib/aspectjrt.jar:/home/minnka/aspectj-1.9.7/lib/aspectjweaver.jar: -e PATH=/home/minnka/apache-maven/bin:/usr/lib/jvm/java-8-openjdk/bin:/home/minnka/aspectj-1.9.7/bin:/home/minnka/aspectj-1.9.7/lib/aspectjweaver.jar:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin ${id} timeout ${NEW_TIMEOUT} bash scripts/evolution_experimentsh.sh -p ${repo} -s /home/minnka/minnka/sha/${project_name}.txt -a ${seq_par} -t ${tiebreaker} -r ${algorithm} -e ${scheme} /home/minnka/minnka/scripts/projects/${project_name} /home/minnka/minnka/scripts/projects/repo &> ${OUTPUT_DIR}/${project_name}/docker.log

  docker cp ${id}:/home/minnka/minnka/scripts/projects/${project_name} ${OUTPUT_DIR}/${project_name}/project
  docker cp ${id}:/home/minnka/minnka/scripts/projects/repo ${OUTPUT_DIR}/${project_name}/repo

  docker rm -f ${id}
  
  local end=$(date +%s%3N)
  local duration=$((end - start))
  echo "Finished running ${project_name} in ${duration} ms" |& tee -a docker.log
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
      echo "Finished running all projects in ${duration} ms" |& tee -a docker.log

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
