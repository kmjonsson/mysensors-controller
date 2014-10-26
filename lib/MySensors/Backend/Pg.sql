DROP TABLE values;
DROP TABLE sensors;
DROP TABLE nodes;

-- If protocol, sketchname or version change create new node else update last = now();
CREATE TABLE nodes (
	id		serial PRIMARY KEY NOT NULL,
	first		timestamp NOT NULL DEFAULT now(),
	last		timestamp NOT NULL DEFAULT now(),
	node		int NOT NULL CHECK (id > 0),
	protocol	text,
	sketchname	text,
	sketchversion	text,
	CHECK		(first <= last)
);

-- if sensor type changes create new node else update last = now();
CREATE TABLE sensors (
	id		serial PRIMARY KEY,
	node		int NOT NULL REFERENCES nodes,
	sensor		int NOT NULL CHECK (id >= 0 AND id < 256),
	type		int NOT NULL CHECK (type >= 0),
	first		timestamp NOT NULL DEFAULT now(),
	last		timestamp NOT NULL DEFAULT now(),
	CHECK		(first <= last)
);

CREATE TABLE values (
	id		serial PRIMARY KEY,
	sensor		int NOT NULL REFERENCES sensors,
	type		int NOT NULL CHECK (type >= 0),
	first		timestamp NOT NULL DEFAULT now(),
	last		timestamp NOT NULL DEFAULT now(),
	value		text	NOT NULL CHECK (length(value) > 0),
	CHECK		(first <= last)
);


CREATE OR REPLACE FUNCTION save_sensor ( 
		in_node		int,
		in_sensor	int,
		in_type		int
	)
RETURNS boolean AS $save_sensor$
DECLARE
	var_sensor	RECORD;
BEGIN
	SELECT * INTO var_sensor FROM sensors WHERE node = in_node AND sensor = in_sensor
		ORDER BY last,first DESC LIMIT 1;
	IF FOUND THEN
		UPDATE sensors SET last = now() WHERE id = var_sensor.id;
		IF var_sensor.type = in_type THEN
			return TRUE;
		END IF;
	END IF;
	INSERT INTO sensors (node,sensor,type) VALUES (in_node,in_sensor,in_type);
	RETURN true;
END;
$save_sensor$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_next_available_nodeid ( )
RETURNS int AS $get_next_available_nodeid$
DECLARE
	var_next INT;
BEGIN
	SELECT max(node)+1 INTO var_next FROM nodes;
	IF NOT FOUND THEN
		return 1;
	END IF;
	INSERT INTO nodes (node)
		VALUES    (var_next);
	RETURN var_next;
END;
$get_next_available_nodeid$
LANGUAGE plpgsql;

-- if type or value changes create new 'value' or
-- no report in 1h create new 'value' or
-- sensors.first > values.last
-- else update last = now();
CREATE OR REPLACE FUNCTION save_value ( 
		in_node		int,
		in_sensor	int,
		in_type		int,
		in_value	text
	)
RETURNS boolean AS $save_value$
DECLARE
	var_value	RECORD;
	var_sensor	RECORD;
BEGIN
	SELECT * INTO var_sensor FROM sensors WHERE node = in_node AND sensor = in_sensor ORDER BY last,first DESC LIMIT 1;
	IF NOT FOUND THEN
		return false;
	END IF;
	SELECT * INTO var_value FROM values WHERE sensor = var_sensor.id ORDER BY last,first DESC LIMIT 1;
	IF NOT FOUND or now() - var_value.last > '1h'::interval THEN
		INSERT INTO values (sensor,type,value) VALUES (var_sensor.id,in_type,in_value);
	END IF;
	UPDATE values SET last = now() WHERE id = var_value.id;
	IF var_value.type <> in_type or var_value.value <> in_value 
			or var_sensor.first > var_value.last THEN
		INSERT INTO values (sensor,type,value) VALUES (var_sensor.id,in_type,in_value);
	END IF;
	RETURN true;
END;
$save_value$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION get_value (
		in_node		int,
		in_sensor	int,
		in_type		int
	)
RETURNS text AS $get_value$
DECLARE
	var_value	RECORD;
	var_sensor	RECORD;
BEGIN
	SELECT * INTO var_sensor FROM sensors WHERE node = in_node AND sensor = in_sensor ORDER BY last,first DESC LIMIT 1;
	IF NOT FOUND THEN
		return NULL;
	END IF;
	SELECT * INTO var_value FROM values WHERE sensor = var_sensor.id AND type = in_type ORDER BY last,first DESC LIMIT 1;
	IF NOT FOUND THEN
		return NULL;
	END IF;
	return var_value.value;
END;
$get_value$
LANGUAGE plpgsql;

-- CREATE OR REPLACE FUNCTION save_batterylevel ( 

CREATE OR REPLACE FUNCTION save_protocol ( 
		in_node		int,
		in_protocol	text
	)
RETURNS boolean AS $save_protocol$
DECLARE
	var_node	RECORD;
BEGIN
	SELECT * INTO var_node FROM nodes where node = in_node ORDER BY last,first DESC LIMIT 1;
	IF NOT FOUND THEN
		RETURN false;
	END IF;

	IF var_node.protocol IS NULL THEN
		UPDATE nodes SET protocol = in_protocol, last = now() WHERE id = var_node.id;
		return true;
	END IF;
	UPDATE nodes SET last = now() WHERE id = var_node.id;
	IF var_node.protocol = in_protocol THEN
		return true;
	END IF;
	INSERT INTO nodes (node,protocol,sketchname,sketchversion) 
		VALUES    (in_node,in_protocol,var_node.sketchname,
				var_node.sketchversion);
	RETURN true;
END;
$save_sketch_name$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION save_sketch_name ( 
		in_node		int,
		in_name		text
	)
RETURNS boolean AS $save_sketch_name$
DECLARE
	var_node	RECORD;
BEGIN
	SELECT * INTO var_node FROM nodes where node = in_node ORDER BY last,first DESC LIMIT 1;
	IF NOT FOUND THEN
		RETURN false;
	END IF;

	IF var_node.sketchname IS NULL THEN
		UPDATE nodes SET sketchname = in_name, last = now() WHERE id = var_node.id;
		return true;
	END IF;
	UPDATE nodes SET last = now() WHERE id = var_node.id;
	IF var_node.sketchname = in_name THEN
		return true;
	END IF;
	INSERT INTO nodes (node,protocol,sketchname,sketchversion) 
		VALUES    (in_node,var_node.protocol,in_name,var_node.sketchversion);
	RETURN true;
END;
$save_sketch_name$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION save_sketch_version ( 
		in_node		int,
		in_version	text
	)
RETURNS boolean AS $save_sketch_version$
DECLARE
	var_node	RECORD;
BEGIN
	SELECT * INTO var_node FROM nodes where node = in_node ORDER BY last,first DESC LIMIT 1;
	IF NOT FOUND THEN
		RETURN false;
	END IF;

	IF var_node.sketchversion IS NULL THEN
		UPDATE nodes SET sketchversion = in_version, last = now() WHERE id = var_node.id;
		return true;
	END IF;
	IF var_node.sketchversion = in_version THEN
		return true;
	END IF;
	UPDATE nodes SET last = now() WHERE id = var_node.id;
	INSERT INTO nodes (node,protocol,sketchname,sketchversion) 
		VALUES    (in_node,var_node.protocol,var_node.sketchname,in_version);
	RETURN true;
END;
$save_sketch_version$
LANGUAGE plpgsql;
