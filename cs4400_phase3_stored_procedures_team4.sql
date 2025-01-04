-- CS4400: Introduction to Database Systems: Monday, July 1, 2024
-- Simple Cruise Management System Course Project Stored Procedures [TEMPLATE] (v0)
-- Views, Functions & Stored Procedures

/* This is a standard preamble for most of our scripts.  The intent is to establish
a consistent environment for the database behavior. */
set global transaction isolation level serializable;
set global SQL_MODE = 'ANSI,TRADITIONAL';
set names utf8mb4;
set SQL_SAFE_UPDATES = 0;

set @thisDatabase = 'cruise_tracking';
use cruise_tracking;
-- -----------------------------------------------------------------------------
-- stored procedures and views
-- -----------------------------------------------------------------------------
/* Standard Procedure: If one or more of the necessary conditions for a procedure to
be executed is false, then simply have the procedure halt execution without changing
the database state. Do NOT display any error messages, etc. */

-- [_] supporting functions, views and stored procedures
-- -----------------------------------------------------------------------------
/* Helpful library capabilities to simplify the implementation of the required
views and procedures. */
-- -----------------------------------------------------------------------------
drop function if exists leg_time;
delimiter //
create function leg_time (ip_distance integer, ip_speed integer)
	returns time reads sql data
begin
	declare total_time decimal(10,2);
    declare hours, minutes integer default 0;
    set total_time = ip_distance / ip_speed;
    set hours = truncate(total_time, 0);
    set minutes = truncate((total_time - hours) * 60, 0);
    return maketime(hours, minutes, 0);
end //
delimiter ;

-- [1] add_ship()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new ship.  A new ship must be sponsored
by an existing cruiseline, and must have a unique name for that cruiseline. 
A ship must also have a non-zero seat capacity and speed. A ship
might also have other factors depending on it's type, like paddles or some number
of lifeboats.  Finally, a ship must have a new and database-wide unique location
since it will be used to carry passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_ship;
delimiter //
create procedure add_ship (in ip_cruiselineID varchar(50), in ip_ship_name varchar(50),
	in ip_max_capacity integer, in ip_speed integer, in ip_locationID varchar(50),
    in ip_ship_type varchar(100), in ip_uses_paddles boolean, in ip_lifeboats integer)
sp_main: begin
IF NOT EXISTS (SELECT cruiselineID FROM cruiseline WHERE cruiselineID = ip_cruiselineID) OR EXISTS (SELECT ship_name FROM ship WHERE ship_name = ip_ship_name) OR ip_max_capacity = 0 OR ip_speed = 0
THEN LEAVE sp_main;
END IF;
INSERT INTO location VALUE (ip_locationID);
INSERT INTO ship VALUES (ip_cruiselineID, ip_ship_name, ip_max_capacity, ip_speed, ip_locationID, ip_ship_type, ip_uses_paddles, ip_lifeboats);
end //
delimiter ;

-- [2] add_port()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new port.  A new port must have a unique
identifier along with a new and database-wide unique location if it will be used
to support ship arrivals and departures.  A port may have a longer, more
descriptive name.  An airport must also have a city, state, and country designation. */
-- -----------------------------------------------------------------------------
drop procedure if exists add_port;
delimiter //
create procedure add_port (in ip_portID char(3), in ip_port_name varchar(200),
    in ip_city varchar(100), in ip_state varchar(100), in ip_country char(3), in ip_locationID varchar(50))
sp_main: begin
IF EXISTS (SELECT portID FROM ship_port WHERE portID = ip_portID)
THEN LEAVE sp_main;
END IF;
INSERT INTO location VALUE (ip_locationID);
INSERT INTO ship_port VALUES (ip_portID, ip_port_name, ip_city, ip_state, ip_country, ip_locationID);
end //
delimiter ;

-- [3] add_person()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new person.  A new person must reference a unique
identifier along with a database-wide unique location used to determine where the
person is currently located: either at a port, on a ship, or both, at any given
time.  A person must have a first name, and might also have a last name.

