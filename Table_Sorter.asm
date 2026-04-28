.MODEL SMALL
.STACK 1000h

.DATA 
    ; ASCII control characters for formatting output
    LF EQU 0AH                  ; Line feed character (newline)
    CR EQU 0DH                  ; Carriage return character
    
    ; System configuration constants - define maximum limits for the table
    MAX_TABLE_ROWS    EQU 50    ; Maximum number of rows allowed in table
    MAX_TABLE_COLS    EQU 10    ; Maximum number of columns allowed in table
    MAX_CELL_LENGTH   EQU 8     ; Maximum characters per cell (excluding terminator)
    COLUMN_WIDTH      EQU 12    ; Fixed width for each column for uniform spacing
    
    ; Interface text messages for user interaction (updated for multi-digit support)
    MSG1     DB CR, LF, 'Enter the number of columns (1-10): $'
    MSG2     DB CR, LF, 'Enter the number of rows (1-50): $'
    MSG3     DB CR, LF, 'Col $'
    MSG4     DB CR, LF, 'Enter column name: $'
    MSG5     DB CR, LF, 'Enter column type (S/N): $'
    MSG6     DB CR, LF, 'Row $'
    MSG7     DB ', Column $'
    MSG8     DB ': $'
    MSG9     DB CR, LF, 'Select column to sort by (1-$'
    MSG10    DB '): $'
    MSG11    DB CR, LF, '--- Original Table ---$'
    MSG12    DB CR, LF, '--- Sorted Table ---$'
    MSG13    DB ' | $'                              ; Column separator
    MSG14    DB CR, LF, '$'                         ; Newline message
    MSG15    DB CR, LF, 'Invalid input. Please try again.$'
    MSG16    DB CR, LF, 'Input cannot be empty. Please enter a value: $'  ; New message for empty input
    
    ; Padding spaces for column alignment
    PADDING_SPACES DB '            $'               ; 12 spaces for padding columns
    SEPARATOR_LINE DB '+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+-----------+$'

    ; Data storage variables - main data structures for the table
    column_count      DB ?                          ; Stores actual number of columns (1-10)
    row_count         DB ?                          ; Stores actual number of rows (1-50)
    ; Column headers storage - each header can be up to MAX_CELL_LENGTH chars plus null terminator
    column_headers    DB MAX_TABLE_COLS * (MAX_CELL_LENGTH + 1) DUP(?)
    ; Column data types storage - 'S' for string, 'N' for numeric
    column_datatypes  DB MAX_TABLE_COLS DUP(?)
    ; Main table data storage - organized as row-major order
    table_data        DB MAX_TABLE_ROWS * MAX_TABLE_COLS * (MAX_CELL_LENGTH + 1) DUP(?)
    
    ; Enhanced temporary variables for multi-digit input handling
    input_buffer      DB MAX_CELL_LENGTH + 2 DUP(?) ; Buffer for user input (increased size)
    number_buffer     DB 4 DUP(?)                   ; Buffer for number input (up to 3 digits + terminator)
    current_row       DB ?                          ; Current row being processed
    current_col       DB ?                          ; Current column being processed
    sort_column_idx   DB ?                          ; Index of column to sort by (1-based)
    sort_column_type  DB ?                          ; Data type of sort column ('S' or 'N')
    input_length      DB ?                          ; Length of current input
    
    ; Sorting variables - used during bubble sort operations
    row_swap_buffer   DB MAX_TABLE_COLS * (MAX_CELL_LENGTH + 1) DUP(?) ; Buffer for row swapping

.CODE
; Main procedure - entry point of the program
; Coordinates all major operations: input, display, sorting
MAIN PROC
    ; Initialize data segments - set up memory access
    MOV AX, @DATA               ; Load data segment address
    MOV DS, AX                  ; Set data segment register
    MOV ES, AX                  ; Set extra segment register for string operations
    
    ; Phase 1: Get table structure from user (now supports multi-digit input)
    CALL GET_TABLE_DIMENSIONS   ; Get number of rows and columns
    
    ; Phase 2: Define each column (name and data type)
    CALL GET_COLUMN_DETAILS     ; Collect column names and data types
    
    ; Phase 3: Populate the table with data
    CALL POPULATE_TABLE         ; Enter all table data from user
    
    ; Phase 4: Display original table before sorting
    LEA DX, MSG11               ; Load address of "Original Table" message
    CALL PRINT_STRING           ; Display the message
    CALL DISPLAY_TABLE          ; Show the table in original order
    
    ; Phase 5: Sort and display results
    CALL GET_SORT_COLUMN        ; Get column to sort by from user
    CALL BUBBLE_SORT_TABLE      ; Perform the sorting operation
    
    ; Phase 6: Display sorted table
    LEA DX, MSG12               ; Load address of "Sorted Table" message
    CALL PRINT_STRING           ; Display the message
    CALL DISPLAY_TABLE          ; Show the table after sorting
    
    ; Terminate program gracefully
    MOV AH, 4Ch                 ; DOS terminate program function
    INT 21h                     ; Call DOS interrupt
MAIN ENDP

; --- ENHANCED INPUT HANDLING PROCEDURES ---

; Enhanced procedure to get table dimensions with multi-digit support
; Now handles 1-10 columns and 1-50 rows properly
GET_TABLE_DIMENSIONS PROC
    ; Get column count with multi-digit support
    LEA DX, MSG1                ; Load "Enter number of columns" message
    CALL PRINT_STRING           ; Display the prompt
    
COLUMN_COUNT_PROMPT:
    CALL READ_NUMBER            ; Read multi-digit number into AX
    CMP AX, 1                   ; Check minimum value
    JB INVALID_COLUMN_INPUT     ; Jump if less than 1
    CMP AX, 10                  ; Check maximum value
    JA INVALID_COLUMN_INPUT     ; Jump if greater than 10
    
    ; Valid column count
    MOV column_count, AL        ; Store the column count
    JMP ROW_COUNT_PROMPT        ; Proceed to get row count
    
