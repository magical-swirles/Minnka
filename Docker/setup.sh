#!/bin/bash

SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
TSM_DIR="${SCRIPT_DIR}/tsm"
PROJECT_DIR="${TSM_DIR}/scripts/projects"
MOP_DIR="${SCRIPT_DIR}/tsm/mop"
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
  # Source: https://github.com/SoftEngResearch/tracemop by Guan and Legunsen
  echo "Installing JavaMOP/TraceMOP"
  pushd ${PROJECT_DIR}
  git clone https://github.com/SoftEngResearch/tracemop
  popd
}

function install_listener() {
  echo "Installing junit-test-listener"
  pushd ${TSM_DIR}/junit-listener/junit-test-listener
  mvn clean install
  popd
  
  echo "Installing junit-measure-time"
  pushd ${TSM_DIR}/junit-listener/junit-measure-time
  mvn clean install
  popd
}

function build_agents() {
  export PATH=${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/bin:${PROJECT_DIR}/tracemop/javamop/target/release/javamop/javamop/bin:${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${PATH}
  export CLASSPATH=${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor-rt.jar:${PROJECT_DIR}/tracemop/rv-monitor/target/release/rv-monitor/lib/rv-monitor.jar:${CLASSPATH}
  
  mkdir -p ${TSM_DIR}/mop/agents
  
  pushd ${TSM_DIR}/scripts
  echo -e "db=memory\ndumpDB=false" > .trace-db.config
}

function build_extensions() {
  echo "Installing maven extensions"
  if [[ ! -f ${TSM_DIR}/extensions/javamop-extension-1.0.jar || ! -f ${TSM_DIR}/extensions/junit-extension-1.0.jar ]]; then
    pushd ${SCRIPT_DIR}/tsm/extensions
    mvn package
    mv javamop-extension/target/javamop-extension-*.jar ${TSM_DIR}/extensions
    mv junit-extension/target/junit-extension-*.jar ${TSM_DIR}/extensions
    popd
  fi
}

function setup() {
  clone_repository
  install_javamop
  build_agents
  install_listener
  build_extensions
}

setup
