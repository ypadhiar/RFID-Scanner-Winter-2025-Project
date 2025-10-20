  .global _start
  .data
  // 7SD segment codes – see https://www.dcode.fr/7-segment-display?__r=1.1a32af4ede8c0241e82b89f9a6acebd7
  hex_number_array:
      .byte 0b00111111    @ 0 (0x3F)
      .byte 0b00000110    @ 1 (0x06)
      .byte 0b01011011    @ 2 (0x5B)
      .byte 0b01001111    @ 3 (0x4F)
      .byte 0b01100110    @ 4 (0x66)
      .byte 0b01101101    @ 5 (0x6C)
      .byte 0b01111101    @ 6 (0x7D)
      .byte 0b00000111    @ 7 (0x07)
      .byte 0b01111111    @ 8 (0x7F)
      .byte 0b01101111    @ 9 (0x6F)
  .align 4
  hex_data_array:
      .word 0x3F737937    @  "OPEN"
      .word 0x383F6D79    @  "LOSE"
      .word 0x39          @ Letter C 
      .word 0x50793D      @ (reg)
      .word 0x5E5E795E    @ (ddEd)
      .word 0x77          @ Letter A  
      .word 0x38797750    @ (LEAr)
      .word 0x39          @ Letter C 
      .word 0x50505C50    @ (rror)
      .word 0x79          @ Letter E
      .word 0x5079775E @rEAD

  .align 4
  uid_array:
      .word 0,0,0,0,0,0,0,0,0,0
  uid_array_length:
      .word 0
  time_storage:     .word 0

  UID_BASE:           .word uid_array
  UID_LENGTH_BASE:    .word uid_array_length
  hex_data_array_addr:.word hex_data_array
  hex_number_array_addr:.word hex_number_array
  TIME_BASE:          .word 0

  .text
  .align 4
      @ Define hardware addresses (as immediate constants)
      .equ SW_BASE, 0xFF200040   @ RFID input
      .equ LED_BASE, 0xFF200000
      .equ HEX3_HEX0_BASE, 0xFF200020
      .equ HEX5_HEX4_BASE, 0xFF200030
      .equ BUTTON_BASE, 0xFF200050
      .equ TIMER_BASE, 0xFFFEC600

  _start:
    ldr   r9, =SW_BASE
    ldr   r8, =BUTTON_BASE
    ldr   r7, =hex_data_array_addr
    ldr   r7, [r7]         @ r7 now holds address of hex_data_array
    ldr   r6, =TIMER_BASE
    ldr   r5, =hex_number_array_addr
    ldr   r5, [r5]         @ r5 now holds address of hex_number_array
  
    ldr   r0, =200000       @ For 1 ms if the system clock is 200 MHz
    str   r0, [r6, #0]      @ Set the timer's load register

    mov   r0, #1
    str   r0, [r6, #12]     @ Clear any pending interrupt

    mov   r0, #0b011        @ Enable
    str   r0, [r6, #8]      @ Store into the timer's control register

    b _main_loop

  _main_loop:
    ldr   r4, =BUTTON_BASE
    ldr   r0, [r4]
    cmp   r0, #2          @ button 1 pressed? (registration mode)

    beq _registration_mode_switch
    cmp   r0, #1          @ button 0 pressed? (simulate RFID UID read)
    bne   _main_loop      @ if not, keep polling

    ldr   r4, =SW_BASE
    ldr   r0, [r4]        @ load switches (simulate UID)
    ldr   r2, =0xFFFFFFFF       @ initialize index to -1
    bl    _check_uid_exists  @ check if the UID exists
    ldr   r2, =0xFFFFFFFF         @ initialize index to -1
    cmp   r1, r2         @ if not found…
    beq   _display_error  @ …display error message
    b      _unlock_lock //if found, unlock lock

  _registration_mode_switch:
    bl _display_alt
    b _register_deregister_device

  _display_alt:
    push {r4, lr}
    ldr   r1, [r7, #12]    
    ldr   r4, =HEX3_HEX0_BASE
    str   r1, [r4]
    ldr   r0, =1000     @ Delay: 1000 ms (1 s)
    bl    _delay
    bl    _clear_hex_display
    pop {r4, lr}
    bx lr

  _register_deregister_device:
    ldr   r4, =BUTTON_BASE
    ldr   r0, [r4]
    cmp   r0, #2        @ check if button 1 (exit registration) pressed
    beq   _read_loop
    cmp   r0, #1        @ check if button 0 (UID input) pressed
    bne   _register_deregister_device

    ldr   r4, =SW_BASE
    ldr   r0, [r4]      @ read switches
    bl    _check_uid_exists  @ check if UID exists
    ldr  r4, =0xFFFFFFFF
    cmp   r1, r4       @ if UID not found…
    beq   _add_to_memory  @ …add it to memory
    b     _remove_from_memory  @ otherwise, remove it
    
_read_loop:
	bl _display_read
	b  _main_loop
  _display_error:
    ldr   r1, [r7, #32]    
    ldr   r4, =HEX3_HEX0_BASE
    str   r1, [r4]
    ldr   r1, [r7, #36]    
    ldr   r4, =HEX5_HEX4_BASE
    str   r1, [r4]
    ldr   r0, =2000     @ Delay: 2000 ms (2 s)
    bl    _delay
    bl    _clear_hex_display
    b     _main_loop

    
  _display_added:
    push {r4}
    ldr   r1, [r7, #16]    
    ldr   r4, =HEX3_HEX0_BASE
    str   r1, [r4]
    ldr   r1, [r7, #20]    
    ldr   r4, =HEX5_HEX4_BASE
    str   r1, [r4]
    ldr   r0, =2000     @ Delay: 2000 ms (2 s)
    pop {r4}
    bl    _delay
    bl    _clear_hex_display
    b     _main_loop
        
  _display_read:
    push {r4}
    ldr   r1, [r7, #40]    
    ldr   r4, =HEX3_HEX0_BASE
    str   r1, [r4]
    ldr   r0, =1000     @ Delay: 2000 ms (2 s)
    pop {r4}
    bl    _delay
    bl    _clear_hex_display
    b     _main_loop
    
  _display_clear:
    push {r4}
    ldr   r1, [r7, #24]    
    ldr   r4, =HEX3_HEX0_BASE
    str   r1, [r4]
    ldr   r1, [r7, #28]    
    ldr   r4, =HEX5_HEX4_BASE
    str   r1, [r4]
    ldr   r0, =2000     @ Delay: 2000 ms (2 s)
    pop {r4}
    bl    _delay
    bl    _clear_hex_display
    b     _main_loop

_check_uid_exists:
    push {r4, r5, r6, r7, r8, r9}
    mov   r2, #0           @ Initialize index to 0
check_loop:
    ldr   r4, =UID_LENGTH_BASE
    ldr   r4, [r4]
    ldr   r1, [r4]        @ Load UID array length
    cmp   r2, r1
    beq   not_found        @ If index equals length, not found
    ldr   r4, =UID_BASE
    ldr   r4, [r4]
    ldr   r1, [r4, r2, LSL #2]     @ Get UID at current index
    cmp   r0, r1           @ Compare with input UID
    beq   found            @ If match, branch to found
    add   r2, r2, #1       @ Increment index
    b     check_loop
found:
    mov   r1, r2           @ Return index (or any flag you prefer)
    pop {r4, r5, r6, r7, r8, r9}
    bx    lr
not_found:
    mov   r1, #0xFFFFFFFF  @ Return -1 to indicate not found
    pop {r4, r5, r6, r7, r8, r9}
    bx    lr


  _add_to_memory:
    push {r4}
    ldr   r4, =UID_LENGTH_BASE
    ldr   r4, [r4]
    ldr   r1, [r4]
    cmp   r1, #10
    
    bleq    _display_error
    ldreq   r0, =2000     @ Delay: 2000 ms (2 s)
    bleq    _delay
    bleq    _clear_hex_display

    beq   _register_deregister_device
    ldr   r4, =UID_BASE
    ldr   r4, [r4]
    str   r0, [r4, r1, LSL #2]
    add   r1, r1, #1
    ldr   r4, =UID_LENGTH_BASE
    ldr   r4, [r4]
    str   r1, [r4]

    bl    _display_added
    ldr   r0, =2000     @ Delay: 2000 ms (2 s)
    bl    _delay
    bl    _clear_hex_display

    pop {r4}
    b     _main_loop

  _remove_from_memory:
    push {r4}
    ldr   r4, =UID_LENGTH_BASE
    ldr   r4, [r4]
    ldr   r1, [r4]
    ldr   r4, =UID_BASE
    ldr   r4, [r4]
    ldr   r3, [r4, r2, LSL #2]
    
    cmp   r0, r3
    mov   r0, r2
    bleq    _shift_uid_array
    add   r2, r2, #1
    cmp   r2, r1
    beq _main_loop //if it cant find it then return to main
    
    cmp   r0, r3
    bne   _remove_from_memory
    pop {r4}
    b     _main_loop

_unlock_lock:
    @ Show "OPEN" message (from hex_data_array index 0)
    ldr   r2, [r7]       
    ldr   r4, =HEX3_HEX0_BASE
    str   r2, [r4]
    ldr   r0, =2000      @ Display open message for 2 s
    bl    _delay

    @ Initialize a countdown timer of 5 seconds in ms (5000 ms)
    ldr   r8, =5000     @ r8 will hold remaining ms for countdown

countdown_loop:
    @ Divide remaining ms (in r8) by 1000 to get full seconds.
    mov   r0, r8         @ r0 = remaining ms
    ldr   r1, =1000      @ r1 = divisor (ms per second)
    bl    unsigned_div   @ After call, r0 = full seconds, r1 = remainder (ignored)
    mov   r9, r0         @ r9 now holds the number of seconds to display


    @ Get the base address of the 7-segment codes
    ldr   r10, =hex_number_array_addr
    ldr   r10, [r10]     @ r10 now holds the address of hex_number_array

    cmp   r9, #10        @ Check if seconds equals 10
    beq   load_10
    @ If not 10, load the single digit code:
    mov   r0, r9         @ Use seconds value as index
    ldrb  r0, [r10, r0]  @ Load 7-seg code for the digit
    b     display_digit

load_10:
    @ If seconds is 10, display "10" by combining two 7-seg codes
    ldrb  r0, [r10, #1]  @ Load 7-seg code for digit 1 (tens place)
    lsl   r0, r0, #8     @ Shift left 8 bits to position the tens digit
    ldrb  r1, [r10, #0]  @ Load 7-seg code for digit 0 (ones place)
    add   r0, r0, r1     @ Combine the two codes

display_digit:
    ldr   r4, =HEX3_HEX0_BASE
    str   r0, [r4]       @ Display the resulting code on HEX3_HEX0
    @ Wait for 1 second
    mov   r0, #1000     @ Delay 1000 ms (1 s)
    bl    _delay

    @ Subtract 1000 ms from the remaining countdown
    sub   r8, r8, #1000
    cmp   r8, #0
    bgt   countdown_loop  @ If there is still time left, continue the loop

    @ After countdown is finished, display the closing message.
    ldr   r2, [r7, #4]   @ Get "LOSE" (first part) from hex_data_array (index 1)
    ldr   r4, =HEX3_HEX0_BASE
    str   r2, [r4]
    ldr   r2, [r7, #8]   @ Get "LOSE" (second part) from hex_data_array (index 2)
    ldr   r4, =HEX5_HEX4_BASE
    str   r2, [r4]
    ldr   r0, =2000     @ Display close message for 2 s
    bl    _delay
    bl    _clear_hex_display

    b     _main_loop

@-------------------------------------------------------------
@ _delay: delays execution for the number of milliseconds passed
@ in r0.
@ Assumes:
@   - TIMER_BASE (r6) points to the timer registers.
@   - time_storage is used to store the ms count.
@   - 200000 cycles equals 1ms (for a 200MHz clock)
@-------------------------------------------------------------
_delay:
    push {r4, r5, r6, lr}     @ Save registers we will modify

    mov   r4, r0             @ r4 holds the desired delay (in ms)

    @ Reset the millisecond counter in memory
    ldr   r5, =time_storage  @ r5 points to our time counter
    mov   r0, #0
    str   r0, [r5]           @ Clear the time counter

    @ Load the timer base address into r6 (if not already set)
    ldr   r6, =TIMER_BASE

    @ Start the timer for 1ms ticks:
    ldr   r0, =200000        @ Load 200000 cycles (1ms for a 200MHz clock)
    str   r0, [r6]           @ Store into the timer's load register
    mov   r0, #1
    str   r0, [r6, #12]      @ Clear the timer's interrupt flag
    mov   r0, #0b011
    str   r0, [r6, #8]       @ Start the timer with auto-reload enabled

_delay_loop:
    @ Poll the timer to see if the 1ms tick occurred
    ldr   r0, [r6, #12]      @ Check the timer's interrupt status register
    cmp   r0, #1
    bne   _no_update         @ If not set, skip the update

    @ If the timer ticked:
    mov   r0, #1
    str   r0, [r6, #12]      @ Clear the interrupt flag
    ldr   r1, [r5]           @ Load current millisecond counter from memory
    add   r1, r1, #1         @ Increment counter by 1 (1ms elapsed)
    str   r1, [r5]           @ Store updated counter back to memory

_no_update:
    @ Check if we have reached the desired delay:
    ldr   r0, [r5]           @ Load current counter
    cmp   r0, r4             @ Compare with the delay value
    blt   _delay_loop        @ Loop again if we haven't waited long enough

    pop   {r4, r5, r6, lr}    @ Restore registers
    bx    lr                 @ Return to caller

  @-------------------------------------------------------------
  @ _clear_hex_display clears both HEX displays.
  @-------------------------------------------------------------
  _clear_hex_display:
    push {r4}
    mov   r1, #0
    ldr   r4, =HEX3_HEX0_BASE
    str   r1, [r4]
    ldr   r4, =HEX5_HEX4_BASE
    str   r1, [r4]
    pop {r4}
    bx    lr

  @ _shift_uid_array shifts the UID array after deletion.
  _shift_uid_array:
    push {r1, r2, r3, r4, lr}
    ldr   r4, =UID_LENGTH_BASE
    ldr   r4, [r4]
    ldr  r3, [r4]
    subs  r3, r3, #1
    str  r3, [r4]
    mov   r1, r0
  shift_loop:
    cmp   r1, r3
    bge   shift_done
    add   r2, r1, #1
    ldr   r4, =uid_array
    ldr   r0, [r4, r2, LSL #2]
    str   r0, [r4, r1, LSL #2]
    add   r1, r1, #1
    b     shift_loop
  shift_done:
    bl    _display_clear
    pop {r1, r2, r3, r4, lr}
    bx    lr

@ setting r0 to be the result of r0/r1 and r1 ends with storing the remainder
unsigned_div:
		push {r2}
        mov   r2, #0 @set r2 to 0
        cmp   r1, #0 @check if r1 is 0, if so then dont divide 
        beq   div_end

div_loop:
        cmp   r0, r1 @compare r0 and r1
        blt   div_end @if r0 is less than r1 don't divide 
        sub   r0, r0, r1  @subtract r1 from r0
        add   r2, r2, #1 @increase r2 by 1
        b     div_loop @repeat

div_end:
        mov   r0, r2 @store r2 (total times r1 fit into r0) in r0
		pop {r2}
        bx    lr @return
        
  STOP:
    b STOP
