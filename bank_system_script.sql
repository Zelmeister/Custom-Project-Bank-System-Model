DROP DATABASE IF EXISTS bank_system;
CREATE DATABASE bank_system;
USE bank_system;




###	CLIENTS" TABLE
/* This is a table that contains data on clients – their client ID,
	first name, last name, sex, birth date, email, phone, city and the date
    on which they became our client. */
 
DROP TABLE IF EXISTS clients;
CREATE TABLE clients (
	client_id 		INT PRIMARY KEY AUTO_INCREMENT,		# Starting from 100001
    first_name		VARCHAR(50) NOT NULL,
    last_name		VARCHAR(50) NOT NULL,
    sex				ENUM('M', 'F'),						# M – male, F – female
    birth_date		DATE NOT NULL,
    email			VARCHAR(100) UNIQUE KEY NOT NULL,	# Each client has to have a unique email address
    phone			VARCHAR(50) UNIQUE KEY NOT NULL,	# Each client has to a have unique phone number
    city			VARCHAR(100) NOT NULL,				# I don't use the whole address to avoid potentially inserting a real person's address
    client_since	DATE NOT NULL,						# Date on which the particular client opened their first account
    client_until	DATE DEFAULT NULL					# This column is to be populated once a client stops using our bank's products (accounts)
);




###	FUNCTION 01: "F01_PROPER_CASE"
/*	Since MySQL, unlike Microsoft Excel, lacks a poper case function, I created such a function based on what was suggested on this forum:
    https://stackoverflow.com/questions/6181937/how-to-do-a-proper-case-formatting-of-a-mysql-column 
    The function is to be used for preventing entry errors on the "clients" table, such as non-capitalized city names. */
    
DROP FUNCTION IF EXISTS f01_proper_case;
DELIMITER $$
CREATE FUNCTION f01_proper_case(p_str VARCHAR(255))
RETURNS VARCHAR(255)
DETERMINISTIC NO SQL READS SQL DATA
BEGIN
	DECLARE chr VARCHAR(1);
	DECLARE oStr VARCHAR(255) DEFAULT '';
    DECLARE i INT DEFAULT 1;
    DECLARE `bool` INT DEFAULT 1;
    DECLARE punct CHAR(18) DEFAULT ' ()[]{},.-–_!@;:?/';
    
    WHILE i <= LENGTH(p_str) DO
		BEGIN
			SET chr = SUBSTRING(p_str, i, 1); 	
            IF LOCATE(chr, punct) > 0 THEN 		
				BEGIN
					SET `bool` = 1;
                    SET oStr = CONCAT(oStr, chr); 
				END;
			ELSEIF `bool` = 1 THEN
				BEGIN
					SET oStr = CONCAT(oStr, UPPER(chr));	
                    SET `bool` = 0;
				END;
			ELSE
				BEGIN
					SET oStr = CONCAT(oStr, LOWER(chr));
                END;
			END IF;
            SET i = i + 1;
		END;
	END WHILE;
    
    RETURN oStr;
END$$
DELIMITER ;




###	FUNCTION 02: "F02_CITY_PREPOSITION_CASE"
/*	Names of municipalities are usually capitalized in the Slovak language. However, if the name contains
	a preposition, the preposition is written in lower case. The following function distinguishes prepositions
    from other words in municiplaty names, and ensures that they written in lower case. */
    
DROP FUNCTION IF EXISTS f02_city_preposition_case;
DELIMITER $$
CREATE FUNCTION f02_city_preposition_case(p_city VARCHAR(255))
RETURNS VARCHAR(255)
DETERMINISTIC NO SQL READS SQL DATA
BEGIN
	DECLARE lPrep VARCHAR(255); # String left to the preposition
    DECLARE rPrep VARCHAR(255); # String right to the preposition
    
    IF p_city LIKE '% nad %' THEN
		BEGIN
			SET lPrep =  SUBSTRING(p_city, 1,  LOCATE(' nad ', p_city));
			SET rPrep = SUBSTRING(p_city, LOCATE(' nad ', p_city) + 4, LENGTH(p_city) - LOCATE(' nad ', p_city) + 4);
			SET p_city = CONCAT(lPrep, 'nad', rPrep);
		END;
	ELSEIF p_city LIKE '% pod %' THEN
		BEGIN
			SET lPrep =  SUBSTRING(p_city, 1,  LOCATE(' pod ', p_city));
			SET rPrep = SUBSTRING(p_city, LOCATE(' pod ', p_city) + 4, LENGTH(p_city) - LOCATE(' pod ', p_city) + 4);
			SET p_city = CONCAT(lPrep, 'pod', rPrep);
		END;
	ELSEIF p_city LIKE '% pred %' THEN
		BEGIN
			SET lPrep =  SUBSTRING(p_city, 1,  LOCATE(' pred ', p_city));
			SET rPrep = SUBSTRING(p_city, LOCATE(' pred ', p_city) + 5, LENGTH(p_city) - LOCATE(' pred ', p_city) + 5);
			SET p_city = CONCAT(lPrep, 'pred', rPrep);
		END;
	ELSEIF p_city LIKE '% pri %' THEN
		BEGIN
			SET lPrep =  SUBSTRING(p_city, 1,  LOCATE(' pri ', p_city));
			SET rPrep = SUBSTRING(p_city, LOCATE(' pri ', p_city) + 4, LENGTH(p_city) - LOCATE(' pri ', p_city) + 4);
			SET p_city = CONCAT(lPrep, 'pri', rPrep);
		END;
	ELSEIF p_city LIKE '% za %' THEN
		BEGIN
			SET lPrep =  SUBSTRING(p_city, 1,  LOCATE(' za ', p_city));
			SET rPrep = SUBSTRING(p_city, LOCATE(' za ', p_city) + 3, LENGTH(p_city) - LOCATE(' za ', p_city) + 3);
			SET p_city = CONCAT(lPrep, 'za', rPrep);
		END;
	ELSEIF p_city LIKE '% u %' THEN
		BEGIN
			SET lPrep =  SUBSTRING(p_city, 1,  LOCATE(' u ', p_city));
			SET rPrep = SUBSTRING(p_city, LOCATE(' u ', p_city) + 2, LENGTH(p_city) - LOCATE(' u ', p_city) + 2);
			SET p_city = CONCAT(lPrep, 'u', rPrep);
		END;
	ELSEIF p_city LIKE '% a %' THEN
		BEGIN
			SET lPrep =  SUBSTRING(p_city, 1,  LOCATE(' a ', p_city));
			SET rPrep = SUBSTRING(p_city, LOCATE(' a ', p_city) + 2, LENGTH(p_city) - LOCATE(' a ', p_city) + 2);
			SET p_city = CONCAT(lPrep, 'a', rPrep);
		END;
	ELSE 
		BEGIN
			SET p_city = p_city;
		END;
	END IF;
    
    RETURN p_city;
END$$
DELIMITER ;




### TRIGGER 01: "T01_GENERATE_CLIENT_ID"
/*	The purpose of this trigger is to auto-generate unique consecutive client IDs,
	starting from "100001", whenever a new client's record is created. */
    
DROP TRIGGER IF EXISTS t01_generate_client_id;
DELIMITER $$
CREATE TRIGGER t01_generate_client_id
BEFORE INSERT ON clients
FOR EACH ROW
BEGIN
	DECLARE max_id INT;
    
    SELECT MAX(client_id)
    INTO max_id
    FROM clients;
    
	IF max_id IS NOT NULL THEN
		SET NEW.client_id = max_id + 1;
	ELSE 
		SET NEW.client_id = 100001;
	END IF;
END$$
DELIMITER ;




###	TRIGGER 02: "T02_VERIFY_NEW_CLIENT_EMAIL
/*	The purpose of this trigger is to verify whether the email address, that is about to be
	inserted, complies with email address standards as far as allowed characters go.
    If the proposed email address doesn't comply with the standards, an error message will
    appear informing the user that "The email address contains invalid characters. Moreover,
    if the email address containts two "@" characters or multiple dots after "@", an error
	message will appear, stating "You have entered an invalid email address." */
    
DROP TRIGGER IF EXISTS t02_verify_new_client_email;
DELIMITER $$
CREATE TRIGGER t02_verify_new_client_email
BEFORE INSERT ON clients
FOR EACH ROW
BEGIN
	DECLARE allowed_Lchars CHAR(39) 						# Characters that are allowed in the local part of the email address (before '@')
		DEFAULT "0123456789abcdefghijklmnopqrstuvwxyz-._"; 	# While these are technically allowed "+~!#$%&‘/=^'{}|", many mail services,
															# servers and organizations don't accept them, thus I avoid them all together.
	
    DECLARE allowed_SLDchars CHAR(37) 						# Valid characters for the second-level domain (SLD) part of the email address 
		DEFAULT "0123456789abcdefghijklmnopqrstuvwxyz-";	# (after '@' and before '.')
        
	DECLARE allowed_TLDchars CHAR(27)						# Valid chacters for the top-level domain (TLD) part of the emial address (after '.')
		DEFAULT "abcdefghijklmnopqrstuvwxyz-";
	DECLARE Lchar_position INT DEFAULT 1;					# Variable for the local part's character position
    DECLARE SLDchar_position INT DEFAULT 1;					# Variable for the SLD part's character position
    DECLARE TLDchar_position INT DEFAULT 1;					# Variable for the TLD part's character position
    
    # Checks whether the email address contains only a single '@'
    IF (LENGTH(NEW.email) - LENGTH(REPLACE(NEW.email, '@', ''))) != 1
		THEN SIGNAL SQLSTATE '45000' 
		SET MESSAGE_TEXT = "You have entered an invalid email address.";
	END IF;
    
    # Checks whether the email address contains a dot after '@', separated at least by one character
    IF 	LOCATE('.', SUBSTRING_INDEX(NEW.email, '@', -1)) = 1 OR 
		(LENGTH(SUBSTRING_INDEX(NEW.email, '@', -1)) - LENGTH(REPLACE(SUBSTRING_INDEX(NEW.email, '@', -1), '.', ''))) != 1
		THEN SIGNAL SQLSTATE '45000' 
		SET MESSAGE_TEXT = "You have entered an invalid email address.";
	END IF;
    
    SET NEW.email = LOWER(NEW.email);	# To apply the standard of writing email addresses in lower case
    
    # This piece of code checks whether the local part contains only valid characters
    WHILE Lchar_position <= LENGTH(SUBSTRING_INDEX(NEW.email, '@', 1)) DO
		IF LOCATE(
			SUBSTRING(
				SUBSTRING_INDEX(NEW.email, '@', 1), Lchar_position, 1), allowed_Lchars) > 0 THEN
			SET Lchar_position = Lchar_position + 1;
		ELSE 
			SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'The email address contains invalid characters.';
		END IF;
	END WHILE;
    
	# This piece of code checks whether the SLD part contains only valid characters
	WHILE SLDchar_position <= LENGTH(SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.email, '@', -1), '.', 1)) DO
		IF LOCATE(
			SUBSTRING((
				SUBSTRING_INDEX(
					SUBSTRING_INDEX(NEW.email, '@', -1), '.', 1)), SLDchar_position, 1), allowed_SLDchars) > 0 THEN
			SET SLDchar_position = SLDchar_position + 1;
		ELSE 
			SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'The email address contains invalid characters.';
		END IF;
	END WHILE;
    
    # This piece of code checks whether the TLD part contains only valid characters
    WHILE TLDchar_position <= LENGTH(SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.email, '@', -1), '.', -1)) DO
		IF ((LOCATE(
			SUBSTRING((
				SUBSTRING_INDEX(
					SUBSTRING_INDEX(NEW.email, '@', -1), '.', -1)), TLDchar_position, 1), allowed_TLDchars) > 0) AND
			(((SUBSTRING((
					SUBSTRING_INDEX(
						SUBSTRING_INDEX(NEW.email, '@', -1), '.', -1)), 1, 1)) != '-') OR
            ((SUBSTRING((
				SUBSTRING_INDEX(
					SUBSTRING_INDEX(NEW.email, '@', -1), '.', -1)), 1, 1)) != '-'))) THEN
			SET TLDchar_position = TLDchar_position + 1;
		ELSE 
			SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'The email address contains invalid characters.';
		END IF;
    END WHILE;
END$$
DELIMITER ;



###	TRIGGER 03: "T03_VERIFY_UPDATED_CLIENT_EMAIL
/*	This trigger does the same job as "t2_verify_new_client_email",
	but upon updates. It checks whether an email address that is about
    contains only valid characters. */
    
DROP TRIGGER IF EXISTS t03_verify_updated_client_email;
DELIMITER $$
CREATE TRIGGER t03_verify_updated_client_email
BEFORE UPDATE ON clients
FOR EACH ROW
BEGIN
	DECLARE allowed_Lchars CHAR(39) 						# Characters that are allowed in the local part of the email address (before '@')
		DEFAULT "0123456789abcdefghijklmnopqrstuvwxyz-._"; 	# While these are technically allowed "+~!#$%&‘/=^'{}|", many mail services,
															# servers and organizations don't accept them, thus I avoid them all together.
	
    DECLARE allowed_SLDchars CHAR(37) 						# Valid characters for the second-level domain (SLD) part of the email address 
		DEFAULT "0123456789abcdefghijklmnopqrstuvwxyz-";	# (after '@' and before '.')
        
	DECLARE allowed_TLDchars CHAR(27)						# Valid chacters for the top-level domain (TLD) part of the emial address (after '.')
		DEFAULT "abcdefghijklmnopqrstuvwxyz-";
	DECLARE Lchar_position INT DEFAULT 1;					# Variable for the local part's character position
    DECLARE SLDchar_position INT DEFAULT 1;					# Variable for the SLD part's character position
    DECLARE TLDchar_position INT DEFAULT 1;					# Variable for the TLD part's character position
    
     # Checks whether the email address contains only a single '@'
    IF (LENGTH(NEW.email) - LENGTH(REPLACE(NEW.email, '@', ''))) = 1
		THEN SET NEW.email = NEW.email;
	ELSE 
		SIGNAL SQLSTATE '45000' 
		SET MESSAGE_TEXT = "You have entered an invalid email address.";
	END IF;
    
    # Checks whether the email address contains a dot after '@', separated at least by one character
    IF 	LOCATE('.', SUBSTRING_INDEX(NEW.email, '@', -1)) > 1 AND
		(LENGTH(SUBSTRING_INDEX(NEW.email, '@', -1)) - LENGTH(REPLACE(SUBSTRING_INDEX(NEW.email, '@', -1), '.', ''))) = 1
		THEN SET NEW.email = NEW.email;
	ELSE 
		SIGNAL SQLSTATE '45000' 
		SET MESSAGE_TEXT = "You have entered an invalid email address.";
	END IF;
    
    SET NEW.email = LOWER(NEW.email);		# To apply the standard of writing email addresses in lower case
    
    # This piece of code checks whether the local part contains only valid characters
    WHILE Lchar_position <= LENGTH(SUBSTRING_INDEX(NEW.email, '@', 1)) DO
		IF LOCATE(
			SUBSTRING(
				SUBSTRING_INDEX(NEW.email, '@', 1), Lchar_position, 1), allowed_Lchars) > 0 THEN
			SET Lchar_position = Lchar_position + 1;
		ELSE 
			SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'The email address contains invalid characters.';
		END IF;
	END WHILE;
    
	# This piece of code checks whether the SLD part contains only valid characters
	WHILE SLDchar_position <= LENGTH(SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.email, '@', -1), '.', 1)) DO
		IF LOCATE(
			SUBSTRING((
				SUBSTRING_INDEX(
					SUBSTRING_INDEX(NEW.email, '@', -1), '.', 1)), SLDchar_position, 1), allowed_SLDchars) > 0 THEN
			SET SLDchar_position = SLDchar_position + 1;
		ELSE 
			SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'The email address contains invalid characters.';
		END IF;
	END WHILE;
    
    # This piece of code checks whether the TLD part contains only valid characters
    WHILE TLDchar_position <= LENGTH(SUBSTRING_INDEX(SUBSTRING_INDEX(NEW.email, '@', -1), '.', -1)) DO
		IF ((LOCATE(
			SUBSTRING((
				SUBSTRING_INDEX(
					SUBSTRING_INDEX(NEW.email, '@', -1), '.', -1)), TLDchar_position, 1), allowed_TLDchars) > 0) AND
			(((SUBSTRING((
					SUBSTRING_INDEX(
						SUBSTRING_INDEX(NEW.email, '@', -1), '.', -1)), 1, 1)) != '-') OR
            ((SUBSTRING((
				SUBSTRING_INDEX(
					SUBSTRING_INDEX(NEW.email, '@', -1), '.', -1)), 1, 1)) != '-'))) THEN
			SET TLDchar_position = TLDchar_position + 1;
		ELSE 
			SIGNAL SQLSTATE '45000' 
            SET MESSAGE_TEXT = 'The email address contains invalid characters.';
		END IF;
    END WHILE;
END$$
DELIMITER ;




###	TRIGGER 04: "T04_CLEAN_NEW_CLIENT_PHONE"
/* 	This trigger cleans entry errors in the "phone" column in the "clients" table.
	It removes spaces between digits as well as common extra characters, like dots,
    slashes or dashes, and applies the standard "+421" code to Slovak phone numbers 
    – those that begin with +421, 00421 or 09##. Phone numbers with different prefixes 
    remain unchained. This is to allow other types of phone numbers as well. However, 
    the assumption is that these will be mostly Slovak, since the fictional bank is based 
    in Slovakia. In addition, if invalid characters, such as letters, are entered
    an error message will appear, saying "The phone number contains invalid characters." */
    
