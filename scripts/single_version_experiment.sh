#!/bin/bash

SCRIPT_DIR=$( cd $( dirname $0 ) && pwd )
PROJECT_DIR=${SCRIPT_DIR}/projects

source ${SCRIPT_DIR}/../experiments/constants.sh
source ${SCRIPT_DIR}/../experiments/utils.sh

cd $SCRIPT_DIR

IS_MMMP=false
while getopts :r:s:m:t:l:x: opts; do
    case "${opts}" in
        r ) REPO="${OPTARG}" ;;
        s ) SHA="${OPTARG}" ;;
        m ) MATRIX="${OPTARG}" ;;
        l ) LOCATION="${OPTARG}" ;;
        t ) TESTS="${OPTARG}" ;;
        x ) SKIP_RUN="${OPTARG}" ;;
    esac
done
shift $((${OPTIND} - 1))
EXTENSION_DIR=$1
MOP_DIR=$2
OUTPUT_DIR=$3
PROJECT_NAME=$(echo ${REPO} | tr / -)
if [[ $(head -n 1 ${TESTS}) == *#*#* ]]; then
    IS_MMMP=true
fi

mkdir -p ${OUTPUT_DIR}/logs
mkdir -p ${OUTPUT_DIR}/violations
mkdir -p ${OUTPUT_DIR}/surefire
export _JAVA_OPTIONS=-Djava.io.tmpdir=${TMP_DIR}/${PROJECT_NAME}
export RVMLOGGINGLEVEL=UNIQUE
export TRACEDB_CONFIG_PATH="${SCRIPT_DIR}/.trace-db.config"
echo -e "db=memory\ndumpDB=false" > ${TRACEDB_CONFIG_PATH}

check_status_code() {
    local error_code=$?
    if [[ ${error_code} -ne 0 ]]; then
        echo "Step $1 failed"
        echo "$1,${error_code}" > "${OUTPUT_DIR}/logs/status.log"
        exit 1
    fi
}


clone_project() {
    pushd ${OUTPUT_DIR} &> /dev/null
        git clone https://github.com/${REPO} project
        check_status_code "clone_project clone"
        pushd project &> /dev/null
            git checkout ${SHA}
            check_status_code "clone_project checkout"
            
            if [[ -f ${SCRIPT_DIR}/../experiments/treat_special.sh ]]; then
                bash ${SCRIPT_DIR}/../experiments/treat_special.sh ${OUTPUT_DIR}/project ${PROJECT_NAME}
            fi
        popd &> /dev/null
    popd &> /dev/null
}


run_all_test() {
    local extension_jar="${EXTENSION_DIR}/javamop-extension-1.0.jar"
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    export ADD_AGENT=0
    
    pushd ${OUTPUT_DIR}/project &> /dev/null
        echo "Running all test to download dependencies"
        if [[ ${IS_MMMP} != "true" ]]; then
            (time mvn ${SKIP} -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${OUTPUT_DIR}/repo" -Dmaven.ext.class.path=${extension_jar} test-compile test) &> "${OUTPUT_DIR}/logs/test-compile.log"
            check_status_code "run_all_test_initial"
        else
            (time mvn ${SKIP} -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${OUTPUT_DIR}/repo" -Dmaven.ext.class.path=${extension_jar} test install) &> "${OUTPUT_DIR}/logs/test-compile.log"
            check_status_code "run_all_test_initial"
        fi
    
        echo "Running all test without RV"
        (time mvn ${SKIP} -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${OUTPUT_DIR}/repo" -Dmaven.ext.class.path=${extension_jar} test) &> "${OUTPUT_DIR}/logs/test.log"
        check_status_code "run_all_test"

        local name="test"
        if [[ ${IS_MMMP} != "true" ]]; then
            if [[ -d target/surefire-reports ]]; then
                mv target/surefire-reports ${OUTPUT_DIR}/surefire/${name}
            fi
        else
            move_surefire ${OUTPUT_DIR}/surefire ${name}
        fi
    unset ADD_AGENT
    popd &> /dev/null
}


run_all_javamop_all_specs() {
    local name="all-javamop-all-specs"
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    local extension_jar="${EXTENSION_DIR}/javamop-extension-1.0.jar"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${MOP_DIR} "no-track-all"
    
    pushd ${OUTPUT_DIR}/project &> /dev/null
    echo "Running all test with JavaMOP with all specs"
    (time mvn ${SKIP} -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${OUTPUT_DIR}/repo" -Dmaven.ext.class.path=${extension_jar} test) &> "${OUTPUT_DIR}/logs/${name}.log"
    check_status_code "run_all_javamop_all_specs"
    
    if [[ ${IS_MMMP} != "true" ]]; then
        if [[ -f violation-counts ]]; then
            mv violation-counts ${OUTPUT_DIR}/violations/${name}
        fi
        if [[ -d target/surefire-reports ]]; then
            mv target/surefire-reports ${OUTPUT_DIR}/surefire/${name}
        fi
    else
        move_violations ${OUTPUT_DIR}/violations ${name}
        move_surefire ${OUTPUT_DIR}/surefire ${name}
    fi
    popd &> /dev/null
}


run_all_tracemop_all_specs() {
    local name="all-tracemop-all-specs"
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    local extension_jar="${EXTENSION_DIR}/javamop-extension-1.0.jar"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${MOP_DIR} "track-agent"
    
    export COLLECT_TRACES=1 # extension will add -Xmx500g -XX:-UseGCOverheadLimit
    export COLLECT_MONITORS=1 # TraceMOP will collect monitor
    export TRACEDB_PATH=${OUTPUT_DIR}/tracemop/${name}/all-traces # Store traces in this directory
    export TRACEDB_RANDOM=1 # Directory name should end with random string, to prevent duplicated DB
    local old_MAVEN_OPTS=${MAVEN_OPTS}
    export MAVEN_OPTS="${MAVEN_OPTS} -Xmx500g -XX:-UseGCOverheadLimit"
    mkdir -p ${OUTPUT_DIR}/tracemop/${name}
    
    pushd ${OUTPUT_DIR}/project &> /dev/null
    echo "Running all test with TraceMOP with all specs"
    (time mvn ${SKIP} -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${OUTPUT_DIR}/repo" -Dmaven.ext.class.path=${extension_jar} -Dsurefire.exitTimeout=86400 test) &> "${OUTPUT_DIR}/logs/${name}.log"
    if [[ $? -ne 0 ]]; then
        echo "Step run_all_tracemop_all_specs failed"
    fi
    
    if [[ ${IS_MMMP} != "true" ]]; then
        if [[ -f violation-counts ]]; then
            mv violation-counts ${OUTPUT_DIR}/violations/${name}
        fi
        if [[ -d target/surefire-reports ]]; then
            mv target/surefire-reports ${OUTPUT_DIR}/surefire/${name}
        fi
    else
        move_violations ${OUTPUT_DIR}/violations ${name}
        move_surefire ${OUTPUT_DIR}/surefire ${name}
    fi
    
    unset COLLECT_TRACES
    unset COLLECT_MONITORS
    unset TRACEDB_PATH
    unset TRACEDB_RANDOM
    export MAVEN_OPTS=${old_MAVEN_OPTS}
    popd &> /dev/null
}


run_all_javamop_deinstr_raw() {
    local name="all-javamop-deinstr-raw"
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    local extension_jar="${EXTENSION_DIR}/javamop-extension-1.0.jar"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${MOP_DIR} "no-track-agent"
    
    pushd ${OUTPUT_DIR}/project &> /dev/null
        echo "Running all test with JavaMOP with raw de-instrumentation"
        (time mvn ${SKIP} -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${OUTPUT_DIR}/repo" -Dmaven.ext.class.path=${extension_jar} test) &> "${OUTPUT_DIR}/logs/${name}.log"
        check_status_code "run_all_javamop_deinstr_raw"
        
        if [[ ${IS_MMMP} != "true" ]]; then
            if [[ -f violation-counts ]]; then
                mv violation-counts ${OUTPUT_DIR}/violations/${name}
            fi
            if [[ -d target/surefire-reports ]]; then
                mv target/surefire-reports ${OUTPUT_DIR}/surefire/${name}
            fi
        else
            move_violations ${OUTPUT_DIR}/violations ${name}
            move_surefire ${OUTPUT_DIR}/surefire ${name}
        fi
    popd &> /dev/null
}


run_all_tracemop_deinstr_raw() {
    local name="all-tracemop-deinstr-raw"
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    local extension_jar="${EXTENSION_DIR}/javamop-extension-1.0.jar"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${MOP_DIR} "track-deinstr-raw"
    
    export COLLECT_TRACES=1 # extension will add -Xmx500g -XX:-UseGCOverheadLimit
    export COLLECT_MONITORS=1 # TraceMOP will collect monitor
    export TRACEDB_PATH=${OUTPUT_DIR}/tracemop/${name}/all-traces # Store traces in this directory
    export TRACEDB_RANDOM=1 # Directory name should end with random string, to prevent duplicated DB
    local old_MAVEN_OPTS=${MAVEN_OPTS}
    export MAVEN_OPTS="${MAVEN_OPTS} -Xmx500g -XX:-UseGCOverheadLimit"
    mkdir -p ${OUTPUT_DIR}/tracemop/${name}
    
    pushd ${OUTPUT_DIR}/project &> /dev/null
    echo "Running all test with TraceMOP with raw de-instrumentation"
    (time mvn ${SKIP} -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${OUTPUT_DIR}/repo" -Dmaven.ext.class.path=${extension_jar} -Dsurefire.exitTimeout=86400 test) &> "${OUTPUT_DIR}/logs/${name}.log"
    if [[ $? -ne 0 ]]; then
        echo "Step run_all_tracemop_deinstr_raw failed"
    fi
    
    if [[ ${IS_MMMP} != "true" ]]; then
        if [[ -f violation-counts ]]; then
            mv violation-counts ${OUTPUT_DIR}/violations/${name}
        fi
        if [[ -d target/surefire-reports ]]; then
            mv target/surefire-reports ${OUTPUT_DIR}/surefire/${name}
        fi
    else
        move_violations ${OUTPUT_DIR}/violations ${name}
        move_surefire ${OUTPUT_DIR}/surefire ${name}
    fi
    unset COLLECT_TRACES
    unset COLLECT_MONITORS
    unset TRACEDB_PATH
    unset TRACEDB_RANDOM
    export MAVEN_OPTS=${old_MAVEN_OPTS}
    popd &> /dev/null
}


run_reduced_javamop_all_specs() {
    local name="reduced-javamop-all-specs"
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    local extension_jar="${EXTENSION_DIR}/javamop-extension-1.0.jar"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${MOP_DIR} "no-track-all"
    
    pushd ${OUTPUT_DIR}/project &> /dev/null
    echo "Running reduced test with JavaMOP with all specs"
    
    if [[ ${IS_MMMP} != "true" ]]; then
        (time mvn ${SKIP} -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${OUTPUT_DIR}/repo" -Dmaven.ext.class.path=${extension_jar} -Dtest=$(cat ${TESTS} | tr '\n' ',') test) &> "${OUTPUT_DIR}/logs/${name}.log"
        check_status_code "run_reduced_javamop_all_specs"
    else
        (time cut -d'#' -f1 "$TESTS" | sort -u | \
        parallel '
            module="{}"
            logfile="'"${OUTPUT_DIR}/logs/${name}-{}"'.log"
            tests=$(grep "^$module#" "'"$TESTS"'" | cut -d"#" -f2- | sed -z "$ s/\n$//;s/\n/,/g")
            mvn '"${SKIP}"' \
                    -Djava.io.tmpdir="'"${tmp_dir}"'" \
                    -Dmaven.repo.local="'"${OUTPUT_DIR}/repo"'" \
                    -Dmaven.ext.class.path="'"${extension_jar}"'" \
                    -pl "$module" \
                    -Dtest="$tests" \
                    test &> "$logfile"
        ') &> "${OUTPUT_DIR}/logs/${name}.log"
        check_status_code "run_reduced_javamop_all_specs"
    fi
    
    if [[ ${IS_MMMP} != "true" ]]; then
        if [[ -f violation-counts ]]; then
            mv violation-counts ${OUTPUT_DIR}/violations/${name}
        fi
        if [[ -d target/surefire-reports ]]; then
            mv target/surefire-reports ${OUTPUT_DIR}/surefire/${name}
        fi
    else
        move_violations ${OUTPUT_DIR}/violations ${name}
        move_surefire ${OUTPUT_DIR}/surefire ${name}
    fi
    popd &> /dev/null
}


run_reduced_tracemop_all_specs() {
    local name="reduced-tracemop-all-specs"
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    local extension_jar="${EXTENSION_DIR}/javamop-extension-1.0.jar"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${MOP_DIR} "track-agent"
    
    export COLLECT_TRACES=1 # extension will add -Xmx500g -XX:-UseGCOverheadLimit
    export COLLECT_MONITORS=1 # TraceMOP will collect monitor
    export TRACEDB_PATH=${OUTPUT_DIR}/tracemop/${name}/all-traces # Store traces in this directory
    export TRACEDB_RANDOM=1 # Directory name should end with random string, to prevent duplicated DB
    local old_MAVEN_OPTS=${MAVEN_OPTS}
    export MAVEN_OPTS="${MAVEN_OPTS} -Xmx500g -XX:-UseGCOverheadLimit"
    mkdir -p ${OUTPUT_DIR}/tracemop/${name}
    
    pushd ${OUTPUT_DIR}/project &> /dev/null
    echo "Running reduced test with TraceMOP with all specs"
    
    if [[ ${IS_MMMP} != "true" ]]; then
        (time mvn ${SKIP} -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${OUTPUT_DIR}/repo" -Dmaven.ext.class.path=${extension_jar} -Dsurefire.exitTimeout=86400 -Dtest=$(cat ${TESTS} | tr '\n' ',') test) &> "${OUTPUT_DIR}/logs/${name}.log"
        if [[ $? -ne 0 ]]; then
            echo "Step run_reduced_tracemop_all_specs failed"
        fi
    else
        (time cut -d'#' -f1 "$TESTS" | sort -u | \
            parallel '
            module="{}"
            logfile="'"${OUTPUT_DIR}/logs/${name}-{}"'.log"
            tests=$(grep "^$module#" "'"$TESTS"'" | cut -d"#" -f2- | sed -z "$ s/\n$//;s/\n/,/g")
            mvn '"${SKIP}"' \
                    -Djava.io.tmpdir="'"${tmp_dir}"'" \
                    -Dmaven.repo.local="'"${OUTPUT_DIR}/repo"'" \
                    -Dmaven.ext.class.path="'"${extension_jar}"'" \
                    -pl "$module" \
                    -Dsurefire.exitTimeout=86400 \
                    -Dtest="$tests" \
                    test &> "$logfile"
        ') &> "${OUTPUT_DIR}/logs/${name}.log"
        if [[ $? -ne 0 ]]; then
            echo "Step run_reduced_tracemop_all_specs failed"
        fi
    fi
    
    if [[ ${IS_MMMP} != "true" ]]; then
        if [[ -f violation-counts ]]; then
            mv violation-counts ${OUTPUT_DIR}/violations/${name}
        fi
        if [[ -d target/surefire-reports ]]; then
            mv target/surefire-reports ${OUTPUT_DIR}/surefire/${name}
        fi
    else
        move_violations ${OUTPUT_DIR}/violations ${name}
        move_surefire ${OUTPUT_DIR}/surefire ${name}
    fi
    unset COLLECT_TRACES
    unset COLLECT_MONITORS
    unset TRACEDB_PATH
    unset TRACEDB_RANDOM
    export MAVEN_OPTS=${old_MAVEN_OPTS}
    popd &> /dev/null
}


run_reduced_javamop_deinstr_raw() {
    local name="reduced-javamop-deinstr-raw"
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    local extension_jar="${EXTENSION_DIR}/javamop-extension-1.0.jar"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${MOP_DIR} "no-track-agent"
    
    pushd ${OUTPUT_DIR}/project &> /dev/null
        echo "Running reduced test with JavaMOP with raw de-instrumentation"

        if [[ ${IS_MMMP} != "true" ]]; then
            (time mvn ${SKIP} -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${OUTPUT_DIR}/repo" -Dmaven.ext.class.path=${extension_jar} -Dtest=$(cat ${TESTS} | tr '\n' ',') test) &> "${OUTPUT_DIR}/logs/${name}.log"
            check_status_code "run_reduced_javamop_deinstr_raw"
        else
            (time cut -d'#' -f1 "$TESTS" | sort -u | \
                parallel '
                module="{}"
                logfile="'"${OUTPUT_DIR}/logs/${name}-{}"'.log"
                tests=$(grep "^$module#" "'"$TESTS"'" | cut -d"#" -f2- | sed -z "$ s/\n$//;s/\n/,/g")
                mvn '"${SKIP}"' \
                        -Djava.io.tmpdir="'"${tmp_dir}"'" \
                        -Dmaven.repo.local="'"${OUTPUT_DIR}/repo"'" \
                        -Dmaven.ext.class.path="'"${extension_jar}"'" \
                        -pl "$module" \
                        -Dtest="$tests" \
                        test &> "$logfile"
            ') &> "${OUTPUT_DIR}/logs/${name}.log"
            check_status_code "run_reduced_javamop_deinstr_raw"
        fi
    
        if [[ ${IS_MMMP} != "true" ]]; then
            if [[ -f violation-counts ]]; then
                mv violation-counts ${OUTPUT_DIR}/violations/${name}
            fi
            if [[ -d target/surefire-reports ]]; then
                mv target/surefire-reports ${OUTPUT_DIR}/surefire/${name}
            fi
        else
            move_violations ${OUTPUT_DIR}/violations ${name}
            move_surefire ${OUTPUT_DIR}/surefire ${name}
        fi
    popd &> /dev/null
}


run_reduced_tracemop_deinstr_raw() {
    local name="reduced-tracemop-deinstr-raw"
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    local extension_jar="${EXTENSION_DIR}/javamop-extension-1.0.jar"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${MOP_DIR} "track-deinstr-raw"
    
    export COLLECT_TRACES=1 # extension will add -Xmx500g -XX:-UseGCOverheadLimit
    export COLLECT_MONITORS=1 # TraceMOP will collect monitor
    export TRACEDB_PATH=${OUTPUT_DIR}/tracemop/${name}/all-traces # Store traces in this directory
    export TRACEDB_RANDOM=1 # Directory name should end with random string, to prevent duplicated DB
    local old_MAVEN_OPTS=${MAVEN_OPTS}
    export MAVEN_OPTS="${MAVEN_OPTS} -Xmx500g -XX:-UseGCOverheadLimit"
    mkdir -p ${OUTPUT_DIR}/tracemop/${name}
    
    pushd ${OUTPUT_DIR}/project &> /dev/null
    echo "Running reduced test with TraceMOP with raw de-instrumentation"

    if [[ ${IS_MMMP} != "true" ]]; then
        (time mvn ${SKIP} -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${OUTPUT_DIR}/repo" -Dmaven.ext.class.path=${extension_jar} -Dsurefire.exitTimeout=86400 -Dtest=$(cat ${TESTS} | tr '\n' ',') test) &> "${OUTPUT_DIR}/logs/${name}.log"
        if [[ $? -ne 0 ]]; then
            echo "Step run_reduced_tracemop_deinstr_raw failed"
        fi
    else
        (time cut -d'#' -f1 "$TESTS" | sort -u | \
            parallel '
            module="{}"
            logfile="'"${OUTPUT_DIR}/logs/${name}-{}"'.log"
            tests=$(grep "^$module#" "'"$TESTS"'" | cut -d"#" -f2- | sed -z "$ s/\n$//;s/\n/,/g")
            mvn '"${SKIP}"' \
                    -Djava.io.tmpdir="'"${tmp_dir}"'" \
                    -Dmaven.repo.local="'"${OUTPUT_DIR}/repo"'" \
                    -Dmaven.ext.class.path="'"${extension_jar}"'" \
                    -pl "$module" \
                    -Dsurefire.exitTimeout=86400 \
                    -Dtest="$tests" \
                    test &> "$logfile"
        ') &> "${OUTPUT_DIR}/logs/${name}.log"
        if [[ $? -ne 0 ]]; then
            echo "Step run_reduced_tracemop_deinstr_raw failed"
        fi
    fi
    
    if [[ ${IS_MMMP} != "true" ]]; then
        if [[ -f violation-counts ]]; then
            mv violation-counts ${OUTPUT_DIR}/violations/${name}
        fi
        if [[ -d target/surefire-reports ]]; then
            mv target/surefire-reports ${OUTPUT_DIR}/surefire/${name}
        fi
    else
        move_violations ${OUTPUT_DIR}/violations ${name}
        move_surefire ${OUTPUT_DIR}/surefire ${name}
    fi
    unset COLLECT_TRACES
    unset COLLECT_MONITORS
    unset TRACEDB_PATH
    unset TRACEDB_RANDOM
    export MAVEN_OPTS=${old_MAVEN_OPTS}
    popd &> /dev/null
}


run_reduced_javamop_deinstr_both() {
    local conservative=$1
    local label=""
    if [[ ${conservative} == "true" ]]; then
        label="-conservative"
    fi
    
    local name="reduced-javamop-deinstr-both${label}"
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    local extension_jar="${EXTENSION_DIR}/javamop-extension-1.0.jar"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    # Install agent
    install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${MOP_DIR} "no-track-deinstr"
    
    # Find test and event to de-instrument
    pushd ${OUTPUT_DIR} &> /dev/null
        if [[ ${conservative} == "true" ]]; then
            if [[ ! -d ${OUTPUT_DIR}/skip-conservative ]]; then
                python3 ${SCRIPT_DIR}/skip_monitoring.py ${MATRIX} ${LOCATION} ${TESTS} ${MOP_DIR}/events_encoding_id.txt skip-conservative true
            fi
            source ${OUTPUT_DIR}/skip-conservative/setup.sh
        else
            if [[ ! -d ${OUTPUT_DIR}/skip ]]; then
                python3 ${SCRIPT_DIR}/skip_monitoring.py ${MATRIX} ${LOCATION} ${TESTS} ${MOP_DIR}/events_encoding_id.txt skip
            fi
            source ${OUTPUT_DIR}/skip/setup.sh
        fi
    popd &> /dev/null
    
    pushd ${OUTPUT_DIR}/project &> /dev/null
        echo "Running reduced test with JavaMOP with raw and non-raw de-instrumentation${label}"

        if [[ ${IS_MMMP} != "true" ]]; then
            (time mvn ${SKIP} -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${OUTPUT_DIR}/repo" -Dmaven.ext.class.path=${extension_jar} -Dtest=$(cat ${TESTS} | tr '\n' ',') test) &> "${OUTPUT_DIR}/logs/${name}.log"
            check_status_code "run_reduced_javamop_deinstr_both${label}"
        else
            (time cut -d'#' -f1 "$TESTS" | sort -u | \
                parallel '
                module="{}"
                logfile="'"${OUTPUT_DIR}/logs/${name}-{}"'.log"
                tests=$(grep "^$module#" "'"$TESTS"'" | cut -d"#" -f2- | sed -z "$ s/\n$//;s/\n/,/g")
                mvn '"${SKIP}"' \
                        -Djava.io.tmpdir="'"${tmp_dir}"'" \
                        -Dmaven.repo.local="'"${OUTPUT_DIR}/repo"'" \
                        -Dmaven.ext.class.path="'"${extension_jar}"'" \
                        -pl "$module" \
                        -Dtest="$tests" \
                        test &> "$logfile"
            ') &> "${OUTPUT_DIR}/logs/${name}.log"
            check_status_code "run_reduced_javamop_deinstr_both${label}"
        fi
    
        if [[ ${IS_MMMP} != "true" ]]; then
            if [[ -f violation-counts ]]; then
                mv violation-counts ${OUTPUT_DIR}/violations/${name}
            fi
            if [[ -d target/surefire-reports ]]; then
                mv target/surefire-reports ${OUTPUT_DIR}/surefire/${name}
            fi
        else
            move_violations ${OUTPUT_DIR}/violations ${name}
            move_surefire ${OUTPUT_DIR}/surefire ${name}
        fi
    popd &> /dev/null
    if [[ ${conservative} == "true" ]]; then
        source ${OUTPUT_DIR}/skip-conservative/cleanup.sh
    else
        source ${OUTPUT_DIR}/skip/cleanup.sh
    fi
}


run_reduced_tracemop_deinstr_both() {
    local conservative=$1
    local label=""
    if [[ ${conservative} == "true" ]]; then
        label="-conservative"
    fi
    
    local name="reduced-tracemop-deinstr-both${label}"
    local tmp_dir="${TMP_DIR}/${PROJECT_NAME}"
    local extension_jar="${EXTENSION_DIR}/javamop-extension-1.0.jar"
    rm -rf ${tmp_dir} && mkdir ${tmp_dir}
    
    # Install agent
    install_agent "${OUTPUT_DIR}/project" "${OUTPUT_DIR}/repo" ${MOP_DIR} "track-deinstr-both"
    
    export COLLECT_TRACES=1 # extension will add -Xmx500g -XX:-UseGCOverheadLimit
    export COLLECT_MONITORS=1 # TraceMOP will collect monitor
    export TRACEDB_PATH=${OUTPUT_DIR}/tracemop/${name}/all-traces # Store traces in this directory
    export TRACEDB_RANDOM=1 # Directory name should end with random string, to prevent duplicated DB
    local old_MAVEN_OPTS=${MAVEN_OPTS}
    export MAVEN_OPTS="${MAVEN_OPTS} -Xmx500g -XX:-UseGCOverheadLimit"
    mkdir -p ${OUTPUT_DIR}/tracemop/${name}
    
    # Find test and event to de-instrument
    pushd ${OUTPUT_DIR} &> /dev/null
    if [[ ${conservative} == "true" ]]; then
        if [[ ! -d ${OUTPUT_DIR}/skip-conservative ]]; then
            python3 ${SCRIPT_DIR}/skip_monitoring.py ${MATRIX} ${LOCATION} ${TESTS} ${MOP_DIR}/events_encoding_id.txt skip-conservative true
        fi
        source ${OUTPUT_DIR}/skip-conservative/setup.sh
    else
        if [[ ! -d ${OUTPUT_DIR}/skip ]]; then
            python3 ${SCRIPT_DIR}/skip_monitoring.py ${MATRIX} ${LOCATION} ${TESTS} ${MOP_DIR}/events_encoding_id.txt skip
        fi
        source ${OUTPUT_DIR}/skip/setup.sh
    fi
    popd &> /dev/null
    
    pushd ${OUTPUT_DIR}/project &> /dev/null
    echo "Running reduced test with TraceMOP with raw and non-raw de-instrumentation${label}"

    if [[ ${IS_MMMP} != "true" ]]; then
        (time mvn ${SKIP} -Djava.io.tmpdir=${tmp_dir} -Dmaven.repo.local="${OUTPUT_DIR}/repo" -Dmaven.ext.class.path=${extension_jar} -Dsurefire.exitTimeout=86400 -Dtest=$(cat ${TESTS} | tr '\n' ',') test) &> "${OUTPUT_DIR}/logs/${name}.log"
        if [[ $? -ne 0 ]]; then
            echo "Step run_reduced_tracemop_deinstr_both failed"
        fi
    else
        (time cut -d'#' -f1 "$TESTS" | sort -u | \
            parallel '
            module="{}"
            logfile="'"${OUTPUT_DIR}/logs/${name}-{}"'.log"
            tests=$(grep "^$module#" "'"$TESTS"'" | cut -d"#" -f2- | sed -z "$ s/\n$//;s/\n/,/g")
            mvn '"${SKIP}"' \
                    -Djava.io.tmpdir="'"${tmp_dir}"'" \
                    -Dmaven.repo.local="'"${OUTPUT_DIR}/repo"'" \
                    -Dmaven.ext.class.path="'"${extension_jar}"'" \
                    -pl "$module" \
                    -Dsurefire.exitTimeout=86400 \
                    -Dtest="$tests" \
                    test &> "$logfile"
        ') &> "${OUTPUT_DIR}/logs/${name}.log"
        if [[ $? -ne 0 ]]; then
            echo "Step run_reduced_tracemop_deinstr_both failed"
        fi
    fi
    
    if [[ ${IS_MMMP} != "true" ]]; then
        if [[ -f violation-counts ]]; then
            mv violation-counts ${OUTPUT_DIR}/violations/${name}
        fi
        if [[ -d target/surefire-reports ]]; then
            mv target/surefire-reports ${OUTPUT_DIR}/surefire/${name}
        fi
    else
        move_violations ${OUTPUT_DIR}/violations ${name}
        move_surefire ${OUTPUT_DIR}/surefire ${name}
    fi
    unset COLLECT_TRACES
    unset COLLECT_MONITORS
    unset TRACEDB_PATH
    unset TRACEDB_RANDOM
    export MAVEN_OPTS=${old_MAVEN_OPTS}
    popd &> /dev/null
    if [[ ${conservative} == "true" ]]; then
        source ${OUTPUT_DIR}/skip-conservative/cleanup.sh
    else
        source ${OUTPUT_DIR}/skip/cleanup.sh
    fi
}


echo "TSM version: ($(git rev-parse HEAD) - $(date +%s))"
clone_project
run_all_test

if [[ -z ${SKIP_RUN} || -z $(echo ${SKIP_RUN} | grep "all_javamop_all_specs") ]]; then
    run_all_javamop_all_specs
fi
#run_all_javamop_deinstr_raw
if [[ -z ${SKIP_RUN} || -z $(echo ${SKIP_RUN} | grep "reduced_javamop_all_specs") ]]; then
    run_reduced_javamop_all_specs
fi
#run_reduced_javamop_deinstr_raw
run_reduced_javamop_deinstr_both
#run_reduced_javamop_deinstr_both true

run_all_tracemop_all_specs
#run_all_tracemop_deinstr_raw
#run_reduced_tracemop_all_specs
#run_reduced_tracemop_deinstr_raw
run_reduced_tracemop_deinstr_both
#run_reduced_tracemop_deinstr_both true
echo "OK"
