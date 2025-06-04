package org.rvtsm;

import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;
import org.apache.maven.plugins.annotations.ResolutionScope;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.twdata.maven.mojoexecutor.MojoExecutor.artifactId;
import static org.twdata.maven.mojoexecutor.MojoExecutor.configuration;
import static org.twdata.maven.mojoexecutor.MojoExecutor.element;
import static org.twdata.maven.mojoexecutor.MojoExecutor.executeMojo;
import static org.twdata.maven.mojoexecutor.MojoExecutor.executionEnvironment;
import static org.twdata.maven.mojoexecutor.MojoExecutor.goal;
import static org.twdata.maven.mojoexecutor.MojoExecutor.groupId;
import static org.twdata.maven.mojoexecutor.MojoExecutor.name;
import static org.twdata.maven.mojoexecutor.MojoExecutor.plugin;
import static org.twdata.maven.mojoexecutor.MojoExecutor.version;

@Mojo(name = "collect-traces", requiresDependencyResolution = ResolutionScope.TEST)
public class CollectTracesMojo extends CollectTestsMojo {
    /** Decides whether to compress traces (for storage reasons) or not. */
    // TODO: Implement
    @Parameter(property = "compressTraces")
    protected boolean compressTraces;

    @Parameter(property = "parallelCollection")
    protected boolean parallelCollection;

    @Parameter(property = "collectionThreads", defaultValue = "10")
    protected int collectionThreads;

    /** Specifies what kind of test requirement is used. Supports "trace" and "coverage". */
    @Parameter(property = "testRequirementType", defaultValue = "trace")
    protected String testRequirementType;

    private void collectTracesSequential() {
        Utils.setEnv(getLog(), "RVMLOGGINGLEVEL", "UNIQUE");
        Utils.setEnv(getLog(), "TRACEDB_PATH", allTracesDir);
        Utils.setEnv(getLog(), "TRACEDB_CONFIG_PATH", artifactDir + File.separator + ".trace-db.config");
        try (PrintWriter writer = new PrintWriter(artifactDir + File.separator + ".trace-db.config")) {
            writer.println("db=memory");
            writer.println("dumpDB=false");
            writer.flush();
        } catch (FileNotFoundException e) {
            throw new RuntimeException(e);
        }
        Utils.setEnv(getLog(), "COLLECT_MONITORS", "1");
        Utils.setEnv(getLog(), "COLLECT_TRACES", "1");
        try {
            executeMojo(
                    plugin(
                            groupId("org.apache.maven.plugins"),
                            artifactId("maven-surefire-plugin"),
                            version(SUREFIRE_VERSION)
                    ),
                    goal("test"),
                    configuration(
                            element(name("argLine"), "-javaagent:" + trackNoStatsAgent + " "
                                    + "-Xmx500g -XX:-UseGCOverheadLimit"),
                            element(name("tempDir"), "collect-traces"),
                            element(name("forkedProcessExitTimeoutInSeconds"), "" + TIMEOUT_3H)
                    ),
                    executionEnvironment(this.getProject(), this.getSession(), manager)
            );
        } catch (MojoExecutionException ex) {
            throw new RuntimeException(ex);
        }
    }

    private void collectTracesParallel() {
        new File(allTracesDir).mkdirs();
        // Write to the DB config.
        try (PrintWriter writer = new PrintWriter(artifactDir + File.separator + ".trace-db.config")) {
            writer.println("db=memory");
            writer.println("dumpDB=false");
            writer.flush();
        } catch (FileNotFoundException ex) {
            throw new RuntimeException(ex);
        }
        Set<String> testMethods = Utils.getTestSetFromFile(testMethodList);
        String traceCollectionLogDir = logDir + File.separator + "trace-collection";
        new File(traceCollectionLogDir).mkdirs();
        try {
            ExecutorService pool = Executors.newFixedThreadPool(collectionThreads);
            List<Future<?>> futures = new ArrayList<>();
            for (String testMethod : testMethods) {
                futures.add(pool.submit(() -> {
                    String randomId = UUID.randomUUID().toString();
                    String tmpDir = File.separator + "tmp" + File.separator + "tsm" + File.separator + randomId;
                    new File(tmpDir).mkdirs();
                    String destDir = allTracesDir + File.separator + testMethod;
                    new File(destDir).mkdirs();
                    Map<String, String> env = new HashMap<>();
                    env.put("RVMLOGGINGLEVEL", "UNIQUE");
                    env.put("TRACEDB_PATH", destDir);
                    env.put("TRACEDB_CONFIG_PATH", artifactDir + File.separator + ".trace-db.config");
                    env.put("COLLECT_MONITORS", "1");
                    env.put("COLLECT_TRACES", "1");
                    List<String> command = new ArrayList<>(Arrays.asList(
                            "mvn", "-Djava.io.tmpdir=" + destDir,
                            "-Dmaven.repo.local=" + this.getSession().getLocalRepository().getBasedir(),
                            "-Dsurefire.exitTimeout=" + TIMEOUT_3H,
                            "-DargLine=-Xmx500g -XX:-UseGCOverheadLimit -javaagent:" + trackNoStatsAgent,
                            "surefire:" + SUREFIRE_VERSION + ":test", "-Dtest=" + testMethod, "-DtempDir=" + randomId
                    ));
                    int exitCode = Utils.runSubprocess(command, basedir,
                            new File(traceCollectionLogDir + File.separator + testMethod + "-log.txt"), 0, false, env);
                    if (exitCode != 0) {
                        throw new RuntimeException("Failed to collect traces for test method: " + testMethod);
                    }
                }));
            }
            for (Future<?> future : futures) {
                future.get();
            }
        } catch (InterruptedException | ExecutionException ex) {
            ex.printStackTrace();
        }
    }

    /**
     * Collect all traces observed by tracemop in the project.
     * Achieved through invoking the surefire plugin with the right settings.
     */
    @Override
    public void execute() throws MojoExecutionException {
        if (!skipAllPreviousSteps) {
            super.execute();
        } else {
            initialize();
        }
        // Skip if traces are already collected.
        if (new File(allTracesDir).exists()) {
            getLog().info("Skipping trace collection, as traces have already been collected.");
            return;
        }

        if (testRequirementType.equals("coverage")) {
            getLog().info("Skipping trace collection, we only need to collect coverage.");
            return;
        }

        getLog().info("Collecting traces to: " + allTracesDir);

        if (parallelCollection) {
            collectTracesParallel();
        } else {
            collectTracesSequential();
        }
    }
}
