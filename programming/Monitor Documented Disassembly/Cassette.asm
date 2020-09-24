        org     0x04e1
; BLOCK 'casjumptable' (start 0x04e1 end 0x04f1)
cas_JumpTable:
        defw    cas_Init            ; 05 06
        defw    cas_Rewind          ; b4 0b
        defw    cas_Skip_Forward    ; 0f 0c
        defw    cas_Skip_Reverse    ; 61 0c
        defw    cas_WriteEOTGap     ; e4 0b
        defw    cas_Write           ; 7a 05
        defw    cas_Read            ; 52 05
        defw    cas_Status          ; 15 05
; cassette entry point
; inputs:
; A contains cassette command (0-7)
; -caller must have prepared other info
;  like file size and address of data in the Descriptor 
;  locations in RAM (0x6030  - 0x604f)
;
; returns:
; Z if succes, NZ if failure
cassette:
        call saveregs2 
        cp 008h                     ; commands range from 0 to 7 
        jr c,knowncascommand        ; less than 8 is good (carry set) 
        ld a,'K'                    ; error 'K' means unknown command 
        jr cas_command_error         

knowncascommand:
        ld hl,transfer              ; make the header address equal to the source/dest address for the cassette command
        ld (des1),hl                ; this address must be stored in 0x6030 by the caller 
        ld hl,0x20                  ; header is 20 bytes long 
        ld (des_length),hl          ; store in header length 
        ld hl,cas_JumpTable         ; start of jumptable 
        sla a                       ; command * 2 (addresses are 2 bytes) 
        ld d,0                      ; build offset in DE  
        ld e,a
        add hl,de                   ; HL now contains address of destination address 
        cp 7*2                      ; is offset (in a) equal to 2*7(cas_status offset#)
        jr nz,do_cas_jump           ; if not, perform the jump otherwise fall through to cas_status 
                                    ; fall through to
; cas_Status:
; Z flag set: NO TAPE
; C carry set: Write protected (is not bad per se)
;
; status byte from cassette:
; bit 4 = CIP (1=no tape,   0=tape inserted)
; bit 3 = WEN (1=protected, 0=can write)
cas_Status:
        in a,(CPRIN)                ; read status from cassette device   
        rra                         ; 4 rotates move WEN in carry  (write protect flag)
        rra
        rra
        rra
        cpl                         ; Invert A
        bit 0,a                     ; Test CIP (now in pos 0) if bit == 0 Z=>1  
        call restoreregs2 
        ret 

do_cas_jump:
        ld de,cas_command_return    ; get address of clean cassette jump return code 
        push de                     ; push on stack, so RET at end of cass routines will go here
        ld a,(record_number)        ; get # of blocks to process 
        ld (block_counter),a        ; copy to the counter 
        xor a                       ; clear cassette error 
        ld (cassette_error),a
        call disablekey             ; turn off key scanner and CTC interrupt 
        push hl                     ; save pointer to cassette jump address 
        ld b,'T'                    ; write a 'T' to the 
        ld e,3                      ; offset in status line 
        call show_mon_status
        pop hl                      ; restore pointer to cassette jump address
        ld e,(hl)                   ; Lo byte in E 
        inc hl 
        ld d,(hl)                   ; Hi byte in D 
        ex de,hl                    ; address in HL 
        di                          ; Interrupts off 
        jp (hl)                     ; and jump to cassette command routine 

; this address was pushed on the stack before a jp(hl) to the proper routine was made.
; all routines end in RET, ending up here
cas_command_return:
        ei                          ; interrupts on
        xor a                       ; zero A
        ld (motor_status),a         ; motor off
        call enablekey              ; key scan and CTC interrupt back on
        ld a,(cassette_error)       ; get cassette error  status 
cas_command_error:
        or a                        ; In case of error A is non-zero, NZ indicates error
        call restoreregs2           ; restore all registers
        ret 

; interrupts are off when we get here
cas_Read:
        call get_length_blocks      ; blocks to transfer and # of bytes 
read_loop:
        call get_block_parameters   ; get all parameters for transfer of next block
        ld a,(block_counter)        ; how many blocks to go?
        ld hl,motor_status          ; get location of motor state
        cp 001h                     ; last block (count==1)?
        jr nz,keep_reading          ; no, so keep motor on
        res BIT_MOTON,(hl)          ; reset bit 2 to switch off the motor after this block
        jr read_block               ; and get next block
keep_reading:
        set BIT_MOTON,(hl)          ; set bit 2 to keep motor on after this block
read_block:
        call cas_block_read         ; read the block from tape
        ld a,(cassette_error)       ; did the block load ok? 
        or a 
        ret nz                      ; no, so exit now!

        ld a,(block_counter)        ; block was loaded, so decrement # of blocks to go
        dec a           
        ld (block_counter),a
        jr nz,read_loop             ; load next if not done
        ret                         ; zero flag set == success

; interrupts are off when we get here
cas_Write:
        call get_length_blocks      ; blocks to transfer and # of bytes 
write_loop:
        call get_block_parameters   ; get all parameters for transfer of next block
        ld a,(block_counter)        ; how many blocks to go?
        ld hl,motor_status          ; prepare next block motor status
        cp 001h                     ; last block (count == 1)?
        jr nz,keep_writing          ; no, keep motor on and keep writing after this block
        res BIT_MOTON,(hl)          ; motor off after this block
        res BIT_MOTWR,(hl)          ; stop writing after this block
        jr write_block              ; 
keep_writing:
        set BIT_MOTON,(hl)          ; keep motor on after this block
        set BIT_MOTWR,(hl)          ; keep writing after this block
write_block:
        ld (record_number),a        ; block counter in record number (counts down!) 
        call cas_block_write        ; write block to tape
        ld a,(cassette_error)       ; all well?
        or a
        ret nz                      ; no, so stop.
        ld a,(block_counter)        ; decrement blocks to go 
        dec a
        ld (block_counter),a
        jr nz,write_loop            ; repeat until done
        ret                         ; zero flag set == success!

; get_length_blocks 
; this routine calculates the number of blocks required for the file.
; inputs: 
; - data addres in transfer
; - number of bytes in file_length
; 
; block count is stored in block_counter and returned in A
get_length_blocks:
        ld hl,(file_length)         ; length in bytes of the file (usually a multiple of 1024!)
        ld de,0400h                 ; we count in blocks of 1024 bytes
        dec hl                      ; subtract 1 from length
        xor a                       ; blockcounter to zero
lencalcloop:
        inc a                       ; minimum is 1 block
        sbc hl,de                   ; subtract 1024 
        jr nc,lencalcloop           ; No carry: still bytes left!
        ld (block_counter),a        ; save # of blocks
        ld hl,(transfer)            ; destination/source address
        ld (next_block),hl          ; is start of next block to transfer
        ld hl,(record_length)       ; get real length of the file in bytes 
        ld (length),hl              ; and save a copy for cassette transfer
        ret

; this subroutine prepares all parameters for reading/writing a block
; - next source/destination address in next_block
; - current source/destination address in current_block
; - valid # of bytes to transfer in valid_length
; - # of padding bytes in paddingbytes
; - remaining bytes to transfer in length
get_block_parameters:
        ld de,1024                  ; block is 1024 bytes
        ld hl,(next_block)          ; get source/destination address for block
        ld (current_block),hl       ; save as previous address
        add hl,de                   ; add 1024
        ld (next_block),hl          ; store as next block address
        xor a
        ld hl,(length)              ; get remaining lenth
        sbc hl,de                   ; subtract 1024
        jr c,partial_block          ; less than a full block
        ld (valid_length),de        ; bytes to write (1024) in valid length
        ld (length),hl              ; save remaining bytes
        jr exit_get_parameters      ; wrap up

partial_block:
        ld hl,(length)              ; get # of remaining bytes (<1024)
        ld (valid_length),HL        ; save this as # of bytes to transfer
        ld hl,0                     ; and set remaining bytes to
        ld (length),hl              ; 0 

; when we get here DE contains 1024, HL contains bytes to write
; the difference is the amount of padding bytes (if any) to write.
exit_get_parameters:
        ex de,hl                    ; put 1024 in HL  
        ld de,(valid_length)        ; get # of bytes to write 
        xor a                       ; zero a, clear Carry
        sbc hl,de                   ; subtract bytes to write from 1024
        ld (paddingbytes),hl        ; remainder = number of padding-bytes
        ret 

; similar to saveregs, implemented at address 0x01a5
saveregs2:
        ex (sp),hl                  ; put HL on, and get return address off, the stack 
        push de 
        push bc
        jp (hl)                     ; jump back to where we came from (address is in HL) 

; similar to restoreregs, implemented at address 0x01ab
restoreregs2:
        pop hl                      ; get calling address off the stack
        pop bc                      ; get BC
        pop de                      ; get DE
        ex (sp),hl                  ; gets HL and puts calling address back on the stack
        ret                         ; and go there 

; cas_Init
; reset cassette status, motor status.
; checks MDCR bits CIP and WEN
; returns:
; NZ for valid CIP/WEN combinations (01, 00, 11)
; Z  for invalid (10) combination
;    AND sending of cassette status bytes to the comm port is turned on
;
cas_Init:
        xor a
        ld (cassette_status),a      ; reset status bits for cassette
        ld (motor_status),a         ; and cassette motor (motor off and not writing)
        in a,(CPRIN)                ; read cassette status from device  
        and CIP|WEN                 ; interested in tape present and write protect notch
                                    ; valid combinations are:
                                    ; 01 = cas loaded, write protected
                                    ; 00 = cas loaded, write enabled
                                    ; 11 = no cassette, write protected
                                    ; INVALID combination:
                                    ; 10 = no cassette, write enabled
        cp CIP                      ; Compare with Invalid combination Mo cassette, write enabled
        ret nz                      ; Valid state, so all ok

; invalid cassette sensor combination!!
; An engineer may force this by deperessing the write-protect sensor during a call to cas_Init.
; this code will then turn on the bit that enables output of status bytes to the comm port at 2400 baud.
; In this way the cassette behavior can be followed in more detail.
        ld hl,cassette_status
        set CST_TOCOMM,(hl)         ; set bit 2 in status: enable send error/status bytes to RS232 port 
        ld e,KBIEN                  ; send_cas_status expects CPOUT value in E
        ld h,'1'                    ; status '1' to comm port
        jp send_cas_status          ; returns Z (error)

; cas_block_write
; writes the actual data block to the tape
; cassette status is checked.
; the 
cas_block_write:
        call cas_writable           ; cassette present and writable?
        ret nz                      ; nz indicates write protected cassette

        ld a,(cassette_status)
        bit CST_NOMARK,a            ; mark not found error?
        jr z,replace_block          ; no, try to replace an existing block

; no startmark means that the block is appended at the end and not overwriting
; an existing block, or that the block is the first one on tape 
        bit CST_WCDON,a
        jr z,skip_back_or_rewind    ; WCDON not set tells that the block is the first one on an empty tape
                                    ; in this case the tape will be rewound, and the block written from tha start.

; WCDON set means that another block was already written: this is not the first block, append this one.
        res CST_WCDON,a             ; turn WCDON bit off, will be turned on again later in the procedure
        ld (cassette_status),a
        jr append_block

replace_block:
        call find_and_replace_block ; find marker, and if found write new block 
        ld a,(cassette_error)
        cp 'M'                      ; 'M' = Mark not found, 
        jr z,blk_wrt_mark_not_found ; could not replace existing block
                                    ; this can happen when the new file is longer that the one
                                    ; it is replacing or the tape is empty 

        cp 0                        ; other error? 
        ret nz                      ; yes, so abort

        ld e,KBIEN|FWD|WCD          ; forward and write
        ld h,'`'                    ; report status '`'
        call status_out_wait_150ms  ; write 150 ms gap  
        ret nz                      ; EOT or ejected
         
        ld a,(motor_status)
        bit BIT_MOTON,a             ; keep motor on?
        ld h,'`'
        jr z,cas_motor_off          ; no, then motor off with status '`' 

        ld a,KBIEN|FWD              ; write head off
        out (CPOUT),a
        ret

; cas_motor_off
; turns motor off and sends char in h to the comm port (if enabled)
cas_motor_off:
        ld a,KBIEN                  ; cassette all off
        out (CPOUT),a
        ld e,a                      ; tape status in E
        call status_out_wait_120ms  ; wait and write h to comm port 
        ret

blk_wrt_mark_not_found:
                                    ; skip back over last written block
        ld hl,cassette_status
        set CST_NOMARK,(hl)         ; Bit 0 = No start Mark found 
                                    ; in this case the tape will skip back over the last written 
                                    ; block, skip forward again and append the block at the end, not
                                    ; searching for a mark.
skip_back_or_rewind:
        call rewind_to_prev_data_block
        ld a,(cassette_error)
        cp 'B'                      ; 'B' is begin of tape: writing first block on tape
        jr z,append_block           ; which is ok
        cp 0                        ; any other error? 
        ret nz                      ; yes, abort!
; successfully backed up a block
        ld hl,cassette_status       ; we backed up to the previous block. need to Skipover it
        set CST_MOTOROFF,(hl)       ; causes fwd_find_block to stop after 1 block
        call fwd_find_block         ; without destroying (block_counter) in the header
        ld a,(cassette_error)
        cp 0                        ; block found?
        ret nz                      ; no, abort
; and append after this block
append_block:
        call write_Gap_Mark_Gap_Block   ; Write the mark and new block in one go
        ld e,KBIEN|FWD|WCD          ; KBIEN | Write | Forward 
        ld h,'a'                    ; with status 'a' 
        call status_out_wait_150ms  ; write end of block gap

        ld a,(cassette_error)
        cp 0                        ; all ok? 
        ret nz                      ; no, abort

        ld a,(motor_status)
        bit BIT_MOTWR,a             ; writing ?
        jr nz,more_to_write
                                    ; last appended block is always at the end of a tape 
        call cas_WriteEOTGap        ; must now write end of tape marker (gap of 1.8 sec)
        ld a,(cassette_error)
        cp 'E'                      ; 'E' means EOT during write operation 
        ret nz                      ; other error, so abort 

; make error more explicit: End of tape was reached during EOF write
; data block was saved ok
        ld a,'F'                    ; 'F' means EOT during EOF write 
        ld (cassette_error),a
        ret

more_to_write:
        res BIT_MOTWR,a             ; reset write bit
        ld (motor_status),a
        ld a,(cassette_status)
        set CST_WCDON,a             ; indicate that WCD is active
        ld (cassette_status),a
        ld a,(motor_status)
        bit BIT_MOTON,a             ; keep motor on? (more to write) 
        ret nz                      ; yes, go do it

        ld a,KBIEN|WCD              ; motor off (????), write on, data bit 0
        out (CPOUT),a               ; what te function of this is 
        call wait_120ms             ; is unclear
        ld h,'a'                    ; turn motor off with status 'a' 
        jr cas_motor_off

find_and_replace_block:
        call off_M                  ; Video chip may not interrupt CPU
        call search_marker          ; first find the marker
        ld a,(cassette_error)       ; succes?
        cp 0
        jr z,write_Gap_Block        ; yes, continue and write gap+datablock

replace_exit:
        call on_M                   ; Allow video chip to interrupt CPU
        ret                         ; NZ indicates failure

write_Gap_Block:
        ld a,KBIEN|FWD|WCD          ; start writing data block
        out (CPOUT),a
        call write_gap_81ms         ; first the marker-block gap
        jr nz,replace_exit          ; abort on EOT or ejected

        call save_block             ; save the data block
        call on_M                   ; Allow video chip to interrupt CPU
        ld a,(cassette_error)       ; any errors?
        cp 0
        ret z                       ; no :-) 

                                    ; flag error
        ld h,'`'                    ; motor off with status '`' 
        jp cas_motor_off


write_Gap_Mark_Gap_Block:
        ld a,KBIEN|FWD|WCD          ; start writing gap (databit == 0)
        out (CPOUT),a
        ld a,(cassette_status)
        bit CST_BOT,a               ; starting at Begin of Tape?
        jr z,inter_block_gap        ; no, so only write inter-block gap

        call resetBOTandWait1sec    ; write BOT gap (1 sec)
        jr write_data

inter_block_gap:
        call wait_492ms             ; gap of ~0,5 sec between block and next marker

write_data:
        ret nz                      ; abort if ejected or EOT

        call off_M                  ; 2000M Video chip may not interrupt CPU during data-writing
                                    ; timing is extremely critical!
        ld (spsave),sp              ; save stackpointer

        push hl                     ; :-) clever trick, prep stack in such a way that
        push hl                     ; execution of code after writing the marker 
        call save_marker            ; will automatically resume with 
        call set_WDA_0              ; <- this code
        jr nz,write_data_failed
        call write_gap_81ms         ; write marker-block gap
        jr nz,write_data_failed
        call save_block             ; write the data block
        jr nz,write_data_failed
write_exit:
        call on_M                   ; Allow video chip to interrupt CPU
        ret

write_data_failed:
        ld h,'a'                    ; motor off with status 'a'
        call cas_motor_off
        jr write_exit               

; save_marker
; when we get here, the stack already contains:
; word (dummy)
; word (dummy)
; word (address of 'call set WDA')
; the write_data_block code executes these last
save_marker:
                                    ; prepare the marker-section on the stack
        ld hl,0003h                 ; Marker is only 3 bytes, 2 checksum (always 0x00), 1 postamble (always 0xaa)
        push hl                     ; length
        push hl                     ; source address (in ROM!)
        ld hl,fetch_checksum_postamble  ; fetch data byte function
        push hl                     ;
        jr write_data_block         ; write marker


; save block
; a data block is stored on tape like this:
; sync          1       byte    (10101010, 0xAA)
; header        32      bytes     
; data          1024    bytes
; checksum      2       bytes
; post sync     1       byte    (10101010, 0xAA) 
; the saver code reads the size, source address and data fetch code addresses for each segment 
; from the stack. these segments are prepared first, then processed in one go
; to ensure proper timing of all data writes.
save_block:
        ld (spsave),sp              ; save current stackpointer, to allow clean return to caller
                                    ; because a lot of data is pushed on the stack now.
; always add cleanup code that sets data bit to 0 and gracefully exits
        push hl                     ; dummy
        push hl                     ; dummy
        ld hl,set_WDA_0             ; routine that cleans up and exits
        push hl

; always add segment that writes checksum and postamble bytes
        ld hl,0003h                 ; 3 bytes to write
        push hl                     ; count
        push hl                     ; source address (not used)
        ld hl,fetch_checksum_postamble  ; returns data to write in A
        push hl

; add (optional) segment that writes padding bytes
        ld hl,(paddingbytes)        ; padding bytes zero?
        ld a,l
        or h
        jr z,no_padding             ; no padding to write

        push hl                     ; count
        push hl                     ; source address (not used)
        ld hl,fetch_padding_byte    ; fetch routine
        push hl                     ; always returns 0x00

no_padding:
; add (optional) segment that writes data bytes
        ld hl,(valid_length)        ; valid_length zero?
        ld a,l
        or h
        jr z,no_data                ; no data to write
        push hl                     ; count
        ld hl,(current_block)       ; source address
        push hl
        ld hl,fetch_data_byte       ; fetch routine 
        push hl

no_data:
; add (optional) segment that writes header bytes
        ld hl,(des_length)          ; header length zero?
        ld a,l
        or h
        jr z,write_data_block       ; then no header to write
        push hl                     ; count
        ld hl,(des1)                ; source address (usually 0x6030)
        push hl
        ld hl,fetch_data_byte       ; fetch routine 
        push hl

