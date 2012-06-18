
-- Host: localhost    Database: bart2
-- ------------------------------------------------------
-- Server version	5.1.54-1ubuntu4-log
/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

-- Non-voided HIV Clinic Consultation encounters
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `clinic_consultation_encounter` AS
  SELECT `encounter`.`encounter_id` AS `encounter_id`,
         `encounter`.`encounter_type` AS `encounter_type`,
         `encounter`.`patient_id` AS `patient_id`,
         `encounter`.`provider_id` AS `provider_id`,
         `encounter`.`location_id` AS `location_id`,
         `encounter`.`form_id` AS `form_id`,
         `encounter`.`encounter_datetime` AS `encounter_datetime`,
         `encounter`.`creator` AS `creator`,
         `encounter`.`date_created` AS `date_created`,
         `encounter`.`voided` AS `voided`,
         `encounter`.`voided_by` AS `voided_by`,
         `encounter`.`date_voided` AS `date_voided`,
         `encounter`.`void_reason` AS `void_reason`,
         `encounter`.`uuid` AS `uuid`,
         `encounter`.`changed_by` AS `changed_by`,
         `encounter`.`date_changed` AS `date_changed`
  FROM `encounter`
  WHERE (`encounter`.`encounter_type` = 53 AND `encounter`.`voided` = 0);

-- ARV drugs
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
	VIEW `arv_drug` AS
	SELECT `drug_id` FROM `drug` 
	WHERE `concept_id` IN (SELECT `concept_id` FROM `concept_set` WHERE `concept_set` = 1085);

-- Non-voided HIV Clinic Registration encounters
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
	VIEW `clinic_registration_encounter` AS 
	SELECT `encounter`.`encounter_id` AS `encounter_id`,
         `encounter`.`encounter_type` AS `encounter_type`,
         `encounter`.`patient_id` AS `patient_id`,
         `encounter`.`provider_id` AS `provider_id`,
         `encounter`.`location_id` AS `location_id`,
         `encounter`.`form_id` AS `form_id`,
         `encounter`.`encounter_datetime` AS `encounter_datetime`,
         `encounter`.`creator` AS `creator`,
         `encounter`.`date_created` AS `date_created`,
         `encounter`.`voided` AS `voided`,
         `encounter`.`voided_by` AS `voided_by`,
         `encounter`.`date_voided` AS `date_voided`,
         `encounter`.`void_reason` AS `void_reason`,
         `encounter`.`uuid` AS `uuid`,
         `encounter`.`changed_by` AS `changed_by`,
         `encounter`.`date_changed` AS `date_changed`
	FROM `encounter`
	WHERE (`encounter`.`encounter_type` = 9 AND `encounter`.`voided` = 0);

-- The date of the first On ARVs state for each patient
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `earliest_start_date` AS
  SELECT `p`.`patient_id` AS `patient_id`,`p`.`date_enrolled`,
         MIN(`s`.`start_date`) AS `earliest_start_date`, `person`.`death_date` AS death_date
  FROM ((`patient_program` `p`
  LEFT JOIN `patient_state` `s` ON((`p`.`patient_program_id` = `s`.`patient_program_id`)))
  LEFT JOIN `person` ON((`person`.`person_id` = `p`.`patient_id`)))
  WHERE ((`p`.`voided` = 0) AND (`s`.`voided` = 0) AND (`p`.`program_id` = 1) AND
        (`s`.`state` = 7))
  GROUP BY `p`.`patient_id`;

