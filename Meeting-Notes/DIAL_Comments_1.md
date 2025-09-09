DataSourceConfig.java

/**
 * Configuration class for setting up multiple DataSource beans in a Spring Boot application.
 * This class defines primary and secondary data sources for dial, entity, and script operations,
 * along with their corresponding JdbcTemplate beans.
 * 
 * <p>This configuration class provides the following DataSource beans:
 * <ul>
 * <li><strong>primaryDataSource</strong> - Primary data source using "dial.datasource" properties</li>
 * <li><strong>dialrptDataSource</strong> - Dial report data source using "dialrpt.datasource" properties</li>
 * <li><strong>entityDataSource</strong> - Entity data source using "entity.datasource" properties</li>
 * <li><strong>alscriptDataSource</strong> - Script data source using "alscript.datasource" properties</li>
 * </ul>
 * 
 * <p>Corresponding JdbcTemplate beans are also configured:
 * <ul>
 * <li><strong>primaryJdbcTemplate</strong> - Primary JdbcTemplate (marked as @Primary)</li>
 * <li><strong>dialrptJdbcTemplate</strong> - JdbcTemplate for dial report operations</li>
 * <li><strong>entityJdbcTemplate</strong> - JdbcTemplate for entity operations</li>
 * <li><strong>alscriptJdbcTemplate</strong> - JdbcTemplate for script operations</li>
 * </ul>
 * 
 * <p><strong>Key Methods:</strong>
 * <ul>
 * <li>{@code printDataSourceProperties()} - Utility method to print all Spring DataSource properties for debugging</li>
 * <li>{@code primaryDataSource()} - Creates primary DataSource bean with "dial.datasource" prefix</li>
 * <li>{@code dialrptDataSource()} - Creates dial report DataSource bean with "dialrpt.datasource" prefix</li>
 * <li>{@code alsDataSource()} - Creates entity DataSource bean with "entity.datasource" prefix</li>
 * <li>{@code alscriptDataSource()} - Creates script DataSource bean with "alscript.datasource" prefix</li>
 * <li>{@code primaryJdbcTemplate()} - Creates primary JdbcTemplate using primaryDataSource</li>
 * <li>{@code dialrptJdbcTemplate()} - Creates JdbcTemplate using dialrptDataSource</li>
 * <li>{@code alsJdbcTemplate()} - Creates JdbcTemplate using entityDataSource</li>
 * <li>{@code alscriptJdbcTemplate()} - Creates JdbcTemplate using alscriptDataSource</li>
 * </ul>
 * 
 * <p><strong>Configuration Properties:</strong>
 * This class expects the following property prefixes to be configured in application properties:
 * <ul>
 * <li>dial.datasource.* - Primary database configuration</li>
 * <li>dialrpt.datasource.* - Dial report database configuration</li>
 * <li>entity.datasource.* - Entity database configuration</li>
 * <li>alscript.datasource.* - Script database configuration</li>
 * </ul>
 * 
 * @author [Your Name]
 * @version 1.0
 * @since [Date]
 * @see org.springframework.context.annotation.Configuration
 * @see org.springframework.context.annotation.Bean
 * @see org.springframework.context.annotation.Primary
 * @see org.springframework.boot.context.properties.ConfigurationProperties
 * @see javax.sql.DataSource
 * @see org.springframework.jdbc.core.JdbcTemplate
 */
@Configuration
public class DataSourceConfig {



DialEnvironmentConfig.java

/**
 * Configuration class that manages environment setup and initialization for the DIAL application.
 * This class replaces the traditional DIAL.path shell script and handles environment variable 
 * configuration, directory creation, and path management for DIAL operations.
 * 
 * <p>This configuration class provides the following key functionality:
 * <ul>
 * <li><strong>Environment Initialization</strong> - Sets up all required environment variables and paths</li>
 * <li><strong>Directory Management</strong> - Creates necessary directories if they don't exist</li>
 * <li><strong>Database Configuration</strong> - Configures Oracle database settings and connection parameters</li>
 * <li><strong>File Path Management</strong> - Sets up processing areas and file locations</li>
 * <li><strong>Executor Services</strong> - Provides thread pool executors for concurrent operations</li>
 * </ul>
 * 
 * <p><strong>Environment Variables Configured:</strong>
 * <ul>
 * <li><strong>Database Settings:</strong> Oracle home, SID, term, records count, library paths</li>
 * <li><strong>Processing Areas:</strong> Multiple numbered processing areas (11,12,13,14,15,21,22,23,24,25,26,27,35)</li>
 * <li><strong>File Paths:</strong> Data file paths for entity, MOD, SUM, and SCO operations</li>
 * <li><strong>Directory Paths:</strong> AREADIR, CONSOLDIR, EXP_DIR, RAM_DIR, RAM_BKUP, XFILES, LOADSTAGE, DIAL</li>
 * <li><strong>TDA/TDI Settings:</strong> Time-based processing configurations</li>
 * </ul>
 * 
 * <p><strong>Key Configuration Properties Used:</strong>
 * <ul>
 * <li>dial.als.base.dir - Base directory for ALS operations</li>
 * <li>dial.combo.records.count - Record count for combo operations</li>
 * <li>dial.oracle.home - Oracle database home directory</li>
 * <li>dial.oracle.sid - Oracle database SID</li>
 * <li>dial.oracle.term - Oracle terminal setting</li>
 * <li>dial.path.backup.enabled - Flag to enable/disable backup functionality</li>
 * <li>dial.file.processing.areas - Comma-separated list of processing area numbers</li>
 * </ul>
 * 
 * <p><strong>Bean Methods:</strong>
 * <ul>
 * <li>{@code dialEnvironment()} - Main method that initializes the complete environment map</li>
 * <li>{@code createRequiredDirectories()} - Private utility to create necessary directories</li>
 * <li>{@code comboFileExecutorService()} - Creates executor service for combo file operations</li>
 * <li>{@code dialDatabasePasswordFile()} - Returns path to dial database password file</li>
 * <li>{@code alsDatabasePasswordFile()} - Returns path to ALS database password file</li>
 * <li>{@code processingAreas()} - Returns array of configured processing areas</li>
 * <li>{@code isBackupEnabled()} - Returns backup enabled status</li>
 * </ul>
 * 
 * <p><strong>Directory Structure Created:</strong>
 * The class automatically creates the following directories if they don't exist:
 * AREADIR, CONSOLDIR, EXP_DIR, RAM_DIR, RAM_BKUP, XFILES, LOADSTAGE, DIAL
 * 
 * <p><strong>Thread Pool Configuration:</strong>
 * Provides a fixed thread pool executor service with 5 threads for handling concurrent 
 * combo file operations, qualified as "dialExecutorService".
 * 
 * @author [Your Name]
 * @version 1.0
 * @since [Date]
 * @see org.springframework.context.annotation.Configuration
 * @see org.springframework.context.annotation.Bean
 * @see org.springframework.beans.factory.annotation.Value
 * @see org.springframework.core.env.Environment
 * @see java.util.concurrent.ExecutorService
 * @see java.nio.file.Path
 */
@Configuration
public class DialEnvironmentConfig {
