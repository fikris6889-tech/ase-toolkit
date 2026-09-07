-- Fikris Technologies ASE DBA Toolkit
-- Purpose: Returns a count (0 or 1) indicating whether the sp_dumpdb
--          stored procedure already exists in this ASE instance.
--          Consumed by wrapper_complete_data_backup.sh.
sp_help
go | grep -i 'sp_dumpdb' | wc -l