DROP TRIGGER IF EXISTS t04_clean_new_client_phone;
DELIMITER $$
CREATE TRIGGER t04_clean_new_client_phone
BEFORE INSERT ON clients
FOR EACH ROW
BEGIN
	DECLARE valid_char CHAR(12) DEFAULT '+0123456789'; # These are the valid characters for a phone number
    DECLARE char_position INT DEFAULT 1; # Character position in the phone number
    
    SET NEW.phone = REPLACE(NEW.phone, ' ', ''); # Removes spaces
    SET NEW.phone = REPLACE(NEW.phone, '.', ''); # Removes dots
    SET NEW.phone = REPLACE(NEW.phone, '/', ''); # Removes slashes
    SET NEW.phone = REPLACE(NEW.phone, '-', ''); # Removes dashes
    SET NEW.phone = REPLACE(NEW.phone, '(', ''); # Removes left parentheses
    SET NEW.phone = REPLACE(NEW.phone, ')', ''); # Removes right parentheses
    SET NEW.phone = REPLACE(NEW.phone, '#', ''); # Removes pound signs
    
    # This piece of code checks whether the new phone number contains only valid characters
    WHILE char_position <= LENGTH(NEW.phone) DO
		IF 		LOCATE(SUBSTRING(NEW.phone, char_position, 1), valid_char) > 0
				THEN SET char_position = char_position + 1;
		ELSE	SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'The phone number contains invalid characters.';
		END IF;
    END WHILE;
    
    # The following piece of code transofrms common ways of writing Slovak phone prefixes into the correct '+421' format
	IF		NEW.phone LIKE '00421%' OR
			NEW.phone LIKE '0421%' OR
            NEW.phone LIKE '421%' OR
            NEW.phone LIKE '+421%' OR
            NEW.phone LIKE '+0421%' OR
            NEW.phone LIKE '+00421%'
			THEN SET NEW.phone = CONCAT('+421', SUBSTRING_INDEX(NEW.phone , '421', -1));
	ELSEIF  NEW.phone LIKE '09%' OR
			NEW.phone LIKE '009%' OR
            NEW.phone LIKE '+09%' OR
            NEW.phone LIKE '+009%' 
			THEN SET NEW.phone = CONCAT('+4219', SUBSTRING_INDEX(NEW.phone , '09', -1));
	ELSE	SET NEW.phone = NEW.phone; # This is to allow non-Slovak phone numbers as well
    END IF;
END$$
DELIMITER ;




###	TRIGGER 05: "T05_CLEAN_UPDATED_CLIENT_PHONE"
/* 	Again, this is almost identical to "t04_clean_new_client_phone" with the only 
	difference being that the phone number clean-up takes place upon updating the 
    phone number instead of inserting a new one. */
    
DROP TRIGGER IF EXISTS t05_clean_updated_client_phone;
DELIMITER $$
CREATE TRIGGER t05_clean_updated_client_phone
BEFORE UPDATE ON clients
FOR EACH ROW
BEGIN
	DECLARE valid_char CHAR(12) DEFAULT '+0123456789'; # These are the valid characters for a phone number
    DECLARE char_position INT DEFAULT 1; # Character position in the phone number
    
    SET NEW.phone = REPLACE(NEW.phone, ' ', ''); # Removes spaces
    SET NEW.phone = REPLACE(NEW.phone, '.', ''); # Removes dots
    SET NEW.phone = REPLACE(NEW.phone, '/', ''); # Removes slashes
    SET NEW.phone = REPLACE(NEW.phone, '-', ''); # Removes dashes
    SET NEW.phone = REPLACE(NEW.phone, '(', ''); # Removes left parentheses
    SET NEW.phone = REPLACE(NEW.phone, ')', ''); # Removes right parentheses
    SET NEW.phone = REPLACE(NEW.phone, '#', ''); # Removes pound signs
    
    # This piece of code checks whether the new phone number contains only valid characters
    WHILE char_position <= LENGTH(NEW.phone) DO
		IF 		LOCATE(SUBSTRING(NEW.phone, char_position, 1), valid_char) > 0
				THEN SET char_position = char_position + 1;
		ELSE	SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'The phone number contains invalid characters.';
		END IF;
    END WHILE;
    
    # The following piece of code transofrms common ways of writing Slovak phone prefixes into the correct '+421' format
	IF		NEW.phone LIKE '00421%' OR
			NEW.phone LIKE '0421%' OR
            NEW.phone LIKE '421%' OR
            NEW.phone LIKE '+421%' OR
            NEW.phone LIKE '+0421%' OR
            NEW.phone LIKE '+00421%'
			THEN SET NEW.phone = CONCAT('+421', SUBSTRING_INDEX(NEW.phone , '421', -1));
	ELSEIF  NEW.phone LIKE '09%' OR
			NEW.phone LIKE '009%' OR
            NEW.phone LIKE '+09%' OR
            NEW.phone LIKE '+009%' 
			THEN SET NEW.phone = CONCAT('+4219', SUBSTRING_INDEX(NEW.phone , '09', -1));
	ELSE	SET NEW.phone = NEW.phone; # This is to allow non-Slovak phone numbers as well
    END IF;
END$$
DELIMITER ;




###	TRIGGER 06: "T06_CLEAN_NEW_CLIENT_CITY"
/*	This is essentially just an application of functions "f01_proper_case"
	and "f02_city_preposition_case" that were created earlier. The purpose
    is to have values in the "city" column written in proper case, with Slovak
    prepositions (nad, pod, pri, pred, za, u, a) in lower case, which is the
    standard way of writing Slovak municipality names. */
    
DROP TRIGGER IF EXISTS t06_clean_new_client_city;
DELIMITER $$
CREATE TRIGGER t06_clean_new_client_city
BEFORE INSERT ON clients
FOR EACH ROW
BEGIN
	SET NEW.city = f02_city_preposition_case(f01_proper_case(NEW.city));
END$$
DELIMITER ;




###	TRIGGER 07: "T07_CLEAN_UPDATED_CLIENT_CITY"
/*	Again, this is the same as "t06_clean_new_client_city", only applied
	to updates on the "clients" table, rather than inserts. */
    
DROP TRIGGER IF EXISTS t07_clean_updated_client_city;
DELIMITER $$
CREATE TRIGGER t07_clean_updated_client_city
BEFORE UPDATE ON clients
FOR EACH ROW
BEGIN
	SET NEW.city = f02_city_preposition_case(f01_proper_case(NEW.city));
END$$
DELIMITER ;




### PROCEDURE 01: "P01_REGISTER_NEW_CLIENT"
/*	This is a stored procedure, whose purpose is to register new clients.
	In other words, create a record to the "clients" table. Additionally,
    since a pre-condition for becoming a client is opening an account,
    an account record gets created based on what account has been specified
    in the form: personal account, student account or business account.
    Note: To open a savings accounts or a term deposit one has to have
    one of the aforementioned accounts. */
    
DROP PROCEDURE IF EXISTS p01_register_new_client;
DELIMITER $$
CREATE PROCEDURE p01_register_new_client (
	IN p_first_name		VARCHAR(50),
	IN p_last_name		VARCHAR(50),
    IN p_sex			ENUM('M','F'),
    IN p_birth_date		VARCHAR(50), # To allow people to use the Slovak standard → e.g. 01.02.2025 (the procedure will change it to 2025-02-01)
    IN p_email			VARCHAR(100),
    IN p_phone			VARCHAR(50),
    IN p_city			VARCHAR(100),
    IN p_account_type	ENUM('personal account', 'student account', 'business account'))						
BEGIN
	DECLARE p_client_id INT;
	
    SET @allow_client_insert = 1; # This is a boolean value defined in trigger t14; it's purpose is to prevent direct inserts on the "clients" table
    
	INSERT INTO clients VALUES (
		100000,	# This value gets corrected by trigger "t01_generate_client_id"
        p_first_name,
        p_last_name,
        p_sex,
        CASE	# MySQL will display warning about an incorrect date value; however, the following piece of code converts it to the correct format.
			WHEN p_birth_date LIKE '%.%.____'
				THEN DATE_FORMAT(STR_TO_DATE(p_birth_date, '%d.%m.%Y'), '%Y-%m-%d')
			WHEN p_birth_date LIKE '%/%/____'
				THEN DATE_FORMAT(STR_TO_DATE(p_birth_date, '%d/%m/%Y'), '%Y-%m-%d')
			WHEN p_birth_date LIKE '%-%-____'
				THEN DATE_FORMAT(STR_TO_DATE(p_birth_date, '%d-%m-%Y'), '%Y-%m-%d')
			WHEN p_birth_date LIKE '____-%-%'
				THEN STR_TO_DATE(p_birth_date, '%Y-%m-%d')
			ELSE NULL
		END,
        p_email,
        p_phone,
        p_city,
        DATE_FORMAT(CURRENT_TIMESTAMP(), '%Y-%m-%d'),
        NULL);
        
	SELECT client_id INTO p_client_id FROM clients
    WHERE 
		first_name = p_first_name AND
        last_name = p_last_name AND
        sex = p_sex AND
        birth_date = p_birth_date AND
        email = p_email AND
        phone = p_phone AND
        city = p_city;
		
	INSERT INTO accounts VALUES (
		'SK0000000000000000000000', # This value gets corrected by trigger "t10_generate_new_iban"
        p_client_id,
        p_account_type,
        DEFAULT,
        0,
        DATE_FORMAT(CURRENT_TIMESTAMP, '%Y-%m-%d'),
        DEFAULT
	);
    
    SET @allow_client_insert = 0;
END$$
DELIMITER ;




### TRIGGER 08: "T08_LOCK_CLIENT_ID"
/*	This trigger has been created to make sure that client_id
	is auto-generated only. In other words, client_id should
    not be updated manually. */

DROP TRIGGER IF EXISTS t08_lock_client_id;
DELIMITER $$
CREATE TRIGGER t08_lock_client_id
BEFORE UPDATE ON clients
FOR EACH ROW
BEGIN
	IF NEW.client_id != OLD.client_id THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Updates to client_id are not allowed.';
	END IF;
END$$
DELIMITER ;




### TRIGGER 09: "T09_LOCK_CLIENT_SINCE"
/*	This trigger has been created to make sure that client_since
	is auto-generated only. In other words, client_since should
    not be updated manually. */

DROP TRIGGER IF EXISTS t09_lock_client_since;
DELIMITER $$
CREATE TRIGGER t09_lock_client_since
BEFORE UPDATE ON clients
FOR EACH ROW
BEGIN
	IF NEW.client_since != OLD.client_since THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Updates to client_since are not allowed.';
	END IF;
END$$
DELIMITER ;




### PROCEDURE 02: "P02_UPDATE_CLIENT_RECORD"
/*	The clients' data sometimes needs to get updated, as people change
	their phone numbers, email addresses, move to different cities or we
    just need to correct a mistake in the entry. This procedure performs 
    an update to a specific client's record based on their client_id. */
    
DROP PROCEDURE IF EXISTS p02_update_client_record;
DELIMITER $$
CREATE PROCEDURE p02_update_client_record (
	IN p_client_id 		INT,		
    IN p_first_name		VARCHAR(50),
    IN p_last_name		VARCHAR(50),
    IN p_sex			ENUM('M', 'F'),						
    IN p_birth_date		VARCHAR(50), # To allow people to use the Slovak standard → e.g. 01.02.2025 (the procedure will change it to 2025-02-01)
    IN p_email			VARCHAR(100),	
    IN p_phone			VARCHAR(50),	
    IN p_city			VARCHAR(100))
BEGIN
    UPDATE clients
	SET first_name = p_first_name
	WHERE client_id = p_client_id;
    
	UPDATE clients
	SET last_name = p_last_name
	WHERE client_id = p_client_id;
    
	UPDATE clients
	SET sex = p_sex
	WHERE client_id = p_client_id;
    
	UPDATE clients
	SET birth_date = p_birth_date
	WHERE client_id = p_client_id;
    
	UPDATE clients
	SET email = p_email
	WHERE client_id = p_client_id;

	UPDATE clients
	SET phone = p_phone
	WHERE client_id = p_client_id;
    
	UPDATE clients
	SET city = p_city
	WHERE client_id = p_client_id;
END$$
DELIMITER ;



### "ACCOUNTS" TABLE
/*	This table contains data on accounts – IBAN, client id, account type,
	currency, balance and date of creation of the account. In IBAN we will
    use '9700' as our bank code, as it is currently not being used by any 
    Slovak bank. In addition, we will use internal codes for each type
    of account, which will be reflected in the beginning of the account
    number in IBAN – personal account (11), student account (22), business
    account (33), savings account (44) and term deposit (55). */

DROP TABLE IF EXISTS accounts;
CREATE TABLE accounts (
	iban			CHAR(24) NOT NULL PRIMARY KEY,
    client_id		INT NOT NULL,
    account_type	ENUM(
						'personal account', # Corresponds to Slovak "osobný účet"
                        'student account',	# Corresponds to Slovak "študentský účet"
                        'business account',	# Corresponds to Slovak "podnikateľský účet"
                        'savings account',	# Corresponds to Slovak "sporiaci účet"
                        'term deposit'),	# Corresponds to Slovak "osobný účet"
	currency		CHAR(3) NOT NULL DEFAULT 'EUR', # We'll use the three-letter currency codes as defined by ISO 4217 
	balance			DECIMAL(12, 2) NOT NULL DEFAULT 0,
    created_at		DATE NOT NULL,
    closed_at		DATE DEFAULT NULL,
    FOREIGN KEY (client_id) REFERENCES clients(client_id)
);




### TRIGGER 10: "T10_GENERATE_NEW_IBAN"
/*	This trigger generates a new IBAN whenever a new record is inserted into
	the "accounts" table. The IBAN follows the Slovak standards for IBANs – it starts 
	with "SK", which is followed by two check digits that are generated based on
    MOD 97, then followed by bank code ('9700' – fake bank code), and lastly the
    actual account number incremented by 1 with each new account. On top of this, the 
    account number begins with our internal two-digit code denoting account type, followed
    by 14 digits. */
    
DROP TRIGGER IF EXISTS t10_generate_new_iban;
DELIMITER $$
CREATE TRIGGER t10_generate_new_iban
BEFORE INSERT ON accounts
FOR EACH ROW
BEGIN
	DECLARE account_no VARCHAR(30);
    DECLARE check_digits INT;
    DECLARE max_account_no BIGINT;
	
    SET  @allow_accounts_update = 1; # This variable will be later used to prevent direct updates to the "accounts" table
    
	IF NEW.account_type = 'personal account' THEN
			SELECT MAX(RIGHT(iban, 16))
			INTO max_account_no
            FROM accounts
            WHERE account_type = 'personal account';
            
            IF max_account_no IS NULL THEN
				SET NEW.iban = 'SK2397001100000000000001';
			ELSE
				SET account_no = CONCAT(max_account_no + 1);
				SET check_digits = 98 - (CONCAT(account_no, 282000) MOD 97); # S → 28, K → 20, 00 → default check digits
				IF check_digits < 10 THEN
					SET NEW.iban = CONCAT('SK0', check_digits, '9700', account_no); 	
				ELSE
					SET NEW.iban = CONCAT('SK', check_digits, '9700', account_no); 	
				END IF;
			END IF;
	ELSEIF NEW.account_type = 'student account' THEN
			SELECT MAX(RIGHT(iban, 16))
			INTO max_account_no
            FROM accounts
            WHERE account_type = 'student account';
            
            IF max_account_no IS NULL THEN
				SET NEW.iban = 'SK9397002200000000000001';
			ELSE
				SET account_no = CONCAT(max_account_no + 1);
				SET check_digits = 98 - (CONCAT(account_no, 282000) MOD 97);
                
				IF check_digits < 10 THEN
					SET NEW.iban = CONCAT('SK0', check_digits, '9700', account_no); 	
				ELSE
					SET NEW.iban = CONCAT('SK', check_digits, '9700', account_no); 	
				END IF;
			END IF;
	ELSEIF NEW.account_type = 'business account' THEN
			SELECT MAX(RIGHT(iban, 16))
			INTO max_account_no
            FROM accounts
            WHERE account_type = 'business account';
            
			IF max_account_no IS NULL THEN					
				SET NEW.iban = 'SK6697003300000000000001';
			ELSE
				SET account_no = CONCAT(max_account_no + 1);
				SET check_digits = 98 - (CONCAT(account_no, 282000) MOD 97);
                
				IF check_digits < 10 THEN
					SET NEW.iban = CONCAT('SK0', check_digits, '9700', account_no); 	
				ELSE
					SET NEW.iban = CONCAT('SK', check_digits, '9700', account_no); 	
				END IF;
			END IF;
	ELSEIF NEW.account_type = 'savings account' THEN
			SELECT MAX(RIGHT(iban, 16))
			INTO max_account_no
            FROM accounts
            WHERE account_type = 'savings account';
            
			IF max_account_no IS NULL THEN
				SET NEW.iban = 'SK3997004400000000000001';
			ELSE
				SET account_no = CONCAT(max_account_no + 1);
				SET check_digits = 98 - (CONCAT(account_no, 282000) MOD 97);
                
				IF check_digits < 10 THEN
					SET NEW.iban = CONCAT('SK0', check_digits, '9700', account_no); 	
				ELSE
					SET NEW.iban = CONCAT('SK', check_digits, '9700', account_no); 	
				END IF;
			END IF;
	ELSEIF NEW.account_type = 'term deposit' THEN
			SELECT MAX(RIGHT(iban, 16))
			INTO max_account_no
            FROM accounts
            WHERE account_type = 'term deposit';
            
			IF max_account_no IS NULL THEN
				SET NEW.iban = 'SK1297005500000000000001';
			ELSE
				SET account_no = CONCAT(max_account_no + 1);
				SET check_digits = 98 - (CONCAT(account_no, 282000) MOD 97);
                
				IF check_digits < 10 THEN
					SET NEW.iban = CONCAT('SK0', check_digits, '9700', account_no); 	
				ELSE
					SET NEW.iban = CONCAT('SK', check_digits, '9700', account_no); 	
				END IF;
			END IF;
	END IF;
    
    SET @allow_accounts_update = 0; # Set to 0, because the IBAN update is done and no direct updates are allowed anymore
