package org.rvtsm;

import org.apache.maven.plugin.MojoExecutionException;
import org.apache.maven.plugins.annotations.Mojo;
import org.apache.maven.plugins.annotations.Parameter;
import org.apache.maven.plugins.annotations.ResolutionScope;
import org.w3c.dom.Document;
import org.w3c.dom.Element;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import static org.twdata.maven.mojoexecutor.MojoExecutor.artifactId;
import static org.twdata.maven.mojoexecutor.MojoExecutor.configuration;
import static org.twdata.maven.mojoexecutor.MojoExecutor.executeMojo;
import static org.twdata.maven.mojoexecutor.MojoExecutor.executionEnvironment;
import static org.twdata.maven.mojoexecutor.MojoExecutor.goal;
import static org.twdata.maven.mojoexecutor.MojoExecutor.groupId;
import static org.twdata.maven.mojoexecutor.MojoExecutor.plugin;
import static org.twdata.maven.mojoexecutor.MojoExecutor.version;

@Mojo(name = "collect-tests", requiresDependencyResolution = ResolutionScope.TEST)
public class CollectTestsMojo extends BaseMojo {
    @Parameter(property = "coverageCollectionThreads", defaultValue = "10")
    protected int coverageCollectionThreads;

    /**
     * Upon reading a test report XML file, this method will register a line of "test_class#test_method" to the test
     * method list file.
     * @param testReportXML path to the test report XML file
     */
    public void registerTestMethods(Path testReportXML) {
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
                    String name = element.getAttribute("name").split("\\[")[0];
                    String classname = element.getAttribute("classname");
                    PrintWriter writer = new PrintWriter(new FileOutputStream(testMethodList, true));
                    writer.println(classname + "#" + name);
                    writer.flush();
                    writer.close();
                }
            }
        } catch (ParserConfigurationException | IOException | SAXException ex) {
            ex.printStackTrace();
        }
    }

    void collectCoverage() {
        new File(coverageDir).mkdirs();
        Set<String> testMethods = Utils.getTestSetFromFile(testMethodList);
        String coverageCollectionLogDir = logDir + File.separator + "coverage-collection";
        new File(coverageCollectionLogDir).mkdirs();
        try {
            ExecutorService pool = Executors.newFixedThreadPool(coverageCollectionThreads);
            List<Future<?>> futures = new ArrayList<>();
            for (String testMethod : testMethods) {
                futures.add(pool.submit(() -> {
                    String randomId = UUID.randomUUID().toString();
                    String ioTmpDir = artifactDir + File.separator + randomId;
                    new File(ioTmpDir).mkdirs();
                    List<String> command = new ArrayList<>(Arrays.asList(
                            "mvn", "-Djava.io.tmpdir=" + ioTmpDir,
                            "-Dmaven.repo.local=" + this.getSession().getLocalRepository().getBasedir(),
                            "-Dsurefire.exitTimeout=" + TIMEOUT_3H,
                            "-DargLine=-Xmx500g -XX:-UseGCOverheadLimit -javaagent:" + jacocoAgent + "=destfile="
                                    + coverageDir + File.separator + testMethod + ".exec",
                            "surefire:" + SUREFIRE_VERSION + ":test", "-Dtest=" + testMethod, "-DtempDir=" + randomId
                    ));
                    int exitCode = Utils.runSubprocess(command, basedir,
                            new File(coverageCollectionLogDir + File.separator + testMethod + "-log.txt"),
                            0, false, null);
                    Utils.recursiveDelete(new File(ioTmpDir));
                    if (exitCode != 0) {
                        throw new RuntimeException("Failed to collect coverage for test method: " + testMethod);
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

    /** Executes all tests in the project by invoking Maven Surefire Plugin. */
    protected void runAllTests() {
        try {
            executeMojo(
                    plugin(
                            groupId("org.apache.maven.plugins"),
                            artifactId("maven-surefire-plugin"),
                            version(SUREFIRE_VERSION)
                    ),
                    goal("test"),
                    configuration(),
                    executionEnvironment(this.getProject(), this.getSession(), manager)
            );
        } catch (MojoExecutionException ex) {
            ex.printStackTrace();
        }
    }

    /**
     * Collect the set of test methods in the project as well as their coverage information.
     * Achieved through invoking the surefire plugin and analyzing surefire reports.
     */
    @Override
    public void execute() throws MojoExecutionException {
        initialize();
        if (Files.exists(Paths.get(testMethodList))) {
            getLog().info("Skipping test collection, as test method list file already exists.");
            return;
        }
        getLog().info("Collecting test methods to file: " + testMethodList);

        runAllTests();

        try {
            Files.walk(this.getReportsDirectory().toPath())
                    .filter(Files::isRegularFile)
                    .filter(path -> path.toString().endsWith(".xml"))
                    .forEach(this::registerTestMethods);
        } catch (IOException ex) {
            ex.printStackTrace();
        }

        try {
            if (Files.exists(Paths.get(surefireReportsDirForTestCollection))) {
                Utils.recursiveDelete(new File(surefireReportsDirForTestCollection));
            }
            Utils.copyRecursively(this.getReportsDirectory().toPath(), Paths.get(surefireReportsDirForTestCollection));
        } catch (IOException ex) {
            throw new RuntimeException(ex);
        }

        if (!Files.exists(Paths.get(coverageDir))) {
            collectCoverage();
        }
    }
}
