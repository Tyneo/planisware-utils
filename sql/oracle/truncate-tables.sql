/*
 * Procedure to truncate all tables from the current tablespace
 * autoexec with: exec sp_truncate;
 * author: sah2ed 
 * website: http://blog.ejeboo.com/2010/08/truncate-or-delete-all-tables-in-oracle.html
 */
CREATE OR REPLACE PROCEDURE sp_truncate AS
BEGIN
-- Disable all constraints
FOR c IN
(SELECT c.owner, c.table_name, c.constraint_name
FROM user_constraints c, user_tables t
WHERE c.table_name = t.table_name
AND c.status = 'ENABLED'
ORDER BY c.constraint_type DESC)
LOOP
DBMS_UTILITY.EXEC_DDL_STATEMENT('ALTER TABLE ' || c.owner || '.' || c.table_name || ' disable constraint ' || c.constraint_name);
DBMS_OUTPUT.PUT_LINE('Disabled constraints for table ' || c.table_name);
END LOOP;
 
-- Truncate data in all tables
FOR i IN (SELECT table_name FROM user_tables)
LOOP
EXECUTE IMMEDIATE 'TRUNCATE TABLE ' || i.table_name;
DBMS_OUTPUT.PUT_LINE('Truncated table ' || i.table_name); 
END LOOP;
 
-- Enable all constraints
FOR c IN
(SELECT c.owner, c.table_name, c.constraint_name
FROM user_constraints c, user_tables t
WHERE c.table_name = t.table_name
AND c.status = 'DISABLED'
ORDER BY c.constraint_type)
LOOP
DBMS_UTILITY.EXEC_DDL_STATEMENT('ALTER TABLE ' || c.owner || '.' || c.table_name || ' enable constraint ' || c.constraint_name);
DBMS_OUTPUT.PUT_LINE('Enabled constraints for table ' || c.table_name);
END LOOP;
 
COMMIT;
END sp_truncate;
/

-- Let's go
exec sp_truncate;