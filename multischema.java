// 1. Multiple DataSource Configuration
@Configuration
public class MultiSchemaDataSourceConfig {

    @Primary
    @Bean(name = "entityDataSource")
    @ConfigurationProperties(prefix = "spring.datasource.entity")
    public DataSource entityDataSource() {
        return DataSourceBuilder.create().build();
    }

    @Bean(name = "dialDataSource")
    @ConfigurationProperties(prefix = "spring.datasource.dial")
    public DataSource dialDataSource() {
        return DataSourceBuilder.create().build();
    }

    @Bean(name = "entityJdbcTemplate")
    public JdbcTemplate entityJdbcTemplate(@Qualifier("entityDataSource") DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }

    @Bean(name = "dialJdbcTemplate")
    public JdbcTemplate dialJdbcTemplate(@Qualifier("dialDataSource") DataSource dataSource) {
        return new JdbcTemplate(dataSource);
    }
}

// 2. Cross-Schema Query Service
@Service
@Slf4j
public class CrossSchemaQueryService {

    @Qualifier("entityJdbcTemplate")
    private final JdbcTemplate entityJdbcTemplate;
    
    @Qualifier("dialJdbcTemplate")
    private final JdbcTemplate dialJdbcTemplate;
    
    // Primary datasource for cross-schema queries
    @Qualifier("entityJdbcTemplate")
    private final JdbcTemplate primaryJdbcTemplate;

    public CrossSchemaQueryService(
            @Qualifier("entityJdbcTemplate") JdbcTemplate entityJdbcTemplate,
            @Qualifier("dialJdbcTemplate") JdbcTemplate dialJdbcTemplate,
            @Qualifier("entityJdbcTemplate") JdbcTemplate primaryJdbcTemplate) {
        this.entityJdbcTemplate = entityJdbcTemplate;
        this.dialJdbcTemplate = dialJdbcTemplate;
        this.primaryJdbcTemplate = primaryJdbcTemplate;
    }

    /**
     * Execute cross-schema query using schema-qualified table names
     */
    public List<Map<String, Object>> executeCrossSchemaQuery(String sql, Object... params) {
        try {
            log.info("Executing cross-schema query: {}", sql);
            return primaryJdbcTemplate.queryForList(sql, params);
        } catch (Exception e) {
            log.error("Error executing cross-schema query: {}", e.getMessage());
            throw new RuntimeException("Failed to execute cross-schema query", e);
        }
    }

    /**
     * Execute query on specific schema
     */
    public List<Map<String, Object>> executeEntityQuery(String sql, Object... params) {
        return entityJdbcTemplate.queryForList(sql, params);
    }

    public List<Map<String, Object>> executeDialQuery(String sql, Object... params) {
        return dialJdbcTemplate.queryForList(sql, params);
    }

    /**
     * Execute cross-schema query with custom row mapper
     */
    public <T> List<T> executeCrossSchemaQuery(String sql, RowMapper<T> rowMapper, Object... params) {
        try {
            return primaryJdbcTemplate.query(sql, rowMapper, params);
        } catch (Exception e) {
            log.error("Error executing cross-schema query with mapper: {}", e.getMessage());
            throw new RuntimeException("Failed to execute cross-schema query", e);
        }
    }
}

// 3. Schema-Aware Query Builder
@Component
public class SchemaAwareQueryBuilder {

    @Value("${app.database.entity-schema:ENTITYDEV}")
    private String entitySchema;

    @Value("${app.database.dial-schema:DIALDEV}")
    private String dialSchema;

    /**
     * Build query with proper schema qualification
     */
    public String buildCrossSchemaQuery(String baseQuery) {
        return baseQuery
                .replace("${ENTITY_SCHEMA}", entitySchema)
                .replace("${DIAL_SCHEMA}", dialSchema);
    }

    /**
     * Example: Build a cross-schema join query
     */
    public String buildEntityDialJoinQuery() {
        return """
            SELECT e.entity_id, e.entity_name, d.dial_value
            FROM ${ENTITY_SCHEMA}.entities e
            INNER JOIN ${DIAL_SCHEMA}.dial_data d ON e.entity_id = d.entity_id
            WHERE e.active = 1
            """.replace("${ENTITY_SCHEMA}", entitySchema)
               .replace("${DIAL_SCHEMA}", dialSchema);
    }
}

// 4. Transaction Manager for Cross-Schema Operations
@Configuration
@EnableTransactionManagement
public class TransactionConfig {

    @Bean(name = "entityTransactionManager")
    public PlatformTransactionManager entityTransactionManager(
            @Qualifier("entityDataSource") DataSource dataSource) {
        return new DataSourceTransactionManager(dataSource);
    }

    @Bean(name = "dialTransactionManager")
    public PlatformTransactionManager dialTransactionManager(
            @Qualifier("dialDataSource") DataSource dataSource) {
        return new DataSourceTransactionManager(dataSource);
    }

    @Bean(name = "chainedTransactionManager")
    public ChainedTransactionManager chainedTransactionManager(
            @Qualifier("entityTransactionManager") PlatformTransactionManager entityTxManager,
            @Qualifier("dialTransactionManager") PlatformTransactionManager dialTxManager) {
        return new ChainedTransactionManager(entityTxManager, dialTxManager);
    }
}

// 5. ETL Data Service using Cross-Schema Queries
@Service
@Transactional
public class EtlDataService {

