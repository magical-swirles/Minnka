package org.rvtsm.reduction;

import org.rvtsm.Utils;

import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class GreedyEssential extends Greedy {
    @Override
    public Set<String> reduce(Map<String, Set<String>> testToTestRequirements, Map<String, Double> tieBreaker,
                              double percentage) {
        Map<String, Set<String>> testRequirementToTests = Utils.inverseMap(testToTestRequirements);
        Set<String> reducedTestSuite = new HashSet<>();
        Set<String> coveredEntities = new HashSet<>();
        findEssential(testRequirementToTests, testToTestRequirements, reducedTestSuite, coveredEntities);
        for (String testRequirement : coveredEntities) {
            testRequirementToTests.remove(testRequirement);
        }
        testToTestRequirements = Utils.inverseMap(testRequirementToTests);
        Set<String> reducedTestSuiteFromGreedy = super.reduce(testToTestRequirements, tieBreaker, percentage);
        reducedTestSuite.addAll(reducedTestSuiteFromGreedy);
        return reducedTestSuite;
    }
}