; entry point that processes all prepared data segments from the stack
; in one continous flow. This is necessary, and needs to be cycle-exact
; because precise timing of the digital levels on tape is essential
; each state lasts exactly 209 clock cycles, or 0.0000836 seconds.
; one bit takes 418 cycles or 0.1672 ms. 1 byte takes 1.3376 ms
write_data_block: 
        ld iy,write_bit_loop        ; 14T Timing? has no function afaik
        ld c,0                      ;  7T Clock ticks toadd after write
        sub a                       ;  4T
        scf                         ;  4T no checksum (Carry set)
        ld b,8                      ;  7T 8 bits per byte
        ld a,0xaa                   ;  7T preamble byte
        exx                         ;  4T save bitcount(B), tick count (C)
        ld de,0                     ; 10T clear checksum
;--- 57T
                                    ;  72T to get here after fetch takes 72T
write_byte_loop:
        exx                         ;  4T get bitcount (B), tick count (C)
        ld d,a                      ;  4T save data byte in D
        ex af,af'                   ;  4T save control flags
        in a,(CPRIN)                ; 11T Tape status  
        and CIP|BET                 ;  7T only interested in these bits
        cp BET                      ;  7T BET = 1, CIP = 0 is good  
        jp nz,write_abort           ; 10T all others: abort 
        ld a,0                      ;  7T
        rr a                        ;  8T clear carry?
;--- 62T
write_bit_loop:                     ; when we get here in the bit loop, 134T-states elapsed since previous out()
                                    ; when we get here via the byte loop, 134T-states elapsedsince previous out()
        ld a,d                      ;  4T get data byte
        nop                         ;  4T Timing 
        and 001h                    ;  7T isolate data bit (least significant bit first)
        or KBIEN|FWD|WCD            ;  7T add correct cas control bits
        ex (sp),hl                  ; 19T Timing 
        ex (sp),hl                  ; 19T Timing
        nop                         ;  4T Timing
        out (CPOUT),a               ; 11T Bit to tape
                        ; 75T       ; 134+75 = 209 Cycles since previous state
        ex (sp),hl                  ; 19T Timing 
        ex (sp),hl                  ; 19T Timing
        nop                         ;  4T Timing
        jr timing_jump              ; 12T Timing jump adds 12 cycles
timing_jump:
        nop                         ;  4T Timing
        ex af,af'                   ;  4T get control flags
                                    ; 62T
;--- 137T
        jr c,skip_checksum_for_bit  ; 12T Carry set = No checksum 
                                    ;     Skip costs 5T states + 101T states = 106 to get to 'write_2nd_bit_state'

; checksum calculation for a 0 or 1 bit: 106T states 

                                    ;  7T jr not taken
        ex af,af'                   ;  4T save control flags
        ld a,d                      ;  4T get data byte
        exx                         ;  4T get checksum

; The following algorithm is used:
;
; XOR new bit with lo bit of checksum : de ^= bit
; only if resulting lo bit == 1 then XOR checksum with 0x4002 ; if ((de & 0x01) != 0) de ^= 0x4002
; Always rotate bits to the right (lo bit moves into hi bit) : 
; var hiBit = (de & 0x01)!=0 ? 0x8000:0;
; de = (hiBit|de>>1);

; step 1, de ^= new bit
        and 001h                    ;  7T get data bit
        xor e                       ;  4T 
        ld e,a                      ;  4T 

; step 2, if de&1 == 1, XOR with 0x4002
        and 001h                    ;  7T 
                        ;--- 41T
        jr z,to_rotate_in_29T       ; 12T when bit is zero: only rotate, add timing compensation
                                    ;     takes 22T cycles extra to get to rotate_checksum

; bit is 1 : E <- E xor 0x02
                                    ;  7T (branch not taken)
        ld a,002h                   ;  7T
        xor e                       ;  4T
        ld e,a                      ;  4T
        ld a,040h                   ;  7T prepare 0x40
                        ;--- 29T
rotate_checksum:
        xor d                       ;  4T xor with D (no EOR gets here with A = 0!) 
        rra                         ;  4T rotate right, lo bit in carry
        rr e                        ;  8T rotate carry in E, lo bit in carry
        jr c,set_hi_bit_d           ; 12T carry set: set hi bit in D
                                    ;     both paths take 19T states to get at set_D 
                                    ;  7T 

        jr set_D                    ; 12T not set
set_hi_bit_d:
        or 0x80                     ;  7T or value in

set_D:
        ld d,a                      ;  4T back in D 
        exx                         ;  4T save checksum
                                    ;  8T +
                        ;--- 43T

; to write the 1st phase of a bit takes:
;  57T byte loop init
;  62T bit loop bit fetch and set correct value on WDA 
; 137T pre-checksum
; 113T checksum
;-------------------
; 354T total, since out() to CPOUT, 175 Tstates elapsed (62 + 113)
write_2nd_bit_state:
        xor a                       ;  4T zero A
        rr d                        ;  8T bit in Carry
        ccf                         ;  4T invert
        adc a,KBIEN|FWD|WCD         ;  7T WDA contains inverted bit
        out (CPOUT),a               ; 11T Bit to tape
                        ; 34T       ; 175+34 = 209T states since previous value
        djnz delay_2nd_bit_state    ; 13T  excactly 134T to get to write_bit_loop

                                    ;  8T 
        ld b,008h                   ;  7T 8 bits to load
        jp (hl)                     ;  4T fetch next byte (takes 53T states)
                                    ; 19T
to_rotate_in_29T:                   ; 29T total to get here takes 12T extra for the jr z
        jr nz,rotate_checksum       ;  7T   Extra timing: execution gets here with a jr z, so this jr nz is never taken!
        jp rotate_checksum          ; 10T 

skip_checksum_for_bit:              ; 30+4*16-5+12 = 101T + 
        ex af,af'                   ;  4T save control flags (C)
        ld a,(ix+0)                 ; 19T dummy
        ld a,004h                   ;  7T 4 loops 
no_checksum_timing_loop:
        dec a                           ;  4T
        jr nz,no_checksum_timing_loop   ; 12/7T
        jr write_2nd_bit_state          ; 12T

delay_2nd_bit_state:                ; 121T total, + 13 for the djnz = 134
        ex af,af'                   ;  4T get control flags (P, C, Z)
        jp pe,no_segment_pop_delay  ; 10T (always!) if parity is set then no segment needs to be fetched 
                                    ;     the delay routine also takes exactly 107 T-states. 
                                    ;     otherwise it is the first byte of a new segment 
                                    ;     and we need to get the fetch routine, source address and count

                                    ; 107T exactly for the code to get segment off the stack
        ld a,080h                   ;  7T clear parity: ensure that data is fetched from stack only once
        dec a                       ;  4T A<-0x7f, P = 0, NZ
        ex af,af'                   ;  4T save control flags (P, C)
        pop hl                      ; 10T get data fetch address
        exx                         ;  4T Get Source and count registers
        ld a,02dh                   ;  7T Timing
        ld c,l                      ;  4T Timing
        ld b,l                      ;  4T Timing
        ld c,b                      ;  4T Timing
        ld c,a                      ;  4T Timing
        ld b,(hl)                   ;  7T Timing
        ld b,l                      ;  4T Timing
        ld d,d                      ;  4T Timing
        dec l                       ;  4T Timing
        pop hl                      ; 10T Get source address
        pop bc                      ; 10T Get count
        exx                         ;  4T save Source and dest
        jr write_bit_loop           ; 12T next bit!

; ****************************
; data fetch routines
;
; NB: to ensure exact timing all fetch routines use
; the same amount of cycles: 53 + 4 for the jp (hl) = 57, to get to write_byte_loop,
; exactly the same # of cycles that the write_data_block setup code takes
;
;*****************************

; fetch_data_byte
; returns:
; A: next data byte
; C: cleared, enable checksum
; P: 1 = don't fetch next data block from stack after this byte
;    0 = get next block from stack after this byte
fetch_data_byte:                    ; 53T Total, + 4 for the jp(hl) is 57T cycles
        ex af,af'                   ;  4T get control flags
        exx                         ;  4T get checcksum, BC and HL (count and source address)
        rr a                        ;  8T TIMING added for Timing (shorter than 2 NOPs)
        or a                        ;  4T Do checksum (Carry clear)
        ld a,(hl)                   ;  7T get next byte
        cpi                         ; 16T (HL) == A?, HL+=1 BC-=1, when last byte was read, when BC == 0 then P <- 0
                                    ;     this triggers next count, source and fetch routine retrieval when this section
                                    ;     is done
        jp write_byte_loop          ; 10T

; fetch_padding_byte
; returns:
; A: 0x00
; C: cleared, enable checksum
; P: 1 = don't fetch next data block from stack after this byte
;    0 = get next block from stack after this byte
fetch_padding_byte:                 ; 53T Total, + 4 for the jp(hl) is 57T cycles
        ex af,af'                   ;  4T get control flags
        exx                         ;  4T get BC and HL (count and source address)
        rr a                        ;  8T TIMING added for Timing (shorter than 2 NOPs)
        or a                        ;  4T Do checksum (Carry clear)
        ld a,0                      ;  7T always pad with 0x00
        cpi                         ; 16T (HL) == A?, HL+=1 BC-=1, when last byte was read, when BC == 0 then P <- 0
                                    ;     this triggers next count, source and fetch routine retrieval when this section
                                    ;     is done
        jp write_byte_loop          ; 10T

; fetch_checksum_postamble
; returns:
; A: E, D, 0xAA in this order
; C: set, disable checksum
; P: 1 = don't fetch next data block from stack after this byte
;    0 = get next block from stack after this byte
;
; NOTE: this fetch uses the most clockcycles, therefore the other fetch routines
; contain dummy opcodes to take exactly as many 
fetch_checksum_postamble:           ; 53T total, + 4 for the jp(hl) is 57T cycles
        ex af,af'                   ;  4T get control flags
        exx                         ;  4T get checcksum, BC and HL (count and source address)
        ld a,e                      ;  4T A <- E
        ld e,d                      ;  4T E <- D
        ld d,0xaa                   ;  7T D <- 0xAA
        scf                         ;  4T No checksum (Carry set)
        cpi                         ; 16T (HL) == A?, HL+=1 BC-=1, when last byte was read, when BC == 0 then P <- 0
                                    ;     this triggers next count, source and fetch routine retrieval when this section
                                    ;     is done
        jp write_byte_loop          ; 10T

