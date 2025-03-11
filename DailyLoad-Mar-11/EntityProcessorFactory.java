/**
 * EntityProcessorFactory - Factory for creating entity processors
 * This class creates the appropriate entity processor for a given entity code
 */
public class EntityProcessorFactory {
    
    /**
     * Create an entity processor for the given entity code
     * 
     * @param entity The entity code (E5, E3, E8, E7, EB)
     * @param loadDir Directory containing the data files
     * @param logDir Directory for log files
     * @param dbUser Database username
     * @param dbPassword Database password
     * @param jdbcUrl JDBC URL for database connection
     * @return An entity processor for the given entity
     */
    public static EntityProcessor createProcessor(
            String entity,
            String loadDir,
            String logDir,
            String dbUser,
            String dbPassword,
            String jdbcUrl) {
        
        // Create the appropriate processor based on entity code
        switch (entity) {
            case "E5":
                return new ProcessE5Entity(loadDir, logDir, dbUser, dbPassword, jdbcUrl);
            case "E3":
                // Return E3 processor when implemented
                // return new ProcessE3Entity(loadDir, logDir, dbUser, dbPassword, jdbcUrl);
                // For now, throw exception
                throw new UnsupportedOperationException("E3 processor not yet implemented");
            case "E8":
                // Return E8 processor when implemented
                // return new ProcessE8Entity(loadDir, logDir, dbUser, dbPassword, jdbcUrl);
                // For now, throw exception
                throw new UnsupportedOperationException("E8 processor not yet implemented");
            case "E7":
                // Return E7 processor when implemented
                // return new ProcessE7Entity(loadDir, logDir, dbUser, dbPassword, jdbcUrl);
                // For now, throw exception
                throw new UnsupportedOperationException("E7 processor not yet implemented");
            case "EB":
                // Return EB processor when implemented
                // return new ProcessEBEntity(loadDir, logDir, dbUser, dbPassword, jdbcUrl);
                // For now, throw exception
                throw new UnsupportedOperationException("EB processor not yet implemented");
            default:
                throw new IllegalArgumentException("Unknown entity code: " + entity);
        }
    }
}