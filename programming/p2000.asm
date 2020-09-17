;  Annotated assembly, obtained by running z80dasm
;
;  and injecting documentation from monitor.pdf
;
;  please make sure that z80asm p2000.asm && diff a.bin p2000.rom && echo "all good"
;  prints all good!

      org      00000h
keybuf:           equ 6000h  ; 6000 - 6000B is the keyboard buffer
keycnt:           equ 600ch  ; sizeof(keybuf)
					; Toetsbufferteller. Dit adres bevat het aantal toetscodes dat is
					; opgeborgen vanaf adres 6000 (maximaal 12).
lastkey:          equ 600dh
					; Op dit adres staat de code van de laatst ingedrukte toets. De
					; ingedrukte toets wordt niet automatisch verwerkt. maar de
					; toetscode lij ft staan zolang de toets ingedrukt is. Wordt de
					; toets losgelaten. dan komt er bij de eerstvolgende toetsenbord-
					; "scan"-routine (d.w.z. binnen 20 ms) FF (=255) te staan.
keytime:          equ 600eh
statkey:          equ 600fh
					; Vlag voor het toetsenbord. Normaal staat er 00.
					; 00 = geen SHIFT of SHIFT LOCK ingedrukt
					; 01 = SHIFT ingedrukt (bit 0 = 1)
					; 04 = SHIFT LOCK aan (bit 2 = 1)
					; 05 = SHIFT en SHIFT LOCK ingedrukt (bit 0 = 1 en bit 2 = 1).
klok:             equ 6010h ; klok, loopt van 0 tot plm. 20
klok_2:           equ 6011h ; minuten met stapjes van 20 msec.  (klok + 256 * klok_2)
autorep:          equ 6012h
					; Vlagadres voor de monitor. dat voor verschillende doeleinden
					; wordt gebruikt. Bij voorbeeld voor het automatisch herhalen
					; van een ingedrukt gehouden toets; bit 0 = 1 betekent:
					; "repeat" aan (zie &HO06C voor vullen en &HO07 A. ..0083 voor
					; testen); bit 1 = 1 betekent "numeric" aan.
T_M:              equ 6013h ; type (model M or T?)
iotype:           equ 6014h
baudrate:         equ 6016h  ; baudrate printer
intr:             equ 6026h
fileleng:         equ 6032h
rec1eng:          equ 6034h
strt_boot:        equ 6043h
sptemp:           equ 6055h
memsize:          equ 605ch
					; Bij het opstarten controleert de monitor hoeveel geheugen
					; aanwezig is en zet het resultaat hier neer. De getallen hebben
					; de volgende betekenis:
					; 01 16 Kbyte
					; 02 32 Kbyte
					; 03 48 Kbyte of meer

caserror:         equ 6017h
		; Op dit adres staat het ASCII-karakter van de laatst opgetreden cassettefout ("tape error"). Het adres wordt gebruikt
		; door de monitor. De karakters hebben de volgende betekenis: 00 (&HOO) = Geen fout r
		; 65 (&H41) = "A" Geen cassette
		; 66 (&H42) = "B" Begin van de band
		; 67 (&H43) = "C" Leesfout, record gelezen
		; 68 (&H44) = "D" Controlegetal ("checksum") fout in startmerk
		; 69 (&H45) = "E" Einde van de band bij schrijven
		; 70 (&H46) = "F" Einde van de band, maar bestand is geSAVEd
		; 71 (&H47) = "G" Geen stopje
		; 73 (&H49) = "I" Maximale terugspoeltijd verstreken; cassetteband gebroken of te lange cassetteband
		; 74 (&H4A) = "J" Te kort datablok gelezen, maar controle-getal ("checksum") in orde, of band spoelt niet doordat deze vast zit
		; 75 (&H4B) = "K" Verkeerde functiecode (komt niet voor; in BASIC)
		; 76 (&H4C) = "1" Einde van de band bij lezen
		; 77 (&H4D) = "M" Geen begin-merk ("start mark") gevonden
		; 78 (&H4E) = "N" Geen programma gevonden
		; 87 (&H57) = "W" Verkeerd bestandstype (geen BASIC)

newblock:         equ 6018h
		; &H8147 -Laadadres (buffer) voor machinetaalprogramma's,
		; geladen van cassette (zonder ROM-pack in sleuf 1). Het adres
		; wordt ook gebruikt bij het laden van een BASIC-programma
		; voor het doorgeven van het laadadres.
		; Adres waar de uitvoering van een machinetaa

length:           equ 601ah
		; Adres waar de uitvoering van een machinetaalprogramma begint, dat is geladen zonder ROM-pack in sleuf 1.
		; Het adres wordt ook gebruikt voor het doorgeven van de DATA lengte bij het laden van een BASIC-programma.

transfer:         equ 6030h   ; Tape Header
		; De adressen &H6030 en &H6031 vormen het transferadres, dat
		; wil zeggen het eerste lees- of schrijfadres voor cassette-files.
		; Het adres moet worden gegeven door het toepassingsprogramma. Bij BASIC NL is dit adres gewoonlijk &H6547, als het
		; laatste bestand dat de cassetterecorder "passeerde" een
		; BASIC-programma was.

filelen:          equ 6032h
		; In deze adressen staat de totale lengte van het programma of  bestand. Dit in verband met het bepalen van het einde van
		; dat programma of bestand.

reclen:           equ 6034h
		; Aantal zinvolle bytes van het gehele programma. BASIC NL
		; schrijft altijd hele blokken van 1024 bytes (&H0400) weg,
		; behalve in het algemeen voor het laatste blok dat wordt weggeschreven (of ingelezen).
		; Als het laatste blok korter is dan
		; 1024 zinvolle bytes, wordt dit blok aangevuld met nullen tot
		; 1024. De "zinvolle lengte" in &H6034 en 6035 is meestal korter
		; dan de "totale lengte" in &H 6032 en 6033. Als een programma
		; met een totale lengte van 7 blokken wordt overschreven door
		; een programma van bij voorbeeld 3 blokken, blijft de totale
		; lengte 7 blokken, maar de zinvolle lengte wordt dan 3 blokken.
file_type:        equ 6041h   ; B, P etc. (File type?)
		; File-type; het type ROM-pack of toepassingsprogramma waaronder de file is aangemaakt. De karakters kunnen de volgende betekenis hebben:
		; 64 (&H40) = "@" Plaatje van Peters Plaatjes Programma
		; 65 (&H41) = "A" Familiegeheugen
		; 66 (&H42) = "B" BASIC NL
		; 68 (&H44) = "D" 24K DISK BASIC
		; 70 (&H46) = "F" FORTH
		; 79 (&H4F) = "0" Overige
		; 80 (&H50) = "P" "Stand alone"-programma (zonder ROMpack in sleuf 1)
		; 86 (&H56) = "V" B IS editor
		; 87 (&H57) = "VJ" Tekstverwerker ("Wordprocessor")

load:             equ 6045h
recnum:           equ 604fh
motorstat:        equ 6050h
		; Commandovlag voor de cassettemotor; er worden 2 bits gebruikt door
		; de Monitor:
		; 		bit 2 = 0 zet de motor uit
		; 		bit 2 = 1 zet de motor aan
		; 		bit 3 = 0 niet (meer) schrijven
		; 		bit 3 = 0 (blijf) schrijven
stacas:           equ 6060h
		; Vlagadres voor de cassettestatus, gebruikt door de monitor.
		; De inhoud van dit adres mag niet door de gebruiker worden veranderd.
		; Er zijn 5 bits in gebruik. Als alle bits = 0 zijn, is er geen
		; fout opgetreden. Anders geldt:
		;		bit 0 = 1 geen startmerk
		; 		bit 1 = 1 niet (meer) schrijven
		; 		bit 2 = 1 zend cassette-ERROR-code naar de printer
		; 		bit 4 = 1 er is een Begin Of Tape-error (BOT-error)
		; 		bit 5 = 1 zet de motor uit
spsave:           equ 6061h   ; stores the sp
		; Dit adres wordt door de cassetteroutines van de monitor gebruikt om de
		; stack pointer te bewaren.
oldblk:           equ 6064h   ; casste
        ; Tijdelijke opslag voor de cassetteroutines van de monitor.Laadadres.
		; Pointer naar het adres van waar af data van cassette in het geheugen moet worden geladen.
validlen:         equ 6066h   ; in blok tape
		; Bloklengte. Dit adres bevat de lengte van het laaste gelezen blok

desl:             equ 6068h   ; copy descrip
		; Beginadres van de cassette-header of "file descriptor". Deze
		; begint meestal op &H6030.
hdrlen:           equ 606ah   ; length of header
		; Lengte van de cassette-header. Deze is altijd 32 bytes lang
		; (&H0020).
endblk:           equ 606ch   ; einde blok
		; Deze adressen bevatten het aantal nullen waarmee een onvolledig blok
		; moet worden aangevuld tot 1024.
telblok:          equ 606eh   ; blokken
		; Hier staat de lengte in blokken van de cassette file.


; DISK
descrip:          equ 6070h

cas_kbd:          equ 10h     ; output port for cassette, printer, keyboard
                              ; also used to enable/disable keyboard
;    bit 0 - Cassette write data    (WDA)
;    bit 1 - Cassette write command (WCD)
;    bit 2 - Cassette rewind        (RWD)
;    bit 3 - Cassette forward       (FWD)
;    bit 4 - Unused
;    bit 5 - Unused
;    bit 6 - Keyboard interrupt enable
;    bit 7 - Printer output


cas_inp:          equ 20h     ; input port for cassette
;    bit 0 - Printer input
;    bit 1 - Printer ready
;    bit 2 - Strap N (daisy/matrix)
;    bit 3 - Cassette write enabled (WEN)  1 = Write protected, 0 can write
;    bit 4 - Cassette in position   (CIP)  1 = cassette in place, 0 otherwise.
;    bit 5 - Begin/end of tape      (BET)  1 = tape ok, 0 if end of tape.
;    bit 6 - Cassette read clock    (RDC)  (goes High-Low or Low-High when a databit is ready)
;    bit 7 - Cassette read data     (RDA)

; RST Jump table:

; 00h 000
; 08h 001
; 10h l13c3h
; 18h cassette (04f1)
; 20h enkey
; 28h
; 30h 110
; 38h 111


l0000h:
      di                      ;0000    f3
l0001h:
      jp       start          ;0001    c3  5a  02
      nop                     ;0004    00
      jp       CPM_start      ;0005    c3  4f  04
l0008h:
      jp       prscreen       ;0008    c3  00  0d
      jp       inpdisk        ;000b    c3  67  04
      call     po,0c301h      ;000e    e4  01  c3
      inc      de             ;0011    13          ; RST 10: jp 13c3
      djnz     $-59           ;0012    10  c3
l0014h:
      ld       a,d            ;0014    7a
      inc      b              ;0015    04
      call     po,0c301h      ;0016    e4  01  c3  ; RST 18: jp cassette
      pop      af             ;0019    f1
      inc      b              ;001a    04
      jp       initkbd        ;001b    c3  67  01
      sub      b              ;001e    90
      ld       c,0c3h         ;001f    0e  c3      ; RST 20h jp enkey
      or       h              ;0021    b4
      nop                     ;0022    00
      jp       no_kbd         ;0023    c3  bc  00
      jp       readkey        ;0026    c3  9b  04
      jp       l0489h         ;0029    c3  89  04
      jp       clearkey       ;002c    c3  dc  04
      jp       001e1h         ;002f    c3  e1  01
      jp       beep           ;0032    c3  ea  01
      jp       wisregel       ;0035    c3  23  04

; Via de interrupt woth het toestenbord
; bekenen, eventeel een toest in de be
; buffer gezet (6000) en de klok bijgewerkt
; scanfrequentie toestebord 20msec, repeat delay 1 sec
; repeat freq 4o msec
keyscan:
      call     save_reg       ;0038    cd  a5  01
      ld       hl,(klok)      ;003b    2a  10  60
      inc      hl             ;003e    23
      ld       (klok),hl      ;003f    22  10  60
      in       a,(000h)       ;0042    db  00
      cp       0ffh           ;0044    fe  ff
      ld       a,000h         ;0046    3e  00
      out      (cas_kbd),a    ;0048    d3  10
      jr       z,nokey        ;004a    28  2d
      call     sub_00fah      ;004c    cd  fa  00
      ld       a,b            ;004f    78
l0050h:
      cp       0ffh           ;0050    fe  ff
      jr       z,l00a1h       ;0052    28  4d
      ld       a,(lastkey)    ;0054    3a  0d  60
      cp       b              ;0057    b8
      jr       nz,l009eh      ;0058    20  44
      ld       hl,keytime     ;005a    21  0e  60
      dec      (hl)           ;005d    35  5
      jr       z,l0062h       ;005e    28  02
      jr       l00aah         ;0060    18  48
l0062h:
      push     hl             ;0062    e5
      jp       l0069h         ;0063    c3  69  00
      jp       01016h         ;0066    c3  16  10
l0069h:
      ld       hl,autorep     ;0069    21  12  60
      set      0,(hl)         ;006c    cb  c6
      pop      hl             ;006e    e1
      call     sub_00d0h      ;006f    cd  d0  00
      ld       a,002h         ;0072    3e  02
      ld       (keytime),a    ;0074    32  0e  60
      jr       l00aah         ;0077    18  31
nokey:
      push     af             ;0079    f5
      ld       a,(autorep)    ;007a    3a  12  60
      bit      0,a            ;007d    cb  47
      jr       z,l008ah       ;007f    28  09
      res      0,a            ;0081    cb  87
      ld       (autorep),a    ;0083    32  12  60
      xor      a              ;0086    af
      ld       (keycnt),a     ;0087    32  0c  60
l008ah:
      pop      af             ;008a    f1
      ld       a,0ffh         ;008b    3e  ff
      ld       (lastkey),a    ;008d    32  0d  60
      ld       a,(statkey)    ;0090    3a  0f  60
      bit      2,a            ;0093    cb  57
      jr       nz,l009ch      ;0095    20  05
      and      0feh           ;0097    e6  fe
      ld       (statkey),a    ;0099    32  0f  60
l009ch:
      jr       l00aah         ;009c    18  0c
l009eh:
      call     sub_00d0h      ;009e    cd  d0  00
l00a1h:
      ld       a,032h         ;00a1    3e  32
      ld       (keytime),a    ;00a3    32  0e  60
      ld       a,b            ;00a6    78
      ld       (lastkey),a    ;00a7    32  0d  60
l00aah:
      ld       a,040h         ;00aa    3e  40
      out      (cas_kbd),a    ;00ac    d3  10
      call     sub_01abh      ;00ae    cd  ab  01
      ei                      ;00b1    fb
      reti                    ;00b2    ed  4d
enkey:
      ; enable keyboard scanning
      call     save_reg       ;00b4    cd  a5  01
      call     sub_00c5h      ;00b7    cd  c5  00
      jr       l00aah         ;00ba    18  ee
no_kbd:
      ld       a,000h         ;00bc    3e  00
      out      (cas_kbd),a    ;00be    d3  10
sub_00c0h:
      ld       a,001h         ;00c0    3e  01
      out      (08bh),a       ;00c2    d3  8b
      ret                     ;00c4    c9
sub_00c5h:
      ld       a,0d5h         ;00c5    3e  d5
      out      (08bh),a       ;00c7    d3  8b
      ld       a,001h         ;00c9    3e  01
      out      (08bh),a       ;00cb    d3  8b
sub_00cdh:
      ei      		      ;00cd    fb
      reti   			;00ce    ed  4d
sub_00d0h:
      ld       a,b            ;00d0    78
      cp       058h           ;00d1    fe  58
      jr       nz,l00dch      ;00d3    20  07
      ld       (keybuf),a     ;00d5    32  00  60
      ld       a,001h         ;00d8    3e  01
      jr       l00f3h         ;00da    18  17
l00dch:
      cp       012h           ;00dc    fe  12
      jr       nz,l00e4h      ;00de    20  04
      ld       b,a            ;00e0    47
      call     l00e4h         ;00e1    cd  e4  00
l00e4h:
      ld       a,(keycnt)     ;00e4    3a  0c  60
      ld       hl,keybuf      ;00e7    21  00  60
      ld       l,a            ;00ea    6f
      cp       00ch           ;00eb    fe  0c
      jr       z,l00f7h       ;00ed    28  08
l00efh:
      ld       a,b            ;00ef    78
      ld       (hl),a         ;00f0    77
      inc      hl             ;00f1    23
      ld       a,l            ;00f2    7d
l00f3h:
      ld       (keycnt),a     ;00f3    32  0c  60
      ret                     ;00f6    c9
l00f7h:
      dec      hl             ;00f7    2b
      jr       l00efh         ;00f8    18  f5
sub_00fah:
      ld       b,0ffh         ;00fa    06  ff
      ld       hl,statkey      ;00fc    21  0f  60
      ld       c,000h         ;00ff    0e  00
l0101h:
      in       a,(c)          ;0101    ed  78
      ld       e,a            ;0103    5f
      xor      0ffh           ;0104    ee  ff
      call     nz,sub_0129h   ;0106    c4  29  01
      inc      c              ;0109    0c
      ld       a,c            ;010a    79
      cp       009h           ;010b    fe  09
      jr       nz,l0101h      ;010d    20  f2
      in       a,(c)          ;010f    ed  78
      cp       0ffh           ;0111    fe  ff
      jr       z,l0123h       ;0113    28  0e
      set      0,(hl)         ;0115    cb  c6
      res      2,(hl)         ;0117    cb  96
      push     bc             ;0119    c5
      ld       b,000h         ;011a    06  00
      ld       e,001h         ;011c    1e  01
      call     scrn_type      ;011e    cd  be  01
      pop      bc             ;0121    c1
      ret                     ;0122    c9
