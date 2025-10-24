Hi Chinmaya,
I hope this email finds you well.
I'm currently reviewing our ICS zip code assignment data processing workflow (ent_zip.csh script) and need to verify the status of the input data file.
Request:
Could you please check and confirm if the icszip.dat file (or files matching the pattern icszip.????????.dat) is currently available for processing in the following location:

Directory: /als-ALS/app/entity/d.ics_zips/
Expected file pattern: icszip.YYYYMMDD.dat (date-stamped format)

Specifically, please verify:

Is the file present in the directory?
If yes, what is the file name and date stamp?
Are there multiple files, or just one file available?
Is the file size reasonable (non-zero)?

The script expects exactly one file matching this pattern to proceed with the data load to the oldzips table, followed by the crzips procedure execution.
Please let me know your findings at your earliest convenience so we can proceed accordingly.
Thank you for your assistance!
