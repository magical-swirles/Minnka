#!/bin/bash

SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )

source ${SCRIPT_DIR}/../experiments/constants.sh
source ${SCRIPT_DIR}/../experiments/utils.sh

cd $SCRIPT_DIR

while getopts :r:s:m:t:l:c:d: opts; do
    case "${opts}" in
        r ) REPO="${OPTARG}" ;;
        s ) SHA_FILE="${OPTARG}" ;;
        m ) MATRIX="${OPTARG}" ;;
        l ) LOCATION="${OPTARG}" ;;
        t ) TESTS="${OPTARG}" ;;
        c ) COV_TESTS="${OPTARG}" ;;
        d ) DEINSTR="${OPTARG}" ;;
    esac
done
shift $((${OPTIND} - 1))
EXTENSION_DIR=$1
MOP_DIR=$2
OUTPUT_DIR=$3
PROJECT_NAME=$(echo ${REPO} | tr / -)

mkdir -p ${OUTPUT_DIR}/logs
mkdir -p ${TMP_DIR}/${PROJECT_NAME}
mkdir -p ${TMP_DIR}/${PROJECT_NAME}-agent
mkdir -p ${TMP_DIR}/${PROJECT_NAME}-deps

MAVEN_OPTION="-Dmaven.repo.local=${OUTPUT_DIR}/repo -Dmaven.ext.class.path=${EXTENSION_DIR}/javamop-extension-1.0.jar ${SKIP}"
export RVMLOGGINGLEVEL=UNIQUE


JAVAMOP_AGENT="${MOP_DIR}/agents/no-track-all.jar"
EMOP_AGENT_ALL="${TMP_DIR}/${PROJECT_NAME}-agent/emop-no-track-agent.jar"
EMOP_AGENT_REDUCED="${TMP_DIR}/${PROJECT_NAME}-agent/emop-no-track-agent-2.jar"

cp ${JAVAMOP_AGENT} ${EMOP_AGENT_ALL}
if [[ ${DEINSTR} == "true" ]]; then
    cp "${MOP_DIR}/agents/no-track-deinstr.jar" ${EMOP_AGENT_REDUCED}
    
    pushd ${OUTPUT_DIR} &> /dev/null
    if [[ ! -d ${OUTPUT_DIR}/skip ]]; then
        python3 ${SCRIPT_DIR}/skip_monitoring.py ${MATRIX} ${LOCATION} ${TESTS} ${MOP_DIR}/events_encoding_id.txt skip &> ${OUTPUT_DIR}/logs/deinstr.log
        if [[ $? -ne 0 ]]; then
            echo "ERROR: failed to build de-instrumentation map"
            exit 1
        fi
    fi
    source ${OUTPUT_DIR}/skip/setup.sh
    popd &> /dev/null
else
    cp ${JAVAMOP_AGENT} ${EMOP_AGENT_REDUCED}
fi
cp ${MOP_DIR}/agents/no-track-all.jar ${TMP_DIR}/${PROJECT_NAME}-agent/no-track-all.jar
cp ${MOP_DIR}/agents/no-track-agent.jar ${TMP_DIR}/${PROJECT_NAME}-agent/no-track-agent.jar
cp ${MOP_DIR}/agents/no-track-deinstr.jar ${TMP_DIR}/${PROJECT_NAME}-agent/no-track-deinstr.jar

function clone_project() {
    pushd ${OUTPUT_DIR} &> /dev/null
    git clone https://github.com/${REPO} project
    if [[ $? -ne 0 ]]; then
        echo "Unable to clone project"
        exit 1
    fi
    
    pushd project &> /dev/null
    if [[ -f ${SCRIPT_DIR}/../experiments/treat_special.sh ]]; then
        bash ${SCRIPT_DIR}/../experiments/treat_special.sh ${OUTPUT_DIR}/project ${PROJECT_NAME}
    fi
    popd &> /dev/null
    popd &> /dev/null
}