    private final CrossSchemaQueryService queryService;
    private final SchemaAwareQueryBuilder queryBuilder;

    public EtlDataService(CrossSchemaQueryService queryService, 
                         SchemaAwareQueryBuilder queryBuilder) {
        this.queryService = queryService;
        this.queryBuilder = queryBuilder;
    }

    /**
     * Example ETL operation across schemas
     */
    public List<EtlDataRecord> extractCrossSchemaData() {
        String query = queryBuilder.buildCrossSchemaQuery("""
            SELECT 
                e.entity_id,
                e.entity_name,
                e.created_date,
                d.dial_code,
                d.dial_value,
                d.last_updated
            FROM ${ENTITY_SCHEMA}.entity_master e
            LEFT JOIN ${DIAL_SCHEMA}.dial_config d ON e.entity_id = d.entity_ref_id
            WHERE e.status = 'ACTIVE'
            AND d.effective_date <= SYSDATE
            ORDER BY e.entity_id
            """);

        return queryService.executeCrossSchemaQuery(query, new EtlDataRecordMapper());
    }

    /**
     * Execute parameterized cross-schema query
     */
    public List<Map<String, Object>> getEntityDialData(String entityType, Date fromDate) {
        String query = queryBuilder.buildCrossSchemaQuery("""
            SELECT e.*, d.*
            FROM ${ENTITY_SCHEMA}.entities e
            INNER JOIN ${DIAL_SCHEMA}.dial_transactions d ON e.id = d.entity_id
            WHERE e.entity_type = ?
            AND d.transaction_date >= ?
            """);

        return queryService.executeCrossSchemaQuery(query, entityType, fromDate);
    }
}

// 6. Custom Row Mapper for ETL Data
public class EtlDataRecordMapper implements RowMapper<EtlDataRecord> {
    
    @Override
    public EtlDataRecord mapRow(ResultSet rs, int rowNum) throws SQLException {
        return EtlDataRecord.builder()
                .entityId(rs.getLong("entity_id"))
                .entityName(rs.getString("entity_name"))
                .createdDate(rs.getTimestamp("created_date").toLocalDateTime())
                .dialCode(rs.getString("dial_code"))
                .dialValue(rs.getString("dial_value"))
                .lastUpdated(rs.getTimestamp("last_updated").toLocalDateTime())
                .build();
    }
}

// 7. Data Transfer Object
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class EtlDataRecord {
    private Long entityId;
    private String entityName;
    private LocalDateTime createdDate;
    private String dialCode;
    private String dialValue;
    private LocalDateTime lastUpdated;
}

// 8. Repository Pattern for Cross-Schema Operations
@Repository
public class CrossSchemaRepository {

    private final CrossSchemaQueryService queryService;
    private final SchemaAwareQueryBuilder queryBuilder;

    public CrossSchemaRepository(CrossSchemaQueryService queryService,
                               SchemaAwareQueryBuilder queryBuilder) {
        this.queryService = queryService;
        this.queryBuilder = queryBuilder;
    }

    public Optional<EtlDataRecord> findByEntityId(Long entityId) {
        String query = queryBuilder.buildCrossSchemaQuery("""
            SELECT e.entity_id, e.entity_name, e.created_date,
                   d.dial_code, d.dial_value, d.last_updated
            FROM ${ENTITY_SCHEMA}.entity_master e
            LEFT JOIN ${DIAL_SCHEMA}.dial_config d ON e.entity_id = d.entity_ref_id
            WHERE e.entity_id = ?
            """);

        List<EtlDataRecord> results = queryService.executeCrossSchemaQuery(
                query, new EtlDataRecordMapper(), entityId);
        
        return results.isEmpty() ? Optional.empty() : Optional.of(results.get(0));
    }

    public List<EtlDataRecord> findEntitiesWithDialData(String status) {
        String query = queryBuilder.buildCrossSchemaQuery("""
            SELECT e.entity_id, e.entity_name, e.created_date,
                   d.dial_code, d.dial_value, d.last_updated
            FROM ${ENTITY_SCHEMA}.entity_master e
            INNER JOIN ${DIAL_SCHEMA}.dial_config d ON e.entity_id = d.entity_ref_id
            WHERE e.status = ?
            ORDER BY e.entity_id
            """);

        return queryService.executeCrossSchemaQuery(query, new EtlDataRecordMapper(), status);
    }
}

// 9. Integration with ETL Job Service
@Service
public class EtlJobDataProcessor {

    private final CrossSchemaRepository repository;
    private final EtlDataService dataService;

    public EtlJobDataProcessor(CrossSchemaRepository repository, EtlDataService dataService) {
        this.repository = repository;
        this.dataService = dataService;
    }

    /**
     * Process data for E3 job type (example)
     */
    public void processE3JobData() {
        log.info("Processing E3 job data across schemas");
        
        List<EtlDataRecord> activeEntities = repository.findEntitiesWithDialData("ACTIVE");
        
        // Process the data
        activeEntities.forEach(record -> {
            // Transform and load logic here
            log.debug("Processing entity: {} with dial code: {}", 
                     record.getEntityName(), record.getDialCode());
        });
    }

    /**
     * Extract data for specific date range
     */
    public List<Map<String, Object>> extractDataForDateRange(Date fromDate, Date toDate) {
        return dataService.getEntityDialData("STANDARD", fromDate);
    }
}
