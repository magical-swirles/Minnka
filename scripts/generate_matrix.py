#!/usr/bin/env python3
#
# Put all the tests and their traces into a single csv file
# Usage: python3 generate_matrix.py <path-to-project> <output-csv> [equivalence: equality]
#   equivalence: define how two traces are equivalent
#   equality (default): two traces are the same
#   remove_duplicated_events: skip event if it is the same as the previous one, for example, e1,e1,e2,e2,e1 => e1,e2,e1
#   remove_duplicated_phrases: skip phrase if it is the same as the previous one, for example, e1,e2,e3,e4,e2,e3,e4,e2,e3,e4,e5 => e1,e2,e3,e4,e5
#   remove_duplicated_events_phrases: remove_duplicated_events then remove_duplicated_phrases, for example, e1,e2,e2,e3,e4,e2,e3,e3,e4,e4,e2 => e1,e2,e3,e4,e2
# Output: A <output-csv> file in the following format
#         test_name1,trace_1,trace_2,...
#         test_name2,trace_1,trace_2,...
#         ...
#
import os
import re
import csv
import sys
import gzip
import equivalence.equality as equality
from pathlib import Path
from collections import defaultdict


# a.txt => cd /home/tsm/tsm/mop/raw/ && ls | sed "s/MonitorAspect.aj//" > ../a.txt
# cd .. && for i in $(cat a.txt); do grep "^${i}," events_encoding_id.txt; done | cut -d ',' -f 3 | sort -n | uniq | paste -sd, | sed 's/\([^,]*\)/ "e\1"/g' | sed 's/^/{/; s/$/}/'
raw_spec_events = {"e3", "e7", "e8", "e9", "e15", "e23", "e24", "e25", "e26", "e27", "e28", "e29", "e30", "e31", "e32", "e33", "e34", "e35", "e37", "e44", "e45", "e46", "e47", "e48", "e67", "e68", "e69", "e70", "e75", "e76", "e77", "e78", "e79", "e80", "e81", "e82", "e83", "e84", "e87", "e88", "e89", "e90", "e91", "e92", "e93", "e96", "e97", "e98", "e103", "e111", "e112", "e113", "e140", "e141", "e142", "e145", "e146", "e147", "e148", "e159", "e160", "e180", "e181", "e182", "e183", "e184", "e185", "e186", "e189", "e190", "e191", "e210", "e211", "e226", "e229", "e230", "e240", "e241", "e242", "e250", "e251", "e252", "e261", "e269", "e275", "e276", "e277", "e278", "e279", "e303", "e345", "e346", "e347", "e348", "e362", "e363", "e374", "e375", "e376", "e377", "e378", "e381", "e384", "e385", "e387"}


def get_traces_from_file(traces_dir):
    unique_traces_file = os.path.join(traces_dir, 'unique-traces.txt')
    unique_traces_file_compressed = os.path.join(traces_dir, 'unique-traces.txt.gz')

    traces_lines = []
    traces_started = False

    if os.path.isfile(unique_traces_file):
        open_using = open
        filename = unique_traces_file
    else:
        open_using = gzip.open
        filename = unique_traces_file_compressed

    with open_using(filename, 'rt') as f:
        for line in f:
            line = line.strip();
            if traces_started:
                if line:
                    traces_lines.append(line)
                else:
                    # Empty line means it is EOF
                    break
            elif '=== UNIQUE TRACES ===' in line:
                traces_started = True
    return traces_lines


def get_all_traces(project_path):
    # Load unique traces and map into memory
    path = Path(os.path.join(project_path, '.all-traces'))
    if not os.path.isdir(path):
        return {}, {}

    tests = [directory for directory in path.iterdir() if directory.is_dir()]
    traces = {}	# {test: [frequency, trace]}
    location_map = {} # {test: [location]}

    for test in tests:
        unique_traces_file = os.path.join(test, 'unique-traces.txt')
        unique_traces_file_compressed = os.path.join(test, 'unique-traces.txt.gz')
        locations_file = os.path.join(test, 'locations.txt')
        if (os.path.isfile(unique_traces_file) or os.path.isfile(unique_traces_file_compressed)) and os.path.isfile(locations_file):
            with open(locations_file) as f:
                map_started = False
                map_lines = []
                for line in f.readlines():
                    line = line.strip();
                    if map_started:
                        if line:
                            map_lines.append(line)
                        else:
                            # Empty line means it is EOF
                            break
                    elif line == '=== LOCATION MAP ===':
                        map_started = True

            traces[test.name] = get_traces_from_file(test)
            location_map[test.name] = map_lines
    return traces, location_map