l0123h:
      bit      2,(hl)         ;0123    cb  56
      ret      nz             ;0125    c0
      res      0,(hl)         ;0126    cb  86
      ret                     ;0128    c9
sub_0129h:
      push     af             ;0129    f5
      ld       a,003h         ;012a    3e  03
      cp       c              ;012c    b9
      jr       nz,l0148h      ;012d    20  19
      bit      0,e            ;012f    cb  43
      jr       nz,l0148h      ;0131    20  15
      push     bc             ;0133    c5
      push     hl             ;0134    e5
      ld       b,04ch         ;0135    06  4c
      ld       e,001h         ;0137    1e  01
      call     scrn_type      ;0139    cd  be  01
      pop      hl             ;013c    e1
      pop      bc             ;013d    c1
      ld       a,(statkey)    ;013e    3a  0f  60
      or       005h           ;0141    f6  05
      ld       (statkey),a    ;0143    32  0f  60
      pop      af             ;0146    f1
      ret                     ;0147    c9
l0148h:
      pop      af             ;0148    f1
      ld       e,000h         ;0149    1e  00
l014bh:
      rra                     ;014b    1f
      jr       c,l0151h       ;014c    38  03
      inc      e              ;014e    1c
      jr       l014bh         ;014f    18  fa
l0151h:
      ld       a,c            ;0151    79
      rlca                    ;0152    07
      rlca                    ;0153    07
      rlca                    ;0154    07
      or       e              ;0155    b3
      ld       e,a            ;0156    5f
      ld       a,(statkey)     ;0157    3a  0f  60
      bit      0,a            ;015a    cb  47
      ld       a,e            ;015c    7b
      jr       z,l0162h       ;015d    28  03
      ld       a,048h         ;015f    3e  48
      add      a,e            ;0161    83
l0162h:
      ld       b,a            ;0162    47
      call     special      ;0163    cd  d2  01
      ret                     ;0166    c9
initkbd:
      call     sub_01b2h      ;0167    cd  b2  01
      ld       hl,l0188h      ;016a    21  88  01
      ld       (06026h),hl    ;016d    22  26  60
      ld       a,000h         ;0170    3e  00
      out      (cas_kbd),a    ;0172    d3  10
      ld       a,032h         ;0174    3e  32
      ld       (keytime),a     ;0176    32  0e  60
      ld       a,085h         ;0179    3e  85
      out      (08bh),a       ;017b    d3  8b
      ld       a,001h         ;017d    3e  01
      out      (08bh),a       ;017f    d3  8b
      call     sub_00cdh      ;0181    cd  cd  00
      im       1              ;0184    ed  56
      jr       l0195h         ;0186    18  0d
l0188h:
      pop      hl             ;0188    e1
      call     sub_00c0h      ;0189    cd  c0  00
      ld       hl,keyscan     ;018c    21  38  00
      ld       (06026h),hl    ;018f    22  26  60
      call     sub_00c5h      ;0192    cd  c5  00
l0195h:
      ld       a,040h         ;0195    3e  40
      out      (cas_kbd),a    ;0197    d3  10
      ld       hl,keybuf      ;0199    21  00  60
      ld       a,l            ;019c    7d
      ld       (keycnt),a     ;019d    32  0c  60
      xor      a              ;01a0    af
      ld       (statkey),a     ;01a1    32  0f  60
      ret                     ;01a4    c9
save_reg:
      ex       (sp),hl        ;01a5    e3
      push     de             ;01a6    d5
      push     bc             ;01a7    c5
      push     af             ;01a8    f5
      di                      ;01a9    f3
      jp       (hl)           ;01aa    e9
sub_01abh:
      pop      hl             ;01ab    e1
      pop      af             ;01ac    f1
      pop      bc             ;01ad    c1
      pop      de             ;01ae    d1
      ei                      ;01af    fb
      ex       (sp),hl        ;01b0    e3
      ret                     ;01b1    c9
sub_01b2h:
      im       2              ;01b2    ed  5e
      ld       hl,06020h      ;01b4    21  20  60
      ld       a,l            ;01b7    7d
      out      (088h),a       ;01b8    d3  88
      ld       a,h            ;01ba    7c
      ld       i,a            ;01bb    ed  47
      ret                     ;01bd    c9

; laat type functie op scherm zien. dit gebeurt bijvals een bootstrap-
; tape geladen wordt (zonder ROM module) er verschijnt dan een T (van Tape)
; op het scherm.
; 			B: karakter
; 			E: verplaatsing in ilo veld
scrn_type:
      push     af             ;01be    f5
      push     hl             ;01bf    e5
      push     de             ;01c0    d5
      ld       hl,(iotype)    ;01c1    2a  14  60
      ld       d,000h         ;01c4    16  00
      add      hl,de          ;01c6    19
      ld       (hl),b         ;01c7    70
      ld       de,0800h       ;01c8    11  00  08
      add      hl,de          ;01cb    19
      ld       (hl),0f5h      ;01cc    36  f5
      pop      de             ;01ce    d1
      pop      hl             ;01cf    e1
      pop      af             ;01d0    f1
      ret

	                    ;01d1    c9
special:
      ld       a,(lastkey)     ;01d2    3a  0d  60
      sub      048h           ;01d5    d6  48
      cp       b              ;01d7    b8
      ret      nz             ;01d8    c0
      ld       a,b            ;01d9    78
      ld       (lastkey),a     ;01da    32  0d  60
      ret                     ;01dd    c9

; system error, met een maintenance
; module kan via een NMI achterhaald
; worden welk type fout er was (in A).
err0:
      ld       a,035h         ;01de    3e  35       ; '5'
      ld       bc,0313eh      ;01e0    01  3e  31
      ld       bc,0303eh      ;01e3    01  3e  30
l01e6h:
      di                      ;01e6    f3
      halt                    ;01e7    76
      jr       l01e6h         ;01e8    18  fc
beep:
      call     save_reg       ;01ea    cd  a5  01
      ld       e,080h         ;01ed    1e  80
l01efh:
      ld       a,001h         ;01ef    3e  01
      out      (050h),a       ;01f1    d3  50
      call     sub_0205h      ;01f3    cd  05  02
      xor      a              ;01f6    af
      out      (050h),a       ;01f7    d3  50
      call     sub_0205h      ;01f9    cd  05  02
      dec      e              ;01fc    1d
      ld       a,e            ;01fd    7b
      or       a              ;01fe    b7
      jr       nz,l01efh      ;01ff    20  ee
l0201h:
      call     sub_01abh      ;0201    cd  ab  01
      ret                     ;0204    c9
sub_0205h:
      ld       b,080h         ;0205    06  80
l0207h:
      djnz     l0207h         ;0207    10  fe
      ret                     ;0209    c9
      ld       a,(hl)         ;020a    7e
      ld       b,000h         ;020b    06  00
      ld       c,a            ;020d    4f
      inc      hl             ;020e    23
      ldir                    ;020f    ed  b0
      ret                     ;0211    c9
l0212h:
      ld       b,e            ;0212    43
      ld       b,c            ;0213    41
      ld       c,h            ;0214    4c
      ld       c,h            ;0215    4c
      jr       nz,l026bh      ;0216    20  53
      ld       b,l            ;0218    45
      ld       d,d            ;0219    52
      ld       d,(hl)         ;021a    56
      ld       c,c            ;021b    49
      ld       b,e            ;021c    43
      ld       b,l            ;021d    45
l021eh:
      call     pe,sub_0f51h   ;021e    ec  51  0f
      ld       b,00dh         ;0221    06  0d
      ld       d,b            ;0223    50
      jr       nz,$+74        ;0224    20  48
      jr       nz,$+75        ;0226    20  49
      jr       nz,l0276h      ;0228    20  4c
      jr       nz,$+75        ;022a    20  49
      jr       nz,$+82        ;022c    20  50
      jr       nz,$+85        ;022e    20  53
      call     c,sub_0f51h+1  ;0230    dc  52  0f
      ld       b,00dh         ;0233    06  0d
      ld       c,l            ;0235    4d
      ld       c,c            ;0236    49
      ld       b,e            ;0237    43
      ld       d,d            ;0238    52
      ld       c,a            ;0239    4f
      ld       b,e            ;023a    43
      ld       c,a            ;023b    4f
      ld       c,l            ;023c    4d
      ld       d,b            ;023d    50
      ld       d,l            ;023e    55
      ld       d,h            ;023f    54
      ld       b,l            ;0240    45
      ld       d,d            ;0241    52
      ret      nc             ;0242    d0
      ld       d,e            ;0243    53
      rlca                    ;0244    07
      ld       b,00dh         ;0245    06  0d
      ld       d,b            ;0247    50
      ld       (03030h),a     ;0248    32  30  30
      jr       nc,$+1         ;024b    30  ff  0

ram_error:
			; Plaats call service op het scherm
      ld       hl,l0212h      ;024d    21  12  02
      ld       de,05012h      ;0250    11  12  50
      ld       bc,0000ch      ;0253    01  0c  00
      ldir                    ;0256    ed  b0
      jr       l01e6h         ;0258    18  8c
start:
      ld       a,001h         ;025a    3e  01
      out      (088h),a       ;025c    d3  88
      out      (089h),a       ;025e    d3  89
      out      (08ah),a       ;0260    d3  8a
      out      (08bh),a       ;0262    d3  8b
      ld       a,000h         ;0264    3e  00
      out      (cas_kbd),a    ;0266    d3  10
      ld       a,(01000h)     ;0268    3a  00  10
l026bh:
      cp       058h           ;026b    fe  58
      jp       z,01010h       ;026d    ca  10  10
      ld       sp,057ffh      ;0270    31  ff  57
      call     beep           ;0273    cd  ea  01
l0276h:
      ld       hl,keybuf      ;0276    21  00  60
      ld       bc,040ffh      ;0279    01  ff  40
      call     ram_test      ;027c    cd  dc  03
      or       a              ;027f    b7
      jr       nz,ram_error   ;0280    20  cb
      ld       sp,06200h      ;0282    31  00  62
      ld       hl,memsize      ;0285    21  5c  60
      inc      (hl)           ;0288    34  4
      ld       hl,05000h      ;0289    21  00  50
      ld       bc,008ffh      ;028c    01  ff  08
      call     ram_test      ;028f    cd  dc  03
      or       a              ;0292    b7
l0293h:
      jr       nz,ram_error   ;0293    20  b8
      ld       hl,05800h      ;0295    21  00  58
      ld       bc,0080fh      ;0298    01  0f  08
      call     ram_test      ;029b    cd  dc  03
      cp       002h           ;029e    fe  02
      jr       z,ram_error    ;02a0    28  ab
      cp       001h           ;02a2    fe  01
      jr       z,l02bdh       ;02a4    28  17
      ld       a,005h         ;02a6    3e  05
      ld       (05800h),a     ;02a8    32  00  58
      ld       a,(05800h)     ;02ab    3a  00  58
      and      00fh           ;02ae    e6  0f
      cp       005h           ;02b0    fe  05
      jr       nz,l02bdh      ;02b2    20  09
      ld       hl,T_M         ;02b4    21  13  60
      set      0,(hl)         ;02b7    cb  c6
      xor      a              ;02b9    af
      ld       (05800h),a     ;02ba    32  00  58
l02bdh:
      ld       hl,0a000h      ;02bd    21  00  a0
      ld       bc,040ffh      ;02c0    01  ff  40
      call     ram_test       ;02c3    cd  dc  03
      cp       002h           ;02c6    fe  02
l02c8h:
      jr       z,ram_error    ;02c8    28  83
      cp       001h           ;02ca    fe  01
      jr       z,not_present  ;02cc    28  3e
      ld       hl,0a000h      ;02ce    21  00  a0
      call     test_55      ;02d1    cd  fe  03
      jr       nz,not_present      ;02d4    20  36  6
      ld       hl,memsize     ;02d6    21  5c  60 ; 32Kb!
      inc      (hl)           ;02d9    34  4
      xor      a              ;02da    af
      out      (094h),a       ;02db    d3  94
      ld       hl,0e000h      ;02dd    21  00  e0
      ld       bc,020ffh      ;02e0    01  ff  20
      call     ram_test       ;02e3    cd  dc  03
      cp       002h           ;02e6    fe  02
      jr       z,l02c8h       ;02e8    28  de
      cp       001h           ;02ea    fe  01
      jr       z,not_present  ;02ec    28  1e
      ld       hl,0e000h      ;02ee    21  00  e0
      call     test_55      ;02f1    cd  fe  03
      jr       nz,not_present ;02f4    20  16
      ld       a,001h         ;02f6    3e  01
      out      (094h),a       ;02f8    d3  94
      ld       hl,0e000h      ;02fa    21  00  e0
      ld       bc,020ffh      ;02fd    01  ff  20
      call     ram_test       ;0300    cd  dc  03
l0303h:
      or       a              ;0303    b7
      jr       nz,l0293h      ;0304    20  8d
      ld       hl,memsize     ;0306    21  5c  60
      inc      (hl)           ;0309    34  4
      out      (094h),a       ;030a    d3  94

not_present:
      ld       a,(memsize)    ;030c    3a  5c  60
      cp       003h           ;030f    fe  03     ; 48kb?
      jr       nz,l0330h      ;0311    20  1d
      ld       a,(01000h)     ;0313    3a  00  10
      bit      0,a            ;0316    cb  47     ; rom module
      jr       nz,l0330h      ;0318    20  16     ; not present?
      bit      1,a            ;031a    cb  4f     ; do we need dos?
      jr       z,l0330h       ;031c    28  12

; Activate floppy controller and wait until it is awake
      ld       a,004h         ;031e    3e  04
      out      (090h),a       ;0320    d3  90
      ld       b,000h         ;0322    06  00
l0324h:
      djnz     l0324h         ;0324    10  fe
      in       a,(08ch)       ;0326    db  8c     ; ask the controllor if it is awake
      cp       080h           ;0328    fe  80
      call     z,getDOS       ;032a    cc  90  0e ; if so, let's get dos!
      xor      a              ;032d    af
      out      (090h),a       ;032e    d3  90     ; Turn of the FDC.


l0330h:
      ld       hl,0500eh      ;0330    21  0e  50
      ld       (iotype),hl    ;0333    22  14  60
      ld       b,008h         ;0336    06  08
      ld       e,000h         ;0338    1e  00
      call     scrn_type      ;033a    cd  be  01 ; Flash screen
      ld       b,009h         ;033d    06  09
      ld       e,004h         ;033f    1e  04
      call     scrn_type      ;0341    cd  be  01
      in       a,(cas_inp)    ;0344    db  20   ; baudrate
      bit      0,a            ;0346    cb  47   ; printer
      ld       a,007h         ;0348    3e  07   ; 300 baud
      jr       z,l034eh       ;034a    28  02
      ld       a,001h         ;034c    3e  01   ; 1200 baud
l034eh:
      ld       (baudrate),a   ;034e    32  16  60
      call     cas_init       ;0351    cd  05  06
      call     initkbd        ;0354    cd  67  01
      call     enkey          ;0357    cd  b4  00 ; Enable the keyboard
      ld       a,(01000h)     ;035a    3a  00  10
      and      0f5h           ;035d    e6  f5     ; erase bit 1,3
      cp       054h           ;035f    fe  54     ; Rom ok?
      jr       nz,bootstrap    ;0361    20  22     ; no rom!
      ld       hl,01000h      ;0363    21  00  10
      ld       a,(hl)         ;0366    7e
      bit      0,a            ;0367    cb  47
      jr       nz,bootstrap   ;0369    20  1a     ; no rom!
      push     hl             ;036b    e5
      call     romtest        ;036c    cd  07  04 ; test 1000-2FFF
      pop      hl             ;036f    e1
      bit      3,(hl)         ;0370    cb  5e
      set      5,h            ;0372    cb  ec     ; H = 30
      call     z,romtest      ;0374    cc  07  04 ; test 3000-4FFF
      ld       hl,01005h      ;0377    21  05  10 ; To rom
      ld       de,05002h      ;037a    11  02  50 ; To screen
      ld       bc,l0008h      ;037d    01  08  00 ; 8 letters
      ldir    				  ;0380    ed  b0
      jp       01010h         ;0382    c3  10  10 ; start module

; bootstrap wordt uitgevoerd als er geen
; ROM insteek module met de juiste
; kenmerken wordt gevonden. Begint met
; PHILIPS microcomputer P2000 op
; het scherm te zetten.
bootstrap:
      call     prn_text       ;0385    cd  2e  04
boo1:
      ld       b,000h         ;0388    06  00
      ld       e,003h         ;038a    1e  03
      call     scrn_type      ;038c    cd  be  01

; wait until a tape is available.
boo2:
      ld       a,007h         ;038f    3e  07       ; status
      call     cassette       ;0391    cd  f1  04
      jr       z,boo2         ;0394    28  f9       ; no tape available
      ld       a,001h         ;0396    3e  01       ; rewind
      call     cassette       ;0398    cd  f1  04
      jr       nz,boo1        ;039b    20  eb       ; error! try again
      ld       hl,l0400h      ;039d    21  00  04   ; header only
      ld       (filelen),hl   ;03a0    22  32  60
      ld       hl,l0000h      ;03a3    21  00  00   ; length of data
      ld       (reclen),hl    ;03a6    22  34  60
      ld       a,006h         ;03a9    3e  06       ; read header
      call     cassette       ;03ab    cd  f1  04
      jr       nz,boo1        ;03ae    20  d8       ; failed!
      ld       a,001h         ;03b0    3e  01       ; rewind
      call     cassette       ;03b2    cd  f1  04
      jr       nz,boo1        ;03b5    20  d1       ; error
      ld       a,(file_type)  ;03b7    3a  41  60
      cp       "P"            ;03ba    fe  50       ; bootstrap?
      jr       nz,boo1        ;03bc    20  ca       ; try again
      ld       hl,(reclen)    ;03be    2a  34  60
      ld       (filelen),hl   ;03c1    22  32  60
      ld       hl,(06045h)    ;03c4    2a  45  60
      ld       (transfer),hl  ;03c7    22  30  60
      ld       a,006h         ;03ca    3e  06       ; read
      call     cassette       ;03cc    cd  f1  04
      jr       nz,boo1        ;03cf    20  b7       ; error!
      ld       b,000h         ;03d1    06  00       ; clear C from
      ld       e,003h         ;03d3    1e  03       ; screen
      call     scrn_type      ;03d5    cd  be  01
      ld       hl,(strt_boot) ;03d8    2a  43  60   ; launch loaded
      jp       (hl)           ;03db    e9           ; program

