package org.rvtsm;

import org.apache.maven.plugin.logging.Log;

import java.io.File;
import java.io.IOException;
import java.lang.reflect.Field;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Arrays;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TreeSet;
import java.util.concurrent.TimeUnit;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

public class Utils {
    public static int runSubprocess(List<String> command, File basedir, File output, long timeout, boolean append,
                                    Map<String, String> env) {
        int exitCode;
        try {
            ProcessBuilder pb = new ProcessBuilder(command);
            pb.inheritIO();
            pb.directory(basedir);
            pb.redirectErrorStream(true);
            if (output != null) {
                if (append) {
                    pb.redirectOutput(ProcessBuilder.Redirect.appendTo(output));
                } else {
                    pb.redirectOutput(output);
                }
            }
            if (env != null) {
                pb.environment().putAll(env);
            }
            Process process = pb.start();
            if (timeout > 0) {
                exitCode = process.waitFor(timeout, TimeUnit.SECONDS) ? 0 : 1;
            } else {
                exitCode = process.waitFor();
            }
        } catch (IOException | InterruptedException ex) {
            ex.printStackTrace();
            exitCode = 1;
        }
        return exitCode;
    }

    public static void copyRecursively(Path src, Path dest) throws IOException {
        Files.walk(src).forEach(srcPath -> {
            try {
                Path targetPath = dest.resolve(src.relativize(srcPath));
                Files.copy(srcPath, targetPath, StandardCopyOption.REPLACE_EXISTING);
            } catch (IOException ex) {
                ex.printStackTrace();
            }
        });
    }

    public static boolean recursiveDelete(File toDelete) {
        File[] contents = toDelete.listFiles();
        if (contents != null) {
            for (File file : contents) {
                recursiveDelete(file);
            }
        }
        return toDelete.delete();
    }

    /**
     * Helper method that inverts a map.
     * @param original the original map to invert
     * @return the inverted map
     */
    public static Map<String, Set<String>> inverseMap(Map<String, Set<String>> original) {
        Map<String, Set<String>> inverse = new HashMap<>();
        for (Map.Entry<String, Set<String>> entry : original.entrySet()) {
            for (String value : entry.getValue()) {
                if (!inverse.containsKey(value)) {
                    inverse.put(value, new HashSet<>());
                }
                // Note: Do not use getOrDefault, because the default empty set is not a part of the map,
                // so updating it will not have any effect for the inverse map.
                inverse.get(value).add(entry.getKey());
            }
        }
        return inverse;
    }

    /**
     * Get a set of tests from a file.
     * @param file the file containing tests
     * @return a set of tests in that file
     */
    public static Set<String> getTestSetFromFile(String file) {
        try {
            List<String> lines = Files.readAllLines(Paths.get(file));
            return lines.stream()
                    .map(String::trim)
                    .map(testMethod -> testMethod.split("\\[")[0])
                    .collect(Collectors.toSet());
        } catch (IOException ex) {
            ex.printStackTrace();
        }
        return null;
    }

    /**
     * Loads a trace ID to test method mapping from a file.
     * @param traceIdToTestMethodsFile the file is usually named "specs-test.csv"
     * @return a map of trace IDs to the set of test methods that produce the trace
     */
    public static Map<String, Set<String>> loadTraceIdToTestMethods(String traceIdToTestMethodsFile) {
        Map<String, Set<String>> traceIdToTestMethods = new HashMap<>();
        try {
            Files.readAllLines(Paths.get(traceIdToTestMethodsFile)).stream()
                    .map(String::trim)
                    .filter(line -> !line.startsWith("OK"))
                    .forEach(line -> {
                        String traceId = line.split("\\s+")[0];
                        Set<String> testMethods = new HashSet<>();

                        Pattern methodPattern = Pattern.compile("([\\w\\.]+)\\.([\\w]+)\\([^)]+\\)");
                        Matcher methodMatcher = methodPattern.matcher(line);

                        while (methodMatcher.find()) {
                            String testMethod = methodPattern.matcher(methodMatcher.group(1) + "#"
                                    + methodMatcher.group(2)).replaceAll("$1");
                            testMethods.add(testMethod);
                        }
                        if (testMethods.isEmpty()) {
                            testMethods.add("NoTest");
                        }
                        traceIdToTestMethods.put(traceId, testMethods);
                    });
        } catch (IOException ex) {
            ex.printStackTrace();
        }
        return traceIdToTestMethods;
    }

