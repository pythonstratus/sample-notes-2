package com.example.dbmigration;

import java.io.FileInputStream;
import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Date;
import java.util.List;
import java.util.Properties;
import java.util.logging.FileHandler;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.logging.SimpleFormatter;

public class DatabaseMigrator {
    private static final Logger LOGGER = Logger.getLogger(DatabaseMigrator.class.getName());
    private Properties properties;
    private Connection sourceConnection;
    private Connection destConnection;
    private String timestamp;

    public static void main(String[] args) {
        DatabaseMigrator migrator = new DatabaseMigrator();
        try {
            migrator.initialize();
            
            // Process command line arguments
            if (args.length > 0) {
                String mode = args[0].toLowerCase();
                switch (mode) {
                    case "pre":
                        LOGGER.info("Running pre-tables migration");
                        migrator.executePreAction();
                        migrator.migratePreTables();
                        break;
                    case "post":
                        LOGGER.info("Running post-tables migration");
                        migrator.migratePostTables();
                        migrator.executePostAction();
                        break;
                    case "full":
                        LOGGER.info("Running full migration process");
                        migrator.executePreAction();
                        migrator.migratePreTables();
                        migrator.migratePostTables();
                        migrator.executePostAction();
                        break;
                    default:
                        LOGGER.warning("Unknown mode: " + mode + ". Valid modes are: pre, post, full");
                        System.out.println("Usage: java -jar oracle-db-migrator.jar [mode]");
                        System.out.println("Available modes:");
                        System.out.println("  pre  - Migrate only pre-tables with 'pre' suffix");
                        System.out.println("  post - Migrate only post-tables with 'post' suffix");
                        System.out.println("  full - Perform complete migration (both pre and post tables)");
                }
            } else {
                // Default behavior - perform full migration
                LOGGER.info("No mode specified, running full migration process");
                migrator.executePreAction();
                migrator.migratePreTables();
                migrator.migratePostTables();
                migrator.executePostAction();
            }
        } catch (Exception e) {
            LOGGER.severe("Migration failed: " + e.getMessage());
            e.printStackTrace();
        } finally {
            migrator.cleanup();
        }
    }

    private void initialize() throws IOException, SQLException {
        // Setup logging
        properties = new Properties();
        try (FileInputStream fis = new FileInputStream("application.properties")) {
            properties.load(fis);
        }
        
        configureLogger();
        
        // Generate timestamp for table naming
        SimpleDateFormat dateFormat = new SimpleDateFormat("yyyyMMdd_HHmmss");
        timestamp = dateFormat.format(new Date());
        
        LOGGER.info("Initializing database connections");
        
        // Connect to source database
        sourceConnection = DriverManager.getConnection(
                properties.getProperty("source.db.url"),
                properties.getProperty("source.db.username"),
                properties.getProperty("source.db.password"));
        
        // Connect to destination database
        destConnection = DriverManager.getConnection(
                properties.getProperty("dest.db.url"),
                properties.getProperty("dest.db.username"),
                properties.getProperty("dest.db.password"));
        
        LOGGER.info("Database connections established successfully");
    }
    
    private void configureLogger() throws IOException {
        Level logLevel = Level.parse(properties.getProperty("logging.level", "INFO"));
        LOGGER.setLevel(logLevel);
        
        String logFile = properties.getProperty("logging.file", "db-migration.log");
        FileHandler fileHandler = new FileHandler(logFile, true);
        fileHandler.setFormatter(new SimpleFormatter());
        LOGGER.addHandler(fileHandler);
    }
    
    private void migratePreTables() throws SQLException {
        migrateTables("pre.tables", "_pre");
    }
    
    private void migratePostTables() throws SQLException {
        migrateTables("post.tables", "_post");
    }
    
    private void migrateTables(String tablePropertyKey, String tableSuffix) throws SQLException {
        String tablesProperty = properties.getProperty(tablePropertyKey);
        if (tablesProperty == null || tablesProperty.trim().isEmpty()) {
            LOGGER.warning("No tables specified for " + tablePropertyKey);
            return;
        }
        
        List<String> tables = Arrays.asList(tablesProperty.split(","));
        int batchSize = Integer.parseInt(properties.getProperty("batch.size", "1000"));
        
        for (String table : tables) {
            String tableName = table.trim();
            LOGGER.info("Starting migration for table: " + tableName);
            
            try {
                // Get table structure and create destination table with appropriate suffix
                String destinationTableName = tableName + tableSuffix + "_" + timestamp;
                createDestinationTable(tableName, destinationTableName);
                
                // Copy data from source to destination
                copyTableData(tableName, destinationTableName, batchSize);
                
                LOGGER.info("Migration completed for table: " + tableName);
            } catch (SQLException e) {
                LOGGER.severe("Error migrating table " + tableName + ": " + e.getMessage());
                throw e; // Re-throwing to handle in main
            }
        }
    }
    
    private void executePreAction() throws SQLException {
        String preAction = properties.getProperty("pre.action");
        if (preAction != null && !preAction.trim().isEmpty()) {
            LOGGER.info("Executing pre-action");
            try (Statement stmt = destConnection.createStatement()) {
                stmt.execute(preAction);
                LOGGER.info("Pre-action completed");
            }
        }
    }