INVALID_COLUMN_INPUT:
    ; Display error and retry column input
    LEA DX, MSG15               ; Load "Invalid input" message
    CALL PRINT_STRING           ; Display error message
    LEA DX, MSG1                ; Reload column prompt
    CALL PRINT_STRING           ; Display prompt again
    JMP COLUMN_COUNT_PROMPT     ; Retry input
    
ROW_COUNT_PROMPT:
    ; Get row count with multi-digit support
    LEA DX, MSG2                ; Load "Enter number of rows" message
    CALL PRINT_STRING           ; Display the prompt
    
ROW_COUNT_INPUT_LOOP:
    CALL READ_NUMBER            ; Read multi-digit number into AX
    CMP AX, 1                   ; Check minimum value
    JB INVALID_ROW_INPUT        ; Jump if less than 1
    CMP AX, 50                  ; Check maximum value (changed from 9 to 50)
    JA INVALID_ROW_INPUT        ; Jump if greater than 50
    
    ; Valid row count
    MOV row_count, AL           ; Store row count
    RET                         ; Return to caller
    
INVALID_ROW_INPUT:
    ; Display error and retry row input
    LEA DX, MSG15               ; Load "Invalid input" message
    CALL PRINT_STRING           ; Display error message
    LEA DX, MSG2                ; Reload row prompt
    CALL PRINT_STRING           ; Display prompt again
    JMP ROW_COUNT_INPUT_LOOP    ; Retry input
GET_TABLE_DIMENSIONS ENDP

; New procedure to read multi-digit numbers from user input
; Output: AX contains the number (0-99)
; Uses Enter key to confirm input, Backspace for correction
READ_NUMBER PROC
    PUSH BX                     ; Preserve registers
    PUSH CX
    PUSH DX
    PUSH SI
    
    ; Initialize variables
    MOV AX, 0                   ; Result starts at 0
    MOV CX, 0                   ; Digit counter
    LEA SI, number_buffer       ; Use number buffer for temporary storage
    
READ_DIGIT_LOOP:
    ; Read one character
    MOV AH, 01h                 ; DOS read character function
    INT 21h                     ; Get character from user
    
    ; Check for special keys
    CMP AL, CR                  ; Is it Enter?
    JE VALIDATE_NUMBER          ; If yes, validate and return
    CMP AL, 08h                 ; Is it Backspace?
    JE HANDLE_NUMBER_BACKSPACE  ; If yes, handle backspace
    
    ; Check if it's a valid digit
    CMP AL, '0'                 ; Check if below '0'
    JB READ_DIGIT_LOOP          ; Ignore if not a digit
    CMP AL, '9'                 ; Check if above '9'
    JA READ_DIGIT_LOOP          ; Ignore if not a digit
    
    ; Check if we already have maximum digits (2 for numbers up to 50)
    CMP CX, 2                   ; Maximum 2 digits
    JAE READ_DIGIT_LOOP         ; Ignore if already at maximum
    
    ; Store digit and update display
    MOV [SI], AL                ; Store digit in buffer
    INC SI                      ; Move buffer pointer
    INC CX                      ; Increment digit count
    JMP READ_DIGIT_LOOP         ; Continue reading
    
HANDLE_NUMBER_BACKSPACE:
    ; Remove last digit if any
    CMP CX, 0                   ; Any digits to remove?
    JE READ_DIGIT_LOOP          ; If none, ignore backspace
    
    ; Visual backspace (move cursor back and erase)
    MOV DL, 08h                 ; Backspace character
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Move cursor back
    MOV DL, ' '                 ; Space to erase
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Erase character
    MOV DL, 08h                 ; Backspace again
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Position cursor
    
    ; Update counters
    DEC SI                      ; Move buffer pointer back
    DEC CX                      ; Decrease digit count
    JMP READ_DIGIT_LOOP         ; Continue reading
    
VALIDATE_NUMBER:
    ; Check if at least one digit was entered
    CMP CX, 0                   ; Any digits entered?
    JE READ_DIGIT_LOOP          ; If none, continue reading
    
    ; Convert stored digits to number
    MOV BYTE PTR [SI], '$'      ; Terminate string
    LEA SI, number_buffer       ; Reset to start of buffer
    CALL ASCII_TO_INT           ; Convert to integer in AX
    
    ; Restore registers and return
    POP SI
    POP DX
    POP CX
    POP BX
    RET
READ_NUMBER ENDP

; Helper procedure to print numbers (1-99)
; Input: AL contains the number to print
PRINT_NUMBER PROC
    PUSH AX                     ; Preserve registers
    PUSH DX
    
    CMP AL, 10                  ; Check if single or double digit
    JB PRINT_SINGLE_DIGIT       ; Jump if single digit
    
    ; Double digit number
    XOR AH, AH                  ; Clear high byte
    MOV BL, 10                  ; Divisor
    DIV BL                      ; AL = tens, AH = ones
    
    ; Print tens digit
    ADD AL, '0'                 ; Convert to ASCII
    MOV DL, AL                  ; Move to DL for printing
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Print tens digit
    
    ; Print ones digit
    MOV AL, AH                  ; Get ones digit from remainder
    ADD AL, '0'                 ; Convert to ASCII
    MOV DL, AL                  ; Move to DL for printing
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Print ones digit
    JMP PRINT_NUMBER_END        ; Jump to end
    
PRINT_SINGLE_DIGIT:
    ; Single digit number
    ADD AL, '0'                 ; Convert to ASCII
    MOV DL, AL                  ; Move to DL for printing
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Print digit
    
PRINT_NUMBER_END:
    ; Restore registers and return
    POP DX
    POP AX
    RET
PRINT_NUMBER ENDP