; F' = NZ
; (we get here through DJNZ)
; and a JP PE
no_segment_pop_delay:               ; total: 107T 
        ex af,af'                   ;  4T save control flags 
        ret z                       ;  5T Timing, never taken
        or 0                        ;  7T Timing
        or 0                        ;  7T Timing
        or 0                        ;  7T Timing
        nop                         ;  4T Timing
        inc c                       ;  4T Timing
        di                          ;  4T Timing
        dec c                       ;  4T Timing
        ld iy,write_bit_loop        ; 14T Timing
        nop                         ;  4T Timing
        ld iy,write_bit_loop        ; 14T Timing
        ld a,(iy+0)                 ; 19T Timing
        jp write_bit_loop           ; 10T next bit

write_abort:
        ld d,a                      ; last CPRIN status in D, to allow determination 
                                    ; of failure reason by 
        ld hl,(spsave)              ; get stackpointer
        dec hl                      ; skip 1st count
        dec hl 
        dec hl                      ; skip 1st source address
        dec hl
        dec hl                      ; point to high byte of cleanup code
        ld a,(hl)                   ; save in A
        dec hl                      ; point to lo-byte of cleanup code
        ld l,(hl)                   ; in L
        ld h,a                      ; hi byte in H
        ld sp,(spsave)              ; set stack pointer to final return address
        ld b,0                      ; indicate write error
        jp (hl)                     ; jump into 'cleanup code' (set_WDA_0)

; D contains CPRIN status
; exit code jumps here, or execution gets here by the segment stackframe
; see save_block:
set_WDA_0:
        ld a,KBIEN|FWD|WCD          ; write forward
        out (CPOUT),a
        ld a,0                      ; reset error
        ld (cassette_error),a
        ld a,b                      ; save write_block status code
        ld b,0                      ; reset B, BC now contains ticks to add to clock
        ld hl,(clock)               ; and add
        add hl,bc
        ld (clock),hl
        cp 8                        ; 8 == success
        ret z

; write error occured, D contains bits with more info
        bit 4,d                     ; CIP
        ld a,'A'                    ; if set: No cassette
        jr nz,set_error
        sub a                       ; set NZ : error
        inc a
        ld a,'E'                    ; End of tape while writing 
set_error:
        ld (cassette_error),a 
        ret



cas_block_read:                     ; 0872
        call not_writing            ; check if writing is disabled
        ret nz                      ; abort to avoid writing while reading!! 

; HL contains pointer to cassette_status here
        bit CST_NOMARK,(hl)         ; start mark found on tape (bit is zero)? 
        jr z,tape_is_formatted      ; continue!
        ld a,'M'                    ; M indicates Mark not Found error
        ld (cassette_error),a       ; store in error 
        ret                         ; and exit! 

tape_is_formatted:
        call off_M                  ; 2000M Video chip may not interrupt CPU
        call search_marker          ; Find start of block marker
        ld hl,(cass_loops_rem_block)    ; get remaining # of waits allowed for a block read
        ld (cass_loops_rem_marker),hl   ; save a copy
        ld a,(cassette_error)
        cp 0                        ; no errors?
        jr z,has_data 
        call on_M                   ; Allow video chip to interrupt CPU
        ret                         ; abort 
has_data:
        call wait_70ms              ; skip gap between mark and data block
        jr nz,read_abort            ; tape end or ejected then abort
        call load_block             ; load data block 
        ld a,(cassette_error)       ; check result
        cp 0                        ; sets Z if all ok
read_abort:
        ld h,'b'
        jr z,read_success           ; no error 
        call cas_motor_off          ; motor off with status 'b'
        call on_M                   ; Allow 2000M video chip to interupt CPU
        ret

read_success:
        ld e,KBIEN|FWD              ; Current tape command in E (KBIEN and forward)
        call status_out_wait_150ms  ; skip 150 ms of tape, H to comm if enabled
        call on_M                   ; Allow 2000M video chip to interupt CPU
        ld a,(motor_status)         ; check motor bit 
        bit BIT_MOTON,a             ; keep on?
        ret nz                      ; yes, more blocks to do 

        ld h,'b'
        jp cas_motor_off            ; motor off with status 'b'


; reads start of block marker.
; mark is made of 4 bytes.
; BYTE 1, preamble: 0b10101010 (0xAA)
; BYTE 2, 0b00000000 (0x00)
; BYTE 3, 0b00000000 (0x00)
; BYTE 4, postamble: 0b10101010 (0xAA)

search_marker:
        ld a,KBIEN|FWD              ; start motor forward, and read
        out (CPOUT),a 
        call skip_marker_gap        ; skip part of the Gap between the end of the previous block and the mark, or between BOT and first Mark.
        ret nz                      ; NZ means an error occurred
search_marker_loop:
        call read_mark              ; read mark from tape
        ld de,(paddingbytes)        ; save data block paddingbytes value
        call end_read_cleanup
        ld hl,(paddingbytes)        ; cleanup modifies paddingbytes
        ld (paddingbytes),de        ; restore data block paddingbytes value
        ld a,(cassette_error)
        cp 0                        ; error during read or cleanup?
        jr nz,handle_mark_read_error ; yes, find out what 
        ld a,h                      ; did marker cleanup return 0 in paddingbytes? 
        or l
        jr nz,search_marker_loop    ; no: then it was not a valid marker 
        ret                         ; yes, so we're done

handle_mark_read_error:
        cp 'J'                      ; 'J' datablock too short 
        jr z,search_marker_loop     ; try again
        cp 'L'                      ; 'L' end of tape during read
        jr z,search_marker_loop     ; try again
        cp 'C'                      ; 'C' checksum error 
        jr z,search_marker_loop     ; try again
        cp 'N'                      ; 'N' record/file not found
        jr nz,other_mark_error

; report error as 'no start mark found'
        ld hl,cassette_status       ; set internal status to
        set CST_NOMARK,(hl)         ; 'no start mark' 
        ld a,'M'                    ; 'M', mark not found 
        ld (cassette_error),a       ; in public status

; retain original error
other_mark_error:
        ld h,'c'
        jp cas_motor_off            ; motor off with status 'c'

; read Mark
read_mark:
        ld (spsave),sp              ; save stackpointer
        ld hl,0                     ; create the following data struct on the stack
        push hl                     ; 00 00         ; data length
        push hl                     ; 00 00         ; data destination
        ld hl,read_until_timeout    ; reads bytes and ignores until data-timeout
        push hl                     ; 0A 25         ; data handling routine
        
        push hl                     ; 0A 25         ; dummy data
        push hl                     ; 0A 25         ; dummy data
        ld hl,skip_preamble
        push hl                     ; 0A 0B         ; ignores 1 byte and forces next set of routine and data 
        jp read_data_block          ; read data according to stack-description

; load block
; a data block is stored on tape like this:
; sync          1       byte    (10101010, 0xAA)
; header        32      bytes     
; data          1024    bytes
; checksum      2       bytes
; post sync     1       byte    (10101010, 0xAA) 
; the loader code reads the size, destination and handler code addresses for each segment 
; from the stack. these segments are prepared first:
load_block:
                                    ; we push the end of data handler routine on the stack
        ld hl,end_read_cleanup      ; the load routine ends wit RET, and execution ends up in cleanup.
        push hl                     ; push on stack.
        ld (spsave),sp              ; save current stackpointer, cleanup uses this to return to caller

; final block on the stack first, the post sync
; no dest, no length and the handler throws away bytes until read timeout
        ld hl,0 
        push hl                     ; 00 00  ; len        
        push hl                     ; 00 00  ; dest 
        ld hl,read_until_timeout    ; data handler routine
        push hl

; data block next
; length is the real length of the datablock (usually 1024, but less for the last block)
; destination is the current_block pointer
; and the handler routine stores data at the destination until valid_length bytes are read.
        ld hl,(valid_length)        ; only read data when the length >0!
        ld a,l 
        or h
        jr z,prep_header            ; valid lenght is zero, so skip and proceed with the header

        push hl                     ; data length on stack
        ld hl,(current_block)       ; destination address
        push hl                     ; destination on stack
        ld hl,read_payload
        push hl                     ; data store routine on stack 

; header block next
; length is usually is 32, destination is always des1 or 0x6068
; the handler routine stores data at the destination until valid_length bytes are read.
prep_header:
        ld hl,(des_length)          ; get header (description) length
        ld a,h                      ; only read header when length > 0
        or l
        jr z,prep_preamble          ; header  (description) length is zero
 
        push hl                     ; header length on stack (usually 32 or 0x20)
        ld hl,(des1)                ; 
        push hl                     ; header destination (0x6068) on stack
        ld hl,read_payload
        push hl                     ; data store routine on stack

; block starts with preamble
; length 0, destination 0 (not used) by the handler routine
; it immediately starts loading the next part of the data block.
prep_preamble:
        push hl                     ; 00 00 
        push hl                     ; 00 00  
        ld hl,skip_preamble
        push hl                     ; skip_preamble does not store the byte
                                    ; but moves on to next part of the data block

; read_data block processes sets of 3 words from the stack:
; SP     word 1 = length
; SP + 2 word 2 = destination
; SP + 4 word 3 = data handler routine  <- stackpointer