-- 7937 = Ever registered at ART clinic
CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `ever_registered_obs` AS
  SELECT `obs`.`obs_id` AS `obs_id`,
         `obs`.`person_id` AS `person_id`,
         `obs`.`concept_id` AS `concept_id`,
         `obs`.`encounter_id` AS `encounter_id`,
         `obs`.`order_id` AS `order_id`,
         `obs`.`obs_datetime` AS `obs_datetime`,
         `obs`.`location_id` AS `location_id`,
         `obs`.`obs_group_id` AS `obs_group_id`,
         `obs`.`accession_number` AS `accession_number`,
         `obs`.`value_group_id` AS `value_group_id`,
         `obs`.`value_boolean` AS `value_boolean`,
         `obs`.`value_coded` AS `value_coded`,
         `obs`.`value_coded_name_id` AS `value_coded_name_id`,
         `obs`.`value_drug` AS `value_drug`,
         `obs`.`value_datetime` AS `value_datetime`,
         `obs`.`value_numeric` AS `value_numeric`,
         `obs`.`value_modifier` AS `value_modifier`,
         `obs`.`value_text` AS `value_text`,
         `obs`.`date_started` AS `date_started`,
         `obs`.`date_stopped` AS `date_stopped`,
         `obs`.`comments` AS `comments`,
         `obs`.`creator` AS `creator`,
         `obs`.`date_created` AS `date_created`,
         `obs`.`voided` AS `voided`,
         `obs`.`voided_by` AS `voided_by`,
         `obs`.`date_voided` AS `date_voided`,
         `obs`.`void_reason` AS `void_reason`,
         `obs`.`value_complex` AS `value_complex`,
         `obs`.`uuid` AS `uuid`
  FROM `obs`
  WHERE ((`obs`.`concept_id` = 7937) AND (`obs`.`voided` = 0))
  AND (`obs`.`value_coded` = 1065);

CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `patient_pregnant_obs` AS
  SELECT `obs`.`obs_id` AS `obs_id`,
         `obs`.`person_id` AS `person_id`,
         `obs`.`concept_id` AS `concept_id`,
         `obs`.`encounter_id` AS `encounter_id`,
         `obs`.`order_id` AS `order_id`,
         `obs`.`obs_datetime` AS `obs_datetime`,
         `obs`.`location_id` AS `location_id`,
         `obs`.`obs_group_id` AS `obs_group_id`,
         `obs`.`accession_number` AS `accession_number`,
         `obs`.`value_group_id` AS `value_group_id`,
         `obs`.`value_boolean` AS `value_boolean`,
         `obs`.`value_coded` AS `value_coded`,
         `obs`.`value_coded_name_id` AS `value_coded_name_id`,
         `obs`.`value_drug` AS `value_drug`,
         `obs`.`value_datetime` AS `value_datetime`,
         `obs`.`value_numeric` AS `value_numeric`,
         `obs`.`value_modifier` AS `value_modifier`,
         `obs`.`value_text` AS `value_text`,
         `obs`.`date_started` AS `date_started`,
         `obs`.`date_stopped` AS `date_stopped`,
         `obs`.`comments` AS `comments`,
         `obs`.`creator` AS `creator`,
         `obs`.`date_created` AS `date_created`,
         `obs`.`voided` AS `voided`,
         `obs`.`voided_by` AS `voided_by`,
         `obs`.`date_voided` AS `date_voided`,
         `obs`.`void_reason` AS `void_reason`,
         `obs`.`value_complex` AS `value_complex`,
         `obs`.`uuid` AS `uuid` 
  FROM `obs`
  WHERE ((`obs`.`concept_id` IN (6131,1755)) AND
         (`obs`.`value_coded` = 1065) AND
         (`obs`.`voided` = 0));

CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `patient_state_on_arvs` AS
  SELECT `patient_state`.`patient_state_id` AS `patient_state_id`,
         `patient_state`.`patient_program_id` AS `patient_program_id`,
         `patient_state`.`state` AS `state`,
         `patient_state`.`start_date` AS `start_date`,
         `patient_state`.`end_date` AS `end_date`,
         `patient_state`.`creator` AS `creator`,
         `patient_state`.`date_created` AS `date_created`,
         `patient_state`.`changed_by` AS `changed_by`,
         `patient_state`.`date_changed` AS `date_changed`,
         `patient_state`.`voided` AS `voided`,
         `patient_state`.`voided_by` AS `voided_by`,
         `patient_state`.`date_voided` AS `date_voided`,
         `patient_state`.`void_reason` AS `void_reason`,
         `patient_state`.`uuid` AS `uuid`
  FROM `patient_state`
  WHERE (`patient_state`.`state` = 7 AND `patient_state`.`voided` = 0);

CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `regimen_observation` AS
  SELECT `obs`.`obs_id` AS `obs_id`,
         `obs`.`person_id` AS `person_id`,
         `obs`.`concept_id` AS `concept_id`,
         `obs`.`encounter_id` AS `encounter_id`,
         `obs`.`order_id` AS `order_id`,
         `obs`.`obs_datetime` AS `obs_datetime`,
         `obs`.`location_id` AS `location_id`,
         `obs`.`obs_group_id` AS `obs_group_id`,
         `obs`.`accession_number` AS `accession_number`,
         `obs`.`value_group_id` AS `value_group_id`,
         `obs`.`value_boolean` AS `value_boolean`,
         `obs`.`value_coded` AS `value_coded`,
         `obs`.`value_coded_name_id` AS `value_coded_name_id`,
         `obs`.`value_drug` AS `value_drug`,
         `obs`.`value_datetime` AS `value_datetime`,
         `obs`.`value_numeric` AS `value_numeric`,
         `obs`.`value_modifier` AS `value_modifier`,
         `obs`.`value_text` AS `value_text`,
         `obs`.`date_started` AS `date_started`,
         `obs`.`date_stopped` AS `date_stopped`,
         `obs`.`comments` AS `comments`,
         `obs`.`creator` AS `creator`,
         `obs`.`date_created` AS `date_created`,
         `obs`.`voided` AS `voided`,
         `obs`.`voided_by` AS `voided_by`,
         `obs`.`date_voided` AS `date_voided`,
         `obs`.`void_reason` AS `void_reason`,
         `obs`.`value_complex` AS `value_complex`,
         `obs`.`uuid` AS `uuid`
  FROM `obs`
  WHERE ((`obs`.`concept_id` = 2559) AND (`obs`.`voided` = 0));

CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER 
  VIEW `start_date_observation` AS 
  SELECT `obs`.`obs_id` AS `obs_id`,
         `obs`.`person_id` AS `person_id`,
         `obs`.`concept_id` AS `concept_id`,
         `obs`.`encounter_id` AS `encounter_id`,
         `obs`.`order_id` AS `order_id`,
         `obs`.`obs_datetime` AS `obs_datetime`,
         `obs`.`location_id` AS `location_id`,
         `obs`.`obs_group_id` AS `obs_group_id`,
         `obs`.`accession_number` AS `accession_number`,
         `obs`.`value_group_id` AS `value_group_id`,
         `obs`.`value_boolean` AS `value_boolean`,
         `obs`.`value_coded` AS `value_coded`,
         `obs`.`value_coded_name_id` AS `value_coded_name_id`,
         `obs`.`value_drug` AS `value_drug`,
         `obs`.`value_datetime` AS `value_datetime`,
         `obs`.`value_numeric` AS `value_numeric`,
         `obs`.`value_modifier` AS `value_modifier`,
         `obs`.`value_text` AS `value_text`,
         `obs`.`date_started` AS `date_started`,
         `obs`.`date_stopped` AS `date_stopped`,
         `obs`.`comments` AS `comments`,
         `obs`.`creator` AS `creator`,
         `obs`.`date_created` AS `date_created`,
         `obs`.`voided` AS `voided`,
         `obs`.`voided_by` AS `voided_by`,
         `obs`.`date_voided` AS `date_voided`,
         `obs`.`void_reason` AS `void_reason`,
         `obs`.`value_complex` AS `value_complex`,
         `obs`.`uuid` AS `uuid` 
  FROM `obs` 
  WHERE ((`obs`.`concept_id` = 2516) AND (`obs`.`voided` = 0));

