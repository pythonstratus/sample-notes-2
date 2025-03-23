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
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.logging.FileHandler;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.logging.SimpleFormatter;
import oracle.jdbc.OracleConnection;
import oracle.jdbc.pool.OracleDataSource;

public class OptimizedDatabaseMigrator {
    private static final Logger LOGGER = Logger.getLogger(OptimizedDatabaseMigrator.class.getName());
    private Properties properties;
    private OracleDataSource sourceDS;
    private OracleDataSource destDS;
    private String timestamp;
    private int threadPoolSize;
    private int batchSize;
    private int fetchSize;
    private Properties sourceConnProps = new Properties();
    private Properties destConnProps = new Properties();

    public static void main(String[] args) {
        OptimizedDatabaseMigrator migrator = new OptimizedDatabaseMigrator();
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
        
        // Initialize performance parameters
        threadPoolSize = Integer.parseInt(properties.getProperty("parallel.threads", "4"));
        batchSize = Integer.parseInt(properties.getProperty("batch.size", "10000"));
        fetchSize = Integer.parseInt(properties.getProperty("fetch.size", "50000"));
        
        LOGGER.info("Using thread pool size: " + threadPoolSize);
        LOGGER.info("Using batch size: " + batchSize);
        LOGGER.info("Using fetch size: " + fetchSize);
        
        // Configure connection properties for better performance
        sourceConnProps.setProperty(OracleConnection.CONNECTION_PROPERTY_THIN_NET_CHECKSUM_TYPES, "");
        sourceConnProps.setProperty(OracleConnection.CONNECTION_PROPERTY_THIN_NET_ENCRYPTION_TYPES, "");
        sourceConnProps.setProperty(OracleConnection.CONNECTION_PROPERTY_DEFAULT_ROW_PREFETCH, String.valueOf(fetchSize));
        
        destConnProps.setProperty(OracleConnection.CONNECTION_PROPERTY_THIN_NET_CHECKSUM_TYPES, "");
        destConnProps.setProperty(OracleConnection.CONNECTION_PROPERTY_THIN_NET_ENCRYPTION_TYPES, "");
        
        LOGGER.info("Initializing database connections");
        
        // Connect to source database using connection pooling
        sourceDS = new OracleDataSource();
        sourceDS.setURL(properties.getProperty("source.db.url"));
        sourceDS.setUser(properties.getProperty("source.db.username"));
        sourceDS.setPassword(properties.getProperty("source.db.password"));
        sourceDS.setConnectionProperties(sourceConnProps);
        sourceDS.setConnectionCachingEnabled(true);
        sourceDS.setImplicitCachingEnabled(true);
        sourceDS.setFastConnectionFailoverEnabled(true);
        
        // Connect to destination database using connection pooling
        destDS = new OracleDataSource();
        destDS.setURL(properties.getProperty("dest.db.url"));
        destDS.setUser(properties.getProperty("dest.db.username"));
        destDS.setPassword(properties.getProperty("dest.db.password"));
        destDS.setConnectionProperties(destConnProps);
        destDS.setConnectionCachingEnabled(true);
        destDS.setImplicitCachingEnabled(true);
        destDS.setFastConnectionFailoverEnabled(true);
        
        // Test connections
        try (Connection srcConn = sourceDS.getConnection();
             Connection destConn = destDS.getConnection()) {
            LOGGER.info("Database connections established successfully");
        }
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
        ExecutorService executor = Executors.newFixedThreadPool(threadPoolSize);
        List<Future<?>> futures = new ArrayList<>();
        
        for (String table : tables) {
            String tableName = table.trim();
            LOGGER.info("Starting migration for table: " + tableName);
            
            // Create destination table first (this is sequential)
            String destinationTableName = tableName + tableSuffix + "_" + timestamp;
            try (Connection sourceConn = sourceDS.getConnection()) {
                createDestinationTable(sourceConn, tableName, destinationTableName);
            } catch (SQLException e) {
                LOGGER.severe("Error creating destination table " + destinationTableName + ": " + e.getMessage());
                throw e;
            }
            
            // Submit the data copy task to the thread pool
            Future<?> future = executor.submit(() -> {
                try {
                    long startTime = System.currentTimeMillis();
                    long rowCount = copyTableData(tableName, destinationTableName);
                    long endTime = System.currentTimeMillis();
                    double seconds = (endTime - startTime) / 1000.0;
                    LOGGER.info(String.format("Table %s migration completed: %d rows in %.2f seconds (%.2f rows/sec)", 
                        tableName, rowCount, seconds, rowCount / seconds));
                } catch (SQLException e) {
                    LOGGER.severe("Error migrating table " + tableName + ": " + e.getMessage());
                    throw new RuntimeException(e);
                }
            });
            
            futures.add(future);
        }
        
        // Wait for all migrations to complete
        for (Future<?> future : futures) {
            try {
                future.get();
            } catch (Exception e) {
                LOGGER.severe("Error in table migration thread: " + e.getMessage());
                executor.shutdownNow();
                throw new SQLException("Migration failed due to thread error", e);
            }
        }
        
        executor.shutdown();
    }
    
