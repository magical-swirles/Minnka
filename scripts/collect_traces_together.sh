#!/bin/bash
#
# Run `mvn surefire:test` with TraceMOP to collect traces for each test
# Usage: collect_traces_together.sh <project-directory> <project-name> <extension-directory> <mop-directory> <log-directory>
# Output: Multiple traces directories in `projects/<project-name>/.all-traces` directory
#
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

source ${SCRIPT_DIR}/../experiments/constants.sh
source ${SCRIPT_DIR}/../experiments/utils.sh

# Convert relative path to absolute path
function convert_to_absolute_paths() {
  if [[ ! ${PROJECT_DIR} =~ ^/.* ]]; then
    PROJECT_DIR=${SCRIPT_DIR}/${PROJECT_DIR}
  fi
  
  if [[ ! ${EXTENSION_DIR} =~ ^/.* ]]; then
    EXTENSION_DIR=${SCRIPT_DIR}/${EXTENSION_DIR}
  fi
  
  if [[ ! ${MOP_DIR} =~ ^/.* ]]; then
    MOP_DIR=${SCRIPT_DIR}/${MOP_DIR}
  fi
  
  if [[ ! ${LOG_DIR} =~ ^/.* ]]; then
    LOG_DIR=${SCRIPT_DIR}/${LOG_DIR}
  fi
}

# Clone and install JavaMOP
function setup_tracemop() {
  if [[ ! -f "${MOP_DIR}/agents/track-agent.jar" || ! -f "${MOP_DIR}/agents/no-track-agent.jar" || ! -f "${MOP_DIR}/agents/stats-agent.jar" ]]; then
    pushd ${PROJECT_DIR} &> /dev/null
      if [[ ! -d tracemop ]]; then
        # Source: https://github.com/SoftEngResearch/tracemop by Guan and Legunsen
        git clone https://github.com/SoftEngResearch/tracemop.git
        pushd tracemop &> /dev/null
          bash scripts/install-javaparser.sh
          mvn install -DskipTests
        popd &> /dev/null
      fi
    popd &> /dev/null
  fi
}

# Install JavaMOP agent
function install_mop_agent() {
  mkdir -p ${MOP_DIR}/agents
  if [[ ! -f "${MOP_DIR}/agents/track-agent.jar" || ! -f "${MOP_DIR}/agents/no-track-agent.jar" || ! -f "${MOP_DIR}/agents/stats-agent.jar" ]]; then
    pushd ${PROJECT_DIR}/tracemop/scripts &> /dev/null
    if [[ ! -f "${MOP_DIR}/agents/track-agent.jar" ]]; then
      mv props-track tmp.props && cp -r ${MOP_DIR}/renamed_props-non-raw props-track
      bash install.sh true false # This will generate a track-no-stats-agent.jar file
      cp track-no-stats-agent.jar ${MOP_DIR}/agents/track-agent.jar
      rm -rf props-track && mv tmp.props props-track
    fi
    if [[ ! -f "${MOP_DIR}/agents/no-track-agent.jar" ]]; then
      mv props tmp.props && cp -r ${MOP_DIR}/props-non-raw props
      bash install.sh false false # This will generate a no-track-no-stats-agent.jar
      cp no-track-no-stats-agent.jar ${MOP_DIR}/agents/no-track-agent.jar
      rm -rf props && mv tmp.props props
    fi
    if [[ ! -f "${MOP_DIR}/agents/stats-agent.jar" ]]; then
      mv props tmp.props && cp -r ${MOP_DIR}/props-non-raw props
      bash install.sh false true # This will generate a no-track-stats-agent.jar
      cp no-track-stats-agent.jar ${MOP_DIR}/agents/stats-agent.jar
      rm -rf props && mv tmp.props props
    fi
    popd &> /dev/null
  fi
  pushd ${SCRIPT_DIR} &> /dev/null
    if [[ ! -f .trace-db.config ]]; then
      echo -e "db=memory\ndumpDB=false" > .trace-db.config
    fi
    install_agent ${PROJECT_DIR}/${PROJECT_NAME} "${PROJECT_DIR}/repo${REPO_SUFFIX}" ${MOP_DIR} "track-agent"
  popd &> /dev/null
}

# Collect traces using python script
function collect_traces() {
  python3 ${SCRIPT_DIR}/collect_traces_together.py ${PROJECT_DIR} ${PROJECT_NAME} ${EXTENSION_DIR} ${MOP_DIR} ${LOG_DIR} ${THREADS:-20} ${TRACES_TIMEOUT:-20}
  status=$?

  rm -rf commands.txt
  # Compress traces
  while read -r file; do
    if [[ -n $file ]]; then
      echo "gzip '${file}'" >> commands.txt
    fi
  done <<< $(find ${PROJECT_DIR}/${PROJECT_NAME}  -name "unique-traces.txt")
  
  if [[ -f commands.txt ]]; then
    cat commands.txt | parallel --jobs ${THREADS:-20}
    rm -rf commands.txt
    exit ${status}
  else
    # Cannot find any traces
    exit 1
  fi
}

PROJECT_DIR=$1
PROJECT_NAME=$(echo $2 | tr / -)
EXTENSION_DIR=$3
MOP_DIR=$4
LOG_DIR=$5
THREADS=$6
TRACES_TIMEOUT=$7
convert_to_absolute_paths


if [[ -z "$5" ]]; then
  echo "Usage: ./collect_traces_together.sh <project-directory> <project-name> <extension-directory> <mop-directory> <log-directory>"
  exit 1
fi

if [[ ! -f "${PROJECT_DIR}/${PROJECT_NAME}/tests.txt" ]]; then
  echo "Please run 'collect_tests.sh' first"
  exit 1
fi

setup_tracemop
install_mop_agent
collect_traces
