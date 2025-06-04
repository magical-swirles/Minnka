package org.rvtsm.equivalence;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.rvtsm.Utils;

public class OnlineDetourEquivalence extends Equivalence {
    public Map<String, Set<String>> process(Map<String, Set<String>> matrix) {
        Map<String, Set<String>> newMatrix = new HashMap<>();
        for (Map.Entry<String, Set<String>> entry : matrix.entrySet()) {
            Set<String> newTraces = new HashSet<>();

            for (String trace : entry.getValue()) {
                // Expand the events, e.g., it turns e1~2x3 into [e1~2, e1~2, e1~2]
                List<String> originalEvents = new ArrayList<>();
                List<String> expandedEvents = new ArrayList<>();
                Utils.expandTraces(trace, originalEvents, expandedEvents);

                newTraces.add(reduceTrace(originalEvents, expandedEvents));
            }

            newMatrix.put(entry.getKey(), newTraces);
        }
        return newMatrix;
    }

    /**
     * Reduces a trace by removing redundant detour based on FSM transitions.
     *
     * @param traceWithLocation the list of events in the trace (with location)
     * @param trace the list of events in the trace (without location)
     * @return the reduced trace
     */
    private String reduceTrace(List<String> traceWithLocation, List<String> trace) {
        FSM.state = 0;
        FSM.violation = false;

        Set<Integer> S_v = new HashSet<>();
        S_v.add(FSM.state);

        Set<String> e_v = new HashSet<>();
        int S_curr = FSM.state;
        Map<Integer, int[]> detours = new HashMap<>();
        Set<int[]> candidates = new HashSet<>();
        Set<Integer> removed = new HashSet<>();

        List<String> tau = new ArrayList<>();


        for (int i = 0; i < trace.size(); i++) {
            int S_new = FSM.transition(trace.get(i));
            String e = S_curr + "-" + S_new + "-" + trace.get(i);

            if (!S_v.contains(S_new) || !e_v.contains(e)) {
                detours = new HashMap<>();
                S_v.add(S_new);
                e_v.add(e);
            } else {
                Set<Integer> allS = new HashSet<>(detours.keySet());
                for (int S : allS) {
                    detours.put(S, new int[]{detours.get(S)[0], i, S_new});
                    if (S == S_new) {
                        candidates.add(new int[]{detours.get(S)[0], i});
                        detours.remove(S);
                    }
                }

                if (S_curr == S_new) { // Deals w/ self loop
                    candidates.add(new int[]{i, i});
                } else {
                    detours.put(S_curr, new int[]{i, i, S_new});
                }

                S_curr = S_new;
            }
        }

        List<int[]> sortedCandidates = new ArrayList<>(candidates);
        sortedCandidates.sort(Comparator.comparingInt(arr -> arr[0]));
        for (int[] begin_end : sortedCandidates) {
            int begin = begin_end[0];
            int end = begin_end[1];

            boolean isTrue = true;
            for (int i = begin; i <= end; i++) {
                if (removed.contains(i)) {
                    isTrue = false;
                    break;
                }
            }

            if (isTrue) {
                for (int i = begin; i <= end; i++) {
                    removed.add(i);
                }
            }
        }

        for (int i = 0; i < trace.size(); i++) {
            if (!removed.contains(i)) {
                tau.add(traceWithLocation.get(i));
            }
        }

        return String.join(" ", tau);
    }
}