    private void executePostAction() throws SQLException {
        String postAction = properties.getProperty("post.action");
        if (postAction != null && !postAction.trim().isEmpty()) {
            LOGGER.info("Executing post-action");
            try (Statement stmt = destConnection.createStatement()) {
                stmt.execute(postAction);
                LOGGER.info("Post-action completed");
            }
        }
    }

    private void createDestinationTable(String sourceTableName, String destTableName) throws SQLException {
        LOGGER.info("Creating destination table: " + destTableName);
        
        // Get source table structure
        StringBuilder createTableSQL = new StringBuilder("CREATE TABLE " + destTableName + " (");
        
        try (Statement stmt = sourceConnection.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT * FROM " + sourceTableName + " WHERE 1=0")) {
            
            ResultSetMetaData metaData = rs.getMetaData();
            int columnCount = metaData.getColumnCount();
            
            // Build column definitions
            for (int i = 1; i <= columnCount; i++) {
                String columnName = metaData.getColumnName(i);
                String columnType = metaData.getColumnTypeName(i);
                int columnSize = metaData.getPrecision(i);
                int scale = metaData.getScale(i);
                
                createTableSQL.append(columnName).append(" ").append(columnType);
                
                // Add size for character types
                if (columnType.contains("CHAR") || columnType.contains("VARCHAR")) {
                    createTableSQL.append("(").append(columnSize).append(")");
                } 
                // Add precision and scale for numeric types
                else if (columnType.contains("NUMBER") || columnType.contains("DECIMAL")) {
                    if (scale > 0) {
                        createTableSQL.append("(").append(columnSize).append(",").append(scale).append(")");
                    } else if (columnSize > 0) {
                        createTableSQL.append("(").append(columnSize).append(")");
                    }
                }
                
                if (i < columnCount) {
                    createTableSQL.append(", ");
                }
            }
            
            createTableSQL.append(")");
            
            // Create the table in destination database
            try (Statement destStmt = destConnection.createStatement()) {
                destStmt.execute(createTableSQL.toString());
                LOGGER.info("Destination table created successfully: " + destTableName);
            }
        }
    }

    private void copyTableData(String sourceTableName, String destTableName, int batchSize) throws SQLException {
        LOGGER.info("Copying data from " + sourceTableName + " to " + destTableName);
        
        // Get column names
        List<String> columnNames = new ArrayList<>();
        try (Statement stmt = sourceConnection.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT * FROM " + sourceTableName + " WHERE 1=0")) {
            
            ResultSetMetaData metaData = rs.getMetaData();
            int columnCount = metaData.getColumnCount();
            
            for (int i = 1; i <= columnCount; i++) {
                columnNames.add(metaData.getColumnName(i));
            }
        }
        
        // Prepare insert statement with placeholders
        StringBuilder insertSQL = new StringBuilder("INSERT INTO " + destTableName + " (");
        StringBuilder placeholders = new StringBuilder();
        
        for (int i = 0; i < columnNames.size(); i++) {
            insertSQL.append(columnNames.get(i));
            placeholders.append("?");
            
            if (i < columnNames.size() - 1) {
                insertSQL.append(", ");
                placeholders.append(", ");
            }
        }
        
        insertSQL.append(") VALUES (").append(placeholders).append(")");
        
        // Fetch data from source and insert into destination
        String selectSQL = "SELECT * FROM " + sourceTableName;
        destConnection.setAutoCommit(false);
        
        try (Statement selectStmt = sourceConnection.createStatement();
             ResultSet sourceData = selectStmt.executeQuery(selectSQL);
             PreparedStatement insertStmt = destConnection.prepareStatement(insertSQL.toString())) {
            
            int rowCount = 0;
            int batchCount = 0;
            
            while (sourceData.next()) {
                for (int i = 1; i <= columnNames.size(); i++) {
                    insertStmt.setObject(i, sourceData.getObject(i));
                }
                
                insertStmt.addBatch();
                rowCount++;
                
                if (rowCount % batchSize == 0) {
                    insertStmt.executeBatch();
                    destConnection.commit();
                    batchCount++;
                    LOGGER.info("Inserted batch " + batchCount + " (" + rowCount + " rows so far)");
                }
            }
            
            // Insert remaining rows
            if (rowCount % batchSize != 0) {
                insertStmt.executeBatch();
                destConnection.commit();
            }
            
            LOGGER.info("Data copy completed: " + rowCount + " rows inserted into " + destTableName);
        } catch (SQLException e) {
            destConnection.rollback();
            throw e;
        } finally {
            destConnection.setAutoCommit(true);
        }
    }

    private void cleanup() {
        LOGGER.info("Cleaning up resources");
        
        try {
            if (sourceConnection != null && !sourceConnection.isClosed()) {
                sourceConnection.close();
                LOGGER.info("Source connection closed");
            }
        } catch (SQLException e) {
            LOGGER.warning("Error closing source connection: " + e.getMessage());
        }
        
        try {
            if (destConnection != null && !destConnection.isClosed()) {
                destConnection.close();
                LOGGER.info("Destination connection closed");
            }
        } catch (SQLException e) {
            LOGGER.warning("Error closing destination connection: " + e.getMessage());
        }
        
        LOGGER.info("Database migration process completed");
    }
}