; Enhanced procedure to collect column details with improved display and empty input validation
GET_COLUMN_DETAILS PROC
    MOV current_col, 1          ; Start with first column
    
COLUMN_DEFINITION_LOOP:
    ; Display current column number being defined
    LEA DX, MSG3                ; Load "Col " message
    CALL PRINT_STRING           ; Display "Col "
    MOV AL, current_col         ; Get current column number
    CALL PRINT_NUMBER           ; Print the column number (handles 1-10)
    
    ; Get column name from user with empty input validation
    LEA DX, MSG4                ; Load "Enter column name" message
    CALL PRINT_STRING           ; Display prompt
    
GET_COLUMN_NAME_LOOP:
    CALL READ_USER_STRING       ; Read column name into buffer
    MOV AL, input_length        ; Check if input is empty
    CMP AL, 0                   ; Compare with 0
    JE EMPTY_COLUMN_NAME        ; Jump if empty input
    CALL STORE_COLUMN_HEADER    ; Store the column name
    JMP GET_COLUMN_TYPE         ; Proceed to get column type
    
EMPTY_COLUMN_NAME:
    LEA DX, MSG16               ; Load "Input cannot be empty" message
    CALL PRINT_STRING           ; Display error message
    JMP GET_COLUMN_NAME_LOOP    ; Retry input
    
GET_COLUMN_TYPE:
    ; Get data type for this column
    LEA DX, MSG5                ; Load "Enter column type (S/N)" message
    CALL PRINT_STRING           ; Display prompt
    
GET_DATATYPE_INPUT:
    ; Read data type character
    MOV AH, 01h                 ; DOS read character function
    INT 21h                     ; Get character from user
    ; Check for valid data type inputs (S, s, N, n)
    CMP AL, 'S'                 ; Check for uppercase 'S'
    JE SAVE_AS_STRING           ; Jump if string type
    CMP AL, 's'                 ; Check for lowercase 's'
    JE SAVE_AS_STRING           ; Jump if string type
    CMP AL, 'N'                 ; Check for uppercase 'N'
    JE SAVE_AS_NUMERIC          ; Jump if numeric type
    CMP AL, 'n'                 ; Check for lowercase 'n'
    JE SAVE_AS_NUMERIC          ; Jump if numeric type
    JMP GET_DATATYPE_INPUT      ; Invalid input, try again
    
SAVE_AS_STRING:
    MOV AL, 'S'                 ; Normalize to uppercase 'S'
    JMP STORE_TYPE              ; Store the type
SAVE_AS_NUMERIC:
    MOV AL, 'N'                 ; Normalize to uppercase 'N'
STORE_TYPE:
    CALL STORE_COLUMN_DATATYPE  ; Store the data type
    
    ; Move to next column or finish if all columns defined
    INC current_col             ; Move to next column
    MOV AL, current_col         ; Get current column number
    CMP AL, column_count        ; Compare with total columns
    JBE COLUMN_DEFINITION_LOOP  ; Continue if more columns to define
    
    RET                         ; All columns defined, return
GET_COLUMN_DETAILS ENDP

; Enhanced procedure to populate table with improved row/column display and empty input validation
POPULATE_TABLE PROC
    MOV current_row, 1          ; Start with first row
    
ROW_INPUT_LOOP:
    MOV current_col, 1          ; Start with first column of current row
    
COLUMN_INPUT_LOOP:
    ; Display prompt showing current row and column position
    LEA DX, MSG6                ; Load "Row " message
    CALL PRINT_STRING           ; Display "Row "
    
    ; Display current row number (supports 1-50)
    MOV AL, current_row         ; Get current row number
    CALL PRINT_NUMBER           ; Print the row number
    
    ; Display ", Column " part of prompt
    LEA DX, MSG7                ; Load ", Column " message
    CALL PRINT_STRING           ; Display the text
    
    ; Display current column number (supports 1-10)
    MOV AL, current_col         ; Get current column number
    CALL PRINT_NUMBER           ; Print the column number
    
    ; Display the colon and space
    LEA DX, MSG8                ; Load ": " message
    CALL PRINT_STRING           ; Display ": "
    
    ; Get data for this cell with empty input validation
GET_CELL_DATA_LOOP:
    CALL READ_USER_STRING       ; Read user input into buffer
    MOV AL, input_length        ; Check if input is empty
    CMP AL, 0                   ; Compare with 0
    JE EMPTY_CELL_DATA          ; Jump if empty input
    CALL STORE_CELL_DATA        ; Store input in table data structure
    JMP NEXT_CELL               ; Proceed to next cell
    
EMPTY_CELL_DATA:
    LEA DX, MSG16               ; Load "Input cannot be empty" message
    CALL PRINT_STRING           ; Display error message
    JMP GET_CELL_DATA_LOOP      ; Retry input
    
NEXT_CELL:
    ; Move to next column or next row
    INC current_col             ; Increment column counter
    MOV AL, current_col         ; Get current column number
    CMP AL, column_count        ; Compare with total columns
    JBE COLUMN_INPUT_LOOP       ; Continue if more columns in this row
    
    ; Move to next row
    INC current_row             ; Increment row counter
    MOV AL, current_row         ; Get current row number
    CMP AL, row_count           ; Compare with total rows
    JBE ROW_INPUT_LOOP          ; Continue if more rows to fill
    
    RET                         ; All data entered, return
POPULATE_TABLE ENDP

; Enhanced procedure to get sort column with multi-digit support
GET_SORT_COLUMN PROC
    ; Display prompt with valid range
    LEA DX, MSG9                ; Load "Select column to sort by (1-"
    CALL PRINT_STRING           ; Display first part
    
    ; Display maximum column number (handles 1-10)
    MOV AL, column_count        ; Get total columns
    CALL PRINT_NUMBER           ; Print the number (handles 1-10)
    
    LEA DX, MSG10               ; Load "): " message
    CALL PRINT_STRING           ; Complete the prompt
    
