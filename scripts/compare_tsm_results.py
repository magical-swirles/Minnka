# Given two TSM results A and B (map from test method to set of traces),
# compare them and print the set and size of A_i\B_i
# for all i in (testMethods(A) union testMethods(B)).
# Arguments:
# - Project A's directory, assumed to contain:
#   - .all-traces/: directory containing detailed metadata for the test method
#   - tests.csv: the tsm test requirements matrix
# - Project B's directory, assumed to contain the same things
# It will be automatically decided whether any of them is run in parallel or in one go.

import csv
import gzip
import os
import re
import sys
from typing import Dict, List

# Debug function to inspect test method to traces map.
def inspect_traces(test_method_to_traces: Dict[str, List[List[str]]]):
    for test_method, traces in test_method_to_traces.items():
        print(test_method, end=" -> ")
        print(traces)

# Check if the project is run in parallel or in one go.
# If the project is run in parallel, under .all-traces/,
# there will be multiple directories, each corresponding to a test method.
def is_parallel(project_dir: str) -> bool:
    all_traces_dir = os.path.join(project_dir, ".all-traces")
    if os.path.exists(all_traces_dir):
        # Check if there are any directories inside .all-traces
        for item in os.listdir(all_traces_dir):
            item_path = os.path.join(all_traces_dir, item)
            if os.path.isdir(item_path):
                return True
        # If we got here, there are only files, no directories
        return False
    
# Given an event, replace it with the full location of the test method based on location map.
# e.g. 'e1~54x3' -> 'e1~org.example.TestClass#testMethod~3'
def replace_with_full_location(event: str, location_map: Dict[str, str]) -> str:
    # Regular expression to match patterns like 'e1~54x3' or 'e1~54'
    # Captures three groups: the event ID, the location ID, and possible repetitions
    pattern = re.compile(r'e(\d+)~(\d+)(?:x(\d+))?')
    # Extract components from the event string
    match = pattern.match(event)
    if match:
        event_id = match.group(1)
        location_id = match.group(2)
        count = match.group(3) if match.group(3) else ""
        
        # Look up the full location in the location map
        if location_id in location_map:
            full_location = location_map[location_id]
            return f"e{event_id}~{full_location}" + (f"~{count}" if count else "")
        else:
            # If location not found in map, return the original event
            return event
    else:
        # If the pattern doesn't match, return the original event
        return event

def load_location_map_from_file(location_map_file: str) -> Dict[str, str]:
    location_map = {}
    with open(location_map_file, "r") as f:
        lines = f.readlines()
        # Skip first row
        for line in lines[1:]:
            location_id = line.split(" ")[0]
            location = line.split(" ")[1].strip()
            location_map[location_id] = location
    return location_map

def get_test_method_to_traces_parallel(project_dir: str) -> Dict[str, List[List[str]]]:
    test_method_to_traces = {}
    # Get all directories under .all-traces
    all_traces_dir = os.path.join(project_dir, ".all-traces")
    for test_method in os.listdir(all_traces_dir):
        test_method_dir = os.path.join(all_traces_dir, test_method)
        if os.path.isdir(test_method_dir):
            test_method_to_traces[test_method] = []
            if not os.listdir(test_method_dir):
                continue # No traces for this test method
            local_map = load_location_map_from_file(os.path.join(test_method_dir, "locations.txt"))
            # Process the unique-traces.txt.gz file for this test method
            unique_traces_file = os.path.join(test_method_dir, "unique-traces.txt.gz")
            if os.path.exists(unique_traces_file):
                with gzip.open(unique_traces_file, 'rt') as f:
                    for line in f:
                        if "UNIQUE TRACES" in line:
                            continue
                        line = line.strip()
                        if line:
                            unique_trace = line.split(" ", 1)[1].replace("[", "").replace("]", "")
                            # Replace each event with its full location
                            trace = [replace_with_full_location(event, local_map) for event in unique_trace.split(", ")]
                            if remove_clinit:
                                trace = [event for event in trace if not "<clinit>" in event]
                            test_method_to_traces[test_method].append(trace)
            else:
                # Check for uncompressed file as fallback
                uncompressed_file = os.path.join(test_method_dir, "unique-traces.txt")
                if os.path.exists(uncompressed_file):
                    with open(uncompressed_file, 'r') as f:
                        for line in f:
                            if "UNIQUE TRACES" in line:
                                continue
                            line = line.strip()
                            if line:
                                unique_trace = line.split(" ", 1)[1].replace("[", "").replace("]", "")
                                # Replace each event with its full location
                                trace = [replace_with_full_location(event, local_map) for event in unique_trace.split(", ")]
                                if remove_clinit:
                                    trace = [event for event in trace if not "<clinit>" in event]
                                test_method_to_traces[test_method].append(trace)

    return test_method_to_traces

def get_test_method_to_traces_centralized(project_dir: str) -> Dict[str, List[List[str]]]:
    test_method_to_traces = {}
    location_map = load_location_map_from_file(os.path.join(project_dir, ".all-traces", "locations.txt"))
    with open(os.path.join(project_dir, "tests.csv"), "r") as f:
        reader = csv.reader(f)
        for row in reader:
            test_method = row[0] # e.g. 'org.example.TestClass#testMethod'
            raw_traces = row[1:] # e.g. ['e1~54x3', 'e116~74 e117~74']
            traces = []
            for raw_trace in raw_traces:
                trace = [replace_with_full_location(event, location_map) for event in raw_trace.split(" ")]
                if remove_clinit:
                    trace = [event for event in trace if not "<clinit>" in event]
                traces.append(trace)
            test_method_to_traces[test_method] = traces
    return test_method_to_traces

# Compares and prints the set difference and its size per test method.
def compare(a: Dict[str, List[List[str]]], b: Dict[str, List[List[str]]]):
    total_diff_size = 0
    for test_method in a.keys():
        if test_method not in b:
            a_remove_empty = [trace for trace in a[test_method] if trace != []]
            print(test_method + ";" + str(len(a_remove_empty)) + ";" + str(a_remove_empty))
            total_diff_size += len(a_remove_empty)
        else:
            only_a = []
            for trace in a[test_method]:
                if trace not in b[test_method] and trace != []:
                    only_a.append(trace)
            print(test_method + ";" + str(len(only_a)) + ";" + str(only_a))
            total_diff_size += len(only_a)
    print("Total difference size: " + str(total_diff_size))
if __name__ == "__main__":
    project_a = sys.argv[1]
    project_b = sys.argv[2]
    remove_clinit = sys.argv[3].lower() == "true"

    test_method_to_traces_a = get_test_method_to_traces_parallel(project_a) if is_parallel(project_a) else get_test_method_to_traces_centralized(project_a)
    inspect_traces(test_method_to_traces_a)
    test_method_to_traces_b = get_test_method_to_traces_parallel(project_b) if is_parallel(project_b) else get_test_method_to_traces_centralized(project_b)
    inspect_traces(test_method_to_traces_b)

    compare(test_method_to_traces_a, test_method_to_traces_b)
