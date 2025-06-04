package org.rvtsm.reduction;

import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

public class Greedy extends ReductionAlgorithm {

    @Override
    public Set<String> reduce(Map<String, Set<String>> testToTestRequirements, Map<String, Double> tieBreaker,
                              double percentage) {
        if (testToTestRequirements == null) {
            return new HashSet<>();
        }
        Set<String> reducedTestSuite = new HashSet<>();
        Set<String> coveredEntities = new HashSet<>();
        Set<String> totalEntities = testToTestRequirements.values().stream()
                .flatMap(Set::stream)
                .collect(Collectors.toSet());
        while (coveredEntities.size() < percentage * totalEntities.size()) {
            String testMethod = getBestTest(testToTestRequirements, tieBreaker);
            coveredEntities.addAll(testToTestRequirements.get(testMethod));
            Set<String> removeableRequirements = testToTestRequirements.remove(testMethod);
            removeEntities(testToTestRequirements, removeableRequirements);
            reducedTestSuite.add(testMethod);
        }
        return reducedTestSuite;
    }
}
