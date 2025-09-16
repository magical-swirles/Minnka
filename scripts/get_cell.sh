#! /bin/bash
# Obtains the cell content of a given column and row of a CSV file.
# The mode can be numerical, textual, or mixed.

function main {
    local file=""
    local column=""
    local row=""
    local mode=""

    while getopts "f:c:r:m:" opt; do
        case $opt in
            f)
                file="${OPTARG}"
                ;;
            c)
                column="${OPTARG}"
                ;;
            r)
                row="${OPTARG}"
                ;;
            m)
                mode="${OPTARG}"
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done

    # Validate inputs
    if [ -z "$file" ] || [ -z "$column" ] || [ -z "$row" ]; then
        echo "Error: Missing required arguments"
        echo "Usage: $0 -f <file> -c <column> -r <row> [-m <mode>]"
        exit 1
    fi

    if [ ! -f "$file" ]; then
        echo "Error: File '$file' does not exist"
        exit 1
    fi

    if [ "${mode}" == "numerical" ]; then
        cat "${file}" | cut -d ',' -f "${column}" | sed -n "${row}p"
    elif [ "${mode}" == "textual" ]; then
        header=$(head -n 1 "${file}")
        IFS=',' read -ra header_array <<< "$header"
        column_index=0
        for i in "${!header_array[@]}"; do
            if [ "${header_array[$i]}" == "${column}" ]; then
                # Add 1 because cut uses 1-based indexing
                column_index=$((i+1))
                break
            fi
        done
        if [ "$column_index" -eq 0 ]; then
            echo "Error: Column '${column}' not found in header" >&2
            exit 1
        fi
        grep "${row}" "${file}" | cut -d ',' -f "${column_index}"
    elif [ "${mode}" == "mixed" ]; then
        # Mixed mode uses textual column name and numerical row.
        header=$(head -n 1 "${file}")
        IFS=',' read -ra header_array <<< "$header"
        column_index=0
        for i in "${!header_array[@]}"; do
            if [ "${header_array[$i]}" == "${column}" ]; then
                # Add 1 because cut uses 1-based indexing
                column_index=$((i+1))
                break
            fi
        done
        if [ "$column_index" -eq 0 ]; then
            echo "Error: Column '${column}' not found in header" >&2
            exit 1
        fi
        cut -d ',' -f "${column_index}" "${file}" | sed -n "${row}p"
    fi
}

main "$@"