ram_test:
     ; HL: Starting address
	 ; B: number of bytes
	 ; C  = FF:  test whole byte
	 ;      0F:  test half byte
	 ; exit: A = 0, ok
     ;         = 1, no ram.
	 ;         = 2  error at (HL)
      push     hl             ;03dc    e5
      pop      ix             ;03dd    dd  e1
      ld       d,c            ;03df    51
      ld       c,000h         ;03e0    0e  00
      dec      hl             ;03e2    2b
ram1:
      inc      hl             ;03e3    23
      ld       (hl),000h      ;03e4    36  00
      ld       a,(hl)         ;03e6    7e
      and      d              ;03e7    a2  ; Test mask is now in D, if one bit != 0, error will be called.
      jr       nz,ram2        ;03e8    20  08
      dec      bc             ;03ea    0b
      or       b              ;03eb    b0
      jr       nz,ram1        ;03ec    20  f5
      or       c              ;03ee    b1
      jr       nz,ram1        ;03ef    20  f2
      ret                     ;03f1    c9
ram2:
      push     ix             ;03f2    dd  e5
      pop      bc             ;03f4    c1
      xor      a              ;03f5    af
      inc      a              ;03f6    3c
      sbc      hl,bc          ;03f7    ed  42
      jr       nz,ram3        ;03f9    20  01
      ret                     ;03fb    c9
ram3:
      inc      a              ;03fc    3c
      ret                     ;03fd    c9

; test op een byte met 55
; 		  	 Z: alles in orde
; 			NZ: fout
test_55:
      ld       (hl),055h      ;03fe    36  55
l0400h:
      ld       a,(hl)         ;0400    7e
      cp       055h           ;0401    fe  55
      ret      nz             ;0403    c0
      xor      a              ;0404    af
      ld       (hl),a         ;0405    77
      ret                     ;0406    c9

romtest:
      inc      hl             ;0407    23
      ld       c,(hl)         ;0408    4e
      inc      hl             ;0409    23
      ld       b,(hl)         ;040a    46
      inc      hl             ;040b    23
      ld       e,(hl)         ;040c    5e
      inc      hl             ;040d    23
      ld       d,(hl)         ;040e    56
romtes1:
      ld       a,b            ;040f    78
      or       c              ;0410    b1
      jr       nz,romtes2     ;0411    20  06
      ld       a,d            ;0413    7a
      or       e              ;0414    b3
      ret      z              ;0415    c8
; BC op 0000 en DE niet op 0000
; betekent tape laden!
      jp       bootstrap      ;0416    c3  85  03
romtes2:
      inc      hl             ;0419    23
      ld       a,(hl)         ;041a    7e
      add      a,e            ;041b    83
      jr       nc,romtes3     ;041c    30  01  0
      inc      d              ;041e    14
romtes3:
      ld       e,a            ;041f    5f
      dec      bc             ;0420    0b
      jr       romtes1        ;0421    18  ec

;veeg een stuk scherm schoon
; HL: start adres
; A: aantal regels
wisregel:
      ld       b,050h         ;0423    06  50
wisreg1:
      ld       (hl),000h      ;0425    36  00  6
      inc      hl             ;0427    23
      djnz     wisreg1        ;0428    10  fb
      dec      a              ;042a    3d
      jr       nz,wisregel    ;042b    20  f6
      ret                     ;042d    c9

; zet meerdere strings op scherm
; format: twee bytes schermadres
; 		  een byte lengtetekst als afsluiting FF,
;         anders weer string met schermadres etc.
; als er een M-model aanwezig is, wordt
; er 0014 bij schermadres opgeteld.
prn_text:
      ld       hl,l021eh      ;042e    21  1e  02   ; adress PHILIPS
prn_txt1:
      ld       e,(hl)         ;0431    5e
      inc      hl             ;0432    23
      ld       d,(hl)         ;0433    56
      inc      hl             ;0434    23
      ld       b,000h         ;0435    06  00
      ld       c,(hl)         ;0437    4e
      inc      hl             ;0438    23
      ld       a,(T_M)        ;0439    3a  13  60
      bit      0,a            ;043c    cb  47
      jr       z,prn_txt2     ;043e    28  07
      push     hl             ;0440    e5
      ld       hl,l0014h      ;0441    21  14  00
      add      hl,de          ;0444    19
      ex       de,hl          ;0445    eb
      pop      hl             ;0446    e1
prn_txt2:
      ldir                    ;0447    ed  b0
      ld       a,(hl)         ;0449    7e
      cp       0ffh           ;044a    fe  ff
      jr       nz,prn_txt1    ;044c    20  e3
      ret                     ;044e    c9

; cpm dos zit in bank een vanaf EOOO
CPM_start:
      ld       (06055h),sp    ;044f    ed  73  55
      ld       sp,06130h      ;0453    31  30  61
      ld       a,001h         ;0456    3e  01
      out      (094h),a       ;0458    d3  94
      call     0e000h         ;045a    cd  00  e0
      push     af             ;045d    f5
      xor      a              ;045e    af
      out      (094h),a       ;045f    d3  94
      pop      af             ;0461    f1
      ld       sp,(06055h)    ;0462    ed  7b  55
      ret                     ;0466    c9

; routine schakelt naar bank 0 om
; data te lezen vanaf disk en gaat dan
; weer terug naar bank 1: terugkomen
; in DOS system. HL bestemming, B aantal
; bytes te lezen. C: poort FDC
inpdisk:
      xor      a              ;0467    af
      out      (094h),a       ;0468    d3  94
l046ah:
      in       a,(090h)       ;046a    db  90
      rra                     ;046c    1f
      jp       nc,l046ah      ;046d    d2  6a  04
      ini                     ;0470    ed  a2
      jp       nz,l046ah      ;0472    c2  6a  04
l0475h:
      ld       a,001h         ;0475    3e  01
      out      (094h),a       ;0477    d3  94
      ret                     ;0479    c9
      xor      a              ;047a    af
      out      (094h),a       ;047b    d3  94
l047dh:
      in       a,(090h)       ;047d    db  90
      rra                     ;047f    1f
      jr       nc,l047dh      ;0480    30  fb  0
      outi                    ;0482    ed  a3
      jp       nz,l047dh      ;0484    c2  7d  04
      jr       l0475h         ;0487    18  ec
l0489h:
      ld       a,(keycnt)     ;0489    3a  0c  60
      or       a              ;048c    b7
      ret      z              ;048d    c8
      ld       a,(keybuf)     ;048e    3a  00  60
      cp       058h           ;0491    fe  58
      jr       nz,l0498h      ;0493    20  03
      sub      059h           ;0495    d6  59
      ret                     ;0497    c9
l0498h:
      scf                     ;0498    37
      ccf                     ;0499    3f
      ret                     ;049a    c9

; wacht tot er een toets in de input
; buffer zit en haal hem eruit. Hij
; wordt er door de interrupt ingezet.
readkey:
      call     l0489h         ;049b    cd  89  04
      jr       z,readkey      ;049e    28  fb
      di                      ;04a0    f3
      exx                     ;04a1    d9
      ld       hl,keycnt      ;04a2    21  0c  60
      ld       a,(hl)         ;04a5    7e
      or       a              ;04a6    b7
      jr       z,readkey      ;04a7    28  f2
      dec      (hl)           ;04a9    35  5
      ld       a,(keycnt)     ;04aa    3a  0c  60
      or       a              ;04ad    b7          ; empty?
      jr       nz,shiftbuf    ;04ae    20  0a
      ld       a,(keybuf)     ;04b0    3a  00  60
      ld       hl,keybuf      ;04b3    21  00  60
      ld       (hl),000h      ;04b6    36  00       ; clean out buffer
      jr       readke1        ;04b8    18  19
shiftbuf:
      ld       b,000h         ;04ba    06  00
      ld       c,a            ;04bc    4f
      ld       hl,06001h      ;04bd    21  01  60
      ld       de,keybuf      ;04c0    11  00  60
      ld       a,(keybuf)     ;04c3    3a  00  60   ; retrieve the ky
      ldir                    ;04c6    ed  b0       ; shift
      ld       hl,keybuf      ;04c8    21  00  60
      push     af             ;04cb    f5
      ld       a,(keycnt)     ;04cc    3a  0c  60
      ld       l,a            ;04cf    6f
      ld       (hl),000h      ;04d0    36  00       ; clean out buffer
      pop      af             ;04d2    f1
readke1:
      exx                     ;04d3    d9
      cp       058h           ;04d4    fe  58       ; stop ?
      scf                     ;04d6    37
      jr       z,readke2      ;04d7    28  01
      ccf                     ;04d9    3f           ; stop in carry
readke2:
      ei                      ;04da    fb
      ret                     ;04db    c9


clearkey:
      xor      a              ;04dc    af
      ld       (keycnt),a     ;04dd    32  0c  60
      ret                     ;04e0    c9


; betekenis inhoud caserror ,
; 00 operatie normaal beeindigd
; 41 geen cassette
; 42 begin van tape
; 43 checksom fout, record gelezen
; 44 checksom fout in startmerk
; 45 einde van de band
; 46 band vol bij schrijven EOF
; 47 geen stopje
; 49 rewind tijd verlopen
; 4a kort record) geen checksom fout
; 4b verkeerde functie keuze
; 4c kort record + checksom fout
; 4d geen startmerk gevonden
; 4e geen record gevonden


; jumptabel voor diverse cassette
; opdrachten. entry point bij cassette functie in a
cas_jmp_tbl:  defw  0605h, 0bb4h, 0c0fh, 0c61h, 0be4h, 057ah, 0552h, 0515h

                              ; 04e1  05 06 ; 0 init pointers
                              ; 04e3  b4 0b ; 1 tape rewind
                              ; 04e5  0f 0c ; 2 skip a block
                              ; 04e7  61 0c ; 3 skip block back?
                              ; 04e9  e4 0b ; 4 last file
                              ; 04eb  7a 05 ; 5 write file
                              ; 04ed  52 05 ; 6 read file
                              ; 04ef  15 05 ; 7 status

cassette:
      call     opberg         ;04f1    cd  fc  05
      cp       008h           ;04f4    fe  08
      jr       c,cas1         ;04f6    38  04      ; Wrong arg in a
      ld       a,'K'          ;04f8    3e  4b      ; Error K
      jr       cassette_exit  ;04fa    18  51
cas1:
      ld       hl,transfer    ;04fc    21  30  60
      ld       (desl),hl      ;04ff    22  68  60
      ld       hl,00020h      ;0502    21  20  00  ; header of 32 bytes
      ld       (hdrlen),hl    ;0505    22  6a  60
      ld       hl,cas_jmp_tbl ;0508    21  e1  04  ; Lookup in jumptable
      sla      a              ;050b    cb  27
      ld       d,000h         ;050d    16  00
      ld       e,a            ;050f    5f
      add      hl,de          ;0510    19
      cp       00eh           ;0511    fe  0e      ; Check status
      jr       nz,cas2        ;0513    20  0d

; tapestatus: Z = no tape         (!CIP)
;             C = write protected (WEN)
read_cassette_status:
      in       a,(cas_inp)    ;0515    db  20
      rra                     ;0517    1f
      rra                     ;0518    1f
      rra                     ;0519    1f
      rra                     ;051a    1f           ; >> 4 (bit 3 is in C)
      cpl                     ;051b    2f           ; Flip all the bits.
      bit      0,a            ;051c    cb  47       ; WEN is in bit 0
      call     restore_reg    ;051e    cd  00  06
      ret                     ;0521    c9
cas2:
      ld       de,casret      ;0522    11  42  05
      push     de             ;0525    d5
      ld       a,(recnum)     ;0526    3a  4f  60
      ld       (telblok),a    ;0529    32  6e  60
      xor      a              ;052c    af
      ld       (caserror),a   ;052d    32  17  60
      call     no_kbd         ;0530    cd  bc  00
      push     hl             ;0533    e5
      ld       b,054h         ;0534    06  54
      ld       e,003h         ;0536    1e  03
      call     scrn_type      ;0538    cd  be  01
      pop      hl             ;053b    e1
      ld       e,(hl)         ;053c    5e
      inc      hl             ;053d    23
      ld       d,(hl)         ;053e    56
      ex       de,hl          ;053f    eb
      di                      ;0540    f3
      jp       (hl)           ;0541    e9

; nette beeindiging van cassette
; routines. adres van deze routine wordt
; door cas2 op stack gezet.
casret:
      ei                      ;0542    fb   			   	; return address
      xor      a              ;0543    af                    ; flags' cass
      ld       (motorstat),a  ;0544    32  50  60
      call     enkey          ;0547    cd  b4  00
      ld       a,(caserror)   ;054a    3a  17  60
cassette_exit:
      or       a              ;054d    b7                         ; fout in 0
      call     restore_reg    ;054e    cd  00  06
      ret                     ;0551    c9


lees:
      call     blocknr        ;0552    cd  a9  05   ; no i/o
lees1:
      call     nextparam      ;0555    cd  c6  05   ; no i/o
      ld       a,(telblok)    ;0558    3a  6e  60
      ld       hl,motorstat   ;055b    21  50  60
      cp       001h           ;055e    fe  01

; na laatste blok moet de motor uitgezet worden, anders niet.
      jr       nz,lees2       ;0560    20  04
      res      2,(hl)         ;0562    cb  96     ; na blok motor uitzetten
      jr       lees3          ;0564    18  02
lees2:
      set      2,(hl)         ;0566    cb  d6      ; na blok motor aanzetten
lees3:
      call     blkread        ;0568    cd  72  08  ;
      ld       a,(caserror)   ;056b    3a  17  60
      or       a              ;056e    b7          ; check for error
      ret      nz             ;056f    c0
      ld       a,(telblok)    ;0570    3a  6e  60 ; next block
      dec      a              ;0573    3d         ; should be read
      ld       (telblok),a    ;0574    32  6e  60
      jr       nz,lees1       ;0577    20  dc     ; done?
      ret                     ;0579    c9
schrijf:
      call     blocknr        ;057a    cd  a9  05  ; aantal blokken
schrijf1:
      call     nextparam      ;057d    cd  c6  05
      ld       a,(telblok)    ;0580    3a  6e  60
      ld       hl,motorstat   ;0583    21  50  60
      cp       001h           ;0586    fe  01      ; laatste blok?
      jr       nz,schrijf2    ;0588    20  06

; last block, turn of the motor, and stop writing
      res      2,(hl)         ;058a    cb  96
      res      3,(hl)         ;058c    cb  9e
      jr       schrijf3       ;058e    18  04
schrijf2:
      set      2,(hl)         ;0590    cb  d6
      set      3,(hl)         ;0592    cb  de
schrijf3:
      ld       (recnum),a     ;0594    32  4f  60
      call     sub_061fh      ;0597    cd  1f  06
      ld       a,(caserror)   ;059a    3a  17  60
      or       a              ;059d    b7
      ret      nz             ;059e    c0
      ld       a,(telblok)    ;059f    3a  6e  60
      dec      a              ;05a2    3d
      ld       (telblok),a    ;05a3    32  6e  60
      jr       nz,schrijf1    ;05a6    20  d5
      ret                     ;05a8    c9
blocknr:
      ld       hl,(filelen)   ;05a9    2a  32  60
      ld       de,l0400h      ;05ac    11  00  04  ; 1kb
      dec      hl             ;05af    2b
      xor      a              ;05b0    af
blockl:
      inc      a              ;05b1    3c          ; count  of blocks
      sbc      hl,de          ;05b2    ed  52      ; done?
      jr       nc,blockl      ;05b4    30  fb
      ld       (telblok),a    ;05b6    32  6e  60  ; we have a blocks left
      ld       hl,(transfer)  ;05b9    2a  30  60
      ld       (newblock),hl  ;05bc    22  18  60
      ld       hl,(reclen)    ;05bf    2a  34  60
      ld       (length),hl    ;05c2    22  1a  60
      ret                     ;05c5    c9
nextparam:
      ld       de,l0400h      ;05c6    11  00  04  ; 1 kb
      ld       hl,(newblock)  ;05c9    2a  18  60
      ld       (oldblk),hl    ;05cc    22  64  60
      add      hl,de          ;05cf    19
      ld       (newblock),hl  ;05d0    22  18  60
      xor      a              ;05d3    af
      ld       hl,(length)    ;05d4    2a  1a  60
      sbc      hl,de          ;05d7    ed  52
      jr       c,l05e4h       ;05d9    38  09
      ld       (validlen),de  ;05db    ed  53  66
      ld       (length),hl    ;05df    22  1a  60
      jr       l05f0h         ;05e2    18  0c
l05e4h:
      ld       hl,(length)    ;05e4    2a  1a  60
      ld       (validlen),hl  ;05e7    22  66  60
      ld       hl,l0000h      ;05ea    21  00  00
      ld       (length),hl    ;05ed    22  1a  60
