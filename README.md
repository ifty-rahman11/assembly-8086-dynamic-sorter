# Interactive Data Table Manager & Sorter (8086 Assembly)

## 💾 Overview
This project is an interactive data table management program developed in 8086 Assembly Language. The software allows users to dynamically generate a table, input data across multiple rows and columns, and perform type-specific sorting directly on the 8086 microprocessor architecture.

## ⚙️ Core Features & Constraints Managed
Developing an interactive database strictly in assembly required precise memory and register management to meet the following system constraints:
**Dynamic Structure:** Supports dynamic creation of tables up to 50 rows by 10 columns.
**Mixed Data Types:** Handles both numeric data and string data, with strings constrained to a maximum of 8 bytes per cell.
* **Advanced Sorting Algorithms:** Implements column-specific sorting.Numeric columns are sorted in descending order using numeric comparison, while string columns are sorted in ascending (dictionary) order using ASCII value comparison. 
**No Null Values:** Enforces validation to ensure no cell is left empty during user input.
