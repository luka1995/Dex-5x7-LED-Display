;*******************************************************
;**      D E X   5 X 7   L E D   D I S P L A Y        **
;**                                                   **
;**                      pic 16F689                   **
;**                                                   **
;**                                   by Mucek4 & Dex **
;*******************************************************

	#include "P16F689.INC"
	#include "Defines.inc"


;*******************************************************
;** Konfiguracijsi biti                               **
;*******************************************************
; 
	__CONFIG  _MCLRE_ON & _FCMEN_OFF & _BOR_OFF & _WDT_OFF & _INTRC_OSC_NOCLKOUT & _CP_OFF & _CPD_OFF
;	__CONFIG 0x30F4
;	__CONFIG b'11010011110100'

;*******************************************************
;**  Spremenljivke                                    **
;*******************************************************

	cblock 0x20
	COLUMNS:0, C1, C2, C3, C4, C5
	COLUMNSCOUNT
	ASCII_CHAR, ASCII_FOR, ASCII_ADDR
	FLAGS, d3, d1, d2, d4
	endc

	cblock 0x70
	WTMP, STMP, FSRTMP, PCLATHTMP
	endc

;*******************************************************
;**  Definiranje konstant                             **
;*******************************************************


;*******************************************************
;**  Program                                          **
;*******************************************************

	;reset vector
	org 0x00
	goto MAIN

	;interrupt vector
	org 0x04
	movwf WTMP						; Save W and status
	swapf STATUS,W					;
	movwf STMP						;
	clrf STATUS						; Clear status ( BANK 0 )
	movfw FSR						; save FSR
	movwf FSRTMP					;
	movfw PCLATH					; save PCLATH
	movwf PCLATHTMP					;
	clrf PCLATH						;

	bcf INTCON, T0IF				; Clear T0 interrupt bit

	clrf CATODES					; Clear display

	incf COLUMNSCOUNT,f				; Increment cathode
	movlw .5						; check if COLUMNSCOUNT is 5
	subwf COLUMNSCOUNT,w			;
	btfsc STATUS, Z					;
	clrf COLUMNSCOUNT				; and set it to 0 if so

	bankisel COLUMNS				; sets bank for indirect addressing
	movlw COLUMNS					; loads an address of columens
	addwf COLUMNSCOUNT, w			; adds an columns count
	movwf FSR						; sets to FSR (address for indirect addressing)
	movfw INDF						; indirect addressing
	movwf LEDOUTPUT					; sets to LEDs

	call LOOKUP_COLUMNS				; call lookup table
	movwf CATODES					; and fire up the right catode


	movfw PCLATHTMP					; restore PCLATH
	movwf PCLATH					;
	movfw FSRTMP					; restore FSR 
	movwf FSR						;
	swapf STMP,w					; restore W and status
	movwf STATUS					;
	swapf WTMP,f					;
	swapf WTMP,w					;
	retfie

LOOKUP_COLUMNS
	clrf PCLATH						; clr PCLATH (we are on 1st page)
	movfw COLUMNSCOUNT				; load COLUMNSCOUNT
	addwf PCL, f					; adding columnsCount to program counter
	retlw _CAT1						;0
	retlw _CAT2						;1
	retlw _CAT3						;2
	retlw _CAT4						;3
	retlw _CAT5						;4


MAIN

	banksel OSCCON					;
	movlw b'01110001'				; 8 MHz
			errorlevel      -302
	movwf OSCCON					;
			errorlevel      +302

	banksel ANSEL					; select input as digital
			errorlevel      -302
	clrf ANSEL						;
	clrf ANSELH						;
			errorlevel      +302

	banksel PORTA					; set A and B to 0
	clrf PORTA						;
	clrf PORTB						;
	movlw 0xff						; and set to C to 1
	movwf PORTC						;

	banksel TRISA					; output selection
			errorlevel      -302
	clrf TRISA						; all output
	clrf TRISB						; 
	clrf TRISC						; 
			errorlevel      +302

	;Init timer0 for display
	banksel OPTION_REG
	movlw b'10000001'				; Disable pullups, internal clock source, 1:4 prescaler
			errorlevel      -302
	movwf OPTION_REG				;
			errorlevel      +302

	; Enable timer0 int
	movlw b'10100000'				; Timer0 interrupt
	movwf INTCON					;

	banksel C1						; clear all display
	movlw 0xff						;
	movwf C1						;
	movwf C2						;
	movwf C3						;
	movwf C4						;
	movwf C5						;

	clrf COLUMNSCOUNT				; Defines a selected column

	movlw b'11111111'				; Clear screen
	movwf PORTC						;


