package particletrieur.utils;

import java.io.*;
import java.nio.file.*;
import java.util.Enumeration;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

public class ResourceExtractor {
    /**
     * Extracts a directory from the JAR resources to a target directory on disk.
     * @param resourcePathInJar Path inside the JAR (e.g. "/python-env")
     * @param targetDir Directory to extract to
     * @throws IOException if extraction fails
     */
    public static void extractDirectoryFromJar(String resourcePathInJar, File targetDir) throws IOException {
        String jarPath = ResourceExtractor.class.getProtectionDomain().getCodeSource().getLocation().getPath();
        try (ZipFile jar = new ZipFile(jarPath)) {
            Enumeration<? extends ZipEntry> entries = jar.entries();
            while (entries.hasMoreElements()) {
                ZipEntry entry = entries.nextElement();
                String name = entry.getName();
                if (name.startsWith(resourcePathInJar.replaceFirst("^/", ""))) {
                    File dest = new File(targetDir, name.substring(resourcePathInJar.length()));
                    if (entry.isDirectory()) {
                        dest.mkdirs();
                    } else {
                        dest.getParentFile().mkdirs();
                        try (InputStream in = jar.getInputStream(entry);
                             OutputStream out = new FileOutputStream(dest)) {
                            byte[] buffer = new byte[4096];
                            int len;
                            while ((len = in.read(buffer)) > 0) {
                                out.write(buffer, 0, len);
                            }
                        }
                        dest.setExecutable(true, false);
                    }
                }
            }
        }
    }
}
