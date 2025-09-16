#!/usr/bin/env python3

def update(tests_traces):
    for test, traces in tests_traces.items():
        new_traces = []
        for trace in traces:
            new_traces.append(' '.join(trace))
        tests_traces[test] = new_traces
    return tests_traces
