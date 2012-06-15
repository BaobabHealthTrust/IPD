DELETE FROM global_property WHERE property = 'dde_server_ip';

INSERT INTO global_property (property, property_value, `description`, uuid) VALUES ('dde_server_ip', '192.168.6.139:3001', 'Demographics Data Exchange Server IP address and port', (SELECT UUID()));

DELETE FROM global_property WHERE property = 'dde_server_username';

INSERT INTO global_property (property, property_value, `description`, uuid) VALUES ('dde_server_username', 'admin', 'Demographics Data Exchange Server username', (SELECT UUID()));

DELETE FROM global_property WHERE property = 'dde_server_password';

INSERT INTO global_property (property, property_value, `description`, uuid) VALUES ('dde_server_password', 'admin', 'Demographics Data Exchange Server password', (SELECT UUID()));

