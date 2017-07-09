
DELETE FROM global_property WHERE property = 'create.from.dde2.server';
DELETE FROM global_property WHERE property = 'dde2_server_ip';
DELETE FROM global_property WHERE property = 'dde2_server_username';
DELETE FROM global_property WHERE property = 'dde2_server_password';
DELETE FROM global_property WHERE property = 'dde2_basic_http_auth';

INSERT INTO global_property (property, property_value, description, uuid) 
VALUES ("create.from.dde2.server", "true", "Demographics Data Exchange 2 connection parameter", 
(SELECT uuid()));

INSERT INTO global_property (property, property_value, description, uuid) 
VALUES ("dde2_server_ip", "localhost:3009", "Demographics Data Exchange 2 server ip and port", 
(SELECT uuid()));

INSERT INTO global_property (property, property_value, description, uuid) 
VALUES ("dde2_server_username", "admin", "Demographics Data Exchange 2 Server username", 
(SELECT uuid()));

INSERT INTO global_property (property, property_value, description, uuid) 
VALUES ("dde2_server_password", "admin", "Demographics Data Exchange 2 Server password", 
(SELECT uuid()));

INSERT INTO global_property (property, property_value, description, uuid) 
VALUES ("dde2_basic_http_auth", "true", "Demographics Data Exchange 2 Server authentication", 
(SELECT uuid()));
