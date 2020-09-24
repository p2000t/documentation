rstdebug:   	        equ 0x1013
keybuffer:      	    equ 0x6000
keycount:   	        equ 0x600c
last_key:   	        equ 0x600d
key_time:       	    equ 0x600e

RAM_bank1:              equ 0x6000
RAM_bank2:              equ 0xa000
RAM_bank3:              equ 0xe000

CPM_entry_point:        equ 0xe000

VIDEO_ram:              equ 0x5000
ATTR_ram:               equ 0x5800  ; for 2000M
Cartridge_ROM:          equ 0x1000
Cartridge_NAME:         equ 0x1005
Cartridge_START:        equ 0x1010

key_status:     	    equ 0x600f
; bit 0: 1 = shifted 
; bit 2: 1 = shift locked

clock:          	    equ 0x6010
auto_repeat:   	        equ 0x6012
type_T_M:       	    equ 0x6013

mon_status_io:          equ 0x6014
; pointer to the screenram where the monitor can display info
; about what it is doing. A bug prevents it from working correctly.
; in BASIC NL this location contains memory size 1,2,3:
; 16, 32 or 48 kb memory


baudrate:       	    equ 0x6016
; value     baud
;   0       2400
;   1       1200
;   3        600
;   7        300
;   F        150
;  1F         75
; bit 7 of baudrate 1 set: don't translate values

cassette_error: 	    equ 0x6017
next_block:	            equ	0x6018
length:                 equ 0x601a
print_linenumber:       equ 0x601e

CTC_timer_disk:         equ 0x6020
CTC_disk_not_ready:     equ 0x6022
CTC_communication:      equ 0x6022
CTC_keyboard:           equ 0x6026

transfer:       	    equ 0x6030
file_length:    	    equ 0x6032
record_length:  	    equ 0x6034
type:                   equ 0x6041
start_boot:	            equ 0x6043
load:	                equ 0x6045
record_number:	        equ 0x604f

motor_status:	        equ 0x6050 
; bit 2 = keep motor on after BLOCK read/write
; bit 3 = keep writing after BLOK write
BIT_MOTON:              equ 2
BIT_MOTWR:              equ 3

cass_loops_rem_block:   equ 0x6051  ; retry loops remaining after waiting for 1st bit of data block
cass_loops_rem_marker:  equ 0x6053  ; retry loops remaining after waiting for 1st bit of marker
; these two words contain some debugging info after a block-read operation
; wait time for a marker bit + wait time for a datablock bit may not exceed 1 second
; the value in these words record something about gap length
; and may provide diagnostic data for a slow or fast MDCR to a technician
; total wait time is

stacktemp:              equ 0x6055
stacktemp_disk:	        equ 0x608e
memsize:	            equ 0x605c
sysdisk_status:         equ 0x605d
print_translation:      equ 0x605e          ; printer character translation table


cassette_status:	    equ 0x6060
; used by the monitor. ; DON'T MODIFY as USER
; Contains Flags that indicate internal MDCR status
; bit 0: 1 = no start Mark found, 0 = mark found
; bit 1: 1 = cassette WCD is on, write head active
; bit 2: 1 = send cassette status bytes to comm port at 2400 baud
; bit 4: 1 = Tape at begin (fully rewound)
; bit 5: 1 = motor off
CST_NOMARK:             equ 0
CST_WCDON:              equ 1
CST_TOCOMM:             equ 2
CST_BOT:                equ 4
CST_MOTOROFF:           equ 5

spsave:                 equ 0x6061
sections_left:          equ 0x6063      ; 3*# block data sections left to read/write. When a cassette block I/O fails
                                        ; this value may provide diagnostic data to a technician
current_block:	        equ	0x6064
valid_length:   	    equ 0x6066
des1:           	    equ 0x6068
des_length:     	    equ 0x606a
lastblocknumber:	    equ 0x606c
block_counter:  	    equ 0x606e
paddingbytes:	        equ	0x606c

disk_transfer:          equ 0x6070          ; dest/source address for floppy data

