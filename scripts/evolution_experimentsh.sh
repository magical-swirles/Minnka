#!/bin/bash
#
# This is a proof of concept script to test different notions of equivalence.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PARALLEL="false"
while getopts :p:s:a:t:r:e: opts; do
    case "${opts}" in
        p ) PROJECT_NAME="${OPTARG}" ;;
        s ) SHA_FILE="${OPTARG}" ;;
        a ) PARALLEL="${OPTARG}" ;; # SEQ OR PAR
        t ) TIEBREAKER="${OPTARG}" ;; # none or time
        r ) ALGORITHM="${OPTARG}" ;; # greedy, ge, gre, or hgs
        e ) REDUCTION_SCHEME="${OPTARG}" ;;
    esac
done
shift $((${OPTIND} - 1))

PROJECT_DIR=$1
REPO_DIR=$2

source ${SCRIPT_DIR}/../experiments/constants.sh

if [[ ! -d ${PROJECT_DIR} || ! -d ${REPO_DIR} ]]; then
    echo "Cannot find ${PROJECT_DIR} or ${REPO_DIR}"
    rm -rf ${PROJECT_DIR} ${REPO_DIR}
    name=$(echo ${repo} | tr / -)
    git clone https://github.com/${PROJECT_NAME} ${PROJECT_DIR}
    pushd ${PROJECT_DIR} &> /dev/null
    popd &> /dev/null
fi

if [[ ! -f ${SHA_FILE} ]]; then
    echo "Cannot find file ${SHA_FILE}"
    exit 1
fi

if [[ -z ${REDUCTION_SCHEME} ]]; then
    REDUCTION_SCHEME="perfect"
fi

if [[ -z ${TIEBREAKER} ]]; then
    TIEBREAKER="none"
fi

if [[ -z ${ALGORITHM} ]]; then
    ALGORITHM="greedy"
fi

MAVEN_OPTION="-Dmaven.repo.local=${REPO_DIR}"
MODE="all"


# SETUP
echo "REDUCTION_SCHEME: ${REDUCTION_SCHEME}"
echo "TIEBREAKER: ${TIEBREAKER}"
echo "ALGORITHM: ${ALGORITHM}"

export MAVEN_OPTS="${MAVEN_OPTS} -Xmx500g -XX:-UseGCOverheadLimit -Dmaven.ext.class.path=${SCRIPT_DIR}/../extensions/junit-extension-1.0.jar"
export RVMLOGGINGLEVEL=UNIQUE
JAVAMOP_AGENT="${SCRIPT_DIR}/../mop/agents/no-track-agent.jar"
EMOP_AGENT="${SCRIPT_DIR}/../mop/agents/emop-no-track-agent.jar"
EMOP_AGENT_2="${SCRIPT_DIR}/../mop/agents/emop-no-track-agent-2.jar"
cp ${JAVAMOP_AGENT} ${EMOP_AGENT}
cp ${JAVAMOP_AGENT} ${EMOP_AGENT_2}

function build_emop_and_imop() {
    pushd ${SCRIPT_DIR} &> /dev/null

    if [[ ! -d emop ]]; then
        git clone https://github.com/SoftEngResearch/emop &>> ${PROJECT_DIR}/logs/setup-log.txt
        cd emop
        local old_MAVEN_OPTS=${MAVEN_OPTS}
        export MAVEN_OPTS="${MAVEN_OPTS} -Dmaven.repo.local=${REPO_DIR}"
        bash scripts/install-starts.sh &>> ${PROJECT_DIR}/logs/setup-log.txt
        export MAVEN_OPTS=${old_MAVEN_OPTS}
    else
        cd emop
    fi

    # Remove raw specs
    pushd emop-maven-plugin/src/main/resources/weaved-specs/ &> /dev/null
        comm -23 <(ls | sed "s/MonitorAspect.aj//g" | sort) <(ls ${SCRIPT_DIR}/../mop/renamed_props | cut -d '.' -f 1 | sort) | xargs -I {} rm {}MonitorAspect.aj
    popd &> /dev/null

    # Install eMOP
    mvn ${MAVEN_OPTION} clean install -Dcheckstyle.skip &>> ${PROJECT_DIR}/logs/setup-log.txt
    popd &> /dev/null
}

