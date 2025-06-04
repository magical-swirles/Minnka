package org.rvtsm;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;

public class TestUtils {
    /** Get files in resources. */
    public File loadFileFromResources(String prefix, String suffix) {
        // Get the resource as a stream
        InputStream scriptStream = getClass().getClassLoader().getResourceAsStream(prefix + suffix);
        // TODO: Use the python script from source's resources directory.
        // Create a temporary file
        File tempFile;
        try {
            tempFile = File.createTempFile(prefix, suffix);
        } catch (IOException ex) {
            throw new RuntimeException(ex);
        }
        tempFile.deleteOnExit();

        // Copy the script to the temp file
        try (FileOutputStream out = new FileOutputStream(tempFile)) {
            byte[] buffer = new byte[1024];
            int bytesRead;
            while ((bytesRead = scriptStream.read(buffer)) != -1) {
                out.write(buffer, 0, bytesRead);
            }
        } catch (IOException ex) {
            ex.printStackTrace();
        }
        return tempFile;
    }
}
