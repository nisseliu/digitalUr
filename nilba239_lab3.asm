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

	call	TIME_TACK
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

	
INIT_PORTS:
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


	call	INIT_PORTS
	
	call	LCD_INIT
	call	LCD_CLEAR
	ldi		r16, 10
	call	DELAY
	
	call	LCD_HOME

	call	INIT_TIME
	sei
	call	TIMER1_INIT
MAIN:
	jmp		MAIN
	

LCD_INIT:
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


INIT_TIME:
	ldi		ZH, HIGH(TIME)
	ldi		ZL, LOW(TIME)

	
		
	ldi		r16, 0		
	std		Z+0, r16
	ldi		r16, 4
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


TIME_TACK:
	ldi		ZH, HIGH(TIME)
	ldi		ZL, LOW(TIME)

	ldd		r16, Z+0		//Entals-sekund
	cpi		r16, 9
	breq	OVERFLOW_SECOND
	inc		r16
	std		Z+0, r16
	jmp		TIME_TICK_EXIT
	
	

OVERFLOW_SECOND:
	ldi		r16, 0
	std		Z+0, r16		//Ental-sekund noll(0)
	ldd		r16, Z+1
	cpi		r16, 5
	breq	OVERFLOW_TEN_SECOND
	inc		r16
	std		Z+1, r16
	jmp		TIME_TICK_EXIT

OVERFLOW_TEN_SECOND:
	ldi		r16, 0
	std		Z+1, r16		//Tiotals-sekund (0)
	ldd		r16, Z+2
	cpi		r16, 9
	breq	OVERFLOW_MINUTE	
	inc		r16
	std		Z+2, r16
	jmp		TIME_TICK_EXIT

OVERFLOW_MINUTE:
	ldi		r16, 0
	std		Z+2, r16		//Entals-minut noll(0)
	ldd		r16, Z+3
	cpi		r16, 5
	breq	OVERFLOW_TEN_MINUTE	
	inc		r16
	std		Z+3, r16
	jmp		TIME_TICK_EXIT



OVERFLOW_TEN_MINUTE:
	ldi		r16, 0
	std		Z+3, r16		//Tiotals-minut noll(0)
	
	//Börjar på entals-timmen nu
	//Först måste tiotals-timmen kollas upp

	ldd		r18, Z+5		//sätter r17 till Tiotals-timme
	cpi		r18, 2			// ÄRr tiotals-timmen 2?
	breq	LATE_NIGHT		//Om den är det gå till LATE_NIGHT
	ldi		r17, 9			//Om inte tiotals-timmen är 2 så kan entals-timmen var max 9
	jmp		HOUR
LATE_NIGHT:					//Här är klockan > 19:59:59
	ldi		r17, 3			//Här kan entals timmen vara max 3 dvs max 23:59:59
HOUR:
	ldd		r16, Z+4		//Läser in entals-timmen till r16
	cp		r16, r17		//Jämför r16 med r17. r17 innehåller entals-timmen maxvärde.
	breq	SET_HOUR_ZERO
	inc		r16
	std		Z+4, r16
	jmp		TIME_TICK_EXIT

SET_HOUR_ZERO:
	ldi		r16, 0
	std		Z+4, r16
	cpi		r18, 2
	breq	NEW_DAY
	inc		r18
	std		Z+5, r18
	jmp		TIME_TICK_EXIT

NEW_DAY:
	ldi		r18, 0
	std		Z+5, r18
TIME_TICK_EXIT:
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

WAIT:
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