def process_traces(tests_traces_str, tests_locations_str):
    # tests_traces_str: Given {test: [frequency, trace]}, return {test: [trace]}
    for test, traces_str in tests_traces_str.items():
        result = set()
        for trace_str in traces_str:
            # For example, if trace_str is "1 [next~1, next~1, next~1, next~1, next~1]",
            # add "[next~1, next~1, next~1, next~1, next~1]" to result
            # However, if trace_str is "1 []" then don't add [] to result
            match = re.match('^\d+ \[(.+)\]$', trace_str)
            if match:
                result.add(match.group(1))
        tests_traces_str[test] = result

    # tests_locations_str: Given {test: [location]}, return {test: {location id: line location}}
    for test, locations_str in tests_locations_str.items():
        result = {}
        for location_str in locations_str:
            id, _, line = location_str.partition(' ')
            result[id] = line
        tests_locations_str[test] = result

    return tests_traces_str, tests_locations_str


def rename_events(tests_traces, locations):
    # Test A's next~1 and Test B's next~1 can be two completely different events

    global_location = {} # {long location: unique ID}
    next_id = 0

    for test, traces in tests_traces.items():
        test_location = locations[test]
        new_traces = []
    
        for trace in traces:
            events = trace.split(', ')
            new_events = []
            for event in events:
                event_name, _, location_id = event.rpartition('~')
                location_id, _, event_freq = location_id.partition('x')
                if event_freq:
                    event_long_location = test_location.get(location_id, '(Unknown)')
                    if event_long_location in global_location:
                        # If long location is already in global_location, get unique ID
                        new_events.append('{}~{}x{}'.format(event_name, global_location[event_long_location], event_freq))
                    else:
                        # Otherwise, add new long location to global_location, set new unique ID
                        global_location[event_long_location] = next_id
                        new_events.append('{}~{}x{}'.format(event_name, next_id, event_freq))
                        next_id += 1
                else:
                    event_long_location = test_location.get(location_id, '(Unknown)')
                    if event_long_location in global_location:
                        # If long location is already in global_location, get unique ID
                        new_events.append('{}~{}'.format(event_name, global_location[event_long_location]))
                    else:
                        # Otherwise, add new long location to global_location, set new unique ID
                        global_location[event_long_location] = next_id
                        new_events.append('{}~{}'.format(event_name, next_id))
                        next_id += 1
            new_traces.append(new_events)
        tests_traces[test] = new_traces
    return tests_traces, global_location  # {test: [traces]} => {test: [[event]]}


def remove_raw_specs(tests_traces):
    new_tests_traces = {}
    for test, traces in tests_traces.items():
        new_traces = []
        for trace in traces:
            if len(trace) > 0:
                first_event = trace[0]
                event_name = first_event.partition('~')[0]
                if event_name in raw_spec_events:
                    # do not add to new_traces
                    # the goal is, each unique raw spec and event pair is a test requirement
                    unique_raw_events = set()
                    for event in trace:
                        event = event.partition('x')[0] # remove frequency
                        unique_raw_events.add(event)
                    for event in unique_raw_events:
                        new_traces.append([event.replace('e', 'r')])
                else:
                    new_traces.append(trace)
            else:
                print('empty trace is not allowed')
                exit(1)
        new_tests_traces[test] = new_traces
    return new_tests_traces


def generate_map(tests_traces, global_location, output_csv):
    # Given {test: [trace]}, generate a csv file in the following format:
    # test_name,trace_1,trace_2,...
    with open(output_csv, 'w', newline='') as f:
        writer = csv.writer(f)
        for test, traces in tests_traces.items():
            row = [test]
            for trace in traces:
                row.append(trace)
            writer.writerow(row)
    with open(output_csv.replace('.csv', '-location.csv'), 'w', newline='') as f:
        for long_location, short_location in global_location.items():
            f.write('{},{}\n'.format(short_location, long_location))


def main(argv=None):
    argv = argv or sys.argv

    if len(argv) != 3:
        print('Usage: python3 generate_matrix.py <path-to-project> <output-csv> [reduced-test-suite] [raw-event-file]')
        exit(1)

    tests_traces_str, tests_locations_str = get_all_traces(argv[1])
    tests_traces, locations = process_traces(tests_traces_str, tests_locations_str)
    new_tests_traces, global_location = rename_events(tests_traces, locations)
    # remove raw spec unless it is unique
    removed_raw_traces = remove_raw_specs(new_tests_traces)
    removed_raw_traces = equality.update(removed_raw_traces)
    generate_map(removed_raw_traces, global_location, argv[2])


if __name__ == '__main__':
    main()