A person can hold a crew role or a passenger role (exclusively).  As crew,
a person must have a tax identifier to receive pay, and an experience level.  As a
passenger, a person will have some amount of rewards miles, along with a
certain amount of funds needed to purchase cruise packages. */
-- -----------------------------------------------------------------------------

drop procedure if exists add_person;
delimiter //
create procedure add_person (in ip_personid varchar(50), in ip_first_name varchar(100),
    in ip_last_name varchar(100), in ip_locationid varchar(50), in ip_taxid varchar(50),
    in ip_experience integer, in ip_miles integer, in ip_funds integer)
sp_main: begin
    if exists (select 1 from person where personid = ip_personid) then
        leave sp_main;
    end if;

    if not exists (select 1 from location where locationid = ip_locationid) then
        leave sp_main;
    end if;

    insert into person (personid, first_name, last_name) values (ip_personid, ip_first_name, ip_last_name);

    insert into person_occupies (personid, locationid) values (ip_personid, ip_locationid);
    
    if ip_taxid is not null and ip_experience is not null then
        insert into crew (personid, taxid, experience) values (ip_personid, ip_taxid, ip_experience);
    elseif ip_miles is not null and ip_funds is not null then
        insert into passenger (personid, miles, funds) values (ip_personid, ip_miles, ip_funds);
    end if;
end //
delimiter ;

-- [4] grant_or_revoke_crew_license()
-- -----------------------------------------------------------------------------
/* This stored procedure inverts the status of a crew member's license.  If the license
doesn't exist, it must be created; and, if it already exists, then it must be removed. */
-- -----------------------------------------------------------------------------
drop procedure if exists grant_or_revoke_crew_license;
delimiter //
create procedure grant_or_revoke_crew_license (in ip_personID varchar(50), in ip_license varchar(100))
sp_main: begin
	declare lID int;
	select count(*) into lID from licenses where personID = ip_personID and license = ip_license;
	If lID > 0 THEN
	Delete from licenses where personID = ip_personID and license = ip_license;
	Else
	Insert into licenses (personID, license) VALUES (ip_personID, ip_license);
    End if;
end //
delimiter ;

-- [5] offer_cruise()
-- -----------------------------------------------------------------------------
/* This stored procedure creates a new cruise.  The cruise can be defined before
a ship has been assigned for support, but it must have a valid route.  And
the ship, if designated, must not be in use by another cruise.  The cruise
can be started at any valid location along the route except for the final stop,
and it will begin docked.  You must also include when the cruise will
depart along with its cost. */
-- -----------------------------------------------------------------------------
drop procedure if exists offer_cruise;
delimiter //
create procedure offer_cruise (in ip_cruiseID varchar(50), in ip_routeID varchar(50),
    in ip_support_cruiseline varchar(50), in ip_support_ship_name varchar(50), in ip_progress integer,
    in ip_next_time time, in ip_cost integer)
sp_main: begin
IF NOT EXISTS (SELECT routeID FROM route WHERE routeID = ip_routeID)
THEN LEAVE sp_main;
ELSEIF EXISTS (SELECT support_ship_name, support_cruiseline FROM cruise WHERE support_ship_name = ip_support_ship_name AND support_cruiseline = ip_support_cruiseline) AND ip_support_ship_name IS NOT NULL
THEN LEAVE sp_main;
END IF;
INSERT INTO cruise values (ip_cruiseID, ip_routeID, ip_support_cruiseline, ip_support_ship_name, ip_progress, 'docked', ip_next_time, ip_cost);
end //
delimiter ;