function build_emop_and_imop() {
    export ADD_AGENT=0
    pushd ${TMP_DIR}/${PROJECT_NAME}-deps &> /dev/null

    # eMOP's source: https://github.com/SoftEngResearch/emop by Yorihiro et al.
    if [[ ! -d emop ]]; then
        git clone https://github.com/SoftEngResearch/emop &>> ${OUTPUT_DIR}/logs/setup-log.txt
        cd emop
        
        # We need to run the below script to install STARTS, but we can't set the repo directlry
        # so we need to backup current MAVEN_OPTS, then use MAVEN_OPTS to set repo, and restore original MAVEN_OPTS
        local tmp_OPTS=${MAVEN_OPTS}
        export MAVEN_OPTS=${MAVEN_OPTION}
        
        echo "Installing STARTS..."
        bash scripts/install-starts.sh &>> ${OUTPUT_DIR}/logs/setup-log.txt
        if [[ $? -ne 0 ]]; then
            echo "ERROR: Unable to install starts"
            exit 1
        fi
        export MAVEN_OPTS=${tmp_OPTS}
    else
        cd emop
    fi

    # Remove raw specs
    # pushd emop-maven-plugin/src/main/resources/weaved-specs/ &> /dev/null
    #    comm -23 <(ls | sed "s/MonitorAspect.aj//g" | sort) <(ls ${SCRIPT_DIR}/../mop/renamed_props | cut -d '.' -f 1 | sort) | xargs -I {} rm {}MonitorAspect.aj
    # popd &> /dev/null

    # Install eMOP
    echo "Installing eMOP..."
    mvn -Dmaven.repo.local=${OUTPUT_DIR}/repo clean install &>> ${OUTPUT_DIR}/logs/setup-log.txt # can't use ${SKIP} else it will not install the plugin
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Unable to install eMOP"
        exit 1
    fi
    popd &> /dev/null
    
    echo "Installing iMOP..."
    pushd ${TMP_DIR}/${PROJECT_NAME}-agent/ &> /dev/null
    cp ${MOP_DIR}/DefaultCacheKeyResolver.java .
    javac -cp no-track-all.jar DefaultCacheKeyResolver.java
    mkdir -p org/aspectj/weaver/tools/cache/
    cp DefaultCacheKeyResolver.class org/aspectj/weaver/tools/cache/
    jar -uf no-track-all.jar -C . org/aspectj/weaver/tools/cache/DefaultCacheKeyResolver.class
    jar -uf no-track-agent.jar -C . org/aspectj/weaver/tools/cache/DefaultCacheKeyResolver.class
    jar -uf no-track-deinstr.jar -C . org/aspectj/weaver/tools/cache/DefaultCacheKeyResolver.class
    popd &> /dev/null

    unset ADD_AGENT
}

function compileAndTestAllWithoutRV() {
    local sha=$1
    export ADD_AGENT=0

    echo "Compiling"
    mvn ${MAVEN_OPTION} clean test-compile &> ${OUTPUT_DIR}/logs/${sha}/test-compile.log
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Unable to compile"
        exit 1
    fi

    echo "Running test to download dependencies"
    mvn ${MAVEN_OPTION} test &> ${OUTPUT_DIR}/logs/${sha}/test-init.log
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Unable to download dependencies"
        exit 1
    fi

    # Need to run twice because the first time might contain downloading times
    echo "Measuring test time"
    local start=$(date +%s%3N)
    (time mvn ${MAVEN_OPTION} test) &> ${OUTPUT_DIR}/logs/${sha}/test.log
    local status=$?
    local end=$(date +%s%3N)
    duration=$((end - start))
    echo -n ",${duration},${status}" >> ${OUTPUT_DIR}/logs/results.csv
    
    if [[ ${status} -ne 0 ]]; then
        echo "ERROR: Unable to run test"
        exit 1
    fi
    unset ADD_AGENT
}

function run_all_javamop_all_specs {
    local sha=$1
    local name="all-javamop-all-specs"
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${TMP_DIR}/${PROJECT_NAME}-agent "no-track-all"
    
    echo "Running ${name}"

    local start=$(date +%s%3N)
    (time mvn ${MAVEN_OPTION} test) &> ${OUTPUT_DIR}/logs/${sha}/${name}.log
    local status=$?
    local end=$(date +%s%3N)
    duration=$((end - start))
    echo -n ",${duration},${status}" >> ${OUTPUT_DIR}/logs/results.csv
#   if [[ ${status} -ne 0 ]]; then
#       echo "ERROR: Unable to run ${name}"
#       exit 1
#   fi
    
    if [[ -f violation-counts ]]; then
        mv violation-counts ${OUTPUT_DIR}/logs/${sha}/violations/${name}
    fi
}

# Given file, return tests
# $(cat ${tests_file} | sed -z '$ s/\n$//;s/\n/,/g')

