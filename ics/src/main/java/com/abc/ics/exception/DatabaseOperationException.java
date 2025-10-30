package com.abc.ics.exception;

/**
 * Exception thrown when database operations fail
 */
public class DatabaseOperationException extends IcsZipProcessingException {
    
    public DatabaseOperationException(String message) {
        super(message);
    }
    
    public DatabaseOperationException(String message, Throwable cause) {
        super(message, cause);
    }
}
