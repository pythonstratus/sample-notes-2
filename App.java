# Server configuration
server.port=8080
server.servlet.context-path=/entity-webservice

# Common logging configuration
logging.level.root=INFO
logging.level.org.springframework=INFO
logging.level.gov.irs.sbse.os.ts.csp.elsentity=DEBUG

# Common CORS configuration
spring.mvc.cors.allowed-origins=*
spring.mvc.cors.allowed-methods=GET,POST,PUT,DELETE,OPTIONS
spring.mvc.cors.allowed-headers=*
spring.mvc.cors.max-age=3600

# Actuator endpoints for monitoring
management.endpoints.web.exposure.include=health,info,metrics
management.endpoint.health.show-details=when-authorized

# Disable auto-configuration to prevent conflicts
spring.autoconfigure.exclude=org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration,springfox.documentation.swagger2.configuration.Swagger2DocumentationConfiguration



# Oracle Data source configuration
spring.datasource.driver-class-name=oracle.jdbc.OracleDriver
spring.datasource.url=jdbc:oracle:thin:****
spring.datasource.username=ENTITYDEV
spring.datasource.password=****

# JPA configuration for Oracle
spring.jpa.database-platform=org.hibernate.dialect.Oracle12cDialect
spring.jpa.hibernate.ddl-auto=none
spring.jpa.show-sql=false
spring.jpa.properties.hibernate.format_sql=true

# Connection pool configuration (HikariCP)
spring.datasource.hikari.connection-timeout=20000
spring.datasource.hikari.minimum-idle=5
spring.datasource.hikari.maximum-pool-size=20
spring.datasource.hikari.idle-timeout=300000
spring.datasource.hikari.max-lifetime=1200000

# Oracle specific optimizations
spring.jpa.properties.hibernate.jdbc.batch_size=30
spring.jpa.properties.hibernate.jdbc.fetch_size=100
spring.jpa.properties.hibernate.order_inserts=true
spring.jpa.properties.hibernate.order_updates=true
spring.jpa.properties.hibernate.batch_versioned_data=true

# Important for entity manager
spring.jpa.generate-ddl=false
spring.jpa.open-in-view=false

# Disable default validation
spring.jpa.properties.hibernate.validator.apply_to_ddl=false

# Fine-tuned logging for database operations
logging.level.org.hibernate.SQL=DEBUG
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE
