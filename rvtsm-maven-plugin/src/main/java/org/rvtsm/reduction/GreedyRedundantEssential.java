package org.rvtsm.reduction;

import org.rvtsm.Utils;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

public class GreedyRedundantEssential extends ReductionAlgorithm {
    /**
     * Helper function for removing any redundant tests from the mapping from tests to entities they cover.
     * @param testToTestRequirements a map from test to the test requirements that it covers
     * @return the new map after removing redundant tests
     */
    private static Map<String, Set<String>> removeRedundant(Map<String, Set<String>> testToTestRequirements,
                                                            Map <String, Double> tieBreaker) {
        Map<String, Set<String>> modifiedMapping = new HashMap<>();
        for (Map.Entry<String, Set<String>> entry : testToTestRequirements.entrySet()) {
            modifiedMapping.put(entry.getKey(), new HashSet<>(entry.getValue()));
        }

        for (Map.Entry<String, Set<String>> first : testToTestRequirements.entrySet()) {
            for (Map.Entry<String, Set<String>> second : testToTestRequirements.entrySet()) {
                if (!first.getKey().equals(second.getKey())
                        && second.getValue().containsAll(first.getValue())
                        && first.getValue().size() != second.getValue().size()) {
                    modifiedMapping.remove(first.getKey());
                    break;
                }
            }
        }

        Set<String> redundant = new HashSet<>();
        for (String first : new ArrayList<>(modifiedMapping.keySet()).stream().sorted().collect(Collectors.toList())) {
            if (!redundant.contains(first)) {
                for (String second : modifiedMapping.keySet()) {
                    if (!first.equals(second) && modifiedMapping.get(first).equals(modifiedMapping.get(second))) {
                        redundant.add(second);
                        modifiedMapping.remove(second);
                        break;
                    }
                }
            }
        }

        return modifiedMapping;
    }

    @Override
    public Set<String> reduce(Map<String, Set<String>> testToTestRequirements, Map<String, Double> tieBreaker,
                              double percentage) {
        Set<String> totalEntities = testToTestRequirements.values().stream()
                .flatMap(Set::stream)
                .collect(Collectors.toSet());
        Map<String, Set<String>> testRequirementToTests = Utils.inverseMap(testToTestRequirements);
        Set<String> reducedTestSuite = new HashSet<>();
        Set<String> coveredEntities = new HashSet<>();
        findEssential(testRequirementToTests, testToTestRequirements, reducedTestSuite, coveredEntities);
        for (String testRequirement : coveredEntities) {
            testRequirementToTests.remove(testRequirement);
        }
        testToTestRequirements = Utils.inverseMap(testRequirementToTests);
        if (testToTestRequirements.isEmpty()) {
            return reducedTestSuite;
        }

        while (coveredEntities.size() < percentage * totalEntities.size()) {
            testToTestRequirements = removeRedundant(testToTestRequirements, tieBreaker);
            testRequirementToTests = Utils.inverseMap(testToTestRequirements);
            Set<String> newSelected = new HashSet<>();
            Set<String> newCovered = new HashSet<>();
            findEssential(testRequirementToTests, testToTestRequirements, newSelected, newCovered);
            if (newSelected.isEmpty()) {
                String test = getBestTest(testToTestRequirements, tieBreaker);
                newSelected.add(test);
                newCovered = testToTestRequirements.get(test);
            }
            for (String testRequirement : newCovered) {
                testRequirementToTests.remove(testRequirement);
            }
            testToTestRequirements = Utils.inverseMap(testRequirementToTests);
            coveredEntities.addAll(newCovered);
            reducedTestSuite.addAll(newSelected);
        }
        return reducedTestSuite;
    }
}
