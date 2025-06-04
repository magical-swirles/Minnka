package org.rvtsm.coverage;

import java.io.File;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.PrintWriter;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

import org.jacoco.core.analysis.Analyzer;
import org.jacoco.core.analysis.CoverageBuilder;
import org.jacoco.core.analysis.IClassCoverage;
import org.jacoco.core.analysis.ICounter;
import org.jacoco.core.tools.ExecFileLoader;

/**
 * This class takes a set of jacoco.exec files obtained from running
 * some "tests" and produces the map of coverage for each line in all
 * classes that are covered per test. The name of each jacoco.exec is
 * used as the test name. Tests can be at any granularity level.
 */

public class CoverageMapGenerator {

    public final File execFileDir;
    private final File classesDirectory;

    private ExecFileLoader execFileLoader;

    /**
     * Create a new generator based for the given project.
     */
    public CoverageMapGenerator(final File execDir, final File compileDir) {
        this.execFileDir = execDir;
        this.classesDirectory = compileDir;
    }

    /**
     * Create the reports.
     *
     * @throws IOException
     */
    public void create(File[] execFiles, String outputFile) throws IOException {
        Map<String, Map<String, Map<Integer, Integer>>> covMap
                = new HashMap<String, Map<String, Map<Integer, Integer>>>();

        for (File execFile : execFiles) {

            // Read a jacoco.exec file.
            loadExecutionData(execFile);

            // Run the structure analyzer on a single class folder to build up
            // the coverage model. The process would be similar if your classes
            // were in a jar file. Typically you would create a bundle for each
            // class folder and each jar you want in your report. If you have
            // more than one bundle you will need to add a grouping node to your
            // report
            String testName = execFile.getName().substring(0, execFile.getName().lastIndexOf("."));

            covMap.put(testName, new HashMap<String, Map<Integer, Integer>>());

            analyzeStructure(testName, covMap);
        }
        // Need a step here to clean up PUTs
        Map<String, Map<String, Map<Integer, Integer>>> cleanedMap = new HashMap<>();
        for (Map.Entry<String, Map<String, Map<Integer, Integer>>> entry : covMap.entrySet()) {
            String cleanedKey = entry.getKey().split("\\[")[0];
            Map<String, Map<Integer, Integer>> value = entry.getValue();
            value.putAll(covMap.getOrDefault(entry.getKey(), new HashMap<>()));
            cleanedMap.put(cleanedKey, value);
        }

        try (PrintWriter pw = new PrintWriter(outputFile)) {
            // First level: Test to a map from every class to whether its lines are covered or not
            for (Map.Entry<String, Map<String, Map<Integer, Integer>>> entry : covMap.entrySet()) {
                pw.print(entry.getKey());
                // Second level: A class to the lines that it covers
                for (Map.Entry<String, Map<Integer, Integer>> classEntry : entry.getValue().entrySet()) {
                    String className = classEntry.getKey();
                    List<Integer> coveredLines = classEntry.getValue().entrySet().stream()
                            .filter(e -> e.getValue() >= ICounter.FULLY_COVERED)
                            .map(Map.Entry::getKey)
                            .collect(Collectors.toList());
                    for (Integer coveredLine : coveredLines) {
                        pw.print("," + className.hashCode() + ":" + coveredLine);
                    }
                }
                pw.println();
            }
            pw.flush();
        } catch (IOException ex) {
            ex.printStackTrace();
        }
    }

    private void loadExecutionData(File execFile) throws IOException {
        execFileLoader = new ExecFileLoader();
        execFileLoader.load(execFile);
    }

    private void analyzeStructure(String testName, Map<String, Map<String, Map<Integer, Integer>>> covMap) throws IOException {
        final CoverageBuilder coverageBuilder = new CoverageBuilder();
        final Analyzer analyzer
            = new Analyzer(execFileLoader.getExecutionDataStore(), coverageBuilder);

        analyzer.analyzeAll(classesDirectory);

        Map<String, Map<Integer, Integer>> iCovMap = new HashMap<String, Map<Integer, Integer>>();

        for (IClassCoverage icc : coverageBuilder.getClasses()) {
            String name = icc.getName().replace('/', '.');
            Map<Integer, Integer> covLinesMap = new HashMap<Integer, Integer>();

            for (int i = icc.getFirstLine(); i <= icc.getLastLine(); i++) {
                covLinesMap.put(i, icc.getLine(i).getStatus());
            }

            covMap.get(testName).put(name, covLinesMap);
        }
    }

    public static void main(final String[] args) throws IOException {
        // The first argument is the directory with the jacoco.exec
        // files

        // The second argument is the directory with the compiled
        // sources that we care about
        CoverageMapGenerator generator = new CoverageMapGenerator(new File(args[0]), new File(args[1]));
        File [] execFiles = generator.execFileDir.listFiles(new FilenameFilter() {
                @Override
                public boolean accept(File dir, String name) {
                    return name.endsWith(".exec");
                }
            });

        generator.create(execFiles, args[2]);
    }
}
