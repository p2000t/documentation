; Disk routines

	org	0x0e90

getdos:
	di		            		; interrupts off
	ld (stacktemp_disk),sp	    ; save user stackpointer 
	ld a,001h	        		; presume no controller, no drive, no disk in drive A, 
								; drive switched off, drive door open OR PDOS was read
	ld (sysdisk_status),a
	ld hl,disk_constants 	    ; table of constants in ROM
	ld de,disk_transfer	    	; destination in RAM
	ld bc,disk_constants_size	; # of bytes to move
	ldir	            		; move constants to RAM

	call disk_init
	call disk_motor_on
next_track:
	call read_track			   	; track was initialized at 1 (rom constant) 
								; as were destination and other parameters
	ld hl,(disk_transfer)	    ; get destination address
	ld bc,01000h			    ; add 4K for next track (tracks contain 4k)
	add hl,bc			    	;
	ld (disk_transfer),hl		; put in dest address for next track
	ld hl,disk_track_num	    ; get current track number
	ld a,002h	        		; 2nd track processed?
	cp (hl)
	jr z,tracks_loaded	       	; yes, done!
	inc (hl)		    		; next track
	call disk_gotrack
	jr next_track

tracks_loaded:
	ld hl,0e000h	    		; 1st byte of track 1
	ld a,0f3h		     	    ; 0xf3h indicates it was a system disk
	cp (hl)	
	jr z,disk_interrupts_off
	xor a			       		; set sysdisk_status to 0
	ld (sysdisk_status),a

disk_interrupts_off:
	di							; interrupts off
	ld a,003h					; reset CTC channel 0 (interrupts off) Ctrlwrd|reset
	out (CTC_CH0),a
	xor a						; disk motor off
	out (DSKCTRL),a
	ld sp,(stacktemp_disk)		; user stack back 
	xor a						; bank 0 
	out (094h),a
	ret

; init FDC
; Head to 1st track
; set interrupt vectors
; wait 350ms and remove interrupt
disk_init:
	im 2						; CTC-interrupt mode 2
	di							; disable
	ld a,004h					; FDC reset (bit 2)
	out (DSKCTRL),a
	call delay_342ms
	call disk_reti				; reason: RETI is also decoded by the Z80 peripheral
								; chips (SIO, CTC, PIO, DMA) and tells them to reset
								; the interrupt daisy chain so the next interrupt can be accepted
	call read_dsk_status
	call disk_interrupts_on
	ld hl,disk_specify_cmd		; send timing etc specifications
	call disk_send_command		; to FDC
	call disk_recall			; disk recall commmand inits drive and moves head to track 1
	ret

; delays ~854799 cycles = ~0,3419 sec
delay_342ms:
	ld bc,0000h					; 10T 
d342mloop:
	djnz d342mloop				; 13T/8T   256*13-5 =  3323 cycles
	dec c						; 4T
	jr nz,d342mloop				; 12T/7T   256*(3323+4+12)-5 = 854.779 cycles
	ret							; total delay = 854.799 cycles (20 added for ld bc and ret)

disk_recall:
	ld hl,empty_handler			; set correct interrupt vector
	ld (CTC_timer_disk),hl		; for disk interrupt
	ld hl,disk_recall_cmd		; head to track 1, device # at disk_recall_device (default 1)
	call disk_send_command
	halt						; wait for interrupt
	call read_dsk_status
	ret

; reads a full track, (16 sectors) and stores it
; at disk_transfer
read_track:
	ld iy,disk_IO_cmd
	ld hl,disk_IO_interrupt		; set proper disk interrupt vector, called after the full track was read
	ld (CTC_timer_disk),hl
	xor a
	inc a
	ld (iy+005h),a				; set sector number or does this indicate 'read 1 track'?
	ld hl,disk_IO_cmd			; execute load sector 
	call disk_send_command		; returns with B = 0, important for the ini loop later on

; setup disk_not_ready intterupt channel
; CTC vector 1, at 0x6022 normally points at 0xe799, in the DOS
; disk_init calls disk_interrupts_on. This code enables CTC channel 0 ('disk finished' interrupt)
; and initializes CTC vector 1 to point to the disk_interrupts_off routine. When the disk triggers
; a 'not_ready' interrupt this routine will gracefully deal with it.
; disk_interrupts_on does not enable channel1 interrupts, so we do it here
	ld a,0c5h					; 1100_0101 = INTEN | COUNTMODE | NOPRESCALE | TRIGGERFALLINGEDGE | STARTIMEMDIATELY | TIMECONSTANTFOLLOWS | NORESET| CTRLWORD
	out (CTC_CH1),a			
	ld a,001h					; time constant 1 : trigger after 1 pulse 
	out (CTC_CH1),a
	ld hl,(disk_transfer)		; data destination address
	ld c,DSKSTAT				; data will arrive at this port
	ld a,00dh					; 0000_1101 = MOTOR ON, RESET, ENABLE 
	out (DSKCTRL),a
	ld e,16						; 16 sectors to read (not used at all)
	ld a,001h					; switch to bank 1 at 0xE000-0xFFFF
	out (094h),a

wait_next_trk_byte:
	in a,(DSKCTRL)				; disk ctrl status
	rra							; bit 0 in carry
	jp nc,wait_next_trk_byte	; byte not available yet

	ini							; Read data byte from 0x8d, store at (HL), inc HL, dec B
	jp wait_next_trk_byte		; keep going until Disk interrupt triggers after full track is loaded
								; the interrupt will read IO status (7 bytes) from drive and return

; this code seems to be a remnant from a sector-by sector load implementation.
; is not reachable, nor referenced anywhere
	dec e						; decrement sector counter
	jp nz,wait_fdc_byte			; loop that reads B bytes from disk and returns
	ld a,00eh					; 0000_1110 = MOTORON | RESET | COUNT ?
	out (DSKCTRL),a
