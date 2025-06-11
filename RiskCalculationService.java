package com.entitydev.risk;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.*;
import java.util.concurrent.*;
import java.util.stream.Collectors;

@Service
public class RiskCalculationService {
    
    private static final Logger logger = LoggerFactory.getLogger(RiskCalculationService.class);
    
    @Autowired
    private JdbcTemplate jdbcTemplate;
    
    @Autowired
    private ExecutorService executorService;
    
    // Constants matching the hardcoded values from the procedure
    private static final Set<String> SPEC_PRJ_CODES = new HashSet<>(Arrays.asList(
        "0019", "0020", "0041", "0042", "0043", "0053", "0080", "0090",
        "0108", "0117", "0126", "0127", "0130", "0132", "0134", "0159"
        // ... add all the other codes
    ));
    
    private static final Set<String> MFT_CODES = new HashSet<>(Arrays.asList(
        "01", "03", "08", "09", "11", "12", "14", "16", "17", "72"
        // ... add all the other codes
    ));
    
    // Entity classes matching cursor data
    public static class EntmodRecord {
        private Long sid;
        private Long tin;
        private Integer fs;
        private Integer tt;
        private Double sumbal;
        private Double tfbal;
        private Double tdiCredit;
        private Integer oicAccYr;
        private Double tfIraSum;
        private Integer tfModCnt;
        private Date extractDt;
        private String subcd;
        private Integer baserank;
        private String fatca;
        private Integer irsemp;
        private String address;
        // getters and setters
    }
    
    public static class EntmodDetailRecord {
        private String mft;
        private String period;
        private Integer salcode;
        private Integer type;
        private Integer age;
        private Double balance;
        private Integer lra;
        private Integer specPrjCd;
        private Integer civpcd;
        private String status;
        private Date rtndt;
        // getters and setters
    }
    
    @Transactional
    public void calculateRisk(Integer area) {
        logger.info("Starting risk calculation for area: {}", area);
        long startTime = System.currentTimeMillis();
        
        try {
            // Main cursor query - entcur1
            String mainQuery = """
                SELECT DISTINCT
                    tinsid, tin, tinsfs, tintt, sumbal, tfbal, tdi_credit,
                    oic_acc_yr, tf_ira_sum, tf_mod_cnt, extractdt, subcd,
                    baserank, fatca, irsemp, address
                FROM entmod
                WHERE emodsid = ?
                    AND status = 'O'
                    AND tinsid IN (
                        SELECT DISTINCT e.tinsid
                        FROM trantrail t
                        WHERE t.tinsid = e.tinsid
                            AND t.status = 'O'
                            AND DECODE(t.segind,'A',1,'I',1,'C',1,0) = 1
                    )
                    AND eomodsid = ?
                    AND mft IN (
                        SELECT DISTINCT mft
                        FROM entmod
                        WHERE decode(type,'2',1,'F',1,'G',1,'I',1,0) = 1
                            AND e.tinsid = emodsid
                            AND mft IN (01,03,08,09,11,12,14,16,17,38,31)
                    )
                """;
            
            List<EntmodRecord> mainRecords = jdbcTemplate.query(
                mainQuery, 
                new Object[]{area, area},
                new EntmodRecordMapper()
            );
            
            logger.info("Found {} records to process for area {}", mainRecords.size(), area);
            
            // Process in parallel batches
            int batchSize = 1000;
            List<CompletableFuture<Void>> futures = new ArrayList<>();
            
            for (int i = 0; i < mainRecords.size(); i += batchSize) {
                int endIndex = Math.min(i + batchSize, mainRecords.size());
                List<EntmodRecord> batch = mainRecords.subList(i, endIndex);
                
                CompletableFuture<Void> future = CompletableFuture.runAsync(() -> 
                    processBatch(batch, area), executorService
                );
                futures.add(future);
            }
            
            // Wait for all batches to complete
            CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();
            
            long endTime = System.currentTimeMillis();
            logger.info("Risk calculation completed for area {} in {} seconds", 
                area, (endTime - startTime) / 1000);
            
        } catch (Exception e) {
            logger.error("Error processing risk calculation for area " + area, e);
            throw new RuntimeException("Risk calculation failed for area " + area, e);
        }
    }
    
