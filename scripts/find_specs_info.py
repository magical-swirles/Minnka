#!/usr/bin/env python3
#
# Parse test log to retrieve monitors count, events count, and violations count for each spec
# Usage: python3 find_specs_info.py <log-file> <output-csv>
# Output: A <output-csv> file in the following format
#         spec1,# of monitors,# of events,# of violations
#         spec2,# of monitors,# of events,# of violations
#         ...
#
import re
import os
import csv
import sys


def read_log(log_file):
    if not os.path.isfile(log_file):
        print('{} is not a valid file'.format(log_file))
        exit(1)
    
    with open(log_file) as f:
        return f.readlines()


def process_log(log):
    started = False
    rows = []
    """
    Example:
    turn:
        ==start Map_CollectionViewAdd ==
        #monitors: 640
        #collected monitors: 5
        #terminated monitors: 174
        #event - add: 6650
        #event - getset: 648
        #category - prop 1 - match: 0
        ==end Map_CollectionViewAdd ==
    into:
        [Map_CollectionViewAdd, 640, 7298, 0]
    """
    for line in log:
        line = line.strip()
        if not started and line[:7] == '==start':
            started = True
            monitors, events, violations = 0, 0, 0
            spec = line.split(' ')[1]
        elif started and line[:5] == '==end':
            started = False
            rows.append([spec, monitors, events, violations])
        elif started:
            if line.startswith('#monitors: '):
                monitors = line.split(' ')[1]
            if line.startswith('#event'):
                events += int(line.split(' ')[3])
            if line.startswith('#category - prop 1 - '):
                violations += int(line.split(' ')[6])
    return rows


def generate_csv(rows, output_csv):
    with open(output_csv, 'w', newline='') as f:
        writer = csv.writer(f)
        for row in rows:
            writer.writerow(row)


def main(argv=None):
    argv = argv or sys.argv
    
    if len(argv) != 3:
        print('Usage: python3 find_specs_info.py <log-file> <output-csv>')
        exit(1)

    log = read_log(argv[1]);
    rows = process_log(log)
    generate_csv(rows, argv[2])


if __name__ == '__main__':
    main()
