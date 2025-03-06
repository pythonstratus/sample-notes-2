# DailyLoad Java Application Guide

## How to Run the Java Code

1. **Set up your environment**:
   - Install Java JDK (Java Development Kit) version 8 or higher
   - Ensure Oracle JDBC drivers are available (for database connectivity)
   - Make sure the JavaMail API libraries are available (for email functionality)

2. **Compile the code**:
   ```bash
   # Create a directory for compiled classes
   mkdir -p classes
   
   # Compile the Java file
   javac -cp "path/to/ojdbc.jar:path/to/javax.mail.jar" -d classes DailyLoad.java
   ```

3. **Run the application**:
   ```bash
   # Run without arguments (uses current date)
   java -cp "classes:path/to/ojdbc.jar:path/to/javax.mail.jar" DailyLoad
   
   # Run with a specific date (MM/DD/YYYY format)
   java -cp "classes:path/to/ojdbc.jar:path/to/javax.mail.jar" DailyLoad 03/06/2025
   ```

4. **Dependencies you need**:
   - Oracle JDBC driver (ojdbc8.jar or similar)
   - JavaMail API (javax.mail.jar and javax.activation.jar)

5. **Important considerations**:
   - Ensure the directories specified in the code (ftpDir, logDir, etc.) exist and have proper permissions
   - The c.proc scripts referenced in the code must be executable
   - The database connection details (URL, username, password) need to be correct
   - SMTP server information must be valid for email functionality

6. **For Windows systems**, use semicolons instead of colons in the classpath:
   ```bash
   java -cp "classes;path\to\ojdbc.jar;path\to\javax.mail.jar" DailyLoad
   ```

## Database Tables and Schema

The DailyLoad application interacts with the following database objects:

1. **Main database table: LOGLOAD**
   - This is the central table for tracking extract file processing
   - Referenced in multiple queries throughout the code
   - Contains columns such as:
     - `LOADNAME` - Name of the extract file (E5, E3, E8, E7, E9)
     - `EXTRDTX` - Extract date
     - `LOADDT` - Load date and time
     - `UNLZ` - Appears to be a count or status field
     - `NUMREC` - Number of records received/processed

2. **Database objects/packages:**
   - `DATELIB.xtrchldv` - A function called to determine holiday dates
   - `DATELIB.nsrtholidayrecs` - A procedure called to insert holiday records

3. **Schema information:**
   - The code connects to the database using the username `als`
   - This suggests that the schema is named `ALS`
   - The database appears to be Oracle, using the standard SID "orcl"

4. **Table "dual":**
   - This is a standard Oracle system table used for various calculations and date manipulations
   - Used in multiple places for date arithmetic

Example queries used against these tables include:
- Retrieving the maximum extract date for a given load name:
  ```sql
  SELECT max(EXTRDTX) FROM LOGLOAD WHERE LOADNAME = 'E5'
  ```

- Getting records loaded on the current date:
  ```sql
  SELECT loadname, to_char(extrdt, 'MM/DD/YYYY '), 
         to_char(to_date(loaddt, 'MM/DD/YYYY HH24:MI:SS'), 'MM/DD/YYYY HH24:MI:SS'), 
         unlz, numrec 
  FROM logload 
  WHERE loaddt LIKE '03/06/2025%' 
  ORDER BY loaddt
  ```
