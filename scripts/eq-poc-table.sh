#!/bin/bash

REDUCTION_SCHEMES=(perfect state prefix online_detour state-online_detour-prefix)
RV_CONFIGS=(no-track no-rv)

function main {
    echo -n "project"
    for reduction in "${REDUCTION_SCHEMES[@]}"; do
        echo -n ",${reduction}_reduced_tests"
        for rvconfig in "${RV_CONFIGS[@]}"; do
            echo -n ",time_${reduction}_${rvconfig}"
        done
        echo -n ",violations_${reduction}"
    done
    echo ",time_test_all"

    while IFS=$'\t' read -r proj sha; do
        project_on_disk=$(echo $proj | sed 's/\//-/g')
        echo -n "$proj"
        for reduction in "${REDUCTION_SCHEMES[@]}"; do
            if [ $reduction == "all" ]; then
                echo -n ",$(wc -l projects/$project_on_disk/tests.txt | xargs | cut -d ' ' -f 1)"
            else
                echo -n ",$(wc -l projects/$project_on_disk/.rvtsm/${reduction}-reduced.txt | xargs | cut -d ' ' -f 1)"
            fi
            for rvconfig in "${RV_CONFIGS[@]}"; do
                echo -n ",$(grep "finished in" projects/$project_on_disk/logs/${reduction}-reduced-${rvconfig}-log.txt | cut -d ' ' -f 9)"
            done
            violations=0
            if [ -f projects/$project_on_disk/.rvtsm/violation-counts-${reduction}-reduced-no-track ]; then
                violations=$(wc -l projects/$project_on_disk/.rvtsm/violation-counts-${reduction}-reduced-no-track | xargs | cut -d ' ' -f 1)
            fi
            echo -n ",${violations}"
        done
        echo ",$(grep 'Total time:' projects/$project_on_disk/logs/surefire-log.txt | cut -d ' ' -f 5 | xargs)"
done < "projects.tsv"
}

main
