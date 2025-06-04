package com.minnka;

import org.apache.maven.artifact.versioning.ComparableVersion;
import org.apache.maven.eventspy.AbstractEventSpy;
import org.apache.maven.execution.ExecutionEvent;
import org.apache.maven.model.ConfigurationContainer;
import org.apache.maven.model.Dependency;
import org.apache.maven.model.Plugin;
import org.apache.maven.model.PluginExecution;
import org.apache.maven.project.MavenProject;
import org.codehaus.plexus.util.xml.Xpp3Dom;
import javax.inject.Named;
import javax.inject.Singleton;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Named
@Singleton
public class JUnitExtension extends AbstractEventSpy {
    private enum JUnit_Version {
        JUNIT_4,    // JUnit >= 4.12
        JUNIT_5
    }

    private Set<JUnit_Version> addDependencyIfNecessary(MavenProject project) {
        boolean hasListener = false;
        Set<JUnit_Version> versions = new HashSet<>();

        for (Dependency dependency : project.getDependencies()) {
            if (dependency.getGroupId().equals("junit") &&
                    (dependency.getArtifactId().equals("junit") || dependency.getArtifactId().equals("junit-dep"))) {
                ComparableVersion junitVersion = new ComparableVersion(dependency.getVersion());
                ComparableVersion minimumVersion = new ComparableVersion("4.11");

                if (junitVersion.compareTo(minimumVersion) < 0) {
                    dependency.setVersion("4.11");
                }

                versions.add(JUnit_Version.JUNIT_4);
            } else if (dependency.getGroupId().equals("org.junit.jupiter") &&
                    dependency.getArtifactId().equals("junit-jupiter-engine"))  {
                versions.add(JUnit_Version.JUNIT_5);
            }
        }
        return versions;
    }

    private void updateSurefireVersion(Plugin plugin) {
        if (System.getenv("JUNIT_TEST_LISTENER") == null ||
                (!System.getenv("JUNIT_TEST_LISTENER").equals("1")
                        && !System.getenv("JUNIT_TEST_LISTENER").equals("2")
                )) {
            return;
        }

        if (!plugin.getGroupId().equals("org.apache.maven.plugins") ||
                !plugin.getArtifactId().equals("maven-surefire-plugin")) {
            // Not Surefire
            return;
        }

        if (System.getenv("SUREFIRE_VERSION") != null) {
            plugin.setVersion(System.getenv("SUREFIRE_VERSION"));
            return;
        }

        if (System.getenv("JUNIT_TEST_LISTENER").equals("2")) {
            plugin.setVersion("3.5.2");
            return;
        }


        // getVersion will return null for project romix/java-concurrent-hash-trie-map
        String pluginVersion = plugin.getVersion() == null ? "0" : plugin.getVersion();
        ComparableVersion surefireVersion = new ComparableVersion(pluginVersion);
        ComparableVersion reasonableVersion = new ComparableVersion("3.1.2");
        if (surefireVersion.compareTo(reasonableVersion) < 0) {
            // Surefire is outdated, update it to `reasonableVersion`
            plugin.setVersion("3.1.2");
        }
    }

    private void updateSurefire(MavenProject project, Set<JUnit_Version> versions) {
        for (Plugin plugin : project.getBuildPlugins()) {
            if (plugin.getGroupId().equals("org.apache.maven.plugins") &&
                    plugin.getArtifactId().equals("maven-surefire-plugin")) {
                updateSurefireVersion(plugin);
            }
        }
    }

    @Override
    public void onEvent(Object event) {
        if (System.getenv("JUNIT_TEST_LISTENER") == null ||
                (!System.getenv("JUNIT_TEST_LISTENER").equals("1")
                        && !System.getenv("JUNIT_TEST_LISTENER").equals("2")
                )) {
            return;
        }

        if (event instanceof ExecutionEvent) {
            ExecutionEvent e = (ExecutionEvent) event;
            if (e.getType() == ExecutionEvent.Type.SessionStarted) {
                List<MavenProject> sortedProjects = e.getSession().getProjectDependencyGraph().getSortedProjects();
                for (MavenProject project : sortedProjects) {
                    Set<JUnit_Version> versions = addDependencyIfNecessary(project);
                    updateSurefire(project, versions);
                }
            }
        }
    }
}
