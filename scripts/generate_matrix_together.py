#!/usr/bin/env python3
#
# Put all the tests and their traces into a single csv file
# Usage: python3 generate_matrix_together.py <path-to-project> <output-csv> [equivalence: equality]
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
import equivalence.remove_duplicated_events as remove_duplicated_events
import equivalence.remove_duplicated_phrases as remove_duplicated_phrases
import equivalence.remove_duplicated_events_phrases as remove_duplicated_events_phrases
import equivalence.equality as equality
from pathlib import Path
from collections import defaultdict

def get_traces_from_file(traces_dir):
    unique_traces_file = os.path.join(traces_dir, 'unique-traces.txt')
    unique_traces_file_compressed = os.path.join(traces_dir, 'unique-traces.txt.gz')

    traces_started = False

    if os.path.isfile(unique_traces_file):
        open_using = open
        filename = unique_traces_file
    else:
        open_using = gzip.open
        filename = unique_traces_file_compressed

    trace_id_to_trace = {}
    with open_using(filename, 'rt') as f:
        for line in f:
            line = line.strip();
            if traces_started:
                if line:
                    trace_id_to_trace[line.split(' ')[0]] = line.split(' ', 1)[1]
                    # e.g., '123' -> '[e30~8, e30~11, e30~12, e30~13, e30~14, e30~19]'
                else:
                    # Empty line means it is EOF
                    break
            elif '=== UNIQUE TRACES ===' in line:
                traces_started = True

    traces = {} # {test: [frequency, trace]}
    with open(os.path.join(traces_dir, 'specs-test.csv')) as f:
        counter = 0 # This is used to shift trace ID so that they are consecutive
        for line in f:
            line = line.strip()
            if line == 'OK':
                continue
            if not line:
                continue
                
            # Handle multiple test cases in a single line
            # Format: trace_id {test1(file:line)=freq1, test2(file:line)=freq2, ...}
            parts = line.split(' ', 1)
            trace_id = parts[0]
            if int(trace_id) > counter:
                trace_id = str(counter)
            
            # Check if we have multiple test cases in curly braces
            if '{' in parts[1] and '}' in parts[1]:
                test_cases_str = parts[1].strip('{}')
                # Split by comma to get individual test cases
                test_cases = test_cases_str.split(', ')
                
                for test_case in test_cases:
                    # Extract test name and frequency
                    match = re.match(r'([^(]*)(?:\(([^)]*)\))?=(\d+)', test_case)
                    if match:
                        test_full_name = match.group(1)
                        test_file = match.group(2)
                        frequency = match.group(3)
                        
                        if test_full_name and test_file:
                            # Format test name as className#methodName
                            test_name = test_full_name.rsplit('.', 1)[0] + '#' + test_full_name.rsplit('.', 1)[1]
                        else:
                            test_name = "NoTest" # These are traces that do not begin in any test method.

                        if test_name not in traces:
                            traces[test_name] = []
                        if trace_id in trace_id_to_trace:
                            traces[test_name].append(frequency + ' ' + trace_id_to_trace[trace_id])
                
                counter += 1

    return traces