    private void executePreAction() throws SQLException {
        String preAction = properties.getProperty("pre.action");
        if (preAction != null && !preAction.trim().isEmpty()) {
            LOGGER.info("Executing pre-action");
            try (Connection destConn = destDS.getConnection();
                 Statement stmt = destConn.createStatement()) {
                stmt.execute(preAction);
                LOGGER.info("Pre-action completed");
            }
        }
    }

    private void executePostAction() throws SQLException {
        String postAction = properties.getProperty("post.action");
        if (postAction != null && !postAction.trim().isEmpty()) {
            LOGGER.info("Executing post-action");
            try (Connection destConn = destDS.getConnection();
                 Statement stmt = destConn.createStatement()) {
                stmt.execute(postAction);
                LOGGER.info("Post-action completed");
            }
        }
    }

    private void createDestinationTable(Connection sourceConn, String sourceTableName, String destTableName) throws SQLException {
        LOGGER.info("Creating destination table: " + destTableName);
        
        // Get source table structure
        StringBuilder createTableSQL = new StringBuilder("CREATE TABLE " + destTableName + " (");
        
        try (Statement stmt = sourceConn.createStatement();
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
            
            // Enable parallel DDL if specified
            boolean enableParallelDDL = Boolean.parseBoolean(properties.getProperty("enable.parallel.ddl", "true"));
            if (enableParallelDDL) {
                createTableSQL.append(" PARALLEL");
            }
            
            // Create the table in destination database
            try (Connection destConn = destDS.getConnection();
                 Statement destStmt = destConn.createStatement()) {
                destStmt.execute(createTableSQL.toString());
                
                // Create a direct path hint if supported
                if (enableParallelDDL) {
                    try {
                        // Add some common helpful hints for large tables
                        destStmt.execute("ALTER TABLE " + destTableName + " NOLOGGING");
                    } catch (SQLException e) {
                        // Just log and continue if this fails
                        LOGGER.warning("Could not set NOLOGGING on destination table: " + e.getMessage());
                    }
                }
                
                LOGGER.info("Destination table created successfully: " + destTableName);
            }
        }
    }

