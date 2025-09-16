#!/bin/bash
#
# This is a proof of concept script to test different notions of equivalence.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REDUCTION_SCHEMES=(all perfect state prefix online_detour state-online_detour-prefix)
RV_CONFIGS=(no-track no-rv)

DATA="${SCRIPT_DIR}/data"

function get_matrix() {
    local config=$1 # Can be state, perfect, etc.
    local project_dir_on_disk=$2
    mvn -l logs/${config}-reduce-log.txt org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:reduce -DartifactDir=.rvtsm -DmatrixReductionScheme=${config} -DtestMethodList=${project_dir_on_disk}/tests.txt -Dmatrix=.rvtsm/${config}-matrix.csv -DreducedSet=.rvtsm/${config}-reduced.txt -DredundantAndNoTraceSet=.rvtsm/${config}-redundant-and-no-trace.txt -DlogDir=./rvtsm/logs -DallTracesDir=${project_dir_on_disk}/.all-traces
}

function main() {
    local project=$1
    local sha=$2
    local project_name_on_disk="$(echo ${project} | sed 's/\//-/g')"
    local project_dir_on_disk="${DATA}/${project_name_on_disk}/project"
    mkdir -p projects
    mkdir -p ${DATA}
    pushd projects
        git clone https://github.com/$project.git $project_name_on_disk
        pushd $project_name_on_disk
            git checkout -f $sha
            # Decompress unique traces
            if [ ! -f "${project_dir_on_disk}/.all-traces/unique-traces.txt" ]; then
                gunzip ${project_dir_on_disk}/.all-traces/unique-traces.txt.gz
            fi
            mkdir logs
            mvn clean test-compile
            mvn surefire:3.5.2:test
            # Need to run twice because the first time might contain downloading times
            mvn -l logs/surefire-log.txt surefire:3.5.2:test
            for reduction in "${REDUCTION_SCHEMES[@]}"; do
                if [ "${reduction}" != "all" ]; then
                    get_matrix ${reduction} ${project_dir_on_disk}
                fi
            done
            # Run four configs
            for rvconfig in "${RV_CONFIGS[@]}"; do
                for reduction in "${REDUCTION_SCHEMES[@]}"; do
                    local full_label="${reduction}-reduced-${rvconfig}"

                    # Skip if the set of reduced tests is the same as another run that already has results
                    local skip=false
                    for other_reduction in "${REDUCTION_SCHEMES[@]}"; do
                        if [ "${reduction}" != "${other_reduction}" ]; then
                            diff <(sort .rvtsm/${reduction}-reduced.txt) <(sort .rvtsm/${other_reduction}-reduced.txt)
                            # Make sure that the set are the same and the other run has already completed
                            if [ $? -eq 0 ] && [ -f logs/${other_reduction}-reduced-${rvconfig}-log.txt ]; then
                                skip=true
                                cp logs/${other_reduction}-reduced-${rvconfig}-log.txt logs/${full_label}-log.txt
                                cp .rvtsm/${other_reduction}-reduced.txt .rvtsm/${reduction}-reduced.txt
                                cp .rvtsm/violation-counts-${other_reduction}-reduced-${rvconfig} .rvtsm/violation-counts-${full_label}
                                cp -r .rvtsm/scr-${other_reduction}-reduced-${rvconfig}-traces .rvtsm/scr-${full_label}-traces
                                break
                            fi
                        fi
                    done
                    if [ "${skip}" = true ]; then
                        continue
                    fi

                    mvn -l logs/${full_label}-log.txt org.rvtsm:rvtsm-maven-plugin:1.0-SNAPSHOT:scr -DskipAllPreviousSteps=true -DtestMethodsToRun=.rvtsm/${reduction}-reduced.txt -DrvConfig=${rvconfig} -DrunLabel=${full_label}
                    if [ -f "violation-counts" ]; then
                        mv violation-counts .rvtsm/violation-counts-${full_label}
                    fi
                done
            done
        popd
    popd
}

while IFS=$'\t' read -r proj sha; do
    main $proj $sha
done < "projects.tsv"