function compileAndTestAllWithoutRV() {
    local sha=$1

    echo "[TSM] Compiling"
    mvn ${MAVEN_OPTION} clean test-compile "${SKIP}" &> logs/${sha}/compile-log.txt
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Unable to compile"
        exit 1
    fi

    echo "[TSM] Running test to download dependencies"
    mvn ${MAVEN_OPTION} surefire:3.5.2:test &> logs/${sha}/surefire-init-log.txt
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Unable to download dependencies"
        exit 1
    fi

    # Need to run twice because the first time might contain downloading times
    echo "[TSM] Measuring test time"
    local start=$(date +%s%3N)
    mvn ${MAVEN_OPTION} surefire:3.5.2:test &> logs/${sha}/surefire-log.txt
    local status=$?
    local end=$(date +%s%3N)
    duration=$((end - start))
    echo -n ",${duration},${status}" >> logs/results.csv
    
    if [[ ${status} -ne 0 ]]; then
        echo "ERROR: Unable to run test"
        exit 1
    fi
}

# Given file, return tests
# $(cat ${tests_file} | sed -z '$ s/\n$//;s/\n/,/g')

function run_reduced_with_JavaMOP() {
    local sha=$1
    local reduced_set_file=$2
    local reduced_set=$(cat ${reduced_set_file} | sed -z '$ s/\n$//;s/\n/,/g')
    
    git restore .
    mvn ${MAVEN_OPTION} clean test-compile "${SKIP}" &> /dev/null
    
    echo "[TSM] Running reduced with JavaMOP"
    echo "> (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -DargLine=-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${JAVAMOP_AGENT} -Dtest=${reduced_set}) &> logs/${sha}/reduced-javamop-log.txt"
    
    local start=$(date +%s%3N)
    (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -DargLine="-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${JAVAMOP_AGENT}" -Dtest=${reduced_set}) &> logs/${sha}/reduced-javamop-log.txt
    local status=$?
    local end=$(date +%s%3N)
    duration=$((end - start))
    echo -n ",${duration},${status}" >> logs/results.csv
    if [[ ${status} -ne 0 ]]; then
        echo "ERROR: Unable to run_reduced_with_JavaMOP"
        exit 1
    fi
    
    if [ -f "violation-counts" ]; then
        mv violation-counts logs/${sha}/violations/violation-counts-reduced-javamop
    fi
}

function run_reduced_with_eMOP {
    local sha=$1
    local reduced_set_file=$2
    local reduced_set=$(cat ${reduced_set_file} | sed -z '$ s/\n$//;s/\n/,/g')
    
    git restore .
    mvn ${MAVEN_OPTION} clean test-compile "${SKIP}" &> /dev/null
    
    echo "[TSM] Running eMOP with reduced set"
    echo "> (time mvn edu.cornell:emop-maven-plugin:1.0-SNAPSHOT:rps ${MAVEN_OPTION} -DargLine=\"-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${EMOP_AGENT}\" -DjavamopAgent=${EMOP_AGENT} -DincludeNonAffected=false -DclosureOption=PS1 -Dtest=${reduced_set}) &> logs/${sha}/reduced-emop-log.txt"

    if [[ -d .starts-reduced ]]; then
        mv .starts-reduced .starts
    fi
    
    local start=$(date +%s%3N)
    (time mvn edu.cornell:emop-maven-plugin:1.0-SNAPSHOT:rps ${MAVEN_OPTION} -DargLine="-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${EMOP_AGENT}" -DjavamopAgent=${EMOP_AGENT} -DincludeNonAffected=false -DclosureOption=PS1 -Dtest=${reduced_set}) &> logs/${sha}/reduced-emop-log.txt
    local status=$?
    local end=$(date +%s%3N)
    duration=$((end - start))
    echo -n ",${duration},${status}" >> logs/results.csv
    if [[ ${status} -ne 0 ]]; then
        echo "ERROR: Unable to run_reduced_with_eMOP"
        exit 1
    fi
    
    if [[ -d .starts ]]; then
        mv .starts .starts-reduced
    fi
    if [ -f "violation-counts" ]; then
        mv violation-counts logs/${sha}/violations/violation-counts-reduced-emop
    fi
}

