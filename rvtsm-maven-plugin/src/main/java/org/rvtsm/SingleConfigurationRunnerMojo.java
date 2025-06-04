package org.rvtsm;

import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;
import org.apache.maven.plugins.annotations.ResolutionScope;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.rvtsm.Utils.runSubprocess;

/**
 * Conducts a Maven Surefire run with these configurations:
 * 1. File pointing to the set of tests to run.
 * 2. Whether to use no-rv, no-track, track, or stats.
 * 3. A label to mark the run, related to the output file generated as well.
 */
@Mojo(name = "scr", requiresDependencyResolution = ResolutionScope.TEST)
public class SingleConfigurationRunnerMojo extends MatrixReductionMojo {
    @Parameter(property = "testMethodsToRun")
    protected String testMethodsToRun;

    @Parameter(property = "rvConfig")
    protected String rvConfig;

    @Parameter(property = "runLabel")
    protected String runLabel;

    @Override
    public void execute() throws MojoExecutionException {
        if (!skipAllPreviousSteps) {
            super.execute();
        } else {
            initialize();
        }

        String scrDir = artifactDir + File.separator + "scr-" + runLabel + "-traces";
        new File(scrDir).mkdirs();
        String testsToRun = Utils.getTestsFromFile(testMethodsToRun);
        String agentPath = "";
        Map<String, String> env = new HashMap<>();
        env.put("RVMLOGGINGLEVEL", "UNIQUE");
        switch (rvConfig) {
            case "track":
                agentPath = trackNoStatsAgent;
                env.put("TRACEDB_PATH", scrDir);
                env.put("TRACEDB_CONFIG_PATH", artifactDir + File.separator + ".trace-db.config");
                env.put("COLLECT_MONITORS", "1");
                env.put("COLLECT_TRACES", "1");
                break;
            case "stats":
                agentPath = noTrackStatsAgent;
                break;
            case "no-track":
                agentPath = noTrackNoStatsAgent;
                break;
            case "no-rv":
            default:
                break;
        }
        String randomId = UUID.randomUUID().toString();
        List<String> command = new ArrayList<>();
        if (rvConfig.equals("no-rv")) {
            command = new ArrayList<>(Arrays.asList(
                    "mvn", "-Djava.io.tmpdir=" + scrDir,
                    "-Dmaven.repo.local=" + this.getSession().getLocalRepository().getBasedir(),
                    "-Dsurefire.exitTimeout=" + TIMEOUT_3H,
                    "surefire:" + SUREFIRE_VERSION + ":test", "-DtempDir=" + randomId
            ));
        } else {
            command = new ArrayList<>(Arrays.asList(
                    "mvn", "-Djava.io.tmpdir=" + scrDir,
                    "-Dmaven.repo.local=" + this.getSession().getLocalRepository().getBasedir(),
                    "-Dsurefire.exitTimeout=" + TIMEOUT_3H,
                    "-DargLine=-Xmx500g -XX:-UseGCOverheadLimit -javaagent:" + agentPath,
                    "surefire:" + SUREFIRE_VERSION + ":test", "-DtempDir=" + randomId
            ));
        }
        if (!(testsToRun == null || testsToRun.equals(""))) {
            command.add("-Dtest=" + testsToRun);
        }
        long start = System.currentTimeMillis();
        int exitCode = runSubprocess(command, basedir,
                new File(logDir + File.separator + runLabel + "-scr-log.txt"), 0, false, env);
        long end = System.currentTimeMillis();
        getLog().info("The run with label " + runLabel + " finished in "
                + String.format("%.3f", ((double) end - (double) start) / 1000) + " s.");
        if (exitCode != 0) {
            throw new MojoExecutionException("Failed to run tests with label " + runLabel);
        }
    }
}