-- [6] cruise_arriving()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a cruise arriving at the next port
along its route.  The status should be updated, and the next_time for the cruise 
should be moved 8 hours into the future to allow for the passengers to disembark 
and sight-see for the next leg of travel.  Also, the crew of the cruise should receive 
increased experience, and the passengers should have their rewards miles updated. 
Everyone on the cruise must also have their locations updated to include the port of 
arrival as one of their locations, (as per the scenario description, a person's location 
when the ship docks includes the ship they are on, and the port they are docked at). */
-- -----------------------------------------------------------------------------
drop procedure if exists cruise_arriving;
delimiter //
create procedure cruise_arriving (in ip_cruiseID varchar(50))
sp_main: begin
    declare port_locid varchar(50);
    declare current_progress int;
    declare miles_travelled int;
    declare counter int;
	declare all_personid varchar(500);
    declare person_id varchar(50);
    
	select progress into current_progress from cruise where cruiseID = ip_cruiseID;
    select distance into miles_travelled from leg where legID = (select legID from route_path where routeID = (select routeID from cruise where cruiseID = ip_cruiseID) and sequence = current_progress);
	select locationID into port_locid from ship_port where portID = (select arrival from leg where legID = (select legID from route_path where routeID = (select routeID from cruise where cruiseID = ip_cruiseID) and sequence = current_progress));
    set counter = (select count(personID) from (select personID from passenger_books where cruiseID = ip_cruiseID union select personID from crew where assigned_to = ip_cruiseID) s) * -1;
    select group_concat(personID) into all_personid from (select personID from passenger_books where cruiseID = ip_cruiseID union select personID from crew where assigned_to = ip_cruiseID) s;
    
    update cruise set ship_status = 'docked', next_time = addtime(next_time,'08:00:00') where cruiseID = ip_cruiseID;
    while counter < 0 do
		set person_id = substring_index((select substring(all_personid,(select locate(substring_index(all_personid,',',counter),all_personid)),(select length(substring_index(all_personid,',',counter))))),',',1);
		insert into person_occupies values (person_id,port_locid);
        if person_id in (select personID from passenger_books where cruiseID = ip_cruiseID) then
			update passenger set miles = miles + miles_travelled where personID = person_id;
		elseif person_id in (select personID from crew where assigned_to = ip_cruiseID) then
			update crew set experience = experience + 1 where personID = person_id;
		end if;
		set counter = counter + 1;
	end while;
end //
delimiter ;

-- [7] cruise_departing()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the state for a cruise departing from its current
port towards the next port along its route.  The time for the next leg of
the cruise must be calculated based on the distance and the speed of the ship. The progress
of the ship must also be incremented on a successful departure, and the status must be updated.
We must also ensure that everyone, (crew and passengers), are back on board. 
If the cruise cannot depart because of missing people, then the cruise must be delayed 
for 30 minutes. You must also update the locations of all the people on that cruise,
so that their location is no longer connected to the port the cruise departed from, 
(as per the scenario description, a person's location when the ship sets sails only includes 
the ship they are on and not the port of departure). */
-- -----------------------------------------------------------------------------
drop procedure if exists cruise_departing;
delimiter //
create procedure cruise_departing (in ip_cruiseID varchar(50))
sp_main: begin
	declare next_leg_distance int;
    declare next_leg_time time;
	declare port_locid varchar(50);
    declare ship_locid varchar(50);
	declare cruiseline varchar(50);
 	declare shipname varchar(50);
	declare current_progress int;
	declare locID varchar(50);
	declare route varchar(50);
	declare counter int;     
	declare all_personid varchar(500);
	declare person_id varchar(50);
    
	select support_cruiseline,support_ship_name,progress into cruiseline,shipname,current_progress from cruise where cruiseID = ip_cruiseID;
  	select locationID into port_locid from ship_port where 
  		portID = (select departure from leg where legID = (select legID from route_path where routeID = (select routeID from cruise where cruiseID = ip_cruiseID) and sequence = current_progress + 1));
 	select locationID into ship_locid from ship where cruiselineID = (select support_cruiseline from cruise where cruiseID = ip_cruiseID) and ship_name = (select support_ship_name from cruise where cruiseID = ip_cruiseID); 
	select group_concat(personID) into all_personid from (select personID from passenger_books where cruiseID = ip_cruiseID union select personID from crew where assigned_to = ip_cruiseID) s;
	set counter = (select count(personID) from (select personID from passenger_books where cruiseID = ip_cruiseID union select personID from crew where assigned_to = ip_cruiseID) s) * -1;
	select distance into next_leg_distance from leg where 
  		legID = (select legID from route_path where routeID = (select routeID from cruise where cruiseID = ip_cruiseID) and sequence = current_progress + 1);
 	set next_leg_time = sec_to_time((next_leg_distance*3600) / (select speed from ship where cruiselineID = cruiseline and ship_name = shipname));
    
	if ((select count(personID) from (select personID from passenger_books where cruiseID = ip_cruiseID union select personID from crew where assigned_to = ip_cruiseID) s) -
      (select count(personID) from person_occupies where locationID = ship_locid)) > 0 then
  		update cruise set next_time = addtime(next_time,'00:30:00') where cruiseID = ip_cruiseID;
          leave sp_main;
 	else
 		update cruise set next_time = addtime(next_time,next_leg_time), ship_status = 'sailing', progress = progress + 1 where cruiseID = ip_cruiseID;
		while counter < 0 do
			set person_id = substring_index((select substring(all_personid,(select locate(substring_index(all_personid,',',counter),all_personid)),(select length(substring_index(all_personid,',',counter))))),',',1);
 			delete from person_occupies where personID = person_id and locationID = port_locid;
			set counter = counter + 1;
 		end while;
		leave sp_main;
	end if;
