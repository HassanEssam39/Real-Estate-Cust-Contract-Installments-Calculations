----------------------------------------------- CREATING TABLE & SEQ & TRIG ---------------------------------------------
DROP TABLE HR.INSTALLMENTS_PAID CASCADE CONSTRAINTS;
CREATE TABLE HR.INSTALLMENTS_PAID
(
  INSTALLMENT_ID      NUMBER(8),
  CONTRACT_ID         NUMBER(8),
  INSTALLMENT_DATE    DATE,
  INSTALLMENT_AMOUNT  NUMBER(15,2),
  PAID                NUMBER(15,2)              DEFAULT 0
);
ALTER TABLE HR.INSTALLMENTS_PAID ADD (
  CONSTRAINT INSTALLMENTS_PAID_PK
 PRIMARY KEY
 (INSTALLMENT_ID));

DROP SEQUENCE HR.INSTALLMENTS_PAID_SEQ;
CREATE SEQUENCE HR.INSTALLMENTS_PAID_SEQ
START WITH 1
INCREMENT BY 1;
-- Trigger
CREATE TRIGGER HR.INSTALLMENTS_PAID_TRG
BEFORE INSERT
ON HR.INSTALLMENTS_PAID
REFERENCING NEW AS New OLD AS Old
FOR EACH ROW
BEGIN
-- For Toad:  Highlight column INSTALLMENT_ID
  :new.INSTALLMENT_ID := INSTALLMENTS_PAID_SEQ.nextval;
END INSTALLMENTS_PAID_TRG;

CREATE TABLE HR.CLIENTS
(
  CLIENT_ID       NUMBER(8),
  CLIENT_NAME     VARCHAR2(50 BYTE),
  CLIENT_ADDRESS  VARCHAR2(50 BYTE),
  CLIENT_NOTES    VARCHAR2(100 BYTE)
);

-----------------------------  1st Part ----------------------------------

DECLARE
    CURSOR no_insts_curs IS
     SELECT contract_id
     FROM contracts;
     v_division NUMBER(8);
        
BEGIN
        FOR insts_record IN no_insts_curs LOOP
        SELECT 
        CASE WHEN contract_payment_type = 'annual' THEN
        months_between ( contract_enddate, contract_startdate  ) / 12
                WHEN contract_payment_type = 'half_annual' THEN
        months_between ( contract_enddate, contract_startdate  ) / 6
        WHEN  contract_payment_type = 'quarter' THEN
        months_between ( contract_enddate, contract_startdate  ) / 3
        WHEN contract_payment_type = 'monthly' THEN
        months_between ( contract_enddate, contract_startdate  )
        END 
        INTO v_division
        FROM contracts
        WHERE contract_id = insts_record.contract_id ;
        
        UPDATE contracts
        SET PAYMENTS_INSTALLMENTS_NO = v_division
        WHERE contract_id = insts_record.contract_id ;
        END LOOP;
END;

update contracts 
set PAYMENTS_INSTALLMENTS_NO = NULL;

------------------------------------ 2nd Part -------------------------------------------

CREATE OR REPLACE PROCEDURE insts_proc (v_contract_id NUMBER)
IS
v_result DATE;   i NUMBER := 2;   v_max DATE; v_contract_startdate DATE; v_fees NUMBER (10, 2);
v_contract_enddate DATE; v_contract_type VARCHAR2(50); v_payments_installments_no NUMBER(4); v_cont_total NUMBER (10,2); v_cont_deposit NUMBER(10, 2);
BEGIN 
            SELECT contract_startdate, contract_enddate, contract_payment_type, payments_installments_no, contract_total_fees , NVL (contract_deposit_fees, 0)
                    INTO  v_contract_startdate, v_contract_enddate, v_contract_type, v_payments_installments_no, v_cont_total, v_cont_deposit
               FROM contracts 
               WHERE contract_id = v_contract_id;
               
            v_fees := ROUND ( (v_cont_total - v_cont_deposit) / v_payments_installments_no );
            
                         INSERT INTO installments_paid( contract_id, installment_date, installment_amount)
                              VALUES ( v_contract_id, v_contract_startdate, v_fees );
    
                                WHILE  i <= v_payments_installments_no LOOP
                                    SELECT   MAX(installment_date) INTO v_max FROM installments_paid
                                    WHERE contract_id = v_contract_id;

                                        IF      v_contract_type = 'annual' THEN
                                                       v_result := ADD_MONTHS (v_max, 12);
                                                       v_fees := ROUND ( (v_cont_total - v_cont_deposit) / v_payments_installments_no ) ;
                                            ELSIF v_contract_type = 'half_annual' THEN
                                                       v_result := ADD_MONTHS (v_max, 6);
                                                       v_fees := ROUND ( (v_cont_total - v_cont_deposit) / v_payments_installments_no ) ;
                                            ELSIF v_contract_type = 'quarter' THEN
                                                       v_result := ADD_MONTHS (v_max, 3);
                                                       v_fees := ROUND ( (v_cont_total - v_cont_deposit) / v_payments_installments_no ) ;
                                            ELSIF v_contract_type = 'monthly' THEN
                                                       v_result := ADD_MONTHS (v_max, 1);     
                                                       v_fees := ROUND ( (v_cont_total - v_cont_deposit) / v_payments_installments_no ) ;        
                                                                                    
                                        END IF;
                                                     INSERT INTO installments_paid( contract_id, installment_date, installment_amount)
                                                          VALUES ( v_contract_id, v_result, v_fees);
                                                          

                                              i := i + 1;
                                              
                                END LOOP;
                                
END;

DECLARE 

            CURSOR insts_curs IS
            SELECT contract_id 
            FROM contracts
            ORDER BY contract_id; 
            
BEGIN 
           FOR insts_record IN insts_curs LOOP
            insts_proc ( insts_record.contract_id );
            END LOOP;
END;