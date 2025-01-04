# Simple Cruise Management System (SCMS) DB

## Project Overview

This project is the Phase III implementation of the **Simple Cruise Management System (SCMS)** for the CS4400: Introduction to Database Systems course. The system is designed to manage cruise operations, including ships, ports, routes, passengers, and crew. The objective of this phase was to implement **stored procedures** and **views** to query and modify the database state according to the provided problem scenario.

The database was implemented using MySQL, adhering to relational database development best practices. Stored procedures and views were created to meet specific functional requirements and maintain data consistency across the system.

## Features Implemented

### Stored Procedures
1. **add_ship**: Adds a new ship to the system with specified attributes and validations.
2. **add_port**: Adds a new port with unique identifiers and geographic details.
3. **add_person**: Adds a new person with attributes defining their role (crew or passenger).
4. **grant_or_revoke_crew_license**: Toggles the license status of a crew member.
5. **offer_cruise**: Creates a new cruise with a valid route and ship assignment.
6. **cruise_arriving**: Updates the state of a cruise upon arrival at a port.
7. **cruise_departing**: Updates the state of a cruise upon departure from a port.
8. **person_boards**: Updates the location of a person boarding a cruise.
9. **person_disembarks**: Updates the location of a person disembarking a cruise.
10. **assign_crew**: Assigns a crew member to a specific cruise.
11. **recycle_crew**: Releases all crew assignments for a cruise after its completion.
12. **retire_cruise**: Removes a cruise from the system once it has ended.
13. **other supporting procedures**: Additional helper functions for data management.

### Views
1. **cruises_at_sea**: Displays cruises currently sailing, their locations, and schedules.
2. **cruises_docked**: Lists cruises that are docked at various ports.
3. **people_at_sea**: Provides details about people on board sailing cruises.
4. **people_docked**: Lists people currently docked at ports and their details.
5. **route_summary**: Summarizes the utilization of routes by various cruises.
6. **alternative_ports**: Shows ports within the same country as alternatives.

---

## Development Process

- **Relational Database Design**: Developed and maintained based on the provided Enhanced ERD and schema.
- **Stored Procedures**: Implemented using MySQL, ensuring compliance with the given specifications.
- **Views**: Designed to provide operators with insights into the database state from multiple perspectives.

---

## Instructions to Run

1. **Setup the Database**:
   - Create a MySQL database named `cruise_tracking`.
   - Import the provided schema and initial data set (dataset will not be provided in this repo).

2. **Load the SQL File**:
   - Execute the `cs4400_phase3_stored_procedures.sql` file in MySQL Workbench.
   - Ensure the script runs without errors.

3. **Test the System**:
   - Use the implemented stored procedures and views to query and update the database.
   - Validate functionality with test cases for each procedure and view.

---

## Deliverables

- **SQL File**: Contains all the stored procedures, views, and supporting database structures.
- **Test Cases**: Used to verify the functionality of the implemented procedures and views.