function run_reduced_javamop_all_specs() {
    local sha=$1
    local reduced_set_file=$2
    local coverage=$3
    local reduced_set=$(cat ${reduced_set_file} | sed -z '$ s/\n$//;s/\n/,/g')
    if [[ ${coverage} != "true" ]]; then
        local name="reduced-javamop-all-specs"
    else
        local name="reduced-codecov"
    fi
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    # Install special agent if needed
    if [[ ${coverage} != "true" ]]; then
        if [[ ${DEINSTR} == "true" ]]; then
            install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${TMP_DIR}/${PROJECT_NAME}-agent "no-track-deinstr"
        else
            install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${TMP_DIR}/${PROJECT_NAME}-agent "no-track-all"
        fi
    else
        install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${TMP_DIR}/${PROJECT_NAME}-agent "no-track-all"
    fi
    
    echo "Running ${name}"
    
    local start=$(date +%s%3N)
    (time mvn ${MAVEN_OPTION} -Dtest=${reduced_set} test) &> ${OUTPUT_DIR}/logs/${sha}/${name}.log
    local status=$?
    local end=$(date +%s%3N)
    duration=$((end - start))
    echo -n ",${duration},${status}" >> ${OUTPUT_DIR}/logs/results.csv
#   if [[ ${status} -ne 0 ]]; then
#       echo "ERROR: Unable to run ${name}"
#       exit 1
#   fi
    
    if [[ -f violation-counts ]]; then
        mv violation-counts ${OUTPUT_DIR}/logs/${sha}/violations/${name}
    fi
}

function run_emop {
    local sha=$1
    local reduced_set_file=$2
    if [[ ${reduced_set_file} != "" ]]; then
        local reduced_set=$(cat ${reduced_set_file} | sed -z '$ s/\n$//;s/\n/,/g')
        local name="reduced-emop"
        export MOP_AGENT_PATH="-javaagent:${EMOP_AGENT_REDUCED}"
    else
        local name="all-emop"
        export MOP_AGENT_PATH="-javaagent:${EMOP_AGENT_ALL}"
    fi
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}

    if [[ -d .starts-${name} ]]; then
        mv .starts-${name} .starts
    fi
    
    echo "Running ${name}"
    
    if [[ ${reduced_set_file} != "" && -f ${OUTPUT_DIR}/logs/${sha}/all-emop.log && -n $(grep --text "No impacted classes" ${OUTPUT_DIR}/logs/${sha}/all-emop.log) ]]; then
        duration=$(tail -n 1 ${OUTPUT_DIR}/logs/results.csv | rev | cut -d ',' -f 2 | rev)
        cp ${OUTPUT_DIR}/logs/${sha}/all-emop.log ${OUTPUT_DIR}/logs/${sha}/${name}.log
        local status=0
        echo -n ",${duration},${status}" >> ${OUTPUT_DIR}/logs/results.csv
    else
        # eMOP's source: https://github.com/SoftEngResearch/emop by Yorihiro et al.
        local start=$(date +%s%3N)
        if [[ ${reduced_set_file} != "" ]]; then
            (time mvn ${MAVEN_OPTION} -DjavamopAgent=${EMOP_AGENT_REDUCED} -DincludeNonAffected=false -DclosureOption=PS1 -Dtest=${reduced_set} edu.cornell:emop-maven-plugin:1.0-SNAPSHOT:rps) &> ${OUTPUT_DIR}/logs/${sha}/${name}.log
            local status=$?
        else
            (time mvn ${MAVEN_OPTION} -DjavamopAgent=${EMOP_AGENT_ALL} -DincludeNonAffected=false -DclosureOption=PS1 edu.cornell:emop-maven-plugin:1.0-SNAPSHOT:rps) &> ${OUTPUT_DIR}/logs/${sha}/${name}.log
            local status=$?
        fi
        local end=$(date +%s%3N)
        duration=$((end - start))
        echo -n ",${duration},${status}" >> ${OUTPUT_DIR}/logs/results.csv
    fi
    
#   if [[ ${status} -ne 0 ]]; then
#       echo "ERROR: Unable to run ${name}"
#       exit 1
#   fi
    
    if [[ -d .starts ]]; then
        mv .starts .starts-${name}
    fi
    if [[ -f violation-counts ]]; then
        mv violation-counts ${OUTPUT_DIR}/logs/${sha}/violations/${name}
    fi
    unset MOP_AGENT_PATH
}

