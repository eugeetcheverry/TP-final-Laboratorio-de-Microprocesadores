 .include "m328pdef.inc"


 .def aux_SREG = r18
 .org SRAM_START

.cseg

.org 0X0000
	rjmp main

main:
	;Inicializo stack-pointer
	ldi r16, low(RAMEND)
	out spl, r16
	ldi r16, high(RAMEND)
	out sph, r16

	;inicializo los puertos 
	ldi r16, 0b01011111
	out ddrc, r16

	ldi r16, 0b00001111
	out ddrb, r16

;FUNCION LED_TITILANDO--------------------------------------------------
led_titilando:
	;timer de 0.5ms por ctc 
	cli
	ldi r16, 0b10000010
	out TCCR0A, r16
	ldi r16, 0b10000010
	out TCCR0A, r16

	ldi r16, 39 ; top con prescaler de 1024
	out OCR0A, r16
	sei
	ldi r16, 0b00000101
	out TCCR0B, r16 ; cuando seteamos el prescaler 64 arranca a contar
	sei
	ldi r16, 5 ; contador
	ldi r17, 0x0f
	ldi r18, 0x0f
	out PORTC, r17
	out PORTB, r17
	
	
toggle_leds:
	sbis TIFR0, 1
	rjmp toggle_leds
	cpi r16, 0
	in aux_SREG, sreg
	sbrc aux_SREG, 1
	rcall apago_timer_leds
	eor r17, r18
	out PORTC, r17
	out PORTB, r17
	dec r16
	rjmp toggle_leds

apago_timer_leds:
	clr r16
	out TCCR0B, r16
	out PORTC, r16
	out PORTB, r16
	ret

loop_wait:
	rjmp loop_wait