VALIDATE_SORT_COLUMN_LOOP:
    ; Read column selection using new number reader
    CALL READ_NUMBER            ; Get multi-digit input in AX
    
    ; Validate column selection
    CMP AX, 1                   ; Check if less than 1
    JB INVALID_SORT_CHOICE      ; Invalid if below 1
    MOV BL, column_count        ; Get total columns
    XOR BH, BH                  ; Clear high byte
    CMP AX, BX                  ; Compare with maximum
    JA INVALID_SORT_CHOICE      ; Invalid if above maximum
    
    ; Valid column selection
    MOV sort_column_idx, AL     ; Store selected column index
    
    ; Store column data type for sorting algorithm
    DEC AL                      ; Convert to 0-based index
    XOR AH, AH                  ; Clear high byte
    LEA BX, column_datatypes    ; Load address of data types array
    ADD BX, AX                  ; Add offset to get specific column type
    MOV AL, [BX]                ; Load data type
    MOV sort_column_type, AL    ; Store for sorting procedure
    RET                         ; Valid selection made, return
    
INVALID_SORT_CHOICE:
    ; Display error and retry
    LEA DX, MSG15               ; Load "Invalid input" message
    CALL PRINT_STRING           ; Display error
    JMP GET_SORT_COLUMN         ; Retry selection
GET_SORT_COLUMN ENDP

; --- UTILITY PROCEDURES ---

; Enhanced string reading procedure with better buffer management and empty input detection
READ_USER_STRING PROC
    PUSH AX                     ; Preserve registers
    PUSH CX
    PUSH SI
    
    ; Initialize input buffer and character counter
    LEA SI, input_buffer        ; Point to input buffer
    MOV CX, 0                   ; Character count = 0
    
READ_CHAR_LOOP:
    ; Read one character from keyboard
    MOV AH, 01h                 ; DOS read character function
    INT 21h                     ; Get character
    
    ; Check for special characters
    CMP AL, CR                  ; Is it carriage return (Enter)?
    JE END_OF_INPUT             ; If yes, end input
    CMP AL, 08h                 ; Is it backspace?
    JE HANDLE_BACKSPACE         ; If yes, handle backspace
    CMP CX, MAX_CELL_LENGTH     ; Check if buffer full
    JAE READ_CHAR_LOOP          ; If full, ignore character
    
    ; Normal character - add to buffer
    MOV [SI], AL                ; Store character in buffer
    INC SI                      ; Move to next buffer position
    INC CX                      ; Increment character count
    JMP READ_CHAR_LOOP          ; Continue reading
    
HANDLE_BACKSPACE:
    ; Handle backspace - remove last character if any
    CMP CX, 0                   ; Any characters to remove?
    JE READ_CHAR_LOOP           ; If none, ignore backspace
    
    ; Visual backspace (move cursor back and erase)
    MOV DL, 08h                 ; Backspace character
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Move cursor back
    MOV DL, ' '                 ; Space to erase
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Erase character
    MOV DL, 08h                 ; Backspace again
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Position cursor
    
    DEC SI                      ; Move back in buffer
    DEC CX                      ; Decrease character count
    JMP READ_CHAR_LOOP          ; Continue reading
    
END_OF_INPUT:
    ; Store input length for empty input validation
    MOV input_length, CL        ; Store the length of input
    
    ; Terminate string with '$' for DOS string functions
    MOV BYTE PTR [SI], '$'      ; Add string terminator
    
    ; Restore registers and return
    POP SI
    POP CX
    POP AX
    RET
READ_USER_STRING ENDP

; Simple procedure to print a '$'-terminated string
PRINT_STRING PROC
    PUSH AX                     ; Preserve AX register
    MOV AH, 09h                 ; DOS print string function
    INT 21h                     ; Call DOS interrupt
    POP AX                      ; Restore AX register
    RET
PRINT_STRING ENDP

; --- DATA STORAGE PROCEDURES ---

; Enhanced column header storage with better addressing
STORE_COLUMN_HEADER PROC
    PUSH AX                     ; Preserve all registers used
    PUSH BX
    PUSH CX
    PUSH SI
    PUSH DI
    
    ; Calculate storage offset for current column
    MOV AL, current_col         ; Get current column number
    DEC AL                      ; Convert to 0-based index
    MOV BL, MAX_CELL_LENGTH + 1 ; Size of each header slot
    MUL BL                      ; Calculate offset
    
    ; Set up source and destination for string copy
    LEA DI, column_headers      ; Load base address of headers array
    ADD DI, AX                  ; Add offset to get storage location
    LEA SI, input_buffer        ; Source is the input buffer
    
    ; Copy header string to storage
    MOV CX, MAX_CELL_LENGTH + 1 ; Number of bytes to copy
    REP MOVSB                   ; Copy string from SI to DI
    
    ; Restore all registers
    POP DI
    POP SI
    POP CX
    POP BX
    POP AX
    RET
STORE_COLUMN_HEADER ENDP

; Enhanced column datatype storage
STORE_COLUMN_DATATYPE PROC
    PUSH BX                     ; Preserve registers
    PUSH DI
    
    ; Calculate storage location for current column's data type
    MOV BL, current_col         ; Get current column number
    DEC BL                      ; Convert to 0-based index
    XOR BH, BH                  ; Clear high byte of index
    LEA DI, column_datatypes    ; Load base address of datatypes array
    ADD DI, BX                  ; Add offset to get storage location
    MOV [DI], AL                ; Store data type character
    
    ; Restore registers and return
    POP DI
    POP BX
    RET
STORE_COLUMN_DATATYPE ENDP

