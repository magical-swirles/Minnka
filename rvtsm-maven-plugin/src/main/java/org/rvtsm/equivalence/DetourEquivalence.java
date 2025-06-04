package org.rvtsm.equivalence;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class DetourEquivalence extends Equivalence {
    private Map<String, String> idToSpec;

    public DetourEquivalence() {
        this.idToSpec = getMapping();
    }

    @Override
    public Map<String, Set<String>> process(Map<String, Set<String>> matrix) {
        Map<String, Set<String>> newMatrix = new HashMap<>();
        for (Map.Entry<String, Set<String>> entry : matrix.entrySet()) {
            Set<String> newTraces = new HashSet<>();
            for (String trace : entry.getValue()) {
                newTraces.add(removeDetour(trace));
            }

            newMatrix.put(entry.getKey(), newTraces);
        }
        return newMatrix;
    }

    private String removeDetour(String trace) {
        int idx = trace.indexOf('~');
        if (trace.isEmpty() || idx <= 1) {
            return trace;
        }

        String spec = idToSpec.get(trace.substring(1, idx)); // find spec based on first event's id
        if (spec == null) {
            // Unable to find spec given this event id
            return trace;
        }

        switch (spec) {
            case "Iterator_HasNext":
                // e115 is hasnexttrue, e116 is next
                // we want to turn "hasnexttrue next hasnexttrue next hasnexttrue next"
                // to just "hasnexttrue next hasnexttrue next"
                return removeRedundantPatterns(trace, "(e115~[^\\s]+ e116~[^\\s]+)");
            case "Iterator_RemoveOnce":
                // e117 is next, e118 is remove
                // we want to turn "next remove next remove next remove"
                // to just "next remove next remove"
                return removeRedundantPatterns(trace, "(e117~[^\\s]+ e118~[^\\s]+)");
            case "ListIterator_RemoveOnce":
                // e119 is next, e121 is remove
                // we want to turn "next remove next remove next remove"
                // to just "next remove next remove"
                return removeRedundantPatterns(trace, "(e119~[^\\s]+ e121~[^\\s]+)");
            case "ListIterator_hasNextPrevious":
                // e129 is hasnexttrue, e132 is next
                // we want to turn "hasnexttrue next hasnexttrue next hasnexttrue next"
                // to just "hasnexttrue next hasnexttrue next"
                trace = removeRedundantPatterns(trace, "(e129~[^\\s]+ e132~[^\\s]+)");
                // e131 is hasprevioustrue, e133 is previous
                // we want to turn "hasprevioustrue previous hasprevioustrue previous hasprevioustrue previous"
                // to just "hasprevioustrue previous hasprevioustrue previous"
                return removeRedundantPatterns(trace, "(e131~[^\\s]+ e133~[^\\s]+)");
            case "StringTokenizer_HasMoreElements":
                // e360 is hasnexttrue, e361 is next
                // we want to turn "hasnexttrue next hasnexttrue next hasnexttrue next"
                // to just "hasnexttrue next hasnexttrue next"
                return removeRedundantPatterns(trace, "(e360~[^\\s]+ e361~[^\\s]+)");
            default:
                return trace;
        }
    }

    public static String removeRedundantPatterns(String trace, String regex) {
        // Extract all hasnext~X, next~Y patterns
        Pattern findPattern = Pattern.compile(regex);
        Matcher matcher = findPattern.matcher(trace);

        // Map to track occurrence count of each pattern
        Map<String, Integer> patternCounts = new HashMap<>();

        // Find all patterns and count them
        while (matcher.find()) {
            String pattern = matcher.group(1);
            patternCounts.put(pattern, patternCounts.getOrDefault(pattern, 0) + 1);
        }

        String result = trace;

        // For each pattern that appears more than twice
        for (Map.Entry<String, Integer> entry : patternCounts.entrySet()) {
            if (entry.getValue() > 2) {
                String patternToRemove = entry.getKey();

                // Create a regex to remove occurrences after the first two
                String replacementRegex = "(?<=" + Pattern.quote(patternToRemove) +
                        " " + Pattern.quote(patternToRemove) +
                        ")( " + Pattern.quote(patternToRemove) + ")";

                // Apply the replacement
                result = result.replaceAll(replacementRegex, "");
            }
        }

        return result;
    }

    public Map<String, String>  getMapping() {
        Map<String, String> idToSpec = new HashMap<>();
        try (InputStream inputStream = getClass().getClassLoader().getResourceAsStream("events_encoding_id.txt")) {
            if (inputStream == null) {
                throw new Exception("Mapping file not found");
            }

            try (BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {
                String line;

                // Process data rows
                while ((line = reader.readLine()) != null) {
                    String[] parts = line.split(",");
                    idToSpec.put(parts[2], parts[0]);
                }
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

        return idToSpec;
    }
}