; the shadow registers ar used for:
; AF' Parity flag and carry flag.
;     P signals that a new set of handler, destination and length words must be popped from the stack 
;     C indicates that the byte being loaded must not be added to the checksum
;     A tracks checksum non-zero state. Whenever checksum == 0 a <- 0, otherwise 1 bits are shifted in 
;       for each time checksum != 0
; HL' Destination address for the data bytes
; BC' data byte counter
; DE' D = data byte collector, E = data bit counter
;
; the normal registers are used for:
; H contains the IO bit pattern that indicates a new bit is available
; L contains the data byte from port 20 (and new data bit if pattern in h is found)
; AF anything
; BC
; DE checksum
; IY contains the correct bit-loop address
; IX contains the address of the data handling routine 
read_data_block:
        ld a,KBIEN                  ; KBIEN (cas off)
        out (CPOUT),a
        ld a,KBIEN|FWD              ; KBIEN | Forward 
        out (CPOUT),a
        call get_startclock         ; waits about 0,24 ms to read current clock bit state.
                                    ; With tapeOK (0x20) bit set. 0x60 means clock high, 0x20 clock low  
        xor RDC                     ; invert clock bit, we want to act when this state is reached
        ld h,a                      ; save in H to compare with status from cassette
        ld iy,wait_first_bit        ; wait for 1st bit loop address in IY
        ld c,0                      ; clear C == number of clock ticks to add to clock after read block finishes????
        ld de,0x4ce5                ; load with 19685, for a maximum wait for first bit of 1 second 
                                    ; When no clock-flip is detected, and no errors occur, one loop takes 132 T-states (my count, see below)
                                    ; 19685 * 132 Tstates = 2.598.420 Tstates or a little over 1 second.
                                    ; However, my calculation may be wrong, because when the loop would take 127 tstates
                                    ; 19685 * 127 = 2.499.995 Tstates or almost exactly 1 second.  
                                    ; todo:  ? count T-states one more time
wait_first_bit:
        in a,(CPRIN)                ; 11T read cas status   
        and RDC|BET|CIP             ;  7T keep significant bits 
        cp h                        ;  4T compare with desired bit pattern 
        jr z,first_bit_received     ;  7T (12 if z) equal, so clock bit was flipped: data bit can be read!
        and BET|CIP                 ;  7T ignore clock bit 
        cp BET                      ;  7T tape still ok and present BET==1|CIP==0    
        jr nz,_errexit              ;  7T (12 if nz) no, so exit
        dec de                      ;  6T decrement wait counter 
        ld a,d                      ;  9T hi byte 
        or e                        ;  4T or lobyte
        jr z,_errnotfound           ;  7T (12 if z) if zero we are done, but should not be! 

; a few more t-states delay
        nop                         ;  4T waste some cycles 
        inc c                       ;  4T and some more
        di                          ;  4T and more
        dec c                       ;  4T and more

        ld a,KBIEN|FWD              ;  7T continue reading 
        out (CPOUT),a               ; 11T

        ld iy,wait_first_bit        ; 14T loop address
        jp (iy)                     ;  8T and jmp to wait_first_bit 

_errexit:
        jp rd_blk_finished

_errnotfound:
        ld a,'N'                    ; 'N' (4e) means File/Record/Mark Not Found 
        ld (cassette_error),a       ; store 
        ld sp,(spsave)              ; restore stackpointer
        ld l,0                      ; L = 0 means all sub-sections were processed
        ld b,008h                   ; normally indicates succes but cassette_error ('N') overrules this
        ret

; A  =  data bit and clock
; H  =  previous clock state
; DE =  wait count. Block is always read in 2 sections. The Marker and the DataBlock
;       the total wait time for the 1st bits of these sections may not exceed 1 second.
;       therefore the remaining counter value is saved for the next section's read operation
; the first bit of the preamble is per definition a zero.
; from now on we can process all bits in one big stream.
first_bit_received:
        ld (cass_loops_rem_block),de    ; save the remaining # 0f waits (this is how long the wait for the next first bit may take) 
        ld iy,get_next_bit          ; 2nd loop address for the section's remaining bits

; prepare the shadow registers for receiving data
        exx                         ;  4T get Count (BC), destination(HL) and byte collector (DE) 
        ld e,007h                   ;  7T store 7 in E', 7 more bits to go (we ignore the bits of the preamble)
        exx                         ;  4T adnd save Count, destination, byte collector
        ex af,af'                   ;  4T get P and C flags for flow control
        sub a                       ;  4T clear A',  set Z Positive, Parity = 0, which is a signalto get len, dest and handler from stack
        scf                         ;  4T set Carry indicates bits must not be added to the checksum 
        ld de,0                     ; 10T reset Checksum

get_next_byte:
        ex af,af'                   ; save P anc C control flags
get_next_bit:
        ld a,h                      ; old clockbit and EOT + CIP in A
        xor 040h                    ; set cklock bit to next expected state 
        ld h,a                      ; h contains desired pattern 
        ld b,0                      ; 256 loops max, about 5 ms (51*256 = 13056 = 0,0052224 sec)
wait_next_bit:
        in a,(CPRIN)                ; 11T   read cas status
        ld l,a                      ;  9T   save databit in L
        and 070h                    ;  7T   tape ok and clock bit
        cp h                        ;  4T   is the clock bit in the desired state?  
        jr z,add_bit                ; 12/7T yes, so add the bit to the byte 
        djnz wait_next_bit          ; 13/8T no so keep waiting
                                    ; one loop takes 11+9+7+4+7+13 = 51 Tstates
        jr rd_blk_finished          ; no flip within the expected time, something is wrong so we're done

add_bit:
        ex af,af'                   ; get Carry (fillerdata) and Parity(first byte of block) Flags 
        jr c,_no_checksum           ; if carry set, we're processing bytes that do not affect checksum

; process data bit with checksum.
; first update checksum in DE with the new bit. The following algorithm is used:
;
; XOR new bit with lo bit of checksum : de ^= bit
; only if resulting lo bit == 1 then XOR checksum with 0x4002 ; if ((de & 0x01) != 0) de ^= 0x4002
; Always rotate bits to the right (lo bit moves into hi bit) : 
; var hiBit = (de & 0x01)!=0 ? 0x8000:0;
; de = (hiBit|de>>1);
        ex af,af'                   ; first save Control bits Carry(fillerdata) and Parity(Preamble) Flags 

        xor a                       ; get new data bit in A
        rlc l                       ; hi bit (data bit) into carry and lo bit of l, useful later.
        rla                         ; shift bit into bit 0 of A

        ; step 1, XOR new bit with lo bit of checksum
        xor e                       ; LB Checksum = LB checksum ^ databit 
        ld e,a

        ; step 2, check resulting bit. When set, XOR checksum with 0x4002
        and 001h
        jr z,rotate_DE_right        ; bit is zero: just rotate 

        ; XOR de with 0x4002
        ld a,0x02                   ; first XOR E with 0x02 
        xor e
        ld e,a

        ld a,0x40                   ; and D with 0x40

rotate_DE_right:
                                    ; rotate bits to the right (lo bit moves into hi bit)
                                    ; clever code to get either D or D xor 0x40
        xor d                       ; D <- D XOR 0x40 (if lo bit was 1) or D <- D (xor with 0x00 == no change) 
        rra                         ; hi byte >> 1, bit 0 in carry, bit 7 <- 0
        rr e                        ; lo byte >> 1, carry in bit 7, bit 0 in carry
        jr nc,rot_done              ; If no carry then done 
        or 010000000b               ; set bit 7 of D 
rot_done:
        ld d,a                      ; and store D (hi byte of checksum)
                                    ; DE now contains new checksum

; when we arrive here lo bit of l contains data bit for real data, 
; and unknown (and not important) for filler/sync data
_add_bit:
        rrc l                       ; 8T least significant bit in carry and in bit 7. 
                                    ;    For data bytes the data bit was earlier moved there!
                                    ;    for filler bits/bytes the contents doesn't matter
        exx                         ; 4T Get Destination address, counter and DE (data collector and bit-counter) 
        rr d                        ; 8T shift carry (data bit) into the byte
        dec e                       ;    1 more bit done  
        jr nz,_more_bits            ;    if != 0 we need more bits

        ld e,008h                   ; ready for next 8 bits  
        jp (ix)                     ; call byte processing routine 

; just collects bits, ignores the content
; since the bytes are thrown out anyway
_no_checksum:
        ex af,af'                   ; store Carry (fillerdata) and Parity(first byte of block) Flags 
        jr _add_bit                 ; and add bit

_more_bits:
        ex af,af'                   ; A'F' Parity bit == 0 ? get routine, dest and length from stack, otherwise next bit.
        jp pe,_next_bit             ; if parity is set then we skip to next bit 
                                    ; otherwise it is the first byte of a new block 
                                    ; and we need to get the handling routine and size + destination

        ld b,080h                   ; set parity bit so next loop does not end up here again
        dec b                       ; 0x7f in B, carry unchanged and flags: NZ, Pos, P=1
        ex af,af'                   ; save P & C flags 

        pop ix                      ; get processing routine from the stack
        pop hl                      ; get destination address in HL'
        pop bc                      ; get number of bytes to process in BC'
        exx                         ; save HL (dest) and BC (len) 
        jr get_next_bit

_next_bit:
        ex af,af'                   ; AF 
        exx                         ; REG 

        nop                         ; 4T dummy
        inc c                       ; 4T dummy
        di                          ; 4T dummy
        dec c                       ; 4T dummy

        ld a,KBIEN|FWD              ; keep reading forward
        out (CPOUT),a
        ld iy,get_next_bit
        jp (iy)                     ; and loop 

; data handling routine 'skip preamble'
; it ignores the data and immediately activates the next data handler routine on the stack frame
; HL, BC, DE contain dest, count and data
skip_preamble:
        ex af,af'                   ; get load control flags (P and C) 
        exx                         ; save HL (dest) and BC (len) and data collector & count
        sub a                       ; clear A',  set Z Positive, Parity = 0
                                    ; this signals to get length, destination and handler address from stack!
        jr get_next_byte

