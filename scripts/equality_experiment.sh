#!/bin/bash
#
# This is a proof of concept script to test different notions of equivalence.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PARALLEL="false"
while getopts :p:s:a:t:r: opts; do
    case "${opts}" in
        p ) PROJECT_NAME="${OPTARG}" ;;
        s ) SHA="${OPTARG}" ;;
        a ) PARALLEL="${OPTARG}" ;; # SEQ OR PAR
        t ) TIEBREAKER="${OPTARG}" ;; # none or time
        r ) ALGORITHM="${OPTARG}" ;; # greedy, ge, gre, or hgs
    esac
done
shift $((${OPTIND} - 1))

PROJECT_DIR=$1
REPO_DIR=$2
REDUCTION_SCHEMES=$3
RV_CONFIGS=$4
CONFIGURATIONS=()

source ${SCRIPT_DIR}/../experiments/constants.sh

if [[ ! -d ${PROJECT_DIR} || ! -d ${REPO_DIR} ]]; then
    echo "Cannot find ${PROJECT_DIR} or ${REPO_DIR}"
    rm -rf ${PROJECT_DIR} ${REPO_DIR}
    name=$(echo ${repo} | tr / -)
    git clone https://github.com/${PROJECT_NAME} ${PROJECT_DIR}
    pushd ${PROJECT_DIR} &> /dev/null
    git checkout ${SHA}
    popd &> /dev/null
    
    if [[ -f ${SCRIPT_DIR}/../experiments/treat_special.sh ]]; then
        # Run treat_special script
        bash ${SCRIPT_DIR}/../experiments/treat_special.sh ${PROJECT_DIR} ${PROJECT_NAME}
    fi
fi

if [[ -z ${REDUCTION_SCHEMES} ]]; then
    REDUCTION_SCHEMES=(all perfect state prefix online_detour state-online_detour-prefix)
else
    IFS=',' read -ra REDUCTION_SCHEMES <<< "${REDUCTION_SCHEMES}"
fi

if [[ -z ${RV_CONFIGS} ]]; then
    RV_CONFIGS=(no-track no-rv)
else
    IFS=',' read -ra RV_CONFIGS <<< "${RV_CONFIGS}"
fi

if [[ -z ${TIEBREAKER} ]]; then
    TIEBREAKER=(none)
else
    IFS=',' read -ra TIEBREAKER <<< "${TIEBREAKER}"
fi

if [[ -z ${ALGORITHM} ]]; then
    ALGORITHM=(greedy)
else
    IFS=',' read -ra ALGORITHM <<< "${ALGORITHM}"
fi

MVN_OPTIONS=""
if [[ ${PARALLEL} == "true" ]]; then
    MVN_OPTIONS="-DparallelCollection=true"
fi

echo "REDUCTION_SCHEMES: ${REDUCTION_SCHEMES[@]}"
echo "RV_CONFIGS: ${RV_CONFIGS[@]}"

function get_matrix() {
    local reduction=$1 # Can be state, perfect, etc.
    local tiebreaker=$2
    local algorithm=$3
    local config="${reduction}-${tiebreaker}-${algorithm}"
    if [[ ${tiebreaker} == "none" && ${algorithm} == "greedy" ]]; then
        config="${reduction}"
    fi
    echo "[TSM] Generating matrix for ${config}"
    mkdir -p logs
    echo "> mvn -l logs/${config}-reduce-log.txt -Dmaven.repo.local=${REPO_DIR} org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:reduce -DartifactDir=.rvtsm -DmatrixReductionScheme=${config} -DtestMethodList=${PROJECT_DIR}/tests.txt -Dmatrix=.rvtsm/${config}-matrix.csv -DreducedSet=.rvtsm/${config}-reduced.txt -DredundantAndNoTraceSet=.rvtsm/${config}-redundant-and-no-trace.txt -DlogDir=./rvtsm/logs -DallTracesDir=${PROJECT_DIR}/.all-traces -Dtiebreaker=${tiebreaker} -Dalgorithm=${algorithm} ${MVN_OPTIONS}"
    mvn -l logs/${config}-reduce-log.txt -Dmaven.repo.local=${REPO_DIR} org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:reduce -DartifactDir=.rvtsm -DmatrixReductionScheme=${config} -DtestMethodList=${PROJECT_DIR}/tests.txt -Dmatrix=.rvtsm/${config}-matrix.csv -DreducedSet=.rvtsm/${config}-reduced.txt -DredundantAndNoTraceSet=.rvtsm/${config}-redundant-and-no-trace.txt -DlogDir=./rvtsm/logs -DallTracesDir=${PROJECT_DIR}/.all-traces -Dtiebreaker=${tiebreaker} -Dalgorithm=${algorithm} ${MVN_OPTIONS}
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Unable to generate matrix"
        exit 1
    fi
}