; Enhanced cell data storage with improved addressing
STORE_CELL_DATA PROC
    PUSH AX                     ; Preserve all registers used
    PUSH BX
    PUSH CX
    PUSH SI
    PUSH DI
    
    ; Calculate storage position using row-major order formula
    MOV AL, current_row         ; Get current row number
    DEC AL                      ; Convert to 0-based index
    MOV BL, column_count        ; Get total columns
    MUL BL                      ; Multiply row by columns
    MOV BL, MAX_CELL_LENGTH + 1 ; Size of each cell
    MUL BL                      ; Multiply by cell size
    MOV BX, AX                  ; Store row offset in BX
    
    ; Add column offset to row offset
    MOV AL, current_col         ; Get current column number
    DEC AL                      ; Convert to 0-based index
    MOV CL, MAX_CELL_LENGTH + 1 ; Size of each cell
    MUL CL                      ; Calculate column offset
    ADD BX, AX                  ; Add to row offset for final position
    
    ; Set up source and destination for data copy
    LEA DI, table_data          ; Load base address of table data
    ADD DI, BX                  ; Add offset to get storage location
    LEA SI, input_buffer        ; Source is the input buffer
    
    ; Copy cell data to storage
    MOV CX, MAX_CELL_LENGTH + 1 ; Number of bytes to copy
    REP MOVSB                   ; Copy data from SI to DI
    
    ; Restore all registers
    POP DI
    POP SI
    POP CX
    POP BX
    POP AX
    RET
STORE_CELL_DATA ENDP

; --- ENHANCED DISPLAY PROCEDURES ---

; Enhanced table display with better formatting and vertical alignment
DISPLAY_TABLE PROC
    PUSH AX                     ; Preserve registers
    PUSH BX
    PUSH CX
    
    ; Print a blank line before table
    LEA DX, MSG14               ; Load newline message
    CALL PRINT_STRING           ; Print blank line
    
    ; Print top border
    CALL PRINT_TABLE_BORDER     ; Print the top border line
    
    ; Display column headers first
    CALL PRINT_TABLE_HEADER     ; Print all column headers with spacing
    
    ; Print separator line after headers
    CALL PRINT_TABLE_BORDER     ; Print separator line
    
    ; Display all data rows
    MOV current_row, 1          ; Start with first row
    
ROW_DISPLAY_LOOP:
    CALL PRINT_TABLE_ROW        ; Print current row
    
    ; Move to next row
    INC current_row             ; Increment row counter
    MOV AL, current_row         ; Get current row number
    CMP AL, row_count           ; Compare with total rows
    JBE ROW_DISPLAY_LOOP        ; Continue if more rows to display
    
    ; Print bottom border
    CALL PRINT_TABLE_BORDER     ; Print the bottom border line
    
    ; Restore registers and return
    POP CX
    POP BX
    POP AX
    RET
DISPLAY_TABLE ENDP

; New procedure to print table borders for better visual alignment
PRINT_TABLE_BORDER PROC
    PUSH AX                     ; Preserve registers
    PUSH CX
    PUSH DX
    
    ; Calculate how many columns to draw borders for
    MOV CL, column_count        ; Get number of columns
    XOR CH, CH                  ; Clear high byte
    
    ; Print left edge
    MOV DL, '+'                 ; Print corner/junction
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Print character
    
BORDER_LOOP:
    ; Print horizontal line for each column
    PUSH CX                     ; Save column counter
    MOV CX, COLUMN_WIDTH - 1    ; Width minus borders
    
DASH_LOOP:
    MOV DL, '-'                 ; Print dash
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Print character
    LOOP DASH_LOOP              ; Continue for column width
    
    POP CX                      ; Restore column counter
    
    ; Print junction or end
    MOV DL, '+'                 ; Print corner/junction
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Print character
    
    LOOP BORDER_LOOP            ; Continue for all columns
    
    ; Print newline
    LEA DX, MSG14               ; Load newline message
    CALL PRINT_STRING           ; Print newline
    
    ; Restore registers and return
    POP DX
    POP CX
    POP AX
    RET
PRINT_TABLE_BORDER ENDP

; Enhanced header printing with improved formatting and vertical alignment
PRINT_TABLE_HEADER PROC
    MOV current_col, 1          ; Start with first column
    
    ; Print left border
    MOV DL, '|'                 ; Print vertical bar
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Print character
    
HEADER_PRINT_LOOP:
    ; Get address of current header and display it
    CALL GET_HEADER_ADDRESS     ; Get address of current header in BX
    MOV DX, BX                  ; Move address to DX for printing
    CALL PRINT_STRING           ; Display the header text
    
    ; Add padding to make columns equal width
    CALL PRINT_COLUMN_PADDING   ; Add spaces for consistent column width
    
    ; Print column separator
    MOV DL, '|'                 ; Print vertical bar
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Print character
    
    ; Check if this is the last column
    MOV AL, current_col         ; Get current column number
    CMP AL, column_count        ; Compare with total columns
    JAE END_OF_HEADER           ; Jump if last column
    
    ; Move to next column
    INC current_col             ; Increment column counter
    JMP HEADER_PRINT_LOOP       ; Continue with next column
    
END_OF_HEADER:
    ; End header row with newline
    LEA DX, MSG14               ; Load newline message
    CALL PRINT_STRING           ; Print newline
    RET
PRINT_TABLE_HEADER ENDP

; Enhanced row printing procedure with vertical alignment
PRINT_TABLE_ROW PROC
    MOV current_col, 1          ; Start with first column
    
    ; Print left border
    MOV DL, '|'                 ; Print vertical bar
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Print character
    