end //
delimiter ;

-- [8] person_boards()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the location for people, (crew and passengers), 
getting on a in-progress cruise at its current port.  The person must be at the same port as the cruise,
and that person must either have booked that cruise as a passenger or been assigned
to it as a crew member. The person's location cannot already be assigned to the ship
they are boarding. After running the procedure, the person will still be assigned to the port location, 
but they will also be assigned to the ship location. */
-- -----------------------------------------------------------------------------
drop procedure if exists person_boards;
delimiter //
create procedure person_boards (in ip_personID varchar(50), in ip_cruiseID varchar(50))
sp_main: begin
	declare current_port varchar(50); 
	declare current_progress int; 
    declare ship_locid varchar(50);
    
	select progress into current_progress from cruise where cruiseID = ip_cruiseID;
	select locationID into current_port from ship_port where 
		portID = (select departure from leg where legID = (select legID from route_path where routeID = (select routeID from cruise where cruiseID = ip_cruiseID) and sequence = current_progress + 1));
	select locationID into ship_locid from ship where cruiselineID = (select support_cruiseline from cruise where cruiseID = ip_cruiseID) and ship_name = (select support_ship_name from cruise where cruiseID = ip_cruiseID);
    
	if current_port in (select locationID from person_occupies where personID = ip_personID) then
		if ip_personID in (select personID from passenger_books where cruiseID = ip_cruiseID union select personID from crew where assigned_to = ip_cruiseID) then
			if ship_locid not in (select locationID from person_occupies where personID = ip_personID) then
				insert into person_occupies values (ip_personID,ship_locid);
                leave sp_main;
			end if;
		end if;
	end if;
end //
delimiter ;

-- [9] person_disembarks()
-- -----------------------------------------------------------------------------
/* This stored procedure updates the location for people, (crew and passengers), 
getting off a cruise at its current port.  The person must be on the ship supporting 
the cruise, and the cruise must be docked at a port. The person should no longer be
assigned to the ship location, and they will only be assigned to the port location. */
-- -----------------------------------------------------------------------------
drop procedure if exists person_disembarks;
delimiter //
create procedure person_disembarks (in ip_personID varchar(50), in ip_cruiseID varchar(50))
sp_main: begin
	declare port_locid varchar(50); 
	declare current_progress int; 
    declare ship_locid varchar(50);
    declare s_status varchar(100);
    
	select progress,ship_status into current_progress,s_status from cruise where cruiseID = ip_cruiseID;
	select locationID into port_locid from ship_port where 
		portID = (select arrival from leg where legID = (select legID from route_path where routeID = (select routeID from cruise where cruiseID = ip_cruiseID) and sequence = current_progress));
	select locationID into ship_locid from ship where cruiselineID = (select support_cruiseline from cruise where cruiseID = ip_cruiseID) and ship_name = (select support_ship_name from cruise where cruiseID = ip_cruiseID);
    
	if ship_locid in (select locationID from person_occupies where personID = ip_personID) then
		if s_status = 'docked' then
            delete from person_occupies where personID = ip_personID and locationID = ship_locid;
			leave sp_main;
		end if;
	end if;
