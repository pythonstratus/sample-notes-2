CREATE TABLE US_HOLIDAYS (
    holiday_date DATE,
    holiday_name VARCHAR2(255)
);


INSERT INTO US_HOLIDAYS (holiday_date, holiday_name) VALUES (TO_DATE('2025-01-01', 'YYYY-MM-DD'), 'New Year''s Day');
INSERT INTO US_HOLIDAYS (holiday_date, holiday_name) VALUES (TO_DATE('2025-01-20', 'YYYY-MM-DD'), 'Birthday of Martin Luther King, Jr.');
INSERT INTO US_HOLIDAYS (holiday_date, holiday_name) VALUES (TO_DATE('2025-02-17', 'YYYY-MM-DD'), 'Washington''s Birthday');
INSERT INTO US_HOLIDAYS (holiday_date, holiday_name) VALUES (TO_DATE('2025-05-26', 'YYYY-MM-DD'), 'Memorial Day');
INSERT INTO US_HOLIDAYS (holiday_date, holiday_name) VALUES (TO_DATE('2025-06-19', 'YYYY-MM-DD'), 'Juneteenth');
INSERT INTO US_HOLIDAYS (holiday_date, holiday_name) VALUES (TO_DATE('2025-07-04', 'YYYY-MM-DD'), 'Independence Day');
INSERT INTO US_HOLIDAYS (holiday_date, holiday_name) VALUES (TO_DATE('2025-09-01', 'YYYY-MM-DD'), 'Labor Day');
INSERT INTO US_HOLIDAYS (holiday_date, holiday_name) VALUES (TO_DATE('2025-10-13', 'YYYY-MM-DD'), 'Columbus Day');
INSERT INTO US_HOLIDAYS (holiday_date, holiday_name) VALUES (TO_DATE('2025-11-11', 'YYYY-MM-DD'), 'Veterans Day');
INSERT INTO US_HOLIDAYS (holiday_date, holiday_name) VALUES (TO_DATE('2025-11-27', 'YYYY-MM-DD'), 'Thanksgiving Day');
INSERT INTO US_HOLIDAYS (holiday_date, holiday_name) VALUES (TO_DATE('2025-12-25', 'YYYY-MM-DD'), 'Christmas Day');
