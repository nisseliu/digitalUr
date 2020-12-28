	jmp		START
	.org	OC1Aaddr
	jmp		TIMER_INTERUPT



.equ	E = 1
.equ	RS = 0
.equ	FN_SET = $28
.equ	DISP_ON = $0F
.equ	LCD_CLR = $01
.equ	E_MODE = $06
.equ	RET_HOME = $03
.equ	ERASE = $01
.equ	SECOND_TICKS = 62500 - 1

.dseg
TIME_STRING: .byte 9
TIME: .byte 6
.cseg



TIMER_INTERUPT:
	push	r16
	in		r16, SREG
	push	r16
	push	r17
	push	r18
	push	ZH
	push	ZL
	push	YH
	push	YL

	call	TIME_TICK
	call	TIME_FORMAT
	ldi		ZH, HIGH(TIME_STRING)
	ldi		ZL, LOW(TIME_STRING)
	call	LCD_PRINT
	call	LCD_HOME

	pop		YL
	pop		YH
	pop		ZL
	pop		ZH
	pop		r18 
	pop		r17
	pop		r16
	out		SREG, r16
	pop		r16

	reti

	
INIT_PORTS:				//Initierar de berörda portarna databladet förklarar.
	sbi		DDRB, 0
	sbi		DDRB, 1
	sbi		DDRB, 2
	ldi		r16, $F0
	out		DDRD, r16
	ret

START:
	ldi		r16, HIGH(RAMEND)
	out		SPH, r16
	ldi		r16, LOW(RAMEND)
	out		SPL, r16

	call	INIT_PORTS			//Måste anropas i början
	
	call	LCD_INIT			//Måste också anropas tidigt. Denna initierar LCDn
	call	LCD_CLEAR
	ldi		r16, 10
	call	DELAY
	
	call	LCD_HOME

	call	INIT_TIME
	sei
	call	TIMER1_INIT
MAIN:
	jmp		MAIN
	

LCD_INIT:					//Denna rutin är väldigt viktigt! Den kräver samtliga av de nedan nämnda rutinerna. 
	call	BACKLIGHT_OFF
	call	DELAY
	call	BACKLIGHT_ON
	call	DELAY

	ldi		r16 , $30
	call	LCD_WRITE4
	call	LCD_WRITE4
	call	LCD_WRITE4
	ldi		r16 , $20
	call	LCD_WRITE4

	; -- 
	ldi		r16 , FN_SET
	call	LCD_COMMAND

	; --- Display on , cursor on , cursor blink
	ldi		r16 , DISP_ON
	call	LCD_COMMAND

	; --- Clear display
	ldi		r16 , LCD_CLR
	call	LCD_COMMAND

	; --- Entry mode : Increment cursor , no shift
	ldi		r16 , E_MODE
	call	LCD_COMMAND

	ret


BACKLIGHT_ON:
	sbi		PORTB, 2
	ret

BACKLIGHT_OFF:
	cbi		PORTB, 2
	ret

LCD_WRITE4:
	sbi		PORTB, E
	out		PORTD, r16
	call	WAIT
	cbi		PORTB, E 	
	ret

LCD_WRITE8:
	call	LCD_WRITE4
	swap	r16
	call	LCD_WRITE4
	ret

LCD_COMMAND:
	cbi		PORTB, RS
	call	LCD_WRITE8
	ret

LCD_ASCII:
	sbi		PORTB, RS
	call	LCD_WRITE8
	ret

LCD_CLEAR:
	ldi		r16, ERASE
	call	LCD_COMMAND
	ret

LCD_HOME:
	ldi		r16, RET_HOME
	call	LCD_COMMAND
	ret


INIT_TIME:					//Denna initierar tiden vid starten
	ldi		ZH, HIGH(TIME)		//Z-Pekaren pekar på TIME delen i minnet
	ldi		ZL, LOW(TIME)

	
	ldi		r16, 7			x
	std		Z+0, r16
	ldi		r16, 5
	std		Z+1, r16
	

	ldi		r16, 9		
	std		Z+2, r16
	ldi		r16, 5
	std		Z+3, r16
	
	ldi		r16, 3		
	std		Z+4, r16
	ldi		r16, 2
	std		Z+5, r16

	ret

LCD_PRINT:
	ld		r16, Z+
	cpi		r16, 0
	breq	LCD_PRINT_DONE	
	call	LCD_ASCII
	jmp		LCD_PRINT

	LCD_PRINT_DONE:
	ret


TIME_TICK:
	ldi		YH, HIGH(TIME)
	ldi		YL, LOW(TIME)
	ldi		ZH, HIGH(MAX_VALUES*2)
	ldi		ZL, LOW(MAX_VALUES*2)

	ldi		r19, 6			//Loop counter
TIME_LOOP:
	ld		r16, Y			//Load digit
	lpm		r17, Z+			//Load Max value for digit in r16
	cpi		r19, 2			//Check if we are handling one-hour digit
	brne	COMPARE_MAX
	ldd		r18, Y+1		//Load ten-hour digit
	cpi		r18, 2			//Check if ten-hour digit is 2 aka 20:00
	brne	COMPARE_MAX
	ldi		r17, 3			//Change one-hour digit max value to 3 aka 23:XX is the latest possible
	
COMPARE_MAX:
	cp		r16, r17		//Compare digit with max value
	breq	OVERFLOW
	inc		r16				//If not max increase by one
	st		Y, r16			//Save new time in Y
	jmp		EXIT

OVERFLOW:
	ldi		r16, 0			//Load zero because max value is overflow
	st		Y+, r16			//Save new time
	dec		r19				//Dec loop counter by one
	cpi		r19, 0			
	brne	TIME_LOOP		//Check if we are done
	
EXIT:
	ret	

TIME_FORMAT:
	ldi		ZH, HIGH(TIME)
	ldi		ZL, LOW(TIME)

	ldi		YH, HIGH(TIME_STRING)
	ldi		YL, LOW(TIME_STRING)

	ldi		r17, $30

	ldd		r16, Z+5		//Omvandlar tiotals-timme till ascii
	add		r16, r17
	std		Y+0, r16

	ldd		r16, Z+4		//Omvandlar	entals-timme till ascii
	add		r16, r17
	std		Y+1, r16


	ldi		r16, $3A		//Skriver :
	std		Y+2, r16

	ldd		r16, Z+3		//Omvandlar	tiotals-minut till ascii
	add		r16, r17
	std		Y+3, r16

	ldd		r16, Z+2
	add		r16, r17
	std		Y+4, r16

	ldi		r16, $3A
	std		Y+5, r16

	ldd		r16, Z+1
	add		r16, r17
	std		Y+6, r16

	ldd		r16, Z+0
	add		r16, r17
	std		Y+7, r16

	ldi		r16, 0
	std		Y+8, r16
	ret

WAIT:					//Min WAIT-loop går att kopierar rakt av i samtliga program som använder LCD
	adiw	r24,1
	brne	WAIT
	ret

	DELAY:
	ldi		r16, 1
	DELAY_LOOP:
	call	WAIT
	dec		r16
	brne	DELAY_LOOP
	ret


TIMER1_INIT :
	ldi r16 ,(1 << WGM12 )|(1 << CS12 ) ; CTC , prescale 256
	sts TCCR1B , r16
	ldi r16 , HIGH ( SECOND_TICKS )
	sts OCR1AH , r16
	ldi r16 , LOW ( SECOND_TICKS )
	sts OCR1AL , r16
	ldi r16 ,(1 << OCIE1A ) ; allow to interrupt
	sts TIMSK1 , r16
	ret


MAX_VALUES: .db $09, $05, $09, $05, $09, $02