end //
delimiter ;

-- [10] assign_crew()
-- -----------------------------------------------------------------------------
/* This stored procedure assigns a crew member as part of the cruise crew for a given
cruise.  The crew member being assigned must have a license for that type of ship,
and must be at the same location as the cruise's first port. Also, the cruise must not 
already be in progress. Also, a crew member can only support one cruise (i.e. one ship) at a time. */
-- -----------------------------------------------------------------------------
drop procedure if exists assign_crew;
delimiter //
create procedure assign_crew (in ip_cruiseID varchar(50), ip_personID varchar(50))
sp_main: begin
declare ship_t varchar(100);
declare port_locid varchar(50); 
declare current_progress int;

select ship_type into ship_t from ship where cruiselineID = (select support_cruiseline from cruise where cruiseID = ip_cruiseID) and ship_name = (select support_ship_name from cruise where cruiseID = ip_cruiseID);
select progress into current_progress from cruise where cruiseID = ip_cruiseID;
select locationID into port_locid from ship_port where 
	portID = (select departure from leg where legID = (select legID from route_path where routeID = (select routeID from cruise where cruiseID = ip_cruiseID) and sequence = current_progress + 1));

if ship_t in (select license from licenses where personID = ip_personID) then
	if port_locid in (select locationID from person_occupies where personID = ip_personID) then
		if current_progress = 0 then
			if (select assigned_to from crew where personID = ip_personID) is null then
				update crew set assigned_to = ip_cruiseID where personID = ip_personID;
				leave sp_main;
			end if;
		end if;
	end if;
end if;
end //
delimiter ;

-- [11] recycle_crew()
-- -----------------------------------------------------------------------------
/* This stored procedure releases the crew assignments for a given cruise. The
cruise must have ended, and all passengers must have disembarked. */
-- -----------------------------------------------------------------------------
drop procedure if exists recycle_crew;
delimiter //
create procedure recycle_crew (in ip_cruiseID varchar(50))
sp_main: begin
	declare current_progress int;
	declare s_status varchar(100);
    declare ship_locid varchar(50);
    declare all_crewid varchar(500);
    declare person_id varchar(50); 
    declare counter int;
    
	select locationID into ship_locid from ship where cruiselineID = (select support_cruiseline from cruise where cruiseID = ip_cruiseID) and ship_name = (select support_ship_name from cruise where cruiseID = ip_cruiseID);
	select progress,ship_status into current_progress,s_status from cruise where cruiseID = ip_cruiseID;
	select group_concat(personID) into all_crewid from (select personID from crew where assigned_to = ip_cruiseID) c;
	set counter = (select count(personID) from (select personID from crew where assigned_to = ip_cruiseID) c) * -1;
    
    if s_status = 'docked' then
		if current_progress = 0 or (select max(sequence) from route_path where routeID = (select routeID from cruise where cruiseID = ip_cruiseID)) then
			if (select count(*) from person_occupies where locationID = ship_locid and personID in (select personID from passenger_books where cruiseID = ip_cruiseID)) = 0 then
				while counter < 0 do
					set person_id = substring_index((select substring(all_crewid,(select locate(substring_index(all_crewid,',',counter),all_crewid)),(select length(substring_index(all_crewid,',',counter))))),',',1);
					update crew set assigned_to = null where personID = person_id;
					set counter = counter + 1;
				end while;
                leave sp_main;
			end if;
		end if;
	end if;
end //
delimiter ;