    private long copyTableData(String sourceTableName, String destTableName) throws SQLException {
        LOGGER.info("Copying data from " + sourceTableName + " to " + destTableName);
        
        // Get column information upfront
        List<String> columnNames = new ArrayList<>();
        List<Integer> columnTypes = new ArrayList<>();
        
        try (Connection srcConn = sourceDS.getConnection();
             Statement stmt = srcConn.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT * FROM " + sourceTableName + " WHERE 1=0")) {
            
            ResultSetMetaData metaData = rs.getMetaData();
            int columnCount = metaData.getColumnCount();
            
            for (int i = 1; i <= columnCount; i++) {
                columnNames.add(metaData.getColumnName(i));
                columnTypes.add(metaData.getColumnType(i));
            }
        }
        
        // Prepare the SQL statements
        StringBuilder insertSQL = new StringBuilder("INSERT /*+ APPEND_VALUES */ INTO " + destTableName + " (");
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
        
        // Determine if we should use parallel query for fetching
        boolean useParallelQuery = Boolean.parseBoolean(properties.getProperty("enable.parallel.query", "true"));
        String parallelHint = useParallelQuery ? "/*+ PARALLEL(t, 4) */" : "";
        String selectSQL = "SELECT " + parallelHint + " * FROM " + sourceTableName + " t";
        
        // Check if the source table has an approximate row count
        long approximateRowCount = 0;
        try (Connection srcConn = sourceDS.getConnection();
             Statement stmt = srcConn.createStatement();
             ResultSet rs = stmt.executeQuery("SELECT COUNT(*) FROM " + sourceTableName)) {
            if (rs.next()) {
                approximateRowCount = rs.getLong(1);
            }
        } catch (SQLException e) {
            LOGGER.warning("Could not get row count for " + sourceTableName + ": " + e.getMessage());
        }
        
        if (approximateRowCount > 0) {
            LOGGER.info("Approximate row count for " + sourceTableName + ": " + approximateRowCount);
        }
        
        // Use a progress counter
        final AtomicInteger progressCounter = new AtomicInteger(0);
        long totalRowsCopied = 0;
        
        try (Connection srcConn = sourceDS.getConnection();
             Statement selectStmt = srcConn.createStatement();
             ResultSet sourceData = selectStmt.executeQuery(selectSQL);
             Connection destConn = destDS.getConnection()) {
            
            destConn.setAutoCommit(false);
            
            try (PreparedStatement insertStmt = destConn.prepareStatement(insertSQL.toString())) {
                int rowCount = 0;
                int batchCount = 0;
                long startTime = System.currentTimeMillis();
                long lastLogTime = startTime;
                
                while (sourceData.next()) {
                    for (int i = 1; i <= columnNames.size(); i++) {
                        insertStmt.setObject(i, sourceData.getObject(i));
                    }
                    
                    insertStmt.addBatch();
                    rowCount++;
                    
                    if (rowCount % batchSize == 0) {
                        insertStmt.executeBatch();
                        destConn.commit();
                        batchCount++;
                        
                        // Log progress periodically
                        long currentTime = System.currentTimeMillis();
                        if (currentTime - lastLogTime > 5000) { // Log every 5 seconds
                            double elapsedSeconds = (currentTime - startTime) / 1000.0;
                            double rowsPerSecond = rowCount / elapsedSeconds;
                            
                            if (approximateRowCount > 0) {
                                double percentComplete = (rowCount * 100.0) / approximateRowCount;
                                LOGGER.info(String.format("Table %s: %.2f%% complete (%d/%d rows), %.2f rows/sec", 
                                    sourceTableName, percentComplete, rowCount, approximateRowCount, rowsPerSecond));
                            } else {
                                LOGGER.info(String.format("Table %s: %d rows copied, %.2f rows/sec", 
                                    sourceTableName, rowCount, rowsPerSecond));
                            }
                            
                            lastLogTime = currentTime;
                        }
                    }
                }
                
                // Insert remaining rows
                if (rowCount % batchSize != 0) {
                    insertStmt.executeBatch();
                    destConn.commit();
                }
                
                totalRowsCopied = rowCount;
                LOGGER.info("Data copy completed: " + rowCount + " rows inserted into " + destTableName);
            } catch (SQLException e) {
                destConn.rollback();
                throw e;
            } finally {
                destConn.setAutoCommit(true);
            }
        }
        
        // Gather statistics on the new table if specified
        boolean gatherStats = Boolean.parseBoolean(properties.getProperty("gather.stats", "true"));
        if (gatherStats) {
            try (Connection destConn = destDS.getConnection();
                 Statement stmt = destConn.createStatement()) {
                LOGGER.info("Gathering statistics on " + destTableName);
                stmt.execute("BEGIN DBMS_STATS.GATHER_TABLE_STATS('" + 
                             properties.getProperty("dest.db.username").toUpperCase() + "', '" + 
                             destTableName + "'); END;");
            } catch (SQLException e) {
                LOGGER.warning("Could not gather statistics on " + destTableName + ": " + e.getMessage());
            }
        }
        
        return totalRowsCopied;
    }

    private void cleanup() {
        LOGGER.info("Cleaning up resources");
        
        try {
            if (sourceDS != null) {
                sourceDS.close();
                LOGGER.info("Source connection pool closed");
            }
        } catch (SQLException e) {
            LOGGER.warning("Error closing source connection pool: " + e.getMessage());
        }
        
        try {
            if (destDS != null) {
                destDS.close();
                LOGGER.info("Destination connection pool closed");
            }
        } catch (SQLException e) {
            LOGGER.warning("Error closing destination connection pool: " + e.getMessage());
        }
        
        LOGGER.info("Database migration process completed");
    }
}
