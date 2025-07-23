
**Use this search to get a clean table view:**

```
namespace="sbse-als-dev" sourcetype="kube:container:ics-etl-batch" weeklyLogger "FILE:" 
| rex field=_raw "FILE:\s+(?<file_id>\w+)\s+\|\s+EXTRACT DATE:\s+(?<extract_date>\d{2}/\d{2}/\d{4})\s+\|\s+DATE LOADED:\s+(?<loaded_date>\d{2}/\d{2}/\d{4})\s+(?<loaded_time>\d{2}:\d{2}:\d{2})\s+\|\s+LOADED BY:\s+(?<loaded_by>\d+)\s+\|\s+RECORDS RECEIVED:\s+(?<records>\d+)"
| table _time, file_id, extract_date, loaded_date, loaded_time, loaded_by, records
| sort -_time
```

**For a simpler view with key metrics:**

```
namespace="sbse-als-dev" sourcetype="kube:container:ics-etl-batch" weeklyLogger "FILE:" 
| rex field=_raw "FILE:\s+(?<file_id>\w+).*EXTRACT DATE:\s+(?<extract_date>\d{2}/\d{2}/\d{4}).*RECORDS RECEIVED:\s+(?<records>\d+)"
| table file_id, extract_date, records
| sort -records
```

**For dashboard metrics - Total records by extract date:**

```
namespace="sbse-als-dev" sourcetype="kube:container:ics-etl-batch" weeklyLogger "RECORDS RECEIVED" 
| rex field=_raw "EXTRACT DATE:\s+(?<extract_date>\d{2}/\d{2}/\d{4}).*RECORDS RECEIVED:\s+(?<records>\d+)"
| stats sum(records) as total_records, count as file_count by extract_date
| sort extract_date
```

**File processing summary for dashboard:**

```
namespace="sbse-als-dev" sourcetype="kube:container:ics-etl-batch" weeklyLogger "FILE:" 
| rex field=_raw "RECORDS RECEIVED:\s+(?<records>\d+)"
| stats count as total_files, sum(records) as total_records, avg(records) as avg_records_per_file
| eval avg_records_per_file=round(avg_records_per_file,0)
```

Try the first search - it should give you a clean table with all the file processing details. Make sure to click on the **Statistics** tab if you don't see the table format immediately.

Which search gives you the table format you're looking for?
