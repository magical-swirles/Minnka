#!/bin/bash

SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
TSM_DIR="${SCRIPT_DIR}/minnka"
PROJECT_DIR="${TSM_DIR}/scripts/projects"
MOP_DIR="${SCRIPT_DIR}/minnka/mop"
MODE=$1

function clone_repository() {
  echo "Cloning minnka repository"
  pushd ${SCRIPT_DIR}
  git clone https://github.com/magical-swirles/Minnka minnka
  
  if [[ ${MODE} == "force" ]]; then
    echo "Force re-setup..."
    rm -rf ${TSM_DIR}/extensions
    rm -rf ${TSM_DIR}/mop/agents
  fi

  mkdir -p ${TSM_DIR}/extensions
  mkdir -p ${TSM_DIR}/mop/agents
  mkdir -p ${PROJECT_DIR}
  popd
}

function install_javamop() {
  # Source: https://github.com/SoftEngResearch/tracemop
  echo "Installing JavaMOP/TraceMOP"
  pushd ${PROJECT_DIR}
  git clone https://github.com/SoftEngResearch/tracemop
  popd
}

function build_agents() {
  export PATH=${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/bin:${PROJECT_DIR}/tracemop/javamop/target/release/javamop/javamop/bin:${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${PATH}
  export CLASSPATH=${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${CLASSPATH}
  
  mkdir -p ${TSM_DIR}/mop/agents
  
  pushd ${TSM_DIR}/scripts
  echo -e "db=memory\ndumpDB=false" > .trace-db.config

  pushd ${PROJECT_DIR}/tracemop/scripts
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
  popd
}

function build_extensions() {
  echo "Installing maven extensions"
  if [[ ! -f ${TSM_DIR}/extensions/junit-extension-1.0.jar ]]; then
    pushd ${SCRIPT_DIR}/minnka/extensions
    mvn package
    mv junit-extension/target/junit-extension-*.jar ${TSM_DIR}/extensions
    popd
  fi
}

function setup() {
  clone_repository
  install_javamop
  build_agents
  build_extensions
}

setup