-- [12] retire_cruise()
-- -----------------------------------------------------------------------------
/* This stored procedure removes a cruise that has ended from the system.  The
cruise must be docked, and either be at the start its route, or at the
end of its route.  And the cruise must be empty - no crew or passengers. */
-- -----------------------------------------------------------------------------
drop procedure if exists retire_cruise;
delimiter //
create procedure retire_cruise (in ip_cruiseID varchar(50))
sp_main: begin
	DECLARE cruise_ended BOOLEAN;
    DECLARE is_start_or_end BOOLEAN;
    DECLARE cruise_empty BOOLEAN;
    DECLARE route_legs INT;
    
    SELECT ship_status = 'docked'
    INTO cruise_ended
    FROM cruise
    WHERE cruiseID = ip_cruiseID;

    SELECT COUNT(*) INTO route_legs
    FROM route_path
    WHERE routeID = (SELECT routeID FROM cruise WHERE cruiseID = ip_cruiseID);

    SELECT (progress = 0 OR progress = route_legs)
    INTO is_start_or_end
    FROM cruise
    WHERE cruiseID = ip_cruiseID;

    SELECT (COUNT(*) = 0)
    INTO cruise_empty
    FROM (
        SELECT personID FROM passenger_books WHERE cruiseID = ip_cruiseID
        UNION
        SELECT personID FROM crew WHERE assigned_to = ip_cruiseID
    ) AS occupants;

    DELETE FROM cruise WHERE cruiseID = ip_cruiseID;
end //
delimiter ;

-- [13] cruises_at_sea()
-- -----------------------------------------------------------------------------
/* This view describes where cruises that are currently sailing are located. */
-- -----------------------------------------------------------------------------
create or replace view cruises_at_sea (departing_from, arriving_at, num_cruises,
	cruise_list, earliest_arrival, latest_arrival, ship_list) as
select leg.departure, leg.arrival, count(cruise.cruiseID), group_concat(cruise.cruiseID), MIN(next_time), MAX(next_time), group_concat(ship.locationID) FROM cruise JOIN ship ON support_ship_name = ship_name 
JOIN route_path ON cruise.routeID = route_path.routeID JOIN leg ON route_path.legID = leg.legID JOIN ship_port ON leg.departure = ship_port.portID WHERE (cruise.ship_status = 'sailing') 
AND (route_path.sequence = cruise.progress) GROUP BY leg.departure, leg.arrival;

-- [14] cruises_docked()
-- -----------------------------------------------------------------------------
/* This view describes where cruises that are currently docked are located. */
-- -----------------------------------------------------------------------------
create or replace view cruises_docked (departing_from, num_cruises,
	cruise_list, earliest_departure, latest_departure, ship_list) as 
select ship_port.portID, count(cruise.cruiseID), group_concat(cruise.cruiseID), MIN(next_time), MAX(next_time), group_concat(ship.locationID) FROM cruise JOIN ship ON support_ship_name = ship_name 
JOIN route_path ON cruise.routeID = route_path.routeID JOIN leg ON route_path.legID = leg.legID JOIN ship_port ON leg.departure = ship_port.portID WHERE (cruise.ship_status = 'docked') 
AND (cruise.progress NOT LIKE (SELECT MAX(sequence) FROM route_path WHERE route_path.routeID = cruise.routeID)) AND (route_path.sequence = (cruise.progress + 1)) GROUP BY ship_port.portID;

-- [15] people_at_sea()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently at sea are located. */
-- -----------------------------------------------------------------------------
create or replace view people_at_sea (departing_from, arriving_at, num_ships,
	ship_list, cruise_list, earliest_arrival, latest_arrival, num_crew,
	num_passengers, num_people, person_list) as
