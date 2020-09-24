; Printer routines

	org	0x0cf5

; printstring
; send string to printer, 0x00 terminates string
; input:
; HL start of string
; outputs:
; C-flag set: error occurred
; C-flag clear: OK
printstring:
	ld c,(hl)		    	    ; get char
	sub a	        		    ; clears A and carry flag 
	or c                        ; is character zero?
	ret z	        		    ; yes, done!
	inc hl			            ; point to next character
	call printchar
	ret c       			    ; return on error 
	jr printstring		        ; continue printing

; printscreen
; internal: 
; D -register contains flags
; bit 7: graphical printer (no backspace support?)
; bit 4: Graphics mode on
; bit 0: bgcol = fgcol? (hidden) flag. 1 = hidden
; 
; Bit 7 of character set: print underlined
;
; inputs
; HL   startaddress first line
; A    lines to print
; C    max line length.
;      when C == 0 then only CR/LF is printed for each line.
;
; outputs:
; C-flag set: error occurred
; C-flag clear: OK
printscreen:
	ex af,af'		        	; # of lines to print
	sub a		            	; reset lines printed
	ld (print_linenumber),a
	call printerready   		; is printer ready?
	ret nz			            ; no, exit!
	ex af,af'		        	; get lines to print
	and a
	jr z,printstring	    	; zero? then fall back on printstring!

	call show_P_status		    ; P on screen
	push hl         			; save regs
	push de
	ld d,000h                   ; reset flags (no STOP, normal printer normal character)
prt_line:
	push bc         			; save line len (C)
	push af		            	; save # of lines (A)
	bit 0,d	                	; stop pressed?
	jr z,prt_checkstop          ; no 
	call toggle_crsr_bit	    ; remove cursor from screen
	jr prt_realstop            	; only 2 STOPS in a row abort the printjob
prt_checkstop:
	call statuskey		        ; key in buffer? C-flag set means STOP key in buffer
	jr nc,prt_not_stopped       
	call prt_readkey        	; remove STOP key from buffer 
prt_realstop:
	call prt_readkey        	; wait for next key
	jr nc,prt_not_stopped		; if this is not STOP, continue printing 
	ld (print_linenumber),a		; 2 STOPS in a row abort printing, store current linenumber
	jr prt_clean_exit		    ; and exit

prt_not_stopped:
	push hl			            ; save pointer to character
	ld a,(baudrate)	        	; get baudrate
	and 080h		            ; HI bit of baudrate indicates printer type (backspace support yes/no?) 
	ld d,a			            ; in D (flags) bit indicates printer type
	jr nz,no_trim				; 1 = gfx, so print without prcessing

; don't print trailing spaces or 0x00 (blanks) at end of line 
	ld b,000h		            ; 
	add hl,bc	        		; point to end of line (line start + C) 
	inc c           			; preincrement for dec 
trim_whitespace_loop:
	dec c		            	; dec line len
	jr z,prt_CR_LF				; line len is zero, nothing to print 
	dec hl						; point to last char of the line to print
	ld a,(hl)					; get char
	and a
	jr z,trim_whitespace_loop	; zero can be trimmed
	cp ' '						; space?  
	jr z,trim_whitespace_loop	; can be trimmed

; C now contains actual # of characters to print
	pop hl						; get pointer to characters
	push hl						; save a copy 
no_trim:
	ld b,c			            ; characters to print in B
prt_char_loop:
	ld c,(hl)					; get character to print
	call toggle_crsr_bit		; show print-progress (crsr on screen)
	ld a,c						; is the char 
	cp 29						; switch to 'hidden' text (bgcol = fgcol)?
	jr nz,not_hidden
	set 0,d						; turn hidden flag on
not_hidden:
	bit 7,d						; gfx printer?  
	jr z,prt_processed_char		; no, prt_processed
	call printchar				; simply print
	jr prt_next_char

