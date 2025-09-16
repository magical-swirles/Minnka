#! /usr/bin/python3
import os
import csv
import sys


conservative = False

def main(args):
    if len(args) < 6:
      print("Usage: python3 skip_monitoring.py <matrix-file> <location-file> <test-suite-file> <spec-encoding-file> <output-dir> [conservative]")
      exit(1)

    matrix_file = args[1]
    location_file = args[2]
    test_suite_file = args[3]
    encoding_file = args[4]
    output_dir = args[5]
    if len(args) == 7:
      global conservative
      conservative = bool(args[6])
    skip_monitoring(matrix_file, location_file, test_suite_file, encoding_file, output_dir)


def skip_monitoring(matrix_file, location_file, test_suite_file, encoding_file, output_dir):
  tests_to_traces = {}
  events_freq = {}
  traces_freq = {}
  test_suite = set()
  id_to_location = {}
  spec_mapping = {}
  tests_to_event_to_traces = {}
  
  with open(test_suite_file) as f:
    for test in f.readlines():
      test = test.strip()
      if not test:
        continue
      test_suite.add(test)

  with open(location_file) as f:
    for id_location in f.readlines():
      id_location = id_location.strip()
      if not id_location:
        continue
      loc_id, _, loc_str = id_location.partition(',')
      klass, line = loc_str.split('(')
      klass = klass.rpartition('.')[0]
      line = line.partition(':')[2].partition(')')[0]
      id_to_location[loc_id] = klass + line
  
  with open(encoding_file) as f:
    for line in f.readlines():
      line = line.strip()
      if not line:
        continue
      spec_name, _, event_id = line.split(',')
      spec_mapping[event_id] = spec_name

  with open(matrix_file) as f:
    for test_traces in f.readlines():
      test_traces = test_traces.strip()
      if not test_traces:
        continue
      data = test_traces.split(',')
      test = data[0]
      if test not in test_suite:
        # eliminated by TSM
        continue
  
      traces = []
      if len(data) > 1:
        traces = data[1:]
      for trace in traces:
        if trace.startswith('r'):
          # eliminted by raw
          continue
        
        if not conservative:
          # need to build tests_to_event_to_traces
          if test not in tests_to_event_to_traces:
            tests_to_event_to_traces[test] = {}
            
          for event in set(trace.split(' ')):
            if 'x' in event:
              event = event.split('x')[0]
            if event not in tests_to_event_to_traces[test]:
              tests_to_event_to_traces[test][event] = set([trace])
            else:
              tests_to_event_to_traces[test][event].add(trace)
          
          if trace in traces_freq:
            # saw this trace b4
            traces_freq[trace].add(test)
          else:
            # this trace is totally new
            traces_freq[trace] = set([test])
        else:
          # track events_freq (event in unique traces, ie unique events)
          if trace in traces_freq:
            # saw this trace b4
            traces_freq[trace].add(test)
          else:
            # this trace is totally new
            traces_freq[trace] = set([test])
            for event in set(trace.split(' ')):
              if 'x' in event:
                event = event.split('x')[0]
              if event in events_freq:
                events_freq[event].add(test)
              else:
                events_freq[event] = set([test])

  spec_to_test_to_excluded = {}
  if not conservative:
    for trace, tests in traces_freq.items():
    #   print(trace, tests)
      benefit_tests = set()
      if len(tests) > 1:
        # multiple tests have this trace
        for test in tests:
          events = set(trace.split(' '))
          for event in events:
            if 'x' in event:
              event = event.split('x')[0]
            if len(tests_to_event_to_traces[test][event]) == 1:
              # this test can exclude this trace
              benefit_tests.add(test)
      if len(tests) == len(benefit_tests):
        # although all test can exclude this trace, one test should still monitor it
        benefit_tests.pop();
      if len(benefit_tests) > 0:
        spec = None
        trace_excluded = set()
        print('trace {} has {} tests'.format(trace, len(benefit_tests)))
        for event in events:
          if not spec:
            event_id = event.partition('~')[0][1:]
            spec = spec_mapping[event_id]
          loc_id = event.partition('~')[2]
          trace_excluded.add(id_to_location[loc_id])

        if spec not in spec_to_test_to_excluded:
          spec_to_test_to_excluded[spec] = {}
        skip = False
        for test in benefit_tests:
          if test not in spec_to_test_to_excluded[spec]:
            spec_to_test_to_excluded[spec][test] = set()
          spec_to_test_to_excluded[spec][test].update(trace_excluded)
  else:
    for trace, tests in traces_freq.items():
    #   print(trace, tests)
      if len(tests) > 1:
        # multiple tests have this trace
        events_are_unique = True
        events = set(trace.split(' '))
        for event in events:
          if 'x' in event:
            event = event.split('x')[0]
          if len(events_freq[event]) != 1:
            # more than 2+ tests have unique trace with this event
            events_are_unique = False
            break
        spec = None
        trace_excluded = set()
        if events_are_unique:
          print('trace {} has {} tests'.format(trace, len(tests)))
          for event in events:
            if not spec:
              event_id = event.partition('~')[0][1:]
              spec = spec_mapping[event_id]
            loc_id = event.partition('~')[2]
            trace_excluded.add(id_to_location[loc_id])
            
          if spec not in spec_to_test_to_excluded:
            spec_to_test_to_excluded[spec] = {}
          skip = False
          for test in tests:
            if not skip:
              # first test should still monitor the events
              skip = True
              continue
            if test not in spec_to_test_to_excluded[spec]:
              spec_to_test_to_excluded[spec][test] = set()
            spec_to_test_to_excluded[spec][test].update(trace_excluded)

  cwd = os.getcwd()
  os.makedirs(output_dir, exist_ok=True)
  script = []
  unset_script = []
  for spec, test_to_excluded in spec_to_test_to_excluded.items():
    unset_script.append('unset SKIP_{}'.format(spec))
    if output_dir.startswith('/'):
      script.append('export SKIP_{}={}\n'.format(spec, os.path.join(output_dir, 'SKIP_{}.csv'.format(spec))))
    else:
      script.append('export SKIP_{}={}\n'.format(spec, os.path.join(cwd, output_dir, 'SKIP_{}.csv'.format(spec))))
    with open(os.path.join(output_dir, 'SKIP_{}.csv'.format(spec)), 'w') as f:
      for test, excluded in test_to_excluded.items():
        f.write('{},{}\n'.format(test, ','.join(excluded)))
  with open(os.path.join(output_dir, 'setup.sh'), 'w') as f:
    f.writelines(script)
  with open(os.path.join(output_dir, 'cleanup.sh'), 'w') as f:
    f.writelines(unset_script)
    

if __name__ == '__main__':
    csv.field_size_limit(sys.maxsize)
    main(sys.argv)