MAIN_LOOP

	movlw .32
	movwf d4

LOOPY
	movfw d4
	pagesel DISPLAY_ASCII
	call DISPLAY_ASCII

	call DELAY

	incf d4, f
	movfw d4
	sublw .128
	btfss STATUS, Z
	goto LOOPY


	goto MAIN_LOOP

DELAY
			;499994 cycles
	movlw	0x03
	movwf	d1
	movlw	0x18
	movwf	d2
	movlw	0x02
	movwf	d3
DELAY_0
	decfsz	d1, f
	goto	$+2
	decfsz	d2, f
	goto	$+2
	decfsz	d3, f
	goto	DELAY_0

			;2 cycles
	goto	$+1

			;4 cycles (including call)
	return





	org 0xD00


; as W we get an ASCII character between .32 (space) and .127 (left arrow)
; the lookup CALL returns ASCII char in C1 to C5 or returns firts ASCII (space)
; if W not in range
; start in bank0, page1
; exits in bank0, page0
DISPLAY_ASCII
	movwf ASCII_CHAR				; store W for later useage

	addlw .255 - .127				; Carry is set if W is in range
	addlw (.127 - .32) + .1			; from .32 to .127 inclusive
	movfw ASCII_CHAR				; Move ASCII_TEMP to W
	btfss STATUS, C					;
	movlw .32						; if input out of range set it to default value
	movwf ASCII_CHAR				; and write it bank to ASCII_TEMP

	; set appropriate PCLATH
	addlw .255 - .127				; Carry is set if W is in range
	addlw (.127 - .80) + .1			; from .80 to .127 inclusive
	btfsc STATUS, C					; for calling lookup tables
	goto ASCII_SET_H
;ASCII_SET_L
	movlw high(ASCII_LO)			; set PCLATH to lo part
	movwf PCLATH					;

	bcf ASCII_HILO					; set to lo

	movlw .32						; calculate address
	subwf ASCII_CHAR, w				;
	movwf ASCII_ADDR				;

	goto ASCII_SET_SKIP	
ASCII_SET_H
	movlw high(ASCII_HI)			; sets PCLATH (higer part of address)
	movwf PCLATH					;

	bsf ASCII_HILO					; set to hi

	movlw .80						; calculate address
	subwf ASCII_CHAR, w				;
	movwf ASCII_ADDR				;

ASCII_SET_SKIP

	movfw ASCII_ADDR				; multiply address by 5
	addwf ASCII_ADDR, f				; (actually adding the same value 4 times)
	addwf ASCII_ADDR, f				;
	addwf ASCII_ADDR, f				;
	addwf ASCII_ADDR, f				;

	clrf ASCII_FOR					; set to 0
ASCII_FOR_LOOP
	; start loop
	movlw COLUMNS					; Calculate address for indirect addressing
	addwf ASCII_FOR, w				; 
	movwf FSR						; Save result in FSR

	movfw ASCII_ADDR				; Calculate address for lookup table
	addwf ASCII_FOR, w				; 

	btfsc ASCII_HILO				; 
	call ASCII_HI					; calls HI
	btfss ASCII_HILO				; 
	call ASCII_LO					; or LO lookup table

	movwf INDF						; and saves resoult to register using indirect addressing
	; end loop

	incf ASCII_FOR, f				; increment
	movlw .5						; and check if it's 5
	subwf ASCII_FOR, w				;
	btfss STATUS, Z					;
	goto ASCII_FOR_LOOP				; if not 5 goto back

	clrf PCLATH						; Exits in page0
	return



; WARNING!!!
; PCLATH MUST BE SET BEFORE CALLING THIS SUBROUTINE!
; in W is the parameter for the call
	org 0x0E00