; data handling routine 'read payload'
; stores the data byte at destination.
; HL, BC, DE contain dest, count and data
; Shadow DE contains the checksum 
; checksum is not calculated for the first byte of a block.
; the store routine turns on checksum by clearing the carry.
; 'control' flags affected:
; P = 0 when last data byte was stored, otherwise 1
; C = 0 after 1st byte, indicates that checksum must be calculated
; Z = Checksum is zero
read_payload:
        exx                         ; save databyte, destination and count

        ld a,d                      ; is checksum 0?
        or e
        jr nz,checksum_on           ; no. 

        ex af,af'                   ; get load control flags (P, C)
        xor a                       ; A <- 0, Z, P = 1, C = 0
        jp store_byte 

checksum_on:
                                    ; clears carry -> add bits to checksum
        ex af,af'                   ; get load control flags (P, C)
        scf                         ; Set Carry
        rla                         ; shift in A (NZ) (A indicates that Checksum is non-zero ????)
        or a                        ; NZ, Set P = 1, C = 0

store_byte:
        exx                         ; get data byte, dest and count
        ld (hl),d                   ; store data byte
        cpi                         ; inc HL, dec BC  P <- 0 when BC == 0
                                    ; this triggers next len, dest and handler retrieval 
                                    ; after finishing the data block
        exx                         ; save dest, count
        jr get_next_byte

; data handling routine 'read until timeout'
; it counts the databyte and keeps asking for more until 
; the read next bit wait loop times out: trailing gap reached.
; while reading (but not storing) the checksum is updated too.
;
; IMPORTANT!!
; when a byte is counted, and checksum == 0 then A is set to 0.
; This should happen exactly BEFORE the postamble byte.
; when the postamble byte is added (0xAA or 10101010), the checksum 
; will be non-zero 1 again,and the Lo bit of A is set.
; so a pattern of ------01 means that the checksum was ok.
; 
; it can also happen that the postamble byte was not read completely (EOT!)
; in that case A will contain ------00
; so a pattern of 00 or 01 in A means checksum was OK.
; a pattern of 1x means Checksum error!
;
; HL, BC, DE contain dest, count and data
; 
read_until_timeout:
        inc bc                      ; increment # of bytes read 

        exx                         ; Save the collected bits (D) and bitcounter (E)

        ld a,d                      ; is checksum 0?
        or e
        jr nz,to_checksum_on        ; no. 

        ex af,af'                   ; get load control flags (P, C)
        xor a                       ; A <- 0, Z, P = 1, C = 0
        jr read_on

to_checksum_on:
        ex af,af'                   ; get Carry (checksum) and Parity(new subsection) Flags     . 
        scf                         ; set carry flag
        rla                         ; indicate checksum was non-zero
        or a                        ; NZ, Set P = 1, C = 0

read_on:
        ld b,080h
        dec b                       ; 0x7f in B, carry unchanged and flags set (not zero, positive, P = set)
                                    ; this ensures that no new len. dest and handler will be read from stack
                                    ; for the next byte
        jp get_next_byte

; for the marker this RET's to the calling address.
; for a data block RET ends up in 'end_read_cleanup'  
rd_blk_finished:
        ld b,01eh                   ; 29 x 13 + 15 = delay 392 T-states (= 0,0001568 sec)
_dl:
        djnz _dl
        in a,(CPRIN)                ; read cas status   
        and CIP|BET                 ; get tapeok and ejected bits 
        ld hl,(spsave)              ; get saved stackpointer
        sbc hl,sp                   ; subtract current stackpointer 
                                    ; when result in L == 0, all file sub-sections (len, dest, routine)
                                    ; on the stack were processed
        ld sp,(spsave)              ; restore stackpointer for correct return address
        cp BET                      ; BET = 1, CIP = 0 is good
        ret nz                      ; no, error! 

        ld a,0                      ; indicate success 
        ld (cassette_error),a
        ld b,008h                   ; 8 indicates read was ok

        ld a,d                      ; checksum zero now? 
        or e                        ; then all is ok   
        ret z

; was the checksum OK after reading data?
        ex af,af'                   ; Get control Flags and A

                                    ; A contains info about the last checksum values.
                                    ; 00 = ok (next to last byte read: checksum 0, incomplete postamble) OK!
                                    ; 01 = ok (next to last byte read: checksum 0, postamble caused nonzero checksum) OK!
                                    ; 11 = not ok: next to last byte did not yield zero checksum, postamble neither!

        bit 0,a                     ; bit 0 clear? (------00) (------10 is impossible)  
        ret z                       ; ok
        bit 1,a                     ; bit 1 clear? (------01) 
        ret z                       ; ok

                                    ; ------11 indicates checksum error
        ex af,af'                   ; old a and flags back
        ld a,020h                   ; set bit 5 
        ld b,0                      ; indicate read error
        ret

; read_block returns status as follows:
; A: bits indicating reason for failure
; B: succes == 0x08
; L: 0 means all segments processed. != 0 means data block was too short
; C: ticks to add to clock
end_read_cleanup:
        ld h,a                      ; save copy of A in H (can)
        ld a,b                      ; was load result (in B)
        cp 008h                     ; successful? 
        jr z,read_ok

        bit 4,h                       
        ld a,'A'                    ; 'A' means no cassette
        jr nz,error_and_exit
        bit 5,h
        ld a,'E'                    ; 'E' : end of tape while writing
        jr z,error_and_exit
        ld a,'L'                    ; 'L' : end of tape during read 
        inc l                       ; inc/dec checks L for zero
        dec l
        jr nz,error_and_exit        ; l != 0 (and it should be)

                                    ; all segments were processed. Last segment is always the
                                    ; 'count bytes until timeout' handler, and BC contains
                                    ; the # of bytes that were read, but not stored.
                                    ; value is padding bytes + 3 (2 checksum bytes, 1 postamble byte)
        exx                         ; get last loader params (count BC, dest HL)
        dec bc                      ; subtract 3 for checksum and postamble
        dec bc
        dec bc
        ld (paddingbytes),bc        ; store # paddingbytes  
        exx

        ld a,'C'                    ; 'C' means read-error (checksum error)
error_and_exit:
        ld (cassette_error),a
adjust_clock:
        ld a,l                      ; save L, this indicates on what segment the load failed
        ld (sections_left),a        ; can be used for debugging
        ld b,0                      ; clear hi byte, BC <- ticks to add to clock
        ld hl,(clock)               ; add
        add hl,bc
        ld (clock),hl
        ret

read_ok:
        xor a                       ; double check for false positive (checksum ok, block too short)
        cp l                        ; L == 0 when all data was read 
        ld a,'J'                    ; 'J' Tape torn/stuck or data block too short
        jr nz,error_and_exit        ; error after all.

        ld a,(cassette_error)       ; Read routine could have returned a 'N': 'not found'
        cp 0
        jr nz,adjust_clock          ; it did return an error, exit without setting padding bytes

                                    ; all segments were processed. Last segment is always the
                                    ; 'count bytes until timeout' handler, and BC contains
                                    ; the # of bytes that were read, but not stored.
                                    ; value is padding bytes + 3 (2 checksum bytes, 1 postamble byte)
        exx                         ; get last loader params (count BC, dest HL)
        dec bc                      ; subtract 3 for checksum and postamble
        dec bc
        dec bc
        ld (paddingbytes),bc        ; store # paddingbytes  
        exx

        jr adjust_clock



status_out_wait_150ms:
        push bc
        ld c,032h                   ; 50 * 3ms = 150 ms
        jp status_out_and_wait      ; output byte in H to comm port if enabled and delay

write_gap_81ms:
        push bc
        ld c,27                     ; 27 * 3ms = 81 ms
        jr wait_C_times_3ms 

wait_492ms:
        push bc
        ld c,164                    ;164* 3ms = 492 ms
        jr wait_C_times_3ms

; skip_marker_gap
; KBIEN|FWD was sent before calling this routine so the motor is running, and reading, forward
; if the current internal state says we're at the start of the tape,
; skip an extra 500ms before the regular 120 
; otherwise skip only 120ms
skip_marker_gap:
        ld a,(cassette_status)      ; get current cassette status
        bit CST_BOT,a               ; Are we at begin of tape BOT?  (set is yes)
        jr z,wait_120ms             ; no, so skip part of the inter-block gap 

        res CST_BOT,a               ; tape starts, turn off BOT flag
        ld (cassette_status),a      ; and save 
        call wait_500ms             ; Skip empty area at begin of tape
        ret nz                      ; error 
; after the 500 ms extra for begin of tape gap, we fall through to
; wait 120 ms to skip the regular Gap between blocks
wait_120ms:
        push bc         
        ld c,38                     ; 38 * .00315 = 0.1197 = 120ms 
        jr wait_C_times_3ms 

; wait 120 ms and write byte in H to comm port
status_out_wait_120ms:
        push bc 
        ld c,38                     ; 38 * .00315 = 0.1197 = 120ms 
        jr status_out_and_wait      

wait_70ms:
        push bc         
        ld c,22                     ; 22* 0.00315 sec = 0,0693 sec
        jr wait_C_times_3ms

status_out_wait_100ms:
        push bc
        ld c,32                     ; 32*0.00315 = 0.1008 sec
        jr status_out_and_wait

wait_261ms:
        push bc
        ld c,83                     ; 83 * .00315 = 261ms 
        jr wait_C_times_3ms

resetBOTandWait1sec:
        res CST_BOT,a               ; turn off begin of tape 
        ld (cassette_status),a      ; save in status
                                    ; fall through to 1 second wait
wait_1second:
        call wait_500ms             ; max wait is .80325 sec, so wait .5 twice :-) 
        ret nz                      ; if wait returns NZ the operation was finished.
                                    ; otherwise it falls through to another .5 seconds wait!
wait_500ms:
        push bc         
        ld c,159                    ; 159 * .00315 = 0.50085 sec 


; this routine waits at exactly C times 0,00315 seconds
; for a cassette operation(?) to finish. 
; when an error (tape end or tape ejected) occurs
; the error is recorded and the wait loop correctly finished.
wait_C_times_3ms:
        ld b,175                    ; 175 inner loops 
