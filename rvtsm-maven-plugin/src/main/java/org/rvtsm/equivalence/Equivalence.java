package org.rvtsm.equivalence;

import org.rvtsm.Utils;

import java.io.FileNotFoundException;
import java.io.PrintWriter;
import java.io.UnsupportedEncodingException;
import java.util.Map;
import java.util.Set;

public class Equivalence {

    /**
     * Processes the matrix to produce a new matrix by applying different notions of equivalence.
     * @param matrix the original matrix to process
     * @return the processed matrix after applying different notions of equivalence
     */
    public Map<String, Set<String>> process(Map<String, Set<String>> matrix) {
        return matrix;
    }

    /**
     * Provides a command line interface for running the equivalence algorithm.
     * @param args accepts three arguments: matrix file, equivalence, and output file
     */
    public static void main(String[] args) {
        if (args.length != 3) {
            System.err.println("You need 3 arguments: matrix file, equivalence, and output file.");
        }
        String matrixFile = args[0];
        String equivalence = args[1];
        String outputFile = args[2];
        Map<String, Set<String>> matrix = Utils.loadMatrix(matrixFile);
        System.out.println("Loaded " + matrix.size() + " test requirements from " + matrixFile + ", using " + equivalence);
        for (String eq : equivalence.split("-")) {
            Equivalence instance;
            switch (eq) {
                // TODO: Add other notions too (Don't forget about break)
                case "state":
                    System.out.println("Running state transition equivalence...");
                    instance = new StateTransitionEquivalence();
                    break;
                case "prefix":
                    System.out.println("Running prefix equivalence...");
                    instance = new PrefixEquivalence();
                    break;
                case "detour":
                    System.out.println("Running detour equivalence...");
                    instance = new DetourEquivalence();
                    break;
                case "online_detour":
                    System.out.println("Running online detour equivalence...");
                    instance = new OnlineDetourEquivalence();
                    break;
                case "violation":
                    System.out.println("Running violation equivalence...");
                    instance = new ViolationEquivalence();
                    break;
                default:
                    instance = new PerfectEquivalence();
            }
            matrix = instance.process(matrix);
        }
        try (PrintWriter writer = new PrintWriter(outputFile, "UTF-8")) {
            for (Map.Entry<String, Set<String>> entry : matrix.entrySet()) {
                writer.print(entry.getKey());
                for (String trace : entry.getValue()) {
                    writer.print("," + trace);
                }
                writer.println();
            }
            writer.flush();
        } catch (FileNotFoundException | UnsupportedEncodingException ex) {
            ex.printStackTrace();
        }
    }
}
