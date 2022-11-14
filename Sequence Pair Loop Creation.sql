DECLARE
            CURSOR action_curs IS
                    SELECT  con.constraint_name, con.table_name, col.column_name
                     FROM USER_CONSTRAINTS con 
                     INNER JOIN USER_INDEXES ind
                     ON con.constraint_name = ind.index_name
                     INNER JOIN USER_IND_COLUMNS col
                     ON  ind.index_name = col.index_name
                     WHERE con.constraint_type = 'P' and column_position = 1;
            
            
BEGIN
       FOR action_record IN action_curs LOOP

        EXECUTE IMMEDIATE ' CREATE SEQUENCE '||action_record.table_name|| '_sequence  ' || ' START WITH 600 INCREMENT BY 1 ';

                    EXECUTE IMMEDIATE ' CREATE OR REPLACE TRIGGER ' || action_record.table_name || '_trig ' ||
                        ' BEFORE INSERT 
                        ON ' || action_record.table_name ||
                        ' FOR EACH ROW
                             BEGIN 
                                :NEW.' || action_record.column_name || ' := ' ||  action_record.table_name || '_sequence.NEXTVAL;
                                END;' ;
                 
       END LOOP;

END;