function run_imop {
    local sha=$1
    local reduced_set_file=$2
    if [[ ${reduced_set_file} != "" ]]; then
        local reduced_set=$(cat ${reduced_set_file} | sed -z '$ s/\n$//;s/\n/,/g')
        local name="reduced-imop"
    else
        local name="all-imop"
    fi
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    # Install special agent if needed
    if [[ ${DEINSTR} == "true" && ${reduced_set_file} != "" ]]; then
        install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${TMP_DIR}/${PROJECT_NAME}-agent "no-track-deinstr"
    else
        install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${TMP_DIR}/${PROJECT_NAME}-agent "no-track-all"
    fi
    
    echo "Running ${name}"

    if [[ -f ${OUTPUT_DIR}/logs/${sha}/all-emop.log && -n $(grep --text "No impacted classes" ${OUTPUT_DIR}/logs/${sha}/all-emop.log) && -z $(grep --text "Dependencies changed" ${OUTPUT_DIR}/logs/${sha}/all-emop.log) ]]; then
        duration=$(tail -n 1 ${OUTPUT_DIR}/logs/results.csv | rev | cut -d ',' -f 2 | rev)
        cp ${OUTPUT_DIR}/logs/${sha}/all-emop.log ${OUTPUT_DIR}/logs/${sha}/${name}.log
        local status=0
        echo -n ",${duration},${status}" >> ${OUTPUT_DIR}/logs/results.csv
    else
        export ARG_LINE=" -Daj.weaving.cache.enabled=true -Daj.weaving.cache.dir=${OUTPUT_DIR}/${name}"
        local start=$(date +%s%3N)
        if [[ ${reduced_set_file} != "" ]]; then
            (time mvn ${MAVEN_OPTION} -Dtest=${reduced_set} test) &> ${OUTPUT_DIR}/logs/${sha}/${name}.log
            local status=$?
        else
            (time mvn ${MAVEN_OPTION} test) &> ${OUTPUT_DIR}/logs/${sha}/${name}.log
            local status=$?
        fi
        local end=$(date +%s%3N)
        duration=$((end - start))
        echo -n ",${duration},${status}" >> ${OUTPUT_DIR}/logs/results.csv
    fi
    
    if [[ ${status} -ne 0 ]]; then
        echo "ERROR: Unable to run ${name}"
    fi
    
    if [[ -f violation-counts ]]; then
        mv violation-counts ${OUTPUT_DIR}/logs/${sha}/violations/${name}
    fi
    unset ARG_LINE
}

function run_redundant_tests {
    local sha=$1
    local reduced_set_file=$2
    local coverage=$3
    local all_minus_reduced_set=$(cat ${reduced_set_file} | sed 's/^/\!/g' | sed -z '$ s/\n$//;s/\n/,/g')
    if [[ ${coverage} != "true" ]]; then
        local name="redundant-tests"
    else
        local name="redundant-codecov"
    fi
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    export ADD_AGENT=0
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    echo "Running ${name}"
    
    local start=$(date +%s%3N)
    (time mvn ${MAVEN_OPTION} -Dtest=${all_minus_reduced_set} test) &> ${OUTPUT_DIR}/logs/${sha}/${name}.log
    local status=$?
    local end=$(date +%s%3N)
    duration=$((end - start))
    echo -n ",${duration},${status}" >> ${OUTPUT_DIR}/logs/results.csv
    if [[ ${status} -ne 0 ]]; then
        echo "ERROR: Unable to run ${name}"
    fi


    if [[ -f violation-counts ]]; then
        mv violation-counts ${OUTPUT_DIR}/logs/${sha}/violations/${name}
    fi
    unset ADD_AGENT
}

