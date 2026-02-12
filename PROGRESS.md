# Development Progress

This document tracks the ongoing development of the ARM7TDMI interpreter. We are taking a methodical, "one step at a time" approach to ensure accuracy and maintainability.

## Achieved So Far

We have established the basic simulation infrastructure and implemented the logic for several fundamental ARM instructions:

*   **`MOV`**: Data transfer operations.
*   **`ADD`**: Arithmetic addition.
*   **`SUB`**: Arithmetic subtraction.
*   **`BL`**: Branch with Link (subroutine calls).

## Currently Working On

*   **Binary Ingestion**: We are currently working on reading actual ARM binary files from disk [`in the bin folder`] into the interpreter's memory.
*   **Emulation Loop**: Bridging the gap between the binary loader and the execution engine to emulate instructions directly from the loaded binary data.
*   **Fetch-Decode-Execute**: Refining the main CPU loop to process raw opcodes from the binary.