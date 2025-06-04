#!/bin/bash

function move_violations() {
  local directory=$1
  local filename=$2
  for violation in $(find -name "violation-counts"); do
    local name=$(echo "${violation}" | rev | cut -d '/' -f 2 | rev)
    if [[ ${name} != "." ]]; then
      # Is MMMP, add module name to file name
      mv ${violation} ${directory}/${filename}_${name}
    else
      mv ${violation} ${directory}/${filename}
    fi
  done
}

function delete_violations() {
  for violation in $(find -name "violation-counts"); do
    rm ${violation}
  done
}

function move_jfr() {
  local directory=$1
  local filename=$2
  for jfr in $(find -name "profile.jfr"); do
    local name=$(echo "${jfr}" | rev | cut -d '/' -f 2 | rev)
    if [[ ${name} != "." ]]; then
      # Is MMMP, add module name to file name
      mv ${jfr} ${directory}/${filename}_${name}
    else
      mv ${jfr} ${directory}/${filename}
    fi
  done
}

function install_agent() {
  local project_dir=$1
  local repo_dir=$2
  local mop_dir=$3
  local agent_name=$4
  local agent_type=""

  pushd ${project_dir} &> /dev/null
  if [[ -f ${mop_dir}/agents.tar.gz ]]; then
    tar -xvzf ${mop_dir}/agents.tar.gz
    rm -rf ${mop_dir}/agents.tar.gz
  fi
  
  if [[ ! -f ${mop_dir}/agents/${agent_name}.jar ]]; then
    echo "Unable to find agent @ ${mop_dir}/agents/${agent_name}.jar"
    popd &> /dev/null
    return 1
  fi

  mvn install:install-file -Dmaven.repo.local="${repo_dir}" -Dfile=${mop_dir}/agents${agent_type}/${agent_name}.jar -DgroupId="javamop-agent" -DartifactId="javamop-agent" -Dversion="1.0" -Dpackaging="jar" &> /dev/null

  popd &> /dev/null
  return 0
}
