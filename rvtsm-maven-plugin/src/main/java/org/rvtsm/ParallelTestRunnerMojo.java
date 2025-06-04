package org.rvtsm;

import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.ResolutionScope;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.List;
import java.util.stream.Collectors;

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

/**
 * Given a set of reduced test methods, and a set of redundant and no trace test methods, execute:
 * 1. The reduced set of tests with RV
 * 2. The redundant and no-trace set of tests without RV
 */
@Mojo(name = "ptr", requiresDependencyResolution = ResolutionScope.TEST)
public class ParallelTestRunnerMojo extends MatrixReductionMojo {
    @Override
    public void execute() throws MojoExecutionException {
        if (!skipAllPreviousSteps) {
            super.execute();
        } else {
            initialize();
        }

        String reducedTests = Utils.getTestsFromFile(reducedSet);
        String redundantAndNoTraceTests = Utils.getTestsFromFile(redundantAndNoTraceSet);
        Thread reducedThread = new Thread(() -> {
            try {
                executeMojo(
                        plugin(
                                groupId("org.apache.maven.plugins"),
                                artifactId("maven-surefire-plugin"),
                                version(SUREFIRE_VERSION)
                        ),
                        goal("test"),
                        configuration(
                                element(name("argLine"), "-javaagent:" + noTrackNoStatsAgent + " "
                                        + "-Xmx500g -XX:-UseGCOverheadLimit"),
                                element(name("test"), reducedTests),
                                element(name("tempDir"), "reduced")
                        ),
                        executionEnvironment(this.getProject(), this.getSession(), manager)
                );
            } catch (MojoExecutionException ex) {
                throw new RuntimeException(ex);
            }
        });
        // TODO: In the long term, we only want to specify 1 set and deduce the other.
        Thread redundantAndNoTraceThread = new Thread(() -> {
            try {
                executeMojo(
                        plugin(
                                groupId("org.apache.maven.plugins"),
                                artifactId("maven-surefire-plugin"),
                                version(SUREFIRE_VERSION)
                        ),
                        goal("test"),
                        configuration(
                                element(name("test"), redundantAndNoTraceTests),
                                element(name("tempDir"), "redundantAndNoTrace")
                        ),
                        executionEnvironment(this.getProject(), this.getSession(), manager)
                );
            } catch (MojoExecutionException ex) {
                throw new RuntimeException(ex);
            }
        });
        try {
            reducedThread.start();
            redundantAndNoTraceThread.start();
            reducedThread.join();
            redundantAndNoTraceThread.join();
        } catch (Exception ex) {
            ex.printStackTrace();
        }
    }
}
