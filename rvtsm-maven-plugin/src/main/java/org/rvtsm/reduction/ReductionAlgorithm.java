package org.rvtsm.reduction;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public abstract class ReductionAlgorithm {
    protected static void removeEntities(Map<String, Set<String>> testToTestRequirements,
                                                             Set<String> removeableRequirements) {
        testToTestRequirements.forEach((test, requirements) -> requirements.removeAll(removeableRequirements));
    }

    /**
     * Helper function for resolving ties between tests during selection.
     * @param arbitrarilyChosen the value that would have been chosen if tiebreaking did not occur
     * @param tests set of tests that are tied
     * @param tieBreaker a mapping of tests to numerical values. The test with the *smallest* value will break the tie
     * @return
     */
    protected static String breakTies(String arbitrarilyChosen, List<String> tests, Map<String, Double> tieBreaker) {
        if (tieBreaker.isEmpty()) {
            return arbitrarilyChosen;
        }
        double min = Double.MAX_VALUE;
        String chosenTest = "";
        for (String test : tests) {
            if (tieBreaker.containsKey(test) && tieBreaker.get(test) < min) {
                min = tieBreaker.get(test);
                chosenTest = test;
            }
        }
        return chosenTest;
    }

    /**
     * Helper function for finding test that covers the most entities,
     * and in case of ties chooses the last one.
     * @param testToTestRequirements mapping from test method to the set of test requirements that this method satisfies
     * @param tieBreaker mapping from test method to the value that should be used to break ties when choosing the best test method
     * @return the test method that covers the most entities, and in case of ties chooses the last one
     */
    protected static String getBestTest(Map<String, Set<String>> testToTestRequirements,
                                        Map<String, Double> tieBreaker) {
        int maxCoverage = 1;
        String selected = null;
        Map<Integer, List<String>> coverageMapping = new HashMap<>();
        for (Map.Entry<String, Set<String>> entry : testToTestRequirements.entrySet()) {
            int numCovered = entry.getValue().size();
            if (!coverageMapping.containsKey(numCovered)) {
                coverageMapping.put(numCovered, new ArrayList<>());
            }
            coverageMapping.get(numCovered).add(entry.getKey());
            if (numCovered >= maxCoverage) {
                selected = entry.getKey();
                maxCoverage = entry.getValue().size();
            }
        }
        if (coverageMapping.get(maxCoverage).size() > 1) {
            selected = breakTies(selected, coverageMapping.get(maxCoverage), tieBreaker);
        }
        return selected;
    }

    /**
     * Helper function for finding tests that cover a unique test requirement.
     * @param testRequirementToTests a map from a test requirement to a set of tests
     * @param testToTestRequirements a map from a test to a set of test requirements
     * @param reducedTestSuite a set that keeps track of the selected tests
     * @param coveredEntities a set that keeps track of covered test requirements
     */
    public static void findEssential(Map<String, Set<String>> testRequirementToTests,
                                      Map<String, Set<String>> testToTestRequirements, Set<String> reducedTestSuite,
                                      Set<String> coveredEntities) {
        for (Map.Entry<String, Set<String>> entry : testRequirementToTests.entrySet()) {
            if (entry.getValue().size() == 1) { // Means that only one test can satisfy this particular test requirement
                String test = entry.getValue().iterator().next();
                reducedTestSuite.add(test);
                coveredEntities.addAll(testToTestRequirements.get(test));
            }
        }
    }

    public abstract Set<String> reduce(Map<String, Set<String>> testToTestRequirements, Map<String, Double> tieBreaker,
                       double percentage);
}