END$$
DELIMITER ;




### TRIGGER 11: "T11_PREVENT_DIRECT_ACCOUNT_UPDATES"
/*	The "accounts" table is expected to be updated by triggers (or procedures)
	only. In other words, there is no need for manual updates. All data will be
    updated automatically. This trigger prevents users from amending the "accounts"
    table directly. */

DROP TRIGGER IF EXISTS t11_prevent_direct_account_updates;
DELIMITER $$
CREATE TRIGGER t11_prevent_direct_account_updates
BEFORE UPDATE ON accounts
FOR EACH ROW
BEGIN
	# "@allow_accounts_update" is boolean variable, that switches on and off direct updateS to "accounts"
	IF @allow_accounts_update IS NULL OR @allow_accounts_update = 0 THEN 
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Direct updates to the "accounts" table are not allowed.';
	END IF;
END$$
DELIMITER ;




### TRIGGER 12: "T12_ACCOUNTS_AGE_RESTRICTIONS"
/*	This trigger checks if the applicant doesn't violate the age restrictions
	on opening of an account. Student accounts are available to clients aged
    15-26. Personal and business accounts are not available to clients under 18.
    In addition, there are no restrictions on savings accounts and term deposits. */

DROP TRIGGER IF EXISTS t12_accounts_age_restrictions
DELIMITER $$
CREATE TRIGGER t12_accounts_age_restrictions
BEFORE INSERT ON accounts
FOR EACH ROW
BEGIN
	DECLARE age VARCHAR(50);
    
    SELECT TIMESTAMPDIFF(YEAR, birth_date, CURDATE())
    INTO age FROM clients
    WHERE client_id = NEW.client_id;
    
    IF NEW.account_type = 'personal account' AND age < 18 THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Personal accounts are not available to clients under 18.';
	ELSEIF NEW.account_type = 'student account' AND age > 26 THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Student accounts are not avaible to clients over 26.';
	ELSEIF NEW.account_type = 'business account' AND age < 18 THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Business accounts are not available to clients under 18.';
	END IF;
END$$
DELIMITER ;




### TRIGGER 13: "T13_PREVENT_CLIENTS_UNDER_15"
/*	Our bank'đ internal regulation states that only people with a valid personal ID
	(občiansky preukaz) can open an account at our bank. In Slovakia, personal IDs
    are given to people from the age of 15, hence this trigger prevents an
    individual below this age limit from being registered. */

DROP TRIGGER IF EXISTS t13_prevent_clients_under_15;
DELIMITER $$
CREATE TRIGGER t13_prevent_clients_under_15
BEFORE INSERT ON clients
FOR EACH ROW
BEGIN
	IF TIMESTAMPDIFF(YEAR, NEW.birth_date, CURDATE()) < 15	THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'The bank does not offer services to individuals under 15.';
	END IF;
END$$
DELIMITER ;




### DATABASE "SOURCE_TABLES"
/* 	This database will store source tables that will be used for generating mock data
	on clients, accounts, transactions, etc. For the sake of clarity and tideness,
    I prefore to keep these tables in a separate database, bacause they are not 
    related to the ones in the "bank_system" database. */
DROP DATABASE source_tables;
CREATE DATABASE source_tables;




###	TABLE "SOURCE_TABLES.FIRST_NAMES"
/*	This table contains all possible first names that will be used to generate
	mock client first names. */

DROP TABLE IF EXISTS source_tables.first_names;
CREATE TABLE source_tables.first_names(
	first_name 	VARCHAR(50),
    sex			ENUM('M', 'F'));
    
INSERT INTO source_tables.first_names VALUES
	('Adam', 'M'),
	('Adela', 'F'),
	('Adolf', 'M'),
	('Adrián', 'M'),
	('Agáta', 'F'),
	('Agnesa', 'F'),
	('Alan', 'M'),
	('Alana', 'F'),
	('Albert', 'M'),
	('Albín', 'M'),
	('Alena', 'F'),
	('Aleš', 'M'),
	('Alexander', 'M'),
	('Alexandra', 'F'),
	('Alexej', 'M'),
	('Alfonz', 'M'),
	('Alfréd', 'M'),
	('Alojz', 'M'),
	('Alojzia', 'F'),
	('Alžbeta', 'F'),
	('Amália', 'F'),
	('Ambróz', 'M'),
	('Anabela', 'F'),
	('Anastázia', 'F'),
	('Andrej', 'M'),
	('Aneta', 'F'),
	('Anežka', 'F'),
	('Angela', 'F'),
	('Angelika', 'F'),
	('Anna', 'F'),
	('Anton', 'M'),
	('Antónia', 'F'),
	('Arnold', 'M'),
	('Arpád', 'M'),
	('Augustín', 'M'),
	('Aurélia', 'F'),
	('Barbara', 'F'),
	('Bartolomej', 'M'),
	('Beáta', 'F'),
	('Beňadik', 'M'),
	('Benjamín', 'M'),
	('Bernard', 'M'),
	('Berta', 'F'),
	('Bianka', 'F'),
	('Bibiána', 'F'),
	('Blahoslav', 'M'),
	('Blanka', 'F'),
	('Blažej', 'M'),
	('Blažena', 'F'),
	('Bohdan', 'M'),
	('Bohdana', 'F'),
	('Bohumil', 'M'),
	('Bohumila', 'F'),
	('Bohumír', 'M'),
	('Bohuslav', 'M'),
	('Bohuslava', 'F'),
	('Bohuš', 'M'),
	('Boleslav', 'M'),
	('Bonifác', 'M'),
	('Boris', 'M'),
	('Božena', 'F'),
	('Božidara', 'F'),
	('Branislav', 'M'),
	('Branislava', 'F'),
	('Brigita', 'F'),
	('Bruno', 'M'),
	('Bystrík', 'M'),
	('Cecília', 'F'),
	('Cyprián', 'M'),
	('Cyril', 'M'),
	('Dagmara', 'F'),
	('Dana', 'F'),
	('Danica', 'F'),
	('Daniel', 'M'),
	('Daniela', 'F'),
	('Darina', 'F'),
	('Dáša', 'F'),
	('Dávid', 'M'),
	('Demeter', 'M'),
	('Denis', 'M'),
	('Denisa', 'F'),
	('Dezider', 'M'),
	('Diana', 'F'),
	('Dionýz', 'M'),
	('Dobromila', 'F'),
	('Dobroslav', 'M'),
	('Dobroslava', 'F'),
	('Dominik', 'M'),
	('Dominika', 'F'),
	('Dorota', 'F'),
	('Drahomír', 'M'),
	('Drahoslava', 'F'),
	('Dušan', 'M'),
	('Dušana', 'F'),
	('Edita', 'F'),
	('Edmund', 'M'),
	('Eduard', 'M'),
	('Ela', 'F'),
	('Elena', 'F'),
	('Eleonóra', 'F'),
	('Eliáš', 'M'),
	('Eliška', 'F'),
	('Elvíra', 'F'),
	('Ema', 'F'),
	('Emanuel', 'M'),
	('Emil', 'M'),
	('Emília', 'F'),
	('Erik', 'M'),
	('Erika', 'F'),
	('Ernest', 'M'),
	('Ervín', 'M'),
	('Etela', 'F'),
	('Eugen', 'M'),
	('Eva', 'F'),
	('Fedor', 'M'),
	('Félix', 'M'),
	('Ferdinand', 'M'),
	('Filip', 'M'),
	('Filoména', 'F'),
	('Florián', 'M'),
	('František', 'M'),
	('Františka', 'F'),
	('Frederik', 'M'),
	('Frederika', 'F'),
	('Fridrich', 'M'),
	('Gabriel', 'M'),
	('Gabriela', 'F'),
	('Galina', 'F'),
	('Gašpar', 'M'),
	('Gejza', 'M'),
	('Gertrúda', 'F'),
	('Gizela', 'F'),
	('Gregor', 'M'),
	('Gréta', 'F'),
	('Gustáv', 'M'),
	('Hana', 'F'),
	('Hedviga', 'F'),
	('Henrieta', 'F'),
	('Henrich', 'M'),
	('Hermína', 'F'),
	('Hortenzia', 'F'),
	('Hubert', 'M'),
	('Hugo', 'M'),
	('Ida', 'F'),
	('Igor', 'M'),
	('Iľja', 'M'),
	('Imrich', 'M'),
	('Ingrida', 'F'),
	('Irena', 'F'),
	('Irma', 'F'),
	('Ivan', 'M'),
	('Ivana', 'F'),
	('Iveta', 'F'),
	('Ivica', 'F'),
	('Ivona', 'F'),
	('Izabela', 'F'),
	('Izidor', 'M'),
	('Jakub', 'M'),
	('Ján', 'M'),
	('Jarmila', 'F'),
	('Jarolím', 'M'),
	('Jaromír', 'M'),
	('Jaroslav', 'M'),
	('Jaroslava', 'F'),
	('Jela', 'F'),
	('Jerguš', 'M'),
	('Jesika', 'F'),
	('Jolana', 'F'),
	('Jozefína', 'F'),
	('Judita', 'F'),
	('Júlia', 'F'),
	('Juliana', 'F'),
	('Július', 'M'),
	('Juraj', 'M'),
	('Kamil', 'M'),
	('Kamila', 'F'),
	('Karina', 'F'),
	('Karol', 'M'),
	('Karolína', 'F'),
	('Katarína', 'F'),
	('Kazimír', 'M'),
	('Klaudia', 'F'),
	('Klaudius', 'M'),
	('Klement', 'M'),
	('Koloman', 'M'),
	('Konštantín', 'M'),
	('Kornel', 'M'),
	('Kornélia', 'F'),
	('Kristián', 'M'),
	('Kristína', 'F'),
	('Krištof', 'M'),
	('Kvetoslava', 'F'),
	('Ladislav', 'M'),
	('Ladislava', 'F'),
	('Laura', 'F'),
	('Lea', 'F'),
	('Lenka', 'F'),
	('Leonard', 'M'),
	('Leopold', 'M'),
	('Lesia', 'F'),
	('Levoslav', 'M'),
	('Liana', 'F'),
	('Libuša', 'F'),
	('Liliana', 'F'),
	('Linda', 'F'),
	('Lívia', 'F'),
	('Ľubica', 'F'),
	('Ľubomír', 'M'),
	('Ľubomíra', 'F'),
	('Ľubor', 'M'),
	('Ľuboslava', 'F'),
	('Ľuboš', 'M'),
	('Lucia', 'F'),
	('Ľudmila', 'F'),
	('Ľudomil', 'M'),
	('Ľudovít', 'M'),
	('Lujza', 'F'),
	('Lýdia', 'F'),
	('Magdaléna', 'F'),
	('Malvína', 'F'),
	('Marcel', 'M'),
	('Marek', 'M'),
	('Margaréta', 'F'),
	('Margita', 'F'),
	('Marián', 'M'),
	('Marianna', 'F'),
	('Marína', 'F'),
	('Mário', 'M'),
	('Marlena', 'F'),
	('Maroš', 'M'),
	('Marta', 'F'),
	('Martin', 'M'),
	('Martina', 'F'),
	('Matej', 'M'),
	('Mateo', 'M'),
	('Matilda', 'F'),
	('Matúš', 'M'),
	('Maximilián', 'M'),
	('Medard', 'M'),
	('Melánia', 'F'),
	('Metod', 'M'),
	('Michaela', 'F'),
	('Michal', 'M'),
	('Mikuláš', 'M'),
	('Milada', 'F'),
	('Milan', 'M'),
	('Milena', 'F'),
	('Milica', 'F'),
	('Miloslav', 'M'),
	('Miloslava', 'F'),
	('Miloš', 'M'),
	('Milota', 'F'),
	('Miriama', 'F'),
	('Miroslava', 'F'),
	('Monika', 'F'),
	('Nadežda', 'F'),
	('Natália', 'F'),
	('Nataša', 'F'),
	('Nikola', 'F'),
	('Nikolaj', 'M'),
	('Nina', 'F'),
	('Nora', 'F'),
	('Norbert', 'M'),
	('Oldrich', 'M'),
	('Oleg', 'M'),
	('Oľga', 'F'),
	('Oliver', 'M'),
	('Olívia', 'F'),
	('Olympia', 'F'),
	('Ondrej', 'M'),
	('Oskar', 'M'),
	('Otília', 'F'),
	('Oto', 'M'),
	('Oxana', 'F'),
	('Pankrác', 'M'),
	('Patrícia', 'F'),
	('Patrik', 'M'),
	('Paulína', 'F'),
	('Pavol', 'M'),
	('Perla', 'F'),
	('Peter', 'M'),
	('Petra', 'F'),
	('Petrana', 'F'),
	('Petronela', 'F'),
	('Pravoslav', 'M'),
	('Prokop', 'M'),
	('Radomír', 'M'),
	('Radoslava', 'F'),
	('Radovan', 'M'),
	('Radúz', 'M'),
	('Rastislav', 'M'),
	('Rebeka', 'F'),
	('Regina', 'F'),
	('René', 'M'),
	('Richard', 'M'),
	('Róbert', 'M'),
	('Róberta', 'F'),
	('Roland', 'M'),
	('Roman', 'M'),
	('Romana', 'F'),
	('Rozália', 'F'),
	('Rudolf', 'M'),
	('Rudolfa', 'F'),
	('Rút', 'F'),
	('Ružena', 'F'),
	('Sabína', 'F'),
	('Samuel', 'M'),
	('Sebastián', 'M'),
	('Sergej', 'M'),
	('Servác', 'M'),
	('Severín', 'M'),
	('Sidónia', 'F'),
	('Silvester', 'M'),
	('Silvia', 'F'),
	('Simona', 'F'),
	('Sláva', 'F'),
	('Slavomír', 'M'),
	('Slavomíra', 'F'),
	('Soňa', 'F'),
	('Stanislav', 'M'),
	('Stanislava', 'F'),
	('Stela', 'F'),
	('Svätopluk', 'M'),
	('Svetlana', 'F'),
	('Svetozár', 'M'),
	('Šimon', 'M'),
	('Štefan', 'M'),
	('Štefánia', 'F'),
	('Tadeáš', 'M'),
	('Tamara', 'F'),
	('Tatiana', 'F'),
	('Teodor', 'M'),
	('Terézia', 'F'),
	('Tibor', 'M'),
	('Tichomír', 'M'),
	('Timea', 'F'),
	('Timotej', 'M'),
	('Timur', 'M'),
	('Tomáš', 'M'),
	('Urban', 'M'),
	('Uršuľa', 'F'),
	('Václav', 'M'),
	('Valentín', 'M'),
	('Valentína', 'F'),
	('Valér', 'M'),
	('Valéria', 'F'),
	('Vasil', 'M'),
	('Vavrinec', 'M'),
	('Vendelín', 'M'),
	('Viera', 'F'),
	('Vieroslava', 'F'),
	('Viktor', 'M'),
	('Viliam', 'M'),
	('Vilma', 'F'),
	('Vincent', 'M'),
	('Viola', 'F'),
	('Vít', 'M'),
	('Víťazoslav', 'M'),
	('Vivien', 'F'),
	('Vladimír', 'M'),
	('Vladimíra', 'F'),
	('Vladislav', 'M'),
	('Vladislava', 'F'),
	('Vlasta', 'F'),
	('Vojtech', 'M'),
	('Vratislav', 'M'),
	('Vratko', 'M'),
	('Zdenka', 'F'),
	('Zdenko', 'M'),
	('Zina', 'F'),
	('Zita', 'F'),
	('Zlatica', 'F'),
	('Zlatko', 'M'),
	('Zoja', 'F'),
	('Zoltán', 'M'),
	('Zora', 'F'),
	('Zuzana', 'F'),
	('Žaneta', 'F'),
	('Žigmund', 'M'),
	('Žofia', 'F')
;




### TABLE "SOURCE_TABLES.LAST_NAMES"
/*	This table contains all possible last names that will be used to generate
	mock client first names. */

DROP TABLE IF EXISTS source_tables.last_names;
CREATE TABLE source_tables.last_names(
	last_name 	VARCHAR(50),
    sex			ENUM('M', 'F'));
    