l05f0h:
      ex       de,hl          ;05f0    eb
      ld       de,(validlen)  ;05f1    ed  5b  66
      xor      a              ;05f5    af
      sbc      hl,de          ;05f6    ed  52
      ld       (endblk),hl    ;05f8    22  6c  60
      ret                     ;05fb    c9
opberg:
      ex       (sp),hl        ;05fc    e3
      push     de             ;05fd    d5
      push     bc             ;05fe    c5
      jp       (hl)           ;05ff    e9
restore_reg:
      pop      hl             ;0600    e1
      pop      bc             ;0601    c1
      pop      de             ;0602    d1
      ex       (sp),hl        ;0603    e3
      ret                     ;0604    c9
cas_init:
      xor      a              ;0605    af
      ld       (stacas),a     ;0606    32  60  60      ; clear out stacas motor
      ld       (motorstat),a  ;0609    32  50  60
      in       a,(cas_inp)    ;060c    db  20
      and      018h           ;060e    e6  18         ; mask out cip wen
      cp       010h           ;0610    fe  10         ; check if cip
      ret      nz             ;0612    c0             ; return if
      ld       hl,stacas      ;0613    21  60  60
      set      2,(hl)         ;0616    cb  d6         ; set bit 2 in stacas zend cassette-ERROR-code naar de printer
      ld       e,040h         ;0618    1e  40         ; e =
      ld       h,031h         ;061a    26  31
      jp       l0b54h         ;061c    c3  54  0b
sub_061fh:
      call     castest        ;061f    cd  83  0b
      ret      nz             ;0622    c0
      ld       a,(stacas)     ;0623    3a  60  60
      bit      0,a            ;0626    cb  47    ; bit 0 startmerk?
      jr       z,l0635h       ;0628    28  0b    ; if (startmerk) l0635h
      bit      1,a            ;062a    cb  4f    ;
      jr       z,l0666h       ;062c    28  38    ; if (schrijven) l0666h
      res      1,a            ;062e    cb  8f    ; schrijven = true
      ld       (stacas),a     ;0630    32  60  60
      jr       l0681h         ;0633    18  4c
l0635h:
      call     sub_06c5h      ;0635    cd  c5  06
      ld       a,(caserror)   ;0638    3a  17  60
      cp       04dh           ;063b    fe  4d  ; bit 2 cas error to priner?
      jr       z,l0661h       ;063d    28  22  ; yes, goto 0661h
      cp       000h           ;063f    fe  00
      ret      nz             ;0641    c0
      ld       e,04ah         ;0642    1e  4a
      ld       h,060h         ;0644    26  60
      call     wait_157msec      ;0646    cd  b0  0a
      ret      nz             ;0649    c0
      ld       a,(motorstat)  ;064a    3a  50  60
      bit      2,a            ;064d    cb  57
      ld       h,060h         ;064f    26  60
      jr       z,retOffMotor  ;0651    28  05
      ld       a,048h         ;0653    3e  48
      out      (cas_kbd),a    ;0655    d3  10
      ret                     ;0657    c9

retOffMotor:
    ;; Turns of the tape motor and enable keyboard.
      ld       a,040h         ;0658    3e  40
      out      (cas_kbd),a    ;065a    d3  10
      ld       e,a            ;065c    5f
      call     sub_0ad5h      ;065d    cd  d5  0a
      ret                     ;0660    c9


l0661h:
      ld       hl,stacas      ;0661    21  60  60
      set      0,(hl)         ;0664    cb  c6
l0666h:
      call     sub_0c5dh      ;0666    cd  5d  0c
      ld       a,(caserror)   ;0669    3a  17  60
      cp       042h           ;066c    fe  42
      jr       z,l0681h       ;066e    28  11
      cp       000h           ;0670    fe  00
      ret      nz             ;0672    c0
      ld       hl,stacas      ;0673    21  60  60
      set      5,(hl)         ;0676    cb  ee
      call     sub_0c13h      ;0678    cd  13  0c
      ld       a,(caserror)   ;067b    3a  17  60
      cp       000h           ;067e    fe  00
      ret      nz             ;0680    c0
l0681h:
      call     write_tape      ;0681    cd  f0  06
      ld       e,04ah         ;0684    1e  4a
      ld       h,061h         ;0686    26  61
      call     wait_157msec      ;0688    cd  b0  0a
      ld       a,(caserror)   ;068b    3a  17  60
      cp       000h           ;068e    fe  00
      ret      nz             ;0690    c0
      ld       a,(motorstat)  ;0691    3a  50  60
      bit      3,a            ;0694    cb  5f
      jr       nz,l06a7h      ;0696    20  0f
      call     EOT            ;0698    cd  e4  0b
      ld       a,(caserror)   ;069b    3a  17  60
      cp       045h           ;069e    fe  45
      ret      nz             ;06a0    c0
      ld       a,046h         ;06a1    3e  46
      ld       (caserror),a   ;06a3    32  17  60
      ret                     ;06a6    c9
l06a7h:
      res      3,a            ;06a7    cb  9f
      ld       (motorstat),a  ;06a9    32  50  60
      ld       a,(stacas)     ;06ac    3a  60  60
      set      1,a            ;06af    cb  cf
      ld       (stacas),a     ;06b1    32  60  60
      ld       a,(motorstat)  ;06b4    3a  50  60
      bit      2,a            ;06b7    cb  57
      ret      nz             ;06b9    c0
      ld       a,042h         ;06ba    3e  42
      out      (cas_kbd),a    ;06bc    d3  10
      call     wait10ms       ;06be    cd  d0  0a
      ld       h,061h         ;06c1    26  61
      jr       retOffMotor    ;06c3    18  93
sub_06c5h:
      call     video_off      ;06c5    cd  91  0b
      call     readmark       ;06c8    cd  c2  08
      ld       a,(caserror)   ;06cb    3a  17  60
      cp       000h           ;06ce    fe  00
      jr       z,l06d6h       ;06d0    28  04
l06d2h:
      call     video_on       ;06d2    cd  96  0b
      ret                     ;06d5    c9
l06d6h:
      ld       a,04ah         ;06d6    3e  4a
      out      (cas_kbd),a    ;06d8    d3  10
      call     write_gap      ;06da    cd  b6  0a
      jr       nz,l06d2h      ;06dd    20  f3
      call     write_blk      ;06df    cd  35  07
      call     video_on       ;06e2    cd  96  0b
      ld       a,(caserror)   ;06e5    3a  17  60
      cp       000h           ;06e8    fe  00
      ret      z              ;06ea    c8
      ld       h,060h         ;06eb    26  60
      jp       retOffMotor    ;06ed    c3  58  06

write_tape:
      ld       a,04ah         ;06f0    3e  4a
      out      (cas_kbd),a    ;06f2    d3  10
      ld       a,(stacas)     ;06f4    3a  60  60
      bit      4,a            ;06f7    cb  67
      jr       z,write_block_start       ;06f9    28  05
      call     sub_0ae9h      ;06fb    cd  e9  0a ; Beginning of tape gap..
      jr       l0703h         ;06fe    18  03
write_block_start:
      call     wait_516msec      ;0700    cd  bb  0a  ; Start of block gap.
l0703h:
      ret      nz             ;0703    c0
      call     video_off      ;0704    cd  91  0b
      ld       (spsave),sp    ;0707    ed  73  61
      push     hl             ;070b    e5
      push     hl             ;070c    e5
      call     sub_072ah      ;070d    cd  2a  07
      call     write_last_bit ;0710    cd  4e  08
      jr       nz,l0723h      ;0713    20  0e        ; check err.
      call     write_gap      ;0715    cd  b6  0a    ; Mark gap..
      jr       nz,l0723h      ;0718    20  09
      call     write_blk      ;071a    cd  35  07
      jr       nz,l0723h      ;071d    20  04
l071fh:
      call     video_on       ;071f    cd  96  0b
      ret                     ;0722    c9
l0723h:
      ld       h,061h         ;0723    26  61
      call     retOffMotor    ;0725    cd  58  06
      jr       l071fh         ;0728    18  f5

