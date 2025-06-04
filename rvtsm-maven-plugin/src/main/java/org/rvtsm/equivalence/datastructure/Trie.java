package org.rvtsm.equivalence.datastructure;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Trie {
    private static class TrieNode {
        Map<String, TrieNode> children = new HashMap<>();
        boolean isEndOfTrace = false;
    }

    private final TrieNode root;

    public Trie() {
        root = new TrieNode();
    }
    /**
     * Adds a trace to the Trie. If the trace is already present (e.g., a prefix of another), it does not add it again.
     *
     * @param trace the traces to add, represented as a list of events
     * @return the list of prefixes that are already in the Trie if the trace is new, null if the trace is a prefix
     */
    public List<String> addTraceIfRequired(List<String> trace) {
        List<String> prefixes = new ArrayList<>();
        StringBuilder currentPrefix = new StringBuilder();
        TrieNode current = root;
        for (int i = 0; i < trace.size(); i++) {
            String event = trace.get(i);

            if (i > 0) {
                currentPrefix.append(" ");
            }
            currentPrefix.append(event);

            current = current.children.computeIfAbsent(event, k -> new TrieNode());
            if (current.isEndOfTrace) {
                // This current node is the end of another trace
                if (i + 1 < trace.size()) {
                    // Not the end of this trace, so we have more events to process
                    // We will remove this prefix, because we will remove the trace from test requirement
                    prefixes.add(currentPrefix.toString());
                    current.isEndOfTrace = false;
                }
            }
        }

        if (current.children.isEmpty()) {
            current.isEndOfTrace = true;
            return prefixes;
        } else {
            return null;
        }
    }

    /**
     * Checks if a trace is present in the Trie.
     *
     * @param trace the sentence to check, represented as a list of events
     * @return true if the trace is a prefix, false otherwise
     */
    public boolean isPrefix(List<String> trace) {
        TrieNode current = root;
        for (String event : trace) {
            current = current.children.get(event);
            if (current == null) {
                return false;
            }
        }
        return true;
    }
}