function main() {
    pushd ${PROJECT_DIR}
    # Decompress unique traces
    if [[ ! -f "${PROJECT_DIR}/.all-traces/unique-traces.txt" && -f "${PROJECT_DIR}/.all-traces/unique-traces.txt.gz" ]]; then
        pushd ${PROJECT_DIR}/.all-traces &> /dev/null
        gunzip unique-traces.txt.gz
        popd &> /dev/null
    else
        mkdir -p .rvtsm/all-traces
        for t in $(ls ${PROJECT_DIR}/.all-traces); do
            if [[ ! -f "${PROJECT_DIR}/.all-traces/${t}/unique-traces.txt" && -f "${PROJECT_DIR}/.all-traces/${t}/unique-traces.txt.gz" ]]; then
                pushd ${PROJECT_DIR}/.all-traces/${t} &> /dev/null
                gunzip unique-traces.txt.gz
                popd &> /dev/null
            fi
        done
    fi
    
    mkdir -p logs

    export MAVEN_OPTS="${MAVEN_OPTS} -Xmx500g -XX:-UseGCOverheadLimit"

    echo "[TSM] Compiling"
    mvn -l logs/compile-log.txt -Dmaven.repo.local=${REPO_DIR} ${SKIP} clean test-compile
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Unable to compile"
        exit 1
    fi

    echo "[TSM] Running test to download dependencies"
    mvn -l logs/surefire-init-log.txt -Dmaven.repo.local=${REPO_DIR} ${SKIP} surefire:3.5.2:test
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Unable to download dependencies"
        exit 1
    fi

    # Need to run twice because the first time might contain downloading times
    echo "[TSM] Measuring test time"
    mvn -l logs/surefire-log.txt -Dmaven.repo.local=${REPO_DIR} ${SKIP} surefire:3.5.2:test
    if [[ $? -ne 0 ]]; then
        echo "ERROR: Unable to run test"
        exit 1
    fi

    for reduction in "${REDUCTION_SCHEMES[@]}"; do
        for tiebreaker in "${TIEBREAKER[@]}"; do
            for algorithm in "${ALGORITHM[@]}"; do
                if [[ ${tiebreaker} == "none" && ${algorithm} == "greedy" ]]; then
                    CONFIGURATIONS+=("${reduction}")
                else
                    CONFIGURATIONS+=("${reduction}-${tiebreaker}-${algorithm}")
                fi
                if [ "${reduction}" != "all" ]; then
                    get_matrix ${reduction} ${tiebreaker} ${algorithm}
                fi
            done
        done
    done
    # Run four configs
    for rvconfig in "${RV_CONFIGS[@]}"; do
        for reduction in "${REDUCTION_SCHEMES[@]}"; do
            for tiebreaker in "${TIEBREAKER[@]}"; do
                for algorithm in "${ALGORITHM[@]}"; do
                    local configuration="${reduction}-${tiebreaker}-${algorithm}"
                    local full_label="${configuration}-reduced-${rvconfig}"
                    if [[ ${tiebreaker} == "none" && ${algorithm} == "greedy" ]]; then
                        full_label="${reduction}-reduced-${rvconfig}"
                        configuration="${reduction}"
                    fi

                    # Skip if the set of reduced tests is the same as another run that already has results
                    local skip=false
                    for other_configuration in "${CONFIGURATIONS[@]}"; do
                        if [[ "${configuration}" == "all"* || "${other_configuration}" == "all"* ]]; then
                            continue
                        fi

                        if [ "${configuration}" != "${other_configuration}" ]; then
                            diff <(sort .rvtsm/${configuration}-reduced.txt) <(sort .rvtsm/${other_configuration}-reduced.txt) &> /dev/null
                            # Make sure that the set are the same and the other run has already completed
                            if [ $? -eq 0 ] && [ -f logs/${other_configuration}-reduced-${rvconfig}-log.txt ]; then
                                echo "[TSM] Skipping ${rvconfig} for ${configuration} (same test set as ${other_configuration})"
                                
                                skip=true
                                cp logs/${other_configuration}-reduced-${rvconfig}-log.txt logs/${full_label}-log.txt
                                cp .rvtsm/${other_configuration}-reduced.txt .rvtsm/${configuration}-reduced.txt
                                cp .rvtsm/${other_configuration}-redundant-and-no-trace.txt .rvtsm/${configuration}-redundant-and-no-trace.txt
                                
                                if [[ -f .rvtsm/violation-counts-${other_configuration}-reduced-${rvconfig} ]]; then
                                    cp .rvtsm/violation-counts-${other_configuration}-reduced-${rvconfig} .rvtsm/violation-counts-${full_label}
                                fi

                                if [[ -d .rvtsm/scr-${other_configuration}-reduced-${rvconfig}-traces ]]; then
                                    cp -r .rvtsm/scr-${other_configuration}-reduced-${rvconfig}-traces .rvtsm/scr-${full_label}-traces
                                fi
                                break
                            fi
                        fi
                    done
                    if [ "${skip}" = true ]; then
                        continue
                    fi

                    echo "[TSM] Running ${rvconfig} for ${configuration}"
                    echo "> mvn -l logs/${full_label}-log.txt -Dmaven.repo.local=${REPO_DIR} org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:scr -DskipAllPreviousSteps=true -DtestMethodsToRun=.rvtsm/${configuration}-reduced.txt -DrvConfig=${rvconfig} -DrunLabel=${full_label} ${MVN_OPTIONS}"
                    mvn -l logs/${full_label}-log.txt -Dmaven.repo.local=${REPO_DIR} org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:scr -DskipAllPreviousSteps=true -DtestMethodsToRun=.rvtsm/${configuration}-reduced.txt -DrvConfig=${rvconfig} -DrunLabel=${full_label} ${MVN_OPTIONS}
                    if [[ $? -ne 0 ]]; then
                        echo "ERROR: Unable to run ${rvconfig} for ${configuration}"
                        exit 1
                    fi
                    
                    if [ -f "violation-counts" ]; then
                        mv violation-counts .rvtsm/violation-counts-${full_label}
                    fi
                    
                    if [[ ${rvconfig} == "no-rv" && ${configuration} != "all"* ]]; then
                        local full_label="${configuration}-redundant-and-no-trace-${rvconfig}"
                        
                        echo "[TSM] Running no-rv for ${configuration} (redundant and no trace)"
                        echo "mvn -l logs/${full_label}-log.txt -Dmaven.repo.local=${REPO_DIR} org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:scr -DskipAllPreviousSteps=true -DtestMethodsToRun=.rvtsm/${configuration}-redundant-and-no-trace.txt -DrvConfig=${rvconfig} -DrunLabel=${full_label}"
                        
                        mvn -l logs/${full_label}-log.txt -Dmaven.repo.local=${REPO_DIR} org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:scr -DskipAllPreviousSteps=true -DtestMethodsToRun=.rvtsm/${configuration}-redundant-and-no-trace.txt -DrvConfig=${rvconfig} -DrunLabel=${full_label} ${MVN_OPTIONS}
                        if [[ $? -ne 0 ]]; then
                            echo "ERROR: Unable to run no-rv for ${configuration} (redundant and no trace)"
                            exit 1
                        fi
                    fi
                done
            done
        done
    done
    popd
}

echo "TSM version: ($(git rev-parse HEAD) - $(date +%s))"

echo "[TSM] Installing Maven plugin..."
pushd ${SCRIPT_DIR}/../rvtsm-maven-plugin &> /dev/null
mvn -Dmaven.repo.local=${REPO_DIR} install -DskipTests &> /dev/null
popd &> /dev/null

main
