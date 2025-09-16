import sys
import os
import statistics
from collections import Counter

def count_tests_per_unique_trace(matrix_file):
    to_return = []
    lines = {}
    unique_traces = []
    tests = []
    with open(matrix_file, 'r') as f:
        for line in f:
            tests.append(line.split(',')[0])
            unique_traces += line.split(',')[1:]
            lines[line.split(',')[0]] = line.split(',')[1:]
    # For each unique trace, count how many tests have it
    counts = Counter(unique_traces)
    to_return = list(counts.values())
    return to_return

def count_unique_traces_per_test(matrix_file):
    to_return = []
    with open(matrix_file, 'r') as f:
        lines = f.readlines()
        to_return = [line.count(',') for line in lines]
        return to_return

def get_essential_tests(matrix_file):
    lines = {}
    unique_traces = []
    all_tests = []
    with open(matrix_file, 'r') as f:
        for line in f:
            all_tests.append(line.split(',')[0])
            unique_traces += line.split(',')[1:]
            lines[line.split(',')[0]] = line.split(',')[1:]
    # Build a map from unique trace to tests
    trace_to_tests = {}
    for test, traces in lines.items():
        for trace in traces:
            if trace not in trace_to_tests:
                trace_to_tests[trace] = []
            trace_to_tests[trace].append(test)
    essential_tests = set()
    for trace, tests in trace_to_tests.items():
        if len(tests) == 1:
            essential_tests.add(tests[0])
    return all_tests, essential_tests

def get_essential_tests_percentage(matrix_file):
    all_tests, essential_tests = get_essential_tests(matrix_file)
    return [len(essential_tests) / len(all_tests)]

def get_time_contributions_of_essential_tests(matrix_file, time_contribution_csv):
    _, essential_tests = get_essential_tests(matrix_file)
    test_to_rv_time = {}
    with open(time_contribution_csv, 'r') as f:
        for line in f:
            test, rv_time = line.strip().split(',')
            test_to_rv_time[test] = float(rv_time)
    essential_tests_time = 0
    for test in essential_tests:
        if test not in test_to_rv_time:
            print(f"Test {test} not in {time_contribution_csv}. Assuming 0.")
            continue
        essential_tests_time += test_to_rv_time[test]
    if sum(test_to_rv_time.values()) == 0:
        print(f"Warning: Total RV time is 0 in {time_contribution_csv}.")
        return [0]
    return [essential_tests_time / sum(test_to_rv_time.values())]

if __name__ == '__main__':
    op = sys.argv[1]
    noe = sys.argv[2]
    test_to_time_dir = sys.argv[3]
    build_matrix_dirs = sys.argv[4:]
    acc = []
    for dir in build_matrix_dirs:
        if not os.path.isdir(dir):
            print(f"Directory {dir} does not exist.")
            continue
        for project in os.listdir(dir):
            matrix_file = os.path.join(dir, project, 'project', 'tsm-matrix', 'tests-state-online_detour-prefix.csv' if noe == 'noe' else 'tests-perfect.csv')
            if not os.path.isfile(matrix_file):
                print(f"Matrix file {matrix_file} does not exist.")
                continue
            if op == 'count_unique_traces_per_test':
                acc += count_unique_traces_per_test(matrix_file)
            if op == 'count_tests_per_unique_trace':
                acc += count_tests_per_unique_trace(matrix_file)
            if op == 'get_essential_tests_percentage':
                acc += get_essential_tests_percentage(matrix_file)
            if op == 'get_essential_tests_time_contributions':
                time_contribution_file = os.path.join(test_to_time_dir, f'{project}.csv')
                if not os.path.exists(time_contribution_file):
                    print(f"No RV time info for project {project}.")
                    continue
                result = get_time_contributions_of_essential_tests(matrix_file, time_contribution_file)
                if result != [0]:
                    acc += result
                    with open('tmp.csv', 'a') as f:
                        f.write(f"{project},{result[0]}\n")
    print(statistics.mean(acc))