; screen codes are translated into proper printer characters
prt_processed_char:
	cp 0x98						; 0x98 means conceal, so rest of line is invisible..
	jr z,prt_CR_LF				; in that case we're done

	and 07fh					; mask inverse/crsr bit 
	jr z,output_char			; zero, processing done, just print it
	cp 9						; carry set if 9 or higher 
	jr nc,not_color				; less than 9, no action
	res 4,d						; 1-8 = set color, gfx offesst than 9 is color, turn gfx off
not_color:
	cp 17						; less than 17?
	jr c,output_char			; done
	cp 24						; less than 24?
	jr nc,not_gfx				; no 
	set 4,d						; 17-23 = set color, gfx ON 
not_gfx:
	bit 4,d						; gfx on? 
	jr z,output_char			; no, print it! 
	sub 040h					; characters in the range
	cp 020h						; 0x40-0x5F are non-printable
	jr c,output_char			; others are
	ld c,020h					; turn non-printable into a space  
output_char:
	call translate_and_print
prt_next_char:
	call toggle_crsr_bit		; hide crsr 
	jr c,end_of_line			; abort on printer error during last character
	inc hl						; next char 
	djnz prt_char_loop			; dec b (len counter) and loop till done
	dec hl						
prt_CR_LF:
	bit 7,d						; untranslated/gfx print? 
	jr nz,end_of_line			; yes, don't add CR/LF 
	ld c,00dh					; CR 
	call printchar
	ld c,0x0a					; LF
	ld a,(hl)					; get current char
	cp 0x98						; is it Conceal (0x98) 
	jr nz,no_formfeed			; no
	ld c,0x0c					; Conceal forces FF (0x0c) 
no_formfeed:
	call printchar
end_of_line:
	pop hl						; HL was pushed to save original start of line
prt_clean_exit:
	pop bc						; AF was pushed
	ld a,b						; # of lines in A 
	pop bc						; BC, containing linelen in C 
	jr c,prt_abort				; a print error occured 
	push de						; save D (flags)
	ld de,80					; video line is always 80 characters long
	add hl,de					; point to next line
	pop de						; D back
	dec a						; line counter
	jp nz,prt_line				; more to print!
prt_abort:
	pop de						
	call clear_P_status			; remove flashing P
	pop hl
	ret

; HL untouched 
; waits a maximum of ~ 10 seconds for printer to get ready
; returns set Carry id printer not ready
waitprinter:
	ld b,006h					;max 6*65536 loops 
waitprtloop:
	call printerready			; sets carry returns Z if printer is ready
	jr z,prt_ready				; 
	inc de						; loops 65536 times
	ld a,d
	or e
	jr nz,waitprtloop
	djnz waitprtloop			; clears carry
prt_ready:
; if printer ready the set flag is unset
; if time out the unset flag is set
	ccf							; invert carry 
	ret							;0dcb	c9 	. 

; returns always C, Z if printer ready
printerready:
	scf							; set carry
	in a,(CPRIN)
	bit 1,a						; READY
	ret nz						; not ready
	in a,(CPRIN)				; ready, double check!! (why??)   
	bit 1,a
	ret

prt_readkey:
	call readkey

; toggle cursor
; HL points to current char
toggle_crsr_bit:
	rl (hl)		                ; high bit in C-flag 
	ccf			                ; invert C-flag 
	rr (hl)		                ; back into character
	ret

; show a flashing P on screen
show_P_status:
	push de			            ; preserve registers
	push bc
	ld b,'P'                    ; P to screen 
plot_status:
	ld e,003h		            ; offset
	call show_mon_status
	pop bc                      ; restore registers 
	pop de
	ret

; remove flashing P from screen
clear_P_status:
	push de
	push bc
	ld b,000h					; empty char
	jr plot_status

; wrapper that saves registers before translating a char to what the printer can handle
translate_and_print:
	push hl
	push de
	push bc
	call translate_and_prt
	pop bc
	pop de
	pop hl
	ret

