CREATE SCHEMA clinic;

/*
DDL order for table creation:

Tier 1 — indeoendent entities
1. medical_staff
2. patient
3. medication

Tier 2 — Depend only on Tier 1:
4. doctor (refs medical_staff)
5. schedule (refs medical_staff)

Tier 3 — Depend on Tier 2:
6. schedule_history (refs schedule)
7. appointment (refs patient + doctor)

Tier 4 — Depend on Tier 3:
8. prescription (refs appointment)
9. treatment (refs appointment)
10. diagnostic_test (refs appointment)
11. billing (refs appointment)
12. appointment_history (refs appointment)

Tier 5 — Depend on Tier 4:
13. medication_prescription (refs prescription + medication)
14. treatment_history (refs treatment)
15. payment (refs billing)
16. billing_history (refs billing)
*/


-- Block 1: CREATING all 16 tables (DDL order)
-- Tier 1 — indeoendent entities

-- medical_staff
CREATE TABLE IF NOT EXISTS clinic.medical_staff (
	staff_id BIGSERIAL 		PRIMARY KEY,
	first_name VARCHAR(200) NOT NULL,
	last_name VARCHAR(200)  NOT NULL,
	phone VARCHAR(50)       NOT NULL UNIQUE,
	email VARCHAR(250)      NOT NULL UNIQUE,
	"role" VARCHAR(200)     NOT NULL
	);

-- PK staff_id: BIGSERIAL — auto-increments, no manual ID needed.
--   Risk of INT: overflows at 2.1B rows → "integer out of range" error.
-- first_name/last_name: VARCHAR(200) — limits name length to reasonable size.
--   Risk of TEXT: no limit, 10,000 char name accepted → storage waste, UI breaks.
-- phone: VARCHAR not INT — INT drops leading zeros.
--   Example: 0901234567 as INT becomes 901234567 → wrong number stored.
-- email: VARCHAR(250) — long enough for real emails.
--   Risk of VARCHAR(50): rejects 'firstname.lastname@corporatedomain.com'.
-- "role": reserved word, must always quote in queries → SELECT "role" FROM clinic.medical_staff.


-- patient
CREATE TABLE clinic.patient (
	patient_id BIGSERIAL 	PRIMARY KEY,
	first_name VARCHAR(200) NOT NULL,
	last_name VARCHAR(200)  NOT NULL,
	date_of_birth DATE      NOT NULL,
	phone VARCHAR(50)       NOT NULL,
	email VARCHAR(250)      UNIQUE,
	sensitivity_level VARCHAR(50) NOT NULL DEFAULT 'STANDARD'
		CHECK (sensitivity_level IN ('STANDARD', 'SENSITIVE', 'HIGHLY_SENSITIVE'))
);


-- date_of_birth: DATE not VARCHAR — enables age calculation and date comparisons.
--   Risk of VARCHAR: '1990-13-45' accepted → invalid date stored silently.
-- phone: no UNIQUE — family members may share one phone number.
-- email: UNIQUE but nullable — patient may not have email, if provided must be unique.
-- sensitivity_level: CHECK + DEFAULT 'STANDARD' — controlled vocabulary, least restrictive by default.
--   Risk of no CHECK: 'top secret', 'classified' inserted freely → inconsistent access control.


-- medication
CREATE TABLE clinic.medication (
	medication_id     BIGSERIAL     PRIMARY KEY,
	medication_name   VARCHAR(100)  NOT NULL,
	medication_form   VARCHAR (100) NOT NULL,
	strength          VARCHAR(100)  NOT NULL,
	CONSTRAINT uq_medication UNIQUE (medication_name, medication_form, strength)
);

-- strength: VARCHAR not DECIMAL — strength can be '500mg/5ml', not just a number.
--   Risk of DECIMAL: rejects '500mg/5ml' → valid data blocked.
-- Composite UNIQUE (medication_name, medication_form, strength) — same drug exists in different forms.
--   Example: Ibuprofen+Tablet+200mg, Ibuprofen+Tablet+200mg again blocked.
--   Risk of no UNIQUE: duplicate medications → prescription confusion.