function run_reduced_with_iMOP {
    local sha=$1
    local reduced_set_file=$2
    local reduced_set=$(cat ${reduced_set_file} | sed -z '$ s/\n$//;s/\n/,/g')
    
    git restore .
    mvn ${MAVEN_OPTION} clean test-compile "${SKIP}" &> /dev/null
    
    echo "[TSM] Running reduced with iMOP"
    echo "> (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -DargLine=\"-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${JAVAMOP_AGENT} -Daj.weaving.cache.enabled=true -Daj.weaving.cache.dir=.rvtsm/imop-reduced\" -Dtest=${reduced_set}) &> logs/${sha}/reduced-imop-log.txt"
    
    local start=$(date +%s%3N)
    (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -DargLine="-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${JAVAMOP_AGENT} -Daj.weaving.cache.enabled=true -Daj.weaving.cache.dir=.rvtsm/imop-reduced" -Dtest=${reduced_set}) &> logs/${sha}/reduced-imop-log.txt
    local status=$?
    local end=$(date +%s%3N)
    duration=$((end - start))
    echo -n ",${duration},${status}" >> logs/results.csv
    if [[ ${status} -ne 0 ]]; then
        echo "ERROR: Unable to run_reduced_with_iMOP"
        exit 1
    fi
    
    if [ -f "violation-counts" ]; then
        mv violation-counts logs/${sha}/violations/violation-counts-reduced-imop
    fi
}

function run_all_minus_reduced_without_RV {
    local sha=$1
    local reduced_set_file=$2
    local all_minus_reduced_set=$(cat ${reduced_set_file} | sed 's/^/\!/g' | sed -z '$ s/\n$//;s/\n/,/g')
    
    git restore .
    mvn ${MAVEN_OPTION} clean test-compile "${SKIP}" &> /dev/null
    
    echo "[TSM] Running all minus reduced set without RV"
    echo "> (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -Dtest=${all_minus_reduced_set}) &> logs/${sha}/all-minus-reduced-no-rv-log.txt"
    
    local start=$(date +%s%3N)
    (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -Dtest=${all_minus_reduced_set}) &> logs/${sha}/all-minus-reduced-no-rv-log.txt
    local status=$?
    local end=$(date +%s%3N)
    duration=$((end - start))
    echo -n ",${duration},${status}" >> logs/results.csv
    if [[ ${status} -ne 0 ]]; then
        echo "ERROR: Unable to run_all_minus_reduced_without_RV"
        exit 1
    fi


    if [ -f "violation-counts" ]; then
        mv violation-counts logs/${sha}/violations/violation-counts-redundant-norv
    fi
}

function run_partial_reduced_with_JavaMOP {
    local sha=$1
    local partial_reduced_set_file=$2
    
    if [[ -s ${partial_reduced_set_file} ]]; then
        local partial_reduced_set=$(cat ${partial_reduced_set_file} | sed -z '$ s/\n$//;s/\n/,/g')
        
        git restore .
        mvn ${MAVEN_OPTION} clean test-compile "${SKIP}" &> /dev/null
        
        echo "[TSM] Running partial reduced set with JavaMOP"
        echo "> (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -DargLine=\"-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${JAVAMOP_AGENT}\" -Dtest=${partial_reduced_set}) &> logs/${sha}/partial-reduced-javamop-log.txt"
        
        local start=$(date +%s%3N)
        (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -DargLine="-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${JAVAMOP_AGENT}" -Dtest=${partial_reduced_set}) &> logs/${sha}/partial-reduced-javamop-log.txt
        local status=$?
        local end=$(date +%s%3N)
        duration=$((end - start))
        echo -n ",${duration},${status}" >> logs/results.csv
        if [[ ${status} -ne 0 ]]; then
            echo "ERROR: Unable to run_partial_reduced_with_JavaMOP"
            exit 1
        fi
    
        if [ -f "violation-counts" ]; then
            mv violation-counts logs/${sha}/violations/violation-counts-partial-reduced-javamop
        fi
    else
        echo "[TSM] Skipping partial reduced set with JavaMOP"
        echo -n ",0,0" >> logs/results.csv
    fi
}

function run_all_minus_partial_without_RV {
    local sha=$1
    local partial_reduced_set_file=$2
    if [[ -s ${partial_reduced_set_file} ]]; then
        local all_minus_partial_set=$(cat ${partial_reduced_set_file} | sed 's/^/\!/g' | sed -z '$ s/\n$//;s/\n/,/g')
        
        git restore .
        mvn ${MAVEN_OPTION} clean test-compile "${SKIP}" &> /dev/null
        
        echo "[TSM] Running all minus partial set without RV"
        echo "> (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -Dtest=${all_minus_partial_set}) &> logs/${sha}/all-minus-partial-no-rv-log.txt"
        
        local start=$(date +%s%3N)
        (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -Dtest=${all_minus_partial_set}) &> logs/${sha}/all-minus-partial-no-rv-log.txt
        local status=$?
        local end=$(date +%s%3N)
        duration=$((end - start))
        echo -n ",${duration},${status}" >> logs/results.csv
        if [[ ${status} -ne 0 ]]; then
            echo "ERROR: Unable to run_all_minus_partial_without_RV"
            exit 1
        fi
        
        if [ -f "violation-counts" ]; then
            mv violation-counts logs/${sha}/violations/violation-counts-partial-norv
        fi
    else
        echo "[TSM] Skipping all minus partial set without RV"
        echo -n ",0,0" >> logs/results.csv
    fi
}

