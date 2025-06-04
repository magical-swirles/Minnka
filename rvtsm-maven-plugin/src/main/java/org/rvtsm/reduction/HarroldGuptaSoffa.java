package org.rvtsm.reduction;

import org.rvtsm.Utils;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

public class HarroldGuptaSoffa extends ReductionAlgorithm {
    private static Map<String, Set<String>> removeKeys(Map<String, Set<String>> testRequirementToTests, String test) {
        Map<String, Set<String>> modifiedMap = new HashMap<>();
        for (Map.Entry<String, Set<String>> entry : testRequirementToTests.entrySet()) {
            if (!entry.getValue().contains(test)) {
                modifiedMap.put(entry.getKey(), new HashSet<>(entry.getValue()));
            }
        }
        return modifiedMap;
    }

    /**
     * Returns a new map with all empty sets removed.
     * @param map the original map to remove empty sets from
     * @return the modified map
     */
    private static Map<Integer, List<Set<String>>> removeEmpty(Map<Integer, List<Set<String>>> map) {
        Map<Integer, List<Set<String>>> modifiedMap = new HashMap<>();
        for (Map.Entry<Integer, List<Set<String>>> entry : map.entrySet()) {
            if (!entry.getValue().isEmpty()) {
                modifiedMap.put(entry.getKey(), new ArrayList<>(entry.getValue()));
            }
        }
        return modifiedMap;
    }

    private static String selectTest(int currCardinality, Map<Integer, List<Set<String>>> cardinality,
                                     int maxCardinality, Map<String, Double> tieBreaker) {
        List<String> tests = new ArrayList<>();
        for (Set<String> testSet : cardinality.get(currCardinality)) {
            tests.addAll(testSet);
        }

        while (currCardinality <= maxCardinality) {
            // Frequency of test to the requirements in this cardinality that it covers.
            Map<String, Integer> count = new HashMap<>();
            int maxCount = 0; // Used to determine which test gets selected.
            for (String test : tests) {
                count.putIfAbsent(test, 0);
                for (Set<String> testRequirements : cardinality.get(currCardinality)) {
                    if (testRequirements.contains(test)) {
                        count.put(test, count.get(test) + 1);
                    }
                }
                maxCount = Math.max(maxCount, count.get(test));
            }
            List<String> mList = new ArrayList<>();
            for (Map.Entry<String, Integer> entry : count.entrySet()) {
                if (entry.getValue() == maxCount) {
                    mList.add(entry.getKey());
                }
            }
            if (mList.size() == 1) {
                return mList.get(0);
            }
            tests = mList;
            currCardinality += 1;
            while (currCardinality <= maxCardinality && !cardinality.containsKey(currCardinality)) {
                currCardinality += 1;
            }

        }
        if (tests.size() > 1) {
            return breakTies(tests.get(0), tests, tieBreaker);
        }
        return tests.get(0);
    }

    @Override
    public Set<String> reduce(Map<String, Set<String>> testToTestRequirements, Map<String, Double> tieBreaker,
                              double percentage) {
        Set<String> reducedTestSuite = new HashSet<>();
        Set<String> coveredEntities = new HashSet<>();
        Map<String, Set<String>> testRequirementToTests = Utils.inverseMap(testToTestRequirements);
        Set<String> totalEntities = testToTestRequirements.values().stream()
                .flatMap(Set::stream)
                .collect(Collectors.toSet());
        if (totalEntities.isEmpty()) {
            return reducedTestSuite;
        }

        // This is essentially doing cardinality=1's job.
        for (Map.Entry<String, Set<String>> entry : testRequirementToTests.entrySet()) {
            if (entry.getValue().size() == 1) {
                reducedTestSuite.add(entry.getValue().iterator().next());
                coveredEntities.add(entry.getKey());
                if (coveredEntities.size() >= percentage * totalEntities.size()) {
                    return reducedTestSuite;
                }
            }
        }

        for (String test : reducedTestSuite) {
            testRequirementToTests = removeKeys(testRequirementToTests, test);
        }

        Map<Integer, List<Set<String>>> cardinality = new HashMap<>();
        int maxCardinality = 0;
        for (Map.Entry<String, Set<String>> entry : testRequirementToTests.entrySet()) {
            cardinality.putIfAbsent(entry.getValue().size(), new ArrayList<>());
            cardinality.get(entry.getValue().size()).add(entry.getValue());
            maxCardinality = Math.max(maxCardinality, entry.getValue().size());
        }
        cardinality = removeEmpty(cardinality);

        int currCardinality = 2;
        while (currCardinality <= maxCardinality) {
            while (currCardinality <= maxCardinality && !cardinality.containsKey(currCardinality)) {
                currCardinality++;
            }
            if (currCardinality > maxCardinality) {
                return reducedTestSuite;
            }
            String selected = selectTest(currCardinality, cardinality, maxCardinality, tieBreaker);

            reducedTestSuite.add(selected);
            coveredEntities.addAll(testToTestRequirements.get(selected));
            if (coveredEntities.size() >= percentage * totalEntities.size()) {
                return reducedTestSuite;
            }
            Set<Integer> toRemove = new HashSet<>();
            for (Integer size : cardinality.keySet()) {
                List<Set<String>> keep = new ArrayList<>();
                for (Set<String> tests : cardinality.get(size)) {
                    if (!tests.contains(selected)) {
                        keep.add(tests);
                    }
                }
                if (!keep.isEmpty()) {
                    cardinality.putIfAbsent(size, new ArrayList<>());
                    cardinality.put(size, keep);
                } else {
                    toRemove.add(size);
                }
            }
            for (Integer size : toRemove) {
                cardinality.remove(size);
            }
        }
        return reducedTestSuite;
    }
}