INSERT INTO source_tables.last_names VALUES
	('Abrahám', 'M'),
	('Abrahámová', 'F'),
	('Adamcová', 'F'),
	('Adamec', 'M'),
	('Almáši', 'M'),
	('Almášiová', 'F'),
	('Andráši', 'M'),
	('Andrášiová', 'F'),
	('Bača', 'M'),
	('Bačová', 'F'),
	('Baďura', 'M'),
	('Baďurová', 'F'),
	('Bakoš', 'M'),
	('Bakošová', 'F'),
	('Baláž', 'M'),
	('Balážová', 'F'),
	('Bán', 'M'),
	('Bánová', 'F'),
	('Baran', 'M'),
	('Baranová', 'F'),
	('Bárta', 'M'),
	('Bartošík', 'M'),
	('Bartošíková', 'F'),
	('Bártová', 'F'),
	('Bartovič', 'M'),
	('Bartovičová', 'F'),
	('Baško', 'M'),
	('Bašková', 'F'),
	('Bednár', 'M'),
	('Bednárik', 'M'),
	('Bednáriková', 'F'),
	('Bednárová', 'F'),
	('Beňo', 'M'),
	('Beňová', 'F'),
	('Beňuš', 'M'),
	('Beňušová', 'F'),
	('Bezák', 'M'),
	('Bezáková', 'F'),
	('Bielik', 'M'),
	('Bieliková', 'F'),
	('Blaha', 'M'),
	('Blahová', 'F'),
	('Bobuľa', 'M'),
	('Bobuľová', 'F'),
	('Brunovská', 'F'),
	('Brunovský', 'M'),
	('Capko', 'M'),
	('Capková', 'F'),
	('Cibuľa', 'M'),
	('Cibuľka', 'M'),
	('Cibuľková', 'F'),
	('Cibuľová', 'F'),
	('Cíger', 'M'),
	('Cígerová', 'F'),
	('Čajkovič', 'M'),
	('Čajkovičová', 'F'),
	('Čapek', 'M'),
	('Čapeková', 'F'),
	('Čaplovič', 'M'),
	('Čaplovičová', 'F'),
	('Čekovská', 'F'),
	('Čekovský', 'M'),
	('Čierna', 'F'),
	('Čierny', 'M'),
	('Čobrda', 'M'),
	('Čobrdová', 'F'),
	('Danko', 'M'),
	('Danková', 'F'),
	('Daňo', 'M'),
	('Daňová', 'F'),
	('Debnár', 'M'),
	('Debnárová', 'F'),
	('Devečková', 'F'),
	('Dobšinská', 'F'),
	('Dobšinský', 'M'),
	('Doležal', 'M'),
	('Doležalová', 'F'),
	('Dostál', 'M'),
	('Dostálová', 'F'),
	('Drotár', 'M'),
	('Drotárová', 'F'),
	('Duboská', 'F'),
	('Dubovský', 'M'),
	('Duda', 'M'),
	('Dudová', 'F'),
	('Ďurek', 'M'),
	('Ďureková', 'F'),
	('Ďurica', 'M'),
	('Ďuricová', 'F'),
	('Ďuriš', 'M'),
	('Ďurišová', 'F'),
	('Ďurkovič', 'M'),
	('Ďurkovičová', 'F'),
	('Dušek', 'M'),
	('Dušeková', 'F'),
	('Dvorská', 'F'),
	('Dvorský', 'M'),
	('Farkaš', 'M'),
	('Farkašová', 'F'),
	('Farkašovská', 'F'),
	('Farkašovský', 'M'),
	('Feldek', 'M'),
	('Feldeková', 'F'),
	('Figuli', 'M'),
	('Figuli', 'F'),
	('Filc', 'M'),
	('Filcová', 'F'),
	('Fischer', 'M'),
	('Fischerová', 'F'),
	('Forgáč', 'M'),
	('Forgáčová', 'F'),
	('Fráňa', 'M'),
	('Franek', 'M'),
	('Franeková', 'F'),
	('Ftáčnik', 'M'),
	('Ftáčniková', 'F'),
	('Gál', 'M'),
	('Gálik', 'M'),
	('Gáliková', 'F'),
	('Gálová', 'F'),
	('Gažová', 'F'),
	('Hagara', 'M'),
	('Hagarová', 'F'),
	('Halušková', 'F'),
	('Hanák', 'M'),
	('Hečko', 'M'),
	('Hečková', 'F'),
	('Hladká', 'F'),
	('Hladký', 'M'),
	('Hošták', 'M'),
	('Hoštáková', 'F'),
	('Hraško', 'M'),
	('Hrašková', 'F'),
	('Hric', 'M'),
	('Hricová', 'F'),
	('Hruška', 'M'),
	('Hrušková', 'F'),
	('Hudáček', 'M'),
	('Hudáčeková', 'F'),
	('Hudec', 'M'),
	('Hudecová', 'F'),
	('Husár', 'M'),
	('Husárová', 'F'),
	('Chovan', 'M'),
	('Chovancová', 'F'),
	('Chovanec', 'M'),
	('Chovanová', 'F'),
	('Chudík', 'M'),
	('Chudíková', 'F'),
	('Jakab', 'M'),
	('Jakabová', 'F'),
	('Jakubcová', 'F'),
	('Jakubec', 'M'),
	('Janák', 'M'),
	('Janáková', 'F'),
	('Janek', 'M'),
	('Janeková', 'F'),
	('Jánošík', 'M'),
	('Jánošíková', 'F'),
	('Jurek', 'M'),
	('Kalusová', 'F'),
	('Karvaš', 'M'),
	('Karvašová', 'F'),
	('Klaus', 'M'),
	('Klíma', 'M'),
	('Klimek', 'M'),
	('Klimeková', 'F'),
	('Klímová', 'F'),
	('Klokoč', 'M'),
	('Klokočová', 'F'),
	('Kocián', 'M'),
	('Kociánová', 'F'),
	('Korcová', 'F'),
	('Korec', 'M'),
	('Kováč', 'M'),
	('Kováčik', 'M'),
	('Kováčová', 'F'),
	('Kovalčík', 'M'),
	('Kovalčíková', 'F'),
	('Kozáčik', 'M'),
	('Kozáčiková', 'F'),
	('Kozák', 'M'),
	('Kozáková', 'F'),
	('Kôstková', 'F'),
	('Krajčí', 'M'),
	('Krajčíová', 'F'),
	('Kráľ', 'M'),
	('Králik', 'M'),
	('Králiková', 'F'),
	('Kráľová', 'F'),
	('Krčméry', 'M'),
	('Krčméryová', 'F'),
	('Krejča', 'M'),
	('Krejčová', 'F'),
	('Kubcová', 'F'),
	('Kubec', 'M'),
	('Kyseľa', 'M'),
	('Kyseľová', 'F'),
	('Laco', 'M'),
	('Lacová', 'F'),
	('Lipa', 'M'),
	('Líška', 'M'),
	('Líšková', 'F'),
	('Ľupták', 'M'),
	('Ľuptáková', 'F'),
	('Macko', 'M'),
	('Macková', 'F'),
	('Majeská', 'F'),
	('Majeský', 'M'),
	('Makovická', 'F'),
	('Makovický', 'M'),
	('Marcin', 'M'),
	('Marcinek', 'M'),
	('Marcineková', 'F'),
	('Marcinová', 'F'),
	('Masarík', 'M'),
	('Masaríková', 'F'),
	('Medvecká', 'F'),
	('Medvecký', 'M'),
	('Mihál', 'M'),
	('Mihálik', 'M'),
	('Miháliková', 'F'),
	('Mihálová', 'F'),
	('Miller', 'M'),
	('Millerová', 'F'),
	('Mistrík', 'M'),
	('Mistríková', 'F'),
	('Mlynár', 'M'),
	('Mlynárik', 'M'),
	('Mlynáriková', 'F'),
	('Mlynárová', 'F'),
	('Moravcová', 'F'),
	('Moravčík', 'M'),
	('Moravčíková', 'F'),
	('Moravec', 'M'),
	('Mrázik', 'M'),
	('Mráziková', 'F'),
	('Mucha', 'M'),
	('Muchová', 'F'),
	('Murín', 'M'),
	('Murínová', 'F'),
	('Nemcová', 'F'),
	('Nemec', 'M'),
	('Novák', 'M'),
	('Nováková', 'F'),
	('Ondráš', 'M'),
	('Ondrášová', 'F'),
	('Országh', 'M'),
	('Országhová', 'F'),
	('Otčenáš', 'M'),
	('Otčenášová', 'F'),
	('Pálek', 'M'),
	('Páleková', 'F'),
	('Palkovič', 'M'),
	('Palkovičová', 'F'),
	('Petruška', 'M'),
	('Petrušková', 'F'),
	('Polák', 'M'),
	('Poláková', 'F'),
	('Porubjaková', 'F'),
	('Puškár', 'M'),
	('Révay', 'M'),
	('Révayová', 'F'),
	('Richtár', 'M'),
	('Richtárová', 'F'),
	('Rusnák', 'M'),
	('Rusnáková', 'F'),
	('Rybár', 'M'),
	('Rybárová', 'F'),
	('Rybníček', 'M'),
	('Rybníčková', 'F'),
	('Sebo', 'M'),
	('Sebová', 'F'),
	('Sedliak', 'M'),
	('Sedliaková', 'F'),
	('Sidor', 'M'),
	('Sidorová', 'F'),
	('Sklár', 'M'),
	('Sklárová', 'F'),
	('Sklenár', 'M'),
	('Sklenárová', 'F'),
	('Sloboda', 'M'),
	('Slobodová', 'F'),
	('Slovák', 'M'),
	('Slováková', 'F'),
	('Stodolová', 'F'),
	('Sýkora', 'M'),
	('Sýkorová', 'F'),
	('Šebo', 'M'),
	('Šebová', 'F'),
	('Šimeček', 'M'),
	('Šimečková', 'F'),
	('Šimko', 'M'),
	('Šimková', 'F'),
	('Šťastná', 'F'),
	('Šťastný', 'M'),
	('Štefánik', 'M'),
	('Štefániková', 'F'),
	('Štrba', 'M'),
	('Štrbová', 'F'),
	('Švehla', 'M'),
	('Švehlová', 'F'),
	('Ťapák', 'M'),
	('Ťapáková', 'F'),
	('Tatarka', 'M'),
	('Tatarková', 'F'),
	('Toman', 'M'),
	('Tomanová', 'F'),
	('Topoľská', 'F'),
	('Topoľský', 'M'),
	('Ursíny', 'M'),
	('Ursínyová', 'F'),
	('Vajda', 'M'),
	('Vajdová', 'F'),
	('Záborská', 'F'),
	('Záborský', 'M'),
	('Zachar', 'M'),
	('Zacharová', 'F'),
	('Zajac', 'M'),
	('Zajacová', 'F'),
	('Zúbko', 'M'),
	('Zúbková', 'F'),
	('Železník', 'M'),
	('Železníková', 'F')
;




### TABLE "SOURCE_TABLES.AGE_BUCKETS"
/*	This table will help me generate clients' birth dates based on a random
	selection with weights of the selection following the real Slovak demografics. */

DROP TABLE IF EXISTS source_tables.age_buckets;
CREATE TABLE source_tables.age_buckets (
	lower_int	FLOAT,
    upper_int	FLOAT,
    lower_age	INT,
    upper_age	INT);

INSERT INTO source_tables.age_buckets VALUES
(0, 0.0605, 15, 19),
(0.0605, 0.1173, 20, 24),
(0.1173, 0.1807, 25, 29),
(0.1807, 0.2606, 30, 34),
(0.2606, 0.3497, 35, 39),
(0.3497, 0.4438, 40, 44),
(0.4438, 0.5422, 45, 49),
(0.5422, 0.6280, 50, 54),
(0.6280, 0.7018, 55, 59),
(0.7018, 0.7767, 60, 64),
(0.7767, 0.8499, 65, 69),
(0.8499, 0.9140, 70, 74),
(0.9140, 0.9560, 75, 79),
(0.9560, 0.9812, 80, 84),
(0.9812, 0.9939, 85, 89),
(0.9939, 0.9986, 90, 94),
(0.9986, 0.9997, 95, 99),
(0.9997, 1, 100, 105)
;




### FUNCTION 03: "F03_REMOVE_DIACRITICS"
-- 	Removes Slovak diacritic marks from a string.

DROP FUNCTION IF EXISTS f03_remove_diacritics;
DELIMITER $$
CREATE FUNCTION f03_remove_diacritics(p_string VARCHAR(255)) RETURNS VARCHAR(255)
DETERMINISTIC NO SQL READS SQL DATA
BEGIN
	SET p_string = REPLACE(p_string, 'á', 'a');
    SET p_string = REPLACE(p_string, 'é', 'e');
    SET p_string = REPLACE(p_string, 'í', 'i');
    SET p_string = REPLACE(p_string, 'ó', 'o');
    SET p_string = REPLACE(p_string, 'ú', 'u');
    SET p_string = REPLACE(p_string, 'ý', 'y');
    SET p_string = REPLACE(p_string, 'ĺ', 'l');
    SET p_string = REPLACE(p_string, 'ŕ', 'r');
    SET p_string = REPLACE(p_string, 'č', 'c');
    SET p_string = REPLACE(p_string, 'ď', 'd');
    SET p_string = REPLACE(p_string, 'ľ', 'l');
    SET p_string = REPLACE(p_string, 'ň', 'n');
    SET p_string = REPLACE(p_string, 'š', 's');
    SET p_string = REPLACE(p_string, 'ť', 't');
    SET p_string = REPLACE(p_string, 'ž', 'z');
    SET p_string = REPLACE(p_string, 'ä', 'a');
    SET p_string = REPLACE(p_string, 'ô', 'o');
	SET p_string = REPLACE(p_string, 'Á', 'A');
    SET p_string = REPLACE(p_string, 'É', 'E');
    SET p_string = REPLACE(p_string, 'Í', 'I');
    SET p_string = REPLACE(p_string, 'Ó', 'O');
    SET p_string = REPLACE(p_string, 'Ú', 'U');
    SET p_string = REPLACE(p_string, 'Ý', 'Y');
    SET p_string = REPLACE(p_string, 'Ĺ', 'L');
    SET p_string = REPLACE(p_string, 'Ŕ', 'R');
    SET p_string = REPLACE(p_string, 'Č', 'C');
    SET p_string = REPLACE(p_string, 'Ď', 'D');
    SET p_string = REPLACE(p_string, 'Ľ', 'L');
    SET p_string = REPLACE(p_string, 'Ň', 'N');
    SET p_string = REPLACE(p_string, 'Š', 'S');
    SET p_string = REPLACE(p_string, 'Ť', 'T');
    SET p_string = REPLACE(p_string, 'Ž', 'Z');
    SET p_string = REPLACE(p_string, 'Ä', 'A');
    SET p_string = REPLACE(p_string, 'Ô', 'O');
    
    RETURN p_string;
END$$
DELIMITER ;




### TABLE "SOURCE_TABLES.CITIES"
/*	This is a table based on which clients' cities are generated. It contains
	200 largest Slovak municipalities with weights defined as intervals that
    follow the real population ratios between these municipalities. */
    
DROP TABLE IF EXISTS source_tables.cities ;
CREATE TABLE source_tables.cities (
	city		VARCHAR(100),
    lower_int	FLOAT,
    upper_int	FLOAT
);