--Tier 2 — Depend only on Tier 1:

-- doctor (refs medical_staff)
CREATE TABLE clinic.doctor (
	staff_id            BIGINT 		    PRIMARY KEY,
	room_number         INTEGER         NOT NULL UNIQUE, 
	specialization      VARCHAR(100)    NOT NULL,
	years_of_experience INTEGER         NOT NULL CHECK (years_of_experience >= 0),
	 CONSTRAINT fk_doctor_staff         FOREIGN KEY (staff_id)
        REFERENCES clinic.medical_staff (staff_id)
);

-- staff_id: BIGINT not BIGSERIAL — ID comes from medical_staff, not auto-generated.
--   Risk of BIGSERIAL: generates own IDs → breaks 1:1 relationship with medical_staff.
-- room_number: INTEGER UNIQUE — numeric sorting enabled, one doctor per room enforced.
--   Risk of no UNIQUE: two doctors assigned same room → scheduling conflict.
-- years_of_experience: CHECK >= 0 — cannot be negative.
--   Risk of no CHECK: years_of_experience = -5 accepted → meaningless data.
-- FK fk_doctor_staff → medical_staff: doctor must exist as staff first.
--   Risk of no FK: doctor inserted with nonexistent staff_id → orphan record.


-- schedule (refs medical_staff)
CREATE TABLE clinic.schedule (
    schedule_id         BIGSERIAL    PRIMARY KEY,
    staff_id            BIGINT       NOT NULL,
    check_in            TIME         NOT NULL,
    check_out           TIME         NOT NULL,
    day_of_week         VARCHAR(100) NOT NULL,
    availability_status VARCHAR(50)  NOT NULL,
	CONSTRAINT fk_schedule_staff FOREIGN KEY (staff_id)
        REFERENCES clinic.medical_staff (staff_id),
    CONSTRAINT chk_schedule_day CHECK (day_of_week IN (
        'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    )),
    CONSTRAINT chk_availability_status CHECK (availability_status IN (
        'AVAILABLE', 'UNAVAILABLE', 'ON_LEAVE'
    ))
);

-- check_in/check_out: TIME not VARCHAR — enables time comparisons.
--   Risk of VARCHAR: '9am', '09:00', '9:00 AM' all accepted → inconsistent, filtering breaks.
-- day_of_week: CHECK enforces valid day names only.
--   Risk of no CHECK: 'Mondayy', 'mon' accepted → grouping and filtering breaks.
-- availability_status: CHECK enforces controlled vocabulary.
--   Risk of no CHECK: 'off', 'busy' inserted freely → reporting inconsistent.
-- FK fk_schedule_staff → medical_staff: schedule must belong to existing staff.
--   Risk of no FK: schedule created for deleted staff → orphan record.


--Tier 3 — Depend on Tier 2:

-- schedule_history
CREATE TABLE clinic.schedule_history (
    schedule_history_id     BIGSERIAL    PRIMARY KEY,
    schedule_id             BIGINT       NOT NULL,
    old_check_in            TIME         NOT NULL,
    old_check_out           TIME         NOT NULL,
    old_day_of_week         VARCHAR(50)  NOT NULL,
    old_availability_status VARCHAR(50)  NOT NULL,
    new_check_in            TIME         NOT NULL,
    new_check_out           TIME         NOT NULL,
    new_day_of_week         VARCHAR(50)  NOT NULL,
    new_availability_status VARCHAR(50)  NOT NULL,
    changed_at              TIMESTAMP    NOT NULL DEFAULT NOW(),
    change_note             TEXT,
	CONSTRAINT fk_schedule_history_schedule FOREIGN KEY (schedule_id)
        REFERENCES clinic.schedule (schedule_id)
);

-- changed_at: TIMESTAMP not DATE — captures exact moment, not just the day.
--   Risk of DATE: two changes same day indistinguishable → audit trail incomplete.
--   DEFAULT NOW() — current timestamp recorded automatically.
-- change_note: TEXT nullable — explanation is optional, not every change needs one.
-- FK fk_schedule_history_schedule → schedule: history must belong to existing schedule.
--   Risk of no FK: history record for deleted schedule → dangling reference.


-- appointment (refs patient + doctor)
CREATE TABLE clinic.appointment (
	appointment_id		BIGSERIAL 		PRIMARY KEY,
	patient_id 			BIGINT 			NOT NULL,
	doctor_id           BIGINT 			NOT NULL,
	appointment_date    DATE 			NOT NULL CHECK (appointment_date > '2000-01-01'),
	appointment_time    TIME            NOT NULL,
	appointment_reason  TEXT 			NOT NULL,
	status              VARCHAR(50)     NOT NULL DEFAULT 'SCHEDULED' CHECK (status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED', 'NO_SHOW')),
	CONSTRAINT fk_appointment_patient  FOREIGN KEY (patient_id)
		REFERENCES clinic.patient (patient_id),
	CONSTRAINT fk_appointment_doctor FOREIGN KEY (doctor_id)
		REFERENCES clinic.doctor (staff_id)
);

-- appointment_date: CHECK > '2000-01-01' — rejects historically invalid dates.
--   Risk of no CHECK: appointment_date = '1800-01-01' accepted → meaningless data.
-- appointment_reason: TEXT — reason can be long clinical description, no length cap needed.
-- status: DEFAULT 'SCHEDULED' — new appointments always start scheduled.
--   Risk of no DEFAULT: status must be manually inserted every time → easy to forget, NULL inserted.
-- FK fk_appointment_patient → patient, fk_appointment_doctor → doctor: both parents must exist.
--   Risk of no FK: appointment for nonexistent patient or fired doctor → data integrity broken.


-- Tier 4 — Depend on Tier 3:

-- prescription (refs appointment)
CREATE TABLE clinic.prescription ( 
	prescription_id 	BIGSERIAL 		PRIMARY KEY,
	appointment_id 		BIGINT  		NOT NULL,
	date_issued 		DATE            NOT NULL CHECK (date_issued > '2000-01-01'),
	instruction 		TEXT,
	sensitivity_level   VARCHAR(50)		NOT NULL DEFAULT 'STANDARD' CHECK (sensitivity_level IN ('STANDARD', 'SENSITIVE', 'HIGHLY_SENSITIVE')),
	visibility_scope 	VARCHAR(50)		NOT NULL DEFAULT 'PRIVATE' CHECK (visibility_scope IN ('PUBLIC', 'PRIVATE', 'RESTRICTED')),
	CONSTRAINT fk_prescription_appointment FOREIGN KEY (appointment_id)
		REFERENCES clinic.appointment (appointment_id)
);

-- instruction: TEXT nullable — not every prescription has written instructions.
-- visibility_scope: DEFAULT 'PRIVATE' — prescriptions are sensitive, private by default.
--   Risk of no DEFAULT: visibility inconsistent across records → accidental data exposure.
-- FK fk_prescription_appointment → appointment: prescription must belong to real appointment.
--   Risk of no FK: prescription created for cancelled/deleted appointment → orphan record.


-- treatment (refs appointment) 
CREATE TABLE clinic.treatment (
	treatment_id 		BIGSERIAL 		PRIMARY KEY,
	appointment_id 		BIGINT 			NOT NULL,
	treatment_name 		VARCHAR(200)    NOT NULL,
	treatment_date 		DATE      		NOT NULL CHECK (treatment_date > '2000-01-01'),
	description 		TEXT  			NOT NULL,
	status  			VARCHAR(50)		NOT NULL DEFAULT 'ONGOING' CHECK (status IN ('ONGOING', 'COMPLETED', 'CANCELLED')),
	sensitivity_level   VARCHAR(50)		NOT NULL DEFAULT 'STANDARD' CHECK (sensitivity_level IN ('STANDARD', 'SENSITIVE', 'HIGHLY_SENSITIVE')),
	visibility_scope 	VARCHAR(50)		NOT NULL DEFAULT 'PRIVATE' CHECK (visibility_scope IN ('PUBLIC', 'PRIVATE', 'RESTRICTED')),
	CONSTRAINT fk_treatment_appointment FOREIGN KEY (appointment_id)
		REFERENCES clinic.appointment (appointment_id)
);

-- description: TEXT not VARCHAR — clinical notes can be long.
--   Risk of VARCHAR(200): long descriptions truncated → data loss.
-- status: DEFAULT 'ONGOING' — new treatment always starts ongoing.
-- sensitivity_level/visibility_scope: same pattern as prescription — controlled access by default.
-- FK fk_treatment_appointment → appointment: same reasoning as prescription FK.


-- diagnostic_test (refs appointment)
CREATE TABLE clinic.diagnostic_test (
    test_id           BIGSERIAL    PRIMARY KEY,
    appointment_id    BIGINT       NOT NULL,
    test_type         VARCHAR(200) NOT NULL,
    test_date         DATE         NOT NULL CHECK (test_date > '2000-01-01'),
    result_status     VARCHAR(50)  NOT NULL DEFAULT 'PENDING' CHECK (result_status IN ('PENDING', 'COMPLETED', 'CANCELLED')),
    note              TEXT         NOT NULL,
    sensitivity_level VARCHAR(50)  NOT NULL DEFAULT 'STANDARD' CHECK (sensitivity_level IN ('STANDARD', 'SENSITIVE', 'HIGHLY_SENSITIVE')),
    visibility_scope  VARCHAR(50)  NOT NULL DEFAULT 'PRIVATE' CHECK (visibility_scope IN ('PUBLIC', 'PRIVATE', 'RESTRICTED')),
	CONSTRAINT fk_diagnostic_appointment FOREIGN KEY (appointment_id)
        REFERENCES clinic.appointment (appointment_id)
);

-- test_type: VARCHAR(200) — test names can be long medical terms.
--   Example: 'High-resolution computed tomography' = 40 chars, fits comfortably.
-- result_status: DEFAULT 'PENDING' — new test always starts pending, result comes later.
--   Risk of no DEFAULT: result_status must be manually inserted → NULL if forgotten, CHECK blocks insert.
-- FK fk_diagnostic_appointment → appointment: test must belong to real appointment.


-- billing (refs appointment)
CREATE TABLE clinic.billing (
	billing_id 	   BIGSERIAL     PRIMARY KEY,
	appointment_id BIGINT 	     NOT NULL,
	billing_date   DATE 	     NOT NULL CHECK (billing_date > '2000-01-01'),
	total_amount   DECIMAL(10,2) NOT NULL CHECK (total_amount >= 0),
	billing_status VARCHAR (100) NOT NULL DEFAULT 'UNPAID' CHECK (billing_status IN ('UNPAID', 'PAID', 'PARTIALLY_PAID', 'CANCELLED')),
	CONSTRAINT fk_billing_appointment FOREIGN KEY (appointment_id)
		REFERENCES clinic.appointment (appointment_id)
);

-- total_amount: DECIMAL(10,2) not FLOAT — exact two decimal places for financial data.
--   Risk of FLOAT: 150.10 stored as 150.09999999 → rounding errors in financial reports.
-- CHECK total_amount >= 0 — amount cannot be negative.
--   Example: total_amount = -500.00 blocked → prevents accidental negative billing.
-- billing_status: DEFAULT 'UNPAID' — new billing always starts unpaid.
-- FK fk_billing_appointment → appointment: billing must belong to real appointment.

-- appointment_history (refs appointment)
CREATE TABLE clinic.appointment_history (
    appointment_history_id BIGSERIAL   PRIMARY KEY,
    appointment_id         BIGINT      NOT NULL,
    old_status             VARCHAR(50) CHECK (old_status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED', 'NO_SHOW')),
    new_status             VARCHAR(50) NOT NULL CHECK (new_status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED', 'NO_SHOW')),
    changed_at             TIMESTAMP   NOT NULL DEFAULT NOW(),
    change_note            TEXT,
    CONSTRAINT fk_appointment_history FOREIGN KEY (appointment_id)
        REFERENCES clinic.appointment (appointment_id)
);

-- old_status: nullable, no NOT NULL — first status change has no previous value.
--   Example: appointment created → old_status = NULL, new_status = 'SCHEDULED'.
-- CHECK values match appointment.status exactly — history must reflect valid status transitions.
--   Risk of mismatch: 'DONE' in history, 'COMPLETED' in appointment → inconsistent audit trail.


-- Tier 5 — Depend on Tier 4:

-- medication_prescription (refs medication + prescription)
CREATE TABLE clinic.medication_prescription (
    medication_id   BIGINT       NOT NULL,
    prescription_id BIGINT       NOT NULL,
    dosage          VARCHAR(100) NOT NULL,
    frequency       VARCHAR(100) NOT NULL,
    duration        VARCHAR(100) NOT NULL,
    CONSTRAINT pk_medication_prescription PRIMARY KEY (medication_id, prescription_id),
    CONSTRAINT fk_med_prescription_medication FOREIGN KEY (medication_id)
        REFERENCES clinic.medication (medication_id),
    CONSTRAINT fk_med_prescription_prescription FOREIGN KEY (prescription_id)
        REFERENCES clinic.prescription (prescription_id)
);

-- No BIGSERIAL — composite PK (medication_id + prescription_id) is the unique identifier.
--   Risk of no composite PK: same medication added to same prescription twice → duplicate dosage.
-- dosage/frequency/duration: VARCHAR(100) — flexible format needed.
--   Example: dosage = '2 tablets', frequency = 'twice daily', duration = '7 days'.
-- FK → both medication and prescription must exist before linking.
--   Risk of no FK: medication_prescription for deleted prescription → broken M:M link.


-- treatment_history (refs treatment)
CREATE TABLE clinic.treatment_history (
    treatment_history_id BIGSERIAL   PRIMARY KEY,
    treatment_id         BIGINT      NOT NULL,
    old_status           VARCHAR(50) CHECK (old_status IN ('ONGOING', 'COMPLETED', 'CANCELLED')),
    new_status           VARCHAR(50) NOT NULL CHECK (new_status IN ('ONGOING', 'COMPLETED', 'CANCELLED')),
    changed_at           TIMESTAMP   NOT NULL DEFAULT NOW(),
    change_note          TEXT,
    CONSTRAINT fk_treatment_history FOREIGN KEY (treatment_id)
        REFERENCES clinic.treatment (treatment_id)
);

-- CHECK values match treatment.status exactly — same reasoning as appointment_history.
-- old_status nullable — first treatment record has no previous status.
-- FK fk_treatment_history → treatment: history must belong to existing treatment.


-- payment (refs billing)
CREATE TABLE clinic.payment (
    payment_id      BIGSERIAL      PRIMARY KEY,
    billing_id      BIGINT         NOT NULL,
    payment_method  VARCHAR(100)   NOT NULL CHECK (payment_method IN ('CASH', 'CARD', 'BANK_TRANSFER', 'INSURANCE')),
    payment_date    DATE           NOT NULL CHECK (payment_date > '2000-01-01'),
    payment_amount  DECIMAL(10,2)  NOT NULL CHECK (payment_amount >= 0),
    payment_status  VARCHAR(100)   NOT NULL DEFAULT 'PENDING' CHECK (payment_status IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED')),
	CONSTRAINT fk_payment_billing FOREIGN KEY (billing_id)
        REFERENCES clinic.billing (billing_id)
);

-- payment_method: CHECK enforces valid methods only.
--   Example: 'CASH', 'CARD' valid. 'crypto', 'barter' blocked → financial reporting consistent.
-- payment_amount: DECIMAL(10,2) — same reasoning as billing.total_amount.
-- payment_status: DEFAULT 'PENDING' — payment always starts pending until processed.
-- FK fk_payment_billing → billing: payment must belong to existing bill.
--   Risk of no FK: payment for nonexistent bill → financial records corrupted.


-- billing_history (refs billing)
CREATE TABLE clinic.billing_history (
    billing_history_id BIGSERIAL   PRIMARY KEY,
    billing_id         BIGINT      NOT NULL,
    old_status         VARCHAR(50) CHECK (old_status IN ('UNPAID', 'PAID', 'PARTIALLY_PAID', 'CANCELLED')),
    new_status         VARCHAR(50) NOT NULL CHECK (new_status IN ('UNPAID', 'PAID', 'PARTIALLY_PAID', 'CANCELLED')),
    changed_at         TIMESTAMP   NOT NULL DEFAULT NOW(),
    change_note        TEXT,
	CONSTRAINT fk_billing_history FOREIGN KEY (billing_id)
        REFERENCES clinic.billing (billing_id)
);

-- old_status nullable — first billing record has no previous status.
-- CHECK values match billing.billing_status exactly — consistent audit trail.
-- FK fk_billing_history → billing: history must belong to existing billing record.
--   Risk of no FK: history for deleted bill - compliance risk.

 
-- Block 2 — INSERT data into tables

-- medical_staff
BEGIN;

	INSERT INTO clinic.medical_staff (first_name, last_name, phone, email, "role")
	SELECT
	    'John',
	    'Davis',
	    '+99899855631',
	    'John@gmail.com',
	    'Doctor'
	WHERE NOT EXISTS (
	    SELECT 1 FROM clinic.medical_staff
	    WHERE phone = '+99899855631')
	UNION ALL 
	SELECT 
		'Cristian',
	    'Henderson',
	    '+99896888563',
	    'Cristian@mail.ru',
	    'Receptionist'
	WHERE NOT EXISTS (SELECT 1 FROM clinic.medical_staff
					  WHERE phone = '+99896888563');

COMMIT;

-- patient 
BEGIN;

	INSERT INTO clinic.patient (first_name, last_name, date_of_birth, phone, email, sensitivity_level)
	SELECT
	    'Emma',
	    'Wilson',
	    '1990-05-15'::DATE,
	    '+99890123456',
	    'emma.wilson@gmail.com',
	    'STANDARD'
	WHERE NOT EXISTS (
	    SELECT 1 FROM clinic.patient
	    WHERE phone = '+99890123456')
    UNION ALL 
	SELECT
	    'James',
	    'Miller',
	    '1985-11-23'::DATE,
	    '+99891234567',
	    'james.miller@mail.ru',
	    'SENSITIVE'
	WHERE NOT EXISTS (
	    SELECT 1 FROM clinic.patient
	    WHERE phone = '+99891234567'
	)
	RETURNING patient_id, first_name, last_name, date_of_birth, phone, email, sensitivity_level;

COMMIT;

-- medication 
BEGIN;

	INSERT INTO clinic.medication (medication_name, medication_form, strength)
	SELECT
	    'IBUPROFEN',
	    'TABLET',
	    '200MG'
	WHERE NOT EXISTS (
	    SELECT 1 FROM clinic.medication
	    WHERE UPPER(medication_name) = 'IBUPROFEN'
	    AND UPPER(medication_form) = 'TABLET'
	    AND UPPER(strength) = '200MG')
	UNION ALL 
	SELECT
	    'AMOXICILLIN',
	    'CAPSULE',
	    '500MG'
	WHERE NOT EXISTS (
	    SELECT 1 FROM clinic.medication
	    WHERE UPPER(medication_name) = 'AMOXICILLIN'
	    AND UPPER(medication_form) = 'CAPSULE'
	    AND UPPER(strength) = '500MG'
	)
	RETURNING *;

COMMIT;

