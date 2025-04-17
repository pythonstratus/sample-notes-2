package com.abc.sbse.os.ts.csp.alsentity.ale.repository;

import java.time.LocalDate;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import org.springframework.transaction.annotation.Transactional;

import com.abc.sbse.os.ts.csp.alsentity.ale.model.LogLoad;

@Repository
public interface LogLoadRepository extends JpaRepository<LogLoad, Long> {

    @Query("SELECT MAX(l.extrDt) FROM LogLoad l WHERE l.loadName = :loadname")
    LocalDate findMaxExtrDtByLoadname(@Param("loadname") String loadname);
    
    @Query("SELECT l.holiday FROM LogLoad l WHERE l.loadDate = :today")
    String findHoliday(@Param("today") String today);
    
    @Modifying
    @Transactional
    @Query(value = "CALL PROCESS_HOLIDAY(:holiday)", nativeQuery = true)
    void processHoliday(@Param("holiday") String holiday);
    
    @Modifying
    @Transactional
    @Query(value = "CALL PREPARE_LOGLOAD(:today)", nativeQuery = true)
    void prepareLogload(@Param("today") String today);
    
    @Query("SELECT l.prevE3 FROM LogLoad l")
    String getPrevE3();
    
    /**
     * Save a log entry to the LOGLOAD table
     * 
     * @param loadName The job code (e.g., E5, E3, etc.)
     * @param extrDt The extract date
     * @param loadDt The load date (current date)
     * @param unix The username
     * @param numRec Number of records processed
     */
    @Modifying
    @Transactional
    @Query(value = "INSERT INTO LOGLOAD (LOADNAME, EXTRDT, LOADDT, UNIX, NUMREC) VALUES (:loadName, :extrDt, :loadDt, :unix, :numRec)", nativeQuery = true)
    void saveLogEntry(
        @Param("loadName") String loadName,
        @Param("extrDt") String extrDt,
        @Param("loadDt") String loadDt,
        @Param("unix") String unix,
        @Param("numRec") int numRec
    );
}
