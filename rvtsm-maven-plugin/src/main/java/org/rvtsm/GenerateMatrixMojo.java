package org.rvtsm;

import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;
import org.apache.maven.plugins.annotations.ResolutionScope;
import org.rvtsm.coverage.CoverageMapGenerator;
import org.rvtsm.equivalence.Equivalence;
import org.rvtsm.equivalence.OnlineDetourEquivalence;
import org.rvtsm.equivalence.PerfectEquivalence;
import org.rvtsm.equivalence.PrefixEquivalence;
import org.rvtsm.equivalence.StateTransitionEquivalence;
import org.rvtsm.equivalence.ViolationEquivalence;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Mojo(name = "generate-matrix", requiresDependencyResolution = ResolutionScope.TEST)
public class GenerateMatrixMojo extends CollectTracesMojo {
    /**
     * Decides which format of matrix to generate. Currently, supports two values:
     * 1. complete: test requirements are shown as complete traces
     * 2. compact: test requirements are shown as trace ids,
     *      you may want to choose this for easier inspection or storage reasons
     * TODO: Currently does not support compact
     */
    @Parameter(property = "matrixFormat", defaultValue = "complete")
    protected String matrixFormat;

    @Parameter(property = "matrixReductionScheme", defaultValue = "perfect")
    protected String matrixReductionScheme;

    private Map<String, Set<String>> traceIdToTestMethods = new HashMap<>();
    private Map<String, Set<String>> testMethodToTraceIds = new HashMap<>();
    private Map<String, Set<String>> testMethodToTraces = new HashMap<>();
    private String traceIdToTestMethodsFile;

    private void loadTraceIdToTestMethods() {
        if (!Files.exists(Paths.get(traceIdToTestMethodsFile))) {
            getLog().error("Trace ID to test methods file does not exist: " + traceIdToTestMethodsFile);
            return;
        }
        traceIdToTestMethods = Utils.loadTraceIdToTestMethods(traceIdToTestMethodsFile);
    }

    // TODO: Currently does not support compact.
    private void printToMatrix() {
        try (PrintWriter writer = new PrintWriter(matrix)) {
            for (Map.Entry<String, Set<String>> entry
                    : (matrixFormat.equals("complete") ? testMethodToTraces : testMethodToTraceIds).entrySet()) {
                if (!entry.getKey().equals("NoTest")) {
                    writer.print(entry.getKey());
                    for (String traceOrId : entry.getValue()) {
                        writer.print("," + traceOrId);
                    }
                    writer.println();
                }
            }
            writer.flush();
        } catch (FileNotFoundException ex) {
            ex.printStackTrace();
        }
    }

    private void writeGlobalLocationMap(Map<String, Integer> globalLocationToId) {
        Map<Integer, String> locationIdToLocation = globalLocationToId.entrySet().stream()
                .collect(Collectors.toMap(Map.Entry::getValue, Map.Entry::getKey));
        try (PrintWriter writer =
                     new PrintWriter(artifactDir + File.separator + "all-traces" + File.separator + "locations.txt")) {
            writer.println("=== LOCATION MAP ===");
            for (Map.Entry<Integer, String> entry : locationIdToLocation.entrySet()) {
                writer.println(entry.getKey() + " " + entry.getValue());
            }
            writer.flush();
        } catch (FileNotFoundException ex) {
            ex.printStackTrace();
        }
    }

    private void writeGlobalTraceMap(Map<String, Integer> globalTraceToId) {
        Map<Integer, String> idToTrace = globalTraceToId.entrySet().stream()
                .collect(Collectors.toMap(Map.Entry::getValue, Map.Entry::getKey));
        try (PrintWriter writer =
                     new PrintWriter(artifactDir + File.separator + "all-traces"
                             + File.separator + "unique-traces.txt")) {
            writer.println("=== UNIQUE TRACES ===");
            for (Map.Entry<Integer, String> entry : idToTrace.entrySet()) {
                writer.println(entry.getKey() + " [" + entry.getValue() + "]");
            }
            writer.flush();
        } catch (FileNotFoundException ex) {
            ex.printStackTrace();
        }
    }

    private void populateTestMethodToTraces() {
        Map<Integer, String> idToTrace;
        if (parallelCollection) {
            idToTrace = Utils.loadTraceIdToTrace(artifactDir + File.separator + "all-traces"
                    + File.separator + "unique-traces.txt");
        } else {
            idToTrace = Utils.loadTraceIdToTrace(allTracesDir + File.separator + "unique-traces.txt");
        }
        for (Map.Entry<String, Set<String>> entry : testMethodToTraceIds.entrySet()) {
            if (!entry.getKey().equals("NoTest")) {
                testMethodToTraces.put(entry.getKey(), entry.getValue().stream()
                        .map(traceId -> idToTrace.get(Integer.valueOf(traceId)).replace(", ", " "))
                        .collect(Collectors.toSet()));
            }
        }
    }

