package org.rvtsm.equivalence;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.rvtsm.Utils;

public class ViolationEquivalence extends Equivalence {
    public Map<String, Set<String>> process(Map<String, Set<String>> matrix) {
        Map<String, Set<String>> newMatrix = new HashMap<>();
        for (Map.Entry<String, Set<String>> entry : matrix.entrySet()) {
            Set<String> newTraces = new HashSet<>();

            for (String trace : entry.getValue()) {
                if (trace.startsWith("r")) { // raw trace
                    continue;
                }

                // Expand the events, e.g., it turns e1~2x3 into [e1~2, e1~2, e1~2]
                List<String> originalEvents = new ArrayList<>();
                List<String> expandedEvents = new ArrayList<>();
                Utils.expandTraces(trace, originalEvents, expandedEvents);

                if (isViolating(expandedEvents)) {
                    // If a trace is violating, add that trace to the new matrix
                    newTraces.add(trace);
                }
            }

            if (!newTraces.isEmpty()) {
                // Only add test require to matrix if there are violating traces
                newMatrix.put(entry.getKey(), newTraces);
            }
        }
        return newMatrix;
    }

    /**
     * Return whether a trace is violating based on FSM transitions.
     *
     * @param trace the list of events in the trace (without location)
     * @return true if violating, false otherwise
     */
    private boolean isViolating(List<String> trace) {
        FSM.state = 0;
        FSM.violation = false;

        for (String event : trace) {
            FSM.transition(event);
            if (FSM.violation) {
                return true;
            }
        }

        return false;
    }
}