CELL_PRINT_LOOP:
    ; Get address of current cell and display it
    CALL GET_CELL_POINTER       ; Get address of current cell in BX
    MOV DX, BX                  ; Move address to DX for printing
    CALL PRINT_STRING           ; Display the cell content
    
    ; Add padding to make columns equal width
    CALL PRINT_COLUMN_PADDING   ; Add spaces for consistent column width
    
    ; Print column separator
    MOV DL, '|'                 ; Print vertical bar
    MOV AH, 02h                 ; DOS display character
    INT 21h                     ; Print character
    
    ; Check if this is the last column in the row
    MOV AL, current_col         ; Get current column number
    CMP AL, column_count        ; Compare with total columns
    JAE END_OF_ROW              ; Jump if last column
    
    ; Move to next column
    INC current_col             ; Increment column counter
    JMP CELL_PRINT_LOOP         ; Continue with next column
    
END_OF_ROW:
    ; End row with newline
    LEA DX, MSG14               ; Load newline message
    CALL PRINT_STRING           ; Print newline
    RET
PRINT_TABLE_ROW ENDP

; Enhanced padding procedure with better content measurement for vertical alignment
PRINT_COLUMN_PADDING PROC
    PUSH AX                     ; Preserve registers
    PUSH BX
    PUSH CX
    PUSH DX
    PUSH SI
    
    ; Get current content to measure its length
    MOV AL, current_row
    CMP AL, 1
    JB USE_HEADER_FOR_PADDING   ; If less than 1, use header
    
    ; We're in a data row, get cell content
    CALL GET_CELL_POINTER       ; Get current cell address in BX
    JMP MEASURE_CONTENT_LENGTH
    
USE_HEADER_FOR_PADDING:
    ; We're in header row, get header content
    CALL GET_HEADER_ADDRESS     ; Get current header address in BX
    
MEASURE_CONTENT_LENGTH:
    ; Count characters in current content until '$' terminator
    MOV SI, BX                  ; SI points to content start
    MOV CX, 0                   ; Character counter
    
COUNT_CHARS:
    MOV AL, [SI]                ; Get current character
    CMP AL, '$'                 ; Check for string terminator
    JE CALC_PADDING             ; If found, calculate padding
    INC CX                      ; Increment character count
    INC SI                      ; Move to next character
    CMP CX, MAX_CELL_LENGTH     ; Safety check to prevent infinite loop
    JB COUNT_CHARS              ; Continue counting if within limit
    
CALC_PADDING:
    ; Calculate how many spaces needed for equal column width (excluding borders)
    MOV AX, COLUMN_WIDTH - 1    ; Get desired column width minus border
    SUB AX, CX                  ; Subtract actual content length
    CMP AX, 0                   ; Check if padding needed
    JLE NO_PADDING              ; Skip if no padding needed
    
    ; Print the required number of spaces
    MOV CX, AX                  ; Number of spaces to print
    
PRINT_SPACES:
    MOV DL, ' '                 ; Space character
    MOV AH, 02h                 ; DOS display character function
    INT 21h                     ; Print one space
    LOOP PRINT_SPACES           ; Repeat for all needed spaces
    
NO_PADDING:
    ; Restore registers and return
    POP SI
    POP DX
    POP CX
    POP BX
    POP AX
    RET
PRINT_COLUMN_PADDING ENDP

; --- ADDRESS CALCULATION PROCEDURES ---

; Enhanced header address calculation
GET_HEADER_ADDRESS PROC
    PUSH AX                     ; Preserve AX register
    
    ; Calculate offset for current column header
    MOV AL, current_col         ; Get current column number
    DEC AL                      ; Convert to 0-based index
    MOV BL, MAX_CELL_LENGTH + 1 ; Size of each header slot
    MUL BL                      ; Calculate byte offset
    
    ; Calculate final address
    LEA BX, column_headers      ; Load base address of headers array
    ADD BX, AX                  ; Add offset to get specific header address
    
    POP AX                      ; Restore AX register
    RET
GET_HEADER_ADDRESS ENDP

; Enhanced cell pointer calculation
GET_CELL_POINTER PROC
    PUSH AX                     ; Preserve registers
    PUSH CX
    
    ; Calculate row offset using row-major order
    MOV AL, current_row         ; Get current row number
    DEC AL                      ; Convert to 0-based index
    MOV BL, column_count        ; Get total columns per row
    MUL BL                      ; Calculate row offset in cells
    MOV BL, MAX_CELL_LENGTH + 1 ; Size of each cell in bytes
    MUL BL                      ; Calculate row offset in bytes
    MOV BX, AX                  ; Store row offset in BX
    
    ; Calculate column offset
    MOV AL, current_col         ; Get current column number
    DEC AL                      ; Convert to 0-based index
    MOV CL, MAX_CELL_LENGTH + 1 ; Size of each cell in bytes
    MUL CL                      ; Calculate column offset in bytes
    ADD BX, AX                  ; Add column offset to row offset
    
    ; Calculate final address
    MOV AX, OFFSET table_data   ; Get base address of table data
    ADD BX, AX                  ; Add offset to get specific cell address
    
    ; Restore registers and return
    POP CX
    POP AX
    RET
GET_CELL_POINTER ENDP

; --- SORTING PROCEDURES ---

; Enhanced bubble sort with unchanged core logic
BUBBLE_SORT_TABLE PROC
    PUSH AX                     ; Preserve all registers used
    PUSH BX
    PUSH CX
    PUSH DX
    
    ; Check if sorting is needed (at least 2 rows required)
    MOV AL, row_count           ; Get total number of rows
    CMP AL, 2                   ; Compare with minimum for sorting
    JB SORTING_COMPLETE         ; Skip sorting if less than 2 rows
    
    ; Outer loop counter for bubble sort passes
    MOV CX, 0                   ; Initialize outer loop counter
    
OUTER_SORT_LOOP:
    ; Calculate number of comparisons needed in this pass
    MOV AL, row_count           ; Get total rows
    DEC AL                      ; Subtract 1 (last element position)
    SUB AL, CL                  ; Subtract current pass number
    CMP AL, 0                   ; Check if any comparisons left
    JBE SORTING_COMPLETE        ; Complete if no more comparisons
    MOV DH, AL                  ; Store comparison count in DH
    
    ; Inner loop for comparing adjacent rows
    MOV BX, 1                   ; Start with first row
    
