# Oracle Database Table Migration Tool

A Java-based tool for migrating tables between Oracle databases with separate pre and post table lists.

## Features

- **Database Connection**: Connect to source and destination Oracle databases using configurable connection parameters
- **Pre and Post Tables**: Copy tables with appropriate suffixes for pre and post-migration comparison
- **Timestamped Tables**: Automatically append timestamps to all table names for clear identification
- **Pre/Post Actions**: Execute configurable SQL commands before and after the migration process
- **Batch Processing**: Transfer data in configurable batch sizes for performance optimization
- **Flexible Execution Modes**: Run pre-tables or post-tables migrations independently or together
- **Comprehensive Logging**: Detailed logging of all migration steps and potential errors

## Prerequisites

- Java 11 or higher
- Maven 3.6.0 or higher
- Access to Oracle databases (source and destination)
- Oracle JDBC driver (included as a Maven dependency)
- dest.db.url=jdbc:oracle:thin:@(DESCRIPTION=(ADDRESS=(PROTOCOL=TCP)(HOST=xlmtb-dev2-scan1.mcc.abc.com)(PORT=1521))(CONNECT_DATA=(SERVICE_NAME=ALSDEVSVC.dev.abc.com)))

## Installation

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/oracle-db-migrator.git
   cd oracle-db-migrator
   ```

2. Build the project using Maven:
   ```
   mvn clean package
   ```

This will generate a JAR file in the `target` directory named `oracle-db-migrator-1.0.0.jar`.

## Configuration

Create an `application.properties` file in the same directory as the JAR file with the following configuration:

```properties
# Source Database Configuration
source.db.url=jdbc:oracle:thin:@//source-server:1521/orcl
source.db.username=source_user
source.db.password=source_password

# Destination Database Configuration
dest.db.url=jdbc:oracle:thin:@//destination-server:1521/orcl
dest.db.username=dest_user
dest.db.password=dest_password

# Tables to Copy (comma-separated lists)
pre.tables=EMPLOYEES,DEPARTMENTS,CUSTOMER_MASTER,PRODUCT_CATALOG,INVENTORY_STATUS
post.tables=ORDER_HEADER,ORDER_DETAIL,SHIPPING_LOG,SALARY_HISTORY,PROJECTS

# SQL Actions (optional)
pre.action=INSERT INTO MIGRATION_LOG VALUES (SYSDATE, 'Starting table migrations')
post.action=INSERT INTO MIGRATION_LOG VALUES (SYSDATE, 'Completed table migrations')

# Batch Size for Data Transfer
batch.size=1000

# Connection Pool Configuration
connection.pool.size=5
connection.timeout.seconds=30

# Logging Configuration
logging.level=INFO
logging.file=db-migration.log
```

### Configuration Notes:

- **Pre Tables**: Tables listed in `pre.tables` will be copied with the `_pre_[TIMESTAMP]` suffix
- **Post Tables**: Tables listed in `post.tables` will be copied with the `_post_[TIMESTAMP]` suffix
- **Pre/Post Actions**: Optional SQL statements to execute at the beginning and end of the migration process

## Usage

Run the application with one of the following commands:

### Full Migration Process

```
java -jar target/oracle-db-migrator-1.0.0.jar
```

or

```
java -jar target/oracle-db-migrator-1.0.0.jar full
```

This migrates both pre and post tables and executes pre/post actions.

### Pre-Tables Migration Only

```
java -jar target/oracle-db-migrator-1.0.0.jar pre
```

This only migrates tables listed in `pre.tables` with the `_pre_[TIMESTAMP]` suffix.

### Post-Tables Migration Only

```
java -jar target/oracle-db-migrator-1.0.0.jar post
```

This only migrates tables listed in `post.tables` with the `_post_[TIMESTAMP]` suffix.

## Logging

The application logs all activities to both the console and a log file specified in `application.properties`. The default log file is `db-migration.log`.

## Example Table Naming

For a timestamp of `20250322_120130`:

- A pre table `EMPLOYEES` becomes `EMPLOYEES_pre_20250322_120130`
- A post table `ORDER_HEADER` becomes `ORDER_HEADER_post_20250322_120130`

## Example Workflow

A typical usage scenario might look like this:

1. **Setup**: Configure your database connections and table lists in `application.properties`
2. **Pre-Migration Run**: 
   ```
   java -jar target/oracle-db-migrator-1.0.0.jar pre
   ```
   This copies all pre-tables with the `_pre` suffix before making changes to your system

3. **Make System Changes**: Make your changes to the source database or system

4. **Post-Migration Run**: 
   ```
   java -jar target/oracle-db-migrator-1.0.0.jar post
   ```
   This copies all post-tables with the `_post` suffix after your changes

5. **Comparison**: Compare the pre and post tables to analyze the impact of your changes

## Troubleshooting

Common issues and solutions:

- **Connection Failures**: Verify database connection details in `application.properties`
- **Permission Errors**: Ensure database users have appropriate privileges for the operations
- **Memory Issues**: For large tables, increase JVM memory using `-Xmx` parameter, e.g., `java -Xmx2g -jar ...`

## Development

### Project Structure

```
oracle-db-migrator/
├── src/
│   ├── main/
│   │   ├── java/
│   │   │   └── com/
│   │   │       └── example/
│   │   │           └── dbmigration/
│   │   │               └── DatabaseMigrator.java
│   │   └── resources/
│   └── test/
├── pom.xml
├── application.properties
└── README.md
```

### Building from Source

```
mvn clean package
```

## License

[MIT License](LICENSE)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
