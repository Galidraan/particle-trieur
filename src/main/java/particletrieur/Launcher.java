package particletrieur;

/**
 * Launcher class that does not extend javafx.application.Application.
 * This is required for JDK 11+ when JavaFX is bundled in a fat JAR,
 * otherwise the JVM fails to find the JavaFX modules before loading the classpath.
 */
public class Launcher {
    public static void main(String[] args) {
        App.main(args);
    }
}
