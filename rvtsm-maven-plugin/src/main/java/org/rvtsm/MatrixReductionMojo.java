package org.rvtsm;

import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;
import org.apache.maven.plugins.annotations.ResolutionScope;
import org.rvtsm.coverage.CoverageMapGenerator;
import org.rvtsm.reduction.Greedy;
import org.rvtsm.reduction.GreedyEssential;
import org.rvtsm.reduction.GreedyRedundantEssential;
import org.rvtsm.reduction.HarroldGuptaSoffa;
import org.rvtsm.reduction.ReductionAlgorithm;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Given a matrix file, reduce the matrix into two sets:
 * 1. Reduced set
 * 2. Redundant and no trace set
 */
@Mojo(name = "reduce", requiresDependencyResolution = ResolutionScope.TEST)
public class MatrixReductionMojo extends GenerateMatrixMojo {
    /**
     * Specifies which reduction algorithm to use, currently supports the following 4:
     * 1. greedy: The most basic form of greedy algorithm.
     * 2. ge: Greedy Essential, an extension to the greedy algorithm.
     * 3. gre: Greedy Redundant Essential, an extension to the greedy essential algorithm.
     * 4. hgs: Harrold-Gupta-Soffa, a heuristic for test-suite minimization.
     */
    @Parameter(property = "algorithm", defaultValue = "greedy")
    protected String algorithm;

    /**
     * Specifies which kind of tiebreaker to use when reducing tests. Currently supports:
     * 1. none: The default option that doesn't use any tiebreakers.
     * 2. order: Assign weights to tests by their order of appearance, where the earlier tests are more
     *    likely to be chosen. This option is beneficial for stable reproduction of reduction results.
     * 3. time: Use test time recorded in surefire reports for each test method as the tiebreaker.
     */
    @Parameter(property = "tiebreaker", defaultValue = "none")
    protected String tiebreaker;

    /**
     * Specifies where to find the surefire reports. Used to get tiebreaker.
     * Uses this.getReportsDirectory().toPath() if not specified.
     */
    @Parameter(property = "surefireReportsForTiebreak")
    protected String surefireReportsForTiebreak;

    /** Decides which reduction algorithm implementation to use. */
    @Parameter(property = "implementation", defaultValue = "java")
    protected String implementation;

    @Parameter(property = "disablePUT", defaultValue = "false")
    protected boolean disablePUT;

    private void pythonImpl() throws MojoExecutionException {
        // Get the resource as a stream
        InputStream scriptStream = getClass().getClassLoader().getResourceAsStream("reduce.py");
        if (scriptStream == null) {
            throw new MojoExecutionException("Reduction script not found, exiting.");
        }

        // Create a temporary file
        File tempScript;
        try {
            tempScript = File.createTempFile("reduce", ".py");
        } catch (IOException ex) {
            throw new RuntimeException(ex);
        }
        tempScript.deleteOnExit();

        // Copy the script to the temp file
        try (FileOutputStream out = new FileOutputStream(tempScript)) {
            byte[] buffer = new byte[1024];
            int bytesRead;
            while ((bytesRead = scriptStream.read(buffer)) != -1) {
                out.write(buffer, 0, bytesRead);
            }
        } catch (IOException ex) {
            ex.printStackTrace();
        }

        getTiebreakerMap(Utils.getTestSetFromFile(testMethodList));
        String tiebreakerArg = "NONE";
        switch (tiebreaker) {
            case "order":
                tiebreakerArg = artifactDir + File.separator + "order-tiebreaker.csv";
                break;
            case "time":
                tiebreakerArg = artifactDir + File.separator + "time-tiebreaker.csv";
                break;
            case "none":
            default:
                break;
        }
        List<String> command = new ArrayList<>(Arrays.asList("python3", tempScript.getAbsolutePath(), matrix,
                testMethodList, algorithm, reducedSet, tiebreakerArg));
        int exitCode = Utils.runSubprocess(command, basedir, null, 0, false, null);
        if (exitCode != 0) {
            throw new MojoExecutionException("Python implementation of reduction algorithms failed, exiting.");
        }
    }