translate_and_prt:
	ld hl,(print_translation)	; pointer to translation table
	ld d,000h					; 
	ld e,(hl)					; length of 1st translation table in DE
	in a,(CPRIN)
	and 004h					; Printer type bit daisy 1, matrix 0 
	ld a,c						; char in A 
	res 7,c						; strip underline bit from char
	jr z,is_matrix				; STRAP bit is zero
	bit 7,a						; does char need underline? 
	jr z,no_underline			; no
	push bc						; save char
	ld c,'_'					; print underline 
	call printchar
	ld c,008h					; prep backspace
	call nc,printchar			; no error in underline then print backspace 
	pop bc						; get char back
	ret c						; not ok then return

no_underline:
	add hl,de					; skip to 2nd tranlation table.
								; table 1 = DE byte pairs long 
	add hl,de					; add len twice
	inc hl						; point to len of table 2
	ld e,(hl)					; len of table 2 in DE
	inc e						; pre increment to detect len of 0  
search_in_t2:
	inc hl						; point to input char in translation table
	dec e						; end of table reached?
	jr z,not_in_t2				; yes!

	ld a,(hl)					; get charvalue from table
	cp c						; compare to char to print
	inc hl						; get 1st translated char
	ld b,(hl)					; in B
	inc hl						; point to next translated char
	jr nz,search_in_t2			; not the correct char
	push bc						; save c and b
	ld c,(hl)					; get 2nd translated char
	call print_esc_char			; print with escape if necessary
	ld c,008h					; backspace
	call nc,printchar			; print if no error
	pop bc						; get 1st translated char
	ld c,b						; prepare for output
	call nc,print_esc_char		; print if no error
	ret							; and we're done

not_in_t2:
	ld e,(hl)					; get len (0)
is_matrix:
	inc e						; pre increment to handle len of 0
search_in_t1:
	inc hl						; point to next entry in t1-table
	dec e						; end of table?
	jr z,not_in_t1				; yes, so not found
	ld a,(hl)					; get translated char
	inc hl						; skip to next table entry
	cp c						; match with char to print? 
	jr nz,search_in_t1			; no, keep searching!
	ld c,(hl)					; get translation and print 
print_esc_char:
	bit 7,c						; needs escape? 
	res 7,c						; remove escape bit
	push bc						; save C
	ld c,27						; load escape char 
	call nz,printchar			; only print if esc is needed
	pop bc						; get char
	jr printchar				; print

not_in_t1:
	res 7,c						; remove underline bit
	ld a,020h					; space
	cp c						; is char above space (printable) ?
	jr c,printchar				; yes, print it
	ld c,a						; print a space

; printchar
; input
; charcter in C
; returns
; C-flag set: error!
; C-flag clear: OK
; HL untouched
printchar:
	push bc		            	; save registers
	push de
	call waitprinter            ; wait for printer to be ready
	jr c,exit_printchar 		; Carry means error (time out)
	ld d,00ah	            	; 10 bits to send
	di                          ; timing is critical, interrupts off
nextbit:
; bit 7, port 10 is printer data bit
; waitprinter returns NC causing startbit to be set!
	ld a,PRD|KBIEN	            ; set PRD en KBIEN 
	jr nc,sendbit		        ; carry clear? keep databit high
	res 7,a	                	; PRD <- 0 
sendbit:
	out (010h),a
	ld b,049h           		; prepare first delay (always)
	ld a,(baudrate)		        ; get baudrate code
	res 7,a		                ; remove translate flag
	inc a		            	; formula = 2400 / baudratecode +1 so add one
bitdelay:
	djnz bitdelay         		; first delay 
	ld b,04eh           		; prepare for next delay
	dec a		            	; one less delay to go
	add a,000h          		; Zero? 
	jr nz,bitdelay	        	; no so do another delay

	scf             			; set carry, so C is filled wit 1 bits
                                ; causing a Cset (0 bit to printer) for the stopbit 
	rr c	                	; lo-bit in carry 
	dec d	            		; more bits to go?
	jr nz,nextbit		        ; yes
	ld b,a			            ; A is zero when we get here
lastbitdelay:
	djnz lastbitdelay	        ; loop 256 times
	call waitprinter		    ; wait for printer ready
	ei              			; critical timing is over, enable interrupts 
exit_printchar:
	pop de	            		;restore registers
	pop bc
	ret