CREATE OR REPLACE ALGORITHM=UNDEFINED  SQL SECURITY INVOKER
  VIEW `tb_status_observations` AS
  SELECT `obs`.`obs_id` AS `obs_id`,
         `obs`.`person_id` AS `person_id`,
         `obs`.`concept_id` AS `concept_id`,
         `obs`.`encounter_id` AS `encounter_id`,
         `obs`.`order_id` AS `order_id`,
         `obs`.`obs_datetime` AS `obs_datetime`,
         `obs`.`location_id` AS `location_id`,
         `obs`.`obs_group_id` AS `obs_group_id`,
         `obs`.`accession_number` AS `accession_number`,
         `obs`.`value_group_id` AS `value_group_id`,
         `obs`.`value_boolean` AS `value_boolean`,
         `obs`.`value_coded` AS `value_coded`,
         `obs`.`value_coded_name_id` AS `value_coded_name_id`,
         `obs`.`value_drug` AS `value_drug`,
         `obs`.`value_datetime` AS `value_datetime`,
         `obs`.`value_numeric` AS `value_numeric`,
         `obs`.`value_modifier` AS `value_modifier`,
         `obs`.`value_text` AS `value_text`,
         `obs`.`date_started` AS `date_started`,
         `obs`.`date_stopped` AS `date_stopped`,
         `obs`.`comments` AS `comments`,
         `obs`.`creator` AS `creator`,
         `obs`.`date_created` AS `date_created`,
         `obs`.`voided` AS `voided`,
         `obs`.`voided_by` AS `voided_by`,
         `obs`.`date_voided` AS `date_voided`,
         `obs`.`void_reason` AS `void_reason`,
         `obs`.`value_complex` AS `value_complex`,
         `obs`.`uuid` AS `uuid` 
  FROM `obs` 
  WHERE ((`obs`.`concept_id` = 7459) and (`obs`.`voided` = 0));

--
-- Dumping routines for database 'bart2'
--
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;
DROP FUNCTION IF EXISTS `age`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `age`(birthdate varchar(10),visit_date varchar(10),date_created varchar(10),est int) RETURNS int(11)
    DETERMINISTIC
BEGIN
DECLARE n INT;

DECLARE birth_month INT;
DECLARE birth_day INT;

DECLARE year_when_patient_created INT;

DECLARE cur_month INT;
DECLARE cur_year INT;

set birth_month = (SELECT MONTH(FROM_DAYS(TO_DAYS(birthdate))));
set birth_day = (SELECT DAY(FROM_DAYS(TO_DAYS(birthdate))));

set cur_month = (SELECT MONTH(CURDATE()));
set cur_year = (SELECT YEAR(CURDATE()));

set year_when_patient_created = (SELECT YEAR(FROM_DAYS(TO_DAYS(date_created))));

set n =  (SELECT DATE_FORMAT(FROM_DAYS(TO_DAYS(visit_date)-TO_DAYS(DATE(birthdate))), '%Y')+0);

if birth_month = 7 and birth_day = 1 and est = 1 and cur_month < birth_month and year_when_patient_created = cur_year then set n=(n + 1);
end if;

RETURN n;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `age_group`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `age_group`(birthdate varchar(10),visit_date varchar(10),date_created varchar(10),est int) RETURNS varchar(25) CHARSET latin1
    DETERMINISTIC
BEGIN
DECLARE avg VARCHAR(25);
DECLARE mths INT;
DECLARE n INT;

set avg="none";
set n =  (SELECT age(birthdate,visit_date,date_created,est));
set mths = (SELECT extract(MONTH FROM DATE(visit_date))-extract(MONTH FROM DATE(birthdate)));

if n >= 1 AND n < 5 then set avg="1 to < 5";
elseif n >= 5 AND n <= 14 then set avg="5 to 14";
elseif n > 14 AND n < 20 then set avg="> 14 to < 20";
elseif n >= 20 AND n < 30 then set avg="20 to < 30";
elseif n >= 30 AND n < 40 then set avg="30 to < 40";
elseif n >= 40 AND n < 50 then set avg="40 to < 50";
elseif n >= 50 then set avg="50 and above";
end if;

if mths >= 0 AND mths < 6 and avg="none" then set avg="< 6 months";
elseif mths >= 6 AND n < 12 and avg="none"then set avg="6 months to < 1 yr";
end if;