ASCII_LO
	addwf PCL, f					; adding columnsCount to program counter
	; spejs
	retlw 0xFF
	retlw 0xFF
	retlw 0xFF
	retlw 0xFF
	retlw 0xFF
	; !
	retlw 0xFF
	retlw 0xFF
	retlw 0xB0
	retlw 0xFF
	retlw 0xFF
	; "
	retlw 0xFF
	retlw 0xF8
	retlw 0xFF
	retlw 0xF8
	retlw 0xFF
	; #
	retlw 0xEB
	retlw 0x80
	retlw 0xEB
	retlw 0x80
	retlw 0xEB
	; $
	retlw 0xDB
	retlw 0xD5
	retlw 0x80
	retlw 0xD5
	retlw 0xED
	; %
	retlw 0xDC
	retlw 0xEC
	retlw 0xF7
	retlw 0x9B
	retlw 0x9D
	; &
	retlw 0xC9
	retlw 0xB6
	retlw 0xAA
	retlw 0xDD
	retlw 0xAF
	; '
	retlw 0xFF
	retlw 0xFA
	retlw 0xFC
	retlw 0xFF
	retlw 0xFF
	; (
	retlw 0xFF
	retlw 0xE3
	retlw 0xDD
	retlw 0xBE
	retlw 0xFF
	; )
	retlw 0xFF
	retlw 0xBE
	retlw 0xDD
	retlw 0xE3
	retlw 0xFF
	; *
	retlw 0xEB
	retlw 0xF7
	retlw 0xC1
	retlw 0xF7
	retlw 0xEB
	; +
	retlw 0xF7
	retlw 0xF7
	retlw 0xC1
	retlw 0xF7
	retlw 0xF7
	; ,
	retlw 0xFF
	retlw 0xAF
	retlw 0xCF
	retlw 0xFF
	retlw 0xFF
	; -
	retlw 0xF7
	retlw 0xF7
	retlw 0xF7
	retlw 0xF7
	retlw 0xF7
	; .
	retlw 0xFF
	retlw 0x9F
	retlw 0x9F
	retlw 0xFF
	retlw 0xFF
	; /
	retlw 0xDF
	retlw 0xEF
	retlw 0xF7
	retlw 0xFB
	retlw 0xFD
	; 0
	retlw 0xC1
	retlw 0xBE
	retlw 0xBE
	retlw 0xBE
	retlw 0xC1
	; 1
	retlw 0xFF
	retlw 0xBD
	retlw 0x80
	retlw 0xBF
	retlw 0xFF
	; 2
	retlw 0xBD
	retlw 0x9E
	retlw 0xAE
	retlw 0xB6
	retlw 0xB9
	; 3
	retlw 0xDE
	retlw 0xBE
	retlw 0xBA
	retlw 0xB4
	retlw 0xCE
	; 4
	retlw 0xE7
	retlw 0xEB
	retlw 0xED
	retlw 0x80
	retlw 0xEF
	; 5
	retlw 0xD8
	retlw 0xBA
	retlw 0xBA
	retlw 0xBA
	retlw 0xC6
	; 6
	retlw 0xC3
	retlw 0xB5
	retlw 0xB6
	retlw 0xB6
	retlw 0xCF
	; 7
	retlw 0xFE
	retlw 0x8E
	retlw 0xF6
	retlw 0xFA
	retlw 0xFC
	; 8
	retlw 0xC9
	retlw 0xB6
	retlw 0xB6
	retlw 0xB6
	retlw 0xC9
	; 9
	retlw 0xF9
	retlw 0xB6
	retlw 0xB6
	retlw 0xD6
	retlw 0xE9
	; :
	retlw 0xFF
	retlw 0xFF
	retlw 0xC9
	retlw 0xFF
	retlw 0xFF
	; ;
	retlw 0xFF
	retlw 0xA9
	retlw 0xC9
	retlw 0xFF
	retlw 0xFF
	; <
	retlw 0xF7
	retlw 0xEB
	retlw 0xDD
	retlw 0xBE
	retlw 0xFF
	; =
	retlw 0xEB
	retlw 0xEB
	retlw 0xEB
	retlw 0xEB
	retlw 0xEB
	; >
	retlw 0xFF
	retlw 0xBE
	retlw 0xDD
	retlw 0xEB
	retlw 0xF7
	; ?
	retlw 0xFD
	retlw 0xFE
	retlw 0xAE
	retlw 0xF6
	retlw 0xF9
	; @
	retlw 0xCD
	retlw 0xB6
	retlw 0x86
	retlw 0xBE
	retlw 0xC1
	; A
	retlw 0x81
	retlw 0xEE
	retlw 0xEE
	retlw 0xEE
	retlw 0x81
	; B
	retlw 0x80
	retlw 0xB6
	retlw 0xB6
	retlw 0xB6
	retlw 0xC9
	; C
	retlw 0xC1
	retlw 0xBE
	retlw 0xBE
	retlw 0xBE
	retlw 0xDD
	; D
	retlw 0x80
	retlw 0xBE
	retlw 0xBE
	retlw 0xDD
	retlw 0xE3
	; E
	retlw 0x80
	retlw 0xB6
	retlw 0xB6
	retlw 0xB6
	retlw 0xBE
	; F
	retlw 0x80
	retlw 0xF6
	retlw 0xF6
	retlw 0xF6
	retlw 0xFE
	; G
	retlw 0xC1
	retlw 0xBE
	retlw 0xB6
	retlw 0xB6
	retlw 0x85
	; H
	retlw 0x80
	retlw 0xF7
	retlw 0xF7
	retlw 0xF7
	retlw 0x80
	; I
	retlw 0xFF
	retlw 0xBE
	retlw 0x80
	retlw 0xBE
	retlw 0xFF
	; J
	retlw 0xDF
	retlw 0xBF
	retlw 0xBE
	retlw 0xC0
	retlw 0xFE
	; K
	retlw 0x80
	retlw 0xF7
	retlw 0xEB
	retlw 0xDD
	retlw 0xBE
	; L
	retlw 0x80
	retlw 0xBF
	retlw 0xBF
	retlw 0xBF
	retlw 0xBF
	; M
	retlw 0x80
	retlw 0xFD
	retlw 0xF3
	retlw 0xFD
	retlw 0x80
	; N
	retlw 0x80
	retlw 0xFB
	retlw 0xF7
	retlw 0xEF
	retlw 0x80
	; O
	retlw 0xC1
	retlw 0xBE
	retlw 0xBE
	retlw 0xBE
	retlw 0xC1	

	org 0x0F00