function run_ekstazi {
    local sha=$1
    local reduced_set_file=$2
    if [[ ${reduced_set_file} != "" ]]; then
        local reduced_set=$(cat ${reduced_set_file} | sed -z '$ s/\n$//;s/\n/,/g')
        local name="reduced-ekstazi"
    else
        local name="all-ekstazi"
    fi
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    # Install special agent if needed
    if [[ ${DEINSTR} == "true" && ${reduced_set_file} != "" ]]; then
        install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${TMP_DIR}/${PROJECT_NAME}-agent "no-track-deinstr"
    else
        install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${TMP_DIR}/${PROJECT_NAME}-agent "no-track-all"
    fi
    
    export SUREFIRE_VERSION="2.14"
    
    echo "Running ${name}"
    
    if [[ -d .ekstazi-${name} ]]; then
        mv .ekstazi-${name} .ekstazi
    fi
    
    local start=$(date +%s%3N)
    if [[ ${reduced_set_file} != "" && -f ${OUTPUT_DIR}/logs/${sha}/all-ekstazi.log && -n $(grep "Tests run: 0" ${OUTPUT_DIR}/logs/${sha}/all-ekstazi.log) ]]; then
        duration=$(tail -n 1 ${OUTPUT_DIR}/logs/results.csv | rev | cut -d ',' -f 2 | rev)
        cp ${OUTPUT_DIR}/logs/${sha}/all-ekstazi.log ${OUTPUT_DIR}/logs/${sha}/${name}.log
        local status=0
        echo -n ",${duration},${status}" >> ${OUTPUT_DIR}/logs/results.csv
    else
        if [[ ${reduced_set_file} != "" ]]; then
            (time mvn ${MAVEN_OPTION} -DfailIfNoTests=false -Dtest=${reduced_set} org.ekstazi:ekstazi-maven-plugin:5.3.0:ekstazi) &> ${OUTPUT_DIR}/logs/${sha}/${name}.log
            local status=$?
        else
            (time mvn ${MAVEN_OPTION} -DfailIfNoTests=false org.ekstazi:ekstazi-maven-plugin:5.3.0:ekstazi) &> ${OUTPUT_DIR}/logs/${sha}/${name}.log
            local status=$?
        fi
        local end=$(date +%s%3N)
        duration=$((end - start))
        echo -n ",${duration},${status}" >> ${OUTPUT_DIR}/logs/results.csv
    fi
    
    if [[ ${status} -ne 0 ]]; then
        echo "ERROR: Unable to run ${name}"
    fi
    
    if [[ -d .ekstazi ]]; then
        mv .ekstazi .ekstazi-${name}
    fi
    if [[ -f violation-counts ]]; then
        mv violation-counts ${OUTPUT_DIR}/logs/${sha}/violations/${name}
    fi
    unset SUREFIRE_VERSION
}

function main() {
    clone_project
    
    echo -n "sha" > ${OUTPUT_DIR}/logs/results.csv
    echo -n ",test,status" >> ${OUTPUT_DIR}/logs/results.csv
    echo -n ",all_javamop_all_specs,status" >> ${OUTPUT_DIR}/logs/results.csv
    echo -n ",reduced_javamop_all_specs,status" >> ${OUTPUT_DIR}/logs/results.csv
    echo -n ",redundant_tests,status" >> ${OUTPUT_DIR}/logs/results.csv
    echo -n ",all_emop,status" >> ${OUTPUT_DIR}/logs/results.csv
    echo -n ",reduced_emop,status" >> ${OUTPUT_DIR}/logs/results.csv
    echo -n ",all_imop,status" >> ${OUTPUT_DIR}/logs/results.csv
    echo -n ",reduced_imop,status" >> ${OUTPUT_DIR}/logs/results.csv
    echo -n ",all_ekstazi,status" >> ${OUTPUT_DIR}/logs/results.csv
    echo -n ",reduced_ekstazi,status" >> ${OUTPUT_DIR}/logs/results.csv
    if [[ -n ${COV_TESTS} ]]; then
        echo -n ",reduced_codecov,status" >> ${OUTPUT_DIR}/logs/results.csv
        echo -n ",redundant_codecov,status" >> ${OUTPUT_DIR}/logs/results.csv
    fi
    echo "" >> ${OUTPUT_DIR}/logs/results.csv

    pushd ${OUTPUT_DIR}/project &> /dev/null
    for sha in $(tac ${SHA_FILE}); do
        echo "Running SHA ${sha}"
        git checkout ${sha} &> /dev/null
        mkdir -p ${OUTPUT_DIR}/logs/${sha}/violations

        echo -n "${sha}" >> ${OUTPUT_DIR}/logs/results.csv
        compileAndTestAllWithoutRV ${sha}

        run_all_javamop_all_specs "${sha}"
        run_reduced_javamop_all_specs "${sha}" "${TESTS}"
        
        run_redundant_tests "${sha}" "${TESTS}"
        
        # Must run together vvv
        run_emop "${sha}"
        run_emop "${sha}" "${TESTS}"
        
        run_imop "${sha}"
        run_imop "${sha}" "${TESTS}"
        
        run_ekstazi "${sha}"
        run_ekstazi "${sha}" "${TESTS}"
        # Must run together ^^^
        
        if [[ -n ${COV_TESTS} ]]; then
            run_reduced_javamop_all_specs "${sha}" "${COV_TESTS}" true
            run_redundant_tests "${sha}" "${COV_TESTS}" true
        fi

        echo "" >> ${OUTPUT_DIR}/logs/results.csv
    done
    popd &> /dev/null
}

echo "TSM version: ($(git rev-parse HEAD) - $(date +%s))"

build_emop_and_imop
main