RETURN avg;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `current_defaulter`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `current_defaulter`(my_patient_id INT, my_end_date DATETIME) RETURNS int(1)
BEGIN
	DECLARE done INT DEFAULT FALSE;
	DECLARE my_start_date, my_expiry_date, my_obs_datetime DATETIME;
	DECLARE my_daily_dose, my_quantity INT;
	DECLARE flag INT;

	DECLARE cur1 CURSOR FOR SELECT o.start_date, d.equivalent_daily_dose daily_dose, d.quantity, o.start_date FROM drug_order d
		INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id		
		INNER JOIN orders o ON d.order_id = o.order_id
			AND d.quantity > 0
			AND o.voided = 0
			AND o.start_date <= my_end_date
			AND o.patient_id = my_patient_id;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

	SELECT MAX(o.start_date) INTO @obs_datetime FROM drug_order d
		INNER JOIN arv_drug ad ON d.drug_inventory_id = ad.drug_id		
		INNER JOIN orders o ON d.order_id = o.order_id
			AND d.quantity > 0
			AND o.voided = 0
			AND o.start_date <= my_end_date
			AND o.patient_id = my_patient_id
		GROUP BY o.patient_id;



	OPEN cur1;

	SET flag = 0;

	read_loop: LOOP
		FETCH cur1 INTO my_start_date, my_daily_dose, my_quantity, my_obs_datetime;

		IF done THEN
			CLOSE cur1;
			LEAVE read_loop;
		END IF;

		IF DATE(my_obs_datetime) = DATE(@obs_datetime) THEN
			SET @expiry_date = ADDDATE(my_start_date, (my_quantity/my_daily_dose));

			IF my_expiry_date IS NULL THEN
				SET my_expiry_date = @expiry_date;
			END IF;

			IF @expiry_date < my_expiry_date THEN
				SET my_expiry_date = @expiry_date;
				END IF;
				END IF;
			END LOOP;

			IF DATEDIFF(my_end_date, my_expiry_date) > 56 THEN
				SET flag = 1;
			END IF;
	RETURN flag;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `current_state_for_program`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `current_state_for_program`(my_patient_id INT, my_program_id INT, my_end_date DATETIME) RETURNS int(11)
BEGIN
  SET @state_id = NULL;
	SELECT  patient_program_id INTO @patient_program_id FROM patient_program 
			WHERE patient_id = my_patient_id 
				AND program_id = my_program_id 
				AND voided = 0 LIMIT 1;

	SELECT state INTO @state_id FROM patient_state 
		WHERE patient_program_id = @patient_program_id
			AND voided = 0
			AND start_date <= my_end_date
		ORDER BY start_date DESC, date_created DESC LIMIT 1;

	RETURN @state_id;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `current_text_for_obs`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `current_text_for_obs`(my_patient_id INT, my_encounter_type_id INT, my_concept_id INT, my_end_date DATETIME) RETURNS VARCHAR(255)
BEGIN
  SET @obs_value = NULL;
	SELECT encounter_id INTO @encounter_id FROM encounter 
		WHERE encounter_type = my_encounter_type_id 
			AND voided = 0
			AND patient_id = my_patient_id 
			AND encounter_datetime <= my_end_date 
		ORDER BY encounter_datetime DESC LIMIT 1;

	SELECT cn.name INTO @obs_value FROM obs o
			LEFT JOIN concept_name cn ON o.value_coded = cn.concept_id AND cn.concept_name_type = 'FULLY_SPECIFIED' 
		WHERE encounter_id = @encounter_id
			AND o.voided = 0 
			AND o.concept_id = my_concept_id 
			AND o.voided = 0 LIMIT 1;

	IF @obs_value IS NULL THEN
		SELECT value_text INTO @obs_value FROM obs
			WHERE encounter_id = @encounter_id
				AND voided = 0 
				AND concept_id = my_concept_id 
				AND voided = 0 LIMIT 1;
	END IF;

	IF @obs_value IS NULL THEN
		SELECT value_numeric INTO @obs_value FROM obs
			WHERE encounter_id = @encounter_id
				AND voided = 0 
				AND concept_id = my_concept_id 
				AND voided = 0 LIMIT 1;
	END IF;

	RETURN @obs_value;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `current_value_for_obs`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `current_value_for_obs`(my_patient_id INT, my_encounter_type_id INT, my_concept_id INT, my_end_date DATETIME) RETURNS int(11)
