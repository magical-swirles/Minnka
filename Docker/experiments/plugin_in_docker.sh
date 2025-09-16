#!/bin/bash
#
# Run plugin's experiment in Docker
# Before running this script, run `docker login`
# Usage: plugin_in_docker.sh [-r <reduction_schemes> -c <rv_configs> -o <old-output-dir> -a <parallel: true/false> -v <violation-only: true/false>] <projects-list> <output-dir> [branch=false] [timeout=1440 (min)]
#
SCRIPT_DIR=$(cd $(dirname $0) && pwd)

PARALLEL="false"
VIOLATION_ONLY="false"
while getopts :r:c:o:a:v:t:l: opts; do
  case "${opts}" in
    r ) REDUCTION_SCHEMES="${OPTARG}" ;;
    c ) RV_CONFIGS="${OPTARG}" ;;
    o ) GLOBAL_OLD_OUTPUT_DIR="${OPTARG}" ;;
    a ) PARALLEL="${OPTARG}" ;;
    v ) VIOLATION_ONLY="${OPTARG}" ;;
    t ) TIEBREAKER="${OPTARG}" ;; # none or time
    l ) ALGORITHM="${OPTARG}" ;; # greedy, ge, gre, or hgs
  esac
done
shift $((${OPTIND} - 1))

PROJECTS_LIST=$1
OUTPUT_DIR=$2
BRANCH=$3
TIMEOUT=$4

if [[ -z ${REDUCTION_SCHEMES} ]]; then
  REDUCTION_SCHEMES="all,perfect,state,prefix,online_detour,state-online_detour-prefix"
fi

if [[ -z ${RV_CONFIGS} ]]; then
  RV_CONFIGS="no-track,no-rv"
fi

if [[ -z ${TIEBREAKER} ]]; then
  TIEBREAKER="none"
fi

if [[ -z ${ALGORITHM} ]]; then
  ALGORITHM="greedy"
fi

function check_input() {
  if [[ ! -f ${PROJECTS_LIST} || -z ${OUTPUT_DIR} ]]; then
    echo "Usage: plugin_in_docker.sh [-r <reduction_schemes> -c <rv_configs> -o <old-output-dir> -a <parallel: true/false> -v <violation-only: true/false>] <projects-list> <output-dir> [branch=false] [timeout=1440 (min)]"
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

  local schemes=$(echo "${repo}" | cut -d ',' -f 5)
  local seq_par=$(echo "${repo}" | cut -d ',' -f 4)
  OLD_OUTPUT=$(echo "${repo}" | cut -d ',' -f 3)
  sha=$(echo "${repo}" | cut -d ',' -f 2)
  repo=$(echo "${repo}" | cut -d ',' -f 1)
  if [[ -z ${OLD_OUTPUT} ]]; then
    OLD_OUTPUT=${GLOBAL_OLD_OUTPUT_DIR}
  fi
  
  if [[ -z ${schemes} ]]; then
    schemes=${REDUCTION_SCHEMES}
  fi
  
  if [[ ${seq_par} == "seq" ]]; then
    seq_par="false"
  elif [[ ${seq_par} == "par" ]]; then
    seq_par="true"
  else
    seq_par=${PARALLEL}
  fi

  local project_name=$(echo ${repo} | tr / -)

  local start=$(date +%s%3N)
  echo "Running ${project_name} with SHA ${sha}"
  mkdir -p ${OUTPUT_DIR}/${project_name}

  local id=$(docker run -itd --name ${project_name} minnka:latest)
  docker exec -w /home/tsm/tsm ${id} git pull
  if [[ $? -ne 0 ]]; then
    echo "Unable to pull project ${project_name}, try again in 60 seconds" |& tee -a docker.log
    sleep 60
    docker exec -w /home/tsm/tsm ${id} git pull
    if [[ $? -ne 0 ]]; then
      echo "Skip ${project_name} because script can't pull" |& tee -a docker.log
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
  
  local skip=0
  if [[ -d ${OLD_OUTPUT}/${project_name} ]]; then
    echo "Found previous project directory. Copying to container..."
    if [[ -d ${OLD_OUTPUT}/${project_name}/project && -d ${OLD_OUTPUT}/${project_name}/repo ]]; then
      docker cp ${OLD_OUTPUT}/${project_name}/project ${id}:/home/tsm/tsm/scripts/projects/${project_name}
      docker cp ${OLD_OUTPUT}/${project_name}/repo ${id}:/home/tsm/tsm/scripts/projects/repo
      docker exec -u 0 ${id} chown -R tsm:tsm /home/tsm/tsm/scripts/projects/${project_name}
      docker exec -u 0 ${id} chown -R tsm:tsm /home/tsm/tsm/scripts/projects/repo
    else
      docker cp ${OLD_OUTPUT}/${project_name} ${id}:/home/tsm/tsm/scripts/projects/${project_name}
      docker exec -u 0 ${id} chown -R tsm:tsm /home/tsm/tsm/scripts/projects/${project_name}
    fi
  
    if [[ ${VIOLATION_ONLY} == "true" ]]; then
      local filename=${OLD_OUTPUT}/${project_name}/output/${project_name}/stats/violations/all.txt
      if [[ ! -s ${filename} ]]; then
        echo "Skip ${project_name} because it does not have violation" &> ${OUTPUT_DIR}/${project_name}/docker.log
        docker rm -f ${id}
        echo "Finished running ${project_name} - no violation" |& tee -a docker.log
        return
      fi
    fi
  fi

  echo "Running command: timeout ${NEW_TIMEOUT} bash scripts/equality_experiment.sh -p ${repo} -s ${sha} -a ${seq_par} -t ${TIEBREAKER} -r ${ALGORITHM} /home/tsm/tsm/scripts/projects/${project_name} /home/tsm/tsm/scripts/projects/repo ${schemes} ${RV_CONFIGS}"
  timeout ${NEW_TIMEOUT} docker exec -w /home/tsm/tsm -e M2_HOME=/home/tsm/apache-maven -e MAVEN_HOME=/home/tsm/apache-maven -e CLASSPATH=/home/tsm/aspectj-1.9.7/lib/aspectjtools.jar:/home/tsm/aspectj-1.9.7/lib/aspectjrt.jar:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar: -e PATH=/home/tsm/apache-maven/bin:/usr/lib/jvm/java-8-openjdk/bin:/home/tsm/aspectj-1.9.7/bin:/home/tsm/aspectj-1.9.7/lib/aspectjweaver.jar:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin ${id} timeout ${NEW_TIMEOUT} bash scripts/equality_experiment.sh -p ${repo} -s ${sha} -a ${seq_par} -t ${TIEBREAKER} -r ${ALGORITHM} /home/tsm/tsm/scripts/projects/${project_name} /home/tsm/tsm/scripts/projects/repo "${schemes}" "${RV_CONFIGS}" &> ${OUTPUT_DIR}/${project_name}/docker.log

  docker cp ${id}:/home/tsm/tsm/scripts/projects/${project_name} ${OUTPUT_DIR}/${project_name}/project
  docker cp ${id}:/home/tsm/tsm/scripts/projects/repo ${OUTPUT_DIR}/${project_name}/repo

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