    private void generateMatrixParallel() {
        Map<String, Integer> globalLocationToId = new HashMap<>(); // Location is 1-indexed
        Map<String, Integer> globalTraceToId = new HashMap<>(); // Trace is 0-indexed
        Set<String> allTestMethods = Utils.getTestSetFromFile(testMethodList);
        for (String testMethod : allTestMethods) {
            testMethodToTraceIds.putIfAbsent(testMethod, new HashSet<>());
            Path parent = Paths.get(allTracesDir + File.separator + testMethod);
            if (!parent.toFile().exists()) {
                continue;
            }
            try {
                if (Files.walk(parent)
                        .filter(path -> !path.equals(parent))
                        .collect(Collectors.toList()).isEmpty()) {
                    continue;
                }
            } catch (IOException ex) {
                ex.printStackTrace();
            }
            Map<Integer, String> localIdToLocation = Utils.loadLocationMap(parent + File.separator + "locations.txt");
            Map<Integer, Integer> localLocationIdToGlobalLocationId = new HashMap<>();
            for (Map.Entry<Integer, String> entry : localIdToLocation.entrySet()) {
                String location = entry.getValue();
                if (!globalLocationToId.containsKey(location)) {
                    globalLocationToId.put(location, globalLocationToId.size() + 1);
                }
                localLocationIdToGlobalLocationId.put(entry.getKey(), globalLocationToId.get(location));
            }
            Map<Integer, String> localIdToTrace = Utils.loadTraceIdToTrace(parent + File.separator + "unique-traces.txt");
            for (Map.Entry<Integer, String> entry : localIdToTrace.entrySet()) {
                String localTrace = entry.getValue();
                String trace = Utils.transformToGlobalTrace(localTrace, localLocationIdToGlobalLocationId);
                if (!globalTraceToId.containsKey(trace)) {
                    globalTraceToId.put(trace, globalTraceToId.size());
                }
                testMethodToTraceIds.get(testMethod).add(globalTraceToId.get(trace).toString());
            }
        }
        writeGlobalLocationMap(globalLocationToId);
        writeGlobalTraceMap(globalTraceToId);
    }

    private void generateMatrixSequential() {
        traceIdToTestMethodsFile = allTracesDir + File.separator + "specs-test.csv";
        loadTraceIdToTestMethods();
        testMethodToTraceIds = Utils.inverseMap(traceIdToTestMethods);
    }

    private Equivalence getEquivalence(String scheme) {
        Equivalence eq;
        switch (scheme) {
            case "state":
                eq = new StateTransitionEquivalence();
                break;
            case "prefix":
                eq = new PrefixEquivalence();
                break;
            case "online_detour":
                eq = new OnlineDetourEquivalence();
                break;
            case "violation":
                eq = new ViolationEquivalence();
                break;
            default:
                eq = new PerfectEquivalence();
        }
        return eq;
    }

    private void applyTransformation() {
        for (String reduction : matrixReductionScheme.split("-")) {
            testMethodToTraces = getEquivalence(reduction).process(testMethodToTraces);
        }
    }

    @Override
    public void execute() throws MojoExecutionException {
        if (!skipAllPreviousSteps) {
            super.execute();
        } else {
            initialize();
        }
        if (new File(matrix).exists()) {
            getLog().info("Skipping matrix generation, as matrix file already exists.");
            return;
        }
        getLog().info("Generating matrix to: " + matrix);

        if (testRequirementType.equals("trace")) {
            if (parallelCollection) {
                generateMatrixParallel();
            } else {
                generateMatrixSequential();
            }
            populateTestMethodToTraces();
            applyTransformation();
            printToMatrix();
        } else if (testRequirementType.equals("coverage")) {
            if (!Files.exists(Paths.get(coverageDir))) {
                collectCoverage();
            }
            CoverageMapGenerator generator = new CoverageMapGenerator(new File(coverageDir),
                    new File(getProject().getBuild().getOutputDirectory()));
            File[] execFiles = generator.execFileDir.listFiles((dir, name) -> name.endsWith(".exec"));
            try {
                generator.create(execFiles, matrix);
            } catch (IOException ex) {
                ex.printStackTrace();
                throw new MojoExecutionException("Failed to parse coverage!");
            }
        }
    }
}