sub_072ah:
      ld       hl,0x03        ;072a    21  03  00
      push     hl             ;072d    e5            [ 3 ]
      push     hl             ;072e    e5            [ 3 ]
      ld       hl,get_checksum      ;072f    21  13  08
      push     hl             ;0732    e5`           [ get_checksum ] <-- what does this do?
      jr       start_writing         ;0733    18  40


write_blk:
;; This function is responsible for writing a block to tape.
;; Blocks are written using a manchester like encoding, that is
;; A clock cycle will consist of two pulses i.e.:
;;
;; Signals are converted into bits whenever the line signal
;; changes from low to high and vice versa on a clock signal.
;;
;; A transition on a clock boundary from low to high is a 1.
;; A transition on a clock boundary from high to low is a 0
;; An intermediate transition halfway between the clock boundary
;; can occur when there are consecutive 0s or 1s. See the example
;; below where the clock is marked by a |
;;
;;
;;          1    0    1    1    0    0
;;   RDA:  _|----|____|--__|----|__--|__--
;;   RDC:  _|-___|-___|-___|-___|-___|-___
;;          ^                      ^
;;          |-- clock signal       |-- intermediate transition.
;;
;; The signal is written by sending a signal to WDA & WDA.  Indicating
;; if the tape should output a high or low value.
;;
;; This signal can be written by a simple algorithm where the first bit
;; is always false (transition to low, half clock).  Now only one bit is needed
;; to determine what the next partial clock should look like.
;;
;;
;; This works because we are always guaranteed that a block starts with 0xAA, and
;; hence will ALWAYS find a signal like this on tape: _-- (low, high, high) after
;; a gap. This is guaranteed when the tape is moving forward as well as backwards.
;; Writing a byte is roughly:
;;
;; write_signal(LOW_SIGNAL);
;; uint8_t byte = get_next_byte();
;; for(int i = 0; i < 7; i++) {
;;   auto bit = (byte >> i) & 0x1;
;; 	 write_signal(bit ? LOW_SIGNAL  : HIGH_SIGNAL);  // Note signal swapping!
;; 	 write_signal(bit ? HIGH_SIGNAL : LOW_SIGNAL);
;;   if (chksum_needed) update_chksum(bit);
;; }
;;
;; The code is clock-cycle perfect to make sure that every 82.3us a bit gets written
;; to tape. (The MDCR expects a clock cycle to be 167us). Due to this you will find
;; a series of timing related dummy/jmp instructions.
;;
;; When this function is called it will build up a stack that contains the following:
;;
;;  | # of bytes to write |  --> Byte Counter with number times to call byte fetch fn
;;  | start address       |  --> Starting address to fetch data from
;;  | byte fetch function |  --> Function responsible for loading byte in A
;;
;;  The stack is used to determine how bytes are written to tape. First the byte
;;  0xAA is written to tape, after which the next active function is popped from
;;  the stack.
;;
;; The function will keep writing bytes until either all bytes have been written,
;; or a cassette error arose
;;
;; A checksum will be calculated if C=0 (no carry), the checksum is stored in DE
;;
;; Note: If you call this with [hdrlen] = 0, it can be used to write the starting gap marker
;; (0xAA, 00, 00, 0xAA)
;; Note: There is a lot of usage of shadow registers to make things confusing.
setup_function_stacks:
      ld       (spsave),sp    ;0735    ed  73  61     ; store quick exit
      push     hl             ;0739    e5             ; Add function that writes the last bit and exits.
      push     hl             ;073a    e5             ; [unused]
      ld       hl,write_last_bit;073b    21  4e  08   ; [unused]
      push     hl             ;073e    e5             ; [write_last_bit] <-- closing 0 bit
      ld       hl,0x03        ;073f    21  03  00
      push     hl             ;0742    e5             ; Write out the checksum and closing 0xAA marker
      push     hl             ;0743    e5             ; [ 3            ] <-- checksum (2 byts) + 0xAA
      ld       hl,get_checksum;0744    21  13  08     ; [ unused       ]
      push     hl             ;0747    e5             ; [ get_checksum ]
      ld       hl,(endblk)    ;0748    2a  6c  60     ; Do we need to write 0 bytes?
      ld       a,l            ;074b    7d
      or       h              ;074c    b4
      jr       z,skip_filler  ;074d    28  06         ;  Fill up the remainder with 0s (with checksum)
      push     hl             ;074f    e5             ; [ endblk       ] <-- # of 0s needed to write
      push     hl             ;0750    e5             ; [ unused       ]
      ld       hl,get_0_filler;0751    21  07  08     ; [ get_0_filler ]
      push     hl             ;0754    e5
skip_filler:
      ld       hl,(validlen)  ;0755    2a  66  60     ; Do we have any data bytes to write?
      ld       a,l            ;0758    7d
      or       h              ;0759    b4
      jr       z,skip_data    ;075a    28  09
      push     hl             ;075c    e5             ; Write the actual data bytes
      ld       hl,(oldblk)    ;075d    2a  64  60 	  ; [ validlen     ]  <-- # of bytes
      push     hl             ;0760    e5    		  ; [ oldblock     ]  <-- Location of data
      ld       hl,get_byte_wrt;0761    21  fc  07     ; [ get_byte_wrt ]
      push     hl             ;0764    e5
skip_data:
      ld       hl,(hdrlen)    ;0765    2a  6a  60
      ld       a,l            ;0768    7d
      or       h              ;0769    b4
      jr       z,start_writing;076a    28  09         ; Do we have a header?
      push     hl             ;076c    e5
      ld       hl,(desl)      ;076d    2a  68  60     ; [ hdrlen       ]  <-- 32 byte tape header
      push     hl             ;0770    e5             ; [ desl         ]  <-- header in memory
      ld       hl,get_byte_wrt;0771    21  fc  07     ; [ get_byte_wrt ]
      push     hl             ;0774    e5
;; The stack with how we are going to write bytes has now been setup.

start_writing:
;; This sets us up for writing the first marker 0xAA byte, disables and resets checksum calculation.
      ld       iy,write_bit   ;0775    fd  21  95
      ld       c,000h         ;0779    0e  00
      sub      a              ;077b    97            ; A=0
      scf                     ;077c    37            ; C=1 (disable checksums)
      ld       b,008h         ;077d    06  08        ; (8 bits)
      ld       a,0aah         ;077f    3e  aa        ; (write 0xAA marker)
      exx                     ;0781    d9
      ld       de,l0000h      ;0782    11  00  00    ; reset checksum

write_byte:
      exx                     ;0785    d9            ; B has nr of bits, A what to write.
      ld       d,a            ;0786    57            ; d = byte to write? DE2 = checksum
      ex       af,af'         ;0787    08
      in       a,(cas_inp)    ;0788    db  20        ; read cassette state
      and      030h           ;078a    e6  30        ; bit 4 + 5. CIP/BET
      cp       020h           ;078c    fe  20        ; check if we only have start/end of tape.
      jp       nz,fast_exit   ;078e    c2  3a  08    ; BET -> !CIP?
      ld       a,000h         ;0791    3e  00
      rr       a              ;0793    cb  1f
write_bit:
      ld       a,d            ;0795    7a           ; a = byte to write
      nop                     ;0796    00           ;
      and      001h           ;0797    e6  01       ; a will now b0
      or       04ah           ;0799    f6  4a       ; set ready for writing
      ex       (sp),hl        ;079b    e3           ; dummy
      ex       (sp),hl        ;079c    e3     	    ; dummy
      nop                     ;079d    00           ; dummy
      out      (cas_kbd),a    ;079e    d3  10       ; write bit to tape
      ex       (sp),hl        ;07a0    e3           ; dummy
      ex       (sp),hl        ;07a1    e3           ; dummy
      nop                     ;07a2    00           ; dummy
      jr       l07a5h         ;07a3    18  00       ; a dummy timing jump.
l07a5h:
      nop                     ;07a5    00
      ex       af,af'         ;07a6    08           ; A = byte to write?
      jr       c,no_chksum    ;07a7    38  2f       ; jump if no checksum
      ex       af,af'         ;07a9    08
      ld       a,d            ;07aa    7a
      exx                     ;07ab    d9
calc_chksum:
     ;; This calculates the cheksum
      and      001h           ;07ac    e6  01   ; DE with checksum is active
      xor      e              ;07ae    ab       ; a = written bit.
      ld       e,a            ;07af    5f       ; e = e ^ (bit written)
      and      001h           ;07b0    e6  01
      jr       z,l07d3h       ;07b2    28  1f   ; through a complex web it will jump to chksum (this is to keep the right timing.)
      ld       a,002h         ;07b4    3e  02
      xor      e              ;07b6    ab
      ld       e,a            ;07b7    5f       ; e = e ^ 0x02
      ld       a,040h         ;07b8    3e  40
chksum:
      xor      d              ;07ba    aa       ; a = d ^ (0x40 | 0x0)
      rra                     ;07bb    1f       ; >> 1
      rr       e              ;07bc    cb  1b   ; >> rotate through DE (i.e. e0 -> d7 etc..)
      jr       c,l07c2h       ;07be    38  02
      jr       l07c4h         ;07c0    18  02
l07c2h:
      or       080h           ;07c2    f6  80  ;
l07c4h:
      ld       d,a            ;07c4    57
      exx                     ;07c5    d9
write_inv_bit:
      ; This writes the inverted bit to the one that was written
	  ; a little earlier or on.
      xor      a              ;07c6    af     ; A = 0
      rr       d              ;07c7    cb  1a ; bit 7 goes to carry
      ccf                     ;07c9    3f     ; and gets inverted.
      adc      a,04ah         ;07ca    ce  4a ; and now ends up in bit 0 of A
      out      (cas_kbd),a    ;07cc    d3  10 ; FWD | WCD | KBD and gets written to tape
      djnz     write_nxt_bit  ;07ce    10  13 ;
      ld       b,008h         ;07d0    06  08 ; We have written a byte, time to fetch
      jp       (hl)           ;07d2    e9     ; the next byte and continue.
l07d3h:
      jr       nz,chksum      ;07d3    20  e5
      jp       chksum         ;07d5    c3  ba  07
no_chksum:
      ex       af,af'         ;07d8    08
      ld       a,(ix+000h)    ;07d9    dd  7e  00  ; dummy
      ld       a,004h         ;07dc    3e  04      ; setup a little timed loop
l07deh:
      dec      a              ;07de    3d
      jr       nz,l07deh      ;07df    20  fd      ; a simple wait thing..
      jr       write_inv_bit       ;07e1    18  e3      ; write next bit
write_nxt_bit:
      ex       af,af'         ;07e3    08
      jp       pe,cnt_writing ;07e4    ea  1f  08 ; continue if BC!=0
      ld       a,080h         ;07e7    3e  80     ; prepare the next byte fetch function
      dec      a              ;07e9    3d
      ex       af,af'         ;07ea    08
      pop      hl             ;07eb    e1  ; hl now has the next jump funciton
      exx                     ;07ec    d9  ; swap to shadow regs.
      ld       a,02dh         ;07ed    3e  2d
      ld       c,l            ;07ef    4d  ; dummy
      ld       b,l            ;07f0    45  ; dummy
      ld       c,b            ;07f1    48  ; dummy
      ld       c,a            ;07f2    4f  ; dummy
      ld       b,(hl)         ;07f3    46  ; dummy
      ld       b,l            ;07f4    45  ; dummy
      ld       d,d            ;07f5    52  ; dummy
      dec      l              ;07f6    2d
      pop      hl             ;07f7    e1  ; Next address
      pop      bc             ;07f8    c1  ; Next byte counter
      exx                     ;07f9    d9
      jr       write_bit      ;07fa    18  99

get_byte_wrt:
; Gets the next byte and sets the checksum flag.
      ex       af,af'         ;07fc    08
      exx                     ;07fd    d9
      rr       a              ;07fe    cb  1f      ; Dummy?
      or       a              ;0800    b7          Reset Carry, calculate checksum.
      ld       a,(hl)         ;0801    7e          A = (HL)
      cpi                     ;0802    ed  a1;     A – (HL), HL = HL +1, BC = BC – 1;
      jp       write_byte     ;0804    c3  85  07  Note Z=0, S=0, N=1

get_0_filler:
; Gets a 0 filler byte and sets the checksum flag.
      ex       af,af'         ;0807    08
      exx                     ;0808    d9
      rr       a              ;0809    cb  1f
      or       a              ;080b    b7           Reset Carry, calculate checksum.
      ld       a,000h         ;080c    3e  00       A = 0 (write 0)
      cpi                     ;080e    ed  a1       A – (HL), HL = HL +1, BC = BC – 1; Z=1?
      jp       write_byte     ;0810    c3  85  07

get_checksum:
; Gets the checksum and end marker
      ex       af,af'         ;0813    08
      exx                     ;0814    d9       ; DE has checksum
      ld       a,e            ;0815    7b       ; this shifts checksum + AA through DE,
      ld       e,d            ;0816    5a       ; resulting in writing E, D, 0xaa
      ld       d,0aah         ;0817    16  aa
      scf                     ;0819    37       ; set carry flag (no checksum!)
      cpi                     ;081a    ed  a1     A – (HL), HL = HL +1, BC = BC – 1;
      jp       write_byte     ;081c    c3  85  07

cnt_writing:
      ex       af,af'         ;081f    08
      ret      z              ;0820    c8
      or       000h           ;0821    f6  00
      or       000h           ;0823    f6  00
      or       000h           ;0825    f6  00
      nop                     ;0827    00
      inc      c              ;0828    0c
      di                      ;0829    f3
      dec      c              ;082a    0d
      ld       iy,write_bit   ;082b    fd  21  95  ; Dummy for timing
      nop                     ;082f    00          ; Dummy for timing
      ld       iy,write_bit   ;0830    fd  21  95  ; Dummy for timing
      ld       a,(iy+000h)    ;0834    fd  7e  00  ; Dummy for timing
      jp       write_bit      ;0837    c3  95  07

fast_exit:
; Quick exit to return address.

      ld       d,a            ;083a    57
      ld       hl,(spsave)    ;083b    2a  61  60
      dec      hl             ;083e    2b
      dec      hl             ;083f    2b
      dec      hl             ;0840    2b
      dec      hl             ;0841    2b
      dec      hl             ;0842    2b
      ld       a,(hl)         ;0843    7e
      dec      hl             ;0844    2b
      ld       l,(hl)         ;0845    6e
      ld       h,a            ;0846    67
      ld       sp,(spsave)    ;0847    ed  7b  61
      ld       b,000h         ;084b    06  00
      jp       (hl)           ;084d    e9

write_last_bit:
; This writes out the last closing bit, (which will always be the reference signal)
; and exits the block writing function, updating error settings & clock
;
      ld       a,04ah         ;084e    3e  4a
      out      (cas_kbd),a    ;0850    d3  10        ; FWD | WCD | KBD (write a 0 to tape)
      ld       a,000h         ;0852    3e  00
      ld       (caserror),a   ;0854    32  17  60    ; Success!
      ld       a,b            ;0857    78
      ld       b,000h         ;0858    06  00
      ld       hl,(klok)      ;085a    2a  10  60
      add      hl,bc          ;085d    09
      ld       (klok),hl      ;085e    22  10  60    ; update the klok.
      cp       008h           ;0861    fe  08
      ret      z              ;0863    c8
      bit      4,d            ;0864    cb  62
      ld       a,'A'          ;0866    3e  41        ; geen cassette
      jr       nz,l086eh      ;0868    20  04
      sub      a              ;086a    97
      inc      a              ;086b    3c
      ld       a,045h         ;086c    3e  45
l086eh:
      ld       (caserror),a   ;086e    32  17  60
      ret                     ;0871    c9

blkread:
      call     sub_0b9ah      ;0872    cd  9a  0b
      ret      nz             ;0875    c0         ; nz means we are in write mode
      bit      0,(hl)         ;0876    cb  46     ; hl = stacas check if we have not found a start mark
      jr       z,l0880h       ;0878    28  06
      ld       a,"M"          ;087a    3e  4d      ; No starting mark found
      ld       (caserror),a   ;087c    32  17  60
      ret                     ;087f    c9
l0880h:
      call     video_off      ;0880    cd  91  0b  ; let's read the mark
      call     readmark       ;0883    cd  c2  08  ;
      ld       hl,(06051h)    ;0886    2a  51  60
      ld       (06053h),hl    ;0889    22  53  60
      ld       a,(caserror)   ;088c    3a  17  60  ; check for error
      cp       000h           ;088f    fe  00
      jr       z,blkread_ok   ;0891    28  04
      call     video_on       ;0893    cd  96  0b
      ret                     ;0896    c9
blkread_ok:
      call     sub_0adah      ;0897    cd  da  0a  ; we are looking good so far. (does not read)
      jr       nz,l08a4h      ;089a    20  08
      call     read_data_blk      ;089c    cd  1c  09  ; Reads remaining data
      ld       a,(caserror)   ;089f    3a  17  60
      cp       000h           ;08a2    fe  00
l08a4h:
      ld       h,062h         ;08a4    26  62
      jr       z,l08afh       ;08a6    28  07
      call     retOffMotor    ;08a8    cd  58  06
      call     video_on       ;08ab    cd  96  0b
      ret                     ;08ae    c9
l08afh:
      ld       e,048h         ;08af    1e  48
      call     wait_157msec   ;08b1    cd  b0  0a
      call     video_on       ;08b4    cd  96  0b
      ld       a,(motorstat)  ;08b7    3a  50  60
      bit      2,a            ;08ba    cb  57
      ret      nz             ;08bc    c0
      ld       h,062h         ;08bd    26  62
      jp       retOffMotor    ;08bf    c3  58  06
readmark:
      ld       a,048h         ;08c2    3e  48              ; enable keyboard + move cassette fwd.
      out      (cas_kbd),a    ;08c4    d3  10
      call     wait_up_o_620ms;08c6    cd  c0  0a
      ret      nz             ;08c9    c0                  ;
l08cah:
      call     read_mark      ;08ca    cd  06  09
      ld       de,(endblk)    ;08cd    ed  5b  6c
      call     sub_0a64h      ;08d1    cd  64  0a
      ld       hl,(endblk)    ;08d4    2a  6c  60
      ld       (endblk),de    ;08d7    ed  53  6c
      ld       a,(caserror)   ;08db    3a  17  60
      cp       000h           ;08de    fe  00
      jr       nz,l08e7h      ;08e0    20  05
      ld       a,h            ;08e2    7c
      or       l              ;08e3    b5
      jr       nz,l08cah      ;08e4    20  e4
      ret                     ;08e6    c9
l08e7h:
      cp       04ah           ;08e7    fe  4a
      jr       z,l08cah       ;08e9    28  df
      cp       04ch           ;08eb    fe  4c
      jr       z,l08cah       ;08ed    28  db
      cp       043h           ;08ef    fe  43  ; Check for Leesfout?
      jr       z,l08cah       ;08f1    28  d7
      cp       04eh           ;08f3    fe  4e
      jr       nz,l0901h      ;08f5    20  0a
      ld       hl,stacas      ;08f7    21  60  60
      set      0,(hl)         ;08fa    cb  c6
      ld       a,04dh         ;08fc    3e  4d
      ld       (caserror),a   ;08fe    32  17  60
l0901h:
      ld       h,063h         ;0901    26  63
      jp       retOffMotor    ;0903    c3  58  06


read_mark:
      ;; This is likely the block reading routine, which probably follows the same
	  ;; technique as the write block functions above.
	  ;; This function is only partially reverse engineered and merely contains
	  ;; suggestions about what might be happening.
      ld       (spsave),sp    ;0906    ed  73  61           ; used for quick error exit..
      ld       hl,l0000h      ;090a    21  00  00			; | 0x00 |
      push     hl             ;090d    e5					; | 0x00 |
      push     hl             ;090e    e5                   ;
      ld       hl,l0a25h      ;090f    21  25  0a           ; function l0a25h 3x on stacl
      push     hl             ;0912    e5                   ; | l0a25; |
      push     hl             ;0913    e5					; | l0a25; |
      push     hl             ;0914    e5					; | l0a25; |
      ld       hl,aa_mark      ;0915    21  0b  0a          ; function aa_mark on stack
      push     hl             ;0918    e5                   ; | aa_mark| on stack
      jp       l0953h         ;0919    c3  53  09


read_data_blk:
	; Reads the data block.
      ld       hl,sub_0a64h   ;091c    21  64  0a         ; | sub_0a64h |  <-- check error
      push     hl             ;091f    e5
      ld       (spsave),sp    ;0920    ed  73  61         ; Old SP
      ld       hl,l0000h      ;0924    21  00  00
      push     hl             ;0927    e5                 ;  | 0x0000    |  /* validlen = 0? */
      push     hl             ;0928    e5                 ;  | 0x0000    |  /* oldblock = 0? */
      ld       hl,l0a25h      ;0929    21  25  0a         ;  | 0x0a25    |   <- Function
      push     hl             ;092c    e5
      ld       hl,(validlen)  ;092d    2a  66  60
      ld       a,l            ;0930    7d                  ; lower part of length of last block
      or       h              ;0931    b4
      jr       z,l093dh       ;0932    28  09              ; no more left overs in h, so only "reg A" bytes left?
      push     hl             ;0934    e5                  ; | validlen  |
      ld       hl,(oldblk)    ;0935    2a  64  60          ; | oldblock  |
      push     hl             ;0938    e5                  ; | 0x0a10    |  <-- Function
      ld       hl,store_read_byte      ;0939    21  10  0a
      push     hl             ;093c    e5

l093dh:
      ; At this point the stack will contain either 3 or 6 entries. The stack will look like this
      ; [SP - 6] = validlen
      ; [SP - 4] = oldblock
      ; [SP - 2] = Cont, func.

      ld       hl,(hdrlen)    ;093d    2a  6a  60
      ld       a,h            ;0940    7c
      or       l              ;0941    b5
      jr       z,l094dh       ;0942    28  09              ; hdrlen == 0?
      push     hl             ;0944    e5                  ; | hdrlen             |
      ld       hl,(desl)      ;0945    2a  68  60
      push     hl             ;0948    e5
      ld       hl,store_read_byte      ;0949    21  10  0a ; | desl               |     dest off header
      push     hl             ;094c    e5                  ; | store_read_byte    | <-- Function

l094dh:
      push     hl             ;094d    e5                  ; | store_read_byte    |
      push     hl             ;094e    e5                  ; | store_read_byte    |
      ld       hl,aa_mark     ;094f    21  0b  0a          ; | 0x0a0b             |
      push     hl             ;0952    e5
l0953h:
      ld       a,040h         ;0953    3e  40              ; enable kbk
      out      (cas_kbd),a    ;0955    d3  10
      ld       a,048h         ;0957    3e  48              ; key + fwd
      out      (cas_kbd),a    ;0959    d3  10
      call     wait_250_us    ;095b    cd  78  0b          ; A = state(rdc) | BET
      xor      040h           ;095e    ee  40              ; flip rdc bit
      ld       h,a            ;0960    67                  ; H = A
      ld       iy,first_mdcr_signal      ;0961    fd  21  6a          ; IY = 0x096a
      ld       c,000h         ;0965    0e  00              ; C = 0
      ld       de,04ce5h      ;0967    11  e5  4c          ; DE = 0x4ce5 seems timing related..

first_mdcr_signal:
;; It looks this waits for the first bit from the cassette port.
;;
;; Vars:
;;     H  = state(RDC) | state(BET)
;;     DE = # of times we are willing to loop while waiting for a bit
;;
      in       a,(cas_inp)    ;096a    db  20
      and      070h           ;096c    e6  70 ; mask for bit 4,5,6 (rd clock, cip, bet)
      cp       h              ;096e    bc     ; H = state(RDC) | BET
      jr       z,start_bytes  ;096f    28  2a ; if (A == H) goto 0x099b  (Bit available for read?)
      and      030h           ;0971    e6  30 ; A = BET | CIP            (Does BET->CIP?)
      cp       020h           ;0973    fe  20 ; A -= BET
      jr       nz,mdcr_signal_err    ;0975    20  13 ; if (A == CIP) goto 098a (exit_cas)
      dec      de             ;0977    1b     ; DE--
      ld       a,d            ;0978    7a     ; A = F
      or       e              ;0979    b3     ; D || E (set Z if D==0 && E==0)
      jr       z,no_prog      ;097a    28  11 ; if (DE == 0)  no_prog
      nop                     ;097c    00     ; timing related nops?
      inc      c              ;097d    0c
      di                      ;097e    f3
      dec      c              ;097f    0d
      ld       a,048h         ;0980    3e  48 ; tape fwd keybd on.
      out      (cas_kbd),a    ;0982    d3  10
      ld       iy,first_mdcr_signal      ;0984    fd  21  6a
      jp       (iy)           ;0988    fd  e9 ;

mdcr_signal_err:
      jp       exit_cas       ;098a    c3  39  0a
no_prog:
      ld       a,"N"          ;098d    3e  4e      ; no program found
      ld       (caserror),a   ;098f    32  17  60
      ld       sp,(spsave)    ;0992    ed  7b  61  ; Restore stack.
      ld       l,000h         ;0996    2e  00      ; L = 0
      ld       b,008h         ;0998    06  08      ; B = 0x08
      ret                     ;099a    c9

start_bytes:
    ; Prep for read byte?  Looks like this gets called when we find the first
    ; bit on our mdcr (de = 0x2F86 on first call?)
    ; It looks like we use the shadow registers to collect bits
    ; E' contains the number of bits
    ; A' contains the byte we are reading

      ld       (06051h),de    ;099b    ed  53  51   ; Store counter.
      ld       iy,next_bit    ;099f    fd  21  ae   ; IY = 0x09ae
      exx     	              ;09a3    d9           ; Setup shadow registers.
      ld       e,007h         ;09a4    1e  07
      exx    		          ;09a6    d9           ; E' = 0x07
      ex       af,af'         ;09a7    08           ; A' active
      sub      a              ;09a8    97           ; A' = 0
      scf     		          ;09a9    37           ; FC = 1       AF = 0x0041 (Z + C)
      ld       de,l0000h      ;09aa    11  00  00   ; DE = 0
next_bit_af_flp:
      ex       af,af'         ;09ad    08           ; Activate our tempory  AF

next_bit:
      ; It looks like this sets up the h register for the next
      ; expected state on the cassette input port.
      ld       a,h            ;09ae    7c           ; A = state(RDC) | BET
      xor      040h           ;09af    ee  40       ; flip RDC state
      ld       h,a            ;09b1    67           ;
      ld       b,000h         ;09b2    06  00       ; B = 0

wait_for_bit:
      ; At this point h contains the RDC state we exepect at the cassette port
      ; b = 0; so we loop at most 255 times. (4692 usec 4,6 ms)
      in       a,(cas_inp)    ;09b4    db  20 ; bit read?                                          2.75  <-- Execution single instruction 4mhz z80  (P2000 = 2.5mhz)
      ld       l,a            ;09b6    6f     ; L = A  (i.e. last read)                         E.T 1                         |
      and      070h           ;09b7    e6  70 ; mask 6,5,4 (RDC, BET, CIP)                          1.75                      | (this loop is 18.4 usec on P2000t)
      cp       h              ;09b9    bc                                                           1                         |
      jr       z,read_bit     ;09ba    28  04 ; bit has arrived.                                F:  1.75  T: 3.00             |
      djnz     wait_for_bit   ;09bc    10  f6 ; keep trying until we receive the expected state F:  3.25  T: 2 (11.5) --------
      jr       exit_cas       ;09be    18  79

read_bit:
      ;; This is called when a bit has arrived
      ;; L contains the last read from the cassette port, and should have the bit
      ;; of interest
      ex       af,af'         ;09c0    08       ; A = A' bring in real A..                      1
      jr       c,l09e9h       ;09c1    38  26   ;
      ex       af,af'         ;09c3    08       ;
      xor      a              ;09c4    af       ; A = 0
      rlc      l              ;09c5    cb  05   ; shift bit 8 into C (read bit from port)
      rla                     ;09c7    17       ; shift this bit into A
      xor      e              ;09c8    ab       ; E = 0
      ld       e,a            ;09c9    5f       ; e <- (1/0)
      and      001h           ;09ca    e6  01
      jr       z,l09d4h       ;09cc    28  06   ; IF (A == 0) 0x9d4 (i.e. 0 bit read from tape)
      ld       a,002h         ;09ce    3e  02   ; E = 1
      xor      e              ;09d0    ab       ; A = 2
      ld       e,a            ;09d1    5f       ; E = 2
      ld       a,040h         ;09d2    3e  40   ; A = 40
l09d4h:
      xor      d              ;09d4    aa        ; D = 0,
      rra      		          ;09d5    1f        ; A = A / 2 (A = 0 | A =  0x20)
      rr       e              ;09d6    cb  1b    ; E now has the bit from tape
      jr       nc,l09dch      ;09d8    30  02  0 ;
      or       080h           ;09da    f6  80
l09dch:
      ld       d,a            ;09dc    57        ; D = 1000 | 1001 | 0 | 1
l09ddh:
      rrc      l              ;09dd    cb  0d
      exx                     ;09df    d9       ; Flip in shadow regs.
      rr       d              ;09e0    cb  1a   ; /2?
      dec      e              ;09e2    1d       ; bit counter?
      jr       nz,l09ech      ;09e3    20  07   ; get next byte handle function.
      ld       e,008h         ;09e5    1e  08
      jp       (ix)           ;09e7    dd  e9   ; we read a byte. [0a0b, 0a25, 0a10]
l09e9h:
      ex       af,af'         ;09e9    08       ; Called on bit 0,1, activates the shadow AF
      jr       l09ddh         ;09ea    18  f1
l09ech:                                         ; Did not yet read whole byte.
      ex       af,af'         ;09ec    08
      jp       pe,l09fbh      ;09ed    ea  fb  09 ; Jump parity even
      ld       b,080h         ;09f0    06  80
      dec      b              ;09f2    05
      ex       af,af'         ;09f3    08       ; F' = (Z=0, P=0, H=1, V=0, N=1, S=0 )
      pop      ix             ;09f4    dd  e1   ; Byte handle function.
      pop      hl             ;09f6    e1       ; Destination address.
      pop      bc             ;09f7    c1       ; Number of bytes.
      exx                     ;09f8    d9
      jr       next_bit       ;09f9    18  b3   ; It takes 82.8 usec to read a single bit.
l09fbh:
      ex       af,af'         ;09fb    08
      exx                     ;09fc    d9
      nop                     ;09fd    00
      inc      c              ;09fe    0c
      di                      ;09ff    f3
      dec      c              ;0a00    0d
      ld       a,048h         ;0a01    3e  48  ; write to unused ports? must be dummy..
      out      (cas_kbd),a    ;0a03    d3  10
      ld       iy,next_bit    ;0a05    fd  21  ae
      jp       (iy)           ;0a09    fd  e9  ; It takes 82.4 usec to take this path.
aa_mark:
      ex       af,af'         ;0a0b    08      ; Called after 1st byte was read 0xAA marker?
      exx                     ;0a0c    d9
      sub      a              ;0a0d    97       ; This resets the carry flag.
      jr       next_bit_af_flp  ;0a0e    18  9d  ; This path takes 66.4 usec., swap AF' in and next bit
store_read_byte:
      exx                     ;0a10    d9
      ld       a,d            ;0a11    7a
      or       e              ;0a12    b3
      jr       nz,l0a1ah      ;0a13    20  05
      ex       af,af'         ;0a15    08
      xor      a              ;0a16    af
      jp       l0a1eh         ;0a17    c3  1e  0a
l0a1ah:
      ex       af,af'         ;0a1a    08
      scf                     ;0a1b    37
      rla                     ;0a1c    17
      or       a              ;0a1d    b7
l0a1eh:
      exx                     ;0a1e    d9        ; D has the byte that was read.
      ld       (hl),d         ;0a1f    72        ; store in memory.
      cpi                     ;0a20    ed  a1    ; HL+1, BC-1, A-=[HL] BC has number of bytes in block
      exx                     ;0a22    d9
      jr       next_bit_af_flp         ;0a23    18  88
l0a25h:
      inc      bc             ;0a25    03        ; # bytes read?
      exx     		          ;0a26    d9
      ld       a,d            ;0a27    7a        ; Byte read in a.
      or       e              ;0a28    b3        ; Check if byte is non zero (we read 0xaa)
      jr       nz,l0a2fh      ;0a29    20  04
      ex       af,af'         ;0a2b    08
      xor      a              ;0a2c    af
      jr       l0a33h         ;0a2d    18  04
l0a2fh:                                          ; <- after we read the marker? (ie. AA 00 00 AA)
      ex       af,af'         ;0a2f    08
      scf                     ;0a30    37
      rla                     ;0a31    17
      or       a              ;0a32    b7
l0a33h:
      ld       b,080h         ;0a33    06  80
      dec      b              ;0a35    05
      jp       next_bit_af_flp         ;0a36    c3  ad  09
exit_cas:
; This is some kind of tape exit routine
; which will set there error to 0.
      ld       b,01eh         ;0a39    06  1e
l0a3bh:
      djnz     l0a3bh         ;0a3b    10  fe
      in       a,(cas_inp)    ;0a3d    db  20
      and      030h           ;0a3f    e6  30     ; mask 4,5 CIP & BET
      ld       hl,(spsave)    ;0a41    2a  61  60
      sbc      hl,sp          ;0a44    ed  72     ; subtract with carry
      ld       sp,(spsave)    ;0a46    ed  7b  61
      cp       020h           ;0a4a    fe  20     ; A - bit 5.
      ret      nz             ;0a4c    c0         ; return if no cassette?
      ld       a,000h         ;0a4d    3e  00     ; erase cassette error
      ld       (caserror),a   ;0a4f    32  17  60 ; cleanup of shadow?
      ld       b,008h         ;0a52    06  08
      ld       a,d            ;0a54    7a
      or       e              ;0a55    b3
      ret      z              ;0a56    c8
      ex       af,af'         ;0a57    08
      bit      0,a            ;0a58    cb  47
      ret      z              ;0a5a    c8
      bit      1,a            ;0a5b    cb  4f
      ret      z              ;0a5d    c8
      ex       af,af'         ;0a5e    08
      ld       a,020h         ;0a5f    3e  20
      ld       b,000h         ;0a61    06  00
      ret                     ;0a63    c9


; L != 0 error.
sub_0a64h:
      ld       h,a            ;0a64    67
      ld       a,b            ;0a65    78
      cp       008h           ;0a66    fe  08
      jr       z,l0a98h       ;0a68    28  2e
      bit      4,h            ;0a6a    cb  64
      ld       a,"A"          ;0a6c    3e  41  ; Geen cassette?
      jr       nz,l0a87h      ;0a6e    20  17
      bit      5,h            ;0a70    cb  6c
      ld       a,"E"          ;0a72    3e  45 ; End of tape, writing
      jr       z,l0a87h       ;0a74    28  11
      ld       a,"L"          ;0a76    3e  4c ; End of tape, reading.
      inc      l              ;0a78    2c
      dec      l              ;0a79    2d
      jr       nz,l0a87h      ;0a7a    20  0b
      exx                     ;0a7c    d9
      dec      bc             ;0a7d    0b
      dec      bc             ;0a7e    0b
      dec      bc             ;0a7f    0b
      ld       (endblk),bc    ;0a80    ed  43  6c
      exx                     ;0a84    d9
      ld       a,"C"          ;0a85    3e  43  ; Leesfout
l0a87h:
      ld       (caserror),a   ;0a87    32  17  60
l0a8ah:
      ld       a,l            ;0a8a    7d
      ld       (06063h),a     ;0a8b    32  63  60
      ld       b,000h         ;0a8e    06  00
      ld       hl,(klok)      ;0a90    2a  10  60
      add      hl,bc          ;0a93    09
      ld       (klok),hl      ;0a94    22  10  60
      ret                     ;0a97    c9
l0a98h:
      xor      a              ;0a98    af
      cp       l              ;0a99    bd
      ld       a,"J"          ;0a9a    3e  4a ; Te kort datablok gelezen, maar controle-getal ("checksum") in orde, of band spoelt niet doordat deze vast zit
      jr       nz,l0a87h      ;0a9c    20  e9
      ld       a,(caserror)   ;0a9e    3a  17  60
      cp       000h           ;0aa1    fe  00
      jr       nz,l0a8ah      ;0aa3    20  e5
      exx                     ;0aa5    d9
      dec      bc             ;0aa6    0b
      dec      bc             ;0aa7    0b
      dec      bc             ;0aa8    0b
      ld       (endblk),bc    ;0aa9    ed  43  6c
      exx                     ;0aad    d9
      jr       l0a8ah         ;0aae    18  da
wait_157msec:
; Length of start gap.
      push     bc             ;0ab0    c5
      ld       c,032h         ;0ab1    0e  32
      jp       l0b3ch         ;0ab3    c3  3c  0b
write_gap:
      push     bc             ;0ab6    c5
      ld       c,01bh         ;0ab7    0e  1b
      jr       delay          ;0ab9    18  3a
wait_516msec:
      push     bc             ;0abb    c5
      ld       c,0a4h         ;0abc    0e  a4
      jr       delay          ;0abe    18  35
wait_up_o_620ms:
      ld       a,(stacas)     ;0ac0    3a  60  60
      bit      4,a            ;0ac3    cb  67   ; BOT error?
      jr       z,wait10ms    ;0ac5    28  09   ; if no goto wait
      res      4,a            ;0ac7    cb  a7   ; reset BOT, and wait
      ld       (stacas),a     ;0ac9    32  60  60
      call     wait_500ms     ;0acc    cd  f2  0a
      ret      nz             ;0acf    c0
wait10ms:
      push     bc             ;0ad0    c5    ; wait 10.86ms
      ld       c,026h         ;0ad1    0e  26
      jr       delay          ;0ad3    18  20
sub_0ad5h:
      push     bc             ;0ad5    c5
      ld       c,026h         ;0ad6    0e  26 ; wait 7280 us
      jr       l0b3ch         ;0ad8    18  62
sub_0adah:
      push     bc             ;0ada    c5
      ld       c,016h         ;0adb    0e  16 ; wait 4480 us
      jr       delay          ;0add    18  16
sub_0adfh:
      push     bc             ;0adf    c5
      ld       c,020h         ;0ae0    0e  20 ; Wait 9152 us, 9ms
      jr       l0b3ch         ;0ae2    18  58
sub_0ae4h:
      push     bc             ;0ae4    c5
      ld       c,053h         ;0ae5    0e  53 ; Wait 23771us, 23ms.
      jr       delay          ;0ae7    18  0c
sub_0ae9h:
      res      4,a            ;0ae9    cb  a7
      ld       (stacas),a     ;0aeb    32  60  60
wait_1_sec:
      call     wait_500ms     ;0aee    cd  f2  0a
      ret      nz             ;0af1    c0
wait_500ms:
      push     bc             ;0af2    c5
      ld       c,09fh         ;0af3    0e  9f ; 500 ms
delay:
;  Delay a bit, while detecting end of tape, or tape removal
;  Args:
;       C: =  We will for +/- C * 286.4 us  delay
;
; bc should be on stack already
      ld       b,0afh         ;0af5    06  af ; from 0aff takes 280us
delay1:
      in       a,(cas_inp)    ;0af7    db  20  ;ET: 3.0
      and      030h           ;0af9    e6  30  ;ET: 1.0  A = BET | CIP   (Does BET->CIP?)
      cp       020h           ;0afb    fe  20  ;ET: 1.0  A -= BET
      jr       nz,handle_err  ;0afd    20  07  ;ET: 3.00 / 1.75 if (A == CIP) goto 098a (handle_err)
      djnz     delay1         ;0aff    10  f6  ;ET: 3.25 / 2.00  (One loop = 16us)
      dec      c              ;0b01    0d      ;ET: 1.00
      jr       nz,delay       ;0b02    20  f1  ;ET: 3.00 / 1.75
      pop      bc             ;0b04    c1      ;ET: 2.50
      ret                     ;0b05    c9      ;
handle_err:
      or       a              ;0b06    b7
      ld       a,"A"          ;0b07    3e  41  ; No cassette
      jr       nz,l0b0dh      ;0b09    20  02  ; if (A == CIP) exit
      ld       a,"E"          ;0b0b    3e  45  ; End of tape <--- Error
l0b0dh:
      ld       (caserror),a   ;0b0d    32  17  60
      ld       h,a            ;0b10    67
      ld       a,040h         ;0b11    3e  40     ; stop the motor
      out      (cas_kbd),a    ;0b13    d3  10
      ld       e,a            ;0b15    5f         ; E = 0x40
      ld       a,(stacas)     ;0b16    3a  60  60
      bit      2,a            ;0b19    cb  57     ; check if cassette err.
      jr       z,l0b2ah       ;0b1b    28  0d     ; if no caserr go to lob2ah
      call     l0b54h         ;0b1d    cd  54  0b
      ld       a,c            ;0b20    79
      sbc      a,002h         ;0b21    de  02
      ld       c,a            ;0b23    4f
      jr       c,l0b39h       ;0b24    38  13
      ld       b,08fh         ;0b26    06  8f
      jr       l0b2ch         ;0b28    18  02
l0b2ah:
      ld       b,0afh         ;0b2a    06  af
l0b2ch:
      in       a,(cas_inp)    ;0b2c    db  20
      and      030h           ;0b2e    e6  30  ; mask bit 4,5 (CIP/BET)
      xor      020h           ;0b30    ee  20  ; CIP or not BET
      jr       c,l0b2ah       ;0b32    38  f6
      djnz     l0b2ch         ;0b34    10  f6
      dec      c              ;0b36    0d
      jr       nz,l0b2ah      ;0b37    20  f1
l0b39h:
      inc      c              ;0b39    0c
      pop      bc             ;0b3a    c1
      ret                     ;0b3b    c9
l0b3ch:
      ld       a,(stacas)     ;0b3c    3a  60  60
      bit      2,a            ;0b3f    cb  57
      jr       z,delay        ;0b41    28  b2
      dec      c              ;0b43    0d
      dec      c              ;0b44    0d
      dec      c              ;0b45    0d
      call     l0b54h         ;0b46    cd  54  0b
      ld       a,(caserror)   ;0b49    3a  17  60
      ld       h,a            ;0b4c    67
      call     l0b54h         ;0b4d    cd  54  0b
      ld       b,070h         ;0b50    06  70
      jr       delay1         ;0b52    18  a3
l0b54h:
      ld       b,009h         ;0b54    06  09
      ld       a,e            ;0b56    7b
      and      07fh           ;0b57    e6  7f
      ld       e,a            ;0b59    5f
      rlc      e              ;0b5a    cb  03
l0b5ch:
      xor      080h           ;0b5c    ee  80       ; switch bit 7 PRNOUT
      out      (cas_kbd),a    ;0b5e    d3  10
      call     sub_0b72h      ;0b60    cd  72  0b
      srl      h              ;0b63    cb  3c
      ccf     		      ;0b65    3f
      ld       a,e            ;0b66    7b
      adc      a,000h         ;0b67    ce  00
      rrca                    ;0b69    0f
      djnz     l0b5ch         ;0b6a    10  f0
      and      07fh           ;0b6c    e6  7f
      out      (cas_kbd),a    ;0b6e    d3  10
      rrc      e              ;0b70    cb  0b
sub_0b72h:
; this seems to wait a few clock cycles. (Find out how many)
; for(D = 3; D > 0; D--);
      ld       d,03dh         ;0b72    16  3d
l0b74h:
      dec      d              ;0b74    15
      jr       nz,l0b74h      ;0b75    20  fd
      ret

	                   ;0b77    c9
wait_250_us:
; waits a bit and sets the current RDC state + bit 5 (BET) in A
; so A = 0101 0000 or 0001 0000
      ld       b,02eh         ;0b78    06  2e  ; for(B = 0x2e; B > 0; B--);
l0b7ah:
      djnz     l0b7ah         ;0b7a    10  fe  ; ET= 3.25  (5.2 usec * ) (239.2 us)
      in       a,(cas_inp)    ;0b7c    db  20  ; ET= 2.75
      and      040h           ;0b7e    e6  40  ; ET= 1.75
      set      5,a            ;0b80    cb  ef  ; ET= 2   a = RDC | bit5 (BET)
      ret                     ;0b82    c9      ; ET= 2.5   Total 249.7

castest:
      in       a,(cas_inp)    ;0b83    db  20
      and      018h           ;0b85    e6  18 ; mask CIP WEN  (0001 1000)
      ret      z              ;0b87    c8     ; if (!CIP && !WEN) return
      cp       018h           ;0b88    fe  18 ;
      ret      z              ;0b8a    c8     ; if (CIP && WEN) return
      ld       a,"G"          ;0b8b    3e  47 ; Geen stopje.  (!WEN || !CIP), invariant?: WEN -> CIP
      ld       (caserror),a   ;0b8d    32  17  60
      ret                     ;0b90    c9

video_off:
;    When the DISAS is active, the CPU has the highest priority and
;    video refresh is disabled when the CPU accesses video memory
      ld       a,0ffh         ;0b91    3e  ff
      out      (070h),a       ;0b93    d3  70
      ret                     ;0b95    c9

video_on:
      xor      a              ;0b96    af
      out      (070h),a       ;0b97    d3  70
      ret                     ;0b99    c9

sub_0b9ah:
;; Reads some block?
      ld       hl,stacas      ;0b9a    21  60  60
      bit      1,(hl)         ;0b9d    cb  4e        ; check if we are writing
      ret      z              ;0b9f    c8
      res      1,(hl)         ;0ba0    cb  8e
      jp       err0           ;0ba2    c3  de  01
      call     EOT            ;0ba5    cd  e4  0b    ; last file
      ld       a,(caserror)   ;0ba8    3a  17  60
      cp       000h           ;0bab    fe  00
      ret      nz             ;0bad    c0
      ld       hl,stacas      ;0bae    21  60  60
      set      0,(hl)         ;0bb1    cb  c6
      ret                     ;0bb3    c9

rewind:
      call     sub_0b9ah      ;0bb4    cd  9a  0b
      ret      nz             ;0bb7    c0
      ld       a,044h         ;0bb8    3e  44     ; key + rewind
      out      (cas_kbd),a    ;0bba    d3  10     ; send the tape back home.
      ld       b,067h         ;0bbc    06  67     ; max 103 sec
l0bbeh:
      call     wait_1_sec     ;0bbe    cd  ee  0a
      jr       nz,l0bcch      ;0bc1    20  09
      djnz     l0bbeh         ;0bc3    10  f9
      ld       a,"I"          ;0bc5    3e  49     ; cassette error `I` wait too long
      ld       (caserror),a   ;0bc7    32  17  60
      ld       c,00fh         ;0bca    0e  0f
l0bcch:
      ld       a,(caserror)   ;0bcc    3a  17  60
      cp       "E"            ;0bcf    fe  45     ; we should have reached an end
      jr       nz,l0bdfh      ;0bd1    20  0c     ; but maybe we did not..
      ld       a,000h         ;0bd3    3e  00     ; Everything ok!
      ld       (caserror),a   ;0bd5    32  17  60
      ld       hl,stacas      ;0bd8    21  60  60
      set      4,(hl)         ;0bdb    cb  e6
      res      0,(hl)         ;0bdd    cb  86
l0bdfh:
      ld       h,067h         ;0bdf    26  67
      jp       retOffMotor    ;0be1    c3  58  06


EOT:
      call     castest        ;0be4    cd  83  0b
      ret      nz             ;0be7    c0
      ld       a,04ah         ;0be8    3e  4a  ;; FWD WRITE
      out      (cas_kbd),a    ;0bea    d3  10
      ld       b,00fh         ;0bec    06  0f
l0beeh:
      call     wait10ms      ;0bee    cd  d0  0a
      jr       nz,l0c03h      ;0bf1    20  10
      djnz     l0beeh         ;0bf3    10  f9
      ld       a,000h         ;0bf5    3e  00
      ld       (caserror),a   ;0bf7    32  17  60 ; No error.
      ld       hl,stacas      ;0bfa    21  60  60
      res      1,(hl)         ;0bfd    cb  8e      ; can write
      set      0,(hl)         ;0bff    cb  c6      ; no start mark
      res      4,(hl)         ;0c01    cb  a6      ; no bot error
l0c03h:
      ld       a,042h         ;0c03    3e  42
      out      (cas_kbd),a    ;0c05    d3  10
      call     wait10ms      ;0c07    cd  d0  0a
      ld       h,068h         ;0c0a    26  68
      jp       retOffMotor    ;0c0c    c3  58  06
      call     sub_0b9ah      ;0c0f    cd  9a  0b
      ret      nz             ;0c12    c0


sub_0c13h:
      ld       a,048h         ;0c13    3e  48   ; move tape forward + with keyboard
      out      (cas_kbd),a    ;0c15    d3  10
      call     wait_up_o_620ms;0c17    cd  c0  0a
      ret      nz             ;0c1a    c0
      call     sub_0adah      ;0c1b    cd  da  0a
      ret      nz             ;0c1e    c0
      ld       a,"N"          ;0c1f    3e  4e   ; no program found
      ld       (caserror),a   ;0c21    32  17  60
      call     get_rda        ;0c24    cd  ee  0c
      ld       d,0eah         ;0c27    16  ea
l0c29h:
      call     read_rev_byte       ;0c29    cd  bf  0c
      jr       c,sub_0c13h_ret;0c2c    38  23
      jr       nz,l0c3ah      ;0c2e    20  0a
      ld       d,023h         ;0c30    16  23
      ld       a,000h         ;0c32    3e  00
      ld       (caserror),a   ;0c34    32  17  60 ; No error
      ld       a,h            ;0c37    7c
      jr       l0c29h         ;0c38    18  ef
l0c3ah:
      ld       a,(caserror)   ;0c3a    3a  17  60
      cp       000h           ;0c3d    fe  00
      jr       nz,no_start_marker ;0c3f    20  15
      ld       hl,stacas      ;0c41    21  60  60
      bit      5,(hl)         ;0c44    cb  6e
      jr       z,l0c4bh       ;0c46    28  03
      res      5,(hl)         ;0c48    cb  ae
      ret                     ;0c4a    c9
l0c4bh:
      ld       hl,telblok     ;0c4b    21  6e  60  ;; telblock--
      dec      (hl)           ;0c4e    35  5
      jr       nz,sub_0c13h   ;0c4f    20  c2      ;; if telblock > 0
sub_0c13h_ret:
      ld       h,066h         ;0c51    26  66
      jp       retOffMotor    ;0c53    c3  58  06
no_start_marker:
      ld       hl,stacas      ;0c56    21  60  60
      set      0,(hl)         ;0c59    cb  c6     ; geen startmerk..
      jr       sub_0c13h_ret  ;0c5b    18  f4


sub_0c5dh:
      ld       l,001h         ;0c5d    2e  01
      jr       l0c6ch         ;0c5f    18  0b

move_back_block:
      call     sub_0b9ah      ;0c61    cd  9a  0b ; Entry point move block back
      ret      nz             ;0c64    c0
      ld       hl,stacas      ;0c65    21  60  60
      res      0,(hl)         ;0c68    cb  86
      ld       l,000h         ;0c6a    2e  00
l0c6ch:
      ld       a,044h         ;0c6c    3e  44     ; Set tape to move back
      out      (cas_kbd),a    ;0c6e    d3  10
      call     get_rda        ;0c70    cd  ee  0c ; Get the state of the clock.
l0c73h:
      ld       e,0e1h         ;0c73    1e  e1     ; e1? (225?)
      ld       d,001h         ;0c75    16  01
l0c77h:
      call     read_rev_byte      ;0c77    cd  bf  0c  ; Move back one byte.
      jr       c,move_back_err     ;0c7a    38  26     ; Carry bit means we saw an error
      jr       nz,l0c73h      ;0c7c    20  f5
      dec      e              ;0c7e    1d
      jr       nz,l0c77h      ;0c7f    20  f6
      bit      0,l            ;0c81    cb  45
      jr       nz,l0cb8h      ;0c83    20  33
l0c85h:
      ld       d,027h         ;0c85    16  27
      call     read_rev_byte  ;0c87    cd  bf  0c
      jr       c,move_back_err       ;0c8a    38  16     ; Carry bit means error
      jr       z,l0c85h       ;0c8c    28  f7
      ld       h,064h         ;0c8e    26  64
      ld       e,044h         ;0c90    1e  44
      call     sub_0adfh      ;0c92    cd  df  0a
      jr       nz,l0ca7h      ;0c95    20  10
      ld       hl,telblok     ;0c97    21  6e  60
      dec      (hl)           ;0c9a    35  5
      jr       nz,l0c6ch      ;0c9b    20  cf
l0c9dh:
      ld       a,000h         ;0c9d    3e  00
      ld       (caserror),a   ;0c9f    32  17  60 ; Reset error
move_back_err:
      ld       h,065h         ;0ca2    26  65     ;
      call     retOffMotor    ;0ca4    cd  58  06 ; Stop the motor and continue..
l0ca7h:
      ld       a,(caserror)   ;0ca7    3a  17  60 ; Set error to "B" and set bit 4 in stacas if we saw BET signal
      cp       045h           ;0caa    fe  45     ;
      ret      nz             ;0cac    c0         ;
      ld       a,"B"          ;0cad    3e  42     ; Start of tape, bad news we went back too far?
      ld       (caserror),a   ;0caf    32  17  60
      ld       hl,stacas      ;0cb2    21  60  60
      set      4,(hl)         ;0cb5    cb  e6
      ret                     ;0cb7    c9
l0cb8h:
      call     sub_0ae4h      ;0cb8    cd  e4  0a
      jr       nz,l0ca7h      ;0cbb    20  ea
      jr       l0c9dh         ;0cbd    18  de


      ;; This seems to read a byte when the tape is moving backwards.
      ;; Note that RDA <-> RDC when moving backwards.
      ;;
      ;; Args:
      ;;   A must contain the current state of RDC & BET
      ;;   D related to time we are willing to wait to see a byte.
      ;;
      ;; Returns:
      ;;   Sets the C flag in case of failure (beginning of tape, or tape removed.)
      ;;   Sets (caserror) with the actual error in case C is set
read_rev_byte:
      ld       c,008h         ;0cbf    0e  08        ; wait for at most 8 bits
rev_next_bit:
      xor      080h           ;0cc1    ee  80        ; Flip the expected RDA, we wait for next clock
      ld       h,a            ;0cc3    67
l0cc4h:
      ld       b,000h         ;0cc4    06  00        ; Max time we are willing to wait for RDA clock signal, we loop 256 times
wait_for_rev_bit:
      ; Keep spinning until we have a bit flip
      in       a,(cas_inp)    ;0cc6    db  20        ;
      and      0b0h           ;0cc8    e6  b0        ; RDA, BET, CIP
      cp       h              ;0cca    bc            ; Is the clock state as expected?
      jr       z,rev_bit_available  ;0ccb    28  10
      djnz     wait_for_rev_bit     ;0ccd    10  f7  ; Spin until RDA changes.
      and      030h           ;0ccf    e6  30        ; mask bet & cip
      cp       020h           ;0cd1    fe  20        ; this checks for errors.
      jr       nz,read_rev_err     ;0cd3    20  0d   ; Check if we are at the end, or cassette removed.
      dec      d              ;0cd5    15
      jr       nz,l0cc4h      ;0cd6    20  ec
      ld       a,h            ;0cd8    7c
      xor      080h           ;0cd9    ee  80
      inc      d              ;0cdb    14
      ret                     ;0cdc    c9
rev_bit_available:
      ;; This is called when we have a bit available..
      ld       a,h            ;0cdd    7c
      dec      c              ;0cde    0d
      jr       nz,rev_next_bit      ;0cdf    20  e0
      ret                     ;0ce1    c9  ; We have read 8 bits..

read_rev_err:
      ;; This happens when we hit the beginning of the tape, or if we
      ;; removed the tape while moving backwards.
      or       a              ;0ce2    b7
      ld       a,"E"          ;0ce3    3e  45   ; End of tape error
      jr       z,l0ce9h       ;0ce5    28  02
      ld       a,"A"          ;0ce7    3e  41   ; No tape
l0ce9h:
      ld       (caserror),a   ;0ce9    32  17  60
      scf                     ;0cec    37       ; Set the carry flag to indicate failure.
      ret                     ;0ced    c9


;; Read the RDA state and set bit 5 in A
;; RDA_state | BET
;; Note when the tape is moving in reverse this actually gets the RDC bit.
get_rda:
      in       a,(cas_inp)    ;0cee    db  20
      and      080h           ;0cf0    e6  80
      set      5,a            ;0cf2    cb  ef
      ret                     ;0cf4    c9


l0cf5h:
      ld       c,(hl)         ;0cf5    4e
      sub      a              ;0cf6    97
      or       c              ;0cf7    b1
      ret      z              ;0cf8    c8
      inc      hl             ;0cf9    23
      call     sub_0e5dh      ;0cfa    cd  5d  0e
      ret c                   ;0cfd    d8
      jr       l0cf5h         ;0cfe    18  f5
prscreen:
      ex       af,af'         ;0d00    08
      sub      a              ;0d01    97
      ld       (0601eh),a     ;0d02    32  1e  60
      call     sub_0dcch      ;0d05    cd  cc  0d
      ret      nz             ;0d08    c0
      ex       af,af'         ;0d09    08
      and      a              ;0d0a    a7
      jr       z,l0cf5h       ;0d0b    28  e8
      call     sub_0de0h      ;0d0d    cd  e0  0d
      push     hl             ;0d10    e5
      push     de             ;0d11    d5
      ld       d,000h         ;0d12    16  00
l0d14h:
      push     bc             ;0d14    c5
      push     af             ;0d15    f5
      bit      0,d            ;0d16    cb  42
      jr       z,l0d1fh       ;0d18    28  05
      call     sub_0ddah      ;0d1a    cd  da  0d
      jr       l0d27h         ;0d1d    18  08
l0d1fh:
      call     l0489h         ;0d1f    cd  89  04
      jr       nc,l0d31h      ;0d22    30  0d  0
      call     sub_0dd7h      ;0d24    cd  d7  0d
l0d27h:
      call     sub_0dd7h      ;0d27    cd  d7  0d
      jr       nc,l0d31h      ;0d2a    30  05  0
      ld       (0601eh),a     ;0d2c    32  1e  60
      jr       l0da7h         ;0d2f    18  76
l0d31h:
      push     hl             ;0d31    e5
      ld       a,(baudrate)   ;0d32    3a  16  60
      and      080h           ;0d35    e6  80
      ld       d,a            ;0d37    57
      jr       nz,l0d4ch      ;0d38    20  12
      ld       b,000h         ;0d3a    06  00
      add      hl,bc          ;0d3c    09
      inc      c              ;0d3d    0c
l0d3eh:
      dec      c              ;0d3e    0d
      jr       z,l0d91h       ;0d3f    28  50
      dec      hl             ;0d41    2b
      ld       a,(hl)         ;0d42    7e
      and      a              ;0d43    a7
      jr       z,l0d3eh       ;0d44    28  f8
      cp       020h           ;0d46    fe  20
      jr       z,l0d3eh       ;0d48    28  f4
      pop      hl             ;0d4a    e1
      push     hl             ;0d4b    e5
l0d4ch:
      ld       b,c            ;0d4c    41
l0d4dh:
      ld       c,(hl)         ;0d4d    4e
      call     sub_0ddah      ;0d4e    cd  da  0d
      ld       a,c            ;0d51    79
      cp       01dh           ;0d52    fe  1d
      jr       nz,l0d58h      ;0d54    20  02
      set      0,d            ;0d56    cb  c2
l0d58h:
      bit      7,d            ;0d58    cb  7a
      jr       z,l0d61h       ;0d5a    28  05
      call     sub_0e5dh      ;0d5c    cd  5d  0e
      jr       l0d88h         ;0d5f    18  27
l0d61h:
      cp       098h           ;0d61    fe  98
      jr       z,l0d91h       ;0d63    28  2c
      and      07fh           ;0d65    e6  7f
      jr       z,l0d85h       ;0d67    28  1c
      cp       009h           ;0d69    fe  09
      jr       nc,l0d6fh      ;0d6b    30  02  0
      res      4,d            ;0d6d    cb  a2
l0d6fh:
      cp       011h           ;0d6f    fe  11
      jr       c,l0d85h       ;0d71    38  12
      cp       018h           ;0d73    fe  18
      jr       nc,l0d79h      ;0d75    30  02  0
      set      4,d            ;0d77    cb  e2
l0d79h:
      bit      4,d            ;0d79    cb  62
      jr       z,l0d85h       ;0d7b    28  08
      sub      040h           ;0d7d    d6  40
      cp       020h           ;0d7f    fe  20
      jr       c,l0d85h       ;0d81    38  02
      ld       c,020h         ;0d83    0e  20
l0d85h:
      call     sub_0df2h      ;0d85    cd  f2  0d
l0d88h:
      call     sub_0ddah      ;0d88    cd  da  0d
      jr       c,l0da6h       ;0d8b    38  19
      inc      hl             ;0d8d    23
      djnz     l0d4dh         ;0d8e    10  bd
      dec      hl             ;0d90    2b
l0d91h:
      bit      7,d            ;0d91    cb  7a
      jr       nz,l0da6h      ;0d93    20  11
      ld       c,00dh         ;0d95    0e  0d
      call     sub_0e5dh      ;0d97    cd  5d  0e
      ld       c,00ah         ;0d9a    0e  0a
      ld       a,(hl)         ;0d9c    7e
      cp       098h           ;0d9d    fe  98
      jr       nz,l0da3h      ;0d9f    20  02
      ld       c,00ch         ;0da1    0e  0c
l0da3h:
      call     sub_0e5dh      ;0da3    cd  5d  0e
l0da6h:
      pop      hl             ;0da6    e1
l0da7h:
      pop      bc             ;0da7    c1
      ld       a,b            ;0da8    78
      pop      bc             ;0da9    c1
      jr       c,l0db6h       ;0daa    38  0a
      push     de             ;0dac    d5
      ld       de,l0050h      ;0dad    11  50  00
      add      hl,de          ;0db0    19
      pop      de             ;0db1    d1
      dec      a              ;0db2    3d
      jp       nz,l0d14h      ;0db3    c2  14  0d
l0db6h:
      pop      de             ;0db6    d1
      call     sub_0dech      ;0db7    cd  ec  0d
      pop      hl             ;0dba    e1
      ret                     ;0dbb    c9
sub_0dbch:
      ld       b,006h         ;0dbc    06  06
l0dbeh:
      call     sub_0dcch      ;0dbe    cd  cc  0d
      jr       z,l0dcah       ;0dc1    28  07
      inc      de             ;0dc3    13
      ld       a,d            ;0dc4    7a
      or       e              ;0dc5    b3
      jr       nz,l0dbeh      ;0dc6    20  f6
      djnz     l0dbeh         ;0dc8    10  f4
l0dcah:
      ccf      ;0dca    3f
      ret                     ;0dcb    c9

sub_0dcch:
      scf                     ;0dcc    37        ; set Carry flag
      in       a,(cas_inp)    ;0dcd    db  20
      bit      1,a            ;0dcf    cb  4f    ; printer ready?
      ret      nz             ;0dd1    c0        ; if yes, return.
      in       a,(cas_inp)    ;0dd2    db  20
      bit      1,a            ;0dd4    cb  4f    ; printer ready?
      ret                     ;0dd6    c9
sub_0dd7h:
      call     readkey        ;0dd7    cd  9b  04
sub_0ddah:
      rl       (hl)           ;0dda    cb  16
      ccf     		      ;0ddc    3f
      rr       (hl)           ;0ddd    cb  1e
      ret                     ;0ddf    c9
sub_0de0h:
      push     de             ;0de0    d5
      push     bc             ;0de1    c5
      ld       b,050h         ;0de2    06  50
l0de4h:
      ld       e,003h         ;0de4    1e  03
      call     scrn_type      ;0de6    cd  be  01
      pop      bc             ;0de9    c1
      pop      de             ;0dea    d1
      ret                     ;0deb    c9
sub_0dech:
      push     de             ;0dec    d5
      push     bc             ;0ded    c5
      ld       b,000h         ;0dee    06  00
      jr       l0de4h         ;0df0    18  f2
sub_0df2h:
      push     hl             ;0df2    e5
      push     de             ;0df3    d5
      push     bc             ;0df4    c5
      call     sub_0dfch      ;0df5    cd  fc  0d
      pop      bc             ;0df8    c1
      pop      de             ;0df9    d1
      pop      hl             ;0dfa    e1
      ret                     ;0dfb    c9
sub_0dfch:
      ld       hl,(0605eh)    ;0dfc    2a  5e  60
      ld       d,000h         ;0dff    16  00
      ld       e,(hl)         ;0e01    5e
      in       a,(cas_inp)    ;0e02    db  20    ;  STRAPN printer
      and      004h           ;0e04    e6  04
      ld       a,c            ;0e06    79
      res      7,c            ;0e07    cb  b9
      jr       z,l0e3dh       ;0e09    28  32
      bit      7,a            ;0e0b    cb  7f
      jr       z,l0e1ch       ;0e0d    28  0d
      push     bc             ;0e0f    c5
      ld       c,05fh         ;0e10    0e  5f
      call     sub_0e5dh      ;0e12    cd  5d  0e
      ld       c,008h         ;0e15    0e  08
      call     nc,sub_0e5dh   ;0e17    d4  5d  0e
      pop      bc             ;0e1a    c1
      ret c                   ;0e1b    d8
l0e1ch:
      add      hl,de          ;0e1c    19
      add      hl,de          ;0e1d    19
      inc      hl             ;0e1e    23
      ld       e,(hl)         ;0e1f    5e
      inc      e              ;0e20    1c
l0e21h:
      inc      hl             ;0e21    23
      dec      e              ;0e22    1d
      jr       z,l0e3ch       ;0e23    28  17
      ld       a,(hl)         ;0e25    7e
      cp       c              ;0e26    b9
      inc      hl             ;0e27    23
      ld       b,(hl)         ;0e28    46
      inc      hl             ;0e29    23
      jr       nz,l0e21h      ;0e2a    20  f5
      push     bc             ;0e2c    c5
      ld       c,(hl)         ;0e2d    4e
      call     sub_0e48h      ;0e2e    cd  48  0e
      ld       c,008h         ;0e31    0e  08
      call     nc,sub_0e5dh   ;0e33    d4  5d  0e
      pop      bc             ;0e36    c1
      ld       c,b            ;0e37    48
      call     nc,sub_0e48h   ;0e38    d4  48  0e
      ret                     ;0e3b    c9
l0e3ch:
      ld       e,(hl)         ;0e3c    5e
l0e3dh:
      inc      e              ;0e3d    1c
l0e3eh:
      inc      hl             ;0e3e    23
      dec      e              ;0e3f    1d
      jr       z,l0e55h       ;0e40    28  13
      ld       a,(hl)         ;0e42    7e
      inc      hl             ;0e43    23
      cp       c              ;0e44    b9
      jr       nz,l0e3eh      ;0e45    20  f7
      ld       c,(hl)         ;0e47    4e
sub_0e48h:
      bit      7,c            ;0e48    cb  79
      res      7,c            ;0e4a    cb  b9
      push     bc             ;0e4c    c5
      ld       c,01bh         ;0e4d    0e  1b
      call     nz,sub_0e5dh   ;0e4f    c4  5d  0e
      pop      bc             ;0e52    c1
      jr       sub_0e5dh      ;0e53    18  08
l0e55h:
      res      7,c            ;0e55    cb  b9
      ld       a,020h         ;0e57    3e  20
      cp       c              ;0e59    b9
      jr       c,sub_0e5dh    ;0e5a    38  01
      ld       c,a            ;0e5c    4f
sub_0e5dh:
      push     bc             ;0e5d    c5
      push     de             ;0e5e    d5
      call     sub_0dbch      ;0e5f    cd  bc  0d
      jr       c,l0e8dh       ;0e62    38  29
      ld       d,00ah         ;0e64    16  0a
      di                      ;0e66    f3
l0e67h:
      ld       a,0c0h         ;0e67    3e  c0
      jr       nc,l0e6dh      ;0e69    30  02  0
      res      7,a            ;0e6b    cb  bf
l0e6dh:
      out      (cas_kbd),a    ;0e6d    d3  10
      ld       b,049h         ;0e6f    06  49
      ld       a,(baudrate)   ;0e71    3a  16  60
      res      7,a            ;0e74    cb  bf
      inc      a              ;0e76    3c
l0e77h:
      djnz     l0e77h         ;0e77    10  fe
      ld       b,04eh         ;0e79    06  4e
      dec      a              ;0e7b    3d
      add      a,000h         ;0e7c    c6  00
      jr       nz,l0e77h      ;0e7e    20  f7
      scf                     ;0e80    37
      rr       c              ;0e81    cb  19
      dec      d              ;0e83    15
      jr       nz,l0e67h      ;0e84    20  e1
      ld       b,a            ;0e86    47
l0e87h:
      djnz     l0e87h         ;0e87    10  fe
      call     sub_0dbch      ;0e89    cd  bc  0d
      ei                      ;0e8c    fb
l0e8dh:
      pop      de             ;0e8d    d1
      pop      bc             ;0e8e    c1
      ret                     ;0e8f    c9

; Floppy related things

spsave_d:           equ 608eh  ; Return address disk system
hasdisk:            equ 605dh  ; disk available?

; poorten voor de floppy handling:
; poort 8C: input status FDC
; poort 8D: bit 0 op poort 90 selecteert
; 			0: data I/O disk-geheugen
; 			1: input: lees status registers FDC
; output: geef FDC opdracht

; poort 90 is een output poort voor de controle signalen van de floppy
; bit 0: FDC enable
; 			0: data transport
; 			1: registers schrijven-lezen
; bit 1: terminal count FDC
; bit 2: FDC reset
; bit 3: motor on
; bit 4: disable select FDC
; 		    0: normaal
; 			1: noselect
;
; N.B. bit 4 wordt op de normale 48-k plank niet gebruikt, wel de in
; ontwikkeling zijnde plank van P2C2
getDOS:
      di                      ;0e90    f3           ; no interrupts please
      ld       (spsave_d),sp  ;0e91    ed  73  8e   ; Store return address.
      ld       a,001h         ;0e95    3e  01
      ld       (hasdisk),a    ;0e97    32  5d  60   ; disk available?
      ld       hl,l0fe8h      ;0e9a    21  e8  0f
      ld       de,descrip     ;0e9d    11  70  60
      ld       bc,00017h      ;0ea0    01  17  00
      ldir                    ;0ea3    ed  b0
      call     init_disk      ;0ea5    cd  e2  0e   ; kop-0, timing
      call     dsk_motor_on   ;0ea8    cd  88  0f
l0eabh:
      call     read_track     ;0eab    cd  19  0f
      ld       hl,(descrip)   ;0eae    2a  70  60
      ld       bc,01000h      ;0eb1    01  00  10
      add      hl,bc          ;0eb4    09
      ld       (descrip),hl   ;0eb5    22  70  60
      ld       hl,06075h      ;0eb8    21  75  60
      ld       a,002h         ;0ebb    3e  02
      cp       (hl)           ;0ebd    be
      jr       z,l0ec6h       ;0ebe    28  06
      inc      (hl)           ;0ec0    34  4
      call     sub_0f7dh      ;0ec1    cd  7d  0f
      jr       l0eabh         ;0ec4    18  e5
l0ec6h:
      ld       hl,0e000h      ;0ec6    21  00  e0
      ld       a,0f3h         ;0ec9    3e  f3
      cp       (hl)           ;0ecb    be
      jr       z,l0ed2h       ;0ecc    28  04
      xor      a              ;0ece    af
      ld       (hasdisk),a     ;0ecf    32  5d  60
l0ed2h:
      di                      ;0ed2    f3
      ld       a,003h         ;0ed3    3e  03
      out      (088h),a       ;0ed5    d3  88
      xor      a              ;0ed7    af
      out      (090h),a       ;0ed8    d3  90
      ld       sp,(spsave_d)    ;0eda    ed  7b  8e
      xor      a              ;0ede    af
      out      (094h),a       ;0edf    d3  94
      ret                     ;0ee1    c9

init_disk:
; initialiseer de FDC, zet kop op eerste track, zet de interrupt vectors
; wacht 350 msec en verwijder interrupt
      im       2              ;0ee2    ed  5e
      di                      ;0ee4    f3
      ld       a,004h         ;0ee5    3e  04
      out      (090h),a       ;0ee7    d3  90
      call     wait350ms      ;0ee9    cd  ff  0e
      call     sub_0fe6h      ;0eec    cd  e6  0f
      call     word_res       ;0eef    cd  d9  0f
      call     sub_0fb7h      ;0ef2    cd  b7  0f
      ld       hl,06083h      ;0ef5    21  83  60
      call     sub_0fa5h      ;0ef8    cd  a5  0f
      call     sub_0f08h      ;0efb    cd  08  0f
      ret                     ;0efe    c9

wait350ms:
      ld       bc,l0000h      ;0eff    01  00  00
wait_l:
      djnz     wait_l         ;0f02    10  fe
      dec      c              ;0f04    0d
      jr       nz,wait_l      ;0f05    20  fb
      ret                     ;0f07    c9


sub_0f08h:
      ld       hl,l0fd6h      ;0f08    21  d6  0f
      ld       (06020h),hl    ;0f0b    22  20  60
      ld       hl,06080h      ;0f0e    21  80  60
      call     sub_0fa5h      ;0f11    cd  a5  0f
      halt                    ;0f14    76
      call     word_res       ;0f15    cd  d9  0f
      ret
	                ;0f18    c9
read_track:
      ld       iy,06072h      ;0f19    fd  21  72
      ld       hl,l0f5ah      ;0f1d    21  5a  0f
      ld       (06020h),hl    ;0f20    22  20  60
      xor      a              ;0f23    af
      inc      a              ;0f24    3c
      ld       (iy+005h),a    ;0f25    fd  77  05
      ld       hl,06072h      ;0f28    21  72  60
      call     sub_0fa5h      ;0f2b    cd  a5  0f
      ld       a,0c5h         ;0f2e    3e  c5
      out      (089h),a       ;0f30    d3  89
      ld       a,001h         ;0f32    3e  01
      out      (089h),a       ;0f34    d3  89
      ld       hl,(descrip)   ;0f36    2a  70  60
      ld       c,08dh         ;0f39    0e  8d
      ld       a,00dh         ;0f3b    3e  0d
      out      (090h),a       ;0f3d    d3  90
      ld       e,010h         ;0f3f    1e  10
      ld       a,001h         ;0f41    3e  01
      out      (094h),a       ;0f43    d3  94
l0f45h:
      in       a,(090h)       ;0f45    db  90
      rra                     ;0f47    1f
      jp       nc,l0f45h      ;0f48    d2  45  0f
      ini                     ;0f4b    ed  a2
      jp       l0f45h         ;0f4d    c3  45  0f
      dec      e              ;0f50    1d
sub_0f51h:
      jp       nz,l046ah      ;0f51    c2  6a  04
      ld       a,00eh         ;0f54    3e  0e
      out      (090h),a       ;0f56    d3  90
l0f58h:
      jr       l0f58h         ;0f58    18  fe
l0f5ah:
      pop      hl             ;0f5a    e1
      ld       hl,l0f62h      ;0f5b    21  62  0f
      push     hl             ;0f5e    e5
      ei                      ;0f5f    fb
      reti                    ;0f60    ed  4d
l0f62h:
      ld       a,003h         ;0f62    3e  03
      out      (089h),a       ;0f64    d3  89
      ld       b,007h         ;0f66    06  07
      call     sub_0f90h      ;0f68    cd  90  0f
      ret                     ;0f6b    c9
sub_0f6ch:
      ld       hl,l0fd6h      ;0f6c    21  d6  0f
      ld       (06020h),hl    ;0f6f    22  20  60
      ld       hl,0607ch      ;0f72    21  7c  60
      call     sub_0fa5h      ;0f75    cd  a5  0f
      halt                    ;0f78    76
      call     word_res       ;0f79    cd  d9  0f
      ret                     ;0f7c    c9
sub_0f7dh:
      ld       a,(06075h)     ;0f7d    3a  75  60
      dec      a              ;0f80    3d
      ld       (0607fh),a     ;0f81    32  7f  60
      call     sub_0f6ch      ;0f84    cd  6c  0f
      ret                     ;0f87    c9
dsk_motor_on:
      ld       a,00ch         ;0f88    3e  0c
      out      (090h),a       ;0f8a    d3  90
      call     wait350ms      ;0f8c    cd  ff  0e
      ret                     ;0f8f    c9
sub_0f90h:
      ld       a,003h         ;0f90    3e  03
      out      (089h),a       ;0f92    d3  89
      ld       hl,06087h      ;0f94    21  87  60
      ld       a,00ch         ;0f97    3e  0c
      out      (090h),a       ;0f99    d3  90
l0f9bh:
      call     sub_0fb0h      ;0f9b    cd  b0  0f
      in       a,(08dh)       ;0f9e    db  8d
      ld       (hl),a         ;0fa0    77
      inc      hl             ;0fa1    23
      djnz     l0f9bh         ;0fa2    10  f7
      ret                     ;0fa4    c9
sub_0fa5h:
      ld       b,(hl)         ;0fa5    46
l0fa6h:
      inc      hl             ;0fa6    23
      call     sub_0fb0h      ;0fa7    cd  b0  0f
      ld       a,(hl)         ;0faa    7e
      out      (08dh),a       ;0fab    d3  8d
      djnz     l0fa6h         ;0fad    10  f7
      ret                     ;0faf    c9
sub_0fb0h:
      in       a,(08ch)       ;0fb0    db  8c
      bit      7,a            ;0fb2    cb  7f
      jr       z,sub_0fb0h    ;0fb4    28  fa
      ret                     ;0fb6    c9
sub_0fb7h:
      ld       hl,06020h      ;0fb7    21  20  60
      ld       a,h            ;0fba    7c
      ld       i,a            ;0fbb    ed  47
      ld       a,l            ;0fbd    7d
      out      (088h),a       ;0fbe    d3  88
      ld       a,0d5h         ;0fc0    3e  d5
      out      (088h),a       ;0fc2    d3  88
      ld       a,001h         ;0fc4    3e  01
      out      (088h),a       ;0fc6    d3  88
      ld       hl,l0fd6h      ;0fc8    21  d6  0f
      ld       (06020h),hl    ;0fcb    22  20  60
      ld       hl,l0ed2h      ;0fce    21  d2  0e
      ld       (06022h),hl    ;0fd1    22  22  60
      ei                      ;0fd4    fb
      ret                     ;0fd5    c9
l0fd6h:
      ei                      ;0fd6    fb
      reti                    ;0fd7    ed  4d
word_res:
      ld       a,008h         ;0fd9    3e  08
      out      (08dh),a       ;0fdb    d3  8d
      call     sub_0fb0h      ;0fdd    cd  b0  0f
      ld       b,002h         ;0fe0    06  02
      call     sub_0f90h      ;0fe2    cd  90  0f
      ret                     ;0fe5    c9
sub_0fe6h:
      reti                    ;0fe6    ed  4d
l0fe8h:
      nop                     ;0fe8    00
      ret      po             ;0fe9    e0
      add      hl,bc          ;0fea    09
      ld       b,d            ;0feb    42
      ld       bc,l0001h      ;0fec    01  01  00
      ld       bc,01001h      ;0fef    01  01  10
      ld       c,000h         ;0ff2    0e  00
      inc      bc             ;0ff4    03
      rrca                    ;0ff5    0f
      ld       bc,l0201h      ;0ff6    01  01  02
      rlca                    ;0ff9    07
      ld       bc,l0303h      ;0ffa    01  03  03
      ld       h,b            ;0ffd    60
      inc      (hl)           ;0ffe    34  4
      rst      38h            ;0fff    ff
