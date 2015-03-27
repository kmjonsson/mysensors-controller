DROP TABLE values;
DROP TABLE sensors;
DROP TABLE nodes;

-- Information about nodes.
CREATE TABLE nodes (
	id		serial PRIMARY KEY NOT NULL,
	node		int NOT NULL CHECK (id > 0),
	first		timestamp NOT NULL DEFAULT now(),
	last		timestamp NOT NULL DEFAULT now(),
	CHECK		(first <= last)
);

-- Information about sensors
CREATE TABLE sensors (
	id		serial PRIMARY KEY,
	node		int NOT NULL REFERENCES nodes,
	sensor		int NOT NULL CHECK (id >= 0 AND id < 256),
	type		int NOT NULL CHECK (type >= 0),
	ttl		interval  NOT NULL DEFAULT '1day'::interval,
	first		timestamp NOT NULL DEFAULT now(),
	last		timestamp NOT NULL DEFAULT now(),
	CHECK		(first <= last)
);

-- Sampled values
CREATE TABLE values (
	id		serial PRIMARY KEY,
	sensor		int NOT NULL REFERENCES sensors,
	type		int NOT NULL CHECK (type >= 0),
	first		timestamp NOT NULL DEFAULT now(),
	last		timestamp NOT NULL DEFAULT now(),
	value		text	NOT NULL CHECK (length(value) > 0),
	CHECK		(first <= last)
);

-- Save (new) Sensor
CREATE OR REPLACE FUNCTION save_sensor ( 
		in_node		int,
		in_sensor	int,
		in_type		int
	)
RETURNS boolean AS $save_sensor$
DECLARE
	var_node	RECORD;
	var_sensor	RECORD;
BEGIN
	-- Fetch node
	SELECT id INTO var_node FROM nodes WHERE node = in_node 
		ORDER BY last DESC,first DESC LIMIT 1;
	IF NOT FOUND THEN
		INSERT INTO nodes (node) VALUES (var_node);
	END IF;
	SELECT id,type,ttl INTO var_sensor FROM sensors 
		WHERE node = var_node.id AND sensor = in_sensor
		ORDER BY last DESC,first DESC LIMIT 1;
	UPDATE nodes SET last = now() WHERE id = var_node.id;
	-- If found update last
	IF FOUND THEN
		UPDATE sensors SET last = now() WHERE id = var_sensor.id;
		-- if same we are done.
		IF var_sensor.type = in_type THEN
			return TRUE;
		END IF;
	END IF;
	-- Add new
	INSERT INTO sensors (node,sensor,type,ttl) 
		VALUES (var_node.id,in_sensor,in_type,var_sensor.ttl);
	RETURN true;
END;
$save_sensor$
LANGUAGE plpgsql;

-- Get next available node id and add emply node reservation in db
CREATE OR REPLACE FUNCTION get_next_available_nodeid ( )
RETURNS int AS $get_next_available_nodeid$
DECLARE
	var_res RECORD;
BEGIN
	SELECT max(node)+1 as next INTO var_res FROM nodes;
	IF var_res.next IS NULL THEN
		INSERT INTO nodes (node) VALUES (1);
		return 1;
	END IF;
	INSERT INTO nodes (node) VALUES (var_res.next);
	RETURN var_res.next;
END;
$get_next_available_nodeid$
LANGUAGE plpgsql;

-- Save value
CREATE OR REPLACE FUNCTION save_value ( 
		in_node		int,
		in_sensor	int,
		in_type		int,
		in_value	text
	)
RETURNS boolean AS $save_value$
DECLARE
	var_node	RECORD;
	var_sensor	RECORD;
	var_value	RECORD;
