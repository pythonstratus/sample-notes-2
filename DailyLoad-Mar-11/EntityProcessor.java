/**
 * EntityProcessor - Interface for all entity processors
 * This defines the common methods that all entity processors must implement
 */
public interface EntityProcessor {
    
    /**
     * Process the entity data file
     * 
     * @return true if processing was successful, false otherwise
     * @throws Exception if any error occurs during processing
     */
    boolean process() throws Exception;
    
    /**
     * Get the entity code (E5, E3, E8, E7, EB)
     * 
     * @return the entity code
     */
    String getEntityCode();
    
    /**
     * Get the output file path
     * 
     * @return the path to the output file
     */
    String getOutputFilePath();
}