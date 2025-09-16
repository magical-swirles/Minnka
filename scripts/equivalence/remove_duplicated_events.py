#!/usr/bin/env python3

def update(tests_traces):
    for test, traces in tests_traces.items():
        print('processing ' + test)
        tests_traces[test] = simplfy_traces(traces)
    return tests_traces


def simplfy_traces(traces):
    traces_res = set()
    for trace in traces:
        events = simplfy_trace(trace)
        traces_res.add(' '.join(events))
    return traces_res


def simplfy_trace(trace):
    events = []
    i = 0
    while i < len(trace):
        for j in range(i + 1, len(trace) + 1):
            if j >= len(trace) or trace[i] != trace[j]:
                break
        # i to j-1 are the same
        if i != j - 1:
            # length is j - 1
            events.append(trace[i]) # treat them like a single event
#               events.append(trace[i] + ' x {}'.format(j - i))  # show frequency
        else:
            # length is 1
            events.append(trace[i])
        i = j
    return events