    private void processBatch(List<EntmodRecord> batch, Integer area) {
        for (EntmodRecord record : batch) {
            try {
                processIndividualRecord(record, area);
            } catch (Exception e) {
                logger.error("Error processing record: " + record.getSid(), e);
            }
        }
    }
    
    private void processIndividualRecord(EntmodRecord record, Integer area) {
        Integer rank = 0;
        
        // Check IDA and IDL conditions
        if (area == 35) {
            Integer estateTax = getEstateTaxCount(record.getTin());
            
            // Implement the complex business rules
            if (record.getFs() == 2 && 
                Arrays.asList(01,03,08,09,11,12,14,16,17,72).contains(record.getMft()) &&
                record.getAge() < 2) {
                
                rank = calculateRankBasedOnConditions(record, estateTax);
            }
        }
        
        // Update the risk value
        if (rank > 0) {
            updateRisk(record.getSid(), rank);
        }
    }
    
    private Integer calculateRankBasedOnConditions(EntmodRecord record, Integer estateTax) {
        // This is where all the complex IF-THEN-ELSE logic would go
        // Converting from the PL/SQL conditions
        
        // Example of one condition block:
        if (record.getRectype() == 5 && record.getSumbal() >= 168546) {
            if (SPEC_PRJ_CODES.contains(String.valueOf(record.getSpecPrjCd()))) {
                return 103;
            }
        }
        
        // SP377 Update threshold rules
        if (record.getRectype() == 5 && record.getSumbal() >= 168546 && 
            record.getFatca().equals("1")) {
            return 103;
        }
        
        // Continue with all other conditions...
        // This would be hundreds of lines matching the original logic
        
        return 0;
    }
    
    private Integer getEstateTaxCount(Long tin) {
        String query = """
            SELECT COUNT(*)
            FROM trantrail t, entmod e
            WHERE t.tinsid = ? 
                AND t.status = 'O'
                AND e.tinsid = t.tinsid
                AND e.emodsid = t.emodsid
                AND e.mft IN (01,03,08,09,11,12,14,16,17,38,31)
            """;
        
        return jdbcTemplate.queryForObject(query, Integer.class, tin);
    }
    
    private void updateRisk(Long sid, Integer risk) {
        String updateQuery = "UPDATE ent SET risk = ? WHERE tinsid = ?";
        jdbcTemplate.update(updateQuery, risk, sid);
    }
    
    // RowMapper implementations
    private static class EntmodRecordMapper implements RowMapper<EntmodRecord> {
        @Override
        public EntmodRecord mapRow(ResultSet rs, int rowNum) throws SQLException {
            EntmodRecord record = new EntmodRecord();
            record.setSid(rs.getLong("tinsid"));
            record.setTin(rs.getLong("tin"));
            record.setFs(rs.getInt("tinsfs"));
            record.setTt(rs.getInt("tintt"));
            record.setSumbal(rs.getDouble("sumbal"));
            record.setTfbal(rs.getDouble("tfbal"));
            record.setTdiCredit(rs.getDouble("tdi_credit"));
            record.setOicAccYr(rs.getInt("oic_acc_yr"));
            record.setTfIraSum(rs.getDouble("tf_ira_sum"));
            record.setTfModCnt(rs.getInt("tf_mod_cnt"));
            record.setExtractDt(rs.getDate("extractdt"));
            record.setSubcd(rs.getString("subcd"));
            record.setBaserank(rs.getInt("baserank"));
            record.setFatca(rs.getString("fatca"));
            record.setIrsemp(rs.getInt("irsemp"));
            record.setAddress(rs.getString("address"));
            return record;
        }
    }
    
    // Configuration for parallel processing
    @Configuration
    public class RiskCalcConfig {
        
        @Bean
        public ExecutorService riskCalcExecutorService() {
            return Executors.newFixedThreadPool(
                Runtime.getRuntime().availableProcessors() * 2
            );
        }
    }
}