INSERT INTO source_tables.cities VALUES
	('Bratislava', 0, 0.149),
	('Košice', 0.149, 0.2207),
	('Prešov', 0.2207, 0.2473),
	('Žilina', 0.2473, 0.2732),
	('Nitra', 0.2732, 0.2978),
	('Banská Bystrica', 0.2978, 0.3216),
	('Trnava', 0.3216, 0.3416),
	('Trenčín', 0.3416, 0.3588),
	('Martin', 0.3588, 0.3752),
	('Poprad', 0.3752, 0.3908),
	('Prievidza', 0.3908, 0.405),
	('Zvolen', 0.405, 0.4177),
	('Považská Bystrica', 0.4177, 0.4298),
	('Nové Zámky', 0.4298, 0.4416),
	('Michalovce', 0.4416, 0.4531),
	('Spišská Nová Ves', 0.4531, 0.4642),
	('Komárno', 0.4642, 0.4746),
	('Levice', 0.4746, 0.4846),
	('Humenné', 0.4846, 0.4944),
	('Bardejov', 0.4944, 0.5041),
	('Liptovský Mikuláš', 0.5041, 0.5136),
	('Piešťany', 0.5136, 0.5223),
	('Ružomberok', 0.5223, 0.5309),
	('Lučenec', 0.5309, 0.539),
	('Topoľčany', 0.539, 0.5469),
	('Pezinok', 0.5469, 0.5547),
	('Čadca', 0.5547, 0.562),
	('Trebišov', 0.562, 0.5693),
	('Dunajská Streda', 0.5693, 0.5765),
	('Dubnica nad Váhom', 0.5765, 0.5836),
	('Rimavská Sobota', 0.5836, 0.5905),
	('Partizánske', 0.5905, 0.5972),
	('Vranov nad Topľou', 0.5972, 0.6039),
	('Šaľa', 0.6039, 0.6105),
	('Hlohovec', 0.6105, 0.617),
	('Senec', 0.617, 0.6233),
	('Brezno', 0.6233, 0.6296),
	('Senica', 0.6296, 0.6358),
	('Nové Mesto nad Váhom', 0.6358, 0.6419),
	('Malacky', 0.6419, 0.6479),
	('Snina', 0.6479, 0.6537),
	('Dolný Kubín', 0.6537, 0.6594),
	('Žiar nad Hronom', 0.6594, 0.6649),
	('Rožňava', 0.6649, 0.6704),
	('Púchov', 0.6704, 0.6759),
	('Bánovce nad Bebravou', 0.6759, 0.6813),
	('Handlová', 0.6813, 0.6864),
	('Stará Ľubovňa', 0.6864, 0.6914),
	('Sereď', 0.6914, 0.6963),
	('Skalica', 0.6963, 0.7012),
	('Kežmarok', 0.7012, 0.7061),
	('Galanta', 0.7061, 0.7108),
	('Kysucké Nové Mesto', 0.7108, 0.7154),
	('Levoča', 0.7154, 0.7198),
	('Detva', 0.7198, 0.7242),
	('Šamorín', 0.7242, 0.7285),
	('Stupava', 0.7285, 0.7324),
	('Sabinov', 0.7324, 0.7363),
	('Zlaté Moravce', 0.7363, 0.74),
	('Revúca', 0.74, 0.7436),
	('Bytča', 0.7436, 0.7472),
	('Holíč', 0.7472, 0.7507),
	('Veľký Krtíš', 0.7507, 0.7542),
	('Myjava', 0.7542, 0.7576),
	('Nová Dubnica', 0.7576, 0.761),
	('Kolárovo', 0.761, 0.7643),
	('Moldava nad Bodvou', 0.7643, 0.7676),
	('Svidník', 0.7676, 0.7708),
	('Stropkov', 0.7708, 0.7739),
	('Fiľakovo', 0.7739, 0.777),
	('Štúrovo', 0.777, 0.7801),
	('Banská Štiavnica', 0.7801, 0.7831),
	('Šurany', 0.7831, 0.7861),
	('Modra', 0.7861, 0.789),
	('Tvrdošín', 0.789, 0.7918),
	('Smižany', 0.7918, 0.7946),
	('Bernolákovo', 0.7946, 0.7974),
	('Veľké Kapušany', 0.7974, 0.8001),
	('Krompachy', 0.8001, 0.8029),
	('Stará Turá', 0.8029, 0.8056),
	('Vráble', 0.8056, 0.8083),
	('Sečovce', 0.8083, 0.811),
	('Veľký Meder', 0.811, 0.8136),
	('Svit', 0.8136, 0.816),
	('Námestovo', 0.816, 0.8185),
	('Dunajská Lužná', 0.8185, 0.8208),
	('Krupina', 0.8208, 0.8232),
	('Vrútky', 0.8232, 0.8256),
	('Kráľovský Chlmec', 0.8256, 0.8279),
	('Hurbanovo', 0.8279, 0.8303),
	('Šahy', 0.8303, 0.8325),
	('Jarovnice', 0.8325, 0.8348),
	('Turzovka', 0.8348, 0.8371),
	('Trstená', 0.8371, 0.8393),
	('Hriňová', 0.8393, 0.8416),
	('Liptovský Hrádok', 0.8416, 0.8438),
	('Nová Baňa', 0.8438, 0.846),
	('Ivanka pri Dunaji', 0.846, 0.8482),
	('Tornaľa', 0.8482, 0.8504),
	('Chorvátsky Grob', 0.8504, 0.8525),
	('Hnúšťa', 0.8525, 0.8546),
	('Želiezovce', 0.8546, 0.8568),
	('Krásno nad Kysucou', 0.8568, 0.8588),
	('Spišská Belá', 0.8588, 0.8609),
	('Lipany', 0.8609, 0.863),
	('Veľký Šariš', 0.863, 0.865),
	('Turčianske Teplice', 0.865, 0.867),
	('Nemšová', 0.867, 0.869),
	('Beluša', 0.869, 0.8709),
	('Medzilaborce', 0.8709, 0.8728),
	('Gelnica', 0.8728, 0.8746),
	('Svätý Jur', 0.8746, 0.8765),
	('Rajec', 0.8765, 0.8784),
	('Sobrance', 0.8784, 0.8802),
	('Čaňa', 0.8802, 0.882),
	('Žarnovica', 0.882, 0.8839),
	('Vrbové', 0.8839, 0.8857),
	('Oščadnica', 0.8857, 0.8875),
	('Raková', 0.8875, 0.8892),
	('Ilava', 0.8892, 0.891),
	('Zákamenné', 0.891, 0.8927),
	('Sládkovičovo', 0.8927, 0.8944),
	('Lendak', 0.8944, 0.8961),
	('Poltár', 0.8961, 0.8978),
	('Šenkvice', 0.8978, 0.8994),
	('Skalité', 0.8994, 0.9011),
	('Gabčíkovo', 0.9011, 0.9027),
	('Slovenský Grob', 0.9027, 0.9043),
	('Tvrdošovce', 0.9043, 0.9059),
	('Rabča', 0.9059, 0.9076),
	('Rovinka', 0.9076, 0.9092),
	('Veľká Lomnica', 0.9092, 0.9108),
	('Dobšiná', 0.9108, 0.9124),
	('Čierny Balog', 0.9124, 0.914),
	('Nesvady', 0.914, 0.9155),
	('Dvory nad Žitavou', 0.9155, 0.9171),
	('Šaštín-Stráže', 0.9171, 0.9187),
	('Bojnice', 0.9187, 0.9202),
	('Kremnica', 0.9202, 0.9218),
	('Gbely', 0.9218, 0.9233),
	('Sliač', 0.9233, 0.9248),
	('Brezová pod Bradlom', 0.9248, 0.9264),
	('Rudňany', 0.9264, 0.9279),
	('Sučany', 0.9279, 0.9293),
	('Veľké Úľany', 0.9293, 0.9308),
	('Markušovce', 0.9308, 0.9322),
	('Pavlovce nad Uhom', 0.9322, 0.9337),
	('Cífer', 0.9337, 0.9351),
	('Ľubica', 0.9351, 0.9365),
	('Valaliky', 0.9365, 0.9379),
	('Čierne', 0.9379, 0.9393),
	('Teplička nad Váhom', 0.9393, 0.9407),
	('Močenok', 0.9407, 0.942),
	('Veľké Zálužie', 0.942, 0.9434),
	('Cabaj-Čápor', 0.9434, 0.9447),
	('Strážske', 0.9447, 0.9461),
	('Palárikovo', 0.9461, 0.9474),
	('Komjatice', 0.9474, 0.9487),
	('Trenčianska Teplá', 0.9487, 0.9501),
	('Nováky', 0.9501, 0.9514),
	('Turany', 0.9514, 0.9527),
	('Medzev', 0.9527, 0.954),
	('Šoporňa', 0.954, 0.9553),
	('Bošany', 0.9553, 0.9565),
	('Jelka', 0.9565, 0.9578),
	('Kúty', 0.9578, 0.9591),
	('Štiavnik', 0.9591, 0.9603),
	('Terchová', 0.9603, 0.9616),
	('Giraltovce', 0.9616, 0.9628),
	('Miloslavov', 0.9628, 0.9641),
	('Trenčianske Teplice', 0.9641, 0.9653),
	('Kanianka', 0.9653, 0.9666),
	('Oravská Polhora', 0.9666, 0.9678),
	('Leopoldov', 0.9678, 0.9691),
	('Lednické Rovne', 0.9691, 0.9703),
	('Borský Mikuláš', 0.9703, 0.9715),
	('Nižná', 0.9715, 0.9728),
	('Most pri Bratislave', 0.9728, 0.974),
	('Veľká Ida', 0.974, 0.9752),
	('Vysoké Tatry', 0.9752, 0.9764),
	('Varín', 0.9764, 0.9777),
	('Malinovo', 0.9777, 0.9789),
	('Trstice', 0.9789, 0.9801),
	('Bystrany', 0.9801, 0.9813),
	('Lehota pod Vtáčnikom', 0.9813, 0.9825),
	('Marcelová', 0.9825, 0.9837),
	('Kecerovce', 0.9837, 0.9849),
	('Spišské Podhradie', 0.9849, 0.9861),
	('Hanušovce nad Topľou', 0.9861, 0.9872),
	('Tisovec', 0.9872, 0.9884),
	('Veľké Leváre', 0.9884, 0.9896),
	('Tešedíkovo', 0.9896, 0.9907),
	('Liptovské Sliače', 0.9907, 0.9919),
	('Novoť', 0.9919, 0.9931),
	('Okoč', 0.9931, 0.9942),
	('Čachtice', 0.9942, 0.9954),
	('Turňa nad Bodvou', 0.9954, 0.9965),
	('Bánov', 0.9965, 0.9977),
	('Veľké Rovné', 0.9977, 0.9989),
	('Ľubotice', 0.9989, 1);


   

### FUNCTION 04: "F04_GENERATE_FAKE_IBAN"
/*	This function generates a fake Slovak IBAN, with fake bank coded of "9999".
	These fake IBANs will be useful in generating transactions for our mock clients. */
    
DROP FUNCTION IF EXISTS f04_generate_fake_iban
DELIMITER $$
CREATE FUNCTION f04_generate_fake_iban() RETURNS CHAR(24)
DETERMINISTIC NO SQL READS SQL DATA
BEGIN
	DECLARE p_iban CHAR(24);
    
    SELECT
		CONCAT(
			'SK',
			(98 - (CONCAT(
				FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10),
				FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10),
				FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10),
				FLOOR(RAND()*10)) 
				MOD 97)),
			'9999',
			(CONCAT(
				FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10),
				FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10),
				FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10), FLOOR(RAND()*10),
				FLOOR(RAND()*10))))
	INTO p_iban;
    
    RETURN p_iban;
END$$
DELIMITER ;



   
### PROCEDURE 03: "P03_GENERATE_NEW_CLIENT"
/*	Since I am not working with a real world dataset, I needed some way of populating my
	tables with mock data. Procedure "p03_generate_new_client" does just the thing. 
    It generates mock first name, last name, sex, birth date, email, phone and city and
    inserts this data onto the "clients" table. The procedure also creates either a personal 
    account or a student account for each newly created client based on age conditions: 
    15-17 → student account; 18-26 → 35% student account, 65% personal account; 
    27+ → personal account. In addition, it generates each client's monthly incomes
    (allowance, salary, social benefits, pension) and regular expenses (rent
    payments, mortgage payments, bill payments, subscription payments). This data is stored
    in "source_tables.regular_transactions". */

