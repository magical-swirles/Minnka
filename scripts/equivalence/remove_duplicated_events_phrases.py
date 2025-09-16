#!/usr/bin/env python3
import equivalence.remove_duplicated_events as remove_duplicated_events
import equivalence.remove_duplicated_phrases as remove_duplicated_phrases

def update(tests_traces):
    for test, traces in tests_traces.items():
        print('processing ' + test)
        tests_traces[test] = simplfy_traces(traces)
    return tests_traces


def simplfy_traces(traces):
    traces_res = set()
    for trace in traces:
        trace_no_dup_events = remove_duplicated_events.simplfy_trace(trace)
        events = remove_duplicated_phrases.simplfy_trace(trace_no_dup_events)
        traces_res.add(' '.join(events))
    return traces_res