    /**
     * Reads the test method list file and returns a set of test methods.
     * @return a set of test methods
     */
    public static Set<String> processTestMethodListFile(String testMethodList) {
        Set<String> testMethods = new HashSet<>();
        try {
            List<String> allLines = Files.readAllLines(Paths.get(testMethodList));
            testMethods = allLines.stream().map(String::trim).collect(java.util.stream.Collectors.toSet());
        } catch (IOException ex) {
            ex.printStackTrace();
        }
        return testMethods;
    }

    /**
     * Reads a matrix file into a map where the key is the test method name and the value is the set of test
     * requirements that this method satisfies. We only care about test methods that are present in the test method list
     * file.
     * @param matrixPath path to the matrix file
     * @param testMethods a set of test methods
     * @return a map of test method names to the set of test requirements that this method satisfies
     */
    public static Map<String, Set<String>> readMatrix(String matrixPath, Set<String> testMethods) {
        Map<String, Set<String>> testToTestRequirements = new HashMap<>();
        try {
            List<String> allLines = Files.readAllLines(Paths.get(matrixPath));
            for (String line : allLines) {
                String[] parts = line.trim().split(",");
                if (parts.length == 0) {
                    return testToTestRequirements;
                }
                String testMethod = parts[0];
                if (!testMethods.contains(testMethod)) {
                    continue;
                }
                if (!testToTestRequirements.containsKey(testMethod)) {
                    testToTestRequirements.put(testMethod, new HashSet<>());
                }
                for (int i = 1; i < parts.length; i++) {
                    testToTestRequirements.get(testMethod).add(parts[i]);
                }
            }
        } catch (IOException ex) {
            ex.printStackTrace();
        }
        return testToTestRequirements;
    }

    private void buildTiebreakerFromReport(Map<String, Double> tiebreakerMap, Path testReportXML) {
        try {
            DocumentBuilder builder = DocumentBuilderFactory.newInstance().newDocumentBuilder();
            File xmlFile = new File(testReportXML.toUri());
            Document document = builder.parse(xmlFile);
            document.getDocumentElement().normalize();

            NodeList testCases = document.getElementsByTagName("testcase");
            for (int i = 0; i < testCases.getLength(); i++) {
                Node node = testCases.item(i);
                if (node.getNodeType() == Node.ELEMENT_NODE) {
                    Element element = (Element) node;
                    String name = disablePUT ? element.getAttribute("name").split("\\[")[0] : element
                            .getAttribute("name");
                    String classname = element.getAttribute("classname");
                    Double time = Double.parseDouble(element.getAttribute("time"));
                    if (!tiebreakerMap.containsKey(classname + "#" + name)) {
                        tiebreakerMap.put(classname + "#" + name, time);
                    }
                }
            }
        } catch (ParserConfigurationException | IOException | SAXException ex) {
            ex.printStackTrace();
        }
    }