Select departure,arrival,count(distinct locationID),group_concat(distinct locationID), group_concat(distinct cruise.cruiseID),
min(next_time),max(next_time), count(distinct crew.personID), 
count(distinct passenger_books.personID), 
(count(distinct crew.personID) +
count(distinct passenger_books.personID)), -- select group_concat(personID order by personID seperator ',') as c
-- from (select personID from passenger_books union select personID from crew) 
concat(group_concat(distinct crew.personID order by length(crew.personID),crew.personID asc), ',' , group_concat(distinct passenger_books.personID order by length(passenger_books.personID),passenger_books.personID asc))
from cruise
-- group_concat(distinct passenger_books.personID,',',  distinct crew.personID) 
-- from cruise
join route_path on route_path.routeID =  cruise.routeID 
join leg on leg.legID = route_path.legID
join ship on (ship.cruiselineID,ship.ship_name) = (cruise.support_cruiseline,cruise.support_ship_name) 
join crew on crew.assigned_to = cruise.cruiseID
join passenger_books on passenger_books.cruiseID = cruise.cruiseID
-- join ship on cruise.support_cruiseline = ship.cruiselineID
-- join crew on cruise.cruiseID = crew.assigned_to
where ship_status = 'sailing' and  cruise.progress = route_path.sequence 
group by departure,arrival;

-- [16] people_docked()
-- -----------------------------------------------------------------------------
/* This view describes where people who are currently docked are located. */
-- -----------------------------------------------------------------------------
create or replace view people_docked (departing_from, ship_port, port_name,
	city, state, country, num_crew, num_passengers, num_people, person_list) as
select
    sp.portid as departing_from,
    sp.locationid as ship_port,
    sp.port_name,
    sp.city,
    sp.state,
    sp.country,
    count(distinct c.personid) as num_crew,
    count(distinct p.personid) as num_passengers,
    count(distinct po.personid) as num_people,
    group_concat(distinct po.personid order by cast(substring(po.personid, 2) as unsigned) asc separator ',') as person_list
from
    ship_port sp
    join person_occupies po on sp.locationid = po.locationid
    left join crew c on po.personid = c.personid
    left join passenger p on po.personid = p.personid
where
    sp.portid not in (
        select arrival
        from leg l
        join route_path rp on l.legid = rp.legid
        join cruise cr on rp.routeid = cr.routeid
        where cr.ship_status = 'docked'
        and rp.sequence = (
            select max(rp2.sequence)
            from route_path rp2
            where rp2.routeid = rp.routeid
        )
    )
    and po.personid != 'p0' -- exclude personid 'p0'
group by
    sp.portid, sp.locationid, sp.port_name, sp.city, sp.state, sp.country;

-- [17] route_summary()
-- -----------------------------------------------------------------------------
/* This view describes how the routes are being utilized by different cruises. */
-- -----------------------------------------------------------------------------
create or replace view route_summary (route, num_legs, leg_sequence, route_length,
	num_cruises, cruise_list, port_sequence) as
select
    r.routeid as route,
    count(distinct rp.legid) as num_legs,
    group_concat(distinct rp.legid order by rp.sequence asc separator ',') as leg_sequence,
    sum(distinct l.distance) as route_length,
    count(distinct c.cruiseid) as num_cruises,
    group_concat(distinct c.cruiseid order by c.cruiseid asc separator ',') as cruise_list,
    group_concat(distinct concat(sp1.portid, '->', sp2.portid) order by rp.sequence asc separator ',') as port_sequence
from
    route r
    join route_path rp on r.routeid = rp.routeid
    join leg l on rp.legid = l.legid
    join ship_port sp1 on l.departure = sp1.portid
    join ship_port sp2 on l.arrival = sp2.portid
    left join cruise c on r.routeid = c.routeid
group by
    r.routeid;

-- [18] alternative_ports()
-- -----------------------------------------------------------------------------
/* This view displays ports that share the same country. */
-- -----------------------------------------------------------------------------
create or replace view alternative_ports (country, num_ports,
	port_code_list, port_name_list) as
select
    country,
    count(portID) as num_ports,
    group_concat(portID order by portID asc separator ',') as port_code_list,
    group_concat(port_name order by portID asc separator ',') as port_name_list
from
    ship_port
group by
    country;