ASCII_HI
	addwf PCL, f					; adding columnsCount to program counter
	; P
	retlw 0x80
	retlw 0xF6
	retlw 0xF6
	retlw 0xF6
	retlw 0xF9
	; Q
	retlw 0xC1
	retlw 0xBE
	retlw 0xAE
	retlw 0xDE
	retlw 0xA1
	; R
	retlw 0x80
	retlw 0xF6
	retlw 0xE6
	retlw 0xD6
	retlw 0xB9
	; S
	retlw 0xB9
	retlw 0xB6
	retlw 0xB6
	retlw 0xB6
	retlw 0xCE
	; T
	retlw 0xFE
	retlw 0xFE
	retlw 0x80
	retlw 0xFE
	retlw 0xFE
	; U
	retlw 0xC0
	retlw 0xBF
	retlw 0xBF
	retlw 0xBF
	retlw 0xC0
	; V
	retlw 0xE0
	retlw 0xDF
	retlw 0xBF
	retlw 0xDF
	retlw 0xE0
	; W
	retlw 0xC0
	retlw 0xBF
	retlw 0xC7
	retlw 0xBF
	retlw 0xC0
	; X
	retlw 0x9C
	retlw 0xEB
	retlw 0xF7
	retlw 0xEB
	retlw 0x9C
	; Y
	retlw 0xF8
	retlw 0xF7
	retlw 0x8F
	retlw 0xF7
	retlw 0xF8
	; Z
	retlw 0x9E
	retlw 0xAE
	retlw 0xB6
	retlw 0xBA
	retlw 0xBC
	; [
	retlw 0xFF
	retlw 0x80
	retlw 0xBE
	retlw 0xBE
	retlw 0xFF
	; jen
	retlw 0xEA
	retlw 0xE9
	retlw 0x80
	retlw 0xE9
	retlw 0xEA
	; ]
	retlw 0xFF
	retlw 0xBE
	retlw 0xBE
	retlw 0x80
	retlw 0xFF
	; ^
	retlw 0xFB
	retlw 0xFD
	retlw 0xFE
	retlw 0xFD
	retlw 0xFB
	; _
	retlw 0xBF
	retlw 0xBF
	retlw 0xBF
	retlw 0xBF
	retlw 0xBF
	; `
	retlw 0xFF
	retlw 0xFE
	retlw 0xFD
	retlw 0xFB
	retlw 0xFF
	; a
	retlw 0xDF
	retlw 0xAB
	retlw 0xAB
	retlw 0xAB
	retlw 0x87
	; b
	retlw 0x80
	retlw 0xB7
	retlw 0xBB
	retlw 0xBB
	retlw 0xC7
	; c
	retlw 0xC7
	retlw 0xBB
	retlw 0xBB
	retlw 0xBB
	retlw 0xDF
	; d
	retlw 0xC7
	retlw 0xBB
	retlw 0xBB
	retlw 0xB7
	retlw 0x80
	; e
	retlw 0xC7
	retlw 0xAB
	retlw 0xAB
	retlw 0xAB
	retlw 0xE7
	; f
	retlw 0xF7
	retlw 0x81
	retlw 0xF6
	retlw 0xFE
	retlw 0xFD
	; g
	retlw 0xF3
	retlw 0xAD
	retlw 0xAD
	retlw 0xAD
	retlw 0xC1
	; h
	retlw 0x80
	retlw 0xF7
	retlw 0xFB
	retlw 0xFB
	retlw 0x87
	; i
	retlw 0xFF
	retlw 0xBB
	retlw 0x82
	retlw 0xBF
	retlw 0xFF
	; j
	retlw 0xDF
	retlw 0xBF
	retlw 0xBB
	retlw 0xC2
	retlw 0xFF
	; k
	retlw 0x80
	retlw 0xEF
	retlw 0xD7
	retlw 0xBB
	retlw 0xFF
	; l
	retlw 0xFF
	retlw 0xBE
	retlw 0x80
	retlw 0xBF
	retlw 0xFF
	; m
	retlw 0x83
	retlw 0xFB
	retlw 0xE7
	retlw 0xFB
	retlw 0x87
	; n
	retlw 0x83
	retlw 0xF7
	retlw 0xFB
	retlw 0xFB
	retlw 0x87
	; o
	retlw 0xC7
	retlw 0xBB
	retlw 0xBB
	retlw 0xBB
	retlw 0xC7
	; p
	retlw 0x83
	retlw 0xEB
	retlw 0xEB
	retlw 0xEB
	retlw 0xF7
	; q
	retlw 0xF7
	retlw 0xEB
	retlw 0xEB
	retlw 0xE7
	retlw 0x83
	; r
	retlw 0x83
	retlw 0xF7
	retlw 0xFB
	retlw 0xFB
	retlw 0xFF
	; s
	retlw 0xF7
	retlw 0xAB
	retlw 0xAB
	retlw 0xAB
	retlw 0xDF
	; t
	retlw 0xFB
	retlw 0xC0
	retlw 0xBB
	retlw 0x9F
	retlw 0xFF
	; u
	retlw 0xC3
	retlw 0xBF
	retlw 0xBF
	retlw 0xDF
	retlw 0x83
	; v
	retlw 0xE3
	retlw 0xDF
	retlw 0xBF
	retlw 0xDF
	retlw 0xE3
	; w
	retlw 0xC3
	retlw 0xBF
	retlw 0xCF
	retlw 0xBF
	retlw 0xC3
	; x
	retlw 0xBB
	retlw 0xD7
	retlw 0xEF
	retlw 0xD7
	retlw 0xBB
	; y
	retlw 0xF3
	retlw 0xAF
	retlw 0xAF
	retlw 0xAF
	retlw 0xD3
	; z
	retlw 0xBB
	retlw 0x9B
	retlw 0xAB
	retlw 0xB3
	retlw 0xBB
	; {
	retlw 0xFF
	retlw 0xF7
	retlw 0xC9
	retlw 0xBE
	retlw 0xFF
	; |
	retlw 0xFF
	retlw 0xFF
	retlw 0x80
	retlw 0xFF
	retlw 0xFF
	; }
	retlw 0xFF
	retlw 0xBE
	retlw 0xC9
	retlw 0xF7
	retlw 0xFF
	; --> (pušèica desno)
	retlw 0xF7
	retlw 0xF7
	retlw 0xD5
	retlw 0xE3
	retlw 0xF7
	; <-- (pušèica levo)
	retlw 0xF7
	retlw 0xE3
	retlw 0xD5
	retlw 0xF7
	retlw 0xF7

	end