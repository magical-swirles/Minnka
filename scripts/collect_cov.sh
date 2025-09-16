#!/bin/bash
SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

source ${SCRIPT_DIR}/../experiments/constants.sh

repo=$1
commit=$2

PROJECT_NAME=$(echo ${repo} | tr / -)

echo "TSM version: ($(git rev-parse HEAD) - $(date +%s))"

just_cloned=false

echo "[TSM] Installing Maven plugin..."
pushd ${SCRIPT_DIR}/../rvtsm-maven-plugin &> /dev/null
mvn install -DskipTests &> /dev/null
popd &> /dev/null

pushd ${SCRIPT_DIR} &> /dev/null
    mkdir -p projects
    pushd projects &> /dev/null
        if [[ ! -d ${PROJECT_NAME} ]]; then
            git clone https://github.com/${repo} ${PROJECT_NAME}
            just_cloned=true
        fi
        pushd ${PROJECT_NAME} &> /dev/null
            if [[ ${just_cloned} == "true" ]]; then
                git checkout ${commit}
                mvn clean test-compile ${SKIP}
                mvn org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:reduce -DtestRequirementType=coverage
            else
                mvn clean test-compile ${SKIP}
                if [[ $? -ne 0 ]]; then
                    echo "ERROR: compile"
                    exit 1
                fi
                
                mkdir logs
                echo "> mvn -l logs/coverage-no-track-log.txt org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:scr -DskipAllPreviousSteps=true -DtestMethodsToRun=.rvtsm/reduced.txt -DrunLabel=coverage-no-track -DrvConfig=no-track"
                mvn -l logs/coverage-no-track-log.txt org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:scr -DskipAllPreviousSteps=true -DtestMethodsToRun=.rvtsm/reduced.txt -DrunLabel=coverage-no-track -DrvConfig=no-track
                if [[ $? -ne 0 ]]; then
                    echo "ERROR: run no-track"
                    exit 1
                fi
                if [[ -f violation-counts ]]; then
                    mv violation-counts violation-counts-no-track
                fi
                
                echo "> mvn -l logs/coverage-track-log.txt org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:scr -DskipAllPreviousSteps=true -DtestMethodsToRun=.rvtsm/reduced.txt -DrunLabel=coverage-track -DrvConfig=track"
                mvn -l logs/coverage-track-log.txt org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:scr -DskipAllPreviousSteps=true -DtestMethodsToRun=.rvtsm/reduced.txt -DrunLabel=coverage-track -DrvConfig=track
                if [[ $? -ne 0 ]]; then
                    echo "ERROR: run track"
                    exit 1
                fi
                if [[ -f violation-counts ]]; then
                    mv violation-counts violation-counts-track
                fi
                
                echo "> mvn -l coverage-redundant-no-rv-log.txt org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:scr -DskipAllPreviousSteps=true -DtestMethodsToRun=.rvtsm/redundant-and-no-trace.txt -DrunLabel=coverage-redundant-no-rv -DrvConfig=no-rv"
                mvn -l logs/coverage-redundant-no-rv-log.txt org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:scr -DskipAllPreviousSteps=true -DtestMethodsToRun=.rvtsm/redundant-and-no-trace.txt -DrunLabel=coverage-redundant-no-rv -DrvConfig=no-rv
                if [[ $? -ne 0 ]]; then
                    echo "ERROR: run no-rv"
                    exit 1
                fi
            fi
        popd &> /dev/null
    popd &> /dev/null
popd &> /dev/null
