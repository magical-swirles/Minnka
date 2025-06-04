package org.rvtsm;

import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;
import org.rvtsm.reduction.Greedy;
import org.rvtsm.reduction.GreedyEssential;
import org.rvtsm.reduction.GreedyRedundantEssential;
import org.rvtsm.reduction.HarroldGuptaSoffa;
import org.rvtsm.reduction.ReductionAlgorithm;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.rvtsm.MatrixReductionMojo.processTestMethodListFile;
import static org.rvtsm.MatrixReductionMojo.readMatrix;

public class MatrixReductionMojoTest {
    private File script;
    private List<File> matrices;
    private List<File> testMethodLists;
    private List<File> tieBreakers;

    private Map<String, Double> loadTieBreaker(File file) {
        Map<String, Double> tieBreaker = new HashMap<>();
        try {
            Files.readAllLines(file.toPath())
                    .forEach(line -> tieBreaker.put(line.split(",")[0], new Double(line.split(",")[1])));
        } catch(IOException ex) {
            ex.printStackTrace();
        }
        return tieBreaker;
    }

    /** Run the Python implementation of the reduction algorithm. */
    private Set<String> getPythonResult(String algorithm, int i) {
        String reducedOutput = "reduced-out.txt";
        List<String> command = new ArrayList<>(Arrays.asList("python3", script.getAbsolutePath(),
                matrices.get(i).getAbsolutePath(), testMethodLists.get(i).getAbsolutePath(), algorithm, reducedOutput,
                tieBreakers.get(i) == null ? "NONE" : tieBreakers.get(i).getAbsolutePath()));
        Utils.runSubprocess(command, new File(System.getProperty("user.dir")), new File("/dev/null"), 0, false, null);
        Set<String> pythonImplResult = new HashSet<>();
        try {
            List<String> allLines = Files.readAllLines(Paths.get(reducedOutput));
            pythonImplResult = allLines.stream().map(String::trim).collect(java.util.stream.Collectors.toSet());
            Files.deleteIfExists(Paths.get(reducedOutput));
        } catch (IOException ex) {
            ex.printStackTrace();
        }
        return pythonImplResult;
    }

    private Set<String> getJavaResult(String algorithm, int i) {
        Set<String> testMethods = processTestMethodListFile(testMethodLists.get(i).getAbsolutePath());
        Map<String, Set<String>> testToTestRequirements = readMatrix(matrices.get(i).getAbsolutePath(), testMethods);
        ReductionAlgorithm reductionAlgorithm;
        switch (algorithm) {
            case "greedy":
                reductionAlgorithm = new Greedy();
                break;
            case "ge":
                reductionAlgorithm = new GreedyEssential();
                break;
            case "gre":
                reductionAlgorithm = new GreedyRedundantEssential();
                break;
            case "hgs":
                reductionAlgorithm = new HarroldGuptaSoffa();
                break;
            default:
                throw new RuntimeException("Invalid algorithm: " + algorithm);
        }
        Map<String, Double> tieBreaker = tieBreakers.get(i) == null
                ? new HashMap<>()
                : loadTieBreaker(tieBreakers.get(i));
        double percentage = 1.0;
        return reductionAlgorithm.reduce(testToTestRequirements, tieBreaker, percentage);
    }

    @Before
    public void setup() {
        TestUtils tu = new TestUtils();
        // Load files from resources
        script = tu.loadFileFromResources("reduce", ".py");
        matrices = new ArrayList<>(Arrays.asList(
                tu.loadFileFromResources("sample-matrix", ".csv"),
                tu.loadFileFromResources("sample-matrix-2", ".csv")
        ));
        testMethodLists = new ArrayList<>(Arrays.asList(
                tu.loadFileFromResources("sample-tests", ".txt"),
                tu.loadFileFromResources("sample-tests-2", ".txt")
        ));
        tieBreakers = new ArrayList<>(Arrays.asList(
                null,
                tu.loadFileFromResources("sample-tie-breaker-2", ".csv")
        ));
    }

    @Test
    public void greedyImplTest() {
        for (int i = 0; i < matrices.size(); i++) {
            Assert.assertEquals(getPythonResult("greedy", i), getJavaResult("greedy", i));
        }
    }

    @Test
    public void greedyEssentialImplTest() {
        for (int i = 0; i < matrices.size(); i++) {
            Assert.assertEquals(getPythonResult("ge", i), getJavaResult("ge", i));
        }
    }

    @Test
    public void greedyRedundantEssentialImplTest() {
        for (int i = 0; i < matrices.size(); i++) {
            Assert.assertEquals(getPythonResult("gre", i), getJavaResult("gre", i));
        }
    }

    @Test
    public void HarroldGuptaSoffaImplTest() {
        for (int i = 0; i < matrices.size(); i++) {
            Assert.assertEquals(getPythonResult("hgs", i), getJavaResult("hgs", i));
        }
    }
}
