#!/usr/bin/env python3
from multiprocessing import Pool

SOFT_LIMIT=50000
MAX_LIMIT=100000

def update(tests_traces):
    for test, traces in tests_traces.items():
        print('processing ' + test)
        tests_traces[test] = simplfy_traces(traces)
    return tests_traces


def simplfy_traces(traces):
    with Pool(50) as pool:
        results = pool.map(simplfy_trace, traces)
        traces_res = set()
        for events in results:
            traces_res.add(' '.join(events))
        return traces_res
    
    
def simplfy_trace(trace):
    if len(trace) > MAX_LIMIT:
        return trace

    events = []
    i = 0
    while i < len(trace):
        current_longest_length = -1
        current_longest_pattern = ''
        current_longest_first_end = -1
        current_longest_last_start = -1
        current_longest_last_end = -1
        
        for j in range(i + 1, min(len(trace), i + 1 + SOFT_LIMIT)):
            k = 0
            while j + k < len(trace) and i + k < j and trace[i + k] == trace[j + k]:
                k += 1
            k -= 1
            if k >= 0 and i + k + 1 == j:
                pattern = trace[i : i + k + 1]
                length = k + 1
                # Check how many time trace[i : i+k+1] shows up after j + k
                y = 0
                while trace[(j+k+1) + length*y : j+k+1 + length*(y+1)] == pattern:
                    y += 1
                # pattern ends at y-1
                # so j+k+1 + length*(y)
                last_start = (j+k+1) + length*(y-1)
                last_end = (j+k+1) + length*y - 1
                
                if length > current_longest_length:
                    current_longest_length = length
                    current_longest_pattern = pattern
                    current_longest_first_end = i + k
                    current_longest_last_start = last_start
                    current_longets_last_end = last_end
                    
        if current_longest_length >= 1:
            i = current_longets_last_end + 1
            events += current_longest_pattern
        else:
            events.append(trace[i])
            i += 1
            
    return events


def __test__():
    print(simplfy_trace(['a', 'b', 'c', 'b', 'c', 'd', 'b', 'c', 'b', 'c', 'd', 'e']) == ['a', 'b', 'c', 'b', 'c', 'd', 'e'])
    print(simplfy_trace(['a', 'b', 'c', 'b', 'c', 'e', 'b', 'c', 'b', 'c', 'd', 'e']) == ['a', 'b', 'c', 'e', 'b', 'c', 'd', 'e'])
    print(simplfy_trace(['a']) == ['a'])
    print(simplfy_trace(['a', 'b', 'a', 'b']) == ['a', 'b'])
    print(simplfy_trace(['a', 'b', 'a', 'b', 'a', 'b']) == ['a', 'b'])
    print(simplfy_trace(['a', 'b', 'a', 'b', 'a', 'b', 'a']) == ['a', 'b', 'a'])
    print(simplfy_trace(['a', 'b']) == ['a', 'b'])
    print(simplfy_trace(['a', 'a']) == ['a'])
    print(simplfy_trace(['a', 'b', 'b', 'a']) == ['a', 'b', 'a'])
    print(simplfy_trace(['a', 'b', 'c', 'd', 'b', 'c', 'd', 'b', 'c']) == ['a', 'b', 'c', 'd', 'b', 'c'])
    
    print(update({'t1': [['a', 'b', 'c', 'a', 'b', 'c'], ['a', 'b', 'a'], ['a', 'a', 'a', 'b']]}) == {'t1': {'a b c', 'a b a', 'a b'}})
    print(update({
        't1': [['a', 'b', 'c', 'a', 'b', 'c'], ['a', 'b', 'a'], ['a', 'a', 'a', 'b']],
        't2': [['a', 'b', 'c', 'b', 'c', 'b', 'c', 'd'], ['a'], ['a', 'a', 'a'], ['b', 'a', 'c', 'a', 'c']]
    }) == {'t1': {'a b c', 'a b a', 'a b'}, 't2': {'a b c d', 'a', 'b a c'}})
    
    
    #if __name__ == '__main__':
    # __test__()
