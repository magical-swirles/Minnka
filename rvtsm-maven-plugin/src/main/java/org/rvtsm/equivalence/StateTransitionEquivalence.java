package org.rvtsm.equivalence;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.rvtsm.Utils;

public class StateTransitionEquivalence extends Equivalence {

    public Map<String, Set<String>> process(Map<String, Set<String>> matrix) {
        Map<String, Set<String>> newMatrix = new HashMap<>();
        for (Map.Entry<String, Set<String>> entry : matrix.entrySet()) {
            Set<String> newTraces = new HashSet<>();
            for (String trace : entry.getValue()) {
                // We must reset the FSM before we can use it!
                FSM.state = 0;
                FSM.violation = false;

                List<String> newTrace = new ArrayList<>();

                // The goal of this for loop is to expand the events, e.g., it turns e1~2x3 into [e1~2, e1~2, e1~2]
                List<String> originalEvents = new ArrayList<>();
                List<String> expandedEvents = new ArrayList<>();
                Utils.expandTraces(trace, originalEvents, expandedEvents);

//                System.out.println(expandedEvents);
                for (int i = 0; i < expandedEvents.size(); i++) {
                    int previousState = i == 0 ? -1 : FSM.state;
                    int nextState = FSM.transition(expandedEvents.get(i));
//                    System.out.println(previousState + " - > " + nextState);
                    if (nextState != previousState) {
                        // This 'event' is meaningful, because we are in a new state
                        newTrace.add(originalEvents.get(i));
                    }
                    // Otherwise, do nothing (discard the event)
                    if (FSM.violation) {
                        break;
                    }
                }

                newTraces.add(String.join(" ", newTrace));
            }

            newMatrix.put(entry.getKey(), newTraces);
        }
        return newMatrix;
    }
}