BEGIN
	-- Fetch node
	SELECT id INTO var_node FROM nodes WHERE node = in_node 
		ORDER BY last DESC,first DESC LIMIT 1;
	IF NOT FOUND THEN
		return false;
	END IF;
	-- Fetch sensor
	SELECT id,ttl INTO var_sensor FROM sensors 
		WHERE node = var_node.id AND sensor = in_sensor 
		ORDER BY last DESC,first DESC LIMIT 1;
	IF NOT FOUND THEN
		return false;
	END IF;
	-- Update last in sensors & nodes
	UPDATE sensors SET last = now() WHERE id = var_sensor.id;
	UPDATE nodes   SET last = now() WHERE id = var_node.id;
	-- Fetch Value
	SELECT id,type,last,value INTO var_value FROM values 
		WHERE sensor = var_sensor.id AND type = in_type
		ORDER BY last DESC ,first DESC LIMIT 1;
	-- Add new if not found
	IF FOUND THEN
		-- IF value older then 1h (change to something good)
		IF now() - var_value.last > var_sensor.ttl THEN
			-- Add new value without updateing last
			INSERT INTO values (sensor,type,value) 
				VALUES (var_sensor.id,in_type,in_value);
			RETURN true;
		END IF;

		UPDATE values  SET last = now() WHERE id = var_value.id;
		-- If value changed
		IF var_value.value <> in_value THEN
			INSERT INTO values (sensor,type,value) 
				VALUES (var_sensor.id,in_type,in_value);
		END IF;
	ELSE
		INSERT INTO values (sensor,type,value) 
			VALUES (var_sensor.id,in_type,in_value);
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
	var_node	RECORD;
	var_sensor	RECORD;
	var_value	RECORD;
BEGIN
	-- Fetch node
	SELECT * INTO var_node FROM nodes WHERE node = in_node 
		ORDER BY last DESC,first DESC LIMIT 1;
	IF NOT FOUND THEN
		return NULL;
	END IF;
	-- Fetch sensor
	SELECT * INTO var_sensor FROM sensors 
		WHERE node = var_node.id AND sensor = in_sensor 
		ORDER BY last DESC,first DESC LIMIT 1;
	IF NOT FOUND THEN
		return NULL;
	END IF;
	-- Fetch value
	SELECT * INTO var_value FROM values 
		WHERE 
				sensor = var_sensor.id 
			AND 
				type = in_type 
	--		AND
	--			now() - last < var_sensor.ttl
		ORDER BY last DESC,first DESC LIMIT 1;
	IF NOT FOUND THEN
		return NULL;
	END IF;
	return var_value.value;
END;
$get_value$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION save_batterylevel ( 
		in_node		int,
		in_level	int
	)
RETURNS boolean AS $save_batterylevel$
DECLARE 
        var_value      TEXT;
	var_res        BOOLEAN;
BEGIN   
	SELECT get_value(in_node,255,38) INTO var_value;
	IF var_value IS NULL THEN
		PERFORM save_sensor(in_node,255,38);
	END IF;
	SELECT save_value(in_node,255,38,in_level::text) INTO var_res;
	RETURN var_res;
END;
$save_batterylevel$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION save_protocol ( 
		in_node		int,
		in_protocol	text
	)
RETURNS boolean AS $save_protocol$
DECLARE
        var_value      TEXT;
	var_res        BOOLEAN;
BEGIN
	SELECT get_value(in_node,255,10000) INTO var_value;
	IF var_value IS NULL THEN
		PERFORM save_sensor(in_node,255,255);
	END IF;
	SELECT save_value(in_node,255,10000,in_protocol::text) INTO var_res;
	RETURN var_res;
END;
$save_protocol$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION save_sketch_name ( 
		in_node		int,
		in_name		text
	)
RETURNS boolean AS $save_sketch_name$
DECLARE
        var_value      TEXT;
	var_res        BOOLEAN;
BEGIN
	SELECT get_value(in_node,255,10001) INTO var_value;
	IF var_value IS NULL THEN
		PERFORM save_sensor(in_node,255,255);
	END IF;
	SELECT save_value(in_node,255,10001,in_protocol::text) INTO var_res;
	RETURN var_res;
END;
$save_sketch_name$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION save_sketch_version ( 
		in_node		int,
		in_version	text
	)
RETURNS boolean AS $save_sketch_version$
DECLARE
        var_value      TEXT;
	var_res        BOOLEAN;
BEGIN
	SELECT get_value(in_node,255,10002) INTO var_value;
	IF var_value IS NULL THEN
		PERFORM save_sensor(in_node,255,255);
	END IF;
	SELECT save_value(in_node,255,10002,in_protocol::text) INTO var_res;
	RETURN var_res;
END;
$save_sketch_version$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION save_version ( 
		in_node		int,
		in_version	text
	)
RETURNS boolean AS $save_version$
DECLARE
BEGIN
	-- Do nothing (successfully :-)
	RETURN true;
END;
$save_version$
LANGUAGE plpgsql;