endless_loop:
	jr endless_loop


disk_IO_interrupt:
	pop hl						; remove interrupt return address from stack
	ld hl,read_IO_status		; put IO handler routine address on stack
	push hl
	ei							; and go there
	reti						; signal peripheral devices interrupt is served

read_IO_status:
	ld a,003h					; Reset CTC channel 1 (disk not ready interrupt off)
	out (CTC_CH1),a
	ld b,007h					; read 7 status bytes
	call read_status_bytes
	ret

; sends the goto track command, located at disk_search_cmd 
disk_do_search:
	ld hl,empty_handler			; setup interrupt handler vector
	ld (CTC_timer_disk),hl
	ld hl,disk_search_cmd
	call disk_send_command
	halt						; disk generates interrupt when done
	call read_dsk_status
	ret

; disk_track_num contains a 1 based track number (1-16)
; FDC uses 0 based (0-15)
; this entrypoint predecrements the track# and stores it in the
; gotrack command, then executes it
disk_gotrack:
	ld a,(disk_track_num)		; get track #
	dec a						; FDC works 0-based= 
	ld (disk_search_track),a	; prepare track for command
	call disk_do_search
	ret

disk_motor_on:
	ld a,00ch					; command 00001100 = RESET, MOTOR on
	out (DSKCTRL),a
	call delay_342ms			; give FDC a little time
	ret

; read disk status
; # of bytes in B
read_status_bytes:
	ld a,003h					; Reset/turn off CTC channel 1
	out (CTC_CH1),a
	ld hl,disk_status			; store disk status here
	ld a,00ch					; command 00001100 = RESET, MOTOR on
	out (DSKCTRL),a
read_status_loop:
	call disk_wait_ready
	in a,(DSKSTAT)				; read and store status byte
	ld (hl),a
	inc hl
	djnz read_status_loop		; repeat B times
	ret

disk_send_command:
	ld b,(hl)					; command length in B
dsk_cmd_loop:
	inc hl						; next command byte
	call disk_wait_ready
	ld a,(hl)					; get byte
	out (DSKSTAT),a				; send command
	djnz dsk_cmd_loop			; do all B-bytes
	ret

; checks bit 7 of port 1
; if bit is 1, disk is ready and 
; status is available on IO port 0x08D (DSKSTAT)
disk_wait_ready:
	in a,(DSKIO1)				; read status bit 
	bit 7,a						; check MSB  
	jr z,disk_wait_ready		; not ready
	ret 

disk_interrupts_on:
	ld hl,CTC_timer_disk		; disk interrupt vector
	ld a,h						; hi-byte in I register
	ld i,a
	ld a,l						; send lo byte of interrupt vector to CTC (valid for all 4 channels)
	out (CTC_CH0),a
								; preparer channel 0:
	ld a,0d5h					; 11010101 = INTEN | COUNTMODE | NOPRESCALE | TRIGGERRISINGEDGE | STARTIMEMDIATELY | TIMECONSTANTFOLLOWS | CTRLWORD
	out (CTC_CH0),a	
	ld a,001h					; timer constant = 1 so a single pulse will trigger interrupt 
	out (CTC_CH0),a
	ld hl,empty_handler			; store interrupt handler routine
	ld (CTC_timer_disk),hl		; in vector  
	ld hl,disk_interrupts_off	; intterupt handler disk not ready (channel 1) 
	ld (CTC_disk_not_ready),hl	; disable disk intterupts
	ei
	ret

empty_handler:
	ei							; just enable interrupts
	reti						; and signal peripheral devices interrupt is served

read_dsk_status:
	ld a,008h					; bit 2 = status request?
	out (DSKSTAT),a				; command to FDC
	call disk_wait_ready
	ld b,002h					; 2 bytes
	call read_status_bytes
	ret

disk_reti:
	reti						; return from interrupt signals peripheral devices interrupt is served

; disk commands setup data, will be copied to RAM at 0x6070 (disk_transfer)
; 4 commands, necessary for the disk bootstrap code are defined and filled
; with the correct values here.
disk_constants:
	defw	0xe000				; Transfer adress for PDOS (0xE000 in bank 1)

; Command 1. Disk IO, used to read a full track
	defb	0x09				; 'Disk IO' command length (always 9)
	defb	0x42				; 0100_0010 = 0x42 = 'B': read from disk (default)
								; 0100_0101 = 0x45 = 'E': write to disk
	defb	0x01				; drive #
	defb	0x01				; track #
	defb	0x00				; side	#
	defb	0x01				; sector # (0-15)
 	defb	0x01				; transmission speed (always 1)
	defb	0x10				; Sectors/track (always 16)
	defb 	0x0e				; gap space between sectors (always 15)
	defb	0x00				; data length

; Command 2. Goto Track
	defb	0x03				; 'Search' command length (always 3)
	defb	0x0f				; Search command code (0x0F)
	defb	0x01				; drive # 
	defb	0x01				; track #

; Command 3. Drive Reset, inits drive and moves head to track 1
	defb	0x02				; 'Recall' command length (always 2)
	defb	0x07				; Recall command code (0x07)
	defb	0x01				; drive # 

; Command 4. Setup drive parameters
	defb	0x03				; 'Specification' command length (always 3)
	defb	0x03				; Specification command code (0x03)
	defb	0x60				; parameters 1 and 2 (6,0) 
	defb	0x34				; parameters 3 and 4 (3,4)
constants_end:	
	defb	0xff				; unused :-) but now the code is exactly 0x1000 bytes long
disk_constants_size:    equ constants_end-disk_constants	;  