innerwait1:
        in a,(CPRIN)                ; 11 tstates read cassette status  
        and CIP|BET                 ;  7 tstates test bits 4 and 5 (cassette present and end of tape)  
        cp BET                      ;  7 tstates BET =1, CIP=0 means Tape OK and cassette present   
        jr nz,cas_removedorEOT      ;  7 tstates if equal, 13 if not: tape end or tape removed 
        djnz innerwait1             ; 13 tstates if B not zero
                                    ; 1 loop takes 45 clocks when B == 0
                                    ;   loop is repeated,  175 * 45 = 7875 cycles or 0,00315 seconds
        dec c
        jr nz,wait_C_times_3ms      ; once more .00315 seconds
        pop bc                      ; restore BC
        ret                         ; Zero flag is set, all ok! 

cas_removedorEOT:
        or a                        ; 0x00 means end of tape, tape present  . 
        ld a,041h                   ; 0x41 'A' means no tape 
        jr nz,cas_processerror      ; state is 0x10: no tape, store that in cassette_error
        ld a,045h                   ; 0x45 'E' means end of tape during write
cas_processerror:
        ld (cassette_error),a       ; store 
        ld h,a                      ; save errorcode in H
        ld a,KBIEN                  ; cassette all off
        out (CPOUT),a
        ld e,a                      ; save command in E, so we can pass it on to send_cas_status
        ld a,(cassette_status)      ; get cass status
        bit CST_TOCOMM,a            ; output status to comm port?
        jr z,wait_C_times_3ms2      ; no, continue delay

        call send_cas_status        ; write error byte (in H) to comm port
        ld a,c                      ; get remaining loops
        sbc a,002h                  ; subtract 2 loops to compensate for the time taken by sending H to comm port 
        ld c,a                      ; set outer loop counter 
        jr c,wait_done              ; less than 0 left  
        ld b,08fh                   ; first delay is slightly shorter, to compensate for sendig a byte to comm port
        jr innerwait2               ; and start the inner loop

wait_C_times_3ms2:
        ld b,0afh                   ; 175 inner loops
innerwait2:
        in a,(CPRIN)                ; read cas status  
        and CIP|BET                 ; filter bits 4 and 5 (cassette present and end of tape) 
                                    ; the following opcodes have no effect, but take the same 
                                    ; amount of cycles as the functional ones in the first wait loop
                                    ; so the timimg is exactly the same!
        xor 020h                    ; flip tape end bit (7 tstates) .   
        jr c,wait_C_times_3ms2      ; never taken (carry is cleared by XOR) (7 tstates)
        djnz innerwait2             ; loop
        dec c                       ; outer loop counter    . 
        jr nz,wait_C_times_3ms2     ; do all      . 
wait_done:
        inc c                       ; inc c clears zero flag
        pop bc                      ; restore bc
        ret                         ; done, return NZ = error (Z = OK)

; if CST_TOCOMM bit is on, send status (in H), followed by cassette_error to comm port, then wait
status_out_and_wait:
        ld a,(cassette_status)
        bit CST_TOCOMM,a            ; send errorcode to comm port? 
        jr z,wait_C_times_3ms       ; no, wait normally

        dec c                       ; remove 3 times 3ms from the requested wait time
        dec c                       ; to compensate for writing 2 bytes to comm port
        dec c
        call send_cas_status        ; send status byte in H to comm port
        ld a,(cassette_error)       ; get the error (if any) 
        ld h,a                      ; put in H 
        call send_cas_status        ; send cassette_error to comm port 
        ld b,070h                   ; slightly shorter first delay to compensate
                                    ; the time consumed by 2 writes to the comm port
        jr innerwait1               ; start waitloop


; send the byte in H to the RS232 comm port (usually the printer) at 2400 baud during a tape-operation
; because reading and writing bits to and from the tape is very time-critcal, this always happens during
; the GAP interactions, which write (or read) a static value.
;
; Format: startbit (1) 8 databits stopbit (0)
;
; My timing calculation (see T-state figures in the comments below) results in ~ 1040 T-states/bit
; that is almost exactly 2400 baud, hardcoded
; returns: Z set (success)
; status byte in H data in H
; current CPOUT value in E, to keep the Cassette command alive while writing bits to the comm port.
;
; status byte meaning:
; '1': cassette ststus logging to comm port initialized
; '`': block write REPLACE progress, a '`' is sent when:
;       - block replaced successfully
;       - all blocks replaced (end WRITE replace)
;       - failure during append, a second char may specify reason (cassette_error).
; 'a': block write APPEND progress, an 'a' is sent when:
;       - block appended successfully
;       - last block is appended (end WRITE append)
;       - failure during append, a second char may specify reason (cassette_error).
; 'b': block READ progress, a 'b' is sent when:
;       - block read successfully
;       - last block is read successfully
;       - failure during read, a second char may specify reason (cassette_error).
; 'c': Mark error, a second char may specifies reason (cassette_error)
; 'd': REV_Skip block: One Block skipped, one for each block 
; 'e': REV_Skip block: invoked
; 'f': FWD_Skip block: invoked
; 'g': cas_Rewind: invoked
; 'g': Write_EOT: invoked

send_cas_status:
                                    ; TTTT 
        ld b,009h                   ;    7 in total 10 bits to write, we do startbit and 8 data bits in a loop, and end with the stop bit 
        ld a,e                      ;    9 save tape status bits in A
        and 01111111b               ;    7 clear bit 7 (RS232 data bit)
        ld e,a                      ;    9 back in E
        rlc e                       ;    8 shift command 1 bit to the left 
                                    ;   40 states for setup
send_bit_loop:
        xor 080h                    ;    7 invert bit (0)(1) (first bit is startbit)
        out (CPOUT),a               ;   12 send command with data bit in bit 7 to the comm port
        call put_bit_delay          ; 1005 delay T-states (988 + 17 (call) = 1005)  0,000404
        srl h                       ;    8 next data bit in carry (0)(1)
        ccf                         ;    4 complement (invert) carry (1)(0) (will be corrected again by the XOR before the out)
        ld a,e                      ;    9 get left-shifted tape commandstatus bits
        adc a,0                     ;    7 add zero with carry, so bit 0 now contains databit
        rrca                        ;    8 rotate right, bit now in pos 7  (1)(0)
        djnz send_bit_loop          ;   13 write bits until done
                                    ; 1073 times 9 bits - 5 for the last djnz not branching 
                                    ; 9652 (1073*9-5)

        and 07fh                    ;    7 prepare stopbit (zero) 
        out (CPOUT),a               ;   12 write stopbit 
        rrc e                       ;    8 restore E 
                                    ;   27 cycles for sending the stop bit
                                    ; fall through in delay for stop bit

; bit delay takes 7+61*16+10 = 988 T-states
put_bit_delay:
        ld d,03dh                   ;    7 loop 61 times 
put_bit_delay_loop:
        dec d                       ;    4 T-states 
        jr nz,put_bit_delay_loop    ;   12 T-states NZ, 7 T-states Z
        ret                         ;   10 T-states
                                    ;  988 for stop bit
                                    ; TOTAL T-states: 40 + 9652 + 27 + 988 = 10.707 