# Some traces are not associated with any test method.
# This function assigns those traces to the correct test method based on the location.
def assign_traces_to_test_methods(traces, locations_file, tests_txt):
    location_map = {}
    with open(locations_file, "r") as f:
        lines = f.readlines()
        # Skip first row
        for line in lines[1:]:
            location_id = line.split(" ")[0]
            location = line.split(" ")[1].strip()
            location_map[location_id] = location
    # Do something special for NoTest
    if "NoTest" in traces:
        """
        traces_to_assign = traces["NoTest"]
        for trace in traces_to_assign:
            # e.g., trace is '[e30~8, e30~11, e30~12, e30~13, e30~14, e30~19]'
            # It is NOT enough to just check the first event,
            # because some traces involve multiple test classes
            test_classes_for_trace = set()
            for event in trace.split(', '):
                location_id = event.strip('[]').split('~')[1].split('x')[0]
                location = location_map[location_id]
                test_class = location.split('(')[0].rsplit('.', 1)[0].split('$')[0]
                test_classes_for_trace.add(test_class)
            # It might not be appropriate to use traces.keys, because some test methods are not in traces.keys,
            # due to the fact that all the traces they have in parallel runs come from places like static
            # initializer blocks, which are not associated with any test method.
            # for test_method in traces.keys():
            #     if test_method.startswith(test_class):
            #         traces[test_method].append(trace)
            with open(tests_txt) as f:
                test_methods = f.readlines()
                for test_method in test_methods:
                    test_method = test_method.strip()
                    test_class_name = test_method.split('#')[0]
                    if any(test_class_name.startswith(test_class) for test_class in test_classes_for_trace):
                        if test_method in traces.keys():
                            traces[test_method].append(trace)
                        else:
                            traces[test_method] = []
                            traces[test_method].append(trace)
        """
        del traces["NoTest"]
    return traces

def get_all_traces(project_path):
    # Load unique traces and map into memory
    path = Path(os.path.join(project_path, '.all-traces'))
    if not os.path.isdir(path):
        return {}, {}

    traces = {}	# {test: [frequency, trace]}

    unique_traces_file = os.path.join(path, 'unique-traces.txt')
    unique_traces_file_compressed = os.path.join(path, 'unique-traces.txt.gz')
    locations_file = os.path.join(path, 'locations.txt')
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

        traces = get_traces_from_file(path)
        traces = assign_traces_to_test_methods(traces, locations_file, os.path.join(project_path, 'tests.txt'))

    return traces


def process_traces(tests_traces_str):
    # tests_traces_str: Given {test: [frequency, trace]}, return {test: [trace]}
    for test, traces_str in tests_traces_str.items():
        result = []
        for trace_str in traces_str:
            # For example, if trace_str is "1 [next~1, next~1, next~1, next~1, next~1]",
            # add "[next~1, next~1, next~1, next~1, next~1]" to result
            # However, if trace_str is "1 []" then don't add [] to result
            match = re.match('^\d+ \[(.+)\]$', trace_str)
            if match:
                result.append(match.group(1).split(', '))
        tests_traces_str[test] = result

    return tests_traces_str


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
    return tests_traces  # {test: [traces]} => {test: [[event]]}


def generate_map(tests_traces, output_csv):
    # Given {test: [trace]}, generate a csv file in the following format:
    # test_name,trace_1,trace_2,...
    with open(output_csv, 'w', newline='') as f:
        writer = csv.writer(f)
        for test, traces in tests_traces.items():
            row = [test]
            for trace in traces:
                row.append(trace)
            writer.writerow(row)


def main(argv=None):
    argv = argv or sys.argv

    if len(argv) != 3 and len(argv) != 4:
        print('Usage: python3 generate_matrix.py <path-to-project> <output-csv> [equivalence: equality]')
        exit(1)

    equivalence = 'equality'
    if len(argv) == 4:
        if argv[3] != 'equality' and argv[3] != 'remove_duplicated_events' and argv[3] != 'remove_duplicated_phrases' and argv[3] != 'remove_duplicated_events_phrases':
            print('equivalence must be: equality, remove_duplicated_events, remove_duplicated_phrases, or remove_duplicated_events_phrases')
            exit(1)
        equivalence = argv[3]

    tests_traces_str = get_all_traces(argv[1])
    tests_traces = process_traces(tests_traces_str)
    
    if equivalence == 'equality':
        tests_traces = equality.update(tests_traces)
    elif equivalence == 'remove_duplicated_events':
        tests_traces = remove_duplicated_events.update(tests_traces)
    elif equivalence == 'remove_duplicated_phrases':
        tests_traces = remove_duplicated_phrases.update(tests_traces)
    elif equivalence == 'remove_duplicated_events_phrases':
        tests_traces = remove_duplicated_events_phrases.update(tests_traces)

    generate_map(tests_traces, argv[2])


if __name__ == '__main__':
    main()
