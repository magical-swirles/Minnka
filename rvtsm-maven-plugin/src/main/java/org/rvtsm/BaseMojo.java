package org.rvtsm;

import org.apache.maven.plugin.BuildPluginManager;
import org.apache.maven.plugin.surefire.SurefireMojo;
import org.apache.maven.plugins.annotations.Component;
import org.apache.maven.plugins.annotations.Parameter;

import java.io.File;
import java.net.URISyntaxException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

/**
 * A basis for other Mojos to build upon. This Mojo contains initialization code and some constants.
 * It extends the SurefireMojo and is responsible for collecting various input parameters.
 */
public class BaseMojo extends SurefireMojo {
    public static String SUREFIRE_VERSION = "3.5.2";
    public static int TIMEOUT_3H = 10800;

    /** Path to the artifact directory. */
    @Parameter(property = "artifactDir", defaultValue = ".rvtsm")
    protected String artifactDir;

    /** Path to the file that contains a list of reduced test methods. */
    @Parameter(property = "reducedSet")
    protected String reducedSet;

    /** Path to the file that contains a list of redundant and no trace test methods. */
    @Parameter(property = "redundantAndNoTraceSet")
    protected String redundantAndNoTraceSet;

    /** Output file of the redundant and no trace run. */
    @Parameter(property = "redundantAndNoTraceOut", defaultValue = "redundant-and-no-trace-output.txt")
    protected String redundantAndNoTraceOut;

    /** Path to the matrix file that is used for reduction. */
    @Parameter(property = "matrix")
    protected String matrix;

    /** File that contains a list of test methods in the format of fully_qualified_test_class#test_method. */
    @Parameter(property = "testMethodList")
    protected String testMethodList;

    @Component
    protected BuildPluginManager manager;

    /** Whether to skip all previous steps. */
    @Parameter(property = "skipAllPreviousSteps")
    protected boolean skipAllPreviousSteps;

    // TODO: Currently the agents for non-raw specs have the wrong aop-ajc.xml.
    //  This affects presentation but not correctness.
    // TODO: Do not support raw specs yet.
    @Parameter(property = "excludeRawSpecs", defaultValue = "true")
    protected boolean excludeRawSpecs;

    @Parameter(property = "allTracesDir")
    protected String allTracesDir;

    protected String trackNoStatsAgent;
    protected String noTrackNoStatsAgent;
    protected String noTrackStatsAgent;
    protected String jacocoAgent;

    protected String surefireReportsDirForTestCollection;
    protected String coverageDir;

    /** A directory to keep all the logs generated in the process. */
    protected String logDir;

    protected void initialize() {
        artifactDir = basedir + File.separator + artifactDir;
        new File(artifactDir).mkdirs();
        if (testMethodList == null || testMethodList.isEmpty()) {
            testMethodList = artifactDir + File.separator + "tests.txt";
        }
        if (matrix == null || matrix.isEmpty()) {
            matrix = artifactDir + File.separator + "tests.csv";
        }
        if (reducedSet == null || reducedSet.isEmpty()) {
            reducedSet = artifactDir + File.separator + "reduced.txt";
        }
        if (redundantAndNoTraceSet == null || redundantAndNoTraceSet.isEmpty()) {
            redundantAndNoTraceSet = artifactDir + File.separator + "redundant-and-no-trace.txt";
        }
        if (logDir == null || logDir.isEmpty()) {
            logDir = artifactDir + File.separator + "logs";
        }
        new File(logDir).mkdirs();
        if (allTracesDir == null || allTracesDir.isEmpty()) {
            allTracesDir = artifactDir + File.separator + "all-traces";
        }
        String jarsDir = artifactDir + File.separator + "jars";
        if (!Files.exists(Paths.get(jarsDir))) {
            extractJars();
        }
        trackNoStatsAgent = jarsDir + File.separator
                + String.format("track-no-stats%s-agent.jar", (excludeRawSpecs ? "-no-raw" : ""));
        noTrackNoStatsAgent = jarsDir + File.separator
                + String.format("no-track-no-stats%s-agent.jar", (excludeRawSpecs ? "-no-raw" : ""));
        noTrackStatsAgent = jarsDir + File.separator
                + String.format("no-track-stats%s-agent.jar", (excludeRawSpecs ? "-no-raw" : ""));
        jacocoAgent = jarsDir + File.separator + "jacocoagent-0.8.13.jar";
        surefireReportsDirForTestCollection = artifactDir + File.separator + "surefire-reports-collect-tests";
        coverageDir = artifactDir + File.separator + "coverage";
    }

    protected void extractJars() {
        try {
            String thisJarAbsolutePath = new File(
                    this.getClass().getProtectionDomain().getCodeSource().getLocation().toURI()).getAbsolutePath();
            List<String> command = new ArrayList<>(Arrays.asList("jar", "-xf", thisJarAbsolutePath, "jars"));
            int exitCode = Utils.runSubprocess(command, new File(artifactDir), new File("/dev/null"), 0, false, null);
            if (exitCode != 0) {
                command = new ArrayList<>(Arrays.asList("unzip", "-d", artifactDir, thisJarAbsolutePath, "jars/*"));
                Utils.runSubprocess(command, new File(artifactDir), new File("/dev/null"), 0, false, null);
                if (exitCode != 0) {
                    throw new RuntimeException("Error extracting jars.");
                }
            }
        } catch (URISyntaxException ex) {
            getLog().error( "Error extracting jars.");
        }
    }
}