; allow read head to settle on found 1st phase-state (600 clocks, or 0.00024 s)
; then read clock bit. When bit flips, a new bit is present at the WDA pin
get_startclock:
        ld b,46                     ; 7  (# of loops)
_get_clk_delay:
        djnz _get_clk_delay         ; 7 + (46 * 13) -5  = 600 T-states or 0,00024s
        in a,(CPRIN)                ; 11  read current cassette state  
        and 040h                    ;  7  save clock bit 
        set 5,a                     ;  8  set tapeok (not at end = 1) and tape present (=0) 
        ret                         ; 10 
                                    ; total: 636

cas_writable:
        in a,(CPRIN)                ; cassette status  
        and CIP|WEN                 ; mask required bits 
        ret z                       ; return when both clear (Cassette in place, not protected)     . 
        cp CIP|WEN                  ; both set? (no cassette, protected) means MDCR is empty
        ret z                       ; OK why is this ok? I guess to allow enabling of comm port logging.

                                    ; no tape and protected is impossible so 
        ld a,'G'                    ; status must be Cassette, protected. 'G' signals write protect is on.
        ld (cassette_error),a       ; store 
        ret                         ; and return NZ 

; turn off Video memory access on model M
; on model T this has no effect.
off_M:
        ld a,0ffh                   ; Disable video chip memory access
        out (070h),a                ; send byte
        ret


; turn on Video memory access on model M
; on model T this has no effect.
on_M:
        xor a                       ; Enable videochip memory access
        out (070h),a                ; send byte
        ret

; is write disabled?
; returns:
; - Z flag indicates all is safe
; - cassette_status address in HL
; hangs machine when write is enabled.
not_writing:
        ld hl,cassette_status
        bit CST_WCDON,(hl)          ; 1 = WCD is set, and write head is active
        ret z                       ; no, so all ok! 
        res CST_WCDON,(hl)          ; Disable Write 
        jp error_035                ; error code 0x35 and freeze

; no references to this address found
; perhaps old, dead code?
        call cas_WriteEOTGap
        ld a,(cassette_error)
        cp 0
        ret nz                      ; error, so abort
        ld hl,cassette_status
        set CST_NOMARK,(hl)         ; no start mark found 
        ret 

; cas_Rewind
; rewinds tape for a maximum duration of 103 seconds.
; a verified data tape rewinds within 90-something seconds
; if EOT os not reached within those 103 seconds,
; the tape is either broken or too long (not a supported tape) 
; inputs: none
; outputs: Cassette error contains 0, 'A' or 'I'
cas_Rewind:
        call not_writing            ; writing?
        ret nz                      ; don't rewind while writing: destroys data

        ld a,KBIEN|REV              ; start rewinding
        out (CPOUT),a               ; 
        ld b,103                    ; 103 wait max 103 seconds  (1m 43 seconds)
_rew_wait_loop:
        call wait_1second           ; this routine returns NZ when tape ejected or EOT is reached
        jr nz,_EOT_or_Ejected       ; we have EOT or no tape. EOT is what we want in this case.
        djnz _rew_wait_loop         ; no eot, wait one more second 
        ld a,'I'                    ; still no eot after 103 seconds: Error 'I' means time out during rewind 
        ld (cassette_error),a
        ld c,00fh                   ; not sure why this is... ????

; status from wait_1_second can be:
; 0x41 = 'A' no tape
; 0x45 = 'E' end of tape (during write)
_EOT_or_Ejected:
        ld a,(cassette_error)       ; get error 
        cp 'E'                      ; equal to end of tape?
        jr nz,_was_ejected          ; no, other problem 
        ld a,0                      ; no error, because EOT is what we wanted here
        ld (cassette_error),a       ;
        ld hl,cassette_status       ;
        set 4,(hl)                  ; indicate MDCR is at BOT (begin of tape)
        res 0,(hl)                  ; and start mark found (bit 0 == 0)
_was_ejected:
        ld h,'g'
        jp cas_motor_off            ; turn motor off with status 'g'

; this routine writes the EOT marker to tape
; 1.8 second gap 
cas_WriteEOTGap:
        call cas_writable           ; cassette present and writable?
        ret nz                      ; nz indicates write protected cassette

        ld a,KBIEN|FWD|WCD          ; KBIEN | Forward | Write | data bit 0
        out (CPOUT),a               ; to cassette
        ld b,15                     ; 15 * 120ms = 1,8 seconds
eot_gap_loop:
        call wait_120ms 
        jr nz,EOT_write_error           ; handle error that occurred  
        djnz eot_gap_loop           ; no error, so repeat

        ld a,0                      ; reset 
        ld (cassette_error),a       ; cassette error
        ld hl,cassette_status       ; update status
        res CST_WCDON,(hl)          ; not writing
        set CST_NOMARK,(hl)         ; Start mark not found
        res CST_BOT,(hl)            ; Cassette not at beginning of tape

EOT_write_error:
        ld a,KBIEN|WCD              ; KBIEN | Write , motor off 
        out (CPOUT),a               ; to Cassette 
        call wait_120ms
        ld h,'h'                    ; motor off with status 'h'
        jp cas_motor_off


cas_Skip_Forward:
        call not_writing            ; write head active?
        ret nz                      ; yes, abort (redundant because when write is active)

fwd_find_block:
        ld a,KBIEN|FWD              ; start reading
        out (CPOUT),a
        call skip_marker_gap        ; skip part of gap betwen block and marker or BOT and marker
        ret nz                      ; tape not ok
        call wait_70ms              ; skip another bit of the gap 
        ret nz                      ; tape not ok
        ld a,'N'
        ld (cassette_error),a       ; presume marker not found
        call get_RDA                ; get current state of data-line 
        ld d,0eah                   ; 0c27  16 ea   . . 
skip_fwd_read_loop:
        call skip_byte              ; read 8 data bit flips
        jr c,skip_fwd_exit          ; carry set = tape error
        jr nz,skip_fwd_timeout      ; NZ = byte read timed out
        ld d,023h                   ; next byte(s) should take a lot less time
        ld a,0                      ; reset cassette error
        ld (cassette_error),a
        ld a,h                      ; get last RDA bit state 
        jr skip_fwd_read_loop

skip_fwd_timeout:
        ld a,(cassette_error)       ; was a byte read syccessfully before timeout?
        cp 0
        jr nz,skip_fwd_no_mark      ; no, so nothing was skipped

        ld hl,cassette_status       ; bit 5 (turn motor off) set?
        bit CST_MOTOROFF,(hl)
        jr z,skip_more_fwd          ; continue skipping forward
        res CST_MOTOROFF,(hl)       ; yes, stop skipping and reset motor bit
        ret 

skip_more_fwd:
        ld hl,block_counter         ; all blocks done?
        dec (hl)
        jr nz,fwd_find_block        ; no, skip one more

skip_fwd_exit:
        ld h,'f'
        jp cas_motor_off            ; motor off with code 'f'

skip_fwd_no_mark:
        ld hl,cassette_status       ; No Mark Found  
        set CST_NOMARK,(hl)
        jr skip_fwd_exit

; this entrypoint is used by the write-block operation when 
; no start mark for a next block is found.
; te tape is then reversed to before the last block
; the block is skipped forward again and the 
; new block is appended with a fresh marker
; it uses the cas_Skip_Reverse code, but sets a special flag 
; to make it terminate properly for this purpose
rewind_to_prev_data_block:
        ld l,001h                   ; set rewind_to_prev_data_block flag
        jr rev_find_block           ; and 0c5f  18 0b   . . 

; cas_Skip_Reverse
; skips block_counter blocks back
; can be called from the write-block operation to back up 
; when no marker is found, so the block can be appended.
cas_Skip_Reverse:
        call not_writing            ; writing?
        ret nz                      ; yes, so don't accidentally erase tape!

        ld hl,cassette_status
        res CST_NOMARK,(hl)         ; clear start mark found bit
        ld l,0                      ; reset rewind_to_prev_data_block (enable multi-block skip) 

rev_find_block:
        ld a,KBIEN|REV              ; start reading in reverse
        out (CPOUT),a
        call get_RDA                ; get initial RDA state and desired CIP/BET pattern

; skip data block...
skip_rev_retry:
        ld e,225                    ; 225 bytes
        ld d,1                      ; wait 4,3 ms for a byte
rev_skip_byte_loop:
        call skip_byte              ; read 8 data bit flips
        jr c,skip_rev_exit          ; carry set = tape error
        jr nz,skip_rev_retry        ; NZ = byte read timed out, wait some more
        dec e                       ; one more byte skipped, all done?
        jr nz,rev_skip_byte_loop    ; no 
        bit 0,l                     ; rewind_to_prev_data_block flag set (for write-append)? 
        jr nz,skip_rev_gap          ; yes, no need to rev skip marker
; skip marker
rev_skip_byte_loop2:
        ld d,39                     ; wait max 39*4.3 = 167.7ms for a byte
        call skip_byte
        jr c,skip_rev_exit          ; carry set = tape error
        jr z,rev_skip_byte_loop2    ; byte skipped, keep skipping
        ld h,'d'                    ; status 'd' to comm, when enabled 
        ld e,KBIEN|REV              ; reverse
        call status_out_wait_100ms  ; skip 100ms of gap
        jr nz,skip_rev_error            ; EOT or ejected

        ld hl,block_counter         ; all blocks done?
        dec (hl)
        jr nz,rev_find_block        ; skip one more

skip_rev_exit_ok:
        ld a,0                      ; clear error
        ld (cassette_error),a

skip_rev_exit:
        ld h,'e'                    ; motor off with status 'e' 
        call cas_motor_off 

skip_rev_error:
        ld a,(cassette_error)       ; Was cassette error EOT?
        cp 'E'
        ret nz                      ; no, just report the error

        ld a,'B'                    ; We were rewinding and reached EOT 
        ld (cassette_error),a       ; report BOT
        ld hl,cassette_status
        set CST_BOT,(hl)            ; also set BOT flag and return
        ret

skip_rev_gap:
        call wait_261ms             ;0cb8   cd e4 0a    . . . 
        jr nz,skip_rev_error        ;0cbb   20 ea     . 
        jr skip_rev_exit_ok         ;0cbd   18 de   . . 

; skips a byte 
; A: starting expected bit pattern (RDA and CIP/BET bits)
; D: number of inner loops (4,3 ms) 
; returns: 
;  Z: byte succesfully read
; NZ: read timeout 
;  C: tape error error
; NC: succes

skip_byte:
        ld c,008h                   ; 8 data bit flips
next_bit_rev:
        xor RDA                     ; create expected data bit state 
                                    ; when skipping, only RDA flips are used
                                    ; clock (RDC) is ignored
        ld h,a
bit_wait_retry:
        ld b,0                      ;  7T loop max 256 times
bit_rev_wait:                       ; the inner wait loop takes max 256*(42)-5 = 10.747cycles = 0.0043 sec
        in a,(CPRIN)                ; 11T read data port
        and RDA|BET|CIP             ;  7T interested in RDA, BET and CIP
        cp h                        ;  4T RDA (clock) flipped?
        jr z,bit_rev_ready          ; 12T yes
                                    ;  7T no
        djnz bit_rev_wait           ; 13T keep waiting for clock flip 

                                    ;  8T
        and CIP|BET                 ;  7T check CIP and BET 
        cp BET                      ;  7T BET = 1, CIP = 0 is good  
        jr nz,byte_rev_error        ; 12T Ejected or EOT
                                    ;  7T
        dec d                       ;  4T retry?
        jr nz,bit_wait_retry        ; 12T yes
                                    ;  7T
        ld a,h                      ;  4T return original A
        xor RDA                     ;  7T restore last bit state (invert RDA)  (clock when reading in reverse)
        inc d                       ;  4T and 1 in D 
        ret                         ; 10T

bit_rev_ready:
        ld a,h                      ;  4T copy last input state in a 
        dec c                       ;  4T all bits done?
        jr nz,next_bit_rev          ; 12T no
                                    ;  7T
        ret                         ; 10T

byte_rev_error:
        or a                        ; test a
        ld a,'E'                    ; tape end
        jr z,byte_rev_EOT           ; 0 indicates tape present and EOT
        ld a,'A'                    ; tape ejected
byte_rev_EOT:
        ld (cassette_error),a
        scf                         ; carry indicates failure
        ret

; Read the RDA state and set bit 5 in A
; A <- RDA_state | BET
get_RDA:
        in a,(CPRIN)
        and 080h                    ; mask RDA
        set 5,a                     ; Set desired flags to not BET and CIP (tape ok)
        ret