package com.abc.ics.exception;

/**
 * Base exception for ICS Zip Processing application
 */
public class IcsZipProcessingException extends RuntimeException {
    
    public IcsZipProcessingException(String message) {
        super(message);
    }
    
    public IcsZipProcessingException(String message, Throwable cause) {
        super(message, cause);
    }
}