function run_all_with_JavaMOP {
    local sha=$1
    
    git restore .
    mvn ${MAVEN_OPTION} clean test-compile "${SKIP}" &> /dev/null
    
    echo "[TSM] Running all with JavaMOP"
    echo "> (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -DargLine=\"-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${JAVAMOP_AGENT}\") &> logs/${sha}/all-javamop-log.txt"
    
    local start=$(date +%s%3N)
    (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -DargLine="-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${JAVAMOP_AGENT}") &> logs/${sha}/all-javamop-log.txt
    local status=$?
    local end=$(date +%s%3N)
    duration=$((end - start))
    echo -n ",${duration},${status}" >> logs/results.csv
    if [[ ${status} -ne 0 ]]; then
        echo "ERROR: Unable to run_all_with_JavaMOP"
        exit 1
    fi

    if [ -f "violation-counts" ]; then
        mv violation-counts logs/${sha}/violations/violation-counts-all-javamop
    fi
}

function run_all_with_eMOP {
    local sha=$1
    
    git restore .
    mvn ${MAVEN_OPTION} clean test-compile "${SKIP}" &> /dev/null
    
    echo "[TSM] Running all with JavaMOP"
    echo "> (time mvn edu.cornell:emop-maven-plugin:1.0-SNAPSHOT:rps ${MAVEN_OPTION} -DargLine=\"-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${EMOP_AGENT_2}\" -DjavamopAgent=${EMOP_AGENT_2} -DincludeNonAffected=false -DclosureOption=PS1) &> logs/${sha}/all-emop-log.txt"
    
    if [[ -d .starts-all ]]; then
        mv .starts-all .starts
    fi
    
    local start=$(date +%s%3N)
    (time mvn edu.cornell:emop-maven-plugin:1.0-SNAPSHOT:rps ${MAVEN_OPTION} -DargLine="-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${EMOP_AGENT_2}" -DjavamopAgent=${EMOP_AGENT_2} -DincludeNonAffected=false -DclosureOption=PS1) &> logs/${sha}/all-emop-log.txt
    local status=$?
    local end=$(date +%s%3N)
    duration=$((end - start))
    echo -n ",${duration},${status}" >> logs/results.csv
    if [[ ${status} -ne 0 ]]; then
        echo "ERROR: Unable to run_all_with_eMOP"
        exit 1
    fi

    if [[ -d .starts ]]; then
        mv .starts .starts-all
    fi
    if [ -f "violation-counts" ]; then
        mv violation-counts logs/${sha}/violations/violation-counts-all-emop
    fi
}

function run_all_with_iMOP {
    local sha=$1
    
    git restore .
    mvn ${MAVEN_OPTION} clean test-compile "${SKIP}" &> /dev/null
    
    echo "[TSM] Running all with iMOP"
    echo "> (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -DargLine=\"-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${JAVAMOP_AGENT} -Daj.weaving.cache.enabled=true -Daj.weaving.cache.dir=.rvtsm/imop-all\") &> logs/${sha}/all-imop-log.txt"
    
    local start=$(date +%s%3N)
    (time mvn surefire:3.5.2:test ${MAVEN_OPTION} -DargLine="-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${JAVAMOP_AGENT} -Daj.weaving.cache.enabled=true -Daj.weaving.cache.dir=.rvtsm/imop-all") &> logs/${sha}/all-imop-log.txt
    local status=$?
    local end=$(date +%s%3N)
    duration=$((end - start))
    echo -n ",${duration},${status}" >> logs/results.csv
    if [[ ${status} -ne 0 ]]; then
        echo "ERROR: Unable to run_all_with_iMOP"
        exit 1
    fi

    if [ -f "violation-counts" ]; then
        mv violation-counts logs/${sha}/violations/violation-counts-all-imop
    fi
}

function run_rts_with_JavaMOP {
    local sha=$1
    run_ekstazi_with_JavaMOP ${sha}
}

