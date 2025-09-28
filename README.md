# Custom-Project-Bank-System-Model
This project is a WORK IN PROGRESS. It is a simplified model of a bank database system created in MySQL. It simulates common tasks of a bank, such as registrations of clients, creation of different types of accounts, executing transactions using double entry accounting, etc. The model considers a fictional bank based in Slovakia.

The database is equiped with multiple mechanisms like triggers, procedures and events that simplify data entry, ensure data consistency and prevent violations of internal rules of the bank.

In addition, the database contains a complex stored procedure called "p03_generate_new_client", which populates the tables in the database with mock data on a single client, along with their personal data, accounts as well as regular transactions. The generated data will be eventually used for analysis and data visualizations.