    /**
     * Loads a matrix file into a map. Usually this file is "tests.csv."
     * @param matrixFile the file containing the matrix
     * @return the matric as a map from a test method to a set of test requirements that this method satisfies
     */
    public static Map<String, Set<String>> loadMatrix(String matrixFile) {
        Map<String, Set<String>> matrix = new HashMap<>();
        try {
            Files.readAllLines(Paths.get(matrixFile)).stream()
                    .map(String::trim)
                    .forEach(line -> {
                        String[] parts = line.split(",");
                        String testMethod = parts[0];
                        Set<String> testRequirements = new TreeSet<>(Arrays.asList(parts).subList(1, parts.length));
                        matrix.put(testMethod, testRequirements);
                    });
        } catch (IOException ex) {
            ex.printStackTrace();
        }
        return matrix;
    }

    public static Map<Integer, String> loadLocationMap(String locationMapFile) {
        Map<Integer, String> locationIdToLocation = new HashMap<>();
        try {
            Files.readAllLines(Paths.get(locationMapFile)).stream()
                    .map(String::trim)
                    .filter(line -> !line.equals("=== LOCATION MAP ==="))
                    .forEach(line ->
                            locationIdToLocation.put(Integer.valueOf(line.split("\\s+")[0]), line.split("\\s+")[1]));
        } catch (IOException ex) {
            ex.printStackTrace();
        }
        return locationIdToLocation;
    }

    public static Map<Integer, String> loadTraceIdToTrace(String traceIdToTraceFile) {
        Map<Integer, String> traceIdToTrace = new HashMap<>();
        try {
            Files.readAllLines(Paths.get(traceIdToTraceFile)).stream()
                    .map(String::trim)
                    .filter(line -> !line.startsWith("=== UNIQUE TRACES ==="))
                    .forEach(line -> traceIdToTrace.put(Integer.valueOf(line.split("\\s+")[0]),
                            line.split("\\s+", 2)[1].replace("[", "").replace("]", "")));
        } catch (IOException ex) {
            ex.printStackTrace();
        }
        return traceIdToTrace;
    }

    /**
     * Transforms a local trace using local locations to a global trace using global locations.
     * @param localTrace
     * @param localLocationIdToGlobalLocationId
     * @param globalLocationToId
     * @return
     */
    public static String transformToGlobalTrace(String localTrace,
                                                Map<Integer, Integer> localLocationIdToGlobalLocationId) {
        String[] localEvents = localTrace.split(",\\s+");
        String[] globalEvents = new String[localEvents.length];
        Pattern pattern = Pattern.compile("(e\\d+)~(\\d+)(?:x(\\d+))?");
        for (int i = 0; i < localEvents.length; i++) {
            String localEvent = localEvents[i];
            Matcher matcher = pattern.matcher(localEvent);
            if (matcher.matches()) {
                String eventId = matcher.group(1);
                String localLocation = matcher.group(2);
                String frequency = matcher.group(3);
                globalEvents[i] = eventId + "~" + localLocationIdToGlobalLocationId.get(Integer.valueOf(localLocation))
                        + (frequency != null ? "x" + Integer.valueOf(frequency) : "");
            }
        }
        return String.join(", ", globalEvents);
    }

    /**
     * Expands the traces by replacing events with their expanded versions.
     * @param trace the trace to expand
     * @param originalEvents the list of original events
     * @param expandedEvents the list of expanded events (with locations removed)
     */
    public static void expandTraces(String trace, List<String> originalEvents, List<String> expandedEvents) {
        // The goal of this for loop is to expand the events, e.g., it turns e1~2x3 into [e1~2, e1~2, e1~2]
        for (String event : trace.split(" ")) {
            if (event.contains("x")) {
                for (int i = 0; i < Integer.parseInt(event.substring(event.indexOf('x') + 1)); i++) {
                    expandedEvents.add(event.substring(0, event.indexOf('~')));
                    originalEvents.add(event.substring(0, event.indexOf('x')));
                }
            } else {
                expandedEvents.add(event.substring(0, event.indexOf('~')));
                originalEvents.add(event);
            }
        }
    }

    /**
     * Get the comma-seperated string representation from a file of test methods.
     * @param file
     * @return
     */
    public static String getTestsFromFile(String file) {
        if (file == null || file.isEmpty() || !Files.exists(Paths.get(file))) {
            return null;
        }
        try {
            List<String> lines = Files.readAllLines(Paths.get(file));
            lines = lines.stream().map(String::trim).collect(Collectors.toList());
            return String.join(",", lines);
        } catch (IOException ex) {
            ex.printStackTrace();
        }
        return null;
    }

    public static void setEnv(Log log, String key, String value) {
        try {
            Map<String, String> env = System.getenv();
            Class<?> cl = env.getClass();
            Field field = cl.getDeclaredField("m");
            field.setAccessible(true);
            Map<String, String> writableEnv = (Map)field.get(env);
            writableEnv.put(key, value);
        } catch (Exception e) {
            log.error(e);
        }
    }
}