BEGIN
  SET @obs_value_coded = NULL;
	SELECT encounter_id INTO @encounter_id FROM encounter 
		WHERE encounter_type = my_encounter_type_id 
			AND voided = 0
			AND patient_id = my_patient_id 
			AND encounter_datetime <= my_end_date 
		ORDER BY encounter_datetime DESC LIMIT 1;

	SELECT value_coded INTO @obs_value_coded FROM obs
			WHERE encounter_id = @encounter_id
				AND voided = 0 
				AND concept_id = my_concept_id 
				AND voided = 0 LIMIT 1;

	RETURN @obs_value_coded;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `current_value_for_obs_at_initiation`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `current_value_for_obs_at_initiation`(my_patient_id INT, my_earliest_start_date DATETIME, my_encounter_type_id INT, my_concept_id INT, my_end_date DATETIME) RETURNS int(11)
BEGIN
	DECLARE obs_value_coded, my_encounter_id INT;

	SELECT encounter_id INTO my_encounter_id FROM encounter 
		WHERE encounter_type = my_encounter_type_id 
			AND voided = 0
			AND patient_id = my_patient_id 
			AND encounter_datetime <= ADDDATE(DATE(my_earliest_start_date), 1)
		ORDER BY encounter_datetime DESC LIMIT 1;

	IF my_encounter_id IS NULL THEN
		SELECT encounter_id INTO my_encounter_id FROM encounter 
			WHERE encounter_type = my_encounter_type_id 
				AND voided = 0
				AND patient_id = my_patient_id 
				AND encounter_datetime <= my_end_date 
                AND encounter_datetime >= ADDDATE(DATE(my_earliest_start_date), 1)
			ORDER BY encounter_datetime LIMIT 1;
	END IF;

	SELECT value_coded INTO obs_value_coded FROM obs
			WHERE encounter_id = my_encounter_id
				AND voided = 0 
				AND concept_id = my_concept_id 
				AND voided = 0 LIMIT 1;

	RETURN obs_value_coded;
END */;;
DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!50003 SET @saved_cs_client      = @@character_set_client */ ;
/*!50003 SET @saved_cs_results     = @@character_set_results */ ;
/*!50003 SET @saved_col_connection = @@collation_connection */ ;
/*!50003 SET character_set_client  = utf8 */ ;
/*!50003 SET character_set_results = utf8 */ ;
/*!50003 SET collation_connection  = utf8_general_ci */ ;
/*!50003 SET @saved_sql_mode       = @@sql_mode */ ;
/*!50003 SET sql_mode              = '' */ ;

DROP FUNCTION IF EXISTS `patient_start_date`;
DELIMITER ;;
/*!50003 CREATE*/ /*!50020 */ /*!50003 FUNCTION `patient_start_date`(patient_id int) RETURNS varchar(10) CHARSET latin1
    DETERMINISTIC
BEGIN
DECLARE start_date VARCHAR(10);
DECLARE dispension_concept_id INT;
DECLARE arv_concept INT;

set dispension_concept_id = (SELECT concept_id FROM concept_name WHERE name = 'AMOUNT DISPENSED');
set arv_concept = (SELECT concept_id FROM concept_name WHERE name = "ANTIRETROVIRAL DRUGS");

set start_date = (SELECT DATE(obs_datetime) FROM obs WHERE person_id = patient_id AND concept_id = dispension_concept_id AND value_drug IN (SELECT drug_id FROM drug d  WHERE d.concept_id IN (SELECT cs.concept_id FROM concept_set cs WHERE cs.concept_set = arv_concept)) ORDER BY obs_datetime DESC LIMIT 1);

RETURN start_date;
END */;;

DELIMITER ;
/*!50003 SET sql_mode              = @saved_sql_mode */ ;
/*!50003 SET character_set_client  = @saved_cs_client */ ;
/*!50003 SET character_set_results = @saved_cs_results */ ;
/*!50003 SET collation_connection  = @saved_col_connection */ ;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2012-05-03 21:13:17