    private HashMap<String, Double> getTiebreakerMap(Set<String> testMethods) throws MojoExecutionException {
        switch (tiebreaker) {
            case "order":
                HashMap<String, Double> orderTiebreaker = new HashMap<>();
                double i = 1.0;
                for (String testMethod : testMethods) {
                    orderTiebreaker.put(testMethod, i);
                    i += 1.0;
                }
                try {
                    PrintWriter orderWriter = new PrintWriter(
                            new FileOutputStream(artifactDir + File.separator + "order-tiebreaker.csv", true));
                    for (Map.Entry<String, Double> entry : orderTiebreaker.entrySet()) {
                        orderWriter.println(entry.getKey() + "," + entry.getValue());
                    }
                    orderWriter.flush();
                    orderWriter.close();
                } catch (FileNotFoundException ex) {
                    ex.printStackTrace();
                    throw new MojoExecutionException(
                            "Failed to write order tiebreaker, exiting.");
                }
                return orderTiebreaker;
            case "time":
                HashMap<String, Double> testTiebreaker = new HashMap<>();
                if (surefireReportsForTiebreak == null || surefireReportsForTiebreak.isEmpty()
                        || !new File(surefireReportsForTiebreak).exists()) {
                    surefireReportsForTiebreak = surefireReportsDirForTestCollection;
                    if (!new File(surefireReportsDirForTestCollection).exists()) {
                        runAllTests();
                        surefireReportsDirForTestCollection =
                                artifactDir + File.separator + "surefire-reports-collect-tests";
                        try {
                            Utils.copyRecursively(this.getReportsDirectory().toPath(),
                                    Paths.get(surefireReportsDirForTestCollection));
                        } catch (IOException ex) {
                            throw new RuntimeException(ex);
                        }
                    }
                }
                try {
                    List<Path> reports = Files.walk(Paths.get(surefireReportsForTiebreak))
                            .filter(Files::isRegularFile)
                            .filter(path -> path.toString().endsWith(".xml"))
                            .collect(Collectors.toList());
                    for (Path report : reports) {
                        buildTiebreakerFromReport(testTiebreaker, report);
                    }
                    PrintWriter timeWriter = new PrintWriter(
                            new FileOutputStream(artifactDir + File.separator + "time-tiebreaker.csv", true));
                    for (Map.Entry<String, Double> entry : testTiebreaker.entrySet()) {
                        timeWriter.println(entry.getKey() + "," + entry.getValue());
                    }
                    timeWriter.flush();
                    timeWriter.close();
                } catch (IOException ex) {
                    ex.printStackTrace();
                    throw new MojoExecutionException(
                            "Failed to read surefire reports when building tiebreaker, exiting.");
                }
                return testTiebreaker;
            case "none":
            default:
                return new HashMap<>();
        }
    }

    private void javaImpl() throws MojoExecutionException {
        Set<String> testMethods = processTestMethodListFile(testMethodList);
        Map<String, Set<String>> testToTestRequirements = readMatrix(matrix, testMethods);
        ReductionAlgorithm reductionAlgorithm;
        Map<String, Double> tiebreakerMap = getTiebreakerMap(testMethods);
        double percentage = 1.0;
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
                throw new MojoExecutionException("Invalid algorithm: " + algorithm);
        }
        Set<String> selectedTests = reductionAlgorithm.reduce(testToTestRequirements, tiebreakerMap, percentage);
        getLog().info(String.format("[reduce_suite] Number of selected tests: %s", selectedTests.size()));
        getLog().info(String.format("[reduce_suite] Selected tests: %s", selectedTests));
        try (PrintWriter writer = new PrintWriter(reducedSet)) {
            for (String test : selectedTests) {
                writer.println(test);
            }
            writer.flush();
        } catch (IOException ex) {
            ex.printStackTrace();
        }
    }

    private void noneImpl() throws MojoExecutionException {
        Set<String> testMethods = processTestMethodListFile(testMethodList);
        getTiebreakerMap(testMethods);
    }

    private void writeToRedundantAndNoTrace() {
        Set<String> allTests = Utils.getTestSetFromFile(testMethodList);
        Set<String> reducedTests = Utils.getTestSetFromFile(reducedSet);
        Set<String> redundantAndNoTraceTests = new HashSet<>(allTests);
        redundantAndNoTraceTests.removeAll(reducedTests);
        try (PrintWriter writer = new PrintWriter(redundantAndNoTraceSet)) {
            for (String test : redundantAndNoTraceTests) {
                writer.println(test);
            }
            writer.flush();
        } catch (FileNotFoundException ex) {
            ex.printStackTrace();
        }
    }

    @Override
    public void execute() throws MojoExecutionException {
        if (!skipAllPreviousSteps) {
            super.execute();
        } else {
            initialize();
        }

        if (implementation.equals("python")) {
            pythonImpl();
            writeToRedundantAndNoTrace();
        } else if (implementation.equals("java")) {
            javaImpl();
            writeToRedundantAndNoTrace();
        } else if (implementation.equals("none")) {
            noneImpl();
        } else {
            throw new MojoExecutionException("Invalid implementation: " + implementation);
        }
    }
}