INNER_SORT_LOOP:
    ; Check if we've done all comparisons for this pass
    MOV AL, BL                  ; Get current row number
    CMP AL, DH                  ; Compare with comparison limit
    JA NEXT_OUTER_ITERATION     ; Move to next pass if done
    
    ; Preserve loop counters before comparison
    PUSH BX                     ; Save inner loop counter
    PUSH CX                     ; Save outer loop counter
    PUSH DX                     ; Save comparison limit
    
    ; Compare current row with next row
    MOV current_row, BL         ; Set current row for comparison
    CALL COMPARE_ROWS           ; Compare rows, result in AL
    CMP AL, 1                   ; Check if swap is needed
    JNE SKIP_SWAP               ; Skip swap if order is correct
    
    ; Swap rows if they are out of order
    CALL SWAP_ROWS              ; Perform the row swap
    
SKIP_SWAP:
    ; Restore loop counters after comparison
    POP DX                      ; Restore comparison limit
    POP CX                      ; Restore outer loop counter
    POP BX                      ; Restore inner loop counter
    
    ; Move to next pair of rows
    INC BX                      ; Increment row counter
    JMP INNER_SORT_LOOP         ; Continue inner loop
    
NEXT_OUTER_ITERATION:
    ; Move to next pass of bubble sort
    INC CX                      ; Increment outer loop counter
    JMP OUTER_SORT_LOOP         ; Continue outer loop
    
SORTING_COMPLETE:
    ; Restore all registers and return
    POP DX
    POP CX
    POP BX
    POP AX
    RET
BUBBLE_SORT_TABLE ENDP

; Enhanced row comparison procedure
COMPARE_ROWS PROC
    PUSH BX                     ; Preserve all registers used
    PUSH CX
    PUSH DX
    PUSH SI
    PUSH DI
    
    ; Calculate address of sort column in current row
    MOV AL, current_row         ; Get current row number
    DEC AL                      ; Convert to 0-based index
    MOV BL, column_count        ; Get columns per row
    MUL BL                      ; Calculate row offset in cells
    MOV BL, MAX_CELL_LENGTH + 1 ; Size of each cell
    MUL BL                      ; Calculate row offset in bytes
    MOV BX, AX                  ; Store row offset
    MOV AL, sort_column_idx     ; Get sort column index
    DEC AL                      ; Convert to 0-based
    MOV CL, MAX_CELL_LENGTH + 1 ; Size of each cell
    MUL CL                      ; Calculate column offset
    ADD BX, AX                  ; Add offsets
    LEA SI, table_data          ; Get table base address
    ADD SI, BX                  ; SI points to current row's sort cell
    
    ; Calculate address of sort column in next row
    MOV AL, current_row         ; Get current row number
    MOV BL, column_count        ; Get columns per row
    MUL BL                      ; Calculate row offset in cells
    MOV BL, MAX_CELL_LENGTH + 1 ; Size of each cell
    MUL BL                      ; Calculate row offset in bytes
    MOV BX, AX                  ; Store row offset
    MOV AL, sort_column_idx     ; Get sort column index
    DEC AL                      ; Convert to 0-based
    MOV CL, MAX_CELL_LENGTH + 1 ; Size of each cell
    MUL CL                      ; Calculate column offset
    ADD BX, AX                  ; Add offsets
    LEA DI, table_data          ; Get table base address
    ADD DI, BX                  ; DI points to next row's sort cell
    
    ; Choose comparison method based on data type
    MOV AL, sort_column_type    ; Get sort column data type
    CMP AL, 'S'                 ; Check if string type
    JE DO_LEXICAL_COMPARE       ; Jump if string comparison needed
    
    ; Numeric comparison
    CALL NUMERIC_STRING_COMPARE ; Compare as numbers
    JMP COMPARISON_DONE         ; Skip to end
    
DO_LEXICAL_COMPARE:
    ; String comparison
    CALL LEXICAL_STRING_COMPARE ; Compare as strings
    
COMPARISON_DONE:
    ; Restore all registers and return
    POP DI
    POP SI
    POP DX
    POP CX
    POP BX
    RET
COMPARE_ROWS ENDP

; Enhanced numeric comparison procedure
NUMERIC_STRING_COMPARE PROC
    PUSH BX                     ; Preserve registers used
    PUSH CX
    PUSH DX
    
    ; Convert first string to integer
    PUSH DI                     ; Save DI (second string address)
    CALL ASCII_TO_INT           ; Convert SI string to integer in AX
    MOV BX, AX                  ; Store first number in BX
    POP DI                      ; Restore DI
    
    ; Convert second string to integer
    PUSH SI                     ; Save SI (first string address)
    MOV SI, DI                  ; Move second string address to SI
    CALL ASCII_TO_INT           ; Convert SI string to integer in AX
    MOV CX, AX                  ; Store second number in CX
    POP SI                      ; Restore SI
    
    ; Compare the two numbers
    CMP BX, CX                  ; Compare first with second
    JB NUMERIC_SWAP_NEEDED      ; Jump if first > second (swap needed)
    MOV AL, 0                   ; No swap needed
    JMP NUMERIC_COMPARE_END     ; Jump to end
    
NUMERIC_SWAP_NEEDED:
    MOV AL, 1                   ; Swap is needed
    
NUMERIC_COMPARE_END:
    ; Restore registers and return
    POP DX
    POP CX
    POP BX
    RET
NUMERIC_STRING_COMPARE ENDP

; Enhanced lexical comparison procedure
LEXICAL_STRING_COMPARE PROC
    PUSH BX                     ; Preserve registers used
    PUSH CX
    PUSH SI
    PUSH DI
    