function run_ekstazi_with_JavaMOP {
    local sha=$1

    git restore .
    mvn ${MAVEN_OPTION} clean test-compile "${SKIP}" &> /dev/null
    export SUREFIRE_VERSION="2.14"
    
    echo "[TSM] Running Ekstazi with JavaMOP"
    echo "> (time mvn org.ekstazi:ekstazi-maven-plugin:5.3.0:ekstazi -DargLine=\"-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${JAVAMOP_AGENT}\") &> logs/${sha}/ekstazi-javamop-log.txt"
    
    local start=$(date +%s%3N)
    (time mvn org.ekstazi:ekstazi-maven-plugin:5.3.0:ekstazi ${MAVEN_OPTION} -DargLine="-Xmx500g -XX:-UseGCOverheadLimit -javaagent:${JAVAMOP_AGENT}") &> logs/${sha}/ekstazi-javamop-log.txt
    local status=$?
    local end=$(date +%s%3N)
    duration=$((end - start))
    echo -n ",${duration},${status}" >> logs/results.csv
    if [[ ${status} -ne 0 ]]; then
        echo "ERROR: Unable to run_ekstazi_with_JavaMOP"
        exit 1
    fi
    if [ -f "violation-counts" ]; then
        mv violation-counts logs/${sha}/violations/violation-counts-ekstazi-javamop
    fi
    unset SUREFIRE_VERSION
}

function main() {
    pushd ${PROJECT_DIR} &> /dev/null
    local first_sha="true"
    for sha in $(cat ${SHA_FILE}); do
        echo "[TSM] Running SHA ${sha}"
        git checkout ${sha} &> /dev/null
        mkdir -p logs/${sha}/violations
        # Test all without RV
        
        echo -n "${sha}" >> logs/results.csv
        compileAndTestAllWithoutRV ${sha}

        if [[ ${MODE} != "ekstazi" ]]; then
            if [[ ${first_sha} == "true" ]]; then
                echo "[TSM] Running TSM on the first SHA ${sha}"
                # Run TSM on the first SHA, using the input config (both full and partial)
                # Reduce with full
                mvn -l logs/reduce-log.txt org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:reduce ${MAVEN_OPTION} -DparallelCollection=${PARALLEL} -Dalgorithm=${ALGORITHM} -DmatrixReductionScheme=${REDUCTION_SCHEME} -Dtiebreaker=${TIEBREAKER} -DreducedSet=.rvtsm/reduced.txt -DredundantAndNoTraceSet=.rvtsm/redundant-and-no-trace.txt -Dmatrix=.rvtsm/tests.csv
                # Reduce with partial
                mvn -l logs/partial-reduce-log.txt org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:reduce ${MAVEN_OPTION} -DparallelCollection=${PARALLEL} -Dalgorithm=${ALGORITHM} -DmatrixReductionScheme=violation-${REDUCTION_SCHEME} -Dtiebreaker=${TIEBREAKER} -DreducedSet=.rvtsm/partial-reduced.txt -DredundantAndNoTraceSet=.rvtsm/partial-redundant-and-no-trace.txt -Dmatrix=.rvtsm/reduced-tests.csv
            fi
            first_sha=false
            
            # Non-Ekstazi run
            run_reduced_with_JavaMOP "${sha}" ".rvtsm/reduced.txt"
            run_reduced_with_eMOP "${sha}" ".rvtsm/reduced.txt"
            run_reduced_with_iMOP "${sha}" ".rvtsm/reduced.txt"
            run_all_minus_reduced_without_RV "${sha}" ".rvtsm/reduced.txt"
            run_partial_reduced_with_JavaMOP "${sha}" ".rvtsm/partial-reduced.txt"
            run_all_minus_partial_without_RV "${sha}" ".rvtsm/partial-reduced.txt"
            run_all_with_JavaMOP "${sha}"
            run_all_with_eMOP "${sha}"
            run_all_with_iMOP "${sha}"
        fi
        
        # Ekstazi run
        run_ekstazi_with_JavaMOP "${sha}"
        
        echo "" >> logs/results.csv
    done
    popd &> /dev/null
}

echo "TSM version: ($(git rev-parse HEAD) - $(date +%s))"

echo "[TSM] Installing Maven plugin..."
mkdir -p ${PROJECT_DIR}/logs
pushd ${SCRIPT_DIR}/../rvtsm-maven-plugin &> /dev/null
mvn ${MAVEN_OPTION} install -DskipTests &>> ${PROJECT_DIR}/logs/setup-log.txt
popd &> /dev/null

build_emop_and_imop

export JUNIT_TEST_LISTENER=2
main