disk_IO_cmd:            equ 0x6072          ; length of IO command
disk_rw:                equ 0x6073          ; read/write (0x42 = read, 0x45 = write)
disk_drive_num:         equ 0x6074          ; 
disk_track_num:         equ 0x6075
disk_side:              equ 0x6076
disk_sector_num:        equ 0x6077
disk_speed:             equ 0x6078
disk_sectorspertrack:   equ 0x6079
disk_gapspace:          equ 0x607a
disk_datalength:        equ 0x607b

disk_search_cmd:        equ 0x607c
disk_search_track:      equ 0x607f

disk_recall_cmd:        equ 0x6080
disk_recall_device:     equ 0x6082

disk_specify_cmd:       equ 0x6083

disk_status:            equ 0x6087

CPOUT:                  equ 0x10
;---------------------
;bit	description
;7	    PRD Printer data out, connected to printer port pin 3
;6  	KBIEN Keyboard interrupt enable. 1=on, 0=off
;5	    ---
;4	    ---
;3	    FWD cassette forward
;2	    REV cassette backward
;1	    WCD Write Command write = 1, no action = 0
;0 	    WDA Write Data   data to cassette
PRD:                    equ 0x80
KBIEN:                  equ 0x40
FWD:                    equ 0x08
REV:                    equ 0x04
WCD:                    equ 0x02
WDA:                    equ 0x01


CPRIN:                  equ 020h
;INPUT port 0x20-0x2f 	cassette and printer
;--------------------
;bit	description
; 0	    PRI   	printer data in connected to printer port pin 2
; 1	    READY 	printer ready connected to printer port pin 20
; 2	    STRAP	(N) printer type (Daisy/Matrix) 
; 3	    WEN	(N) Can write = 0, Protected   = 1
; 4	    CIP 	(N) Cassette  = 0, No cassette = 1
; 5	    BET 	(N) Begin/end = 0, Tape ok     = 1
; 6	    RDC 	ReaD Clock (goes High-Low or Low-High when a databit is ready)
; 7     RDA 	Data bit from cassette
PRI:                    equ 0x01
READY:                  equ 0x02
STRAP:                  equ 0x04
WEN:                    equ 0x08
CIP:                    equ 0x10
BET:                    equ 0x20
RDC:                    equ 0x40
RDA:                    equ 0x80


; if a CTC is present, the P2000 uses channel 3 for keyboard interrupt generation
CTC_CH0:                equ 088h         ; timer/disk interrupt
CTC_CH1:                equ 089h         ; disk not ready interrupt
CTC_CH2:                equ 08ah         ; communication (I/O) interrupt
CTC_CH3:                equ 08bh         ; keyboard interrupt
;--------------------
;bit	description
; 0	    CTRLWRD   	1 = this is a control word
; 1	    RESET       1 = reset CTC
; 2	    TCNEXT      1 = next word is a time constant
; 3	    CLKSTRT     1 = start on next clock 0 = start immediately 
; 4	    ACTTRG      1 = trigger on rising edge of clock
; 5	    PRE256      1 = prescaler = 256, 0 = 16 
; 6	    CNTMD       1 = Counter, 0 = timer
; 7     INTEN       1 = generate interrupt, 0 = don't generate

DSKIO1:                 equ 0x8C     ; INPUT status of FDC
;--------------------
;bit	description
; 7	    RDY         1 = ready, 0 = not ready

DSKSTAT:                equ 0x8D     ; INPUT/OUTPUT 
; bit 2 REQ        1 = request status


DSKCTRL:                equ 0x90
;--------------------
;bit	description
; 0	    ENABLE      1 = read/write registers
; 1	    Count       terminal count
; 2	    RESET       1 = FDC reset
; 3	    MOTOR       1 = on, 0 = off 
; 4	    SELDIS      1 = Select disabled, 0 = normal, enabled
;                   Bit 4 only in use on P2C2 disk board

; cassette jumptable codes
cInit:                  equ 0
cRewind:                equ 1
cSkip_Forward:          equ 2
cSkip_Reverse:          equ 3
cEndOfTape:             equ 4
cWrite:                 equ 5
cRead:                  equ 6
cStatus:                equ 7
