#!/bin/bash
# Generates a summary table for a list of projects.

SCRIPT_DIR="$(cd "$(dirname $0)" && pwd)"
COLUMNS=("# of tests" "MOP e2e" "monitors" "events" "monitoring samples" "instrumentation samples")

function main() {
    local project_list=$1
    echo "project,pnum_tests,snum_tests,pnum_tests_ratio,snum_tests_ratio,ptime,stime,ptime_ratio,stime_ratio,pmon,smon,pmon_ratio,smon_ratio,pevent,sevent,pevent_ratio,sevent_ratio,pmon_samples,smon_samples,pmon_samples_ratio,smon_samples_ratio,pinstr_samples,sinstr_samples,pinstr_samples_ratio,sinstr_samples_ratio"
    while IFS= read -r line; do
        project=$(echo "${line}" | cut -d ',' -f 1)
        project_dash_format=$(echo "${project}" | tr '/' '-')
        # project
        echo -n "${project}"
        for column in "${COLUMNS[@]}"; do
            # pcolumn
            local pcolumn_reduced="$(bash ${SCRIPT_DIR}/get_cell.sh -f ${SCRIPT_DIR}/output/${project_dash_format}-parallel/stats.csv -r "reduced" -c "${column}" -m "textual")"
            local pcolumn_all="$(bash ${SCRIPT_DIR}/get_cell.sh -f ${SCRIPT_DIR}/output/${project_dash_format}-parallel/stats.csv -r "all" -c "${column}" -m "textual")"
            echo -n ",${pcolumn_reduced}/${pcolumn_all}"
            # scolumn
            local scolumn_reduced="$(bash ${SCRIPT_DIR}/get_cell.sh -f ${SCRIPT_DIR}/output/${project_dash_format}-sequential/stats.csv -r "reduced" -c "${column}" -m "textual")"
            local scolumn_all="$(bash ${SCRIPT_DIR}/get_cell.sh -f ${SCRIPT_DIR}/output/${project_dash_format}-sequential/stats.csv -r "all" -c "${column}" -m "textual")"
            echo -n ",${scolumn_reduced}/${scolumn_all}"
            # pratio
            local pratio=$(echo "scale=3; ${pcolumn_reduced}/${pcolumn_all}" | bc -l)
            echo -n ",${pratio}"
            # sratio
            local sratio=$(echo "scale=3; ${scolumn_reduced}/${scolumn_all}" | bc -l)
            echo -n ",${sratio}"
        done
        echo ""
    done < "${project_list}"
}

main $@
