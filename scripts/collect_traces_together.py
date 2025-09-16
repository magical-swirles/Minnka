#!/usr/bin/env python3
#
# Run `mvn surefire:test` with TraceMOP to collect traces for each test
# Usage: collect_traces.py <project-directory> <project-name> <extension-directory> <mop-directory> <log-directory> [threads=20] [timeout=20]
# Output: Multiple traces directories in `projects/<project-name>/.all-traces` directory
#         And the overall result in traces-result.csv
#
import os
import re
import csv
import sys
import time
import shutil
import subprocess
from multiprocessing import Pool


OS_ENV = os.environ
project_directory, project_name, extension_directory, mop_directory, log_directory, threads, timeout = "", "", "", "", "", 20, 20
script_dir = os.path.dirname(os.path.abspath(__file__))

def collect():
    print('Collecting tests')

    # Create temporary directories
    tmp_dir = os.path.join(os.sep, 'tmp', 'tsm')
    traces_dir = os.path.join(tmp_dir, '.traces')
    os.makedirs(tmp_dir, exist_ok=True)
    os.makedirs(traces_dir, exist_ok=True)

    status = 'PASS'
    e2e_time = -1
    test_num = -1
    build_time = -1
    test_time = -1
    
    print('[TSM] Timeout is set to {}s'.format(timeout * 60))

    try:
        with open(os.path.join(log_directory, project_name, 'tests.log'), 'w') as f:
            start = time.time()

            # Running surefire:test with the following options
            # -Djava.io.tmpdir: set java tmp directory
            # -Dmaven.ext.class.path: set JavaMOP extension
            # -Dtest: set test
            # -DtempDir: set surefire's tmp directory
            result = subprocess.run(['mvn', '-Djava.io.tmpdir={}'.format(tmp_dir),
                '-Dmaven.repo.local={}/repo{}'.format(project_directory, os.getenv('REPO_SUFFIX', '')),
                '-Dsurefire.exitTimeout={}'.format(timeout * 60),
                '-Dmaven.ext.class.path={}/javamop-extension-1.0.jar'.format(extension_directory),
                'surefire:test', '-DtempDir=tmp'],
                stdout=f, stderr=subprocess.STDOUT,
                cwd=os.path.join(project_directory, project_name), timeout=timeout * 60,
                env={
                    **OS_ENV,
                    'PROJECT_BUILD_DIRECTORY': str(os.path.join(tmp_dir, '.target')),
                    'TRACEDB_PATH': traces_dir,
                    'TRACEDB_CONFIG_PATH': os.path.join(script_dir, '.trace-db.config'),
                    'JUNIT_MEASURE_TIME_LISTENER': '1',
                    'COLLECT_MONITORS': '1',
                    'COLLECT_TRACES': '1',
                    'RVMLOGGINGLEVEL': 'UNIQUE'
                }
            )
            e2e_time = time.time() - start
            f.write('time: {} s\n'.format(round(e2e_time, 3)))

        move_traces(traces_dir)

        test_num, build_time, test_time = stats()
        if result.returncode != 0 and test_num > 0:
            status = 'FAIL'
            print('[TSM] Failed to collect traces')

        if test_num == 0:
            status = 'No_TEST'
            print('[TSM] Failed to collect traces (no test)')
    except subprocess.TimeoutExpired:
        print('[TSM] Failed to collect traces (timeout)')
        status = 'TIMEOUT'
    except Exception as e:
        print('[TSM] Failed to collect traces ({})'.format(repr(e)))
        status = 'EXCEPTION'

    cleanup(tmp_dir)

    result = (status, e2e_time, test_num, build_time, test_time)

    try:
        # Write out test result just in case
        with open(os.path.join(log_directory, project_name, 'tests.csv'), 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerows([result])
    except:
        pass

    return result


def stats():
    log_path = os.path.join(log_directory, project_name, 'tests.log')
    test_num, build_time, test_time = -1, -1, -1
    if os.path.exists(log_path):
        with open(log_path, 'r') as f:
            for line in reversed(f.readlines()):
                if test_num != -1 and build_time != -1 and test_time != -1:
                    break

                # Check total from log
                # example: [INFO] Total time:  6.489 s
                if line.startswith('[INFO] Total time:'):
                    x = line.split(' ')[4]
                    if ':' in x:
                        build_time = float(x.split(':')[0]) * 60 + int(x.split(':')[1])
                    else:
                        build_time = float(x)
                
                # example: [TSM] JUnit Total Time: 1951
                if line.startswith('[TSM] JUnit Total Time:'):
                    x = line.split(' ')[4]
                    test_time = float(x) / 1000 # convert ms to s

                # Check # of tests run
                # example: [INFO] Tests run: 1, Failures: 0, Errors: 0, Skipped: 0
                match = re.search('Tests run: (\d+),', line)
                if match:
                    test_num = int(match.group(1))
    return test_num, build_time, test_time


def move_traces(traces_dir):
    test_dir_dest = os.path.join(project_directory, project_name, '.all-traces')
    if os.path.isdir(test_dir_dest):
        shutil.rmtree(test_dir_dest, True)
    shutil.move(traces_dir, test_dir_dest)


def cleanup(tmp_dir):
    if os.path.isdir(tmp_dir):
        # Delete local repository and ignore error
        # # We need to add write permission because projects like apache/commons-io will create non-writable directories in tmp_dir
        subprocess.run(['chmod', '-R', '+w', tmp_dir])
        shutil.rmtree(tmp_dir, True)


def start():
    os.makedirs(os.path.join(project_directory, project_name, '.all-traces'), exist_ok=True)
    os.makedirs(os.path.join(log_directory, project_name), exist_ok=True)

    tests = []

    with open(os.path.join(project_directory, project_name, 'tests.txt')) as f:
        for test in f.readlines():
            test = test.strip()
            if test:
                tests.append(test)

    print('Start collecting traces for {} tests'.format(len(tests)))
    res = collect()
    with open(os.path.join(log_directory, project_name, 'traces-result.csv'), 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerows([res])
    # No reason to generate statistics table if we cannot collect traces
    exit(1) if res[0] != "PASS" else exit(0)


def main(argv=None):
    argv = argv or sys.argv

    if len(argv) < 6:
        print('Usage: python3 collect_traces_together.py <project-directory> <project-name> <extension-directory> <mop-directory> <log-directory> [threads=20] [timeout=20]')
        exit(1)

    global project_directory, project_name, extension_directory, mop_directory, log_directory, threads, timeout
    project_directory = argv[1]
    project_name = argv[2]
    extension_directory = os.path.abspath(argv[3])
    mop_directory = os.path.abspath(argv[4])
    log_directory = os.path.abspath(argv[5])
    threads = int(argv[6]) if len(argv) >= 6 else 20
    timeout = int(argv[7]) if len(argv) >= 7 else 20

    if not os.path.exists(os.path.join(project_directory, project_name, 'tests.txt')):
        print('Cannot find tests.txt file in project repository.')
        exit(1)

    start()


if __name__ == '__main__':
    main()
