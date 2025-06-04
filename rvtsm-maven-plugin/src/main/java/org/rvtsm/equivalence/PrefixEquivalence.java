package org.rvtsm.equivalence;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.rvtsm.Utils;
import org.rvtsm.equivalence.datastructure.Trie;

public class PrefixEquivalence extends Equivalence {

    /**
     * t1 is equivalent to t2 if t1 is a prefix of t2 and t1 is a violating trace
     * Implementation: for each trace, we first find the shortest prefix that leads to a violation
     * If t1 (violating) is a prefix of t2, then shortest_violating_prefix(t1) = shortest_violating_prefix(t2)
     * Therefore, if T1 covers t1 and T2 covers t2, we can choose either T1 or T2
     * If t1 is not a violating trace, then we remove t1 from test requirement, because we have to monitor t2.
     * Therefore, if T1 covers t1 and T2 covers t2, we must choose T2
     *
     * @param matrix the original matrix to process
     * @return the processed matrix after applying prefix equivalence
     */
    public Map<String, Set<String>> process(Map<String, Set<String>> matrix) {
        Map<String, Set<String>> newMatrix = new HashMap<>();
        Map<String, Set<String>> traceToTests = new HashMap<>(); // we need this map to help us remove other TR.
        Trie prefixTree = new Trie();

        for (Map.Entry<String, Set<String>> entry : matrix.entrySet()) {
            Set<String> newTraces = new HashSet<>();

            for (String trace : entry.getValue()) {
                // Expand the events, e.g., it turns e1~2x3 into [e1~2, e1~2, e1~2]
                List<String> originalEvents = new ArrayList<>();
                List<String> expandedEvents = new ArrayList<>();
                Utils.expandTraces(trace, originalEvents, expandedEvents);

                List<String> newTrace = shortestViolatingPrefix(originalEvents, expandedEvents);
                if (newTrace != null) {
//                    System.out.println("Trace " + originalEvents + " is violating! Shortest prefix is " + newTrace);
                    // This trace is a violating trace, so we keep the trace and add it to the new matrix
                    newTraces.add(String.join(" ", newTrace));
                } else {
//                    System.out.println("Trace " + originalEvents + " is NOT violating!");
                    newTrace = originalEvents;
                }

                List<String> previousPrefix = prefixTree.addTraceIfRequired(newTrace);
                if (previousPrefix != null) {
//                    System.out.println(newTrace + " is a new trace, with " + previousPrefix + " prefixes");
                    // This is a new trace (not a prefix of others)
                    // I think previousPrefix is always size 0 or 1, we should not have multiple prefixes
                    // Because we will remove them when we extend the trie

                    String finalTrace = String.join(" ", newTrace);
                    newTraces.add(finalTrace);
                    traceToTests.computeIfAbsent(finalTrace, k -> new HashSet<>()).add(entry.getKey());

                    // Remove shorter prefixes from the new matrix
                    for (String shorterTrace : previousPrefix) {
                        Set<String> tests = traceToTests.getOrDefault(shorterTrace, new HashSet<>());
//                        System.out.println("Removing " + shorterTrace + " from the new matrix (in test " + tests + ")");
                        for (String test : tests) {
                            if (test.equals(entry.getKey())) {
                                newTraces.remove(shorterTrace);
                            } else {
                                newMatrix.get(test).remove(shorterTrace);
                            }
                        }
                    }
                } else {
                    // Otherwise, this trace is a prefix of another trace, we can discard this test requirement
                    // Because we have to monitor the longer trace
//                    System.out.println(newTrace + " is a prefix of another trace, so we don't add it to TR.");
                }
            }
            newMatrix.put(entry.getKey(), newTraces);
        }

//        System.out.println(newMatrix);

        return newMatrix;
    }

    /**
     * Finds the shortest prefix that leads to a violation.
     * @param originalEvents the list of original events
     * @param expandedEvents the list of expanded events (with locations removed)
     * @return the shortest prefix that leads to a violation or null if no violation is found
     */
    public static List<String> shortestViolatingPrefix(List<String> originalEvents, List<String> expandedEvents) {
        List<String> newTrace = new ArrayList<>();

        // We must reset the FSM before we can sue it!
        FSM.state = 0;
        FSM.violation = false;

        for (int i = 0; i < expandedEvents.size(); i++) {
            FSM.transition(expandedEvents.get(i));
            newTrace.add(originalEvents.get(i));

            if (FSM.violation) {
                // Stop processing the trace, because we have a violation. So this is the shortestViolatingPrefix
                return newTrace;
            }
        }

        return null;
    }
}
