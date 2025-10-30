package com.abc.ics.exception;

/**
 * Exception thrown when file validation fails
 */
public class FileValidationException extends IcsZipProcessingException {
    
    public FileValidationException(String message) {
        super(message);
    }
    
    public FileValidationException(String message, Throwable cause) {
        super(message, cause);
    }
}