LEXICAL_LOOP:
    ; Get characters from both strings
    MOV AL, [SI]                ; Get character from first string
    MOV BL, [DI]                ; Get character from second string
    
    ; Check for end of strings
    CMP AL, '$'                 ; Check if first string ends
    JE STR1_ENDS                ; Handle first string ending
    CMP BL, '$'                 ; Check if second string ends
    JE STR2_ENDS                ; Handle second string ending
    
    ; Compare current characters
    CMP AL, BL                  ; Compare characters
    JB NO_SWAP_NEEDED           ; First < second, no swap
    JA SWAP_NEEDED              ; First > second, swap needed
    
    ; Characters are equal, move to next position
    INC SI                      ; Move to next char in first string
    INC DI                      ; Move to next char in second string
    JMP LEXICAL_LOOP            ; Continue comparison
    
STR1_ENDS:
    ; First string ended, check if second also ends
    CMP BL, '$'                 ; Check if second string also ends
    JE STRINGS_ARE_EQUAL        ; Both end, strings are equal
    MOV AL, 0                   ; First is shorter, no swap needed
    JMP LEXICAL_COMPARE_END     ; Jump to end
    
STR2_ENDS:
    ; Second string ended but first didn't
    MOV AL, 1                   ; First is longer, swap needed
    JMP LEXICAL_COMPARE_END     ; Jump to end
    
STRINGS_ARE_EQUAL:
NO_SWAP_NEEDED:
    MOV AL, 0                   ; No swap needed
    JMP LEXICAL_COMPARE_END     ; Jump to end
    
SWAP_NEEDED:
    MOV AL, 1                   ; Swap needed
    
LEXICAL_COMPARE_END:
    ; Restore registers and return
    POP DI
    POP SI
    POP CX
    POP BX
    RET
LEXICAL_STRING_COMPARE ENDP

; Enhanced ASCII to integer conversion
ASCII_TO_INT PROC
    PUSH BX                     ; Preserve registers used
    PUSH CX
    PUSH SI
    
    ; Initialize conversion variables
    MOV AX, 0                   ; Result starts at 0
    MOV BX, 10                  ; Decimal base for conversion
    
CONVERT_LOOP:
    ; Get next character from string
    MOV CL, [SI]                ; Load character into CL
    CMP CL, '$'                 ; Check for string terminator
    JE END_CONVERSION           ; End if terminator found
    CMP CL, '0'                 ; Check if below '0'
    JB END_CONVERSION           ; End if not a digit
    CMP CL, '9'                 ; Check if above '9'
    JA END_CONVERSION           ; End if not a digit
    
    ; Convert digit and accumulate result
    SUB CL, '0'                 ; Convert ASCII to numeric value
    MUL BX                      ; Multiply current result by 10
    ADD AL, CL                  ; Add new digit to result
    ADC AH, 0                   ; Handle carry to high byte
    
    ; Move to next character
    INC SI                      ; Advance string pointer
    JMP CONVERT_LOOP            ; Continue conversion
    
END_CONVERSION:
    ; Restore registers and return
    POP SI
    POP CX
    POP BX
    RET
ASCII_TO_INT ENDP

; Enhanced row swapping procedure
SWAP_ROWS PROC
    PUSH AX                     ; Preserve all registers used
    PUSH BX
    PUSH CX
    PUSH SI
    PUSH DI
    
    ; Calculate address of first row (current_row)
    MOV AL, current_row         ; Get current row number
    DEC AL                      ; Convert to 0-based index
    MOV BL, column_count        ; Get columns per row
    MUL BL                      ; Calculate row offset in cells
    MOV BL, MAX_CELL_LENGTH + 1 ; Size of each cell in bytes
    MUL BL                      ; Calculate row offset in bytes
    LEA SI, table_data          ; Get table base address
    ADD SI, AX                  ; SI points to first row
    
    ; Calculate address of second row (current_row+1)
    MOV AL, current_row         ; Get current row number
    MOV BL, column_count        ; Get columns per row
    MUL BL                      ; Calculate row offset in cells
    MOV BL, MAX_CELL_LENGTH + 1 ; Size of each cell in bytes
    MUL BL                      ; Calculate row offset in bytes
    LEA DI, table_data          ; Get table base address
    ADD DI, AX                  ; DI points to second row
    
    ; Calculate row size in bytes
    MOV AL, column_count        ; Get number of columns
    MOV AH, MAX_CELL_LENGTH + 1 ; Size of each cell
    MUL AH                      ; Calculate total row size
    MOV CX, AX                  ; Store row size in CX
    
    ; Step 1: Copy first row to temporary buffer
    PUSH SI                     ; Save first row address
    PUSH DI                     ; Save second row address
    PUSH CX                     ; Save row size
    LEA DI, row_swap_buffer     ; Point to temporary buffer
    CLD                         ; Clear direction flag (forward copy)
    REP MOVSB                   ; Copy first row to buffer
    POP CX                      ; Restore row size
    POP DI                      ; Restore second row address
    POP SI                      ; Restore first row address
    
    ; Step 2: Copy second row to first row's position
    PUSH SI                     ; Save first row address
    PUSH CX                     ; Save row size
    MOV SI, DI                  ; Source is second row
    SUB DI, CX                  ; Destination is first row (go back)
    CLD                         ; Clear direction flag
    REP MOVSB                   ; Copy second row to first position
    POP CX                      ; Restore row size
    POP SI                      ; Restore first row address
    
    ; Step 3: Copy temporary buffer to second row's position
    LEA SI, row_swap_buffer     ; Source is temporary buffer
    CLD                         ; Clear direction flag
    REP MOVSB                   ; Copy buffer to second row position
    
    ; Restore all registers and return
    POP DI
    POP SI
    POP CX
    POP BX
    POP AX
    RET
SWAP_ROWS ENDP

END MAIN
