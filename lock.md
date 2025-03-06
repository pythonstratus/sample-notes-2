# DailyLoad Application README

## Overview
The DailyLoad application is a Java implementation of an ETL (Extract, Transform, Load) process for Oracle database extracts. It processes E-series files, validates them, loads them into the database, and generates reports.

## Key Functions

### Entity Unlocking Process
```java
if (cal.get(Calendar.DAY_OF_WEEK) != Calendar.SATURDAY) {
    logMessage("Unlocking Entity ........................... " + dateFormat.format(new Date()) + "\n");
    // NOTE: This requires external process execution
    runProcessWithLogs(entDir + "/als_lock", new String[]{"ent", "u", "load"}, logFile);
}
```

This code block checks if the current day is not a Saturday, and if it's not, it unlocks an entity in the system. Let me break it down step by step:

1. `if (cal.get(Calendar.DAY_OF_WEEK) != Calendar.SATURDAY) {` - This condition checks the current day of the week from the calendar object. It specifically checks if the day is NOT Saturday.

2. If the condition is true (meaning it's any day except Saturday), then:

3. `logMessage("Unlocking Entity ..." + dateFormat.format(new Date()) + "\n")` - This writes a message to the log file indicating that entity unlocking is in progress, along with the current timestamp.

4. `runProcessWithLogs(entDir + "/als_lock", new String[]{"ent", "u", "load"}, logFile)` - This executes an external process:
   * It runs the program located at `entDir + "/als_lock"` (which is likely a script or executable)
   * It passes three arguments to this program: "ent", "u", and "load"
   * The output of this process is appended to the log file specified by `logFile`

The purpose of this code appears to be managing locking states in the system. On days other than Saturday, it unlocks an entity (likely a database entity or resource) to allow processing. This suggests that Saturday might have special handling in the system, possibly because it's a weekend day where certain operations don't need to be performed or have different requirements.

The comment "NOTE: This requires external process execution" indicates that this operation cannot be done purely in Java and needs to invoke an external script or program to unlock the entity.

## Dependencies on External Processes

Despite being a Java application, DailyLoad still relies on several external scripts:

1. **c.proc scripts**: The application executes these scripts to perform the actual data loading.
   ```java
   runProcessWithLogs(loadDir + "/c.proc" + file, new String[]{}, logDir + "/" + file + ".out");
   ```

2. **als_lock script**: Used for locking/unlocking entities as described above.

## File Paths

The application uses the following directory paths:

```java
entDir = app + "/execloc/d.entity";
loadDir = app + "/execloc/d.loads";
ftpDir = app + "/FTPDIR";  // This is where E files are expected to be found
logDir = app + "/entity/d.ICS/d.NEWDATA";  // This is where .dat files are copied to
bkupDir = app + "/entity/d.ICS/d.NEWDATA/d.BACKUP";
```

All paths are relative to the base `app` variable, which is set to `/als-ALS/app` in the code.

## Running the Application

Refer to the [DailyLoad Java Application Guide](dailyload-java-guide.md) for detailed instructions on how to compile and run the application, as well as information about the database schema used.