DROP PROCEDURE IF EXISTS p03_generate_new_client;
DELIMITER $$
CREATE PROCEDURE p03_generate_new_client()
BEGIN
	DECLARE seed 				DOUBLE;
    DECLARE p_sex 				ENUM('M', 'F');
    DECLARE p_first_name 		VARCHAR(50);
    DECLARE p_last_name 		VARCHAR(50);
    DECLARE p_birth_date 		DATE;
    DECLARE domain 				VARCHAR(100);
    DECLARE p_email 			VARCHAR(100);
    DECLARE p_phone 			VARCHAR(50);
    DECLARE p_city 				VARCHAR(100);
    DECLARE p_client_id 		INT;
    DECLARE p_primary_income	VARCHAR(100);
    DECLARE p_secondary_income	VARCHAR(100);
    DECLARE p_account_type		VARCHAR(100);
	DECLARE seed1 				DOUBLE;
    DECLARE seed2 				DOUBLE;
    DECLARE p_prim_income_worth DECIMAL(12, 2);
    DECLARE p_sec_income_worth	DECIMAL(12, 2);
    DECLARE p_expense_name		VARCHAR(100);
    DECLARE p_expense_value		DECIMAL(12, 2);
    DECLARE p_total_income		DECIMAL(12, 2);
    DECLARE p_num_payments		INTEGER;
    DECLARE p_agg_expenses		DECIMAL(12, 2);
    DECLARE p_clients_account	CHAR(24);
    DECLARE p_opposite_account	CHAR(24);
    DECLARE p_due_day			INT;
    DECLARE p1					DOUBLE;
    DECLARE p2					DOUBLE;
    DECLARE p3					DOUBLE;
    DECLARE p4					DOUBLE;
    DECLARE p5					DOUBLE;
    DECLARE p6					DOUBLE;
	DECLARE p7					DOUBLE;
    DECLARE p8					DOUBLE;

	
    SET @allow_client_insert = 1;
    
    # Generating random sex
    SET seed = RAND();
    IF seed < 0.5 THEN
		SET p_sex = 'M';
		ELSE SET p_sex = 'F';
    END IF;
	
    # Generating random first name
    SET seed = RAND();
	IF p_sex = 'M' THEN
		SELECT fn.first_name
		INTO p_first_name
		FROM
			(SELECT first_name, 
					sex,
					ROW_NUMBER() OVER(PARTITION BY sex) AS row_num
			FROM source_tables.first_names
			WHERE sex = 'M') fn
		WHERE row_num = FLOOR(seed * 185) + 1;
	ELSEIF p_sex = 'F' THEN
		SELECT fn.first_name
		INTO p_first_name
		FROM
			(SELECT first_name, 
					sex,
					ROW_NUMBER() OVER(PARTITION BY sex) AS row_num
			FROM source_tables.first_names
			WHERE sex = 'F') fn
		WHERE row_num = FLOOR(seed * 195) + 1;
	END IF;
    
    # Generating random last name
    SET seed = RAND();
	SELECT sn.last_name
	INTO p_last_name
	FROM
		(SELECT last_name, 
				sex,
				ROW_NUMBER() OVER(PARTITION BY sex) AS row_num
		FROM source_tables.last_names
		WHERE sex = p_sex) sn
	WHERE row_num = FLOOR(seed * 162) + 1;
    
    # Genrating random birth date
    SET seed = RAND();
    SELECT DATE_ADD(DATE_ADD(CURDATE(), INTERVAL - upper_age YEAR),
					INTERVAL FLOOR(RAND() * (TIMESTAMPDIFF(DAY,
						DATE_ADD(CURDATE(), INTERVAL - upper_age YEAR),
						DATE_ADD(CURDATE(), INTERVAL - lower_age YEAR)))) DAY) AS birth_date
	INTO p_birth_date
    FROM source_tables.age_buckets
    WHERE seed >= lower_int AND seed < upper_int;

	# Generating fake email domain
    SET seed = RAND();
    IF seed < 0.3 THEN
		SET domain = '@fakemail.com';
	ELSEIF seed >= 0.3 AND seed < 0.5 THEN
		SET domain = '@fakemail.sk';
	ELSEIF seed >= 0.5 AND seed < 0.8 THEN
		SET domain = '@fictmail.com';
	ELSEIF seed >= 0.8 THEN
		SET domain = '@fakebox.sk';
	END IF;
    
	# Generating fake email address
    SET seed = RAND();
    IF seed < 0.2 THEN
		SET p_email = CONCAT(
			LOWER(f03_remove_diacritics(p_first_name)), 
            '.', 
            LOWER(f03_remove_diacritics(p_last_name)), 
            SUBSTRING(p_birth_date, 3, 2), 
            domain);
	ELSEIF seed >= 0.2 AND seed < 0.4 THEN
		SET p_email = CONCAT(
			LOWER(f03_remove_diacritics(p_first_name)), 
            '.', 
            LOWER(f03_remove_diacritics(p_last_name)), 
            YEAR(p_birth_date), 
            domain);
	ELSEIF seed >= 0.4 AND seed < 0.6 THEN
		SET p_email = CONCAT(
			LEFT(LOWER(f03_remove_diacritics(p_first_name)), 1), 
            '.', 
            LOWER(f03_remove_diacritics(p_last_name)), 
            SUBSTRING(p_birth_date, 3, 2), 
            domain);
	ELSEIF seed >= 0.6 AND seed < 0.8 THEN
		SET p_email = CONCAT(
			LEFT(LOWER(f03_remove_diacritics(p_first_name)), 1), 
            '.', 
            LOWER(f03_remove_diacritics(p_last_name)), 
            YEAR(p_birth_date), 
            domain);
	ELSEIF seed >= 0.8 AND seed < 1 THEN
		SET p_email = CONCAT(
			LOWER(f03_remove_diacritics(p_last_name)), 
            '.', 
            LOWER(f03_remove_diacritics(p_first_name)), 
            SUBSTRING(p_birth_date, 3, 2), 
            domain);
	END IF;
    
    # Generating fake phone numbers
    SET p_phone = CONCAT(
		'+421900',				# +421900 is used, because '900' is not used by any Slovak phone services operators
        FLOOR(10 * RAND()), 
        FLOOR(10 * RAND()),
        FLOOR(10 * RAND()),
        FLOOR(10 * RAND()),
        FLOOR(10 * RAND()),
        FLOOR(10 * RAND())
	);
    
    # Generating a random Slovak city (more precisely municipality)
	SET seed = RAND();
    SELECT city
	INTO p_city
    FROM source_tables.cities
    WHERE seed >= lower_int AND seed < upper_int;
    
    # Insert the generated values
    INSERT INTO clients VALUES (
		100000,
        p_first_name,
        p_last_name,
        p_sex,
        p_birth_date,
        p_email,
        p_phone,
        p_city,
        DATE_FORMAT(CURRENT_TIMESTAMP, '%Y-%m-%d'),
        NULL);
        
	# Set the p_client_id parameter
	SELECT client_id 
    INTO p_client_id 
    FROM clients
    WHERE 
		first_name = p_first_name AND
        last_name = p_last_name AND
        sex = p_sex AND
        birth_date = p_birth_date AND
        email = p_email AND
        phone = p_phone AND
        city = p_city;
    
    # Generating client's first account: 15-17 → student account; 18-26 → 35% student account, 65% personal account; 26< → personal account
    # Note: For the student account one has to be below 26 and have a student status
    SET seed = RAND();
    IF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) < 18 THEN
		INSERT INTO accounts VALUES ('SK0000000000000000000000', p_client_id, 'student account', DEFAULT, DEFAULT, DATE_FORMAT(CURRENT_TIMESTAMP, '%Y-%m-%d'), DEFAULT);
	ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) >= 18 AND TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) <= 26 THEN
		IF seed < 0.35 THEN
			INSERT INTO accounts VALUES ('SK0000000000000000000000', p_client_id, 'student account', DEFAULT, DEFAULT, DATE_FORMAT(CURRENT_TIMESTAMP, '%Y-%m-%d'), DEFAULT);
		ELSEIF seed >= 0.35 THEN
			INSERT INTO accounts VALUES ('SK0000000000000000000000', p_client_id, 'personal account', DEFAULT, DEFAULT, DATE_FORMAT(CURRENT_TIMESTAMP, '%Y-%m-%d'), DEFAULT);
		END IF;
	ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) > 26 THEN
		INSERT INTO accounts VALUES ('SK0000000000000000000000', p_client_id, 'personal account', DEFAULT, DEFAULT, DATE_FORMAT(CURRENT_TIMESTAMP, '%Y-%m-%d'), DEFAULT);
	END IF;
    
    SELECT a.account_type
	INTO p_account_type
    FROM accounts a
    WHERE a.client_id = p_client_id;
    
    # Generating the type of regular income (allowance, salary, social benefits, pension)
    SET seed = RAND();
    IF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 15 AND 17 THEN
		IF seed < 0.20 THEN
			SET p_primary_income = '1/2 salary';
		ELSEIF seed >= 0.20 THEN
			SET p_primary_income = 'allowance';
		END IF;
    ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 18 AND 26 THEN
		IF p_account_type = 'student account' THEN
			IF seed < 0.20 THEN
				SET p_primary_income = 'full salary';
			ELSEIF seed >= 0.20 AND seed < 0.60 THEN
				SET p_primary_income = '1/2 salary';
			ELSEIF seed >= 0.60 THEN
				SET p_primary_income = 'allowance';
			END IF;
        ELSEIF p_account_type = 'personal account' THEN
			IF p_sex = 'M' THEN
				IF seed < 0.80 THEN
					SET p_primary_income = 'full salary';
				ELSEIF seed >= 0.80 AND seed < 0.90 THEN
					SET p_primary_income = '1/2 salary';
				ELSEIF seed >= 0.90 THEN
					SET p_primary_income = 'social benefits';
				END IF;
            ELSEIF p_sex = 'F' THEN
				IF seed < 0.60 THEN
					SET p_primary_income = 'full salary';
				ELSEIF seed >= 0.60 AND seed < 0.70 THEN
					SET p_primary_income = '1/2 salary';
				ELSEIF seed >= 0.70 THEN
					SET p_primary_income = 'social benefits';
				END IF;
            END IF;
        END IF;
    ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 27 AND 39 THEN
		IF p_sex = 'M' THEN
			IF seed < 0.85 THEN
				SET p_primary_income = 'full salary';
			ELSEIF seed >= 0.85 AND seed < 0.95 THEN
				SET p_primary_income = '1/2 salary';
                SET seed = RAND();
                IF	seed < 0.50 THEN
					SET p_secondary_income = '1/2 benefits';
				ELSE
					SET p_secondary_income = NULL;
				END IF;
			ELSEIF seed >= 0.95 THEN
				SET p_primary_income = 'social benefits';
			END IF;
		ELSEIF p_sex = 'F' THEN
			IF seed < 0.60 THEN
				SET p_primary_income = 'full salary';
			ELSEIF seed >= 0.60 AND seed < 0.80 THEN
				SET p_primary_income = '1/2 salary';
                SET seed = RAND();
                IF	seed < 0.75 THEN
					SET p_secondary_income = '1/2 benefits';
				ELSE
					SET p_secondary_income = NULL;
				END IF;
			ELSEIF seed >= 0.80 THEN
				SET p_primary_income = 'social benefits';
			END IF;		
        END IF;
    ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 40 AND 49 THEN
		IF p_sex = 'M' THEN
			IF seed < 0.85 THEN
				SET p_primary_income = 'full salary';
			ELSEIF seed >= 0.85 AND seed < 0.95 THEN
				SET p_primary_income = '1/2 salary';
                SET seed = RAND();
                IF	seed < 0.50 THEN
					SET p_secondary_income = '1/2 benefits';
				ELSE
					SET p_secondary_income = NULL;
				END IF;
			ELSEIF seed >= 0.95 THEN
				SET p_primary_income = 'social benefits';
			END IF;			
        ELSEIF p_sex = 'F' THEN
			IF seed < 0.80 THEN
				SET p_primary_income = 'full salary';
			ELSEIF seed >= 0.80 AND seed < 0.85 THEN
				SET p_primary_income = '1/2 salary';
                SET seed = RAND();
                IF	seed < 0.75 THEN
					SET p_secondary_income = '1/2 benefits';
				ELSE
					SET p_secondary_income = NULL;
				END IF;
			ELSEIF seed >= 0.85 THEN
				SET p_primary_income = 'social benefits';
			END IF;
        END IF;
    ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 50 AND 64 THEN
		IF seed < 0.65 THEN
			SET p_primary_income = 'full salary';
            SET seed = RAND();
            IF seed < 0.10 THEN
				SET p_secondary_income = '1/2 benefits';
			ELSE
				SET p_secondary_income = NULL;
			END IF;
        ELSEIF seed >= 0.65 AND seed < 0.80 THEN
			SET p_primary_income = '1/2 salary';
            SET seed = RAND();
            IF seed < 0.40 THEN
				SET p_secondary_income = '1/2 benefits';
			ELSE
				SET p_secondary_income = NULL;
			END IF;
        ELSEIF seed >= 0.80 THEN
			SET p_primary_income = 'social benefits';
        END IF;
    ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 65 AND 74 THEN
	IF p_sex = 'M' THEN
			IF seed < 0.25 THEN
				SET p_primary_income = 'full salary';
                SET seed = RAND();
                IF seed < 0.20 THEN
					SET p_secondary_income = '1/2 benefits';
				ELSE
					SET p_secondary_income = NULL;
				END IF;
			ELSEIF seed >= 0.25 AND seed < 0.35 THEN
				SET p_primary_income = '1/2 salary';
                SET seed = RAND();
                IF	seed < 0.40 THEN
					SET p_secondary_income = '1/2 benefits';
				ELSE
					SET p_secondary_income = NULL;
				END IF;
			ELSEIF seed >= 0.35 THEN
				SET p_primary_income = 'pension';
                SET seed = RAND();
                IF seed < 0.50 THEN
					SET p_secondary_income = '1/2 benefits';
				ELSE
					SET p_secondary_income = NULL;
				END IF;
			END IF;			
        ELSEIF p_sex = 'F' THEN
			IF seed < 0.15 THEN
				SET p_primary_income = 'full salary';
                SET seed = RAND();
                IF seed < 0.20 THEN
					SET p_secondary_income = '1/2 benefits';
				ELSE
					SET p_secondary_income = NULL;
				END IF;
			ELSEIF seed >= 0.15 AND seed < 0.25 THEN
				SET p_primary_income = '1/2 salary';
                SET seed = RAND();
                IF	seed < 0.40 THEN
					SET p_secondary_income = '1/2 benefits';
				ELSE
					SET p_secondary_income = NULL;
				END IF;
			ELSEIF seed >= 0.25 THEN
				SET p_primary_income = 'pension';
                SET seed = RAND();
                IF seed < 0.50 THEN
					SET p_secondary_income = '1/2 benefits';
				ELSE
					SET p_secondary_income = NULL;
				END IF;
			END IF;
		END IF;
    ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 75 AND 84 THEN
		IF seed < 0.10 THEN
			SET p_primary_income = '1/2 salary';
            SET seed = RAND();
            IF seed < 0.40 THEN
				SET p_secondary_income = '1/2 benefits';
			ELSE
				SET p_secondary_income = NULL;
			END IF;
		ELSEIF seed >= 0.10 THEN
			SET p_primary_income = 'pension';
            SET seed = RAND();
            IF seed < 0.60 THEN
				SET p_secondary_income = '1/2 benefits';
			ELSE
				SET p_secondary_income = NULL;
			END IF;
		END IF;
    ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) >= 85 THEN
		SET p_primary_income = 'pension';
		SET seed = RAND();
		IF seed < 0.70 THEN
			SET p_secondary_income = '1/2 benefits';
		ELSE
			SET p_secondary_income = NULL;
		END IF; 
    END IF;
    
    # Now we need to generate actual values for the incomes; "source_tables.income_rates_distribution" will be employed
    # I'll start with primary incomes:
    SET seed1 = RAND();
    SET seed2 = RAND();
    
	IF p_primary_income = 'allowance' AND TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 15 AND 17 THEN
		SELECT ROUND(lower_eur + seed1 * (upper_eur - lower_eur), 2)
		INTO p_prim_income_worth
		FROM source_tables.income_rates_distribution
		WHERE 
			income_type = 'allowance 15-17' AND
			seed2 >= lower_int AND
			seed2 < upper_int;
	ELSEIF p_primary_income = 'allowance' AND TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 18 AND 26 THEN
		SELECT ROUND(lower_eur + seed1 * (upper_eur - lower_eur), 2)
		INTO p_prim_income_worth
		FROM source_tables.income_rates_distribution
		WHERE 
			income_type = 'allowance 18-26' AND
			seed2 >= lower_int AND
			seed2 < upper_int;
	ELSEIF p_primary_income = 'full salary' THEN
		SELECT ROUND(lower_eur + seed1 * (upper_eur - lower_eur), 2)
		INTO p_prim_income_worth
		FROM source_tables.income_rates_distribution
		WHERE 
			income_type = 'salary' AND
			seed2 >= lower_int AND
			seed2 < upper_int;
	ELSEIF p_primary_income = '1/2 salary' THEN
		SELECT ROUND(((lower_eur + seed1 * (upper_eur - lower_eur)) / 2), 2)
		INTO p_prim_income_worth
		FROM source_tables.income_rates_distribution
		WHERE 
			income_type = 'salary' AND
			seed2 >= lower_int AND
			seed2 < upper_int;	
	ELSEIF p_primary_income = 'social benefits' THEN
		SELECT ROUND(lower_eur + seed1 * (upper_eur - lower_eur), 2)
		INTO p_prim_income_worth
		FROM source_tables.income_rates_distribution
		WHERE 
			income_type = 'social benefits' AND
			seed2 >= lower_int AND
			seed2 < upper_int;	
	ELSEIF p_primary_income = 'pension' THEN
		SELECT ROUND(lower_eur + seed1 * (upper_eur - lower_eur), 2)
		INTO p_prim_income_worth
		FROM source_tables.income_rates_distribution
		WHERE 
			income_type = 'pension' AND
			seed2 >= lower_int AND
			seed2 < upper_int;
	END IF;
    
    # Now the same needs to be done for secondary incomes as well
    SET seed1 = RAND();
    SET seed2 = RAND();
    IF p_secondary_income = '1/2 benefits' THEN
		SELECT ROUND(((lower_eur + seed1 * (upper_eur - lower_eur)) / 2), 2)
        INTO p_sec_income_worth
        FROM source_tables.income_rates_distribution
        WHERE
			income_type = 'social benefits' AND
			seed2 >= lower_int AND
			seed2 < upper_int;
	ELSEIF p_secondary_income = NULL THEN
		SET p_sec_income_worth = NULL;
	END IF;
    
    # Insert the generated data on regular income into "source_tables.regular_transactions"
    SELECT iban
    INTO p_clients_account
    FROM accounts
    WHERE 
		(account_type = 'personal account' OR account_type = 'student account') AND
        client_id = p_client_id;
        
	SET p_opposite_account = f04_generate_fake_iban();
    SET p_due_day = FLOOR(RAND()*28) + 1;
    
    -- First, the primary income
    IF p_primary_income = 'allowance' THEN
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since)
		VALUES (p_client_id, 'EUR', p_prim_income_worth, 1, p_clients_account, p_opposite_account, p_due_day, CURDATE());
    ELSEIF p_primary_income = 'full salary' OR p_primary_income = '1/2 salary' THEN
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since)
		VALUES (p_client_id, 'EUR', p_prim_income_worth, 2, p_clients_account, p_opposite_account, p_due_day, CURDATE());
	ELSEIF p_primary_income = 'social benefits' THEN
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since)
		VALUES (p_client_id, 'EUR', p_prim_income_worth, 3, p_clients_account, p_opposite_account, p_due_day, CURDATE());
	ELSEIF p_primary_income = 'pension' THEN
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since)
		VALUES (p_client_id, 'EUR', p_prim_income_worth, 4, p_clients_account, p_opposite_account, p_due_day, CURDATE());
	END IF;
    
	-- Secondly, the secondary income
	SET p_opposite_account = f04_generate_fake_iban();
    SET p_due_day = FLOOR(RAND()*28) + 1;
    
	IF p_secondary_income = '1/2 benefits' THEN
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since)
		VALUES (p_client_id, 'EUR', p_sec_income_worth, 3, p_clients_account, p_opposite_account, p_due_day, CURDATE());
	END IF;
    
    
    # This is a mechanism that creates an initial cash deposit after one's account has been created
    # It is to make sure that any regular expenses that are due prior to regular incomes are paid
    INSERT INTO transactions(transaction_id, transaction_date, currency, amount, category_id, debit_account, credit_account, `description`)
    VALUES (
		1, # Adjusted by trigger "t17_generate_transaction_id"
        CURDATE(),
        'EUR',
        SUBSTRING_INDEX(p_prim_income_worth / 10, '.', 1) * 10, # This gives a more round number
        6,
        p_clients_account,
        NULL,
        'Initial cash deposit');
	
    
	# Total worth of regular incomes. It will be useful in the following step.
	SELECT 
		amount
	INTO p_total_income
	FROM source_tables.regular_transactions 
    WHERE 
		client_id = p_client_id AND
        debit_account = p_clients_account;
    
    # Generating regular housing expenses data (rent payments, mortgage payments)
    # The older a person is the more likely they are to own their property
    # Middle-aged people are more likely to have mortgages
    SET seed = RAND();
    SET seed2 = RAND();
	IF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 15 AND 17 THEN
		SET p_expense_name = NULL; # No rent, because they live with their parents
	ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 18 AND 26 THEN
		IF p_account_type = 'student account' THEN
			IF seed < 0.6 THEN
				SET p_expense_name = 'rent payment';
                SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
			ELSE
				SET p_expense_name = NULL; # Those who live with their parents
			END IF;
        ELSEIF p_account_type = 'personal account' THEN
			IF seed < 0.5 THEN
				SET p_expense_name = 'rent payment';
				SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
			ELSEIF seed >= 0.5 AND seed < 0.6 THEN
				SET p_expense_name = 'mortgage payment'; # A small number of people age 18-26 will have a mortgage
				SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
			ELSE
				SET p_expense_name = NULL; # They probably still live with their parents
			END IF;
		END IF;
	ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 27 AND 39 THEN
		IF seed < 0.4 THEN
			SET p_expense_name = 'rent payment';
			SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
		ELSEIF seed >= 0.4 AND seed < 0.8 THEN
			SET p_expense_name = 'mortgage payment';
			SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
		ELSE
			SET p_expense_name = NULL;
		END IF;
	ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 40 AND 49 THEN
		IF seed < 0.1 THEN
			SET p_expense_name = 'rent payment';
			SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
		ELSEIF seed >= 0.1 AND seed < 0.5 THEN
			SET p_expense_name = 'mortgage payment';
			SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
		ELSE
			SET p_expense_name = NULL;
		END IF;
	ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 50 AND 65 THEN
		IF seed < 0.05 THEN
			SET p_expense_name = 'rent payment';
			SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
		ELSEIF seed >= 0.05 AND seed < 0.25 THEN
			SET p_expense_name = 'mortgage payment';
			SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
		ELSE
			SET p_expense_name = NULL;
		END IF;
	ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 65 AND 74 THEN
		IF seed < 0.03 THEN
			SET p_expense_name = 'rent payment';
			SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
		ELSEIF seed >= 0.03 AND seed < 0.08 THEN
			SET p_expense_name = 'mortgage payment';
			SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
		ELSE
			SET p_expense_name = NULL;
		END IF;
	ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 75 AND 84 THEN
		IF seed < 0.02 THEN
			SET p_expense_name = 'rent payment';
			SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
		ELSEIF seed >= 0.02 AND seed < 0.04 THEN
			SET p_expense_name = 'mortgage payment';
			SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
		ELSE
			SET p_expense_name = NULL;
		END IF;	
	ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) >= 85 THEN
		IF seed < 0.01 THEN
			SET p_expense_name = 'rent payment';
			SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
		ELSEIF seed >= 0.01 AND seed < 0.02 THEN
			SET p_expense_name = 'mortgage payment';
			SET p_expense_value = p_total_income * (seed2 * 0.2 + 0.4);
		ELSE
			SET p_expense_name = NULL;
		END IF;	
    END IF;
    
    # Insert the generated data on housing expenses (rent payments, mortgage payments)
    SET p_opposite_account = f04_generate_fake_iban();
    SET p_due_day = FLOOR(RAND()*28) + 1;
    
    IF p_expense_name IS NOT NULL THEN
		IF p_expense_name = 'rent payment' THEN
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
			VALUES (p_client_id, 'EUR', p_expense_value, 13, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		ELSEIF p_expense_name = 'mortgage payment' THEN
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
			VALUES (p_client_id, 'EUR', p_expense_value, 14, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		END IF;
	END IF;
    
    # Generating regular bill payments – (1) total worth of bills
    SET seed = RAND();
    IF p_total_income < 800 THEN
		SET p_agg_expenses = (0.15 + seed * 0.15) * p_total_income;
	ELSEIF p_total_income >= 800 AND p_total_income < 1600 THEN
		SET p_agg_expenses = (0.10 + seed * 0.10) * p_total_income;
	ELSE
		SET p_agg_expenses = (0.05 + seed * 0.10) * p_total_income;
	END IF;
    
    # Generating regular bill payments – (2) splitting the total worth of bills into individual payments
    SET seed = RAND();
    SET p_num_payments = CASE
		WHEN seed < 0.2 THEN 2
        WHEN seed < 0.5 THEN 3
        WHEN seed < 0.8 THEN 4
        ELSE FLOOR(seed * 3) + 4 
	END;
    
    # Generating regular bill payments 
    # (3) Randomly allocating amounts to each bill payment 
    SET p1 = RAND();
    SET p2 = RAND();
    SET p3 = RAND();
    SET p4 = RAND();
    SET p5 = RAND();
    SET p6 = RAND();
	
	IF p_primary_income != 'allowance' THEN
		IF p_num_payments = 2 THEN
			SET p_expense_name = 'bill payment';
			SET p_expense_value = ((p1 / (p1 + p2)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p2 / (p1 + p2)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		ELSEIF p_num_payments = 3 THEN
			SET p_expense_name = 'bill payment';
			SET p_expense_value = ((p1 / (p1 + p2 + p3)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p2 / (p1 + p2 + p3)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p3 / (p1 + p2 + p3)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		ELSEIF p_num_payments = 4 THEN
			SET p_expense_name = 'bill payment';
			SET p_expense_value = ((p1 / (p1 + p2 + p3 + p4)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p2 / (p1 + p2 + p3 + p4)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p3 / (p1 + p2 + p3 + p4)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p4 / (p1 + p2 + p3 + p4)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		ELSEIF p_num_payments = 5 THEN
			SET p_expense_name = 'bill payment';
			SET p_expense_value = ((p1 / (p1 + p2 + p3 + p4 + p5)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p2 / (p1 + p2 + p3 + p4 + p5)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p3 / (p1 + p2 + p3 + p4 + p5)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p4 / (p1 + p2 + p3 + p4 + p5)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p5 / (p1 + p2 + p3 + p4 + p5)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		ELSEIF p_num_payments = 6 THEN
			SET p_expense_name = 'bill payment';
			SET p_expense_value = ((p1 / (p1 + p2 + p3 + p4 + p5 + p6)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p2 / (p1 + p2 + p3 + p4 + p5 + p6)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p3 / (p1 + p2 + p3 + p4 + p5 + p6)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p4 / (p1 + p2 + p3 + p4 + p5 + p6)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p5 / (p1 + p2 + p3 + p4 + p5 + p6)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
			SET p_expense_value = ((p6 / (p1 + p2 + p3 + p4 + p5 + p6)) * p_agg_expenses);
            SET p_opposite_account = f04_generate_fake_iban();
            SET p_due_day = FLOOR(RAND()*28) + 1;
			INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 15, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		END IF;
	END IF;
    
    # Generating subscription payments – (1) total worth of subscription payments
    SET seed = RAND();
    IF p_account_type = 'student account' THEN
		SET p_agg_expenses = (0.03 + seed * 0.02) * p_total_income;
	ELSEIF p_account_type = 'personal account' THEN
		IF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 18 AND 39 THEN
			SET p_agg_expenses = (0.04 + seed * 0.03) * p_total_income;
		ELSEIF TIMESTAMPDIFF(YEAR, p_birth_date, CURDATE()) BETWEEN 40 AND 64 THEN
			SET p_agg_expenses = (0.03 + seed * 0.02) * p_total_income;
		ELSE
			SET p_agg_expenses = (seed * 0.03) * p_total_income;
		END IF;
	END IF;
    
    # Generating subscription payments – (2) splitting the total worth of subscription payments into individual payments
    SET seed = RAND();
    SET p_num_payments = CASE
		WHEN p_total_income < 500 
			THEN FLOOR(RAND()*3) # 0-2
        WHEN p_total_income >= 500 AND p_total_income < 1000
			THEN FLOOR(RAND()*3) + 1 # 1-3
        WHEN p_total_income >= 1000 AND p_total_income < 1600
			THEN FLOOR(RAND()*3) + 2 # 2-4
        WHEN p_total_income >= 1600 AND p_total_income < 2500
			THEN FLOOR(RAND()*4) + 3 # 3-6
        ELSE FLOOR(seed * 5) + 4 # 4-8
	END;    
    
    # Generating subscription payments
    # (3) Randomly allocating amounts to each subscription payment
    SET p1 = RAND();
    SET p2 = RAND();
    SET p3 = RAND();
    SET p4 = RAND();
    SET p5 = RAND();
    SET p6 = RAND();
	SET p7 = RAND();
    SET p8 = RAND();

	IF p_num_payments = 2 THEN
		SET p_expense_name = 'subscription payment';
		SET p_expense_value = ((p1 / (p1 + p2)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p2 / (p1 + p2)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
	ELSEIF p_num_payments = 3 THEN
		SET p_expense_name = 'subscription payment';
		SET p_expense_value = ((p1 / (p1 + p2 + p3)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p2 / (p1 + p2 + p3)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p3 / (p1 + p2 + p3)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
	ELSEIF p_num_payments = 4 THEN
		SET p_expense_name = 'subscription payment';
		SET p_expense_value = ((p1 / (p1 + p2 + p3 + p4)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p2 / (p1 + p2 + p3 + p4)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p3 / (p1 + p2 + p3 + p4)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p4 / (p1 + p2 + p3 + p4)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
	ELSEIF p_num_payments = 5 THEN
		SET p_expense_name = 'subscription payment';
		SET p_expense_value = ((p1 / (p1 + p2 + p3 + p4 + p5)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p2 / (p1 + p2 + p3 + p4 + p5)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p3 / (p1 + p2 + p3 + p4 + p5)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p4 / (p1 + p2 + p3 + p4 + p5)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p5 / (p1 + p2 + p3 + p4 + p5)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
	ELSEIF p_num_payments = 6 THEN
		SET p_expense_name = 'subscription payment';
		SET p_expense_value = ((p1 / (p1 + p2 + p3 + p4 + p5 + p6)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p2 / (p1 + p2 + p3 + p4 + p5 + p6)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p3 / (p1 + p2 + p3 + p4 + p5 + p6)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p4 / (p1 + p2 + p3 + p4 + p5 + p6)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p5 / (p1 + p2 + p3 + p4 + p5 + p6)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p6 / (p1 + p2 + p3 + p4 + p5 + p6)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
	ELSEIF p_num_payments = 7 THEN
		SET p_expense_name = 'subscription payment';
		SET p_expense_value = ((p1 / (p1 + p2 + p3 + p4 + p5 + p6 + p7)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p2 / (p1 + p2 + p3 + p4 + p5 + p6 + p7)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p3 / (p1 + p2 + p3 + p4 + p5 + p6 + p7)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p4 / (p1 + p2 + p3 + p4 + p5 + p6 + p7)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p5 / (p1 + p2 + p3 + p4 + p5 + p6 + p7)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p6 / (p1 + p2 + p3 + p4 + p5 + p6 + p7)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p7 / (p1 + p2 + p3 + p4 + p5 + p6 + p7)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
	ELSEIF p_num_payments = 8 THEN
		SET p_expense_name = 'subscription payment';
		SET p_expense_value = ((p1 / (p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p2 / (p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p3 / (p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p4 / (p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p5 / (p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p6 / (p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p7 / (p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
		SET p_expense_value = ((p8 / (p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8)) * p_agg_expenses);
		SET p_opposite_account = f04_generate_fake_iban();
		SET p_due_day = FLOOR(RAND()*28) + 1;
		INSERT INTO source_tables.regular_transactions(client_id, currency, amount, category_id, debit_account, credit_account, due_day, valid_since) 
				VALUES (p_client_id, 'EUR', p_expense_value, 16, p_opposite_account, p_clients_account, p_due_day, CURDATE());
	END IF;
    
	SET @allow_client_insert = 0; # Disable inserts on the clients table
END$$
DELIMITER ;




### TRIGGER 14: "T14_PREVENT_DIRECT_CLIENT_INSERTS"
/*	The purpose of this trigger is to prevent users from performing direct insert
	statements on the "clients" table. The reasoning behind this is that whenever a
    new client record is created we expect for the client's first account to get created
    as well, which is impossible without specifying the account type, which in turn is
    impossible to do using a plain insert statement, since there is no "account_type" column
    in the "clients" table. Therefore, it's preferable to apply the procedure called
    "p01_register_new_client" or "p03_generate_new_client", which alongside creating a
    new client records will also create their first account. */
    
DROP TRIGGER IF EXISTS t14_prevent_direct_client_inserts;
DELIMITER $$
CREATE TRIGGER t14_prevent_direct_client_inserts
BEFORE INSERT ON clients
FOR EACH ROW
BEGIN
	# "@allow_client_insert" is a boolean variable, that switches on and off direct updates to "accounts"
	IF @allow_client_insert IS NULL OR @allow_client_insert = 0 THEN 
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Direct inserts into the "clients" table are not allowed. Use a corresponding procedure instead.';
	END IF;
END$$
DELIMITER ;




### TABLE "SOURCE_TABLES.INCOME_RATES_DISTRIBUTION"
/*	This is another source table, in which I store the distribution of regular income rates,
	based on which client's monthly income values are generated. */
    
DROP TABLE IF EXISTS source_tables.income_rates_distribution;
CREATE TABLE source_tables.income_rates_distribution (
	income_type 	ENUM ('allowance 15-17', 'allowance 18-26', 'salary', 'social benefits', 'pension'),
    lower_int		DECIMAL(12,2),
    upper_int		DECIMAL(12,2),
    lower_eur		DECIMAL(12,2),
    upper_eur		DECIMAL(12,2)
);

INSERT INTO source_tables.income_rates_distribution VALUES
('allowance 15-17', 0, 0.11, 21, 40),
('allowance 15-17', 0.11, 0.23, 41, 60),
('allowance 15-17', 0.23, 0.37, 61, 80),
('allowance 15-17', 0.37, 0.51, 81, 100),
('allowance 15-17', 0.51, 0.63, 101, 120),
('allowance 15-17', 0.63, 0.73, 121, 140),
('allowance 15-17', 0.73, 0.81, 141, 160),
('allowance 15-17', 0.81, 0.87, 161, 180),
('allowance 15-17', 0.87, 0.91, 181, 200),
('allowance 15-17', 0.91, 0.94, 201, 220),
('allowance 15-17', 0.94, 0.96, 221, 240),
('allowance 15-17', 0.96, 0.97, 241, 260),
('allowance 15-17', 0.97, 0.98, 261, 280),
('allowance 15-17', 0.98, 0.99, 281, 300),
('allowance 15-17', 0.99, 1, 301, 320),
('allowance 18-26', 0, 0.11, 121, 160),
('allowance 18-26', 0.11, 0.23, 161, 200),
('allowance 18-26', 0.23, 0.37, 201, 240),
('allowance 18-26', 0.37, 0.51, 241, 280),
('allowance 18-26', 0.51, 0.63, 281, 320),
('allowance 18-26', 0.63, 0.73, 321, 360),
('allowance 18-26', 0.73, 0.81, 361, 400),
('allowance 18-26', 0.81, 0.87, 401, 440),
('allowance 18-26', 0.87, 0.91, 441, 480),
('allowance 18-26', 0.91, 0.94, 481, 520),
('allowance 18-26', 0.94, 0.96, 521, 560),
('allowance 18-26', 0.96, 0.97, 561, 600),
('allowance 18-26', 0.97, 0.98, 601, 640),
('allowance 18-26', 0.98, 0.99, 641, 680),
('allowance 18-26', 0.99, 1, 681, 720),
('salary', 0, 0.11, 817, 1070),
('salary', 0.11, 0.23, 1071, 1320),
('salary', 0.23, 0.37, 1321, 1570),
('salary', 0.37, 0.51, 1571, 1820),
('salary', 0.51, 0.63, 1821, 2070),
('salary', 0.63, 0.73, 2071, 2320),
('salary', 0.73, 0.81, 2321, 2570),
('salary', 0.81, 0.87, 2571, 2820),
('salary', 0.87, 0.91, 2821, 3070),
('salary', 0.91, 0.94, 3071, 3320),
('salary', 0.94, 0.96, 3321, 3570),
('salary', 0.96, 0.97, 3571, 3820),
('salary', 0.97, 0.98, 3821, 4070),
('salary', 0.98, 0.99, 4071, 4320),
('salary', 0.99, 1, 4321, 6000),
('social benefits', 0, 0.25, 450, 550),
('social benefits', 0.25, 0.5, 550, 750),
('social benefits', 0.5, 0.75, 750, 950),
('social benefits', 0.75, 1, 950, 1150),
('pension', 0, 0.36, 400, 450),
('pension', 0.36, 0.56, 450, 500),
('pension', 0.56, 0.66, 500, 550),
('pension', 0.66, 0.73, 550, 600),
('pension', 0.73, 0.79, 600, 650),
('pension', 0.79, 0.83, 650, 700),
('pension', 0.83, 0.88, 700, 800),
('pension', 0.88, 0.91, 800, 900),
('pension', 0.91, 0.93, 900, 1000),
('pension', 0.93, 0.96, 1000, 1250),
('pension', 0.96, 0.97, 1250, 1500),
('pension', 0.97, 1, 1500, 2000);
	



### "CATEGORIES" TABLE
/*	This table stores information on transactions categories. */
DROP TABLE IF EXISTS categories;
CREATE TABLE categories(
	category_id		INT PRIMARY KEY AUTO_INCREMENT,
    category_name	VARCHAR(100) NOT NULL);
    
INSERT INTO categories VALUES
	(1, 'allowance'),
    (2, 'salary'),
    (3, 'social benefits'),
    (4, 'pension'),
    (5, 'investment disbursement'),
    (6, 'cash deposit'),
    (7, 'bank transfer'),
    (8, 'savings account transfer'),
    (9, 'savings account disbursement'),
    (10, 'term deposit disbursement'),
    (11, 'business account transfer'),
    (12, 'student account transfer'),
    (13, 'rent payment'),
    (14, 'mortgage payment'),
    (15, 'bill payment'),
    (16, 'subscription payment'),
    (17, 'deposit to savings account'),
    (18, 'cash withdrawal'),
    (19, 'POS purchase'),
    (20, 'online purchase'),
    (21, 'term deposit transfer');
 



### "TRANSACTIONS" TABLE
DROP TABLE IF EXISTS transactions;
CREATE TABLE transactions (
	transaction_id			BIGINT PRIMARY KEY AUTO_INCREMENT,
    transaction_date		DATE NOT NULL,
    currency				CHAR(3) NOT NULL DEFAULT 'EUR',
    amount					DECIMAL(12, 2) NOT NULL,
    category_id				INT NOT NULL,
    debit_account			CHAR(24) NULL, # Double-entry accounting
    credit_account			CHAR(24) NULL, # Double-entry accounting
    `description`			VARCHAR(255) NULL,
    FOREIGN KEY(category_id) REFERENCES categories(category_id), # Foreign key refericing iban in the "accounts" table is missing, becase we have 2 iban columns
	CONSTRAINT amount_not_negative CHECK (amount >= 0), # Amount cannot be negative; addition or subtraction is determined based on debit/credit
    CONSTRAINT iban_populated CHECK(debit_account IS NOT NULL OR credit_account IS NOT NULL) # At least one of the IBANs have to be indicated
);




### TRIGGER 15: "T15_UPDATE_ACCOUNTS_AFTER_TRANSACTIONS"
/*	This trigger represents the main mechanism thanks to which clients' accounts get
	updated according to transactions that they have been engaged in. */
    
DROP TRIGGER IF EXISTS t15_update_accounts_after_transactions;
DELIMITER $$
CREATE TRIGGER t15_update_accounts_after_transactions
AFTER INSERT ON transactions
FOR EACH ROW
BEGIN
	SET  @allow_accounts_update = 1;
    
	IF NEW.debit_account IN (SELECT iban FROM accounts) AND NEW.credit_account IN (SELECT iban FROM accounts) THEN
		UPDATE accounts
        SET balance = balance + NEW.amount
        WHERE iban = NEW.debit_account;
        
        UPDATE accounts
        SET balance = balance - NEW.amount
        WHERE iban = NEW.credit_account;
	ELSEIF NEW.debit_account IN (SELECT iban FROM accounts) THEN
		UPDATE accounts
        SET balance = balance + NEW.amount
        WHERE iban = NEW.debit_account;
    ELSEIF NEW.credit_account IN (SELECT iban FROM accounts) THEN
		UPDATE accounts
        SET balance = balance - NEW.amount
        WHERE iban = NEW.credit_account;
	END IF;
    
    SET  @allow_accounts_update = 0;
END$$
DELIMITER ;

### TRIGGER 16: "T16_CHECK_ACCOUNT_BEFORE_TRANSACTION"
/* 	This trigger checks whether the transaction currency and the currency of the accounts involved
	in the transaction match. If in the future, other currencies are introduced with conversions,
    this trigger will be changed. In addition, the trigger checks if there is enough money on the
    account to perform the transaction. Finally, it also checks whether the bank accounts inlvoved
    in a transaction belong to this bank. */
    
DROP TRIGGER IF EXISTS t16_check_account_before_transaction;
DELIMITER $$
CREATE TRIGGER t16_check_account_before_transaction
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
	DECLARE p_debit_currency 	CHAR(3);
    DECLARE p_credit_currency 	CHAR(3);
    DECLARE p_debit_balance 	DECIMAL(12, 2);
    DECLARE p_credit_balance 	DECIMAL(12, 2);
    
    SELECT currency 
    INTO p_debit_currency 
    FROM accounts 
    WHERE iban = NEW.debit_account;
    
	SELECT currency 
    INTO p_credit_currency 
    FROM accounts 
    WHERE iban = NEW.credit_account;
    
    IF NEW.currency != p_debit_currency OR NEW.currency != p_credit_currency THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = "The transaction currency and the currency of the involved account(s) have to match.";
    END IF;
    
    SELECT balance
    INTO p_debit_balance
    FROM accounts
    WHERE iban = NEW.debit_account;
    
	SELECT balance
    INTO p_credit_balance
    FROM accounts
    WHERE iban = NEW.credit_account;
    
    IF NEW.credit_account IS NOT NULL THEN
		IF p_credit_balance < NEW.amount THEN
			SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = "There are insufficient funds on the credit account to perform the transaction.";
		END IF;
	END IF;
    
    IF (NEW.debit_account IS NOT NULL AND NEW.debit_account NOT IN (SELECT iban FROM accounts)) AND 
			(NEW.credit_account IS NOT NULL AND NEW.credit_account NOT IN (SELECT iban FROM accounts)) THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = "None of the accounts involved in this transaction belong to this bank.";
	ELSEIF NEW.debit_account IS NULL AND (NEW.credit_account IS NOT NULL AND NEW.credit_account NOT IN (SELECT iban FROM accounts)) THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = "The account does not belong to this bank.";
	ELSEIF NEW.credit_account IS NULL AND (NEW.debit_account IS NOT NULL AND NEW.debit_account NOT IN (SELECT iban FROM accounts)) THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = "The account does not belong to this bank.";		
	END IF;
END$$
DELIMITER ;



### TRIGGER 17: "T17_GENERATE_TRANSACTION_ID"
/*	This trigger makes sure that transaction_id's in the "transactions" table get correctly
	incremented. */
DROP TRIGGER IF EXISTS t17_generate_transaction_id;
DELIMITER $$
CREATE TRIGGER t17_generate_transaction_id
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
	DECLARE p_max_transaction_id BIGINT;
    
    SELECT MAX(transaction_id)
    INTO p_max_transaction_id
    FROM transactions;
    
    IF p_max_transaction_id IS NULL THEN
		SET NEW.transaction_id = 1;
	ELSE
		SET NEW.transaction_id = p_max_transaction_id + 1;
	END IF;
END$$
DELIMITER ;




### PROCEDURE 04: "P04_MAKE_A_TRANSACTION"
/*	This is essentially a transaction form. */
DROP PROCEDURE IF EXISTS p04_make_a_transaction;
DELIMITER $$
CREATE PROCEDURE p04_make_a_transaction(
	IN p_currency 		CHAR(3),
    IN p_amount 		DECIMAL(12, 2),
    IN p_category_id 	INT,
    IN p_to_account 	CHAR(24),
    IN p_from_account 	CHAR(24),
    IN p_description 	VARCHAR(255))
BEGIN
    INSERT INTO transactions VALUES (
		1,	# to be updated by trigger 17
		DATE_FORMAT(CURRENT_TIMESTAMP, '%Y-%m-%d'),
		p_currency,
		p_amount,
		p_category_id,
		NULLIF(p_to_account, ''),
		NULLIF(p_from_account, ''),
		NULLIF(p_description, '')
	);
END$$
DELIMITER ;




### TABLE "SOURCE_TABLES.REGULAR_TRANSACTIONS"
/*	This table will store regular incomes and expenses of generated clients. */

DROP TABLE IF EXISTS source_tables.regular_transactions;
CREATE TABLE source_tables.regular_transactions (
	client_id		INT,
    currency		CHAR(3) DEFAULT 'EUR',
    amount			DECIMAL(12, 2),
    category_id		INT,
    debit_account	CHAR(24),
    credit_account	CHAR(24),
    due_day			INT,
    valid_since		DATE);

# Just adding another column that will help the upcoming event to establish since what date it should check for missed transactions
ALTER TABLE source_tables.regular_transactions
ADD COLUMN last_executed DATE NULL;


### EVENT 01: "E01_EXECUTE_REGULAR_TRANSACTIONS"
/*	This event executes any regular transaction that is due on a given day. In addition, it also checks whether all transactions
	that were due in the past (since the day the client was registered) were actually executed. */
    
DROP EVENT IF EXISTS e01_execute_regular_transactions;
DELIMITER $$
CREATE EVENT e01_execute_regular_transactions
ON SCHEDULE EVERY 5 MINUTE
DO
BEGIN
	DECLARE p_start_date	DATE;
    DECLARE p_check_day		INT;
    DECLARE p_check_date	DATE;
    
    IF EXISTS (SELECT 1 FROM source_tables.regular_transactions WHERE last_executed IS NULL) THEN
        SELECT MIN(valid_since) INTO p_start_date FROM source_tables.regular_transactions;
	ELSE
		SELECT MIN(last_executed) INTO p_start_date FROM source_tables.regular_transactions;
	END IF;
	
    SET p_check_day = 0;
    
    WHILE p_check_day <= TIMESTAMPDIFF(DAY, p_start_date, CURDATE()) DO
		SET p_check_date = DATE_ADD(p_start_date, INTERVAL p_check_day DAY);
        
		INSERT INTO transactions (transaction_id, transaction_date, currency, amount, category_id, debit_account, credit_account, `description`)
		SELECT
			1 AS transaction_id, # To be corrected by trigger "t17_generate_transaction_id"
            p_check_date AS transaction_date,
            r.currency,
            r.amount,
            r.category_id,
            r.debit_account,
            r.credit_account,
            NULL AS `description`
		FROM source_tables.regular_transactions r
        WHERE 
			r.due_day = DAY(p_check_date)
            AND NOT EXISTS (
				SELECT 1
                FROM transactions t
                WHERE t.transaction_date 	= p_check_date
					AND t.currency			= r.currency
                    AND t.amount			= r.amount
                    AND	t.category_id		= r.category_id
                    AND t.debit_account		= r.debit_account
                    AND t.credit_account	= r.credit_account
			);
		
        UPDATE source_tables.regular_transactions
        SET last_executed = p_check_date
        WHERE due_day = DAY(p_check_date)
			AND (last_executed IS NULL OR last_executed < p_check_date); 
        
		SET p_check_day = p_check_day + 1;
    END WHILE;    
END$$
DELIMITER ;




### EVENT 02: "E02_STUDENT_ACCOUNT_TO_PERSONAL"
/*	This event creates a personal accounts for all clients with student accounts, who have
	turned 27. This is in accordance with our internal policy, which does not allow clients
    over the age of 26 to own student accounts. The event also transfers all funds from the
    old student account to the new person accounts, substitutes the accounts in the
    "source_table.regular_transactions" table and closes the student account (updates the
    "closed_at" column.) */
    
DROP EVENT IF EXISTS e02_student_account_to_personal;
DELIMITER $$
CREATE EVENT e02_student_account_to_personal
ON SCHEDULE EVERY 1 MINUTE
DO
BEGIN
	# Auto-create a new personal account for everyone over 26 who has a student account
	INSERT INTO accounts(iban, client_id, account_type, currency, balance, created_at, closed_at)
	SELECT
		'SK0000000000000000000000' AS iban, # to be changed by trigger "t10_generate_new_iban"
        c.client_id,
        'personal account' AS account_type,
        a.currency,
        0 AS balance,
        DATE_ADD(c.birth_date, INTERVAL 27 YEAR) AS created_at, # the day the client turned 27 (no longer eligible for student account)
        NULL AS closed_at
	FROM
		clients c
			JOIN
		accounts a ON c.client_id = a.client_id
	WHERE TIMESTAMPDIFF(YEAR, c.birth_date, CURDATE()) > 26
		AND a.account_type = 'student account'
        AND a.closed_at IS NULL;
        
    # This temporary table contains the data for a transaction of all funds from the student account to the newly created personal account
	DROP TEMPORARY TABLE IF EXISTS student_to_personal_transfer;
    CREATE TEMPORARY TABLE student_to_personal_transfer
	SELECT
		1 AS transaction_id, # to be corrected by trigger "t17_generate_transaction_id",
		DATE_ADD(x.birth_date, INTERVAL 27 YEAR) AS transaction_date,
		x.currency,
		x.amount,
		12 AS category_id, # student account transfer
		x.debit_account,
		x.credit_account,
		'Funds transferred from the closed student account' AS `description`
	FROM
		(SELECT 
			s.client_id,
			s.iban AS credit_account, # student account
			s.currency, # student account's currency
			s.balance AS amount, # student account's balance
			p.iban AS debit_account, # debit account
			c.birth_date
		FROM
			(SELECT a.*
			FROM
				clients c
					JOIN
				accounts a ON c.client_id = a.client_id
			WHERE TIMESTAMPDIFF(YEAR, c.birth_date, CURDATE()) > 26
				AND a.account_type = 'student account'
                AND a.closed_at IS NULL) s
				JOIN
			(SELECT a.*
			FROM
				clients c
					JOIN
				accounts a ON c.client_id = a.client_id
			WHERE TIMESTAMPDIFF(YEAR, c.birth_date, CURDATE()) > 26
				AND a.account_type = 'personal account'
                AND a.closed_at IS NULL) p ON s.client_id = p.client_id
				JOIN
			clients c ON s.client_id = c.client_id) x;
     
    # Execute the transaction using the data from the temporary table "student_to_personal_transfer" 
	INSERT INTO transactions(transaction_id, transaction_date, currency, amount, category_id, debit_account, credit_account, `description`)
	SELECT * FROM student_to_personal_transfer;
    
    # Drop the temporary table
    DROP TEMPORARY TABLE IF EXISTS student_to_personal_transfer;
    
    # Next, we need to update any potential regular transactions = replace the student account IBAN with the new personal account IBAN
    # To have this data in a clean and visible form, I will create a temporary table to contain it
    DROP TEMPORARY TABLE IF EXISTS student_personal_iban;
    CREATE TEMPORARY TABLE student_personal_iban
	SELECT y.client_id, y.student_account, y.personal_account
	FROM
		(SELECT 
			s.client_id,
			s.iban AS student_account,
			p.iban AS personal_account
		FROM
			((SELECT a.*
				FROM
					clients c
						JOIN
					accounts a ON c.client_id = a.client_id
				WHERE TIMESTAMPDIFF(YEAR, c.birth_date, CURDATE()) > 26
					AND a.account_type = 'student account'
                    AND a.closed_at IS NULL) s
					JOIN
			(SELECT a.*
				FROM
					clients c
						JOIN
					accounts a ON c.client_id = a.client_id
				WHERE TIMESTAMPDIFF(YEAR, c.birth_date, CURDATE()) > 26
					AND a.account_type = 'personal account'
                    AND a.closed_at IS NULL) p ON s.client_id = p.client_id)) y;
    
    # Replace the student account IBAN with the personal account IBAN wherever the student account is in the debit account position
	UPDATE source_tables.regular_transactions r
    JOIN student_personal_iban s
    ON r.client_id = s.client_id
    SET r.debit_account = s.personal_account
    WHERE r.debit_account = s.student_account;
    
    # Replace the student account IBAN with the personal account IBAN wherever the student account is in the credit account position
	UPDATE source_tables.regular_transactions r
    JOIN student_personal_iban s
    ON r.client_id = s.client_id
    SET r.credit_account = s.personal_account
    WHERE r.credit_account = s.student_account;
    
    # Next, drop the temporary table
    DROP TEMPORARY TABLE IF EXISTS student_personal_iban;
    
    # Now, I will create another temporary table to be able to update the "closed_at" column in the "accounts" table
    # MySQL won't make update it using a subquery, because of cross referencing 
    DROP TEMPORARY TABLE IF EXISTS student_account_and_birth_date;
    CREATE TEMPORARY TABLE student_account_and_birth_date
    SELECT a.iban, c.birth_date
	FROM clients c
	JOIN accounts a ON c.client_id = a.client_id
	WHERE TIMESTAMPDIFF(YEAR, c.birth_date, CURDATE()) > 26
		AND a.account_type = 'student account'
		AND a.closed_at IS NULL;
    
    # Update the "closed_at" column
    SET @allow_accounts_update = 1;
    UPDATE accounts a
    JOIN student_account_and_birth_date s
	ON a.iban = s.iban
    SET a.closed_at = DATE_ADD(s.birth_date, INTERVAL 27 YEAR);
    SET @allow_accounts_update = 0;
    
    # Lastly, drop the temporary table
    DROP TEMPORARY TABLE IF EXISTS student_account_and_birth_date;
END$$
DELIMITER ;




### TRIGGER 18: "T18_DISABLE_TRANSACTIONS_ON_CLOSED_ACCOUNTS"
/* 	This is a trigger that prevents transactions to/from closed accounts. */

DROP TRIGGER IF EXISTS t18_disable_transactions_on_closed_accounts;
DELIMITER $$
CREATE TRIGGER t18_disable_transactions_on_closed_accounts
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
	IF 	
		NEW.debit_account IN 		
			(SELECT iban FROM accounts WHERE closed_at IS NOT NULL) # Closed accounts
		OR NEW.credit_account IN	
			(SELECT iban FROM accounts WHERE closed_at IS NOT NULL) # Closed accounts
	THEN
		SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Transactions cannot made to/from a closed account.';
	END IF;
END$$
DELIMITER ;
 

 

### PROCEDURE 05: "P05_CLOSE_AN_ACCOUNT"
/* WORK IN PROGRESS */

DROP PROCEDURE p05_close_an_account;
DELIMITER $$
CREATE PROCEDURE p05_close_an_account(IN p_iban CHAR(24))
BEGIN
	IF p_iban IN (SELECT iban FROM accounts WHERE account_type = 'term deposit')
		THEN SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'You cannot close a term deposit before its due date.';
	ELSEIF p_iban IN (SELECT iban FROM accounts WHERE account_type = 'business account')
		THEN 
			# This temporary table contains data on the business account as well as the personal (or student) account to which the money needs to be sent
			DROP TEMPORARY TABLE IF EXISTS business_personal_accounts;
            CREATE TEMPORARY TABLE business_personal_accounts
				SELECT 
					1, # to be corrected by trigger "t17_generate_transaction_id"
					CURDATE() AS transaction_date,
					x.currency,
					x.balance AS amount,
					11, # business account transfer
					x.personal_iban AS debit_account,
					x.business_iban AS credit_account,
					'Funds transferred from the business account' AS `description`
				FROM
					(SELECT
						b.iban AS business_iban,
						b.client_id,
						b.account_type,
						b.currency,
						b.balance,
						p.iban AS personal_iban
					FROM
						(SELECT * FROM accounts WHERE iban = p_iban) b
							JOIN
						(SELECT * FROM accounts WHERE account_type = 'personal account' OR account_type = 'student account') p 
								ON b.client_id = p.client_id) x;
             
			# Transfer the funds from the business account to the personal/student account
			INSERT INTO transactions(transaction_id, transaction_date, currency, amount, category_id, debit_account, credit_account, `description`)
            SELECT * FROM business_personal_accounts;
            
            # Drop the temporary table
            DROP TEMPORARY TABLE IF EXISTS business_personal_accounts;
            
            # Close the business account = populate the "closed_at" column
            SET @allow_accounts_update = 1;
            UPDATE accounts
            SET closed_at = CURDATE()
            WHERE iban = p_iban;
			SET @allow_accounts_update = 0;
	-- ELSEIF p_iban IN (SELECT iban FROM accounts WHERE account_type = 'savings account')

	-- ELSEIF p_iban IN (SELECT iban FROM accounts WHERE account_type = 'personal account' OR account_type = 'student account')
		-- cash withdrawal (category_id = 18)
	END IF;
END$$
DELIMITER ;


DELETE FROM accounts;	
DELETE FROM transactions;
DELETE FROM clients;    
DELETE FROM source_tables.regular_transactions;
CALL p03_generate_new_client; # Generate a new client along with their accounts and transactions
SELECT * FROM clients;

SELECT * FROM accounts;
SELECT * FROM transactions;
SELECT * FROM categories;
SELECT * FROM source_tables.regular_transactions;



# TO-DO LIST
-- Create a procedure for opening a savings account or a term deposit
-- Create a procedure for opening a business account
-- Allow opening of savings accounts, business accounts and term deposits only if a client has a personal, student
-- Delete from accounts once a client has no accounts
-- Disable deleting from clients if a client has still a term deposit or savings account
-- Disable deleting personal, student or business account if a client has still a term deposit or savings account
-- Create a trigger: Disable deletes on the "clients" table (populate the "client_until" column instead)
-- Create a trigger that would prevent users from entering a non-existent category_id
-- For those who have a business account, adjust the credit_account in salary transactions as that of the business account
-- Disable transactions to accounts with populated closed_at column
-- Repair trigger: student accounts are not available to clients over 26 → the procedure registers the client nonetheless without creating an account
	-- it shouldn't register them at all in such a case
-- Create a procedure to close an account
-- Try to repair procedure "p03_generate_a_new_client" so that it doesn't show "Error Code: 1172. Result consisted of more than one row." 
	-- It does it in like 10% of cases
-- Come up with a way of generating mock data on business accounts, savings accounts and term deposits 
-- For mock clients, add transactions of other categories with different chances of each transation to take place for different clients on a given day